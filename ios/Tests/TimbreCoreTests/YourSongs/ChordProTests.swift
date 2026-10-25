import XCTest
@testable import TimbreCore

final class ChordProTests: XCTestCase {
    private let amazingGrace = """
    {title: Amazing Grace}
    {artist: John Newton}
    {key: G}
    {tempo: 90}
    {time: 3/4}
    {capo: 2}
    # a note for whoever edits the file
    {c: Gently}

    {start_of_verse: Verse 1}
    A[G]mazing [G7]grace, how [C]sweet the [G]sound
    {end_of_verse}

    {soc}
    [D]Chorus line [G]here
    {eoc}

    {chorus}
    """

    func testReadsDirectivesSectionsAndChords() {
        let chart = ChordProParser.parse(amazingGrace)
        XCTAssertEqual(chart.title, "Amazing Grace")
        XCTAssertEqual(chart.artist, "John Newton")
        XCTAssertEqual(chart.key, "G")
        XCTAssertEqual(chart.tempo, 90)
        XCTAssertEqual(chart.meter, ChartMeter(beats: 3, unit: 4))
        XCTAssertEqual(chart.beatsPerBar, 3)
        XCTAssertEqual(chart.capo, 2)
        XCTAssertEqual(chart.sections.map(\.kind), [.untitled, .verse, .chorus, .chorus])
        XCTAssertEqual(chart.sections[0].lines, [.comment("Gently")])
        XCTAssertEqual(chart.sections[1].label, "Verse 1")
        XCTAssertTrue(chart.sections[3].isRepeat, "{chorus} repeats the chorus")
        XCTAssertEqual(chart.sections[3].lines, chart.sections[2].lines)
        XCTAssertEqual(chart.sections[1].lines.first, .lyrics([
            ChartSegment(chord: nil, text: "A"), ChartSegment(chord: "G", text: "mazing "), ChartSegment(chord: "G7", text: "grace, how "),
            ChartSegment(chord: "C", text: "sweet the "), ChartSegment(chord: "G", text: "sound"),
        ]))
        XCTAssertEqual(chart.chordSequence.map(\.chord), ["G", "G7", "C", "G", "D", "G", "D", "G"])
        XCTAssertEqual(chart.uniqueChords.map(\.text), ["G", "G7", "C", "D"])
        XCTAssertTrue(chart.hasLyrics)
    }

    func testIsLenientWithRealWorldFiles() {
        let messy = "\u{FEFF}{t:Song}\r\n{st:Sub}\r\n[Am]Hello [*N.C.] world [F\r\n{ start_of_chorus label=\"Big Chorus\" }\r\n"
            + "[C]la\r\n{end_of_chorus}\r\n{unknown_directive: x}\r\n{TITLE: Not this one}\r\n{new_song}\r\n{title: Other}\r\n[G]x"
        let chart = ChordProParser.parse(messy)
        XCTAssertEqual(chart.title, "Song", "the first title wins, and a songbook's later songs are left out")
        XCTAssertEqual(chart.subtitle, "Sub")
        XCTAssertEqual(chart.sections.count, 2)
        XCTAssertEqual(chart.sections[1].label, "Big Chorus")
        XCTAssertEqual(chart.sections[0].lines.first, .lyrics([ChartSegment(chord: "Am", text: "Hello "), ChartSegment(chord: "*N.C.", text: " world [F")]))
        XCTAssertEqual(chart.chordSequence.map(\.chord), ["Am", "C"], "annotations are not chords to time")
    }

    func testCustomSectionsTabsAndOldMacLineEnds() {
        let text = "{title: Riff}\r{start_of_solo}\r[E5]Go\r{end_of_solo}\r{sot}\re|--0--3--|\r# not a comment in a tab\r{eot}"
        let chart = ChordProParser.parse(text)
        XCTAssertEqual(chart.sections.count, 2)
        XCTAssertEqual(chart.sections[0].kind, .other)
        XCTAssertEqual(chart.sections[0].label, "Solo")
        XCTAssertEqual(chart.sections[1].kind, .tab)
        XCTAssertEqual(chart.sections[1].lines, [.verbatim("e|--0--3--|"), .verbatim("# not a comment in a tab")])
    }

    func testLooseParagraphsBecomeSections() {
        let chart = ChordProParser.parse("{title: T}\n[G]One\n[C]Two\n\n\n[D]Three")
        XCTAssertEqual(chart.sections.count, 2)
        XCTAssertEqual(chart.sections.map(\.kind), [.untitled, .untitled])
        XCTAssertEqual(chart.sections[0].lines.count, 2)
    }

    func testMeters() {
        XCTAssertEqual(ChartMeter("6/8"), ChartMeter(beats: 6, unit: 8))
        XCTAssertEqual(ChartMeter("C")?.text, "4/4")
        XCTAssertNil(ChartMeter("5"))
        XCTAssertNil(ChartMeter("4/3"))
    }

    // MARK: Chord sheets with chords over the words

    private let wonderwall = """
    Oasis - Wonderwall
    Capo 2

    [Intro]
    Em7   G   Dsus4   A7sus4

    [Verse 1]
    Em7          G
    Today is gonna be the day
            Dsus4              A7sus4
    That they're gonna throw it back to you
    """

    func testConvertsChordsOverWords() {
        let chart = ChordProParser.parse(wonderwall)
        XCTAssertEqual(chart.title, "Wonderwall")
        XCTAssertEqual(chart.artist, "Oasis")
        XCTAssertEqual(chart.capo, 2)
        XCTAssertEqual(chart.sections.map(\.label), ["Intro", "Verse 1"])
        XCTAssertEqual(chart.sections[1].lines.first, .lyrics([ChartSegment(chord: "Em7", text: "Today is gonn"), ChartSegment(chord: "G", text: "a be the day")]))
        XCTAssertEqual(chart.sections[1].lines.last, .lyrics([
            ChartSegment(chord: nil, text: "That the"), ChartSegment(chord: "Dsus4", text: "y're gonna throw it"),
            ChartSegment(chord: "A7sus4", text: " back to you"),
        ]))
        XCTAssertEqual(chart.chordSequence.count, 8)

        let converted = ChordProImport.convert(wonderwall, fallbackTitle: nil)
        XCTAssertTrue(converted.contains("{start_of_verse: Intro}"))
        XCTAssertTrue(converted.contains("[Em7]   [G]   [Dsus4]   [A7sus4]"))
        XCTAssertTrue(ChordProImport.looksLikeChordPro(converted))
        XCTAssertFalse(ChordProImport.looksLikeChordPro(wonderwall))
    }

    func testLyricsAreNeverTakenForChords() {
        let sheet = "Go go go\nG\nA little song"
        let converted = ChordProImport.convert(sheet, fallbackTitle: "Test")
        XCTAssertTrue(converted.hasPrefix("{title: Test}"))
        XCTAssertTrue(converted.contains("Go go go"))
        XCTAssertTrue(converted.contains("[G]A little song"))
        XCTAssertNil(ChordProImport.chordLine("A man walks in"))
        XCTAssertEqual(ChordProImport.chordLine("| G  D/F# | Em x2 |")?.map(\.text), ["G", "D/F#", "Em"])
        XCTAssertEqual(ChordProImport.chordLine("(G)  N.C.  C*")?.map(\.text), ["G", "C"])
    }

    func testSectionNamesTabsAndDetails() {
        XCTAssertEqual(ChordProImport.sectionHeader("[Chorus]")?.kind, "chorus")
        XCTAssertEqual(ChordProImport.sectionHeader("Verse 2:")?.label, "Verse 2")
        XCTAssertEqual(ChordProImport.sectionHeader("PRE-CHORUS")?.kind, "bridge")
        XCTAssertEqual(ChordProImport.sectionHeader("(Outro x2)")?.kind, "verse")
        XCTAssertNil(ChordProImport.sectionHeader("Chorus girls are dancing"))
        XCTAssertNil(ChordProImport.sectionHeader("[G]"))
        XCTAssertTrue(ChordProImport.isTabLine("e|--0--3--|"))
        XCTAssertTrue(ChordProImport.isTabLine("A|-----2-h4--|"))
        XCTAssertFalse(ChordProImport.isTabLine("| G | D |"))
        XCTAssertEqual(ChordProImport.metadata("Capo: 3rd fret"), "{capo: 3}")
        XCTAssertEqual(ChordProImport.metadata("Key: Bb"), "{key: Bb}")
        XCTAssertEqual(ChordProImport.metadata("Tempo: 96 bpm"), "{tempo: 96}")
        XCTAssertEqual(ChordProImport.metadata("Time: 3/4"), "{time: 3/4}")
        XCTAssertNil(ChordProImport.metadata("Time after time"))
        XCTAssertNil(ChordProImport.metadata("Keys to the kingdom"))

        let withTab = ChordProParser.parse("Night Drive\n\ne|--0--3--|\nB|--1--0--|\n\n[Verse]\nG\nWords here")
        XCTAssertEqual(withTab.title, "Night Drive")
        XCTAssertEqual(withTab.sections.first?.kind, .tab)
        XCTAssertEqual(withTab.sections.first?.lines.count, 2)
        XCTAssertEqual(withTab.sections.last?.lines, [.lyrics([ChartSegment(chord: "G", text: "Words here")])])
    }

    func testChordProKeepsItsOwnTitleOrTakesTheFileName() {
        XCTAssertEqual(ChordProImport.convert("[G]Hello", fallbackTitle: "hello"), "{title: hello}\n[G]Hello")
        XCTAssertEqual(ChordProImport.convert("{title: Mine}\n[G]Hello", fallbackTitle: "file"), "{title: Mine}\n[G]Hello")
    }

    // MARK: Editing

    func testSetsDirectivesInPlace() {
        let source = "{title: A}\n\n[G]Hi"
        let keyed = ChordProEdit.setDirective("key", "G", in: source)
        XCTAssertEqual(keyed, "{title: A}\n{key: G}\n\n[G]Hi")
        XCTAssertEqual(ChordProEdit.setDirective("title", "B", in: keyed), "{title: B}\n{key: G}\n\n[G]Hi")
        XCTAssertEqual(ChordProEdit.setDirective("key", nil, in: keyed), source)
        XCTAssertEqual(ChordProEdit.setDirective("title", "C", in: "{t: A}\n[G]x"), "{title: C}\n[G]x")
    }

    func testTapsChordsOntoWords() throws {
        let source = "{title: A}\nHello world\n[G]Amazing grace"
        let rows = ChordProEdit.words(in: source)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].map(\.text), ["Hello", "world"])
        XCTAssertEqual(rows[1].map(\.chord), ["G", nil])
        let world = try XCTUnwrap(rows[0].last)
        let withC = ChordProEdit.setChord("C", on: world, in: source)
        XCTAssertEqual(withC, "{title: A}\nHello [C]world\n[G]Amazing grace")
        let amazing = rows[1][0]
        XCTAssertEqual(ChordProEdit.setChord("D", on: amazing, in: source), "{title: A}\nHello world\n[D]Amazing grace")
        XCTAssertEqual(ChordProEdit.setChord(nil, on: amazing, in: source), "{title: A}\nHello world\nAmazing grace")
        // A chord standing alone is a word of its own.
        let alone = ChordProEdit.words(in: "[G]  [D]")
        XCTAssertEqual(alone.first?.map(\.chord), ["G", "D"])
    }

    func testNewChart() {
        let text = ChordProEdit.newChart(title: "Mine", artist: "Me", lyrics: "line one\nline two")
        let chart = ChordProParser.parse(text)
        XCTAssertEqual(chart.title, "Mine")
        XCTAssertEqual(chart.artist, "Me")
        XCTAssertEqual(chart.sections.first?.lines.count, 2)
        XCTAssertTrue(chart.chordSequence.isEmpty)
    }
}
