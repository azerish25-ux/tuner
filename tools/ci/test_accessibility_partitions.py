#!/usr/bin/env python3
"""Partition orchestration tests; not a substitute for native XCTest execution."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import accessibility_partitions as subject

NAME = 'TimbreUITests/AccessibilityAuditUITests/testEveryTab'
CASE_NAME = 'TimbreUITests.AccessibilityAuditUITests testEveryTab'
PASS = f"Test Case '-[{CASE_NAME}]' passed (1 seconds).\n"
FAIL = f"Test Case '-[{CASE_NAME}]' failed (1 seconds).\n"
LAUNCH = f"error: -[{CASE_NAME}] : Failed to launch application via Xcode\n" + FAIL
AUDIT = f"error: -[{CASE_NAME}] : failed - contrast failed\n" + FAIL


class PartitionTests(unittest.TestCase):
    def test_partition_selection_is_exhaustive_and_disjoint(self):
        groups = [subject.expected_tests(p) for p in subject.PARTITIONS]
        self.assertEqual(groups[2], {NAME})
        self.assertIn('TimbreUITests/AccessibilityAuditUITests/testWelcomeScreen', groups[1])
        self.assertIn('TimbreUITests/AccessibilityAuditUITests/testSettingsAndPaywall', groups[1])
        for index, group in enumerate(groups):
            for other in groups[index + 1:]:
                self.assertFalse(group & other)
        import re
        sources = ['AccessibilityAuditUITests', 'LocalizationLaunchUITests']
        all_methods = {f'TimbreUITests/{cls}/{name}' for cls in sources
                       for name in re.findall(r'^\s*func (test\w+)\s*\(',
                           (subject.ROOT / f'ios/TimbreUITests/{cls}.swift').read_text(), re.MULTILINE)}
        self.assertEqual(set.union(*groups), all_methods)

    def test_missing_terminal_case_fails_even_successful_command(self):
        self.assertEqual(subject.evaluate_initial(0, '', {NAME}), (True, [], [NAME]))

    def test_nonlaunch_failure_is_sticky(self):
        self.assertEqual(subject.evaluate_initial(65, AUDIT, {NAME}), (True, [], []))

    def test_launch_only_failure_can_retry(self):
        self.assertEqual(subject.evaluate_initial(65, LAUNCH, {NAME}), (False, [NAME], []))

    def test_crash_without_retryable_failure_is_sticky(self):
        self.assertTrue(subject.evaluate_initial(65, PASS, {NAME})[0])

    def test_failed_case_cannot_pass_with_zero_exit(self):
        self.assertTrue(subject.evaluate_initial(0, LAUNCH, {NAME})[0])
        self.assertTrue(subject.evaluate_initial(0, AUDIT, {NAME})[0])

    def run_fake(self, attempts):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            calls = []
            def invoke(bundle, log, arguments):
                calls.append(arguments)
                code, text = attempts[len(calls) - 1]
                log.write_text(text)
                return code
            with patch.object(subject, 'ROOT', root), patch.object(subject, 'expected_tests', return_value={NAME}), patch.object(subject, 'invoke', side_effect=invoke):
                code = subject.run('tabs')
                receipt = json.loads((root / 'ci-out/tabs/status.json').read_text())
            return code, receipt, calls

    def test_successful_launch_retry_and_exact_retry_selector(self):
        code, receipt, calls = self.run_fake([(65, LAUNCH), (0, PASS)])
        self.assertEqual(code, 0)
        self.assertTrue(receipt['passed'])
        self.assertEqual(calls[1], ['-only-testing:' + NAME])

    def test_signal_or_infrastructure_exit_stays_failed_after_successful_retry(self):
        for code in (-15, 137, 70):
            with self.subTest(code=code):
                result, receipt, calls = self.run_fake([(code, LAUNCH), (0, PASS)])
                self.assertEqual(result, 1)
                self.assertFalse(receipt['passed'])
                self.assertEqual(len(calls), 2)

    def test_retry_missing_terminal_result_is_failure(self):
        code, receipt, _ = self.run_fake([(65, LAUNCH), (0, '')])
        self.assertEqual(code, 1)
        self.assertEqual(receipt['retry_missing'], [NAME])

    def test_retry_does_not_erase_other_failure(self):
        other = AUDIT.replace('testEveryTab', 'testWelcomeScreen')
        code, receipt, _ = self.run_fake([(65, LAUNCH + other), (0, PASS)])
        self.assertEqual(code, 1)
        self.assertFalse(receipt['passed'])

    def test_missing_partition_receipt_fails_aggregate(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(subject, 'ROOT', Path(directory)), patch.object(subject, 'expected_tests', return_value={NAME}):
            self.assertEqual(subject.aggregate(), 1)

    def test_workflow_checkpoints_precede_next_partition_and_keep_consumer_name(self):
        workflow = (subject.ROOT / '.github/workflows/ios.yml').read_text()
        job = workflow.split('  accessibility:\n', 1)[1].split('\n  gate:\n', 1)[0]
        self.assertIn('timeout-minutes: 75', job)
        self.assertIn('name: results-accessibility\n', job)
        previous = -1
        for partition in subject.PARTITIONS:
            run = job.index('run: python3 tools/ci/accessibility_partitions.py ' + partition)
            checkpoint = job.index('name: accessibility-checkpoint-' + partition)
            self.assertLess(previous, run)
            self.assertLess(run, checkpoint)
            self.assertIn(f'ios/build/Accessibility-{partition}*.xcresult', job)
            previous = checkpoint
        self.assertGreater(job.index('accessibility_partitions.py aggregate'), previous)
        self.assertEqual(job.count("!cancelled() && steps.ax-build.outcome == 'success'"), 3)

    def test_audit_streams_events_without_dropping_attachments(self):
        source = (subject.ROOT / 'ios/TimbreUITests/AccessibilityAuditUITests.swift').read_text()
        self.assertIn('for line in lines.dropFirst(oldValue.count)', source)
        self.assertIn('AX-AUDIT: Begin screen', source)
        self.assertIn('threw: \\(error.localizedDescription)', source)
        self.assertIn('report.lifetime = .keepAlways', source)
        self.assertIn('rendered.lifetime = .keepAlways', source)


class SubmissionDispositionTests(unittest.TestCase):
    def evidence(self, message, *, code=65, terminal='failed'):
        text = (f"Test Case '-[{CASE_NAME}]' started.\n"
                + (f"error: -[{CASE_NAME}] : {message}\n" if message else '')
                + f"Test Case '-[{CASE_NAME}]' {terminal} (1 seconds).\n")
        receipt = dict(expected=[NAME], initial_exit=code, retried=[], retry_exit=None,
                       missing=[], retry_missing=[], passed=(code == 0))
        return receipt, text

    def test_contrast_stays_strictly_failed_but_is_advisory_for_submission(self):
        receipt, text = self.evidence('failed - tab-3-songs: [contrast, enforced] Contrast failed | id example')
        result = subject.submission_disposition(receipt, text, {NAME})
        self.assertTrue(result['required_checks_passed'])
        self.assertFalse(result['strict_sdk_passed'])
        self.assertEqual(len(result['advisory']), 1)
        self.assertFalse(receipt['passed'])

    def test_two_uncorroborated_sdk_timeout_kinds_are_advisory(self):
        for kind in ['Dynamic Type', 'clipped text']:
            receipt, text = self.evidence('failed - tab-3-songs: the accessibility audit could not run '
                f'(up to 3 isolated tries): {kind}: Audit failed to complete in time')
            with self.subTest(kind=kind):
                self.assertTrue(subject.submission_disposition(receipt, text, {NAME})['required_checks_passed'])

    def test_other_accessibility_assertions_and_unknown_errors_remain_blocking(self):
        for message in ['failed - tab-3-songs: [hit region, enforced] hit region failed',
                        'failed - tab-3-songs: [traits, enforced] invalid trait',
                        'failed - missing control', 'failed - anonymous unknown failure',
                        'Failed to launch application via Xcode']:
            receipt, text = self.evidence(message)
            with self.subTest(message=message):
                self.assertFalse(subject.submission_disposition(receipt, text, {NAME})['required_checks_passed'])

    def test_missing_skipped_duplicate_foreign_or_crashed_cases_cannot_pass(self):
        receipt, text = self.evidence('failed - tab-3-songs: [contrast, enforced] Contrast failed | id example')
        for bad in ['', text.replace('failed (1', 'skipped (1'), text + text,
                    text.replace('testEveryTab', 'testForeign'), text + 'Test crashed\n']:
            with self.subTest(bad=bad):
                self.assertFalse(subject.submission_disposition(receipt, bad, {NAME})['required_checks_passed'])
        for code in [1, 70, 124, -9]:
            changed = dict(receipt, initial_exit=code)
            self.assertFalse(subject.submission_disposition(changed, text, {NAME})['required_checks_passed'])

    def test_success_is_retained_and_receipt_tampering_or_retry_is_not_advisory_fallback(self):
        receipt, text = self.evidence('', code=0, terminal='passed')
        self.assertTrue(subject.submission_disposition(receipt, text, {NAME})['strict_sdk_passed'])
        for changed in [dict(receipt, expected=[]), dict(receipt, retried=[NAME]),
                        dict(receipt, missing=[NAME]), dict(receipt, initial_exit=65)]:
            self.assertFalse(subject.submission_disposition(changed, text, {NAME})['required_checks_passed'])

    def test_setup_failure_cannot_be_waived_alone_or_alongside_sdk_failures(self):
        import re
        workflow = (subject.ROOT / '.github/workflows/ios.yml').read_text()
        job = workflow.split('  accessibility:\n', 1)[1].split('\n  gate:\n', 1)[0]
        identities = re.findall(r'^        id: ([\w-]+)$', job, re.MULTILINE)
        clean = {identity: {'outcome': 'success'} for identity in identities}
        self.assertEqual(subject.submission_step_disposition(clean), [])
        for sdk_failed in [False, True]:
            changed = {key: dict(value) for key, value in clean.items()}
            if sdk_failed:
                changed['ax-sdk-tabs']['outcome'] = 'failure'
                changed['ax-sdk-aggregate']['outcome'] = 'failure'
                self.assertEqual(subject.submission_step_disposition(changed), [])
            changed['ax-build']['outcome'] = 'failure'
            self.assertTrue(subject.submission_step_disposition(changed))
            changed['ax-build']['outcome'] = 'skipped'
            self.assertTrue(subject.submission_step_disposition(changed))
        missing = dict(clean); missing.pop('ax-logcollect')
        self.assertTrue(subject.submission_step_disposition(missing))
        foreign = dict(clean, foreign={'outcome': 'success'})
        self.assertTrue(subject.submission_step_disposition(foreign))

    def test_missing_receipt_fields_are_not_complete_evidence(self):
        receipt, text = self.evidence('', code=0, terminal='passed')
        for field in receipt:
            changed = dict(receipt); del changed[field]
            self.assertFalse(subject.submission_disposition(changed, text, {NAME})['required_checks_passed'])


if __name__ == '__main__':
    unittest.main()
