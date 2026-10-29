import SwiftUI
import UIKit
import XCTest
import TimbreCore
@testable import Timbre

@MainActor
final class SongCaptionMetadataTests: XCTestCase {
    func testAccessibleMetadataRetainsCompleteDurationAndRewardAtBothRailWidths() {
        let originalLanguage = TimbreLocalization.language
        defer { TimbreLocalization.language = originalLanguage }
        for language in ["en", "de", "ar"] {
            TimbreLocalization.language = language
            for width in [CGFloat(148), CGFloat(176)] {
                let direction: LayoutDirection = language == "ar" ? .rightToLeft : .leftToRight
                // The production screenshot lost these exact values to ellipses, despite full AX labels.
                let metadata = SongsView.TileMetadata(difficulty: 2, length: "2:29", xp: 30, stars: 0,
                                                      calm: false, accent: Palette.mint, identity: "metadata")
                let actual = measure(metadata, width: width, size: .accessibility5, language: language, direction: direction)
                let duration = measure(Text(verbatim: "2:29").font(Typeface.number(.caption))
                    .fixedSize(horizontal: false, vertical: true), width: width, size: .accessibility5,
                    language: language, direction: direction)
                let reward = measure(Text("+\(30) XP").font(.footnote).fixedSize(horizontal: false, vertical: true),
                                     width: width, size: .accessibility5, language: language, direction: direction)
                XCTAssertEqual(actual.height, 6 + duration.height + reward.height + 14, accuracy: 1,
                               "Both complete values must receive their own full-height row: \(language), \(width)")
                XCTAssertLessThanOrEqual(actual.width, width + 0.5)
            }
        }
    }

    func testWideMetadataKeepsCompactRowAndCalmModeKeepsOnlyItsExistingFields() {
        let metadata = SongsView.TileMetadata(difficulty: 2, length: "2:29", xp: 30, stars: 0,
                                              calm: false, accent: Palette.mint, identity: "metadata")
        let wide = measure(metadata, width: 800, size: .large)
        let duration = measure(Text(verbatim: "2:29").font(Typeface.number(.caption)), width: 800, size: .large)
        let reward = measure(Text("+\(30) XP").font(.footnote), width: 800, size: .large)
        XCTAssertEqual(wide.height, max(CGFloat(6), max(duration.height, reward.height)), accuracy: 1)
        let calm = SongsView.TileMetadata(difficulty: 2, length: "2:29", xp: 30, stars: 0,
                                          calm: true, accent: Palette.mint, identity: "metadata")
        let plain = measure(calm, width: 148, size: .accessibility5)
        let full = measure(metadata, width: 148, size: .accessibility5)
        XCTAssertLessThan(plain.height, full.height)
    }

    func testPixelsMatchIndependentCompleteFieldsAndRejectTruncatedAccessibleRow() throws {
        let originalLanguage = TimbreLocalization.language
        defer { TimbreLocalization.language = originalLanguage }
        for language in ["en", "de", "ar"] {
            TimbreLocalization.language = language
            let direction: LayoutDirection = language == "ar" ? .rightToLeft : .leftToRight
            for size in [DynamicTypeSize.large, .accessibility5] {
                for width in [CGFloat(148), CGFloat(176)] {
                    let suffix = "\(language)-\(size)-\(Int(width))"
                    let actual = SongsView.TileMetadata(difficulty: 2, length: "2:29", xp: 30, stars: 0,
                                                        calm: false, accent: Palette.mint, identity: "metadata")
                    let row = HStack(spacing: 7) { oracleFields }.fixedSize(horizontal: true, vertical: false)
                    let stack = VStack(alignment: .leading, spacing: 7) { oracleFields }
                        .fixedSize(horizontal: false, vertical: true)
                    let natural = measure(row, width: 800, size: size, language: language, direction: direction)
                    let expected = natural.width <= width ? AnyView(row) : AnyView(stack)
                    let pixels = try render(actual, width: width, language: language, size: size, name: "metadata-actual-" + suffix)
                    let oracle = try render(expected, width: width, language: language, size: size, name: "metadata-oracle-" + suffix)
                    XCTAssertEqual(pixels, oracle, "Render every glyph at full size, not just a complete AX label: " + suffix)
                    if size == .accessibility5 {
                        // The former one-line row has complete AX labels but loses visible glyphs.
                        let old = HStack(spacing: 7) { oracleFields }.lineLimit(1)
                        let truncated = try render(old, width: width, language: language, size: size, name: "metadata-old-row-" + suffix)
                        XCTAssertNotEqual(pixels, truncated, "The former compressed row must fail the pixel oracle: " + suffix)
                    }
                }
            }
        }
    }

    @ViewBuilder private var oracleFields: some View {
        HStack(spacing: 3) {
            Circle().fill(Palette.mint).frame(width: 6, height: 6)
            Circle().fill(Palette.mint).frame(width: 6, height: 6)
            Circle().fill(Color.white.opacity(0.18)).frame(width: 6, height: 6)
        }
        Text(verbatim: "2:29").font(Typeface.number(.caption)).foregroundStyle(Palette.inkSoft)
        Text("+\(30) XP").font(.footnote).foregroundStyle(Palette.inkSoft)
    }

    private func render<Content: View>(_ content: Content, width: CGFloat, language: String, size: DynamicTypeSize, name: String) throws -> Data {
        let renderer = ImageRenderer(content: content.frame(width: width, alignment: .leading).padding(20)
            .frame(width: width + 40, height: 320, alignment: .topLeading).background(Palette.stage)
            .environment(\.locale, Locale(identifier: language))
            .environment(\.layoutDirection, language == "ar" ? .rightToLeft : .leftToRight)
            .environment(\.dynamicTypeSize, size))
        renderer.scale = 1
        renderer.isOpaque = true
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let source = try XCTUnwrap(image.cgImage)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        var bytes = Data(count: source.width * source.height * 4)
        try bytes.withUnsafeMutableBytes { storage in
            let context = try XCTUnwrap(CGContext(data: storage.baseAddress, width: source.width, height: source.height,
                                                 bitsPerComponent: 8, bytesPerRow: source.width * 4, space: space,
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.interpolationQuality = .none
            context.draw(source, in: CGRect(x: 0, y: 0, width: CGFloat(source.width), height: CGFloat(source.height)))
        }
        return bytes
    }

    private func measure<Content: View>(_ content: Content, width: CGFloat, size: DynamicTypeSize,
                                        language: String = "en", direction: LayoutDirection = .leftToRight) -> CGSize {
        let host = UIHostingController(rootView: content.environment(\.locale, Locale(identifier: language))
            .environment(\.layoutDirection, direction).environment(\.dynamicTypeSize, size))
        return host.sizeThatFits(in: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
    }
}
