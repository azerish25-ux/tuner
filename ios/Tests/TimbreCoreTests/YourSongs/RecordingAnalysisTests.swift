import XCTest
@testable import TimbreCore

final class RecordingAnalysisTests: XCTestCase {
    private let frameRate = 44100.0 / 512

    /// An onset envelope: a little noise, a strong onset on each beat (strongest on the bar's first), and a weaker
    /// off-beat after every other beat.
    private func envelope(bpm: Double, seconds: Double = 30, first: Double = 0.73, seed: UInt64 = 7) -> [Double] {
        var rng = TestRandom(seed: seed)
        let count = Int(seconds * frameRate)
        var out = (0..<count).map { _ in rng.uniform(0, 0.05) }
        let period = 60 / bpm
        var time = first
        var beat = 0
        while time < seconds - 0.1 {
            let index = Int((time * frameRate).rounded())
            if index < count { out[index] += beat % 4 == 0 ? 1 : 0.6 }
            let offbeat = Int(((time + period / 2) * frameRate).rounded())
            if beat % 2 == 1 && offbeat < count { out[offbeat] += 0.3 }
            time += period
            beat += 1
        }
        return out
    }

    func testTempoAndBeatsFromAnEnvelope() throws {
        for bpm in [72.0, 100, 128, 140] {
            let onsets = envelope(bpm: bpm)
            let estimate = try XCTUnwrap(TempoEstimator.estimate(onsets, frameRate: frameRate), "\(bpm)")
            XCTAssertEqual(estimate, bpm, accuracy: 1.5, "\(bpm)")
            let frames = BeatTracker.track(onsets, frameRate: frameRate, bpm: estimate)
            let times = frames.map { Double($0) / frameRate }
            XCTAssertGreaterThan(times.count, Int(bpm * 0.4), "\(bpm): nearly every beat of 30 s")
            XCTAssertEqual(try XCTUnwrap(BeatTracker.bpm(of: times)), bpm, accuracy: 0.5, "\(bpm)")
            XCTAssertEqual(try XCTUnwrap(times.first), 0.73, accuracy: 0.02, "\(bpm): the first beat")
            for (a, b) in zip(times, times.dropFirst()) {
                XCTAssertEqual(b - a, 60 / bpm, accuracy: 0.03, "\(bpm): a steady gap")
            }
        }
    }

    func testTempoOfAClickTrack() throws {
        let rate = 44100.0
        var rng = TestRandom(seed: 3)
        var samples = [Double](repeating: 0, count: Int(12 * rate))
        var time = 0.4
        var beat = 0
        while time < 11.8 {
            Synth.click(at: time, amplitude: beat % 4 == 0 ? 0.5 : 0.3, into: &samples, sampleRate: rate, rng: &rng)
            time += 0.6
            beat += 1
        }
        Synth.addNoise(&samples, level: 0.001, rng: &rng)
        let analyzer = try XCTUnwrap(RecordingAnalyzer(sampleRate: rate))
        // Fed as a file is read: in uneven chunks.
        let floats = Synth.floats(samples)
        var index = 0
        var chunk = 3000
        while index < floats.count {
            analyzer.feed(Array(floats[index..<min(floats.count, index + chunk)]))
            index += chunk
            chunk = chunk == 3000 ? 7777 : 3000
        }
        let analysis = try XCTUnwrap(analyzer.finish())
        XCTAssertEqual(analysis.bpm, 100, accuracy: 2)
        XCTAssertEqual(analysis.duration, 12, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(analysis.beats.count, 16)
    }

    func testChordsBarByBar() throws {
        let rate = 44100.0
        let progression = ["320003", "xx0232", "022000", "x32010", "320003"]  // G D Em C G, a bar each
        let beat = 0.6
        var rng = TestRandom(seed: 11)
        var samples = [Double](repeating: 0, count: Int((0.5 + Double(progression.count * 4) * beat + 1) * rate))
        for (bar, shape) in progression.enumerated() {
            let notes = Synth.voicing(shape)
            for step in 0..<4 {
                let start = 0.5 + Double(bar * 4 + step) * beat
                var k = 0
                for note in notes {
                    guard let note else { continue }
                    Synth.pluck(note, at: start + Double(k) * 0.01, into: &samples, sampleRate: rate, rng: &rng,
                                level: step == 0 ? 0.9 : 0.7, decayScale: 5)
                    k += 1
                }
            }
        }
        let peak = samples.map { abs($0) }.max() ?? 1
        samples = samples.map { $0 / peak * 0.3 }
        Synth.addNoise(&samples, level: 0.002, rng: &rng)
        let analyzer = try XCTUnwrap(RecordingAnalyzer(sampleRate: rate))
        analyzer.feed(Synth.floats(samples))
        let analysis = try XCTUnwrap(analyzer.finish(beatsPerBar: 4))
        XCTAssertEqual(analysis.bpm, 100, accuracy: 3)
        let heard = analysis.bars.compactMap { $0.chords.first ?? nil }
        let joined = heard.joined(separator: " ")
        XCTAssertTrue(joined.contains("G D Em C"), "heard \(joined)")
        XCTAssertEqual(analysis.key, "G")

        // The draft chart reads back with one timing per chord.
        let draft = DraftChart.chordPro(analysis, title: "Take")
        let chart = ChordProParser.parse(draft)
        XCTAssertEqual(chart.title, "Take")
        XCTAssertEqual(chart.chordSequence.count, DraftChart.timings(analysis).count)
        XCTAssertEqual(chart.tempo, analysis.bpm.rounded())
    }

    func testDraftChartFromBars() {
        let analysis = RecordingAnalysis(bpm: 96.4, beatsPerBar: 4, beats: [], bars: [
            .init(start: 1, end: 3, chords: ["G"], confidence: 0.9),
            .init(start: 3, end: 5, chords: ["G"], confidence: 0.9),
            .init(start: 5, end: 7, chords: ["D", "A"], confidence: 0.7),
            .init(start: 7, end: 9, chords: [nil], confidence: 0.1),
            .init(start: 9, end: 11, chords: ["Em"], confidence: 0.8),
        ], duration: 12, key: "G")
        let text = DraftChart.chordPro(analysis, title: "Take {1}")
        XCTAssertTrue(text.hasPrefix("{title: Take {1)}\n{key: G}\n{tempo: 96}\n{time: 4/4}\n"))
        XCTAssertTrue(text.contains("| [G] | [G] | [D] [A] | [N.C.] |"))
        let chart = ChordProParser.parse(text)
        XCTAssertEqual(chart.chordSequence.map(\.chord), ["G", "G", "D", "A", "Em"])
        XCTAssertEqual(DraftChart.timings(analysis), [1, 3, 5, 6, 9])
        XCTAssertFalse(chart.hasLyrics)
    }

    func testTooShortOrSilent() throws {
        let analyzer = try XCTUnwrap(RecordingAnalyzer(sampleRate: 44100))
        analyzer.feed([Float](repeating: 0, count: 44100 * 3))
        XCTAssertNil(analyzer.finish(), "three seconds is too short")
        XCTAssertNil(RecordingAnalyzer(sampleRate: 4000))
    }
}
