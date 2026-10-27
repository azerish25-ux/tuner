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


if __name__ == '__main__':
    unittest.main()
