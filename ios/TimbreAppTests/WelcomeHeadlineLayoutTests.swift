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
        // 320/375/402/430-point phones, less the actual two 20-point welcome gutters.
        for width in [CGFloat(280), 335, 362, 390] {
            var heights: [Int] = []
            for size in [DynamicTypeSize.large, .accessibility5] {
                let example = Example(width: width, size: size)
                let masks = try probe(WelcomeHeadline(), example: example, name: example.name)
                let full = masks.full, even = masks.even, odd = masks.odd
                let union = zip(even.ink, odd.ink).map { $0 || $1 }
                XCTAssertTrue(union.elementsEqual(full.ink), "The line masks must reconstruct the unmodified native render: " + example.name)
                XCTAssertFalse(even.touches(odd), "Adjacent Nastaliq lines must not share or touch ink pixels: " + example.name)
                // A generous outer canvas is deliberately NOT clipped to the layout's rectangle. Any overflowing
                // first/last-line glyph or horizontally cropped word is visible to this bounds assertion.
                let content = CGRect(x: 240, y: 240, width: width * 3, height: CGFloat(full.height - 480))
                XCTAssertTrue(content.insetBy(dx: -1, dy: -1).contains(full.bounds), "All ink must fit its reserved layout: " + example.name)
                heights.append(full.height)
            }
            XCTAssertGreaterThan(heights[1], heights[0], "AX5 must genuinely grow, never cap or shrink the heading")
        }
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
                                      diagnostics: Bool = true, nativeImage: Bool = true) throws -> ProbedText {
        let full = try render(view, example: example, name: "headline-" + name, attachImage: nativeImage)
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

    private struct CalibrationHeadline: View {
        @ScaledMetric private var leading: CGFloat
        @ScaledMetric private var vertical: CGFloat
        @ScaledMetric private var horizontal: CGFloat

        init(leading: CGFloat, vertical: CGFloat, horizontal: CGFloat) {
            _leading = ScaledMetric(wrappedValue: leading, relativeTo: .largeTitle)
            _vertical = ScaledMetric(wrappedValue: vertical, relativeTo: .largeTitle)
            _horizontal = ScaledMetric(wrappedValue: horizontal, relativeTo: .largeTitle)
        }

        var body: some View {
            Text("Tune in seconds.\nThen learn to play.").font(Typeface.display(40)).tracking(-1)
                .lineSpacing(leading).padding(.vertical, vertical).padding(.horizontal, horizontal)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A bounded diagnostic table, not a replacement for the strict production test above. Every measurement
    /// first passes the exact native/language/renderer equivalence gates. Only scalar results leave each pool.
    func testRecordBoundedUrduLeadingCalibration() throws {
        let candidates: [(String, CGFloat, CGFloat, CGFloat)] = [("baseline", 24, 12, 0), ("roomier", 40, 32, 12), ("separated", 48, 32, 12)]
        var rows: [[String: Any]] = []
        for width in [CGFloat(280), 335, 362, 390] {
            for size in [DynamicTypeSize.large, .accessibility5] {
                let example = Example(width: width, size: size)
                // Do not silently calibrate a replica whose typography differs from the shipping view.
                try autoreleasepool {
                    let native = try render(WelcomeHeadline(), example: example, name: "calibration-baseline-native", attachImage: false)
                    let baseline = try render(CalibrationHeadline(leading: 24, vertical: 12, horizontal: 0), example: example,
                                              name: "calibration-baseline-replica", attachImage: false)
                    try requireSamePixels(native, baseline, name: "calibration-baseline-" + example.name)
                }
                for (label, leading, vertical, horizontal) in candidates {
                    let row: [String: Any] = try autoreleasepool {
                        let view = CalibrationHeadline(leading: leading, vertical: vertical, horizontal: horizontal)
                        let representative = (width == 362 && size == .large) || (width == 280 && size == .accessibility5)
                        let masks = try probe(view, example: example, name: "calibration-" + label + "-" + example.name,
                                              diagnostics: false, nativeImage: representative)
                        let full = masks.full
                        let content = CGRect(x: 240, y: 240, width: width * 3, height: CGFloat(full.height - 480))
                        let bounds = full.bounds
                        let separated = !masks.even.touches(masks.odd)
                        let fits = content.insetBy(dx: -1, dy: -1).contains(bounds)
                        let union = zip(masks.even.ink, masks.odd.ink).map { $0 || $1 }
                        return ["candidate": label, "widthPoints": Double(width), "dynamicType": String(describing: size),
                                "baseLeading": Double(leading), "baseVerticalClearance": Double(vertical),
                                "baseHorizontalClearance": Double(horizontal), "canvasHeightPixels": full.height,
                                "inkBoundsPixels": [bounds.minX, bounds.minY, bounds.maxX, bounds.maxY].map { Double($0) },
                                "outsideLayoutPixels": [max(0, content.minX - bounds.minX), max(0, content.minY - bounds.minY),
                                                        max(0, bounds.maxX - content.maxX), max(0, bounds.maxY - content.maxY)].map { Double($0) },
                                "separatedByMoreThanTwoPixels": separated, "allInkInsideLayout": fits,
                                "maskUnionMatchesNative": union.elementsEqual(full.ink),
                                "safeForThisSample": separated && fits && union.elementsEqual(full.ink)]
                    }
                    rows.append(row)
                }
            }
        }
        XCTAssertEqual(rows.count, 24, "All three candidates must cover all eight width/type cases")
        let data = try JSONSerialization.data(withJSONObject: ["diagnosticOnly": true, "samples": rows], options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "urdu-leading-calibration.json"
        attachment.lifetime = .keepAlways
        add(attachment)
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
                XCTAssertTrue(actual.ink.elementsEqual(expected.ink), "No other language's typography may change: " + example.name)
            }
        }
    }

    private func render<Content: View>(_ view: Content, example: Example, name: String, attachImage: Bool = true) throws -> Bitmap {
        let content = view.foregroundStyle(Color.black)
            .frame(width: example.width)
            .fixedSize(horizontal: false, vertical: true)
            .padding(80)
            .background(Color.white)
            .environment(\.locale, Locale(identifier: example.language))
            .environment(\.layoutDirection, example.direction)
            .environment(\.dynamicTypeSize, example.size)
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
