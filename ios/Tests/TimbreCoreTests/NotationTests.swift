import XCTest
@testable import TimbreCore

final class NotationTests: XCTestCase {
    private func notes(_ list: [(Int, Double, Double)]) -> [TimedNote] {
        list.map { TimedNote(midi: $0.0, beat: $0.1, beats: $0.2) }
    }

    /// The written values of a bar, "q", "e.", "h" …, a rest as "r", a note held over from the last with "~".
    private func values(_ measure: NotationMeasure) -> [String] {
        measure.events.map { event in
            let names = ["w", "h", "q", "e", "s"]
            let value = names[event.duration.level] + (event.duration.dotted ? "." : "")
            if event.isRest { return "r" + value }
            return (event.continued ? "~" : "") + value
        }
    }

    // MARK: Key signatures

    func testKeySignaturesTakeTheSpellingWithFewerAccidentals() {
        XCTAssertEqual(KeySignature(tonic: 7, minor: false).fifths, 1)     // G
        XCTAssertEqual(KeySignature(tonic: 5, minor: false).fifths, -1)    // F
        XCTAssertEqual(KeySignature(tonic: 1, minor: false).fifths, -5)    // D♭, not C♯
        XCTAssertEqual(KeySignature(tonic: 11, minor: false).fifths, 5)    // B, not C♭
        XCTAssertEqual(KeySignature(tonic: 6, minor: false).fifths, 6)     // F♯ major
        XCTAssertEqual(KeySignature(tonic: 3, minor: true).fifths, -6)     // E♭ minor
        XCTAssertEqual(KeySignature(tonic: 9, minor: true).fifths, 0)      // A minor
        XCTAssertEqual(KeySignature(tonic: 4, minor: true).fifths, 1)      // E minor
        XCTAssertEqual(KeySignature(tonic: 0, minor: true).fifths, -3)     // C minor
        XCTAssertEqual(KeySignature(tonic: 2, minor: false).letters, [3, 0])       // F♯ C♯
        XCTAssertEqual(KeySignature(tonic: 10, minor: false).letters, [6, 2])      // B♭ E♭
    }

    func testSignaturesSitWhereTheyAreWrittenOnEachClef() {
        XCTAssertEqual(Clef.treble.positions(of: KeySignature(fifths: 2)), [8, 5])
        XCTAssertEqual(Clef.treble.positions(of: KeySignature(fifths: -3)), [4, 7, 3])
        XCTAssertEqual(Clef.bass.positions(of: KeySignature(fifths: 1)), [6])
        XCTAssertEqual(Clef.bass.positions(of: KeySignature(fifths: -2)), [2, 5])
    }

    // MARK: Spelling

    private func name(_ pitch: SpelledPitch) -> String {
        let signs = [-2: "bb", -1: "b", 0: "", 1: "#", 2: "x"]
        return ["C", "D", "E", "F", "G", "A", "B"][pitch.letter] + (signs[pitch.alter] ?? "?") + "\(pitch.octave)"
    }

    func testNotesOfTheKeyTakeTheirOwnLetters() {
        let g = KeySignature(tonic: 7, minor: false)
        XCTAssertEqual(name(g.spell(66)), "F#4")
        XCTAssertEqual(name(g.spell(65)), "F4", "F natural in G major, not E sharp")
        XCTAssertEqual(name(KeySignature(tonic: 5, minor: false).spell(70)), "Bb4")
        XCTAssertEqual(name(KeySignature(tonic: 5, minor: false).spell(71)), "B4")
        XCTAssertEqual(name(KeySignature(tonic: 11, minor: false).spell(70)), "A#4")
    }

    func testMinorKeysRaiseTheirSixthAndSeventh() {
        XCTAssertEqual(name(KeySignature(tonic: 9, minor: true).spell(68)), "G#4")
        XCTAssertEqual(name(KeySignature(tonic: 6, minor: true).spell(65)), "E#4")
        XCTAssertEqual(name(KeySignature(tonic: 2, minor: true).spell(71)), "B4")
        XCTAssertEqual(name(KeySignature(tonic: 2, minor: true).spell(61)), "C#4")
    }

    func testChromaticNotesReadAsStepsFromTheirNeighbours() {
        let c = KeySignature.empty
        let e = SpelledPitch(letter: 2, alter: 0, octave: 4)
        let g = SpelledPitch(letter: 4, alter: 0, octave: 4)
        XCTAssertEqual(name(c.spell(66, after: e, before: 64)), "F#4", "E F♯ E, not E G♭ E")
        XCTAssertEqual(name(c.spell(68, after: g, before: 67)), "Ab4", "G A♭ G")
        XCTAssertEqual(name(c.spell(68, after: g, before: 69)), "G#4", "G G♯ A")
        XCTAssertEqual(name(c.spell(61, before: 62)), "C#4")
        XCTAssertEqual(name(c.spell(61, before: 60)), "Db4")
        XCTAssertEqual(name(c.spell(63)), "Eb4")
        XCTAssertEqual(name(c.spell(66)), "F#4")
    }

    func testSpellingKeepsTheOctaveOfTheLetter() {
        let pitch = SpelledPitch(midi: 60, letter: 6, alter: 1)
        XCTAssertEqual(pitch.octave, 3, "B♯3 sounds as middle C")
        XCTAssertEqual(pitch.midi, 60)
        XCTAssertEqual(SpelledPitch(midi: 71, letter: 0, alter: -1).octave, 5, "C♭5 sounds as B4")
    }

    // MARK: Clefs

    func testClefPositions() {
        let c = KeySignature.empty
        XCTAssertEqual(Clef.treble.position(of: c.spell(64)), 0, "E4 on the bottom line")
        XCTAssertEqual(Clef.treble.position(of: c.spell(77)), 8, "F5 on the top line")
        XCTAssertEqual(Clef.treble.position(of: c.spell(60)), -2, "middle C on the first ledger line")
        XCTAssertEqual(Clef.bass.position(of: c.spell(43)), 0, "G2 on the bottom line")
        XCTAssertEqual(Clef.bass.position(of: c.spell(57)), 8, "A3 on the top line")
        let guitar = Clef.reading(instrument: "guitar.acoustic.6", midis: [])
        XCTAssertEqual(guitar, Clef(.treble, octaveDown: true))
        XCTAssertEqual(guitar.position(of: c.spell(guitar.written(40))), -7, "the low E string under three ledger lines")
        XCTAssertEqual(Clef.reading(instrument: "cello.standard.4", midis: []), .bass)
        XCTAssertEqual(Clef.reading(instrument: "bass.electric.4", midis: []), Clef(.bass, octaveDown: true))
        XCTAssertEqual(Clef.reading(instrument: "violin.standard.4", midis: []), .treble)
        XCTAssertEqual(Clef.reading(instrument: nil, midis: [43, 48, 50]), .bass)
    }

    // MARK: Rhythm

    func testANoteLongerThanTheBarIsTiedOverTheBarline() {
        let score = NotationScore(notes: notes([(72, 0, 5)]), beatsPerBar: 4, bars: 2, key: .empty, clef: .treble)
        XCTAssertEqual(score.measures.count, 2)
        XCTAssertEqual(values(score.measures[0]), ["w"])
        XCTAssertTrue(score.measures[0].events[0].tied)
        XCTAssertEqual(values(score.measures[1]), ["~q", "rq", "rh"])
        XCTAssertFalse(score.measures[1].events[0].tied)
    }

    func testSyncopationsKeepTheirShape() {
        // Eighth, quarter, eighth, half: the quarter across beat two stays one note.
        let score = NotationScore(notes: notes([(72, 0, 0.5), (74, 0.5, 1), (76, 1.5, 0.5), (77, 2, 2)]),
                                  beatsPerBar: 4, bars: 1, key: .empty, clef: .treble)
        XCTAssertEqual(values(score.measures[0]), ["e", "q", "e", "h"])
        // Quarter, half, quarter.
        let middle = NotationScore(notes: notes([(67, 0, 1), (69, 1, 2), (71, 3, 1)]), beatsPerBar: 4, bars: 1, key: .empty, clef: .treble)
        XCTAssertEqual(values(middle.measures[0]), ["q", "h", "q"])
        // A quarter from the half beat before beat three splits at the middle of the bar.
        let split = NotationScore(notes: notes([(67, 0, 1.5), (69, 1.5, 1), (71, 2.5, 1.5)]), beatsPerBar: 4, bars: 1, key: .empty, clef: .treble)
        XCTAssertEqual(values(split.measures[0]), ["q.", "e", "~e", "q."])
        XCTAssertTrue(split.measures[0].events[1].tied)
    }

    func testCompoundTimeKeepsThePulseVisible() {
        // 6/8: a half note's worth from the bar's start is a dotted quarter tied to an eighth.
        let score = NotationScore(notes: notes([(67, 0, 4), (69, 4, 2)]), beatsPerBar: 6, bars: 1, key: .empty, clef: .treble)
        XCTAssertEqual(score.meter.unit, 8)
        XCTAssertEqual(values(score.measures[0]), ["q.", "~e", "q"])
        let full = NotationScore(notes: notes([(67, 0, 6)]), beatsPerBar: 6, bars: 1, key: .empty, clef: .treble)
        XCTAssertEqual(values(full.measures[0]), ["h."])
    }

    func testGapsAreFilledWithRestsThatShowTheBeat() {
        // A note on beat two of 4/4 with nothing after it: quarter rest, quarter, then a half rest.
        let score = NotationScore(notes: notes([(67, 1, 1)]), beatsPerBar: 4, bars: 1, key: .empty, clef: .treble)
        XCTAssertEqual(values(score.measures[0]), ["rq", "q", "rh"])
        // An empty bar is one whole rest, in 3/4 too.
        let empty = NotationScore(notes: notes([(67, 0, 3)]), beatsPerBar: 3, bars: 2, key: .empty, clef: .treble)
        XCTAssertEqual(values(empty.measures[1]), ["rw"])
        XCTAssertTrue(empty.measures[1].events[0].fillsBar)
        // Off the beat, a rest fills to the beat first.
        let offbeat = NotationScore(notes: notes([(67, 0, 0.5), (69, 2, 2)]), beatsPerBar: 4, bars: 1, key: .empty, clef: .treble)
        XCTAssertEqual(values(offbeat.measures[0]), ["e", "re", "rq", "h"])
    }

    func testSwungEighthsAreWrittenStraight() {
        let score = NotationScore(notes: notes([(64, 0, 0.667), (64, 0.667, 0.333), (67, 1, 0.667), (67, 1.667, 0.333), (69, 2, 2)]),
                                  beatsPerBar: 4, bars: 1, key: .empty, clef: .treble)
        XCTAssertTrue(score.swing)
        XCTAssertEqual(values(score.measures[0]), ["e", "e", "e", "e", "h"])
    }

    // MARK: Beams

    func testEighthsAreBeamedByTheBeat() {
        let eight = notes((0..<8).map { (60 + $0, Double($0) * 0.5, 0.5) })
        let common = NotationScore(notes: eight, beatsPerBar: 4, bars: 1, key: .empty, clef: .treble)
        XCTAssertEqual(common.measures[0].beams.map(\.events), [[0, 1, 2, 3], [4, 5, 6, 7]], "two beats to a beam in 4/4")
        let six = notes((0..<6).map { (60 + $0, Double($0) * 0.5, 0.5) })
        let waltz = NotationScore(notes: six, beatsPerBar: 3, bars: 1, key: .empty, clef: .treble)
        XCTAssertEqual(waltz.measures[0].beams.map(\.events), [[0, 1], [2, 3], [4, 5]], "a beat to a beam in 3/4")
        let jig = NotationScore(notes: notes((0..<6).map { (60 + $0, Double($0), 1) }), beatsPerBar: 6, bars: 1, key: .empty, clef: .treble)
        XCTAssertEqual(jig.measures[0].beams.map(\.events), [[0, 1, 2], [3, 4, 5]], "three eighths to a beam in 6/8")
    }

    func testRestsAndLongNotesBreakBeams() {
        let score = NotationScore(notes: notes([(67, 0, 1.5), (69, 1.5, 0.5), (71, 2, 0.5), (72, 3, 0.5), (74, 3.5, 0.5)]),
                                  beatsPerBar: 4, bars: 1, key: .empty, clef: .treble)
        XCTAssertEqual(values(score.measures[0]), ["q.", "e", "e", "re", "e", "e"])
        XCTAssertEqual(score.measures[0].beams.map(\.events), [[4, 5]])
        XCTAssertNil(score.measures[0].events[1].beam, "an eighth after a dotted quarter has a flag")
    }

    func testStemsFollowTheNotesDistanceFromTheMiddleLine() {
        let score = NotationScore(notes: notes([(64, 0, 1), (71, 1, 1), (64, 2, 0.5), (72, 2.5, 0.5)]),
                                  beatsPerBar: 4, bars: 1, key: .empty, clef: .treble)
        let events = score.measures[0].events
        XCTAssertTrue(events[0].stemUp, "E4 on the bottom line: up")
        XCTAssertFalse(events[1].stemUp, "B4 on the middle line: down")
        XCTAssertTrue(events[2].stemUp && events[3].stemUp, "E4 and C5 beamed: the E is further from the middle")
    }

    // MARK: Accidentals

    func testAccidentalsLastToTheBarline() {
        // F♯ G F | F♯: the sharp once, a natural to cancel it, a sign again in the next bar.
        let score = NotationScore(notes: notes([(66, 0, 1), (67, 1, 1), (65, 2, 2), (66, 4, 4)]),
                                  beatsPerBar: 4, bars: 2, key: .empty, clef: .treble)
        let first = score.measures[0].events
        XCTAssertEqual(first[0].accidental, 1, "F♯ rising to G")
        XCTAssertNil(first[1].accidental)
        XCTAssertEqual(first[2].accidental, 0, "a natural cancels the sharp earlier in the bar")
        XCTAssertNotNil(score.measures[1].events[0].accidental, "the barline clears it")
        // Repeated chromatic notes keep one spelling: one sign for both.
        let repeated = NotationScore(notes: notes([(66, 0, 1), (66, 1, 1), (65, 2, 2)]), beatsPerBar: 4, bars: 1, key: .empty, clef: .treble)
        XCTAssertEqual(repeated.measures[0].events[0].pitch, repeated.measures[0].events[1].pitch)
        XCTAssertNil(repeated.measures[0].events[1].accidental)
        // In G major the F♯ needs nothing, the F needs a natural.
        let g = NotationScore(notes: notes([(66, 0, 2), (65, 2, 2)]), beatsPerBar: 4, bars: 1, key: KeySignature(tonic: 7, minor: false), clef: .treble)
        XCTAssertNil(g.measures[0].events[0].accidental)
        XCTAssertEqual(g.measures[0].events[1].accidental, 0)
    }

    func testANoteTiedOverTheBarlineCarriesItsOwnAccidental() {
        let score = NotationScore(notes: notes([(66, 0, 6), (66, 6, 1), (64, 7, 1)]), beatsPerBar: 4, bars: 2, key: .empty, clef: .treble)
        let second = score.measures[1].events
        XCTAssertTrue(second[0].continued)
        XCTAssertNil(second[0].accidental, "no sign on the tied note")
        XCTAssertEqual(second[1].accidental, 1, "the next F♯ in the bar is marked again")
    }

    // MARK: Lines

    func testBarsBreakIntoTheFewestEvenLines() {
        XCTAssertEqual(NotationLayout.lines(widths: [100, 100, 100, 100], available: 330, firstPrefix: 20, prefix: 20), [0..<2, 2..<4])
        XCTAssertEqual(NotationLayout.lines(widths: [100, 100, 100, 100, 100], available: 330, firstPrefix: 40, prefix: 20), [0..<2, 2..<5])
        XCTAssertEqual(NotationLayout.lines(widths: [500, 100], available: 330, firstPrefix: 20, prefix: 20), [0..<1, 1..<2])
        XCTAssertEqual(NotationLayout.lines(widths: [], available: 330, firstPrefix: 20, prefix: 20), [])
    }

    func testSpacingGrowsWithLengthButNotInProportion() {
        XCTAssertEqual(NotationLayout.space(ticks: 1), 2, accuracy: 1e-9)
        XCTAssertEqual(NotationLayout.space(ticks: 4), 3.2, accuracy: 1e-9)
        XCTAssertLessThan(NotationLayout.space(ticks: 16), 2 * NotationLayout.space(ticks: 4))
        XCTAssertEqual(NotationLayout.share(10, weights: [1, 3]), [2.5, 7.5])
        XCTAssertEqual(NotationLayout.share(9, weights: [0, 0, 0]), [3, 3, 3])
    }

    // MARK: The curriculum

    /// Every play-along in the curriculum engraves: each bar's events run back to back from its first sixteenth to its
    /// last, every value is one that can be written, every note appears, and ties join parts of the same note.
    func testEveryPlayAlongEngraves() throws {
        let curriculum = try Curriculum.bundled()
        var engraved = 0
        for course in curriculum.courses {
            let clef = Clef.reading(instrument: course.instrument, midis: [])
            for lesson in course.lessons {
                for step in lesson.steps {
                    guard case let .playAlong(list, _, beatsPerBar, _) = step else { continue }
                    let sorted = list.sorted { $0.beat < $1.beat }
                    let score = NotationScore(notes: sorted, beatsPerBar: beatsPerBar, bars: 1, key: KeySignature(tonic: 7, minor: false), clef: clef)
                    var seen = Set<Int>()
                    var open: Int?
                    for measure in score.measures {
                        var cursor = 0
                        for event in measure.events {
                            XCTAssertEqual(event.start, cursor, "\(lesson.id) bar \(measure.index)")
                            if !event.fillsBar { XCTAssertEqual(event.length, event.duration.ticks, lesson.id) }
                            cursor = event.end
                            if let note = event.note {
                                seen.insert(note)
                                if event.continued { XCTAssertEqual(open, note, "\(lesson.id): a tie joins one note") }
                                open = event.tied ? note : nil
                            } else {
                                XCTAssertNil(open, "\(lesson.id): a tie never ends on a rest")
                            }
                        }
                        XCTAssertEqual(cursor, score.meter.barTicks, "\(lesson.id) bar \(measure.index) is full")
                    }
                    let spans = NotationScore.spans(sorted, meter: score.meter, swing: score.swing)
                    XCTAssertEqual(spans.count, sorted.count, "\(lesson.id): one note at a time")
                    XCTAssertEqual(seen.count, spans.count, "\(lesson.id): every note is written")
                    engraved += 1
                }
            }
        }
        XCTAssertGreaterThan(engraved, 700)
    }
}
