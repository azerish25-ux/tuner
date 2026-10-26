from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[3]


class LocalizedCaptureChecksTests(unittest.TestCase):
    def test_production_semantic_ids_preserve_spoken_localized_strings(self):
        steps = (ROOT / 'ios/Timbre/Learn/LessonSteps.swift').read_text()
        results = (ROOT / 'ios/Timbre/Learn/LessonResults.swift').read_text()
        self.assertIn('finished ? "lesson.chord.complete" : "lesson.chord.pending"', steps)
        self.assertIn('lesson.chord.string.\\(number).\\(mark.rawValue)', steps)
        self.assertIn('.accessibilityValue(spokenMark)', steps)
        self.assertIn('String(localized: "Got it")', steps)
        self.assertIn('lesson.results.stars.\\(result.stars)', results)
        self.assertIn('.accessibilityLabel(Text("\\(result.stars) of 3 stars"))', results)
        self.assertIn('.accessibilityIdentifier("lesson.results.level")', results)

    def test_capture_checks_do_not_require_english_or_allow_empty_string_checks(self):
        source = (ROOT / 'ios/TimbreUITests/TimbreUITests.swift').read_text()
        self.assertIn('element("lesson.chord.complete").waitForExistence', source)
        self.assertIn('checks.count == 6 && heard == Set(1...6)', source)
        self.assertNotIn('$0.label.hasPrefix("String ")', source)
        self.assertNotIn('labeled("3 of 3 stars")', source)
        self.assertNotIn('labeled("Level [0-9]+")', source)
        self.assertNotIn('start.label == "Start"', source)
        self.assertEqual(source.count('element("lesson.results.stars.3").exists'), 2)

    def test_results_use_actual_fade_state_without_waiving_clipping(self):
        results = (ROOT / 'ios/Timbre/Learn/LessonResults.swift').read_text()
        checks = (ROOT / 'ios/TimbreUITests/TimbreUITests.swift').read_text()
        bounds = (ROOT / 'ios/TimbreUITests/CaptureFrameBounds.swift').read_text()
        self.assertIn('TestSupport.isOn(.debugState)', results)
        self.assertIn('moreBelow ? Self.foldFadeHeight : 0', results)
        self.assertIn('.frame(height: Self.foldFadeHeight)', results)
        self.assertIn('lesson.results.layout', results)
        self.assertNotIn('let clear = buttons - 36', checks)
        self.assertIn('CaptureFrameBounds.safeBottom', checks)
        self.assertIn('the actual results viewport/fade probe is missing', checks)
        self.assertIn('min(viewportBottom, buttonsTop) - fadeHeight', bounds)
        self.assertIn('contentBottom <= safeBottom + 1', bounds)
        self.assertIn('XCTAssertFalse(CaptureFrameBounds.fits(contentBottom: 771, safeBottom: 752))', checks)
        self.assertIn('XCTAssertFalse(CaptureFrameBounds.fits(contentBottom: 782, safeBottom: 780))', checks)

    def test_focused_ci_checks_ltr_rtl_and_requires_real_valid_attachments(self):
        source = (ROOT / '.github/workflows/localized-capture-check.yml').read_text()
        for language in ['en', 'de', 'ar']:
            self.assertIn('language: ' + language, source)
        for name in ['test12StoreChord', 'test19StoreViolinResults']:
            self.assertIn('-only-testing:TimbreUITests/TimbreUITests/' + name, source)
        self.assertIn('TEST_RUNNER_TIMBRE_UI_LANGUAGE:', source)
        self.assertIn('TEST_RUNNER_TIMBRE_UI_LOCALE:', source)
        self.assertIn("name + '-wrong' not in captures", source)
        self.assertIn('len(captures.get(name, [])) == 1', source)
        self.assertIn('persist-credentials: false', source)


if __name__ == '__main__':
    unittest.main()
