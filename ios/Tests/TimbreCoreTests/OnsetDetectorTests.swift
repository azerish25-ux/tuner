import XCTest
@testable import TimbreCore

final class OnsetDetectorTests: XCTestCase {
    private let rates = [44100.0, 48000.0]

    private func detect(_ samples: [Double], rate: Double, chunk: Int = 512) -> [Double] {
        detect(Synth.floats(samples), rate: rate, chunk: chunk)
    }

    private func detect(_ samples: [Float], rate: Double, chunk: Int = 512) -> [Double] {
        let detector = OnsetDetector(sampleRate: rate)
        var onsets: [Double] = []
        var start = 0
        while start < samples.count {
            let end = min(samples.count, start + chunk)
            onsets += detector.process(Array(samples[start..<end]))
            start = end
        }
        XCTAssertEqual(detector.elapsed, Double(samples.count) / rate, accuracy: 1e-9)
        return onsets
    }

    /// Every expected onset is found once, within `tolerance` seconds, and nothing else is reported.
    @discardableResult
    private func assertOnsets(_ samples: [Double], rate: Double, expected: [Double], tolerance: Double = 0.015, _ name: String,
                              file: StaticString = #filePath, line: UInt = #line) -> [Double] {
        let onsets = detect(samples, rate: rate)
        XCTAssertEqual(onsets.count, expected.count, "\(name) at \(Int(rate)) Hz: \(onsets)", file: file, line: line)
        var worst = 0.0
        for time in expected {
            let error = onsets.map { abs($0 - time) }.min() ?? .infinity
            worst = max(worst, error)
            XCTAssertLessThanOrEqual(error, tolerance, "\(name) at \(Int(rate)) Hz: onset \(time) found \(onsets)", file: file, line: line)
        }
        print("Onsets \(name) at \(Int(rate)) Hz: \(onsets.count)/\(expected.count), worst timing error \(String(format: "%.1f", worst * 1000)) ms")
        return onsets
    }

    func testClickTrackOnsetsAreFoundAndTimed() {
        for rate in rates {
            var rng = TestRandom(seed: 11)
            let times = (0..<8).map { 0.3 + 0.5 * Double($0) + rng.uniform(-0.01, 0.01) }
            var out = [Double](repeating: 0, count: Int(4.6 * rate))
            for time in times { Synth.click(at: time, amplitude: 0.5, into: &out, sampleRate: rate, rng: &rng) }
            assertOnsets(out, rate: rate, expected: times, "click track")
        }
    }

    func testQuietClicksOverANoiseFloor() {
        for rate in rates {
            var rng = TestRandom(seed: 12)
            let times = (0..<9).map { 0.25 + 0.37 * Double($0) }
            var out = [Double](repeating: 0, count: Int(3.8 * rate))
            for time in times { Synth.click(at: time, amplitude: 0.02, into: &out, sampleRate: rate, rng: &rng) }
            Synth.addNoise(&out, level: 0.0005, rng: &rng)
            assertOnsets(out, rate: rate, expected: times, "quiet clicks")
        }
    }

    private func pluckedNotes(rate: Double) -> (samples: [Double], times: [Double]) {
        var rng = TestRandom(seed: 13)
        let notes: [(Double, Int)] = [(0.2, 45), (0.75, 52), (1.1, 57), (1.6, 64), (1.85, 60), (2.4, 40), (2.9, 69)]
        var out = [Double](repeating: 0, count: Int(4.0 * rate))
        for (time, midi) in notes { Synth.pluck(midi, at: time, into: &out, sampleRate: rate, rng: &rng, level: 0.3) }
        return (out, notes.map { $0.0 })
    }

    /// Notes ring on under the next ones, as on a real instrument.
    func testPluckedNotesAtKnownTimes() {
        for rate in rates {
            let (samples, times) = pluckedNotes(rate: rate)
            assertOnsets(samples, rate: rate, expected: times, "plucked notes")
        }
    }

    /// A long, slowly decaying note whose partials beat (two coupled modes 3 cents apart) must not retrigger.
    func testRingingNoteIsOneOnset() {
        for rate in rates {
            var rng = TestRandom(seed: 14)
            var out = [Double](repeating: 0, count: Int(4.0 * rate))
            Synth.pluck(52, at: 0.3, into: &out, sampleRate: rate, rng: &rng, level: 0.4, decayScale: 0.25, beatCents: 1.5)
            XCTAssertGreaterThan(out[Int(3.9 * rate)...].map { abs($0) }.max() ?? 0, 0.05, "still ringing at the end")
            assertOnsets(out, rate: rate, expected: [0.3], "ringing note")
        }
    }

    func testStrummedChordIsOneOnset() {
        for rate in rates {
            var rng = TestRandom(seed: 15)
            var out = [Double](repeating: 0, count: Int(3.0 * rate))
            Synth.strum([40, 47, 52, 56, 59, 64], at: 0.4, into: &out, sampleRate: rate, rng: &rng, level: 0.15)
            assertOnsets(out, rate: rate, expected: [0.4], tolerance: 0.03, "strum")
        }
    }

    func testSixteenthNotesAt120Bpm() {
        for rate in rates {
            var rng = TestRandom(seed: 16)
            let times = (0..<16).map { 0.2 + 0.125 * Double($0) }
            var out = [Double](repeating: 0, count: Int(2.6 * rate))
            for (index, time) in times.enumerated() {
                Synth.pluck(57 + (index % 3) * 2, at: time, into: &out, sampleRate: rate, rng: &rng, level: 0.3)
            }
            assertOnsets(out, rate: rate, expected: times, "sixteenths")
        }
    }

    func testSoftNotesAfterALoudOne() {
        for rate in rates {
            var rng = TestRandom(seed: 17)
            var out = [Double](repeating: 0, count: Int(2.5 * rate))
            Synth.pluck(45, at: 0.3, into: &out, sampleRate: rate, rng: &rng, level: 0.6)
            Synth.pluck(64, at: 0.8, into: &out, sampleRate: rate, rng: &rng, level: 0.075)
            Synth.pluck(67, at: 1.4, into: &out, sampleRate: rate, rng: &rng, level: 0.075)
            assertOnsets(out, rate: rate, expected: [0.3, 0.8, 1.4], "loud then soft")
        }
    }

    func testSilenceAndSteadyNoiseStayQuiet() {
        for rate in rates {
            XCTAssertEqual(detect([Float](repeating: 0, count: Int(2 * rate)), rate: rate), [])
            for (level, seed) in [(0.01, UInt64(18)), (0.001, 19), (0.3, 20)] {
                XCTAssertEqual(detect(Synth.whiteNoise(count: Int(3 * rate), level: level, seed: seed), rate: rate), [], "noise \(level)")
            }
        }
    }

    func testChunkSizeDoesNotChangeTheResult() {
        for rate in rates {
            let samples = Synth.floats(pluckedNotes(rate: rate).samples)
            let reference = detect(samples, rate: rate, chunk: 512)
            XCTAssertEqual(reference.count, 7)
            XCTAssertEqual(detect(samples, rate: rate, chunk: 4800), reference)
            XCTAssertEqual(detect(samples, rate: rate, chunk: 333), reference)
        }
        let detector = OnsetDetector()
        _ = detector.process(Synth.floats(pluckedNotes(rate: 48000).samples))
        detector.reset()
        XCTAssertEqual(detector.elapsed, 0)
        XCTAssertEqual(detector.process([Float](repeating: 0, count: 4096)), [])
    }

    // MARK: - Rhythm judge

    func testGradesAtTheWindowEdges() {
        let judge = RhythmJudge()
        let beats = (0..<9).map { Double($0) }
        let offsets = [0, 0.039, -0.04, 0.041, -0.06, 0.09, -0.0899, 0.091, -0.2]
        let report = judge.judge(expected: beats, onsets: zip(beats, offsets).map { $0 + $1 })
        XCTAssertEqual(report.judgments.map(\.grade), [.perfect, .perfect, .perfect, .good, .good, .good, .good, .miss, .miss])
        XCTAssertEqual(report.judgments[3].offset ?? 0, 0.041, accuracy: 1e-9)
        XCTAssertNil(report.judgments[7].offset)
        XCTAssertEqual(report.perfectCount, 3)
        XCTAssertEqual(report.goodCount, 4)
        XCTAssertEqual(report.missCount, 2)
        // The two far-off onsets fall inside the exercise, so they count as extra strums.
        XCTAssertEqual(report.extraOnsets.count, 2)
        XCTAssertEqual(report.accuracy, (3 + 0.5 * 4) / (9 + 2), accuracy: 1e-12)
        XCTAssertEqual(judge.grade(offset: 0.04), .perfect)
        XCTAssertEqual(judge.grade(offset: -0.09), .good)
    }

    func testEachOnsetCountsForOneBeatOnly() {
        let judge = RhythmJudge()
        // One onset between two close beats (sixteenths at 120 bpm) can only be one of them.
        var report = judge.judge(expected: [1.0, 1.125], onsets: [1.06])
        XCTAssertEqual(report.judgments.compactMap(\.onset), [1.06])
        XCTAssertEqual(report.judgments.filter { $0.grade == .miss }.count, 1)
        // Order is kept and both beats are hit when that is possible, even if a greedy pick would not.
        report = judge.judge(expected: [1.0, 1.1], onsets: [1.05, 1.18])
        XCTAssertEqual(report.judgments.map(\.grade), [.good, .good])
        XCTAssertEqual(report.judgments.compactMap(\.onset), [1.05, 1.18])
        // Two strums on one beat: the closer one counts, the other is extra.
        report = judge.judge(expected: [2.0], onsets: [1.97, 2.005])
        XCTAssertEqual(report.judgments[0].onset, 2.005)
        XCTAssertEqual(report.judgments[0].grade, .perfect)
        XCTAssertEqual(report.extraOnsets, [1.97])
        XCTAssertEqual(report.accuracy, 0.5, accuracy: 1e-12)
    }

    func testEmptyUnsortedAndLatencyCompensatedInput() {
        let judge = RhythmJudge(latency: 0.08)
        XCTAssertEqual(judge.judge(expected: [], onsets: [0.5, 1]).accuracy, 1)
        XCTAssertEqual(judge.judge(expected: [], onsets: []).judgments, [])
        let none = judge.judge(expected: [1, 2, 3], onsets: [])
        XCTAssertEqual(none.judgments.map(\.grade), [.miss, .miss, .miss])
        XCTAssertEqual(none.accuracy, 0)
        XCTAssertNil(none.meanOffset)
        // Onsets arrive late by the input latency and out of order; judgments keep the given beat order.
        let report = judge.judge(expected: [2, 1, 3], onsets: [3.1, 1.13, .nan, 2.09, 0.2, 9])
        XCTAssertEqual(report.judgments.map(\.beat), [0, 1, 2])
        XCTAssertEqual(report.judgments.map(\.grade), [.perfect, .good, .perfect])
        XCTAssertEqual(report.judgments[1].offset ?? 0, 0.05, accuracy: 1e-9)
        XCTAssertEqual(report.extraOnsets, [], "count-in and late onsets outside the exercise are ignored")
        XCTAssertEqual(report.meanOffset ?? 0, (0.01 + 0.05 + 0.02) / 3, accuracy: 1e-9)
        XCTAssertEqual(report.accuracy, 2.5 / 3, accuracy: 1e-12)
    }

    func testBeatTimesFromALessonPattern() {
        XCTAssertEqual(RhythmJudge.beatTimes(pattern: [0, 1, 2, 3], bpm: 60, bars: 2, start: 1), [1, 2, 3, 4, 5, 6, 7, 8])
        let swung = RhythmJudge.beatTimes(pattern: [0, 1.5, 2], bpm: 120, bars: 2)
        XCTAssertEqual(swung, [0, 0.75, 1, 2, 2.75, 3])
        XCTAssertEqual(RhythmJudge.beatTimes(pattern: [0, 2], bpm: 60, bars: 2, beatsPerBar: 3), [0, 2, 3, 5])
        XCTAssertEqual(RhythmJudge.beatTimes(pattern: [0, 4.5], bpm: 60, bars: 2), [0, 4.5, 5, 9.5], "a pattern past beat 4 lengthens the bar")
        XCTAssertEqual(RhythmJudge.beatTimes(pattern: [0], bpm: 0, bars: 2), [])
    }

    /// A strum lesson end to end: chords strummed with human timing, detected, then judged.
    func testStrumLessonEndToEnd() {
        let rate = 48000.0
        let expected = RhythmJudge.beatTimes(pattern: [0, 1, 2, 3], bpm: 90, bars: 2, start: 1)
        let offsets: [Double?] = [0, -0.01, 0.06, nil, 0.01, -0.065, 0.2, 0.005]
        var rng = TestRandom(seed: 21)
        var out = [Double](repeating: 0, count: Int(7 * rate))
        for (time, offset) in zip(expected, offsets) {
            guard let offset else { continue }
            Synth.strum(Synth.voicing("x32010"), at: time + offset, into: &out, sampleRate: rate, rng: &rng, level: 0.12)
        }
        Synth.addNoise(&out, level: 0.0005, rng: &rng)
        let onsets = detect(out, rate: rate)
        XCTAssertEqual(onsets.count, 7, "\(onsets)")
        let report = RhythmJudge().judge(expected: expected, onsets: onsets)
        XCTAssertEqual(report.judgments.map(\.grade), [.perfect, .perfect, .good, .miss, .perfect, .good, .miss, .perfect])
        XCTAssertEqual(report.extraOnsets.count, 1, "the strum 200 ms late is an extra")
        XCTAssertEqual(report.accuracy, (4 + 0.5 * 2) / 9, accuracy: 1e-9)
        let offsetsHeard = report.judgments.map { judgment in judgment.offset.map { String(format: "%.0f", $0 * 1000) } ?? "miss" }
        print("Strum lesson offsets (ms): \(offsetsHeard)")
    }
}
