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
    def execute(self, failure=None, fail_once=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = root / 'Timbre.app'
            app.mkdir()
            (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': warm.BUNDLE, 'CFBundleExecutable': 'Timbre'}))
            (app / 'Timbre').write_bytes(b'unit-test executable fixture, not native evidence')
            calls = []
            def native(command, **kwargs):
                calls.append((command, kwargs))
                if command[2] == failure and (not fail_once or sum(c[0][2] == failure for c in calls) == 1):
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

    def test_resting_warmup_retains_demo_pitch_and_records_command_timestamps(self):
        status, calls = self.execute()
        env = calls[1][1]['env']
        self.assertEqual(env['SIMCTL_CHILD_TIMBRE_STAGE_REST'], '1')
        self.assertEqual(env['SIMCTL_CHILD_TIMBRE_DEMO_PITCH'], '1')
        self.assertIsNone(calls[0][1]['env'])
        for command in status['commands']:
            self.assertLessEqual(command['started_at'], command['finished_at'])
            self.assertEqual(command['returncode'], 0)

    def test_terminate_timeout_stays_failed_and_records_owned_pid(self):
        status, calls = self.execute('terminate')
        self.assertFalse(status['passed'])
        self.assertTrue(status['owned_pid_present'])
        self.assertIn('owned_pid_observed_at', status)
        self.assertEqual(status['launch_attempts'], 1)
        self.assertEqual(sum(c[0][2] == 'launch' for c in calls), 1)
        self.assertTrue(all(c[1]['timeout'] <= 30 for c in calls if c[0][2] == 'terminate'))
        self.assertTrue(any(c[0][:3] == ['/bin/ps', '-p', '123'] for c in calls))

    def test_successful_cleanup_does_not_hide_original_terminate_timeout(self):
        status, calls = self.execute('terminate', fail_once=True)
        self.assertFalse(status['passed'])
        self.assertNotIn('cleanup_error', status)
        self.assertTrue(any(c.get('timed_out') for c in status['commands']))
        self.assertEqual(status['commands'][-1]['returncode'], 0)

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

    def test_first_session_still_owns_fresh_onboarding_storage(self):
        root = Path(__file__).resolve().parents[2]
        first = (root / 'ios/TimbreUITests/FirstSessionUITests.swift').read_text()
        setup = first.split('override func setUpWithError()', 1)[1].split('override func tearDown', 1)[0]
        self.assertIn('app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString', setup)
        self.assertNotIn('TIMBRE_SKIP_ONBOARDING', setup)
        self.assertIn('storeKit.resetToDefaultState()', setup)
        self.assertIn('storeKit.clearTransactions()', setup)
        self.assertIn('testDeferredQuestionsPersistOnlyForTheInstallationThatSkippedThem', first)
        self.assertIn('testJustTuneReachesAListeningTuner', first)
        storage = (root / 'ios/Timbre/Support/TestSupport.swift').read_text()
        self.assertIn('.appendingPathComponent("TimbreUITests", isDirectory: true).appendingPathComponent(identifier', storage)
        deferral = (root / 'ios/Timbre/Onboarding/OnboardingDeferral.swift').read_text()
        self.assertIn('storageKey = Self.key + "." + identifier.uuidString', deferral)
        app = (root / 'ios/Timbre/TimbreApp.swift').read_text()
        self.assertIn('TestSupport.storageRoot ?? LocalStore.defaultDirectory', app)

    def test_priming_child_flags_do_not_leak_into_runner_environment(self):
        with patch.dict(os.environ, {}, clear=True):
            _, calls = self.execute()
            self.assertNotIn('SIMCTL_CHILD_TIMBRE_SKIP_ONBOARDING', os.environ)
            self.assertNotIn('SIMCTL_CHILD_TIMBRE_TEST_STORAGE_ID', os.environ)
            child = calls[1][1]['env']
            self.assertEqual(child['SIMCTL_CHILD_TIMBRE_SKIP_ONBOARDING'], '1')
            self.assertIn('SIMCTL_CHILD_TIMBRE_TEST_STORAGE_ID', child)

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
