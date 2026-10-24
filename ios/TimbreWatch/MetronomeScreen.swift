import SwiftUI

/// The wrist metronome: the bar as a ring around the tempo, turned with the Digital Crown. A tap on the ring (or the
/// round button) starts and stops it; the chip beside it steps the meter 2/4…7/4 and Tap sets the tempo by tapping.
struct MetronomeScreen: View {
    /// This page is the one showing: it takes the Digital Crown.
    let selected: Bool
    @EnvironmentObject private var metronome: WristMetronome
    @Environment(\.isLuminanceReduced) private var dimmed
    @FocusState private var crownFocused: Bool

    private static let rowHeight: CGFloat = 40

    var body: some View {
        GeometryReader { proxy in
            let side = max(60, min(proxy.size.width, proxy.size.height - Self.rowHeight - 6))
            VStack(spacing: 6) {
                dial(side: side)
                controls
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .focusable()
        .focused($crownFocused)
        .focusEffectDisabled()
        .digitalCrownRotation($metronome.crownTempo, from: Double(WristMetronome.tempoRange.lowerBound),
                              through: Double(WristMetronome.tempoRange.upperBound), by: 1, sensitivity: .medium,
                              isContinuous: false, isHapticFeedbackEnabled: !metronome.running)
        .onAppear { if selected { crownFocused = true } }
        .onChange(of: selected) { _, now in if now { crownFocused = true } }
        .containerBackground(Self.background, for: .tabView)
    }

    private static let background = LinearGradient(colors: [Palette.mint.opacity(0.16), Palette.stage], startPoint: .top, endPoint: .bottom)

    // MARK: Dial

    private func dial(side: CGFloat) -> some View {
        Button { metronome.toggle() } label: {
            ZStack {
                BeatRing(beats: metronome.beatsPerBar, current: metronome.beat, pulse: metronome.pulse,
                         fade: min(0.35, metronome.interval * 0.7), dimmed: dimmed)
                    .frame(width: side, height: side)
                center(side: side)
            }
            .frame(width: side, height: side)
            .contentShape(Circle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Metronome"))
        .accessibilityValue(Text(verbatim: "\(metronome.bpm), \(metronome.beatsPerBar)/4"))
        .accessibilityHint(metronome.running ? Text("Stop") : Text("Start"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: metronome.setTempo(metronome.bpm + 1)
            case .decrement: metronome.setTempo(metronome.bpm - 1)
            @unknown default: break
            }
        }
    }

    private func center(side: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text(metronome.bpm, format: .number)
                .font(Typeface.display(side * 0.3, relativeTo: .title))
                .monospacedDigit()
                .foregroundStyle(dimmed ? Palette.inkSoft : Palette.ink)
                .contentTransition(.numericText(value: Double(metronome.bpm)))
                .animation(.snappy(duration: 0.2), value: metronome.bpm)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            tempoName
                .font(Typeface.label(max(9, side * 0.085)))
                .foregroundStyle(Palette.mint.opacity(dimmed ? 0.6 : 1))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if dimmed && metronome.running {
                Text("Taps resume when you raise your wrist")
                    .font(.system(size: max(8, side * 0.07)))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 2)
            }
        }
        .frame(width: side * 0.66)
    }

    /// The tempo's Italian name, as the iPhone metronome shows it.
    private var tempoName: Text {
        switch metronome.bpm {
        case ..<60: return Text("Largo")
        case ..<76: return Text("Adagio")
        case ..<108: return Text("Andante")
        case ..<120: return Text("Moderato")
        case ..<168: return Text("Allegro")
        default: return Text("Presto")
        }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 6) {
            Button { metronome.cycleMeter() } label: {
                Text(verbatim: "\(metronome.beatsPerBar)/4")
                    .font(Typeface.number(15))
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: Self.rowHeight)
                    .background(Capsule().fill(Palette.stageRaised))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel(Text("Meter"))
            .accessibilityValue(Text(verbatim: "\(metronome.beatsPerBar)/4"))

            Button { metronome.toggle() } label: {
                Image(systemName: metronome.running ? "stop.fill" : "play.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.onAccent)
                    .frame(width: Self.rowHeight + 4, height: Self.rowHeight + 4)
                    .background(Circle().fill(metronome.running ? Palette.amber : Palette.mint))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel(metronome.running ? Text("Stop") : Text("Start"))

            Button { metronome.tap() } label: {
                Text("Tap")
                    .font(Typeface.label(14))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, minHeight: Self.rowHeight)
                    .background(Capsule().fill(Palette.stageRaised))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel(Text("Tap"))
            .accessibilityHint(Text("Tempo"))
        }
        .opacity(dimmed ? 0.5 : 1)
    }
}
