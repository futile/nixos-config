#!/usr/bin/env python3
"""Migrate context-prune session entries to infinite-context snapshots.

The command is intentionally offline: stop Pi before using ``--apply``.
Without ``--apply`` it only parses and reports what would change.
"""
from __future__ import annotations

import argparse
import dataclasses
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
from typing import Callable, Iterator, Sequence


class MigrationError(Exception):
    """A validation or safety error; no migration should be applied."""


class ApplyError(MigrationError):
    """An error after apply started."""


@dataclasses.dataclass
class Counts:
    scanned_files: int = 0
    scanned_lines: int = 0
    matching_entries: int = 0
    legacy_ids: int = 0
    would_change_files: int = 0
    changed_files: int = 0
    backups: int = 0


@dataclasses.dataclass
class FilePlan:
    source: Path
    root_index: int
    relative: Path
    original: bytes
    migrated: bytes
    mode: int
    fingerprint: tuple[int, int, int, int]
    backup: Path | None = None


_SPAN_KEYS = {"fromId", "memberIds", "summary"}


def _reject_duplicate_keys(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate object key")
        result[key] = value
    return result


def _reject_constant(value: str) -> object:
    raise ValueError("non-standard JSON number")


def _parse_line(content: bytes, source: Path, line_number: int) -> object:
    try:
        text = content.decode("utf-8", errors="strict")
        return json.loads(
            text,
            object_pairs_hook=_reject_duplicate_keys,
            parse_constant=_reject_constant,
        )
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        raise MigrationError(f"{source}:{line_number}: invalid JSON ({exc})") from exc


def _split_jsonl(raw: bytes) -> Iterator[tuple[bytes, bytes]]:
    """Yield (JSON bytes, original line ending), preserving every byte."""
    for line in raw.splitlines(keepends=True):
        if line.endswith(b"\r\n"):
            yield line[:-2], b"\r\n"
        elif line.endswith((b"\n", b"\r")):
            yield line[:-1], line[-1:]
        else:
            yield line, b""


def _validate_span(span: object, source: Path, line_number: int) -> dict[str, object]:
    if not isinstance(span, dict) or set(span) != _SPAN_KEYS:
        raise MigrationError(f"{source}:{line_number}: invalid context span shape")
    from_id = span["fromId"]
    members = span["memberIds"]
    summary = span["summary"]
    if (
        not isinstance(from_id, str)
        or not isinstance(members, list)
        or any(not isinstance(member, str) for member in members)
        or not isinstance(summary, str)
    ):
        raise MigrationError(f"{source}:{line_number}: invalid context span types")
    return span


def _transform_record(
    record: object, source: Path, line_number: int
) -> tuple[dict[str, object] | None, int]:
    if not isinstance(record, dict):
        return None, 0
    if record.get("type") != "custom" or record.get("customType") != "context-prune":
        return None, 0

    data = record.get("data")
    if not isinstance(data, dict):
        raise MigrationError(f"{source}:{line_number}: context-prune data must be an object")
    has_spans = "spans" in data
    has_pruned = "pruned" in data
    if not has_spans and not has_pruned:
        raise MigrationError(
            f"{source}:{line_number}: context-prune data needs spans or pruned"
        )

    spans: list[dict[str, object]] = []
    if has_spans:
        raw_spans = data["spans"]
        if not isinstance(raw_spans, list):
            raise MigrationError(f"{source}:{line_number}: spans must be an array")
        spans.extend(_validate_span(span, source, line_number) for span in raw_spans)

    legacy_ids: list[str] = []
    if has_pruned:
        raw_pruned = data["pruned"]
        if not isinstance(raw_pruned, list) or any(
            not isinstance(identifier, str) for identifier in raw_pruned
        ):
            raise MigrationError(f"{source}:{line_number}: pruned must be a string array")
        legacy_ids = raw_pruned
        spans.extend(
            {"fromId": identifier, "memberIds": [identifier], "summary": ""}
            for identifier in legacy_ids
        )

    new_data = dict(data)
    new_data["spans"] = spans
    new_data.pop("pruned", None)
    migrated = dict(record)
    migrated["customType"] = "infinite-context"
    migrated["data"] = new_data
    return migrated, len(legacy_ids)


def _serialize(record: dict[str, object], source: Path, line_number: int) -> bytes:
    try:
        return json.dumps(
            record,
            ensure_ascii=False,
            allow_nan=False,
            separators=(",", ":"),
        ).encode("utf-8")
    except (TypeError, ValueError, UnicodeEncodeError) as exc:
        raise MigrationError(f"{source}:{line_number}: cannot serialize migrated entry") from exc


def _fingerprint(source: Path) -> tuple[int, int, int, int]:
    info = source.stat()
    return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns)


def _regular_jsonl_files(root: Path) -> Iterator[Path]:
    if root.is_symlink():
        raise MigrationError(f"scan root is a symlink: {root}")
    if root.is_file():
        if root.name.endswith(".jsonl"):
            yield root
        return
    if not root.is_dir():
        raise MigrationError(f"scan root is not a directory: {root}")

    def onerror(exc: OSError) -> None:
        raise MigrationError(f"cannot scan {root}: {exc}") from exc

    for directory, directories, filenames in os.walk(
        root, topdown=True, followlinks=False, onerror=onerror
    ):
        directory_path = Path(directory)
        directories[:] = sorted(
            name
            for name in directories
            if not (directory_path / name).is_symlink()
        )
        for name in sorted(filenames):
            path = directory_path / name
            if name.endswith(".jsonl") and path.is_file() and not path.is_symlink():
                yield path


def _root_specs(roots: Sequence[str | os.PathLike[str]]) -> list[Path]:
    if not roots:
        raise MigrationError("at least one scan root is required")
    result: list[Path] = []
    seen: set[Path] = set()
    for value in roots:
        path = Path(value)
        if path.is_symlink():
            raise MigrationError(f"scan root is a symlink: {path}")
        try:
            resolved = path.resolve(strict=True)
        except OSError as exc:
            raise MigrationError(f"cannot access scan root {path}: {exc}") from exc
        if resolved in seen:
            raise MigrationError(f"duplicate scan root: {resolved}")
        seen.add(resolved)
        result.append(resolved)
    return result


def _scan(
    roots: Sequence[str | os.PathLike[str]], backup_dir: Path | None = None
) -> tuple[list[FilePlan], Counts, list[Path]]:
    root_paths = _root_specs(roots)
    counts = Counts()
    plans: list[FilePlan] = []
    seen_files: set[Path] = set()
    for root_index, root in enumerate(root_paths):
        for source in _regular_jsonl_files(root):
            source = source.resolve(strict=True)
            if source in seen_files:
                continue
            seen_files.add(source)
            relative = source.relative_to(root) if root.is_dir() else Path(source.name)
            raw = source.read_bytes()
            counts.scanned_files += 1
            migrated_parts: list[bytes] = []
            matches = legacy_ids = 0
            for line_number, (content, ending) in enumerate(_split_jsonl(raw), 1):
                counts.scanned_lines += 1
                record = _parse_line(content, source, line_number)
                migrated, old_ids = _transform_record(record, source, line_number)
                if migrated is None:
                    migrated_parts.append(content + ending)
                    continue
                matches += 1
                legacy_ids += old_ids
                migrated_parts.append(_serialize(migrated, source, line_number) + ending)
            counts.matching_entries += matches
            counts.legacy_ids += legacy_ids
            migrated_raw = b"".join(migrated_parts)
            if migrated_raw == raw:
                continue
            info = source.stat()
            plan = FilePlan(
                source=source,
                root_index=root_index,
                relative=relative,
                original=raw,
                migrated=migrated_raw,
                mode=stat.S_IMODE(info.st_mode),
                fingerprint=(info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns),
            )
            if backup_dir is not None:
                plan.backup = backup_dir / f"root-{root_index}" / relative
            plans.append(plan)
    counts.would_change_files = len(plans)
    return plans, counts, root_paths


def _is_inside(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def _nearest_existing(path: Path) -> Path:
    current = path
    while not os.path.lexists(current):
        if current == current.parent:
            return current
        current = current.parent
    return current


def _reject_symlink_components(path: Path) -> None:
    absolute = Path(os.path.abspath(path))
    current = Path(absolute.anchor)
    for component in absolute.parts[1:]:
        current /= component
        if os.path.lexists(current) and current.is_symlink():
            raise MigrationError("backup directory path must not contain symlinks")


def _validate_backup_dir(backup_dir: Path, roots: Sequence[Path], plans: Sequence[FilePlan]) -> Path:
    _reject_symlink_components(backup_dir)
    try:
        resolved = backup_dir.expanduser().resolve(strict=False)
    except OSError as exc:
        raise MigrationError(f"cannot resolve backup directory: {exc}") from exc
    if os.path.lexists(resolved) and resolved.is_symlink():
        raise MigrationError("backup directory must not be a symlink")
    if os.path.lexists(resolved) and not resolved.is_dir():
        raise MigrationError("backup directory is not a directory")
    if any(_is_inside(resolved, root) for root in roots):
        raise MigrationError("backup directory must be outside every scan root")

    writable_parent = _nearest_existing(resolved)
    if writable_parent.is_symlink() or not writable_parent.is_dir():
        raise MigrationError("backup directory parent is not a directory")
    if not os.access(writable_parent, os.W_OK | os.X_OK):
        raise MigrationError("backup directory parent is not writable")

    for plan in plans:
        target = resolved / f"root-{plan.root_index}" / plan.relative
        current = resolved
        for part in target.relative_to(resolved).parts[:-1]:
            current /= part
            if os.path.lexists(current):
                if current.is_symlink():
                    raise MigrationError("backup path contains a symlink")
                if not current.is_dir():
                    raise MigrationError("backup path parent is not a directory")
        if os.path.lexists(target):
            raise MigrationError(f"backup collision: {target}")
        writable_target_parent = _nearest_existing(target.parent)
        if (
            writable_target_parent.is_symlink()
            or not writable_target_parent.is_dir()
            or not os.access(writable_target_parent, os.W_OK | os.X_OK)
        ):
            raise MigrationError("backup path parent is not writable")
    return resolved


def detect_pi_writers(proc_root: str | os.PathLike[str] = "/proc") -> list[int]:
    """Best-effort /proc detection, returning only PIDs (never command lines)."""
    root = Path(proc_root)
    found: list[int] = []
    try:
        entries = sorted(root.iterdir(), key=lambda path: path.name)
    except OSError:
        return found
    for entry in entries:
        if not entry.name.isdigit() or not entry.is_dir():
            continue
        try:
            args = [part.decode("utf-8", "replace") for part in (entry / "cmdline").read_bytes().split(b"\0") if part]
        except OSError:
            continue
        if _looks_like_pi_writer(args):
            found.append(int(entry.name))
    return found


def _looks_like_pi_writer(args: Sequence[str]) -> bool:
    for arg in args:
        lower = arg.lower()
        name = Path(arg).name.lower()
        if name in {"pi", "pi-agent", "pi-coding-agent"} or "pi-coding-agent" in lower:
            return True
    return False


def _verify_unchanged(plan: FilePlan) -> None:
    try:
        current = plan.source.read_bytes()
        fingerprint = _fingerprint(plan.source)
    except OSError as exc:
        raise ApplyError(f"source changed or disappeared: {plan.source}") from exc
    if current != plan.original or fingerprint != plan.fingerprint:
        raise ApplyError(f"source changed during preflight: {plan.source}")


def _fsync_directory(directory: Path) -> None:
    try:
        fd = os.open(directory, os.O_RDONLY)
    except OSError:
        return
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def _create_backup(plan: FilePlan) -> None:
    assert plan.backup is not None
    target = plan.backup
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() or target.is_symlink():
        raise ApplyError(f"backup collision: {target}")
    fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, plan.mode)
    try:
        os.fchmod(fd, plan.mode)
        with os.fdopen(fd, "wb") as output:
            fd = -1
            output.write(plan.original)
            output.flush()
            os.fsync(output.fileno())
        _fsync_directory(target.parent)
    except Exception:
        if fd != -1:
            os.close(fd)
        try:
            target.unlink()
        except OSError:
            pass
        raise


def _atomic_write(path: Path, content: bytes, mode: int) -> None:
    fd, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "wb") as output:
            fd = -1
            output.write(content)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
        _fsync_directory(path.parent)
    except Exception:
        if fd != -1:
            os.close(fd)
        try:
            temporary.unlink()
        except OSError:
            pass
        raise


def _apply(plans: Sequence[FilePlan]) -> None:
    for plan in plans:
        _verify_unchanged(plan)

    replaced: list[FilePlan] = []
    try:
        for plan in plans:
            _verify_unchanged(plan)
            _create_backup(plan)
        for plan in plans:
            _verify_unchanged(plan)
            # Mark before replacement: an fsync error can happen after os.replace.
            replaced.append(plan)
            _atomic_write(plan.source, plan.migrated, plan.mode)
    except Exception as exc:
        rollback_errors: list[str] = []
        for plan in reversed(replaced):
            try:
                assert plan.backup is not None
                _atomic_write(plan.source, plan.backup.read_bytes(), plan.mode)
            except Exception:
                rollback_errors.append(str(plan.source))
        detail = f"apply failed: {exc}"
        if rollback_errors:
            detail += "; rollback failed for " + ", ".join(rollback_errors)
        raise ApplyError(detail) from exc


def _report(counts: Counts, apply: bool, emit: Callable[[str], None]) -> None:
    emit(f"mode: {'apply' if apply else 'dry-run'}")
    emit(f"scanned files: {counts.scanned_files}")
    emit(f"scanned lines: {counts.scanned_lines}")
    emit(f"matching entries: {counts.matching_entries}")
    emit(f"legacy IDs: {counts.legacy_ids}")
    emit(f"would-change files: {counts.would_change_files}")
    emit(f"changed files: {counts.changed_files}")
    emit(f"backups: {counts.backups}")


def migrate(
    roots: Sequence[str | os.PathLike[str]],
    *,
    apply: bool = False,
    backup_dir: str | os.PathLike[str] | None = None,
    process_detector: Callable[[], Sequence[int]] | None = None,
    emit: Callable[[str], None] = print,
) -> Counts:
    """Validate and optionally apply a migration, returning aggregate counts."""
    requested_backup = Path(backup_dir).expanduser() if backup_dir is not None else None
    plans, counts, root_paths = _scan(roots)
    if apply:
        if requested_backup is None:
            raise MigrationError("--backup-dir is required with --apply")
        backup_path = _validate_backup_dir(requested_backup, root_paths, plans)
        for plan in plans:
            plan.backup = backup_path / f"root-{plan.root_index}" / plan.relative
            if not os.access(plan.source.parent, os.W_OK | os.X_OK):
                raise MigrationError(f"source directory is not writable: {plan.source.parent}")
        detector = process_detector or detect_pi_writers
        if detector():
            raise MigrationError(
                "likely Pi writer detected; stop all Pi processes and retry (coordination is mandatory)"
            )
        _apply(plans)
        counts.changed_files = len(plans)
        counts.backups = len(plans)
    _report(counts, apply, emit)
    return counts


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="apply changes (default is dry-run)")
    parser.add_argument("--backup-dir", type=Path, help="backup directory (required with --apply)")
    parser.add_argument("roots", nargs="+", type=Path, help="session directory roots to scan")
    args = parser.parse_args(argv)
    try:
        migrate(
            args.roots,
            apply=args.apply,
            backup_dir=args.backup_dir,
        )
    except ApplyError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    except MigrationError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
