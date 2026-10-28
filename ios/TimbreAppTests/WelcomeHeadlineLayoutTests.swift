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

    /// A rendering-only probe: retain the full original layout and its origins, draw alternate lines separately.
    /// Applying this outside the production view cannot change its font, wrapping, leading, or translation.
    private struct LineMask: TextRenderer {
        let parity: Int
        nonisolated var displayPadding: EdgeInsets { EdgeInsets(top: 80, leading: 80, bottom: 80, trailing: 80) }
        nonisolated func draw(layout: Text.Layout, in context: inout GraphicsContext) {
            for (index, line) in layout.enumerated() where index % 2 == parity {
                context.draw(line)
            }
        }
    }

    private struct Bitmap {
        let width: Int
        let height: Int
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
                let full = try render(WelcomeHeadline(), example: example, name: "headline-" + example.name)
                let even = try render(WelcomeHeadline().textRenderer(LineMask(parity: 0)), example: example, name: "even-" + example.name)
                let odd = try render(WelcomeHeadline().textRenderer(LineMask(parity: 1)), example: example, name: "odd-" + example.name)
                XCTAssertGreaterThan(even.inkCount, 100, "Require real glyph ink, not a blank passing image")
                XCTAssertGreaterThan(odd.inkCount, 100, "The fixture must exercise more than one actual line")
                XCTAssertEqual(even.width, full.width)
                XCTAssertEqual(even.height, full.height)
                XCTAssertEqual(odd.height, full.height)
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
        let original = Text(verbatim: urdu).font(Typeface.display(40)).tracking(-1)
            .fixedSize(horizontal: false, vertical: true)
        // Exact content width from the failing 1206-pixel / 3x native iPhone capture.
        let example = Example(width: 362)
        let even = try render(original.textRenderer(LineMask(parity: 0)), example: example, name: "original-zero-leading-even")
        let odd = try render(original.textRenderer(LineMask(parity: 1)), example: example, name: "original-zero-leading-odd")
        XCTAssertGreaterThan(even.inkCount, 100)
        XCTAssertGreaterThan(odd.inkCount, 100)
        XCTAssertTrue(even.touches(odd), "The oracle must reject the observed collision, not merely accept the new spacing")
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

    private func render<Content: View>(_ view: Content, example: Example, name: String) throws -> Bitmap {
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
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
        return Bitmap(width: width, height: height, ink: ink)
    }
}
