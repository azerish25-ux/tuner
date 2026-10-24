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

    func testNotesShowWithSharpAndFlatSigns() {
        XCTAssertEqual(NoteNames.glyphs("Bb3"), "B♭3")
        XCTAssertEqual(NoteNames.glyphs("C#4"), "C♯4")
        XCTAssertEqual(NoteNames.glyphs("F#"), "F♯")
        XCTAssertEqual(NoteNames.glyphs("Eb"), "E♭")
        XCTAssertEqual(NoteNames.glyphs("Bbb"), "B♭♭")
        XCTAssertEqual(NoteNames.glyphs("C#-1"), "C♯-1")
        XCTAssertEqual(NoteNames.glyphs("A"), "A")
        XCTAssertEqual(NoteNames.glyphs(""), "")
        // Signs already there stay; the formatter can run twice.
        XCTAssertEqual(NoteNames.glyphs("E♭"), "E♭")
        XCTAssertEqual(NoteNames.glyphs("Eb♭"), "E♭♭")
        XCTAssertEqual(NoteNames.glyphs(NoteNames.glyphs("Ab4")), "A♭4")
        XCTAssertEqual(NoteNames.glyphs(NoteNames.glyphs("Eb7b9")), "E♭7b9")
        XCTAssertEqual(NoteNames.glyphs("F#7b9"), "F♯7b9")
    }

    func testChordSymbolsShowWithSigns() {
        XCTAssertEqual(NoteNames.glyphs("Ebmaj7"), "E♭maj7")
        XCTAssertEqual(NoteNames.glyphs("F#m7"), "F♯m7")
        XCTAssertEqual(NoteNames.glyphs("Bbsus4"), "B♭sus4")
        XCTAssertEqual(NoteNames.glyphs("Abdim"), "A♭dim")
        XCTAssertEqual(NoteNames.glyphs("EbM7"), "E♭M7")
        XCTAssertEqual(NoteNames.glyphs("D/F#"), "D/F♯")
        XCTAssertEqual(NoteNames.glyphs("Bb/D"), "B♭/D")
        XCTAssertEqual(NoteNames.glyphs("Bb Eb Ab"), "B♭ E♭ A♭")
        XCTAssertEqual(NoteNames.glyphs(ChordTarget(root: 10, quality: .major7).symbol), "A♯maj7")
    }

    func testEveryNamingSystemShowsSigns() {
        XCTAssertEqual(NoteNames.glyphs(NoteNames.spell("Bb", system: "solfege")), "Si♭")
        XCTAssertEqual(NoteNames.glyphs(NoteNames.spell("Eb", system: "sargam")), "Ga♭")
        XCTAssertEqual(NoteNames.glyphs(NoteNames.spell("Bb", system: "numbered")), "7♭")
        XCTAssertEqual(NoteNames.glyphs("Sol#3"), "Sol♯3")
        XCTAssertEqual(NoteNames.glyphs("Dha#4"), "Dha♯4")
        XCTAssertEqual(NoteNames.glyphs("Do#"), "Do♯")
        XCTAssertEqual(NoteNames.glyphs("1#4"), "1♯4")
        // German keeps its letters: B is B♭ and needs no sign, H is B natural, H♯ its sharp.
        XCTAssertEqual(NoteNames.glyphs(NoteNames.spell("Bb", system: "german")), "B")
        XCTAssertEqual(NoteNames.glyphs(NoteNames.spell("B", system: "german")), "H")
        XCTAssertEqual(NoteNames.glyphs(NoteNames.spell("B#", system: "german")), "H♯")
        XCTAssertEqual(NoteNames.glyphs(NoteNames.spell("Eb", system: "german")), "E♭")
        XCTAssertEqual(NoteNames.glyphs(NoteNames.spell("F#", system: "german")), "F♯")
    }

    func testTunerNamesShowWithSigns() {
        XCTAssertEqual(PitchMath.displayName(midi: 70), "A♯4")
        XCTAssertEqual(PitchMath.displayName(midi: 69), "A4")
        XCTAssertEqual(PitchMath.displayName(midi: 61, notation: "solfege"), "Do♯4")
        XCTAssertEqual(PitchMath.displayName(midi: 61, notation: "sargam"), "Sa♯4")
        XCTAssertEqual(PitchMath.displayName(midi: 61, notation: "numbered"), "1♯4")
        XCTAssertEqual(PitchMath.displayName(midi: 59, notation: "german"), "H3")
        XCTAssertEqual(PitchMath.displayName(midi: 58, notation: "german"), "A♯3")
        XCTAssertEqual(PitchMath.displayName(midi: -1), "B-2")
        // The data names stay ASCII, so they still parse.
        XCTAssertEqual(PitchMath.noteName(midi: 70), "A#4")
        XCTAssertEqual(PitchMath.parseNote(PitchMath.noteName(midi: 70)), 70)
    }

    func testNamesThatNameNotesShowSigns() {
        XCTAssertEqual(NoteNames.glyphs("Eb standard"), "E♭ standard")
        XCTAssertEqual(NoteNames.glyphs("Key of Bb"), "Key of B♭")
        XCTAssertEqual(NoteNames.glyphs("Eb-Standard"), "E♭-Standard")
        XCTAssertEqual(NoteNames.glyphs("Ebスタンダード"), "E♭スタンダード")
        XCTAssertEqual(NoteNames.glyphs("キー：Bb"), "キー：B♭")
        XCTAssertEqual(NoteNames.glyphs("Tonalité de Mib"), "Tonalité de Mi♭")
        XCTAssertEqual(NoteNames.glyphs("Tonalidad de Sib"), "Tonalidad de Si♭")
        XCTAssertEqual(NoteNames.glyphs("Clarinet (Bb / A)"), "Clarinet (B♭ / A)")
        XCTAssertEqual(NoteNames.glyphs("Saxophone (alto Eb / tenor Bb)"), "Saxophone (alto E♭ / tenor B♭)")
        // Words, German letters and interval names are left alone.
        for text in ["Standard", "Drop D", "DADGAD", "Open G", "Tonart B", "Tonart Es", "Abend", "Bass", "Bebop", "b3", "#1",
                     "dB", "Ebbe", "Mi bémol standard", "Eb7b9"] {
            XCTAssertEqual(NoteNames.glyphs(text), text == "Eb7b9" ? "E♭7b9" : text, text)
        }
    }

    func testTuningNamesShowSignsButKeepTheirData() throws {
        let catalog = try Catalog()
        let eFlat = try XCTUnwrap(catalog.tuning(id: "guitar.acoustic.6.eb_std"))
        XCTAssertEqual(eFlat.name.localized, "E♭ standard")
        XCTAssertEqual(eFlat.name.defaultValue, "Eb standard")
        XCTAssertEqual(eFlat.name.key, "timbre_catalog_tuning_guitar_acoustic_6_eb_std")
        XCTAssertEqual(eFlat.courses.first?.label, "Eb2")
        let harmonica = try XCTUnwrap(catalog.tuning(id: "harmonica.diatonic.0.key_bb"))
        XCTAssertEqual(harmonica.name.localized, "Key of B♭")
        XCTAssertEqual(try XCTUnwrap(catalog.tuning(id: "guitar.acoustic.6.standard")).name.localized, "Standard")
        // Catalog names that aren't tunings, and a player's own tuning name, show as written.
        XCTAssertEqual(LocalizedText(defaultValue: "Eb standard").localized, "Eb standard")
        let custom = CustomTuning(instrumentId: "guitar.acoustic.6", name: "Open Eb", midis: [39, 46, 51, 55, 58, 63])
        XCTAssertEqual(custom.tuning(base: eFlat).name.localized, "Open Eb")
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
