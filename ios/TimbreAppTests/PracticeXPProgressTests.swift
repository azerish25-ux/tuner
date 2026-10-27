import CoreText
import SwiftUI
import TimbreCore
import UIKit
import XCTest
@testable import Timbre

@MainActor
final class PracticeXPProgressTests: XCTestCase {
    func testIndependentNumeralPositionsAndOldArabicNegativeControl() throws {
        let fixtures = [("ar_SA", "٢٥٥", "٥٠٠", "التالي"),
                        ("fa_IR", "۲۵۵", "۵۰۰", "بعدی"),
                        ("he_IL", "255", "500", "הבאה"),
                        ("en_US", "255", "500", "next")]
        for (locale, numerator, denominator, word) in fixtures {
            let template = "%lld / %lld XP · \(word): %@"
            let actual = try XCTUnwrap(PracticeXPProgress.sentence(template: template, counts: (255, 500),
                                                                   next: "Next", locale: Locale(identifier: locale)))
            for direction in [NSWritingDirection.leftToRight, .rightToLeft] {
                let first = try position(of: numerator, in: actual, direction: direction)
                let second = try position(of: denominator, in: actual, direction: direction)
                XCTAssertLessThan(first, second, "Numerator must be physically left, not merely first logically: \(locale)")
            }
        }
        // Independent known Arabic digits reproduce the old production order bug, without using the formatter.
        let old = "٢٥٥ / ٥٠٠ XP · التالي: Next"
        XCTAssertGreaterThan(try position(of: "٢٥٥", in: old, direction: .rightToLeft),
                             try position(of: "٥٠٠", in: old, direction: .rightToLeft))
    }

    func testTraditionalChineseFullwidthFractionPreservesTranslationAndSpokenText() throws {
        let template = "%lld／%lld XP · 下一個：%@"
        let actual = try XCTUnwrap(PracticeXPProgress.sentence(template: template, counts: (255, 500),
                                                               next: "XP", locale: Locale(identifier: "zh_TW")))
        let visible = actual.unicodeScalars.filter { ![0x2066, 0x2069].contains($0.value) }.map { String($0) }.joined()
        XCTAssertEqual(visible, "255／500 XP · 下一個：XP")
        for direction in [NSWritingDirection.leftToRight, .rightToLeft] {
            XCTAssertLessThan(try position(of: "255", in: actual, direction: direction),
                              try position(of: "500", in: actual, direction: direction))
        }
        let original = TimbreLocalization.language
        defer { TimbreLocalization.language = original }
        TimbreLocalization.language = "zh-Hant"
        XCTAssertEqual(NSLocalizedString(PracticeXPProgress.key, comment: ""), template)
        let view = PracticeXPProgress(done: 255, total: 500, next: "XP")
        let spoken = try pixels(view.spoken, locale: Locale(identifier: "zh_TW"), name: "practice-xp-zh-Hant-spoken-label")
        let expected = try pixels(Text(verbatim: "255／500 XP · 下一個：XP"), locale: Locale(identifier: "zh_TW"))
        XCTAssertEqual(spoken, expected, "VoiceOver label Text retains the accepted sentence without directional isolates")
    }

    private func position(of operand: String, in sentence: String, direction: NSWritingDirection) throws -> CGFloat {
        let range = (sentence as NSString).range(of: operand)
        XCTAssertNotEqual(range.location, NSNotFound, "Expected independently specified localized digits")
        guard range.location != NSNotFound else { throw NSError(domain: "MissingNumeral", code: 1) }
        let paragraph = NSMutableParagraphStyle()
        paragraph.baseWritingDirection = direction
        let text = NSAttributedString(string: sentence, attributes: [.font: UIFont.systemFont(ofSize: 20),
                                                                    .paragraphStyle: paragraph])
        let line = CTLineCreateWithAttributedString(text)
        // Each digit's actual logical-index caret position comes from native shaping, not string order.
        let positions = (range.location..<(range.location + range.length)).map {
            CTLineGetOffsetForStringIndex(line, $0, nil)
        }
        return positions.reduce(CGFloat.zero, +) / CGFloat(positions.count)
    }

    func testIntegerFormattingMatchesExistingSwiftUITextIncludingGrouping() throws {
        for name in ["ar_SA", "fa_IR", "he_IL", "en_US"] {
            let locale = Locale(identifier: name)
            for value in [255, 500, 12345] {
                let formatted = String(format: "%lld", locale: locale, arguments: [Int64(value)])
                let original = try pixels(Text("\(value)"), locale: locale)
                let replacement = try pixels(Text(verbatim: formatted), locale: locale)
                XCTAssertEqual(original, replacement, "Preserve Int Text digits and grouping: \(name), \(value)")
            }
        }
    }

    func testUnexpectedTemplateFallsBackWithoutRewritingTranslations() {
        for unsupported in ["%lld／%lld XP %@ %lld", "%lld／%lld XP %@ %@", "%lld／%lld XP %u",
                            "%lld／%lld XP", "%lld／%@ XP %lld", "%lld ∕ %lld XP %@"] {
            XCTAssertNil(PracticeXPProgress.sentence(template: unsupported, counts: (255, 500),
                                                     next: "Next", locale: Locale(identifier: "zh_TW")))
        }
        XCTAssertNil(PracticeXPProgress.sentence(template: "%lld / %lld XP %@ %lld", counts: (255, 500),
                                                 next: "Next", locale: Locale(identifier: "ar_SA")))
        XCTAssertNil(PracticeXPProgress.sentence(template: "XP %lld of %lld: %@", counts: (255, 500),
                                                 next: "Next", locale: Locale(identifier: "ar_SA")))
    }

    func testActualSwiftUIViewsAttachNormalAndAccessibilityRenders() throws {
        let original = TimbreLocalization.language
        defer { TimbreLocalization.language = original }
        for language in ["en", "ar", "fa", "he", "zh-Hant"] {
            TimbreLocalization.language = language
            for size in [DynamicTypeSize.large, .accessibility5] {
                let view = PracticeXPProgress(done: 255, total: 500, next: "Tuned Ear")
                    .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    .environment(\.dynamicTypeSize, size)
                    .environment(\.layoutDirection, ["en", "zh-Hant"].contains(language) ? .leftToRight : .rightToLeft)
                _ = try pixels(view, locale: Locale(identifier: language), name: "practice-xp-\(language)-\(size)")
            }
        }
    }

    private func pixels<Content: View>(_ view: Content, locale: Locale, name: String? = nil) throws -> Data {
        let renderer = ImageRenderer(content: view.environment(\.locale, locale)
            .foregroundStyle(.black).frame(width: CGFloat(600), height: CGFloat(360))
            .background(.white))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.uiImage)
        if let name {
            let attachment = XCTAttachment(image: image)
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        return try XCTUnwrap(image.pngData())
    }
}
