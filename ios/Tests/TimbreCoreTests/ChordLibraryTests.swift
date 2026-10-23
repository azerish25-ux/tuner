import XCTest
@testable import TimbreCore

/// The curated guitar chord table, playability and fingering, scale intervals and the scale run,
/// and the single tuning-quest counter.
final class ChordLibraryTests: XCTestCase {
    private let guitar = ChordLibrary.standardGuitar
    private let ukulele = [67, 60, 64, 69]

    private func notations(_ root: Int, _ id: String) -> [String] {
        ChordLibrary.voicings(root: root, formula: .byId(id), openMidi: guitar, limit: 8).map(\.notation)
    }

    /// Every shape for every root and quality the Chords tool offers spells its chord (only chord tones,
    /// every required tone, root in the bass) and fits a hand: four frets, four fingers, a fingering.
    /// Mirrors the chord check in tools/curriculum/lib.py, plus the bass and playability rules.
    func testEveryCuratedShapeSpellsItsChordAndIsPlayable() {
        for formula in ChordFormula.all {
            for root in 0..<12 {
                let shapes = ChordLibrary.curated(root: root, formula: formula)
                XCTAssertGreaterThanOrEqual(shapes.count, 2, "\(formula.id) \(root)")
                XCTAssertEqual(Set(shapes.map(\.frets)).count, shapes.count, "duplicates in \(formula.id) \(root)")
                let tones = Set(formula.intervals.map { (root + $0) % 12 })
                for shape in shapes {
                    let label = "\(formula.id) \(root) \(shape.notation)"
                    XCTAssertEqual(shape.frets.count, 6, label)
                    XCTAssertTrue(ChordLibrary.spells(shape.frets, root: root, formula: formula), label)
                    let pitches = shape.frets.enumerated().compactMap { string, fret in fret.map { guitar[string] + $0 } }
                    XCTAssertTrue(Set(pitches.map { $0 % 12 }).isSubset(of: tones), label)
                    XCTAssertEqual(pitches.min().map { $0 % 12 }, root, label)
                    XCTAssertTrue(shape.isPlayable, label)
                    XCTAssertLessThanOrEqual(shape.highestFret, ChordLibrary.maxFret, label)
                    XCTAssertLessThanOrEqual(shape.highestFret - shape.lowestFret, 3, label)
                    let fingers = shape.fingers
                    XCTAssertNotNil(fingers, label)
                    for (string, fret) in shape.frets.enumerated() {
                        let finger = fingers?[string] ?? -1
                        if let fret, fret > 0 { XCTAssertTrue((1...4).contains(finger), label) } else { XCTAssertEqual(finger, 0, label) }
                    }
                }
            }
        }
    }

    func testOpenShapesComeFirstThenBarreFamilies() {
        XCTAssertEqual(Array(notations(0, "maj").prefix(3)), ["x32010", "x35553", "8-10-10-9-8-8"])
        XCTAssertEqual(notations(7, "maj").first, "320003")
        XCTAssertEqual(notations(4, "maj").first, "022100")
        XCTAssertEqual(notations(9, "min").first, "x02210")
        XCTAssertEqual(notations(11, "min").first, "x24432")
        XCTAssertTrue(notations(5, "maj").contains("133211"))
        XCTAssertEqual(notations(0, "7").first, "x32310")
        XCTAssertEqual(notations(4, "7").first, "020100")
        XCTAssertEqual(notations(2, "maj").first, "xx0232")
        XCTAssertEqual(notations(3, "maj").first, "xx1343", "E♭ has no open shape: lowest position first")
        // The odd algorithmic voicings are gone for C.
        XCTAssertFalse(notations(0, "maj").contains("875050"))
        XCTAssertFalse(notations(0, "maj").contains("875080"))
    }

    func testShiftedStandardTuningsReuseTheTable() {
        let ebStandard = guitar.map { $0 - 1 }
        XCTAssertEqual(ChordLibrary.standardShift(ebStandard), -1)
        XCTAssertNil(ChordLibrary.standardShift([38, 45, 50, 55, 59, 64]), "drop D is not standard")
        // E♭ major in E♭ standard is played with the E major shapes.
        XCTAssertEqual(ChordLibrary.voicings(root: 3, formula: .byId("maj"), openMidi: ebStandard).first?.notation, "022100")
    }

    func testOtherTuningsFallBackToPlayableFinderShapes() {
        XCTAssertEqual(ChordLibrary.voicings(root: 0, formula: .byId("maj"), openMidi: ukulele).first?.notation, "0003")
        let dropD = [38, 45, 50, 55, 59, 64]
        for formula in ChordFormula.all {
            for root in 0..<12 {
                for shape in ChordLibrary.voicings(root: root, formula: formula, openMidi: dropD) {
                    XCTAssertTrue(shape.isPlayable, "\(formula.id) \(root) \(shape.notation)")
                    XCTAssertTrue(ChordLibrary.spells(shape.frets, root: root, formula: formula, openMidi: dropD), shape.notation)
                }
            }
        }
    }

    func testPlayabilityAndFingering() {
        // A five-fret stretch, and five notes with no barre to hold them, are out.
        XCTAssertFalse(ChordFingering.isPlayable([3, 5, 0, 4, 7, 3]))
        XCTAssertFalse(ChordFingering.isPlayable([1, 2, 3, 4, 0, 2]))
        // A barre that would have to cross an open string doesn't count.
        XCTAssertEqual(ChordFingering.fingersNeeded([nil, 1, 0, 1, 1, 1]), 2)
        XCTAssertEqual(ChordFingering.fingersNeeded([1, 3, 3, 2, 1, 1]), 4)
        XCTAssertEqual(ChordFingering.fingers([nil, 3, 2, 0, 1, 0]), [0, 3, 2, 0, 1, 0])
        XCTAssertEqual(ChordFingering.fingers([1, 3, 3, 2, 1, 1]), [1, 3, 4, 2, 1, 1])
        XCTAssertEqual(ChordFingering.fingers([nil, 3, 5, 5, 5, 3]), [0, 1, 2, 3, 4, 1])
        XCTAssertEqual(ChordFingering.fingers([nil, nil, 3, 2, 1, 1]), [0, 0, 3, 2, 1, 1])
        XCTAssertEqual(ChordFingering.fingers([nil, 3, 2, 3, 3, 3]), [0, 2, 1, 3, 3, 3])
        XCTAssertEqual(ChordShape(frets: [8, 10, 10, 9, 8, 8], score: 0).notation, "8-10-10-9-8-8")
        XCTAssertEqual(ChordShape(frets: [nil, 3, 2, 0, 1, 0], score: 0).notation, "x32010")
    }

    func testScaleTonesAreNamedAsIntervals() {
        let minorPentatonic = ScaleFormula.all.first { $0.id == "pent_minor" }!
        let positions = ScaleMap.positions(root: 0, scale: minorPentatonic, openMidi: guitar)
        XCTAssertEqual(Set(positions.map(\.intervalName)), ["R", "♭3", "4", "5", "♭7"])
        XCTAssertTrue(positions.filter(\.isRoot).allSatisfy { $0.intervalName == "R" })
        let blues = ScaleFormula.all.first { $0.id == "blues" }!
        XCTAssertTrue(ScaleMap.positions(root: 4, scale: blues, openMidi: guitar).contains { $0.intervalName == "♭5" })
        XCTAssertEqual(IntervalName.short(-1), "7")
    }

    func testScaleRunStaysInPositionAndClimbsAnOctave() {
        let minorPentatonic = ScaleFormula.all.first { $0.id == "pent_minor" }!
        let run = ScaleMap.run(root: 0, scale: minorPentatonic, openMidi: guitar)
        XCTAssertEqual(run.map { [$0.string, $0.fret] }, [[1, 3], [1, 6], [2, 3], [2, 5], [3, 3], [3, 5]])
        XCTAssertEqual(run.map(\.intervalName), ["R", "♭3", "4", "5", "♭7", "R"])
        let pitches = run.map { guitar[$0.string] + $0.fret }
        XCTAssertEqual(pitches.map { $0 - pitches[0] }, [0, 3, 5, 7, 10, 12])
        // Open position when the root is an open string; every scale on every root climbs in order.
        let a = ScaleMap.run(root: 9, scale: minorPentatonic, openMidi: guitar)
        XCTAssertEqual(a.first.map { [$0.string, $0.fret] }, [1, 0])
        for scale in ScaleFormula.all {
            for root in 0..<12 {
                let notes = ScaleMap.run(root: root, scale: scale, openMidi: guitar).map { guitar[$0.string] + $0.fret }
                XCTAssertEqual(notes.count, scale.intervals.count + 1, "\(scale.id) \(root)")
                XCTAssertEqual(notes.map { $0 - (notes.first ?? 0) }, scale.intervals + [12], "\(scale.id) \(root)")
            }
        }
    }

    func testOneTuningQuestWithOneCounter() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12))!
        for offset in 0..<120 {
            let quests = Quests.daily(for: start.addingTimeInterval(Double(offset) * 86_400), calendar: calendar)
            XCTAssertEqual(quests.count, 3)
            XCTAssertEqual(quests.first?.kind, .tuneAll)
            XCTAssertEqual(quests.filter { Quests.tuningKinds.contains($0.kind) }.count, 1, "one tuning quest a day")
        }
        let tune = Quest(kind: .tuneAll, target: 1, xp: 20)
        XCTAssertTrue(Quests.counter(for: tune, progress: 0, lockedStrings: 1, strings: 6) == (done: 1, total: 6))
        XCTAssertTrue(Quests.counter(for: tune, progress: 1, lockedStrings: 0, strings: 6) == (done: 6, total: 6), "paid out: full")
        XCTAssertTrue(Quests.counter(for: tune, progress: 0, lockedStrings: 9, strings: 4) == (done: 4, total: 4))
        XCTAssertTrue(Quests.counter(for: tune, progress: 0, lockedStrings: 0, strings: 0) == (done: 0, total: 1), "no strings (chromatic)")
        let ear = Quest(kind: .earCorrect, target: 10, xp: 20)
        XCTAssertTrue(Quests.counter(for: ear, progress: 4, lockedStrings: 3, strings: 6) == (done: 4, total: 10))
        // Saved progress under the retired id still decodes and validates.
        var state = ProgressState()
        state.questDay = "2026-01-01"
        state.questProgress = ["holdInTune": 2, "tuneAll": 1]
        let data = try? JSONEncoder().encode(state)
        let decoded = data.flatMap { try? JSONDecoder().decode(ProgressState.self, from: $0) }
        XCTAssertEqual(decoded?.questProgress["holdInTune"], 2)
        XCTAssertEqual(decoded?.isValid, true)
    }
}
