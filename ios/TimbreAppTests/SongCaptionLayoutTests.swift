import SwiftUI
import UIKit
import XCTest
import TimbreCore
@testable import Timbre

@MainActor
final class SongCaptionLayoutTests: XCTestCase {
    private let chords = ["Bb", "F", "Cm", "Eb"].map {
        ChordSpec(name: $0, root: 0, quality: "major", frets: [])
    }

    func testFullChordGlyphsAndVersionsRemainSeparateAtBothRailWidths() throws {
        let originalLanguage = TimbreLocalization.language
        defer { TimbreLocalization.language = originalLanguage }
        for language in ["en", "de", "ar"] {
            TimbreLocalization.language = language
            for size in [DynamicTypeSize.large, .accessibility5] {
                for width in [CGFloat(148), CGFloat(176)] {
                    // Measure inside SwiftUI's layout pass, not through UIKit's hosting-size
                    // rounding. Fractional chip widths must accumulate before rasterization.
                    let oracle = IndependentHeaderLayout(width: width) {
                        ForEach(chords.indices, id: \.self) { index in
                            self.oracleChip(self.chords[index].name)
                        }
                        Color.orange.frame(width: 44, height: 44)
                    }
                    let actual = SongCaptionHeader(hasVersions: true) {
                        ChordChips(chords: self.chords, key: nil, tint: Palette.mint,
                                   identity: "oracle", wrapsAll: true)
                    } versions: { Color.orange.frame(width: 44, height: 44) }
                    let suffix = "\(language)-\(size)-\(Int(width))"
                    let pixels = try render(actual, width: width, language: language, size: size, name: "header-actual-" + suffix)
                    let expected = try render(oracle, width: width, language: language, size: size, name: "header-independent-" + suffix)
                    XCTAssertEqual(pixels, expected, "Full glyphs and separate action, not merely full AX labels: " + suffix)
                    if language == "ar" {
                        let doubleMirrored = IndependentHeaderLayout(width: width, doubleMirrorChips: true) {
                            ForEach(chords.indices, id: \.self) { index in
                                self.oracleChip(self.chords[index].name)
                            }
                            Color.orange.frame(width: 44, height: 44)
                        }
                        let wrongOrder = try render(doubleMirrored, width: width, language: language, size: size,
                                                    name: "header-double-mirror-control-" + suffix)
                        XCTAssertNotEqual(pixels, wrongOrder, "A second RTL mirror must fail the reading-order oracle")
                    }
                    if size == .accessibility5 {
                        let former = HStack(alignment: .top, spacing: 6) {
                            ChordChips(chords: self.chords, key: nil, tint: Palette.mint, identity: "old")
                                .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                            Color.orange.frame(width: 44, height: 44)
                        }
                        let oldPixels = try render(former, width: width, language: language, size: size,
                                                   name: "header-former-overlap-" + suffix)
                        XCTAssertNotEqual(pixels, oldPixels, "Former compressed chord/version row must fail this oracle")
                    }
                }
            }
        }
    }

    func testFlowPackingMirrorsWithoutOverlapOrDroppedChords() {
        let sizes = [CGSize(width: 67, height: 49), CGSize(width: 35, height: 49),
                     CGSize(width: 81, height: 49), CGSize(width: 65, height: 49)]
        for width in [CGFloat(148), CGFloat(176)] {
            let left = SongCaptionFlow.pack(sizes, width: width, spacing: 4, direction: .leftToRight)
            let right = SongCaptionFlow.pack(sizes, width: width, spacing: 4, direction: .rightToLeft)
            XCTAssertEqual(left.count, sizes.count)
            XCTAssertEqual(right.count, sizes.count)
            for index in sizes.indices {
                XCTAssertEqual(right[index].minX, width - left[index].maxX)
                XCTAssertEqual(right[index].minY, left[index].minY)
                XCTAssertEqual(right[index].size, sizes[index])
                XCTAssertGreaterThanOrEqual(right[index].minX, 0)
                XCTAssertLessThanOrEqual(left[index].maxX, width)
            }
        }
    }

    func testEveryProductionChordFitsWithoutReducingGlyphSize() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AppStore(directory: directory)
        let all = store.curriculum.courses.flatMap(\.lessons).flatMap { SongSheet.of($0).chords }
        let symbols = Set(all.map(\.symbol))
        XCTAssertGreaterThan(symbols.count, 10, "Exercise the production catalogue, not a short fixture")
        let originalLanguage = TimbreLocalization.language
        defer { TimbreLocalization.language = originalLanguage }
        for language in ["en", "de", "ar"] {
            TimbreLocalization.language = language
            for size in [DynamicTypeSize.large, .accessibility5] {
                for width in [CGFloat(148), CGFloat(176)] {
                    for symbol in symbols.sorted() {
                        let chord = try XCTUnwrap(all.first { $0.symbol == symbol })
                        let natural = measure(oracleChip(chord.name), width: 800, size: size, language: language)
                        let bounded = measure(oracleChip(chord.name), width: width, size: size, language: language)
                        XCTAssertLessThanOrEqual(bounded.width, width + 0.5, symbol)
                        XCTAssertGreaterThanOrEqual(bounded.height + 0.5, natural.height, symbol)
                    }
                }
            }
        }
    }

    /// Independent partition-by-rows oracle. It never calls SongCaptionFlow, its pack helper,
    /// or SongCaptionHeader. Layout coordinates are logical; SwiftUI supplies the single RTL
    /// transform. The versions action is at logical trailing, not a pre-mirrored .position.
    private struct IndependentHeaderLayout: Layout {
        let width: CGFloat
        var doubleMirrorChips = false

        private func rectangles(_ subviews: Subviews) -> [CGRect] {
            precondition(subviews.count >= 2)
            let chips = subviews.dropLast().map { view in
                let ideal = view.sizeThatFits(.unspecified)
                return view.sizeThatFits(ProposedViewSize(width: min(width, ideal.width), height: nil))
            }
            let intrinsic = chips.reduce(CGFloat.zero) { $0 + $1.width } + CGFloat(chips.count - 1) * 4
            let horizontal = intrinsic + 6 + 44 <= width
            var rows: [[Int]] = [[]]
            for index in chips.indices {
                let occupied = rows[rows.count - 1].reduce(CGFloat.zero) { $0 + chips[$1].width + 4 }
                if !rows[rows.count - 1].isEmpty && occupied + chips[index].width > width {
                    rows.append([])
                }
                rows[rows.count - 1].append(index)
            }
            var result = Array(repeating: CGRect.zero, count: chips.count)
            var top: CGFloat = horizontal ? 0 : 50
            for row in rows {
                for (column, index) in row.enumerated() {
                    let preceding = row.prefix(column).reduce(CGFloat.zero) { $0 + chips[$1].width + 4 }
                    result[index] = CGRect(origin: CGPoint(x: preceding, y: top), size: chips[index])
                }
                top += (row.map { chips[$0].height }.max() ?? 0) + 4
            }
            let versionRect = CGRect(x: horizontal ? intrinsic + 6 : width - 44, y: 0, width: 44, height: 44)
            for (index, rect) in result.enumerated() {
                XCTAssertGreaterThanOrEqual(rect.minX, 0)
                XCTAssertLessThanOrEqual(rect.maxX, width + 0.5)
                XCTAssertFalse(rect.intersects(versionRect), "Chord \(index) must not overlap the 44pt action")
                for other in result.indices where other != index {
                    XCTAssertFalse(rect.intersects(result[other]))
                }
            }
            return result + [versionRect]
        }

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            CGSize(width: width, height: rectangles(subviews).map(\.maxY).max() ?? 0)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let rects = rectangles(subviews)
            // These are logical positions, including the action. No manual RTL mirror here.
            print("CHORD-ORACLE width=\(width) direction=\(subviews.layoutDirection) rectangles=\(rects)")
            for index in rects.indices {
                let rect = rects[index]
                let x = doubleMirrorChips && index < rects.count - 1 ? width - rect.maxX : rect.minX
                subviews[index].place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + rect.minY),
                           anchor: UnitPoint(x: 0, y: 0), proposal: ProposedViewSize(rect.size))
            }
        }
    }

    private func oracleChip(_ name: String) -> some View {
        Text(verbatim: name).font(Typeface.label(.caption)).foregroundStyle(Palette.ink)
            .padding(.horizontal, 7).frame(minHeight: 22)
            .background(Capsule().fill(Palette.mint.opacity(0.16)))
            .overlay(Capsule().strokeBorder(Palette.mint.opacity(0.4), lineWidth: 1))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func render<Content: View>(_ content: Content, width: CGFloat, language: String, size: DynamicTypeSize, name: String) throws -> Data {
        let renderer = ImageRenderer(content: content.frame(width: width, alignment: .leading).padding(20)
            .frame(width: width + 40, height: 640, alignment: .topLeading).background(Palette.stage)
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
