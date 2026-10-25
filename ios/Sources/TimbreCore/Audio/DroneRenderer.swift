import Foundation

/// Sustained reference for intonation practice. `.tanpura` cycles plucked Pa–Sa'–Sa'–Sa
/// strings with a bright, slowly shimmering overtone envelope; `.pure` is a steady
/// organ-like tone with a fifth. Sample-clock driven; `nextSample` allocates nothing.
public final class DroneRenderer {
    public enum Voice: String, CaseIterable, Sendable { case tanpura, pure }
    private struct StringVoice {
        var frequency: Double
        var phase = 0.0
        var age = Int.max
        var gain: Double
    }
    private let sampleRate: Double
    private let voice: Voice
    private var strings: [StringVoice]
    private let harmonicWeights: [Double]
    private var frame: Int64 = 0
    private var cycleIndex = 0
    private let pluckInterval: Int64
    private var nextPluck: Int64 = 0
    private var fade = 0.0
    private var stopping = false
    public private(set) var isPlaying = true
    public var level: Double = 0.22

    /// - Parameter tonic: Sa frequency in Hz (any octave).
    public init(tonic: Double, fifth: Bool = true, voice: Voice = .tanpura, sampleRate: Int = 48000) {
        precondition(tonic.isFinite && tonic > 0)
        self.sampleRate = Double(sampleRate)
        self.voice = voice
        let pa = tonic * 1.5 / 2   // Pa below upper Sa
        let upper = tonic
        let low = tonic / 2
        strings = [
            StringVoice(frequency: fifth ? pa : tonic * 4 / 3 / 2, gain: 0.8),
            StringVoice(frequency: upper, gain: 0.9),
            StringVoice(frequency: upper * 1.0004, gain: 0.85),
            StringVoice(frequency: low, gain: 1.0),
        ]
        harmonicWeights = voice == .tanpura ? (1...16).map { 1 / pow(Double($0), 0.85) } : [1, 0.5, 0.33, 0.12, 0.08, 0.04]
        pluckInterval = Int64(self.sampleRate * 1.05)
        if voice == .pure { for index in strings.indices { strings[index].age = 0 } }
    }

    public func stop() { stopping = true }

    public func nextSample() -> Float {
        guard isPlaying else { return 0 }
        if voice == .tanpura && frame >= nextPluck {
            strings[cycleIndex].age = 0
            strings[cycleIndex].phase = 0
            cycleIndex = (cycleIndex + 1) % strings.count
            nextPluck = frame + (cycleIndex == 0 ? pluckInterval * 2 : pluckInterval)
        }
        fade = stopping ? max(0, fade - 1 / (sampleRate * 0.25)) : min(1, fade + 1 / (sampleRate * 0.4))
        if stopping && fade == 0 { isPlaying = false; return 0 }
        var value = 0.0
        let t = Double(frame) / sampleRate
        for index in strings.indices {
            var string = strings[index]
            let envelope: Double
            if voice == .tanpura {
                guard string.age != Int.max else { continue }
                let seconds = Double(string.age) / sampleRate
                envelope = min(1, seconds / 0.008) * exp(-seconds / 3.2)
                string.age = seconds > 12 ? Int.max : string.age + 1
            } else {
                envelope = index == 2 ? 0 : 0.6
            }
            string.phase += 2 * Double.pi * string.frequency / sampleRate
            if string.phase > 2 * Double.pi { string.phase -= 2 * Double.pi }
            // Jawari: upper partials swell and fade slowly after each pluck.
            let shimmer = voice == .tanpura ? 0.5 + 0.5 * sin(2 * Double.pi * 0.31 * t + Double(index)) : 1
            var partials = 0.0
            for (h, weight) in harmonicWeights.enumerated() {
                let n = Double(h + 1)
                let brightness = h < 3 ? 1 : shimmer * (voice == .tanpura ? min(1, Double(string.age == Int.max ? 0 : string.age) / (sampleRate * 0.6)) : 1)
                partials += weight * brightness * sin(n * string.phase)
            }
            value += string.gain * envelope * partials
            strings[index] = string
        }
        frame += 1
        return Float(value * level * fade * 0.18)
    }
}
