import XCTest
@testable import TimbreCore

/// Strums for the polyphonic tuner: every string's fundamental is set exactly (no random detune), its
/// partials follow a stiff string, n·f₁·√((1 + Bn²)/(1 + B)) (B = 1e-4 wound, 3e-5 plain), with a
/// pluck-position comb, faster decay for higher partials, random phases, a strum's spread across the
/// strings and a little noise. Deterministic (`TestRandom`).
enum StrumSynth {
    static func midiHz(_ midi: Int) -> Double { PitchMath.frequency(midi: Double(midi)) }

    /// Each string's pitch `cents` off its MIDI note; nil cents is a muted string.
    static func detuned(_ midi: [Int], _ cents: [Double?]) -> [Double?] {
        zip(midi, cents).map { note, offset in offset.map { midiHz(note) * PitchMath.ratio(cents: $0) } }
    }

    /// The strings sounded low to high from `start`, `spread` seconds apart (±40%), each at 70–100%
    /// level, peak-normalised to `gain`, plus uniform noise of amplitude `noise`.
    static func strum(_ pitches: [Double?], sampleRate: Double, duration: Double, seed: UInt64, start: Double = 0.3,
                      spread: Double = 0.012, gain: Double = 0.3, noise: Double = 0.002, decayScale: Double = 1,
                      fundamentalGain: Double = 1) -> [Float] {
        var rng = TestRandom(seed: seed)
        var out = [Double](repeating: 0, count: Int(duration * sampleRate))
        var k = 0
        for pitch in pitches {
            guard let pitch else { continue }
            let delay = Double(k) * spread * rng.uniform(0.6, 1.4)
            let level = rng.uniform(0.7, 1.0)
            pluck(pitch, at: start + delay, into: &out, sampleRate: sampleRate, rng: &rng, level: level,
                  stiffness: pitch < 160 ? 1e-4 : 3e-5, decayScale: decayScale, fundamentalGain: fundamentalGain)
            k += 1
        }
        let peak = out.map { abs($0) }.max() ?? 0
        let scale = peak > 0 ? gain / peak : 0
        for i in out.indices {
            out[i] *= scale
            if noise > 0 { out[i] += noise * rng.uniform(-1, 1) }
        }
        return out.map { Float($0) }
    }

    /// One string with fundamental `f1`: up to 16 partials below 4 kHz.
    static func pluck(_ f1: Double, at start: Double, into out: inout [Double], sampleRate: Double, rng: inout TestRandom,
                      level: Double, stiffness: Double, decayScale: Double, fundamentalGain: Double) {
        let beta = rng.uniform(0.1, 0.22)
        var n = 1
        while true {
            let h = Double(n)
            let frequency = h * f1 * ((1 + stiffness * h * h) / (1 + stiffness)).squareRoot()
            if frequency > 4000 || n > 16 { break }
            var amplitude = level * abs(sin(h * Double.pi * beta)) / h
            if n == 1 { amplitude *= fundamentalGain }
            let decay = (1.2 + 0.5 * h * frequency / 1000 + 0.3 * h) * decayScale
            let phase = rng.uniform(0, 6.28)
            addPartial(&out, start: start, frequency: frequency, amplitude: amplitude, decay: decay, phase: phase, sampleRate: sampleRate)
            n += 1
        }
    }

    /// amplitude · e^(−decay·t) · sin(2πft + phase), t from `start`, with a 2 ms attack ramp.
    private static func addPartial(_ out: inout [Double], start: Double, frequency: Double, amplitude: Double, decay: Double,
                                   phase: Double, sampleRate: Double) {
        let first = max(0, Int(ceil(start * sampleRate)))
        guard first < out.count else { return }
        let t0 = Double(first) / sampleRate - start
        let envelope = amplitude * exp(-decay * t0)
        guard envelope > 1e-12 else { return }
        var re = envelope * cos(2 * Double.pi * frequency * t0 + phase)
        var im = envelope * sin(2 * Double.pi * frequency * t0 + phase)
        let damping = exp(-decay / sampleRate), step = 2 * Double.pi * frequency / sampleRate
        let cr = damping * cos(step), ci = damping * sin(step)
        let audible = Int((log(envelope / 1e-9) / decay * sampleRate).rounded(.up))
        let end = min(out.count, first + max(0, audible))
        var i = first
        while i < end {
            out[i] += im * min(1, (Double(i) / sampleRate - start) / 0.002)
            let next = re * cr - im * ci
            im = re * ci + im * cr
            re = next
            i += 1
        }
    }
}

final class PolyTunerTests: XCTestCase {
    private let guitar = [40, 45, 50, 55, 59, 64]
    private let bass = [28, 33, 38, 43]
    /// Re-entrant: the G string is the high G4.
    private let ukulele = [67, 60, 64, 69]
    /// Four unison courses.
    private let mandolin = [55, 55, 62, 62, 69, 69, 76, 76]

    private func feed(_ signal: [Float], to tuner: PolyTuner, chunk: Int) -> [PolyReading] {
        var readings: [PolyReading] = []
        var start = 0
        while start < signal.count {
            let end = min(signal.count, start + chunk)
            if let reading = tuner.feed(Array(signal[start..<end])) { readings.append(reading) }
            start = end
        }
        return readings
    }

    /// Strums the strings once at 0.3 s and feeds the microphone stream in `chunk`-sample buffers: exactly
    /// one reading, every sounding string within ±3 cents of its detune with at least `confidence`, every
    /// muted (nil) string not heard. Returns the worst error in cents.
    @discardableResult
    private func assertStrum(_ name: String, _ midi: [Int], cents: [Double?], seed: UInt64, sampleRate: Double = 48000,
                             chunk: Int = 512, confidence: Double = 0.75, decayScale: Double = 1, fundamentalGain: Double = 1,
                             file: StaticString = #filePath, line: UInt = #line) -> Double {
        let tuner = PolyTuner(strings: midi.map(StrumSynth.midiHz), sampleRate: sampleRate)
        let duration = 0.3 + tuner.settle + tuner.window + 0.15
        let signal = StrumSynth.strum(StrumSynth.detuned(midi, cents), sampleRate: sampleRate, duration: duration, seed: seed,
                                      decayScale: decayScale, fundamentalGain: fundamentalGain)
        let readings = feed(signal, to: tuner, chunk: chunk)
        let context = "\(name) at \(Int(sampleRate)) Hz, seed \(seed)"
        XCTAssertEqual(readings.count, 1, context, file: file, line: line)
        guard let reading = readings.first else { return .infinity }
        XCTAssertEqual(reading.strings.count, midi.count, context, file: file, line: line)
        XCTAssertEqual(reading.onsetTime, 0.3, accuracy: 0.03, context, file: file, line: line)
        var worst = 0.0
        for (index, expected) in cents.enumerated() {
            let string = reading.strings[index]
            let label = "\(context), string \(index + 1) \(PitchMath.noteName(midi: midi[index]))"
            XCTAssertEqual(string.index, index, label, file: file, line: line)
            guard let expected else {
                XCTAssertFalse(string.isHeard, "\(label) is muted but read \(string.cents ?? 0) cents", file: file, line: line)
                continue
            }
            guard let heard = string.cents else {
                XCTFail("\(label) not heard", file: file, line: line)
                worst = .infinity
                continue
            }
            worst = max(worst, abs(heard - expected))
            XCTAssertEqual(heard, expected, accuracy: 3, label, file: file, line: line)
            XCTAssertGreaterThanOrEqual(string.confidence, confidence, label, file: file, line: line)
        }
        let evidence = reading.strings.map { $0.evidence?.rawValue ?? "not heard" }
        print("PolyTuner \(context): worst \(String(format: "%.2f", worst)) cents, \(evidence)")
        return worst
    }

    func testStandardGuitarDetunedStringsReadInOneStrum() {
        let cents: [Double?] = [0, -12, 25, -40, 7, -3]
        for seed: UInt64 in [1, 2] {
            assertStrum("guitar E2 A2 D3 G3 B3 E4", guitar, cents: cents, seed: seed)
            assertStrum("guitar E2 A2 D3 G3 B3 E4", guitar, cents: cents, seed: seed, sampleRate: 44100, chunk: 4410)
        }
    }

    /// In tune, B3 sits 2 cents under E2's 3rd harmonic and E4 on E2's 4th and A2's 3rd: the strings
    /// must still be told from those harmonics. Confidence may be lower where they coincide.
    func testInTuneGuitarStringsAreToldFromLowerStringsHarmonics() {
        for seed: UInt64 in 1...3 {
            assertStrum("guitar in tune", guitar, cents: [0, 0, 0, 0, 0, 0], seed: seed, confidence: 0.4)
        }
    }

    /// E1 is 41 Hz: a bass gets the 0.7 s window. Phone microphones hear little of a bass's fundamental,
    /// so the second strum has its fundamentals 20 dB down and leans on the 2nd and 3rd partials.
    func testBassStringsUseTheLongerWindow() {
        XCTAssertEqual(PolyTuner(strings: bass.map(StrumSynth.midiHz)).window, 0.7)
        for seed: UInt64 in [1, 2] {
            assertStrum("bass E1 A1 D2 G2", bass, cents: [0, -15, 20, -6], seed: seed, decayScale: 0.5)
            assertStrum("bass E1 A1 D2 G2, weak fundamentals", bass, cents: [0, -15, 20, -6], seed: seed, confidence: 0.3,
                        decayScale: 0.5, fundamentalGain: 0.1)
        }
    }

    func testReentrantUkulele() {
        for seed: UInt64 in [1, 2] {
            assertStrum("ukulele G4 C4 E4 A4", ukulele, cents: [10, -5, 0, -20], seed: seed)
        }
    }

    func testMutedStringIsNotHeard() {
        assertStrum("guitar, G3 muted", guitar, cents: [0, -12, 25, nil, 7, -3], seed: 1)
        assertStrum("guitar, E2 muted", guitar, cents: [nil, -12, 25, -40, 7, -3], seed: 2)
    }

    /// One plucked string: its harmonics land on higher strings' pitches (E2's 3rd and 4th on B3 and E4,
    /// A2's 3rd on E4) but must not read as those strings.
    func testSingleNoteDoesNotReadAsOtherStrings() {
        assertStrum("low E alone", guitar, cents: [5, nil, nil, nil, nil, nil], seed: 1)
        assertStrum("A alone", guitar, cents: [nil, -8, nil, nil, nil, nil], seed: 2)
    }

    // MARK: Which strings of a chord rang (ChordRing)

    /// Strums `shape` on a guitar with string `muted` (its place among the sounding strings, lowest first) silent, and
    /// reads the strum once through the stream: each sounding string's state.
    private func ring(_ shape: String, muted: Int?, seed: UInt64, sampleRate: Double) -> [ChordRing.State]? {
        let midi = Synth.voicing(shape).compactMap { $0 }
        let pitches = midi.map(StrumSynth.midiHz)
        let tuner = PolyTuner(strings: pitches, sampleRate: sampleRate)
        var cents = [Double?](repeating: 0, count: midi.count)
        if let muted { cents[muted] = nil }
        let duration = 0.3 + tuner.settle + tuner.window + 0.15
        let signal = StrumSynth.strum(StrumSynth.detuned(midi, cents), sampleRate: sampleRate, duration: duration, seed: seed)
        let readings = feed(signal, to: tuner, chunk: 512)
        XCTAssertEqual(readings.count, 1, "\(shape) at \(Int(sampleRate)) Hz, seed \(seed)")
        return readings.first.map { ChordRing.states($0, pitches: pitches) }
    }

    /// A clean strum of an open chord leaves no string called silent: strings on another string's octave may be unsure,
    /// never dead.
    func testCleanChordsHaveNoSilentString() {
        for (name, shape) in [("C", "x32010"), ("Em", "022000"), ("Am", "x02210"), ("G", "320003"), ("D", "xx0232")] {
            for rate in [44100.0, 48000.0] {
                for seed: UInt64 in [1, 2] {
                    guard let states = ring(shape, muted: nil, seed: seed, sampleRate: rate) else { continue }
                    XCTAssertFalse(states.contains(.dead), "\(name) at \(Int(rate)) Hz, seed \(seed): \(states)")
                }
            }
        }
    }

    /// A string muted by a leaning finger is named, and only that one: C's open G (finger 2 on the D string touching
    /// it), E minor's G, A minor's C, D's F♯.
    func testAMutedStringIsNamed() {
        let cases: [(name: String, shape: String, muted: Int)] = [("C", "x32010", 2), ("Em", "022000", 3), ("Am", "x02210", 3), ("D", "xx0232", 3)]
        for (name, shape, muted) in cases {
            for rate in [44100.0, 48000.0] {
                for seed: UInt64 in [1, 2] {
                    guard let states = ring(shape, muted: muted, seed: seed, sampleRate: rate) else { continue }
                    let dead = states.indices.filter { states[$0] == .dead }
                    XCTAssertEqual(dead, [muted], "\(name) at \(Int(rate)) Hz, seed \(seed): \(states)")
                }
            }
        }
    }

    /// One strum can't hear a string that sits on another's octave (E minor's E3, an octave over the low E): muted or
    /// not, it is never called dead.
    func testAStringOnAnOctaveIsNeverCalledDead() {
        for rate in [44100.0, 48000.0] {
            guard let states = ring("022000", muted: 2, seed: 1, sampleRate: rate) else { continue }
            XCTAssertNotEqual(states[2], .dead, "\(states)")
            XCTAssertFalse(states.contains(.dead), "\(states)")
        }
    }

    func testClearStringsAreTheOnesOffEveryOtherStringsHarmonics() {
        let em = Synth.voicing("022000").compactMap { $0 }.map(StrumSynth.midiHz)
        // E2 B2 E3 G3 B3 E4: E3, B3 and E4 sit on the low E's harmonics; E2, B2 and G3 are clear.
        XCTAssertEqual(em.indices.map { ChordRing.isClear($0, among: em) }, [true, true, false, true, false, false])
        XCTAssertFalse(ChordRing.isClear(1, among: [220, 220]), "a unison")
        XCTAssertFalse(ChordRing.isClear(3, among: [220]), "out of range")
    }

    func testUnisonCoursesShareOneReading() {
        assertStrum("mandolin G3 D4 A4 E5 courses", mandolin, cents: [5, 5, -10, -10, 15, 15, -3, -3], seed: 1)
    }

    func testSilenceAndNoiseGiveNoReading() {
        let tuner = PolyTuner(strings: guitar.map(StrumSynth.midiHz))
        XCTAssertTrue(feed([Float](repeating: 0, count: 72000), to: tuner, chunk: 512).isEmpty)
        let noise = Synth.whiteNoise(count: 72000, level: 0.002, seed: 5)
        XCTAssertTrue(feed(noise, to: tuner, chunk: 512).isEmpty)
        XCTAssertNil(tuner.analyze(noise))
        XCTAssertNil(tuner.analyze([Float](repeating: 0, count: 100)), "shorter than a window")
    }

    /// A second strum, with B3 retuned while the first still rings, gives a second reading.
    func testEachStrumGivesItsOwnReading() {
        let rate = 48000.0
        let tuner = PolyTuner(strings: guitar.map(StrumSynth.midiHz), sampleRate: rate)
        var signal = StrumSynth.strum(StrumSynth.detuned(guitar, [0, -12, 25, -40, 7, -3]), sampleRate: rate, duration: 3, seed: 1)
        let second = StrumSynth.strum(StrumSynth.detuned(guitar, [0, -12, 25, -40, -20, -3]), sampleRate: rate, duration: 1.4, seed: 2)
        let offset = Int(1.6 * rate)
        for i in second.indices where offset + i < signal.count { signal[offset + i] += second[i] }
        let readings = feed(signal, to: tuner, chunk: 512)
        XCTAssertEqual(readings.count, 2)
        guard readings.count == 2 else { return }
        XCTAssertEqual(readings[0].onsetTime, 0.3, accuracy: 0.03)
        XCTAssertEqual(readings[1].onsetTime, 1.9, accuracy: 0.03)
        XCTAssertEqual(readings[0].strings[4].cents ?? 99, 7, accuracy: 3)
        for (index, expected) in [0.0, -12, 25, -40, -20, -3].enumerated() {
            XCTAssertEqual(readings[1].strings[index].cents ?? 99, expected, accuracy: 3, "second strum, string \(index + 1)")
        }
        XCTAssertTrue(readings[1].allInTune(within: 41))
        XCTAssertFalse(readings[1].allInTune(within: 5))
    }

    func testWindowDefaultsAndReadingValues() {
        XCTAssertEqual(PolyTuner.defaultWindow(lowestHz: 82.4), 0.5)
        XCTAssertEqual(PolyTuner.defaultWindow(lowestHz: 41.2), 0.7)
        XCTAssertEqual(PolyTuner(strings: guitar.map(StrumSynth.midiHz), sampleRate: 44100).windowLength, 22050)
        let flat = PolyReading.StringReading(index: 0, targetHz: 440, frequencyHz: 440 * PitchMath.ratio(cents: -10), confidence: 2,
                                             evidence: .fundamental)
        XCTAssertEqual(flat.cents ?? 0, -10, accuracy: 1e-9)
        XCTAssertEqual(flat.confidence, 1)
        XCTAssertTrue(flat.isHeard)
        let silent = PolyReading.StringReading(index: 1, targetHz: 440, frequencyHz: nil, confidence: 0.9, evidence: .shared)
        XCTAssertFalse(silent.isHeard)
        XCTAssertNil(silent.cents)
        XCTAssertNil(silent.evidence)
        XCTAssertEqual(silent.confidence, 0)
        XCTAssertEqual(PolyReading(strings: [flat, silent], onsetTime: 0, levelDbfs: -30).heardCount, 1)
    }

    /// The closed-form partial model matches a direct sum of the windowed, decaying sinusoid.
    func testPartialModelMatchesDirectTransform() {
        let length = 4000, size = 16384, rate = 48000.0
        let model = PolyTuner.PartialModel(length: length, size: size, sampleRate: rate)
        let f = 441.37, alpha = 3.0
        var re = [Double](repeating: 0, count: 8)
        var im = [Double](repeating: 0, count: 8)
        let k0 = Int(f * Double(size) / rate) - 3
        model.write(frequency: f, damping: alpha, k0: k0, count: 8, re: &re, im: &im, offset: 0)
        for k in 0..<8 {
            let theta = Double(k0 + k) * rate / Double(size)
            var sumRe = 0.0, sumIm = 0.0
            for n in 0..<length {
                let w = 0.5 - 0.5 * cos(2 * Double.pi * (Double(n) + 0.5) / Double(length))
                let amplitude = w * exp(-alpha * Double(n) / rate)
                let phase = 2 * Double.pi * (f - theta) * Double(n) / rate
                sumRe += amplitude * cos(phase)
                sumIm += amplitude * sin(phase)
            }
            XCTAssertEqual(re[k], sumRe, accuracy: 1e-6 * Double(length))
            XCTAssertEqual(im[k], sumIm, accuracy: 1e-6 * Double(length))
            let single = model.value(frequency: f, damping: alpha, at: theta)
            XCTAssertEqual(single.re, sumRe, accuracy: 1e-6 * Double(length))
            XCTAssertEqual(single.im, sumIm, accuracy: 1e-6 * Double(length))
        }
    }
}
