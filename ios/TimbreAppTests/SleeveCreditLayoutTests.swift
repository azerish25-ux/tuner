import SwiftUI
import UIKit
import CoreText
import XCTest
@testable import Timbre

@MainActor
final class SleeveCreditLayoutTests: XCTestCase {
    private let credits = [
        "Mandolin songbook",
        "Traditionelles Mandolinenliederbuch",
        "كتاب الأغاني التقليدية للمندولين",
        "マンドリンの伝統的な曲集",
        "曼陀林传统歌曲集"
    ]

    func testFullCreditFitsNativeTextContainerWithoutScalingOrTruncation() {
        for side in [CGFloat(72), 96, 124, 176] {
            for atFoot in [false, true] {
                let width = side * (atFoot ? 1 - 0.075 - CoverArt.playCorner : 0.85)
                for capitals in [false, true] {
                    for text in credits {
                        let labelSize = max(6, side * 0.052)
                        let fit = SleeveCreditFit(text: text, width: width, labelSize: labelSize, capitals: capitals)
                        XCTAssertEqual(fit.text, capitals ? text.uppercased() : text)
                        XCTAssertEqual(fit.font.pointSize, labelSize * (capitals ? 1 : 1.1), accuracy: 0.001)
                        XCTAssertGreaterThanOrEqual(fit.tracking, 0)
                        XCTAssertLessThanOrEqual(fit.tracking, labelSize * (capitals ? 0.16 : 0.01))
                        assertAllGlyphsFit(fit)
                    }
                }
            }
        }
    }

    func testMandolinCreditWrapsRatherThanEllipsizesInReservedFootWidth() {
        let fit = SleeveCreditFit(text: "Mandolin songbook", width: 124 * (1 - 0.075 - CoverArt.playCorner),
                                  labelSize: 124 * 0.052, capitals: true)
        XCTAssertEqual(fit.text, "MANDOLIN SONGBOOK")
        XCTAssertGreaterThan(CFArrayGetCount(CTFrameGetLines(fit.frame())), 1)
        assertAllGlyphsFit(fit)
    }

    func testShortCreditKeepsOriginalTracking() {
        let fit = SleeveCreditFit(text: "Folk", width: 100, labelSize: 8, capitals: true)
        XCTAssertEqual(fit.tracking, 8 * 0.16, accuracy: 0.001)
        XCTAssertEqual(CFArrayGetCount(CTFrameGetLines(fit.frame())), 1)
        assertAllGlyphsFit(fit)
    }

    func testMeasuredCreditHeightIsReservedInMotifAndBannerLayout() {
        var sawFoot = false
        var sawTop = false
        var sawBanner = false
        for index in 0..<100 {
            let art = CoverArt(id: "credit-layout-\(index)", title: "Folk Song", accent: "mint", genre: .folk,
                               label: credits[1], number: index + 1)
            guard art.imprint.credited else { continue }
            for side in [CGFloat(72), 124, 176] {
                let layout = SleeveLayout(art: art, size: CGSize(width: side, height: side), titled: true)
                let block = layout.credit.height + layout.labelSize * 0.35 + layout.fit.height
                XCTAssertEqual(layout.credit.width, layout.typeWidth)
                XCTAssertTrue(layout.typeFitsBounds)
                assertAllGlyphsFit(layout.credit)
                assertRegionFits(layout, side: side)
                if art.titleOnTop {
                    sawTop = true
                    XCTAssertEqual(layout.region.minY, min(side - layout.pad, layout.typeTop + block + side * 0.05),
                                   accuracy: 0.001)
                    XCTAssertLessThanOrEqual(layout.typeTop + block, side - layout.pad + 1)
                } else {
                    sawFoot = true
                    // The entire type block stays horizontally outside the reserved play corner.
                    XCTAssertLessThanOrEqual(layout.pad + layout.typeWidth, side * (1 - CoverArt.playCorner) + 0.001)
                    let bottomInset = art.banner ? layout.bandInset : layout.pad
                    XCTAssertGreaterThanOrEqual(side - bottomInset - block, layout.pad)
                }
                if art.banner {
                    sawBanner = true
                    XCTAssertEqual(layout.bandHeight, min(side, block + layout.bandInset * 2), accuracy: 0.001)
                }
            }
        }
        XCTAssertTrue(sawFoot)
        XCTAssertTrue(sawTop)
        XCTAssertTrue(sawBanner)
    }

    func testHostedCreditUsesMeasuredFrameForLTRAndRTLAtNormalAndAX5() throws {
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            for typeSize in [DynamicTypeSize.large, .accessibility5] {
                let fit = SleeveCreditFit(text: credits[direction == .rightToLeft ? 2 : 1], width: 72,
                                          labelSize: 6.448, capitals: false)
                let view = SleeveCredit(fit: fit, alignment: .leading, color: .white)
                    .frame(width: fit.width, height: fit.height)
                    .environment(\.layoutDirection, direction)
                    .environment(\.dynamicTypeSize, typeSize)
                let host = UIHostingController(rootView: view)
                host.view.frame = CGRect(x: 0, y: 0, width: fit.width, height: fit.height)
                host.view.setNeedsLayout()
                host.view.layoutIfNeeded()
                let measured = host.sizeThatFits(in: CGSize(width: fit.width, height: CGFloat.greatestFiniteMagnitude))
                XCTAssertEqual(measured.width, fit.width, accuracy: 0.5)
                XCTAssertEqual(measured.height, fit.height, accuracy: 0.5)
                assertAllGlyphsFit(fit, rightToLeft: direction == .rightToLeft)
            }
        }
    }

    func testCacheKeepsExactFractionalWidthsAndFontInputs() {
        let first = SleeveCreditFit(text: credits[0], width: 72.01, labelSize: 6.448, capitals: true)
        let narrower = SleeveCreditFit(text: credits[0], width: 71.99, labelSize: 6.448, capitals: true)
        let mixed = SleeveCreditFit(text: credits[0], width: 72.01, labelSize: 6.449, capitals: false)
        let repeatFit = SleeveCreditFit(text: credits[0], width: 72.01, labelSize: 6.448, capitals: true)
        XCTAssertEqual(first.width, 72.01)
        XCTAssertEqual(narrower.width, 71.99)
        XCTAssertEqual(mixed.font.pointSize, 6.449 * 1.1, accuracy: 0.00001)
        XCTAssertEqual(mixed.text, credits[0])
        XCTAssertEqual(first.height, repeatFit.height)
        XCTAssertEqual(first.tracking, repeatFit.tracking)
        assertAllGlyphsFit(narrower)
    }

    func testRealLongCourseCreditsFitCompactSleeves() {
        // Actual curriculum / Learn.strings course labels, not shortened display substitutes.
        let labels = ["Standards & Classics", "Standards & Klassiker", "Mandolin Songbook",
                      "Mandolinen-Liederbuch", "كتاب أغاني غيتار الباس", "المعايير والكلاسيكيات",
                      "スタンダード＆クラシック", "Eigenkompositionen"]
        for label in labels {
            for index in 0..<20 {
                let art = CoverArt(id: "compact-credit-\(index)", title: "Folk Song", accent: "mint",
                                   genre: .folk, label: label, number: index + 1)
                for side in [CGFloat(72), 96, 124, 176] {
                    let layout = SleeveLayout(art: art, size: CGSize(width: side, height: side), titled: true)
                    XCTAssertTrue(layout.typeFitsBounds, "\(label) / \(side) / \(index)")
                    if art.imprint.credited { assertAllGlyphsFit(layout.credit) }
                    assertRegionFits(layout, side: side)
                }
            }
        }
    }

    func testUnboundedCopyReportsInfeasibleTypeButNeverInventsMotifRoom() {
        // No finite square can accommodate arbitrary prose without scaling, truncating, or hiding it.
        // This regression distinguishes honest infeasibility from a bogus successful fit.
        let text = String(repeating: "Mandolinen-Liederbuch كتاب الأغاني 曲集 ", count: 20)
        for index in 0..<20 {
            let art = CoverArt(id: "overflow-credit-\(index)", title: "Folk Song", accent: "mint",
                               genre: .folk, label: text, number: index + 1)
            guard art.imprint.credited else { continue }
            let layout = SleeveLayout(art: art, size: CGSize(width: 72, height: 72), titled: true)
            XCTAssertFalse(layout.typeFitsBounds)
            XCTAssertEqual(layout.credit.text, art.imprint == .catalogue ? text.uppercased() : text)
            XCTAssertEqual(layout.region.height, 0)
            XCTAssertLessThanOrEqual(layout.bandHeight, 72)
            assertRegionFits(layout, side: 72)
        }
    }

    private func assertRegionFits(_ layout: SleeveLayout, side: CGFloat,
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(layout.region.minY, layout.pad, file: file, line: line)
        XCTAssertLessThanOrEqual(layout.region.maxY, side - layout.pad + 0.001, file: file, line: line)
        XCTAssertGreaterThanOrEqual(layout.region.height, 0, file: file, line: line)
    }

    func testImageRendererDrawsActualCreditGlyphsRatherThanUIKitPlaceholder() throws {
        let first = SleeveCreditFit(text: "MANDOLIN SONGBOOK", width: 100, labelSize: 9, capitals: true)
        let second = SleeveCreditFit(text: "CELLO SONGBOOK", width: 100, labelSize: 9, capitals: true)
        let blank = SleeveCreditFit(text: "", width: 100, labelSize: 9, capitals: true)
        let firstPixels = try renderedPixels(first)
        let secondPixels = try renderedPixels(second)
        let blankPixels = try renderedPixels(blank)
        XCTAssertNotEqual(firstPixels, blankPixels, "The exported credit must paint glyphs")
        XCTAssertNotEqual(secondPixels, blankPixels, "The exported credit must paint glyphs")
        XCTAssertNotEqual(firstPixels, secondPixels, "A generic UIKit placeholder cannot pass as credit text")
        XCTAssertEqual(firstPixels, try renderedPixels(first), "The same credit must render deterministically")
    }

    private func renderedPixels(_ fit: SleeveCreditFit) throws -> [UInt8] {
        let view = ZStack(alignment: .topLeading) {
            Color.black
            SleeveCredit(fit: fit, alignment: .leading, color: .white)
        }
        .frame(width: 120, height: 60)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.cgImage)
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
        }
        return pixels
    }

    private func assertAllGlyphsFit(_ fit: SleeveCreditFit, rightToLeft: Bool = false,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let frame = fit.frame(rightToLeft: rightToLeft)
        let visible = CTFrameGetVisibleStringRange(frame)
        XCTAssertEqual(visible.location, 0, file: file, line: line)
        XCTAssertEqual(visible.length, (fit.text as NSString).length, fit.text, file: file, line: line)
        guard let lines = CTFrameGetLines(frame) as? [CTLine] else {
            XCTFail("Core Text did not return a valid line array", file: file, line: line)
            return
        }
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
        for (index, textLine) in lines.enumerated() {
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            let width = CGFloat(CTLineGetTypographicBounds(textLine, &ascent, &descent, &leading))
                - CGFloat(CTLineGetTrailingWhitespaceWidth(textLine))
            XCTAssertLessThanOrEqual(width, fit.width + 0.5, file: file, line: line)
            XCTAssertGreaterThanOrEqual(origins[index].y - descent, -0.5, file: file, line: line)
            XCTAssertLessThanOrEqual(origins[index].y + ascent, fit.height + 0.5, file: file, line: line)
        }
    }
}
