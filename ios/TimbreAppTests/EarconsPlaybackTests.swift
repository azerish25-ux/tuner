import XCTest
@testable import Timbre

@MainActor
final class EarconsPlaybackTests: XCTestCase {
    @MainActor
    private final class Preparation {
        var waiting: [CheckedContinuation<Void, Never>] = []
        var completed = false

        func prepare() async {
            await withCheckedContinuation { waiting.append($0) }
            completed = true
        }

        func finish() {
            let pending = waiting
            waiting.removeAll()
            for continuation in pending { continuation.resume() }
        }
    }

    private func waitForPreparation(_ preparation: Preparation, count: Int = 1) async {
        for _ in 0..<100 where preparation.waiting.count < count { await Task.yield() }
        XCTAssertEqual(preparation.waiting.count, count)
    }

    func testCachingNeverPreparesOrPlaysBeforeSessionPreparationCompletes() async {
        let preparation = Preparation()
        var preparedPlayers = 0
        var createdPlayers = 0
        let earcons = Earcons(prepareSession: { await preparation.prepare() }, soundsEnabled: { true }, now: { 0 },
                              makePlayback: { _ in
            createdPlayers += 1
            return {
                XCTAssertTrue(preparation.completed)
                preparedPlayers += 1
            }
        }, prepareVoice: {})
        earcons.prepare()
        XCTAssertEqual(createdPlayers, 2)
        XCTAssertEqual(preparedPlayers, 0, "cache creation must leave AVAudioPlayer unprepared")
        let request = earcons.play(hit: true)
        await waitForPreparation(preparation)
        XCTAssertEqual(preparedPlayers, 0)
        preparation.finish()
        let played = await request.value
        XCTAssertTrue(played)
        XCTAssertEqual(preparedPlayers, 1)
    }

    func testDisabledSoundIsRecheckedAfterSessionWait() async {
        let preparation = Preparation()
        var enabled = true
        var plays = 0
        let earcons = Earcons(prepareSession: { await preparation.prepare() }, soundsEnabled: { enabled }, now: { 0 },
                              makePlayback: { _ in { plays += 1 } }, prepareVoice: {})
        let request = earcons.lift()
        await waitForPreparation(preparation)
        enabled = false
        preparation.finish()
        let played = await request.value
        XCTAssertFalse(played)
        XCTAssertEqual(plays, 0)
    }

    func testNewerJudgmentSupersedesPendingNoteFeedback() async {
        let preparation = Preparation()
        var played: [Earcons.Cue] = []
        let earcons = Earcons(prepareSession: { await preparation.prepare() }, soundsEnabled: { true }, now: { 0 },
                              makePlayback: { cue in { played.append(cue) } }, prepareVoice: {})
        let old = earcons.play(hit: true)
        let newest = earcons.play(hit: false)
        await waitForPreparation(preparation, count: 2)
        preparation.finish()
        let oldPlayed = await old.value
        let newestPlayed = await newest.value
        XCTAssertFalse(oldPlayed)
        XCTAssertTrue(newestPlayed)
        XCTAssertEqual(played, [.thud])
    }

    func testLateFeedbackIsDiscardedInsteadOfSoundingAfterTheJudgment() async {
        let preparation = Preparation()
        var now = 0.0
        var plays = 0
        let earcons = Earcons(prepareSession: { await preparation.prepare() }, soundsEnabled: { true }, now: { now },
                              makePlayback: { _ in { plays += 1 } }, prepareVoice: {})
        let request = earcons.drop()
        await waitForPreparation(preparation)
        now = 0.5
        preparation.finish()
        let played = await request.value
        XCTAssertFalse(played)
        XCTAssertEqual(plays, 0)
    }

    func testTakeCancellationInvalidatesPendingFeedback() async {
        let preparation = Preparation()
        var plays = 0
        let earcons = Earcons(prepareSession: { await preparation.prepare() }, soundsEnabled: { true }, now: { 0 },
                              makePlayback: { _ in { plays += 1 } }, prepareVoice: {})
        let request = earcons.play(hit: true)
        await waitForPreparation(preparation)
        earcons.cancelPending()
        preparation.finish()
        let played = await request.value
        XCTAssertFalse(played)
        XCTAssertEqual(plays, 0)
    }

    func testCancelledRequestDoesNotPrepareOrPlayItsPlayer() async {
        let preparation = Preparation()
        var plays = 0
        let earcons = Earcons(prepareSession: { await preparation.prepare() }, soundsEnabled: { true }, now: { 0 },
                              makePlayback: { _ in { plays += 1 } }, prepareVoice: {})
        let request = earcons.drop()
        await waitForPreparation(preparation)
        request.cancel()
        preparation.finish()
        let played = await request.value
        XCTAssertFalse(played)
        XCTAssertEqual(plays, 0)
    }

    func testNoteAndTierFeedbackRemainIndependent() async {
        let preparation = Preparation()
        var played: [Earcons.Cue] = []
        let earcons = Earcons(prepareSession: { await preparation.prepare() }, soundsEnabled: { true }, now: { 0 },
                              makePlayback: { cue in { played.append(cue) } }, prepareVoice: {})
        let hit = earcons.play(hit: true)
        let lift = earcons.lift()
        await waitForPreparation(preparation, count: 2)
        preparation.finish()
        let hitPlayed = await hit.value
        let liftPlayed = await lift.value
        XCTAssertTrue(hitPlayed && liftPlayed)
        XCTAssertEqual(Set(played), Set([.tick, .rise]))
    }
}
