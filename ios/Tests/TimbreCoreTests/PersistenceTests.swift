import Foundation
import XCTest
@testable import TimbreCore

final class PersistenceTests: XCTestCase {
    func testHistoryIsRetainedUntilExplicitDeletion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(directory: directory)
        for index in 0..<502 {
            try store.append(PracticeRecord(date: Date(timeIntervalSince1970: Double(index)), instrumentId: "guitar.acoustic.6", kind: "tuning", count: 3, stableCount: 2, durationMs: 2000))
        }
        XCTAssertEqual(try LocalStore(directory: directory).records.count, 502)
        try store.clearHistory()
        XCTAssertTrue(try LocalStore(directory: directory).records.isEmpty)
    }
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    func testSettingsAndRecordsSurviveReopen() throws {
        let directory = try directory(), store = try LocalStore(directory: directory)
        var settings = store.settings
        settings.referencePitchHz = 442; settings.hapticsEnabled = false
        settings.lastTuningIds = ["guitar.acoustic.6": "guitar.drop-d"]
        try store.saveSettings(settings)
        let record = PracticeRecord(instrumentId: "guitar.acoustic.6", kind: "tuner", count: 20, stableCount: 15, meanAbsoluteCents: 12.5)
        try store.append(record)
        let reopened = try LocalStore(directory: directory)
        XCTAssertEqual(reopened.settings, settings)
        XCTAssertEqual(reopened.records, [record])
        XCTAssertTrue(reopened.demonstratedLevels.isEmpty)
    }
    func testFailedWriteDoesNotChangeMemory() throws {
        let directory = try directory(), store = try LocalStore(directory: directory)
        // A directory at the file destination reliably rejects an atomic file replacement.
        try FileManager.default.createDirectory(at: directory.appendingPathComponent(LocalStore.fileName), withIntermediateDirectories: true)
        var settings = store.settings; settings.referencePitchHz = 442
        XCTAssertThrowsError(try store.saveSettings(settings))
        XCTAssertEqual(store.settings.referencePitchHz, 440)
        XCTAssertThrowsError(try store.append(PracticeRecord(instrumentId: "test", kind: "tuner", count: 1, stableCount: 1)))
        XCTAssertTrue(store.records.isEmpty)
    }
    func testInvalidUpdateDoesNotReplaceSavedState() throws {
        let directory = try directory(), store = try LocalStore(directory: directory)
        try store.saveSettings(store.settings)
        var settings = store.settings; settings.confidenceThreshold = .nan
        XCTAssertThrowsError(try store.saveSettings(settings))
        XCTAssertEqual(try LocalStore(directory: directory).settings.confidenceThreshold, 0.75)
        XCTAssertThrowsError(try store.append(PracticeRecord(instrumentId: "guitar", kind: "tuner", count: 1, stableCount: 2)))
    }
    func testHistoryClearIsPersistedAndRetainsSettings() throws {
        let directory = try directory(), store = try LocalStore(directory: directory)
        var settings = store.settings; settings.reducedMotion = true
        try store.saveSettings(settings)
        try store.append(PracticeRecord(instrumentId: "guitar", kind: "tuner", count: 0, stableCount: 0))
        try store.clearHistory()
        let reopened = try LocalStore(directory: directory)
        XCTAssertTrue(reopened.records.isEmpty)
        XCTAssertTrue(reopened.demonstratedLevels.isEmpty)
        XCTAssertTrue(reopened.settings.reducedMotion)
    }
    func testOnlyMeasuredCurrentVoiceEvidenceAdvancesProgress() throws {
        let directory = try directory(), store = try LocalStore(directory: directory)
        let exercise = VoiceExercise(level: 4), attempt = VoiceAttempt(exercise: VoiceExercise(level: 4))
        for index in 0..<110 { attempt.accept(frequency: 220, stable: true, elapsedMs: index * 50) }
        let result = attempt.finish()
        XCTAssertTrue(result.demonstrated)
        try store.append(PracticeRecord(instrumentId: "voice", tuningId: "voice.pitch.v1.4", kind: "voice", count: 110, stableCount: 110, voiceResult: result))
        XCTAssertTrue(store.demonstratedLevels.isEmpty)
        try store.append(PracticeRecord(instrumentId: "voice", tuningId: exercise.id, kind: "tuner", count: 110, stableCount: 110, voiceResult: result))
        XCTAssertTrue(store.demonstratedLevels.isEmpty)
        try store.append(PracticeRecord(instrumentId: "voice", tuningId: exercise.id, kind: "voice", count: 110, stableCount: 110, voiceResult: result))
        XCTAssertEqual(store.demonstratedLevels, [4])
        XCTAssertEqual(try LocalStore(directory: directory).demonstratedLevels, [4])
    }
    func testRecentSelectionsBoundedAndDeduplicatedInOrder() throws {
        let store = try LocalStore(directory: directory())
        var settings = store.settings
        settings.recentInstrumentIds = ["a", "b", "a"] + (0..<20).map(String.init)
        try store.saveSettings(settings)
        XCTAssertEqual(store.settings.recentInstrumentIds.count, LocalStore.recentInstrumentLimit)
        XCTAssertEqual(Array(store.settings.recentInstrumentIds.prefix(2)), ["a", "b"])
    }
    func testReferencePitchAndWrittenTranspositionEnforceSourceBounds() throws {
        let directory = try directory(), store = try LocalStore(directory: directory)
        for pitch in [415.0, 466.0] {
            var settings = store.settings; settings.referencePitchHz = pitch
            try store.saveSettings(settings)
            XCTAssertEqual(try LocalStore(directory: directory).settings.referencePitchHz, pitch)
        }
        for pitch in [414.999, 466.001, 300, 500] {
            var settings = store.settings; settings.referencePitchHz = pitch
            XCTAssertThrowsError(try store.saveSettings(settings))
            XCTAssertEqual(store.settings.referencePitchHz, 466)
        }
        for transposition in [-12, 12] {
            var settings = store.settings; settings.transposition = transposition
            try store.saveSettings(settings)
            XCTAssertEqual(try LocalStore(directory: directory).settings.transposition, transposition)
        }
        for transposition in [-24, -13, 13, 24] {
            var settings = store.settings; settings.transposition = transposition
            XCTAssertThrowsError(try store.saveSettings(settings))
            XCTAssertEqual(store.settings.transposition, 12)
        }
    }

    // MARK: Opening never locks anyone out

    private var fixtures: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures", isDirectory: true)
    }

    private func install(_ data: Data, in directory: URL) throws {
        try data.write(to: directory.appendingPathComponent(LocalStore.fileName))
    }

    /// Edits the saved file as another version, or a damaged disk, might have left it.
    private func rewrite(_ directory: URL, _ edit: (inout [String: Any]) throws -> Void) throws {
        let url = directory.appendingPathComponent(LocalStore.fileName)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        try edit(&json)
        try JSONSerialization.data(withJSONObject: json).write(to: url)
    }

    private func rewriteSettings(_ directory: URL, _ edit: (inout [String: Any]) throws -> Void) throws {
        try rewrite(directory) { json in
            var settings = try XCTUnwrap(json["settings"] as? [String: Any])
            try edit(&settings)
            json["settings"] = settings
        }
    }

    func testGoldenV1FileOpensWithEverythingInIt() throws {
        let directory = try directory()
        try install(Data(contentsOf: fixtures.appendingPathComponent("state-v1-2026-10.json")), in: directory)
        let store = try LocalStore(directory: directory)
        XCTAssertNil(store.recovery)
        let settings = store.settings
        XCTAssertEqual(settings.referencePitchHz, 442)
        XCTAssertEqual(settings.capo, 2)
        XCTAssertEqual(settings.handedness, .left)
        XCTAssertEqual(settings.lastTuningIds["guitar.acoustic.6"], "guitar.acoustic.6.drop_d")
        XCTAssertEqual(settings.onboardingCompleted, true)
        XCTAssertEqual(settings.goal, "songs")
        XCTAssertEqual(settings.metronomeBpm, 96)
        XCTAssertEqual(settings.customTunings?.map(\.name), ["Open C"])
        XCTAssertEqual(settings.progress?.xp, 1240)
        XCTAssertEqual(settings.progress?.streakFreezes, 1)
        XCTAssertEqual(settings.progress?.achievements.count, 3)
        XCTAssertEqual(settings.learn?.stars.count, 3)
        XCTAssertEqual(settings.learn?.lastLessonId, "gtr-1-3")
        XCTAssertEqual(settings.precision, .standard)
        XCTAssertEqual(settings.lastChord, UserSettings.ChordChoice(root: 9, formula: "min"))
        XCTAssertTrue(settings.hasShownDemo("chord:0,2,2,0,0,0", in: "guitar"))
        XCTAssertNotNil(settings.spacedReview)
        XCTAssertEqual(store.records.map(\.kind), ["tuning", "ear", "lesson"])
        XCTAssertEqual(store.demonstratedLevels, [2, 4])
        // English was the default then: nobody picked it, so the app follows the device now.
        XCTAssertEqual(settings.language, TimbreLocalization.system)
        XCTAssertFalse(settings.languageChosen)
        // Fields that came later read as their defaults.
        XCTAssertFalse(settings.simpleTuner || settings.calmMode || settings.tuneByFeel || settings.feelTheBeat)
        XCTAssertFalse(settings.bandOnSpeaker || settings.chartsAsPrinted || settings.firstChordDone)
        // Saved again, it reads back the same.
        try store.saveSettings(settings)
        XCTAssertEqual(try LocalStore(directory: directory).settings, settings)
    }

    func testEverySettingSurvivesTheLenientDecoder() throws {
        var settings = UserSettings()
        settings.referencePitchHz = 442; settings.temperamentId = "just"; settings.theme = "light"; settings.skin = "wood"
        settings.reducedMotion = true; settings.hapticsEnabled = false; settings.language = "de"
        settings.recentInstrumentIds = ["guitar.acoustic.6", "ukulele.soprano.4"]; settings.analysisWindowOverride = 4096
        settings.micSensitivity = 40; settings.confidenceThreshold = 0.6; settings.notation = "solfege"
        settings.capo = 3; settings.transposition = -2; settings.handedness = .leftUpsideDown
        settings.lastTuningIds = ["guitar.acoustic.6": "guitar.acoustic.6.drop_d"]; settings.selectedInstrumentId = "ukulele.soprano.4"
        settings.selectedPhotoAsset = "ukulele"; settings.telemetryEnabled = true; settings.selectedVoiceLevel = 3
        settings.onboardingCompleted = true; settings.playerLevel = "novice"; settings.goal = "songs"; settings.stageMode = "studio"
        settings.metronomeBpm = 96; settings.metronomeBeats = 3; settings.metronomeSubdivision = 2; settings.metronomeSound = "wood"
        settings.metronomeBeatLevels = [2, 1, 1]; settings.droneMidi = 50; settings.droneVoice = "pure"; settings.fullTunes = 7
        settings.dailyDone = ["2026-10-20": ["tune"]]; settings.dailyPlan = ["2026-10-20": ["ear"]]; settings.earLevels = ["intervals": 2]
        settings.customTunings = [CustomTuning(id: "custom.a", instrumentId: "guitar.acoustic.6", name: "Open C", midis: [36, 43, 48, 55, 60, 64])]
        var progress = ProgressState()
        progress.xp = 1240; progress.achievements = ["first_tune"]; progress.streakFreezes = 1
        settings.progress = progress
        var learn = LearnProgress()
        learn.stars = ["gtr-1-1": 3]; learn.lastCourseId = "guitar"
        settings.learn = learn
        settings.tuningPrecision = "standard"; settings.notationChosen = true; settings.spacedReview = ReviewDeck()
        settings.lastChord = UserSettings.ChordChoice(root: 9, formula: "min"); settings.shownDemos = ["guitar": ["chord:0,2,2,0,0,0"]]
        settings.languageChosen = true; settings.simpleTuner = true; settings.calmMode = true; settings.tuneByFeel = true
        settings.feelTheBeat = true; settings.bandOnSpeaker = true; settings.chartsAsPrinted = true; settings.firstChordDone = true
        settings.shareUsageData = false
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(UserSettings.self, from: data), settings)
        // Every setting is given a value above, so every one is written: a new one left out here fails this count.
        let written = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(written.count, Mirror(reflecting: settings).children.count, "set the new setting above, so the round trip covers it")
    }

    func testOutOfBoundsAndUnreadableValuesAreRepairedOnOpening() throws {
        let directory = try directory(), store = try LocalStore(directory: directory)
        let record = PracticeRecord(instrumentId: "guitar.acoustic.6", kind: "tuning", count: 5, stableCount: 4)
        try store.append(record)
        try rewrite(directory) { json in
            var settings = try XCTUnwrap(json["settings"] as? [String: Any])
            settings["referencePitchHz"] = 500
            settings["micSensitivity"] = 150
            settings["capo"] = -3
            settings["selectedVoiceLevel"] = 12
            settings["handedness"] = "sideways"
            settings["transposition"] = "up"
            settings["futureSetting"] = ["a": 1]
            let tunings: [[String: Any]] = [["id": "custom.a", "instrumentId": "guitar.acoustic.6", "name": "Open C", "midis": [36, 43, 48, 55, 60, 64]],
                                            ["id": "custom.b", "instrumentId": "guitar.acoustic.6", "name": "Half written"]]
            settings["customTunings"] = tunings
            json["settings"] = settings
            var records = try XCTUnwrap(json["records"] as? [[String: Any]])
            records[0]["stableCount"] = 9
            records.append(records[0])
            records.append(["kind": "tuning"])
            json["records"] = records
            json["demonstratedLevels"] = [3, 7, 99]
            json["version"] = LocalStore.currentVersion + 1
            json["futureSection"] = true
        }
        let reopened = try LocalStore(directory: directory)
        XCTAssertNil(reopened.recovery)
        let settings = reopened.settings
        XCTAssertEqual(settings.referencePitchHz, 466)
        XCTAssertEqual(settings.micSensitivity, 100)
        XCTAssertEqual(settings.capo, 0)
        XCTAssertNil(settings.selectedVoiceLevel)
        XCTAssertEqual(settings.handedness, .right, "a value only a later version knows reads as the default")
        XCTAssertEqual(settings.transposition, 0)
        XCTAssertEqual(settings.customTunings?.map(\.id), ["custom.a"], "an unreadable custom tuning goes on its own")
        XCTAssertEqual(reopened.records.map(\.id), [record.id], "a duplicate and an unreadable record go; the session stays")
        XCTAssertEqual(reopened.records.first?.stableCount, 5)
        XCTAssertEqual(reopened.demonstratedLevels, [3])
        // What was repaired is a valid state to save.
        XCTAssertNoThrow(try reopened.saveSettings(settings))
    }

    func testAnUnreadableFileIsSetAsideAndTheBackupOpens() throws {
        let directory = try directory(), store = try LocalStore(directory: directory)
        let first = PracticeRecord(date: Date(timeIntervalSince1970: 1_000), instrumentId: "guitar.acoustic.6", kind: "tuning", count: 4, stableCount: 3)
        let second = PracticeRecord(date: Date(timeIntervalSince1970: 2_000), instrumentId: "guitar.acoustic.6", kind: "tuning", count: 4, stableCount: 3)
        try store.append(first)
        try store.append(second)
        let damaged = Data("{\"version\": 1, \"settings\": ".utf8)
        try install(damaged, in: directory)
        let reopened = try LocalStore(directory: directory)
        XCTAssertEqual(reopened.recovery, .restoredBackup)
        XCTAssertEqual(reopened.records, [first], "the copy from before the last save")
        let setAside = try XCTUnwrap(reopened.quarantinedFile)
        XCTAssertTrue(setAside.lastPathComponent.hasPrefix(LocalStore.quarantinePrefix))
        XCTAssertEqual(try Data(contentsOf: setAside), damaged, "the unreadable file is kept as it was")
        // The recovered state is the file again: the next opening is an ordinary one.
        let again = try LocalStore(directory: directory)
        XCTAssertNil(again.recovery)
        XCTAssertEqual(again.records, [first])
    }

    func testAnUnreadableFileWithoutABackupStartsFreshAndIsKept() throws {
        let directory = try directory()
        let bytes = Data("not valid JSON".utf8)
        try install(bytes, in: directory)
        let store = try LocalStore(directory: directory)
        XCTAssertEqual(store.recovery, .startedFresh)
        XCTAssertTrue(store.records.isEmpty)
        XCTAssertEqual(store.settings, UserSettings())
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(store.quarantinedFile)), bytes)
        XCTAssertNil(try LocalStore(directory: directory).recovery)
    }

    func testAFileTheSystemWontHandOverIsLeftAlone() throws {
        let directory = try directory(), store = try LocalStore(directory: directory)
        try store.append(PracticeRecord(instrumentId: "guitar", kind: "tuner", count: 1, stableCount: 1))
        let url = directory.appendingPathComponent(LocalStore.fileName)
        let bytes = try Data(contentsOf: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path) }
        try XCTSkipIf(FileManager.default.isReadableFile(atPath: url.path), "this process may read any file")
        XCTAssertThrowsError(try LocalStore(directory: directory))
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
        XCTAssertEqual(try Data(contentsOf: url), bytes)
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertFalse(names.contains { $0.hasPrefix(LocalStore.quarantinePrefix) })
    }

    func testEachSaveKeepsTheFileBeforeIt() throws {
        let directory = try directory(), store = try LocalStore(directory: directory)
        let backup = directory.appendingPathComponent(LocalStore.backupFileName)
        var settings = store.settings
        settings.capo = 1
        try store.saveSettings(settings)
        XCTAssertFalse(FileManager.default.fileExists(atPath: backup.path), "nothing to keep before the first save")
        settings.capo = 2
        try store.saveSettings(settings)
        // With the file gone, the backup opens: the state before the last save.
        try FileManager.default.removeItem(at: directory.appendingPathComponent(LocalStore.fileName))
        let reopened = try LocalStore(directory: directory)
        XCTAssertEqual(reopened.recovery, .restoredBackup)
        XCTAssertEqual(reopened.settings.capo, 1)
    }

    func testOnlyTheNewestSetAsideFilesAreKept() throws {
        let directory = try directory()
        for second in 0..<5 {
            try install(Data("broken \(second)".utf8), in: directory)
            try LocalStore.setAside(in: directory, now: Date(timeIntervalSince1970: 1_800_000_000 + Double(second)))
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasPrefix(LocalStore.quarantinePrefix) }
        XCTAssertEqual(names.count, LocalStore.quarantineLimit)
        let newest = try XCTUnwrap(names.max())
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(newest)), Data("broken 4".utf8))
        XCTAssertNil(try LocalStore.setAside(in: directory), "no state file, nothing to set aside")
    }

    func testAnEnglishNobodyPickedFollowsTheDevice() throws {
        let directory = try directory(), store = try LocalStore(directory: directory)
        XCTAssertEqual(store.settings.language, TimbreLocalization.system, "a fresh install follows the device")
        try store.saveSettings(store.settings)
        try rewriteSettings(directory) { settings in
            settings["language"] = "en"
            settings.removeValue(forKey: "languageChosen")
        }
        XCTAssertEqual(try LocalStore(directory: directory).settings.language, TimbreLocalization.system)
        try rewriteSettings(directory) { settings in
            settings["language"] = "de"
            settings.removeValue(forKey: "languageChosen")
        }
        let german = try LocalStore(directory: directory).settings
        XCTAssertEqual(german.language, "de")
        XCTAssertTrue(german.languageChosen, "only a player could have picked German")
        // English picked in Settings stays English.
        let reopened = try LocalStore(directory: directory)
        var picked = reopened.settings
        picked.language = "en"
        try reopened.saveSettings(picked)
        XCTAssertTrue(reopened.settings.languageChosen)
        XCTAssertEqual(try LocalStore(directory: directory).settings.language, "en")
    }
}
