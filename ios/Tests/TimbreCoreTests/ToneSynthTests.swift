import XCTest
@testable import TimbreCore

final class ToneSynthTests: XCTestCase {
    private let rate = 48000.0

    private func rms(_ samples: ArraySlice<Float>) -> Double {
        guard !samples.isEmpty else { return 0 }
        return (samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count)).squareRoot()
    }

    private func peak(_ samples: [Float]) -> Float { samples.reduce(0) { max($0, abs($1)) } }

    /// The strongest frequency within half a percent of `hz` (Hann-windowed DTFT, golden-section search).
    private func peakFrequency(_ samples: ArraySlice<Float>, near hz: Double) -> Double {
        let values = Array(samples)
        let n = values.count
        let window = (0..<n).map { 0.5 - 0.5 * cos(2 * Double.pi * Double($0) / Double(max(1, n - 1))) }
        func power(_ frequency: Double) -> Double {
            let step = 2 * Double.pi * frequency / rate
            var re = 0.0, im = 0.0
            for i in 0..<n {
                let v = Double(values[i]) * window[i]
                re += v * cos(step * Double(i)); im -= v * sin(step * Double(i))
            }
            return re * re + im * im
        }
        var low = hz * 0.995, high = hz * 1.005
        let golden = (5.0.squareRoot() - 1) / 2
        var c = high - golden * (high - low), d = low + golden * (high - low)
        var pc = power(c), pd = power(d)
        for _ in 0..<36 {
            if pc > pd { high = d; d = c; pd = pc; c = high - golden * (high - low); pc = power(c) }
            else { low = c; c = d; pc = pd; d = low + golden * (high - low); pd = power(d) }
        }
        return (low + high) / 2
    }

    private func cents(_ measured: Double, _ expected: Double) -> Double { 1200 * log2(measured / expected) }

    func testEveryCatalogueInstrumentAndCourseHasAVoice() throws {
        let catalog = try Catalog()
        for instrument in catalog.instruments {
            XCTAssertNotNil(InstrumentVoice(instrumentId: instrument.id), instrument.id)
            if instrument.familyId == "bowed_strings" { XCTAssertEqual(InstrumentVoice(instrument: instrument).kind, .sustained, instrument.id) }
            if instrument.familyId == "guitar" || instrument.familyId == "ukulele" || instrument.familyId == "mandolin" {
                XCTAssertEqual(InstrumentVoice(instrument: instrument).kind, .plucked, instrument.id)
            }
        }
        XCTAssertEqual(InstrumentVoice(instrumentId: "guitar.acoustic.6"), .guitar)
        XCTAssertEqual(InstrumentVoice(instrumentId: "bass.electric.4"), .bass)
        XCTAssertEqual(InstrumentVoice(instrumentId: "banjo.five.5"), .banjo)
        XCTAssertEqual(InstrumentVoice(instrumentId: "violin.standard.4"), .violin)
        XCTAssertEqual(InstrumentVoice(instrumentId: "bass.double.4"), .cello)
        XCTAssertEqual(InstrumentVoice(instrumentId: "voice"), .voice)
        XCTAssertNil(InstrumentVoice(instrumentId: nil))
        XCTAssertNil(InstrumentVoice(instrumentId: ""))
        XCTAssertEqual(InstrumentVoice.family("winds").kind, .sustained)
    }

    func testEveryVoiceRendersFiniteBoundedAndSilentAtTheEnd() {
        for voice in InstrumentVoice.allCases {
            let chord = ToneSynth.phrase([82.41, 123.47, 164.81, 207.65, 246.94, 329.63], together: true, noteMs: 1900, gapMs: 0, voice: voice, rate: rate)
            let notes = ToneSynth.phrase([196, 246.94, 293.66], together: false, noteMs: 380, gapMs: 30, voice: voice, rate: rate)
            for samples in [chord, notes] {
                XCTAssertTrue(samples.allSatisfy(\.isFinite), "\(voice)")
                XCTAssertLessThanOrEqual(peak(samples), 0.5 + 1e-4, "\(voice)")
                XCTAssertGreaterThan(peak(samples), 0.3, "\(voice)")
                XCTAssertLessThan(abs(samples.last ?? 1), 1e-3, "\(voice)")
            }
            XCTAssertEqual(chord.count, 91_200, "\(voice)")
            XCTAssertEqual(notes.count, 3 * 19_680, "\(voice)")
        }
    }

    func testPluckedChordStrumsLowToHighAndDecays() {
        let chord: [Double] = [329.63, 82.41, 123.47, 164.81, 207.65, 246.94]
        let strum = ToneSynth.phrase(chord, together: true, noteMs: 1900, gapMs: 0, voice: .guitar, rate: rate)
        // Before the second string (24 ± 4 ms), only the lowest one sounds, whatever order the notes came in.
        let early = Int(0.019 * rate)
        func correlation(_ a: ArraySlice<Float>, _ b: ArraySlice<Float>) -> Double {
            var ab = 0.0, aa = 0.0, bb = 0.0
            for (x, y) in zip(a, b) { ab += Double(x) * Double(y); aa += Double(x) * Double(x); bb += Double(y) * Double(y) }
            return ab / max(1e-12, (aa * bb).squareRoot())
        }
        let low = ToneSynth.phrase([82.41], together: true, noteMs: 1900, gapMs: 0, voice: .guitar, rate: rate)
        let high = ToneSynth.phrase([329.63], together: true, noteMs: 1900, gapMs: 0, voice: .guitar, rate: rate)
        XCTAssertGreaterThan(correlation(strum[0..<early], low[0..<early]), 0.999)
        XCTAssertLessThan(correlation(strum[0..<early], high[0..<early]), 0.5)
        // It rings, then fades: well down after a second, not cut off.
        let start = rms(strum[0..<Int(0.1 * rate)])
        let later = rms(strum[Int(1.2 * rate)..<Int(1.3 * rate)])
        XCTAssertGreaterThan(later, 0.002)
        XCTAssertGreaterThan(start / later, 3)
    }

    func testBanjoIsShorterThanGuitarAndBassRingsLongest() {
        func decay(_ voice: InstrumentVoice, _ hz: Double) -> Double {
            let note = ToneSynth.phrase([hz], together: false, noteMs: 1500, gapMs: 0, voice: voice, rate: rate)
            return rms(note[Int(0.6 * rate)..<Int(0.8 * rate)]) / rms(note[0..<Int(0.2 * rate)])
        }
        XCTAssertLessThan(decay(.banjo, 196), decay(.guitar, 196) * 0.5)
        XCTAssertGreaterThan(decay(.bass, 55), decay(.guitar, 55))
    }

    func testNotesInTurnLeaveTheirGapsSilent() {
        let notes = ToneSynth.phrase([196, 246.94, 293.66], together: false, noteMs: 380, gapMs: 30, voice: .guitar, rate: rate)
        let step = 19_680   // 410 ms at 48 kHz
        for index in 1..<3 {
            let gap = notes[(index * step - Int(0.025 * rate))..<(index * step)]
            XCTAssertLessThan(gap.reduce(Float(0)) { max($0, abs($1)) }, 0.005)
        }
    }

    func testReferencesSoundAtExactlyTheirPitch() {
        let cases: [(InstrumentVoice, Double)] = [(.guitar, 82.41), (.guitar, 329.63), (.bass, 41.2), (.banjo, 293.66),
                                                  (.violin, 196), (.cello, 65.41), (.voice, 220), (.mallet, 440)]
        for (voice, hz) in cases {
            let tone = ToneSynth.reference(hz, durationMs: 2000, voice: voice, rate: rate)
            XCTAssertNil(tone.loopStart)
            XCTAssertEqual(tone.frames.count, Int(2 * rate))
            XCTAssertTrue(tone.frames.allSatisfy(\.isFinite))
            let measured = peakFrequency(tone.frames[Int(0.2 * rate)..<Int(0.8 * rate)], near: hz)
            XCTAssertLessThan(abs(cents(measured, hz)), 0.5, "\(voice) \(hz)")
        }
    }

    func testSustainedVoiceHoldsSteadyWithoutVibratoOnTheReference() {
        let tone = ToneSynth.reference(440, durationMs: 2000, voice: .violin, rate: rate).frames
        // Equal loudness through the sustain: no swell or tremolo from a vibrato.
        let levels = stride(from: 0.4, to: 1.7, by: 0.1).map { rms(tone[Int($0 * rate)..<Int(($0 + 0.1) * rate)]) }
        XCTAssertLessThan((levels.max() ?? 0) / (levels.min() ?? 1), 1.05)
        // The attack is soft (no click) and the release fades.
        XCTAssertLessThan(rms(tone[0..<Int(0.01 * rate)]), rms(tone[Int(0.5 * rate)..<Int(0.51 * rate)]) * 0.2)
        XCTAssertLessThan(abs(tone.last ?? 1), 1e-3)
    }

    func testContinuousReferencesLoop() {
        let rateInt = Int(rate)
        let bowed = ToneSynth.render(ToneRequest(frequencies: [196], kind: .reference(durationMs: 0), voice: .violin, sampleRate: rateInt))
        let loop = bowed.loopStart
        XCTAssertEqual(loop, rateInt)
        let frames = bowed.frames
        if let loop {
            // The loop's end runs into its start like any neighbouring samples.
            let largestStep = zip(frames[loop...], frames[(loop + 1)...]).reduce(Float(0)) { max($0, abs($1.1 - $1.0)) }
            XCTAssertLessThan(abs(frames[frames.count - 1] - frames[loop]), largestStep)
        }
        let plucked = ToneSynth.render(ToneRequest(frequencies: [196], kind: .reference(durationMs: 0), voice: .guitar, sampleRate: rateInt))
        XCTAssertEqual(plucked.loopStart, 0)
        XCTAssertEqual(Double(plucked.count) / rate, ToneSynth.repluckInterval(196, voice: .guitar), accuracy: 0.001)
        XCTAssertLessThanOrEqual(ToneSynth.repluckInterval(330, voice: .banjo), ToneSynth.repluckInterval(330, voice: .guitar))
    }

    func testPlayerLoopsAndFadesOutOnStop() {
        let clip = ToneClip(frames: [Float](repeating: 0.25, count: 100), sampleRate: 48000, loopStart: 20)
        let player = ToneClipPlayer(clip: clip)
        for _ in 0..<1000 { XCTAssertEqual(player.nextSample(), 0.25) }
        XCTAssertTrue(player.isPlaying)
        player.stop(fadeFrames: 50)
        var last: Float = 1
        for _ in 0..<60 { last = player.nextSample() }
        XCTAssertEqual(last, 0)
        XCTAssertFalse(player.isPlaying)

        let once = ToneClipPlayer(clip: ToneClip(frames: [0.1, 0.2], sampleRate: 48000))
        XCTAssertEqual(once.nextSample(), 0.1)
        XCTAssertEqual(once.nextSample(), 0.2)
        XCTAssertEqual(once.nextSample(), 0)
        XCTAssertFalse(once.isPlaying)
    }

    func testRendersAreDeterministicAndKeyedByRequest() {
        let request = ToneRequest(frequencies: [110, 164.81, 220], kind: .phrase(together: true, noteMs: 1500, gapMs: 0), voice: .mandolin, sampleRate: 48000)
        XCTAssertEqual(ToneSynth.render(request).frames, ToneSynth.render(request).frames)
        XCTAssertEqual(request.durationMs, 1500)
        XCTAssertEqual(ToneRequest(frequencies: [1, 2, 3], kind: .phrase(together: false, noteMs: 900, gapMs: 150), voice: .guitar, sampleRate: 48000).durationMs, 3150)
        XCTAssertNotEqual(request, request.at(sampleRate: 44100))
        XCTAssertEqual(ToneSynth.render(request.at(sampleRate: 44100)).sampleRate, 44100)
    }
}
