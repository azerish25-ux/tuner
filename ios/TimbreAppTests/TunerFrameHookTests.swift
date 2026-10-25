import XCTest
import TimbreCore
@testable import Timbre

/// The tuner's feel hook (`AppStore.onTunerFrame`): every tuner reading reaches it, and nothing else does.
@MainActor
final class TunerFrameHookTests: XCTestCase {
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

    func testEveryTunerReadingReachesTheHook() {
        var frames: [TunerFrame] = []
        store.onTunerFrame = { frames.append($0) }
        let target = store.targetHz
        for _ in 0..<5 { store.accept(target * 1.001, confidence: 0.95, level: -30) }
        XCTAssertEqual(frames.count, 5)
        XCTAssertEqual(frames.last?.targetHz ?? 0, target, accuracy: 0.0001)
        XCTAssertTrue(frames.allSatisfy(\.measuring))
        XCTAssertEqual(frames.last?.level, -30)
    }

    func testALessonTakesTheReadingsItself() {
        var frames: [TunerFrame] = []
        store.onTunerFrame = { frames.append($0) }
        store.lessonListener = { _, _ in }
        store.accept(store.targetHz, confidence: 0.95, level: -30)
        XCTAssertTrue(frames.isEmpty)
    }

    func testBeatIsTheDifferenceBetweenTheStringAndItsTarget() {
        let reading = TuningReading(frequency: 442, cents: 1200 * log2(442.0 / 440.0), stable: true, inTune: false, status: "sharp")
        let frame = TunerFrame(reading: reading, targetHz: 440, level: -30, enteredTune: false, measuring: true, time: 0)
        XCTAssertEqual(frame.beatHz ?? 0, 2, accuracy: 0.0001)
    }
}
