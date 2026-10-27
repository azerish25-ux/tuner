import SwiftUI
import UIKit
import XCTest
@testable import Timbre

@MainActor
final class WeekStatRenderingTests: XCTestCase {
    func testFullCaptionHeightIsPreservedAtCompactAndAccessibilityWidths() throws {
        let fixtures: [(String, String, LayoutDirection)] = [
            ("de_DE", "bester Stimmvorgang", .leftToRight),
            ("ar_SA", "أفضل ضبط", .rightToLeft),
            ("he_IL", "הכיוון הטוב ביותר", .rightToLeft)
        ]
        for (locale, caption, direction) in fixtures {
            for size in [DynamicTypeSize.large, .accessibility5] {
                let width: CGFloat = size.isAccessibilitySize ? 300 : 96
                let textWidth = width - 26 // Native icon18 + spacing8; no smaller caption font.
                let label = Text(verbatim: caption).font(.caption)
                let value = Text(verbatim: "±0.6¢").font(Typeface.number(.headline))
                let labelImage = try render(label, width: textWidth, size: size, locale: locale, direction: direction)
                let valueImage = try render(value, width: textWidth, size: size, locale: locale, direction: direction)
                let actual = try render(WeekStat(symbol: "scope", tint: Palette.mint,
                    value: Text(verbatim: "±0.6¢"), label: Text(verbatim: caption)),
                    width: width, size: size, locale: locale, direction: direction)
                XCTAssertEqual(actual.size.width, width, accuracy: 1)
                XCTAssertGreaterThanOrEqual(actual.size.height + 2, labelImage.size.height + valueImage.size.height,
                    "The actual stat must reserve the complete independently measured caption: \(locale) \(size)")
                let attachment = XCTAttachment(image: actual)
                attachment.name = "week-stat-\(locale)-\(size)"
                attachment.lifetime = .keepAlways
                add(attachment)
                if locale == "de_DE", size == .large {
                    let oldCaption = try render(label.lineLimit(1).minimumScaleFactor(0.75), width: textWidth,
                                                size: size, locale: locale, direction: direction)
                    XCTAssertGreaterThan(labelImage.size.height, oldCaption.size.height + 2,
                                         "The fixture must expose the old single-line truncation")
                }
            }
        }
    }

    private func render<Content: View>(_ content: Content, width: CGFloat, size: DynamicTypeSize,
                                      locale: String, direction: LayoutDirection) throws -> UIImage {
        let renderer = ImageRenderer(content: content.frame(width: width, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.locale, Locale(identifier: locale))
            .environment(\.layoutDirection, direction)
            .environment(\.dynamicTypeSize, size)
            .environment(\.colorScheme, .dark))
        renderer.scale = 1
        return try XCTUnwrap(renderer.uiImage)
    }
}
