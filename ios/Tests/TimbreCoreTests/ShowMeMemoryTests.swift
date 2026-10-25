import Foundation
import XCTest
@testable import TimbreCore

/// "Show me" plays by itself the first time a chord or a strum pattern appears in a course, and only then.
final class ShowMeMemoryTests: XCTestCase {
    private let em = ChordSpec(name: "Em", root: 4, quality: "min", frets: [0, 2, 2, 0, 0, 0], fingers: [0, 2, 3, 0, 0, 0])

    func testADemonstrationPlaysByItselfOncePerCourse() {
        var settings = UserSettings()
        let key = ShowMeKey.chord(em)
        XCTAssertFalse(settings.hasShownDemo(key, in: "guitar"))
        settings.markDemoShown(key, in: "guitar")
        XCTAssertTrue(settings.hasShownDemo(key, in: "guitar"))
        // Another course (the songs shelf, say) meets it afresh.
        XCTAssertFalse(settings.hasShownDemo(key, in: "songs"))
        // Remembered once, however often it plays.
        settings.markDemoShown(key, in: "guitar")
        XCTAssertEqual(settings.shownDemos?["guitar"], [key])
    }

    func testChordKeysFollowTheShape() {
        // The same shape is the same demonstration, whatever the lesson says about the fingers.
        let plain = ChordSpec(name: "Em", root: 4, quality: "min", frets: [0, 2, 2, 0, 0, 0])
        XCTAssertEqual(ShowMeKey.chord(em), ShowMeKey.chord(plain))
        XCTAssertEqual(ShowMeKey.chord(em), "chord:0,2,2,0,0,0")
        // Another shape, or the same frets up the neck, is another.
        let am = ChordSpec(name: "Am", root: 9, quality: "min", frets: [-1, 0, 2, 2, 1, 0])
        XCTAssertNotEqual(ShowMeKey.chord(em), ShowMeKey.chord(am))
        let up = ChordSpec(name: "Bm", root: 11, quality: "min", frets: [-1, 1, 3, 3, 2, 1], baseFret: 2)
        let low = ChordSpec(name: "A#m", root: 10, quality: "min", frets: [-1, 1, 3, 3, 2, 1])
        XCTAssertNotEqual(ShowMeKey.chord(up), ShowMeKey.chord(low))
    }

    func testStrumKeysFollowThePatternInItsBar() {
        // The tap step and the strum step after it share the explanation's pattern.
        XCTAssertEqual(ShowMeKey.strum(pattern: [0, 1, 2, 3], beatsPerBar: 4), "strum:4/0,1,2,3")
        XCTAssertEqual(ShowMeKey.strum(pattern: [3, 2, 1, 0], beatsPerBar: 4), ShowMeKey.strum(pattern: [0, 1, 2, 3], beatsPerBar: 4))
        XCTAssertEqual(ShowMeKey.strum(pattern: [0, 1.5, 2], beatsPerBar: 4), "strum:4/0,1.5,2")
        XCTAssertNotEqual(ShowMeKey.strum(pattern: [0, 1, 2], beatsPerBar: 3), ShowMeKey.strum(pattern: [0, 1, 2], beatsPerBar: 4))
        XCTAssertNotEqual(ShowMeKey.strum(pattern: [0, 2], beatsPerBar: 4), ShowMeKey.strum(pattern: [0, 1, 2, 3], beatsPerBar: 4))
    }

    func testMemoryIsBoundedOldestFirst() {
        var settings = UserSettings()
        for index in 0..<(UserSettings.shownDemoLimit + 5) { settings.markDemoShown("k\(index)", in: "guitar") }
        XCTAssertEqual(settings.shownDemos?["guitar"]?.count, UserSettings.shownDemoLimit)
        XCTAssertFalse(settings.hasShownDemo("k0", in: "guitar"))
        XCTAssertFalse(settings.hasShownDemo("k4", in: "guitar"))
        XCTAssertTrue(settings.hasShownDemo("k5", in: "guitar"))
        XCTAssertTrue(settings.hasShownDemo("k\(UserSettings.shownDemoLimit + 4)", in: "guitar"))
    }

    func testMemorySurvivesReopenAndEarlierFilesStillDecode() throws {
        // A file written before the field existed has no key for it, and reads back as nothing shown yet.
        let earlier = try JSONEncoder().encode(UserSettings())
        XCTAssertFalse(String(decoding: earlier, as: UTF8.self).contains("shownDemos"))
        XCTAssertNil(try JSONDecoder().decode(UserSettings.self, from: earlier).shownDemos)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(directory: directory)
        var settings = store.settings
        settings.markDemoShown(ShowMeKey.chord(em), in: "guitar")
        settings.markDemoShown(ShowMeKey.strum(pattern: [0, 1, 2, 3], beatsPerBar: 4), in: "guitar")
        try store.saveSettings(settings)
        let reopened = try LocalStore(directory: directory)
        XCTAssertEqual(reopened.settings, settings)
        XCTAssertTrue(reopened.settings.hasShownDemo(ShowMeKey.strum(pattern: [0, 1, 2, 3], beatsPerBar: 4), in: "guitar"))
    }
}
