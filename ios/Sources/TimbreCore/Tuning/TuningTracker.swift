import Foundation

public enum InTuneRule {
    public static let bandCents = 5.0
    public static let holdMs = 650
    public static func isWithinBand(_ cents: Double) -> Bool { cents.isFinite && abs(cents) <= bandCents }
}

public struct TuningReading: Equatable, Sendable {
    public let frequency: Double?
    public let cents: Double?
    public let stable: Bool
    public let inTune: Bool
    public let status: String
    public let holdProgress: Double
    public init(frequency: Double?, cents: Double?, stable: Bool, inTune: Bool, status: String, holdProgress: Double = 0) {
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
/// A publication gap beyond 150 ms restarts confirmation rather than counting unobserved audio.
public final class TuningTracker {
    private let stability = StabilityTracker()
    private var bandEntryMs: Int?
    private var previousTarget: Double?
    private var previousTimestampMs: Int?
    public var confidenceThreshold: Double
    public init(confidenceThreshold: Double = 0.75) { self.confidenceThreshold = confidenceThreshold }
    public func reset() {
        stability.reset(); bandEntryMs = nil; previousTarget = nil; previousTimestampMs = nil
    }
    public func accept(frequency: Double?, confidence: Double, target: Double, timestampMs: Int) -> TuningReading {
        if previousTarget != target || previousTimestampMs.map({ timestampMs < $0 || timestampMs - $0 > 150 }) == true {
            stability.reset(); bandEntryMs = nil
        }
        previousTarget = target; previousTimestampMs = timestampMs
        guard let frequency = frequency, frequency.isFinite, frequency > 0 else {
            stability.reset(); bandEntryMs = nil
            return TuningReading(frequency: nil, cents: nil, stable: false, inTune: false, status: "noSignal")
        }
        guard confidence.isFinite, confidence >= confidenceThreshold, target.isFinite, target > 0 else {
            stability.reset(); bandEntryMs = nil
            return TuningReading(frequency: nil, cents: nil, stable: false, inTune: false, status: "uncertain")
        }
        let stable = stability.update(frequency)
        let cents = 1200 * log2(frequency / target)
        guard cents.isFinite else {
            stability.reset(); bandEntryMs = nil
            return TuningReading(frequency: nil, cents: nil, stable: false, inTune: false, status: "uncertain")
        }
        if !InTuneRule.isWithinBand(cents) {
            bandEntryMs = nil
            return TuningReading(frequency: frequency, cents: cents, stable: stable, inTune: false, status: cents > 0 ? "sharp" : "flat")
        }
        if bandEntryMs == nil { bandEntryMs = timestampMs }
        let elapsed = timestampMs - (bandEntryMs ?? timestampMs)
        let confirmed = elapsed >= InTuneRule.holdMs
        return TuningReading(frequency: frequency, cents: cents, stable: stable, inTune: confirmed, status: confirmed ? "inTune" : "settling", holdProgress: min(1, max(0, Double(elapsed) / Double(InTuneRule.holdMs))))
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

