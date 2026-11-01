#!/usr/bin/env python3
"""sccache-token-guard: leak confirmation and pool pipe access on a fake server process."""
import importlib.machinery
import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest

SCRIPT = Path(__file__).parents[1] / "bin/sccache-token-guard"
loader = importlib.machinery.SourceFileLoader("sccache_token_guard", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
guard = importlib.util.module_from_spec(spec)
loader.exec_module(guard)


def run(samples, capacity=16):
    """Feed (time, pool) idle samples, or (time, None) for busy ones; return refill counts."""
    confirm, out = guard.Confirm(), []
    for now, pool in samples:
        if pool is None:
            confirm.reset()
        else:
            out.append(confirm.step(now, pool, capacity))
    return [n for n in out if n]


class ConfirmTest(unittest.TestCase):
    def test_persistent_shortfall_is_refilled_once(self):
        self.assertEqual(run([(t / 5, 10) for t in range(6)] + [(1.4, 16)]), [6])

    def test_brief_dip_uses_best_sample_in_window(self):
        self.assertEqual(run([(0, 15), (0.2, 16), (0.4, 15)]), [])
        self.assertEqual(run([(0, 9), (0.4, 10), (1.0, 9)]), [6])

    def test_busy_sample_restarts_confirmation(self):
        self.assertEqual(run([(0, 10), (0.8, None), (1.0, 10), (1.8, 10)]), [])

    def test_full_pool_needs_nothing(self):
        self.assertEqual(run([(t, 16) for t in range(5)]), [])


class PoolPipeTest(unittest.TestCase):
    def test_reads_and_refills_pipe_held_for_reading_and_writing(self):
        server = subprocess.Popen(
            [sys.executable, "-c", "import os, time; r, w = os.pipe(); os.write(w, b'|' * 4); "
             "print('ready', flush=True); time.sleep(30)"],
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, text=True)
        self.addCleanup(server.wait)
        self.addCleanup(server.kill)
        self.addCleanup(server.stdout.close)
        server.stdout.readline()
        paths = guard.pool_pipe(server.pid)  # its stdout pipe has only the write end there
        self.assertIsNotNone(paths)
        self.assertEqual(guard.available(paths[0]), 4)
        guard.refill(paths[1], 3)
        self.assertEqual(guard.available(paths[0]), 7)


if __name__ == "__main__":
    unittest.main()
