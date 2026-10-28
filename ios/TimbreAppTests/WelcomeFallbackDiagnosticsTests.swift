import CoreText
import SwiftUI
import UIKit
import XCTest
@testable import Timbre

/// Native evidence for the Latin-metrics/Nastaliq-fallback hypothesis. These candidate captures are not
/// acceptance evidence and never replace WelcomeHeadlineLayoutTests' strict production pixel assertions.
@MainActor
final class WelcomeFallbackDiagnosticsTests: XCTestCase {
    private struct ExplicitFallbackHeadline: View {
        let baseName: String
        let word: String
        @ScaledMetric(relativeTo: .largeTitle) private var points: CGFloat = 40

        init(baseName: String, word: String) {
            self.baseName = baseName
            self.word = word
        }

        var body: some View {
            let base = CTFontCreateWithName(baseName as CFString, points, nil)
            let range = CFRange(location: 0, length: (word as NSString).length)
            let fallback = CTFontCreateForStringWithLanguage(base, word as CFString, range, "ur" as CFString)
            // The runtime-selected face, at the existing uncapped large-title scale; no guessed font name,
            // added leading or padding can disguise whether its own native metrics reserve the complete ink.
            Text("Tune in seconds.\nThen learn to play.").font(Font(fallback)).tracking(-1)
                .typesettingLanguage(Locale(identifier: "ur").language)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func testFontResolutionUsesTheViewLanguageRatherThanTheTestHost() {
        XCTAssertEqual(WelcomeHeadline.fontSelectionText(locale: Locale(identifier: "ur_PK")),
                       "سیکنڈوں میں ٹیون کریں۔\nپھر بجانا سیکھیں۔")
        XCTAssertEqual(WelcomeHeadline.fontSelectionText(locale: Locale(identifier: "en")),
                       "Tune in seconds.\nThen learn to play.")
    }

    func testMeasuredInkAllowanceContainsIndependentGlyphPathsAtNormalAndAX5Sizes() throws {
        let copy = "سیکنڈوں میں ٹیون کریں۔\nپھر بجانا سیکھیں۔"
        let metrics = UIFontMetrics(forTextStyle: .largeTitle)
        let normal = metrics.scaledValue(for: 40, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        let ax5 = metrics.scaledValue(for: 40, compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))
        XCTAssertGreaterThan(ax5, normal)
        var reports: [String] = []
        for points in [normal, ax5] {
            let font = WelcomeHeadline.nativeUrduFont(points: points, locale: Locale(identifier: "ur"))
            XCTAssertEqual(CTFontGetSize(font), points, "The already-scaled font must not scale again")
            let allowance = WelcomeHeadline.nativeUrduInkInsets(font: font, text: copy, displayScale: 3)
            XCTAssertGreaterThan(allowance.leading, 0, "The actual Nastaliq overhang must be reserved")
            XCTAssertEqual(allowance.leading, allowance.trailing, "Symmetric ink allowance cannot flip in RTL")
            let paragraph = NSMutableParagraphStyle()
            paragraph.baseWritingDirection = .rightToLeft
            var checkedFragments = 0
            for word in copy.split(whereSeparator: \.isWhitespace) {
                let clusters = Array(word)
                for start in clusters.indices {
                    for end in (start + 1)...clusters.count {
                        let fragment = String(clusters[start..<end])
                        let attributed = NSAttributedString(string: fragment, attributes: [
                            NSAttributedString.Key(kCTFontAttributeName as String): font,
                            NSAttributedString.Key(kCTLanguageAttributeName as String): "ur",
                            .tracking: -1, .paragraphStyle: paragraph
                        ])
                        let line = CTLineCreateWithAttributedString(attributed as CFAttributedString)
                        var ascent: CGFloat = 0, descent: CGFloat = 0
                        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
                        let ink = try glyphPathBounds(line)
                        guard !ink.isNull else { continue }
                        checkedFragments += 1
                        let reserved = CGRect(x: -allowance.leading, y: -descent - allowance.bottom,
                            width: width + allowance.leading + allowance.trailing,
                            height: ascent + descent + allowance.top + allowance.bottom)
                        XCTAssertTrue(reserved.contains(ink), "Every actual glyph path needs drawing allowance: \(fragment), \(points)pt")
                    }
                }
            }
            XCTAssertGreaterThan(checkedFragments, 20, "The metric oracle must inspect real glyph paths")
            let reserved = WelcomeHeadline.nativeUrduLayoutInsets(ink: allowance, minimumHorizontal: 12)
            XCTAssertGreaterThanOrEqual(reserved.leading, allowance.leading)
            XCTAssertGreaterThanOrEqual(reserved.trailing, allowance.trailing)
            reports.append("points=\(points) measured=\(allowance) reserved=\(reserved)")
        }
        let attachment = XCTAttachment(string: reports.joined(separator: "\n"))
        attachment.name = "urdu-measured-ink-allowance"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Independent path union: do not validate CTLine's aggregate bounds with the same aggregate API.
    private func glyphPathBounds(_ line: CTLine) throws -> CGRect {
        var result = CGRect.null
        let runs = try XCTUnwrap(CTLineGetGlyphRuns(line) as? [CTRun])
        for run in runs {
            let attributes = CTRunGetAttributes(run) as NSDictionary
            let font = attributes[kCTFontAttributeName] as! CTFont
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            for (glyph, position) in zip(glyphs, positions) {
                if let path = CTFontCreatePathForGlyph(font, glyph, nil) {
                    result = result.union(path.boundingBoxOfPath.offsetBy(dx: position.x, dy: position.y))
                }
            }
        }
        return result
    }

    func testRecordUrduFallbackMetricsAndCandidateLayouts() throws {
        let face = Typeface.boldText ? Typeface.Face.semiBold.heavier : Typeface.Face.semiBold
        let name = face.fontName
        _ = try XCTUnwrap(UIFont(name: name, size: 40), "The actual bundled display face must be registered")
        let base = CTFontCreateWithName(name as CFString, 40, nil)
        XCTAssertEqual(CTFontCopyPostScriptName(base) as String, name)
        let production = WelcomeHeadline.nativeUrduFont(points: 40, locale: Locale(identifier: "ur"))
        XCTAssertEqual(CTFontGetSize(production), 40, "The resolved face must not double-scale")
        XCTAssertNotEqual(CTFontCopyPostScriptName(production) as String, name,
                          "Urdu needs a covering native face, not the Latin base's line metrics")
        var report = [metrics(base, label: "base"), metrics(production, label: "production-resolved")]
        var candidates: [String: String] = [:]
        for word in ["سیکنڈوں", "میں", "ٹیون", "کریں۔", "پھر", "بجانا", "سیکھیں۔"] {
            let range = CFRange(location: 0, length: (word as NSString).length)
            let fallback = CTFontCreateForStringWithLanguage(base, word as CFString, range, "ur" as CFString)
            let fallbackName = CTFontCopyPostScriptName(fallback) as String
            report.append(metrics(fallback, label: word))
            candidates[fallbackName] = word
            XCTAssertEqual(fallbackName, CTFontCopyPostScriptName(production) as String,
                           "The actual localized headline must select the same native face as every Urdu word")
            let automatic = Text(verbatim: word).font(Typeface.display(40)).tracking(-1)
                .typesettingLanguage(Locale(identifier: "ur").language).fixedSize()
            let explicit = Text(verbatim: word).font(Font(fallback)).tracking(-1)
                .typesettingLanguage(Locale(identifier: "ur").language).fixedSize()
            // Representative isolated words expose glyph changes separately from multiline metric changes.
            if word == "سیکنڈوں" || word == "سیکھیں۔" {
                try autoreleasepool {
                    try capture(automatic, width: 600, size: .large, name: "fallback-word-original-" + word)
                    try capture(explicit, width: 600, size: .large, name: "fallback-word-explicit-" + word)
                }
            }
        }
        let detail = report.joined(separator: "\n")
        print("TIMBRE_URDU_FALLBACK_METRICS\n" + detail)
        let attachment = XCTAttachment(string: detail)
        attachment.name = "urdu-coretext-fallback-metrics"
        attachment.lifetime = .keepAlways
        add(attachment)
        // A mixed fallback result needs investigation, not an unbounded capture matrix or a guessed face.
        _ = try XCTUnwrap(candidates.count <= 2 ? true : nil, "Unexpected mixed Urdu fallback candidates: \(candidates.keys)")
        for (fallbackName, word) in candidates.sorted(by: { $0.key < $1.key }) {
            for (width, size) in [(CGFloat(362), DynamicTypeSize.large), (CGFloat(280), .accessibility5)] {
                let suffix = "\(Int(width))-\(size)-\(fallbackName)"
                try autoreleasepool {
                    try capture(WelcomeHeadline(), width: width, size: size, name: "fallback-production-reference-" + suffix)
                    try capture(ExplicitFallbackHeadline(baseName: name, word: word), width: width, size: size,
                                name: "fallback-explicit-candidate-" + suffix)
                }
            }
        }
    }

    private func metrics(_ font: CTFont, label: String) -> String {
        "\(label): postScript=\(CTFontCopyPostScriptName(font)) family=\(CTFontCopyFamilyName(font)) "
            + "points=\(CTFontGetSize(font)) ascent=\(CTFontGetAscent(font)) descent=\(CTFontGetDescent(font)) "
            + "leading=\(CTFontGetLeading(font)) boundingBox=\(CTFontGetBoundingBox(font))"
    }

    private func capture<Content: View>(_ view: Content, width: CGFloat, size: DynamicTypeSize, name: String) throws {
        let renderer = ImageRenderer(content: view.foregroundStyle(Color.black).frame(width: width)
            .fixedSize(horizontal: false, vertical: true).padding(80).background(Color.white)
            .environment(\.locale, Locale(identifier: "ur"))
            .environment(\.layoutDirection, .rightToLeft).environment(\.dynamicTypeSize, size)
            .environment(\.displayScale, 3))
        renderer.scale = 3
        renderer.isOpaque = true
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
