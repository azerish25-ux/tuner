import SwiftUI
import TimbreCore

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
    private func label(_ midi: Int) -> String { PitchMath.noteName(midi: midi, notation: notation) }
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
                            .foregroundStyle(TimbreTheme.ink)
                            .background(selected ? TimbreTheme.brass : Color.white.opacity(allowed ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 4))
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
                            if selected { Text("♯").font(.caption.weight(.semibold)).padding(.bottom, 4) }
                        }
                        .frame(width: blackWidth, height: 60)
                        .foregroundStyle(TimbreTheme.ink)
                        .background(selected ? TimbreTheme.brass : Color(hex: 0x0C1014), in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(TimbreTheme.secondary.opacity(0.5), lineWidth: 1))
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
