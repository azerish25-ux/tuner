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
                            .foregroundStyle(Color(hex: 0x1A1206))
                            .background(selected ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xF1D69E), Color(hex: 0xC8954A)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color(hex: 0xF4EEE4).opacity(allowed ? 1 : 0.35)), in: RoundedRectangle(cornerRadius: 6))
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
                        .foregroundStyle(Color(hex: 0x1A1206))
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
