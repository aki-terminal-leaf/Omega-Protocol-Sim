"""Recovery ledger regressions using only isolated POSIX CLI state files."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

if os.name != 'posix':
    raise unittest.SkipTest('work_guard CLI requires POSIX fcntl and process groups')

GUARD = Path(__file__).resolve().parents[1] / 'work_guard.py'


class GuardResumeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.state = Path(self.temp.name) / 'state.json'

    def call(self, *args):
        return subprocess.run(
            [sys.executable, str(GUARD), '--state', str(self.state), *args],
            text=True, capture_output=True, timeout=10)

    def read(self):
        return json.loads(self.state.read_text())

    def begin(self):
        result = self.call('begin', 'test-stage')
        self.assertEqual(result.returncode, 0, result.stderr)

    def resume(self, reason='fixed source and reduced reproducer'):
        result = self.call('begin', 'test-stage', '--reason', reason)
        self.assertEqual(result.returncode, 0, result.stderr)
        return self.read()

    def block_by_stall(self):
        state = self.read()
        state['last_progress'] = time.time() - 1000
        self.state.write_text(json.dumps(state))
        result = self.call('check')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.read()['reason'], 'no_new_evidence')

    def fail(self):
        result = self.call('run', 'failure', '--', sys.executable,
                           '-c', 'raise SystemExit(7)')
        self.assertNotEqual(result.returncode, 0)

    def test_fourth_identical_failure_blocks_across_explicit_resume(self):
        self.begin()
        for _ in range(3):
            self.fail()
        blocked = self.read()
        self.assertEqual(blocked['reason'], 'same_failure_three_times')
        self.assertEqual(list(blocked['failure_counts'].values()), [3])
        resumed = self.resume()
        self.assertEqual(resumed['failure_counts'], blocked['failure_counts'])
        self.assertEqual(resumed['last_command'], blocked['last_command'])
        self.fail()
        state = self.read()
        self.assertEqual(state['status'], 'blocked')
        self.assertEqual(state['reason'], 'same_failure_three_times')
        self.assertEqual(list(state['failure_counts'].values()), [4])
        self.assertEqual(set(state['failure_counts']), set(blocked['failure_counts']))

    def test_unchanged_proof_replay_does_not_renew_progress_after_resume(self):
        self.begin()
        proof = Path(self.temp.name) / 'proof.txt'
        proof.write_text('actual changed source or result')
        self.assertEqual(self.call('progress', str(proof)).returncode, 0)
        digests = self.read()['proof_hashes']
        self.block_by_stall()
        resumed = self.resume()
        self.assertEqual(resumed['proof_hashes'], digests)
        copy = Path(self.temp.name) / 'renamed-proof.txt'
        copy.write_bytes(proof.read_bytes())
        for path in (proof, copy):
            self.assertNotEqual(self.call('progress', str(path)).returncode, 0)
            state = self.read()
            self.assertEqual(state['last_progress'], resumed['last_progress'])
            self.assertEqual(state['proof_hashes'], digests)
        proof.write_text('newly verified result')
        self.assertEqual(self.call('progress', str(proof)).returncode, 0)
        self.assertEqual(len(self.read()['proof_hashes']), 2)

    def test_invalid_resume_keeps_blocked_ledger_byte_for_byte(self):
        self.begin()
        self.fail()
        proof = Path(self.temp.name) / 'proof.txt'
        proof.write_text('verified evidence')
        self.assertEqual(self.call('progress', str(proof)).returncode, 0)
        self.block_by_stall()
        original = self.state.read_bytes()
        attempts = [
            ('begin', 'test-stage'),
            ('begin', 'test-stage', '--reason', ' \t\n '),
            ('begin', 'changed', '--reason', 'fixed source'),
            ('begin', 'test-stage ', '--reason', 'fixed source'),
        ]
        for args in attempts:
            with self.subTest(args=args):
                self.assertNotEqual(self.call(*args).returncode, 0)
                self.assertEqual(self.state.read_bytes(), original)

    def test_genuinely_new_stage_after_finish_starts_fresh(self):
        self.begin()
        self.fail()
        proof = Path(self.temp.name) / 'proof.txt'
        proof.write_text('stage result')
        self.assertEqual(self.call('progress', str(proof)).returncode, 0)
        self.block_by_stall()
        self.resume()
        self.assertEqual(self.call('finish').returncode, 0)
        self.assertEqual(self.call('begin', 'new-stage').returncode, 0)
        state = self.read()
        self.assertEqual(state['stage'], 'new-stage')
        self.assertEqual(state['failure_counts'], {})
        self.assertEqual(state['proof_hashes'], [])
        self.assertFalse(state.get('recovery_history'))
        self.assertNotIn('reason', state)

    def test_resume_clears_stale_block_reason_before_command_timeout(self):
        self.begin()
        self.block_by_stall()
        state = self.resume()
        self.assertNotIn('reason', state)
        self.assertEqual(state['status'], 'running')
        self.assertGreater(state['deadline'], time.time())
        self.assertLessEqual(state['deadline'] - state['started'], 1500)
        self.assertLessEqual(state['stall_seconds'], 900)
        result = self.call('run', 'slow', '--timeout', '1', '--',
                           sys.executable, '-c', 'import time; time.sleep(20)')
        self.assertNotEqual(result.returncode, 0)
        state = self.read()
        self.assertEqual(state['reason'], 'command_timeout')
        self.assertTrue(state['last_command']['timeout'])

    def test_recovery_history_retains_prior_reason_with_bounded_entries(self):
        self.begin()
        reasons = ['attempt-%02d: ' % i + 'x' * 1100 for i in range(12)]
        for reason in reasons:
            self.block_by_stall()
            self.resume(reason)
        state = self.read()
        self.assertEqual(state['resume_reason'], reasons[-1])
        history = state['recovery_history']
        self.assertEqual(len(history), 10)
        for index, entry in enumerate(history, start=2):
            self.assertEqual(entry['blocked_reason'], 'no_new_evidence')
            self.assertEqual(entry['resume_reason'], reasons[index][:1000])
            self.assertEqual(entry['prior_resume_reason'], reasons[index - 1][:1000])
            self.assertIsInstance(entry['resumed'], (int, float))

    def test_legacy_blocked_state_without_new_fields_can_resume(self):
        legacy = {'stage': 'test-stage', 'status': 'blocked',
                  'reason': 'stage_budget_exhausted', 'started': 1,
                  'deadline': 2, 'last_progress': 1, 'stall_seconds': 900,
                  'review_context': {'seed': 'keep-me'}}
        self.state.write_text(json.dumps(legacy))
        state = self.resume()
        self.assertEqual(state['review_context'], legacy['review_context'])
        self.assertEqual(state['failure_counts'], {})
        self.assertEqual(state['proof_hashes'], [])
        self.assertEqual(state['recovery_history'][0]['blocked_reason'], legacy['reason'])
        self.assertEqual(state['recovery_history'][0]['prior_resume_reason'], '')
        self.assertNotIn('reason', state)
        proof = Path(self.temp.name) / 'legacy-proof.txt'
        proof.write_text('legacy recovery result')
        self.assertEqual(self.call('progress', str(proof)).returncode, 0)
        self.assertEqual(self.call('run', 'success', '--', sys.executable,
                                   '-c', 'print("verified")').returncode, 0)

    def test_expired_attempt_is_blocked_and_native_checks_never_restart(self):
        self.begin()
        self.block_by_stall()
        for field, reason in [('deadline', 'stage_budget_exhausted'),
                              ('last_progress', 'no_new_evidence')]:
            with self.subTest(field=field):
                resumed = self.resume('fixed the stalled source, new bounded attempt')
                expired = dict(resumed)
                expired[field] = time.time() - 1000
                self.state.write_text(json.dumps(expired))
                first = self.call('check')
                self.assertEqual(first.returncode, 0, first.stderr)
                blocked = self.read()
                self.assertEqual(blocked['status'], 'blocked')
                self.assertEqual(blocked['reason'], reason)
                for _ in range(2):
                    check = self.call('check')
                    self.assertEqual(check.returncode, 0, check.stderr)
                    self.assertEqual(self.read(), blocked)
                self.assertNotEqual(self.call('run', 'no-restart', '--',
                                             sys.executable, '-c', 'print(1)').returncode, 0)
                self.assertEqual(self.read(), blocked)


if __name__ == '__main__':
    unittest.main()
