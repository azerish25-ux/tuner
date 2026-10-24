import QuartzCore
import SwiftUI
import TimbreCore

/// The metronome: a long pendulum swinging across the hero in time with the click (through the centre on each
/// beat, where a beam lights), a ring round the tempo that pulses with every click, the speed trainer, the meter
/// card, and the bar's beats right above Start, lit as they sound. Accents flash amber everywhere at once.
/// Every light follows one beat clock, moved onto the audio's own click clock once the first click is heard.
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
    /// The pendulum gives up height so tempo, trainer and the meter card end above the dock.
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
        .fitsHero($pendulumHeight, in: 100...200)
        .stageTopShade()
        .background {
            ZStack {
                StageBackground(motes: false)
                accentWash
            }
        }
        .navigationTitle("Metronome")
        .navigationBarTitleDisplayMode(.inline)
        .stageDock {
            VStack(spacing: 10) {
                beatStrip
                transport
            }
        }
        .onChange(of: store.bpm) { old, new in reanchor(from: old, to: new) }
        .onChange(of: store.beats) { _, _ in restartBar() }
        .onChange(of: store.subdivision) { _, _ in restartBar() }
        .onChange(of: audio.metronomeRunning) { _, running in
            if running { anchor = Date(); anchorBpm = store.bpm; alignToClick() } else { trainerTask?.cancel() }
        }
        .onDisappear { trainerTask?.cancel() }
    }

    private func beatPosition(at date: Date) -> Double { date.timeIntervalSince(anchor) * Double(anchorBpm) / 60 }

    /// A tempo change keeps the beat's phase, as the renderer does.
    private func reanchor(from old: Int, to new: Int) {
        guard audio.metronomeRunning else { return }
        let position = beatPosition(at: Date())
        anchorBpm = new
        anchor = Date().addingTimeInterval(-position * 60 / Double(new))
    }

    /// Moves the beat clock onto the first click as it is heard (engine start-up and output latency included),
    /// read from the audio's click clock once its first buffer has played, so the pendulum, the ring and the beat
    /// lights land with the sound.
    private func alignToClick() {
        let bpm = store.bpm
        Task { @MainActor in
            for _ in 0..<10 {
                try? await Task.sleep(for: .milliseconds(120))
                guard audio.metronomeRunning, anchorBpm == bpm, store.bpm == bpm else { return }
                guard let origin = audio.metronomeOrigin() else { continue }
                let heard = Date().addingTimeInterval(origin - CACurrentMediaTime())
                // A start-up delay, never a stale clock.
                guard abs(heard.timeIntervalSince(anchor)) < 0.75 else { return }
                anchor = heard
                return
            }
        }
    }

    /// A new meter or subdivision starts the bar again from beat 1 at once (the renderer does), heard after the
    /// route's delay (the audio clock's heard origin less its rendered one): the beat clock starts with it.
    private func restartBar() {
        guard audio.metronomeRunning else { return }
        var delay = 0.0
        if let heard = audio.metronomeOrigin(), let rendered = audio.metronomeRenderOrigin() {
            delay = min(0.5, max(0, heard - rendered))
        }
        anchor = Date().addingTimeInterval(delay)
        anchorBpm = store.bpm
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

    // MARK: Hero

    /// The pendulum hangs from a pivot above the screen and swings wide across the hero, through the centre on
    /// every click. Reduce Motion: it hangs still and only the lights keep time.
    private var pendulum: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 30 : nil, paused: !audio.metronomeRunning)) { timeline in
            let now = moment(at: timeline.date)
            let still = reduceMotion
            let bpm = Double(store.bpm)
            Canvas { context, size in
                PendulumArt.draw(&context, size: size, moment: now, still: still, bpm: bpm)
            }
        }
        .accessibilityHidden(true)
    }

    /// An accent washes the top of the stage amber for a moment; other beats barely warm it.
    private var accentWash: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !audio.metronomeRunning)) { timeline in
            let now = moment(at: timeline.date)
            let tint = now.accent ? Palette.ember : Palette.brass
            RadialGradient(colors: [tint.opacity((now.accent ? 0.2 : 0.05) * now.flash), .clear],
                           center: UnitPoint(x: 0.5, y: 0.18), startRadius: 10, endRadius: 440)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
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

    /// The ring round the tempo, kept in time by the beat clock.
    private var tempoRing: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 30 : 1.0 / 60, paused: !audio.metronomeRunning)) { timeline in
            TempoRing(moment: moment(at: timeline.date), still: reduceMotion)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var tempo: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                Button { store.setMetronome(bpm: store.bpm - 1) } label: { Image(systemName: "minus").frame(width: 44, height: 44) }
                    .buttonStyle(.plain).foregroundStyle(Palette.inkSoft).accessibilityLabel("Slower")
                Text("\(store.bpm)").font(Typeface.display(80)).foregroundStyle(Palette.ink).contentTransition(.numericText()).monospacedDigit()
                    .background { tempoRing.padding(.horizontal, -16).padding(.vertical, -2) }
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

    // MARK: Beats

    /// The bar's beats in the band above Start: they light as they click (the beat pops, an accent flares
    /// amber), and a tap cycles a beat between accent, normal and silent (Pro).
    private var beatStrip: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 30 : nil, paused: !audio.metronomeRunning)) { timeline in
            let position = audio.metronomeRunning ? beatPosition(at: timeline.date) : -1
            let count = max(1, store.beats)
            let current = position < 0 ? -1 : Int(floor(position)) % count
            let flash = position < 0 ? 0 : max(0, 1 - (position - floor(position)) * 3.5)
            HStack(spacing: count > 8 ? 4 : 8) {
                ForEach(0..<store.beats, id: \.self) { beat in
                    beatCell(beat, lit: beat == current, flash: flash)
                }
            }
        }
        .frame(height: 50)
    }

    private func beatCell(_ beat: Int, lit: Bool, flash: Double) -> some View {
        let level = store.beatLevels.indices.contains(beat) ? store.beatLevels[beat] : 1
        let tint = level == 2 ? Palette.ember : Palette.brass
        let height: CGFloat = level == 2 ? 30 : (level == 1 ? 20 : 8)
        let pop: CGFloat = lit && !reduceMotion ? CGFloat(1 + 0.16 * flash) : 1
        return Button { if commerce.isPro { store.cycleBeatLevel(beat) } else { store.presentPaywall("metronome.accents") } } label: {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(level == 0 ? Palette.line : tint)
                    .frame(maxWidth: 44)
                    .frame(height: height)
                    .opacity(lit ? 1 : 0.42)
                    .scaleEffect(x: 1, y: pop, anchor: .bottom)
                    .shadow(color: tint.opacity(lit ? 0.35 + 0.5 * flash : 0), radius: 10)
                Text("\(beat + 1)").font(Typeface.number(11)).foregroundStyle(lit ? Palette.ink : Palette.inkFaint)
            }
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .bottom)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Beat \(beat + 1), \(levelName(level))"))
    }

    private func levelName(_ level: Int) -> String {
        switch level {
        case 2: return String(localized: "accent")
        case 1: return String(localized: "normal")
        default: return String(localized: "silent")
        }
    }

    /// The groove in one card: the meter, the subdivision and the sound (the beats themselves sit above Start).
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
                // A new meter restarts the bar count.
                if bar < lastBar { lastBar = bar }
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

/// A ring round the tempo that pulses with the click: a hairline at rest; on each click it lights and a second
/// ring swells out and fades, amber and bolder on an accent. Reduce Motion: it only lights.
private struct TempoRing: View {
    let moment: BeatMoment
    let still: Bool

    var body: some View {
        let flash = moment.flash
        let tint = moment.accent ? Palette.ember : Palette.brass
        ZStack {
            Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1.5)
            Capsule().strokeBorder(tint.opacity(0.85 * flash), lineWidth: moment.accent ? 3 : 2)
            if !still && flash > 0 {
                Capsule().stroke(tint.opacity(0.55 * flash), lineWidth: moment.accent ? 2 : 1.5)
                    .scaleEffect(x: CGFloat(1 + 0.14 * (1 - flash)), y: CGFloat(1 + 0.28 * (1 - flash)))
            }
        }
        .shadow(color: tint.opacity(0.45 * flash), radius: 10)
    }
}

/// The metronome hero in one pass: a long pendulum whose pivot sits above the canvas, so the bob sweeps a wide,
/// shallow arc whatever the hero's height. Under it, a printed tempo scale and the click beam at the centre; on
/// the rod, the sliding weight that sets a real metronome's tempo (higher for faster); then the trail and the bob.
private enum PendulumArt {
    /// How far back the trail reaches, in beats: the same shape at any tempo.
    static let trailBeats = 0.3

    struct Geometry {
        let pivot: CGPoint
        /// Pivot to the bob's centre.
        let radius: CGFloat
        /// Widest swing either side, in radians.
        let reach: Double
        /// The bob's radius.
        let bob: CGFloat
        /// The bob's resting height.
        var rest: CGFloat { pivot.y + radius }

        func point(_ angle: Double) -> CGPoint {
            CGPoint(x: pivot.x + CGFloat(sin(angle)) * radius, y: pivot.y + CGFloat(cos(angle)) * radius)
        }

        /// A point `distance` from the pivot along the rod at `angle`.
        func along(_ angle: Double, _ distance: CGFloat) -> CGPoint {
            CGPoint(x: pivot.x + CGFloat(sin(angle)) * distance, y: pivot.y + CGFloat(cos(angle)) * distance)
        }
    }

    static func geometry(_ size: CGSize) -> Geometry {
        let bob = min(22, max(14, size.height * 0.15))
        let rest = size.height - bob - max(12, size.height * 0.12)
        let half = min(size.width * 0.36, 150)
        let radius = max(size.height * 1.6, half * 2.4)
        let reach = asin(min(0.95, Double(half / radius)))
        return Geometry(pivot: CGPoint(x: size.width / 2, y: rest - radius), radius: radius, reach: reach, bob: bob)
    }

    static func draw(_ context: inout GraphicsContext, size: CGSize, moment: BeatMoment, still: Bool, bpm: Double) {
        guard size.width > 40, size.height > 40 else { return }
        let g = geometry(size)
        let swings = moment.running && !still
        let reach = g.reach
        let angleAt: (Double) -> Double = { position in swings ? sin(position * .pi) * reach : 0 }
        let angle = angleAt(moment.position)
        let here = g.point(angle)
        let flash = moment.flash
        let tint = moment.accent ? Palette.ember : Palette.brass
        let scale = g.bob / 22

        // An accent warms the hero round the click.
        if moment.accent && flash > 0 {
            let center = CGPoint(x: size.width / 2, y: g.rest)
            let r = size.width * 0.5
            context.fill(circle(center, r), with: .radialGradient(Gradient(colors: [Palette.ember.opacity(0.18 * flash), .clear]),
                                                                  center: center, startRadius: 0, endRadius: r))
        }

        printedScale(&context, g: g)
        beam(&context, g: g, flash: flash, tint: tint)

        if swings {
            trail(&context, tint: tint, position: moment.position, scale: scale) { g.point(angleAt($0)) }
        }

        rod(&context, g: g, angle: angle, bob: here)
        weight(&context, g: g, angle: angle, bpm: bpm)

        // The beat light around the bob.
        let r = (26 + 10 * CGFloat(flash)) * scale
        context.fill(circle(here, r * 1.5), with: .radialGradient(Gradient(colors: [tint.opacity(0.5 * flash + 0.08), .clear]),
                                                                  center: here, startRadius: 0, endRadius: r * 1.5))
        // An accent sends a ring out from the bob.
        if moment.accent && flash > 0 && !still {
            context.stroke(circle(here, g.bob + 2 + 22 * scale * CGFloat(1 - flash)), with: .color(Palette.ember.opacity(0.75 * flash)), lineWidth: 2)
        }
        context.fill(circle(here, g.bob), with: .linearGradient(Gradient(colors: [Color(hex: 0x8BF7D2), Palette.mintDeep]),
                                                                startPoint: CGPoint(x: here.x, y: here.y - g.bob), endPoint: CGPoint(x: here.x, y: here.y + g.bob)))
        // The bob itself flushes amber on an accent.
        if moment.accent && flash > 0 {
            context.fill(circle(here, g.bob), with: .color(Palette.ember.opacity(0.55 * flash)))
        }
        context.fill(circle(CGPoint(x: here.x - g.bob * 0.32, y: here.y - g.bob * 0.36), g.bob * 0.27),
                     with: .color(.white.opacity(0.16 + 0.2 * flash)))
    }

    /// The dashed arc of travel and a printed scale above it: long ticks at the centre and the ends.
    private static func printedScale(_ context: inout GraphicsContext, g: Geometry) {
        let span = g.reach * 1.08
        var arc = Path()
        arc.addArc(center: g.pivot, radius: g.radius, startAngle: .radians(.pi / 2 - span), endAngle: .radians(.pi / 2 + span), clockwise: false)
        context.stroke(arc, with: .color(Palette.line), style: StrokeStyle(lineWidth: 2, dash: [2, 6]))
        let ticks = 8
        let base = g.radius - g.bob - 8
        for k in -ticks...ticks {
            let angle = span * Double(k) / Double(ticks)
            let major = k == 0 || abs(k) == ticks || k % 4 == 0
            let length: CGFloat = k == 0 ? 11 : (major ? 7 : 4)
            var tick = Path()
            tick.move(to: g.along(angle, base))
            tick.addLine(to: g.along(angle, base - length))
            context.stroke(tick, with: .color(.white.opacity(major ? 0.22 : 0.1)), style: StrokeStyle(lineWidth: major ? 1.5 : 1, lineCap: .round))
        }
    }

    /// The click line: a beam down the centre that lights as the bob crosses it on each click.
    private static func beam(_ context: inout GraphicsContext, g: Geometry, flash: Double, tint: Color) {
        let bottom = g.rest + g.bob
        let top = CGPoint(x: g.pivot.x, y: 0)
        let foot = CGPoint(x: g.pivot.x, y: bottom)
        context.fill(Path(CGRect(x: g.pivot.x - 0.75, y: 0, width: 1.5, height: bottom)),
                     with: .linearGradient(Gradient(colors: [tint.opacity(0), tint.opacity(0.1 + 0.6 * flash)]), startPoint: top, endPoint: foot))
        guard flash > 0 else { return }
        var soft = context
        soft.addFilter(.blur(radius: 8))
        soft.fill(Path(CGRect(x: g.pivot.x - 7, y: 0, width: 14, height: bottom)),
                  with: .linearGradient(Gradient(colors: [tint.opacity(0), tint.opacity(0.4 * flash)]), startPoint: top, endPoint: foot))
    }

    /// The rod, from where it enters the canvas to the bob, brightening toward the bob.
    private static func rod(_ context: inout GraphicsContext, g: Geometry, angle: Double, bob: CGPoint) {
        let entryDistance = g.pivot.y < 0 ? -g.pivot.y / CGFloat(max(0.05, cos(angle))) : 0
        let entry = g.along(angle, min(g.radius, entryDistance))
        var path = Path()
        path.move(to: entry)
        path.addLine(to: bob)
        context.stroke(path, with: .linearGradient(Gradient(colors: [Palette.brassDeep.opacity(0.2), Palette.brass]), startPoint: entry, endPoint: bob),
                       lineWidth: 3)
    }

    /// The sliding weight: near the bob for slow tempos, up the rod for fast ones.
    private static func weight(_ context: inout GraphicsContext, g: Geometry, angle: Double, bpm: Double) {
        // The rod still inside the canvas at the widest swing (the pivot sits above it), so the weight keeps
        // its place on the rod and never leaves the hero.
        let hidden = g.pivot.y < 0 ? -g.pivot.y / CGFloat(max(0.05, cos(g.reach))) : 0
        let visible = max(0, g.radius - hidden)
        let travel = max(0, visible - g.bob - 30)
        let fast = CGFloat(min(1, max(0, (bpm - 30) / 270)))
        let center = g.along(angle, g.radius - g.bob - 12 - fast * travel)
        var layer = context
        layer.translateBy(x: center.x, y: center.y)
        layer.rotate(by: .radians(-angle))
        let body = Path(roundedRect: CGRect(x: -6, y: -9, width: 12, height: 18), cornerRadius: 3)
        layer.fill(body, with: .linearGradient(Gradient(colors: [Palette.ink, Palette.inkSoft]), startPoint: CGPoint(x: -6, y: 0), endPoint: CGPoint(x: 6, y: 0)))
        layer.stroke(body, with: .color(Palette.brassDeep), lineWidth: 1)
        var notch = Path()
        notch.move(to: CGPoint(x: -6, y: 0))
        notch.addLine(to: CGPoint(x: 6, y: 0))
        layer.stroke(notch, with: .color(Palette.stage.opacity(0.5)), lineWidth: 1)
    }

    /// A soft ribbon where the bob just was, fading with age, blurred once as a single layer.
    private static func trail(_ context: inout GraphicsContext, tint: Color, position: Double, scale: CGFloat, bob: @escaping (Double) -> CGPoint) {
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
                layer.stroke(segment, with: .color(tint.opacity(0.3 * age)),
                             style: StrokeStyle(lineWidth: 28 * scale * CGFloat(0.55 + 0.45 * age), lineCap: .round))
                previous = point
            }
        }
    }

    private static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}
