"""Test-driver contracts; native selection and navigation still require XCTest."""
from pathlib import Path
import unittest

SOURCE = (Path(__file__).resolve().parents[2] / 'ios/TimbreUITests/TimbreUITests.swift').read_text()


class OnboardingSelectionContract(unittest.TestCase):
    def test_selection_requires_real_unique_hittable_button_and_observed_state(self):
        helper = SOURCE.split('private func selectOnboardingBeginner()', 1)[1].split('// MARK:', 1)[0]
        for text in ['app.buttons.matching(identifier: "onboarding.option.beginner")',
                     'answers.count == 1', 'answer.isEnabled, answer.isHittable',
                     'for attempt in 0..<3', 'if !answer.isSelected { answer.tap() }',
                     'answer.exists && answer.isSelected && next.exists && next.isEnabled',
                     'XCTWaiter.wait(for: [accepted], timeout: 5)', 'result == .completed']:
            self.assertIn(text, helper)
        self.assertNotIn('coordinate(', helper)
        self.assertNotIn('launchEnvironment', helper)

    def test_failed_selection_attaches_evidence_and_stops_navigation(self):
        helper = SOURCE.split('private func selectOnboardingBeginner()', 1)[1].split('// MARK:', 1)[0]
        self.assertIn('shot("onboarding-beginner-selection-failed")', helper)
        self.assertIn('XCTFail("The unique beginner answer must become selected and enable Continue")', helper)
        self.assertIn('return false', helper)
        flow = SOURCE.split('func test01Onboarding()', 1)[1].split('func test02', 1)[0]
        self.assertIn('guard selectOnboardingBeginner() else { return }', flow)
        for target in ['songs', 'right']:
            self.assertIn(f'guard continueUntil(element("onboarding.option.{target}")) else {{ return }}', flow)

    def test_transition_failure_is_reported_before_any_mislabeled_capture(self):
        helper = SOURCE.split('private func continueUntil(', 1)[1].split('private func selectOnboardingBeginner()', 1)[0]
        self.assertIn('guard next.exists else', helper)
        self.assertIn('shot("onboarding-transition-failed")', helper)
        self.assertIn('XCTFail(', helper)
        self.assertIn('return false', helper)


if __name__ == '__main__':
    unittest.main()
