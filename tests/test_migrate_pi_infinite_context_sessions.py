#!/usr/bin/env python3
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).parents[1] / "scripts/migrate-pi-infinite-context-sessions.py"
spec = importlib.util.spec_from_file_location("pi_migration", SCRIPT)
assert spec and spec.loader
migration = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = migration
spec.loader.exec_module(migration)


class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / "sessions"
        self.root.mkdir()
        self.backup = Path(self.temp.name) / "backups"

    def tearDown(self):
        self.temp.cleanup()

    def write_jsonl(self, path: Path, records, *, trailing_newline=True):
        path.parent.mkdir(parents=True, exist_ok=True)
        text = "\n".join(json.dumps(record, separators=(",", ":")) for record in records)
        if trailing_newline:
            text += "\n"
        path.write_bytes(text.encode())

    def apply(self):
        return migration.migrate(
            [self.root],
            apply=True,
            backup_dir=self.backup,
            process_detector=lambda: [],
            emit=lambda _line: None,
        )

    def test_split_jsonl_preserves_line_endings(self):
        cases = (
            (b"one\n", [(b"one", b"\n")]),
            (b"one\r\n", [(b"one", b"\r\n")]),
            (b"one\rtwo", [(b"one", b"\r"), (b"two", b"")]),
            (
                b"one\ntwo\r\nthree\rfour",
                [
                    (b"one", b"\n"),
                    (b"two", b"\r\n"),
                    (b"three", b"\r"),
                    (b"four", b""),
                ],
            ),
        )
        for raw, expected in cases:
            parts = list(migration._split_jsonl(raw))
            self.assertEqual(parts, expected)
            self.assertEqual(b"".join(content + ending for content, ending in parts), raw)

    def test_backup_failure_leaves_originals_unchanged(self):
        paths = [self.root / "a.jsonl", self.root / "b.jsonl"]
        record = {"type": "custom", "customType": "context-prune", "data": {"pruned": ["x"]}}
        for path in paths:
            self.write_jsonl(path, [record])
        originals = {path: path.read_bytes() for path in paths}
        real_create_backup = migration._create_backup
        calls = 0

        def fail_on_second_backup(plan):
            nonlocal calls
            calls += 1
            if calls == 2:
                raise migration.ApplyError("injected backup failure")
            real_create_backup(plan)

        with mock.patch.object(migration, "_create_backup", side_effect=fail_on_second_backup):
            with self.assertRaises(migration.ApplyError):
                self.apply()
        self.assertEqual({path: path.read_bytes() for path in paths}, originals)

    def test_replacement_failure_rolls_back_every_attempted_original(self):
        paths = [self.root / "a.jsonl", self.root / "b.jsonl"]
        record = {"type": "custom", "customType": "context-prune", "data": {"pruned": ["x"]}}
        for path in paths:
            self.write_jsonl(path, [record])
        originals = {path: path.read_bytes() for path in paths}
        real_atomic_write = migration._atomic_write
        calls = 0

        def fail_after_second_replacement(path, content, mode):
            nonlocal calls
            calls += 1
            real_atomic_write(path, content, mode)
            if calls == 2:
                raise OSError("injected replacement failure")

        with mock.patch.object(migration, "_atomic_write", side_effect=fail_after_second_replacement):
            with self.assertRaises(migration.ApplyError):
                self.apply()
        self.assertEqual({path: path.read_bytes() for path in paths}, originals)

    def test_source_mutation_after_backups_is_not_overwritten(self):
        paths = [self.root / "a.jsonl", self.root / "b.jsonl"]
        record = {"type": "custom", "customType": "context-prune", "data": {"pruned": ["x"]}}
        for path in paths:
            self.write_jsonl(path, [record])
        originals = {path: path.read_bytes() for path in paths}
        external = b'{"type":"session","id":"external"}\n'
        real_create_backup = migration._create_backup
        calls = 0

        def mutate_after_last_backup(plan):
            nonlocal calls
            calls += 1
            real_create_backup(plan)
            if calls == 2:
                paths[1].write_bytes(external)

        with mock.patch.object(migration, "_create_backup", side_effect=mutate_after_last_backup):
            with self.assertRaises(migration.ApplyError):
                self.apply()
        self.assertEqual(paths[0].read_bytes(), originals[paths[0]])
        self.assertEqual(paths[1].read_bytes(), external)

    def test_current_spans_and_historical_pruned_precedence(self):
        path = self.root / "session.jsonl"
        original = (
            b'{"type":"session","id":"s"}\r\n'
            b'{"type":"custom","customType":"context-prune","id":"c",'
            b'"parentId":"parent","data":{"spans":[{"fromId":"a","memberIds":["a","b"],"summary":"sum"}],'
            b'"pruned":["c","c"],"keep":7},"timestamp":"t"}\r\n'
        )
        path.write_bytes(original)
        os.chmod(path, 0o640)

        counts = self.apply()
        self.assertEqual((counts.matching_entries, counts.legacy_ids), (1, 2))
        self.assertEqual(counts.changed_files, 1)
        self.assertEqual(path.stat().st_mode & 0o777, 0o640)
        self.assertEqual((self.backup / "root-0" / "session.jsonl").read_bytes(), original)

        lines = path.read_bytes().splitlines(keepends=True)
        self.assertEqual(len(lines), 2)
        self.assertEqual(lines[0], b'{"type":"session","id":"s"}\r\n')
        header = json.loads(lines[0])
        self.assertEqual((header["type"], header["id"]), ("session", "s"))
        migrated = json.loads(lines[1])
        self.assertEqual(migrated["id"], "c")
        self.assertEqual(migrated["parentId"], "parent")
        self.assertEqual(migrated["timestamp"], "t")
        self.assertEqual(migrated["customType"], "infinite-context")
        self.assertEqual(migrated["data"]["keep"], 7)
        self.assertEqual(
            migrated["data"]["spans"],
            [
                {"fromId": "a", "memberIds": ["a", "b"], "summary": "sum"},
                {"fromId": "c", "memberIds": ["c"], "summary": ""},
                {"fromId": "c", "memberIds": ["c"], "summary": ""},
            ],
        )
        self.assertTrue(lines[1].endswith(b"\r\n"))

    def test_nested_branch_children_and_symlinks(self):
        nested = self.root / "branches" / "child" / "deep.jsonl"
        record = {
            "type": "custom",
            "customType": "context-prune",
            "data": {"pruned": ["message-id"]},
        }
        self.write_jsonl(nested, [{"type": "session", "id": "nested"}, record])
        outside = Path(self.temp.name) / "outside.jsonl"
        self.write_jsonl(outside, [record])
        outside_original = outside.read_bytes()
        os.symlink(outside, self.root / "ignored.jsonl")

        counts = migration.migrate(
            [self.root], process_detector=lambda: [], emit=lambda _line: None
        )
        self.assertEqual((counts.scanned_files, counts.matching_entries), (1, 1))
        self.assertEqual(json.loads(nested.read_text().splitlines()[1])["customType"], "context-prune")
        self.assertEqual(outside.read_bytes(), outside_original)

    def test_malformed_input_prevents_any_apply(self):
        good = self.root / "good.jsonl"
        bad = self.root / "bad.jsonl"
        record = {"type": "custom", "customType": "context-prune", "data": {"pruned": ["x"]}}
        self.write_jsonl(good, [record])
        bad.write_bytes(b'{"type":"custom"\n')
        original = good.read_bytes()

        with self.assertRaises(migration.MigrationError):
            self.apply()
        self.assertEqual(good.read_bytes(), original)
        self.assertFalse(self.backup.exists())

    def test_unrelated_bytes_and_idempotent_rerun(self):
        path = self.root / "mixed.jsonl"
        record = {"type": "custom", "customType": "context-prune", "data": {"pruned": []}}
        unrelated = b'{"type":"message","text":"keep  \\u2603"}  \r\n'
        path.write_bytes(unrelated + json.dumps(record).encode() + b"\r\n")

        first = self.apply()
        after_first = path.read_bytes()
        second = self.apply()
        self.assertEqual(first.changed_files, 1)
        self.assertEqual(second.changed_files, 0)
        self.assertEqual(path.read_bytes(), after_first)
        self.assertTrue(path.read_bytes().startswith(unrelated))

    def test_backup_collision_and_process_detection_refuse_apply(self):
        path = self.root / "session.jsonl"
        record = {"type": "custom", "customType": "context-prune", "data": {"pruned": ["x"]}}
        self.write_jsonl(path, [record])
        collision = self.backup / "root-0" / path.name
        collision.parent.mkdir(parents=True)
        collision.write_bytes(b"not-original")
        with self.assertRaises(migration.MigrationError):
            self.apply()
        self.assertEqual(json.loads(path.read_text())["customType"], "context-prune")

        collision.unlink()
        with self.assertRaises(migration.MigrationError):
            migration.migrate(
                [self.root],
                apply=True,
                backup_dir=self.backup,
                process_detector=lambda: [1234],
                emit=lambda _line: None,
            )
        self.assertEqual(json.loads(path.read_text())["customType"], "context-prune")


if __name__ == "__main__":
    unittest.main()
