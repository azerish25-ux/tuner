import Foundation

/// Pitch Sniper: play or sing the target note and hold it inside the bullseye.
/// Ten rounds; faster bullseyes score more, and consecutive bullseyes build a combo.
public struct PitchSniper: Sendable {
    public struct Round: Equatable, Sendable {
        public let midi: Int
        public let frequency: Double
    }
    public enum Outcome: Equatable, Sendable { case bullseye(points: Int), near(points: Int), miss }
    public enum Event: Equatable, Sendable {
        /// Steady progress toward a hit (0...1 of the hold).
        case holding(Double)
        case finished(Outcome)
    }

    public static let roundSeconds = 8.0
    public static let holdSeconds = 0.6
    public static let bullseyeCents = 5.0
    public static let ringCents = 20.0
    public static let winBullseyes = 6

    public let rounds: [Round]
    public private(set) var index = 0
    public private(set) var score = 0
    public private(set) var combo = 0
    public private(set) var outcomes: [Outcome] = []
    private var roundStart: Double?
    private var holdStart: Double?
    private var bestRing: Double = .infinity

    /// Targets come from the instrument's own notes (open strings, plus the first frets when fretted).
    public init(notes: [Int], fretted: Bool, referenceHz: Double = 440, count: Int = 10, seed: UInt64) {
        var pool = Set(notes)
        if fretted { for n in notes { for fret in 1...4 { pool.insert(n + fret) } } }
        let sorted = pool.sorted()
        var rng = SplitMix64(seed: seed)
        var picks: [Int] = []
        while picks.count < count, !sorted.isEmpty {
            let note = sorted[Int(rng.next() % UInt64(sorted.count))]
            if note != picks.last || sorted.count == 1 { picks.append(note) }
        }
        rounds = picks.map { Round(midi: $0, frequency: referenceHz * pow(2, Double($0 - 69) / 12)) }
    }

    public var current: Round? { index < rounds.count ? rounds[index] : nil }
    public var isOver: Bool { index >= rounds.count }
    public var bullseyes: Int { outcomes.filter { if case .bullseye = $0 { return true } else { return false } }.count }
    public var won: Bool { bullseyes >= Self.winBullseyes }
    public var multiplier: Int { min(5, 1 + combo) }

    /// Seconds left in the current round.
    public func remaining(at time: Double) -> Double {
        guard let roundStart else { return Self.roundSeconds }
        return max(0, Self.roundSeconds - (time - roundStart))
    }

    /// Feed the live reading: cents from the current target (nil when silent).
    public mutating func update(cents: Double?, at time: Double) -> Event? {
        guard !isOver else { return nil }
        if roundStart == nil { roundStart = time }
        let elapsed = time - (roundStart ?? time)
        if let cents, abs(cents) <= Self.bullseyeCents {
            if holdStart == nil { holdStart = time }
            let held = time - (holdStart ?? time)
            if held >= Self.holdSeconds {
                let speed = max(0, 1 - elapsed / Self.roundSeconds)
                let points = (100 + Int(400 * speed)) * multiplier
                combo += 1
                return finish(.bullseye(points: points))
            }
            return .holding(held / Self.holdSeconds)
        }
        holdStart = nil
        if let cents, abs(cents) <= Self.ringCents { bestRing = min(bestRing, abs(cents)) }
        if elapsed >= Self.roundSeconds {
            combo = 0
            return finish(bestRing <= Self.ringCents ? .near(points: 50) : .miss)
        }
        return nil
    }

    /// Give up on the current round (no points, combo resets).
    public mutating func skip() -> Event? {
        guard !isOver else { return nil }
        combo = 0
        return finish(.miss)
    }

    private mutating func finish(_ outcome: Outcome) -> Event {
        switch outcome {
        case .bullseye(let points), .near(let points): score += points
        case .miss: break
        }
        outcomes.append(outcome)
        index += 1
        roundStart = nil; holdStart = nil; bestRing = .infinity
        return .finished(outcome)
    }
}
