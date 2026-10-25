import Foundation

public enum InTuneRule {
    /// The default lock band (Beginner); `TuningPrecision` offers tighter ones.
    public static let bandCents = 5.0
    public static let holdMs = 650
    /// Readings further apart than this are a gap: nothing was heard in between, so a hold still building starts again.
    public static let continuityMs = 150
    /// The longest gap a lock already made survives, when the readings either side of it are both inside the band: a
    /// dropped frame or a busy moment says nothing about the string. Anything heard outside the band, a moment with no
    /// pitch, or a longer silence still ends the lock, and a hold that hasn't locked yet never counts a gap.
    public static let lockGapMs = 500
    public static func isWithinBand(_ cents: Double, band: Double = InTuneRule.bandCents) -> Bool { cents.isFinite && abs(cents) <= band }
}

/// What a tuner reading says, from nothing heard to a lock.
public enum TuningStatus: String, Codable, Sendable, CaseIterable {
    /// Nothing heard.
    case noSignal
    /// A sound too unsure to name its pitch.
    case uncertain
    /// Below the lock band: tighten.
    case flat
    /// Above the lock band: loosen.
    case sharp
    /// Inside the lock band, holding toward the lock.
    case settling
    /// Held inside the band long enough: in tune.
    case inTune
}

extension TuningStatus: ExpressibleByStringLiteral {
    /// A status by its name ("inTune"), as readings were written before they had a type: callers that still compare
    /// or build statuses by name keep working while they move to the cases. A name that isn't a status reads as
    /// `uncertain`, the reading that claims nothing.
    public init(stringLiteral value: String) {
        self = TuningStatus(rawValue: value) ?? .uncertain
    }
}

/// How close a string has to hold to lock (Settings › Tuning › Precision).
public enum TuningPrecision: String, CaseIterable, Codable, Sendable {
    case beginner, standard, pro
    /// The lock band in cents either side of the target.
    public var bandCents: Double {
        switch self {
        case .beginner: return InTuneRule.bandCents
        case .standard: return 3
        case .pro: return 1
        }
    }
}

public struct TuningReading: Equatable, Sendable {
    public let frequency: Double?
    public let cents: Double?
    public let stable: Bool
    public let inTune: Bool
    public let status: TuningStatus
    public let holdProgress: Double
    public init(frequency: Double?, cents: Double?, stable: Bool, inTune: Bool, status: TuningStatus, holdProgress: Double = 0) {
        self.frequency = frequency; self.cents = cents; self.stable = stable
        self.inTune = inTune; self.status = status; self.holdProgress = holdProgress
    }
}

public final class StabilityTracker {
    public private(set) var consecutiveFrames = 0
    private var referenceHz: Double?
    private let requiredFrames: Int
    private let toleranceCents: Double
    public init(requiredFrames: Int = 3, toleranceCents: Double = 5) {
        precondition(requiredFrames >= 2 && toleranceCents >= 0)
        self.requiredFrames = requiredFrames; self.toleranceCents = toleranceCents
    }
    public func reset() { referenceHz = nil; consecutiveFrames = 0 }
    public func update(_ frequencyHz: Double?) -> Bool {
        guard let frequency = frequencyHz, frequency.isFinite, frequency > 0 else { reset(); return false }
        guard let reference = referenceHz, abs(1200 * log2(frequency / reference)) <= toleranceCents else {
            referenceHz = frequency; consecutiveFrames = 1; return false
        }
        consecutiveFrames += 1
        referenceHz = reference + (frequency - reference) / Double(consecutiveFrames)
        return consecutiveFrames >= requiredFrames
    }
}

/// Feed every audio-analysis frame. A low-confidence frame cannot carry a number or preserve a hold.
/// Missing frames should be explicitly fed as nil; timestamps use one monotonic time base.
/// A gap beyond `InTuneRule.continuityMs` restarts a hold still building rather than counting unobserved audio. A lock
/// already made survives a gap of up to `InTuneRule.lockGapMs` when the readings either side of it are in the band;
/// the band and the hold themselves never loosen.
public final class TuningTracker {
    private let stability = StabilityTracker()
    private var bandEntryMs: Int?
    private var previousTarget: Double?
    private var previousTimestampMs: Int?
    /// The last reading was a confirmed lock.
    private var locked = false
    public var confidenceThreshold: Double
    /// The lock band in cents (see `TuningPrecision`); a hold starts and continues only inside it.
    public var bandCents: Double
    public init(confidenceThreshold: Double = 0.75, bandCents: Double = InTuneRule.bandCents) {
        self.confidenceThreshold = confidenceThreshold; self.bandCents = bandCents
    }
    private var band: Double { bandCents.isFinite && bandCents > 0 ? bandCents : InTuneRule.bandCents }
    public func reset() {
        stability.reset(); bandEntryMs = nil; previousTarget = nil; previousTimestampMs = nil; locked = false
    }
    public func accept(frequency: Double?, confidence: Double, target: Double, timestampMs: Int) -> TuningReading {
        let gap = previousTimestampMs.map { timestampMs - $0 }
        let reversed = (gap ?? 0) < 0
        let unobserved = (gap ?? 0) > InTuneRule.continuityMs
        // A lock carries over a short gap; whether the string is still in the band is this frame's to say (below).
        let bridged = locked && previousTarget == target && (gap ?? 0) <= InTuneRule.lockGapMs
        if previousTarget != target || reversed || (unobserved && !bridged) {
            stability.reset(); bandEntryMs = nil; locked = false
        }
        previousTarget = target; previousTimestampMs = timestampMs
        guard let frequency = frequency, frequency.isFinite, frequency > 0 else {
            stability.reset(); bandEntryMs = nil; locked = false
            return TuningReading(frequency: nil, cents: nil, stable: false, inTune: false, status: .noSignal)
        }
        guard confidence.isFinite, confidence >= confidenceThreshold, target.isFinite, target > 0 else {
            stability.reset(); bandEntryMs = nil; locked = false
            return TuningReading(frequency: nil, cents: nil, stable: false, inTune: false, status: .uncertain)
        }
        let stable = stability.update(frequency)
        let cents = 1200 * log2(frequency / target)
        guard cents.isFinite else {
            stability.reset(); bandEntryMs = nil; locked = false
            return TuningReading(frequency: nil, cents: nil, stable: false, inTune: false, status: .uncertain)
        }
        if !InTuneRule.isWithinBand(cents, band: band) {
            bandEntryMs = nil; locked = false
            return TuningReading(frequency: frequency, cents: cents, stable: stable, inTune: false, status: cents > 0 ? .sharp : .flat)
        }
        if bandEntryMs == nil { bandEntryMs = timestampMs }
        let elapsed = timestampMs - (bandEntryMs ?? timestampMs)
        let confirmed = elapsed >= InTuneRule.holdMs
        locked = confirmed
        return TuningReading(frequency: frequency, cents: cents, stable: stable, inTune: confirmed, status: confirmed ? .inTune : .settling, holdProgress: min(1, max(0, Double(elapsed) / Double(InTuneRule.holdMs))))
    }
}

public final class ReadingCadence {
    public let targetHz: Double
    public let minIntervalMs: Int
    private var lastPublishedMs: Int?
    public init(targetHz: Double = 20) {
        precondition(targetHz >= 15 && targetHz <= 25)
        self.targetHz = targetHz; minIntervalMs = Int(ceil(1000 / targetHz))
    }
    public func reset() { lastPublishedMs = nil }
    public func shouldPublish(nowMs: Int, force: Bool = false) -> Bool {
        let due = lastPublishedMs.map { nowMs < $0 || nowMs - $0 >= minIntervalMs } ?? true
        guard due || force else { return false }
        lastPublishedMs = nowMs; return true
    }
}

public enum AnalysisWindowPolicy {
    public static let minWindowSamples = 2048
    public static let maxWindowSamples = 4096
    public static let maxTuningWindowSamples = 8192
    public static func clampToBand(_ samples: Int) -> Int { samples <= 3072 ? 2048 : 4096 }
    public static func windowSizeFor(minFrequencyHz: Double, sampleRateHz: Int, override: Int? = nil) -> Int {
        if let override = override { return clampToBand(override) }
        guard minFrequencyHz.isFinite, minFrequencyHz > 0 else { return maxWindowSamples }
        return choose(minFrequencyHz, sampleRateHz, preferred: minWindowSamples, maximum: maxWindowSamples)
    }
    public static func windowSizeForTuningRange(minFrequencyHz: Double, sampleRateHz: Int, preferredWindow: Int? = nil) -> Int {
        guard minFrequencyHz.isFinite, minFrequencyHz > 0 else { return maxTuningWindowSamples }
        return choose(minFrequencyHz, sampleRateHz, preferred: preferredWindow.map(clampToBand) ?? minWindowSamples, maximum: maxTuningWindowSamples)
    }
    public static func windowSizeForInstrument(minFrequencyHz: Double, requiredAnalysisWindowSamples: Int, sampleRateHz: Int, override: Int? = nil) -> Int {
        if let override = override { return clampToBand(override) }
        return max(windowSizeFor(minFrequencyHz: minFrequencyHz, sampleRateHz: sampleRateHz), requiredAnalysisWindowSamples)
    }
    public static func covers(minFrequencyHz: Double, sampleRateHz: Int, windowSize: Int) -> Bool {
        minFrequencyHz.isFinite && minFrequencyHz > 0 && Double(windowSize) * minFrequencyHz >= 2 * Double(sampleRateHz)
    }
    public static func hopSamplesFor(windowSize: Int, requested: Int = 512) -> Int {
        precondition((256...512).contains(requested)); return min(requested, windowSize)
    }
    private static func choose(_ frequency: Double, _ sampleRate: Int, preferred: Int, maximum: Int) -> Int {
        let required = ceil(2 * Double(sampleRate) / frequency)
        var window = minWindowSamples
        while Double(window) < max(required, Double(preferred)) && window < maximum { window *= 2 }
        return window
    }
}

