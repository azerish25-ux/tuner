import CoreText
import SwiftUI

/// One native Text preserves shaping, natural RTL wrapping, and a single spoken heading.
struct WelcomeHeadline: View {
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .largeTitle) private var urduPoints: CGFloat = 40
    // The native AX5/280pt sample has a 48px trailing ink overhang at 3x (9.4 base points).
    // Reserve 12 base points on both sides without shrinking or capping the script.
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
                headline.typesettingLanguage(locale.language)
            } else {
                headline
            }
        }
        .padding(.horizontal, isUrdu ? urduHorizontalClearance : 0)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("onboarding.headline")
    }
}
