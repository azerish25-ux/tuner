import CoreText
import SwiftUI
import UIKit
import XCTest
@testable import Timbre

/// Separate raster masks of the actual SwiftUI lines detect ink collisions that an accessibility label or
/// the whole Text's frame cannot. No font metrics, guessed baselines, or OCR stand in for the rendered ink.
@MainActor
final class WelcomeHeadlineLayoutTests: XCTestCase {
    private let urdu = "سیکنڈوں میں ٹیون کریں۔\nپھر بجانا سیکھیں۔"

    private struct Example {
        var width: CGFloat
        var language = "ur"
        var size = DynamicTypeSize.large
        var direction: LayoutDirection { ["ur", "ar", "fa", "he"].contains(language) ? .rightToLeft : .leftToRight }
        var name: String { "\(language)-\(Int(width))-\(size)" }
    }

    /// Forward the unchanged proposal and retain the default zero display insets. The previous padded
    /// probe reflowed the native text; the generous canvas belongs outside the Text instead.
    /// A nil parity draws every line, proving this probe matches the unmodified production pixels first.
    private struct LineMask: TextRenderer {
        let parity: Int?
        nonisolated func sizeThatFits(proposal: ProposedViewSize, text: TextProxy) -> CGSize {
            text.sizeThatFits(proposal)
        }
        nonisolated func draw(layout: Text.Layout, in context: inout GraphicsContext) {
            for (index, line) in layout.enumerated() where parity == nil || index % 2 == parity {
                context.draw(line)
            }
        }
    }

    private struct Bitmap {
        let width: Int
        let height: Int
        let rgba: Data
        let ink: [Bool]

        var inkCount: Int { ink.filter { $0 }.count }

        var bounds: CGRect {
            var left = width, top = height, right = -1, bottom = -1
            for y in 0..<height {
                for x in 0..<width where ink[y * width + x] {
                    left = min(left, x); right = max(right, x)
                    top = min(top, y); bottom = max(bottom, y)
                }
            }
            guard right >= left, bottom >= top else { return .null }
            return CGRect(x: CGFloat(left), y: CGFloat(top), width: CGFloat(right - left + 1), height: CGFloat(bottom - top + 1))
        }

        func touches(_ other: Bitmap, radius: Int = 2) -> Bool {
            guard width == other.width, height == other.height else { return true }
            for y in 0..<height {
                for x in 0..<width where ink[y * width + x] {
                    for row in max(0, y - radius)...min(height - 1, y + radius) {
                        for column in max(0, x - radius)...min(width - 1, x + radius)
                            where other.ink[row * width + column] { return true }
                    }
                }
            }
            return false
        }
    }

    func testUrduLinesHaveSeparateInkAtSmallPhoneAndAccessibilityWidths() throws {
        var samples = 0
        // 320/375/402/430-point phones, less the actual two 20-point welcome gutters.
        for width in [CGFloat(280), 335, 362, 390] {
            var heights: [Int] = []
            for size in [DynamicTypeSize.large, .accessibility5] {
                let example = Example(width: width, size: size)
                do {
                    try autoreleasepool {
                        // Measure unmodified native ink before the probe can fail, so an unrelated renderer
                        // mismatch cannot hide a real overflow. Every requested case must still be visited.
                        let native = try render(WelcomeHeadline(), example: example, name: "headline-" + example.name)
                        let content = CGRect(x: 240, y: 240, width: width * 3, height: CGFloat(native.height - 480))
                        XCTAssertTrue(content.insetBy(dx: -1, dy: -1).contains(native.bounds), "All ink must fit its reserved layout: " + example.name)
                        heights.append(native.height)
                        let independent = try render(NativeMetricsHeadline(), example: example, name: "plain-native-" + example.name)
                        try requireSamePixels(native, independent, name: "production-vs-plain-native-" + example.name)
                        let masks = try probe(NativeMetricsHeadline(), example: example, name: example.name, native: independent)
                        let full = masks.full, even = masks.even, odd = masks.odd
                        let union = zip(even.ink, odd.ink).map { $0 || $1 }
                        XCTAssertTrue(union.elementsEqual(full.ink), "The line masks must reconstruct the unmodified native render: " + example.name)
                        XCTAssertFalse(even.touches(odd), "Adjacent Nastaliq lines must not share or touch ink pixels: " + example.name)
                    }
                } catch {
                    XCTFail("Every requested sample requires a pixel-identical native probe: \(example.name): \(error)")
                }
                samples += 1
            }
            XCTAssertEqual(heights.count, 2, "Both native Dynamic Type renders must succeed")
            if heights.count == 2 {
                XCTAssertGreaterThan(heights[1], heights[0], "AX5 must genuinely grow, never cap or shrink the heading")
            }
        }
        XCTAssertEqual(samples, 8, "A failed probe must not prevent the remaining native cases from being checked")
    }

    func testCollisionOracleRejectsTheOriginalZeroLeadingUrduLayout() throws {
        // Retain the old localized Text: plain verbatim Urdu under an English test-host language uses a
        // different Arabic fallback face. The independently specified sentence must match with explicit Urdu.
        let original = Text("Tune in seconds.\nThen learn to play.").font(Typeface.display(40)).tracking(-1)
            .fixedSize(horizontal: false, vertical: true)
        let independent = Text(verbatim: urdu).font(Typeface.display(40)).tracking(-1)
            .fixedSize(horizontal: false, vertical: true)
            .typesettingLanguage(Locale(identifier: "ur").language)
        // Exact content width from the failing 1206-pixel / 3x native iPhone capture.
        let example = Example(width: 362)
        let masks = try probe(original, example: example, name: "original-zero-leading")
        let expected = try render(independent, example: example, name: "original-independent-urdu-language")
        try requireSamePixels(masks.full, expected, name: "old-localized-vs-independent-urdu")
        XCTAssertTrue(masks.even.touches(masks.odd), "The oracle must reject the observed collision, not merely accept the new spacing")
    }

    private struct ProbedText {
        let full: Bitmap
        let even: Bitmap
        let odd: Bitmap
    }

    /// Fail before interpreting parity masks if either explicit language or the custom renderer changes
    /// the reference layout. Exact RGBA equality prevents the probe from silently measuring another font,
    /// reflowing the copy, translating its origins, clipping glyphs, or applying different antialiasing.
    private func probe<Content: View>(_ view: Content, example: Example, name: String,
                                      diagnostics: Bool = true, nativeImage: Bool = true, native: Bitmap? = nil) throws -> ProbedText {
        let full: Bitmap
        if let native {
            full = native
        } else {
            full = try render(view, example: example, name: "headline-" + name, attachImage: nativeImage)
        }
        let controlled = view.typesettingLanguage(Locale(identifier: example.language).language)
        let language = try render(controlled, example: example, name: "explicit-language-" + name, attachImage: diagnostics)
        try requireSamePixels(full, language, name: "native-vs-explicit-language-" + name)
        let completeProbe = try render(controlled.textRenderer(LineMask(parity: nil)), example: example, name: "full-probe-" + name, attachImage: diagnostics)
        try requireSamePixels(full, completeProbe, name: "native-vs-full-probe-" + name)
        let even = try render(controlled.textRenderer(LineMask(parity: 0)), example: example, name: "even-" + name, attachImage: diagnostics)
        let odd = try render(controlled.textRenderer(LineMask(parity: 1)), example: example, name: "odd-" + name, attachImage: diagnostics)
        for mask in [even, odd] {
            _ = try XCTUnwrap(mask.width == full.width && mask.height == full.height ? true : nil,
                              "Every line mask must keep the complete native canvas: " + name)
            XCTAssertGreaterThan(mask.inkCount, 100, "Require real glyph ink on both parities, not blank passing images: " + name)
        }
        return ProbedText(full: full, even: even, odd: odd)
    }

    private func requireSamePixels(_ expected: Bitmap, _ actual: Bitmap, name: String) throws {
        let same = expected.width == actual.width && expected.height == actual.height && expected.rgba == actual.rgba
        let changed = same ? 0 : zip(expected.rgba, actual.rgba).reduce(0) { $0 + ($1.0 == $1.1 ? 0 : 1) }
            + abs(expected.rgba.count - actual.rgba.count)
        let bounds = same ? "" : " expectedInk=\(expected.bounds) actualInk=\(actual.bounds)"
        let detail = "\(name): expected=\(expected.width)x\(expected.height) actual=\(actual.width)x\(actual.height) changedRGBA=\(changed)" + bounds
        print("TIMBRE_WELCOME_PROBE " + detail)
        let attachment = XCTAttachment(string: detail)
        attachment.name = "probe-equivalence-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
        _ = try XCTUnwrap(same ? true : nil, "Only a pixel-identical probe may diagnose line collisions. " + detail)
    }

    /// Independent form of the native fallback candidate captured before this production repair.
    /// The only added clearance addresses its measured AX5 trailing overhang, not line separation.
    private struct NativeMetricsHeadline: View {
        @ScaledMetric(relativeTo: .largeTitle) private var points: CGFloat = 40
        @ScaledMetric(relativeTo: .largeTitle) private var horizontal: CGFloat = 12
        @Environment(\.displayScale) private var displayScale

        var body: some View {
            let face = Typeface.boldText ? Typeface.Face.semiBold.heavier : Typeface.Face.semiBold
            let base = CTFontCreateWithName(face.fontName as CFString, points, nil)
            let word = "سیکھیں۔"
            let fallback = CTFontCreateForStringWithLanguage(base, word as CFString,
                CFRange(location: 0, length: (word as NSString).length), "ur" as CFString)
            return Text("Tune in seconds.\nThen learn to play.").font(Font(fallback)).tracking(-1)
                .typesettingLanguage(Locale(identifier: "ur").language)
                // Share only the measured layout allowance, never the production TextRenderer.
                .padding(WelcomeHeadline.nativeUrduLayoutInsets(
                    ink: WelcomeHeadline.nativeUrduInkInsets(font: fallback,
                        text: "سیکنڈوں میں ٹیون کریں۔\nپھر بجانا سیکھیں۔", displayScale: displayScale),
                    minimumHorizontal: horizontal))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func testProductionUsesNativeUrduMetricsAtEveryWidthAndSize() throws {
        var samples = 0
        for width in [CGFloat(280), 335, 362, 390] {
            for size in [DynamicTypeSize.large, .accessibility5] {
                let example = Example(width: width, size: size)
                do {
                    try autoreleasepool {
                        let native = try render(WelcomeHeadline(), example: example, name: "native-metrics-production-" + example.name)
                        let independent = try render(NativeMetricsHeadline(), example: example, name: "native-metrics-independent-" + example.name)
                        try requireSamePixels(native, independent, name: "production-vs-native-metrics-" + example.name)
                    }
                } catch {
                    XCTFail("Independent native equality is required for every sample: \(example.name): \(error)")
                }
                samples += 1
            }
        }
        XCTAssertEqual(samples, 8, "Native metrics must cover every width and Dynamic Type case")
    }

    func testNonUrduHeadlinePixelsRemainUnchangedIncludingTamil() throws {
        for language in ["en", "ta", "ar", "fa", "he"] {
            for size in [DynamicTypeSize.large, .accessibility5] {
                let example = Example(width: 362, language: language, size: size)
                let previous = Text("Tune in seconds.\nThen learn to play.")
                    .font(language == "ta" ? Typeface.display(28, relativeTo: .largeTitle) : Typeface.display(40))
                    .tracking(-1).fixedSize(horizontal: false, vertical: true)
                let expected = try render(previous, example: example, name: "unchanged-oracle-" + example.name)
                let actual = try render(WelcomeHeadline(), example: example, name: "unchanged-actual-" + example.name)
                XCTAssertEqual(actual.width, expected.width)
                XCTAssertEqual(actual.height, expected.height)
                try requireSamePixels(expected, actual, name: "unchanged-non-urdu-" + example.name)
            }
        }
    }

    /// Align the same logical leading edge before rasterization: right for RTL, left for LTR.
    /// Native Text and TextRenderer can report different intrinsic widths for overhanging ink;
    /// a physical-left anchor misplaces RTL text even when its typographic right edge agrees.
    /// Both paths receive the same width proposal. No measured pixel offset enters placement.
    private struct PinnedCanvas: Layout {
        let width: CGFloat
        let direction: LayoutDirection

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let size = subviews[0].sizeThatFits(ProposedViewSize(width: width, height: nil))
            print("TIMBRE_WELCOME_CANVAS proposal=\(width) intrinsic=\(size) direction=\(direction)")
            return CGSize(width: width + 160, height: size.height + 160)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let rtl = direction == .rightToLeft
            let x = bounds.minX + 80 + (rtl ? width : 0)
            subviews[0].place(at: CGPoint(x: x, y: bounds.minY + 80),
                             anchor: UnitPoint(x: rtl ? 1 : 0, y: 0),
                             proposal: ProposedViewSize(width: width, height: nil))
        }
    }

    private func render<Content: View>(_ view: Content, example: Example, name: String, attachImage: Bool = true) throws -> Bitmap {
        let content = PinnedCanvas(width: example.width, direction: example.direction) {
            view.foregroundStyle(Color.black)
                .environment(\.layoutDirection, example.direction)
        }
        .background(Color.white)
        .environment(\.locale, Locale(identifier: example.language))
        .environment(\.dynamicTypeSize, example.size)
        .environment(\.displayScale, 3)
        // Only the test canvas uses physical LTR coordinates; the native Text above keeps real RTL.
        .environment(\.layoutDirection, .leftToRight)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        renderer.isOpaque = true
        let image = try XCTUnwrap(renderer.uiImage)
        if attachImage {
            let attachment = XCTAttachment(image: image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width, height = cgImage.height
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height,
                                                 bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        }
        let ink = stride(from: 0, to: bytes.count, by: 4).map { bytes[$0] < 128 && bytes[$0 + 1] < 128 && bytes[$0 + 2] < 128 }
        return Bitmap(width: width, height: height, rgba: Data(bytes), ink: ink)
    }
}
