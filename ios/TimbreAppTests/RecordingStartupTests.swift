import XCTest
@testable import Timbre

@MainActor
final class RecordingStartupTests: XCTestCase {
    func testRealDockTransportActionCancelsPendingPlaybackOnSecondTap() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        try SoundSynth.wav(SoundSynth.render(.click), rate: SoundSynth.rate).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        var waiting: CheckedContinuation<Void, Error>?
        var starts = 0
        var releases = 0
        let player = RecordingPlayer(activateSession: {
            try await withCheckedThrowingContinuation { waiting = $0 }
        }, releaseSession: { _ in releases += 1 }, preparePlayback: { starts += 1 }, reserveSession: {})
        player.load(url)
        ChartDock.toggleRecordingPlayback(player, beforePlay: {}, follow: {})
        for _ in 0..<100 where waiting == nil { await Task.yield() }
        XCTAssertTrue(player.playbackRequested)
        XCTAssertFalse(player.isPlaying, "a clock must not report playing during activation")
        ChartDock.toggleRecordingPlayback(player, beforePlay: {}, follow: {})
        XCTAssertFalse(player.playbackRequested)
        waiting?.resume()
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(starts, 0)
        XCTAssertEqual(releases, 1)
        XCTAssertFalse(player.isPlaying)
    }

    func testStopWhileRecordingSessionActivatesNeverSchedulesPlayback() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        try SoundSynth.wav(SoundSynth.render(.click), rate: SoundSynth.rate).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        var waiting: CheckedContinuation<Void, Error>?
        var starts = 0
        var releases = 0
        let player = RecordingPlayer(activateSession: {
            try await withCheckedThrowingContinuation { waiting = $0 }
        }, releaseSession: { _ in releases += 1 }, preparePlayback: { starts += 1 }, reserveSession: {})
        player.load(url)
        let request = player.play()
        for _ in 0..<100 where waiting == nil { await Task.yield() }
        XCTAssertNotNil(waiting)
        XCTAssertEqual(starts, 0)
        player.stop()
        waiting?.resume()
        let started = await request.value
        XCTAssertFalse(started)
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(starts, 0)
        XCTAssertEqual(releases, 1)
    }

    func testNewerRecordingPlayOwnsTheSessionAfterOlderActivationCompletes() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        try SoundSynth.wav(SoundSynth.render(.click), rate: SoundSynth.rate).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        var waiting: [CheckedContinuation<Void, Error>] = []
        var starts = 0
        var releases = 0
        let player = RecordingPlayer(activateSession: {
            try await withCheckedThrowingContinuation { waiting.append($0) }
        }, releaseSession: { _ in releases += 1 }, preparePlayback: { starts += 1 }, reserveSession: {})
        player.load(url)
        let first = player.play()
        for _ in 0..<100 where waiting.isEmpty { await Task.yield() }
        let newer = player.play(from: 0)
        for _ in 0..<100 where waiting.count < 2 { await Task.yield() }
        XCTAssertEqual(waiting.count, 2)
        guard waiting.count == 2 else {
            for continuation in waiting { continuation.resume() }
            _ = await first.value
            _ = await newer.value
            player.stop()
            return
        }
        let older = waiting.removeFirst()
        older.resume()
        let oldStarted = await first.value
        XCTAssertFalse(oldStarted)
        XCTAssertEqual(starts, 0)
        XCTAssertEqual(releases, 0, "the pending newer play still holds its session reservation")
        waiting.removeFirst().resume()
        let newStarted = await newer.value
        XCTAssertTrue(newStarted)
        XCTAssertEqual(starts, 1)
        XCTAssertTrue(player.isPlaying)
        player.stop()
        XCTAssertEqual(releases, 1)
    }

    func testCompletedRecordingReadinessCannotStartSyncAfterPause() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        try SoundSynth.wav(SoundSynth.render(.click), rate: SoundSynth.rate).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let player = RecordingPlayer(activateSession: {}, releaseSession: { _ in }, preparePlayback: {}, reserveSession: {})
        player.load(url)
        let request = player.play()
        _ = await request.value
        player.pause()
        var syncStarts = 0
        let dock = AudioStartGate()
        dock.begin(request) { syncStarts += 1 }
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(syncStarts, 0)
        XCTAssertFalse(player.playbackRequested)
    }

    func testPauseDuringPendingSeekPreservesTheRequestedTarget() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        try SoundSynth.wav(Array(repeating: Float(0), count: SoundSynth.rate * 2), rate: SoundSynth.rate).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        var activations = 0
        var waiting: CheckedContinuation<Void, Error>?
        let player = RecordingPlayer(activateSession: {
            activations += 1
            if activations == 2 { try await withCheckedThrowingContinuation { waiting = $0 } }
        }, releaseSession: { _ in }, preparePlayback: {}, reserveSession: {})
        player.load(url)
        _ = await player.play().value
        let seek = player.play(from: 1)
        for _ in 0..<100 where waiting == nil { await Task.yield() }
        player.pause()
        XCTAssertEqual(player.currentTime(), 1, accuracy: 0.001)
        waiting?.resume()
        let started = await seek.value
        XCTAssertFalse(started)
        XCTAssertFalse(player.isPlaying)
    }
}
