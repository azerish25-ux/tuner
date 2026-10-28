import CoreText
import SwiftUI
import TimbreCore
import UIKit
import XCTest
@testable import Timbre

@MainActor
final class SettingsOptionLabelTests: XCTestCase {
    override func tearDown() {
        TimbreLocalization.language = TimbreLocalization.system
        super.tearDown()
    }

    func testAllTemperamentOptionsUseExistingTranslationsInEveryAppLanguage() throws {
        XCTAssertEqual(Temperament.all.count, 5)
        for language in Bundle.main.localizations where language != "Base" {
            TimbreLocalization.language = language
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            for temperament in Temperament.all {
                let key = "timbre_bench_temperament_" + temperament.id
                let expected = bundle.localizedString(forKey: key, value: "MISSING_SETTING_TRANSLATION", table: nil)
                XCTAssertNotEqual(expected, "MISSING_SETTING_TRANSLATION", "\(language): \(key)")
                XCTAssertFalse(expected.isEmpty)
                XCTAssertEqual(SettingsOptionLabel.temperamentName(temperament), expected, "\(language): \(key)")
            }
        }
        TimbreLocalization.language = "ar"
        XCTAssertEqual(SettingsOptionLabel.temperamentName(.equal), "متساوي")
        XCTAssertEqual(SettingsOptionLabel.temperamentName(.pythagorean), "فيثاغوري")
        TimbreLocalization.language = TimbreLocalization.system
        XCTAssertEqual(SettingsOptionLabel.temperamentName(.equal),
                       Bundle.main.localizedString(forKey: "timbre_bench_temperament_equal", value: "Equal", table: nil))
    }

    func testPrecisionTokensPreserveEverySignValueAndUnit() {
        let cases: [(TuningPrecision, String)] = [(.beginner, "±5¢"), (.standard, "±3¢"), (.pro, "±1¢")]
        XCTAssertEqual(cases.count, TuningPrecision.allCases.count)
        for (precision, expected) in cases {
            let actual = SettingsOptionLabel.precisionTolerance(precision)
            XCTAssertEqual(actual, "\u{2066}" + expected + "\u{2069}")
            XCTAssertEqual(String(actual.dropFirst().dropLast()), expected)
        }
    }

    /// Inspect physical glyph positions, not another string made with the same bidi controls. The unfixed raw
    /// token is a negative control; surrounding Arabic letters must retain their right-to-left physical order.
    func testPrecisionGlyphOrderInArabicContextHasAnIndependentPositionOracle() throws {
        let cases: [(TuningPrecision, String)] = [(.beginner, "5"), (.standard, "3"), (.pro, "1")]
        for (precision, digit) in cases {
            for size in [CGFloat(17), CGFloat(53)] {
                let isolated = "مبتدئ " + SettingsOptionLabel.precisionTolerance(precision)
                let positions = try glyphPositions(isolated, size: size)
                XCTAssertLessThan(try position("±", in: isolated, positions: positions),
                                  try position(digit, in: isolated, positions: positions))
                XCTAssertLessThan(try position(digit, in: isolated, positions: positions),
                                  try position("¢", in: isolated, positions: positions))
                XCTAssertGreaterThan(try position("م", in: isolated, positions: positions),
                                     try position("ئ", in: isolated, positions: positions), "The Arabic name must not flip")
                let raw = "مبتدئ ±" + digit + "¢"
                let reversed = try glyphPositions(raw, size: size)
                XCTAssertGreaterThan(try position("±", in: raw, positions: reversed),
                                     try position("¢", in: raw, positions: reversed), "The oracle must reject the unfixed token")
            }
        }
    }

    /// Separate verbatim glyphs placed physically from left to right are an independent raster oracle. No isolate
    /// controls or production formatter are used to construct the expected image; swapped glyphs must differ.
    func testPrecisionRendersAllGlyphsInOrderAtNormalAndAX5Sizes() throws {
        for size in [DynamicTypeSize.large, .accessibility5] {
            for digit in ["5", "3", "1"] {
                let precision: TuningPrecision = digit == "5" ? .beginner : (digit == "3" ? .standard : .pro)
                let expected = HStack(spacing: 0) {
                    Text(verbatim: "±")
                    Text(verbatim: digit)
                    Text(verbatim: "¢")
                }.environment(\.layoutDirection, .leftToRight)
                let reversed = HStack(spacing: 0) {
                    Text(verbatim: "¢")
                    Text(verbatim: digit)
                    Text(verbatim: "±")
                }.environment(\.layoutDirection, .leftToRight)
                let oracle = try render(expected, size: size, direction: .rightToLeft, name: "oracle-\(digit)-\(size)")
                let wrong = try render(reversed, size: size, direction: .rightToLeft, name: "reversed-\(digit)-\(size)")
                XCTAssertNotEqual(oracle, wrong, "The raster oracle must distinguish glyph order")
                for direction in [LayoutDirection.leftToRight, .rightToLeft] {
                    let token = Text(verbatim: SettingsOptionLabel.precisionTolerance(precision))
                    let actual = try render(token, size: size, direction: direction, name: "actual-\(digit)-\(size)-\(direction)")
                    XCTAssertEqual(actual, oracle, "Every precision glyph must match its independent full-sized template")
                    XCTAssertNotEqual(actual, wrong)
                }
            }
        }
    }

    private func glyphPositions(_ text: String, size: CGFloat) throws -> [Int: CGFloat] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.baseWritingDirection = .rightToLeft
        let attributed = NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: size), .paragraphStyle: paragraph])
        let line = CTLineCreateWithAttributedString(attributed as CFAttributedString)
        let runs = try XCTUnwrap(CTLineGetGlyphRuns(line) as? [CTRun])
        var result: [Int: CGFloat] = [:]
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            var indices = [CFIndex](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetStringIndices(run, CFRange(location: 0, length: 0), &indices)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            for (index, point) in zip(indices, positions) { result[index] = point.x }
        }
        return result
    }

    private func position(_ glyph: String, in text: String, positions: [Int: CGFloat]) throws -> CGFloat {
        let index = (text as NSString).range(of: glyph).location
        XCTAssertNotEqual(index, NSNotFound)
        return try XCTUnwrap(positions[index], "Missing glyph \(glyph)")
    }

    private func render<Content: View>(_ content: Content, size: DynamicTypeSize,
                                       direction: LayoutDirection, name: String) throws -> Data {
        let view = content.font(.system(.body, design: .monospaced)).foregroundStyle(Color.black)
            .frame(width: 240, height: 120).background(Color.white)
            .environment(\.locale, Locale(identifier: "ar_SA"))
            .environment(\.layoutDirection, direction).environment(\.dynamicTypeSize, size)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.isOpaque = true
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = "settings-precision-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
        let cgImage = try XCTUnwrap(image.cgImage)
        XCTAssertEqual(cgImage.width, 240)
        XCTAssertEqual(cgImage.height, 120)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        var pixels = Data(count: 240 * 120 * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: 240, height: 120, bitsPerComponent: 8,
                bytesPerRow: 240 * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.interpolationQuality = .none
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 240, height: 120))
        }
        return pixels
    }
}
