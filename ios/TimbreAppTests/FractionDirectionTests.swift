import SwiftUI
import UIKit
import XCTest
@testable import Timbre

@MainActor
final class FractionDirectionTests: XCTestCase {
    func testProgressFractionKeepsTheSameNumericOrderInBothLayoutDirections() throws {
        for locale in ["ar_SA", "fa_IR", "he_IL", "en_US"] {
            for counts in [(3, 6), (12, 34)] {
                let leftToRight = try render(counts.0, counts.1, locale: locale, direction: .leftToRight)
                let rightToLeft = try render(counts.0, counts.1, locale: locale, direction: .rightToLeft)
                let changed = zip(leftToRight, rightToLeft).filter { $0 != $1 }.count
                XCTAssertEqual(leftToRight, rightToLeft,
                               "The completed/total order must stay intact in \(locale): \(counts.0)/\(counts.1); \(changed) canonical RGBA channel bytes differ")
            }
        }
    }

    func testDirectionFixDoesNotCollapseDifferentProgressValues() throws {
        let threeOfSix = try render(3, 6, locale: "ar_SA", direction: .rightToLeft)
        let sixOfThree = try render(6, 3, locale: "ar_SA", direction: .rightToLeft)
        XCTAssertNotEqual(threeOfSix, sixOfThree)
    }

    private func render(_ done: Int, _ total: Int, locale: String, direction: LayoutDirection) throws -> Data {
        let content = Text.fraction(done, total)
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(Color.black)
            .frame(width: 240, height: 64)
            .background(Color.white)
            .environment(\.locale, Locale(identifier: locale))
            .environment(\.layoutDirection, direction)
            .environment(\.dynamicTypeSize, .large)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.isOpaque = true
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = "fraction-\(locale)-\(done)-\(total)-\(direction == .leftToRight ? "ltr" : "rtl")"
        attachment.lifetime = .keepAlways
        add(attachment)
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width, height = cgImage.height
        XCTAssertEqual(width, 240)
        XCTAssertEqual(height, 64)
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        var pixels = Data(count: width * height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: width, height: height,
                                                 bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace,
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.interpolationQuality = .none
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        }
        return pixels
    }
}
