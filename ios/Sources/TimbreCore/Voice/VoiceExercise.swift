import Foundation

public struct VoiceExercise: Codable, Equatable, Sendable {
    public let id: String
    public let level: Int
    public let name: String
    public let rootMidi: Int
    public let toleranceCents: Double
    public let holdMs: Int
    public let durationMs: Int
    public let notes: [Int]
    public let instructions: String

    public init(level: Int, rootMidi: Int = 57) {
        precondition((1...8).contains(level))
        self.level = level
        self.rootMidi = rootMidi
        name = ["Easy warm-up", "Find your note", "Closer to the pitch", "Hold it steady", "Sing a major third", "Short melody", "Explore your range", "Short song"][level - 1]
        let prefix = level <= 4 ? "voice.pitch.v2." : level <= 6 ? "voice.sequence.v3." : level == 7 ? "voice.range.v1." : "voice.song.v1."
        id = prefix + String(level)
        holdMs = [1000, 1500, 2000, 2500, 800, 600, 500, 600][level - 1]
        toleranceCents = [50, 50, 35, 30, 40, 50, 75, 50][level - 1]
        switch level {
        case 5: notes = [rootMidi, rootMidi + (rootMidi <= 77 ? 4 : -4)]
        case 6: notes = [rootMidi, rootMidi + (rootMidi <= 77 ? 2 : -2), rootMidi + (rootMidi <= 77 ? 4 : -4)]
        case 7: notes = (0...4).map { rootMidi - $0 * 2 } + (1...8).map { rootMidi - 8 + $0 * 2 }.filter { $0 <= 85 }
        case 8: notes = [0, 0, 1, 3, 3, 1, 0, -2].map { rootMidi + $0 }
        default: notes = [rootMidi]
        }
        durationMs = level == 7 ? notes.count * 2000 : level == 8 ? 12000 : 6000
        switch level {
        case 1: instructions = "Sing the target gently. This warm-up is not scored."
        case 5: instructions = "Sing two notes a major third apart."
        case 6: instructions = "Sing the three-note melody, following each note in turn."
        case 7: instructions = "Follow the notes down and up. Skip any pitch that feels strained; this walk is not scored."
        case 8: instructions = "Sing the eight-note song phrase, following each note in turn."
        default: instructions = "Match the target and hold it for \(Double(holdMs) / 1000) seconds. Aim for ±\(Int(toleranceCents)) cents."
        }
    }
    public func noteIndex(at milliseconds: Int) -> Int {
        min(max(milliseconds, 0), durationMs - 1) * notes.count / durationMs
    }
    public func note(at milliseconds: Int) -> Int { notes[noteIndex(at: milliseconds)] }
}

public struct VoiceResult: Codable, Equatable, Sendable {
    public let accuracy: Int?
    public let stability: Int?
    public let longestHoldMs: Int
    public let demonstrated: Bool
    public let explanation: String
    public let lowestMidi: Int?
    public let highestMidi: Int?
    public let readingCount: Int
    public let stableReadingCount: Int
    public let meanAbsoluteCentsError: Double?
    public let toleranceCents: Double
    public let stageHoldMs: [Int]
    public let stageInBandMs: [Int]
    public let contourPercent: Int?
    public let inBandPercent: Int?
}

/// Pure measurements; nil scores mean the capture did not support a measurement.
public final class VoiceAttempt {
    public let exercise: VoiceExercise
    private let referenceHz: Double
    private var samples: [(Int, Double)] = []
    private var readings: [[(Int, Double)]]
    private var stageVoiced: [Int]
    private var stageInBand: [Int]
    private var previousMs: Int?
    private var previousStage: Int?
    private var previousInBand = false
    private var voicedRun = 0
    private var holdRun = 0
    private var longestVoiced = 0
    public private(set) var liveHoldMs = 0
    private var longestHold = 0
    private var stableErrors: [Double] = []
    private var lowest: Int?
    private var highest: Int?

    public init(exercise: VoiceExercise, referenceHz: Double = 440) {
        precondition(referenceHz.isFinite && referenceHz > 0)
        self.exercise = exercise
        self.referenceHz = referenceHz
        readings = Array(repeating: [], count: exercise.notes.count)
        stageVoiced = Array(repeating: 0, count: exercise.notes.count)
        stageInBand = stageVoiced
    }
    private func target(_ stage: Int) -> Double {
        referenceHz * pow(2, Double(exercise.notes[stage] - 69) / 12)
    }
    private func cents(_ target: Double, _ frequency: Double) -> Double { 1200 * log2(frequency / target) }
    private func median(_ values: [Double]) -> Double {
        let sorted = values.sorted(), middle = values.count / 2
        return values.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }
    public func accept(frequency: Double?, stable: Bool, elapsedMs: Int) {
        guard let frequency, frequency.isFinite, frequency > 0 else {
            previousMs = nil; previousStage = nil; previousInBand = false
            voicedRun = 0; holdRun = 0; liveHoldMs = 0
            return
        }
        let stage = exercise.noteIndex(at: elapsedMs)
        let error = cents(target(stage), frequency)
        guard error.isFinite else { return }
        let gap = previousMs.map { elapsedMs - $0 } ?? 0
        let continuous = (1...150).contains(gap) && previousStage == stage
        let inBand = stable && abs(error) <= exercise.toleranceCents + 0.000001
        voicedRun = continuous && stable ? voicedRun + gap : 0
        holdRun = continuous && inBand && previousInBand ? holdRun + gap : 0
        liveHoldMs = holdRun
        longestVoiced = max(longestVoiced, voicedRun)
        longestHold = max(longestHold, holdRun)
        stageVoiced[stage] = max(stageVoiced[stage], voicedRun)
        stageInBand[stage] = max(stageInBand[stage], holdRun)
        previousMs = elapsedMs; previousStage = stage; previousInBand = inBand
        samples.append((elapsedMs, error))
        if stable { readings[stage].append((elapsedMs, frequency)); stableErrors.append(abs(error)) }
        let midiFloat = 69 + 12 * log2(frequency / referenceHz)
        // Avoid trapping on hostile finite frequencies beyond Int's representable range.
        if midiFloat.isFinite && midiFloat > Double(Int.min) && midiFloat < Double(Int.max) {
            let midi = Int(midiFloat.rounded())
            lowest = min(lowest ?? midi, midi); highest = max(highest ?? midi, midi)
        }
    }
    public func finish() -> VoiceResult {
        let multiple = exercise.notes.count > 1
        let measuredHold = multiple ? (stageVoiced.min() ?? 0) : longestHold
        var low = lowest, high = highest
        var errors = samples.map { $0.1 }
        var contour: Int?
        var eligible = samples.count >= 10 && longestVoiced >= exercise.holdMs
        if multiple {
            eligible = readings.indices.allSatisfy { readings[$0].count >= 10 && stageVoiced[$0] >= exercise.holdMs }
            if eligible && exercise.level == 5 {
                let start = median(readings[0].map { $0.1 })
                let interval = Double(exercise.notes[1] - exercise.notes[0]) * 100
                errors = readings[1].map { cents(start, $0.1) - interval }
            } else if eligible {
                errors = readings.indices.flatMap { stage in readings[stage].map { cents(target(stage), $0.1) } }
                let sung = readings.map { Int((69 + 12 * log2(median($0.map { $0.1 }) / 440)).rounded()) }
                let matches = (1..<sung.count).filter { index in
                    (sung[index] - sung[index - 1]).signum() == (exercise.notes[index] - exercise.notes[index - 1]).signum()
                }.count
                contour = Int((100 * Double(matches) / Double(sung.count - 1)).rounded())
            }
        }
        if exercise.level == 7 {
            let reliable = readings.indices.filter { stage in
                readings[stage].count >= 10 && stageInBand[stage] >= exercise.holdMs &&
                abs(cents(target(stage), median(readings[stage].map { $0.1 }))) <= exercise.toleranceCents
            }.map { exercise.notes[$0] }
            low = Set(reliable).count >= 2 ? reliable.min() : nil
            high = Set(reliable).count >= 2 ? reliable.max() : nil
        }
        let scored = eligible && exercise.level != 1 && exercise.level != 7
        let mean = errors.isEmpty ? nil : errors.map(abs).reduce(0, +) / Double(errors.count)
        let accuracy = scored ? mean.map { score($0, zeroAt: exercise.toleranceCents * 4) } : nil
        var deviation: Double?
        if scored && exercise.level <= 4 && samples.count >= 8,
           let first = samples.map({ $0.0 }).min(), let last = samples.map({ $0.0 }).max(), last - first >= 300 {
            let average = errors.reduce(0, +) / Double(errors.count)
            deviation = sqrt(errors.map { pow($0 - average, 2) }.reduce(0, +) / Double(errors.count))
        }
        let stability = deviation.map { score($0, zeroAt: exercise.toleranceCents * 2) }
        let demonstrated = (accuracy ?? -1) >= 70 && measuredHold >= exercise.holdMs && (exercise.level != 4 || (stability ?? -1) >= 60)
        var explanation: String
        if exercise.level == 1 { explanation = "This warm-up is not scored." }
        else if exercise.level == 7 { explanation = low == nil ? "Not enough sustained, near-target notes to describe a range." : "Reliable notes from this range walk. This is descriptive, not a clinical voice classification." }
        else if let accuracy, let mean {
            explanation = "You were \(Int(mean.rounded()))¢ from the target on average. The band we asked for was ±\(Int(exercise.toleranceCents))¢. Accuracy: \(accuracy)%."
            if exercise.level == 5 { explanation += " The interval is measured against the note you started on, so it does not depend on your key." }
            if let deviation { explanation += " Pitch variation was \(Int(deviation.rounded()))¢ (standard deviation), a proxy for steady breath support rather than a measurement of breathing." }
        } else { explanation = "Not enough continuous singing was captured to measure this exercise. Try holding each note for the requested time." }
        return VoiceResult(accuracy: accuracy, stability: stability, longestHoldMs: measuredHold, demonstrated: demonstrated,
            explanation: explanation, lowestMidi: low, highestMidi: high, readingCount: samples.count,
            stableReadingCount: stableErrors.count, meanAbsoluteCentsError: exercise.level == 7 ? nil : exercise.level == 5 ? (scored ? mean : nil) : stableErrors.isEmpty ? nil : stableErrors.reduce(0, +) / Double(stableErrors.count),
            toleranceCents: exercise.toleranceCents, stageHoldMs: stageVoiced, stageInBandMs: stageInBand,
            contourPercent: scored && [6, 8].contains(exercise.level) ? contour : nil,
            inBandPercent: scored && [6, 8].contains(exercise.level) ? Int((100 * Double(errors.filter { abs($0) <= exercise.toleranceCents }.count) / Double(errors.count)).rounded()) : nil)
    }
    private func score(_ value: Double, zeroAt: Double) -> Int { Int(min(100, max(0, 100 * (1 - abs(value) / zeroAt))).rounded()) }
}

public struct VocalProgression: Codable, Equatable, Sendable {
    public var selectedLevel: Int = 1
    public private(set) var demonstratedLevels: Set<Int> = []
    public init() {}
    public var suggestedLevel: Int {
        let best = demonstratedLevels.max() ?? 0
        return best == 6 ? 8 : min(best + 1, 8)
    }
    public mutating func select(level: Int) { precondition((1...8).contains(level)); selectedLevel = level }
    public mutating func record(exercise: VoiceExercise, result: VoiceResult) {
        if result.demonstrated && result.longestHoldMs >= exercise.holdMs && result.toleranceCents <= exercise.toleranceCents && exercise.level != 1 && exercise.level != 7 {
            demonstratedLevels.insert(exercise.level)
        }
    }
}
