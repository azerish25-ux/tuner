"""Source guardrails for the native Urdu ink and welcome-scroll regressions, not a native render pass."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/l10n"))
import matrix_fixture


class WelcomeTypographyContract(unittest.TestCase):
    def test_only_urdu_gains_scaled_leading_without_font_or_copy_replacement(self):
        source = (ROOT / "ios/Timbre/Onboarding/WelcomeHeadline.swift").read_text()
        for token in ['locale.language.languageCode?.identifier == "ur"',
                      '@ScaledMetric(relativeTo: .largeTitle)', 'nastaliqLeading: CGFloat = 24',
                      '.lineSpacing(isUrdu ? nastaliqLeading : 0)',
                      '.padding(.vertical, isUrdu ? nastaliqLeading / 2 : 0)',
                      'Typeface.display(40)', 'Typeface.display(28, relativeTo: .largeTitle)',
                      'Text("Tune in seconds.\\nThen learn to play.")',
                      '.fixedSize(horizontal: false, vertical: true)',
                      '.accessibilityAddTraits(.isHeader)']:
            self.assertIn(token, source)
        for workaround in ['minimumScaleFactor', 'lineLimit', '.dynamicTypeSize(', '.leftToRight',
                           'Text(verbatim:', '.clipped()', '.accessibilityLabel(']:
            self.assertNotIn(workaround, source)

    def test_scroll_fallback_is_urdu_only_and_preserves_actions(self):
        source = (ROOT / "ios/Timbre/Onboarding/OnboardingView.swift").read_text()
        welcome = source.split('// MARK: Welcome', 1)[1].split('/// "Just tune"', 1)[0]
        for token in ['if locale.language.languageCode?.identifier == "ur"', 'ScrollView {',
                      '.frame(minHeight: geometry.size.height, alignment: .top)',
                      'welcomeContent()','WelcomeHeadline().foregroundStyle(Palette.ink)',
                      'Button("Get started") { go(.experience) }', 'justTuneLink', 'restoreLink',
                      '.onAppear(perform: playWelcome)']:
            self.assertIn(token, welcome)
        self.assertIn('} else {\n            welcomeContent()\n        }', welcome)

    def test_native_oracle_separates_actual_lines_and_rejects_original_collision(self):
        source = (ROOT / 'ios/TimbreAppTests/WelcomeHeadlineLayoutTests.swift').read_text()
        for token in ['struct LineMask: TextRenderer', 'layout.enumerated()', 'context.draw(line)',
                      'controlled.textRenderer(LineMask(parity: 0))',
                      'controlled.textRenderer(LineMask(parity: 1))',
                      'union.elementsEqual(full.ink)', 'XCTAssertFalse(even.touches(odd)',
                      'XCTAssertTrue(masks.even.touches(masks.odd)', 'let example = Example(width: 362)',
                      '[CGFloat(280), 335, 362, 390]', 'DynamicTypeSize.large, .accessibility5',
                      'contains(full.bounds)', 'XCTAssertGreaterThan(heights[1], heights[0]',
                      '["en", "ta", "ar", "fa", "he"]', 'renderer.scale = 3',
                      'actual.ink.elementsEqual(expected.ink)', '.keepAlways']:
            self.assertIn(token, source)
        self.assertNotIn('.clipped()', source)
        self.assertNotIn('XCTSkip', source)
        self.assertNotIn('var displayPadding:', source)
        for token in ['text.sizeThatFits(proposal)', 'LineMask(parity: nil)',
                      'view.typesettingLanguage(Locale(identifier: example.language).language)',
                      'try requireSamePixels(full, language', 'try requireSamePixels(full, completeProbe',
                      'expected.rgba == actual.rgba', 'XCTUnwrap(same ? true : nil',
                      'try requireSamePixels(masks.full, expected', 'original-independent-urdu-language']:
            self.assertIn(token, source)
        self.assertLess(source.index('try requireSamePixels(full, completeProbe'),
                        source.index('let even = try render(controlled.textRenderer'))

    def test_calibration_is_bounded_native_only_and_keeps_production_gate(self):
        source = (ROOT / 'ios/TimbreAppTests/WelcomeHeadlineLayoutTests.swift').read_text()
        for token in ['testRecordBoundedUrduLeadingCalibration', '("baseline", 24, 12, 0)',
                      '("roomier", 40, 32, 12)', '("separated", 48, 32, 12)',
                      'try requireSamePixels(native, baseline', 'try autoreleasepool',
                      'diagnostics: false, nativeImage: representative', 'XCTAssertEqual(rows.count, 24',
                      '"diagnosticOnly": true', '"safeForThisSample": separated && fits && union.elementsEqual(full.ink)',
                      '"urdu-leading-calibration.json"']:
            self.assertIn(token, source)
        self.assertIn('XCTAssertFalse(even.touches(odd)', source)
        self.assertIn('contains(full.bounds)', source)

    def test_native_fallback_diagnostic_discovers_the_face_without_changing_production(self):
        source = (ROOT / 'ios/TimbreAppTests/WelcomeFallbackDiagnosticsTests.swift').read_text()
        for token in ['CTFontCreateForStringWithLanguage', 'CTFontCopyPostScriptName',
                      'CTFontGetAscent', 'CTFontGetDescent', 'CTFontGetLeading', 'CTFontGetBoundingBox',
                      'Typeface.Face.semiBold', '@ScaledMetric(relativeTo: .largeTitle)',
                      '.font(Font(fallback))', 'fallback-word-original-', 'fallback-word-explicit-',
                      'fallback-production-reference-', 'fallback-explicit-candidate-',
                      'DynamicTypeSize.large', 'CGFloat(280), .accessibility5', 'autoreleasepool']:
            self.assertIn(token, source)
        for workaround in ['minimumScaleFactor', '.lineLimit(', '.clipped()', 'XCTSkip']:
            self.assertNotIn(workaround, source)
        production = (ROOT / 'ios/Timbre/Onboarding/WelcomeHeadline.swift').read_text()
        self.assertNotIn('CTFontCreate', production)

    def test_actual_ui_flow_uses_exact_shipped_urdu_and_existing_first_session_class(self):
        source = (ROOT / 'ios/TimbreUITests/FirstSessionUITests.swift').read_text()
        expected = matrix_fixture.fixture(['ur'])['ur']
        self.assertIn(expected['headline'].replace('\n', '\\n'), source)
        self.assertIn(expected['start'], source)
        for token in ['"(ur)"', '"ur_PK"', 'UICTContentSizeCategoryAccessibilityXXXL',
                      'revealWelcome(headline, edge: .top)', 'revealWelcome(headline, edge: .bottom)',
                      'revealWelcome(start)', 'start.tap()', 'headline.waitForNonExistence',
                      'scroll.frame.intersection(app.frame)', 'viewport.contains(wanted)',
                      'target.isHittable', 'XCTAttachment(screenshot: app.screenshot())',
                      'testDeferredQuestionsPersistOnlyForTheInstallationThatSkippedThem',
                      'testADeadStringIsNamedWithoutCompletingTheChord',
                      'testThePaywallFromSettingsShowsItsPlans', 'testJustTuneReachesAListeningTuner']:
            self.assertIn(token, source)
        self.assertNotIn('XCTSkip', source)
        self.assertNotIn('performAccessibilityAudit', source)


if __name__ == '__main__':
    unittest.main()
