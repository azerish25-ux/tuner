import XCTest
@testable import TimbreCore

final class ChordSymbolTests: XCTestCase {
    func testParsesRootSuffixAndBass() throws {
        let fSharp = try XCTUnwrap(ChordSymbol("F#m7"))
        XCTAssertEqual(fSharp.root, 6)
        XCTAssertEqual(fSharp.rootName, "F#")
        XCTAssertEqual(fSharp.suffix, "m7")
        XCTAssertNil(fSharp.bass)
        XCTAssertEqual(fSharp.text, "F#m7")

        let slash = try XCTUnwrap(ChordSymbol("D/F#"))
        XCTAssertEqual(slash.root, 2)
        XCTAssertEqual(slash.bass, 6)
        XCTAssertEqual(slash.text, "D/F#")

        let flat = try XCTUnwrap(ChordSymbol("Bbmaj7"))
        XCTAssertEqual(flat.root, 10)
        XCTAssertEqual(flat.suffix, "maj7")

        // Unicode accidentals are read, stored as ASCII.
        XCTAssertEqual(ChordSymbol("E♭")?.text, "Eb")
        XCTAssertEqual(ChordSymbol("C♯m")?.root, 1)
        // "G6/9" keeps its slash in the suffix: 9 is no bass note.
        XCTAssertEqual(ChordSymbol("G6/9")?.suffix, "6/9")
        XCTAssertNil(ChordSymbol("G6/9")?.bass)
    }

    func testRejectsWordsThatAreNotChords() {
        for word in ["And", "Go", "Bed", "Ebb", "Am-", "Dad", "As", "H", "c", "N.C.", "", "x2", "Cmaj7777777777", "Be"] {
            XCTAssertNil(ChordSymbol(word), word)
        }
        for chord in ["A", "Am", "C(add9)", "E7#9", "Bø7", "Co7", "C°", "Asus", "Dsus2", "Cmaj", "CM7", "C-7", "Am7b5", "C+", "E5", "Gadd9/B", "F#m7(b5)"] {
            XCTAssertNotNil(ChordSymbol(chord), chord)
        }
    }

    func testFormulaForEveryCommonSuffix() {
        let cases: [(String, String)] = [
            ("C", "maj"), ("Cm", "min"), ("Cmin7", "m7"), ("C-7", "m7"), ("Cm6", "m6"), ("C7", "7"), ("C9", "9"),
            ("C13", "7"), ("E7#9", "7"), ("Cmaj7", "maj7"), ("CM7", "maj7"), ("CΔ", "maj7"), ("Cmaj", "maj"),
            ("Csus2", "sus2"), ("Csus4", "sus4"), ("Csus", "sus4"), ("C7sus4", "sus4"), ("Cadd9", "add9"),
            ("C(add9)", "add9"), ("C6", "6"), ("G6/9", "6"), ("Cdim", "dim"), ("C°", "dim"), ("Bø7", "dim"),
            ("Am7b5", "dim"), ("Caug", "aug"), ("C+", "aug"), ("C5", "5"), ("Am11", "m7"),
        ]
        for (symbol, formula) in cases {
            XCTAssertEqual(ChordSymbol(symbol)?.formulaId, formula, symbol)
        }
    }

    func testRecognizerTargets() {
        XCTAssertEqual(ChordSymbol("Am")?.target, ChordTarget(root: 9, quality: .minor))
        XCTAssertEqual(ChordSymbol("C6")?.target, ChordTarget(root: 0, quality: .major))
        XCTAssertEqual(ChordSymbol("G9")?.target, ChordTarget(root: 7, quality: .dominant7))
        XCTAssertNil(ChordSymbol("Cdim")?.target)
    }

    func testTransposesWithTheSpellingAsked() {
        let chord = ChordSymbol("F#m7")!
        XCTAssertEqual(chord.transposed(by: 2, preferFlats: false).text, "G#m7")
        XCTAssertEqual(chord.transposed(by: 4, preferFlats: true).text, "Bbm7")
        XCTAssertEqual(chord.transposed(by: 12, preferFlats: true).text, "F#m7", "a whole octave keeps the spelling")
        XCTAssertEqual(ChordSymbol("D/F#")!.transposed(by: 3, preferFlats: true).text, "F/A")
        XCTAssertEqual(ChordSymbol("C")!.transposed(by: -1, preferFlats: false).text, "B")
    }

    func testKeysAndKeyGuessing() throws {
        let fSharpMinor = try XCTUnwrap(ChordSpelling.key("F#m"))
        XCTAssertEqual(fSharpMinor.tonic, 6)
        XCTAssertTrue(fSharpMinor.minor)
        XCTAssertEqual(ChordSpelling.key("C major")?.tonic, 0)
        XCTAssertEqual(ChordSpelling.key("A minor")?.minor, true)
        XCTAssertNil(ChordSpelling.key("Xm"))

        let g = try XCTUnwrap(ChordSpelling.guessKey(["G", "D", "Em", "C", "G"].compactMap { ChordSymbol($0) }))
        XCTAssertEqual(g.tonic, 7)
        XCTAssertFalse(g.minor)
        let am = try XCTUnwrap(ChordSpelling.guessKey(["Am", "F", "C", "G", "Am"].compactMap { ChordSymbol($0) }))
        XCTAssertEqual(am.tonic, 9)
        XCTAssertTrue(am.minor)

        XCTAssertEqual(ChordSpelling.keyName(tonic: 10, minor: false), "Bb")
        XCTAssertEqual(ChordSpelling.keyName(tonic: 6, minor: true), "F#m")
        XCTAssertEqual(ChordSpelling.keyName(tonic: 3, minor: false), "Eb")
        XCTAssertTrue(ChordSpelling.prefersFlats(tonic: 2, minor: true), "D minor is written with a flat")
        XCTAssertFalse(ChordSpelling.prefersFlats(tonic: 4, minor: true))
    }
}
