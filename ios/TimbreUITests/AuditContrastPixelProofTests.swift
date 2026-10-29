import UIKit
import XCTest

@MainActor
final class AuditContrastPixelProofTests: XCTestCase {
    private let viewport = CGRect(x: 0, y: 0, width: 200, height: 80)
    private let target = CGRect(x: 20, y: 20, width: 110, height: 24)
    private let ink = UIColor(red: 245/255, green: 243/255, blue: 239/255, alpha: 1)
    private let backing = UIColor(red: 17/255, green: 19/255, blue: 23/255, alpha: 1)

    func testActualHighContrastGlyphsPassAndUnknownIdentityFails() throws {
        let image = render()
        let proof = try XCTUnwrap(verify(image))
        XCTAssertGreaterThan(proof.ratio, 15)
        XCTAssertGreaterThan(proof.foregroundPixels, 100)
        XCTAssertNil(AuditContrastPixelProof.verify(screen: "songs", identifier: "settings.notation.title",
            label: "Note names", frame: target, viewport: viewport, image: image))
        XCTAssertNil(AuditContrastPixelProof.verify(screen: "settings", identifier: "wrong.identifier",
            label: "Note names", frame: target, viewport: viewport, image: image))
        XCTAssertNil(AuditContrastPixelProof.verify(screen: "settings", identifier: "settings.notation.title",
            label: "Different text", frame: target, viewport: viewport, image: image))
    }

    func testLowContrastAbsentGlyphsWrongFrameAndSolidPatchFailClosed() {
        XCTAssertNil(verify(render(color: UIColor(white: 0.13, alpha: 1))))
        XCTAssertNil(verify(render(text: "")))
        XCTAssertNil(verify(render(solidPatch: true)))
        XCTAssertNil(verify(render(), frame: CGRect(x: 20, y: 52, width: 110, height: 24)))
        XCTAssertNil(verify(render(), frame: CGRect(x: -1, y: 20, width: 110, height: 24)))
        XCTAssertNil(verify(render(), frame: CGRect(x: 190, y: 20, width: 110, height: 24)))
    }

    func testSavingProofIsRestrictedToItsExactReviewedValue() throws {
        let gold = UIColor(red: 255/255, green: 208/255, blue: 138/255, alpha: 1)
        let dark = UIColor(red: 27/255, green: 18/255, blue: 6/255, alpha: 1)
        let image = render(text: "SAVE 58%", color: dark, background: gold)
        let proof = try XCTUnwrap(AuditContrastPixelProof.verify(screen: "paywall",
            identifier: "paywall.plan.yearly.saving", label: "SAVE 58%", frame: target, viewport: viewport, image: image))
        XCTAssertGreaterThan(proof.ratio, 12)
        XCTAssertNil(AuditContrastPixelProof.verify(screen: "paywall", identifier: "paywall.plan.yearly.saving",
            label: "SAVE 60%", frame: target, viewport: viewport, image: image))
        XCTAssertNil(AuditContrastPixelProof.verify(screen: "paywall", identifier: "paywall.plan.yearly.saving",
            label: "SAVE 58%", frame: target, viewport: viewport, image: render(text: "")))
    }

    func testRawPixelScaleMetadataIsIgnoredButRotatedOrWrongViewportFails() throws {
        let original = render()
        let source = try XCTUnwrap(original.cgImage)
        let raw = UIImage(cgImage: source, scale: 1, orientation: .up)
        XCTAssertNotEqual(raw.size, original.size)
        XCTAssertNotNil(verify(raw), "Map physical screen points using the explicit viewport, not UIImage.scale")
        let rotated = UIImage(cgImage: source, scale: 1, orientation: .right)
        XCTAssertNil(verify(rotated))
        for wrongViewport in [CGRect(x: 0, y: 0, width: 80, height: 200),
                              CGRect(x: 0, y: 0, width: 100, height: 80),
                              CGRect(x: 1, y: 0, width: 200, height: 80)] {
            XCTAssertNil(AuditContrastPixelProof.verify(screen: "settings", identifier: "settings.notation.title",
                label: "Note names", frame: target, viewport: wrongViewport, image: raw))
        }
    }

    private func verify(_ image: UIImage, frame: CGRect? = nil) -> AuditContrastPixelProof.Proof? {
        AuditContrastPixelProof.verify(screen: "settings", identifier: "settings.notation.title",
                                       label: "Note names", frame: frame ?? target, viewport: viewport, image: image)
    }

    private func render(text: String = "Note names", color: UIColor? = nil,
                        background: UIColor? = nil, solidPatch: Bool = false) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3; format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 200, height: 80), format: format).image { context in
            (background ?? self.backing).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 80))
            if solidPatch {
                self.ink.setFill()
                context.fill(CGRect(x: 23, y: 23, width: 90, height: 8))
            } else {
                (text as NSString).draw(at: self.target.origin,
                    withAttributes: [.font: UIFont.systemFont(ofSize: 17), .foregroundColor: color ?? self.ink])
            }
        }
    }
}
