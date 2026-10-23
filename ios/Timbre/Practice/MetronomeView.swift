import QuartzCore
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
    /// The pendulum gives up height so tempo, trainer and the meter card (beats, meter, sound) end above the dock.
    @State private var pendulumHeight: CGFloat = 184
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                pendulum.frame(height: pendulumHeight)
                tempo
                trainerControls
                meter
            }
            // Clears the dock's fade, so the sound control rests fully above the bar.
            .padding(.horizontal, Metrics.gutter).padding(.bottom, 24)
        }
        .fitsHero($pendulumHeight, in: 100...184)
        .stageTopShade()
        .background(StageBackground(motes: false))
        .navigationTitle("Metronome")
        .navigationBarTitleDisplayMode(.inline)
        .stageDock { transport }
        .onChange(of: store.bpm) { old, new in reanchor(from: old, to: new) }
        .onChange(of: audio.metronomeRunning) { _, running in
            if running { anchor = Date(); anchorBpm = store.bpm; alignToClick() } else { trainerTask?.cancel() }
        }
        .onDisappear { trainerTask?.cancel() }
    }

    private func beatPosition(at date: Date) -> Double { date.timeIntervalSince(anchor) * Double(anchorBpm) / 60 }

    private func reanchor(from old: Int, to new: Int) {
        guard audio.metronomeRunning else { return }
        let position = beatPosition(at: Date())
        anchorBpm = new
        anchor = Date().addingTimeInterval(-position * 60 / Double(new))
    }

    /// Moves the beat clock onto the first click as it is heard (engine start-up and output latency
    /// included) once audio is flowing, so the glow and the pendulum land with the sound.
    private func alignToClick() {
        let bpm = store.bpm
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard audio.metronomeRunning, anchorBpm == bpm, store.bpm == bpm, let origin = audio.metronomeOrigin() else { return }
            let heard = Date().addingTimeInterval(origin - CACurrentMediaTime())
            // A start-up delay, never a stale clock.
            guard abs(heard.timeIntervalSince(anchor)) < 0.75 else { return }
            anchor = heard
        }
    }

    /// Where the click is at `date`: the beat in the bar, a flash that peaks on the click and fades within
    /// a third of the beat (none on silent beats), and whether the beat is accented (beat 1 by default).
    private func moment(at date: Date) -> BeatMoment {
        guard audio.metronomeRunning else { return BeatMoment() }
        let position = beatPosition(at: date)
        let count = max(1, store.beats)
        let whole = Int(floor(position))
        let beat = ((whole % count) + count) % count
        let levels = store.beatLevels
        let level = levels.indices.contains(beat) ? levels[beat] : 1
        let fraction = position - floor(position)
        let flash = position < 0 || level == 0 ? 0 : max(0, 1 - fraction * 3.5)
        return BeatMoment(position: position, flash: flash, accent: level == 2, running: true)
    }

    /// The pendulum swings through the centre on every click, its soft trail behind it; the bob and the
    /// space around it flare on each beat, amber with a ring on an accent. Reduce Motion: it hangs still
    /// (no swing, no trail, no ring) and only glows with the beat.
    private var pendulum: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 30 : nil, paused: !audio.metronomeRunning)) { timeline in
            let now = moment(at: timeline.date)
            let still = reduceMotion
            Canvas { context, size in
                PendulumArt.draw(&context, size: size, moment: now, still: still)
            }
        }
        .accessibilityHidden(true)
    }

    /// A soft light behind the tempo that breathes with the click: mint on each beat, amber on an accent.
    private var tempoGlow: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !audio.metronomeRunning)) { timeline in
            let now = moment(at: timeline.date)
            Canvas { context, size in
                guard now.flash > 0, size.height > 0 else { return }
                let tint = now.accent ? Palette.ember : Palette.brass
                // A circle of light stretched to the canvas, so it fades out before every edge.
                let radius = size.height / 2
                var glow = context
                glow.translateBy(x: size.width / 2, y: size.height / 2)
                glow.scaleBy(x: size.width / size.height, y: 1)
                glow.fill(Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)),
                          with: .radialGradient(Gradient(colors: [tint.opacity((now.accent ? 0.34 : 0.22) * now.flash), .clear]),
                                                center: .zero, startRadius: 0, endRadius: radius))
            }
        }
        .frame(width: 280, height: 170)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var tempo: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Button { store.setMetronome(bpm: store.bpm - 1) } label: { Image(systemName: "minus").frame(width: 44, height: 44) }
                    .buttonStyle(.plain).foregroundStyle(Palette.inkSoft).accessibilityLabel("Slower")
                Text("\(store.bpm)").font(Typeface.display(80)).foregroundStyle(Palette.ink).contentTransition(.numericText()).monospacedDigit()
                    // VoiceOver: swipe up or down to change the tempo a beat per minute at a time.
                    .adjustableValue(Text("Tempo"), value: Text(verbatim: "\(store.bpm), \(tempoName)"),
                                     increment: { store.setMetronome(bpm: store.bpm + 1) },
                                     decrement: { store.setMetronome(bpm: store.bpm - 1) })
                    .accessibilityIdentifier("metronome.bpm")
                Button { store.setMetronome(bpm: store.bpm + 1) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                    .buttonStyle(.plain).foregroundStyle(Palette.inkSoft).accessibilityLabel("Faster")
            }
            .background { tempoGlow }
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
    }

    private func levelName(_ level: Int) -> String {
        switch level {
        case 2: return String(localized: "accent")
        case 1: return String(localized: "normal")
        default: return String(localized: "silent")
        }
    }

    /// The whole groove in one card: the bar's beats (lit as they click, tapped for accents), the meter, the
    /// subdivision and the sound.
    private var meter: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Meter")
            beatRow
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
            soundPicker.padding(.top, 4)
        }
        .stillCard(padding: 16)
    }

    /// Click, wood or beep: part of the meter card, so the whole groove is set in one place. Its name and
    /// control share a line when they fit (large text stacks them).
    private var soundPicker: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                soundLabel
                Spacer(minLength: 12)
                soundControl.fixedSize()
            }
            VStack(alignment: .leading, spacing: 10) {
                soundLabel
                soundControl
            }
        }
    }

    private var soundLabel: some View {
        HStack(spacing: 8) {
            Eyebrow("Sound")
            if !commerce.isPro { ProBadge() }
        }
    }

    private var soundControl: some View {
        Picker("Sound", selection: Binding(get: { store.metronomeSound }, set: { value in
            if commerce.isPro { store.setMetronome(sound: value) } else { store.presentPaywall("metronome.sound") }
        })) {
            Text("Click").tag(MetronomeRenderer.Sound.click)
            Text("Wood").tag(MetronomeRenderer.Sound.wood)
            Text("Beep").tag(MetronomeRenderer.Sound.beep)
        }
        .pickerStyle(.segmented)
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
                        .adjustableValue(Text("Step: \(trainerStep) BPM"), value: Text(verbatim: "\(trainerStep)"),
                                         increment: { trainerStep = min(20, trainerStep + 1) }, decrement: { trainerStep = max(1, trainerStep - 1) })
                    Stepper("Every \(trainerEvery) bars", value: $trainerEvery, in: 1...16)
                        .adjustableValue(Text("Every \(trainerEvery) bars"), value: Text(verbatim: "\(trainerEvery)"),
                                         increment: { trainerEvery = min(16, trainerEvery + 1) }, decrement: { trainerEvery = max(1, trainerEvery - 1) })
                    Stepper("Target \(trainerTarget) BPM", value: $trainerTarget, in: 40...300, step: 2)
                        .adjustableValue(Text("Target \(trainerTarget) BPM"), value: Text(verbatim: "\(trainerTarget)"),
                                         increment: { trainerTarget = min(300, trainerTarget + 2) }, decrement: { trainerTarget = max(40, trainerTarget - 2) })
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

/// One instant of the click, for drawing.
private struct BeatMoment {
    /// Beats since the clock's anchor (0 at rest).
    var position: Double = 0
    /// 1 on the click, fading to 0 within a third of the beat.
    var flash: Double = 0
    var accent = false
    var running = false
}

/// The metronome hero in one pass: the arc of travel, the trail, the rod, the beat light, the bob.
private enum PendulumArt {
    /// Widest swing either side, in radians.
    static let reach = 0.42
    /// How far back the trail reaches, in beats: the same shape at any tempo.
    static let trailBeats = 0.3

    static func draw(_ context: inout GraphicsContext, size: CGSize, moment: BeatMoment, still: Bool) {
        let pivot = CGPoint(x: size.width / 2, y: 14)
        // Leaves room under the bob so its beat glow fades out inside the canvas.
        let length = max(40, size.height - 62)
        let swings = moment.running && !still
        func bob(at position: Double) -> CGPoint {
            let angle = swings ? sin(position * .pi) * reach : 0  // one side per beat, through the centre on the click
            return CGPoint(x: pivot.x + CGFloat(sin(angle)) * length, y: pivot.y + CGFloat(cos(angle)) * length)
        }
        let here = bob(at: moment.position)
        let flash = moment.flash
        let tint = moment.accent ? Palette.ember : Palette.brass

        // An accent warms the stage around the pendulum, inside the canvas.
        if moment.accent && flash > 0 {
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2
            context.fill(circle(center, r), with: .radialGradient(Gradient(colors: [Palette.ember.opacity(0.12 * flash), .clear]),
                                                                  center: center, startRadius: 0, endRadius: r))
        }

        var arc = Path()
        arc.addArc(center: pivot, radius: length, startAngle: .radians(.pi / 2 - 0.46), endAngle: .radians(.pi / 2 + 0.46), clockwise: false)
        context.stroke(arc, with: .color(Palette.line), style: StrokeStyle(lineWidth: 2, dash: [2, 6]))

        if swings { trail(&context, tint: tint, position: moment.position, bob: bob) }

        var rod = Path(); rod.move(to: pivot); rod.addLine(to: here)
        context.stroke(rod, with: .linearGradient(Gradient(colors: [Palette.brassDeep, Palette.brass]), startPoint: pivot, endPoint: here), lineWidth: 3)

        // The beat light around the bob.
        let r: CGFloat = 26 + 10 * CGFloat(flash)
        context.fill(circle(here, r * 1.5), with: .radialGradient(Gradient(colors: [tint.opacity(0.5 * flash + 0.08), .clear]),
                                                                  center: here, startRadius: 0, endRadius: r * 1.5))
        // An accent sends a ring out from the bob.
        if moment.accent && flash > 0 && !still {
            context.stroke(circle(here, 24 + 20 * CGFloat(1 - flash)), with: .color(Palette.ember.opacity(0.75 * flash)), lineWidth: 2)
        }
        context.fill(circle(here, 22), with: .linearGradient(Gradient(colors: [Color(hex: 0x8BF7D2), Palette.mintDeep]),
                                                             startPoint: CGPoint(x: here.x, y: here.y - 22), endPoint: CGPoint(x: here.x, y: here.y + 22)))
        // The bob itself flushes amber on an accent.
        if moment.accent && flash > 0 {
            context.fill(circle(here, 22), with: .color(Palette.ember.opacity(0.55 * flash)))
        }
        context.fill(circle(CGPoint(x: here.x - 7, y: here.y - 8), 6), with: .color(.white.opacity(0.16 + 0.2 * flash)))
        context.fill(circle(pivot, 6), with: .color(Palette.brass))
    }

    /// A soft ribbon where the bob just was, fading with age, blurred once as a single layer.
    private static func trail(_ context: inout GraphicsContext, tint: Color, position: Double, bob: @escaping (Double) -> CGPoint) {
        let steps = 14
        var soft = context
        soft.addFilter(.blur(radius: 6))
        soft.drawLayer { layer in
            var previous = bob(position - trailBeats)
            for step in 1...steps {
                let point = bob(position - trailBeats * Double(steps - step) / Double(steps))
                var segment = Path()
                segment.move(to: previous)
                segment.addLine(to: point)
                let age = Double(step) / Double(steps)
                layer.stroke(segment, with: .color(tint.opacity(0.3 * age)), style: StrokeStyle(lineWidth: 28 * CGFloat(0.55 + 0.45 * age), lineCap: .round))
                previous = point
            }
        }
    }

    private static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}
