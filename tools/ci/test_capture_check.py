import contextlib
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import capture_check as capture


def transcript(failed=None, error='Application target does not have a process ID'):
    lines = []
    for name in sorted(capture.EXPECTED):
        module, cls, method = name.split('/')
        case = f'{module}.{cls} {method}'
        if name == failed:
            lines.append(f"source.swift:47: error: -[{case}] : {error}")
        lines.append(f"Test Case '-[{case}]' {'failed' if name == failed else 'passed'} (1 seconds).")
    return '\n'.join(lines)


class EvaluationTests(unittest.TestCase):
    def setUp(self):
        self.failed = sorted(capture.EXPECTED)[0]
        self.launch = transcript(self.failed)

    def test_complete_green_and_only_launch_failure(self):
        self.assertEqual(capture.evaluate(0, transcript()), (True, False))
        self.assertEqual(capture.evaluate(65, self.launch), (False, True))

    def test_signal_non65_and_partial_coverage_cannot_retry(self):
        for code in [-9, 137, 143, 1, 0]:
            self.assertEqual(capture.evaluate(code, self.launch), (False, False))
        for text in ['', self.launch.rsplit('\n', 1)[0], self.launch + '\n' + self.launch]:
            self.assertEqual(capture.evaluate(65, text), (False, False))

    def test_real_assertions_and_unclassified_errors_cannot_retry(self):
        for error in ['XCTAssertTrue failed - lock failed', 'crashed', 'failed - does not have a process ID']:
            self.assertEqual(capture.evaluate(65, transcript(self.failed, error)), (False, False))
        self.assertEqual(capture.evaluate(65, self.launch + '\nxcodebuild: error: runner died'), (False, False))
        self.assertEqual(capture.evaluate(65, self.launch + '\nsource.swift: error: -[TimbreUITests.TimbreUITests test19StoreViolinResults] : real assertion'), (False, False))

    def test_green_with_failure_or_missing_tests_is_not_success(self):
        self.assertEqual(capture.evaluate(0, self.launch), (False, False))
        self.assertEqual(capture.evaluate(0, ''), (False, False))


class ExecutionTests(unittest.TestCase):
    def run_case(self, results, valid=True):
        with tempfile.TemporaryDirectory() as directory:
            out = Path(directory)
            invocations = []
            def invoke(mode, bundle, log):
                if mode == 'build-for-testing':
                    log.write_text('native build log fixture')
                    bundle.mkdir()
                    return 0
                index = len(invocations)
                invocations.append((mode, str(bundle)))
                bundle.mkdir()
                code, text = results[index]
                log.write_text(text)
                return code
            with patch.object(capture, 'invoke', side_effect=invoke), \
                 patch.object(capture, 'warmup') as warm, \
                 patch.object(capture.subprocess, 'run') as native, \
                 patch.object(capture, 'validate_captures', side_effect=None if valid else ValueError('missing frame')) as validate, \
                 patch.dict(os.environ, {'DEVICE_ID': 'same-device', 'GITHUB_SHA': 'revision',
                                        'TEST_RUNNER_TIMBRE_UI_LANGUAGE': 'en', 'TEST_RUNNER_TIMBRE_UI_LOCALE': 'en_US'}), \
                 contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                code = capture.run(out)
                receipt = json.loads((out / 'status.json').read_text())
                calls = [call.args[0] for call in native.call_args_list]
                selected = [str(call.args[0].relative_to(out)) for call in validate.call_args_list]
            self.assertTrue((out / 'attempt-1/test.log').exists())
            if len(invocations) == 2:
                self.assertTrue((out / 'attempt-2/test.log').exists())
                self.assertTrue((out / 'attempt-1/CaptureCheck.xcresult').is_dir())
            return code, receipt, invocations, calls, selected

    def test_retry_uses_same_build_preserves_both_attempts_and_selects_only_second(self):
        failed = sorted(capture.EXPECTED)[0]
        code, receipt, invocations, calls, selected = self.run_case([(65, transcript(failed)), (0, transcript())])
        self.assertEqual(code, 0)
        self.assertEqual(receipt['selected_attempt'], 2)
        self.assertEqual([x[0] for x in invocations], ['test-without-building', 'test-without-building'])
        self.assertEqual(selected, ['attempt-2/screenshots'])
        self.assertEqual([x[2] for x in calls if x[1] == 'simctl'], ['shutdown', 'boot', 'bootstatus'])
        self.assertEqual(len([x for x in calls if x[1] == 'xcresulttool']), 2)
        self.assertEqual(receipt['source_sha'], 'revision')
        self.assertEqual(receipt['locale'], 'en_US')

    def test_retry_failure_stays_failed_without_third_attempt(self):
        failed = sorted(capture.EXPECTED)[0]
        code, receipt, invocations, _, selected = self.run_case([(65, transcript(failed)), (65, transcript(failed))])
        self.assertEqual(code, 1)
        self.assertFalse(receipt['passed'])
        self.assertIsNone(receipt['selected_attempt'])
        self.assertEqual(len(invocations), 2)
        self.assertEqual(selected, [])

    def test_signal_partial_real_error_do_not_reboot_or_retry(self):
        failed = sorted(capture.EXPECTED)[0]
        for result in [(-9, transcript(failed)), (65, ''), (65, transcript(failed, 'XCTAssertTrue failed'))]:
            code, receipt, invocations, calls, _ = self.run_case([result])
            self.assertEqual(code, 1)
            self.assertEqual(len(invocations), 1)
            self.assertFalse(any(x[1] == 'simctl' for x in calls))
            self.assertFalse(receipt['passed'])

    def test_green_tests_missing_capture_is_still_failed(self):
        code, receipt, _, _, _ = self.run_case([(0, transcript())], valid=False)
        self.assertEqual(code, 1)
        self.assertFalse(receipt['passed'])

    def test_build_failure_does_not_warm_or_test(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(capture, 'invoke', return_value=65) as invoke, patch.object(capture, 'warmup') as warm, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(capture.run(Path(directory)), 1)
            self.assertEqual(invoke.call_count, 1)
            self.assertEqual(invoke.call_args.args[0], 'build-for-testing')
            warm.assert_not_called()

    def test_warmup_failure_never_falls_back_to_unwarmed_native_test(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(capture, 'invoke', return_value=0) as invoke, patch.object(capture, 'warmup', side_effect=RuntimeError('warmup failed')), patch.dict(os.environ, {'DEVICE_ID': 'same', 'TEST_RUNNER_TIMBRE_UI_LANGUAGE': 'ar', 'TEST_RUNNER_TIMBRE_UI_LOCALE': 'ar_SA'}), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(capture.run(Path(directory)), 1)
            self.assertEqual(invoke.call_count, 1)
            self.assertFalse(json.loads((Path(directory) / 'status.json').read_text())['passed'])

    def test_capture_validation_requires_distinct_originals_and_rejects_wrong_marker(self):
        import sys
        sys.path.insert(0, str(capture.ROOT / 'tools/marketing'))
        import screenshots
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            records = {}
            for name in capture.CAPTURES:
                path = folder / (name + '.png')
                path.write_bytes(b'not image evidence: attachment path contract unit test only')
                records[name] = [path]
            with patch.object(screenshots, 'attachments', return_value=records):
                capture.validate_captures(folder)
            for bad in [{**records, capture.CAPTURES[0]: []},
                        {**records, capture.CAPTURES[0] + '-wrong': []},
                        {**records, capture.CAPTURES[0]: records[capture.CAPTURES[1]]},
                        {**records, capture.CAPTURES[0]: [folder.parent / 'outside.png']}]:
                with patch.object(screenshots, 'attachments', return_value=bad), self.assertRaises(ValueError):
                    capture.validate_captures(folder)


if __name__ == '__main__':
    unittest.main()
