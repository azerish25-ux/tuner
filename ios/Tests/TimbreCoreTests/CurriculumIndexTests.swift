import XCTest
@testable import TimbreCore

private func makeLesson(_ id: String) -> Lesson {
    Lesson(id: id, title: LearnText(id), kind: .lesson, minutes: 3, xp: 20, free: true,
           steps: [.explain(title: LearnText("t"), body: LearnText("b"), visual: .none)])
}

private func makeCourse(_ id: String, units: [[String]]) -> LearnCourse {
    let built = units.enumerated().map { index, ids in
        LearnUnit(id: "\(id).u\(index)", title: LearnText("U"), summary: LearnText("s"), lessons: ids.map { makeLesson($0) })
    }
    return LearnCourse(id: id, title: LearnText(id), subtitle: LearnText("s"), instrument: nil, symbol: "music.note", accent: "mint", units: built)
}

/// The lesson lists and positions built once per course and curriculum (the Learn path and Songs ask for them per node).
final class CurriculumIndexTests: XCTestCase {
    func testCourseIndexesItsLessonsInPathOrder() {
        let course = makeCourse("c", units: [["a", "b"], ["c"], [], ["d", "e"]])
        XCTAssertEqual(course.lessons.map(\.id), ["a", "b", "c", "d", "e"])
        XCTAssertEqual(course.lessons.map(\.id), course.units.flatMap(\.lessons).map(\.id))
        for (index, lesson) in course.lessons.enumerated() { XCTAssertEqual(course.position(of: lesson.id), index, lesson.id) }
        XCTAssertNil(course.position(of: "zzz"))
    }

    func testASongbookOpensEverySongButKeepsItsChallengesInOrder() {
        func lesson(_ id: String, _ kind: Lesson.Kind) -> Lesson {
            Lesson(id: id, title: LearnText(id), kind: kind, minutes: 3, xp: 20, free: true,
                   steps: [.explain(title: LearnText("t"), body: LearnText("b"), visual: .none)])
        }
        let unit = LearnUnit(id: "s.u0", title: LearnText("U"), summary: LearnText("s"),
                             lessons: [lesson("one", .song), lesson("two", .song), lesson("three", .song), lesson("boss", .challenge)])
        let book = LearnCourse(id: "s", title: LearnText("s"), subtitle: LearnText("s"), instrument: nil, symbol: "music.note", accent: "mint", units: [unit])
        XCTAssertTrue(book.isSongbook)
        let progress = LearnProgress()
        XCTAssertTrue(progress.isUnlocked(book.lessons[2], in: book), "any song of a songbook is open")
        XCTAssertFalse(progress.isUnlocked(book.lessons[3], in: book), "its challenge waits for the song before it")
        // A course that teaches keeps its path, songs included.
        let taught = LearnUnit(id: "t.u0", title: LearnText("U"), summary: LearnText("s"), lessons: [lesson("a", .lesson), lesson("b", .song)])
        let course = LearnCourse(id: "t", title: LearnText("t"), subtitle: LearnText("s"), instrument: nil, symbol: "music.note", accent: "mint", units: [taught])
        XCTAssertFalse(course.isSongbook)
        XCTAssertFalse(progress.isUnlocked(course.lessons[1], in: course))
    }

    func testUnlockingReadsTheIndex() {
        let course = makeCourse("c", units: [["a", "b"], ["c", "d"]])
        var progress = LearnProgress()
        XCTAssertTrue(progress.isUnlocked(course.lessons[0], in: course), "the first lesson is always open")
        XCTAssertFalse(progress.isUnlocked(course.lessons[1], in: course))
        XCTAssertFalse(progress.isUnlocked(makeLesson("elsewhere"), in: course), "a lesson of another course is never open here")
        progress.record(LessonResult(lessonId: "a", stars: 2, accuracy: 0.8, xp: 20, minutes: 3), courseId: "c")
        XCTAssertTrue(progress.isUnlocked(course.lessons[1], in: course), "the lesson after a finished one opens")
        XCTAssertFalse(progress.isUnlocked(course.lessons[2], in: course))
        // Placed past the first unit: its lessons and the one after them are open.
        progress.placedThrough["c"] = 0
        XCTAssertTrue(progress.isUnlocked(course.lessons[2], in: course))
        XCTAssertFalse(progress.isUnlocked(course.lessons[3], in: course))
        XCTAssertEqual(progress.nextLesson(in: course)?.id, "c")
    }

    func testBundledCurriculumLookupsMatchAScan() throws {
        let curriculum = try Curriculum.bundled()
        XCTAssertFalse(curriculum.courses.isEmpty)
        for course in curriculum.courses {
            XCTAssertEqual(course.lessons.map(\.id), course.units.flatMap(\.lessons).map(\.id), course.id)
            for unit in course.units {
                for lesson in unit.lessons {
                    let found = try XCTUnwrap(curriculum.lesson(id: lesson.id), lesson.id)
                    XCTAssertEqual(found.course.id, course.id, lesson.id)
                    XCTAssertEqual(found.unit.id, unit.id, lesson.id)
                    XCTAssertEqual(found.lesson.id, lesson.id)
                    XCTAssertEqual(course.position(of: lesson.id), course.lessons.firstIndex { $0.id == lesson.id }, lesson.id)
                }
            }
        }
        XCTAssertNil(curriculum.lesson(id: "no-such-lesson"))
    }

    func testIndexIsRebuiltWhenDecoded() throws {
        let original = Curriculum(courses: [makeCourse("x", units: [["x1", "x2"]]), makeCourse("y", units: [["y1"], ["y2"]])])
        let decoded = try JSONDecoder().decode(Curriculum.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded.courses.map(\.id), ["x", "y"])
        XCTAssertEqual(decoded.courses[1].lessons.map(\.id), ["y1", "y2"])
        XCTAssertEqual(decoded.courses[1].position(of: "y2"), 1)
        XCTAssertEqual(decoded.lesson(id: "y2")?.unit.id, "y.u1")
        XCTAssertEqual(decoded.lesson(id: "x1")?.course.id, "x")
        XCTAssertEqual(decoded.lessonCount, 4)
    }

    /// The slowest rung and the click share one floor, so a slow loop's click never runs ahead of its runway.
    func testSlowestTempoIsOneTheClickPlays() {
        let floor = MetronomePattern.tempoRange.lowerBound
        XCTAssertEqual(TempoLadder(bpm: 20).tempo(at: 0), Double(floor), "75 % of 20 BPM is raised to the slowest click")
        XCTAssertEqual(TempoLadder(bpm: 50).tempo(at: 0), 38)
        // A loop at three quarters of 38 BPM: 29 BPM on the runway, and on the click.
        XCTAssertTrue(MetronomePattern.tempoRange.contains(29))
        let renderer = MetronomeRenderer(sampleRate: 4800, initial: MetronomePattern(bpm: 29, beatsPerBar: 4, subdivision: 1))
        var buffer = [Float](repeating: 0, count: 4800 * 5)
        let pulses = renderer.render(&buffer)
        XCTAssertGreaterThanOrEqual(pulses.count, 2)
        guard pulses.count >= 2 else { return }
        XCTAssertEqual(Double(pulses[1].frame - pulses[0].frame) / 4800, 60.0 / 29, accuracy: 0.001)
    }
}
