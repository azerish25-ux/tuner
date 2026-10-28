import SwiftUI
import UIKit
import XCTest
@testable import Timbre

/// The decorative mask is tested independently of the burst's transient animation clock.
/// Full tune-check captures at short phone heights remain required for layout acceptance.
@MainActor
final class TuneCheckRewardBandTests: XCTestCase {
    func testRewardCannotPaintOutsideItsReservedBandAtEitherDisplayScale() throws {
        XCTAssertEqual(TuneCheckStep.chipRewardHeight, 60)
        XCTAssertEqual(TuneCheckStep.chipRewardFade, 8)
        for scale in [2, 3] {
            var baseline: Data?
            for direction in [LayoutDirection.leftToRight, .rightToLeft] {
                for size in [DynamicTypeSize.large, .accessibility5] {
                    // Fully opaque input is stricter than any individual ring/node phase.
                    let actual = try pixels(masked: true, scale: scale, direction: direction, size: size)
                    let side = 140 * scale
                    let start = 40 * scale
                    let end = 100 * scale
                    var insideInk = 0
                    var escapedInk = 0
                    for y in 0..<side {
                        for x in 0..<side {
                            let alpha = actual[(y * side + x) * 4 + 3]
                            if y < start || y >= end {
                                if alpha > 0 { escapedInk += 1 }
                            } else if alpha > 0 { insideInk += 1 }
                        }
                    }
                    XCTAssertEqual(escapedInk, 0, "No decoration may escape the reserved 60-point band")
                    XCTAssertGreaterThan(insideInk, 0, "Do not fix overlap by hiding the reward")
                    XCTAssertEqual(actual[((side / 2) * side + side / 2) * 4 + 3], 255,
                                   "The centre remains fully opaque")
                    let edgeAlpha = actual[((start + 2 * scale) * side + side / 2) * 4 + 3]
                    XCTAssertGreaterThan(edgeAlpha, 0)
                    XCTAssertLessThan(edgeAlpha, 255, "The band edge must fade rather than hard-cut the arcs")
                    if let baseline { XCTAssertEqual(actual, baseline) }
                    else { baseline = actual }
                }
            }
            let unmasked = try pixels(masked: false, scale: scale, direction: .leftToRight, size: .large)
            XCTAssertEqual(unmasked[3], 255, "The negative control must actually paint outside the band")
            XCTAssertNotEqual(unmasked, try XCTUnwrap(baseline))
        }
    }

    private func pixels(masked: Bool, scale: Int, direction: LayoutDirection,
                        size: DynamicTypeSize) throws -> Data {
        let content = Color.red.frame(width: 140, height: 140)
        let image = Group {
            if masked { content.mask { TuneCheckStep.chipRewardMask } }
            else { content }
        }
        .environment(\.layoutDirection, direction)
        .environment(\.dynamicTypeSize, size)
        .environment(\.displayScale, CGFloat(scale))
        let renderer = ImageRenderer(content: image)
        renderer.scale = CGFloat(scale)
        renderer.isOpaque = false
        let cgImage = try XCTUnwrap(renderer.cgImage)
        let side = 140 * scale
        XCTAssertEqual(cgImage.width, side)
        XCTAssertEqual(cgImage.height, side)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        var data = Data(count: side * side * 4)
        try data.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: side, height: side,
                bitsPerComponent: 8, bytesPerRow: side * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.interpolationQuality = .none
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        return data
    }
}
