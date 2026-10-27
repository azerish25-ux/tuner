import SwiftUI
import UIKit
import XCTest
@testable import Timbre

/// Render the production component, not a replica of its paint. Native execution remains required.
@MainActor
final class PaywallOfferRenderingTests: XCTestCase {
    func testSavingUsesFlatOpaqueGoldAndTrialRemainsMintWithIdenticalGeometry() throws {
        for size in [DynamicTypeSize.large, .accessibility5] {
            let saving = try render(trial: false, size: size)
            let trial = try render(trial: true, size: size)
            XCTAssertEqual(saving.width, trial.width)
            XCTAssertEqual(saving.height, trial.height)
            XCTAssertGreaterThan(saving.width, 20)
            XCTAssertGreaterThan(saving.height, 6)
            XCTAssertLessThanOrEqual(saving.width, 180)
            for (image, expected, ink) in [(saving, [255, 208, 138], [27, 18, 6]),
                                            (trial, [76, 242, 184], [4, 19, 13])] {
                let pixels = try rgba(image)
                var flatBackingPixels = 0
                var inkPixels = 0
                for offset in stride(from: 0, to: pixels.count, by: 4) {
                    if (0..<3).allSatisfy({ abs(Int(pixels[offset + $0]) - ink[$0]) <= 8 }) {
                        inkPixels += 1
                    }
                    if (0..<3).allSatisfy({ abs(Int(pixels[offset + $0]) - expected[$0]) <= 2 })
                        && pixels[offset + 3] == 255 {
                        flatBackingPixels += 1
                    }
                }
                // A solid backing occupies most of the actual badge; the old gradient has only a thin
                // matching strip at its top. Transparent margins are excluded from the denominator.
                let opaquePixels = stride(from: 3, to: pixels.count, by: 4)
                    .filter { pixels[$0] == 255 }.count
                XCTAssertGreaterThan(opaquePixels, 100)
                XCTAssertGreaterThan(inkPixels, 3, "The actual offer text must render, not only its backing")
                XCTAssertGreaterThan(Double(flatBackingPixels) / Double(opaquePixels), 0.5)
            }
        }
    }

    private func render(trial: Bool, size: DynamicTypeSize) throws -> CGImage {
        let renderer = ImageRenderer(content:
            PaywallOfferBadge(text: "SAVE 58%", trial: trial, identity: "paywall.plan.yearly.saving")
                .frame(maxWidth: 180)
                .fixedSize(horizontal: true, vertical: true)
                .environment(\.locale, Locale(identifier: "en_US"))
                .environment(\.dynamicTypeSize, size)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = "offer-\(trial ? "trial" : "saving")-\(size)"
        attachment.lifetime = .keepAlways
        add(attachment)
        return try XCTUnwrap(image.cgImage)
    }

    private func rgba(_ image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: image.width,
                height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
        }
        return pixels
    }
}
