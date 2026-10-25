import XCTest
@testable import TimbreCore

final class CurriculumStoreTests: XCTestCase {
    /// Counts decodes from any thread.
    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        func increment() { lock.lock(); value += 1; lock.unlock() }
        var count: Int { lock.lock(); defer { lock.unlock() }; return value }
    }

    private struct Broken: Error {}

    func testDecodesOnceForEveryCaller() async {
        let counter = Counter()
        let store = CurriculumStore {
            counter.increment()
            Thread.sleep(forTimeInterval: 0.05)
            return Curriculum(version: 7, courses: [])
        }
        store.preload()
        store.preload()
        async let first = store.load()
        async let second = store.load()
        let loaded = await [first, second]
        XCTAssertEqual(loaded.map(\.version), [7, 7])
        XCTAssertEqual(store.curriculum.version, 7)
        XCTAssertTrue(store.isLoaded)
        XCTAssertNil(store.failure)
        XCTAssertEqual(counter.count, 1)
    }

    func testReadingWithoutAPreloadDecodesOnTheSpot() {
        let store = CurriculumStore { Curriculum(version: 3, courses: []) }
        XCTAssertFalse(store.isLoaded)
        XCTAssertEqual(store.curriculum.version, 3)
        XCTAssertTrue(store.isLoaded)
    }

    func testAFailedDecodeLeavesAnEmptyCurriculumAndSaysWhy() async {
        let store = CurriculumStore { throw Broken() }
        let curriculum = await store.load()
        XCTAssertTrue(curriculum.courses.isEmpty)
        XCTAssertTrue(store.failure is Broken)
    }

    func testSharedIsTheBundledCurriculum() throws {
        let bundled = try Curriculum.bundled()
        let shared = CurriculumStore.shared.curriculum
        XCTAssertNil(CurriculumStore.shared.failure)
        XCTAssertEqual(shared.version, bundled.version)
        XCTAssertEqual(shared.lessonCount, bundled.lessonCount)
    }
}
