"""Only two exact callback identities may receive independent raster proof; all other audits stay enforced."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
class PixelProofContract(unittest.TestCase):
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
