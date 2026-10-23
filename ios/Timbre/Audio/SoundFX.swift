import AVFoundation

/// Short interface sounds (right answer, wrong answer, star, count-in click, lock), synthesized once on
/// device: Karplus–Strong plucks for notes, soft harmonic bells for rewards, a two-mode woodblock for clicks.
/// They play through AVAudioPlayer so they never interrupt the microphone capture, and stay quiet.
@MainActor
final class SoundFX {
    static let shared = SoundFX()
    typealias Cue = SoundCue
    var enabled = true
    private var players: [Cue: AVAudioPlayer] = [:]
    /// Lock bells by pitch (tenths of a hertz), rendered once per string pitch.
    private var bells: [Int: AVAudioPlayer] = [:]

    private init() {
        // Render every cue off the main thread; a cue asked for before then renders on the spot.
        Task.detached(priority: .utility) { [weak self] in
            let rendered = Cue.allCases.map { ($0, SoundSynth.wav(SoundSynth.render($0), rate: SoundSynth.rate)) }
            await self?.install(rendered)
        }
    }

    private func install(_ rendered: [(Cue, Data)]) {
        for (cue, data) in rendered where players[cue] == nil { players[cue] = Self.player(data, volume: Self.volume(cue)) }
    }

    func play(_ cue: Cue) {
        guard enabled else { return }
        if players[cue] == nil { players[cue] = Self.player(SoundSynth.wav(SoundSynth.render(cue), rate: SoundSynth.rate), volume: Self.volume(cue)) }
        guard let player = players[cue] else { return }
        player.currentTime = 0
        player.play()
    }

    /// The lock "ding": a plucked harmonic at the pitch of the string just tuned, raised an octave at a time
    /// while it is too low for a phone speaker. Cached per pitch, so the next lock of that string is instant.
    func playLock(frequency: Double) {
        guard enabled, let hz = SoundSynth.bellPitch(frequency) else { return }
        let key = Self.bellKey(hz)
        if bells[key] == nil { installBell(SoundSynth.wav(SoundSynth.bell(hz), rate: SoundSynth.rate), key: key) }
        guard let player = bells[key] else { return }
        player.currentTime = 0
        player.play()
    }

    /// The lock bell for a MIDI note at A4 = 440 Hz.
    func playLock(midi: Int) { playLock(frequency: SoundSynth.hz(midi)) }

    /// Renders the lock bells of these strings in the background, so the first lock never waits on synthesis.
    func prepareLocks(_ frequencies: [Double]) {
        let missing = Array(Set(frequencies.compactMap(SoundSynth.bellPitch).filter { bells[Self.bellKey($0)] == nil }))
        guard !missing.isEmpty else { return }
        Task.detached(priority: .utility) { [weak self] in
            let rendered = missing.map { ($0, SoundSynth.wav(SoundSynth.bell($0), rate: SoundSynth.rate)) }
            await self?.installBells(rendered)
        }
    }

    private func installBells(_ rendered: [(Double, Data)]) {
        for (hz, data) in rendered where bells[Self.bellKey(hz)] == nil { installBell(data, key: Self.bellKey(hz)) }
    }

    private func installBell(_ data: Data, key: Int) {
        if bells.count >= 64 { bells.removeAll() }
        bells[key] = Self.player(data, volume: 0.32)
    }

    private static func bellKey(_ hz: Double) -> Int { Int((hz * 10).rounded()) }

    private static func player(_ data: Data, volume: Float) -> AVAudioPlayer? {
        guard let player = try? AVAudioPlayer(data: data) else { return nil }
        player.volume = volume
        player.prepareToPlay()
        return player
    }

    private static func volume(_ cue: Cue) -> Float {
        switch cue {
        case .click, .accent: return 0.5
        case .hit: return 0.32
        case .wrong: return 0.3
        default: return 0.36
        }
    }
}

/// The interface sounds `SoundFX` plays (kept outside the main-actor class so they render off the main thread).
enum SoundCue: CaseIterable, Sendable { case correct, wrong, star, click, accent, complete, hit, levelUp }

/// Offline synthesis for `SoundFX`: pure functions over sample buffers, normalised to a gentle peak.
enum SoundSynth {
    static let rate = 44_100
    /// Lock bells below this are raised an octave (E2 → E3, bass E1 → E3).
    static let lowestBell = 140.0

    static func hz(_ midi: Int) -> Double { 440 * pow(2, Double(midi - 69) / 12) }

    /// The bell's pitch for a string: its own, an octave up at a time while below `lowestBell`.
    static func bellPitch(_ frequency: Double) -> Double? {
        guard frequency.isFinite, frequency > 1 else { return nil }
        var hz = frequency
        while hz < lowestBell { hz *= 2 }
        return min(hz, 4_000)
    }

    static func render(_ cue: SoundCue) -> [Float] {
        switch cue {
        case .correct:
            // Two bright plucks a sixth apart, the second ringing with a bell partial on top.
            var b = buffer(0.75)
            pluck(&b, hz: hz(76), at: 0, length: 0.4, gain: 0.8, brightness: 0.75, sustain: 0.6)
            pluck(&b, hz: hz(83), at: 0.075, length: 0.65, gain: 0.85, brightness: 0.8, sustain: 0.8)
            chime(&b, hz: hz(83), at: 0.075, length: 0.6, gain: 0.22)
            return normalised(b, peak: 0.55)
        case .wrong:
            // A soft, muted low pluck stepping down: a gentle "not quite", never a buzzer.
            var b = buffer(0.5)
            pluck(&b, hz: hz(50), at: 0, length: 0.22, gain: 0.9, brightness: 0.35, sustain: 0.18)
            pluck(&b, hz: hz(47), at: 0.1, length: 0.32, gain: 0.8, brightness: 0.3, sustain: 0.22)
            return normalised(b, peak: 0.45)
        case .star:
            // A sparkle: three bells rising through a major triad.
            var b = buffer(1.1)
            for (i, midi) in [84, 88, 91].enumerated() {
                chime(&b, hz: hz(midi), at: Double(i) * 0.07, length: 0.9 - Double(i) * 0.1, gain: 0.7, shimmer: true)
            }
            return normalised(b, peak: 0.5)
        case .click:
            var b = buffer(0.07)
            woodblock(&b, modes: [(1_960, 140, 1), (3_120, 220, 0.45), (900, 110, 0.3)])
            return normalised(b, peak: 0.5)
        case .accent:
            var b = buffer(0.09)
            woodblock(&b, modes: [(2_640, 120, 1), (4_180, 190, 0.4), (1_250, 95, 0.35)])
            return normalised(b, peak: 0.62)
        case .complete:
            // A plucked arpeggio that lands on a ringing bell.
            var b = buffer(1.6)
            for (i, midi) in [72, 76, 79].enumerated() {
                pluck(&b, hz: hz(midi), at: Double(i) * 0.095, length: 0.7, gain: 0.7, brightness: 0.65, sustain: 0.7)
            }
            pluck(&b, hz: hz(84), at: 0.285, length: 1.2, gain: 0.75, brightness: 0.7, sustain: 1)
            chime(&b, hz: hz(84), at: 0.285, length: 1.25, gain: 0.35, shimmer: true)
            return normalised(b, peak: 0.55)
        case .hit:
            // A short soft mallet: fundamental plus the marimba's tuned fourth partial.
            var b = buffer(0.2)
            mallet(&b, hz: hz(84), length: 0.18)
            return normalised(b, peak: 0.45)
        case .levelUp:
            // A rising plucked fanfare crowned by a shimmering bell.
            var b = buffer(2)
            for (i, midi) in [72, 76, 79, 84, 88].enumerated() {
                pluck(&b, hz: hz(midi), at: Double(i) * 0.075, length: 0.75, gain: 0.65, brightness: 0.7, sustain: 0.75)
            }
            pluck(&b, hz: hz(91), at: 0.375, length: 1.4, gain: 0.7, brightness: 0.75, sustain: 1.1)
            chime(&b, hz: hz(91), at: 0.375, length: 1.5, gain: 0.4, shimmer: true)
            chime(&b, hz: hz(79), at: 0.375, length: 1.3, gain: 0.25)
            return normalised(b, peak: 0.55)
        }
    }

    /// The lock bell: a pluck for the attack and a harmonic bell that rings on, like a natural harmonic.
    /// Its partials are whole multiples of `hz`, so it reads as exactly that pitch.
    static func bell(_ hz: Double) -> [Float] {
        var b = buffer(1.3)
        pluck(&b, hz: hz, at: 0, length: 0.5, gain: 0.45, brightness: 0.6, sustain: 0.35)
        chime(&b, hz: hz, at: 0.004, length: 1.25, gain: 0.8)
        return normalised(b, peak: 0.5)
    }

    // MARK: Voices

    static func buffer(_ seconds: Double) -> [Float] { [Float](repeating: 0, count: Int(seconds * Double(rate))) }

    /// Karplus–Strong: a noise burst circulating in a delay line one period long, softened each pass by a
    /// two-point average and tuned exactly with a first-order all-pass. `sustain` is roughly seconds to fade 60 dB
    /// at the fundamental; `brightness` (0...1) shapes the pick (darker = softer, rounder).
    static func pluck(_ out: inout [Float], hz: Double, at start: Double, length: Double, gain: Float, brightness: Double, sustain: Double) {
        guard hz > 20, hz < Double(rate) / 4 else { return }
        let period = Double(rate) / hz
        let whole = max(2, Int(period - 0.5 - 0.1))
        let fraction = period - 0.5 - Double(whole)          // all-pass delay, 0.1...1.1 samples
        let coefficient = Float((1 - fraction) / (1 + fraction))
        let loss = Float(pow(0.001, 1 / max(0.05, sustain) / hz))   // per pass, so the fundamental fades 60 dB in `sustain`
        var noise = SystemNoise(seed: UInt64(hz * 1000))
        var line = [Float](repeating: 0, count: whole)
        var low: Float = 0
        let smoothing = Float(0.15 + 0.8 * (1 - max(0, min(1, brightness))))
        for i in 0..<whole {
            low += (noise.next() - low) * (1 - smoothing)
            line[i] = low
        }
        // No DC in the loop: it would otherwise linger as a slow thump.
        let mean = line.reduce(0, +) / Float(whole)
        for i in 0..<whole { line[i] -= mean }
        let first = Int(start * Double(rate))
        let count = min(Int(length * Double(rate)), out.count - first)
        guard count > 0 else { return }
        let fade = Int(0.03 * Double(rate))
        var index = 0
        var previous: Float = 0, apIn: Float = 0, apOut: Float = 0
        for n in 0..<count {
            let current = line[index]
            var envelope: Float = 1
            if n > count - fade { envelope = Float(count - n) / Float(fade) }
            out[first + n] += current * gain * envelope
            let averaged = loss * 0.5 * (current + previous)
            let tuned = coefficient * averaged + apIn - coefficient * apOut
            apIn = averaged; apOut = tuned
            line[index] = tuned
            previous = current
            index += 1
            if index == whole { index = 0 }
        }
    }

    /// A soft bell from harmonic partials (each decaying faster than the one below); `shimmer` adds a faint
    /// inharmonic glint for celebration cues. Partials use recursive oscillators, so a bell costs little.
    static func chime(_ out: inout [Float], hz: Double, at start: Double, length: Double, gain: Float, shimmer: Bool = false) {
        var partials: [(ratio: Double, amplitude: Double, sustain: Double)] = [
            (1, 1, 1.2), (2, 0.42, 0.8), (3, 0.2, 0.55), (4, 0.11, 0.4), (5, 0.06, 0.3), (6, 0.035, 0.25),
        ]
        if shimmer { partials.append((2.76, 0.07, 0.35)); partials.append((5.4, 0.035, 0.2)) }
        let first = Int(start * Double(rate))
        let count = min(Int(length * Double(rate)), out.count - first)
        guard count > 0 else { return }
        let attack = 0.003 * Double(rate)
        let fade = Int(0.04 * Double(rate))
        for partial in partials {
            let frequency = hz * partial.ratio
            guard frequency < Double(rate) / 2.2 else { continue }
            let omega = 2 * Double.pi * frequency / Double(rate)
            let step = 2 * cos(omega)
            var y1 = 0.0, y2 = -sin(omega)        // sin(0) and sin(-ω): a unit sine from n = 0
            let decay = pow(0.001, 1 / (partial.sustain * Double(rate)))
            var level = partial.amplitude * Double(gain)
            for n in 0..<count {
                let y = step * y1 - y2
                y2 = y1; y1 = y
                var envelope = min(1, Double(n) / attack)
                if n > count - fade { envelope *= Double(count - n) / Double(fade) }
                out[first + n] += Float(y2 * level * envelope)
                level *= decay
            }
        }
    }

    /// A short mallet: fundamental, the marimba's fourth partial and a click of the bar.
    static func mallet(_ out: inout [Float], hz: Double, length: Double) {
        let count = min(Int(length * Double(rate)), out.count)
        for (ratio, amplitude, sustain) in [(1.0, 1.0, 0.16), (4.0, 0.3, 0.05), (9.9, 0.08, 0.02)] {
            let frequency = hz * ratio
            guard frequency < Double(rate) / 2.2 else { continue }
            let omega = 2 * Double.pi * frequency / Double(rate)
            let decay = pow(0.001, 1 / (sustain * Double(rate)))
            var level = amplitude
            for n in 0..<count {
                let envelope = min(1, Double(n) / (0.0015 * Double(rate)))
                out[n] += Float(sin(omega * Double(n)) * level * envelope)
                level *= decay
            }
        }
    }

    /// A woodblock: a few fast-decaying resonant modes (hertz, decay per second, level) struck by a sub-millisecond noise tick.
    static func woodblock(_ out: inout [Float], modes: [(Double, Double, Double)]) {
        let count = out.count
        var noise = SystemNoise(seed: 7)
        let tick = Int(0.0008 * Double(rate))
        for n in 0..<min(tick, count) { out[n] += noise.next() * 0.35 * Float(1 - Double(n) / Double(tick)) }
        for (frequency, damping, amplitude) in modes {
            let omega = 2 * Double.pi * frequency / Double(rate)
            for n in 0..<count {
                let t = Double(n) / Double(rate)
                out[n] += Float(amplitude * exp(-damping * t) * sin(omega * Double(n)) * min(1, t / 0.0004))
            }
        }
    }

    static func normalised(_ samples: [Float], peak: Float) -> [Float] {
        let largest = samples.reduce(Float(0)) { max($0, abs($1)) }
        guard largest > 0 else { return samples }
        let scale = peak / largest
        return samples.map { $0 * scale }
    }

    static func wav(_ samples: [Float], rate: Int) -> Data {
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        let bytes = samples.count * 2
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + bytes)); data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(rate)); append(UInt32(rate * 2)); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(UInt32(bytes))
        for sample in samples { append(Int16(max(-1, min(1, sample)) * Float(Int16.max))) }
        return data
    }
}

/// Deterministic white noise in -1...1 (xorshift), so every cue renders the same each launch.
struct SystemNoise {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
    mutating func next() -> Float {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return Float(Double(state >> 11) / Double(1 << 53)) * 2 - 1
    }
}
