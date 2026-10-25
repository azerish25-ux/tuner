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

    /// The whole chart as one "Chords & words" take (`ChartTake`); nil for a chart with fewer than two chords to play.
    @MainActor func take(for chart: ChordChart, title: String, transform: ChartTransform) -> ChartTake? {
        ChartTake(chart: chart, title: title, transform: transform, instrument: self)
    }
}

/// A chart the player brought, played start to finish as a "Chords & words" take (`SongChordsTake`), as a song lesson's
/// final take is: every chord in reading order for a bar (a chart doesn't say how long a chord lasts, and most write one
/// a bar), a repeated chorus (`{chorus}`) played again, the words under each chord shown on its bar, karaoke style,
/// each section of the chart a part of the song map. At the chart's practice tempo, over the band in headphones.
struct ChartTake {
    let bars: [ChordBar]
    let lyrics: LyricSheet
    let sheet: ChordTakeSheet
    let bpm: Double
    let beatsPerBar: Int

    @MainActor init?(chart: ChordChart, title: String, transform: ChartTransform, instrument: ChartInstrument) {
        let names = transform.names(for: chart)
        let meter = max(1, chart.beatsPerBar)
        var bars: [ChordBar] = []
        var words: [(bar: Int, text: String, startsLine: Bool)] = []
        var sections: [SongSheet.Section] = []
        var parts: [(beat: Double, name: String)] = []
        var lastChorus: ChartSection?
        for written in chart.sections where written.kind != .tab {
            var section = written
            if written.isRepeat && !written.hasContent, let chorus = lastChorus { section = chorus }
            if section.kind == .chorus && section.hasContent { lastChorus = section }
            let start = bars.count
            for line in section.lines {
                guard case let .lyrics(segments) = line else { continue }
                var pending = ""
                var firstInLine = true
                for segment in segments {
                    let text = segment.isBarText ? "" : segment.text
                    guard let chord = segment.chord, let symbol = transform.shapeSymbol(chord, names: names),
                          let shape = instrument.spec(symbol) else {
                        // Words before the line's first chord (or under an annotation) go with the next chord's.
                        pending += text
                        continue
                    }
                    bars.append(ChordBar(shape))
                    let sung = pending + text
                    pending = ""
                    if !sung.trimmingCharacters(in: .whitespaces).isEmpty {
                        words.append((bar: bars.count - 1, text: sung, startsLine: firstInLine))
                        firstInLine = false
                    }
                }
            }
            guard bars.count > start else { continue }
            let name = Self.name(of: section)
            sections.append(SongSheet.Section(id: sections.count, title: name.map { LearnText($0) }, chord: nil, start: start,
                                              bars: bars.count - start))
            if let name { parts.append((beat: Double(start * meter), name: name)) }
        }
        guard bars.count >= 2 else { return nil }
        self.bars = bars
        beatsPerBar = meter
        bpm = ChartPractice.tempo(for: chart)
        lyrics = LyricSheet(notes: Self.notes(words, meter: meter))
        sheet = ChordTakeSheet(title: title, art: nil, sections: sections, bars: bars.count, parts: parts, event: "yoursongs_take",
                               properties: ["bars": "\(bars.count)"])
    }

    /// A section's name as the chart shows it: its own label, else its kind's ("Chorus"); nil for plain lines.
    private static func name(of section: ChartSection) -> String? {
        if let label = section.label?.trimmingCharacters(in: .whitespaces), !label.isEmpty { return label }
        let bundle = TimbreLocalization.bundle
        switch section.kind {
        case .chorus: return String(localized: "Chorus", bundle: bundle)
        case .verse: return String(localized: "Verse", bundle: bundle)
        case .bridge: return String(localized: "Bridge", bundle: bundle)
        case .grid: return String(localized: "Chords", bundle: bundle)
        case .tab, .other, .untitled: return nil
        }
    }

    /// The words as the karaoke row reads them: each chord's words a "syllable" on its bar's downbeat (`TimedNote.lyric`;
    /// no note is played), joined to the next without a space where a chord falls inside a word ("Ama[C]zing").
    private static func notes(_ words: [(bar: Int, text: String, startsLine: Bool)], meter: Int) -> [TimedNote] {
        words.enumerated().map { index, entry -> TimedNote in
            var insideWord = false
            if index + 1 < words.count, !words[index + 1].startsLine, let end = entry.text.last, let begin = words[index + 1].text.first {
                insideWord = !end.isWhitespace && !begin.isWhitespace
            }
            let trimmed = entry.text.trimmingCharacters(in: .whitespaces)
            return TimedNote(midi: 60, beat: Double(entry.bar * meter), beats: Double(meter), lyric: insideWord ? trimmed + "-" : trimmed,
                             startsLine: entry.startsLine)
        }
    }

    /// The band under it: the chords bar by bar (no melody of its own to follow).
    @MainActor func band(reference: Double) -> BandArrangement {
        SongPlayback.band(notes: [], harmony: bars, bars: bars.count, bpm: bpm, meter: beatsPerBar, reference: reference, bass: true)
    }
}

/// Practising a chart, full screen: the lessons' own steps one after another (`StepView`: each chord to play, then the
/// progression strummed in time), after the tune check when one is due, then how it went. From there the whole song can
/// be played through as "Chords & words" (`song`, the take a song lesson ends on): every chord heard and judged, the
/// words running under it. It counts toward the day's practice (minutes, streak) but is not a lesson: no stars or XP
/// are recorded.
struct ChartPracticeView: View {
    let title: String
    let steps: [LessonStep]
    let course: LearnCourse
    /// The whole chart as one take, offered once the steps are done; nil leaves the steps alone.
    var song: ChartTake?
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @AppStorage(SpokenCues.storageKey) private var spokenChoice: Bool?
    @State private var index = 0
    @State private var scores: [Double] = []
    @State private var tuneChecked = false
    @State private var confirmQuit = false
    @State private var round = 0
    /// The whole song is being played through.
    @State private var playingSong = false
    /// How the last whole-song take went (0…1), for the summary.
    @State private var songScore: Double?

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
        .adaptiveAnimation(Motion.page, value: playingSong)
        .preferredColorScheme(.dark)
        .statusBarHidden(index < steps.count || playingSong)
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
            CloseButton(label: "Close") {
                if (index == 0 || index >= steps.count) && !playingSong { dismiss() } else { confirmQuit = true }
            }
            .accessibilityIdentifier("yoursongs.practice.close")
            LessonHeader(title: title, index: min(index, steps.count), steps: steps.count, accent: accent,
                         tuningUp: index < steps.count && steps[index].usesMicrophone && !tuneChecked && TuneCheckStep.needed(for: course))
        }
        .padding(.leading, 8).padding(.trailing, Metrics.gutter).padding(.top, 4).padding(.bottom, 6)
    }

    @ViewBuilder private var stage: some View {
        if playingSong, let song {
            songTake(song)
                .transition(.opacity)
        } else if index >= steps.count {
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

    /// The whole song played through, as a song lesson's "Chords & words" take; back to the summary once it ends or
    /// stops.
    private func songTake(_ song: ChartTake) -> some View {
        SongChordsTake(sheet: song.sheet, accent: accent, tempo: song.bpm, beatsPerBar: song.beatsPerBar, bars: song.bars,
                       lyrics: song.lyrics, band: song.band(reference: store.settings.referencePitchHz),
                       spoken: voiceOver && (spokenChoice ?? true),
                       finished: { result in
                           songScore = result.accuracy
                           if result.accuracy >= 0.7 { SoundFX.shared.play(.complete) }
                           Haptics.shared.done()
                           withMotion(Motion.page, reduceMotion: reduceMotion) { playingSong = false }
                       },
                       stopped: { withMotion(Motion.page, reduceMotion: reduceMotion) { playingSong = false } })
    }

    private func playSong() {
        guard let song else { return }
        Haptics.shared.selection()
        store.audio.prepareBand(song.band(reference: store.settings.referencePitchHz))
        withMotion(Motion.page, reduceMotion: reduceMotion) { playingSong = true }
    }

    /// How it went: the share of the chords that rang true (the whole song's, once it has been played through), three
    /// marks for it, and the whole song, again or back to the song's page.
    private var summary: some View {
        let share = songScore ?? accuracy
        let marks = share >= 0.9 ? 3 : share >= 0.7 ? 2 : 1
        return VStack(spacing: 22) {
            Spacer(minLength: 0)
            ZStack {
                SparkBurst(trigger: round + 1 + (songScore == nil ? 0 : 100), color: accent).frame(width: 260, height: 260)
                Glyph(.chart, size: 72, tint: Palette.mint)
            }
            VStack(spacing: 8) {
                StepTitle(songScore == nil ? Text("Practice done") : Text("Chords & words")).multilineTextAlignment(.center)
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
                if song != nil {
                    // The whole song next: the way a song you sing is played.
                    Button { playSong() } label: { Label("Chords & words", systemImage: "guitars") }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityHint(Text("The whole song, start to finish, with the band."))
                        .accessibilityIdentifier("yoursongs.practice.song")
                    Button { again() } label: { Text("Practice again") }
                        .buttonStyle(SecondaryButtonStyle())
                } else {
                    Button { again() } label: { Text("Practice again") }
                        .buttonStyle(PrimaryButtonStyle())
                }
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
        songScore = nil
        round += 1
        withMotion(Motion.page, reduceMotion: reduceMotion) { index = 0 }
    }
}
