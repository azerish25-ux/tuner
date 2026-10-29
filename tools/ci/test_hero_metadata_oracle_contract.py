#!/usr/bin/env python3
"""Source guards for a native-baseline bidi oracle, not a substitute for native RGBA comparisons."""
import hashlib
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'ios/TimbreAppTests/SongHeroMetadataTests.swift').read_text()


class HeroMetadataOracleContractTests(unittest.TestCase):
    def test_all_eight_literal_oracle_comparisons_and_value_order_negatives_remain_exact(self):
        whole = SOURCE.split('func testArabicAndEnglishWholeFieldRendering', 1)[1].split('func testDefaultEnglishPixels', 1)[0]
        for token in ['for fixture in fixtures', 'LayoutDirection.leftToRight, .rightToLeft',
                      'DynamicTypeSize.large, .accessibility5', 'let oracle = Text(verbatim:',
                      'let wrongGroup = Text(verbatim:', 'let wrongValue = Text(verbatim:',
                      'XCTAssertEqual(actual, expected', 'XCTAssertNotEqual(actual, negative',
                      'XCTAssertNotEqual(actual, try pixels(wrongGroup',
                      'XCTAssertNotEqual(actual, try pixels(wrongValue']:
            self.assertIn(token, whole)
        self.assertEqual(whole.count('alignment: .firstTextBaseline'), 5)
        self.assertIn('language: "en", locale: "en_US", length: "2:36", reward: "+30 XP"', SOURCE)
        self.assertIn('language: "ar", locale: "ar_SA", length: "٢:٣٦", reward: "+٣٠ XP"', SOURCE)
        oracle = whole.split('let oracle = ', 1)[1].split('\n', 1)[0]
        self.assertIn(r'\u{2066}\(fixture.reward)\u{2069}', oracle)
        self.assertNotIn('HeroMetadata', oracle)
        self.assertNotIn('.visual', oracle)
        self.assertNotIn('.spoken', oracle)

    def test_native_baseline_is_source_defined_before_render_with_unchanged_size_proposal(self):
        canvas = SOURCE.split('private struct BaselineCanvas: Layout', 1)[1].split('private func pixels', 1)[0]
        for token in ['CGSize(width: 1200, height: 180)', 'subviews.count == 1',
                      'let childProposal = ProposedViewSize(width: 1200, height: 180)',
                      'subviews[0].dimensions(in: childProposal)',
                      'let baseline: CGFloat = dimensions[.firstTextBaseline]',
                      'let baselineY: CGFloat = bounds.minY + 120',
                      'let top: CGFloat = baselineY - baseline', '.allSatisfy(\\.isFinite)',
                      'dimensions.width <= bounds.width', 'top >= bounds.minY',
                      'top + dimensions.height <= bounds.maxY',
                      'CGPoint(x: bounds.midX, y: top), anchor: .top, proposal: childProposal',
                      'HERO-METADATA-LAYOUT:']:
            self.assertIn(token, canvas)
        for forbidden in ['ImageRenderer', 'cgImage', 'Data(', '.offset(', 'round(', 'ceil(', 'floor(',
                          'rightToLeft', 'fixture', 'HeroMetadata', 'firstTextBaseline] + 1']:
            self.assertNotIn(forbidden, canvas)

    def test_centered_english_regression_is_unchanged_and_remains_default(self):
        body = SOURCE.split('    func testDefaultEnglishPixelsAndCalmModeDoNotChange()', 1)[1]
        body = body.split('    func testCalmArabicKeepsOnlyTheOriginalDuration()', 1)[0]
        self.assertEqual(hashlib.sha256(body.encode()).hexdigest(),
                         '776624a54ccf7a03c35cf8b31cdf109735690cd659cea7d3d2c9232cd143baa9')
        helper = SOURCE.split('private func pixels<', 1)[1].split('private func raster<', 1)[0]
        self.assertIn('alignment: RasterAlignment = .centered', helper)
        self.assertIn('case .centered:', helper)
        self.assertIn('styled.frame(width: 1200, height: 180).background(Color.white)', helper)
        self.assertIn('BaselineCanvas(name: name) { styled }.background(Color.white)', helper)
        self.assertNotIn('AnyView', helper)

    def test_canonical_rgba_path_stays_identical_and_translation_negatives_are_explicit(self):
        raster = SOURCE.split('        let renderer = ImageRenderer(content: view)', 1)[1]
        self.assertEqual(hashlib.sha256(raster.encode()).hexdigest(),
                         '07b194f21b21db4baac051de2d791b5372e302ead824cddfc5ebb94f060026c0')
        negative = SOURCE.split('func testBaselineOracleRejectsOnePointDrawingDisplacement()', 1)[1]
        negative = negative.split('private func positions(', 1)[0]
        for token in ['for fixture in fixtures', 'LayoutDirection.leftToRight, .rightToLeft',
                      'DynamicTypeSize.large, .accessibility5', 'literal.offset(x: 1)', 'literal.offset(y: 1)',
                      'XCTAssertNotEqual(expected, shiftedX', 'XCTAssertNotEqual(expected, shiftedY']:
            self.assertIn(token, negative)
        self.assertEqual(negative.count('alignment: .firstTextBaseline'), 3)
        for forbidden in ['XCTSkip', 'accuracy:', 'minimumScaleFactor', 'pngData()', 'cropping(to:', 'abs(']:
            self.assertNotIn(forbidden, SOURCE)

    def test_core_text_position_oracle_is_still_separate_from_swiftui_layout(self):
        method = SOURCE.split('func testIndependentGlyphPositionsKeepRewardTogetherAndRejectOldArabicOrder()', 1)[1]
        method = method.split('func testBaselineOracleRejectsOnePointDrawingDisplacement()', 1)[0]
        for token in ['XCTAssertLessThan(sign, digits)', 'XCTAssertLessThan(digits, unit',
                      'XCTAssertLessThan(duration, sign)', 'XCTAssertGreaterThan(duration, unit)',
                      'let old = "· ٢:٣٦ · +٣٠ XP"', 'XCTAssertGreaterThan(try location']:
            self.assertIn(token, method)
        self.assertNotIn('BaselineCanvas', method)
        self.assertNotIn('pixels(', method)


if __name__ == '__main__':
    unittest.main()
