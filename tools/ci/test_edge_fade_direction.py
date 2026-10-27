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
        self.assertIn('direction == .rightToLeft ? geometry.contentInsets.trailing : geometry.contentInsets.leading', FADE)
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
                      'XCTAssertFalse(overflow.leading', 'XCTAssertTrue(overflow.trailing']:
            self.assertIn(token, NATIVE)
        self.assertNotIn('XCTSkip', NATIVE)

if __name__ == '__main__':
    unittest.main()
