import SwiftUI
import TimbreCore

struct MetronomeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var commerce: CommerceService
    @State private var anchor = Date()
    @State private var anchorBpm = 96
    @State private var trainer = false
    @State private var trainerStep = 4
    @State private var trainerEvery = 4
    @State private var trainerTarget = 140
    @State private var trainerTask: Task<Void, Never>?
    /// The pendulum gives up height so tempo, trainer, beats and meter end above the dock.
    @State private var pendulumHeight: CGFloat = 184
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                pendulum.frame(height: pendulumHeight)
                tempo
                trainerControls
                beatRow
                meter
            }
            .padding(.horizontal, Metrics.gutter).padding(.bottom, 30)
        }
        .fitsHero($pendulumHeight, in: 120...184)
        .stageTopShade()
        .background(StageBackground(motes: false))
        .navigationTitle("Metronome")
        .navigationBarTitleDisplayMode(.inline)
        .stageDock { transport }
        .onChange(of: store.bpm) { old, new in reanchor(from: old, to: new) }
        .onChange(of: audio.metronomeRunning) { _, running in if running { anchor = Date(); anchorBpm = store.bpm } else { trainerTask?.cancel() } }
        .onDisappear { trainerTask?.cancel() }
    }

    private func beatPosition(at date: Date) -> Double { date.timeIntervalSince(anchor) * Double(anchorBpm) / 60 }

    private func reanchor(from old: Int, to new: Int) {
        guard audio.metronomeRunning else { return }
        let position = beatPosition(at: Date())
        anchorBpm = new
        anchor = Date().addingTimeInterval(-position * 60 / Double(new))
    }

    private var pendulum: some View {
        TimelineView(.animation(paused: !audio.metronomeRunning || reduceMotion)) { timeline in
            let position = audio.metronomeRunning ? beatPosition(at: timeline.date) : 0
            let swing = sin(position * .pi)  // one side per beat
            let beat = Int(floor(position)) % max(1, store.beats)
            let frac = position - floor(position)
            let flash = audio.metronomeRunning ? max(0, 1 - frac * 3.5) : 0
            Canvas { context, size in
                let pivot = CGPoint(x: size.width / 2, y: 14)
                // Leaves room under the bob so its beat glow fades out inside the canvas.
                let length = size.height - 62
                let angle = swing * 0.42
                let bob = CGPoint(x: pivot.x + sin(angle) * length, y: pivot.y + cos(angle) * length)
                // Arc of travel
                var arc = Path()
                arc.addArc(center: pivot, radius: length, startAngle: .radians(.pi / 2 - 0.46), endAngle: .radians(.pi / 2 + 0.46), clockwise: false)
                context.stroke(arc, with: .color(Palette.line), style: StrokeStyle(lineWidth: 2, dash: [2, 6]))
                var rod = Path(); rod.move(to: pivot); rod.addLine(to: bob)
                context.stroke(rod, with: .linearGradient(Gradient(colors: [Palette.brassDeep, Palette.brass]), startPoint: pivot, endPoint: bob), lineWidth: 3)
                let accent = store.beatLevels.indices.contains(beat) && store.beatLevels[beat] == 2
                let glowColor = accent ? Palette.ember : Palette.brass
                let r: CGFloat = 26 + 10 * flash
                context.fill(Path(ellipseIn: CGRect(x: bob.x - r * 1.5, y: bob.y - r * 1.5, width: r * 3, height: r * 3)),
                             with: .radialGradient(Gradient(colors: [glowColor.opacity(0.45 * flash + 0.08), .clear]), center: bob, startRadius: 0, endRadius: r * 1.5))
                context.fill(Path(ellipseIn: CGRect(x: bob.x - 22, y: bob.y - 22, width: 44, height: 44)),
                             with: .linearGradient(Gradient(colors: [Color(hex: 0x8BF7D2), Palette.mintDeep]), startPoint: CGPoint(x: bob.x, y: bob.y - 22), endPoint: CGPoint(x: bob.x, y: bob.y + 22)))
                context.fill(Path(ellipseIn: CGRect(x: pivot.x - 6, y: pivot.y - 6, width: 12, height: 12)), with: .color(Palette.brass))
            }
        }
        .accessibilityHidden(true)
    }

    private var tempo: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Button { store.setMetronome(bpm: store.bpm - 1) } label: { Image(systemName: "minus").frame(width: 44, height: 44) }
                    .buttonStyle(.plain).foregroundStyle(Palette.inkSoft).accessibilityLabel("Slower")
                Text("\(store.bpm)").font(Typeface.display(80)).foregroundStyle(Palette.ink).contentTransition(.numericText()).monospacedDigit()
                    .accessibilityIdentifier("metronome.bpm")
                Button { store.setMetronome(bpm: store.bpm + 1) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                    .buttonStyle(.plain).foregroundStyle(Palette.inkSoft).accessibilityLabel("Faster")
            }
            Text("\(tempoName) · beats per minute").font(.subheadline).foregroundStyle(Palette.inkSoft)
            Slider(value: Binding(get: { Double(store.bpm) }, set: { store.setMetronome(bpm: Int($0)) }), in: 30...300, step: 1)
                .tint(Palette.brass).padding(.horizontal, 8)
                .accessibilityLabel("Tempo")
        }
        .animation(Motion.quick, value: store.bpm)
    }

    private var tempoName: String {
        switch store.bpm {
        case ..<60: return String(localized: "Largo")
        case ..<76: return String(localized: "Adagio")
        case ..<108: return String(localized: "Andante")
        case ..<120: return String(localized: "Moderato")
        case ..<168: return String(localized: "Allegro")
        default: return String(localized: "Presto")
        }
    }

    private var beatRow: some View {
        TimelineView(.animation(paused: !audio.metronomeRunning)) { timeline in
            let position = audio.metronomeRunning ? beatPosition(at: timeline.date) : -1
            let current = position < 0 ? -1 : Int(floor(position)) % max(1, store.beats)
            HStack(spacing: 10) {
                ForEach(0..<store.beats, id: \.self) { beat in
                    let level = store.beatLevels.indices.contains(beat) ? store.beatLevels[beat] : 1
                    Button { if commerce.isPro { store.cycleBeatLevel(beat) } else { store.presentPaywall("metronome.accents") } } label: {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 6).fill(level == 0 ? Palette.line : (level == 2 ? Palette.ember : Palette.brass))
                                .frame(width: 22, height: level == 2 ? 34 : (level == 1 ? 22 : 10))
                                .opacity(current == beat ? 1 : 0.45)
                                .shadow(color: (level == 2 ? Palette.ember : Palette.brass).opacity(current == beat ? 0.8 : 0), radius: 10)
                            Text("\(beat + 1)").font(Typeface.number(11)).foregroundStyle(Palette.inkFaint)
                        }
                        .frame(height: 54, alignment: .bottom)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Beat \(beat + 1), \(levelName(level))"))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .stillCard(padding: 12)
    }

    private func levelName(_ level: Int) -> String {
        switch level {
        case 2: return String(localized: "accent")
        case 1: return String(localized: "normal")
        default: return String(localized: "silent")
        }
    }

    private var meter: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Meter")
            EdgeRail(bleed: 16, selection: store.beats) {
                ForEach([2, 3, 4, 5, 6, 7, 9, 12], id: \.self) { value in
                    Button("\(value)/\(value == 6 || value == 9 || value == 12 ? 8 : 4)") { store.setMetronome(beats: value) }
                        .buttonStyle(ChipButtonStyle(selected: store.beats == value))
                        .id(value)
                }
            }
            HStack(spacing: 8) {
                ForEach(1...4, id: \.self) { value in
                    Button { if commerce.isPro || value == 1 { store.setMetronome(subdivision: value) } else { store.presentPaywall("metronome.subdivision") } } label: {
                        Image(systemName: ["music.note", "music.note.list", "triangle", "square.grid.2x2"][value - 1]).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChipButtonStyle(selected: store.subdivision == value))
                    .accessibilityLabel(Text(["Quarter notes", "Eighth notes", "Triplets", "Sixteenth notes"][value - 1]))
                }
            }
            soundPicker.padding(.top, 6)
        }
        .stillCard(padding: 16)
    }

    /// Click, wood or beep: part of the meter card, so the whole groove is set in one place.
    private var soundPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Eyebrow("Sound"); Spacer(); if !commerce.isPro { ProBadge() } }
            Picker("Sound", selection: Binding(get: { store.metronomeSound }, set: { value in
                if commerce.isPro { store.setMetronome(sound: value) } else { store.presentPaywall("metronome.sound") }
            })) {
                Text("Click").tag(MetronomeRenderer.Sound.click)
                Text("Wood").tag(MetronomeRenderer.Sound.wood)
                Text("Beep").tag(MetronomeRenderer.Sound.beep)
            }
            .pickerStyle(.segmented)
        }
    }

    /// The speed trainer sits right under the tempo it drives, so it is never parked under the dock;
    /// its steps open beneath it when it's on.
    private var trainerControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "speedometer").font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(trainer ? Palette.mint : Palette.inkSoft)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Speed trainer").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                        if !commerce.isPro { ProBadge() }
                    }
                    Text("+\(trainerStep) BPM every \(trainerEvery) bars up to \(trainerTarget)").font(.caption).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("Speed trainer", isOn: Binding(get: { trainer }, set: { on in
                    guard commerce.isPro else { store.presentPaywall("metronome.trainer"); return }
                    withAnimation(Motion.settle) { trainer = on }
                }))
                .labelsHidden()
                .tint(Palette.brass)
            }
            if trainer {
                VStack(spacing: 6) {
                    Stepper("Step: \(trainerStep) BPM", value: $trainerStep, in: 1...20)
                    Stepper("Every \(trainerEvery) bars", value: $trainerEvery, in: 1...16)
                    Stepper("Target \(trainerTarget) BPM", value: $trainerTarget, in: 40...300, step: 2)
                }
                .font(.subheadline)
                .foregroundStyle(Palette.ink)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.stageRaised))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(trainer ? Palette.mint.opacity(0.35) : .white.opacity(0.06), lineWidth: 1))
    }

    private var transport: some View {
        HStack(spacing: 12) {
            Button { store.tapTempo() } label: { Label("Tap", systemImage: "hand.tap.fill") }
                .buttonStyle(BrassButtonStyle(prominent: false)).frame(width: 120)
                .accessibilityIdentifier("metronome.tap")
            Button {
                store.toggleMetronome()
                if audio.metronomeRunning && trainer { startTrainer() } else { trainerTask?.cancel() }
            } label: {
                Label(audio.metronomeRunning ? "Stop" : "Start", systemImage: audio.metronomeRunning ? "stop.fill" : "play.fill")
            }
            .buttonStyle(BrassButtonStyle())
            .accessibilityIdentifier("metronome.start")
        }
    }

    private func startTrainer() {
        trainerTask?.cancel()
        trainerTask = Task { @MainActor in
            var lastBar = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard audio.metronomeRunning else { continue }
                let bar = Int(floor(beatPosition(at: Date()) / Double(max(1, store.beats))))
                if bar >= lastBar + trainerEvery, store.bpm < trainerTarget {
                    lastBar = bar
                    store.setMetronome(bpm: min(trainerTarget, store.bpm + trainerStep))
                }
            }
        }
    }
}
