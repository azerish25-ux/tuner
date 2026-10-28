import UIKit
import XCTest

@MainActor
final class ReviewedPracticeLevelRasterTests: XCTestCase {
    private let viewport = CGRect(x: 0, y: 0, width: 402, height: 874)

    func testExactNativeReferencesRequireTheirReviewedIdentityPoseTypeAndStableCapture() throws {
        for reference in ReviewedPracticeLevelRaster.references {
            let image = try canvas(reference)
            XCTAssertNotNil(verify(reference, image))
            XCTAssertNil(verify(reference, image, screen: "tab-2-learn"))
            XCTAssertNil(verify(reference, image, identifier: "foreign"))
            XCTAssertNil(verify(reference, image, label: "LV 2"))
            XCTAssertNil(verify(reference, image, frame: reference.frame.offsetBy(dx: CGFloat(1) / 3, dy: 0)))
            XCTAssertNil(verify(reference, image, staticText: false))
            XCTAssertNil(verify(reference, image, stable: false))
            XCTAssertNil(ReviewedPracticeLevelRaster.verify(screen: "tab-4-practice", identifier: reference.identifier,
                label: "LV 1", frame: reference.frame, viewport: viewport.offsetBy(dx: 1, dy: 0),
                image: image, staticText: true, stable: true))
            let rotated = UIImage(cgImage: try XCTUnwrap(image.cgImage), scale: 1, orientation: .right)
            XCTAssertNil(verify(reference, rotated))
        }
    }

    func testMissingRecoloredFadedClippedOrObscuredNativePaintIsNotAccepted() throws {
        for reference in ReviewedPracticeLevelRaster.references {
            for mutation in ["missing", "faded", "obscured", "clipped", "recolored"] {
                XCTAssertNil(verify(reference, try canvas(reference, mutation: mutation)), mutation)
            }
            XCTAssertNil(verify(reference, try canvas(reference, scale: 2)))
        }
    }

    private func verify(_ reference: ReviewedPracticeLevelRaster.Reference, _ image: UIImage,
                        screen: String = "tab-4-practice", identifier: String? = nil, label: String = "LV 1",
                        frame: CGRect? = nil, staticText: Bool = true, stable: Bool = true) -> String? {
        ReviewedPracticeLevelRaster.verify(screen: screen, identifier: identifier ?? reference.identifier,
            label: label, frame: frame ?? reference.frame, viewport: viewport, image: image,
            staticText: staticText, stable: stable)
    }

    /// Classifier fixtures only. The retained current callback originals establish the reviewed visual state.
    private func canvas(_ reference: ReviewedPracticeLevelRaster.Reference, mutation: String = "none",
                        scale: CGFloat = 3) throws -> UIImage {
        let native = try XCTUnwrap(ReviewedPracticeLevelRaster.load(reference), "Native reference must be bundled and hash-valid")
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        format.preferredRange = .standard
        let rect = CGRect(x: reference.crop.minX / 3, y: reference.crop.minY / 3,
                          width: reference.crop.width / 3, height: reference.crop.height / 3)
        return UIGraphicsImageRenderer(size: viewport.size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(viewport)
            if mutation != "missing" {
                context.cgContext.interpolationQuality = .none
                UIImage(cgImage: native).draw(in: rect, blendMode: .normal, alpha: mutation == "faded" ? 0.2 : 1)
            }
            if mutation == "obscured" {
                UIColor.white.setFill()
                context.fill(rect)
            } else if mutation == "clipped" {
                UIColor.black.setFill()
                context.fill(CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height))
            } else if mutation == "recolored" {
                UIColor.red.withAlphaComponent(0.4).setFill()
                context.fill(rect)
            }
        }
    }
}
