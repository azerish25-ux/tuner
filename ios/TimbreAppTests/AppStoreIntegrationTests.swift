import XCTest
import TimbreCore
import UIKit
@testable import Timbre

@MainActor
final class AppStoreIntegrationTests: XCTestCase {
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

    func testFreeInstrumentOffersEveryPresetTuning() throws {
        let guitar = try XCTUnwrap(store.catalog.instrument(id: "guitar.acoustic.6"))
        XCTAssertTrue(store.selectInstrument(guitar))
        let dropD = try XCTUnwrap(store.catalog.tuning(id: "guitar.acoustic.6.drop_d"))
        store.selectTuning(dropD)
        XCTAssertEqual(store.tuning.id, dropD.id)
        XCTAssertFalse(store.showPaywall)
        XCTAssertEqual(store.courses.first?.label, "D2")
    }

    func testViolinAndCelloTuneFree() throws {
        let violin = try XCTUnwrap(store.catalog.instrument(id: "violin.standard.4"))
        XCTAssertTrue(store.selectInstrument(violin))
        let fiddle = try XCTUnwrap(store.catalog.tuning(id: "violin.standard.4.cross_ae"))
        store.selectTuning(fiddle)
        XCTAssertEqual(store.tuning.id, fiddle.id)
        let cello = try XCTUnwrap(store.catalog.instrument(id: "cello.standard.4"))
        XCTAssertTrue(store.selectInstrument(cello))
        XCTAssertEqual(store.instrument.id, cello.id)
        XCTAssertFalse(store.showPaywall)
    }

    func testEveryInstrumentTunesFreeInItsStandardTuning() throws {
        let viola = try XCTUnwrap(store.catalog.instrument(id: "viola.standard.4"))
        XCTAssertFalse(viola.isFree)
        XCTAssertTrue(store.selectInstrument(viola))
        XCTAssertEqual(store.instrument.id, viola.id)
        XCTAssertEqual(store.tuning.id, viola.defaultTuningId)
        XCTAssertTrue(store.canListen)
        XCTAssertFalse(store.showPaywall)
    }

    func testAnotherInstrumentsAlternateTuningShowsThePaywallForAFreeUser() throws {
        let banjo = try XCTUnwrap(store.catalog.instrument(id: "banjo.five.5"))
        XCTAssertTrue(store.selectInstrument(banjo))
        let alternate = try XCTUnwrap(store.tunings.first { $0.id != banjo.defaultTuningId })
        store.selectTuning(alternate)
        XCTAssertTrue(store.showPaywall)
        XCTAssertEqual(store.tuning.id, banjo.defaultTuningId)
    }

    func testAnUnreadableSavedFileOpensFreshAndSaysSo() throws {
        store = nil
        let fresh = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: fresh) }
        try FileManager.default.createDirectory(at: fresh, withIntermediateDirectories: true)
        try Data("not valid JSON".utf8).write(to: fresh.appendingPathComponent(LocalStore.fileName))
        let opened = try AppStore(directory: fresh)
        XCTAssertEqual(opened.storageRecovery, .startedFresh)
        XCTAssertNil(try AppStore(directory: fresh).storageRecovery, "told once: the next opening is an ordinary one")
    }

    func testGuitarHasA3DModelWithMatchingRigAnchors() throws {
        let modelID = try XCTUnwrap(store.modelID, "the free guitar should ship with a 3D model")
        XCTAssertNotNil(ModelLibrary.url(modelID))
        let rig = try XCTUnwrap(ModelLibrary.rig(modelID))
        let anchors = Set(store.courses.compactMap(\.anchorId))
        XCTAssertEqual(Set(rig.strings.map(\.anchor)), anchors)
        XCTAssertNotNil(UIImage(named: ModelLibrary.cardImageName(modelID)))
        XCTAssertNotNil(rig.card("s6.peg"))
    }

    func testListeningSettingsRestartOnlyWhenRelevant() throws {
        store.updateSettings { $0.hapticsEnabled = false }
        XCTAssertFalse(store.settings.hapticsEnabled)
        store.updateSettings { $0.referencePitchHz = 442 }
        XCTAssertEqual(store.targetHz, 442 * pow(2, (40 - 69) / 12.0), accuracy: 0.001)
    }

    func testMetronomeAndDroneSettingsPersist() throws {
        store.setMetronome(bpm: 132, beats: 7, subdivision: 2, sound: .wood)
        store.cycleBeatLevel(3)
        // Settings writes are coalesced; the app writes what is waiting when it leaves the foreground.
        store.flushSettings()
        let reopened = try AppStore(directory: directory)
        XCTAssertEqual(reopened.bpm, 132)
        XCTAssertEqual(reopened.beats, 7)
        XCTAssertEqual(reopened.subdivision, 2)
        XCTAssertEqual(reopened.metronomeSound, .wood)
        XCTAssertEqual(reopened.beatLevels[3], 0)
        reopened.setDrone(midi: 55, voice: .pure)
        reopened.flushSettings()
        XCTAssertEqual(try AppStore(directory: directory).droneMidi, 55)
    }

    /// Changes asked for "soon" (the tuner's lock path) wait, then apply together and in order; leaving the foreground
    /// applies and writes them.
    func testSettingsChangedSoonApplyTogetherAndFlush() throws {
        let before = store.settings.fullTunes ?? 0
        store.updateSettingsSoon { $0.fullTunes = ($0.fullTunes ?? 0) + 1 }
        store.updateSettingsSoon { $0.fullTunes = ($0.fullTunes ?? 0) + 1 }
        XCTAssertEqual(store.settings.fullTunes ?? 0, before, "nothing applies on the frame that asked")
        store.flushSettings()
        XCTAssertEqual(store.settings.fullTunes, before + 2)
        XCTAssertEqual(try AppStore(directory: directory).settings.fullTunes, before + 2)
    }

    /// A plan's course: the goal's own course, else the instrument's, else theory.
    func testPlanCourseFollowsTheGoalThenTheInstrument() throws {
        XCTAssertEqual(store.planCourse(forGoal: "ear", instrumentId: "guitar.acoustic.6")?.id, "ear")
        XCTAssertEqual(store.planCourse(forGoal: "songs", instrumentId: "violin.standard.4")?.id, "violin")
        XCTAssertEqual(store.planCourse(forGoal: "songs", instrumentId: nil)?.id, "theory")
        let guitar = try XCTUnwrap(store.catalog.instrument(id: "guitar.acoustic.6"))
        XCTAssertTrue(store.selectInstrument(guitar))
        XCTAssertEqual(store.planCourse(forGoal: "songs")?.id, "guitar")
        XCTAssertEqual(store.onboardingCourse(instrumentId: guitar.id, goal: "songs")?.id, "guitar")
    }

    func testSettingsWaitingForTheirWriteRideAlongWithAPracticeRecord() throws {
        store.setDrone(midi: 57)
        store.finishPractice(.ear, questions: 4, correct: 3)
        // The record's write carries the drone setting changed just before it.
        XCTAssertEqual(try AppStore(directory: directory).droneMidi, 57)
    }

    func testTuningSessionSavesOnPauseAndCountsTowardStreak() throws {
        for _ in 0..<40 { store.accept(store.targetHz * 1.002, confidence: 0.95, level: -30) }
        store.endTuningSession()
        XCTAssertTrue(store.records.isEmpty, "a few milliseconds of audio is not a session")
        store.finishPractice(.ear, questions: 10, correct: 8)
        XCTAssertEqual(store.records.first?.kind, "ear")
        XCTAssertEqual(store.streak.current, 1)
        XCTAssertTrue(store.dailyDone(.ear))
    }

    func testAutomaticModeFollowsThePlayedString() throws {
        store.automatic = true
        let a = try XCTUnwrap(store.courses.first { $0.label == "A2" })
        for _ in 0..<5 { store.accept(store.target(for: a), confidence: 0.95, level: -30) }
        XCTAssertEqual(store.selectedCourse, a.index)
    }

    func testTodayOpensWithTheNextLessonAndAFinishedLessonTicksItOff() throws {
        let lesson = try XCTUnwrap(store.dailyLesson, "a fresh learner has a free first lesson to play")
        XCTAssertEqual(store.dailySet.first?.kind, .lesson)
        let course = try XCTUnwrap(store.curriculum.lesson(id: lesson.id)?.course)
        store.finishLesson(LessonResult(lessonId: lesson.id, stars: 2, accuracy: 0.8, xp: 20, minutes: 4), courseId: course.id)
        XCTAssertTrue(store.dailyDone(.lesson))
        XCTAssertEqual(store.dailyLesson?.id, lesson.id, "Today keeps the lesson that was played, not the next one")
        XCTAssertEqual(store.dailySet.first?.kind, .lesson)
        XCTAssertTrue(store.streak.practicedToday, "any activity of Today keeps the streak")
        XCTAssertFalse(store.dailySetComplete)
    }
}
