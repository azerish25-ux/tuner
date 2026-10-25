import SwiftUI
import TimbreCore

/// The instrument a chart's chords are drawn and practised on: the tuner's instrument when it strums chords (guitar,
/// ukulele, banjo, mandolin), else the guitar, in the standard tuning the lessons use for it.
struct ChartInstrument: Equatable {
    let id: String
    /// Open strings, lowest first (`ChordStep.openStrings`).
    let openMidi: [Int]

    @MainActor init(_ store: AppStore) {
        let selected = store.instrument.id
        let id = LearnCourse.strummed(selected) ? selected : "guitar.acoustic.6"
        self.id = id
        openMidi = ChordStep.openStrings(kind: LearnCourse.fretKind(of: id))
    }

    var isGuitar: Bool { LearnCourse.fretKind(of: id) == "guitar" }

    /// The lesson course the chart's practice steps run in (its instrument's strings, sound and runway).
    var course: LearnCourse {
        LearnCourse(id: "yoursongs", title: LearnText("Your songs"), subtitle: LearnText(""), instrument: id, symbol: "music.note",
                    accent: "mint", units: [])
    }

    /// The shape to show and play for a chord.
    func spec(_ chord: ChordSymbol) -> ChordSpec? { ChartPractice.spec(for: chord, openMidi: openMidi) }

    /// A shape's notes, lowest string first (muted strings left out).
    func notes(_ spec: ChordSpec) -> [Int] {
        spec.frets.enumerated().compactMap { index, fret in fret >= 0 && index < openMidi.count ? openMidi[index] + fret : nil }
    }

    /// A chart's practice: each of its chords to play and let ring (the lessons' chord step, which hears a strum with the
    /// chord recogniser), then its opening bars strummed as a progression in time.
    func steps(for chart: ChordChart, transform: ChartTransform) -> [LessonStep] {
        var steps: [LessonStep] = ChartPractice.drill(chart, transform: transform).compactMap { shape in
            spec(shape).map { LessonStep.playChord(chord: $0) }
        }
        var chords: [ChordSpec] = []
        var bars: [Int] = []
        for item in ChartPractice.progression(chart, transform: transform) {
            guard let shape = spec(item.chord) else { continue }
            chords.append(shape)
            bars.append(item.bars)
        }
        if chords.count >= 2 {
            let meter = chart.beatsPerBar
            steps.append(.progression(chords: chords, bars: bars, pattern: (0..<meter).map { Double($0) },
                                      bpm: ChartPractice.tempo(for: chart), beatsPerBar: meter))
        }
        return steps
    }
}

/// Practising a chart, full screen: the lessons' own steps one after another (`StepView`: each chord to play, then the
/// progression strummed in time), after the tune check when one is due, then how it went. It counts toward the day's
/// practice (minutes, streak) but is not a lesson: no stars or XP are recorded.
struct ChartPracticeView: View {
    let title: String
    let steps: [LessonStep]
    let course: LearnCourse
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var scores: [Double] = []
    @State private var tuneChecked = false
    @State private var confirmQuit = false
    @State private var round = 0

    private var accent: Color { Palette.mint }

    var body: some View {
        ZStack {
            Palette.stage.ignoresSafeArea()
            RadialGradient(colors: [accent.opacity(0.16), .clear], center: UnitPoint(x: 0.5, y: 0), startRadius: 10, endRadius: 520)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                stage
            }
        }
        .adaptiveAnimation(Motion.page, value: index)
        .preferredColorScheme(.dark)
        .statusBarHidden(index < steps.count)
        .onAppear {
            store.audio.courseVoice = InstrumentVoice(instrumentId: course.instrument)
            store.beginPractice(DailyActivity.Kind.chord.rawValue)
            Analytics.log("yoursongs_practice", ["steps": "\(steps.count)"])
        }
        .onDisappear {
            store.audio.courseVoice = nil
            store.stopLessonListening()
            if store.audio.metronomeRunning && !store.audio.metronomeOwnedByTool { store.audio.stopMetronome() }
            store.finishPractice(.chord)
        }
        .confirmationDialog("Stop practising?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Stop", role: .destructive) { dismiss() }
            Button("Keep going", role: .cancel) {}
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            CloseButton(label: "Close") { if index == 0 || index >= steps.count { dismiss() } else { confirmQuit = true } }
                .accessibilityIdentifier("yoursongs.practice.close")
            LessonHeader(title: title, index: min(index, steps.count), steps: steps.count, accent: accent,
                         tuningUp: index < steps.count && steps[index].usesMicrophone && !tuneChecked && TuneCheckStep.needed(for: course))
        }
        .padding(.leading, 8).padding(.trailing, Metrics.gutter).padding(.top, 4).padding(.bottom, 6)
    }

    @ViewBuilder private var stage: some View {
        if index >= steps.count {
            summary
                .transition(.adaptive(.opacity.combined(with: .scale(scale: 0.96)), reduceMotion: reduceMotion))
        } else if steps[index].usesMicrophone, !tuneChecked, TuneCheckStep.needed(for: course) {
            TuneCheckStep(course: course, accent: accent) { withAnimation { tuneChecked = true } }
                .transition(.opacity)
        } else {
            StepView(step: steps[index], course: course, accent: accent, done: { score in advance(score) })
                .id("\(round)-\(index)")
                .transition(.adaptive(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                  removal: .move(edge: .leading).combined(with: .opacity)), reduceMotion: reduceMotion))
        }
    }

    private func advance(_ score: Double?) {
        if let score { scores.append(max(0, min(1, score))) }
        withMotion(Motion.page, reduceMotion: reduceMotion) { index += 1 }
        if index >= steps.count {
            SoundFX.shared.play(.complete)
            Haptics.shared.done()
        }
    }

    private var accuracy: Double { scores.isEmpty ? 1 : scores.reduce(0, +) / Double(scores.count) }

    /// How it went: the share of the chords that rang true, three marks for it, and again or back to the song.
    private var summary: some View {
        let share = accuracy
        let marks = share >= 0.9 ? 3 : share >= 0.7 ? 2 : 1
        return VStack(spacing: 22) {
            Spacer(minLength: 0)
            ZStack {
                SparkBurst(trigger: round + 1, color: accent).frame(width: 260, height: 260)
                Glyph(.chart, size: 72, tint: Palette.mint)
            }
            VStack(spacing: 8) {
                StepTitle(Text("Practice done")).multilineTextAlignment(.center)
                Text("\(Int((share * 100).rounded()))% of it rang true.").font(.body).foregroundStyle(Palette.inkSoft)
            }
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: "star.fill").font(.system(size: 28, weight: .bold))
                        .foregroundStyle(i < marks ? AnyShapeStyle(Palette.starFill) : AnyShapeStyle(Color.white.opacity(0.14)))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(marks) of 3 stars"))
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                Button { again() } label: { Text("Practice again") }
                    .buttonStyle(PrimaryButtonStyle())
                Button { dismiss() } label: { Text("Back to the song") }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("yoursongs.practice.done")
            }
            .padding(.horizontal, Metrics.gutter).padding(.bottom, 12)
        }
        .padding(.horizontal, Metrics.gutter)
    }

    private func again() {
        scores = []
        round += 1
        withMotion(Motion.page, reduceMotion: reduceMotion) { index = 0 }
    }
}
