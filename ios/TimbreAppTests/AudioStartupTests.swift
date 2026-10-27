import XCTest
import TimbreCore
@testable import Timbre

/// Exercise the real AudioService command path with a session that the test can hold pending. No audio hardware
/// is required: only graph preparation is replaced. These assertions cover intent across actor suspension points.
@MainActor
final class AudioStartupTests: XCTestCase {
    @MainActor
    private final class SessionGate {
        var continuations: [CheckedContinuation<Void, Error>] = []
        var releases = 0
        var preparations = 0

        func activate(_: TimeInterval) async throws {
            try await withCheckedThrowingContinuation { continuations.append($0) }
        }

        func finish() {
            let waiting = continuations
            continuations.removeAll()
            for continuation in waiting { continuation.resume() }
        }
    }

    private func service(_ gate: SessionGate) -> AudioService {
        AudioService(activateSession: { try await gate.activate($0) },
                     releaseSession: { gate.releases += 1 },
                     prepareOutput: { gate.preparations += 1 }, requestPermission: { true }, reserveSession: {})
    }

    private func waitForActivation(_ gate: SessionGate) async {
        for _ in 0..<100 where gate.continuations.isEmpty { await Task.yield() }
        XCTAssertFalse(gate.continuations.isEmpty, "the output command must await session activation")
    }

    func testOutputActivationYieldsTheMainActorAndCoalescesStartup() async {
        let gate = SessionGate()
        let audio = service(gate)
        let first = audio.setMetronome(bpm: 60, beats: 4, subdivision: 1, accents: true)
        let latest = audio.setMetronome(bpm: 90, beats: 4, subdivision: 1, accents: true)
        await waitForActivation(gate)
        XCTAssertEqual(gate.continuations.count, 1, "one hardware startup serves concurrent output requests")
        XCTAssertEqual(gate.preparations, 0, "no engine or click starts before session readiness")
        gate.finish()
        let oldStarted = await first.value
        let latestStarted = await latest.value
        XCTAssertFalse(oldStarted, "a superseded tempo must never install its click")
        XCTAssertTrue(latestStarted)
        XCTAssertEqual(gate.preparations, 1)
        XCTAssertTrue(audio.metronomeRunning)
        audio.stop()
    }

    func testStopDuringActivationNeverStartsOutputAndReleasesWhenActivationSettles() async {
        let gate = SessionGate()
        let audio = service(gate)
        let request = audio.setMetronome(bpm: 60, beats: 4, subdivision: 1, accents: true)
        await waitForActivation(gate)
        audio.stopMetronome()
        XCTAssertEqual(gate.releases, 0, "pending activation still owns its reservation")
        gate.finish()
        let started = await request.value
        XCTAssertFalse(started)
        XCTAssertEqual(gate.preparations, 0)
        XCTAssertEqual(gate.releases, 1)
        XCTAssertFalse(audio.metronomeRunning)
    }

    func testCancellingTheReadinessHandleCannotInstallAClick() async {
        let gate = SessionGate()
        let audio = service(gate)
        let request = audio.setMetronome(bpm: 60, beats: 4, subdivision: 1, accents: true)
        await waitForActivation(gate)
        request.cancel()
        gate.finish()
        let started = await request.value
        XCTAssertFalse(started)
        XCTAssertFalse(audio.metronomeRunning)
        XCTAssertNil(audio.metronomeOrigin())
        XCTAssertEqual(gate.releases, 1)
    }

    func testNewOutputIntentSurvivesOlderStoppedStartup() async {
        let gate = SessionGate()
        let audio = service(gate)
        let first = audio.setMetronome(bpm: 60, beats: 4, subdivision: 1, accents: true)
        await waitForActivation(gate)
        audio.stop()
        let newer = audio.setDrone(tonic: 110, voice: .tanpura, fifth: true)
        gate.finish()
        _ = await first.value
        // A full stop invalidates the old engine lifecycle; the new request owns a fresh activation.
        await waitForActivation(gate)
        gate.finish()
        let started = await newer.value
        XCTAssertTrue(started)
        XCTAssertTrue(audio.droneRunning)
        XCTAssertEqual(gate.releases, 0, "a stale output request cannot release the newer holder")
        audio.stop()
    }

    func testExplicitStopDuringInterruptionSuppressesAutomaticRestore() async {
        let gate = SessionGate()
        let audio = service(gate)
        let request = audio.setMetronome(bpm: 60, beats: 4, subdivision: 1, accents: true, tool: true)
        await waitForActivation(gate)
        gate.finish()
        _ = await request.value
        audio.interruptionBegan()
        audio.stop()
        audio.interruptionEnded(resume: true)
        for _ in 0..<10 { await Task.yield() }
        XCTAssertFalse(audio.metronomeRunning)
        XCTAssertTrue(gate.continuations.isEmpty, "a user stop during a call cancels the saved restore intent")
    }

    func testNoShouldResumeLeavesOutputStopped() async {
        let gate = SessionGate()
        let audio = service(gate)
        let request = audio.setMetronome(bpm: 60, beats: 4, subdivision: 1, accents: true, tool: true)
        await waitForActivation(gate)
        gate.finish()
        _ = await request.value
        audio.interruptionBegan()
        audio.interruptionEnded(resume: false)
        XCTAssertFalse(audio.metronomeRunning)
        XCTAssertTrue(gate.continuations.isEmpty)
    }

    func testStoppingOneInterruptedToolPreservesOnlyTheOtherToolsRestoreIntent() async {
        let gate = SessionGate()
        let audio = service(gate)
        let click = audio.setMetronome(bpm: 60, beats: 4, subdivision: 1, accents: true, tool: true)
        let drone = audio.setDrone(tonic: 110, voice: .tanpura, fifth: true)
        await waitForActivation(gate)
        gate.finish()
        _ = await click.value
        _ = await drone.value
        audio.interruptionBegan()
        audio.stopDrone()
        audio.interruptionEnded(resume: true)
        XCTAssertTrue(audio.metronomeRunning, "the click is still wanted after the call")
        XCTAssertFalse(audio.droneRunning, "an explicit drone stop cancels its saved restore")
        await waitForActivation(gate)
        gate.finish()
        for _ in 0..<100 { await Task.yield() }
        audio.stop()
    }

    func testLessonClockWaitsForReadinessAndNavigationCancelsItsCallback() async {
        let gate = SessionGate()
        let audio = service(gate)
        let lesson = AudioStartGate()
        var clocksStarted = 0
        lesson.begin(audio.setMetronome(bpm: 60, beats: 4, subdivision: 1, accents: true)) {
            clocksStarted += 1
        }
        await waitForActivation(gate)
        XCTAssertEqual(clocksStarted, 0)
        lesson.cancel()
        audio.stopMetronome()
        gate.finish()
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(clocksStarted, 0, "leaving a lesson must never start its take after activation finishes")
    }

    func testLessonClockStartsOnceAfterSuccessfulReadiness() async {
        let gate = SessionGate()
        let audio = service(gate)
        let lesson = AudioStartGate()
        let started = expectation(description: "lesson may initialize its clock")
        lesson.begin(audio.setMetronome(bpm: 60, beats: 4, subdivision: 1, accents: true)) { started.fulfill() }
        await waitForActivation(gate)
        gate.finish()
        let result = await XCTWaiter.fulfillment(of: [started], timeout: 1)
        XCTAssertEqual(result, .completed)
        audio.stop()
    }

    func testPendingCaptureSurvivesInterruptionButAnExplicitCaptureStopCancelsRestore() async {
        let gate = SessionGate()
        let audio = service(gate)
        let capture = Task { await audio.start() }
        await waitForActivation(gate)
        audio.interruptionBegan()
        audio.stopCapture()
        audio.interruptionEnded(resume: true)
        gate.finish()
        await capture.value
        for _ in 0..<10 { await Task.yield() }
        XCTAssertTrue(gate.continuations.isEmpty, "stopCapture removes pending microphone intent from a call snapshot")
        XCTAssertFalse(audio.running)
    }

    func testStaleMicrophoneCompletionCannotReleaseNewOutput() async {
        let gate = SessionGate()
        let audio = service(gate)
        let capture = Task { await audio.start() }
        await waitForActivation(gate)
        audio.stopCapture()
        let click = audio.setMetronome(bpm: 60, beats: 4, subdivision: 1, accents: true)
        for _ in 0..<100 where gate.continuations.count < 2 { await Task.yield() }
        XCTAssertEqual(gate.continuations.count, 2)
        guard gate.continuations.count == 2 else { gate.finish(); await capture.value; return }
        let microphone = gate.continuations.removeFirst()
        let output = gate.continuations.removeFirst()
        output.resume()
        let ready = await click.value
        XCTAssertTrue(ready)
        microphone.resume()
        await capture.value
        XCTAssertEqual(gate.releases, 0)
        XCTAssertTrue(audio.metronomeRunning)
        audio.stop()
    }

    func testInterruptionRemembersCaptureWhoseSessionHasNotFinishedStarting() async {
        let gate = SessionGate()
        let audio = service(gate)
        let capture = Task { await audio.start() }
        await waitForActivation(gate)
        guard !gate.continuations.isEmpty else { return }
        let original = gate.continuations.removeFirst()
        audio.interruptionBegan()
        audio.interruptionEnded(resume: true)
        original.resume()
        await capture.value
        await waitForActivation(gate)
        // Stop before allowing the restored request to touch real microphone hardware.
        audio.stopCapture()
        gate.finish()
        for _ in 0..<100 { await Task.yield() }
        XCTAssertFalse(audio.running)
    }

    func testStopBeforeQueuedMicrophoneRestoreRunsInvalidatesThatRestore() async {
        let gate = SessionGate()
        let audio = service(gate)
        let capture = Task { await audio.start() }
        await waitForActivation(gate)
        audio.interruptionBegan()
        audio.interruptionEnded(resume: true)
        audio.stop()
        gate.finish()
        await capture.value
        for _ in 0..<100 { await Task.yield() }
        XCTAssertTrue(gate.continuations.isEmpty, "a queued restore must re-check the lifecycle token after stop")
        XCTAssertFalse(audio.running)
    }

    func testCompletedReadinessCannotStartALessonAfterInterruptionOrReplacement() async {
        let gate = SessionGate()
        let audio = service(gate)
        let request = audio.setMetronome(bpm: 60, beats: 4, subdivision: 1, accents: true)
        await waitForActivation(gate)
        gate.finish()
        _ = await request.value
        audio.interruptionBegan()
        let lesson = AudioStartGate()
        var callbacks = 0
        lesson.begin(request) { callbacks += 1 }
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(callbacks, 0, "successful startup is revocable until the caller consumes it")
        audio.stop()
    }

    func testCompletedReadinessChecksCommandIdentityAtConsumption() async {
        let gate = SessionGate()
        let audio = service(gate)
        let first = audio.setMetronome(bpm: 60, beats: 4, subdivision: 1, accents: true)
        await waitForActivation(gate)
        gate.finish()
        _ = await first.value
        let replacement = audio.setMetronome(bpm: 90, beats: 4, subdivision: 1, accents: true)
        var callbacks = 0
        XCTAssertFalse(first.consume { callbacks += 1 })
        _ = await replacement.value
        XCTAssertTrue(replacement.consume { callbacks += 1 })
        XCTAssertEqual(callbacks, 1)
        audio.stop()
    }

    func testPreviewKeepsOutputAcrossPhraseEndAndLongRestAndReleasesOnCancellation() async {
        let gate = SessionGate()
        let audio = service(gate)
        var sleeps: [CheckedContinuation<Void, Error>] = []
        var finished = 0
        let preview = SongPlayback.start([
            .init(beat: 0, beats: 0.1, midis: [60]), .init(beat: 8, beats: 0.1, midis: [64])
        ], bpm: 60, meter: 4, length: 10, band: nil, loop: false, audio: audio, voice: .guitar,
           reference: 440, waitUntil: { _ in
            try await withCheckedThrowingContinuation { sleeps.append($0) }
        }, finished: { finished += 1 })
        await waitForActivation(gate)
        gate.finish()
        for _ in 0..<100 where sleeps.isEmpty { await Task.yield() }
        XCTAssertEqual(sleeps.count, 1)
        if !sleeps.isEmpty { sleeps.removeFirst().resume() }
        for _ in 0..<100 where sleeps.isEmpty { await Task.yield() }
        // Simulate the first phrase ending while the preview is waiting through an eight-beat rest.
        audio.stopTone()
        XCTAssertTrue(audio.outputActive, "preview owns output independently of a phrase")
        XCTAssertEqual(gate.releases, 0)
        if !sleeps.isEmpty { sleeps.removeFirst().resume() }
        for _ in 0..<100 where sleeps.isEmpty { await Task.yield() }
        XCTAssertTrue(gate.continuations.isEmpty, "later notes reuse the held output instead of activating again")
        XCTAssertEqual(gate.preparations, 1)
        preview.cancel()
        for continuation in sleeps { continuation.resume(throwing: CancellationError()) }
        sleeps.removeAll()
        await preview.value
        SongPlayback.stop(audio)
        XCTAssertFalse(audio.outputActive)
        XCTAssertEqual(finished, 0)
    }

    func testPreviewActivationFailureFinishesWithoutStartingItsTimeline() async {
        let gate = SessionGate()
        let audio = service(gate)
        var sleeps = 0
        var finished = 0
        let preview = SongPlayback.start([.init(beat: 0, beats: 1, midis: [60])], bpm: 60, meter: 4,
                                         length: 2, band: nil, loop: false, audio: audio, voice: .guitar,
                                         reference: 440, waitUntil: { _ in sleeps += 1 },
                                         finished: { finished += 1 })
        await waitForActivation(gate)
        let pending = gate.continuations
        gate.continuations.removeAll()
        for continuation in pending { continuation.resume(throwing: AudioFailure.noOutput) }
        await preview.value
        XCTAssertEqual(sleeps, 0)
        XCTAssertEqual(finished, 1)
        XCTAssertFalse(audio.outputActive)
    }

    func testWelcomeRechecksAmbientOwnershipAfterSuspendedPreparation() async {
        let owner = AudioSessionOwner(setAmbient: {})
        await owner.prepareInterfaceSound()
        XCTAssertTrue(owner.interfaceSoundMayPlayNow())
        var preparation: CheckedContinuation<Void, Never>?
        var playerActions = 0
        let welcome = Task { @MainActor in
            await InterfaceSoundPlayback.play(ambientOnly: true, prepare: {
                await withCheckedContinuation { preparation = $0 }
            }, ambientAllowed: { owner.interfaceSoundMayPlayNow() }) { playerActions += 1 }
        }
        for _ in 0..<100 where preparation == nil { await Task.yield() }
        // This synchronous intent precedes the competing request's asynchronous AVAudioSession setters.
        owner.reserveIntent(.lessons)
        preparation?.resume()
        await welcome.value
        XCTAssertEqual(playerActions, 0, "neither player preparation nor playback is permitted after the claim")
        owner.release(.lessons, deactivate: false)
        await InterfaceSoundPlayback.play(ambientOnly: false, prepare: {}, ambientAllowed: { false }) {
            playerActions += 1
        }
        XCTAssertEqual(playerActions, 1, "ordinary cues may use an engine-owned session")
    }

    func testForegroundOutputIntentIsVisibleBeforeItsActivationTaskRuns() async {
        let owner = AudioSessionOwner(setAmbient: {})
        await owner.prepareInterfaceSound()
        let audio = AudioService(activateSession: { _ in }, releaseSession: {
            owner.release(.lessons, deactivate: false)
        }, prepareOutput: {}, requestPermission: { true }, reserveSession: { owner.reserveIntent(.lessons) })
        let request = audio.setMetronome(bpm: 60, beats: 4, subdivision: 1, accents: true)
        XCTAssertFalse(owner.interfaceSoundMayPlayNow(), "the claim cannot wait for an async actor hop")
        audio.stopMetronome()
        _ = await request.value
        XCTAssertTrue(owner.interfaceSoundMayPlayNow())
    }

    func testPreviewDoesNotConsumeCompletedReadinessAfterGlobalStop() async {
        let gate = SessionGate()
        let audio = service(gate)
        var waiting: CheckedContinuation<Void, Error>?
        var finished = 0
        let preview = SongPlayback.start([.init(beat: 4, beats: 1, midis: [60])], bpm: 60, meter: 4,
                                         length: 6, band: nil, loop: false, audio: audio, voice: .guitar,
                                         reference: 440, waitUntil: { _ in
            try await withCheckedThrowingContinuation { waiting = $0 }
        }, finished: { finished += 1 })
        await waitForActivation(gate)
        gate.finish()
        for _ in 0..<100 where waiting == nil { await Task.yield() }
        audio.stop()
        waiting?.resume()
        await preview.value
        XCTAssertEqual(finished, 1)
        XCTAssertFalse(audio.tonePlaying)
        XCTAssertFalse(audio.outputActive)
        XCTAssertTrue(gate.continuations.isEmpty, "the stopped preview cannot reactivate for its delayed first note")
    }

    func testGateChecksCurrentIntentWhenAWaitingSuccessResumes() async {
        var completed: CheckedContinuation<Bool, Never>?
        var current = true
        var callbacks = 0
        let request = AudioReadiness(task: Task {
            await withCheckedContinuation { completed = $0 }
        }, current: { current })
        let gate = AudioStartGate()
        gate.begin(request) { callbacks += 1 }
        for _ in 0..<100 where completed == nil { await Task.yield() }
        completed?.resume(returning: true)
        // No yield: invalidate before the waiting gate can consume the newly successful result.
        current = false
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(callbacks, 0)
    }
}
