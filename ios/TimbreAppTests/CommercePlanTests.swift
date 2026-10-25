import XCTest
import TimbreCore
@testable import Timbre

/// The plan the onboarding paywall sells: the first song it names is one the free plan plays, within the week, for
/// every beginner who came to play songs; its days follow the minutes a day they chose.
@MainActor
final class CommercePlanTests: XCTestCase {
    private var directory: URL!
    private var store: AppStore!

    override func setUp() async throws {
        try await super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        store = try AppStore(directory: directory)
    }

    override func tearDown() async throws {
        store = nil
        try? FileManager.default.removeItem(at: directory)
        try await super.tearDown()
    }

    private func plan(_ instrument: String, goal: String = "songs", level: String = "beginner", minutes: Int = 10) -> PaywallPlan {
        PaywallPlan.make(store: store, answers: PaywallAnswers(instrumentId: instrument, level: level, goal: goal, minutes: minutes),
                         horizon: 14, reason: nil)
    }

    /// "Play your first song this week" is said for these beginners (`PaywallView.pitch`), so the song must be one the
    /// free plan opens, within seven days, and on the plan's track.
    func testABeginnersFirstSongIsFreeThisWeek() throws {
        let instruments = ["guitar.acoustic.6", "ukulele.soprano.4", "violin.standard.4", "mandolin.standard.8"]
        for instrument in instruments {
            let plan = plan(instrument)
            let song = try XCTUnwrap(plan.song, instrument)
            XCTAssertEqual(song.lesson.kind, .song, instrument)
            XCTAssertTrue(song.free, instrument)
            XCTAssertLessThanOrEqual(song.day, 7, instrument)
            XCTAssertTrue(AccessPolicy.canPlay(song.lesson, pro: false, progress: LearnProgress(), courses: store.curriculum.courses,
                                               openings: .none), "\(instrument): \(song.lesson.id) must open on the free plan")
            if song.day > 1 {
                XCTAssertTrue(plan.milestones.contains { $0.kind == .song && $0.day == song.day && $0.title == song.title }, instrument)
            }
        }
    }

    /// Other goals keep the course's own first song, at the person's pace: more minutes a day, sooner.
    func testTheCoursesOwnSongComesAtThePersonsPace() throws {
        let relaxed = try XCTUnwrap(plan("guitar.acoustic.6", goal: "practice", minutes: 5).song)
        let keen = try XCTUnwrap(plan("guitar.acoustic.6", goal: "practice", minutes: 15).song)
        XCTAssertEqual(relaxed.lesson.id, keen.lesson.id)
        let course = try XCTUnwrap(store.curriculum.course(id: "guitar"))
        let index = try XCTUnwrap(course.position(of: keen.lesson.id))
        let minutes = course.lessons[...index].reduce(0) { $0 + max(1, $1.minutes) }
        XCTAssertEqual(keen.day, Int((Double(minutes) / 15).rounded(.up)))
        XCTAssertEqual(relaxed.day, Int((Double(minutes) / 5).rounded(.up)))
        XCTAssertLessThan(keen.day, relaxed.day)
    }

    /// The pace counts minutes, not lessons: 10 minutes a day plays lessons of 3, 4 and 4 minutes on days 1, 1 and 2.
    func testPaceCountsMinutes() {
        func lesson(_ id: String, _ minutes: Int) -> Lesson {
            Lesson(id: id, title: LearnText(id), kind: .lesson, minutes: minutes, xp: 10, free: true,
                   steps: [.quiz(prompt: LearnText("q"), options: [LearnText("a"), LearnText("b")], answer: 0, why: nil, visual: .none)])
        }
        let pace = PaywallPlan.Pace(lessons: [lesson("a", 3), lesson("b", 4), lesson("c", 4), lesson("d", 9)], first: 0, minutesADay: 10)
        XCTAssertEqual((0..<4).map { pace.day(of: $0) }, [1, 1, 2, 2])
    }
}
