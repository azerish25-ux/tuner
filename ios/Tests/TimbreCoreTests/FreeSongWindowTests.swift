import XCTest
@testable import TimbreCore

final class FreeSongWindowTests: XCTestCase {
    private let utc = TimeZone(secondsFromGMT: 0)!
    private let window = FreeSongWindow(startDate: "2026-12-01", endDate: "2026-12-08")

    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    func testLocalDaysIncludeStartAndExcludeEnd() {
        let start = date("2026-12-01T00:00:00Z")
        let end = date("2026-12-08T00:00:00Z")
        XCTAssertFalse(window.includes(at: start.addingTimeInterval(-0.001), timeZone: utc))
        XCTAssertTrue(window.includes(at: start, timeZone: utc))
        XCTAssertTrue(window.includes(at: end.addingTimeInterval(-0.001), timeZone: utc))
        XCTAssertFalse(window.includes(at: end, timeZone: utc))
        XCTAssertFalse(window.includes(at: end.addingTimeInterval(86_400), timeZone: utc))
        XCTAssertEqual(window.nextBoundary(after: start.addingTimeInterval(-1), timeZone: utc), start)
        XCTAssertEqual(window.nextBoundary(after: start, timeZone: utc), end)
        XCTAssertNil(window.nextBoundary(after: end, timeZone: utc))
    }

    func testWindowUsesEachPlayersTimeZoneAndGregorianDates() {
        let instant = date("2026-12-01T00:00:00Z")
        XCTAssertFalse(window.includes(at: instant, timeZone: TimeZone(identifier: "America/Los_Angeles")!))
        XCTAssertTrue(window.includes(at: instant, timeZone: TimeZone(identifier: "Pacific/Kiritimati")!))
        let losAngelesStart = date("2026-12-01T08:00:00Z")
        XCTAssertEqual(window.nextBoundary(after: instant, timeZone: TimeZone(identifier: "America/Los_Angeles")!), losAngelesStart)
        // Explicit Gregorian parsing is independent of Calendar.current (including Buddhist/Hebrew preferences).
        XCTAssertTrue(window.includes(at: date("2026-12-03T00:00:00Z"), timeZone: utc))
        let dst = FreeSongWindow(startDate: "2026-03-08", endDate: "2026-03-09")
        let zone = TimeZone(identifier: "America/New_York")!
        XCTAssertEqual(dst.nextBoundary(after: date("2026-03-08T05:00:00Z"), timeZone: zone), date("2026-03-09T04:00:00Z"))
    }

    func testInvalidWindowsNeverGrantAndHaveNoBoundary() {
        for candidate in [
            FreeSongWindow(startDate: nil, endDate: nil),
            FreeSongWindow(startDate: "2026-12-01", endDate: nil),
            FreeSongWindow(startDate: nil, endDate: "2026-12-08"),
            FreeSongWindow(startDate: "2026-12-08", endDate: "2026-12-01"),
            FreeSongWindow(startDate: "2026-12-01", endDate: "2026-12-01"),
            FreeSongWindow(startDate: "2026-02-30", endDate: "2026-12-08"),
            FreeSongWindow(startDate: "2026-2-01", endDate: "2026-12-08"),
            FreeSongWindow(startDate: "2026-12-01T00:00:00Z", endDate: "2026-12-08")
        ] {
            XCTAssertFalse(candidate.includes(at: date("2026-12-03T00:00:00Z"), timeZone: utc))
            XCTAssertNil(candidate.nextBoundary(after: date("2026-01-01T00:00:00Z"), timeZone: utc))
        }
    }

    func testCachedOpeningsReevaluateEveryReadWithoutRefresh() throws {
        let lesson = Lesson(id: "paid", title: LearnText("paid"), kind: .song, minutes: 3, xp: 20, free: false, steps: [])
        let cached = FreeOpenings(lessons: [lesson.id], window: window)
        let start = date("2026-12-01T00:00:00Z")
        let end = date("2026-12-08T00:00:00Z")
        XCTAssertTrue(AccessPolicy.canPlay(lesson, pro: false, progress: LearnProgress(), courses: [], openings: cached, now: start, timeZone: utc))
        XCTAssertFalse(AccessPolicy.canPlay(lesson, pro: false, progress: LearnProgress(), courses: [], openings: cached, now: end, timeZone: utc))
        XCTAssertTrue(cached.activeLessons(at: start, timeZone: utc).contains(lesson.id))
        XCTAssertTrue(cached.activeLessons(at: end, timeZone: utc).isEmpty)
        let original = FreeOpenings.current
        defer { FreeOpenings.current = original }
        FreeOpenings.current = cached
        XCTAssertTrue(AccessPolicy.canPlay(lesson, pro: false, progress: LearnProgress(), courses: [], now: start, timeZone: utc))
        XCTAssertFalse(AccessPolicy.canPlay(lesson, pro: false, progress: LearnProgress(), courses: [], now: end, timeZone: utc))
        let permanent = FreeOpenings(lessons: [lesson.id])
        XCTAssertTrue(permanent.opens(lesson, courses: [], now: end, timeZone: utc))
        XCTAssertTrue(permanent.opens(lesson, courses: [], now: date("2030-01-01T00:00:00Z"), timeZone: utc))
    }

    func testFullActualCarolCampaignIncludingLateCelloAndBass() throws {
        let curriculum = try Curriculum.bundled()
        let carols = ["song-silent-night", "song-jingle-bells", "song-joy-to-the-world", "song-deck-the-halls", "song-we-wish-you",
                      "song-good-king-wenceslas", "std-o-christmas-tree", "std-o-come-all-ye-faithful", "std-the-first-noel",
                      "std-hark-the-herald", "std-away-in-a-manger", "std-o-little-town", "std-it-came-upon", "std-royal-davids-city",
                      "std-bleak-midwinter", "std-holly-and-ivy", "std-angels-from-the-realms"]
        let ids = carols.flatMap { carol in ["", "uke-sb-", "man-sb-", "vln-sb-", "vc-sb-", "bass-sb-"].map { $0 + carol } }
        XCTAssertEqual(Set(ids).count, 102)
        let openings = FreeOpenings(lessons: Set(ids), window: window)
        let during = date("2026-12-03T12:00:00Z")
        for id in ids {
            let found = try XCTUnwrap(curriculum.lesson(id: id), id)
            XCTAssertTrue(AccessPolicy.canPlay(found.lesson, pro: false, progress: LearnProgress(), courses: curriculum.courses,
                                               openings: openings, now: during, timeZone: utc), id)
        }
        let other = try XCTUnwrap(curriculum.courses.flatMap(\.lessons).first { !$0.free && !ids.contains($0.id) })
        XCTAssertFalse(AccessPolicy.canPlay(other, pro: false, progress: LearnProgress(), courses: curriculum.courses,
                                            openings: openings, now: during, timeZone: utc))
    }

    func testInvalidSongWindowDoesNotRestrictIndependentUnitTwoOrPro() throws {
        let curriculum = try Curriculum.bundled()
        let course = try XCTUnwrap(curriculum.courses.first { !$0.isSongbook && $0.units.count > 1 && $0.units[1].lessons.contains { !$0.free } })
        let lesson = try XCTUnwrap(course.units[1].lessons.first { !$0.free })
        let invalid = FreeOpenings(lessons: ["other"], unit2: true, window: FreeSongWindow(startDate: nil, endDate: nil))
        XCTAssertTrue(invalid.opens(lesson, courses: curriculum.courses, now: date("2026-12-08T00:00:00Z"), timeZone: utc))
        XCTAssertTrue(AccessPolicy.canPlay(lesson, pro: true, progress: LearnProgress(), courses: curriculum.courses,
                                            openings: FreeOpenings(window: FreeSongWindow(startDate: nil, endDate: nil))))
    }

    func testDefaultClockAndGlobalSnapshotCannotPreserveExpiredLessons() {
        let expired = FreeOpenings(lessons: ["paid"], window: FreeSongWindow(startDate: "2000-12-01", endDate: "2000-12-08"))
        XCTAssertTrue(expired.lessons.isEmpty)
        let original = FreeOpenings.current
        defer { FreeOpenings.current = original }
        FreeOpenings.current = expired
        XCTAssertTrue(FreeOpenings.current.lessons.isEmpty)
        let lesson = Lesson(id: "paid", title: LearnText("paid"), kind: .song, minutes: 3, xp: 20, free: false, steps: [])
        XCTAssertFalse(AccessPolicy.canPlay(lesson, pro: false, progress: LearnProgress(), courses: []))
    }
}
