import contextlib
import io
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import simulator_warmup as warm


class WarmupTests(unittest.TestCase):
    def execute(self, failure=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = root / 'Timbre.app'
            app.mkdir()
            (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': warm.BUNDLE, 'CFBundleExecutable': 'Timbre'}))
            (app / 'Timbre').write_bytes(b'unit-test executable fixture, not native evidence')
            calls = []
            def native(command, **kwargs):
                calls.append((command, kwargs))
                if command[2] == failure:
                    raise subprocess.TimeoutExpired(command, kwargs['timeout'])
                return SimpleNamespace(returncode=0, stdout=warm.BUNDLE + ': 123\n')
            out = root / 'diagnostics'
            with patch.object(warm.subprocess, 'run', side_effect=native), patch.object(warm.time, 'sleep'), \
                 patch.object(warm.os, 'kill') as alive, patch.dict(os.environ, {'GITHUB_SHA': 'source'}):
                if failure:
                    with self.assertRaises(RuntimeError):
                        warm.warmup(app, 'device', ['ar'], 'ar_SA', out)
                else:
                    warm.warmup(app, 'device', ['ar'], 'ar_SA', out)
            return json.loads((out / 'status.json').read_text()), calls

    def test_one_scoped_locale_specific_launch_then_terminate_with_binary_identity(self):
        status, calls = self.execute()
        self.assertTrue(status['passed'])
        self.assertTrue(status['diagnostic_only'])
        self.assertEqual(status['source_sha'], 'source')
        self.assertEqual(len(status['executable_sha256']), 64)
        self.assertEqual([c[0][2] for c in calls], ['install', 'launch', 'terminate'])
        launch, args = calls[1]
        self.assertEqual(launch[-4:], ['-AppleLanguages', '(ar)', '-AppleLocale', 'ar_SA'])
        self.assertRegex(args['env']['SIMCTL_CHILD_TIMBRE_TEST_STORAGE_ID'], r'^[a-f0-9-]{36}$')
        self.assertEqual(args['env']['SIMCTL_CHILD_TIMBRE_TEST_STORAGE_ID'], status['automation_storage_id'])
        self.assertTrue(all(0 < kwargs['timeout'] <= 120 for _, kwargs in calls))

    def test_launch_timeout_stays_failed_collects_separate_diagnostics_and_terminates(self):
        status, calls = self.execute('launch')
        self.assertFalse(status['passed'])
        self.assertEqual(status['launch_attempts'], 1)
        self.assertEqual([c[0][2] for c in calls], ['install', 'launch', 'spawn', 'io', 'terminate'])
        self.assertTrue(any('diagnostic-only.png' in str(c[0]) for c in calls))

    def test_install_timeout_never_launches(self):
        status, calls = self.execute('install')
        self.assertFalse(status['passed'])
        self.assertEqual(status['launch_attempts'], 0)
        self.assertNotIn('launch', [c[0][2] for c in calls])

    def test_each_warmup_uses_fresh_automation_storage(self):
        first, _ = self.execute()
        second, _ = self.execute()
        self.assertNotEqual(first['automation_storage_id'], second['automation_storage_id'])

    def test_expired_total_deadline_never_starts_more_commands(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = root / 'Timbre.app'
            app.mkdir()
            (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': warm.BUNDLE, 'CFBundleExecutable': 'Timbre'}))
            (app / 'Timbre').write_bytes(b'fixture')
            times = iter([0, 301, 301, 301])
            with patch.object(warm.time, 'monotonic', side_effect=lambda: next(times)), patch.object(warm.subprocess, 'run') as native:
                with self.assertRaises(RuntimeError):
                    warm.warmup(app, 'device', ['ar'], 'ar_SA', root / 'warmup')
                native.assert_not_called()
            status = json.loads((root / 'warmup/status.json').read_text())
            self.assertFalse(status['passed'])
            self.assertIn('300-second budget', status['error'])

    def test_source_contracts_preserve_two_test_attempts_and_unmodified_language_proof(self):
        root = Path(__file__).resolve().parents[2]
        source = (root / 'tools/marketing/run_listing_assets.py').read_text()
        body = source.split('def test_attempts(', 1)[1].split('def validate_preview_take', 1)[0]
        self.assertIn('for attempt in (1, 2):', body)
        self.assertIn("env['TEST_RUNNER_TIMBRE_UI_APPLE_LANGUAGES'].split(',')", body)
        self.assertLess(body.index('warmup('), body.index('code = run(test_command'))
        self.assertIn("'test-without-building'", source)
        proof = (root / 'ios/TimbreUITests/ListingCaptureEvidenceUITests.swift').read_text()
        self.assertIn('XCTAssertEqual(button.label, expected', proof)
        self.assertIn('XCTAssertTrue(button.isHittable', proof)
        self.assertLess(proof.index('XCTAssertEqual(button.label, expected'), proof.index('CaptureLocalization.recordVerified'))


if __name__ == '__main__':
    unittest.main()
