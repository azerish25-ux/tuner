import Foundation

// MARK: - A take, as the coach reads it

/// One moment of a take: what the player was asked to play, where it sits (beats from the start), and how far
/// off it landed.
public struct CoachHit: Equatable, Sendable {
    public let item: PracticeItem
    public let beat: Double
    /// Seconds late (positive) or early (negative); nil when it was never heard.
    public let offset: Double?
    public init(item: PracticeItem, beat: Double, offset: Double?) {
        self.item = item; self.beat = beat; self.offset = offset
    }
}

/// The timing of one finished take of a play-along (notes) or a strummed step (chords), in time order.
public struct CoachTake: Equatable, Sendable {
    public enum Kind: String, Sendable { case melody, chords }
    public let kind: Kind
    public let hits: [CoachHit]
    /// The tempo the take was played at.
    public let bpm: Double
    public let beatsPerBar: Int
    public let date: Date

    public init(kind: Kind, hits: [CoachHit], bpm: Double, beatsPerBar: Int, date: Date = Date()) {
        self.kind = kind
        self.hits = hits.sorted { $0.beat < $1.beat }
        self.bpm = bpm
        self.beatsPerBar = max(1, beatsPerBar)
        self.date = date
    }

    /// A play-along take from its judge: every note judged so far, with its timing (a miss has none).
    /// - Parameter item: the note as a practice item (the course knows where on the neck it is played).
    public init(judge: PlayAlongJudge, beatsPerBar: Int, date: Date = Date(), item: (TimedNote) -> PracticeItem) {
        let hits = judge.judgments.compactMap { judgment -> CoachHit? in
            guard judge.notes.indices.contains(judgment.index) else { return nil }
            let note = judge.notes[judgment.index]
            return CoachHit(item: item(note), beat: note.beat, offset: judgment.offset)
        }
        self.init(kind: .melody, hits: hits, bpm: 60 / max(0.001, judge.secondsPerBeat), beatsPerBar: beatsPerBar, date: date)
    }

    /// A strummed take: the strokes of `pattern` in every bar, each chord held for its number of bars.
    /// - Parameters:
    ///   - offsets: per stroke, how far off a judged stroke was. Strokes count bar by bar, in the pattern's own
    ///     order (as the rhythm step lays out its beats).
    ///   - strays: per missed stroke, the nearest stroke heard outside its window (a change played far too late).
    /// - Returns: nil without chords or strokes.
    public static func strummed(chords: [ChordSpec], bars: [Int], pattern: [Double], beatsPerBar: Int, bpm: Double,
                                offsets: [Int: Double], strays: [Int: Double] = [:], date: Date = Date()) -> CoachTake? {
        let positions = pattern
        guard !chords.isEmpty, !positions.isEmpty, positions.allSatisfy(\.isFinite), bpm > 0 else { return nil }
        // Which chord sounds in each bar.
        var barChords: [ChordSpec] = []
        for (index, chord) in chords.enumerated() {
            let length = index < bars.count ? max(1, bars[index]) : 1
            barChords += Array(repeating: chord, count: length)
        }
        let perBar = max(1, beatsPerBar)
        var hits: [CoachHit] = []
        for (bar, chord) in barChords.enumerated() {
            for (k, position) in positions.enumerated() {
                let stroke = bar * positions.count + k
                hits.append(CoachHit(item: .chord(chord), beat: Double(bar * perBar) + position, offset: offsets[stroke] ?? strays[stroke]))
            }
        }
        return CoachTake(kind: .chords, hits: hits, bpm: bpm, beatsPerBar: perBar, date: date)
    }
}

// MARK: - What the timing says

extension Coach {
    /// A change between two chords (or two notes) that kept landing off the beat.
    public struct Change: Equatable, Sendable {
        public let from: PracticeItem
        public let to: PracticeItem
        /// Mean seconds late (positive) or early of the changes that were heard; nil when none was.
        public let meanOffset: Double?
        public let missed: Int
        public let count: Int
        /// The beat of the bar (1-based) the change lands on, where it first came up.
        public let beat: Int
        /// The tempo of the take it came up in.
        public let bpm: Double
        /// How far off it typically was: the distance from the beat, a change never heard counting as `missCost`.
        public let cost: Double
    }

    /// The change that cost the most time, when it stands out: on average at least `lateChange` off the beat and
    /// `standOut` worse than the strokes (or notes) that stay put. In a melody, where every note is a change, it
    /// must come up twice or be clearly off (a single slip is noise).
    public static func worstChange(in takes: [CoachTake]) -> Change? {
        struct Tally {
            let from: PracticeItem
            let to: PracticeItem
            var landed: [Double] = []
            var missed = 0
            let beat: Int
            let bpm: Double
            let order: Int
            let melody: Bool
            var count: Int { landed.count + missed }
            var cost: Double { (landed.map { abs($0) }.reduce(0, +) + Double(missed) * Coach.missCost) / Double(max(1, count)) }
        }
        var tallies: [String: Tally] = [:]
        var steady: [Double] = []
        var all: [Double] = []
        var order = 0
        for take in takes {
            for (i, hit) in take.hits.enumerated() {
                let cost = hit.offset.map { abs($0) } ?? missCost
                all.append(cost)
                guard i > 0, take.hits[i - 1].item != hit.item else { steady.append(cost); continue }
                let from = take.hits[i - 1].item
                let key = from.key + ">" + hit.item.key
                if tallies[key] == nil {
                    tallies[key] = Tally(from: from, to: hit.item, beat: beatInBar(hit.beat, take.beatsPerBar), bpm: take.bpm,
                                         order: order, melody: take.kind == .melody)
                    order += 1
                }
                if let offset = hit.offset { tallies[key]?.landed.append(offset) } else { tallies[key]?.missed += 1 }
            }
        }
        // What staying put costs: the strokes that don't change, else every hit.
        let base = steady.count >= 3 ? steady : all
        let baseline = base.isEmpty ? 0 : base.reduce(0, +) / Double(base.count)
        let candidates = tallies.values.filter { tally in
            tally.cost >= lateChange && tally.cost - baseline >= standOut && (!tally.melody || tally.count >= 2 || tally.cost >= 0.2)
        }
        guard let worst = candidates.max(by: { $0.cost != $1.cost ? $0.cost < $1.cost : $0.order > $1.order }) else { return nil }
        let mean = worst.landed.isEmpty ? nil : worst.landed.reduce(0, +) / Double(worst.landed.count)
        return Change(from: worst.from, to: worst.to, meanOffset: mean, missed: worst.missed, count: worst.count,
                      beat: worst.beat, bpm: worst.bpm, cost: worst.cost)
    }

    /// The takes sat behind (positive) or ahead of the click: the mean offset of at least six heard notes, at least
    /// `leanSeconds` either way. A lean with almost no spread is left alone: a steady delay is the audio route
    /// (Bluetooth headphones), which the play-along's calibration fixes, not the player.
    public static func lean(in takes: [CoachTake]) -> (offset: Double, notes: Int, bpm: Double)? {
        let landed = takes.flatMap { $0.hits.compactMap(\.offset) }
        guard landed.count >= 6, let bpm = takes.last?.bpm else { return nil }
        let mean = landed.reduce(0, +) / Double(landed.count)
        guard abs(mean) >= leanSeconds else { return nil }
        let variance = landed.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(landed.count)
        guard variance.squareRoot() >= steadySpread else { return nil }
        return (mean, landed.count, bpm)
    }

    /// The beat of the bar a position falls on, 1-based ("and" of 2 is 2).
    static func beatInBar(_ beat: Double, _ beatsPerBar: Int) -> Int {
        let bar = Double(max(1, beatsPerBar))
        let within = beat - (beat / bar).rounded(.down) * bar
        return min(max(1, beatsPerBar), Int(within.rounded(.down)) + 1)
    }

    /// The slower tempo to practise a change at: a rung down the play-along's ladder (75 %), on a multiple of 5,
    /// never below 40 BPM (nor above the take's own tempo).
    public static func loopTempo(_ bpm: Double) -> Int {
        guard bpm.isFinite, bpm > 0 else { return 40 }
        let slower = (bpm * TempoLadder.rungs[0] / 5).rounded() * 5
        return Int(max(40, min(bpm.rounded(), slower)))
    }

    /// Whole milliseconds to the nearest 10 (a coach says "410 ms", not "413 ms").
    static func milliseconds(_ seconds: Double) -> Int { Int((seconds * 100).rounded()) * 10 }
}
