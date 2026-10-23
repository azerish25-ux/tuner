import XCTest
@testable import TimbreCore

/// Lesson access: free lessons, Pro, and the placement pass (the placed unit's first lesson on the free plan).
final class AccessPolicyTests: XCTestCase {
    private func lesson(_ id: String, free: Bool) -> Lesson {
        Lesson(id: id, title: LearnText(id), kind: .lesson, minutes: 3, xp: 20, free: free,
               steps: [.quiz(prompt: LearnText("q"), options: [LearnText("a"), LearnText("b")], answer: 0, why: nil, visual: .none)])
    }

    private func course(_ id: String) -> LearnCourse {
        func unit(_ name: String, _ lessons: [Lesson]) -> LearnUnit { LearnUnit(id: id + name, title: LearnText(name), summary: LearnText("s"), lessons: lessons) }
        return LearnCourse(id: id, title: LearnText(id), subtitle: LearnText("s"), instrument: nil, symbol: "music.note", accent: "mint",
                           units: [unit("u1", [lesson(id + "-1-1", free: true), lesson(id + "-1-2", free: true)]),
                                   unit("u2", [lesson(id + "-2-1", free: false), lesson(id + "-2-2", free: false)]),
                                   unit("u3", [lesson(id + "-3-1", free: false)])])
    }

    func testPlacementPassOpensOnlyThePlacedFirstLesson() {
        let guitar = course("g"), ear = course("e")
        let courses = [guitar, ear]
        func open(_ progress: LearnProgress, _ id: String, pro: Bool = false) -> Bool {
            let lesson = courses.flatMap(\.lessons).first { $0.id == id }!
            return AccessPolicy.canPlay(lesson, pro: pro, progress: progress, courses: courses)
        }
        var progress = LearnProgress()

        // No placement: free lessons only; Pro opens everything.
        XCTAssertNil(AccessPolicy.placementPass(in: guitar, progress: progress))
        XCTAssertTrue(open(progress, "g-1-1"))
        XCTAssertFalse(open(progress, "g-2-1"))
        XCTAssertTrue(open(progress, "g-2-1", pro: true))

        // Placed past unit 1 of the guitar course: unit 2's first lesson is the pass, and it is the plan's first lesson.
        progress.place(level: "intermediate", in: guitar)
        XCTAssertEqual(AccessPolicy.placementPass(in: guitar, progress: progress)?.id, "g-2-1")
        XCTAssertEqual(progress.nextLesson(in: guitar)?.id, "g-2-1")
        XCTAssertTrue(open(progress, "g-2-1"))
        // Only that lesson, and only in the course that was placed.
        XCTAssertFalse(open(progress, "g-2-2"))
        XCTAssertFalse(open(progress, "g-3-1"))
        XCTAssertFalse(open(progress, "e-2-1"))
        XCTAssertTrue(open(progress, "g-1-2"), "free lessons stay free")

        // A beginner answer clears the placement and its pass.
        progress.place(level: "beginner", in: guitar)
        XCTAssertNil(AccessPolicy.placementPass(in: guitar, progress: progress))
        XCTAssertFalse(open(progress, "g-2-1"))
    }
}
