import XCTest
@testable import TimbreCore

final class ChordRecognizerTests: XCTestCase {
    private let duration = 0.5
    private let openChords = [("C", "x32010"), ("G", "320003"), ("D", "xx0232"), ("A", "x02220"), ("E", "022100"),
                              ("Am", "x02210"), ("Em", "022000"), ("Dm", "xx0231"), ("E7", "020100")]
    private let barreAndPowerChords = [("F", "133211"), ("Bm", "x24432"), ("Bb", "x13331"), ("Gm", "355333"), ("C", "x35553"),
                                       ("F#m", "244222"), ("E5", "022xxx"), ("A5", "x022xx"), ("G5", "355xxx"), ("D5", "x577xx")]

    /// Three 8192-sample frames, hop 4096, from 80 ms after the strum: about what a lesson hears in a quarter second.
    private func recognise(_ signal: [Float], rate: Double, recognizer: ChordRecognizer? = nil) -> (ChordRecognizer, ChordEstimate?) {
        let recognizer = recognizer ?? ChordRecognizer(sampleRate: rate)
        let start = Int(0.08 * rate)
        var estimate: ChordEstimate?
        for k in 0..<3 {
            let from = start + k * 4096
            estimate = recognizer.process(Array(signal[from..<(from + 8192)]))
        }
        return (recognizer, estimate)
    }

    private func assertRecognised(_ chords: [(String, String)], file: StaticString = #filePath, line: UInt = #line) throws {
        var lowest = 1.0
        for (symbol, shape) in chords {
            let target = try XCTUnwrap(ChordTarget(symbol: symbol))
            for rate in [44100.0, 48000.0] {
                for seed: UInt64 in [1, 2] {
                    let (recognizer, estimate) = recognise(Synth.chord(shape, sampleRate: rate, duration: duration, seed: seed), rate: rate)
                    let context = "\(symbol) \(shape) at \(Int(rate)) Hz, seed \(seed): heard \(estimate?.symbol ?? "nothing")"
                    XCTAssertEqual(estimate?.target, target, context, file: file, line: line)
                    XCTAssertGreaterThanOrEqual(estimate?.confidence ?? 0, 0.6, context, file: file, line: line)
                    XCTAssertTrue(recognizer.matches(target), context, file: file, line: line)
                    lowest = min(lowest, estimate?.confidence ?? 0)
                }
            }
        }
        print("Chord recognition: \(chords.count * 4) strums correct, lowest confidence \(String(format: "%.3f", lowest))")
    }

    func testOpenPositionChordsAtBothSampleRates() throws {
        try assertRecognised(openChords)
    }

    func testBarreAndPowerChords() throws {
        try assertRecognised(barreAndPowerChords)
    }

    /// Every root and quality a reading is named with, voiced by the app's own chord finder (its first shape), one
    /// strum each.
    func testEveryRootAndQualityFromTheChordFinder() {
        var total = 0, correct = 0, rootCorrect = 0
        var misses: [String] = []
        for (index, quality) in ChordRecognizer.Quality.heard.enumerated() {
            let formula = ChordFormula.byId(quality.formulaId)
            XCTAssertEqual(formula.intervals, quality.intervals, quality.rawValue)
            for root in 0..<12 {
                guard let shape = ChordFinder.shapes(root: root, formula: formula, openMidi: Synth.guitar).first else { continue }
                let midi = shape.frets.enumerated().map { string, fret in fret.map { Synth.guitar[string] + $0 } }
                let rate: Double = (root + index) % 2 == 0 ? 48000 : 44100
                let signal = Synth.chord(midi, sampleRate: rate, duration: duration, seed: UInt64(100 + root * 8 + index))
                let (_, estimate) = recognise(signal, rate: rate)
                let target = ChordTarget(root: root, quality: quality)
                total += 1
                if estimate?.root == root { rootCorrect += 1 }
                if estimate?.target == target { correct += 1 } else { misses.append("\(target.symbol) \(shape.notation) -> \(estimate?.symbol ?? "nothing")") }
            }
        }
        let accuracy = Double(correct) / Double(max(1, total))
        print("Chord finder bench: \(correct)/\(total) chords (\(String(format: "%.1f", 100 * accuracy))%), roots \(rootCorrect)/\(total); misses: \(misses.joined(separator: ", "))")
        XCTAssertEqual(total, 96)
        XCTAssertGreaterThanOrEqual(accuracy, 0.9)
        XCTAssertGreaterThanOrEqual(Double(rootCorrect) / Double(max(1, total)), 0.95)
    }

    /// Common chords under harder conditions: weak low fundamentals (small body), up-strums, a guitar
    /// tuned 20 cents flat or 15 sharp, a noisy room, a quiet player, dull and bright strings.
    func testRobustnessBench() throws {
        struct Variant { var body = false, up = false, tune = 0.0, noise = 0.002, gain = 0.3, brightness = 1.0 }
        let variants = [Variant(body: true), Variant(up: true), Variant(tune: -20), Variant(tune: 15), Variant(noise: 0.02),
                        Variant(noise: 0.0001, gain: 0.01), Variant(brightness: 0.8), Variant(brightness: 1.4), Variant(body: true, up: true, brightness: 1.3)]
        var total = 0, correct = 0
        var misses: [String] = []
        for (chordIndex, (symbol, shape)) in (openChords + barreAndPowerChords.prefix(6)).enumerated() {
            let target = try XCTUnwrap(ChordTarget(symbol: symbol))
            for (variantIndex, v) in variants.enumerated() {
                let rate: Double = (chordIndex + variantIndex) % 2 == 0 ? 48000 : 44100
                let signal = Synth.chord(shape, sampleRate: rate, duration: duration, seed: UInt64(500 + chordIndex * 31 + variantIndex), gain: v.gain,
                                         noise: v.noise, brightness: v.brightness, up: v.up, body: v.body, tuneCents: v.tune)
                let (_, estimate) = recognise(signal, rate: rate)
                total += 1
                if estimate?.target == target { correct += 1 } else { misses.append("\(symbol) \(shape) variant \(variantIndex) -> \(estimate?.symbol ?? "nothing")") }
            }
        }
        let accuracy = Double(correct) / Double(total)
        print("Chord robustness bench: \(correct)/\(total) (\(String(format: "%.1f", 100 * accuracy))%); misses: \(misses.joined(separator: ", "))")
        XCTAssertGreaterThanOrEqual(accuracy, 0.95)
    }

    func testLessonMatchingAcceptsVoicingsAndInversionsButNotOtherChords() throws {
        let rate = 48000.0
        let cases: [(shape: String, accepted: [String], rejected: [String])] = [
            ("x32010", ["C"], ["G", "Am", "Cm", "Cmaj7", "Em", "C7"]),
            ("320003", ["G"], ["Em", "D", "Gmaj7", "G5"]),
            ("022000", ["Em"], ["G", "E", "Em7"]),
            ("020100", ["E7"], ["E", "Em", "G#m"]),
            ("x02210", ["Am"], ["C", "A", "Am7"]),
            ("x00232", ["D"], ["A", "Dsus4"]),          // D over its fifth in the bass
            ("332010", ["C"], ["G"]),                   // C/G
            ("x20003", ["G"], ["Bm"]),                  // G/B
            ("320033", ["G"], []),                      // another G voicing
            ("x02200", ["Asus2", "Esus4"], ["A", "Am"]),  // same notes, either name
            ("022xxx", ["E5"], ["E", "Em"]),
        ]
        for (shape, accepted, rejected) in cases {
            let (recognizer, estimate) = recognise(Synth.chord(shape, sampleRate: rate, duration: duration, seed: 7), rate: rate)
            XCTAssertNotNil(estimate, shape)
            for symbol in accepted {
                let target = try XCTUnwrap(ChordTarget(symbol: symbol))
                XCTAssertTrue(recognizer.matches(target), "\(shape) should match \(symbol); heard \(estimate?.symbol ?? "nothing")")
                XCTAssertGreaterThan(recognizer.confidence(for: target), 0.8, "\(shape) \(symbol)")
            }
            for symbol in rejected {
                let target = try XCTUnwrap(ChordTarget(symbol: symbol))
                XCTAssertFalse(recognizer.matches(target), "\(shape) must not match \(symbol); heard \(estimate?.symbol ?? "nothing")")
            }
        }
    }

    /// The banjo's two-finger D7 (x0210: D A C D, no F♯) reads best as D5. It must still pass for D7, and not for the
    /// chords around it.
    func testBanjoTwoFingerD7PassesForD7() throws {
        let banjo = [67, 50, 55, 59, 62]
        let d7 = try XCTUnwrap(ChordTarget(symbol: "D7"))
        for rate in [44100.0, 48000.0] {
            for seed: UInt64 in [1, 2, 3] {
                let signal = Synth.chord(Synth.voicing("x0210", tuning: banjo), sampleRate: rate, duration: duration, seed: seed)
                let (recognizer, estimate) = recognise(signal, rate: rate)
                let context = "banjo x0210 at \(Int(rate)) Hz, seed \(seed): heard \(estimate?.symbol ?? "nothing")"
                XCTAssertTrue(recognizer.matches(d7), context)
                XCTAssertEqual(estimate?.matches(d7), true, context)
                for other in ["D", "Dm", "G", "G7", "Am", "C"] {
                    let target = try XCTUnwrap(ChordTarget(symbol: other))
                    XCTAssertFalse(recognizer.matches(target), "\(context) passed for \(other)")
                }
            }
        }
    }

    // MARK: Each stroke's chord

    /// Feeds a take in 1024-sample buffers: each stroke read, with the expected stroke it is nearest (within 30 ms).
    private func strokes(_ take: (samples: [Float], strokes: [Double], chords: [Int]), rate: Double) -> [(expected: Int, chord: ChordEstimate?)] {
        let reader = StrokeChords(sampleRate: rate)
        var found: [StrokeChords.Stroke] = []
        var start = 0
        while start < take.samples.count {
            let end = min(take.samples.count, start + 1024)
            found += reader.feed(Array(take.samples[start..<end])).strokes
            start = end
        }
        return found.compactMap { stroke -> (expected: Int, chord: ChordEstimate?)? in
            guard let nearest = take.strokes.indices.min(by: { abs(take.strokes[$0] - stroke.time) < abs(take.strokes[$1] - stroke.time) }),
                  abs(take.strokes[nearest] - stroke.time) <= 0.03 else { return nil }
            return (expected: nearest, chord: stroke.chord)
        }
    }

    private let progressionTargets = ["C", "Am", "F", "G"].compactMap { ChordTarget(symbol: $0) }

    /// C – Am – F – G strummed in time: every stroke is found, and read as its own bar's chord.
    func testEachStrokeOfAProgressionIsReadForItsChord() {
        let shapes = ["x32010", "x02210", "133211", "320003"]
        for rate in [44100.0, 48000.0] {
            for seed: UInt64 in [1, 2] {
                let take = Synth.progression(shapes, pattern: [0, 1, 2, 3], bpm: 80, sampleRate: rate, seed: seed)
                let heard = strokes(take, rate: rate)
                let context = "C Am F G at \(Int(rate)) Hz, seed \(seed): " + heard.map { $0.chord?.symbol ?? "-" }.joined(separator: " ")
                XCTAssertGreaterThanOrEqual(heard.count, 15, context)
                let right = heard.filter { $0.chord?.matches(progressionTargets[take.chords[$0.expected]]) ?? false }
                XCTAssertGreaterThanOrEqual(right.count, 15, context)
            }
        }
    }

    /// Strummed in time through C – Am – F – G, open strings never pass for the chord, taps on the body ring none, and
    /// G all the way through is right in the G bar only.
    func testStrokesOfTheWrongChordOrNoneAreCaught() {
        for rate in [44100.0, 48000.0] {
            let open = Synth.progression(Array(repeating: "000000", count: 4), pattern: [0, 1, 2, 3], bpm: 80, sampleRate: rate, seed: 1)
            let openHeard = strokes(open, rate: rate)
            XCTAssertGreaterThanOrEqual(openHeard.count, 15, "open strings at \(Int(rate)) Hz")
            for stroke in openHeard {
                XCTAssertFalse(stroke.chord?.matches(progressionTargets[open.chords[stroke.expected]]) ?? false,
                               "open strings passed for \(progressionTargets[open.chords[stroke.expected]]) at \(Int(rate)) Hz")
            }

            let taps = Synth.progression(Array(repeating: "000000", count: 4), pattern: [0, 1, 2, 3], bpm: 80, sampleRate: rate, seed: 1, taps: true)
            let tapHeard = strokes(taps, rate: rate)
            XCTAssertGreaterThanOrEqual(tapHeard.count, 15, "taps at \(Int(rate)) Hz")
            XCTAssertTrue(tapHeard.allSatisfy { $0.chord == nil }, "a tap rang a chord at \(Int(rate)) Hz: \(tapHeard.compactMap { $0.chord?.symbol })")

            let g = Synth.progression(Array(repeating: "320003", count: 4), pattern: [0, 1, 2, 3], bpm: 80, sampleRate: rate, seed: 2)
            for stroke in strokes(g, rate: rate) {
                let bar = g.chords[stroke.expected]
                let right = stroke.chord?.matches(progressionTargets[bar]) ?? false
                XCTAssertEqual(right, bar == 3, "G strummed in bar \(bar + 1) at \(Int(rate)) Hz, heard \(stroke.chord?.symbol ?? "nothing")")
            }
        }
    }

    func testBassAndChromaOfAReading() throws {
        let rate = 48000.0
        for (shape, bass) in [("x32010", 0), ("x00232", 9), ("320003", 7), ("022000", 4)] {
            let (recognizer, estimate) = recognise(Synth.chord(shape, sampleRate: rate, duration: duration, seed: 7), rate: rate)
            let reading = try XCTUnwrap(estimate, shape)
            XCTAssertEqual(reading.bass, bass, shape)
            XCTAssertEqual(recognizer.bassPitchClass, bass, shape)
            XCTAssertEqual(reading.chroma.count, 12)
            XCTAssertEqual(reading.chroma.reduce(0) { $0 + $1 * $1 }, 1, accuracy: 1e-9)
            XCTAssertTrue(reading.chroma.allSatisfy { $0 >= 0 })
            // Chord tones carry the chroma.
            let tones = reading.target.pitchClasses
            XCTAssertGreaterThan(tones.reduce(0) { $0 + reading.chroma[$1] * reading.chroma[$1] }, 0.85, shape)
        }
    }

    func testSilenceNoiseAndInvalidFramesGiveNoChord() {
        for rate in [44100.0, 48000.0] {
            let signals: [(String, [Float])] = [
                ("digital silence", [Float](repeating: 0, count: 40000)),
                ("chord below the silence floor", Synth.chord("x32010", sampleRate: rate, duration: 1, seed: 3, gain: 0.0003, noise: 0)),
                ("loud white noise", Synth.whiteNoise(count: 48000, level: 0.3, seed: 11)),
                ("white noise", Synth.whiteNoise(count: 48000, level: 0.05, seed: 12)),
                ("quiet white noise", Synth.whiteNoise(count: 48000, level: 0.005, seed: 13)),
            ]
            for (name, signal) in signals {
                let recognizer = ChordRecognizer(sampleRate: rate)
                for k in 0..<8 {
                    XCTAssertNil(recognizer.process(Array(signal[(k * 4096)..<(k * 4096 + 8192)])), "\(name) at \(Int(rate)) Hz, frame \(k)")
                }
                XCTAssertNil(recognizer.current, name)
                XCTAssertFalse(recognizer.matches(ChordTarget(root: 0, quality: .major)), name)
                XCTAssertEqual(recognizer.confidence(for: ChordTarget(root: 0, quality: .major)), 0, name)
            }
        }
        let recognizer = ChordRecognizer()
        XCTAssertNil(recognizer.process([]))
        XCTAssertNil(recognizer.process([Float](repeating: 0.1, count: 512)))
        var broken = Synth.chord("x32010", sampleRate: 48000, duration: 0.5, seed: 1)
        broken[5000] = .nan
        XCTAssertNil(recognizer.process(Array(broken[0..<8192])))
    }

    func testSilenceEndsTheChordAndResetForgetsIt() throws {
        let rate = 48000.0
        let (recognizer, estimate) = recognise(Synth.chord("x32010", sampleRate: rate, duration: duration, seed: 4), rate: rate)
        XCTAssertEqual(estimate?.symbol, "C")
        XCTAssertNil(recognizer.process([Float](repeating: 0, count: 8192)))
        XCTAssertNil(recognizer.current)
        XCTAssertFalse(recognizer.matches(ChordTarget(root: 0, quality: .major)))
        _ = recognise(Synth.chord("320003", sampleRate: rate, duration: duration, seed: 5), rate: rate, recognizer: recognizer)
        XCTAssertEqual(recognizer.current?.symbol, "G")
        recognizer.reset()
        XCTAssertNil(recognizer.current)
        XCTAssertEqual(recognizer.chroma, [Double](repeating: 0, count: 12))
    }

    /// C rings and fades, then G is strummed: the reading switches within two frames of the G frames.
    func testFollowsAChordChange() {
        let rate = 48000.0
        let c = Synth.chord("x32010", sampleRate: rate, duration: 1.2, seed: 21)
        let g = Synth.chord("320003", sampleRate: rate, duration: 1.2, seed: 22)
        let fade = Int(0.8 * rate)
        let fading: [Float] = (0..<fade).map { index in c[index] * Float(1 - 0.7 * Double(index) / Double(fade - 1)) }
        let signal = fading + g
        let recognizer = ChordRecognizer(sampleRate: rate)
        var heard: [String?] = []
        for k in 0..<((signal.count - 8192) / 4096) {
            heard.append(recognizer.process(Array(signal[(k * 4096)..<(k * 4096 + 8192)]))?.symbol)
        }
        let firstGFrame = Int((0.8 * rate / 4096).rounded(.up))
        XCTAssertEqual(heard[2], "C", "\(heard)")
        XCTAssertEqual(Array(heard[(firstGFrame + 1)..<(firstGFrame + 8)]), [String?](repeating: "G", count: 7), "\(heard)")
    }

    /// The chroma of a chord's notes, evenly.
    private func idealChroma(_ target: ChordTarget) -> [Double] {
        var chroma = [Double](repeating: 0, count: 12)
        for pitchClass in target.pitchClasses { chroma[pitchClass] = 1 / Double(target.pitchClasses.count).squareRoot() }
        return chroma
    }

    /// A reading of `pitchClasses` played evenly with `bass` lowest, as the recognizer would make it.
    private func idealReading(_ pitchClasses: [Int], bass: Int) throws -> ChordEstimate {
        var chroma = [Double](repeating: 0, count: 12)
        for pitchClass in pitchClasses { chroma[pitchClass] = 1 / Double(pitchClasses.count).squareRoot() }
        let best = try XCTUnwrap(ChordRecognizer.bestChord(chroma: chroma, bass: bass))
        return ChordEstimate(root: best.target.root, quality: best.target.quality, confidence: best.confidence, chroma: chroma, bass: bass)
    }

    func testIdealChromaRecoversEveryChord() throws {
        // Every quality a reading is named with, and the augmented triad, which none of them fits, read as themselves.
        for quality in ChordRecognizer.Quality.heard + [.augmented] {
            for root in 0..<12 {
                let target = ChordTarget(root: root, quality: quality)
                let best = ChordRecognizer.bestChord(chroma: idealChroma(target), bass: root)
                XCTAssertEqual(best?.target, target)
                XCTAssertEqual(best?.confidence ?? 0, 1, accuracy: 1e-12)
            }
        }
        // Every quality, the symmetric ones included, passes a lesson check of itself.
        for quality in ChordRecognizer.Quality.allCases {
            for root in 0..<12 {
                let target = ChordTarget(root: root, quality: quality)
                let reading = try idealReading(Array(target.pitchClasses), bass: root)
                XCTAssertTrue(reading.matches(target), "\(target.symbol) read as \(reading.symbol)")
            }
        }
        // A flat chroma (broadband noise) fits nothing.
        let flat = [Double](repeating: 1 / 12.0.squareRoot(), count: 12)
        XCTAssertEqual(ChordRecognizer.templateConfidence(chroma: flat, target: ChordTarget(root: 0, quality: .major)), 0, accuracy: 1e-12)
        XCTAssertNil(ChordRecognizer.bestChord(chroma: [Double](repeating: 0, count: 12), bass: nil))
    }

    func testChordTargetSymbolsAndLessonBridge() throws {
        let expected: [(String, Int, ChordRecognizer.Quality)] = [
            ("C", 0, .major), ("Am", 9, .minor), ("F#7", 6, .dominant7), ("Bbmaj7", 10, .major7), ("Em7", 4, .minor7),
            ("Dsus2", 2, .sus2), ("Asus4", 9, .sus4), ("E5", 4, .power), ("Ebm", 3, .minor), ("Cb", 11, .major), ("G♯m7", 8, .minor7),
        ]
        for (symbol, root, quality) in expected {
            XCTAssertEqual(ChordTarget(symbol: symbol), ChordTarget(root: root, quality: quality), symbol)
        }
        for bad in ["", "H", "Cadd9", "c", "Gmaj9", "#C"] { XCTAssertNil(ChordTarget(symbol: bad), bad) }
        XCTAssertEqual(ChordTarget(root: 10, quality: .major7).symbol, "A#maj7")
        XCTAssertEqual(ChordTarget(root: -3, quality: .minor).root, 9)
        XCTAssertEqual(ChordTarget(root: 7, quality: .dominant7).pitchClasses, [7, 11, 2, 5])
        for quality in ChordRecognizer.Quality.allCases {
            XCTAssertEqual(ChordRecognizer.Quality(formulaId: quality.formulaId), quality)
            XCTAssertEqual(ChordTarget(symbol: "C" + quality.suffix)?.quality, quality)
        }
        XCTAssertEqual(ChordTarget(root: 4, formulaId: "min"), ChordTarget(root: 4, quality: .minor))
        XCTAssertEqual(ChordTarget(root: 11, formulaId: "dim"), ChordTarget(root: 11, quality: .diminished))
        XCTAssertEqual(ChordTarget(root: 0, formulaId: "aug"), ChordTarget(root: 0, quality: .augmented))
        XCTAssertEqual(ChordTarget(symbol: "Bdim7"), ChordTarget(root: 11, quality: .diminished7))
        XCTAssertEqual(ChordTarget(symbol: "C+"), ChordTarget(root: 0, quality: .augmented))
        // Added sixths and ninths are checked as the chord they colour.
        XCTAssertEqual(ChordTarget(root: 4, formulaId: "9"), ChordTarget(root: 4, quality: .dominant7))
        XCTAssertEqual(ChordTarget(root: 0, formulaId: "add9"), ChordTarget(root: 0, quality: .major))
        XCTAssertEqual(ChordTarget(root: 0, formulaId: "m6"), ChordTarget(root: 0, quality: .minor))
        XCTAssertEqual(ChordTarget(root: 0, formulaId: "6"), ChordTarget(root: 9, quality: .minor7), "C6 is Am7, note for note")
        XCTAssertNil(ChordTarget(root: 4, formulaId: "13b9"))
    }

    /// The funk unit's E9 and D9: a ninth chord is checked as its seventh, so a stroke of E9 passes for E9 (and E7, the
    /// same check) and not for the chords inside it.
    func testNinthChordsAreCheckedAsTheirSeventh() throws {
        let e9 = try XCTUnwrap(ChordTarget(root: 4, formulaId: "9"))
        let reading = try idealReading([4, 8, 11, 2, 6], bass: 4)    // E G♯ B D F♯
        XCTAssertEqual(reading.symbol, "E7")
        XCTAssertTrue(reading.matches(e9))
        for other in ["E", "Bm", "Em7", "E5", "Esus2"] {
            XCTAssertFalse(reading.matches(try XCTUnwrap(ChordTarget(symbol: other))), other)
        }
        let d9 = try XCTUnwrap(ChordTarget(root: 2, formulaId: "9"))
        XCTAssertTrue(try idealReading([2, 6, 9, 0, 4], bass: 2).matches(d9))
        // A plain E major doesn't pass for E9.
        XCTAssertFalse(try idealReading([4, 8, 11], bass: 4).matches(e9))
    }

    /// Diminished and augmented chords are checked against their own templates; the chords around them are turned away.
    func testSymmetricChordsAreChecked() throws {
        let bdim = try XCTUnwrap(ChordTarget(symbol: "Bdim"))
        let bdimHeard = try idealReading([11, 2, 5], bass: 11)
        XCTAssertTrue(bdimHeard.matches(bdim))
        XCTAssertFalse(bdimHeard.matches(try XCTUnwrap(ChordTarget(symbol: "Bm"))))
        // G7 played isn't Bdim, though it holds all of it.
        XCTAssertFalse(try idealReading([7, 11, 2, 5], bass: 7).matches(bdim))
        let caug = try XCTUnwrap(ChordTarget(symbol: "Caug"))
        let caugHeard = try idealReading([0, 4, 8], bass: 0)
        XCTAssertEqual(caugHeard.symbol, "Caug")
        XCTAssertTrue(caugHeard.matches(caug))
        XCTAssertFalse(caugHeard.matches(try XCTUnwrap(ChordTarget(symbol: "C"))))
        XCTAssertFalse(try idealReading([0, 4, 7], bass: 0).matches(caug))
        let bdim7 = try XCTUnwrap(ChordTarget(symbol: "Bdim7"))
        XCTAssertTrue(try idealReading([11, 2, 5, 8], bass: 11).matches(bdim7))
        XCTAssertFalse(try idealReading([7, 11, 2, 5], bass: 7).matches(bdim7))
    }
}
