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

    var body: some View {
        VStack(spacing: 14) {
            header
            TimelineView(.animation(paused: phase != .playing)) { timeline in
                let now = CACurrentMediaTime()
                let elapsed = phase == .ready ? -countIn : now - startTime - countIn
                ZStack {
                    HighwayCanvas(notes: notes, secondsPerBeat: spb, elapsed: elapsed, grades: grades, hitTimes: hitTimes, now: phase == .done ? now + 10 : now,
                                  lanes: fretted ? course.stringCount : 0, accent: accent, trail: fretted ? [] : trail, startTime: startTime + countIn)
                    if phase == .playing, elapsed < 0 {
                        Text("\(Int(-elapsed / spb) + 1)").font(Typeface.note(96)).foregroundStyle(Palette.ink)
                            .shadow(color: accent.opacity(0.6), radius: 20)
                            .transition(.scale.combined(with: .opacity))
                    }
                    GeometryReader { geometry in
                        SparkBurst(trigger: burst, color: accent).frame(width: 140, height: 140)
                            .position(x: geometry.size.width * 0.24, y: geometry.size.height / 2)
                    }
                }
                .onChange(of: Int(now * 20)) { _, _ in tick(now: now) }
            }
            .frame(height: 290)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Palette.stageDeep))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.horizontal, 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Play-along, \(notes.count) notes"))
            if phase == .done { summary } else { upcoming }
            Spacer(minLength: 0)
            MicrophoneHint()
            controls
        }
        .onDisappear { store.audio.stopMetronome(); store.stopLessonListening(owner: owner) }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title?.localized ?? String(localized: "Play along")).font(Typeface.display(24)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.7)
                Text("\(Int(tempo)) BPM · \(notes.count) notes").font(.subheadline).foregroundStyle(Palette.inkSoft)
            }
            Spacer()
            if judge.combo >= 3 {
                Label("×\(judge.combo)", systemImage: "flame.fill").font(Typeface.label(16)).foregroundStyle(Palette.flame)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(Palette.flame.opacity(0.14)))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(Motion.pluck, value: judge.combo >= 3)
        .padding(.horizontal, 22).padding(.top, 8)
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

    private var summary: some View {
        let counts = Dictionary(grouping: grades.values, by: { $0 }).mapValues(\.count)
        return VStack(spacing: 10) {
            Text("\(Int((judge.accuracy * 100).rounded()))%").font(Typeface.note(56)).foregroundStyle(accent)
            HStack(spacing: 18) {
                stat("Perfect", counts[.perfect] ?? 0, accent)
                stat("Good", counts[.good] ?? 0, Palette.ink)
                stat("Late/early", counts[.ok] ?? 0, Palette.amber)
                stat("Missed", counts[.miss] ?? 0, Palette.danger)
            }
            Text("Best combo \(judge.bestCombo)").font(.footnote).foregroundStyle(Palette.inkSoft)
        }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
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
        store.audio.stopMetronome()
        store.stopLessonListening(owner: owner)
        withAnimation(Motion.settle) { phase = .done }
        SoundFX.shared.play(judge.accuracy >= 0.7 ? .star : .wrong)
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
