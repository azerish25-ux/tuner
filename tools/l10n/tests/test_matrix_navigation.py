"""Selection guardrails for the localization route; native tab behavior still requires XCUITest."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/ci'))
import launch_retry


class MatrixNavigationTests(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / 'ios/TimbreUITests/LocalizationMatrixUITests.swift').read_text()
        self.helper = self.source.split('private func selectTab(', 1)[1].split(
            '/// Large localized text', 1)[0]
        self.lesson = self.source.split('private func assertLocalizedLesson(', 1)[1].split(
            '/// A synthesized tab tap', 1)[0]

    def test_learn_selection_is_confirmed_before_looking_for_or_scrolling_lesson(self):
        selection = 'selectTab(learn, in: app, language: language, field: "learn")'
        self.assertIn('buttons[try XCTUnwrap(labels["learn"])]', self.lesson)
        for operation in ['identifier: "learn.lesson.gtr-1-1"', 'node.waitForExistence',
                          'app.swipeUp', 'node.tap()']:
            self.assertLess(self.lesson.index(selection), self.lesson.index(operation))

    def test_tab_retry_is_bounded_and_requires_selected_state(self):
        self.assertIn('for attempt in 1...3', self.helper)
        self.assertIn('button.waitForExistence(timeout: 15)', self.helper)
        self.assertIn('NSPredicate(format: "hittable == true"), object: button', self.helper)
        self.assertIn('XCTAssertEqual(XCTWaiter.wait(for: [reachable], timeout: 5), .completed', self.helper)
        self.assertIn('if button.isSelected { return }', self.helper)
        self.assertIn('NSPredicate(format: "selected == true"), object: button', self.helper)
        self.assertIn('XCTWaiter.wait(for: [selected], timeout: 3) == .completed', self.helper)
        self.assertIn('XCTAssertTrue(button.isSelected,', self.helper)
        self.assertIn('tab did not become selected after 3 taps', self.helper)
        self.assertEqual(self.helper.count('button.tap()'), 1)
        for forbidden in ['while ', 'sleep', 'launch()', 'coordinate(', 'XCTSkip', 'continueAfterFailure = true']:
            self.assertNotIn(forbidden, self.helper)

    def test_each_missed_selection_keeps_pixels_and_hierarchy(self):
        for token in ['capture(app, name: name)', 'XCTAttachment(string: app.debugDescription)',
                      'hierarchy.lifetime = .keepAlways', 'add(hierarchy)',
                      'TIMBRE_L10N_TAB_SELECTION_MISSED', 'tab-\\(field)-attempt-\\(attempt)']:
            self.assertIn(token, self.helper)
        self.assertNotIn('TIMBRE_L10N_MATRIX_TESTED', self.helper)
        self.assertNotIn('TIMBRE_L10N_LESSON_TESTED', self.helper)

    def test_song_route_and_both_tune_returns_use_selection_confirmation(self):
        self.assertEqual(self.source.count('selectTab(songs, in: app, language: language, field: "songs")'), 1)
        self.assertEqual(self.source.count('selectTab(tune, in: app, language: language, field: "tune")'), 2)
        self.assertIn('XCTAssertTrue(songs.isSelected', self.source)
        self.assertIn('XCTAssertTrue(tune.isSelected', self.source)

    def test_real_lesson_and_exact_translation_checks_are_not_retried_or_skipped(self):
        for token in ['XCTAssertTrue(node.isHittable', 'node.tap()',
                      'close.waitForExistence(timeout: 20)',
                      '["lesson_title", "lesson_heading", "lesson_body"]',
                      'NSPredicate(format: "label == %@", value)',
                      'text.waitForExistence(timeout: 15)', 'XCTAssertTrue(text.isHittable',
                      'close.waitForNonExistence(timeout: 15)']:
            self.assertIn(token, self.lesson)
        self.assertIn('continueAfterFailure = false', self.source)
        self.assertNotIn('XCTSkip', self.lesson)
        marker = self.lesson.index('print("TIMBRE_L10N_LESSON_TESTED')
        self.assertGreater(marker, self.lesson.index('selectTab(tune,'))
        self.assertGreater(marker, self.lesson.index('"tune.instrument"'))

    def test_real_tab_or_lesson_failure_cannot_be_retried_as_launch_infrastructure(self):
        case = 'TimbreUITests.LocalizationMatrixUITests testLocalizedWelcomeAndTabs'
        for message in ['ja: learn tab did not become selected after 3 taps',
                        'ja: first guitar lesson cannot be opened',
                        'ja: missing localized lesson_body']:
            with self.subTest(message=message):
                log = (f"Test Case '-[{case}]' started.\n"
                       f"error: -[{case}] : XCTAssertTrue failed - {message}\n"
                       f"Test Case '-[{case}]' failed.\n")
                eligible, other = launch_retry.classify(log)
                self.assertEqual(eligible, [])
                self.assertTrue(other)


if __name__ == '__main__':
    unittest.main()
