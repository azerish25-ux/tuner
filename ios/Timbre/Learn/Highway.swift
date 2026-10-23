import QuartzCore
import SwiftUI
import TimbreCore

/// Play-along: notes glide toward the "now" line on their string (or pitch lane); the microphone
/// judges each one for timing and intonation. Count-in, a tempo ladder (75 → 90 → 100 → 110 %), combo, results.
struct AlongStep: View {
    let notes: [TimedNote]
    let bpm: Double
    let beatsPerBar: Int
    let title: LearnText?
    let course: LearnCourse
    let accent: Color
    /// How each note went in the take that counts (for the lesson's weak spots).
    var onItem: (PracticeItem, Double) -> Void = { _, _ in }
    /// Finished below the lesson tempo: the lesson's stars are capped.
    var onStarCap: (Int) -> Void = { _ in }
    let done: (Double?) -> Void
    @EnvironmentObject private var store: AppStore
    @State private var owner = UUID()
    @State private var phase = Phase.ready
    @State private var ladder: TempoLadder
    /// The last take was good enough to move the ladder up a rung.
    @State private var steppedUp = false
    @State private var judge: PlayAlongJudge
    @State private var grades: [Int: PlayAlongJudge.Grade] = [:]
    /// The grades of the take that counts (the ladder's outcome).
    @State private var countedGrades: [Int: PlayAlongJudge.Grade] = [:]
    @State private var hitTimes: [Int: CFTimeInterval] = [:]
    @State private var startTime: CFTimeInterval = 0
    @State private var trail: [(CFTimeInterval, Double)] = []
    @State private var lastLevel = -120.0
    @State private var lastOnset: CFTimeInterval = 0
    @State private var calibrating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The runway's lanes follow the diagrams' string order (Settings › String order).
    @AppStorage(StringOrder.storageKey) private var stringOrder: StringOrder = .tab

    enum Phase { case ready, playing, done }

    init(notes: [TimedNote], bpm: Double, beatsPerBar: Int, title: LearnText?, course: LearnCourse, accent: Color,
         onItem: @escaping (PracticeItem, Double) -> Void = { _, _ in }, onStarCap: @escaping (Int) -> Void = { _ in },
         done: @escaping (Double?) -> Void) {
        self.notes = notes.sorted { $0.beat < $1.beat }
        self.bpm = bpm; self.beatsPerBar = beatsPerBar; self.title = title; self.course = course; self.accent = accent
        self.onItem = onItem; self.onStarCap = onStarCap; self.done = done
        // Starts at the lesson tempo.
        _ladder = State(initialValue: TempoLadder(bpm: bpm))
        _judge = State(initialValue: PlayAlongJudge(notes: notes, bpm: bpm, anyOctave: course.anyOctave))
    }

    private var tempo: Double { ladder.tempo }
    private var spb: Double { 60 / tempo }
    private var countIn: Double { Double(beatsPerBar) * spb }
    private var fretted: Bool { course.fretKind != nil && notes.allSatisfy { $0.at != nil } }
    /// Drums and a bass on the key of the tune (no band bass when the player is the bass).
    private var band: BandArrangement {
        .melody(notes, bpm: tempo, beatsPerBar: beatsPerBar, reference: store.settings.referencePitchHz, bass: course.fretKind != "bass")
    }
    /// Slower rungs in amber, the lesson tempo and up in the course colour.
    private func rungTint(_ rung: Int) -> Color { rung >= TempoLadder.lessonRung ? accent : Palette.amber }
    /// The combo multiplier (×1…×4) the badge shows and the runway's hit line glows with.
    private var multiplier: Int { ComboBadge.multiplier(judge.combo) }

    var body: some View {
        VStack(spacing: 14) {
            header
            TimelineView(.animation(paused: phase != .playing)) { timeline in
                let now = CACurrentMediaTime()
                // Before the start the first notes already wait near the horizon.
                let elapsed = phase == .ready ? -1.6 : now - startTime - countIn
                let clock = phase == .done ? now + 10 : now
                ZStack {
                    // Hits burst on the hit line inside the drawing (bigger and white-gold when perfect).
                    if fretted {
                        HighwayRunway(notes: notes, secondsPerBeat: spb, elapsed: elapsed, grades: grades, hitTimes: hitTimes, now: clock,
                                      strings: course.stringCount, edges: StringEdges.of(course), beatsPerBar: beatsPerBar,
                                      heat: multiplier, calm: reduceMotion, order: stringOrder)
                    } else {
                        HighwayCanvas(notes: notes, secondsPerBeat: spb, elapsed: elapsed, grades: grades, hitTimes: hitTimes, now: clock,
                                      lanes: 0, accent: accent, trail: trail, startTime: startTime + countIn, calm: reduceMotion)
                    }
                    if phase == .playing, elapsed < 0 {
                        Text("\(Int(-elapsed / spb) + 1)").font(Typeface.note(96)).foregroundStyle(Palette.ink)
                            .shadow(color: accent.opacity(0.6), radius: 20)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .onChange(of: Int(now * 20)) { _, _ in tick(now: now) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Play-along, \(notes.count) notes"))
            // Shrinks on short phones rather than pushing the header off the top; the controls keep one height
            // through ready, playing and done, so the stage never changes size when a take starts or ends.
            .frame(minHeight: 220, maxHeight: fretted ? 420 : 300)
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
        .onChange(of: ladder.rung) { _, _ in store.audio.prepareBand(band) }
        .onDisappear {
            store.audio.stopMetronome(); store.audio.stopBand(); store.stopLessonListening(owner: owner)
            #if DEBUG
            store.demoNoteDue = nil
            #endif
        }
        .sheet(isPresented: $calibrating) {
            LatencyCalibrationSheet(accent: accent).environmentObject(store)
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                Text(title?.localized ?? String(localized: "Play along")).font(Typeface.display(24)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                if multiplier >= 2 {
                    ComboBadge(combo: judge.combo, calm: reduceMotion)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            // One height with or without the badge, so the stage below never shifts when it arrives.
            .frame(minHeight: 36)
            HStack(spacing: 8) {
                Text("\(Int(tempo)) BPM · \(notes.count) notes").font(.subheadline).foregroundStyle(Palette.inkSoft)
                    .lineLimit(1).minimumScaleFactor(0.8)
                tempoBadge
                Spacer(minLength: 8)
                CalibrateButton(audio: store.audio, accent: accent) { calibrating = true }
                    .disabled(phase == .playing)
                    .opacity(phase == .playing ? 0.4 : 1)
                BandControls(audio: store.audio, accent: accent)
            }
        }
        .animation(reduceMotion ? nil : Motion.pluck, value: multiplier >= 2)
        .padding(.horizontal, 22).padding(.top, 8)
        // Always its full height: the title never shrinks to make room below.
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The tempo level at a glance: 100 % in the course colour, slower in amber.
    private var tempoBadge: some View {
        Text("\(ladder.percent)%")
            .font(Typeface.number(12))
            .foregroundStyle(rungTint(ladder.rung))
            .contentTransition(.numericText(value: Double(ladder.percent)))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(rungTint(ladder.rung).opacity(0.14)))
            .animation(Motion.pluck, value: ladder.rung)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Tempo"))
            .accessibilityValue(Text("\(ladder.percent)%"))
    }

    /// The next note by name and where to play it, then the notes after it on a rail.
    @ViewBuilder private var upcoming: some View {
        let index = min(judge.nextIndex, notes.count - 1)
        if notes.indices.contains(index) {
            let note = notes[index]
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("Next").font(Typeface.label(13)).foregroundStyle(Palette.inkFaint)
                    Text(NoteName.name(note.midi)).font(Typeface.display(22)).foregroundStyle(Palette.ink)
                    if fretted, let at = note.at {
                        Text(at.fret == 0 ? LocalizedStringKey("String \(at.string), open") : LocalizedStringKey("String \(at.string), fret \(at.fret)"))
                            .font(Typeface.label(14)).foregroundStyle(nextTint(note))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(nextTint(note).opacity(0.12)))
                    }
                    Spacer()
                }
                .contentTransition(.numericText())
                UpNextRail(notes: notes, from: index + 1, fretted: fretted, strings: course.stringCount, accent: accent)
            }
            .padding(.horizontal, 24)
            .animation(reduceMotion ? nil : Motion.quick, value: index)
        }
    }

    /// The next note's string colour on the runway (the course colour on pitch lanes).
    private func nextTint(_ note: TimedNote) -> Color {
        guard fretted, let at = note.at else { return accent }
        return HighwayRunway.color(string: at.string, of: course.stringCount)
    }

    /// The take's results on an opaque panel over the stage, in the same frame the notes ran in.
    private var resultsPanel: some View {
        ZStack {
            Rectangle().fill(Palette.stageDeep)
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
                .minimumScaleFactor(0.7)
            if steppedUp { tempoUp }
            HStack(spacing: 18) {
                stat("Perfect", counts[.perfect] ?? 0, accent)
                stat("Good", counts[.good] ?? 0, Palette.ink)
                stat("Late/early", counts[.ok] ?? 0, Palette.amber)
                stat("Missed", counts[.miss] ?? 0, Palette.danger)
            }
            Text(timingNote).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
            if timingIsOff {
                // Consistently early or late usually means the headphones or speaker lag: measure it.
                Button { calibrating = true } label: { Label("Calibrate timing", systemImage: "metronome") }
                    .font(Typeface.label(14)).foregroundStyle(accent)
                    .accessibilityIdentifier("along.calibrate.hint")
            } else if judge.bestCombo >= 2 {
                Text("Best combo \(judge.bestCombo)").font(.footnote).foregroundStyle(Palette.inkSoft)
            }
            if judge.accuracy < 0.8 && ladder.rung > 0 {
                Button { ladder.select(0); reset() } label: { Label("Try it at \(Int(ladder.tempo(at: 0))) BPM", systemImage: "tortoise.fill") }
                    .font(Typeface.label(14)).foregroundStyle(accent).padding(.top, 2)
                    .accessibilityIdentifier("along.slower")
            }
        }
    }

    /// The ladder moved up after a take of 90 % or better.
    private var tempoUp: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.right")
            Text("Tempo up")
            Text("\(ladder.percent)%")
        }
        .font(Typeface.label(13))
        .foregroundStyle(rungTint(ladder.rung))
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(Capsule().fill(rungTint(ladder.rung).opacity(0.14)))
        .transition(.scale.combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }

    /// The take's offsets lean one way by 90 ms or more on average.
    private var timingIsOff: Bool {
        let offsets = judge.judgments.compactMap(\.offset)
        guard offsets.count >= 3 else { return false }
        return abs(offsets.reduce(0, +) / Double(offsets.count)) >= 0.09
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
                ladderPicker
                StepButton(title: "Start", accent: accent) { start() }
            }
        case .playing:
            VStack(spacing: 12) {
                // The take so far, in the ladder's place: the hidden ladder keeps its height, so nothing moves.
                ladderPicker
                    .hidden()
                    .accessibilityHidden(true)
                    .overlay { TakeRibbon(count: notes.count, grades: grades, current: judge.nextIndex, accent: accent) }
                StepButton(title: "Listening…", accent: accent, enabled: false) {}
            }
        case .done:
            VStack(spacing: 12) {
                ladderPicker
                HStack(spacing: 10) {
                    Button("Try again") { reset() }.font(Typeface.label(16)).foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.stageRaised))
                        .accessibilityIdentifier("along.again")
                    Button { complete() } label: {
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
    }

    /// The four tempo rungs, the current one filled; below the lesson tempo a note that full tempo earns three stars.
    private var ladderPicker: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                ForEach(TempoLadder.rungs.indices, id: \.self) { rung in rungButton(rung) }
            }
            Label("Full tempo for 3 stars", systemImage: "star.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.amber)
                .opacity(ladder.isFullTempo ? 0 : 1)
                .accessibilityHidden(ladder.isFullTempo)
        }
        .padding(.horizontal, 20)
        .animation(Motion.pluck, value: ladder.rung)
    }

    private func rungButton(_ rung: Int) -> some View {
        let selected = ladder.rung == rung
        let tint = rungTint(rung)
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            guard ladder.rung != rung else { return }
            ladder.select(rung)
            steppedUp = false
            Haptics.shared.selection()
        } label: {
            VStack(spacing: 1) {
                Text("\(Int((TempoLadder.rungs[rung] * 100).rounded()))%").font(Typeface.label(15))
                Text(Int(ladder.tempo(at: rung)), format: .number).font(Typeface.number(11)).opacity(0.75)
            }
            .foregroundStyle(selected ? Palette.onAccent : Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(shape.fill(selected ? AnyShapeStyle(tint) : AnyShapeStyle(Palette.stageRaised)))
            .overlay(shape.strokeBorder(selected ? Color.clear : Palette.line, lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if rung == TempoLadder.lessonRung {
                    // The lesson's own tempo.
                    Image(systemName: "star.fill").font(.system(size: 8, weight: .bold))
                        .foregroundStyle(selected ? Palette.onAccent : Palette.amber).padding(6)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(phase == .playing)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("along.tempo.\(rung)")
    }

    // MARK: Flow

    private func reset() {
        judge = PlayAlongJudge(notes: notes, bpm: tempo, anyOctave: course.anyOctave)
        grades = [:]; hitTimes = [:]; trail = []
        steppedUp = false
        phase = .ready
    }

    private func start() {
        judge = PlayAlongJudge(notes: notes, bpm: tempo, anyOctave: course.anyOctave)
        grades = [:]; hitTimes = [:]; trail = []
        steppedUp = false
        startTime = CACurrentMediaTime()
        phase = .playing
        store.audio.setMetronome(bpm: Int(tempo), beats: beatsPerBar, subdivision: 1, accents: true)
        // The band rides the metronome from the bar after the count-in (headphones only; else the click).
        store.audio.playBand(band, firstBar: 1)
        store.gameTargetHz = notes.first.map { PitchMath.frequency(midi: Double($0.midi), reference: store.settings.referencePitchHz) }
        #if DEBUG
        store.demoNoteDue = { judge.nextIndex < notes.count && CACurrentMediaTime() - startTime - countIn >= judge.time(of: judge.nextIndex) - 0.02 }
        #endif
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
        // latency, far more on Bluetooth; the tap-along calibration when there is one): notes and
        // judging follow the heard clock, not the tap.
        if let heard = store.audio.heardStart(near: startTime) { startTime = heard }
        apply(judge.update(time: now - startTime - countIn, midi: nil, cents: nil), now: now)
        if judge.isFinished || now - startTime - countIn > judge.duration + 1.2 { finish() }
    }

    private func apply(_ judgments: [PlayAlongJudge.Judgment], now: CFTimeInterval) {
        for j in judgments {
            grades[j.index] = j.grade
            hitTimes[j.index] = now
            if j.grade == .perfect { Haptics.shared.selection() }
        }
        // The multiplier steps up at 4, 8 and 16 in a row: a firmer tap with the badge's pulse.
        if let last = judgments.last, last.grade == .perfect || last.grade == .good {
            switch judge.combo {
            case 4, 8, 16: Haptics.shared.beat(accent: true)
            default: break
            }
        }
        if !judgments.isEmpty, judge.nextIndex < notes.count {
            store.gameTargetHz = PitchMath.frequency(midi: Double(notes[judge.nextIndex].midi), reference: store.settings.referencePitchHz)
        }
        if judge.isFinished { finish() }
    }

    private func finish() {
        guard phase == .playing else { return }
        let accuracy = judge.accuracy
        // The take that counts keeps its grades for the lesson's weak spots.
        if ladder.improvesOutcome(accuracy) { countedGrades = grades }
        let up = ladder.record(accuracy: accuracy)
        // A good take ends on the band's final chord; otherwise it fades with the click.
        store.audio.finishBand(celebrate: accuracy >= 0.7)
        store.stopLessonListening(owner: owner)
        #if DEBUG
        store.demoNoteDue = nil
        #endif
        withAnimation(Motion.settle) { phase = .done; steppedUp = up }
        SoundFX.shared.play(accuracy >= 0.7 ? .star : .wrong)
        if up { Haptics.shared.lock() }
    }

    /// Continue: the best take at the lesson tempo or faster counts; only slower takes cap the lesson's stars.
    private func complete() {
        let outcome = ladder.outcome
        if let cap = outcome?.starCap { onStarCap(cap) }
        for (index, note) in notes.enumerated() {
            onItem(course.practiceItem(for: note), PlayAlongJudge.credit(countedGrades[index] ?? .miss))
        }
        done(outcome?.score ?? judge.accuracy)
    }
}

/// The header's timing button: opens the tap-along calibration. A dot asks for it on a wireless route that
/// has never been calibrated (Bluetooth lag is the usual reason good playing scores late).
struct CalibrateButton: View {
    @ObservedObject var audio: AudioService
    let accent: Color
    let action: () -> Void

    private var needsIt: Bool { audio.route == .bluetooth && AudioService.calibratedLatency(for: .bluetooth) == nil }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Palette.stageRaised)
                Circle().strokeBorder(Palette.line, lineWidth: 1)
                Image(systemName: "metronome").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.inkSoft)
            }
            .frame(width: 28, height: 28)
            .overlay(alignment: .topTrailing) {
                if needsIt { Circle().fill(Palette.amber).frame(width: 8, height: 8).offset(x: 1, y: -1) }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .padding(-8)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(Text("Calibrate timing"))
        .accessibilityIdentifier("along.calibrate")
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

/// Pitch lanes (voice, ear and any-instrument courses): notes slide in from the right at the height of their
/// pitch to the now line, your pitch trails behind it, and each hit bursts on the line.
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
    /// Reduce Motion: a hit lights the line without bursts or sparks.
    var calm = false

    var body: some View {
        Canvas { context, size in
            let hitX = size.width * 0.24
            let pps: CGFloat = 150
            let top: CGFloat = 34, bottom = size.height - 30
            var lowest = 60, highest = 72
            if let first = notes.first {
                lowest = first.midi; highest = first.midi
                for note in notes { lowest = min(lowest, note.midi); highest = max(highest, note.midi) }
            }
            let low = Double(lowest - 2), high = Double(highest + 2)
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
            // Now line: a glow, the line, a bright core.
            let glow = Path(CGRect(x: hitX - 24, y: 0, width: 48, height: size.height))
            context.fill(glow, with: .linearGradient(Gradient(colors: [.clear, accent.opacity(0.22), .clear]), startPoint: CGPoint(x: hitX - 24, y: 0), endPoint: CGPoint(x: hitX + 24, y: 0)))
            context.fill(Path(roundedRect: CGRect(x: hitX - 2, y: 8, width: 4, height: size.height - 16), cornerRadius: 2), with: .color(accent))
            context.fill(Path(roundedRect: CGRect(x: hitX - 0.75, y: 10, width: 1.5, height: size.height - 20), cornerRadius: 0.75), with: .color(.white.opacity(0.7)))

            // Notes.
            for i in notes.indices {
                let note = notes[i]
                let start = note.beat * secondsPerBeat - elapsed
                let x0 = hitX + CGFloat(start) * pps
                let width = max(40, CGFloat(note.beats * secondsPerBeat) * pps - 6)
                guard x0 + width > -40, x0 < size.width + 40 else { continue }
                let y = laneY(note)
                let grade = grades[i]
                let age = min(1, hitTimes[i].map { now - $0 } ?? 0)
                let hit = grade != nil && grade != .miss
                // A hit pops white for an instant; its burst takes over.
                if hit && (calm || age > 0.16) { continue }
                var rect = CGRect(x: x0, y: y - 17, width: width, height: 34)
                if hit { rect = rect.insetBy(dx: -CGFloat(age) * 50, dy: -CGFloat(age) * 30) }
                let shape = Path(roundedRect: rect, cornerRadius: 13)
                if grade == .miss {
                    let alpha = max(0.15, 0.7 - age)
                    context.stroke(shape, with: .color(Palette.danger.opacity(alpha)), lineWidth: 2)
                    context.draw(label(note, color: Palette.danger.opacity(alpha)), at: CGPoint(x: rect.minX + 20, y: y))
                } else if hit {
                    context.fill(shape, with: .color(Color.white.opacity(0.9 * (1 - age / 0.16))))
                } else {
                    context.fill(Path(roundedRect: rect.offsetBy(dx: 0, dy: 4), cornerRadius: 13), with: .color(accent.mix(with: .black, by: 0.5)))
                    let shade = Gradient(colors: [accent.mix(with: .white, by: 0.3), accent, accent.mix(with: .black, by: 0.12)])
                    context.fill(shape, with: .linearGradient(shade, startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.minX, y: rect.maxY)))
                    let gloss = CGRect(x: rect.minX + 6, y: rect.minY + 3, width: max(0, rect.width - 12), height: 11)
                    context.fill(Path(roundedRect: gloss, cornerRadius: 5), with: .linearGradient(Gradient(colors: [Color.white.opacity(0.45), Color.white.opacity(0)]), startPoint: CGPoint(x: 0, y: gloss.minY), endPoint: CGPoint(x: 0, y: gloss.maxY)))
                    context.stroke(shape, with: .color(.white.opacity(0.3)), lineWidth: 1)
                    context.draw(label(note, color: Palette.onAccent), at: CGPoint(x: rect.minX + 20, y: y))
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

            // Hits burst on the now line, perfect ones bigger and white-gold.
            var light = context
            light.blendMode = .plusLighter
            for i in notes.indices {
                guard let grade = grades[i], grade != .miss, let time = hitTimes[i] else { continue }
                let age = now - time
                guard age >= 0, age < HitBurst.lifetime else { continue }
                let center = CGPoint(x: hitX, y: laneY(notes[i]))
                let tint: Color = grade == .perfect ? HighwayRunway.perfectGold : accent
                if calm {
                    HitBurst.glow(&light, at: center, tint: tint, age: age)
                } else {
                    HitBurst.draw(&light, at: center, tint: tint, perfect: grade == .perfect, age: age, seed: i, upward: false, scale: 0.85)
                }
            }
        }
    }

    private func label(_ note: TimedNote, color: Color) -> Text {
        let name = lanes > 0 ? (note.at.map { "\($0.fret)" } ?? NoteName.pitchClass(note.midi)) : NoteName.pitchClass(note.midi)
        return Text(verbatim: name).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(color)
    }
}

/// A note landing on the hit line: a flash, a ring opening out and a spray of sparks; a perfect note's is
/// bigger and white-gold. Drawn additively, from nothing but the time since the hit.
enum HitBurst {
    static let lifetime = 0.6

    static func draw(_ context: inout GraphicsContext, at center: CGPoint, tint: Color, perfect: Bool, age: Double, seed: Int,
                     upward: Bool, scale: CGFloat = 1) {
        guard age >= 0, age < lifetime else { return }
        let p = age / lifetime
        if age < 0.3 {
            let f = 1 - age / 0.3
            let radius = (perfect ? 78 : 46) * scale * CGFloat(0.55 + 0.45 * min(1, age / 0.08))
            let flash = Gradient(colors: [Color.white.opacity((perfect ? 0.95 : 0.7) * f), tint.opacity((perfect ? 0.6 : 0.45) * f), tint.opacity(0)])
            context.fill(circle(center, radius), with: .radialGradient(flash, center: center, startRadius: 0, endRadius: radius))
        }
        if age < 0.45 {
            let q = age / 0.45
            let eased = 1 - (1 - q) * (1 - q)
            let radius = (18 + CGFloat(eased) * (perfect ? 90 : 56)) * scale
            context.stroke(circle(center, radius), with: .color(tint.opacity(0.85 * (1 - q))), lineWidth: (perfect ? 3.5 : 2.5) * CGFloat(1 - q) + 0.5)
        }
        // Sparks: a fan rising off the line, or all the way round.
        let count = perfect ? 14 : 9
        for k in 0..<count {
            let n1 = CanvasNoise.value(seed * 31 + k), n2 = CanvasNoise.value(seed * 17 + k * 7 + 3)
            let angle = upward ? -Double.pi / 2 + (n1 - 0.5) * 2.6 : n1 * 2 * Double.pi
            let speed = (perfect ? 190.0 : 140.0) * (0.6 + 0.6 * n2)
            let x = center.x + CGFloat(cos(angle) * speed * age) * scale
            let y = center.y + CGFloat(sin(angle) * speed * age + 240 * age * age) * scale
            let r = CGFloat(2.8 * (1 - p)) * scale * (k % 3 == 0 ? 1.3 : 1)
            let spark: Color = k % 3 == 0 ? .white : tint
            context.fill(circle(CGPoint(x: x, y: y), r), with: .color(spark.opacity(1 - p)))
        }
    }

    /// Reduce Motion: the light alone, fading where the note landed.
    static func glow(_ context: inout GraphicsContext, at center: CGPoint, tint: Color, age: Double) {
        guard age >= 0, age < 0.35 else { return }
        let f = 1 - age / 0.35
        let radius: CGFloat = 40
        context.fill(circle(center, radius), with: .radialGradient(Gradient(colors: [tint.opacity(0.6 * f), tint.opacity(0)]), center: center, startRadius: 0, endRadius: radius))
    }

    static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}

/// Fretted play-along as a runway down a fretboard: a lane per string in the player's string order (the string
/// the diagrams draw on top takes the left lane: string 1 in tab order, the lowest string in mirror order)
/// over dark rosewood whose fret wires and inlays scroll toward you out of the fog. Notes ride their lane as
/// glossy gems in the string's colour, long ones trailing a sustain tail; a hit bursts on the hit line (a
/// perfect one in a bigger white-gold flash) and the line runs hotter as the combo multiplier climbs.
struct HighwayRunway: View {
    let notes: [TimedNote]
    let secondsPerBeat: Double
    let elapsed: Double
    let grades: [Int: PlayAlongJudge.Grade]
    let hitTimes: [Int: CFTimeInterval]
    let now: CFTimeInterval
    let strings: Int
    /// Names the outer lanes under their numbers ("Thinnest (1)", "Thickest (6)"), whichever side they are on.
    var edges: StringEdges?
    /// Beats in a bar: the bar lines are the heavier fret wires, with an inlay in each bar.
    var beatsPerBar = 4
    /// The combo multiplier (1…4): the hit line and the board's binding warm up as it climbs.
    var heat = 1
    /// Reduce Motion: a hit lights its target without bursts, beams or sparks.
    var calm = false
    /// Which string takes the first (left) lane, as the diagrams put it on top (Settings › String order).
    var order: StringOrder = .tab

    static let lookahead = 2.8
    /// The white-gold of a perfect note.
    static let perfectGold = Color(hex: 0xFFE7A3)
    /// Depth of the board's near edge, past the hit line (the bottom of the stage).
    private static let near = -0.15
    /// Notes this long (in beats) and longer trail a sustain tail.
    private static let sustainBeats = 1.5

    /// Lowest string warm, highest cool.
    private static let palette: [Color] = [Palette.violet, Palette.sky, Palette.mint, Color(hex: 0xFFE066), Palette.amber, Palette.coral]
    static func color(string: Int, of count: Int) -> Color {
        let index = count <= 1 ? 0 : Int((Double(string - 1) / Double(count - 1) * Double(palette.count - 1)).rounded())
        return palette[min(palette.count - 1, max(0, index))]
    }

    // The fixed shades, made once rather than on every frame.
    private static let sky = Gradient(colors: [Color(hex: 0x14161B), Palette.stageDeep])
    private static let haze = Gradient(colors: [Color(hex: 0x2B3442).opacity(0.6), Color(hex: 0x2B3442).opacity(0)])
    private static let wood = Gradient(colors: [Color(hex: 0x16100D), Color(hex: 0x3B2A1F)])
    private static let roll = Gradient(colors: [Color.black.opacity(0.4), Color.black.opacity(0), Color.black.opacity(0), Color.black.opacity(0.4)])
    private static let fog = Gradient(colors: [Color(hex: 0x0C0E12).opacity(0.95), Color(hex: 0x0C0E12).opacity(0.45), Color(hex: 0x0C0E12).opacity(0)])
    private static let vignette = Gradient(colors: [Color.black.opacity(0.45), Color.black.opacity(0)])

    var body: some View {
        Canvas { context, size in draw(&context, size: size) }
            .accessibilityHidden(true)
    }

    /// The runway's perspective: depth 0 is the hit line, 1 the horizon, negative past the line toward you.
    private struct Lanes {
        let width: CGFloat
        let hitY: CGFloat
        let horizonY: CGFloat
        let gap: CGFloat
        let strings: Int
        let order: StringOrder

        init(size: CGSize, strings: Int, order: StringOrder) {
            width = size.width
            hitY = size.height - 58
            horizonY = 16
            self.strings = max(1, strings)
            self.order = order
            gap = (size.width - 36) / CGFloat(max(1, strings))
        }

        func depth(_ d: Double) -> CGFloat { CGFloat(d / (abs(d) + 0.55) * 1.55) }
        func y(_ d: Double) -> CGFloat { hitY - (hitY - horizonY) * depth(d) }
        func scale(_ d: Double) -> CGFloat { 1 - 0.8 * depth(max(-0.3, d)) }
        /// Lane centre of a string: the lane its row takes, counted from the left.
        func x(_ string: Int, _ d: Double) -> CGFloat { laneX(order.row(ofString: string, count: strings), d) }
        func laneX(_ row: Int, _ d: Double) -> CGFloat {
            let lane = CGFloat(row) - CGFloat(strings - 1) / 2
            return width / 2 + lane * gap * scale(d)
        }
        /// The strings in the outer lanes.
        var leftString: Int { order.string(atRow: 0, count: strings) }
        var rightString: Int { order.string(atRow: strings - 1, count: strings) }
        func left(_ d: Double) -> CGFloat { laneX(0, d) - gap * 0.5 * scale(d) }
        func right(_ d: Double) -> CGFloat { laneX(strings - 1, d) + gap * 0.5 * scale(d) }
        /// A point across the board at a depth: 0 its left edge, 1 its right.
        func across(_ u: CGFloat, _ d: Double) -> CGPoint { CGPoint(x: left(d) + (right(d) - left(d)) * u, y: y(d)) }
        /// How clearly something at depth `d` shows through the fog toward the horizon.
        func clarity(_ d: Double) -> Double { d < 0.5 ? 1 : max(0.12, 1 - (d - 0.5) / 0.5 * 0.88) }
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize) {
        let g = Lanes(size: size, strings: strings, order: order)
        drawBoard(&context, g, size: size)
        drawFrets(&context, g)
        drawLanes(&context, g)
        drawFog(&context, g, size: size)
        drawTargets(&context, g)
        // Far notes first, so near ones draw on top.
        for i in notes.indices.reversed() { drawNote(&context, g, index: i) }
        drawHits(&context, g)
        drawVignette(&context, size: size)
        drawLabels(&context, g)
    }

    // MARK: Board

    /// Sky with a glow at the vanishing point, and the fretboard: rosewood with its grain running toward you
    /// (so it never needs to scroll), rolled darker at the edges, and bone binding that warms with the multiplier.
    private func drawBoard(_ context: inout GraphicsContext, _ g: Lanes, size: CGSize) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Self.sky, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        let vanish = CGPoint(x: size.width / 2, y: g.horizonY)
        let haze = size.width * 0.6
        context.fill(circle(vanish, haze), with: .radialGradient(Self.haze, center: vanish, startRadius: 0, endRadius: haze))
        var board = Path()
        board.move(to: CGPoint(x: g.left(1), y: g.horizonY))
        board.addLine(to: CGPoint(x: g.right(1), y: g.horizonY))
        board.addLine(to: CGPoint(x: g.right(Self.near), y: g.y(Self.near)))
        board.addLine(to: CGPoint(x: g.left(Self.near), y: g.y(Self.near)))
        board.closeSubpath()
        context.fill(board, with: .linearGradient(Self.wood, startPoint: CGPoint(x: 0, y: g.horizonY), endPoint: CGPoint(x: 0, y: g.hitY)))
        var grain = context
        grain.clip(to: board)
        for i in 0..<22 {
            let u = CGFloat((Double(i) + 0.15 + 0.7 * CanvasNoise.value(i + 300)) / 22)
            let mid = g.across(u, 0.3)
            var line = Path()
            line.move(to: g.across(u, 1))
            line.addQuadCurve(to: g.across(u, Self.near), control: CGPoint(x: mid.x + CGFloat(CanvasNoise.value(i + 340) - 0.5) * 10, y: mid.y))
            let tone: Color = i % 3 == 0 ? Color.white.opacity(0.03) : Color.black.opacity(0.18 + 0.15 * CanvasNoise.value(i + 380))
            grain.stroke(line, with: .color(tone), lineWidth: 0.7 + 1.6 * CGFloat(CanvasNoise.value(i + 420)))
        }
        grain.fill(board, with: .linearGradient(Self.roll, startPoint: CGPoint(x: g.left(0), y: 0), endPoint: CGPoint(x: g.right(0), y: 0)))
        var binding = Path()
        binding.move(to: CGPoint(x: g.left(1), y: g.horizonY))
        binding.addLine(to: CGPoint(x: g.left(Self.near), y: g.y(Self.near)))
        binding.move(to: CGPoint(x: g.right(1), y: g.horizonY))
        binding.addLine(to: CGPoint(x: g.right(Self.near), y: g.y(Self.near)))
        let edge = heatTint
        if heat >= 2 { context.stroke(binding, with: .color(edge.opacity(0.08 * Double(heat))), lineWidth: 7) }
        context.stroke(binding, with: .linearGradient(Gradient(colors: [edge.opacity(0.05), edge.opacity(heat >= 2 ? 0.65 : 0.35)]),
                                                      startPoint: CGPoint(x: 0, y: g.horizonY), endPoint: CGPoint(x: 0, y: g.hitY)), lineWidth: 1.6)
    }

    /// Bone at ×1–2, amber at ×3, white-gold at ×4.
    private var heatTint: Color {
        switch heat {
        case 4...: return Self.perfectGold
        case 3: return Palette.amber
        default: return Color(hex: 0xEDE3CF)
        }
    }

    /// Fret wires scrolling toward you, one per beat with the bar lines heavier, and a pearl inlay mid-bar.
    private func drawFrets(_ context: inout GraphicsContext, _ g: Lanes) {
        let spb = max(0.05, secondsPerBeat)
        let meter = max(1, beatsPerBar)
        let firstBeat = Int((elapsed / spb).rounded(.down))
        let lastBeat = firstBeat + Int(Self.lookahead / spb) + 1
        for beat in firstBeat...lastBeat {
            let d = (Double(beat) * spb - elapsed) / Self.lookahead
            guard d > -0.1, d < 1 else { continue }
            let bar = ((beat % meter) + meter) % meter == 0
            let sc = g.scale(d), clear = g.clarity(d)
            var wire = Path()
            wire.move(to: CGPoint(x: g.left(d), y: g.y(d)))
            wire.addLine(to: CGPoint(x: g.right(d), y: g.y(d)))
            let w: CGFloat = (bar ? 3.2 : 1.6) * sc
            context.stroke(wire.offsetBy(dx: 0, dy: w * 0.8), with: .color(.black.opacity(0.45 * clear)), lineWidth: w)
            context.stroke(wire, with: .color(Color(hex: 0xC9CED6).opacity((bar ? 0.42 : 0.2) * clear)), lineWidth: w)
            context.stroke(wire.offsetBy(dx: 0, dy: -w * 0.25), with: .color(.white.opacity((bar ? 0.35 : 0.15) * clear)), lineWidth: max(0.5, w * 0.35))
        }
        let barSeconds = Double(meter) * spb
        let firstBar = Int((elapsed / barSeconds).rounded(.down)) - 1
        let lastBar = firstBar + Int(Self.lookahead / barSeconds) + 2
        for bar in firstBar...lastBar {
            let d = ((Double(bar) + 0.5) * barSeconds - elapsed) / Self.lookahead
            guard d > -0.1, d < 1 else { continue }
            let sc = g.scale(d), clear = g.clarity(d)
            let c = CGPoint(x: g.width / 2, y: g.y(d))
            let rx = 7 * sc, ry = 4.2 * sc
            let pearl = Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
            let shine = Gradient(colors: [Color.white.opacity(0.42 * clear), Color(hex: 0xB9D3DC).opacity(0.16 * clear)])
            context.fill(pearl, with: .radialGradient(shine, center: CGPoint(x: c.x - rx * 0.3, y: c.y - ry * 0.3), startRadius: 0, endRadius: rx))
        }
    }

    /// The strings, a lane each: a coloured glow under a metal core, brighter toward you, flaring for a moment
    /// when one of its notes is hit. The low strings are the thicker ones.
    private func drawLanes(_ context: inout GraphicsContext, _ g: Lanes) {
        for s in 1...g.strings {
            let tint = Self.color(string: s, of: strings)
            let gauge = g.strings > 1 ? CGFloat(s - 1) / CGFloat(g.strings - 1) : 0.5
            let half = 0.8 + gauge * 1.1
            let lit = target(string: s).flash
            let from = CGPoint(x: 0, y: g.horizonY), to = CGPoint(x: 0, y: g.hitY)
            context.fill(lane(g, string: s, half: half * 5 + CGFloat(lit) * 10),
                         with: .linearGradient(Gradient(colors: [tint.opacity(0.02), tint.opacity(0.16 + 0.3 * lit)]), startPoint: from, endPoint: to))
            context.fill(lane(g, string: s, half: half),
                         with: .linearGradient(Gradient(colors: [tint.opacity(0.15), tint.mix(with: .white, by: 0.35).opacity(0.9)]), startPoint: from, endPoint: to))
        }
    }

    /// A lane's strip from the horizon to the near edge, `half` either side of its centre at the hit line.
    private func lane(_ g: Lanes, string s: Int, half: CGFloat) -> Path {
        let far = half * g.scale(1), close = half * g.scale(Self.near)
        var p = Path()
        p.move(to: CGPoint(x: g.x(s, 1) - far, y: g.horizonY))
        p.addLine(to: CGPoint(x: g.x(s, 1) + far, y: g.horizonY))
        p.addLine(to: CGPoint(x: g.x(s, Self.near) + close, y: g.y(Self.near)))
        p.addLine(to: CGPoint(x: g.x(s, Self.near) - close, y: g.y(Self.near)))
        p.closeSubpath()
        return p
    }

    /// Depth fog over the far end of the board: notes rise out of it.
    private func drawFog(_ context: inout GraphicsContext, _ g: Lanes, size: CGSize) {
        let end = g.y(0.5)
        context.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: end)),
                     with: .linearGradient(Self.fog, startPoint: CGPoint(x: 0, y: g.horizonY), endPoint: CGPoint(x: 0, y: end)))
    }

    // MARK: Hit line

    private struct TargetState {
        /// 1 → 0 over the moment after one of the string's notes is hit.
        var flash = 0.0
        /// One of its notes was just missed.
        var missed = false
        /// 0 → 1 as its next note closes in on the line.
        var approach = 0.0
    }

    private func target(string s: Int) -> TargetState {
        var state = TargetState()
        for i in notes.indices where notes[i].at?.string == s {
            if let grade = grades[i] {
                guard let time = hitTimes[i] else { continue }
                let age = now - time
                guard age >= 0, age < 0.35 else { continue }
                if grade == .miss { state.missed = true } else { state.flash = max(state.flash, 1 - age / 0.35) }
            } else {
                let d = (notes[i].beat * secondsPerBeat - elapsed) / Self.lookahead
                if d > -0.05, d < 0.15 { state.approach = max(state.approach, 1 - max(0, d) / 0.15) }
            }
        }
        return state
    }

    /// The hit line across the board and a target ring per string: recessed, filling as a note comes in,
    /// flashing in the string's colour on a hit (coral on a miss).
    private func drawTargets(_ context: inout GraphicsContext, _ g: Lanes) {
        let from = g.left(0) - 6, to = g.right(0) + 6
        let line = heat >= 3 ? heatTint : Color(hex: 0xFFF4DE)
        let band = CGRect(x: from, y: g.hitY - 13, width: to - from, height: 26)
        context.fill(Path(roundedRect: band, cornerRadius: 13),
                     with: .linearGradient(Gradient(colors: [line.opacity(0), line.opacity(0.1 + 0.04 * Double(heat)), line.opacity(0)]),
                                           startPoint: CGPoint(x: 0, y: band.minY), endPoint: CGPoint(x: 0, y: band.maxY)))
        context.fill(Path(roundedRect: CGRect(x: from, y: g.hitY - 1.5, width: to - from, height: 3), cornerRadius: 1.5), with: .color(line.opacity(0.75)))
        let radius = min(19, g.gap * 0.36)
        for s in 1...g.strings {
            let state = target(string: s)
            let tint = state.missed ? Palette.danger : Self.color(string: s, of: strings)
            let center = CGPoint(x: g.x(s, 0), y: g.hitY)
            let r = radius * (1 + (calm ? 0 : CGFloat(state.flash) * 0.2))
            context.fill(circle(center, radius + 3), with: .color(.black.opacity(0.5)))
            let fill = Gradient(colors: [tint.opacity(0.08 + 0.35 * state.approach + 0.5 * state.flash), tint.opacity(0.04 + 0.2 * state.flash)])
            context.fill(circle(center, r), with: .radialGradient(fill, center: center, startRadius: 0, endRadius: r))
            context.stroke(circle(center, r), with: .color(tint.opacity(0.75 + 0.25 * max(state.approach, state.flash))), lineWidth: 2.5)
            var shine = Path()
            shine.addRelativeArc(center: center, radius: max(1, r - 3.5), startAngle: .degrees(205), delta: .degrees(130))
            context.stroke(shine, with: .color(.white.opacity(0.28)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }

    // MARK: Notes

    private func drawNote(_ context: inout GraphicsContext, _ g: Lanes, index i: Int) {
        let note = notes[i]
        guard let at = note.at else { return }
        let start = (note.beat * secondsPerBeat - elapsed) / Self.lookahead
        let end = ((note.beat + note.beats) * secondsPerBeat - elapsed) / Self.lookahead
        guard start < 1.05, end > -0.25 else { return }
        let grade = grades[i]
        let age = min(1, hitTimes[i].map { now - $0 } ?? 0)
        let tint = Self.color(string: at.string, of: strings)
        if note.beats >= Self.sustainBeats {
            drawTail(&context, g, string: at.string, start: start, end: end, tint: tint, grade: grade)
        }
        drawGem(&context, g, string: at.string, fret: at.fret, start: start, tint: tint, grade: grade, age: age)
    }

    /// A long note's sustain tail up its lane to where the note ends: bright while it rings after a hit (burning
    /// down at the hit line), grey once missed.
    private func drawTail(_ context: inout GraphicsContext, _ g: Lanes, string s: Int, start: Double, end: Double, tint: Color, grade: PlayAlongJudge.Grade?) {
        let held = grade != nil && grade != .miss
        let a = held ? max(start, 0) : max(start, Self.near)
        let b = min(end, 1)
        guard b > a else { return }
        let color = grade == .miss ? Palette.inkFaint : tint
        let strength = grade == .miss ? 0.3 : held ? 1.0 : 0.75
        let half: CGFloat = 6
        var tail = Path()
        tail.move(to: CGPoint(x: g.x(s, a) - half * g.scale(a), y: g.y(a)))
        tail.addLine(to: CGPoint(x: g.x(s, b) - half * g.scale(b), y: g.y(b)))
        tail.addLine(to: CGPoint(x: g.x(s, b) + half * g.scale(b), y: g.y(b)))
        tail.addLine(to: CGPoint(x: g.x(s, a) + half * g.scale(a), y: g.y(a)))
        tail.closeSubpath()
        let fill = Gradient(colors: [color.opacity(0.85 * strength), color.opacity(0.2 * strength * g.clarity(b))])
        context.fill(tail, with: .linearGradient(fill, startPoint: CGPoint(x: 0, y: g.y(a)), endPoint: CGPoint(x: 0, y: g.y(b))))
        var core = Path()
        core.move(to: CGPoint(x: g.x(s, a), y: g.y(a)))
        core.addLine(to: CGPoint(x: g.x(s, b), y: g.y(b)))
        context.stroke(core, with: .color(.white.opacity((held ? 0.8 : 0.4) * strength)), lineWidth: 2 * g.scale(a))
        if held, start <= 0, end > 0, !calm {
            // Ringing: it burns down where it meets the line.
            let center = CGPoint(x: g.x(s, 0), y: g.hitY)
            let flicker = 14 + 4 * CGFloat(sin(now * 38 + Double(s)))
            let flare = Gradient(colors: [Color.white.opacity(0.8), tint.opacity(0.45), tint.opacity(0)])
            context.fill(circle(center, flicker), with: .radialGradient(flare, center: center, startRadius: 0, endRadius: flicker))
        }
    }

    /// A note gem: a glossy tile in its string's colour with the fret on it, standing on its own darker edge and
    /// glowing as it nears the line. A hit pops white for an instant (its burst takes over); a miss runs on past,
    /// hollow and coral.
    private func drawGem(_ context: inout GraphicsContext, _ g: Lanes, string s: Int, fret: Int, start: Double, tint: Color,
                         grade: PlayAlongJudge.Grade?, age: Double) {
        let hit = grade != nil && grade != .miss
        if hit && (calm || age > 0.16) { return }
        let d = hit ? 0 : start
        let sc = g.scale(d)
        var w = g.gap * 0.86 * sc, h = 34 * sc
        var alpha = (start > 0.85 ? max(0, (1.05 - start) / 0.2) : 1) * g.clarity(d)
        if hit {
            let pop = 1 + CGFloat(age / 0.16) * 0.5
            w *= pop; h *= pop
            alpha = 1 - age / 0.16
        }
        if grade == .miss { alpha = max(0.2, 0.8 - age) }
        guard alpha > 0.01 else { return }
        let center = CGPoint(x: g.x(s, d), y: g.y(d))
        let rect = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
        let corner = 10 * sc
        let face = Path(roundedRect: rect, cornerRadius: corner)
        if grade == .miss {
            context.fill(face, with: .color(Palette.danger.opacity(0.12 * alpha)))
            context.stroke(face, with: .color(Palette.danger.opacity(0.8 * alpha)), lineWidth: 2)
            context.draw(fretLabel(fret, size: 17 * sc, color: Palette.danger.opacity(alpha)), at: center)
            return
        }
        if grade == nil, d < 0.3 {
            let reach = w * 0.95
            let glow = Gradient(colors: [tint.opacity(0.35 * (1 - d / 0.3) * alpha), tint.opacity(0)])
            context.fill(circle(center, reach), with: .radialGradient(glow, center: center, startRadius: 0, endRadius: reach))
        }
        context.fill(Path(roundedRect: rect.offsetBy(dx: 0, dy: 5 * sc), cornerRadius: corner), with: .color(tint.mix(with: .black, by: 0.5).opacity(alpha)))
        let faceTint = hit ? tint.mix(with: .white, by: 0.7) : tint
        let shade = Gradient(colors: [faceTint.mix(with: .white, by: 0.35).opacity(alpha), faceTint.opacity(alpha), faceTint.mix(with: .black, by: 0.15).opacity(alpha)])
        context.fill(face, with: .linearGradient(shade, startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
        let gloss = CGRect(x: rect.minX + 3 * sc, y: rect.minY + 2 * sc, width: max(0, rect.width - 6 * sc), height: rect.height * 0.38)
        context.fill(Path(roundedRect: gloss, cornerRadius: corner * 0.7),
                     with: .linearGradient(Gradient(colors: [Color.white.opacity(0.45 * alpha), Color.white.opacity(0)]),
                                           startPoint: CGPoint(x: 0, y: gloss.minY), endPoint: CGPoint(x: 0, y: gloss.maxY)))
        context.stroke(face, with: .color(.white.opacity(0.35 * alpha)), lineWidth: 1)
        if !hit {
            context.draw(fretLabel(fret, size: 18 * sc, color: Palette.onAccent.opacity(alpha)), at: CGPoint(x: center.x, y: center.y + 0.5 * sc))
        }
    }

    private func fretLabel(_ fret: Int, size: CGFloat, color: Color) -> Text {
        Text(verbatim: "\(fret)").font(.system(size: max(9, size), weight: .heavy, design: .rounded)).foregroundStyle(color)
    }

    // MARK: Hits

    /// Each hit bursts on the hit line: a beam up its lane, the line lighting up either side, then the burst
    /// itself (bigger and white-gold when perfect). Reduce Motion keeps just the target lighting up.
    private func drawHits(_ context: inout GraphicsContext, _ g: Lanes) {
        guard !calm else { return }
        var light = context
        light.blendMode = .plusLighter
        for i in notes.indices {
            guard let s = notes[i].at?.string, let grade = grades[i], grade != .miss, let time = hitTimes[i] else { continue }
            let age = now - time
            guard age >= 0, age < HitBurst.lifetime else { continue }
            let perfect = grade == .perfect
            let tint = perfect ? Self.perfectGold : Self.color(string: s, of: strings)
            let cx = g.x(s, 0)
            if age < 0.4 {
                let f = 1 - age / 0.4
                let top = 0.45
                let half = g.gap * 0.42
                var beam = Path()
                beam.move(to: CGPoint(x: cx - half, y: g.hitY))
                beam.addLine(to: CGPoint(x: g.x(s, top) - half * g.scale(top), y: g.y(top)))
                beam.addLine(to: CGPoint(x: g.x(s, top) + half * g.scale(top), y: g.y(top)))
                beam.addLine(to: CGPoint(x: cx + half, y: g.hitY))
                beam.closeSubpath()
                light.fill(beam, with: .linearGradient(Gradient(colors: [tint.opacity((perfect ? 0.55 : 0.35) * f), tint.opacity(0)]),
                                                       startPoint: CGPoint(x: 0, y: g.hitY), endPoint: CGPoint(x: 0, y: g.y(top))))
            }
            if age < 0.3 {
                let f = 1 - age / 0.3
                let reach: CGFloat = perfect ? 150 : 100
                let streak = CGRect(x: cx - reach, y: g.hitY - 3, width: reach * 2, height: 6)
                light.fill(Path(roundedRect: streak, cornerRadius: 3),
                           with: .linearGradient(Gradient(colors: [tint.opacity(0), tint.opacity(0.9 * f), tint.opacity(0)]),
                                                 startPoint: CGPoint(x: streak.minX, y: 0), endPoint: CGPoint(x: streak.maxX, y: 0)))
            }
            HitBurst.draw(&light, at: CGPoint(x: cx, y: g.hitY), tint: tint, perfect: perfect, age: age, seed: i, upward: true)
        }
    }

    // MARK: Finish

    private func drawVignette(_ context: inout GraphicsContext, size: CGSize) {
        context.fill(Path(CGRect(x: 0, y: 0, width: 36, height: size.height)),
                     with: .linearGradient(Self.vignette, startPoint: .zero, endPoint: CGPoint(x: 36, y: 0)))
        context.fill(Path(CGRect(x: size.width - 36, y: 0, width: 36, height: size.height)),
                     with: .linearGradient(Self.vignette, startPoint: CGPoint(x: size.width, y: 0), endPoint: CGPoint(x: size.width - 36, y: 0)))
    }

    /// The string numbers under the targets, and the outer lanes named in words.
    private func drawLabels(_ context: inout GraphicsContext, _ g: Lanes) {
        for s in 1...g.strings {
            context.draw(Text("\(s)").font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.inkFaint), at: CGPoint(x: g.x(s, 0), y: g.hitY + 28))
        }
        if let edges, g.strings >= 2 {
            // Under the outer lanes' numbers, reading inward so they never run off the stage.
            if let name = edges.canvasLabel(g.leftString, size: 9) { context.draw(name, at: CGPoint(x: g.laneX(0, 0) - 16, y: g.hitY + 43), anchor: .leading) }
            if let name = edges.canvasLabel(g.rightString, size: 9) { context.draw(name, at: CGPoint(x: g.laneX(g.strings - 1, 0) + 16, y: g.hitY + 43), anchor: .trailing) }
        }
    }

    private func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}

// MARK: - Around the stage

/// The combo multiplier: ×2 from 4 perfect or good notes in a row, ×3 from 8, ×4 from 16. A ring around the
/// run's length fills toward the next step, and the badge pulses (and its flame hops) as it steps up.
struct ComboBadge: View {
    let combo: Int
    /// Reduce Motion: no pulse, no hop.
    var calm = false

    static func multiplier(_ combo: Int) -> Int { combo >= 16 ? 4 : combo >= 8 ? 3 : combo >= 4 ? 2 : 1 }

    /// 0…1 of the way to the next step; full at ×4.
    static func progress(_ combo: Int) -> Double {
        switch combo {
        case ..<4: return Double(max(0, combo)) / 4
        case 4..<8: return Double(combo - 4) / 4
        case 8..<16: return Double(combo - 8) / 8
        default: return 1
        }
    }

    /// The flame's orange, amber at ×3, white-gold at ×4.
    static func tint(_ multiplier: Int) -> Color {
        switch multiplier {
        case 4...: return HighwayRunway.perfectGold
        case 3: return Palette.amber
        default: return Palette.flame
        }
    }

    var body: some View {
        let level = Self.multiplier(combo)
        let tint = Self.tint(level)
        HStack(spacing: 6) {
            ZStack {
                Circle().stroke(tint.opacity(0.22), lineWidth: 3)
                Circle().trim(from: 0, to: max(0.001, Self.progress(combo)))
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(combo, format: .number).font(Typeface.number(10)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(width: 26, height: 26)
            .animation(calm ? nil : .easeOut(duration: 0.2), value: combo)
            HStack(spacing: 2) {
                Image(systemName: "flame.fill").font(.system(size: 13, weight: .bold))
                    .symbolEffect(.bounce, value: calm ? 0 : level)
                Text("×\(level)").font(Typeface.number(18))
                    .contentTransition(.numericText(value: Double(level)))
            }
            .foregroundStyle(tint)
        }
        .padding(.leading, 5).padding(.trailing, 12).padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.14)))
        .overlay(Capsule().strokeBorder(tint.opacity(level >= 4 ? 0.65 : 0.3), lineWidth: 1))
        .shadow(color: tint.opacity(level >= 3 ? 0.5 : 0), radius: 10)
        .phaseAnimator([1.0, 1.24], trigger: level) { content, scale in
            content.scaleEffect(CGFloat(calm ? 1 : scale))
        } animation: { _ in Animation.spring(response: 0.22, dampingFraction: 0.55) }
        .animation(calm ? nil : Motion.pluck, value: level)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Combo ×\(combo)"))
    }
}

/// The notes after the next one, in order: tiles in their string's colour with the fret over the note name
/// (just the note on pitch lanes). They slide along as each note is played, fading toward the end of the rail.
struct UpNextRail: View {
    let notes: [TimedNote]
    /// The first note on the rail (the one after "Next").
    let from: Int
    let fretted: Bool
    let strings: Int
    let accent: Color
    static let length = 6

    private var shown: [Int] { from < notes.count ? Array(from..<min(notes.count, from + Self.length)) : [] }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.inkFaint)
                .opacity(shown.isEmpty ? 0 : 1)
            ForEach(shown, id: \.self) { index in
                tile(notes[index], rank: index - from)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .scale(scale: 0.6).combined(with: .opacity)))
            }
            Spacer(minLength: 0)
        }
        .frame(height: 44)
        .accessibilityHidden(true)
    }

    private func tile(_ note: TimedNote, rank: Int) -> some View {
        let tint = color(note)
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return VStack(spacing: 0) {
            if fretted, let at = note.at {
                Text(at.fret, format: .number).font(Typeface.number(16)).foregroundStyle(Palette.ink)
                Text(NoteName.pitchClass(note.midi)).font(Typeface.label(9)).foregroundStyle(tint)
            } else {
                Text(NoteName.pitchClass(note.midi)).font(Typeface.label(15)).foregroundStyle(Palette.ink)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(width: 42, height: 42)
        .background(shape.fill(tint.opacity(0.16)))
        .overlay(shape.strokeBorder(tint.opacity(0.55), lineWidth: 1))
        .overlay(alignment: .bottom) { Capsule().fill(tint).frame(width: 18, height: 3).offset(y: 1.5) }
        .opacity(1 - Double(rank) * 0.13)
    }

    private func color(_ note: TimedNote) -> Color {
        guard fretted, let at = note.at else { return accent }
        return HighwayRunway.color(string: at.string, of: strings)
    }
}

/// The take so far, under the stage while it plays: the grades counted, and a ribbon with a segment per note
/// that takes its grade's colour as it is judged (white-gold perfect, the course colour good, amber late or
/// early, coral missed); the note being waited for stands taller.
struct TakeRibbon: View {
    let count: Int
    let grades: [Int: PlayAlongJudge.Grade]
    let current: Int
    let accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                stat(.perfect, symbol: "star.fill", name: "Perfect")
                stat(.good, symbol: "checkmark", name: "Good")
                stat(.ok, symbol: "clock", name: "Late/early")
                stat(.miss, symbol: "xmark", name: "Missed")
            }
            HStack(spacing: count > 48 ? 1 : 2) {
                ForEach(0..<max(0, count), id: \.self) { index in
                    Capsule()
                        .fill(segment(index))
                        .frame(height: index == current ? 10 : 6)
                }
            }
            .frame(height: 10)
            .animation(reduceMotion ? nil : Motion.quick, value: grades.count)
        }
        .padding(.horizontal, 24)
    }

    private func segment(_ index: Int) -> Color {
        guard let grade = grades[index] else { return Color.white.opacity(index == current ? 0.4 : 0.1) }
        return Self.color(grade, accent: accent)
    }

    static func color(_ grade: PlayAlongJudge.Grade, accent: Color) -> Color {
        switch grade {
        case .perfect: return HighwayRunway.perfectGold
        case .good: return accent
        case .ok: return Palette.amber
        case .miss: return Palette.danger
        }
    }

    private func stat(_ grade: PlayAlongJudge.Grade, symbol: String, name: LocalizedStringKey) -> some View {
        let value = grades.values.reduce(0) { $0 + ($1 == grade ? 1 : 0) }
        return HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 11, weight: .bold))
            Text(value, format: .number).font(Typeface.number(15))
                .contentTransition(.numericText(value: Double(value)))
        }
        .foregroundStyle(Self.color(grade, accent: accent))
        .opacity(value == 0 ? 0.45 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(name))
        .accessibilityValue(Text(value, format: .number))
    }
}
