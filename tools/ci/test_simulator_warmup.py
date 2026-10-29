import contextlib
import ctypes
import hashlib
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

DEVICE = 'E952A9B0-CC78-435C-BF08-06AD47FE1076'
OTHER = 'E952A9B0-CC78-435C-BF08-06AD47FE1077'


class WarmupTests(unittest.TestCase):
    def execute(self, failure=None, fail_once=False, diagnostic_returncode=0, preflight_timeout=False):
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
                code = diagnostic_returncode if kwargs.get('check') is False else 0
                return SimpleNamespace(returncode=code, stdout=warm.BUNDLE + ': 123\n')
            out = root / 'diagnostics'
            with patch.object(warm.subprocess, 'run', side_effect=native), patch.object(warm.time, 'sleep'), \
                 patch.object(warm.os, 'kill') as alive, patch.object(warm, 'wait_for_stage_rest', return_value={'synthetic': True}), \
                 patch.object(warm, 'prepare_stage_rest_container', return_value=lambda: 'synthetic',
                              side_effect=subprocess.TimeoutExpired(['xcrun', 'simctl', 'get_app_container'], 5)
                              if preflight_timeout else None), \
                 patch.dict(os.environ, {'GITHUB_SHA': 'source'}):
                if failure or preflight_timeout:
                    with self.assertRaises(RuntimeError):
                        warm.warmup(app, DEVICE, ['ar'], 'ar_SA', out)
                else:
                    warm.warmup(app, DEVICE, ['ar'], 'ar_SA', out)
            return json.loads((out / 'status.json').read_text()), calls

    def test_prelaunch_container_timeout_retains_failure_without_claiming_cleanup(self):
        status, calls = self.execute(preflight_timeout=True)
        self.assertFalse(status['passed'])
        self.assertEqual(status['launch_attempts'], 0)
        self.assertTrue(status['cleanup_not_required'])
        self.assertNotIn('cleanup_confirmed', status)
        self.assertIn('get_app_container', status['error'])
        self.assertIn('5 seconds', status['error'])
        self.assertFalse(any(c[0][:3] in (['xcrun', 'simctl', 'launch'], ['xcrun', 'simctl', 'terminate'])
                             for c in calls))

    def test_one_scoped_locale_specific_launch_then_terminate_with_binary_identity(self):
        status, calls = self.execute()
        self.assertTrue(status['passed'])
        self.assertTrue(status['diagnostic_only'])
        self.assertEqual(status['source_sha'], 'source')
        self.assertEqual(len(status['executable_sha256']), 64)
        self.assertEqual([c[0][2] for c in calls], ['install', 'privacy', 'launch', 'terminate'])
        launch, args = calls[2]
        self.assertEqual(launch[-4:], ['-AppleLanguages', '(ar)', '-AppleLocale', 'ar_SA'])
        self.assertRegex(args['env']['SIMCTL_CHILD_TIMBRE_TEST_STORAGE_ID'], r'^[a-f0-9-]{36}$')
        self.assertEqual(args['env']['SIMCTL_CHILD_TIMBRE_TEST_STORAGE_ID'], status['automation_storage_id'])
        self.assertTrue(all(0 < kwargs['timeout'] <= 120 for _, kwargs in calls))

    def test_resting_warmup_retains_demo_pitch_and_records_command_timestamps(self):
        status, calls = self.execute()
        env = calls[2][1]['env']
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
        self.assertEqual([c[0][2] for c in calls], ['install', 'privacy', 'launch', 'get_app_container', '--probe-installed-app', 'spawn', 'io', '--last', 'list', 'terminate'])
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

    def test_nonzero_diagnostics_are_recorded_not_success_or_cleanup_failure(self):
        status, _ = self.execute('launch', diagnostic_returncode=7)
        self.assertFalse(status['passed'])
        self.assertTrue(status['cleanup_confirmed'])
        self.assertEqual(len(status['diagnostics']), 4)
        for event in status['diagnostics']:
            self.assertEqual(event['returncode'], 7)
            self.assertLessEqual(event['started_at'], event['finished_at'])
            self.assertLessEqual(event['timeout_seconds'], 30)

    def test_cleanup_timeout_has_post_cleanup_evidence_without_second_launch(self):
        status, calls = self.execute('terminate')
        self.assertFalse(status['passed'])
        self.assertFalse(status['cleanup_confirmed'])
        self.assertEqual(status['diagnostics'][-1]['filename'], 'simulator-after-cleanup.log')
        self.assertEqual(sum(command[2] == 'launch' for command, _ in calls), 1)

    def test_launch_services_and_scoped_host_logs_are_not_filtered_out(self):
        status, _ = self.execute('launch')
        simulator = next(event for event in status['diagnostics'] if event['filename'] == 'simulator.log')
        for process in ('runningboardd', 'lsd', 'installd', 'launchd', 'ReportCrash'):
            self.assertIn(f'process == "{process}"', simulator['command'][-1])
        host = next(event for event in status['diagnostics'] if event['filename'] == 'host-launch.log')
        self.assertIn(DEVICE, host['command'][-1])
        self.assertIn(warm.BUNDLE, host['command'][-1])

    def test_device_alias_is_rejected_before_any_native_command(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(warm.subprocess, 'run') as native:
            with self.assertRaises(ValueError):
                warm.warmup(Path('unused'), 'booted', ['en'], 'en_US', Path(directory) / 'out')
            native.assert_not_called()

    def test_diagnostics_reserve_time_for_termination_within_original_total_budget(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = root / 'Timbre.app'
            app.mkdir()
            (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': warm.BUNDLE, 'CFBundleExecutable': 'Timbre'}))
            (app / 'Timbre').write_bytes(b'fixture')
            now = [0.0]
            calls = []
            def native(command, **kwargs):
                calls.append((command, kwargs))
                if command[2] == 'install':
                    now[0] += 119
                elif command[2] == 'launch':
                    now[0] += kwargs['timeout']
                    raise subprocess.TimeoutExpired(command, kwargs['timeout'])
                elif command[2] != 'terminate':
                    now[0] += kwargs['timeout']
                return SimpleNamespace(returncode=0, stdout='')
            with patch.object(warm.time, 'monotonic', side_effect=lambda: now[0]), \
                 patch.object(warm.subprocess, 'run', side_effect=native), \
                 patch.object(warm, 'prepare_stage_rest_container', return_value=lambda: 'synthetic'):
                with self.assertRaises(RuntimeError):
                    warm.warmup(app, DEVICE, ['en'], 'en_US', root / 'out')
            self.assertEqual(calls[-1][0][2], 'terminate')
            self.assertEqual(calls[-1][1]['timeout'], 30)
            status = json.loads((root / 'out/status.json').read_text())
            self.assertFalse(status['passed'])
            self.assertTrue(status['cleanup_confirmed'])
            self.assertTrue(any('reserved for cleanup' in event.get('error', '') for event in status['diagnostics']))

    def test_expired_total_deadline_never_starts_more_commands(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = root / 'Timbre.app'
            app.mkdir()
            (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': warm.BUNDLE, 'CFBundleExecutable': 'Timbre'}))
            (app / 'Timbre').write_bytes(b'fixture')
            times = iter([0])
            with patch.object(warm.time, 'monotonic', side_effect=lambda: next(times, 301)), patch.object(warm.subprocess, 'run') as native:
                with self.assertRaises(RuntimeError):
                    warm.warmup(app, DEVICE, ['ar'], 'ar_SA', root / 'warmup')
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
            child = calls[2][1]['env']
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


class DiagnosticIdentityTests(unittest.TestCase):
    def execute(self, executable='timbre', debug=b'actual app implementation', failure='launch'):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory) / 'User-facing Timbre.app'
            app.mkdir()
            info = plistlib.dumps({'CFBundleIdentifier': warm.BUNDLE, 'CFBundleExecutable': executable})
            (app / 'Info.plist').write_bytes(info)
            (app / executable).write_bytes(b'launcher stub')
            if debug is not None:
                (app / (executable + '.debug.dylib')).write_bytes(debug)
            calls = []

            def native(command, **kwargs):
                calls.append((command, kwargs))
                if command[:3] == ['xcrun', 'simctl', failure]:
                    raise subprocess.TimeoutExpired(command, kwargs['timeout'])
                return SimpleNamespace(returncode=0, stdout=warm.BUNDLE + ': 123\n')

            out = Path(directory) / 'out'
            with patch.object(warm.subprocess, 'run', side_effect=native), patch.object(warm.os, 'kill'), \
                 patch.object(warm.time, 'sleep'), patch.object(warm, 'wait_for_stage_rest', return_value={'synthetic': True}), \
                 patch.object(warm, 'prepare_stage_rest_container', return_value=lambda: 'synthetic'):
                if failure:
                    with self.assertRaises(RuntimeError):
                        warm.warmup(app, DEVICE, ['en'], 'en_US', out)
                else:
                    warm.warmup(app, DEVICE, ['en'], 'en_US', out)
            return json.loads((out / 'status.json').read_text()), calls, info

    def test_actual_bundle_executable_not_display_name_selects_process(self):
        status, _, info = self.execute()
        self.assertEqual(status['executable'], 'timbre')
        self.assertEqual(status['bundle_id'], warm.BUNDLE)
        self.assertEqual(status['info_plist_sha256'], hashlib.sha256(info).hexdigest())
        predicate = next(x for x in status['diagnostics'] if x['filename'] == 'simulator.log')['command'][-1]
        self.assertIn('process == "timbre"', predicate)
        self.assertNotIn('process == "Timbre"', predicate)

    def test_predicate_escapes_executable_as_string_not_predicate_syntax(self):
        predicate = warm.simulator_predicate('A" OR TRUEPREDICATE OR "B')
        self.assertTrue(predicate.startswith('process == "A\\" OR TRUEPREDICATE OR \\"B" OR '))

    def test_debug_app_implementation_hash_is_distinct_from_launcher(self):
        status, _, _ = self.execute()
        self.assertEqual(status['executable_sha256'], hashlib.sha256(b'launcher stub').hexdigest())
        self.assertEqual(status['debug_dylib_sha256'], hashlib.sha256(b'actual app implementation').hexdigest())
        self.assertNotEqual(status['executable_sha256'], status['debug_dylib_sha256'])

    def test_no_debug_dylib_is_valid_for_nonstub_build(self):
        status, _, _ = self.execute(debug=None, failure=None)
        self.assertTrue(status['passed'])
        self.assertNotIn('debug_dylib_sha256', status)

    def test_all_log_snapshots_include_available_info_and_debug(self):
        status, _, _ = self.execute(failure='terminate')
        logs = [x for x in status['diagnostics'] if x['filename'] in
                ('simulator.log', 'host-launch.log', 'simulator-after-cleanup.log')]
        self.assertEqual(len(logs), 3)
        for event in logs:
            self.assertIn('--info', event['command'])
            self.assertIn('--debug', event['command'])
            self.assertLessEqual(event['timeout_seconds'], 30)

    def test_simulator_services_and_bundle_events_not_omitted(self):
        predicate = warm.simulator_predicate('timbre')
        for process in ('tccd', 'mediaserverd', 'audiomxd', 'coreaudiod', 'storekitd', 'appstored'):
            self.assertIn('process == ' + json.dumps(process), predicate)
        self.assertIn('subsystem == ' + json.dumps(warm.BUNDLE), predicate)
        self.assertIn('eventMessage CONTAINS[c] ' + json.dumps(warm.BUNDLE), predicate)

    def test_failures_single_launch_cleanup_and_budget_remain_unchanged(self):
        status, calls, _ = self.execute()
        self.assertFalse(status['passed'])
        self.assertTrue(status['diagnostic_only'])
        self.assertEqual(status['launch_attempts'], 1)
        self.assertEqual(status['total_budget_seconds'], 300)
        self.assertTrue(status['cleanup_confirmed'])
        self.assertEqual(sum(command[:3] == ['xcrun', 'simctl', 'launch'] for command, _ in calls), 1)
        self.assertIn('timed out after 120', status['error'])
        self.assertEqual([x[0][2] for x in calls], ['install', 'privacy', 'launch', 'get_app_container', '--probe-installed-app', 'spawn', 'io', '--last', 'list', 'terminate'])


class ProcessProbeTests(unittest.TestCase):
    def fixture(self, root, device=DEVICE):
        app = root / 'CoreSimulator/Devices' / device / 'data/Containers/Bundle/Application/14F316F3-60DD-4F54-B941-3211AFCBCA3B/Timbre.app'
        app.mkdir(parents=True)
        (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': warm.BUNDLE, 'CFBundleExecutable': 'Timbre'}))
        (app / 'Timbre').write_bytes(b'fixture')
        return app

    def execute(self, matches=(321,), container_device=DEVICE, grant_code=0,
                grant_timeout=False, probe_timeout=False, malformed=None):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            app = self.fixture(root)
            installed = app if container_device == DEVICE else self.fixture(root, container_device)
            out = root / 'out'
            calls = []

            def native(command, **kwargs):
                calls.append((command, kwargs))
                if command[:3] == ['xcrun', 'simctl', 'privacy']:
                    if grant_timeout:
                        raise subprocess.TimeoutExpired(command, kwargs['timeout'])
                    return SimpleNamespace(returncode=grant_code, stdout='', stderr='')
                if command[:3] == ['xcrun', 'simctl', 'launch']:
                    raise subprocess.TimeoutExpired(command, kwargs['timeout'])
                if command[:3] == ['xcrun', 'simctl', 'get_app_container']:
                    if probe_timeout:
                        raise subprocess.TimeoutExpired(command, kwargs['timeout'])
                    return SimpleNamespace(returncode=0, stdout=str(installed) + '\n', stderr='')
                if '--probe-installed-app' in command:
                    try:
                        expected = warm.installed_executable(*command[3:])
                    except (ValueError, OSError):
                        return SimpleNamespace(returncode=1, stdout='{}', stderr='')
                    payload = {'matching_pids': list(matches), 'expected_executable': str(expected),
                               'unreadable_path_count': 0, 'scope': 'current-user-kernel-executable-path',
                               'observation_only': True}
                    return SimpleNamespace(returncode=0, stdout=malformed if malformed is not None else json.dumps(payload), stderr='')
                return SimpleNamespace(returncode=0, stdout='', stderr='')

            with patch.object(warm.subprocess, 'run', side_effect=native), \
                 patch.object(warm, 'prepare_stage_rest_container', return_value=lambda: 'synthetic'), patch.object(warm.time, 'sleep'):
                with self.assertRaises(RuntimeError):
                    warm.warmup(app, DEVICE, ['en'], 'en_US', out)
            return json.loads((out / 'status.json').read_text()), calls

    def test_unique_exact_process_is_observed_without_racy_pid_sampling(self):
        status, calls = self.execute()
        observation = status['unknown_launch_pid_probe']
        self.assertEqual(observation['observed_pid'], 321)
        self.assertEqual(observation['sample_attempts'], 0)
        self.assertEqual(observation['sample_skipped'], 'identity_not_atomically_bound')
        self.assertEqual(observation['status'], 'one_exact_process_observed')
        self.assertFalse(any(c[0][0] == '/usr/bin/sample' for c in calls))
        helper = next(c for c in calls if '--probe-installed-app' in c[0])
        self.assertLessEqual(helper[1]['timeout'], 8)
        self.assertFalse(status['passed'])
        self.assertEqual(status['launch_attempts'], 1)
        self.assertTrue(status['cleanup_confirmed'])
        self.assertNotIn('pid', status, 'A diagnostic lookup must not certify the launch returned a PID')

    def test_absence_is_inconclusive_and_never_sampled(self):
        status, calls = self.execute(matches=())
        self.assertEqual(status['unknown_launch_pid_probe']['status'], 'no_exact_process_observed')
        self.assertTrue(status['unknown_launch_pid_probe']['absence_is_not_proof_of_no_launch'])
        self.assertFalse(any(c[0][0] == '/usr/bin/sample' for c in calls))

    def test_ambiguity_is_inconclusive_and_never_sampled(self):
        status, calls = self.execute(matches=(321, 322))
        self.assertEqual(status['unknown_launch_pid_probe']['status'], 'ambiguous_exact_processes')
        self.assertFalse(any(c[0][0] == '/usr/bin/sample' for c in calls))

    def test_wrong_device_container_never_enumerates_or_samples(self):
        status, calls = self.execute(container_device=OTHER)
        self.assertIn('Process probe command failed', status['unknown_launch_pid_probe']['error'])
        self.assertFalse(any(c[0][0] == '/usr/bin/sample' for c in calls))

    def test_probe_timeout_remains_inconclusive_and_cleanup_runs(self):
        status, calls = self.execute(probe_timeout=True)
        self.assertIn('timed out', status['unknown_launch_pid_probe']['error'])
        self.assertTrue(status['cleanup_confirmed'])
        self.assertFalse(any(c[0][0] == '/usr/bin/sample' for c in calls))

    def test_malformed_probe_results_are_inconclusive_and_keep_original_failure(self):
        for payload in ('null', '[]', '{"matching_pids": null}', '{"matching_pids": ["321"]}', 'garbage'):
            with self.subTest(payload=payload):
                status, calls = self.execute(malformed=payload)
                self.assertEqual(status['unknown_launch_pid_probe']['status'], 'inconclusive')
                self.assertIn('error', status['unknown_launch_pid_probe'])
                self.assertIn('timed out after 120', status['error'])
                self.assertTrue(status['cleanup_confirmed'])
                self.assertFalse(any(c[0][0] == '/usr/bin/sample' for c in calls))

    def test_post_install_grant_is_recorded_without_claiming_runtime_permission(self):
        status, _ = self.execute()
        commands = status['commands']
        self.assertEqual([c['command'][2] for c in commands[:3]], ['install', 'privacy', 'launch'])
        self.assertEqual(commands[1]['command'][3:], [DEVICE, 'grant', 'microphone', warm.BUNDLE])
        self.assertEqual(commands[1]['returncode'], 0)
        self.assertTrue(status['microphone_grant_command_succeeded'])
        self.assertEqual(status['microphone_runtime_permission'], 'not_observed')

    def test_grant_failure_stops_before_launch_and_is_not_suppressed(self):
        status, calls = self.execute(grant_code=7)
        self.assertFalse(status['microphone_grant_command_succeeded'])
        self.assertEqual(status['launch_attempts'], 0)
        self.assertTrue(status['cleanup_not_required'])
        self.assertNotIn('cleanup_confirmed', status)
        self.assertFalse(any(c[0][:3] == ['xcrun', 'simctl', 'launch'] for c in calls))
        self.assertEqual(status['commands'][1]['returncode'], 7)

    def test_grant_timeout_is_recorded_and_never_starts_launch(self):
        status, _ = self.execute(grant_timeout=True)
        self.assertEqual(status['launch_attempts'], 0)
        self.assertTrue(status['commands'][1]['timed_out'])

    def test_near_exhausted_budget_skips_probe_and_preserves_cleanup_reserve(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = self.fixture(root)
            now = [0.0]
            calls = []

            def native(command, **kwargs):
                calls.append((command, kwargs))
                if command[:3] == ['xcrun', 'simctl', 'launch']:
                    now[0] = 270.0
                    raise subprocess.TimeoutExpired(command, kwargs['timeout'])
                return SimpleNamespace(returncode=0, stdout='', stderr='')

            with patch.object(warm.time, 'monotonic', side_effect=lambda: now[0]), \
                 patch.object(warm.subprocess, 'run', side_effect=native), \
                 patch.object(warm, 'prepare_stage_rest_container', return_value=lambda: 'synthetic'):
                with self.assertRaises(RuntimeError):
                    warm.warmup(app, DEVICE, ['en'], 'en_US', root / 'out')
            status = json.loads((root / 'out/status.json').read_text())
            self.assertIn('reserved for cleanup', status['unknown_launch_pid_probe']['error'])
            self.assertFalse(any(c[0][:3] == ['xcrun', 'simctl', 'get_app_container'] for c in calls))
            self.assertEqual(calls[-1][0][:3], ['xcrun', 'simctl', 'terminate'])
            self.assertEqual(calls[-1][1]['timeout'], 30)
            self.assertTrue(status['cleanup_confirmed'])

    def test_helper_filesystem_failure_cannot_escape_bounded_subprocess(self):
        source = Path(warm.__file__).read_text()
        body = source.split('    def locate_unknown_pid():', 1)[1].split('    try:\n        if not languages', 1)[0]
        self.assertNotIn('installed_executable(', body)
        self.assertIn('probe_query(command, limit=8)', body)
        self.assertIn("expected = installed_executable(*sys.argv[2:])", source)

    def test_identity_mismatches_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            app = self.fixture(Path(directory))
            digest = hashlib.sha256(b'fixture').hexdigest()
            # macOS temporary roots can be spelled /var while resolving to /private/var.
            self.assertEqual(warm.installed_executable(str(app), DEVICE, 'Timbre', digest),
                             (app / 'Timbre').resolve(strict=True))
            for path, device, executable, code_hash in [
                (str(app), OTHER, 'Timbre', digest),
                (str(app), DEVICE, 'other', digest),
                (str(app), DEVICE, 'Timbre', '0' * 64),
                ('/System/Applications/Timbre.app', DEVICE, 'Timbre', digest),
            ]:
                with self.assertRaises((ValueError, OSError)):
                    warm.installed_executable(path, device, executable, code_hash)

    def test_same_filesystem_ancestor_alias_returns_canonical_executable(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve(strict=True)
            canonical = root / 'canonical'
            app = self.fixture(canonical)
            alias = root / 'alias'
            alias.symlink_to(canonical, target_is_directory=True)
            aliased_app = alias / app.relative_to(canonical)
            self.assertNotEqual(aliased_app, app)
            self.assertTrue(aliased_app.samefile(app))
            self.assertEqual(warm.installed_executable(str(aliased_app), DEVICE, 'Timbre',
                                                     hashlib.sha256(b'fixture').hexdigest()), app / 'Timbre')

    def test_device_directory_alias_cannot_disguise_another_device(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve(strict=True)
            app = self.fixture(root, OTHER)
            devices = root / 'CoreSimulator/Devices'
            (devices / DEVICE).symlink_to(devices / OTHER, target_is_directory=True)
            aliased_app = devices / DEVICE / app.relative_to(devices / OTHER)
            self.assertTrue(aliased_app.samefile(app))
            with self.assertRaises(ValueError):
                warm.installed_executable(str(aliased_app), DEVICE, 'Timbre', hashlib.sha256(b'fixture').hexdigest())

    def test_invalid_and_duplicate_candidates_are_never_accepted(self):
        for matches in ((True,), (1,), ('321',), (321, 321)):
            with self.subTest(matches=matches):
                status, _ = self.execute(matches=matches)
                self.assertIn('Malformed scoped process observation', status['unknown_launch_pid_probe']['error'])
                self.assertNotIn('observed_pid', status['unknown_launch_pid_probe'])

    def test_malformed_installed_plist_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            app = self.fixture(Path(directory))
            (app / 'Info.plist').write_bytes(plistlib.dumps(['not', 'a', 'dictionary']))
            with self.assertRaises(ValueError):
                warm.installed_executable(str(app), DEVICE, 'Timbre', hashlib.sha256(b'fixture').hexdigest())

    def test_installed_executable_symlink_is_never_followed(self):
        with tempfile.TemporaryDirectory() as directory:
            app = self.fixture(Path(directory))
            (app / 'Timbre').unlink()
            external = Path(directory) / 'other'
            external.write_bytes(b'fixture')
            (app / 'Timbre').symlink_to(external)
            with self.assertRaises(ValueError):
                warm.installed_executable(str(app), DEVICE, 'Timbre', hashlib.sha256(b'fixture').hexdigest())

    def test_kernel_path_not_process_name_or_arguments_controls_match(self):
        expected = Path('/selected/device/Timbre.app/Timbre')
        queried = []
        class Lookup:
            def __call__(self, pid, buffer, size):
                queried.append(pid)
                buffer.value = {101: str(expected).encode(), 103: b'/other/device/Timbre.app/Timbre'}[pid]
                return len(buffer.value)
        library = SimpleNamespace(proc_pidpath=Lookup())
        with patch.object(warm.sys, 'platform', 'darwin'), patch.object(warm.os, 'getuid', return_value=501), \
             patch.object(warm.os, 'geteuid', return_value=501), patch.object(ctypes, 'CDLL', return_value=library), \
             patch.object(warm.subprocess, 'run', return_value=SimpleNamespace(returncode=0, stdout='101 501\n102 0\n103 501\n')) as ps:
            self.assertEqual(warm.kernel_process_matches(expected)['matching_pids'], [101])
            self.assertEqual(queried, [101, 103])
            self.assertEqual(ps.call_args.args[0], ['/bin/ps', '-U', '501', '-o', 'pid=,uid='])
            self.assertNotIn('comm', ' '.join(ps.call_args.args[0]))
            self.assertNotIn('command', ' '.join(ps.call_args.args[0]))


if __name__ == '__main__':
    unittest.main()
