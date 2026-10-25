import XCTest
@testable import TimbreCore

/// The band's styles (TimbreCore/Audio/BandGroove.swift): which style each Originals song gets, how the band
/// recognises a song from what a step asks it to play, and what each style's bar holds.
final class BandGrooveTests: XCTestCase {
    private func context(meter: Int = 4, swing: Bool = false, fill: Bool = false, lift: Bool = false, ending: Bool = false,
                         variation: Int = 0, chord: Bool = true) -> BandGroove.Context {
        BandGroove.Context(meter: meter, bpm: 100, swing: swing, fill: fill, lift: lift, ending: ending, variation: variation,
                           chord: chord, fifth: 7)
    }

    private func beats(_ groove: BandGroove, _ piece: BandGroove.Piece) -> [Double] {
        groove.hits.filter { $0.piece == piece }.map(\.beat).sorted()
    }

    // MARK: Which style

    func testOriginalsSongsGetTheStyleTheirLessonsName() throws {
        let curriculum = try Curriculum.bundled()
        let expected: [String: BandStyle] = [
            "orig-kite-weather": .pop, "orig-echo-canyon": .pop, "orig-roller-rink": .pop, "orig-open-windows": .pop,
            "orig-porchlight": .ballad, "orig-glass-satellites": .ballad, "orig-late-checkout": .ballad, "orig-jukebox-moon": .ballad,
            "orig-low-tide-radio": .reggae, "orig-hammock-season": .reggae, "orig-saltwater-sunday": .reggae,
            "orig-dust-on-the-dashboard": .country, "orig-gravel-road-two-step": .country,
            "orig-neon-laundromat": .funk, "orig-pocket-change": .funk,
            "orig-last-bell": .rock, "orig-basement-weather": .rock, "orig-cold-lake": .rock, "orig-rust-belt-shuffle": .rock,
            "orig-parking-lot-cathedral": .rock,
        ]
        for (id, style) in expected {
            let found = try XCTUnwrap(curriculum.lesson(id: id), id)
            XCTAssertEqual(BandStyle.of(found.lesson, unit: found.unit), style, id)
        }
        let originals = try XCTUnwrap(curriculum.course(id: BandStyleIndex.styledCourse))
        var counts: [BandStyle: Int] = [:]
        for unit in originals.units {
            for lesson in unit.lessons where lesson.kind == .song { counts[BandStyle.of(lesson, unit: unit), default: 0] += 1 }
        }
        for style in BandStyle.allCases where style != .standard { XCTAssertGreaterThanOrEqual(counts[style] ?? 0, 2, "\(style)") }
        XCTAssertLessThanOrEqual(counts[.standard] ?? 0, 2, "nearly every original names its style")
    }

    func testGenreWordsAndStrumPatterns() {
        XCTAssertEqual(BandStyle.named(in: ["Punk-pop"]), .rock)
        XCTAssertEqual(BandStyle.named(in: ["The power ballad"]), .ballad)
        XCTAssertEqual(BandStyle.named(in: ["Indie-rock anthem"]), .rock)
        XCTAssertEqual(BandStyle.named(in: ["Bedroom pop"]), .pop)
        XCTAssertEqual(BandStyle.named(in: ["One-drop reggae", "D7 over A minor"]), .reggae)
        XCTAssertEqual(BandStyle.named(in: ["Country two-step"]), .country)
        XCTAssertEqual(BandStyle.named(in: ["Funk scratch"]), .funk)
        XCTAssertNil(BandStyle.named(in: ["F, the easy way"]))

        let shuffle = (0..<4).flatMap { [Double($0), Double($0) + 0.667] }
        XCTAssertEqual(BandStyle.inferred(pattern: [0.5, 1.5, 2.5, 3.5], bpm: 80, meter: 4), .reggae)
        XCTAssertEqual(BandStyle.inferred(pattern: [1, 3], bpm: 76, meter: 4), .reggae)
        XCTAssertEqual(BandStyle.inferred(pattern: [0, 0.5, 1.5, 2.5, 3], bpm: 96, meter: 4), .funk)
        XCTAssertEqual(BandStyle.inferred(pattern: shuffle, bpm: 80, meter: 4), .rock)
        XCTAssertEqual(BandStyle.inferred(pattern: (0..<8).map { Double($0) / 2 }, bpm: 120, meter: 4), .rock)
        XCTAssertEqual(BandStyle.inferred(pattern: (0..<8).map { Double($0) / 2 }, bpm: 92, meter: 4), .standard)
        XCTAssertEqual(BandStyle.inferred(pattern: [0, 2, 3, 3.5], bpm: 72, meter: 4), .ballad)
        XCTAssertEqual(BandStyle.inferred(pattern: [0, 1, 1.5, 2.5, 3, 3.5], bpm: 88, meter: 4), .standard)
        XCTAssertEqual(BandStyle.inferred(pattern: [0, 1, 2], bpm: 100, meter: 3), .standard)
        // A melody's beats (more than a bar) are not a strum pattern.
        XCTAssertEqual(BandStyle.inferred(pattern: [0.5, 1.5, 4.5, 6.5], bpm: 80, meter: 4), .standard)
    }

    // MARK: Recognising a song

    func testTheBandRecognisesOriginalsStepsAndLeavesOtherCoursesStandard() throws {
        let curriculum = try Curriculum.bundled()
        let index = BandStyleIndex(curriculum: curriculum)
        XCTAssertGreaterThan(index.count, 500)
        var recognised = 0, total = 0
        for course in curriculum.courses {
            for unit in course.units {
                for lesson in unit.lessons where lesson.kind == .song {
                    let style = course.id == BandStyleIndex.styledCourse ? BandStyle.of(lesson, unit: unit) : .standard
                    for step in lesson.steps {
                        var found: BandStyle?
                        switch step {
                        case let .playAlong(notes, _, beatsPerBar, _):
                            found = BandCue.melody(notes, meter: beatsPerBar).flatMap(index.style(forCue:))
                        case let .progression(chords, bars, pattern, bpm, beatsPerBar, _, _):
                            let meter = beatsPerBar ?? max(4, Int((pattern.max() ?? 3) + 1))
                            let symbols = BandCue.perBar(chords, bars: bars)
                            found = BandCue.chords(symbols, meter: meter, pattern: pattern).flatMap(index.style(forCue:))
                                ?? BandCue.chords(symbols, meter: meter).flatMap(index.style(forCue:))
                                ?? BandStyle.inferred(pattern: pattern, bpm: bpm, meter: meter)
                        default:
                            continue
                        }
                        if course.id == BandStyleIndex.styledCourse {
                            total += 1
                            if let found {
                                XCTAssertEqual(found, style, "\(lesson.id): a step recognised as another song's style")
                                recognised += 1
                            }
                        } else if let found, found != .standard, case .playAlong = step {
                            XCTFail("\(lesson.id) (\(course.id)) plays \(found): only the Originals have styles")
                        }
                    }
                }
            }
        }
        XCTAssertGreaterThan(Double(recognised), Double(total) * 0.95, "\(recognised) of \(total) Originals steps recognised")
    }

    func testTheSharedIndexReadsTheAppsOneCurriculum() {
        XCTAssertGreaterThan(BandStyleIndex.shared.count, 500, "built from CurriculumStore's decoded curriculum")
        XCTAssertTrue(CurriculumStore.shared.isLoaded)
    }

    func testCuesIgnoreTempoAndNeedTwoChords() {
        let notes = [60, 62, 64, 65, 67, 69].enumerated().map { TimedNote(midi: $1, beat: 1 + Double($0) * 0.5, beats: 0.5, at: nil) }
        let later = notes.map { TimedNote(midi: $0.midi, beat: $0.beat + 4, beats: $0.beats * 2, at: nil) }
        XCTAssertNotNil(BandCue.melody(notes, meter: 4))
        XCTAssertEqual(BandCue.melody(notes, meter: 4), BandCue.melody(later, meter: 4))
        XCTAssertNotEqual(BandCue.melody(notes, meter: 4), BandCue.melody(notes, meter: 3))
        XCTAssertNil(BandCue.melody(Array(notes.prefix(3)), meter: 4))
        XCTAssertNil(BandCue.chords(["G", "G", "G", "G"], meter: 4), "a one-chord strum names no song")
        XCTAssertNotNil(BandCue.chords(["G", "D", "Em", "C"], meter: 4))
        XCTAssertNotEqual(BandCue.chords(["G", "D"], meter: 4, pattern: [0, 1]), BandCue.chords(["G", "D"], meter: 4))
    }

    // MARK: What each style plays

    func testEveryStyleStaysInsideItsBarInEveryMeter() {
        for style in BandStyle.allCases {
            for meter in [2, 3, 4, 5, 6, 12] {
                for (fill, lift, chord, swing) in [(false, false, true, false), (true, false, true, true), (false, true, false, false)] {
                    let groove = BandGroove.bar(style, context(meter: meter, swing: swing, fill: fill, lift: lift, chord: chord))
                    let bar = Double(meter)
                    XCTAssertFalse(groove.hits.isEmpty, "\(style) \(meter)")
                    XCTAssertTrue(groove.hits.allSatisfy { $0.beat >= 0 && $0.beat < bar && $0.velocity > 0 && $0.velocity <= 1 }, "\(style) \(meter)")
                    XCTAssertTrue(groove.bass.allSatisfy { $0.beat >= 0 && $0.beat < bar && $0.beats > 0 }, "\(style) \(meter)")
                    XCTAssertTrue(groove.comp.allSatisfy { $0.beat >= 0 && $0.beat < bar && $0.beats > 0 && $0.velocity > 0 }, "\(style) \(meter)")
                    if !chord { XCTAssertTrue(groove.comp.isEmpty, "\(style) \(meter): nothing to comp without a chord") }
                }
                let ending = BandGroove.bar(style, context(meter: meter, ending: true))
                XCTAssertEqual(Set(beats(ending, .kick) + beats(ending, .crash)), [0], "\(style) ends on a cymbal")
                XCTAssertEqual(ending.bass.map(\.interval), [0])
            }
        }
    }

    func testTheStandardGrooveIsTheCoursesOwn() {
        let groove = BandGroove.bar(.standard, context())
        XCTAssertEqual(beats(groove, .kick), [0, 2])
        XCTAssertEqual(beats(groove, .snare), [1, 3])
        XCTAssertEqual(beats(groove, .hat).count, 8)
        XCTAssertEqual(groove.bass.map(\.beat), [0, 2, 3.5])
        XCTAssertEqual(groove.comp.map(\.beat), [0, 2, 3.5])
        XCTAssertTrue(groove.comp.allSatisfy { $0.part == .piano })
        let fill = BandGroove.bar(.standard, context(fill: true))
        XCTAssertEqual(beats(fill, .snare), [1, 3, 3.25, 3.5, 3.75])
        // The lift is the bigger styles' crash; the standard groove ignores it.
        XCTAssertEqual(BandGroove.bar(.standard, context(lift: true)), groove)
    }

    func testReggaeIsAOneDropWithASkank() {
        let groove = BandGroove.bar(.reggae, context())
        XCTAssertFalse(beats(groove, .kick).contains(0), "the drop: nothing on one")
        XCTAssertEqual(beats(groove, .kick), [2])
        XCTAssertEqual(beats(groove, .xstick), [2])
        let skank = groove.comp.filter { $0.part == .chop }
        XCTAssertEqual(skank.map(\.beat), [1, 3])
        XCTAssertTrue(skank.allSatisfy(\.up))
        XCTAssertFalse(groove.bass.contains { $0.beat == 0 }, "the bass waits out the drop too")
    }

    func testCountryIsATwoStep() {
        let groove = BandGroove.bar(.country, context())
        XCTAssertEqual(beats(groove, .kick), [0, 2])
        XCTAssertEqual(beats(groove, .snare), [1, 3])
        XCTAssertEqual(groove.bass.prefix(2).map(\.beat), [0, 2])
        XCTAssertEqual(groove.bass.prefix(2).map(\.interval), [0, 7], "boom on the root, then the fifth")
        XCTAssertEqual(groove.comp.filter { $0.part == .chop }.map(\.beat), [1, 3], "the chick on two and four")
    }

    func testFunkScratchesSixteenthsOverGhostNotes() {
        let groove = BandGroove.bar(.funk, context())
        XCTAssertGreaterThanOrEqual(beats(groove, .hat).count, 12)
        XCTAssertTrue(groove.hits.contains { $0.piece == .snare && $0.velocity < 0.25 }, "ghost notes")
        let scratch = groove.comp.filter { $0.part == .chop }
        XCTAssertEqual(scratch.count, 16)
        XCTAssertEqual(Set(scratch.filter { $0.velocity >= 0.7 }.map(\.beat)), [1, 3], "accents on the backbeat")
        XCTAssertTrue(groove.bass.contains { $0.interval == 12 }, "octave pops")
    }

    func testRockPopAndBalladEachSoundTheirPart() {
        let rock = BandGroove.bar(.rock, context())
        XCTAssertEqual(rock.comp.filter { $0.part == .power }.count, 8, "power chords on the eighths")
        XCTAssertEqual(rock.bass.count, 8, "driving eighths")
        XCTAssertTrue(BandGroove.bar(.rock, context(lift: true)).hits.contains { $0.piece == .crash && $0.beat == 0 })
        let rockFill = BandGroove.bar(.rock, context(fill: true))
        XCTAssertFalse(beats(rockFill, .tomhi).isEmpty)
        XCTAssertFalse(beats(rockFill, .tomlo).isEmpty)
        let shuffle = BandGroove.bar(.rock, context(swing: true))
        XCTAssertEqual(Set(shuffle.bass.map(\.interval)), [0, 7, 9], "a shuffle's boogie")

        let pop = BandGroove.bar(.pop, context())
        XCTAssertEqual(beats(pop, .tamb), [1, 3])
        XCTAssertEqual(beats(pop, .snare), [1, 3])

        let ballad = BandGroove.bar(.ballad, context())
        XCTAssertEqual(beats(ballad, .xstick), [1, 3])
        let broken = ballad.comp.filter { $0.part == .arpeggio }
        XCTAssertEqual(broken.count, 8)
        XCTAssertEqual(broken.first?.tone, 0, "the broken chord starts on its bass note")
        XCTAssertEqual(BandGroove.bar(.ballad, context(meter: 3)).comp.filter { $0.part == .arpeggio }.count, 6)
        XCTAssertEqual(BandGroove.bar(.rock, context(meter: 6)).comp.filter { $0.part == .power }.count, 6)
    }
}
