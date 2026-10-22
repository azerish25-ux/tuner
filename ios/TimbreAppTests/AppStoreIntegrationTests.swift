import XCTest
import StoreKitTest
import UIKit
import TimbreCore
@testable import Timbre

/// Exercises the actual app state, DSP handoff, persistence and verified StoreKit gates.
/// Run serially with CommerceIntegrationTests because StoreKit has one shared test environment.
@MainActor
final class AppStoreIntegrationTests: XCTestCase {
    func testBundledTypographyRegistersActualFontNames() {
        for name in ["SpaceGrotesk-Light", "Inter-Regular", "IBMPlexMono-Medium"] {
            XCTAssertNotNil(UIFont(name: name, size: 20), "Bundled font must be registered instead of silently falling back: \(name)")
        }
    }
    private var directory: URL!
    private var session: SKTestSession!
    private var store: Timbre.AppStore!

    override func setUp() async throws {
        try await super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("Timbre-AppStoreTests-" + UUID().uuidString, isDirectory: true)
        session = try SKTestSession(configurationFileNamed: "Timbre")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        try await StoreKitTestEnvironment.waitUntilClean(session)
        store = try Timbre.AppStore(directory: directory)
        store.updateSettings { $0.hapticsEnabled = false }
        await store.commerce.load()
    }
    override func tearDown() async throws {
        store?.stopActivity()
        store = nil
        session?.clearTransactions()
        session = nil
        if let directory, FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
        directory = nil
        try await super.tearDown()
    }
    func testFreeInstrumentsAndPaidAlternatesPreserveCurrentSelection() throws {
        XCTAssertFalse(store.commerce.isPlus)
        for id in ["guitar.acoustic.6", "bass.electric.4", "ukulele.soprano.4"] {
            let instrument = try XCTUnwrap(store.catalog.instrument(id: id))
            store.showPlus = false
            store.selectInstrument(instrument)
            XCTAssertEqual(store.instrument.id, id)
            XCTAssertFalse(store.showPlus)
            let original = store.tuning.id
            let paidTuning = try XCTUnwrap(store.catalog.tunings.first { $0.instrumentId == id && !$0.isFree })
            store.selectTuning(paidTuning)
            XCTAssertTrue(store.showPlus)
            XCTAssertEqual(store.tuning.id, original)
        }
        let originalInstrument = store.instrument.id
        let paidInstrument = try XCTUnwrap(store.catalog.instrument(id: "violin.standard.4"))
        store.selectInstrument(paidInstrument)
        XCTAssertTrue(store.showPlus)
        XCTAssertEqual(store.instrument.id, originalInstrument)
    }
    func testVerifiedPurchaseUnlocksPaidInstrumentAndPairedTwelveStringCourses() async throws {
        _ = try XCTUnwrap(store.commerce.product)
        await store.commerce.purchase()
        try await waitUntil { self.store.commerce.isPlus }
        let guitar = try XCTUnwrap(store.catalog.instrument(id: "guitar.acoustic.12"))
        store.showPlus = false
        store.selectInstrument(guitar)
        XCTAssertFalse(store.showPlus)
        XCTAssertEqual(store.instrument.id, guitar.id)
        XCTAssertEqual(store.courses.count, 12)
        let pairs = store.tuning.coursesByAnchor
        XCTAssertEqual(pairs.count, 6)
        XCTAssertTrue(pairs.values.allSatisfy { $0.count == 2 })
        XCTAssertEqual(pairs["c6"]?.map(\.targetMidi), [40, 52])
        let alternate = try XCTUnwrap(store.catalog.tuning(id: "guitar.acoustic.6.drop_d"))
        store.selectInstrument(try XCTUnwrap(store.catalog.instrument(id: "guitar.acoustic.6")))
        store.selectTuning(alternate)
        XCTAssertEqual(store.tuning.id, alternate.id)
    }
    func testInstrumentPhotoAndTuningSelectionIsOneConfirmedTransaction() async throws {
        await store.commerce.purchase()
        try await waitUntil { self.store.commerce.isPlus }
        let bass = try XCTUnwrap(store.catalog.instrument(id: "bass.electric.4"))
        let five = try XCTUnwrap(store.catalog.tuning(id: "bass.electric.4.five"))
        let photo = try XCTUnwrap(store.catalog.photos.first { $0.label == "5-string bass" })
        XCTAssertTrue(store.selectInstrument(bass, photo: photo.asset, tuning: five))
        let saved = try LocalStore(directory: directory).settings
        XCTAssertEqual(saved.selectedInstrumentId, bass.id)
        XCTAssertEqual(saved.selectedPhotoAsset, photo.asset)
        XCTAssertEqual(saved.lastTuningIds[bass.id], five.id)
        XCTAssertEqual(store.photo?.label, "5-string bass")
        store.selectReference()
        try FileManager.default.removeItem(at: directory)
        let occupiedPath = directory.deletingLastPathComponent().appendingPathComponent(directory.lastPathComponent, isDirectory: false)
        try Data("unavailable storage".utf8).write(to: occupiedPath)
        defer { try? FileManager.default.removeItem(at: occupiedPath) }
        let uke = try XCTUnwrap(store.catalog.instrument(id: "ukulele.soprano.4"))
        XCTAssertFalse(store.selectInstrument(uke, tuning: store.catalog.tuning(id: uke.defaultTuningId)))
        XCTAssertEqual(store.settings, saved)
        XCTAssertTrue(store.referenceMode)
        XCTAssertNotNil(store.error)
    }
    func testDisplayTransposeAndCapoLeaveSoundingPitchUnchangedWhileCalibrationChangesIt() {
        store.chooseCourse(6)
        let originalMidi = store.activeMidi
        let originalHz = store.targetHz
        store.updateSettings { $0.transposition = 2; $0.capo = 1 }
        XCTAssertEqual(store.targetName, PitchMath.noteName(midi: originalMidi + 1))
        XCTAssertEqual(store.activeMidi, originalMidi)
        XCTAssertEqual(store.targetHz, originalHz, accuracy: 1e-9)
        store.updateSettings { $0.referencePitchHz = 432 }
        XCTAssertEqual(store.targetHz, originalHz * 432 / 440, accuracy: 1e-8)
    }
    func testSyntheticDetectedReadingsFinishAndPersistMeasuredStatistics() throws {
        store.chooseCourse(6)
        let target = store.targetHz
        let detected = try detectedPitch(hz: target * PitchMath.ratio(cents: 2))
        for _ in 0..<12 { store.accept(detected.frequencyHz, confidence: detected.confidence, level: detected.levelDbfs) }
        let expectedError = abs(PitchMath.cents(target: target, measured: detected.frequencyHz))
        store.finishTuning()
        XCTAssertNil(store.error)
        let record = try XCTUnwrap(store.records.last)
        XCTAssertEqual(record.instrumentId, "guitar.acoustic.6")
        XCTAssertEqual(record.tuningId, "guitar.acoustic.6.standard")
        XCTAssertEqual(record.count, 12)
        XCTAssertEqual(record.stableCount, 10)
        XCTAssertEqual(try XCTUnwrap(record.meanAbsoluteCents), expectedError, accuracy: 1e-7)
        let disk = try LocalStore(directory: directory)
        XCTAssertEqual(disk.records, store.records)
        store.finishTuning()
        XCTAssertEqual(store.records.count, 1)
        XCTAssertNotNil(store.error)
    }
    func testChangingInstrumentDropsPreviousCountersRatherThanMisattributingHistory() throws {
        store.chooseCourse(6)
        let detected = try detectedPitch(hz: store.targetHz)
        for _ in 0..<5 { store.accept(detected.frequencyHz, confidence: detected.confidence, level: detected.levelDbfs) }
        store.selectInstrument(try XCTUnwrap(store.catalog.instrument(id: "bass.electric.4")))
        store.finishTuning()
        XCTAssertTrue(store.records.isEmpty)
        XCTAssertNotNil(store.error)
    }
    private func detectedPitch(hz: Double) throws -> DetectedPitch {
        let samples: [Float] = (0..<4096).map { Float(0.6 * sin(2 * .pi * hz * Double($0) / 48000)) }
        return try XCTUnwrap(YinPitchDetector(sampleRate: 48000, minFrequency: 50, maxFrequency: 1000).detect(samples))
    }
    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(12)
        while !condition(), Date() < deadline { try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertTrue(condition(), "Verified StoreKit entitlement did not arrive")
    }
}
