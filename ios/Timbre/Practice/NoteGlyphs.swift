import SwiftUI
import TimbreCore

/// Note names on screen, written one way everywhere: ASCII accidentals become ♯ and ♭ (`NoteNames.glyphs`), and the
/// signs are set in the system face. Sora has neither sign, and the face iOS falls back to sets them full width, so
/// a Sora "E♭" reads "E ♭"; the system's signs sit tight against the letter. Everything else takes the Text's font.
enum NoteGlyphs {
    /// `name` ("Eb3", "F#", "Sib", "C minor pentatonic") as Text, its signs in the system face at `size` points.
    static func text(_ name: String, size: CGFloat, weight: Font.Weight = .semibold) -> Text {
        text(name, sign: .system(size: size, weight: weight))
    }

    /// With the signs' font given: one that grows with Dynamic Type beside a Sora face set `relativeTo:` the same
    /// style (`.system(.subheadline, weight: .semibold)` beside `Typeface.label(15, relativeTo: .subheadline)`).
    static func text(_ name: String, sign: Font) -> Text {
        Text(attributed(name, sign: sign))
    }

    static func attributed(_ name: String, sign: Font) -> AttributedString {
        var result = AttributedString()
        var run = ""
        for character in NoteNames.glyphs(name) {
            if character == NoteNames.sharpSign || character == NoteNames.flatSign {
                if !run.isEmpty { result.append(AttributedString(run)) }
                run = ""
                var mark = AttributedString(String(character))
                mark.font = sign
                result.append(mark)
            } else {
                run.append(character)
            }
        }
        if !run.isEmpty { result.append(AttributedString(run)) }
        return result
    }
}
