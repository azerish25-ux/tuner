import Foundation

/// A rhythm step's take judged stroke by stroke: a strum, a progression, or a pattern tapped. Each stroke of the
/// pattern, bar by bar, has a window around its beat; the nearest stroke heard in it scores it by timing (perfect
/// within 50 ms, good within 100, OK within 180), and one heard outside every window is kept as the reason its beat
/// was missed ("240 ms early").
///
/// On a strummed instrument heard through the microphone each stroke's reading follows a moment later
/// (`StrokeChords`), and the take grades what the stroke did as well as when:
/// - A stroke the pattern plays: the chord asked for keeps its timing grade; another chord holds it to OK and is
///   named ("Am?"); no chord at all misses a down stroke and holds an up stroke, which brushes only a few strings, to
///   OK.
/// - A muted stroke (`muted`: a uke chunk, a mandolin chop, a reggae scratch): no chord should ring. It passes when
///   no chord is heard, or when what rings 150 ms later is under 30 % of its attack (a chord read in its first
///   instants, choked right after). A chop left ringing is held to OK and called ("Let it stop"). Muted strokes never
///   count for or against the chords (`chordsMostlyWrong`).
/// - An accented stroke (`accents`) must come in at least `accentDb` above the take's plain strokes (their median);
///   once the take is over, a soft one is held to OK and called, and `accentToPush` names the beat to push.
///
/// The score is perfect 1, good 0.8, OK 0.5 and a miss 0, over every stroke the take asks for.
public struct StrumTake: Sendable {
    public typealias Grade = PlayAlongJudge.Grade

    /// What a stroke did besides its timing, when that cost it.
    public enum Call: Equatable, Sendable {
        /// It rang another chord: its name as the player reads it ("Am").
        case wrongChord(String)
        /// It rang no chord: a tap on the body, or a strum muted where it should ring.
        case noChord
        /// A muted stroke (a chop, a chunk) that kept ringing.
        case ringing
        /// An accented stroke played no harder than the others.
        case softAccent
    }

    /// Timing windows, seconds either side of the beat.
    public static let perfectWindow = 0.05
    public static let goodWindow = 0.1
    public static let window = 0.18
    /// A stroke this far outside every window is still the reason its nearest beat was missed.
    public static let strayWindow = 0.45
    /// A beat with nothing heard is missed this long after it.
    public static let missAfter = 0.2
    /// A stroke's reading is matched to the stroke heard within this many seconds of it.
    public static let readingMatch = 0.05
    /// An accented stroke must be this many dB above the take's plain strokes.
    public static let accentDb = 4.0

    public let pattern: [Double]
    public let beatsPerBar: Int
    public let bars: Int
    public let secondsPerBeat: Double
    /// Seconds from the take's start (its first click) to the first bar: the bar of count-in.
    public let countIn: Double
    /// Positions in `pattern` played muted, and accented.
    public let mutedSlots: Set<Int>
    public let accentSlots: Set<Int>
    /// The chord each bar asks for, nil where none is checked; the last one holds past the end.
    public let barChords: [ChordTarget?]
    /// When each stroke is due, seconds from the take's start, bar by bar in the pattern's order.
    public let expected: [Double]

    public private(set) var grades: [Int: Grade] = [:]
    /// How far off each judged stroke was (negative early).
    public private(set) var offsets: [Int: Double] = [:]
    /// The nearest stroke heard outside a missed beat's window.
    public private(set) var strays: [Int: Double] = [:]
    /// When each judged stroke was heard, on the caller's own clock: its reading is matched by it.
    public private(set) var stamps: [Int: Double] = [:]
    /// Each played (not muted) stroke whose chord was read: true when it rang the chord asked for.
    public private(set) var chordRight: [Int: Bool] = [:]
    /// Each muted stroke read: true when it stopped as a chop should.
    public private(set) var mutedRight: [Int: Bool] = [:]
    /// What cost a stroke beyond its timing.
    public private(set) var calls: [Int: Call] = [:]
    /// Each read stroke's attack, dBFS.
    public private(set) var levels: [Int: Double] = [:]
    public private(set) var isFinished = false

    /// - Parameters:
    ///   - beatsPerBar: the bar's length in beats; nil is 4, or longer when the pattern reaches past beat 4.
    ///   - muted, accents: beats of the pattern (as `pattern` counts them) played muted or accented.
    ///   - chords: the chord each bar asks for (nil: no chord is checked there); the last holds past the end.
    public init(pattern: [Double], beatsPerBar: Int? = nil, bars: Int, bpm: Double, muted: [Double] = [], accents: [Double] = [],
                chords: [ChordTarget?] = []) {
        let perBar = beatsPerBar ?? max(4, Int((pattern.max() ?? 3) + 1))
        let spb = 60 / max(1, bpm)
        self.pattern = pattern
        self.beatsPerBar = perBar
        self.bars = max(0, bars)
        secondsPerBeat = spb
        countIn = Double(perBar) * spb
        mutedSlots = Self.slots(of: muted, in: pattern)
        accentSlots = Self.slots(of: accents, in: pattern)
        barChords = chords
        let lead = Double(perBar) * spb
        expected = (0..<max(0, bars)).flatMap { bar in pattern.map { lead + (Double(bar * perBar) + $0) * spb } }
    }

    /// The positions in `pattern` of `beats` (each within 0.02 of a stroke).
    static func slots(of beats: [Double], in pattern: [Double]) -> Set<Int> {
        Set(pattern.indices.filter { index in beats.contains { abs($0 - pattern[index]) < 0.02 } })
    }

    // MARK: What each stroke asks for

    /// The stroke's place in the pattern.
    public func slot(of index: Int) -> Int { pattern.isEmpty ? 0 : index % pattern.count }
    public func bar(of index: Int) -> Int { pattern.isEmpty ? 0 : index / pattern.count }
    /// A down stroke: on the beat (an up stroke, between beats, brushes only a few strings).
    public func isDown(_ index: Int) -> Bool { pattern.isEmpty ? true : pattern[slot(of: index)].truncatingRemainder(dividingBy: 1) == 0 }
    public func isMuted(_ index: Int) -> Bool { mutedSlots.contains(slot(of: index)) }
    public func isAccented(_ index: Int) -> Bool { accentSlots.contains(slot(of: index)) }

    /// The chord stroke `index` asks for: its bar's.
    public func chord(forStroke index: Int) -> ChordTarget? {
        guard !barChords.isEmpty else { return nil }
        return barChords[min(bar(of: index), barChords.count - 1)]
    }

    /// Whether any stroke's chord is checked.
    public var checksChords: Bool { barChords.contains { $0 != nil } }
    /// Whether the take needs each stroke read (a chord to check, a muted beat or an accent to hear).
    public var readsStrokes: Bool { checksChords || !mutedSlots.isEmpty || !accentSlots.isEmpty }

    // MARK: Hearing the take

    /// A stroke heard `time` seconds after the take's start (`stamp` on the caller's clock, for its reading). Returns
    /// the stroke it scored, nil when it fell outside every window (then it may be the reason a beat is missed).
    @discardableResult
    public mutating func heard(at time: Double, stamp: Double) -> Int? {
        guard !isFinished else { return nil }
        let open = expected.indices.filter { grades[$0] == nil }
        if let index = open.min(by: { abs(expected[$0] - time) < abs(expected[$1] - time) }), abs(expected[index] - time) <= Self.window {
            let offset = abs(expected[index] - time)
            grades[index] = offset <= Self.perfectWindow ? .perfect : offset <= Self.goodWindow ? .good : .ok
            offsets[index] = time - expected[index]
            stamps[index] = stamp
            return index
        }
        // Outside every window: kept as the reason the nearest stroke is missed, unless it's played after all.
        guard let nearest = expected.indices.min(by: { abs(expected[$0] - time) < abs(expected[$1] - time) }),
              grades[nearest] == nil || grades[nearest] == .miss else { return nil }
        let off = time - expected[nearest]
        if abs(off) <= Self.strayWindow, abs(off) < abs(strays[nearest] ?? .infinity) { strays[nearest] = off }
        return nil
    }

    /// The reading of the stroke heard at `stamp` (the caller's clock, as given to `heard`): its chord, attack and
    /// ring. Returns the stroke it graded.
    @discardableResult
    public mutating func read(_ stroke: StrokeChords.Stroke, stamp: Double) -> Int? {
        guard !isFinished,
              let index = stamps.min(by: { abs($0.value - stamp) < abs($1.value - stamp) })?.key,
              let at = stamps[index], abs(at - stamp) <= Self.readingMatch,
              levels[index] == nil, let grade = grades[index] else { return nil }
        levels[index] = stroke.level
        if isMuted(index) {
            // A chop: no chord, or a chord read in its first instants and stopped by 150 ms.
            let stopped = stroke.chord == nil || stroke.stopped == true
            mutedRight[index] = stopped
            if !stopped {
                grades[index] = Self.capped(grade, at: .ok)
                calls[index] = .ringing
            }
            return index
        }
        guard let target = chord(forStroke: index) else { return index }
        if let heard = stroke.chord, heard.matches(target) {
            chordRight[index] = true
            return index
        }
        chordRight[index] = false
        if stroke.chord == nil && isDown(index) {
            grades[index] = .miss
            calls[index] = .noChord
        } else {
            grades[index] = Self.capped(grade, at: .ok)
            calls[index] = stroke.chord.map { Call.wrongChord($0.symbol) } ?? .noChord
        }
        return index
    }

    /// Beats nothing was heard for, `missAfter` past them, are missed by `time` (seconds from the take's start).
    public mutating func expire(at time: Double) {
        guard !isFinished else { return }
        for (index, due) in expected.enumerated() where grades[index] == nil && time > due + Self.missAfter { grades[index] = .miss }
    }

    /// The take is over at `time`: past its last stroke and, when strokes are read, the last one's reading.
    public func isOver(at time: Double, reading: Bool) -> Bool {
        time > (expected.last ?? 0) + (reading ? 0.65 : 0.4)
    }

    /// Ends the take: every stroke not heard is missed, soft accents are called, and the score is in.
    @discardableResult
    public mutating func finish() -> Double {
        guard !isFinished else { return score }
        for index in expected.indices where grades[index] == nil { grades[index] = .miss }
        judgeAccents()
        isFinished = true
        return score
    }

    /// Accented strokes at least `accentDb` above the median of the plain strokes heard; a soft one is held to OK.
    /// Judged only with two plain strokes or more to compare with.
    private mutating func judgeAccents() {
        guard !accentSlots.isEmpty else { return }
        let plain = levels.filter { !isAccented($0.key) && $0.value > -200 }.map { $0.value }.sorted()
        guard plain.count >= 2 else { return }
        let middle = plain.count / 2
        let median = plain.count % 2 == 0 ? (plain[middle - 1] + plain[middle]) / 2 : plain[middle]
        for (index, level) in levels where isAccented(index) {
            guard let grade = grades[index], grade != .miss, calls[index] == nil, level < median + Self.accentDb else { continue }
            grades[index] = Self.capped(grade, at: .ok)
            calls[index] = .softAccent
        }
    }

    // MARK: How it went

    /// 0…1: perfect 1, good 0.8, OK 0.5, a miss 0, over every stroke the take asks for (1 when it asks for none).
    public var score: Double {
        guard !expected.isEmpty else { return 1 }
        return grades.values.reduce(0.0) { $0 + PlayAlongJudge.credit($1) } / Double(expected.count)
    }

    /// Most of the played strokes whose chord was read rang another chord (or none): the lesson keeps one star.
    /// Muted strokes don't count.
    public var chordsMostlyWrong: Bool {
        guard !chordRight.isEmpty else { return false }
        return Double(chordRight.values.filter { $0 }.count) / Double(chordRight.count) < 0.5
    }

    /// The played strokes that rang another chord, or none.
    public var wrongChords: Set<Int> { Set(chordRight.filter { !$0.value }.keys) }

    /// Muted strokes that stopped, of those read.
    public var mutedStopped: (stopped: Int, of: Int) { (mutedRight.values.filter { $0 }.count, mutedRight.count) }

    /// The accented beat (as `pattern` counts it) that most often came in soft, nil when every accent was pushed.
    public var accentToPush: Double? {
        var soft: [Int: Int] = [:]
        for (index, call) in calls where call == .softAccent { soft[slot(of: index), default: 0] += 1 }
        guard let worst = soft.max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }) else { return nil }
        return pattern[worst.key]
    }

    /// `grade`, or `most` when that is lower.
    static func capped(_ grade: Grade, at most: Grade) -> Grade {
        rank(grade) <= rank(most) ? grade : most
    }

    static func rank(_ grade: Grade) -> Int {
        switch grade {
        case .perfect: return 3
        case .good: return 2
        case .ok: return 1
        case .miss: return 0
        }
    }
}
