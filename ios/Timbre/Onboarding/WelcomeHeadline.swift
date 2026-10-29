import CoreText
import SwiftUI
import UIKit

/// One native Text preserves shaping, natural RTL wrapping, and a single spoken heading.
struct WelcomeHeadline: View {
    @Environment(\.locale) private var locale
    @Environment(\.displayScale) private var displayScale
    @ScaledMetric(relativeTo: .largeTitle) private var urduPoints: CGFloat = 40
    // Retain the existing minimum gutter; measured glyph overhang can require more at larger sizes.
    @ScaledMetric(relativeTo: .largeTitle) private var urduHorizontalClearance: CGFloat = 12

    private var isUrdu: Bool { locale.language.languageCode?.identifier == "ur" }

    /// Resolve the OS's existing Urdu fallback from the actual localized copy, not a hardcoded face name.
    /// Supplying that face to Text gives it the same metrics as its glyphs. Native evidence found 100pt
    /// ascent+descent at 40pt, versus Sora's 50.4pt; adding guessed leading to Sora still collided.
    static func nativeUrduFont(points: CGFloat, locale: Locale) -> CTFont {
        let face = Typeface.boldText ? Typeface.Face.semiBold.heavier : Typeface.Face.semiBold
        let base = CTFontCreateWithName(face.fontName as CFString, points, nil)
        let copy = fontSelectionText(locale: locale)
        return CTFontCreateForStringWithLanguage(base, copy as CFString,
                                                CFRange(location: 0, length: (copy as NSString).length), "ur" as CFString)
    }

    /// String's locale argument only formats values; choose the resource bundle explicitly so the
    /// Urdu view also selects Urdu glyphs under an English test host or an in-app language override.
    static func fontSelectionText(locale: Locale) -> String {
        let language = locale.language.languageCode?.identifier ?? "en"
        let bundle = Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        return String(localized: "Tune in seconds.\nThen learn to play.", bundle: bundle, locale: locale)
    }

    private struct InkKey: Hashable {
        let face: String
        let points: CGFloat
        let text: String
        let scale: CGFloat
    }

    private static var inkCache: [InkKey: EdgeInsets] = [:]

    /// Measure ink outside typographic advances, including fragments that emergency wrapping can expose.
    /// These are font geometry measurements at the already-scaled point size, never screenshot offsets.
    static func nativeUrduInkInsets(font: CTFont, text: String, displayScale: CGFloat) -> EdgeInsets {
        let scale = max(1, displayScale)
        let key = InkKey(face: CTFontCopyPostScriptName(font) as String, points: CTFontGetSize(font), text: text, scale: scale)
        if let cached = inkCache[key] { return cached }
        let paragraph = NSMutableParagraphStyle()
        paragraph.baseWritingDirection = .rightToLeft
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTLanguageAttributeName as String): "ur",
            .paragraphStyle: paragraph, .tracking: -1
        ]
        var horizontal: CGFloat = 0, top: CGFloat = 0, bottom: CGFloat = 0
        for fragment in inkFragments(text) {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: fragment, attributes: attributes) as CFAttributedString)
            var ascent: CGFloat = 0, descent: CGFloat = 0
            let advance = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
            // Tracking is trailing whitespace. Cover both the full and trimmed typographic edge.
            let width = max(0, min(advance, advance - CGFloat(CTLineGetTrailingWhitespaceWidth(line))))
            let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            guard !ink.isNull, [ink.minX, ink.maxX, ink.minY, ink.maxY, width].allSatisfy({ $0.isFinite }) else { continue }
            horizontal = max(horizontal, max(-ink.minX, ink.maxX - width))
            top = max(top, ink.maxY - ascent)
            bottom = max(bottom, -descent - ink.minY)
        }
        func outward(_ value: CGFloat) -> CGFloat { ceil(max(0, value) * scale) / scale }
        let insets = EdgeInsets(top: outward(top), leading: outward(horizontal),
                                bottom: outward(bottom), trailing: outward(horizontal))
        if inkCache.count >= 16 { inkCache.removeAll(keepingCapacity: true) }
        inkCache[key] = insets
        return insets
    }

    /// Whole-word spans preserve shaping at ordinary wraps; grapheme fragments cover emergency wraps
    /// without separating a combining mark or removing the original punctuation from the measured copy.
    private static func inkFragments(_ text: String) -> [String] {
        var fragments: Set<String> = []
        for paragraph in text.split(separator: "\n") {
            let words = paragraph.split(whereSeparator: \.isWhitespace).map(String.init)
            for start in words.indices {
                for end in (start + 1)...words.count { fragments.insert(words[start..<end].joined(separator: " ")) }
                let clusters = Array(words[start])
                for first in clusters.indices {
                    for last in (first + 1)...clusters.count { fragments.insert(String(clusters[first..<last])) }
                }
            }
        }
        return fragments.sorted()
    }

    static func nativeUrduLayoutInsets(ink: EdgeInsets, minimumHorizontal: CGFloat) -> EdgeInsets {
        EdgeInsets(top: ink.top, leading: max(minimumHorizontal, ink.leading),
                   bottom: ink.bottom, trailing: max(minimumHorizontal, ink.trailing))
    }

    private var urduInkInsets: EdgeInsets {
        Self.nativeUrduInkInsets(font: Self.nativeUrduFont(points: urduPoints, locale: locale),
                                 text: Self.fontSelectionText(locale: locale), displayScale: displayScale)
    }

    private var font: Font {
        if isUrdu {
            // CTFont already has the uncapped ScaledMetric size: do not scale it a second time.
            return Font(Self.nativeUrduFont(points: urduPoints, locale: locale))
        }
        // Tamil's wide clusters use the existing title step so the final word and punctuation stay together.
        if locale.language.languageCode?.identifier == "ta" {
            return Typeface.display(28, relativeTo: .largeTitle)
        }
        return Typeface.display(40)
    }

    private var headline: Text {
        Text("Tune in seconds.\nThen learn to play.").font(font).tracking(-1)
    }

    var body: some View {
        Group {
            if isUrdu {
                // Keep native Text placement: renderer display padding changes the RTL drawing origin
                // and wrapping. The measured outer reserve already accounts for the font's ink bounds.
                headline.typesettingLanguage(locale.language)
            } else {
                headline
            }
        }
        .padding(isUrdu ? Self.nativeUrduLayoutInsets(ink: urduInkInsets, minimumHorizontal: urduHorizontalClearance) : EdgeInsets())
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("onboarding.headline")
    }
}
