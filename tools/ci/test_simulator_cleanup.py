import json
import os
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import simulator_cleanup as cleanup

DEVICE = 'E952A9B0-CC78-435C-BF08-06AD47FE1076'
ENV = {'DEVICE_ID': DEVICE, 'GITHUB_ACTIONS': 'true', 'RUNNER_ENVIRONMENT': 'github-hosted',
       'GITHUB_SHA': 'a' * 40, 'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '1', 'GITHUB_JOB': 'tour'}
RECEIPT = {'device': DEVICE, 'diagnostic_only': True, 'source_sha': 'a' * 40,
           'run_id': '123', 'run_attempt': '1', 'job': 'tour', 'runner_environment': 'github-hosted',
           'passed': False, 'launch_attempts': 1, 'cleanup_confirmed': False, 'cleanup_error': 'timed out'}


class CleanupTests(unittest.TestCase):
    def execute(self, *, changes=None, environment=None, failure=None, nonzero=None,
                invalid=False, device=DEVICE, raw_json=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            receipt = {**RECEIPT, **(changes or {})}
            status = root / 'warmup.json'
            raw = (json.dumps(receipt) if raw_json is None else raw_json).encode()
            status.write_bytes(raw)
            calls = []
            def native(command, **kwargs):
                calls.append((command, kwargs))
                if command[2] == failure:
                    raise subprocess.TimeoutExpired(command, kwargs['timeout'])
                return SimpleNamespace(returncode=7 if command[2] == nonzero else 0)
            with patch.dict(os.environ, {**ENV, **(environment or {})}, clear=True), \
                 patch.object(cleanup.subprocess, 'run', side_effect=native):
                if failure or nonzero or invalid:
                    with self.assertRaises(RuntimeError):
                        cleanup.isolate(device, status, root / 'out')
                else:
                    cleanup.isolate(device, status, root / 'out')
            self.assertEqual(status.read_bytes(), raw, 'Original failure receipt must never be modified')
            result = json.loads((root / 'out/status.json').read_text())
            self.assertTrue(result['warmup_failure_retained'])
            self.assertNotIn('passed', result)
            return result, calls

    def test_one_device_only_one_reboot_no_launch_or_erase(self):
        result, calls = self.execute()
        self.assertEqual([command[2] for command, _ in calls], ['shutdown', 'bootstatus', 'status_bar'])
        self.assertTrue(all(command[3] == DEVICE for command, _ in calls))
        self.assertTrue(result['reset_completed'])
        self.assertTrue(result['status_bar_restored'])
        self.assertEqual(result['reset_attempts'], 1)
        self.assertEqual([kwargs['timeout'] for _, kwargs in calls], [30, 90, 15])

    def test_timeout_stops_without_retry_and_retains_failed_cleanup(self):
        for failure, expected in [('shutdown', 1), ('bootstatus', 2), ('status_bar', 3)]:
            with self.subTest(failure=failure):
                result, calls = self.execute(failure=failure)
                self.assertEqual(len(calls), expected)
                self.assertTrue(result['commands'][-1]['timed_out'])
                self.assertIn('error', result)

    def test_nonzero_command_stops_without_retry_or_later_commands(self):
        for command, expected in [('shutdown', 1), ('bootstatus', 2), ('status_bar', 3)]:
            with self.subTest(command=command):
                result, calls = self.execute(nonzero=command)
                self.assertEqual(len(calls), expected)
                self.assertEqual(result['commands'][-1]['returncode'], 7)
                self.assertNotIn('timed_out', result['commands'][-1])
                self.assertIn('error', result)
                self.assertEqual(result['reset_completed'], command == 'status_bar')

    def test_confirmed_cleanup_and_success_never_reboot(self):
        for changes in ({'passed': True}, {'cleanup_confirmed': True}):
            result, calls = self.execute(changes=changes)
            self.assertEqual(calls, [])
            self.assertIn('skipped', result)

    def test_unmatched_source_run_attempt_job_or_device_never_mutates(self):
        for field in ('source_sha', 'run_id', 'run_attempt', 'job', 'device', 'runner_environment'):
            with self.subTest(field=field):
                _, calls = self.execute(changes={field: 'other'}, invalid=True)
                self.assertEqual(calls, [])

    def test_alias_and_non_hosted_environment_never_mutate(self):
        for device, environment in [('booted', {}), ('all', {}), (DEVICE, {'RUNNER_ENVIRONMENT': 'self-hosted'}),
                                    (DEVICE, {'GITHUB_ACTIONS': 'false'}), (DEVICE, {'DEVICE_ID': 'other'})]:
            _, calls = self.execute(device=device, environment=environment, invalid=True)
            self.assertEqual(calls, [])

    def test_incomplete_failure_receipt_never_mutates(self):
        for changes in ({'launch_attempts': 0}, {'launch_attempts': True}, {'cleanup_error': ''},
                        {'cleanup_confirmed': None}, {'passed': None}):
            _, calls = self.execute(changes=changes, invalid=True)
            self.assertEqual(calls, [])

    def test_malformed_receipt_shape_records_failure_without_native_commands(self):
        for raw in ('null', '[]', '42', '"receipt"', 'true', '{invalid'):
            with self.subTest(raw=raw):
                result, calls = self.execute(raw_json=raw, invalid=True)
                self.assertEqual(calls, [])
                self.assertIn('error', result)
                self.assertEqual(result['reset_attempts'], 0)

    def test_each_command_uses_remaining_total_budget(self):
        # Deadlines count elapsed time between commands, not just their own limits.
        with patch.object(cleanup.time, 'monotonic', side_effect=[0, 20, 100, 149]):
            result, calls = self.execute()
        self.assertTrue(result['reset_completed'])
        self.assertEqual([kwargs['timeout'] for _, kwargs in calls], [30, 50, 1])

    def test_expired_total_deadline_starts_no_further_command(self):
        for times, expected in (([0, 151], 0), ([0, 10, 151], 1)):
            with self.subTest(times=times), patch.object(cleanup.time, 'monotonic', side_effect=times):
                result, calls = self.execute(invalid=True)
            self.assertEqual(len(calls), expected)
            self.assertFalse(result['reset_completed'])
            self.assertIn('150-second budget expired', result['error'])


if __name__ == '__main__':
    unittest.main()
