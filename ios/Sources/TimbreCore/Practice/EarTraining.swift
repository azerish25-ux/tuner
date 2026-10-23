import Foundation

/// Deterministic generator so sessions and tests are reproducible.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

public enum EarDrill: String, CaseIterable, Sendable, Codable {
    /// Is the second note higher or lower? The gap shrinks as you get it right.
    case pitchDirection
    case interval
    case chordQuality
}

public struct EarQuestion: Equatable, Sendable {
    public let drill: EarDrill
    /// Frequencies to play, in order; a chord plays its notes together.
    public let tones: [Double]
    public let simultaneous: Bool
    public let choices: [String]
    public let answer: String
    /// pitchDirection only: the detune of the second tone in cents.
    public let cents: Double?
}

public enum Intervals {
    public static let names = ["Unison", "Minor 2nd", "Major 2nd", "Minor 3rd", "Major 3rd", "Perfect 4th", "Tritone", "Perfect 5th", "Minor 6th", "Major 6th", "Minor 7th", "Major 7th", "Octave"]
    public static let short = ["P1", "m2", "M2", "m3", "M3", "P4", "TT", "P5", "m6", "M6", "m7", "M7", "P8"]
}

public enum ChordQuality: String, CaseIterable, Sendable {
    case major = "Major", minor = "Minor", diminished = "Diminished", augmented = "Augmented", dominant7 = "Dominant 7", major7 = "Major 7", minor7 = "Minor 7"
    public var intervals: [Int] {
        switch self {
        case .major: return [0, 4, 7]
        case .minor: return [0, 3, 7]
        case .diminished: return [0, 3, 6]
        case .augmented: return [0, 4, 8]
        case .dominant7: return [0, 4, 7, 10]
        case .major7: return [0, 4, 7, 11]
        case .minor7: return [0, 3, 7, 10]
        }
    }
}

public struct EarSession: Sendable {
    public let drill: EarDrill
    public private(set) var level: Int
    public private(set) var correct = 0
    public private(set) var asked = 0
    public private(set) var streak = 0
    private var rng: SplitMix64
    private let reference: Double

    /// Pitch-direction gaps in cents per level: from obvious to tuner-grade.
    public static let directionGaps: [Double] = [50, 35, 25, 18, 12, 8, 5, 3, 2]

    public init(drill: EarDrill, seed: UInt64 = UInt64(Date().timeIntervalSince1970), level: Int = 0, referenceHz: Double = 440) {
        self.drill = drill; self.level = max(0, level); rng = SplitMix64(seed: seed); reference = referenceHz
    }

    public var accuracy: Int? { asked == 0 ? nil : Int((100 * Double(correct) / Double(asked)).rounded()) }

    public mutating func next() -> EarQuestion {
        let root = Int.random(in: 52...67, using: &rng)
        let reference = reference
        let f = { (midi: Double) in PitchMath.frequency(midi: midi, reference: reference) }
        switch drill {
        case .pitchDirection:
            let gap = Self.directionGaps[min(level, Self.directionGaps.count - 1)]
            let up = Bool.random(using: &rng)
            let cents = up ? gap : -gap
            let base = f(Double(root))
            return EarQuestion(drill: drill, tones: [base, base * PitchMath.ratio(cents: cents)], simultaneous: false,
                               choices: ["Lower", "Higher"], answer: up ? "Higher" : "Lower", cents: cents)
        case .interval:
            let pool = level < 2 ? [0, 4, 7, 12] : level < 4 ? [2, 3, 4, 5, 7, 12] : Array(1...12)
            let semitones = pool.randomElement(using: &rng)!
            var choices = Set([semitones])
            while choices.count < min(4, pool.count) { choices.insert(pool.randomElement(using: &rng)!) }
            return EarQuestion(drill: drill, tones: [f(Double(root)), f(Double(root + semitones))], simultaneous: false,
                               choices: choices.sorted().map { Intervals.names[$0] }, answer: Intervals.names[semitones], cents: nil)
        case .chordQuality:
            let pool: [ChordQuality] = level < 2 ? [.major, .minor] : level < 4 ? [.major, .minor, .diminished, .augmented] : ChordQuality.allCases
            let quality = pool.randomElement(using: &rng)!
            return EarQuestion(drill: drill, tones: quality.intervals.map { f(Double(root + $0)) }, simultaneous: true,
                               choices: pool.map(\.rawValue), answer: quality.rawValue, cents: nil)
        }
    }

    /// Records an answer. Three right in a row levels up; a miss steps back one level.
    @discardableResult
    public mutating func answer(_ choice: String, for question: EarQuestion) -> Bool {
        asked += 1
        let right = choice == question.answer
        if right {
            correct += 1; streak += 1
            if streak >= 3 { level += 1; streak = 0 }
        } else {
            streak = 0; level = max(0, level - 1)
        }
        return right
    }
}
