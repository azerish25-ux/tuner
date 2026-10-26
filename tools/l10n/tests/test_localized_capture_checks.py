from pathlib import Path
import unittest
import json
import re

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
        self.assertIn('nodes.contains { $0.identifier == "lesson.chord.complete" }', source)
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

    def test_violin_capture_wait_covers_actual_curriculum_without_mid_take_queries(self):
        curriculum = json.loads((ROOT / 'ios/Sources/TimbreCore/Resources/curriculum.json').read_text())
        def dictionaries(value):
            if isinstance(value, dict):
                yield value
                for child in value.values():
                    yield from dictionaries(child)
            elif isinstance(value, list):
                for child in value:
                    yield from dictionaries(child)
        lesson = next(x for x in dictionaries(curriculum) if x.get('id') == 'vln-1-6')
        take = next(x for x in reversed(lesson['steps']) if x['type'] == 'along')
        beats = max(n['b'] + n['d'] for n in take['notes'])
        session = (ROOT / 'ios/Sources/TimbreCore/Learn/PlayAlongSession.swift').read_text()
        tail = float(re.search(r'public static let tail = ([0-9.]+)', session).group(1))
        seconds = (beats + take['beatsPerBar']) * 60 / take['bpm'] + tail
        self.assertLess(seconds, 40, 'Increase quiet capture wait when this fixture grows')
        source = (ROOT / 'ios/TimbreUITests/TimbreUITests.swift').read_text()
        test = source.split('func test19StoreViolinResults()', 1)[1].split('func testStoreResultsBoundsCalculation()', 1)[0]
        between = test.split('start.tap()', 1)[1].split('element("along.again")', 1)[0]
        self.assertIn('settle(40)', between)
        self.assertNotIn('waitForExistence', between)
        chord = source.split('func test12StoreChord()', 1)[1].split('func ', 1)[0]
        self.assertIn('settle(45)', chord)
        self.assertNotIn('waitForExistence', chord)

    def test_additional_store_frames_use_semantic_controls_and_state(self):
        checks = (ROOT / 'ios/TimbreUITests/TimbreUITests.swift').read_text()
        for obsolete in ['node.label == "Combo"', 'node.label == "Lyrics"', 'node.label.hasSuffix("Score")', 'summary.hasPrefix("Tune ")', 'app.buttons["Folk & world strings"]']:
            self.assertNotIn(obsolete, checks)
        for identifier in ['performance.combo.', 'performance.lyrics', 'performance.score', 'instruments.family.folk_world_strings', 'strum.summary.tune']:
            self.assertIn(identifier, checks)
        self.assertIn('hud == nil || score == nil || regions.count != 3', checks)
        self.assertIn('target.frame.midX > app.frame.midX', checks)
        hud = (ROOT / 'ios/Timbre/Learn/HighwayHUD.swift').read_text()
        lyrics = (ROOT / 'ios/Timbre/Learn/HighwayLyrics.swift').read_text()
        self.assertIn('.accessibilityLabel(Text("Combo"))', hud)
        self.assertIn('.accessibilityLabel(Text("Lyrics"))', lyrics)
        self.assertIn('.accessibilityIdentifier("performance.lyrics")', lyrics)

    def test_tablet_and_phone_share_explicit_language_and_tab_fixture(self):
        phone = (ROOT / 'ios/TimbreUITests/TimbreUITests.swift').read_text()
        tablet = (ROOT / 'ios/TimbreUITests/TabletScreenshotsUITests.swift').read_text()
        helper = (ROOT / 'ios/TimbreUITests/CaptureLocalization.swift').read_text()
        workflow = (ROOT / '.github/workflows/localized-capture-check.yml').read_text()
        self.assertIn('return language == "en" ? source : nil', helper)
        for code in [phone, tablet]:
            self.assertIn('CaptureLocalization.tabLabel(name)', code)
            self.assertIn('CaptureLocalization.language', code)
            self.assertIn('CaptureLocalization.locale', code)
            self.assertNotIn('app.buttons[name]', code)
            self.assertNotIn('app.buttons["Done"]', code)
        self.assertNotIn('app.tabBars.buttons[name]', phone)
        self.assertIn('CaptureLocalizationExpected.json', workflow)
        self.assertLess(workflow.index('CaptureLocalizationExpected.json'), workflow.index('(cd ios && xcodegen generate)'))
        self.assertIn('-only-testing:TimbreUITests/TimbreUITests/testCaptureLocalizationNavigationFixture', workflow)

    def test_capture_fixture_supports_english_source_and_all_translation_targets(self):
        import sys
        sys.path.insert(0, str(ROOT / 'tools/l10n'))
        import matrix_fixture
        import report
        locales = sorted(p.stem for p in report.RES.glob('*.lproj'))
        expected = matrix_fixture.fixture(locales)
        self.assertEqual(len(expected), 49)
        self.assertEqual(expected['en']['headline'], matrix_fixture.KEYS['headline'])
        for labels in expected.values():
            for key in ['tune', 'learn', 'songs', 'practice', 'progress', 'tuned', 'in_tune']:
                self.assertTrue(labels[key].strip())

    def test_general_tour_state_checks_do_not_depend_on_english_captions(self):
        phone = (ROOT / 'ios/TimbreUITests/TimbreUITests.swift').read_text()
        self.assertNotIn('private func labeled(', phone)
        self.assertNotIn('app.buttons["Not now"]', phone)
        for identifier in ['onboarding.microphone.skip', 'journey.accuracy', 'journey.accuracy.locked', 'lesson.explain.turnCue']:
            self.assertIn(identifier, phone)
        explain = (ROOT / 'ios/Timbre/Learn/LessonExplain.swift').read_text()
        self.assertIn('if cueShown {\n                turnCue(compact: false)\n                    .accessibilityIdentifier("lesson.explain.turnCue")', explain)
        self.assertIn('XCTAssertTrue(element("lesson.explain.turnCue").waitForExistence', phone)

    def test_tuner_capture_values_use_current_locale_and_missing_probe_fails(self):
        phone = (ROOT / 'ios/TimbreUITests/TimbreUITests.swift').read_text()
        tablet = (ROOT / 'ios/TimbreUITests/TabletScreenshotsUITests.swift').read_text()
        for code in [phone, tablet]:
            self.assertIn('CaptureLocalization.tuned', code)
            self.assertIn('CaptureLocalization.inTune', code)
            self.assertNotIn('(node.value as? String) == "Tuned"', code)
            self.assertNotIn('status == "In tune"', code)
        self.assertIn('return (false, "the probe has no lock field")', phone)

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
