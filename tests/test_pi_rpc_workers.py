#!/usr/bin/env python3
"""No provider calls: exercise the supervisor against a small fake RPC process."""
import importlib.machinery
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest


SCRIPT = Path(__file__).parents[1] / "bin/pi-rpc-workers"
loader = importlib.machinery.SourceFileLoader("pi_rpc_workers", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
workers = importlib.util.module_from_spec(spec)
loader.exec_module(workers)

FAKE = r'''
import json, sys, time

def emit(event):
    data = (json.dumps(event, ensure_ascii=False) + "\n").encode()
    # Exercise a Unicode LF-only record and arbitrary pipe chunk boundaries.
    for part in (data[:7], data[7:]):
        sys.stdout.buffer.write(part)
        sys.stdout.buffer.flush()

if len(sys.argv) > 1 and sys.argv[1] == "no_read":
    time.sleep(60)
if len(sys.argv) > 1 and sys.argv[1] == "bad_json":
    sys.stdout.write("invalid JSON\n")
    sys.stdout.flush()
    time.sleep(60)
if len(sys.argv) > 1 and sys.argv[1] == "dialog":
    emit({"type": "extension_ui_request", "method": "confirm", "id": "dialog", "title": "Unexpected consent"})
    time.sleep(60)
for line in sys.stdin.buffer:
    request = json.loads(line)
    kind = request["type"]
    emit({"type": "fake_request", "command": request})
    if kind == "no_reply":
        continue
    if kind == "fail":
        emit({"type": "response", "id": request["id"], "success": False, "error": "rejected"})
        continue
    data = None
    if kind == "get_state":
        data = {"model": {"provider": "openai-codex", "id": "gpt-5.6-sol"}, "thinkingLevel": "high", "sessionFile": "fake.jsonl"}
    elif kind == "get_commands":
        data = {"commands": [] if "no_actor" in sys.argv else [{"name": "subagents-pause"}]}
    emit({"type": "response", "id": request["id"], "success": True, "data": data})
    if kind == "prompt" and not request["message"].startswith("/"):
        emit({"type": "agent_start"})
        emit({"type": "agent_end", "willRetry": True})
        time.sleep(0.15)
        emit({"type": "message_end", "message": {"role": "assistant", "content": [{"type": "text", "text": "ready\u2028é"}], "stopReason": "stop"}})
        emit({"type": "agent_settled"})
'''


class WorkerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.spec = {"name": "map", "cwd": str(self.root), "provider": "openai-codex", "model": "gpt-5.6-sol", "thinking": "high"}
        self.worker = None

    def tearDown(self):
        if self.worker:
            self.worker.close()
        self.tmp.cleanup()

    def launch(self, *args):
        self.worker = workers.Worker(self.spec, self.root, [sys.executable, "-u", "-c", FAKE, *args])
        return self.worker

    def test_readiness_correlated_responses_and_real_settlement(self):
        worker = self.launch()
        worker.verify()
        self.assertEqual(worker.snapshot()["phase"], "ready")
        worker.rpc(workers.delivery("hello", "follow_up"))
        early = worker.wait(0, 0.03)
        self.assertTrue(early["wait_timed_out"])
        settled = worker.wait(0, 3)
        self.assertFalse(settled["wait_timed_out"])
        self.assertEqual(settled["last_text"], "ready\u2028é")
        self.assertEqual(settled["stop_reason"], "stop")
        self.assertEqual(settled["settled"], 1)
        self.assertIn(b"agent_end", (worker.root / "events.jsonl").read_bytes())

    def test_mismatched_model_fails_readiness(self):
        worker = self.launch()
        self.spec["model"] = "not-sol"
        with self.assertRaisesRegex(RuntimeError, "model mismatch"):
            worker.verify()

    def test_rpc_failure_and_timeout_are_not_retried(self):
        worker = self.launch()
        with self.assertRaisesRegex(RuntimeError, "rejected"):
            worker.rpc({"type": "fail"})
        with self.assertRaisesRegex(TimeoutError, "NOT retried"):
            worker.rpc({"type": "no_reply"}, timeout=0.05)
        self.assertEqual(worker.pending, {})
        self.assertIsNotNone(worker.rpc({"type": "get_state"}))

    def test_startup_dialog_fails_without_waiting_for_stdin(self):
        worker = self.launch("dialog")
        start = time.monotonic()
        with self.assertRaises((RuntimeError, BrokenPipeError)):
            worker.verify()
        self.assertLess(time.monotonic() - start, 5)
        self.assertIn("ui_cancelled", worker.snapshot())

    def test_abort_attempts_all_steps_and_preserves_worker(self):
        worker = self.launch()
        worker.verify()
        worker.abort()
        self.assertIsNone(worker.proc.poll())
        commands = []
        def fail_first(command, timeout):
            commands.append(command)
            if command["type"] == "clear_queue":
                raise TimeoutError("test")
        worker.rpc = fail_first
        with self.assertRaisesRegex(RuntimeError, "partial abort"):
            worker.abort()
        self.assertEqual([c["type"] for c in commands], ["clear_queue", "prompt", "abort_bash", "abort"])

    def test_close_reaps_owned_process_and_retains_logs(self):
        worker = self.launch()
        worker.verify()
        worker.close()
        self.assertIsNotNone(worker.proc.poll())
        self.assertTrue((worker.root / "events.jsonl").exists())
        self.assertFalse(worker.reader.is_alive())

    def test_unread_pipe_times_out_and_stops_owned_worker(self):
        worker = self.launch("no_read")
        start = time.monotonic()
        with self.assertRaisesRegex(TimeoutError, "pipe write timed out"):
            worker.rpc({"type": "prompt", "message": "x" * 200_000}, timeout=0.1)
        self.assertLess(time.monotonic() - start, 5)
        self.assertIsNotNone(worker.proc.poll())

    def test_malformed_output_does_not_leave_unsupervised_process(self):
        worker = self.launch("bad_json")
        state = worker.wait(0, 3)
        self.assertIn("RPC reader failed", state["error"])
        worker.proc.wait(timeout=3)
        with self.assertRaises(RuntimeError):
            worker.rpc({"type": "get_state"})

    def test_older_settlement_does_not_complete_an_active_run(self):
        worker = self.launch()
        worker.handle({"type": "agent_settled"})
        worker.handle({"type": "agent_start"})
        self.assertTrue(worker.wait(0, 0.02)["wait_timed_out"])
        worker.handle({"type": "agent_settled"})
        self.assertFalse(worker.wait(0, 0)["wait_timed_out"])

    def test_missing_actor_cleanup_never_sends_model_prompt(self):
        worker = self.launch("no_actor")
        with self.assertRaisesRegex(RuntimeError, "actor-subagents"):
            worker.verify()
        worker.close()
        events = [json.loads(line) for line in (worker.root / "events.jsonl").read_bytes().split(b"\n") if line]
        commands = [e["command"]["type"] for e in events if e["type"] == "fake_request"]
        self.assertNotIn("prompt", commands)
        self.assertIn("abort", commands)

    def test_startup_signal_stays_atomic_even_for_huge_error(self):
        for packet in (workers.startup_packet(), workers.startup_packet("é" * 20_000)):
            self.assertLess(len(packet), 4096)
            self.assertTrue(packet.endswith(b"\n"))
            json.loads(packet)
        self.assertNotIn("result", json.loads(workers.startup_packet()))

    def test_manifest_requires_clean_exact_branch_and_worktree(self):
        subprocess.run(["git", "init", "-q", "-b", "task", str(self.root / "repo")], check=True)
        repo = self.root / "repo"
        policy = self.root / "policy.txt"
        policy.write_text("Safety policy")
        manifest = self.root / "workers.json"
        entry = dict(self.spec, cwd=str(repo), branch="task", policy=str(policy), brief=str(policy))
        manifest.write_text(json.dumps({"workers": [entry]}))
        self.assertEqual(workers.load_manifest(manifest)["workers"][0]["name"], "map")
        (repo / "unexpected").write_text("untracked")
        with self.assertRaisesRegex(ValueError, "dirty"):
            workers.load_manifest(manifest)


if __name__ == "__main__":
    unittest.main()
