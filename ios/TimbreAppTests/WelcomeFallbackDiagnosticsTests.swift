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

    func testRecordUrduFallbackMetricsAndCandidateLayouts() throws {
        let face = Typeface.boldText ? Typeface.Face.semiBold.heavier : Typeface.Face.semiBold
        let name = face.fontName
        _ = try XCTUnwrap(UIFont(name: name, size: 40), "The actual bundled display face must be registered")
        let base = CTFontCreateWithName(name as CFString, 40, nil)
        XCTAssertEqual(CTFontCopyPostScriptName(base) as String, name)
        var report = [metrics(base, label: "base")]
        var candidates: [String: String] = [:]
        for word in ["سیکنڈوں", "میں", "ٹیون", "کریں۔", "پھر", "بجانا", "سیکھیں۔"] {
            let range = CFRange(location: 0, length: (word as NSString).length)
            let fallback = CTFontCreateForStringWithLanguage(base, word as CFString, range, "ur" as CFString)
            let fallbackName = CTFontCopyPostScriptName(fallback) as String
            report.append(metrics(fallback, label: word))
            candidates[fallbackName] = word
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
            .environment(\.layoutDirection, .rightToLeft).environment(\.dynamicTypeSize, size))
        renderer.scale = 3
        renderer.isOpaque = true
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
