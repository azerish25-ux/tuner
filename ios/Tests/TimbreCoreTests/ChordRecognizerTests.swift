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

    /// Every root and quality, voiced by the app's own chord finder (its first shape), one strum each.
    func testEveryRootAndQualityFromTheChordFinder() {
        var total = 0, correct = 0, rootCorrect = 0
        var misses: [String] = []
        for (index, quality) in ChordRecognizer.Quality.allCases.enumerated() {
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

    func testIdealChromaRecoversEveryChord() {
        for quality in ChordRecognizer.Quality.allCases {
            for root in 0..<12 {
                let target = ChordTarget(root: root, quality: quality)
                var chroma = [Double](repeating: 0, count: 12)
                for pitchClass in target.pitchClasses { chroma[pitchClass] = 1 / Double(target.pitchClasses.count).squareRoot() }
                let best = ChordRecognizer.bestChord(chroma: chroma, bass: root)
                XCTAssertEqual(best?.target, target)
                XCTAssertEqual(best?.confidence ?? 0, 1, accuracy: 1e-12)
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
        XCTAssertNil(ChordTarget(root: 4, formulaId: "dim"))
    }
}
