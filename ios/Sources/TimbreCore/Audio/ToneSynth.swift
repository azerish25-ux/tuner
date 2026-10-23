import Foundation

/// What to sound, in which voice and at which output rate. Equal requests render the same audio, so a
/// rendering can be cached and replayed.
public struct ToneRequest: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// Each note `noteMs` long, `gapMs` apart; `together` sounds them at once (on plucked and struck
        /// voices as a downstroke, low string to high, about 24 ms apart).
        case phrase(together: Bool, noteMs: Int, gapMs: Int)
        /// The tuner's reference: one note for `durationMs` (0: until stopped, the clip loops). Plucked voices
        /// re-pluck every one to two seconds, sustained voices hold without vibrato, so the pitch stays exact.
        case reference(durationMs: Int)
    }

    public let frequencies: [Double]
    public let kind: Kind
    public let voice: InstrumentVoice
    public let sampleRate: Int

    public init(frequencies: [Double], kind: Kind, voice: InstrumentVoice, sampleRate: Int) {
        self.frequencies = frequencies
        self.kind = kind
        self.voice = voice
        self.sampleRate = sampleRate
    }

    /// How long it sounds, in milliseconds (0: until stopped).
    public var durationMs: Int {
        switch kind {
        case let .phrase(together, noteMs, gapMs): return together ? max(0, noteMs) : frequencies.count * max(0, noteMs + max(0, gapMs))
        case let .reference(durationMs): return max(0, durationMs)
        }
    }

    /// The same request at another output rate.
    public func at(sampleRate rate: Int) -> ToneRequest { ToneRequest(frequencies: frequencies, kind: kind, voice: voice, sampleRate: rate) }
}

/// A rendered tone, immutable once made: the render thread only reads it. Playback returns to `loopStart`
/// after the last frame when it is set (a reference sounding until stopped).
public final class ToneClip: @unchecked Sendable {
    public let sampleRate: Int
    public let count: Int
    public let loopStart: Int?
    let samples: UnsafeMutableBufferPointer<Float>

    public init(frames: [Float], sampleRate: Int, loopStart: Int? = nil) {
        self.sampleRate = sampleRate
        count = frames.count
        self.loopStart = loopStart.flatMap { $0 >= 0 && $0 < frames.count ? $0 : nil }
        samples = UnsafeMutableBufferPointer<Float>.allocate(capacity: max(1, frames.count))
        samples.initialize(repeating: 0)
        for (index, value) in frames.enumerated() { samples[index] = value }
    }

    /// The samples as an array (tests and offline use; playback reads them in place).
    public var frames: [Float] { Array(samples.prefix(count)) }

    deinit { samples.deallocate() }
}

/// Render-thread side of a clip: plays it once (or loops it) and fades out on `stop`, like a damped string
/// rather than a click. Allocates nothing.
public final class ToneClipPlayer {
    private let clip: ToneClip
    private var position = 0
    private var gain: Float = 1
    private var step: Float = 0
    public private(set) var isPlaying: Bool

    public init(clip: ToneClip) {
        self.clip = clip
        isPlaying = clip.count > 0
    }

    public func stop(fadeFrames: Int) {
        guard isPlaying else { return }
        step = max(step, gain / Float(max(1, fadeFrames)))
    }

    public func nextSample() -> Float {
        guard isPlaying else { return 0 }
        if position >= clip.count {
            guard let loop = clip.loopStart else { isPlaying = false; return 0 }
            position = loop
        }
        let value = clip.samples[position] * gain
        position += 1
        if step > 0 {
            gain -= step
            if gain <= 0 { gain = 0; isPlaying = false }
        }
        return value
    }
}

/// Offline synthesis of instrument tones: Karplus–Strong strings tuned exactly with a solved all-pass and
/// played into a light body resonance; a modal struck bar; and a sustained bowed, blown or sung voice
/// (band-limited saw and square, formants, bow or breath noise, delayed vibrato). Pure functions over
/// sample buffers, deterministic, for a background queue; never in the audio callback.
public enum ToneSynth {
    /// Strum spread between neighbouring strings of a chord (a relaxed downstroke).
    public static let strumSpread = 0.024
    /// Vibrato starts this long into a sustained note, then grows in over `vibratoRamp`.
    public static let vibratoOnset = 0.3
    static let vibratoRamp = 0.35
    /// Loudest sample of a rendered clip: plucks and bars, and sustained voices (a little lower, they don't decay).
    public static let pluckedPeak: Float = 0.5
    public static let sustainedPeak: Float = 0.42

    public static func render(_ request: ToneRequest) -> ToneClip {
        let rate = Double(max(1, request.sampleRate))
        switch request.kind {
        case let .phrase(together, noteMs, gapMs):
            let frames = phrase(request.frequencies, together: together, noteMs: noteMs, gapMs: gapMs, voice: request.voice, rate: rate)
            return ToneClip(frames: frames, sampleRate: request.sampleRate)
        case let .reference(durationMs):
            let rendered = reference(request.frequencies.first ?? 0, durationMs: durationMs, voice: request.voice, rate: rate)
            return ToneClip(frames: rendered.frames, sampleRate: request.sampleRate, loopStart: rendered.loopStart)
        }
    }

    // MARK: Phrases and references

    /// Notes in turn (each `noteMs`, then `gapMs` of silence) or together for `noteMs`: plucked and struck
    /// voices strum low to high, sustained voices enter almost at once. Ends in silence on its last frame.
    public static func phrase(_ frequencies: [Double], together: Bool, noteMs: Int, gapMs: Int, voice: InstrumentVoice, rate: Double) -> [Float] {
        let note = max(1, Int(Double(max(1, noteMs)) * rate / 1000))
        let step = Int(Double(max(1, noteMs) + max(0, gapMs)) * rate / 1000)
        let total = together ? note : max(1, step * frequencies.count)
        var out = [Double](repeating: 0, count: total)
        if together {
            let order = frequencies.indices.sorted { frequencies[$0] < frequencies[$1] }
            let spread = voice.kind == .sustained ? 0.012 : strumSpread
            var feel = ToneNoise(seed: 0x5EED_0000 &+ UInt64(order.count))
            for (rank, index) in order.enumerated() {
                let jitter = rank == 0 ? 0 : 0.004 * Double(feel.next())
                let start = max(0, Int((Double(rank) * spread + jitter) * rate))
                let velocity = 1 - 0.03 * Double(rank) + 0.04 * Double(feel.next())
                sound(&out, hz: frequencies[index], start: start, length: total - start, gain: velocity, voice: voice,
                      rate: rate, reference: false, seed: UInt64(rank + 1))
            }
        } else {
            for (index, hz) in frequencies.enumerated() {
                sound(&out, hz: hz, start: index * step, length: note, gain: 1, voice: voice, rate: rate, reference: false, seed: UInt64(index + 1))
            }
        }
        return finish(&out, voice: voice, rate: rate, fadeEnd: true)
    }

    /// The tuner's reference at exactly `hz`. Up to 8 s it is rendered whole (plucks repeating every
    /// `repluckInterval`); longer or 0 (until stopped) it is one loopable cycle: a single pluck, or a
    /// sustained note's settled tone, crossfaded so the loop is seamless.
    public static func reference(_ hz: Double, durationMs: Int, voice: InstrumentVoice, rate: Double) -> (frames: [Float], loopStart: Int?) {
        let bounded = durationMs > 0 && durationMs <= 8000
        let length = max(1, Int(Double(max(1, durationMs)) * rate / 1000))
        if voice.kind == .sustained {
            if bounded {
                var out = [Double](repeating: 0, count: length)
                sound(&out, hz: hz, start: 0, length: length, gain: 1, voice: voice, rate: rate, reference: true, seed: 1)
                return (finish(&out, voice: voice, rate: rate, fadeEnd: true), nil)
            }
            // A second to settle, then about two seconds of whole periods that loop back onto it.
            let settle = Int(rate)
            let periods = max(1, (2 * hz).rounded())
            let loop = max(1, Int((periods * rate / max(1, hz)).rounded()))
            var out = [Double](repeating: 0, count: settle + loop + Int(0.4 * rate))
            sound(&out, hz: hz, start: 0, length: out.count, gain: 1, voice: voice, rate: rate, reference: true, seed: 1)
            out.removeLast(out.count - (settle + loop))
            let crossfade = min(Int(0.05 * rate), settle, loop)
            for j in 0..<crossfade {
                let w = Double(j) / Double(crossfade)
                let index = settle + loop - crossfade + j
                out[index] = out[index] * (1 - w) + out[settle - crossfade + j] * w
            }
            return (finish(&out, voice: voice, rate: rate, fadeEnd: false), settle)
        }
        let cycle = max(1, Int(repluckInterval(hz, voice: voice) * rate))
        let total = bounded ? length : cycle
        var out = [Double](repeating: 0, count: total)
        var start = 0
        while start < total {
            // No new pluck in the last third of a second: it would be cut off at once.
            if start > 0 && total - start < Int(0.35 * rate) { break }
            sound(&out, hz: hz, start: start, length: min(cycle, total - start), gain: 1, voice: voice, rate: rate, reference: true, seed: 1)
            start += cycle
        }
        return (finish(&out, voice: voice, rate: rate, fadeEnd: true), bounded ? nil : 0)
    }

    /// Seconds between reference plucks: two, or sooner for a voice that has faded by then (banjo, ukulele).
    public static func repluckInterval(_ hz: Double, voice: InstrumentVoice) -> Double {
        let base = voice.pluck?.sustain ?? malletSustain
        return min(2, max(1, 0.8 * ringTime(base, hz: hz, reference: true)))
    }

    /// Seconds for a note to fade 60 dB: `base` at 220 Hz, longer below and shorter above; references ring
    /// half as long again so they stay audible for tuning by ear.
    static func ringTime(_ base: Double, hz: Double, reference: Bool) -> Double {
        base * min(2, max(0.5, (220 / max(1, hz)).squareRoot())) * (reference ? 1.5 : 1)
    }

    static let malletSustain = 1.6

    private static func sound(_ out: inout [Double], hz: Double, start: Int, length: Int, gain: Double, voice: InstrumentVoice,
                              rate: Double, reference: Bool, seed: UInt64) {
        guard hz.isFinite, hz > 0 else { return }
        if let profile = voice.pluck {
            if !reference && profile.pairCents > 0 {
                // A doubled course: two strings a hair apart, centred on the pitch.
                let ratio = pow(2, profile.pairCents / 1200)
                pluck(&out, hz: hz * ratio, start: start, length: length, gain: gain * 0.55, profile: profile, rate: rate, reference: false, seed: seed)
                pluck(&out, hz: hz / ratio, start: start, length: length, gain: gain * 0.55, profile: profile, rate: rate, reference: false, seed: seed &+ 101)
            } else {
                pluck(&out, hz: hz, start: start, length: length, gain: gain, profile: profile, rate: rate, reference: reference, seed: seed)
            }
        } else if let profile = voice.sustain {
            sustained(&out, hz: hz, start: start, length: length, gain: gain, profile: profile, rate: rate, vibrato: !reference, seed: seed)
        } else {
            mallet(&out, hz: hz, start: start, length: length, gain: gain, rate: rate, reference: reference, seed: seed)
        }
    }

    /// Body resonance for plucked voices, then the clip brought to its peak level; `fadeEnd` closes the
    /// last 4 ms (not on a loop, whose end runs back into its start).
    private static func finish(_ out: inout [Double], voice: InstrumentVoice, rate: Double, fadeEnd: Bool) -> [Float] {
        if let profile = voice.pluck {
            body(&out, profile: profile, rate: rate)
        } else if voice.kind == .struck {
            var high = Biquad.highPass(hz: 50, q: 0.707, rate: rate)
            for i in out.indices { out[i] = high.process(out[i]) }
        }
        if fadeEnd {
            let fade = min(out.count, max(1, Int(0.004 * rate)))
            for j in 0..<fade { out[out.count - fade + j] *= Double(fade - 1 - j) / Double(fade) }
        }
        var peak = 0.0
        for value in out where value.isFinite { peak = max(peak, abs(value)) }
        let target = Double(voice.kind == .sustained ? sustainedPeak : pluckedPeak)
        let scale = peak > 0 ? target / peak : 0
        return out.map { $0.isFinite ? Float($0 * scale) : 0 }
    }

    // MARK: Voices

    /// Karplus–Strong: a noise burst one period long, coloured by the pick and the pluck point, circulating
    /// through a one-zero loss filter and a first-order all-pass whose coefficient is solved so the loop's
    /// phase delay at the fundamental is exactly one period: the note sounds at exactly `hz`.
    static func pluck(_ out: inout [Double], hz: Double, start: Int, length: Int, gain: Double, profile: PluckProfile,
                      rate: Double, reference: Bool, seed: UInt64) {
        guard hz > 20, hz < rate / 4, start >= 0, start < out.count else { return }
        let count = min(length, out.count - start)
        guard count > 0 else { return }
        let period = rate / hz
        let omega = 2 * Double.pi * hz / rate
        let brightness = min(1, max(0, profile.brightness))
        // Loop smoothing: 0.5 is the classic two-point average; less keeps the upper partials ringing longer.
        let smoothing = 0.5 - 0.3 * brightness
        let real = (1 - smoothing) + smoothing * cos(omega)
        let imaginary = smoothing * sin(omega)
        let filterDelay = atan2(imaginary, real) / omega
        let whole = max(2, Int(period - filterDelay - 0.1))
        let coefficient = allPassCoefficient(delay: period - filterDelay - Double(whole), omega: omega)
        let response = (real * real + imaginary * imaginary).squareRoot()
        let t60 = ringTime(profile.sustain, hz: hz, reference: reference)
        let loss = min(0.99999, pow(0.001, 1 / (t60 * hz)) / max(0.5, response))

        var noise = ToneNoise(seed: seed &* 0x9E37_79B9 &+ UInt64(hz * 1000))
        var burst = [Double](repeating: 0, count: whole)
        let cutoff = min(800 + 9000 * brightness * brightness, rate * 0.45)
        let a = 1 - exp(-2 * Double.pi * cutoff / rate)
        var low1 = 0.0, low2 = 0.0
        for i in 0..<whole {
            low1 += (Double(noise.next()) - low1) * a
            low2 += (low1 - low2) * a
            burst[i] = low2
        }
        var mean = burst.reduce(0, +) / Double(whole)
        for i in 0..<whole { burst[i] -= mean }
        // The pluck point: a string plucked at 1/n of its length has no n-th harmonic.
        let pickDelay = max(1, min(whole - 1, Int((profile.pick * Double(whole)).rounded())))
        var line = [Double](repeating: 0, count: whole)
        for i in 0..<whole { line[i] = burst[i] - 0.9 * burst[(i - pickDelay + whole) % whole] }
        mean = line.reduce(0, +) / Double(whole)
        var peak = 0.0
        for i in 0..<whole { line[i] -= mean; peak = max(peak, abs(line[i])) }
        guard peak > 0 else { return }
        for i in 0..<whole { line[i] /= peak }

        // The note's end: a short damp, as a finger would stop the string.
        let fade = min(Int(0.06 * rate), count / 3)
        var index = 0
        var previous = 0.0, apIn = 0.0, apOut = 0.0
        for n in 0..<count {
            let current = line[index]
            var envelope = 1.0
            if fade > 0 && n >= count - fade { envelope = 0.5 + 0.5 * cos(Double.pi * Double(n - (count - fade)) / Double(fade)) }
            out[start + n] += current * gain * envelope
            let filtered = loss * ((1 - smoothing) * current + smoothing * previous)
            let tuned = coefficient * filtered + apIn - coefficient * apOut
            apIn = filtered
            apOut = tuned
            line[index] = tuned
            previous = current
            index += 1
            if index == whole { index = 0 }
        }
    }

    /// Phase delay in samples of the all-pass (c + z⁻¹) / (1 + c z⁻¹) at `omega`.
    static func allPassDelay(_ c: Double, omega: Double) -> Double {
        let numerator = atan2(-sin(omega), c + cos(omega))
        let denominator = atan2(-c * sin(omega), 1 + c * cos(omega))
        return -(numerator - denominator) / omega
    }

    /// The all-pass coefficient whose phase delay at `omega` is `delay` samples (bisection; the delay falls as c rises).
    static func allPassCoefficient(delay: Double, omega: Double) -> Double {
        var low = -0.95, high = 0.999
        for _ in 0..<48 {
            let middle = (low + high) / 2
            if allPassDelay(middle, omega: omega) > delay { low = middle } else { high = middle }
        }
        return (low + high) / 2
    }

    /// The instrument's body: resonances added in parallel to the strings, a gentle top cut and a low cut.
    private static func body(_ out: inout [Double], profile: PluckProfile, rate: Double) {
        var resonances = profile.body.filter { $0.hz < rate * 0.45 }.map {
            Formant(filter: Biquad.bandPass(hz: $0.hz, q: $0.q, rate: rate), gain: $0.gain)
        }
        var low = Biquad.lowPass(hz: min(profile.lowpass, rate * 0.45), q: 0.707, rate: rate)
        var high = Biquad.highPass(hz: profile.highpass, q: 0.707, rate: rate)
        for i in out.indices {
            let dry = out[i]
            var value = dry
            for k in resonances.indices { value += resonances[k].gain * resonances[k].filter.process(dry) }
            out[i] = high.process(low.process(value))
        }
    }

    /// A bowed, blown or sung note at exactly `hz` (vibrato, when on, swings evenly around it), its level
    /// set by its own steady part so every note of a phrase is as loud as the others.
    static func sustained(_ out: inout [Double], hz: Double, start: Int, length: Int, gain: Double, profile: SustainProfile,
                          rate: Double, vibrato: Bool, seed: UInt64) {
        guard hz > 20, hz < rate / 2.5, start >= 0, start < out.count else { return }
        let count = min(length, out.count - start)
        guard count > 0 else { return }
        var noise = ToneNoise(seed: seed &* 0x2545_F491 &+ UInt64(hz * 1000))
        var lowpass = Biquad.lowPass(hz: min(profile.lowpass, rate * 0.45), q: 0.707, rate: rate)
        var formants = profile.formants.filter { $0.hz < rate * 0.45 }.map {
            Formant(filter: Biquad.bandPass(hz: $0.hz, q: $0.q, rate: rate), gain: $0.gain)
        }
        var breath = Biquad.bandPass(hz: min(profile.noiseHz, rate * 0.4), q: 0.8, rate: rate)
        let attack = max(1, Int(profile.attack * rate))
        let release = max(1, min(Int(profile.release * rate), count / 3))
        var voice = [Double](repeating: 0, count: count)
        var phase = 0.0
        var energy = 0.0, measured = 0
        var frequency = hz
        for n in 0..<count {
            let t = Double(n) / rate
            // The vibrato curve, updated every 8 samples (it moves at about 5 Hz).
            if vibrato && profile.vibratoCents > 0 && t > vibratoOnset && n % 8 == 0 {
                let x = min(1, (t - vibratoOnset) / vibratoRamp)
                let depth = x * x * (3 - 2 * x)
                let cents = depth * profile.vibratoCents * sin(2 * Double.pi * profile.vibratoRate * (t - vibratoOnset))
                frequency = hz * pow(2, cents / 1200)
            }
            let dt = frequency / rate
            var source = 0.0
            if profile.saw > 0 { source += profile.saw * (2 * phase - 1 - blep(phase, dt)) }
            if profile.square > 0 {
                let shifted = phase < 0.5 ? phase + 0.5 : phase - 0.5
                source += profile.square * ((phase < 0.5 ? 1.0 : -1.0) + blep(phase, dt) - blep(shifted, dt))
            }
            if profile.sine > 0 { source += profile.sine * sin(2 * Double.pi * phase) }
            phase += dt
            if phase >= 1 { phase -= 1 }
            let bright = lowpass.process(source)
            var value = profile.dry * bright
            for k in formants.indices { value += formants[k].gain * formants[k].filter.process(bright) }
            if profile.noise > 0 { value += profile.noise * 4 * breath.process(Double(noise.next())) }
            var envelope = 1.0
            if n < attack {
                let x = sin(0.5 * Double.pi * Double(n) / Double(attack))
                envelope = x * x
            }
            if n >= count - release {
                envelope *= 0.5 + 0.5 * cos(Double.pi * Double(n - (count - release)) / Double(release))
            } else if n >= attack {
                energy += value * value
                measured += 1
            }
            voice[n] = value * envelope
        }
        if measured == 0 {
            for value in voice { energy += value * value }
            measured = count
        }
        let rms = (energy / Double(max(1, measured))).squareRoot()
        guard rms > 0, rms.isFinite else { return }
        let scale = gain / rms
        for n in 0..<count { out[start + n] += voice[n] * scale }
    }

    /// PolyBLEP: smooths a saw or square step so the waveform stays band-limited (no aliasing whistles).
    private static func blep(_ phase: Double, _ dt: Double) -> Double {
        guard dt > 0 else { return 0 }
        if phase < dt {
            let t = phase / dt
            return t + t - t * t - 1
        }
        if phase > 1 - dt {
            let t = (phase - 1) / dt
            return t * t + t + t + 1
        }
        return 0
    }

    /// A struck bar (marimba, kalimba, handpan): the fundamental, the bar's tuned overtones and a soft knock.
    static func mallet(_ out: inout [Double], hz: Double, start: Int, length: Int, gain: Double, rate: Double, reference: Bool, seed: UInt64) {
        guard hz > 20, hz < rate / 2.5, start >= 0, start < out.count else { return }
        let count = min(length, out.count - start)
        guard count > 0 else { return }
        let t60 = ringTime(malletSustain, hz: hz, reference: reference)
        let fade = min(Int(0.05 * rate), count / 3)
        let partials: [(ratio: Double, level: Double, sustain: Double)] = [(1, 1, 1), (4, 0.28, 0.16), (10, 0.06, 0.05)]
        for partial in partials where hz * partial.ratio < rate * 0.45 {
            let omega = 2 * Double.pi * hz * partial.ratio / rate
            let k = 2 * cos(omega)
            var y1 = 0.0, y2 = -sin(omega)
            let decay = pow(0.001, 1 / (max(0.02, t60 * partial.sustain) * rate))
            var level = partial.level * gain
            for n in 0..<count {
                let y = k * y1 - y2
                y2 = y1
                y1 = y
                var envelope = min(1, Double(n) / (0.0015 * rate))
                if fade > 0 && n >= count - fade { envelope *= Double(count - n) / Double(fade) }
                out[start + n] += y2 * level * envelope
                level *= decay
            }
        }
        var noise = ToneNoise(seed: seed &+ 77)
        let knock = min(count, Int(0.003 * rate))
        var soft = 0.0
        for n in 0..<knock {
            soft += (Double(noise.next()) - soft) * 0.3
            out[start + n] += soft * 0.25 * gain * (1 - Double(n) / Double(max(1, knock)))
        }
    }
}

// MARK: - Helpers

/// A filter and its level, for a body resonance or a formant.
private struct Formant {
    var filter: Biquad
    let gain: Double
}

/// RBJ biquad, transposed direct form I.
struct Biquad {
    private let b0: Double, b1: Double, b2: Double, a1: Double, a2: Double
    private var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    private init(b0: Double, b1: Double, b2: Double, a0: Double, a1: Double, a2: Double) {
        self.b0 = b0 / a0; self.b1 = b1 / a0; self.b2 = b2 / a0
        self.a1 = a1 / a0; self.a2 = a2 / a0
    }

    /// Band-pass with 0 dB at its centre.
    static func bandPass(hz: Double, q: Double, rate: Double) -> Biquad {
        let w = 2 * Double.pi * hz / rate
        let alpha = sin(w) / (2 * max(0.1, q))
        return Biquad(b0: alpha, b1: 0, b2: -alpha, a0: 1 + alpha, a1: -2 * cos(w), a2: 1 - alpha)
    }

    static func lowPass(hz: Double, q: Double, rate: Double) -> Biquad {
        let w = 2 * Double.pi * hz / rate
        let alpha = sin(w) / (2 * max(0.1, q))
        let c = cos(w)
        return Biquad(b0: (1 - c) / 2, b1: 1 - c, b2: (1 - c) / 2, a0: 1 + alpha, a1: -2 * c, a2: 1 - alpha)
    }

    static func highPass(hz: Double, q: Double, rate: Double) -> Biquad {
        let w = 2 * Double.pi * hz / rate
        let alpha = sin(w) / (2 * max(0.1, q))
        let c = cos(w)
        return Biquad(b0: (1 + c) / 2, b1: -(1 + c), b2: (1 + c) / 2, a0: 1 + alpha, a1: -2 * c, a2: 1 - alpha)
    }

    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x
        y2 = y1; y1 = y
        return y
    }
}

/// Deterministic white noise in -1...1 (xorshift64), so a tone renders the same every time.
struct ToneNoise {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
    mutating func next() -> Float {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Float(Double(state >> 11) / Double(UInt64(1) << 53)) * 2 - 1
    }
}
