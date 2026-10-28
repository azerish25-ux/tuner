"""Static RTL fade guards; the actual native geometry and raster tests remain mandatory."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
FADE = (ROOT / 'ios/Timbre/Design/EdgeFade.swift').read_text()
CHROME = (ROOT / 'ios/Timbre/Practice/PracticeChrome.swift').read_text()
NATIVE = (ROOT / 'ios/TimbreAppTests/EdgeFadeDirectionTests.swift').read_text()

class EdgeFadeDirectionTests(unittest.TestCase):
    def test_all_geometry_callers_supply_direction(self):
        self.assertIn('EdgeOverflow(content: proxy, direction: direction)', CHROME)
        self.assertIn('EdgeOverflow(geometry, direction: direction)', CHROME)
        self.assertIn('EdgeOverflow(geometry, direction: direction)', FADE)
        self.assertNotIn('EdgeOverflow(geometry)', CHROME + FADE)
        self.assertIn('viewportSize: geometry.visibleRect.size', FADE)
        self.assertIn('direction == .rightToLeft ? -insets.trailing : insets.leading', FADE)
        self.assertIn('self.init(leading: progress > 1, trailing: progress < range - 1)', FADE)
        self.assertIn('guard range > 1 else { self.init(); return }', FADE)

    def test_physical_mask_does_not_invert_with_semantic_hstack(self):
        mask = FADE.split('struct EdgeFadeMask: View {', 1)[1].split('extension View {', 1)[0]
        for token in ['rtl ? overflow.trailing : overflow.leading', 'rtl ? overflow.leading : overflow.trailing',
                      'rtl ? trailing : leading', 'rtl ? leading : trailing',
                      '.environment(\\.layoutDirection, .leftToRight)',
                      'UnitPoint(x: fromLeft ? 0 : 1, y: 0.5)', 'UnitPoint(x: fromLeft ? 1 : 0, y: 0.5)']:
            self.assertIn(token, mask)
        self.assertNotIn('startPoint: fromLeading ? .leading', mask)
        self.assertIn('3 - 2 * t', mask)

    def test_native_proves_geometry_ramps_and_negative_control(self):
        for token in ['testLiveScrollGeometryReportsRestingLeadingEdgeWithoutFade',
                      'UIWindow(windowScene: scene)', 'contentMargins(.trailing, 32',
                      'testUnequalInsetsRestingEndsMiddleAndOverscroll',
                      'testContentGeometryPathHasSameSemanticEndContract',
                      'testNativeMaskKeepsRestingEndOpaqueAndFadesOnlyContinuation',
                      'XCTAssertNotEqual(correct, reversed)', 'XCTAssertEqual(pixels[outer], 255',
                      'XCTAssertLessThan(pixels[outer], pixels[inner])',
                      'XCTAssertFalse(overflow.leading', 'XCTAssertTrue(overflow.trailing',
                      'geometry.containerSize.width, 248, accuracy: 1', 'geometry.visibleRect.width - 300',
                      'geometry.contentOffset.x, direction == .rightToLeft ? 32 : -20',
                      '(11, UnitPoint.trailing', '(0, UnitPoint.leading',
                      'XCTAssertEqual(actual, EdgeOverflow(viewport: viewport']:
            self.assertIn(token, NATIVE)
        self.assertNotIn('XCTSkip', NATIVE)
        self.assertNotIn('geometry.containerSize.width >= 300', NATIVE)

    def test_observed_native_endpoints_do_not_double_count_margins(self):
        # Independent replay of native initial measurements, not a substitute for the live
        # first/middle/last oracle that must establish the platform's RTL progress direction.
        for raw_offset, resting_offset in [(-20, -20), (32, 32)]:
            progress = raw_offset - resting_offset
            total_travel = 1288 + 20 + 32 - 300
            self.assertEqual(total_travel, 1040)
            self.assertEqual((progress > 1, progress < total_travel - 1), (False, True))
        self.assertEqual(248 + 20 + 32, 300)

if __name__ == '__main__':
    unittest.main()
