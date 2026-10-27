import Foundation
import SwiftUI
import XCTest
@testable import Timbre
import TimbreCore

@MainActor final class SongsCatalogAccessTests: XCTestCase {
    func testSameDayGrantAndRevocationRebuildRetainedCatalogAndCarolCaption() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AppStore(directory: directory)
        let config = RemoteConfig.shared
        let original = config.values
        let originalOpenings = FreeOpenings.current
        defer { config.apply(original); FreeOpenings.current = originalOpenings }
        config.apply(.init())
        XCTAssertFalse(store.isPro)
        let catalog = SongsCatalog()
        let sameDay = ISO8601DateFormatter().date(from: "2026-12-03T12:00:00Z")!
        let progress = store.learn
        let initial = catalog.layout(filter: SongsView.all, course: "guitar", store: store, now: sameDay)
        let carols = try XCTUnwrap(initial.picks.first { $0.id == "carols" })
        let paid = try XCTUnwrap(carols.songs.first { !$0.lesson.free })
        XCTAssertEqual(carols.title, Text("Carols"))
        XCTAssertEqual(catalog.standing(paid).access, .pro)

        // Same store, catalogue, progress, level, Pro status, day and home instrument: only the remote grant changes.
        config.apply(.init(freeSongs: [paid.id]))
        let granted = catalog.layout(filter: SongsView.all, course: "guitar", store: store, now: sameDay)
        XCTAssertEqual(try XCTUnwrap(granted.picks.first { $0.id == "carols" }).title, Text("Carols, free this week"))
        XCTAssertNotEqual(catalog.standing(paid).access, .pro)
        XCTAssertEqual(catalog.standing(paid).access, LessonAccess.of(paid.lesson, in: paid.course, store: store))
        XCTAssertTrue(store.canPlay(paid.lesson))

        config.apply(.init())
        let revoked = catalog.layout(filter: SongsView.all, course: "guitar", store: store, now: sameDay)
        XCTAssertEqual(try XCTUnwrap(revoked.picks.first { $0.id == "carols" }).title, Text("Carols"))
        XCTAssertEqual(catalog.standing(paid).access, .pro)
        XCTAssertFalse(store.canPlay(paid.lesson))
        XCTAssertEqual(store.learn, progress)
    }

    func testSameDayUnitTwoGrantAndRevocationInvalidateStanding() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AppStore(directory: directory)
        let config = RemoteConfig.shared
        let original = config.values
        let originalOpenings = FreeOpenings.current
        defer { config.apply(original); FreeOpenings.current = originalOpenings }
        config.apply(.init())
        let catalog = SongsCatalog()
        let sameDay = ISO8601DateFormatter().date(from: "2026-12-03T12:00:00Z")!
        let initial = catalog.layout(filter: SongsView.all, course: "guitar", store: store, now: sameDay)
        let song = try XCTUnwrap(initial.rails.flatMap(\.songs).first { $0.id == "gtr-2-4" })
        XCTAssertEqual(catalog.standing(song).access, .pro)
        config.apply(.init(flags: ["unit2Free": true]))
        _ = catalog.layout(filter: SongsView.all, course: "guitar", store: store, now: sameDay)
        XCTAssertNotEqual(catalog.standing(song).access, .pro)
        XCTAssertEqual(catalog.standing(song).access, LessonAccess.of(song.lesson, in: song.course, store: store))
        config.apply(.init())
        _ = catalog.layout(filter: SongsView.all, course: "guitar", store: store, now: sameDay)
        XCTAssertEqual(catalog.standing(song).access, .pro)
    }
}
