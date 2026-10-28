import SwiftUI

/// One native Text preserves shaping, natural RTL wrapping, and a single spoken heading.
struct WelcomeHeadline: View {
    @Environment(\.locale) private var locale
    // Nastaliq's diagonal strokes extend beyond the Latin display face's default line box. Scale the extra
    // leading on the same large-title curve as the 40-point face, rather than shrinking or replacing Urdu.
    @ScaledMetric(relativeTo: .largeTitle) private var nastaliqLeading: CGFloat = 24

    private var isUrdu: Bool { locale.language.languageCode?.identifier == "ur" }

    private var font: Font {
        // Tamil's wide clusters use the existing title step so the final word and punctuation stay together.
        if locale.language.languageCode?.identifier == "ta" {
            return Typeface.display(28, relativeTo: .largeTitle)
        }
        return Typeface.display(40)
    }

    var body: some View {
        Text("Tune in seconds.\nThen learn to play.")
            .font(font).tracking(-1)
            .lineSpacing(isUrdu ? nastaliqLeading : 0)
            // Reserve the first/last line's ink overhang too; inter-line leading only separates interior lines.
            .padding(.vertical, isUrdu ? nastaliqLeading / 2 : 0)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("onboarding.headline")
    }
}
