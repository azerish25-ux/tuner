"""Source guardrails for the native Urdu ink and welcome-scroll regressions, not a native render pass."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/l10n"))
import matrix_fixture


class WelcomeTypographyContract(unittest.TestCase):
    def test_only_urdu_uses_its_existing_native_glyph_face_and_scaled_overhang_clearance(self):
        source = (ROOT / "ios/Timbre/Onboarding/WelcomeHeadline.swift").read_text()
        for token in ['locale.language.languageCode?.identifier == "ur"',
                      '@ScaledMetric(relativeTo: .largeTitle)', 'urduPoints: CGFloat = 40',
                      'urduHorizontalClearance: CGFloat = 12', 'CTFontCreateForStringWithLanguage',
                      'Typeface.boldText ? Typeface.Face.semiBold.heavier : Typeface.Face.semiBold',
                      'Font(Self.nativeUrduFont(points: urduPoints, locale: locale))',
                      '.typesettingLanguage(locale.language)',
                      '.padding(isUrdu ? Self.nativeUrduLayoutInsets(ink: urduInkInsets, minimumHorizontal: urduHorizontalClearance) : EdgeInsets())',
                      'let copy = fontSelectionText(locale: locale)',
                      'Bundle.main.path(forResource: language, ofType: "lproj")',
                      'bundle: bundle, locale: locale',
                      'Typeface.display(40)', 'Typeface.display(28, relativeTo: .largeTitle)',
                      'Text("Tune in seconds.\\nThen learn to play.")',
                      '.fixedSize(horizontal: false, vertical: true)',
                      '.accessibilityAddTraits(.isHeader)']:
            self.assertIn(token, source)
        for workaround in ['minimumScaleFactor', 'lineLimit', '.dynamicTypeSize(', '.leftToRight',
                           'Text(verbatim:', '.clipped()', '.accessibilityLabel(', '.lineSpacing(',
                           '.padding(.vertical', 'NotoNastaliqUrdu', 'Font.custom']:
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
                      'contains(native.bounds)', 'XCTAssertGreaterThan(heights[1], heights[0]',
                      '["en", "ta", "ar", "fa", "he"]', 'renderer.scale = 3',
                      'try requireSamePixels(expected, actual', '.keepAlways']:
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

    def test_native_metrics_acceptance_covers_all_eight_samples_without_calibration_workarounds(self):
        source = (ROOT / 'ios/TimbreAppTests/WelcomeHeadlineLayoutTests.swift').read_text()
        for token in ['testProductionUsesNativeUrduMetricsAtEveryWidthAndSize',
                      'struct NativeMetricsHeadline', 'CTFontCreateForStringWithLanguage',
                      '@ScaledMetric(relativeTo: .largeTitle)', 'points: CGFloat = 40',
                      'horizontal: CGFloat = 12', '.font(Font(fallback)).tracking(-1)',
                      'try requireSamePixels(native, independent', 'try autoreleasepool',
                      'XCTAssertEqual(samples, 8', 'production-vs-native-metrics-',
                      'XCTAssertFalse(even.touches(odd)', 'contains(native.bounds)']:
            self.assertIn(token, source)
        self.assertNotIn('CalibrationHeadline', source)
        self.assertNotIn('diagnosticOnly', source)

    def test_native_and_probe_share_physical_canvas_without_pixel_registration(self):
        source = (ROOT / 'ios/TimbreAppTests/WelcomeHeadlineLayoutTests.swift').read_text()
        for token in ['struct PinnedCanvas: Layout', 'PinnedCanvas(width: example.width, direction: example.direction)',
                      'subviews[0].sizeThatFits(ProposedViewSize(width: width, height: nil))',
                      'anchor: UnitPoint(x: rtl ? 1 : 0, y: 0)',
                      'proposal: ProposedViewSize(width: width, height: nil)',
                      'let x = bounds.minX + 80 + (rtl ? width : 0)',
                      'CGPoint(x: x, y: bounds.minY + 80)',
                      '.environment(\\.layoutDirection, example.direction)',
                      '.environment(\\.layoutDirection, .leftToRight)',
                      'expected.rgba == actual.rgba']:
            self.assertIn(token, source)
        for workaround in ['.translateBy(', '.offset(', 'CGAffineTransform', 'XCTSkip',
                           '.frame(width: example.width)', '.clipped()']:
            self.assertNotIn(workaround, source)

    def test_native_bounds_are_checked_before_strict_probe_and_every_sample_is_attempted(self):
        source = (ROOT / 'ios/TimbreAppTests/WelcomeHeadlineLayoutTests.swift').read_text()
        test = source.split('func testUrduLinesHaveSeparateInkAtSmallPhoneAndAccessibilityWidths()', 1)[1].split('func testCollisionOracle', 1)[0]
        self.assertLess(test.index('contains(native.bounds)'), test.index('let masks = try probe'))
        for token in ['native: independent', '} catch {', 'XCTFail("Every requested sample requires a pixel-identical native probe:',
                      'samples += 1', 'XCTAssertEqual(samples, 8', 'XCTAssertEqual(heights.count, 2']:
            self.assertIn(token, test)
        canvas = source.split('private struct PinnedCanvas:', 1)[1].split('private func render<', 1)[0]
        self.assertIn('let direction: LayoutDirection', canvas)
        self.assertIn('let rtl = direction == .rightToLeft', canvas)
        self.assertNotIn('23', canvas)
        self.assertNotIn('11', canvas)
        self.assertIn('expected.rgba == actual.rgba', source)
        for workaround in ['accuracy:', 'changed <=', '.drawingGroup(', 'disablesSubpixelQuantization']:
            self.assertNotIn(workaround, source)

    def test_measured_clearance_preserves_native_text_placement_and_plain_reference(self):
        source = (ROOT / 'ios/Timbre/Onboarding/WelcomeHeadline.swift').read_text()
        for token in ['nativeUrduInkInsets(font: CTFont, text: String, displayScale: CGFloat)',
                      'CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)', 'CTLineGetTypographicBounds',
                      'CTLineGetTrailingWhitespaceWidth', '.paragraphStyle: paragraph, .tracking: -1',
                      'ink.maxX - width', 'ink.maxY - ascent', '-descent - ink.minY',
                      'ceil(max(0, value) * scale) / scale', 'Array(words[start])',
                      'words[start..<end].joined(separator: " ")', 'String(clusters[first..<last])',
                      'max(minimumHorizontal, ink.leading)',
                      'headline.typesettingLanguage(locale.language)']:
            self.assertIn(token, source)
        for workaround in ['TextRenderer', '.textRenderer(', '.offset(', 'translateBy',
                           'scaleBy', '.clipped()', 'disablesSubpixelQuantization']:
            self.assertNotIn(workaround, source)
        native = (ROOT / 'ios/TimbreAppTests/WelcomeHeadlineLayoutTests.swift').read_text()
        reference = native.split('private struct NativeMetricsHeadline:', 1)[1].split('func testProductionUses', 1)[0]
        self.assertNotIn('.textRenderer(', reference)
        test = native.split('func testUrduLinesHaveSeparateInkAtSmallPhoneAndAccessibilityWidths()', 1)[1].split('func testCollisionOracle', 1)[0]
        self.assertLess(test.index('try requireSamePixels(native, independent'), test.index('let masks = try probe(NativeMetricsHeadline()'))
        self.assertNotIn('probe(WelcomeHeadline()', test)
        self.assertIn('.environment(\\.displayScale, 3)', native)
        metric = (ROOT / 'ios/TimbreAppTests/WelcomeFallbackDiagnosticsTests.swift').read_text()
        for token in ['testMeasuredInkAllowanceContainsIndependentGlyphPathsAtNormalAndAX5Sizes',
                      'CTFontGetSize(font), points', 'CTFontCreatePathForGlyph', 'CTRunGetGlyphs',
                      'CTRunGetPositions', 'path.boundingBoxOfPath', 'reserved.contains(ink)',
                      'XCTAssertGreaterThan(checkedFragments, 20', '.accessibilityExtraExtraExtraLarge']:
            self.assertIn(token, metric)

    def test_live_welcome_gesture_uses_the_viewport_interior_and_saves_failed_trace_before_abort(self):
        source = (ROOT / 'ios/TimbreUITests/FirstSessionUITests.swift').read_text()
        helper = source.split('private func revealWelcome(', 1)[1].split('func testDeferredQuestions', 1)[0]
        for token in ['for attempt in 0..<16', 'viewport.contains(wanted)', 'target.isHittable',
                      'dx: viewport.midX', 'func captureTrace()', 'defer { captureTrace() }']:
            self.assertIn(token, helper)
        self.assertNotIn('viewport.minX + 24', helper)
        failed = helper.split('captureWelcome("unreachable-"', 1)[1]
        self.assertLess(failed.index('captureTrace()'), failed.index('XCTFail('))

    def test_native_fallback_evidence_checks_actual_production_resolution(self):
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
        self.assertIn('CTFontCreateForStringWithLanguage', production)
        for token in ['testFontResolutionUsesTheViewLanguageRatherThanTheTestHost',
                      'WelcomeHeadline.fontSelectionText(locale: Locale(identifier: "ur_PK"))',
                      'WelcomeHeadline.nativeUrduFont(points: 40, locale:',
                      'CTFontGetSize(production), 40', 'CTFontCopyPostScriptName(production)']:
            self.assertIn(token, source)

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
