import XCTest
@testable import TimbreCore

final class NoteNamesTests: XCTestCase {
    override func tearDown() {
        NoteNames.active = "english"
        super.tearDown()
    }

    func testGermanSpellsBNaturalAsHAndBFlatAsB() {
        XCTAssertEqual(NoteNames.spell("B", system: "german"), "H")
        XCTAssertEqual(NoteNames.spell("Bb", system: "german"), "B")
        XCTAssertEqual(NoteNames.spell("B♭", system: "german"), "B")
        XCTAssertEqual(NoteNames.spell("B♯", system: "german"), "H♯")
        XCTAssertEqual(NoteNames.spell("Bbb", system: "german"), "Bb")
        XCTAssertEqual(NoteNames.spell("Eb", system: "german"), "Eb")
        XCTAssertEqual(NoteNames.spell("F#", system: "german"), "F#")
        XCTAssertEqual(NoteNames.spell("B", system: "english"), "B")
        XCTAssertEqual(NoteNames.spell("Bb", system: "solfege"), "Sib")
        XCTAssertEqual(NoteNames.spell("Beat", system: "german"), "Beat")
    }

    func testPitchClassNamesFollowTheSystem() {
        XCTAssertEqual(NoteNames.name(11, system: "german"), "H")
        XCTAssertEqual(NoteNames.name(10, preferFlats: true, system: "german"), "B")
        XCTAssertEqual(NoteNames.name(10, system: "german"), "A#")
        XCTAssertEqual(NoteNames.name(11, system: "english"), "B")
        XCTAssertEqual(NoteNames.name(7, system: "solfege"), "Sol")
        // Chord tools keep letters under sargam and numbers.
        XCTAssertEqual(NoteNames.name(9, system: "sargam"), "A")
        XCTAssertEqual(NoteNames.name(9, system: "numbered"), "A")
        XCTAssertEqual(NoteNames.name(11), "B")
        NoteNames.active = "german"
        XCTAssertEqual(NoteNames.name(11), "H")
        XCTAssertEqual(NoteNames.name(-1), "H")
    }

    func testChordSymbolsFollowTheSystem() {
        XCTAssertEqual(NoteNames.chord(root: 11, suffix: "m", system: "german"), "Hm")
        XCTAssertEqual(NoteNames.chord(root: 11, suffix: "7", system: "german"), "H7")
        XCTAssertEqual(NoteNames.chord(root: 10, suffix: "", preferFlats: true, system: "german"), "B")
        XCTAssertEqual(NoteNames.chordSymbol("Bm", system: "german"), "Hm")
        XCTAssertEqual(NoteNames.chordSymbol("B7", system: "german"), "H7")
        XCTAssertEqual(NoteNames.chordSymbol("Bbmaj7", system: "german"), "Bmaj7")
        XCTAssertEqual(NoteNames.chordSymbol("G/B", system: "german"), "G/H")
        XCTAssertEqual(NoteNames.chordSymbol("F#m", system: "german"), "F#m")
        XCTAssertEqual(NoteNames.chordSymbol("C6/9", system: "german"), "C6/9")
        XCTAssertEqual(NoteNames.chordSymbol("Am", system: "solfege"), "Lam")
        XCTAssertEqual(NoteNames.chordSymbol("D/F#", system: "solfege"), "Re/Fa#")
        XCTAssertEqual(NoteNames.chordSymbol("Bm", system: "sargam"), "Bm")
        XCTAssertEqual(NoteNames.chordSymbol("Bm", system: "english"), "Bm")
        XCTAssertEqual(NoteNames.chordSymbol("", system: "german"), "")
    }

    func testLessonChordNamesFollowTheActiveSystem() throws {
        let spec = ChordSpec(name: "Bm", root: 11, quality: "min", frets: [-1, 2, 4, 4, 3, 2])
        XCTAssertEqual(spec.name, "Bm")
        NoteNames.active = "german"
        XCTAssertEqual(spec.name, "Hm")
        XCTAssertEqual(spec.symbol, "Bm")
        // The curriculum's "name" key round-trips untouched.
        let data = try JSONEncoder().encode(spec)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"name\":\"Bm\""))
        XCTAssertEqual(try JSONDecoder().decode(ChordSpec.self, from: data), spec)
    }

    func testTunerNamesInGerman() {
        XCTAssertEqual(PitchMath.noteName(midi: 59, notation: "german"), "H3")
        XCTAssertEqual(PitchMath.noteName(midi: 58, notation: "german"), "A#3")
        XCTAssertEqual(PitchMath.noteName(midi: 64, notation: "german"), "E4")
        // Authored labels keep their spelling, respelled: the B string is H, a written B♭ is B.
        XCTAssertEqual(TargetLabelFormatter.display(label: "B3", midi: 59, notation: "german"), "H3")
        XCTAssertEqual(TargetLabelFormatter.display(label: "Bb3 (main slide)", midi: 58, notation: "german"), "B3")
        XCTAssertEqual(TargetLabelFormatter.display(label: "Eb2", midi: 39, notation: "german"), "Eb2")
        XCTAssertEqual(TargetLabelFormatter.display(label: "B3", midi: 59, notation: "english"), "B3")
        XCTAssertEqual(TargetLabelFormatter.display(label: "A3", midi: 57, notation: "german", transposition: 2), "H3")
        XCTAssertEqual(NoteNames.spellNote("B-1", system: "german"), "H-1")
    }

    func testDefaultSystemFollowsTheLanguageUntilChosen() {
        XCTAssertEqual(NoteNames.defaultSystem(language: "de"), "german")
        XCTAssertEqual(NoteNames.defaultSystem(language: "de-AT"), "german")
        XCTAssertEqual(NoteNames.defaultSystem(language: "de_CH"), "german")
        XCTAssertEqual(NoteNames.defaultSystem(language: "en"), "english")
        XCTAssertEqual(NoteNames.defaultSystem(language: "fr"), "english")

        var settings = UserSettings()
        settings.language = "de"
        settings.applyNotationDefault(systemLanguage: "en-US")
        XCTAssertEqual(settings.notation, "german")
        settings.language = "en"
        settings.applyNotationDefault(systemLanguage: "de-DE")
        XCTAssertEqual(settings.notation, "english")
        settings.language = "system"
        settings.applyNotationDefault(systemLanguage: "de-DE")
        XCTAssertEqual(settings.notation, "german")

        // A system picked in Settings stays.
        settings.notation = "english"; settings.notationChosen = true
        settings.applyNotationDefault(systemLanguage: "de-DE")
        XCTAssertEqual(settings.notation, "english")
        // So does an earlier non-letter choice.
        var solfege = UserSettings()
        solfege.notation = "solfege"; solfege.language = "de"
        solfege.applyNotationDefault(systemLanguage: nil)
        XCTAssertEqual(solfege.notation, "solfege")
    }
}
