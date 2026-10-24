import Foundation

/// The Songs tab's featured song, picked from where the learner is rather than at random: a song they haven't
/// played, at their level, and once they are past the beginner units one of the Originals (songs written for
/// Timbre) ahead of the traditional tunes. It stays put for the day and changes the next.
public enum SongOfTheDay {
    /// Where a song stands for the learner.
    public enum Access: Sendable, Equatable {
        /// Plays now.
        case open
        /// Next in its course's order, but it needs Timbre Pro.
        case pro
        /// Comes later in its course (earlier lessons first).
        case locked
    }

    public struct Candidate: Sendable, Equatable {
        public let id: String
        /// From the Originals course rather than a traditional tune.
        public let original: Bool
        /// The song's unit in its course, 0-based: later units are harder.
        public let unit: Int
        public let finished: Bool
        public let access: Access

        public init(id: String, original: Bool, unit: Int, finished: Bool, access: Access) {
            self.id = id; self.original = original; self.unit = unit; self.finished = finished; self.access = access
        }
    }

    /// Past the beginner units: level 3 (300 XP), six finished lessons, or a placement past a course's first unit.
    public static func pastBeginner(level: Int, finishedLessons: Int, placed: Bool) -> Bool {
        placed || level >= 3 || finishedLessons >= 6
    }

    /// The unit the day's song should come from: the first for a beginner, then one further every three levels
    /// (0-based: level 5 is the second unit, level 8 the third).
    public static func targetUnit(level: Int, pastBeginner: Bool) -> Int {
        pastBeginner ? max(0, (level - 2) / 3) : 0
    }

    /// The day's song id, nil when there are no songs. In order: an unfinished song that plays now, then the next
    /// one Pro opens, then one to play again. Past the beginner units an Original leads each of the first two
    /// (an open Original, the next Pro Original, then the other open songs). Among equals, the song nearest the
    /// learner's unit wins, and a hash of `day` (days since an epoch) settles the rest, so the pick holds all day.
    public static func pick(_ songs: [Candidate], level: Int, finishedLessons: Int, placed: Bool = false, day: Int) -> String? {
        let advanced = pastBeginner(level: level, finishedLessons: finishedLessons, placed: placed)
        let target = targetUnit(level: level, pastBeginner: advanced)
        let salt = UInt64(bitPattern: Int64(day))
        let ranked = songs.map { song in
            (id: song.id, rank: Self.rank(song, advanced: advanced), distance: abs(song.unit - target), hash: Self.hash(song.id, salt: salt))
        }
        return ranked.min { a, b in
            if a.rank != b.rank { return a.rank < b.rank }
            if a.distance != b.distance { return a.distance < b.distance }
            return a.hash < b.hash
        }?.id
    }

    /// Lower is better: 0 an unfinished song that plays now, 1 the next one Pro opens, 2 a finished song to play
    /// again, 3 anything else. Past the beginner units, unfinished Originals keep 0 and 1 and the other unfinished
    /// songs move to 2 and 3 (and the rest after them).
    private static func rank(_ song: Candidate, advanced: Bool) -> Int {
        let base: Int
        switch (song.finished, song.access) {
        case (false, .open): base = 0
        case (false, .pro): base = 1
        case (true, .open): base = 2
        default: base = 3
        }
        guard advanced else { return base }
        if base < 2 { return song.original ? base : base + 2 }
        return base + 2
    }

    /// A stable 64-bit hash (FNV-1a with a final mix): `String.hashValue` changes between launches.
    public static func hash(_ text: String, salt: UInt64 = 0) -> UInt64 {
        var value: UInt64 = 0xcbf2_9ce4_8422_2325 ^ salt
        for byte in text.utf8 { value = (value ^ UInt64(byte)) &* 0x0000_0100_0000_01b3 }
        value ^= value >> 33
        value = value &* 0xff51_afd7_ed55_8ccd
        value ^= value >> 33
        return value
    }
}

/// The few seconds a song's cover plays before the lesson opens: for a whole arrangement, the opening bars of the
/// part it is known by (its first verse, or the chorus it starts on; never a long intro, `openingSection`); else the
/// opening bars of its first play-along (or, without one, of its first note step); at the fastest tempo the lesson
/// reaches, its performance tempo. `excerpt` gives a longer stretch from the same place, in whole bars, for a sample
/// over the band.
public enum SongPreview {
    public struct Phrase: Equatable, Sendable {
        /// Notes from beat 0.
        public let notes: [TimedNote]
        public let bpm: Double

        public init(notes: [TimedNote], bpm: Double) { self.notes = notes; self.bpm = bpm }

        public var secondsPerBeat: Double { 60 / bpm }
        /// Seconds from the start to note `index`.
        public func time(of index: Int) -> Double { notes[index].beat * secondsPerBeat }
        /// When the last note ends, in seconds.
        public var duration: Double { notes.last.map { ($0.beat + $0.beats) * secondsPerBeat } ?? 0 }
    }

    /// `bars` bars of the opening (twice that when it holds fewer than five notes), cut at `maxSeconds`, at the
    /// lesson's fastest play-along tempo (kept within 40…`maxBpm`; 92 without one). A whole arrangement opens on its
    /// `openingSection` (an upbeat into it first), not on its intro. Nil for a lesson with no notes.
    public static func opening(of lesson: Lesson, bars: Int = 2, maxSeconds: Double = 8, maxBpm: Double = 132) -> Phrase? {
        var alongs: [(notes: [TimedNote], bpm: Double, beatsPerBar: Int)] = []
        var firstNotes: [TimedNote]?
        for step in lesson.steps {
            switch step {
            case let .playAlong(notes, bpm, beatsPerBar, _):
                if !notes.isEmpty { alongs.append((notes: notes, bpm: bpm, beatsPerBar: beatsPerBar)) }
            case let .playNotes(notes, _):
                if firstNotes == nil, !notes.isEmpty { firstNotes = notes }
            default:
                break
            }
        }
        let fastest = alongs.map { $0.bpm }.filter { $0.isFinite }.max() ?? 92
        let tempo = min(max(40, maxBpm), max(40, fastest))
        let source: [TimedNote]
        let perBar: Int
        if let arrangement = lesson.arrangement, let take = lesson.songTake,
           let section = openingSection(of: arrangement, notes: take.notes) {
            let from = arrangement.startBeat(of: section)
            source = take.notes.filter { $0.beat >= from - 1e-6 }
            perBar = max(1, arrangement.beatsPerBar)
        } else if let first = alongs.first {
            source = first.notes
            perBar = max(1, first.beatsPerBar)
        } else if let notes = firstNotes {
            source = notes
            perBar = 4
        } else {
            return nil
        }
        let sorted = source.sorted { $0.beat < $1.beat }
        guard let start = sorted.first?.beat else { return nil }
        func window(_ count: Int) -> [TimedNote] { sorted.filter { $0.beat - start < Double(max(1, count) * perBar) } }
        var chosen = window(bars)
        if chosen.count < 5 { chosen = window(bars * 2) }
        let secondsPerBeat = 60 / tempo
        let notes = chosen
            .filter { ($0.beat - start) * secondsPerBeat < maxSeconds }
            .map { TimedNote(midi: $0.midi, beat: $0.beat - start, beats: max(0.25, $0.beats), at: $0.at) }
        guard !notes.isEmpty else { return nil }
        return Phrase(notes: notes, bpm: tempo)
    }

    // MARK: Whole arrangements

    /// Where a whole song's previews start: its first sung section (the first verse, or the chorus or bridge it opens
    /// on), else its first part after the intro, else its first section with notes. Sections without a note in
    /// `notes` (the take) are passed over. Nil when no section has notes.
    public static func openingSection(of arrangement: SongArrangement, notes: [TimedNote]) -> SongArrangement.Section? {
        let playing = arrangement.sections.filter { section in
            let from = arrangement.startBeat(of: section)
            let to = arrangement.endBeat(of: section)
            return notes.contains { $0.beat >= from - 1e-6 && $0.beat < to - 1e-6 }
        }
        return playing.first { $0.kind.isSung } ?? playing.first { $0.kind != .intro } ?? playing.first
    }

    /// A stretch of a whole song from its `openingSection`, in whole bars so a band can play under it.
    public struct Excerpt: Equatable, Sendable {
        /// The take's notes from beat 0 of `firstBar`, words kept; nothing from before the section (an intro's notes
        /// in its lead-in bar), and nothing ringing past the last bar.
        public let notes: [TimedNote]
        /// The section it opens on.
        public let section: SongArrangement.Section
        /// The bar it starts at (0-based): the section's first, the bar before when it starts on an upbeat, or the
        /// bar its first note comes in when the section opens on a bar's rest.
        public let firstBar: Int
        public let bars: Int
        public let bpm: Double
        public let beatsPerBar: Int

        public var secondsPerBeat: Double { 60 / max(1, bpm) }
        /// Its whole bars, in seconds.
        public var seconds: Double { Double(bars * max(1, beatsPerBar)) * secondsPerBeat }
        /// Beats of silence before its first note (a lead-in bar's rest before the upbeat).
        public var lead: Double { notes.first?.beat ?? 0 }
    }

    /// `bars` bars of a whole song (as many as fit when nil) from its `openingSection`, at its own tempo, never more
    /// than `maxSeconds` (at least one bar) nor past its end. Nil for a lesson without an arrangement or notes.
    public static func excerpt(of lesson: Lesson, bars: Int? = nil, maxSeconds: Double = 20) -> Excerpt? {
        guard let arrangement = lesson.arrangement, let take = lesson.songTake,
              let section = openingSection(of: arrangement, notes: take.notes) else { return nil }
        let meter = max(1, arrangement.beatsPerBar)
        let tempo = max(1, arrangement.bpm)
        let barSeconds = Double(meter) * 60 / tempo
        let from = arrangement.startBeat(of: section)
        // The bar the section's first note sounds in: the bar before for an upbeat, a later one past a bar's rest.
        let entry = take.notes.first { $0.beat >= from - 1e-6 }?.beat ?? from
        let firstBar = max(0, section.bar - (section.pickup > 0 ? 1 : 0), Int((entry / Double(meter) + 1e-6).rounded(.down)))
        let room = max(1, arrangement.bars - firstBar)
        let fit = max(1, Int((maxSeconds / barSeconds + 1e-9).rounded(.down)))
        let count = max(1, min(room, fit, bars ?? fit))
        let origin = Double(firstBar * meter)
        let end = Double((firstBar + count) * meter)
        let notes = take.notes
            .filter { $0.beat >= from - 1e-6 && $0.beat < end - 1e-6 }
            .map { note in
                TimedNote(midi: note.midi, beat: note.beat - origin, beats: max(0.05, min(note.beats, end - note.beat)),
                          at: note.at, lyric: note.lyric, startsLine: note.startsLine)
            }
        guard !notes.isEmpty else { return nil }
        return Excerpt(notes: notes, section: section, firstBar: firstBar, bars: count, bpm: tempo, beatsPerBar: meter)
    }
}
