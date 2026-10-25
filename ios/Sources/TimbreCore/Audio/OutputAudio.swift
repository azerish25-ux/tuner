import Foundation

/// Exact Android low-reference harmonic weights and Schroeder phases, normalized for equal RMS.
public struct ReferenceToneWaveform: Sendable {
    private let omega: Double
    private let weights: [Double]
    private let phases: [Double]
    private let normalization: Double
    public init(frequencyHz: Double, sampleRateHz: Int = 48000) {
        precondition(sampleRateHz > 0 && frequencyHz.isFinite && frequencyHz > 0 && frequencyHz < Double(sampleRateHz) / 2)
        omega = 2.0 * Double.pi * frequencyHz / Double(sampleRateHz)
        let color: Double = min(1.0, max(0.0, (220.0 - frequencyHz) / 110.0))
        var harmonicWeights = [Double](repeating: 0.0, count: 24)
        var squaredWeightSum: Double = 0.0
        var activeCount: Int = 0
        for index in 0..<24 {
            let harmonicHz: Double = Double(index + 1) * frequencyHz
            var weight: Double = 0.0
            if index == 0 {
                weight = 1.0
            } else if harmonicHz <= 850.0 {
                let rolloff: Double = 1.0 - 0.022 * Double(index)
                let audibleFraction: Double = min(1.0, max(0.0, harmonicHz / 300.0))
                let speakerWeight: Double = 0.6 + 0.4 * audibleFraction
                weight = 0.75 * rolloff * color * speakerWeight
            }
            harmonicWeights[index] = weight
            squaredWeightSum += weight * weight
            if weight != 0.0 { activeCount += 1 }
        }
        var harmonicPhases = [Double](repeating: 0.0, count: 24)
        for index in 0..<24 {
            let harmonic: Double = Double(index + 1)
            let previousHarmonic: Double = Double(index)
            harmonicPhases[index] = -Double.pi * harmonic * previousHarmonic / Double(activeCount)
        }
        weights = harmonicWeights
        phases = harmonicPhases
        normalization = sqrt(squaredWeightSum)
    }
    public func sample(frame: Int64) -> Float {
        let phase = omega * Double(frame)
        var value = 0.0
        for index in weights.indices where weights[index] != 0 { value += weights[index] * sin(Double(index + 1) * phase + phases[index]) }
        return Float(value / normalization)
    }
}

/// Sample-clock tone with the Android12ms raised-cosine envelope. No per-sample allocations.
/// Kept for Android parity; the app now sounds tones in the instrument's own voice (`ToneSynth`, `InstrumentVoice`).
public final class ReferenceToneRenderer {
    private let waveform: ReferenceToneWaveform
    private let totalFrames: Int64, fadeFrames: Int64, amplitude: Double
    private var frame: Int64 = 0
    private var stopFrame: Int64?
    public private(set) var isPlaying = true
    public init(frequencyHz: Double, sampleRateHz: Int = 48000, durationMs: Int = 2000, amplitude: Double = 0.20) {
        waveform = ReferenceToneWaveform(frequencyHz: frequencyHz, sampleRateHz: sampleRateHz)
        totalFrames = durationMs > 0 ? Int64(durationMs) * Int64(sampleRateHz) / 1000 : 0
        self.amplitude = min(1, max(0, amplitude))
        // Retain the source one-frame fade for duration-zero continuous playback.
        fadeFrames = max(1, min(Int64(12 * sampleRateHz / 1000), max(1, totalFrames) / 2))
    }
    public func stop() { if stopFrame == nil { stopFrame = frame } }
    public func nextSample() -> Float {
        guard isPlaying else { return 0 }
        if totalFrames > 0 && frame >= totalFrames { isPlaying = false; return 0 }
        var envelope = min(1, Double(frame) / Double(fadeFrames))
        if totalFrames > 0 && frame > totalFrames - fadeFrames { envelope = min(envelope, Double(totalFrames - frame) / Double(fadeFrames)) }
        if let stopFrame {
            if frame - stopFrame >= fadeFrames { isPlaying = false; return 0 }
            envelope = min(envelope, Double(fadeFrames - (frame - stopFrame)) / Double(fadeFrames))
        }
        envelope = 0.5 - 0.5 * cos(.pi * min(1, max(0, envelope)))
        let sample = Float(amplitude * envelope) * waveform.sample(frame: frame)
        frame += 1
        return sample
    }
}

public struct MetronomePattern: Equatable, Sendable {
    /// Every tempo a click plays: the lessons' slowest rungs and bar loops (down to 20) included, so the click never
    /// runs faster than the runway it counts. The Metronome tool offers 30 and up.
    public static let tempoRange = 20...300
    public let bpm: Int, beatsPerBar: Int, subdivision: Int
    public init(bpm: Int = 96, beatsPerBar: Int = 4, subdivision: Int = 1) {
        precondition(Self.tempoRange.contains(bpm) && (1...12).contains(beatsPerBar) && (1...4).contains(subdivision))
        self.bpm = bpm; self.beatsPerBar = beatsPerBar; self.subdivision = subdivision
    }
}
public struct MetronomePulse: Equatable, Sendable {
    public let frame: Int64
    public let beat: Int, subdivision: Int
    public let accent: Bool
}
/// Exact Android sample-clock scheduling and click envelope. `nextSample` allocates nothing.
public final class MetronomeRenderer {
    private let sampleRate: Int, clickLength: Int
    private var pattern: MetronomePattern
    private var frame: Int64 = 0
    private var nextPulse = 0.0
    private var pulseIndex = 0, clickAge = Int.max
    private var clickFrequency = 1000.0, clickAmplitude = 0.18
    public var accents = true
    /// Optional per-beat levels: 0 = silent, 1 = normal, 2 = accent. Overrides `accents`.
    public var beatLevels: [Int]?
    public enum Sound: String, CaseIterable, Sendable { case click, wood, beep }
    public var sound: Sound = .click
    public private(set) var lastPulse: MetronomePulse?
    public init(sampleRate: Int = 48000, initial: MetronomePattern = .init()) {
        precondition(sampleRate >= 40)
        self.sampleRate = sampleRate; clickLength = sampleRate / 40; pattern = initial
    }
    private func interval(_ value: MetronomePattern) -> Double { Double(sampleRate) * 60 / Double(value.bpm) / Double(value.subdivision) }
    public func update(_ value: MetronomePattern) {
        guard value != pattern else { return }
        let remainder = min(1, max(0, (nextPulse - Double(frame)) / interval(pattern)))
        if value.subdivision != pattern.subdivision || value.beatsPerBar != pattern.beatsPerBar { pulseIndex = 0; nextPulse = Double(frame) }
        else { nextPulse = Double(frame) + remainder * interval(value) }
        pattern = value
    }
    public func nextSample() -> Float {
        lastPulse = nil
        if Double(frame) >= nextPulse {
            let sub = pulseIndex % pattern.subdivision, beat = (pulseIndex / pattern.subdivision) % pattern.beatsPerBar
            let levels = beatLevels.flatMap { $0.count == pattern.beatsPerBar ? $0 : nil }
            let level = levels.map { sub == 0 ? $0[beat] : min(1, $0[beat]) } ?? (beat == 0 && sub == 0 && accents ? 2 : 1)
            let accent = level == 2 && sub == 0
            lastPulse = MetronomePulse(frame: frame, beat: beat, subdivision: sub, accent: accent)
            let base: Double = sound == .wood ? 620 : sound == .beep ? 880 : 1100
            clickFrequency = accent ? base * 1.36 : sub == 0 ? base : base * 0.73
            clickAmplitude = level == 0 ? 0 : accent ? 0.28 : sub == 0 ? 0.18 : 0.09
            clickAge = 0; pulseIndex = (pulseIndex + 1) % (pattern.beatsPerBar * pattern.subdivision)
            nextPulse += interval(pattern)
        }
        var value: Float = 0
        if clickAge < clickLength {
            let age = clickAge
            clickAge += 1
            let decay: Double = exp((sound == .beep ? -2.5 : sound == .wood ? -11.0 : -7.0) * Double(age) / Double(clickLength))
            let attack: Double = min(1.0, Double(age) / 12.0)
            let envelope: Double = decay * attack
            let phase: Double = 2.0 * Double.pi * clickFrequency * Double(age) / Double(sampleRate)
            value = Float(sin(phase) * envelope * clickAmplitude)
        }
        frame += 1
        return value
    }
    /// Allocating convenience for deterministic offline tests; audio callbacks use nextSample().
    public func render(_ buffer: inout [Float]) -> [MetronomePulse] {
        var events: [MetronomePulse] = []
        for index in buffer.indices { buffer[index] = nextSample(); if let pulse = lastPulse { events.append(pulse) } }
        return events
    }
}
