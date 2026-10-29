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

    /// An independent operand oracle: known numeral glyphs, not Text.fraction or localized integer
    /// interpolation. Separate verbatim templates are physically placed numerator, slash, denominator.
    /// Direction equality alone cannot detect two identically reversed outputs.
    func testRenderedOperandsMatchIndependentPhysicalOrderOracle() throws {
        let digits = ["ar_SA": "٠١٢٣٤٥٦٧٨٩", "fa_IR": "۰۱۲۳۴۵۶۷۸۹",
                      "he_IL": "0123456789", "en_US": "0123456789"]
        for locale in ["ar_SA", "fa_IR", "he_IL", "en_US"] {
            let alphabet = Array(try XCTUnwrap(digits[locale]))
            func numeral(_ value: Int) throws -> String {
                try String(String(value).map { character in
                    let digit = try XCTUnwrap(character.wholeNumberValue, "Expected a nonnegative decimal test operand")
                    let glyph = try XCTUnwrap(alphabet.indices.contains(digit) ? alphabet[digit] : nil,
                                              "Independent numeral alphabet has no digit \(digit)")
                    return glyph
                })
            }
            for (done, total) in [(3, 6), (12, 34)] {
                let doneDigits = try numeral(done)
                let totalDigits = try numeral(total)
                let expected = HStack(spacing: 0) {
                    Text(verbatim: doneDigits).lineLimit(1)
                    Text(verbatim: "\u{2009}/\u{2009}").lineLimit(1)
                    Text(verbatim: totalDigits).lineLimit(1)
                }
                .environment(\.layoutDirection, .leftToRight)
                let expectedPixels = try renderView(expected, locale: locale, direction: .leftToRight,
                                                    name: "oracle-\(locale)-\(done)-\(total)")
                let swapped = HStack(spacing: 0) {
                    Text(verbatim: totalDigits).lineLimit(1)
                    Text(verbatim: "\u{2009}/\u{2009}").lineLimit(1)
                    Text(verbatim: doneDigits).lineLimit(1)
                }
                .environment(\.layoutDirection, .leftToRight)
                let swappedPixels = try renderView(swapped, locale: locale, direction: .leftToRight,
                                                   name: "swapped-oracle-\(locale)-\(done)-\(total)")
                XCTAssertNotEqual(expectedPixels, swappedPixels, "The independent templates must distinguish operand order")
                for direction in [LayoutDirection.leftToRight, .rightToLeft] {
                    let actual = try render(done, total, locale: locale, direction: direction)
                    XCTAssertEqual(actual, expectedPixels,
                                   "Expected localized numerator physically left and denominator right: \(locale) \(done)/\(total)")
                    XCTAssertNotEqual(actual, swappedPixels, "Reversed operands must never pass")
                }
            }
        }
    }

    /// Match the actual Daily Set's 28-point interior at normal and AX5 requests (its numeral caps at xxxLarge).
    /// The outer white canvas does not clip to 28 points, so overflowing ink cannot quietly pass.
    func testCompactRingCounterStaysInsideItsInteriorAtNormalAndAXSizes() throws {
        let templates = [("ar_SA", "٣", "٦"), ("fa_IR", "۳", "۶"),
                         ("he_IL", "3", "6"), ("en_US", "3", "6")]
        for (locale, numerator, denominator) in templates {
            for size in [DynamicTypeSize.large, .accessibility5] {
                let expected = HStack(spacing: 0) {
                    Text(verbatim: numerator).lineLimit(1)
                    Text(verbatim: "\u{2009}/\u{2009}").lineLimit(1)
                    Text(verbatim: denominator).lineLimit(1)
                }
                .environment(\.layoutDirection, .leftToRight)
                let swapped = HStack(spacing: 0) {
                    Text(verbatim: denominator).lineLimit(1)
                    Text(verbatim: "\u{2009}/\u{2009}").lineLimit(1)
                    Text(verbatim: numerator).lineLimit(1)
                }
                .environment(\.layoutDirection, .leftToRight)
                let suffix = "\(locale)-\(size)"
                let actualPixels = try renderView(compact(Text.fraction(3, 6), size: size),
                                                  locale: locale, direction: .rightToLeft, name: "compact-actual-" + suffix)
                let expectedPixels = try renderView(compact(expected, size: size),
                                                    locale: locale, direction: .rightToLeft, name: "compact-oracle-" + suffix)
                let swappedPixels = try renderView(compact(swapped, size: size),
                                                   locale: locale, direction: .rightToLeft, name: "compact-swapped-" + suffix)
                XCTAssertEqual(actualPixels, expectedPixels, "Compact counter must keep the known full operand templates")
                XCTAssertNotEqual(actualPixels, swappedPixels, "Compact operand order must remain distinguishable")
                XCTAssertTrue(try inkFitsInterior(actualPixels), "Counter ink must fit the actual 28-point interior: " + suffix)
            }
        }
        // A deliberately unshrinkable operand proves the bounds detector rejects the original overflow mechanism.
        let oversized = Text(verbatim: "123 / 456").font(.system(size: 32, weight: .bold))
            .fixedSize().frame(width: 28)
        let negative = try renderView(oversized, locale: "en_US", direction: .leftToRight, name: "compact-overflow-control")
        XCTAssertFalse(try inkFitsInterior(negative), "The negative control must extend outside the intended interior")
    }

    private func compact<Content: View>(_ content: Content, size: DynamicTypeSize) -> some View {
        content.font(Typeface.number(.caption))
            .heroNumeral(cap: .xxxLarge, minimumScale: 0.5)
            .frame(width: 28)
            .environment(\.dynamicTypeSize, size)
    }

    private func inkFitsInterior(_ pixels: Data) throws -> Bool {
        let bytes = [UInt8](pixels)
        var columns: [Int] = []
        for y in 0..<64 {
            for x in 0..<240 {
                let offset = (y * 240 + x) * 4
                if bytes[offset] < 250 || bytes[offset + 1] < 250 || bytes[offset + 2] < 250 {
                    columns.append(x)
                }
            }
        }
        let left = try XCTUnwrap(columns.min(), "The operand render must contain ink")
        let right = try XCTUnwrap(columns.max(), "The operand render must contain ink")
        return left >= 106 && right < 134
    }

    private func render(_ done: Int, _ total: Int, locale: String, direction: LayoutDirection) throws -> Data {
        try renderView(Text.fraction(done, total), locale: locale, direction: direction,
                       name: "fraction-\(locale)-\(done)-\(total)-\(direction == .leftToRight ? "ltr" : "rtl")")
    }

    private func renderView<Content: View>(_ view: Content, locale: String,
                                          direction: LayoutDirection, name: String) throws -> Data {
        let content = view
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
        attachment.name = name
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
