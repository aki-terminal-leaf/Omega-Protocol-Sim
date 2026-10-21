import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

GUARD = Path(__file__).resolve().parents[1] / 'work_guard.py'
spec = importlib.util.spec_from_file_location('guard', GUARD)
guard = importlib.util.module_from_spec(spec); spec.loader.exec_module(guard)


class GuardTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.state = Path(self.temp.name) / 'state.json'

    def call(self, *args):
        return subprocess.run([sys.executable, str(GUARD), '--state', str(self.state), *args],
                              text=True, capture_output=True, timeout=8)

    def begin(self, *args):
        self.assertEqual(self.call('begin', 'test-stage', *args).returncode, 0)

    def test_budgets_and_unchanged_output_do_not_extend_stage(self):
        s = {'status': 'running', 'deadline': 100, 'last_progress': 50, 'stall_seconds': 20}
        self.assertEqual(guard.assess(dict(s), 70)['reason'], 'no_new_evidence')
        self.assertEqual(guard.assess(dict(s, last_progress=99), 100)['reason'], 'stage_budget_exhausted')
        self.assertEqual(guard.assess(dict(s), 69)['status'], 'running')
        self.assertNotEqual(self.call('begin', 'test', '--budget', '1501').returncode, 0)

    def test_three_identical_failures_block_then_require_changed_approach(self):
        self.begin()
        for _ in range(3):
            self.assertNotEqual(self.call('run', 'failure', '--', sys.executable, '-c', 'raise SystemExit(7)').returncode, 0)
        self.assertEqual(json.loads(self.state.read_text())['reason'], 'same_failure_three_times')
        self.assertNotEqual(self.call('run', 'no-fourth', '--', sys.executable, '-c', 'print(1)').returncode, 0)
        self.assertNotEqual(self.call('begin', 'retry').returncode, 0)
        self.assertEqual(self.call('begin', 'changed', '--reason', 'fixed source, reduced reproducer').returncode, 0)

    def test_godot_error_cannot_pass_on_exit_zero(self):
        self.begin()
        self.assertNotEqual(self.call('run', 'parse', '--', sys.executable, '-c', 'print("SCRIPT ERROR: test")').returncode, 0)
        self.assertFalse(json.loads(self.state.read_text())['last_command']['ok'])

    def test_new_proof_only_and_terminal_state(self):
        self.begin(); proof = Path(self.temp.name) / 'proof.log'; proof.write_text('verified result')
        self.assertEqual(self.call('progress', str(proof)).returncode, 0)
        self.assertNotEqual(self.call('progress', str(proof)).returncode, 0)
        self.assertEqual(self.call('finish').returncode, 0)
        self.assertEqual(json.loads(self.call('check').stdout)['status'], 'done')
        self.assertNotEqual(self.call('run', 'late', '--', sys.executable, '-c', 'print(1)').returncode, 0)

    def test_timeout_terminates_owned_group_and_blocks(self):
        self.begin()
        result = self.call('run', 'slow', '--timeout', '1', '--', sys.executable, '-c', 'import time; time.sleep(20)')
        self.assertNotEqual(result.returncode, 0)
        state = json.loads(self.state.read_text())
        self.assertEqual(state['reason'], 'command_timeout')
        self.assertTrue(state['last_command']['timeout'])

    def test_observer_persists_stall_and_does_not_restart(self):
        self.begin(); s = json.loads(self.state.read_text()); s['last_progress'] = time.time() - 1000
        self.state.write_text(json.dumps(s))
        first = self.call('check'); second = self.call('check')
        self.assertEqual(json.loads(first.stdout)['reason'], 'no_new_evidence')
        self.assertEqual(json.loads(second.stdout)['status'], 'blocked')

    def test_interrupted_wrapper_stops_its_child_and_blocks(self):
        self.begin()
        code = 'import os,time; print(os.getpid(), flush=True); time.sleep(20)'
        process = subprocess.Popen([sys.executable, str(GUARD), '--state', str(self.state),
                                    'run', 'interrupted', '--', sys.executable, '-c', code],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.addCleanup(lambda: process.kill() if process.poll() is None else None)
        deadline = time.monotonic() + 3
        logs = self.state.parent / 'top-work-guard-logs'
        log = None
        while time.monotonic() < deadline:
            candidates = list(logs.glob('interrupted-*.log'))
            if candidates and candidates[0].read_text().strip():
                log = candidates[0]; break
            time.sleep(.02)
        self.assertIsNotNone(log)
        pid = int(log.read_text().strip())
        process.terminate(); process.wait(timeout=4)
        self.assertEqual(json.loads(self.state.read_text())['reason'], 'wrapper_interrupted')
        self.assertFalse(Path('/proc/' + str(pid)).exists())

    def test_launch_failure_blocks_without_waiting_for_stall(self):
        self.begin()
        self.assertNotEqual(self.call('run', 'missing', '--', '/missing/top-test-executable').returncode, 0)
        self.assertEqual(json.loads(self.state.read_text())['reason'], 'command_launch_failed')

    def test_overlapping_stage_rejected(self):
        self.begin(); self.assertNotEqual(self.call('begin', 'overlap').returncode, 0)


if __name__ == '__main__':
    unittest.main()
