import QuartzCore
import SwiftUI
import TimbreCore

/// Play-along: notes glide toward the "now" line on their string (or pitch lane); the microphone
/// judges each one for timing and intonation. Count-in, tempo choice, combo, results.
struct AlongStep: View {
    let notes: [TimedNote]
    let bpm: Double
    let beatsPerBar: Int
    let title: LearnText?
    let course: LearnCourse
    let accent: Color
    let done: (Double?) -> Void
    @EnvironmentObject private var store: AppStore
    @State private var owner = UUID()
    @State private var phase = Phase.ready
    @State private var slow = false
    @State private var judge: PlayAlongJudge
    @State private var grades: [Int: PlayAlongJudge.Grade] = [:]
    @State private var hitTimes: [Int: CFTimeInterval] = [:]
    @State private var startTime: CFTimeInterval = 0
    @State private var trail: [(CFTimeInterval, Double)] = []
    @State private var lastLevel = -120.0
    @State private var lastOnset: CFTimeInterval = 0
    @State private var burst = 0

    enum Phase { case ready, playing, done }

    init(notes: [TimedNote], bpm: Double, beatsPerBar: Int, title: LearnText?, course: LearnCourse, accent: Color, done: @escaping (Double?) -> Void) {
        self.notes = notes.sorted { $0.beat < $1.beat }
        self.bpm = bpm; self.beatsPerBar = beatsPerBar; self.title = title; self.course = course; self.accent = accent; self.done = done
        _judge = State(initialValue: PlayAlongJudge(notes: notes, bpm: bpm, anyOctave: course.anyOctave))
    }

    private var tempo: Double { slow ? (bpm * 0.75).rounded() : bpm }
    private var spb: Double { 60 / tempo }
    private var countIn: Double { Double(beatsPerBar) * spb }
    private var fretted: Bool { course.fretKind != nil && notes.allSatisfy { $0.at != nil } }
    /// Drums and a bass on the key of the tune (no band bass when the player is the bass).
    private var band: BandArrangement {
        .melody(notes, bpm: tempo, beatsPerBar: beatsPerBar, reference: store.settings.referencePitchHz, bass: course.fretKind != "bass")
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            TimelineView(.animation(paused: phase != .playing)) { timeline in
                let now = CACurrentMediaTime()
                // Before the start the first notes already wait near the horizon.
                let elapsed = phase == .ready ? -1.6 : now - startTime - countIn
                let clock = phase == .done ? now + 10 : now
                ZStack {
                    if fretted {
                        HighwayRunway(notes: notes, secondsPerBeat: spb, elapsed: elapsed, grades: grades, hitTimes: hitTimes, now: clock, strings: course.stringCount)
                    } else {
                        HighwayCanvas(notes: notes, secondsPerBeat: spb, elapsed: elapsed, grades: grades, hitTimes: hitTimes, now: clock,
                                      lanes: 0, accent: accent, trail: trail, startTime: startTime + countIn)
                    }
                    if phase == .playing, elapsed < 0 {
                        Text("\(Int(-elapsed / spb) + 1)").font(Typeface.note(96)).foregroundStyle(Palette.ink)
                            .shadow(color: accent.opacity(0.6), radius: 20)
                            .transition(.scale.combined(with: .opacity))
                    }
                    GeometryReader { geometry in
                        SparkBurst(trigger: burst, color: accent).frame(width: 140, height: 140)
                            .position(fretted ? CGPoint(x: geometry.size.width / 2, y: geometry.size.height - 58) : CGPoint(x: geometry.size.width * 0.24, y: geometry.size.height / 2))
                    }
                }
                .onChange(of: Int(now * 20)) { _, _ in tick(now: now) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Play-along, \(notes.count) notes"))
            // Shrinks on short phones rather than pushing the header off the top.
            .frame(minHeight: 220, maxHeight: fretted ? 360 : 290)
            // The results take the stage's place, so nothing above or below moves when they arrive.
            .overlay { if phase == .done { resultsPanel } }
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Palette.stageDeep))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.horizontal, 12)
            .layoutPriority(1)
            upcoming
                .frame(minHeight: 44)
                .opacity(phase == .done ? 0 : 1)
                .accessibilityHidden(phase == .done)
            Spacer(minLength: 0)
            MicrophoneHint()
            controls
        }
        .onAppear { store.audio.prepareBand(band) }
        .onChange(of: slow) { _, _ in store.audio.prepareBand(band) }
        .onDisappear { store.audio.stopMetronome(); store.audio.stopBand(); store.stopLessonListening(owner: owner) }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title?.localized ?? String(localized: "Play along")).font(Typeface.display(24)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                if judge.combo >= 3 {
                    Label("×\(judge.combo)", systemImage: "flame.fill").font(Typeface.label(16)).foregroundStyle(Palette.flame)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(Palette.flame.opacity(0.14)))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            HStack(spacing: 8) {
                Text("\(Int(tempo)) BPM · \(notes.count) notes").font(.subheadline).foregroundStyle(Palette.inkSoft)
                Spacer(minLength: 8)
                BandControls(audio: store.audio, accent: accent)
            }
        }
        .animation(Motion.pluck, value: judge.combo >= 3)
        .padding(.horizontal, 22).padding(.top, 8)
        // Always its full height: the title never shrinks to make room below.
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The next note by name, and where to play it.
    @ViewBuilder private var upcoming: some View {
        let index = min(judge.nextIndex, notes.count - 1)
        if notes.indices.contains(index) {
            let note = notes[index]
            HStack(spacing: 10) {
                Text("Next").font(Typeface.label(13)).foregroundStyle(Palette.inkFaint)
                Text(NoteName.name(note.midi)).font(Typeface.display(22)).foregroundStyle(Palette.ink)
                if fretted, let at = note.at {
                    Text(at.fret == 0 ? LocalizedStringKey("String \(at.string), open") : LocalizedStringKey("String \(at.string), fret \(at.fret)"))
                        .font(Typeface.label(14)).foregroundStyle(accent)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(accent.opacity(0.12)))
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .animation(Motion.quick, value: index)
            .contentTransition(.numericText())
        }
    }

    /// The take's results over the dimmed stage, in the same frame the notes ran in.
    private var resultsPanel: some View {
        ZStack {
            Rectangle().fill(Palette.stageDeep.opacity(0.84))
            RadialGradient(colors: [ScoreTint.color(judge.accuracy).opacity(0.14), .clear], center: .center, startRadius: 4, endRadius: 220)
            summary.padding(12)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var summary: some View {
        let counts = Dictionary(grouping: grades.values, by: { $0 }).mapValues(\.count)
        return VStack(spacing: 10) {
            // Coloured by the result: mint from 90 %, gold from 70 %, coral below.
            Text("\(Int((judge.accuracy * 100).rounded()))%").font(Typeface.note(56)).foregroundStyle(ScoreTint.color(judge.accuracy))
            HStack(spacing: 18) {
                stat("Perfect", counts[.perfect] ?? 0, accent)
                stat("Good", counts[.good] ?? 0, Palette.ink)
                stat("Late/early", counts[.ok] ?? 0, Palette.amber)
                stat("Missed", counts[.miss] ?? 0, Palette.danger)
            }
            Text(timingNote).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
            Text("Best combo \(judge.bestCombo)").font(.footnote).foregroundStyle(Palette.inkSoft)
            if judge.accuracy < 0.8 && !slow {
                Button { slow = true; reset() } label: { Label("Try it at \(Int((bpm * 0.75).rounded())) BPM", systemImage: "tortoise.fill") }
                    .font(Typeface.label(14)).foregroundStyle(accent).padding(.top, 2)
                    .accessibilityIdentifier("along.slower")
            }
        }
    }

    /// Where the timing went: early or late on average, in milliseconds.
    private var timingNote: LocalizedStringKey {
        let offsets = judge.judgments.compactMap(\.offset)
        guard !offsets.isEmpty else { return "Play each note as it reaches the line" }
        let mean = offsets.reduce(0, +) / Double(offsets.count)
        let ms = Int((abs(mean) * 1000).rounded())
        if ms < 35 { return "Right on the beat" }
        return mean > 0 ? "About \(ms) ms late on average" : "About \(ms) ms early on average"
    }

    private func stat(_ label: LocalizedStringKey, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(Typeface.number(20)).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(Palette.inkSoft)
        }
    }

    @ViewBuilder private var controls: some View {
        switch phase {
        case .ready:
            VStack(spacing: 12) {
                Picker("Tempo", selection: $slow) {
                    Text("Normal · \(Int(bpm))").tag(false)
                    Text("Slow · \(Int((bpm * 0.75).rounded()))").tag(true)
                }
                .pickerStyle(.segmented).padding(.horizontal, 24)
                StepButton(title: "Start", accent: accent) { start() }
            }
        case .playing:
            StepButton(title: "Listening…", accent: accent, enabled: false) {}
        case .done:
            HStack(spacing: 10) {
                Button("Try again") { reset() }.font(Typeface.label(16)).foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.stageRaised))
                    .accessibilityIdentifier("along.again")
                Button { done(judge.accuracy) } label: {
                    Text("Continue").font(Typeface.label(18)).foregroundStyle(Palette.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(accent))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityIdentifier("lesson.continue")
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
    }

    // MARK: Flow

    private func reset() {
        judge = PlayAlongJudge(notes: notes, bpm: tempo, anyOctave: course.anyOctave)
        grades = [:]; hitTimes = [:]; trail = []
        phase = .ready
    }

    private func start() {
        judge = PlayAlongJudge(notes: notes, bpm: tempo, anyOctave: course.anyOctave)
        grades = [:]; hitTimes = [:]; trail = []
        startTime = CACurrentMediaTime()
        phase = .playing
        store.audio.setMetronome(bpm: Int(tempo), beats: beatsPerBar, subdivision: 1, accents: true)
        // The band rides the metronome from the bar after the count-in (headphones only; else the click).
        store.audio.playBand(band, firstBar: 1)
        store.gameTargetHz = notes.first.map { PitchMath.frequency(midi: Double($0.midi), reference: store.settings.referencePitchHz) }
        // Re-attacks of a repeated note come from the onset detector (a jump in loudness as a fallback).
        let analyzer = LessonAnalyzer(chords: false, onOnset: { time in lastOnset = time })
        store.startLessonListening(owner: owner, analyzer: analyzer) { hz, level in
            let now = CACurrentMediaTime()
            let heard = HeardNote(hz: hz, reference: store.settings.referencePitchHz)
            let onset = (level - lastLevel > 6 && level > -50) || now - lastOnset < 0.12
            lastLevel = level
            if let heard, !fretted { trail.append((now, Double(heard.midi) + heard.cents / 100)); if trail.count > 240 { trail.removeFirst(60) } }
            apply(judge.update(time: now - startTime - countIn, midi: heard?.midi, cents: heard?.cents, onset: onset), now: now)
        }
    }

    private func tick(now: CFTimeInterval) {
        guard phase == .playing else { return }
        // The first click is heard a little after the tap (engine and microphone starting, output
        // latency, far more on Bluetooth): notes and judging follow the audio clock, not the tap.
        if let heard = store.audio.heardStart(near: startTime) { startTime = heard }
        apply(judge.update(time: now - startTime - countIn, midi: nil, cents: nil), now: now)
        if judge.isFinished || now - startTime - countIn > judge.duration + 1.2 { finish() }
    }

    private func apply(_ judgments: [PlayAlongJudge.Judgment], now: CFTimeInterval) {
        for j in judgments {
            grades[j.index] = j.grade
            hitTimes[j.index] = now
            if j.grade != .miss { burst += 1; if j.grade == .perfect { Haptics.shared.selection() } }
        }
        if !judgments.isEmpty, judge.nextIndex < notes.count {
            store.gameTargetHz = PitchMath.frequency(midi: Double(notes[judge.nextIndex].midi), reference: store.settings.referencePitchHz)
        }
        if judge.isFinished { finish() }
    }

    private func finish() {
        guard phase == .playing else { return }
        // A good take ends on the band's final chord; otherwise it fades with the click.
        store.audio.finishBand(celebrate: judge.accuracy >= 0.7)
        store.stopLessonListening(owner: owner)
        withAnimation(Motion.settle) { phase = .done }
        SoundFX.shared.play(judge.accuracy >= 0.7 ? .star : .wrong)
    }
}

/// The band corner of a play-along header: the band switch and, on the speaker, a quiet note that the
/// band plays in headphones (out loud it would reach the microphone and blur what it hears, so the
/// speaker keeps the plain click).
struct BandControls: View {
    @ObservedObject var audio: AudioService
    let accent: Color
    @AppStorage(BandArrangement.preferenceKey) private var bandOn = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            if bandOn && !audio.headphones { headphonesChip }
            toggle
        }
        .animation(reduceMotion ? nil : Motion.quick, value: bandOn)
        .animation(reduceMotion ? nil : Motion.quick, value: audio.headphones)
        .onAppear { audio.refreshRoute() }
    }

    /// Words when they fit, just the headphones glyph when they don't (narrow phones, large type).
    private var headphonesChip: some View {
        ViewThatFits(in: .horizontal) {
            chip(Label("Band with headphones", systemImage: "headphones"))
            chip(Label("Band with headphones", systemImage: "headphones").labelStyle(.iconOnly))
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("along.band.headphones")
    }

    private func chip(_ content: some View) -> some View {
        content
            .font(Typeface.label(12))
            .foregroundStyle(Palette.inkSoft)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10).padding(.vertical, 5)
            .frame(minHeight: 26)
            .background(Capsule().fill(Palette.stageRaised))
            .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
    }

    private var toggle: some View {
        Button {
            bandOn.toggle()
            Haptics.shared.selection()
            audio.refreshBand()
        } label: {
            toggleFace
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .padding(-8)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(Text("Backing band"))
        .accessibilityAddTraits(bandOn ? [.isToggle, .isSelected] : [.isToggle])
        .accessibilityIdentifier("along.band")
    }

    /// A note in a ring: tinted when on, struck through when off; it hops when the band comes in.
    private var toggleFace: some View {
        ZStack {
            Circle().fill(bandOn ? accent.opacity(0.16) : Palette.stageRaised)
            Circle().strokeBorder(bandOn ? accent.opacity(0.45) : Palette.line, lineWidth: 1)
            Image(systemName: "music.quarternote.3")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(bandOn ? accent : Palette.inkFaint)
                .symbolEffect(.bounce, value: reduceMotion ? false : audio.bandPlaying)
            if !bandOn {
                Capsule().fill(Palette.inkFaint).frame(width: 1.5, height: 20).rotationEffect(.degrees(-45))
            }
        }
        .frame(width: 28, height: 28)
    }
}

/// The drawing: lanes, the now line, note gems sliding in, hits bursting, misses fading.
struct HighwayCanvas: View {
    let notes: [TimedNote]
    let secondsPerBeat: Double
    /// Seconds since beat 0 (negative during the count-in).
    let elapsed: Double
    let grades: [Int: PlayAlongJudge.Grade]
    let hitTimes: [Int: CFTimeInterval]
    let now: CFTimeInterval
    /// String lanes for fretted courses; 0 draws pitch lanes.
    let lanes: Int
    let accent: Color
    let trail: [(CFTimeInterval, Double)]
    let startTime: CFTimeInterval

    var body: some View {
        Canvas { context, size in
            let hitX = size.width * 0.24
            let pps: CGFloat = 150
            let top: CGFloat = 34, bottom = size.height - 30
            let midis = notes.map(\.midi)
            let low = Double((midis.min() ?? 60) - 2), high = Double((midis.max() ?? 72) + 2)
            func laneY(_ note: TimedNote) -> CGFloat {
                if lanes > 0, let at = note.at { return top + (bottom - top) * CGFloat(at.string - 1) / CGFloat(max(1, lanes - 1)) }
                return pitchY(Double(note.midi))
            }
            func pitchY(_ midi: Double) -> CGFloat { bottom - (bottom - top) * CGFloat((midi - low) / max(1, high - low)) }

            // Lanes.
            if lanes > 0 {
                for lane in 0..<lanes {
                    let y = top + (bottom - top) * CGFloat(lane) / CGFloat(max(1, lanes - 1))
                    context.fill(Path(CGRect(x: 0, y: y - 0.6 - CGFloat(lane) * 0.15, width: size.width, height: 1.2 + CGFloat(lane) * 0.3)), with: .color(.white.opacity(0.13)))
                    context.draw(Text("\(lane + 1)").font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.inkFaint), at: CGPoint(x: 10, y: y))
                }
            } else {
                for midi in stride(from: Int(low.rounded(.up)), through: Int(high), by: 1) where [0, 2, 4, 5, 7, 9, 11].contains(((midi % 12) + 12) % 12) {
                    let y = pitchY(Double(midi))
                    context.fill(Path(CGRect(x: 0, y: y - 0.5, width: size.width, height: 1)), with: .color(.white.opacity(midi % 12 == 0 ? 0.14 : 0.05)))
                }
            }
            // Beat lines scrolling with the music.
            let firstBeat = Int(floor((elapsed - Double(hitX / pps)) / secondsPerBeat))
            for beat in firstBeat...(firstBeat + Int(Double(size.width / pps) / secondsPerBeat) + 2) {
                let x = hitX + CGFloat((Double(beat) * secondsPerBeat - elapsed)) * pps
                context.fill(Path(CGRect(x: x - 0.5, y: top - 14, width: 1, height: bottom - top + 28)), with: .color(.white.opacity(beat % 4 == 0 ? 0.10 : 0.04)))
            }
            // Now line.
            let glow = Path(CGRect(x: hitX - 18, y: 0, width: 36, height: size.height))
            context.fill(glow, with: .linearGradient(Gradient(colors: [.clear, accent.opacity(0.16), .clear]), startPoint: CGPoint(x: hitX - 18, y: 0), endPoint: CGPoint(x: hitX + 18, y: 0)))
            context.fill(Path(roundedRect: CGRect(x: hitX - 1.5, y: 8, width: 3, height: size.height - 16), cornerRadius: 1.5), with: .color(accent))

            // Notes.
            for (i, note) in notes.enumerated() {
                let start = note.beat * secondsPerBeat - elapsed
                let x0 = hitX + CGFloat(start) * pps
                let width = max(38, CGFloat(note.beats * secondsPerBeat) * pps - 6)
                guard x0 + width > -40, x0 < size.width + 40 else { continue }
                let y = laneY(note)
                let grade = grades[i]
                let age = min(1, hitTimes[i].map { now - $0 } ?? 0)
                var rect = CGRect(x: x0, y: y - 15, width: width, height: 30)
                var alpha = 1.0
                var fill = accent
                switch grade {
                case .miss?: fill = Palette.danger; alpha = max(0.15, 0.7 - age)
                case .some: alpha = max(0, 1 - age * 2.2); rect = rect.insetBy(dx: -CGFloat(age) * 30, dy: -CGFloat(age) * 18)
                case nil: break
                }
                let shape = Path(roundedRect: rect, cornerRadius: 12)
                if grade == nil {
                    context.fill(shape, with: .linearGradient(Gradient(colors: [fill.opacity(0.95), fill.opacity(0.7)]), startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.minX, y: rect.maxY)))
                    context.fill(Path(roundedRect: CGRect(x: rect.minX + 6, y: rect.minY + 3, width: rect.width - 12, height: 4), cornerRadius: 2), with: .color(.white.opacity(0.35)))
                } else if grade == .miss {
                    context.stroke(shape, with: .color(fill.opacity(alpha)), lineWidth: 2)
                } else {
                    context.fill(shape, with: .color(Color.white.opacity(alpha * 0.9)))
                }
                if grade == nil || grade == .miss {
                    let label = lanes > 0 ? (note.at.map { "\($0.fret)" } ?? NoteName.pitchClass(note.midi)) : NoteName.pitchClass(note.midi)
                    context.draw(Text(label).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(grade == .miss ? Palette.danger.opacity(alpha) : Palette.onAccent),
                                 at: CGPoint(x: rect.minX + 19, y: y))
                }
            }

            // Your pitch, as a glowing trail to the left of the now line (pitch lanes only).
            if lanes == 0, trail.count > 1 {
                var path = Path()
                var started = false
                for (time, midi) in trail {
                    let x = hitX + CGFloat(time - now) * pps
                    guard x > -10 else { continue }
                    let point = CGPoint(x: x, y: pitchY(midi))
                    if started { path.addLine(to: point) } else { path.move(to: point); started = true }
                }
                context.stroke(path, with: .color(Palette.ink.opacity(0.85)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                if let last = trail.last, now - last.0 < 0.25 {
                    let p = CGPoint(x: hitX, y: pitchY(last.1))
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)), with: .color(Palette.ink))
                }
            }
        }
    }
}

/// Fretted play-along as a runway: one coloured lane per string (lowest on the left, like a chord
/// box), notes rise out of the horizon and land on the target row, perspective and glow included.
struct HighwayRunway: View {
    let notes: [TimedNote]
    let secondsPerBeat: Double
    let elapsed: Double
    let grades: [Int: PlayAlongJudge.Grade]
    let hitTimes: [Int: CFTimeInterval]
    let now: CFTimeInterval
    let strings: Int

    static let lookahead = 2.8
    static func color(string: Int, of count: Int) -> Color {
        // Lowest string warm, highest cool.
        let palette: [Color] = [Palette.violet, Palette.sky, Palette.mint, Color(hex: 0xFFE066), Palette.amber, Palette.coral]
        let index = count <= 1 ? 0 : Int((Double(string - 1) / Double(count - 1) * Double(palette.count - 1)).rounded())
        return palette[min(palette.count - 1, max(0, index))]
    }

    var body: some View {
        Canvas { context, size in draw(&context, size: size) }
            .accessibilityHidden(true)
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize) {
        let hitY = size.height - 58, horizonY: CGFloat = 16
        let gap = (size.width - 36) / CGFloat(max(1, strings))
        let k = 0.55
        func depth(_ d: Double) -> CGFloat { CGFloat(d / (abs(d) + k) * (1 + k)) }
        func y(_ d: Double) -> CGFloat { hitY - (hitY - horizonY) * depth(d) }
        func scale(_ d: Double) -> CGFloat { 1 - 0.8 * depth(max(-0.3, d)) }
        /// Lane of a string: string N (lowest) on the left.
        func x(_ string: Int, _ d: Double) -> CGFloat {
            let lane = CGFloat(strings - string) - CGFloat(strings - 1) / 2
            return size.width / 2 + lane * gap * scale(d)
        }
        // Horizon glow and runway floor.
        let sky = Gradient(colors: [Color(hex: 0x14161B), Palette.stageDeep])
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(sky, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        var floor = Path()
        floor.move(to: CGPoint(x: x(strings, 1) - gap * 0.5 * scale(1), y: horizonY))
        floor.addLine(to: CGPoint(x: x(1, 1) + gap * 0.5 * scale(1), y: horizonY))
        floor.addLine(to: CGPoint(x: x(1, -0.15) + gap * 0.5 * scale(-0.15), y: size.height))
        floor.addLine(to: CGPoint(x: x(strings, -0.15) - gap * 0.5 * scale(-0.15), y: size.height))
        floor.closeSubpath()
        let ground = Gradient(colors: [Color(hex: 0x1C1F26).opacity(0.4), Color(hex: 0x1C1F26)])
        context.fill(floor, with: .linearGradient(ground, startPoint: CGPoint(x: 0, y: horizonY), endPoint: CGPoint(x: 0, y: size.height)))
        // Beat rungs scrolling toward you.
        let firstBeat = Int(floor_(elapsed / secondsPerBeat))
        for beat in firstBeat...(firstBeat + Int(Self.lookahead / secondsPerBeat) + 1) {
            let d = (Double(beat) * secondsPerBeat - elapsed) / Self.lookahead
            guard d > -0.1, d < 1 else { continue }
            let yy = y(d)
            var rung = Path()
            rung.move(to: CGPoint(x: x(strings, d) - gap * 0.5 * scale(d), y: yy))
            rung.addLine(to: CGPoint(x: x(1, d) + gap * 0.5 * scale(d), y: yy))
            context.stroke(rung, with: .color(.white.opacity(beat % 4 == 0 ? 0.16 : 0.06)), lineWidth: beat % 4 == 0 ? 1.5 : 1)
        }
        // String lanes.
        for s in 1...max(1, strings) {
            var lane = Path()
            lane.move(to: CGPoint(x: x(s, 1), y: horizonY))
            lane.addLine(to: CGPoint(x: x(s, -0.15), y: size.height))
            let laneTint: Color = Self.color(string: s, of: strings)
            let fade = Gradient(colors: [laneTint.opacity(0.05), laneTint.opacity(0.45)])
            context.stroke(lane, with: .linearGradient(fade, startPoint: CGPoint(x: 0, y: horizonY), endPoint: CGPoint(x: 0, y: hitY)), lineWidth: 1.4)
        }
        // Target row.
        context.fill(Path(roundedRect: CGRect(x: 10, y: hitY - 2, width: size.width - 20, height: 4), cornerRadius: 2), with: .color(.white.opacity(0.18)))
        for s in 1...max(1, strings) {
            let center = CGPoint(x: x(s, 0), y: hitY)
            let tint = Self.color(string: s, of: strings)
            let lit = isLit(string: s)
            let r: CGFloat = lit ? 19 : 15
            context.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(tint.opacity(lit ? 0.45 : 0.10)))
            context.stroke(Path(ellipseIn: CGRect(x: center.x - 15, y: center.y - 15, width: 30, height: 30)), with: .color(tint.opacity(0.9)), lineWidth: 2)
            context.draw(Text("\(s)").font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.inkFaint), at: CGPoint(x: center.x, y: hitY + 28))
        }
        // Notes, far ones first so near ones draw on top.
        for (i, note) in notes.enumerated().reversed() {
            guard let at = note.at else { continue }
            let start = (note.beat * secondsPerBeat - elapsed) / Self.lookahead
            let end = ((note.beat + note.beats) * secondsPerBeat - elapsed) / Self.lookahead
            guard start < 1.05, end > -0.25 else { continue }
            let grade = grades[i]
            let age = min(1, hitTimes[i].map { now - $0 } ?? 0)
            let tint = grade == .miss ? Palette.danger : Self.color(string: at.string, of: strings)
            // Sustain tail.
            if end - start > 0.08 {
                var tail = Path()
                let a = max(start, 0), b = min(end, 1)
                if b > a {
                    tail.move(to: CGPoint(x: x(at.string, a) - 4 * scale(a), y: y(a)))
                    tail.addLine(to: CGPoint(x: x(at.string, b) - 4 * scale(b), y: y(b)))
                    tail.addLine(to: CGPoint(x: x(at.string, b) + 4 * scale(b), y: y(b)))
                    tail.addLine(to: CGPoint(x: x(at.string, a) + 4 * scale(a), y: y(a)))
                    tail.closeSubpath()
                    context.fill(tail, with: .color(tint.opacity(grade == nil ? 0.35 : 0.15)))
                }
            }
            if grade != nil && grade != .miss && age > 0.4 { continue }
            let d = grade != nil && grade != .miss ? 0 : start
            let sc = scale(d)
            let w = gap * 0.78 * sc, h = 30 * sc
            var rect = CGRect(x: x(at.string, d) - w / 2, y: y(d) - h / 2, width: w, height: h)
            var alpha = start > 0.85 ? max(0, (1.05 - start) / 0.2) : 1
            if let grade, grade != .miss { alpha = 1 - age / 0.4; rect = rect.insetBy(dx: -CGFloat(age) * 40, dy: -CGFloat(age) * 24) }
            if grade == .miss { alpha = max(0.2, 0.8 - age) }
            let gem = Path(roundedRect: rect, cornerRadius: 9 * sc)
            let top: Color = tint.mix(with: .white, by: 0.3).opacity(alpha)
            let shine = Gradient(colors: [top, tint.opacity(alpha)])
            context.fill(gem, with: .linearGradient(shine, startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
            if grade == nil {
                context.stroke(gem, with: .color(.white.opacity(0.35 * alpha)), lineWidth: 1)
                context.draw(Text("\(at.fret)").font(.system(size: max(9, 17 * sc), weight: .heavy, design: .rounded)).foregroundStyle(Palette.onAccent.opacity(alpha)),
                             at: CGPoint(x: rect.midX, y: rect.midY))
            }
        }
    }

    private func floor_(_ v: Double) -> Double { v.rounded(.down) }

    /// A string flashes on the target row for a moment after one of its notes is hit.
    private func isLit(string: Int) -> Bool {
        for (i, note) in notes.enumerated() where note.at?.string == string {
            guard let grade = grades[i], grade != .miss, let time = hitTimes[i] else { continue }
            if now - time < 0.25 { return true }
        }
        return false
    }
}
