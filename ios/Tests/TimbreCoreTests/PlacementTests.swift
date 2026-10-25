import XCTest
@testable import TimbreCore

/// Onboarding placement in the real courses: each experience answer starts each course where it belongs, and the
/// plan's first lesson, the placement pass (the one lesson it opens on the free plan) and Learn's next lesson are
/// the same lesson. Then the 45-second placement check: its steps, its verdict and the level it leads to.
final class PlacementTests: XCTestCase {
    private var curriculum: Curriculum!

    override func setUpWithError() throws { curriculum = try Curriculum.bundled() }

    private func course(_ id: String) throws -> LearnCourse { try XCTUnwrap(curriculum.course(id: id), id) }

    /// The unit the plan's first lesson is in, for a level.
    private func startUnit(_ level: String, in course: LearnCourse) -> String? {
        var progress = LearnProgress()
        progress.place(level: level, in: course)
        guard let lesson = progress.nextLesson(in: course) else { return nil }
        return course.units.first { unit in unit.lessons.contains { $0.id == lesson.id } }?.id
    }

    /// Beginner, a few months, a few years, many years, professional.
    private func assertStarts(_ courseId: String, _ expected: [String], file: StaticString = #filePath, line: UInt = #line) throws {
        let course = try self.course(courseId)
        let starts = CoursePlacement.levels.map { startUnit($0, in: course) ?? "none" }
        XCTAssertEqual(starts, expected, courseId, file: file, line: line)
    }

    // MARK: Each course

    func testGuitarPlacesAFewYearsAtSongsWithChordsAndManyYearsAtBarres() throws {
        // Hello · First melodies · … · Songs with chords (7) · … · Barre chords and the pentatonic (10) · … · Lead technique (13)
        try assertStarts("guitar", ["gtr-1", "gtr-2", "gtr-7", "gtr-10", "gtr-13"])
        let guitar = try course("guitar")
        XCTAssertEqual(guitar.units[6].title.defaultValue, "Songs with chords")
        XCTAssertEqual(guitar.units[9].title.defaultValue, "Barre chords and the pentatonic")
    }

    func testUkulele() throws { try assertStarts("ukulele", ["uke-1", "uke-2", "uke-5", "uke-6", "uke-7"]) }
    func testBass() throws { try assertStarts("bass", ["bass-1", "bass-2", "bass-4", "bass-5", "bass-6"]) }
    func testViolin() throws { try assertStarts("violin", ["vln-1", "vln-2", "vln-4", "vln-5", "vln-6"]) }
    func testCello() throws { try assertStarts("cello", ["vc-1", "vc-2", "vc-4", "vc-5", "vc-5"]) }
    func testMandolin() throws { try assertStarts("mandolin", ["man-1", "man-2", "man-4", "man-5", "man-6"]) }
    func testBanjo() throws { try assertStarts("banjo", ["bjo-1", "bjo-2", "bjo-4", "bjo-5", "bjo-6"]) }
    func testVoice() throws { try assertStarts("voice", ["voc-1", "voc-2", "voc-4", "voc-5", "voc-6"]) }
    func testEarTheoryAndRhythm() throws {
        try assertStarts("ear", ["ear-1", "ear-2", "ear-4", "ear-6", "ear-7"])
        try assertStarts("theory", ["thy-1", "thy-2", "thy-4", "thy-6", "thy-7"])
        try assertStarts("rhythm", ["rhy-1", "rhy-2", "rhy-3", "rhy-5", "rhy-6"])
    }

    /// Every course, every answer: later answers never start earlier, every answer past "Just starting" skips
    /// unit 1, and the plan, the pass and Learn agree on the first lesson.
    func testPlanPassAndLearnAgreeInEveryCourse() throws {
        for course in curriculum.courses {
            var previous = 0
            for level in CoursePlacement.levels {
                var progress = LearnProgress()
                progress.place(level: level, in: course)
                let next = try XCTUnwrap(progress.nextLesson(in: course), "\(course.id) \(level)")
                let unit = try XCTUnwrap(course.units.firstIndex { unit in unit.lessons.contains { $0.id == next.id } })
                XCTAssertGreaterThanOrEqual(unit, previous, "\(course.id) \(level) starts no earlier than the answer below")
                previous = unit
                XCTAssertTrue(progress.isUnlocked(next, in: course), "\(course.id) \(level)")
                XCTAssertTrue(progress.isValid)
                if level == "beginner" {
                    XCTAssertEqual(next.id, course.lessons.first?.id)
                    XCTAssertNil(AccessPolicy.placementPass(in: course, progress: progress))
                } else {
                    XCTAssertGreaterThan(unit, 0, "\(course.id) \(level) skips the basics")
                    XCTAssertEqual(next.id, course.units[unit].lessons.first?.id, "\(course.id) \(level) starts at a unit's first lesson")
                    XCTAssertEqual(AccessPolicy.placementPass(in: course, progress: progress)?.id, next.id, "\(course.id) \(level)")
                    XCTAssertTrue(AccessPolicy.canPlay(next, pro: false, progress: progress, courses: curriculum.courses), "\(course.id) \(level)")
                }
            }
        }
    }

    func testCoursesWithoutTheirOwnStartsPlaceByShare() {
        // Unit ids the table doesn't know (a renamed guitar course, or a new course): by share of the course.
        let ids = (1...6).map { "x-\($0)" }
        XCTAssertEqual(CoursePlacement.levels.map { CoursePlacement.startUnit(level: $0, courseId: "guitar", unitIds: ids) }, [0, 1, 2, 3, 4])
        XCTAssertEqual(CoursePlacement.levels.map { CoursePlacement.startUnit(level: $0, courseId: "new", unitIds: ids) }, [0, 1, 2, 3, 4])
        XCTAssertEqual(CoursePlacement.startUnit(level: "pro", courseId: "new", unitIds: ["a", "b"]), 1, "never past the last unit")
        XCTAssertEqual(CoursePlacement.startUnit(level: "pro", courseId: "new", unitIds: ["a"]), 0)
        XCTAssertEqual(CoursePlacement.startUnit(level: "expert", courseId: "guitar", unitIds: ids), 0, "an unknown answer starts at the beginning")
        XCTAssertNil(LearnProgress.placementUnit(level: "beginner", unitCount: 6))
        XCTAssertEqual(LearnProgress.placementUnit(level: "novice", unitCount: 6), 0)
    }

    // MARK: The placement check

    private func chords(_ steps: [LessonStep]) -> [String] {
        steps.compactMap { step -> String? in
            if case let .playChord(chord) = step { return chord.symbol }
            return nil
        }
    }

    func testCheckPlaysGCAndDThenAStrumFromTheCourse() throws {
        let guitar = try XCTUnwrap(PlacementCheck.steps(in: try course("guitar")))
        XCTAssertEqual(chords(guitar), ["G", "C", "D"])
        guard case let .strum(chord, pattern, bpm, bars, _)? = guitar.last else { return XCTFail("ends with a strum") }
        XCTAssertEqual(chord?.symbol, "G")
        XCTAssertEqual(pattern, PlacementCheck.strumPattern, "D DU UDU")
        XCTAssertGreaterThanOrEqual(bpm, 60)
        XCTAssertEqual(bars, PlacementCheck.bars)
        // Four chords and two bars: well under a minute.
        XCTAssertEqual(guitar.count, 4)

        let ukulele = try XCTUnwrap(PlacementCheck.steps(in: try course("ukulele")))
        XCTAssertEqual(chords(ukulele), ["G", "C", "D"])
        if case let .strum(_, pattern, _, _, _)? = ukulele.last { XCTAssertEqual(pattern, PlacementCheck.strumPattern, "the island strum") } else { XCTFail() }

        XCTAssertEqual(chords(try XCTUnwrap(PlacementCheck.steps(in: try course("mandolin")))), ["G", "C", "D"])
        // The banjo has no D shape of its own: D7 stands in; its G comes from the strum steps.
        XCTAssertEqual(chords(try XCTUnwrap(PlacementCheck.steps(in: try course("banjo")))), ["G", "C", "D7"])

        // No chords to change between: no check.
        for id in ["bass", "violin", "cello", "voice", "ear", "theory", "rhythm"] {
            XCTAssertNil(PlacementCheck.steps(in: try course(id)), id)
        }
        XCTAssertTrue(PlacementCheck.offered(level: "intermediate"))
        XCTAssertTrue(PlacementCheck.offered(level: "pro"))
        XCTAssertFalse(PlacementCheck.offered(level: "beginner"))
        XCTAssertFalse(PlacementCheck.offered(level: "novice"))
    }

    func testCheckVerdict() {
        let quick = [3.0, 4, 5]
        XCTAssertEqual(PlacementCheck.verdict(chords: [1, 1, 0.95], seconds: quick, strum: 0.9), .up, "clean, quick changes and a steady strum")
        XCTAssertEqual(PlacementCheck.verdict(chords: [1, 1, 1], seconds: [3, 12, 4], strum: 0.9), .same, "one slow change is not fluent")
        XCTAssertEqual(PlacementCheck.verdict(chords: [1, 1, 1], seconds: quick, strum: nil), .same, "a strum the microphone didn't hear proves nothing")
        XCTAssertEqual(PlacementCheck.verdict(chords: [0.6, 0.6, 0.6], seconds: [7, 7, 7], strum: nil), .same, "\"I played it\" is not a fail")
        XCTAssertEqual(PlacementCheck.verdict(chords: [0.4, 0.5, 1], seconds: [15, 14, 4], strum: 0.6), .down)
        XCTAssertEqual(PlacementCheck.verdict(chords: [1, 0.6, 1], seconds: quick, strum: 0.3), .down, "a missed strum without fluent chords")
        XCTAssertEqual(PlacementCheck.verdict(chords: [1, 1, 1], seconds: quick, strum: 0.3), .same, "fluent chords outweigh one missed strum")
        XCTAssertEqual(PlacementCheck.verdict(chords: [0.4, 0.5, 1], seconds: quick, strum: 0.9), .same, "a steady strum outweighs two rough chords")
        XCTAssertEqual(PlacementCheck.verdict(chords: [], seconds: [], strum: 0.9), .same)
    }

    func testCheckMovesTheAnswerOneLevel() throws {
        XCTAssertEqual(PlacementCheck.level("intermediate", after: .up), "advanced")
        XCTAssertEqual(PlacementCheck.level("advanced", after: .up), "pro")
        XCTAssertEqual(PlacementCheck.level("pro", after: .up), "pro")
        XCTAssertEqual(PlacementCheck.level("intermediate", after: .down), "novice")
        XCTAssertEqual(PlacementCheck.level("pro", after: .down), "advanced")
        XCTAssertEqual(PlacementCheck.level("novice", after: .down), "novice")
        XCTAssertEqual(PlacementCheck.level("beginner", after: .down), "beginner")
        XCTAssertEqual(PlacementCheck.level("advanced", after: .same), "advanced")
        // A few years on guitar: Songs with chords; up to the barre chords, or back to after the basics.
        let guitar = try course("guitar")
        XCTAssertEqual(startUnit(PlacementCheck.level("intermediate", after: .up), in: guitar), "gtr-10")
        XCTAssertEqual(startUnit(PlacementCheck.level("intermediate", after: .down), in: guitar), "gtr-2")
    }
}
