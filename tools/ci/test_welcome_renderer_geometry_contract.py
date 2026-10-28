"""Diagnostic source guards; no source or harness pass substitutes for native acceptance."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class WelcomeRendererGeometryContract(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / 'ios/TimbreAppTests/WelcomeRendererGeometryTests.swift').read_text()

    def test_all_four_native_cases_visit_all_variants_and_both_backends(self):
        for name in ['testRTL280Large', 'testRTL280AX5', 'testRTL362Large', 'testRTL362AX5']:
            self.assertIn('func ' + name + '()', self.source)
        for token in ['case imageRenderer, attachedScrollViewport', 'for backend in Backend.allCases',
                      'for variant in GeometryVariant.allCases',
                      'case plain, zeroDefaultSize, zeroExplicitSize, measuredDefaultSize, measuredExplicitSize, actualProduction, paddedDrawingGroup',
                      'continueAfterFailure = true', 'visited += 1', 'XCTAssertEqual(visited, 14',
                      'XCTFail("Native diagnostic capture failed:']:
            self.assertIn(token, self.source)
        self.assertNotIn('XCTSkip', self.source)

    def test_exploratory_cases_have_a_finite_xctest_watchdog(self):
        setup = self.source.split('override func setUp() {', 1)[1].split('    func testRTL280Large()', 1)[0]
        self.assertIn('executionTimeAllowance = 120', setup)
        self.assertEqual(self.source.count('executionTimeAllowance ='), 1)
        self.assertLess(setup.index('executionTimeAllowance = 120'), setup.index('continueAfterFailure = true'))
        # A local poll cannot preempt synchronous UIKit drawing. Keep the original poll and coverage bounds too.
        self.assertIn('Date().addingTimeInterval(5)', self.source)
        self.assertIn('XCTAssertEqual(visited, 14', self.source)
        self.assertIn('xs.count * ys.count <= 64', self.source)
        self.assertNotIn('XCTExpectFailure', self.source)
        self.assertNotIn('XCTSkip', self.source)

    def test_plain_reference_and_drawing_group_candidate_remain_distinct(self):
        variants = self.source.split('switch variant {', 1)[1].split('/// Truly default sizing', 1)[0]
        plain = variants.split('case .plain:', 1)[1].split('case .zeroDefaultSize:', 1)[0]
        self.assertIn('text.padding(reserve).fixedSize(horizontal: false, vertical: true)', plain)
        self.assertNotIn('textRenderer', plain)
        self.assertNotIn('drawingGroup', plain)
        group = variants.split('case .paddedDrawingGroup:', 1)[1]
        self.assertLess(group.index('.padding(reserve)'), group.index('.drawingGroup('))
        self.assertIn('WelcomeHeadline()', variants.split('case .actualProduction:', 1)[1])
        for token in ['CTFontCreateForStringWithLanguage(base, word as CFString', 'let word = "سیکھیں۔"',
                      '.font(Font(font)).tracking(-1)', 'points: CGFloat = 40',
                      '.typesettingLanguage(Locale(identifier: "ur").language)']:
            self.assertIn(token, self.source)
        for forbidden in ['minimumScaleFactor', '.lineLimit(', '.clipped()', '.offset(', '.translateBy(',
                          '.scaleEffect(', '.scaleBy(', 'disablesSubpixelQuantization']:
            self.assertNotIn(forbidden, self.source)

    def test_default_sizing_is_really_default_and_explicit_sizing_is_passthrough(self):
        default = self.source.split('private struct DefaultGeometryRenderer:', 1)[1].split('private struct ExplicitGeometryRenderer:', 1)[0]
        explicit = self.source.split('private struct ExplicitGeometryRenderer:', 1)[1].split('private struct GeometryCanvas:', 1)[0]
        self.assertNotIn('func sizeThatFits', default)
        self.assertIn('let result = text.sizeThatFits(proposal)', explicit)
        self.assertIn('return result', explicit)
        self.assertIn('"explicitTextProxySize"', explicit)
        for text in [default, explicit]:
            self.assertIn('let displayPadding: EdgeInsets', text)
            self.assertIn('for line in layout { context.draw(line) }', text)
        for token in ['"wrapperSize"', '"wrapperPlacement"', '"subviewProposal"', '"subviewReturned"',
                      '"outside-padded-headline"', '"rendererDraw"', '"lineCount": layout.count',
                      'line.typographicBounds', '"contextTransform"', 'context.clipBoundingRect']:
            self.assertIn(token, self.source)

    def test_hosting_view_fits_actual_window_and_captures_original_native_viewports(self):
        for token in ['UIHostingController(rootView: GeometryScrollHost', 'host.safeAreaRegions = []',
                      'window.safeAreaLayoutGuide.layoutFrame.intersection(window.bounds)',
                      'parent.view.convert(viewport, from: window)', 'parent.addChild(host)',
                      'parent.view.addSubview(container)', 'host.didMove(toParent: parent)',
                      'host.view.window === window', 'window.bounds.contains(hostFrame)',
                      'viewport.contains(hostFrame)', 'XCTAssertTrue(contained,',
                      'window.screen.scale == 3', 'XCTAssertTrue(nativeScaleMatches,',
                      'format.scale = window.screen.scale',
                      'host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)',
                      '"drawHierarchyReturned": drawn', '"hostingViewIsWindowBounded": true',
                      '"realOnboardingCoverage": false', '"stitchedOrScaledAcceptance": false',
                      'container.removeFromSuperview()']:
            self.assertIn(token, self.source)
        for forbidden in ['layer.render(', 'resizableSnapshotView', 'host.sizeThatFits(',
                          '"oversizedComponentCanvasNotOnboarding": true']:
            self.assertNotIn(forbidden, self.source)

    def test_source_geometry_drives_bounded_grid_and_native_offsets_are_verified(self):
        for token in ['ScrollView([.horizontal, .vertical]) { content }', '.scrollPosition($model.position)',
                      '.onScrollGeometryChange(for: ScrollGeometry.self)',
                      'model.position.scrollTo(x: target.x, y: target.y)',
                      '"plain-native-scroll-geometry-not-image-data"', '"actualScrollGeometry"',
                      '"requestedOrClampedOffsetReached": reached', '"nativeScrollSettled": didSettle',
                      '"geometryUnchangedDuringCapture": unchanged', '"nativeContainerMatchesHost": viewportMatches',
                      '"everySourceCellVisible": covered', 'XCTAssertTrue(covered,',
                      '"coverageRequiredForReference": isPlain', '"planAlwaysDerivedFromPlain": true',
                      'points.count < 64', 'xs.count * ys.count <= 64', 'never truncate coverage',
                      'reference.geometry == raster.geometry && reference.requested == raster.requested']:
            self.assertIn(token, self.source)
        self.assertIn('"visibleRect": rect(value.visibleRect)', self.source)
        self.assertNotIn('XCTAssertTrue(sameGeometry', self.source)

    def test_exact_outcomes_are_evidence_not_mutually_incompatible_acceptance_gates(self):
        for token in ['reference.bitmap.width == actual.width && reference.bitmap.height == actual.height',
                      'reference.bitmap.rgba == actual.rgba', '"sameBackendOnly": true',
                      '"sameRGBA": same', '"changedRGBABytes": changed',
                      '"coordinateEquivalentComparison": valid && sameGeometry',
                      '"productionEligibilityClaim": false', '"comparisonIsDiagnosticOnly": true',
                      'XCTAssertTrue(raster.valid,', 'XCTAssertGreaterThan(actual.inkCount, 100',
                      '"registrationOrTolerance": false', 'XCTAttachment(image: raster.image)',
                      'XCTAttachment(data: data, uniformTypeIdentifier: "public.json")',
                      'SHA256.hash(data: data)', '"declaredSourceSHAIsIndependentlyVerified": false',
                      'private let lock = NSLock()', 'lock.lock()', 'defer { lock.unlock() }',
                      'if validReference { baseline = references }', '"invalidBaseline"',
                      '"inkBoundsPixels"', '"visibleReservedContentPixels"', '"reservedContainsVisibleInk"',
                      'value.isFinite ? Double(value) as Any : String(describing: value)']:
            self.assertIn(token, self.source)
        for forbidden in ['XCTAssertTrue(same,', 'accuracy:', 'changed <=', 'changed <', 'XCTExpectFailure']:
            self.assertNotIn(forbidden, self.source)
        self.assertIn('XCTFail("Geometry evidence must serialize:', self.source)

    def test_original_native_acceptance_is_separate_strict_and_still_has_negative_controls(self):
        acceptance = (ROOT / 'ios/TimbreAppTests/WelcomeHeadlineLayoutTests.swift').read_text()
        for token in ['[CGFloat(280), 335, 362, 390]', 'DynamicTypeSize.large, .accessibility5',
                      'XCTAssertEqual(samples, 8', 'expected.rgba == actual.rgba',
                      'contains(native.bounds)', 'XCTAssertFalse(even.touches(odd)',
                      'XCTAssertTrue(masks.even.touches(masks.odd)', 'testNonUrduHeadlinePixelsRemainUnchangedIncludingTamil']:
            self.assertIn(token, acceptance)
        self.assertNotIn('WelcomeRendererGeometryTests', acceptance)
        self.assertNotIn('XCTSkip', acceptance)


if __name__ == '__main__':
    unittest.main()
