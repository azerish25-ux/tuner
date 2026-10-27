import Foundation
import Combine
import XCTest
@testable import Timbre
import TimbreCore

final class RemoteConfigWindowTests: XCTestCase {
    @MainActor func testPresentInvalidWindowDoesNotBecomePermanentAccess() throws {
        let utc = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-12-03T00:00:00Z")!
        for raw in ["null", "false", "[]", "{}", "{\"startDate\":\"2026-12-01\"}",
                    "{\"startDate\":7,\"endDate\":\"2026-12-08\"}",
                    "{\"startDate\":\"2026-12-08\",\"endDate\":\"2026-12-01\"}"] {
            let data = Data("{\"freeSongs\":[\"paid\"],\"freeSongsWindow\":\(raw)}".utf8)
            let values = try JSONDecoder().decode(RemoteConfig.Values.self, from: data)
            XCTAssertNotNil(values.freeSongsWindow, raw)
            XCTAssertTrue(RemoteConfig.openings(RemoteConfig.sanitized(values)).activeLessons(at: now, timeZone: utc).isEmpty, raw)
        }
        let legacy = try JSONDecoder().decode(RemoteConfig.Values.self, from: Data("{\"freeSongs\":[\"paid\"]}".utf8))
        XCTAssertEqual(RemoteConfig.openings(legacy).activeLessons(at: now, timeZone: utc), ["paid"])
    }

    @MainActor func testCacheRoundTripPreservesPolicyAndAll102CampaignIDs() throws {
        let curriculum = try Curriculum.bundled()
        let carols = ["song-silent-night", "song-jingle-bells", "song-joy-to-the-world", "song-deck-the-halls", "song-we-wish-you",
                      "song-good-king-wenceslas", "std-o-christmas-tree", "std-o-come-all-ye-faithful", "std-the-first-noel",
                      "std-hark-the-herald", "std-away-in-a-manger", "std-o-little-town", "std-it-came-upon", "std-royal-davids-city",
                      "std-bleak-midwinter", "std-holly-and-ivy", "std-angels-from-the-realms"]
        let ids = carols.flatMap { carol in ["", "uke-sb-", "man-sb-", "vln-sb-", "vc-sb-", "bass-sb-"].map { $0 + carol } }
        XCTAssertEqual(ids.count, 102)
        for id in ids { XCTAssertNotNil(curriculum.lesson(id: id), id) }
        let values = RemoteConfig.Values(freeSongs: ids, freeSongsWindow: FreeSongWindow(startDate: "2026-12-01", endDate: "2026-12-08"))
        let cached = try JSONDecoder().decode(RemoteConfig.Values.self, from: JSONEncoder().encode(values))
        let clean = RemoteConfig.sanitized(cached)
        XCTAssertEqual(clean.freeSongs, ids)
        let openings = RemoteConfig.openings(clean)
        let utc = TimeZone(secondsFromGMT: 0)!
        let clock = ISO8601DateFormatter()
        XCTAssertEqual(openings.activeLessons(at: clock.date(from: "2026-12-03T00:00:00Z")!, timeZone: utc).count, 102)
        XCTAssertTrue(openings.activeLessons(at: clock.date(from: "2026-12-08T00:00:00Z")!, timeZone: utc).isEmpty)
        XCTAssertTrue(openings.activeLessons(at: clock.date(from: "2026-12-03T00:00:00Z")!, timeZone: utc).contains("bass-sb-std-angels-from-the-realms"))
    }

    @MainActor func testCapacityAndIdentifierValidationRemainBounded() {
        let values = RemoteConfig.Values(freeSongs: (0..<300).map { "lesson-\($0)" } + ["bad/id", String(repeating: "a", count: 65)])
        let clean = RemoteConfig.sanitized(values)
        XCTAssertEqual(clean.freeSongs?.count, 256)
        XCTAssertEqual(clean.freeSongs?.last, "lesson-255")
        let invalidFirst = RemoteConfig.Values(freeSongs: ["bad/id", "", String(repeating: "a", count: 65), "good-id"])
        XCTAssertEqual(RemoteConfig.sanitized(invalidFirst).freeSongs, ["good-id"])
    }

    @MainActor func testBoundaryAndTimeZoneRefreshPublishWithoutNetwork() {
        let original = FreeOpenings.current
        defer { FreeOpenings.current = original }
        let clock = ISO8601DateFormatter()
        let before = clock.date(from: "2026-11-30T23:59:59Z")!
        let start = clock.date(from: "2026-12-01T00:00:00Z")!
        let end = clock.date(from: "2026-12-08T00:00:00Z")!
        let utc = TimeZone(secondsFromGMT: 0)!
        let config = RemoteConfig(initialValues: .init(freeSongs: ["paid"],
            freeSongsWindow: FreeSongWindow(startDate: "2026-12-01", endDate: "2026-12-08")), now: before, timeZone: utc)
        var changes = 0
        let token = config.openingsChanged.sink { _ in changes += 1 }
        config.refreshOpenings(now: start, timeZone: utc)
        XCTAssertEqual(changes, 1)
        config.refreshOpenings(now: start, timeZone: utc)
        XCTAssertEqual(changes, 1, "unchanged access does not redraw")
        config.refreshOpenings(now: start, timeZone: TimeZone(identifier: "America/Los_Angeles")!)
        XCTAssertEqual(changes, 2, "same instant, different local day")
        config.refreshOpenings(now: start, timeZone: utc)
        XCTAssertEqual(changes, 3)
        config.refreshOpenings(now: end, timeZone: utc)
        XCTAssertEqual(changes, 4, "expiry publishes while offline; no fetch involved")
        XCTAssertTrue(FreeOpenings.current.activeLessons(at: end, timeZone: utc).isEmpty)
        withExtendedLifetime(token) {}
    }
}
