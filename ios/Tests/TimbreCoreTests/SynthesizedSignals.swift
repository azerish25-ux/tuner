import Foundation

/// Deterministic 64-bit LCG, so synthesised test audio is identical on every run and platform.
struct TestRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(UInt64(1) << 53)
    }
    mutating func uniform(_ low: Double, _ high: Double) -> Double { low + (high - low) * next() }
}

/// Guitar-like test audio: plucked strings built from harmonic partials with a pluck-position comb
/// (|sin(nπβ)|), a 1/n^(1/brightness) roll-off, faster decay for higher partials, slight
/// inharmonicity on wound strings, a few cents of random detune per string and random phases.
enum Synth {
    static let guitar = [40, 45, 50, 55, 59, 64]

    /// MIDI notes for a shape such as "x32010" (low string first; frets above 9 in brackets).
    static func voicing(_ notation: String, tuning: [Int] = guitar) -> [Int?] {
        var frets: [Int?] = []
        var rest = Array(notation)[...]
        while let character = rest.first {
            rest = rest.dropFirst()
            if character == "x" {
                frets.append(nil)
            } else if character == "(" {
                let digits = rest.prefix(while: { $0 != ")" })
                frets.append(Int(String(digits)))
                rest = rest.dropFirst(digits.count + 1)
            } else {
                frets.append(character.wholeNumberValue)
            }
        }
        return frets.enumerated().map { index, fret in fret.map { tuning[index] + $0 } }
    }

    /// One plucked string starting at `start` seconds, added into `out`.
    static func pluck(_ midi: Int, at start: Double, into out: inout [Double], sampleRate: Double, rng: inout TestRandom,
                      level: Double = 1, brightness: Double = 1, body: Bool = false, tuneCents: Double = 0,
                      decayScale: Double = 1, beatCents: Double = 0) {
        let f0 = 440 * pow(2, (Double(midi) - 69 + (tuneCents + rng.uniform(-4, 4)) / 100) / 12)
        let beta = rng.uniform(0.1, 0.22)
        let stiffness = midi < 52 ? 1e-4 : 3e-5
        let first = max(0, Int(ceil(start * sampleRate)))
        var n = 1
        while true {
            let harmonic = Double(n)
            let frequency = harmonic * f0 * (1 + stiffness * harmonic * harmonic).squareRoot()
            if frequency > 4500 || n > 40 { break }
            var amplitude = level * abs(sin(harmonic * Double.pi * beta)) / pow(harmonic, 1 / brightness)
            // A small guitar body radiates little below ~110 Hz.
            if body { amplitude /= 1 + pow(110 / frequency, 4) }
            let decay = (1.2 + 0.5 * harmonic * frequency / 1000 + 0.3 * harmonic) * decayScale
            let phase = rng.uniform(0, 6.28)
            if first < out.count {
                if beatCents == 0 {
                    addPartial(&out, from: first, start: start, frequency: frequency, amplitude: amplitude, decay: decay, phase: phase, sampleRate: sampleRate)
                } else {
                    // Two slightly detuned components beat like a real string's coupled modes.
                    let ratio = pow(2, beatCents / 1200)
                    addPartial(&out, from: first, start: start, frequency: frequency * ratio, amplitude: amplitude / 2, decay: decay, phase: phase, sampleRate: sampleRate)
                    addPartial(&out, from: first, start: start, frequency: frequency / ratio, amplitude: amplitude / 2, decay: decay, phase: phase + 1, sampleRate: sampleRate)
                }
            }
            n += 1
        }
    }

    /// amplitude · e^(−decay·t) · sin(2πft + phase), t measured from `start`, with a 2 ms attack ramp.
    private static func addPartial(_ out: inout [Double], from first: Int, start: Double, frequency: Double, amplitude: Double,
                                   decay: Double, phase: Double, sampleRate: Double) {
        let t0 = Double(first) / sampleRate - start
        let envelope = amplitude * exp(-decay * t0)
        guard envelope > 1e-12 else { return }
        var re = envelope * cos(2 * Double.pi * frequency * t0 + phase)
        var im = envelope * sin(2 * Double.pi * frequency * t0 + phase)
        let damping = exp(-decay / sampleRate), step = 2 * Double.pi * frequency / sampleRate
        let cr = damping * cos(step), ci = damping * sin(step)
        let audible = Int((log(envelope / 1e-9) / decay * sampleRate).rounded(.up))
        let end = min(out.count, first + max(0, audible))
        let rampEnd = min(end, first + Int(0.002 * sampleRate) + 2)
        var i = first
        while i < end {
            if i < rampEnd {
                out[i] += im * min(1, (Double(i) / sampleRate - start) / 0.002)
            } else {
                out[i] += im
            }
            let nextRe = re * cr - im * ci
            im = re * ci + im * cr
            re = nextRe
            i += 1
        }
    }

    /// Strings sounded one after another, `spread` seconds apart (±40%), each at 70–100% of `level`.
    static func strum(_ midi: [Int?], at start: Double, into out: inout [Double], sampleRate: Double, rng: inout TestRandom,
                      spread: Double = 0.012, up: Bool = false, level: Double = 1, brightness: Double = 1, body: Bool = false, tuneCents: Double = 0) {
        let order = up ? Array(midi.reversed()) : midi
        var k = 0
        for note in order {
            guard let note else { continue }
            let delay = Double(k) * spread * rng.uniform(0.6, 1.4)
            let stringLevel = level * rng.uniform(0.7, 1.0)
            pluck(note, at: start + delay, into: &out, sampleRate: sampleRate, rng: &rng, level: stringLevel, brightness: brightness, body: body, tuneCents: tuneCents)
            k += 1
        }
    }

    /// A strummed chord from t = 0, peak-normalised to `gain`, plus uniform noise of amplitude `noise`.
    static func chord(_ midi: [Int?], sampleRate: Double, duration: Double, seed: UInt64, gain: Double = 0.3, noise: Double = 0.002,
                      brightness: Double = 1, spread: Double = 0.012, up: Bool = false, body: Bool = false, tuneCents: Double = 0) -> [Float] {
        var rng = TestRandom(seed: seed)
        var out = [Double](repeating: 0, count: Int(duration * sampleRate))
        strum(midi, at: 0, into: &out, sampleRate: sampleRate, rng: &rng, spread: spread, up: up, brightness: brightness, body: body, tuneCents: tuneCents)
        let peak = out.map { abs($0) }.max() ?? 0
        let scale = peak > 0 ? gain / peak : 0
        for i in out.indices { out[i] = out[i] * scale + noise * rng.uniform(-1, 1) }
        return out.map { Float($0) }
    }

    static func chord(_ notation: String, sampleRate: Double, duration: Double, seed: UInt64, gain: Double = 0.3, noise: Double = 0.002,
                      brightness: Double = 1, up: Bool = false, body: Bool = false, tuneCents: Double = 0) -> [Float] {
        chord(voicing(notation), sampleRate: sampleRate, duration: duration, seed: seed, gain: gain, noise: noise,
              brightness: brightness, up: up, body: body, tuneCents: tuneCents)
    }

    /// A 40 ms woodblock-like click: a 2.5 kHz ping plus noise, decaying with a 6 ms time constant.
    static func click(at time: Double, amplitude: Double, into out: inout [Double], sampleRate: Double, rng: inout TestRandom) {
        let start = Int((time * sampleRate).rounded())
        for i in 0..<Int(0.04 * sampleRate) {
            let t = Double(i) / sampleRate
            let value = exp(-t / 0.006) * (0.6 * sin(2 * Double.pi * 2500 * t) + 0.4 * rng.uniform(-1, 1))
            if start + i < out.count { out[start + i] += amplitude * value }
        }
    }

    static func addNoise(_ out: inout [Double], level: Double, rng: inout TestRandom) {
        for i in out.indices { out[i] += level * rng.uniform(-1, 1) }
    }

    static func whiteNoise(count: Int, level: Double, seed: UInt64) -> [Float] {
        var rng = TestRandom(seed: seed)
        return (0..<count).map { _ in Float(level * rng.uniform(-1, 1)) }
    }

    static func floats(_ samples: [Double]) -> [Float] { samples.map { Float($0) } }
}
