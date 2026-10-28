import CoreText
import SwiftUI
import TimbreCore
import UIKit
import XCTest
@testable import Timbre

@MainActor
final class SongHeroMetadataTests: XCTestCase {
    private let fixtures = [(language: "en", locale: "en_US", length: "2:36", reward: "+30 XP"),
                            (language: "ar", locale: "ar_SA", length: "٢:٣٦", reward: "+٣٠ XP")]

    override func tearDown() {
        TimbreLocalization.language = TimbreLocalization.system
        super.tearDown()
    }

    func testExistingSingleSpokenTextPreservesValuesTranslationAndCalmMode() throws {
        for fixture in fixtures {
            TimbreLocalization.language = fixture.language
            for xp in [Int?.none, 0, 30, 12345] {
                let view = SongsView.HeroMetadata(length: fixture.length, xp: xp)
                let original: Text
                if let xp { original = Text(verbatim: "· \(fixture.length) · ") + Text("+\(xp) XP") }
                else { original = Text(verbatim: "· \(fixture.length)") }
                let locale = Locale(identifier: fixture.locale)
                let actual = try pixels(view.spoken, locale: locale, direction: .rightToLeft)
                let expected = try pixels(original, locale: locale, direction: .rightToLeft)
                XCTAssertEqual(actual, expected, "Spoken Text must not gain isolates or change numeric formatting")
            }
        }
    }

    func testArabicAndEnglishWholeFieldRenderingRejectsRegroupedOrChangedValues() throws {
        for fixture in fixtures {
            TimbreLocalization.language = fixture.language
            let locale = Locale(identifier: fixture.locale)
            // Independent literal oracle: the known reward uses LRI, unlike production's first-strong isolate.
            // Both complete fields keep their glyph order; the surrounding paragraph is still free to be RTL.
            let oracle = Text(verbatim: "· \u{2066}\(fixture.length)\u{2069} · \u{2066}\(fixture.reward)\u{2069}")
            let wrongGroup = Text(verbatim: "· \u{2066}\(fixture.reward)\u{2069} · \u{2066}\(fixture.length) XP\u{2069}")
            let wrongValue = Text(verbatim: "· \u{2066}3:26\u{2069} · \u{2066}\(fixture.reward)\u{2069}")
            for direction in [LayoutDirection.leftToRight, .rightToLeft] {
                for size in [DynamicTypeSize.large, .accessibility5] {
                    let name = "\(fixture.language)-\(direction)-\(size)"
                    let view = SongsView.HeroMetadata(length: fixture.length, xp: 30)
                    let actual = try pixels(view, locale: locale, direction: direction, size: size, name: name + "-actual")
                    let expected = try pixels(oracle, locale: locale, direction: direction, size: size, name: name + "-oracle")
                    XCTAssertEqual(actual, expected, "Every canonical RGBA byte must match the whole-field oracle")
                    XCTAssertNotEqual(actual, try pixels(wrongGroup, locale: locale, direction: direction, size: size))
                    XCTAssertNotEqual(actual, try pixels(wrongValue, locale: locale, direction: direction, size: size))
                    if fixture.language == "ar" {
                        let old = Text(verbatim: "· \(fixture.length) · ") + Text("+\(30) XP")
                        let negative = try pixels(old, locale: locale, direction: direction, size: size, name: name + "-old")
                        XCTAssertNotEqual(actual, negative, "The native pixel oracle must reject the observed Arabic bug")
                    }
                }
            }
        }
    }

    func testDefaultEnglishPixelsAndCalmModeDoNotChange() throws {
        TimbreLocalization.language = "en"
        let locale = Locale(identifier: "en_US")
        for size in [DynamicTypeSize.large, .accessibility5] {
            for xp in [Int?.none, 30] {
                let view = SongsView.HeroMetadata(length: "2:36", xp: xp)
                let actual = try pixels(view, locale: locale, direction: .leftToRight, size: size)
                let old = try pixels(view.spoken, locale: locale, direction: .leftToRight, size: size)
                XCTAssertEqual(actual, old, "Default English gets no spacing, order, or glyph change")
            }
        }
    }

    func testCalmArabicKeepsOnlyTheOriginalDuration() throws {
        TimbreLocalization.language = "ar"
        let locale = Locale(identifier: "ar_SA")
        let view = SongsView.HeroMetadata(length: "٢:٣٦", xp: nil)
        let expected = Text(verbatim: "· \u{2066}٢:٣٦\u{2069}")
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            let actual = try pixels(view, locale: locale, direction: direction)
            XCTAssertEqual(actual, try pixels(expected, locale: locale, direction: direction))
            XCTAssertNotEqual(actual, try pixels(SongsView.HeroMetadata(length: "٢:٣٦", xp: 0),
                                                 locale: locale, direction: direction))
        }
    }

    func testIndependentGlyphPositionsKeepRewardTogetherAndRejectOldArabicOrder() throws {
        // These known localized literals do not call production or its integer interpolation.
        for fixture in fixtures {
            let sentence = "· \u{2066}\(fixture.length)\u{2069} · \u{2066}\(fixture.reward)\u{2069}"
            let number = fixture.language == "ar" ? "٣٠" : "30"
            for direction in [NSWritingDirection.leftToRight, .rightToLeft] {
                for size in [CGFloat(17), CGFloat(53)] {
                    let shaped = try positions(sentence, direction: direction, size: size)
                    let sign = try location("+", in: sentence, positions: shaped)
                    let digits = try location(number, in: sentence, positions: shaped)
                    let unit = try location("XP", in: sentence, positions: shaped)
                    let duration = try location(fixture.length, in: sentence, positions: shaped)
                    XCTAssertLessThan(sign, digits)
                    XCTAssertLessThan(digits, unit, "The reward is one physical +number XP field")
                    if direction == .leftToRight { XCTAssertLessThan(duration, sign) }
                    else { XCTAssertGreaterThan(duration, unit) }
                }
            }
        }
        let old = "· ٢:٣٦ · +٣٠ XP"
        for direction in [NSWritingDirection.leftToRight, .rightToLeft] {
            let shaped = try positions(old, direction: direction, size: 17)
            XCTAssertGreaterThan(try location("+", in: old, positions: shaped),
                                 try location("٣٠", in: old, positions: shaped), "Reject the old sign/number reversal")
        }
    }

    private func positions(_ text: String, direction: NSWritingDirection, size: CGFloat) throws -> [Int: CGFloat] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.baseWritingDirection = direction
        let value = NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: size),
                                                                 .paragraphStyle: paragraph])
        let line = CTLineCreateWithAttributedString(value as CFAttributedString)
        let runs = try XCTUnwrap(CTLineGetGlyphRuns(line) as? [CTRun])
        var result: [Int: CGFloat] = [:]
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            var indices = [CFIndex](repeating: 0, count: count)
            var points = [CGPoint](repeating: .zero, count: count)
            CTRunGetStringIndices(run, CFRange(location: 0, length: 0), &indices)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &points)
            for (index, point) in zip(indices, points) { result[index] = point.x }
        }
        return result
    }

    private func location(_ token: String, in text: String, positions: [Int: CGFloat]) throws -> CGFloat {
        let range = (text as NSString).range(of: token)
        XCTAssertNotEqual(range.location, NSNotFound)
        guard range.location != NSNotFound else { throw NSError(domain: "MissingMetadataToken", code: 1) }
        let points = try (range.location..<(range.location + range.length)).map {
            try XCTUnwrap(positions[$0], "Missing glyph for \(token)")
        }
        return points.reduce(CGFloat.zero, +) / CGFloat(points.count)
    }

    private func pixels<Content: View>(_ content: Content, locale: Locale, direction: LayoutDirection,
                                       size: DynamicTypeSize = .large, name: String? = nil) throws -> Data {
        let view = content.font(.subheadline).foregroundStyle(Color.black)
            .typesettingLanguage(locale.language)
            .environment(\.locale, locale).environment(\.layoutDirection, direction)
            .environment(\.dynamicTypeSize, size)
            .frame(width: 1200, height: 180).background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.isOpaque = true
        let image = try XCTUnwrap(renderer.uiImage)
        if let name {
            let attachment = XCTAttachment(image: image)
            attachment.name = "song-hero-metadata-" + name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        let cgImage = try XCTUnwrap(image.cgImage)
        XCTAssertEqual(cgImage.width, 1200)
        XCTAssertEqual(cgImage.height, 180)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        var data = Data(count: 1200 * 180 * 4)
        try data.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: 1200, height: 180,
                bitsPerComponent: 8, bytesPerRow: 1200 * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.interpolationQuality = .none
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1200, height: 180))
        }
        return data
    }
}
