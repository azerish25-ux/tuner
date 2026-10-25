import XCTest
@testable import TimbreCore

/// The recorded instruments (TimbreCore/Audio/SampleLibrary.swift, SampledTones.swift) over the app's own bundle of
/// samples, read straight from the repository (ios/Timbre/Resources/Samples, the folder the app target copies).
final class SampledTonesTests: XCTestCase {
    private let rate = 48000

    private static let samplesFolder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Timbre/Resources/Samples", isDirectory: true)

    /// A fresh library over the bundled samples (nothing decoded yet).
    private func bundled() throws -> SampleLibrary {
        try XCTUnwrap(SampleLibrary(directory: Self.samplesFolder), "Samples/manifest.json should load")
    }

    private func cents(_ measured: Double, _ expected: Double) -> Double { 1200 * log2(measured / expected) }

    /// What the tuner would show: the app's YIN detector over 4096-sample frames (hop 1024) between `from` and `to`
    /// seconds, the median reading. Readings more than 50 cents from `near` (the detector jumping an octave as a string
    /// fades) are left out, as the tuner's smoothing would.
    private func tunerPitch(_ frames: [Float], from: Double, to: Double, near: Double) -> Double? {
        let detector = YinPitchDetector(sampleRate: Double(rate), minFrequency: 25, maxFrequency: 4500)
        var readings: [Double] = []
        var start = Int(from * Double(rate))
        let end = min(frames.count, Int(to * Double(rate)))
        while start + 4096 <= end {
            if let reading = detector.detect(Array(frames[start..<(start + 4096)])), abs(cents(reading.frequencyHz, near)) <= 50 {
                readings.append(reading.frequencyHz)
            }
            start += 1024
        }
        guard !readings.isEmpty else { return nil }
        readings.sort()
        return readings[readings.count / 2]
    }

    /// The strongest frequency within 5 cents of `hz` (Hann-windowed DTFT, golden-section search).
    private func peakFrequency(_ samples: ArraySlice<Float>, near hz: Double) -> Double {
        let values = Array(samples)
        let n = values.count
        let mean = values.reduce(0.0) { $0 + Double($1) } / Double(max(1, n))
        let windowed = (0..<n).map { (Double(values[$0]) - mean) * (0.5 - 0.5 * cos(2 * Double.pi * Double($0) / Double(max(1, n - 1)))) }
        func power(_ frequency: Double) -> Double {
            let step = 2 * Double.pi * frequency / Double(rate)
            var re = 0.0, im = 0.0
            for i in 0..<n {
                re += windowed[i] * cos(step * Double(i)); im -= windowed[i] * sin(step * Double(i))
            }
            return re * re + im * im
        }
        var low = hz * pow(2, -5.0 / 1200), high = hz * pow(2, 5.0 / 1200)
        let golden = (5.0.squareRoot() - 1) / 2
        var c = high - golden * (high - low), d = low + golden * (high - low)
        var pc = power(c), pd = power(d)
        for _ in 0..<32 {
            if pc > pd { high = d; d = c; pd = pc; c = high - golden * (high - low); pc = power(c) }
            else { low = c; c = d; pc = pd; d = low + golden * (high - low); pd = power(d) }
        }
        return (low + high) / 2
    }

    private func peak(_ samples: [Float]) -> Float { samples.reduce(0) { max($0, abs($1)) } }

    // MARK: The bundle

    func testBundledLibraryCoversTheMainInstrumentsAndTheBand() throws {
        let library = try bundled()
        for voice: InstrumentVoice in [.guitar, .bass, .piano, .harp, .mallet, .violin, .cello, .flute, .reed, .brass] {
            XCTAssertNotNil(library.instrument(for: voice), "\(voice)")
        }
        // No CC0 recordings fit these yet: they keep their synthesized voices.
        for voice: InstrumentVoice in [.ukulele, .mandolin, .banjo, .voice] { XCTAssertNil(library.instrument(for: voice), "\(voice)") }
        let kit = try XCTUnwrap(library.instrument(id: "drums"))
        for piece in ["kick", "snare", "hat", "crash"] { XCTAssertTrue(kit.has(piece: piece), piece) }
        XCTAssertNotNil(library.instrument(id: "bass"))
        XCTAssertNotNil(library.instrument(id: "piano"))
        XCTAssertFalse(library.credits.isEmpty)
        XCTAssertTrue(library.credits.allSatisfy { $0.licence == "CC0-1.0" || $0.licence.hasPrefix("CC-BY") })
        // Lazy: opening the library decodes nothing.
        XCTAssertEqual(library.residentBytes, 0)
    }

    func testDecodingIsLazyCappedAndPurgeable() throws {
        let library = try bundled()
        let guitar = try XCTUnwrap(library.instrument(for: .guitar))
        var out = [Float](repeating: 0, count: rate)
        XCTAssertTrue(library.addNote(guitar, hz: 196, velocity: 0.75, into: &out, start: 0, length: rate, rate: Double(rate)))
        let one = library.residentBytes
        XCTAssertGreaterThan(one, 0)
        XCTAssertLessThan(one, 2 << 20, "one zone, not the whole instrument")
        library.capacityBytes = 1 << 20
        library.prewarm(.guitar)
        XCTAssertLessThanOrEqual(library.residentBytes, max(1 << 20, one * 2))
        library.purge()
        XCTAssertEqual(library.residentBytes, 0)
    }

    // MARK: Pitch

    /// The tuner's reference stays exact from recordings: A4 rendered from the nearest zone (pitched by the exact
    /// ratio to its measured fundamental) reads 440 Hz on the app's own detector.
    func testReferenceA4ReadsExactly440OnTheTunersDetector() throws {
        let library = try bundled()
        for voice: InstrumentVoice in [.piano, .guitar, .harp, .mallet, .flute, .reed, .brass] {
            let request = ToneRequest(frequencies: [440], kind: .reference(durationMs: 2000), voice: voice, sampleRate: rate)
            let clip = try XCTUnwrap(SampledTones.render(request, library: library), "\(voice) should play A4 from its recordings")
            let frames = clip.frames
            XCTAssertEqual(frames.count, 2 * rate, "\(voice)")
            XCTAssertNil(clip.loopStart)
            XCTAssertTrue(frames.allSatisfy(\.isFinite), "\(voice)")
            let window = voice.kind == .sustained ? (0.45, 1.45) : (0.12, 1.12)
            let reading = try XCTUnwrap(tunerPitch(frames, from: window.0, to: window.1, near: 440), "\(voice)")
            XCTAssertLessThan(abs(cents(reading, 440)), 1.0, "\(voice): the tuner reads \(reading) Hz")
        }
    }

    /// Every string of a guitar and a bass, and notes between the zones, come out at their exact pitch.
    func testGuitarAndBassReferencesAreExactAcrossTheirRange() throws {
        let library = try bundled()
        let cases: [(InstrumentVoice, [Double])] = [
            (.guitar, [40, 45, 50, 55, 59, 64, 69, 76].map { PitchMath.frequency(midi: $0) }),
            (.bass, [28, 33, 38, 43, 47].map { PitchMath.frequency(midi: $0) }),
            (.guitar, [PitchMath.frequency(midi: 64, reference: 432)]),
        ]
        for (voice, frequencies) in cases {
            for hz in frequencies {
                let request = ToneRequest(frequencies: [hz], kind: .reference(durationMs: 1500), voice: voice, sampleRate: rate)
                let clip = try XCTUnwrap(SampledTones.render(request, library: library), "\(voice) \(hz)")
                let reading = try XCTUnwrap(tunerPitch(clip.frames, from: 0.12, to: 1.12, near: hz), "\(voice) \(hz)")
                XCTAssertLessThan(abs(cents(reading, hz)), 1.0, "\(voice) \(hz): the tuner reads \(reading) Hz")
            }
        }
    }

    /// Exact ratio, without any recording: a zone measured at 437.3 Hz (44.1 kHz) played at 440 and 415.3 Hz (48 kHz).
    func testPitchShiftUsesTheExactRatio() throws {
        let library = try syntheticLibrary(kind: "plucked", hz: 437.3)
        let instrument = try XCTUnwrap(library.instrument(id: "test"))
        for target in [440.0, 415.3, 466.16] {
            var out = [Float](repeating: 0, count: rate)
            XCTAssertTrue(library.addNote(instrument, hz: target, velocity: 0.75, into: &out, start: 0, length: rate, rate: Double(rate)))
            let measured = peakFrequency(out[Int(0.1 * Double(rate))..<Int(0.9 * Double(rate))], near: target)
            XCTAssertLessThan(abs(cents(measured, target)), 0.05, "\(target): \(measured)")
            let reading = try XCTUnwrap(tunerPitch(out, from: 0.1, to: 0.9, near: target))
            XCTAssertLessThan(abs(cents(reading, target)), 0.5, "\(target): tuner \(reading)")
        }
    }

    /// A sustained note held past its recording loops whole periods: no clicks, no gaps, steady level and pitch.
    func testHeldSustainedNoteLoopsSeamlessly() throws {
        let library = try syntheticLibrary(kind: "sustained", hz: 330)
        let instrument = try XCTUnwrap(library.instrument(id: "test"))
        var out = [Float](repeating: 0, count: 5 * rate)
        XCTAssertTrue(library.addNote(instrument, hz: 330, velocity: 0.75, into: &out, start: 0, length: out.count, rate: Double(rate)))
        // The recording lasts 2 s; at 3 and 4 s the loop still sounds at full level.
        func rms(_ from: Double) -> Double {
            let slice = out[Int(from * Double(rate))..<Int((from + 0.1) * Double(rate))]
            return (slice.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(slice.count)).squareRoot()
        }
        XCTAssertGreaterThan(rms(3), rms(1) * 0.8)
        XCTAssertLessThan(rms(3), rms(1) * 1.2)
        XCTAssertGreaterThan(rms(4.2), rms(1) * 0.8)
        // No sample-to-sample jump bigger than the tone itself makes (a seam would).
        let steps = zip(out[rate..<(4 * rate)], out[(rate + 1)..<(4 * rate + 1)]).map { abs($1 - $0) }
        let normal = zip(out[Int(0.5 * Double(rate))..<rate], out[(Int(0.5 * Double(rate)) + 1)..<(rate + 1)]).map { abs($1 - $0) }
        XCTAssertLessThan(steps.max() ?? 1, (normal.max() ?? 0) * 1.3)
        let reading = try XCTUnwrap(tunerPitch(out, from: 2.2, to: 4.4, near: 330))
        XCTAssertLessThan(abs(cents(reading, 330)), 0.5)
        XCTAssertLessThan(abs(out.last ?? 1), 1e-3, "released at its end")
    }

    // MARK: Timing, levels and fallbacks

    func testRecordedPhrasesKeepTheSynthesizersTimingAndLevels() throws {
        let library = try bundled()
        for voice: InstrumentVoice in [.guitar, .bass, .piano, .harp, .mallet, .violin, .cello, .flute, .reed, .brass] {
            // A chord and a little tune in the middle of the instrument's range.
            let range = try XCTUnwrap(library.instrument(for: voice)).coverage
            let middle = Double(range.lowerBound + range.upperBound) / 2
            let pitch = { (offset: Double) in PitchMath.frequency(midi: (middle + offset).rounded()) }
            let chord = ToneRequest(frequencies: [pitch(-5), pitch(-1), pitch(2), pitch(7)], kind: .phrase(together: true, noteMs: 1900, gapMs: 0),
                                    voice: voice, sampleRate: rate)
            let notes = ToneRequest(frequencies: [pitch(0), pitch(4), pitch(7)], kind: .phrase(together: false, noteMs: 380, gapMs: 30),
                                    voice: voice, sampleRate: rate)
            for request in [chord, notes] {
                let clip = try XCTUnwrap(SampledTones.render(request, library: library), "\(voice)")
                let frames = clip.frames
                XCTAssertTrue(frames.allSatisfy(\.isFinite), "\(voice)")
                XCTAssertLessThanOrEqual(peak(frames), 0.5 + 1e-4, "\(voice)")
                XCTAssertGreaterThan(peak(frames), 0.3, "\(voice)")
                XCTAssertLessThan(abs(frames.last ?? 1), 1e-3, "\(voice)")
                // Same lengths as the synthesized voice, so lessons time against them unchanged.
                XCTAssertEqual(frames.count, ToneSynth.render(request).count, "\(voice)")
            }
            let frames = try XCTUnwrap(SampledTones.render(notes, library: library)).frames
            for index in 1..<3 {
                let gap = frames[(index * 19_680 - Int(0.025 * Double(rate)))..<(index * 19_680)]
                XCTAssertLessThan(gap.reduce(Float(0)) { max($0, abs($1)) }, 0.005, "\(voice): the gap stays silent")
            }
        }
    }

    func testFallsBackToSynthesisWhereRecordingsCannotServe() throws {
        let library = try bundled()
        // No recording for the sung voice: synthesized, identical to before.
        let sung = ToneRequest(frequencies: [220], kind: .phrase(together: false, noteMs: 500, gapMs: 0), voice: .voice, sampleRate: rate)
        XCTAssertNil(SampledTones.render(sung, library: library))
        XCTAssertEqual(ToneSynth.render(sung, samples: library).frames, ToneSynth.render(sung).frames)
        // Out of the guitar's range.
        let low = ToneRequest(frequencies: [30], kind: .reference(durationMs: 1000), voice: .guitar, sampleRate: rate)
        XCTAssertNil(SampledTones.render(low, library: library))
        // A bowed reference from vibrato recordings would waver: the steady synthesized one plays instead.
        let bowed = ToneRequest(frequencies: [440], kind: .reference(durationMs: 2000), voice: .violin, sampleRate: rate)
        XCTAssertNil(SampledTones.render(bowed, library: library))
        XCTAssertEqual(ToneSynth.render(bowed, samples: library).frames, ToneSynth.render(bowed).frames)
        // No library at all: the synthesizer, unchanged.
        let strum = ToneRequest(frequencies: [82.41, 110, 146.83], kind: .phrase(together: true, noteMs: 900, gapMs: 0), voice: .guitar, sampleRate: rate)
        XCTAssertEqual(ToneSynth.render(strum, samples: nil).frames, ToneSynth.render(strum).frames)
        XCTAssertNil(SampleLibrary(directory: FileManager.default.temporaryDirectory.appendingPathComponent("no-samples-here")))
    }

    func testContinuousReferencesLoopFromRecordings() throws {
        let library = try bundled()
        let plucked = try XCTUnwrap(SampledTones.render(ToneRequest(frequencies: [196], kind: .reference(durationMs: 0), voice: .guitar, sampleRate: rate), library: library))
        XCTAssertEqual(plucked.loopStart, 0)
        XCTAssertEqual(plucked.count, Int(ToneSynth.repluckInterval(196, voice: .guitar) * Double(rate)))
        let held = try XCTUnwrap(SampledTones.render(ToneRequest(frequencies: [440], kind: .reference(durationMs: 0), voice: .flute, sampleRate: rate), library: library))
        let loop = try XCTUnwrap(held.loopStart)
        XCTAssertEqual(loop, rate)
        let frames = held.frames
        let largestStep = zip(frames[loop...], frames[(loop + 1)...]).reduce(Float(0)) { max($0, abs($1.1 - $1.0)) }
        XCTAssertLessThan(abs(frames[frames.count - 1] - frames[loop]), largestStep * 1.5)
        let reading = try XCTUnwrap(tunerPitch(frames, from: 0.45, to: 1.45, near: 440))
        XCTAssertLessThan(abs(cents(reading, 440)), 1.0)
    }

    // MARK: Helpers

    /// A one-zone library held in memory: two seconds of a decaying (plucked) or steady (sustained, with a loop of
    /// whole periods) harmonic tone at `hz`, recorded at 44.1 kHz.
    private func syntheticLibrary(kind: String, hz: Double) throws -> SampleLibrary {
        let fileRate = 44_100.0
        let count = Int(2 * fileRate)
        var values = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / fileRate
            let envelope = kind == "sustained" ? min(1, t / 0.05) : exp(-t / 0.8) * min(1, t / 0.002)
            var value = 0.0
            for (h, weight) in [(1.0, 1.0), (2.0, 0.5), (3.0, 0.3), (4.0, 0.15)] { value += weight * sin(2 * Double.pi * hz * h * t + h) }
            values[i] = Float(0.4 * envelope * value)
        }
        let periods = (1.0 * hz).rounded()
        let loopEnd = count - Int(0.05 * fileRate)
        let loopStart = loopEnd - Int((periods * fileRate / hz).rounded())
        let loop = kind == "sustained" ? ", \"loop\": [\(loopStart), \(loopEnd)]" : ""
        let json = """
        {"version": 1, "sampleRate": 44100, "format": "test",
         "sources": {"test": {"title": "Test", "author": "Tests", "licence": "CC0-1.0",
                              "licenceURL": "https://creativecommons.org/publicdomain/zero/1.0/",
                              "repo": "https://github.com/example/test", "commit": "0000000000000000000000000000000000000000"}},
         "instruments": [{"id": "test", "title": "Test", "voices": [], "kind": "\(kind)", "release": 0.1, "steady": true,
                          "coverage": [40, 90],
                          "zones": [{"file": "test/a.m4a", "midi": 69, "hz": \(hz), "layer": "mf", "velocity": 0.75, "gain": 1,
                                     "frames": \(count), "mark": 0, "markLevel": 0.1, "source": "test"\(loop)}]}]}
        """
        let manifest = try JSONDecoder().decode(SampleManifest.self, from: Data(json.utf8))
        return SampleLibrary(directory: FileManager.default.temporaryDirectory, manifest: manifest,
                             buffers: ["test/a.m4a": SampleBuffer(rate: fileRate, values: values)])
    }
}
