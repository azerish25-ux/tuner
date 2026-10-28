"""Only two exact callback identities may receive independent raster proof; all other audits stay enforced."""
from pathlib import Path
import hashlib
import json
import struct
import unittest
ROOT = Path(__file__).resolve().parents[2]
class PixelProofContract(unittest.TestCase):
    def test_reviewed_practice_references_bind_only_exact_native_states_and_influencing_source(self):
        manifest = json.loads((ROOT / 'docs/ios/readiness/reviews/practice-level-native-reference.json').read_text())
        self.assertEqual(manifest['schema'], 1)
        self.assertEqual(manifest['viewport'], [0, 0, 402, 874])
        self.assertEqual(manifest['image_pixels'], [1206, 2622])
        self.assertEqual({r['identifier'] for r in manifest['references']},
                         {'screen.header.level.mark', 'practice.level.card.mark'})
        self.assertEqual(len(manifest['references']), 2)
        self.assertEqual(set(manifest['source_sha256']), {
            'ios/Timbre/Design/GameUI.swift', 'ios/Timbre/Design/Theme.swift',
            'ios/Timbre/Design/Components.swift', 'ios/Timbre/Design/Kit.swift',
            'ios/Timbre/Practice/PracticeView.swift', 'ios/Timbre/Practice/PracticeChrome.swift',
            'ios/Timbre/Root/RootView.swift'})
        source = (ROOT / 'ios/TimbreUITests/ReviewedPracticeLevelRaster.swift').read_text()
        self.assertEqual(source.count('Reference(identifier:'), 2)
        for reference in manifest['references']:
            self.assertEqual(reference['screen'], 'tab-4-practice')
            self.assertEqual(reference['label'], 'LV 1')
            self.assertGreaterEqual(reference['conservative_minimum_contrast'], 5.0)
            raw = (ROOT / reference['path']).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(), reference['png_sha256'])
            self.assertEqual(list(struct.unpack('>II', raw[16:24])), reference['pixels'])
            self.assertIn(reference['png_sha256'], source)
        for path, digest in manifest['source_sha256'].items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), digest, path)
        for guard in ['frame == reference.frame', 'viewport == CGRect', 'image.imageOrientation == .up',
                      'source.width == 1206, source.height == 2622', 'actualPixels == expectedPixels',
                      'guard staticText, stable', 'SHA256.hash(data: data)']:
            self.assertIn(guard, source)
        audit = (ROOT / 'ios/TimbreUITests/AccessibilityAuditUITests.swift').read_text()
        for guard in ['let after = try? element.snapshot()', 'after.frame == before.frame',
                      'after.elementType == before.elementType', 'staticText: before.elementType == .staticText']:
            self.assertIn(guard, audit)

    def test_practice_source_bounds_exceed_body_text_contrast_even_with_linear_light_blending(self):
        def linear(value):
            value /= 255
            return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
        def luminance(rgb):
            return sum(weight * linear(value) for weight, value in zip((.2126, .7152, .0722), rgb))
        mint, ink = luminance((76, 242, 184)), luminance((245, 243, 239))
        header_backing = .85 * luminance((6, 7, 8)) + .15 * luminance((255, 196, 140))
        for paint in (mint, ink):
            self.assertGreater((paint + .05) / (header_backing + .05), 5.0)
        # The reviewed native card geometry fixes the maximal tint under the complete text crop.
        width, height, x, half_text_height = 362, 98, 32 + 2 / 3, 14
        t = (2 * width * x + height ** 2 - 2 * half_text_height * height) / (width ** 2 + height ** 2)
        alpha = .16 * (1 - t)
        card_backing = (1 - alpha) * luminance((17, 19, 23)) + alpha * mint
        for paint in (mint, ink):
            self.assertGreater((paint + .05) / (card_backing + .05), 5.0)
        self.assertGreater(t, .2169)
        self.assertLess(alpha, .1253)
        derivative_at_minimum = (2 * height * (width ** 2 - 2 * width * x)
                                 + 2 * half_text_height * (height ** 2 - width ** 2))
        self.assertGreater(derivative_at_minimum, 0)
        self.assertGreater(width ** 2 - 2 * width * x, 0)
        self.assertIn('-only-testing:TimbreUITests/ReviewedPracticeLevelRasterTests',
                      (ROOT / '.github/workflows/ios.yml').read_text())

    def test_exact_scope_and_callback_capture(self):
        source = (ROOT / 'ios/TimbreUITests/AccessibilityAuditUITests.swift').read_text()
        self.assertIn('issue.auditType == .contrast, snapshot?.elementType == .staticText', source)
        self.assertIn('screen == "settings" && id == "settings.notation.title" && label == "Note names"', source)
        self.assertIn('screen == "paywall" && id == "paywall.plan.yearly.saving" && label == "SAVE 58%"', source)
        self.assertIn('frame: frame, viewport: viewport, image: capture.image', source)
        self.assertIn('evidence.lifetime = .keepAlways', source)
        self.assertIn('callbackScreenshot ?? XCUIScreen.main.screenshot()', source)
        proof = (ROOT / 'ios/TimbreUITests/AuditContrastPixelProof.swift').read_text()
        self.assertEqual(proof.count('case ("'), 2)
        self.assertIn('let viewport = app.frame', source)
        self.assertIn('CGFloat(source.width) / viewport.width', proof)
        self.assertNotIn(' / image.size', proof)
        for token in ['default: return nil', 'ratio >= 4.5', 'viewport.contains(frame)', 'image.imageOrientation == .up',
                      'foreground) / Double(total) >= 0.05', 'background) / Double(total) >= 0.45',
                      'interpolated) / Double(total) >= 0.95', '(6...30).contains(components)']:
            self.assertIn(token, proof)
    def test_native_negative_controls_are_selected(self):
        native = (ROOT / 'ios/TimbreUITests/AuditContrastPixelProofTests.swift').read_text()
        for token in ['wrong.identifier', 'Different text', 'UIColor(white: 0.13', 'text: ""', 'solidPatch: true',
                      'x: -1', 'x: 190', 'y: 52', 'label: "SAVE 60%"', 'scale: 1, orientation: .up', 'orientation: .right', 'viewport: wrongViewport']:
            self.assertIn(token, native)
        self.assertIn('-only-testing:TimbreUITests/AuditContrastPixelProofTests',
                      (ROOT / '.github/workflows/ios.yml').read_text())
if __name__ == '__main__': unittest.main()
