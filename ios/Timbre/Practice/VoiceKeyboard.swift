import SwiftUI
import TimbreCore

/// Voice names notes as the rest of the app does: the drone's tonics, the chord and scale tools and the Live
/// Activity all spell through `NoteNames.name` with D♭ E♭ A♭ B♭ as flats and F♯ as a sharp. Here the same letters
/// are respelled in the player's system (Settings › Note names: B natural is H and B♭ is B in German, Re♭ in
/// solfège, Sa Re Ga in sargam), then the octave in scientific pitch ("Eb4", "H3"). These are ASCII, as data; the
/// screen shows them through the app's one formatter, `NoteNames.glyphs` (`NoteGlyphs` beside a Sora face): "E♭4".
enum VoiceNoteName {
    /// Pitch classes spelled flat (D♭ E♭ A♭ B♭); the others, F♯ among them, keep their sharp.
    static let flatClasses: Set<Int> = [1, 3, 8, 10]

    /// "Eb4": the pitch class, then the octave.
    static func name(_ midi: Int, notation: String) -> String {
        pitchClass(midi, notation: notation) + String(Int(floor(Double(midi) / 12)) - 1)
    }

    /// "Eb", "F#", "H": the pitch class alone, in `notation`.
    static func pitchClass(_ midi: Int, notation: String) -> String {
        let pc = PitchMath.pitchClass(midi: midi)
        let letter = (flatClasses.contains(pc) ? NoteNames.flats : NoteNames.sharps)[pc]
        return NoteNames.spell(letter, system: notation.lowercased())
    }
}

/// Android's one-octave target keyboard, including the same allowed singing range.
struct VoiceKeyboard: View {
    let targetMidi: Int
    let notation: String
    let editable: Bool
    let onSelect: (Int) -> Void
    @Environment(\.layoutDirection) private var direction

    private let naturals = [0, 2, 4, 5, 7, 9, 11]
    private let accidentals = [0, 1, 3, 4, 5]
    private var base: Int { Int(floor(Double(targetMidi) / 12)) * 12 }
    /// "E♭3": as shown and read by VoiceOver ("E flat 3").
    private func label(_ midi: Int) -> String { NoteNames.glyphs(VoiceNoteName.name(midi, notation: notation)) }
    private func accessibleLabel(_ midi: Int) -> String {
        String(format: NSLocalizedString("timbre_voice_keyboard_target", value: "Target %1$@", comment: ""), label(midi))
    }
    var body: some View {
        GeometryReader { geometry in
            let keyWidth = geometry.size.width / 7
            let blackWidth = keyWidth * 0.6
            ZStack(alignment: .topLeading) {
                HStack(spacing: 2) {
                    ForEach(naturals, id: \.self) { semitone in
                        let midi = base + semitone
                        let selected = midi == targetMidi
                        let allowed = (45...81).contains(midi)
                        Button { onSelect(midi) } label: {
                            VStack {
                                Spacer(minLength: 0)
                                Text(label(midi)).font(.caption).lineLimit(1).minimumScaleFactor(0.55).padding(.bottom, 10)
                            }
                            .frame(maxWidth: .infinity).frame(height: 102)
                            .foregroundStyle(Palette.onAccent)
                            .background(selected ? AnyShapeStyle(Palette.mint) : AnyShapeStyle(Color(hex: 0xF4EEE4).opacity(allowed ? 1 : 0.35)), in: RoundedRectangle(cornerRadius: 6))
                            .contentShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                        .disabled(!editable || !allowed)
                        .accessibilityLabel(accessibleLabel(midi))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("voice.key.\(midi)")
                    }
                }
                ForEach(accidentals, id: \.self) { whiteIndex in
                    let midi = base + naturals[whiteIndex] + 1
                    let selected = midi == targetMidi
                    let x = direction == .rightToLeft
                        ? -keyWidth * CGFloat(whiteIndex + 1) + blackWidth / 2
                        : keyWidth * CGFloat(whiteIndex + 1) - blackWidth / 2
                    Button { onSelect(midi) } label: {
                        VStack {
                            Spacer(minLength: 0)
                            // The selected black key names itself as the target above does ("E♭", "F♯", "B" in German).
                            if selected {
                                Text(verbatim: NoteNames.glyphs(VoiceNoteName.pitchClass(midi, notation: notation)))
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1).minimumScaleFactor(0.5)
                                    .padding(.horizontal, 2).padding(.bottom, 5)
                            }
                        }
                        .frame(width: blackWidth, height: 60)
                        .foregroundStyle(Palette.onAccent)
                        .background(selected ? Palette.brass : Color(hex: 0x141110), in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Palette.line, lineWidth: 1))
                        .contentShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .disabled(!editable || !(45...81).contains(midi))
                    .accessibilityLabel(accessibleLabel(midi))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("voice.key.\(midi)")
                    .offset(x: x)
                }
            }
        }
        .frame(height: 102)
    }
}
