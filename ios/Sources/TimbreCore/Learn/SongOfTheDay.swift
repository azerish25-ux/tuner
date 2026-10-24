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

/// The few seconds a song's cover plays before the lesson opens: the opening bars of its first play-along (or,
/// without one, of its first note step), at the fastest tempo the lesson reaches, its performance tempo.
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
    /// lesson's fastest play-along tempo (kept within 40…`maxBpm`; 92 without one). Nil for a lesson with no notes.
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
        if let first = alongs.first {
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
}
