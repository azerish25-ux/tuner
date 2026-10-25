import Foundation

/// One play-along take, the part a lesson's play-along step and a song's final take share: the judge, each note's
/// grade with when it was judged and how early or late, the running score with its combo multiplier, the player's
/// pitch trail (pitch lanes), the take's clock with its count-in, the spoken cues' place, and what each reading
/// changed (`Update`) so the host can answer it with haptics, sound and the band. Times are seconds on the host clock
/// (`CACurrentMediaTime` in the app); the take's clock runs from beat 0 after a one-bar count-in.
public struct PlayAlongSession: Sendable {
    /// What one reading or frame changed.
    public struct Update: Equatable, Sendable {
        /// The notes judged, misses whose window just closed included.
        public var judgments: [PlayAlongJudge.Judgment] = []
        /// The multiplier this update stepped up to (2 at four in a row, 3 at eight, 4 at sixteen).
        public var tier: Int?
        /// A run of four or more that this update ended, its length.
        public var brokenRun: Int?
        /// The take ended with this update: every note judged, or its last note long gone.
        public var finished = false

        public init() {}

        public var isEmpty: Bool { judgments.isEmpty && tier == nil && brokenRun == nil && !finished }
    }

    /// The notes in play order.
    public let notes: [TimedNote]
    public let bpm: Double
    public let beatsPerBar: Int
    public let anyOctave: Bool
    /// Pitch lanes draw the player's pitch behind the hit line.
    public let keepsTrail: Bool
    public private(set) var judge: PlayAlongJudge
    public private(set) var grades: [Int: PlayAlongJudge.Grade] = [:]
    /// When each note was judged (host clock), for its burst and its pop.
    public private(set) var hitTimes: [Int: Double] = [:]
    /// Seconds early (negative) or late of each note played, for the "Early" and "Late" pops.
    public private(set) var offsets: [Int: Double] = [:]
    /// Each note's credit times hundred times the multiplier.
    public private(set) var points = 0
    /// When the multiplier last stepped up: the board's new colour rolls up from the hit line.
    public private(set) var tierUp: Double?
    /// The player's pitch as heard (host time, MIDI with cents), the last few seconds of it.
    public private(set) var trail: [(Double, Double)] = []
    /// The tap that started the take, moved toward the first click as it reached the ears.
    public private(set) var startTime: Double = 0
    public private(set) var finished = false
    /// Grace after the last note before an unplayed take ends on its own.
    public static let tail = 1.2
    private var lastLevel = -120.0
    private var lastOnset = -Double.infinity
    /// The next note the spoken cues have yet to name.
    private var cued = 0

    public init(notes: [TimedNote], bpm: Double, beatsPerBar: Int, anyOctave: Bool = false, keepsTrail: Bool = false) {
        let sorted = notes.sorted { $0.beat < $1.beat }
        self.notes = sorted
        self.bpm = bpm
        self.beatsPerBar = max(1, beatsPerBar)
        self.anyOctave = anyOctave
        self.keepsTrail = keepsTrail
        judge = PlayAlongJudge(notes: sorted, bpm: bpm, anyOctave: anyOctave)
    }

    // MARK: The clock

    public var secondsPerBeat: Double { 60 / max(20, bpm) }
    /// One bar of clicks before the first beat.
    public var countIn: Double { Double(beatsPerBar) * secondsPerBeat }
    public var combo: Int { judge.combo }
    public var multiplier: Int { Self.multiplier(judge.combo) }

    /// ×2 from four perfect or good notes in a row, ×3 from eight, ×4 from sixteen.
    public static func multiplier(_ combo: Int) -> Int { combo >= 16 ? 4 : combo >= 8 ? 3 : combo >= 4 ? 2 : 1 }

    /// Seconds since beat 0 at `now` (negative through the count-in).
    public func clock(at now: Double) -> Double { now - startTime - countIn }

    /// The count-in beat sounding at `now` (0 first), nil outside the count-in.
    public func countInBeat(at now: Double) -> Int? {
        let since = now - startTime
        guard since >= 0, since < countIn else { return nil }
        return min(beatsPerBar - 1, Int(since / secondsPerBeat))
    }

    /// How far into the notes the take is, 0 through the count-in, 1 at the end of the last note.
    public func progress(at now: Double) -> Double {
        let duration = judge.duration
        guard duration > 0 else { return 0 }
        return min(1, max(0, clock(at: now) / duration))
    }

    /// Where the runway stands at `now`, in seconds since beat 0: the take's clock, except in its first half second,
    /// when the first notes glide back from where they waited before the start (`waiting`, seconds since beat 0)
    /// to where the count-in puts them. Without `glide` (Reduce Motion) they jump.
    public func runwayClock(at now: Double, waiting: Double, glide: Bool) -> Double {
        let actual = clock(at: now)
        let t = max(0, now - startTime) / 0.5
        guard glide, t < 1 else { return actual }
        let eased = 1 - pow(1 - t, 3)
        return waiting + (actual - waiting) * eased
    }

    // MARK: A take

    /// A fresh take from `now` (the tap): nothing judged, the count-in starting here.
    public mutating func begin(at now: Double) {
        judge = PlayAlongJudge(notes: notes, bpm: bpm, anyOctave: anyOctave)
        grades = [:]; hitTimes = [:]; offsets = [:]; trail = []
        points = 0; tierUp = nil; finished = false
        lastLevel = -120; lastOnset = -.infinity; cued = 0
        startTime = now
    }

    /// The take's start as the first click was heard (the click starts a little after the tap; far more on Bluetooth).
    public mutating func follow(start: Double) { startTime = start }

    /// Moves the take on by `seconds` at once (a take started part-way through, as the store scene's song is).
    public mutating func skip(_ seconds: Double) { startTime -= seconds }

    /// A fresh attack heard at `time` (host clock): a repeated note counts again only after one.
    public mutating func onset(at time: Double) { lastOnset = time }

    /// One pitch reading at `now`: `midi` and `cents` nil while nothing is heard, `level` the input in dBFS. `clock`
    /// is when the reading counts on the take's clock (by default, now).
    public mutating func hear(midi: Int?, cents: Double?, level: Double, at now: Double, clock: Double? = nil) -> Update {
        guard !finished else { return Update() }
        let attacked = (level - lastLevel > 6 && level > -50) || now - lastOnset < 0.12
        lastLevel = level
        if keepsTrail, let midi {
            trail.append((now, Double(midi) + (cents ?? 0) / 100))
            if trail.count > 240 { trail.removeFirst(60) }
        }
        let run = judge.combo
        let judged = judge.update(time: clock ?? self.clock(at: now), midi: midi, cents: cents, onset: attacked)
        return apply(judged, runBefore: run, at: now)
    }

    /// A frame with nothing heard: notes whose window has closed are missed, and the take ends `tail` seconds after
    /// its last note even when nothing more was played.
    public mutating func tick(at now: Double) -> Update {
        guard !finished else { return Update() }
        let run = judge.combo
        let judged = judge.update(time: clock(at: now), midi: nil, cents: nil)
        var update = apply(judged, runBefore: run, at: now)
        if !finished, clock(at: now) > judge.duration + Self.tail {
            finished = true
            update.finished = true
        }
        return update
    }

    private mutating func apply(_ judged: [PlayAlongJudge.Judgment], runBefore: Int, at now: Double) -> Update {
        var update = Update()
        update.judgments = judged
        guard !judged.isEmpty else { return update }
        let level = multiplier
        for judgment in judged {
            grades[judgment.index] = judgment.grade
            hitTimes[judgment.index] = now
            if let offset = judgment.offset { offsets[judgment.index] = offset }
            if judgment.grade != .miss { points += Int((PlayAlongJudge.credit(judgment.grade) * 100).rounded()) * level }
        }
        if let last = judged.last, last.grade == .perfect || last.grade == .good, [4, 8, 16].contains(judge.combo) {
            tierUp = now
            update.tier = level
        }
        if runBefore >= 4, judge.combo == 0 { update.brokenRun = runBefore }
        if judge.isFinished {
            finished = true
            update.finished = true
        }
        return update
    }

    // MARK: Reading the take

    public var accuracy: Double { judge.accuracy }
    public var nextIndex: Int { judge.nextIndex }

    /// Notes played (perfect, good, early or late) of those judged so far.
    public var hits: Int { grades.values.reduce(0) { $0 + ($1 == .miss ? 0 : 1) } }

    public func count(_ grade: PlayAlongJudge.Grade) -> Int { grades.values.reduce(0) { $0 + ($1 == grade ? 1 : 0) } }

    /// The average lean of the notes played, in seconds (negative early); nil before any.
    public var meanOffset: Double? {
        let played = judge.judgments.compactMap(\.offset)
        guard !played.isEmpty else { return nil }
        return played.reduce(0, +) / Double(played.count)
    }

    /// The take's score over the notes starting from beat `from` up to `to` (perfect 1, good 0.8, early or late 0.5,
    /// missed or unplayed 0); nil when no note starts there.
    public func score(fromBeat from: Double, toBeat to: Double) -> Double? {
        let inside = notes.indices.filter { notes[$0].beat >= from - 1e-6 && notes[$0].beat < to - 1e-6 }
        guard !inside.isEmpty else { return nil }
        let credit = inside.reduce(0.0) { $0 + PlayAlongJudge.credit(grades[$1] ?? .miss) }
        return credit / Double(inside.count)
    }

    // MARK: Spoken cues

    /// The note to name now, `lead` seconds before it is due (a beat, for a cue spoken over the music): the latest
    /// one whose cue time has come and that nothing has named yet, so a run too fast to name note by note names the
    /// note coming up rather than falling behind. Each note is named once.
    public mutating func cue(at now: Double, lead: Double) -> Int? {
        guard !finished, cued < notes.count else { return nil }
        let clock = self.clock(at: now)
        var due: Int?
        var index = max(cued, judge.nextIndex)
        while index < notes.count, judge.time(of: index) - lead <= clock {
            due = index
            index += 1
        }
        guard let due else { return nil }
        cued = due + 1
        return due
    }
}
