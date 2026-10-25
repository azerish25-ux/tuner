import AVFoundation
import XCTest
@testable import TimbreCore

/// Real recordings held to the accuracy the app claims: the tuner on single strings, strum-to-tune, each stroke's
/// chord and the silent-string check. Every other DSP test runs on synthesized signals; these run on the owner's
/// corpus of real instruments, phones and rooms, and skip until it lands.
///
/// The corpus lives in `Tests/Fixtures/RealWorld/`: audio files (anything `AVAudioFile` reads: WAV, CAF, AIFF, M4A;
/// mono or stereo, any sample rate) and `expected.json`, which holds the budgets and lists each clip with what is
/// known to be in it:
///
/// ```
/// { "version": 1,
///   "budgets": { "noteMedianCents": 0.5, "noteSettleSeconds": 0.25, "strumCents": 2.0, "strumSeconds": 0.85,
///                "chordPrecision": 0.95, "chordRecall": 0.85, "ringFalseSilent": 0 },
///   "clips": [
///     { "file": "guitar/e2-iphone15-quiet.wav", "kind": "note", "midi": 40, "cents": -3.2, "onset": 0.41,
///       "device": "iPhone 15", "mic": "built-in", "room": "quiet" },
///     { "file": "guitar/strum-detuned.wav", "kind": "strum", "strings": [40, 45, 50, 55, 59, 64],
///       "stringCents": [0, -12.5, 3.1, 0.4, -7.8, 1.2] },
///     { "file": "guitar/c-strums.wav", "kind": "chord", "played": "C", "targets": ["C", "Am", "G", "F"] },
///     { "file": "guitar/body-taps.wav", "kind": "chord", "played": null, "targets": ["C", "G"] },
///     { "file": "guitar/c-string3-muted.wav", "kind": "ring", "shape": "x32010", "silent": [3] }
///   ] }
/// ```
/// - `note`: one plucked string. `midi` plus `cents` is its true pitch (measured with a reference tuner); `onset`, in
///   seconds, where it starts (found by the onset detector when left out). Budgets: the median error from 0.3 s to
///   1.3 s after the onset, and the median time to the first stable reading (the lock's hold comes after that).
/// - `strum`: every open string at once. `strings` the open strings' MIDI notes, lowest first; `stringCents` each
///   one's true offset. Budgets: every string within `strumCents`, read within `strumSeconds` of the strum.
/// - `chord`: strokes of one chord (`played`), or of none (`played` null: taps on the body, muted strums). Each stroke
///   is judged against every chord in `targets`, so wrong chords turned away count as much as right ones accepted.
///   Budgets: precision (a stroke accepted as a chord really was it) and recall (the right chord accepted).
/// - `ring`: one strum of `shape` (frets lowest string first, "x" muted, on `tuning`, standard guitar by default) with
///   the strings numbered in `silent` (1 the thinnest) muted on purpose, empty for a clean strum. Budget: strings
///   called silent that rang, across the corpus.
/// `device`, `mic` and `room` are free text, printed with each clip's result.
final class RealWorldAccuracyTests: XCTestCase {
    private struct Corpus: Decodable {
        let version: Int
        let budgets: Budgets
        let clips: [Clip]
    }

    private struct Budgets: Decodable {
        let noteMedianCents: Double
        let noteSettleSeconds: Double
        let strumCents: Double
        let strumSeconds: Double
        let chordPrecision: Double
        let chordRecall: Double
        let ringFalseSilent: Int
    }

    private struct Clip: Decodable {
        let file: String
        let kind: String
        var midi: Int?
        var cents: Double?
        var onset: Double?
        var strings: [Int]?
        var stringCents: [Double]?
        var played: String?
        var targets: [String]?
        var shape: String?
        var tuning: [Int]?
        var silent: [Int]?
        var device: String?
        var mic: String?
        var room: String?

        var label: String { [file, device, mic, room].compactMap { $0 }.joined(separator: " · ") }
    }

    private struct Recording {
        let clip: Clip
        let samples: [Float]
        let rate: Double
    }

    private struct CorpusError: Error, CustomStringConvertible {
        let description: String
    }

    private static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/RealWorld", isDirectory: true)

    /// The budgets and the recordings of one kind that are present; skips without any.
    private func corpus(_ kind: String) throws -> (budgets: Budgets, recordings: [Recording]) {
        let manifest = Self.folder.appendingPathComponent("expected.json")
        guard let data = try? Data(contentsOf: manifest) else { throw XCTSkip("No real-world corpus at \(manifest.path)") }
        let corpus = try JSONDecoder().decode(Corpus.self, from: data)
        var recordings: [Recording] = []
        for clip in corpus.clips where clip.kind == kind {
            let url = Self.folder.appendingPathComponent(clip.file)
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("Real-world corpus: \(clip.file) is listed but not present")
                continue
            }
            let audio = try Self.read(url)
            recordings.append(Recording(clip: clip, samples: audio.samples, rate: audio.rate))
        }
        if recordings.isEmpty { throw XCTSkip("No \(kind) recordings in the real-world corpus yet") }
        return (corpus.budgets, recordings)
    }

    /// The file as mono samples at its own rate.
    private static func read(_ url: URL) throws -> (samples: [Float], rate: Double) {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw CorpusError(description: "\(url.lastPathComponent): no buffer")
        }
        try file.read(into: buffer)
        guard let channels = buffer.floatChannelData else { throw CorpusError(description: "\(url.lastPathComponent): not float audio") }
        let frames = Int(buffer.frameLength), count = Int(format.channelCount)
        var mono = [Float](repeating: 0, count: frames)
        for channel in 0..<count {
            for i in 0..<frames { mono[i] += channels[channel][i] / Float(count) }
        }
        return (mono, format.sampleRate)
    }

    private static func firstOnset(_ samples: [Float], rate: Double) -> Double? {
        OnsetDetector(sampleRate: rate).process(samples).first
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }

    // MARK: The tuner on one string

    func testSingleStringsReadWithinBudget() throws {
        let (budgets, recordings) = try corpus("note")
        var medians: [Double] = []
        var settles: [Double] = []
        for recording in recordings {
            let clip = recording.clip, rate = recording.rate, samples = recording.samples
            guard let midi = clip.midi else { XCTFail("\(clip.file): a note clip needs its midi"); continue }
            let truth = clip.cents ?? 0
            let target = PitchMath.frequency(midi: Double(midi))
            let onset = clip.onset ?? Self.firstOnset(samples, rate: rate) ?? 0
            let window = AnalysisWindowPolicy.windowSizeForTuningRange(minFrequencyHz: target / 1.12, sampleRateHz: Int(rate))
            let detector = YinPitchDetector(sampleRate: rate, minFrequency: target / 1.12 / 1.12, maxFrequency: target * 2.5)
            let stability = StabilityTracker()
            // A reading every 20 ms, about the tuner's own rate.
            let hop = max(1, Int(rate / 50))
            var errors: [Double] = []
            var settled: Double?
            var start = max(0, Int(onset * rate))
            while start + window <= samples.count {
                let time = Double(start + window) / rate - onset
                let reading = detector.detect(Array(samples[start..<(start + window)]))
                let heard = reading.flatMap { $0.confidence >= 0.75 ? $0.frequencyHz : nil }
                let error = heard.map { abs(PitchMath.cents(target: target, measured: $0) - truth) }
                if stability.update(heard), settled == nil, let error, error <= InTuneRule.bandCents { settled = time }
                if let error, time >= 0.3, time <= 1.3 { errors.append(error) }
                start += hop
            }
            guard let median = Self.median(errors) else { XCTFail("\(clip.label): no reading"); continue }
            medians.append(median)
            if let settled { settles.append(settled) } else { XCTFail("\(clip.label): never settled") }
            print("Real-world note \(clip.label): median error \(String(format: "%.2f", median)) ¢, settled in "
                  + (settled.map { "\(Int(($0 * 1000).rounded())) ms" } ?? "never"))
        }
        if let median = Self.median(medians) { XCTAssertLessThanOrEqual(median, budgets.noteMedianCents, "median error across the corpus") }
        if let settle = Self.median(settles) { XCTAssertLessThanOrEqual(settle, budgets.noteSettleSeconds, "median time to a steady reading") }
    }

    // MARK: Strum to tune

    func testStrumsReadEveryStringWithinBudget() throws {
        let (budgets, recordings) = try corpus("strum")
        for recording in recordings {
            let clip = recording.clip
            guard let strings = clip.strings, let truth = clip.stringCents, truth.count == strings.count, !strings.isEmpty else {
                XCTFail("\(clip.file): a strum clip needs its strings and their cents")
                continue
            }
            let tuner = PolyTuner(strings: strings.map { PitchMath.frequency(midi: Double($0)) }, sampleRate: recording.rate)
            guard let found = Self.firstReading(recording.samples, rate: recording.rate, tuner: tuner) else {
                XCTFail("\(clip.label): no reading")
                continue
            }
            let delay = found.at - found.reading.onsetTime
            XCTAssertLessThanOrEqual(delay, budgets.strumSeconds, "\(clip.label): read \(delay) s after the strum")
            for (k, string) in found.reading.strings.enumerated() {
                let number = strings.count - k
                guard let cents = string.cents else { XCTFail("\(clip.label): string \(number) not heard"); continue }
                XCTAssertEqual(cents, truth[k], accuracy: budgets.strumCents, "\(clip.label): string \(number)")
            }
            print("Real-world strum \(clip.label): \(found.reading.strings.map { $0.cents.map { String(format: "%.1f", $0) } ?? "-" })")
        }
    }

    /// The tuner's first reading and when it came (seconds of audio fed).
    private static func firstReading(_ samples: [Float], rate: Double, tuner: PolyTuner) -> (reading: PolyReading, at: Double)? {
        var start = 0
        while start < samples.count {
            let end = min(samples.count, start + 512)
            if let reading = tuner.feed(Array(samples[start..<end])) { return (reading, Double(end) / rate) }
            start = end
        }
        return nil
    }

    // MARK: Each stroke's chord

    func testChordStrokesAreJudgedWithinBudget() throws {
        let (budgets, recordings) = try corpus("chord")
        var accepted = 0, acceptedWrongly = 0, owed = 0
        for recording in recordings {
            let clip = recording.clip
            let played = clip.played.flatMap { ChordTarget(symbol: $0) }
            let targets = (clip.targets ?? [clip.played].compactMap { $0 }).compactMap { ChordTarget(symbol: $0) }
            let reader = StrokeChords(sampleRate: recording.rate)
            var strokes: [StrokeChords.Stroke] = []
            var start = 0
            while start < recording.samples.count {
                let end = min(recording.samples.count, start + 1024)
                strokes += reader.feed(Array(recording.samples[start..<end])).strokes
                start = end
            }
            XCTAssertFalse(strokes.isEmpty, "\(clip.label): no strokes heard")
            for stroke in strokes {
                for target in targets {
                    let right = played.map { $0.pitchClasses == target.pitchClasses } ?? false
                    let passed = stroke.chord?.matches(target) ?? false
                    if right { owed += 1 }
                    if passed && right { accepted += 1 }
                    if passed && !right { acceptedWrongly += 1 }
                }
            }
            print("Real-world chord \(clip.label): \(strokes.map { $0.chord?.symbol ?? "-" }.joined(separator: " "))")
        }
        let precision = Double(accepted) / Double(max(1, accepted + acceptedWrongly))
        print("Real-world chords: precision \(String(format: "%.3f", precision)), \(accepted) right of \(owed) owed")
        XCTAssertGreaterThanOrEqual(precision, budgets.chordPrecision)
        if owed > 0 { XCTAssertGreaterThanOrEqual(Double(accepted) / Double(owed), budgets.chordRecall) }
    }

    // MARK: Which strings rang

    func testSilentStringsAreNamedWithoutFalseAccusations() throws {
        let (budgets, recordings) = try corpus("ring")
        var falseSilent = 0, named = 0, muted = 0
        for recording in recordings {
            let clip = recording.clip
            guard let shape = clip.shape else { XCTFail("\(clip.file): a ring clip needs its shape"); continue }
            let frets = Synth.voicing(shape, tuning: clip.tuning ?? Synth.guitar)
            let sounding = frets.indices.filter { frets[$0] != nil }
            let pitches = sounding.compactMap { frets[$0] }.map { PitchMath.frequency(midi: Double($0)) }
            guard !pitches.isEmpty else { continue }
            let tuner = PolyTuner(strings: pitches, sampleRate: recording.rate)
            guard let found = Self.firstReading(recording.samples, rate: recording.rate, tuner: tuner) else {
                XCTFail("\(clip.label): no reading")
                continue
            }
            let silent = Set(clip.silent ?? [])
            muted += silent.count
            let states = ChordRing.states(found.reading, pitches: pitches)
            for (k, state) in states.enumerated() where state == .dead {
                let number = frets.count - sounding[k]
                if silent.contains(number) { named += 1 } else { falseSilent += 1 }
            }
            print("Real-world ring \(clip.label): \(states.map(\.rawValue))")
        }
        print("Real-world rings: \(named) of \(muted) muted strings named, \(falseSilent) called silent that rang")
        XCTAssertLessThanOrEqual(falseSilent, budgets.ringFalseSilent)
    }
}
