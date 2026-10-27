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
            let direction: LayoutDirection = language == "ar" ? .rightToLeft : .leftToRight
            for size in [DynamicTypeSize.large, .accessibility5] {
                for width in [CGFloat(148), CGFloat(176)] {
                    // Independently measure each full glyph, not the production flow's bounding box.
                    let sizes = chords.map { measure(oracleChip($0.name), width: width, size: size,
                                                     language: language, direction: direction) }
                    let intrinsic = sizes.reduce(CGFloat(0)) { $0 + $1.width } + CGFloat(sizes.count - 1) * 4
                    let horizontal = intrinsic + 6 + 44 <= width
                    var row = 0
                    var rows: [[Int]] = [[]]
                    var remaining = horizontal ? intrinsic : width
                    for index in sizes.indices {
                        let needed = sizes[index].width + (rows[row].isEmpty ? 0 : 4)
                        if needed > remaining && !rows[row].isEmpty {
                            rows.append([]); row += 1; remaining = width
                        }
                        if !rows[row].isEmpty { remaining -= 4 }
                        rows[row].append(index); remaining -= sizes[index].width
                    }
                    var rects = Array(repeating: CGRect.zero, count: sizes.count)
                    var top: CGFloat = horizontal ? 0 : 50
                    for indices in rows {
                        var leading: CGFloat = 0
                        for index in indices {
                            let x = direction == .rightToLeft ? width - leading - sizes[index].width : leading
                            rects[index] = CGRect(origin: CGPoint(x: x, y: top), size: sizes[index])
                            leading += sizes[index].width + 4
                        }
                        top += (indices.map { sizes[$0].height }.max() ?? 0) + 4
                    }
                    let versionX = direction == .rightToLeft
                        ? (horizontal ? width - intrinsic - 50 : 0)
                        : (horizontal ? intrinsic + 6 : width - 44)
                    let versionRect = CGRect(x: versionX, y: 0, width: 44, height: 44)
                    for (index, rect) in rects.enumerated() {
                        XCTAssertGreaterThanOrEqual(rect.minX, 0)
                        XCTAssertLessThanOrEqual(rect.maxX, width + 0.5)
                        XCTAssertFalse(rect.intersects(versionRect), "Chord \(index) must not overlap the 44pt action")
                        for other in rects.indices where other != index {
                            XCTAssertFalse(rect.intersects(rects[other]))
                        }
                    }
                    let height = max(versionRect.maxY, rects.map(\.maxY).max() ?? 0)
                    let oracle = ZStack {
                        ForEach(chords.indices, id: \.self) { index in
                            self.oracleChip(self.chords[index].name)
                                .frame(width: rects[index].width, height: rects[index].height)
                                .position(x: rects[index].midX, y: rects[index].midY)
                        }
                        Color.orange.frame(width: 44, height: 44)
                            .position(x: versionRect.midX, y: versionRect.midY)
                    }.frame(width: width, height: height)
                    let actual = SongCaptionHeader(hasVersions: true) {
                        ChordChips(chords: chords, key: nil, tint: Palette.mint,
                                   identity: "oracle", wrapsAll: true)
                    } versions: { Color.orange.frame(width: 44, height: 44) }
                    let suffix = "\(language)-\(size)-\(Int(width))"
                    let pixels = try render(actual, width: width, language: language, size: size, name: "header-actual-" + suffix)
                    let expected = try render(oracle, width: width, language: language, size: size, name: "header-independent-" + suffix)
                    XCTAssertEqual(pixels, expected, "Full glyphs and separate action, not merely full AX labels: " + suffix)
                    if size == .accessibility5 {
                        let former = HStack(alignment: .top, spacing: 6) {
                            ChordChips(chords: chords, key: nil, tint: Palette.mint, identity: "old")
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
