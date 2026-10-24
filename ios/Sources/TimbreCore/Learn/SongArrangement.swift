import Foundation

/// A song lesson's whole arrangement (`Lesson.arrangement`, curriculum.json, built by tools/curriculum/songbook.py):
/// its tempo and meter, its length in bars, the sections in playing order (intro, verses, choruses, a bridge or solo,
/// the outro) with the bars each covers, the chord over every stretch of bars with the shapes it names, and who wrote
/// the words. The notes themselves, each carrying its lyric syllable, are the lesson's last step (`Lesson.songTake`).
///
/// For the song sheet: `sections` lay out the song map (`Section.name` is the localized label, `bar`/`bars` its
/// span); `practice(_:in:speed:passes:)` gives a section's notes to loop or slow down on the play-along; `chordPerBar`
/// is the lead sheet's chord row; `seconds` the song's real length.
public struct SongArrangement: Codable, Equatable, Sendable {
    /// One part of the song, a whole number of bars. A section sung from an upbeat starts `pickup` beats before
    /// its first bar, inside the section before it.
    public struct Section: Codable, Equatable, Hashable, Sendable, Identifiable {
        public enum Kind: String, Codable, Sendable, CaseIterable {
            case intro, verse, chorus, bridge, solo, interlude, outro

            public init(from decoder: Decoder) throws {
                let raw = try decoder.singleValueContainer().decode(String.self)
                self = Kind(rawValue: raw) ?? .interlude
            }

            /// Sections the words are sung in, as opposed to the band's (intro, solo, interlude, outro).
            public var isSung: Bool { self == .verse || self == .chorus || self == .bridge }
        }

        /// "Verse 2", "Chorus": localized through Learn.strings.
        public let name: LearnText
        public let kind: Kind
        /// First bar, 0-based, and how many bars.
        public let bar: Int
        public let bars: Int
        /// Beats of upbeat before `bar` (0 for most).
        public let pickup: Double

        public var id: Int { bar }
        public var barRange: Range<Int> { bar..<(bar + bars) }

        public init(name: LearnText, kind: Kind, bar: Int, bars: Int, pickup: Double = 0) {
            self.name = name; self.kind = kind; self.bar = bar; self.bars = bars; self.pickup = pickup
        }

        enum CodingKeys: String, CodingKey { case name, kind, bar, bars, pickup }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decode(LearnText.self, forKey: .name)
            kind = try c.decode(Kind.self, forKey: .kind)
            bar = try c.decode(Int.self, forKey: .bar)
            bars = try c.decode(Int.self, forKey: .bars)
            pickup = try c.decodeIfPresent(Double.self, forKey: .pickup) ?? 0
        }
        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name)
            try c.encode(kind, forKey: .kind)
            try c.encode(bar, forKey: .bar)
            try c.encode(bars, forKey: .bars)
            if pickup > 0 { try c.encode(pickup, forKey: .pickup) }
        }
    }

    /// A chord starting at `beat` (0-based, within the bar) of `bar` and lasting until the next change; "N" is no chord.
    public struct ChordChange: Codable, Equatable, Hashable, Sendable {
        public let bar: Int
        public let beat: Double
        public let symbol: String
        public init(bar: Int, beat: Double = 0, symbol: String) { self.bar = bar; self.beat = beat; self.symbol = symbol }
        enum CodingKeys: String, CodingKey { case bar, beat, symbol = "name" }
    }

    /// A section set up to practise on its own: its notes from beat 0 (an upbeat gets a bar of lead-in), repeated
    /// `passes` times, at `bpm`.
    public struct Practice: Equatable, Sendable {
        public let section: Section
        public let notes: [TimedNote]
        public let bpm: Double
        public let beatsPerBar: Int
        public let passes: Int
    }

    public let bpm: Double
    public let beatsPerBar: Int
    public let bars: Int
    public let sections: [Section]
    public let changes: [ChordChange]
    /// The shape of every chord the chart names, once each, in the order they first come.
    public let shapes: [ChordSpec]
    /// Who wrote the words ("Jane Taylor (1806)"); nil for a piece without words.
    public let words: LearnText?

    enum CodingKeys: String, CodingKey { case bpm, beatsPerBar, bars, sections, changes = "chords", shapes, words }

    public init(bpm: Double, beatsPerBar: Int, bars: Int, sections: [Section], changes: [ChordChange] = [], shapes: [ChordSpec] = [],
                words: LearnText? = nil) {
        self.bpm = bpm; self.beatsPerBar = beatsPerBar; self.bars = bars; self.sections = sections
        self.changes = changes; self.shapes = shapes; self.words = words
    }

    // MARK: Time

    private var meter: Double { Double(max(1, beatsPerBar)) }
    /// The song's length in beats, every bar counted.
    public var beats: Double { Double(bars) * meter }
    /// The song's length in seconds at `bpm` (its own tempo when nil).
    public func seconds(atBpm tempo: Double? = nil) -> Double { beats * 60 / max(1, tempo ?? bpm) }
    /// The song's length in seconds at its own tempo.
    public var seconds: Double { seconds() }

    /// The section holding `bar` (nil past the end).
    public func section(containingBar bar: Int) -> Section? { sections.first { $0.barRange.contains(bar) } }

    /// The section sounding at `beat` of the song (an upbeat already belongs to the section it leads into).
    public func section(atBeat beat: Double) -> Section? {
        sections.last { startBeat(of: $0) <= beat + 1e-6 } ?? sections.first
    }

    /// Where `section` starts, in beats from the top of the song, its upbeat included.
    public func startBeat(of section: Section) -> Double { max(0, Double(section.bar) * meter - section.pickup) }

    /// Where `section` ends: where the next one starts (its upbeat included), or the end of the song.
    public func endBeat(of section: Section) -> Double {
        guard let index = sections.firstIndex(of: section), index + 1 < sections.count else { return beats }
        return startBeat(of: sections[index + 1])
    }

    // MARK: Practice

    /// The notes of `section` in the whole take `take` (the lesson's last step, `Lesson.songTake`), from beat 0, with
    /// their words: a section with an upbeat gets a bar of lead-in so its bars still start on the downbeat. With more
    /// than one pass the section repeats back to back, each pass making room for the next one's upbeat.
    public func notes(of section: Section, in take: [TimedNote], passes: Int = 1) -> [TimedNote] {
        let from = startBeat(of: section)
        let to = endBeat(of: section)
        let lead = section.pickup > 0 ? meter : 0
        let shift = Double(section.bar) * meter - lead
        let length = Double(section.bars) * meter
        let inside = take.sorted { $0.beat < $1.beat }.filter { $0.beat >= from - 1e-6 && $0.beat < to - 1e-6 }
        guard !inside.isEmpty else { return [] }
        let count = max(1, passes)
        var out: [TimedNote] = []
        for pass in 0..<count {
            let offset = Double(pass) * length - shift
            // Where the next pass's upbeat starts: this pass gives way there.
            let cutoff = pass + 1 < count ? Double(pass + 1) * length + lead - section.pickup : Double.infinity
            for note in inside {
                let beat = note.beat + offset
                guard beat < cutoff - 1e-6 else { continue }
                let beats = min(note.beats, cutoff - beat, to - note.beat)
                out.append(TimedNote(midi: note.midi, beat: beat, beats: max(0.05, beats), at: note.at,
                                     lyric: note.lyric, startsLine: note.startsLine || note.beat == inside.first?.beat))
            }
        }
        return out
    }

    /// `section` of the take set up to practise: at `speed` of the song's tempo (0.75 by default, kept within the
    /// click's range), `passes` times through.
    public func practice(_ section: Section, in take: [TimedNote], speed: Double = 0.75, passes: Int = 2) -> Practice {
        let range = MetronomePattern.tempoRange
        let tempo = min(Double(range.upperBound), max(Double(range.lowerBound), (bpm * speed).rounded()))
        return Practice(section: section, notes: notes(of: section, in: take, passes: passes), bpm: tempo, beatsPerBar: beatsPerBar,
                        passes: max(1, passes))
    }

    // MARK: Chords

    /// The shape for a chord symbol of the chart.
    public func shape(named symbol: String) -> ChordSpec? { shapes.first { $0.symbol == symbol } }

    /// The chord sounding at `beat` of `bar` (nil before the first change, or under "N").
    public func chord(atBar bar: Int, beat: Double = 0) -> ChordSpec? {
        let at = Double(bar) * meter + beat
        let change = changes.last { Double($0.bar) * meter + $0.beat <= at + 1e-6 }
        return change.flatMap { shape(named: $0.symbol) }
    }

    /// The chord on each bar's downbeat, bar by bar: the lead sheet's chord row.
    public var chordPerBar: [ChordSpec?] { (0..<max(0, bars)).map { chord(atBar: $0) } }

    /// The changes inside `bar` (a bar can hold two chords).
    public func changes(inBar bar: Int) -> [ChordChange] { changes.filter { $0.bar == bar } }
}

extension Lesson {
    /// A song's whole take, its last step, when the lesson carries an arrangement: the notes with their words, the
    /// tempo and the meter.
    public var songTake: (notes: [TimedNote], bpm: Double, beatsPerBar: Int)? {
        guard arrangement != nil, case let .playAlong(notes, bpm, beatsPerBar, _)? = steps.last else { return nil }
        return (notes: notes.sorted { $0.beat < $1.beat }, bpm: bpm, beatsPerBar: beatsPerBar)
    }
}

// MARK: - Lyrics

/// A song's words as karaoke lines, read from its notes' syllables (`TimedNote.lyric`): each line its syllables, each
/// syllable on its note, and the stretch of beats the line is sung over (held notes included). Notes outside the
/// words (an intro, a solo) belong to no line. `cue(atBeat:)` says what to show at a moment of the take.
public struct LyricSheet: Equatable, Sendable {
    public struct Syllable: Equatable, Sendable {
        /// As read, without its joining hyphen ("Twin", "kle,").
        public let text: String
        /// The note it is sung on, as an index into the notes the sheet was read from (in playing order).
        public let note: Int
        public let beat: Double
        /// No space before the next syllable: they make one word.
        public let joinsNext: Bool
    }

    public struct Line: Equatable, Sendable, Identifiable {
        public let id: Int
        public let syllables: [Syllable]
        /// The beat its first syllable is sung on, and the beat its last note (a held one included) ends.
        public let start: Double
        public let end: Double

        /// The line as read: "Twinkle, twinkle, little star,".
        public var text: String { Self.text(of: syllables) }

        /// The syllables joined into words.
        public static func text(of syllables: [Syllable]) -> String {
            var out = ""
            for (index, syllable) in syllables.enumerated() {
                out += syllable.text
                if !syllable.joinsNext && index < syllables.count - 1 { out += " " }
            }
            return out
        }
    }

    /// What to show at a moment: the line being sung (or about to be), the syllable sounding in it, and the line after.
    public struct Cue: Equatable, Sendable {
        /// The line in the light; nil between lines (an intro, a solo).
        public let line: Int?
        /// The syllable of `line` sounding now; nil before its first.
        public let syllable: Int?
        /// The line after it (or the next one coming, between lines).
        public let next: Int?

        public init(line: Int?, syllable: Int?, next: Int?) { self.line = line; self.syllable = syllable; self.next = next }
    }

    public let lines: [Line]
    public var isEmpty: Bool { lines.isEmpty }

    /// The lines of `notes` (sorted by beat, as a play-along plays them).
    public init(notes: [TimedNote]) {
        var lines: [Line] = []
        var syllables: [Syllable] = []
        var start = 0.0, end = 0.0
        func close() {
            if !syllables.isEmpty { lines.append(Line(id: lines.count, syllables: syllables, start: start, end: end)) }
            syllables = []
        }
        for (index, note) in notes.enumerated() {
            guard note.lyric != nil else { close(); continue }
            if note.holdsSyllable {
                if !syllables.isEmpty { end = max(end, note.beat + note.beats) }
                continue
            }
            guard let text = note.syllable else { continue }
            if note.startsLine || syllables.isEmpty {
                close()
                start = note.beat
            }
            syllables.append(Syllable(text: text, note: index, beat: note.beat, joinsNext: note.joinsNextSyllable))
            end = note.beat + note.beats
        }
        close()
        self.lines = lines
    }

    /// What to show at `beat` of the take: a line comes into the light `lead` beats before it is sung and stays until
    /// `hold` beats after its last note, or until the next line arrives; between lines only the next one shows.
    public func cue(atBeat beat: Double, lead: Double = 1, hold: Double = 1) -> Cue {
        guard !lines.isEmpty else { return Cue(line: nil, syllable: nil, next: nil) }
        let upcoming = lines.firstIndex { $0.start - lead > beat } ?? lines.count
        let current = upcoming - 1
        guard current >= 0, beat <= lines[current].end + hold else {
            return Cue(line: nil, syllable: nil, next: upcoming < lines.count ? upcoming : nil)
        }
        let sung = lines[current].syllables.lastIndex { $0.beat <= beat + 1e-6 }
        return Cue(line: current, syllable: sung, next: upcoming < lines.count ? upcoming : nil)
    }
}
