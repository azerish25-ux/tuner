"""Portable fail-closed runner tests; these do not execute native UI tests."""
import contextlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import tunecheck_layout as runner

DEVICE = '01234567-89AB-CDEF-0123-456789ABCDEF'
RUNTIME = 'com.apple.CoreSimulator.SimRuntime.iOS-18-0'


def device_records():
    return {'devices': {RUNTIME: [dict(udid=DEVICE, name='iPhone SE (3rd generation)',
                                      deviceTypeIdentifier=runner.DEVICE_TYPE, isAvailable=True)]}}


def runtime_records():
    return {'runtimes': [dict(identifier=RUNTIME, version='18.0', isAvailable=True)]}


def event(method, state, cls=runner.CLASS):
    return f"Test Case '-[TimbreUITests.{cls} {method}]' {state} (0.100 seconds).\n"


def passing_log():
    return ''.join(event(method, 'started') + event(method, 'passed') for method in runner.METHODS)


class TuneCheckLayoutRunnerTests(unittest.TestCase):
    def test_exactly_eight_source_methods(self):
        source = '\n'.join(f'    func {method}() throws {{}}' for method in runner.METHODS)
        runner.validate_source(source)
        for bad in [source + '\nfunc testExtra() {}', source.replace(runner.METHODS[0], 'testWrong'),
                    source + '\nfunc ' + runner.METHODS[0] + '() {}']:
            with self.assertRaises(ValueError):
                runner.validate_source(bad)

    def test_only_explicit_compact_type_and_available_ios18_or_later(self):
        result = runner.validate_device(device_records(), runtime_records(), DEVICE.lower())
        self.assertEqual(result['udid'], DEVICE)
        self.assertEqual(result['expected_portrait_points'], [375, 667])
        renamed = device_records()
        renamed['devices'][RUNTIME][0]['name'] = 'User-renamed compact simulator'
        runner.validate_device(renamed, runtime_records(), DEVICE)
        for key, value in [('deviceTypeIdentifier', 'com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro'),
                           ('deviceTypeIdentifier', None), ('isAvailable', False)]:
            bad = device_records()
            bad['devices'][RUNTIME][0][key] = value
            with self.assertRaises(ValueError):
                runner.validate_device(bad, runtime_records(), DEVICE)

    def test_bad_missing_or_ambiguous_uuid_cannot_fall_back(self):
        for device_id in ['booted', 'iPhone SE (3rd generation)', DEVICE[:-1] + '0']:
            with self.assertRaises(ValueError):
                runner.validate_device(device_records(), runtime_records(), device_id)
        devices = device_records()
        devices['devices'][RUNTIME] *= 2
        with self.assertRaises(ValueError):
            runner.validate_device(devices, runtime_records(), DEVICE)

    def test_old_unavailable_non_ios_or_inconsistent_runtime_rejected(self):
        for identifier, version, available in [
            ('com.apple.CoreSimulator.SimRuntime.iOS-17-5', '17.5', True),
            ('com.apple.CoreSimulator.SimRuntime.tvOS-18-0', '18.0', True),
            (RUNTIME, '17.0', True), (RUNTIME, '18.0', False), (RUNTIME, '', True),
        ]:
            device = device_records()['devices'][RUNTIME]
            with self.assertRaises(ValueError):
                runner.validate_device({'devices': {identifier: device}},
                                       {'runtimes': [dict(identifier=identifier, version=version,
                                                          isAvailable=available)]}, DEVICE)
        newer = 'com.apple.CoreSimulator.SimRuntime.iOS-26-2'
        runner.validate_device({'devices': {newer: device_records()['devices'][RUNTIME]}},
                               {'runtimes': [dict(identifier=newer, version='26.2', isAvailable=True)]}, DEVICE)

    def test_command_selects_only_class_once_on_supplied_device(self):
        command = runner.test_command(DEVICE, Path('/tmp/result.xcresult'))
        self.assertEqual(command[:2], ['xcodebuild', 'test-without-building'])
        self.assertEqual([arg for arg in command if arg.startswith('-only-testing:')],
                         ['-only-testing:TimbreUITests/TuneCheckLayoutUITests'])
        self.assertEqual(command[command.index('-destination') + 1], f'platform=iOS Simulator,id={DEVICE}')
        for forbidden in ['-test-iterations', '-skip-testing:', '-retry-tests-on-failure', '-run-tests-until-failure']:
            self.assertFalse(any(arg.startswith(forbidden) for arg in command))

    def test_all_eight_passes_and_zero_exit_required(self):
        self.assertTrue(runner.evaluate_tests(0, passing_log())['passed'])
        for code in [1, 65, 124, -9]:
            self.assertFalse(runner.evaluate_tests(code, passing_log())['passed'])
        self.assertFalse(runner.evaluate_tests(0, '')['passed'])

    def test_missing_skipped_failed_duplicate_or_extra_case_is_sticky(self):
        method = runner.METHODS[0]
        good = passing_log()
        for bad in [good.replace(event(method, 'passed'), ''),
                    good.replace(event(method, 'passed'), event(method, 'skipped')),
                    good.replace(event(method, 'passed'), event(method, 'failed')),
                    good + event(method, 'passed'), good + event(method, 'started') + event(method, 'passed'),
                    event(method, 'failed') + good, good + event('testExtra', 'passed'),
                    good + event(method, 'passed', cls='AnotherUITest'),
                    good.replace(event(method, 'started') + event(method, 'passed'),
                                 event(method, 'passed') + event(method, 'started'))]:
            with self.subTest(log=bad[-150:]):
                self.assertFalse(runner.evaluate_tests(0, bad)['passed'])

    def test_error_or_skip_summary_cannot_be_hidden_by_passing_terminals(self):
        for marker in ['** TEST FAILED **', '** TEST EXECUTE FAILED **', 'Testing failed:',
                       'error: -[TimbreUITests.TuneCheckLayoutUITests testEnglishPortraitLarge] : failed',
                       'XCTAssertEqual failed', 'failed - missing capture', '1 test skipped']:
            self.assertFalse(runner.evaluate_tests(0, passing_log() + marker)['passed'])
        self.assertTrue(runner.evaluate_tests(0, passing_log() + '0 tests skipped\nTap skip button')['passed'])

    def test_original_export_inventory_keeps_bytes_and_requires_attachments(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            with self.assertRaises(ValueError):
                runner.export_inventory(path)
            (path / 'manifest.json').write_text('[]')
            with self.assertRaises(ValueError):
                runner.export_inventory(path)
            (path / 'native.png').write_bytes(b'original native bytes')
            before = {file.name: file.read_bytes() for file in path.iterdir()}
            inventory = runner.export_inventory(path)
            self.assertEqual({item['path'] for item in inventory}, set(before))
            self.assertEqual({file.name: file.read_bytes() for file in path.iterdir()}, before)
            self.assertTrue(all(len(item['sha256']) == 64 for item in inventory))

    def test_every_method_requires_all_eight_phases_png_hierarchy_and_geometry(self):
        self.assertEqual(runner.PHASES, ('arrival', 'clear-title', 'clear-instructions', 'clear-rail',
                                        'clear-note', 'clear-hint', 'clear-fretboard', 'skip-activated'))
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            manifest = []
            for index, method in enumerate(runner.METHODS):
                sample = ('en' if 'English' in method else 'ar') + '-' + (
                    'landscape' if 'Landscape' in method else 'portrait') + '-' + ('AX5' if 'AX5' in method else 'Large')
                attachments = []
                for phase in runner.PHASES:
                    prefix = f'tunecheck-compact-{sample}-{phase}'
                    for suffix, role in [('.png', ''), ('.txt', '-hierarchy'), ('.json', '-geometry')]:
                        filename = f'{index}-{phase}{suffix}'
                        content = json.dumps(dict(sample=sample, phase=phase)) if suffix == '.json' else 'original'
                        (directory / filename).write_text(content)
                        attachments.append(dict(exportedFileName=filename, deviceId=DEVICE,
                                                suggestedHumanReadableName=prefix + role + '_0_export' + suffix))
                manifest.append(dict(testIdentifier=f'{runner.CLASS}/{method}()', attachments=attachments))
            (directory / 'manifest.json').write_text(json.dumps(manifest))
            self.assertEqual(runner.validate_export_coverage(directory, DEVICE), [])
            manifest[0]['attachments'][0]['deviceId'] = DEVICE[:-1] + '0'
            (directory / 'manifest.json').write_text(json.dumps(manifest))
            self.assertTrue(runner.validate_export_coverage(directory, DEVICE))
            manifest[0]['attachments'][0]['deviceId'] = DEVICE
            (directory / 'manifest.json').write_text(json.dumps(manifest))
            (directory / '0-clear-note.json').unlink()
            failures = runner.validate_export_coverage(directory, DEVICE)
            self.assertTrue(failures)
            self.assertTrue(any('testEnglishPortraitLarge/clear-note: missing original geometry' in item
                                for item in failures))

    def test_mocked_run_exports_failed_attempt_once_without_retry(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root / 'ios/TimbreUITests/TuneCheckLayoutUITests.swift'
            source.parent.mkdir(parents=True)
            source.write_text('\n'.join(f'func {method}() {{}}' for method in runner.METHODS))
            output = root / 'evidence'
            commands = []

            def execute(command, log, repo, timeout):
                commands.append(command)
                if command[:4] == ['xcrun', 'simctl', 'list', 'devices']:
                    log.write_text(json.dumps(device_records()))
                elif command[:4] == ['xcrun', 'simctl', 'list', 'runtimes']:
                    log.write_text(json.dumps(runtime_records()))
                elif command[0] == 'xcodebuild':
                    Path(command[command.index('-resultBundlePath') + 1]).mkdir()
                    log.write_text(passing_log().replace(event(runner.METHODS[0], 'passed'),
                                                       event(runner.METHODS[0], 'failed')))
                    return 65
                else:
                    log.write_text('Exported original attachments\n')
                    attachments = Path(command[command.index('--output-path') + 1])
                    attachments.mkdir()
                    (attachments / 'manifest.json').write_text('[]')
                    (attachments / 'native.png').write_bytes(b'original failure screenshot')
                return 0

            with patch.object(runner, 'logged_command', side_effect=execute), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(runner.run(root, output, DEVICE), 1)
            receipt = json.loads((output / 'status.json').read_text())
            self.assertFalse(receipt['passed'])
            self.assertEqual(receipt['attempts'], 1)
            self.assertEqual(len([command for command in commands if command[0] == 'xcodebuild']), 1)
            self.assertEqual(receipt['export_exit'], 0)
            self.assertTrue((output / 'TuneCheckLayout.xcresult').is_dir())
            self.assertEqual((output / 'attachments/native.png').read_bytes(), b'original failure screenshot')
            with self.assertRaises(FileExistsError):
                runner.run(root, output, DEVICE)

    def test_wrong_device_stops_before_any_xcodebuild_or_device_creation(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root / 'ios/TimbreUITests/TuneCheckLayoutUITests.swift'
            source.parent.mkdir(parents=True)
            source.write_text('\n'.join(f'func {method}() {{}}' for method in runner.METHODS))
            commands = []

            def execute(command, log, repo, timeout):
                commands.append(command)
                records = device_records() if 'devices' in command else runtime_records()
                if 'devices' in command:
                    records['devices'][RUNTIME][0]['deviceTypeIdentifier'] = 'iPhone-large'
                log.write_text(json.dumps(records))
                return 0

            with patch.object(runner, 'logged_command', side_effect=execute), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(runner.run(root, root / 'evidence', DEVICE), 1)
            receipt = json.loads((root / 'evidence/status.json').read_text())
            self.assertEqual(receipt['attempts'], 0)
            self.assertFalse(receipt['passed'])
            self.assertEqual(len(commands), 2)
            self.assertTrue(all(command[:3] == ['xcrun', 'simctl', 'list'] for command in commands))

    def test_passing_test_log_without_original_bundle_remains_failure(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root / 'ios/TimbreUITests/TuneCheckLayoutUITests.swift'
            source.parent.mkdir(parents=True)
            source.write_text('\n'.join(f'func {method}() {{}}' for method in runner.METHODS))

            def execute(command, log, repo, timeout):
                if 'devices' in command:
                    log.write_text(json.dumps(device_records()))
                elif 'runtimes' in command:
                    log.write_text(json.dumps(runtime_records()))
                else:
                    log.write_text(passing_log())
                return 0

            with patch.object(runner, 'logged_command', side_effect=execute), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(runner.run(root, root / 'evidence', DEVICE), 1)
            receipt = json.loads((root / 'evidence/status.json').read_text())
            self.assertTrue(receipt['tests']['passed'])
            self.assertFalse(receipt['passed'])
            self.assertIn('native result bundle', receipt['issues'][0])

    def test_command_timeout_has_one_attempt_and_nonzero_result(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            with patch.object(runner.subprocess, 'run', side_effect=subprocess.TimeoutExpired('xcodebuild', 2400)) as call:
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(runner.logged_command(['xcodebuild'], path / 'test.log', path, 2400), 124)
            call.assert_called_once()


if __name__ == '__main__':
    unittest.main()
