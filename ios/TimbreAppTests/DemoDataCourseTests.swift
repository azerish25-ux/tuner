import Foundation
import XCTest
import TimbreCore
@testable import Timbre

@MainActor final class DemoDataCourseTests: XCTestCase {
    func testFreshDemoHistoryResetsCourseLeftByTerminatedSongCapture() throws {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: Preferences.Key.learnCourse)
        defer {
            if let previous { defaults.set(previous, forKey: Preferences.Key.learnCourse) }
            else { defaults.removeObject(forKey: Preferences.Key.learnCourse) }
        }
        for inheritedCourse in ["originals", "violin", "guitar"] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            Preferences.learnCourse = inheritedCourse
            let store = try AppStore(directory: directory)
            XCTAssertTrue(store.records.isEmpty)
            DemoData.seed(store)
            XCTAssertEqual(Preferences.learnCourse, "guitar")
            XCTAssertEqual(store.learnCourse?.id, "guitar")
            let course = try XCTUnwrap(store.learnCourse)
            let next = try XCTUnwrap(store.learn.nextLesson(in: course))
            XCTAssertEqual(next.id, "gtr-1-4")
            XCTAssertNotNil(store.curriculum.lesson(id: "gtr-1-2"))
            let recordCount = store.records.count
            XCTAssertGreaterThan(recordCount, 0)
            // Neither a repeated seed nor ordinary navigation may lock the user to guitar.
            Preferences.learnCourse = "violin"
            DemoData.seed(store)
            XCTAssertEqual(store.learnCourse?.id, "violin")
            XCTAssertEqual(store.records.count, recordCount)
        }
    }
}
