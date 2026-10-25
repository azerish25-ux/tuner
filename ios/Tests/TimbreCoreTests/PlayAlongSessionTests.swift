import XCTest
@testable import TimbreCore

/// One play-along take (TimbreCore/Learn/PlayAlongSession.swift): its clock and count-in, the score with the combo
/// multiplier, what each reading reports for the host (a tier reached, a run broken, the end), each section's score
/// and when the spoken cues name a note.
final class PlayAlongSessionTests: XCTestCase {
    /// `count` notes a beat apart at 60 BPM in 4/4 (a second a beat, a four-second count-in).
    private func session(_ count: Int, keepsTrail: Bool = false) -> PlayAlongSession {
        let notes = (0..<count).map { TimedNote(midi: 60 + $0 % 5, beat: Double($0), beats: 1) }
        return PlayAlongSession(notes: notes, bpm: 60, beatsPerBar: 4, keepsTrail: keepsTrail)
    }

    /// Plays note `index` with a fresh attack, `late` seconds after it is due.
    @discardableResult
    private func play(_ take: inout PlayAlongSession, _ index: Int, late: Double = 0) -> PlayAlongSession.Update {
        let now = take.startTime + take.countIn + take.judge.time(of: index) + late
        take.onset(at: now)
        return take.hear(midi: take.notes[index].midi, cents: 0, level: -20, at: now)
    }

    func testTheClockCountsInABarBeforeBeatZero() {
        var take = session(4)
        take.begin(at: 100)
        XCTAssertEqual(take.countIn, 4, accuracy: 1e-9)
        XCTAssertEqual(take.clock(at: 104), 0, accuracy: 1e-9)
        XCTAssertEqual(take.countInBeat(at: 100), 0)
        XCTAssertEqual(take.countInBeat(at: 102.5), 2)
        XCTAssertNil(take.countInBeat(at: 104.1), "the count-in is over")
        XCTAssertNil(take.countInBeat(at: 99), "not started")
        take.follow(start: 100.05)
        XCTAssertEqual(take.clock(at: 104.05), 0, accuracy: 1e-9, "the clock follows the click as it was heard")
        take.skip(8)
        XCTAssertEqual(take.clock(at: 104.05), 8, accuracy: 1e-9)
    }

    func testTheMultiplierStepsUpAndScoresEachNote() {
        var take = session(16)
        take.begin(at: 10)
        var tiers: [Int] = []
        var last = PlayAlongSession.Update()
        for index in 0..<16 {
            last = play(&take, index)
            XCTAssertEqual(last.judgments.map(\.grade), [.perfect])
            if let tier = last.tier { tiers.append(tier) }
        }
        XCTAssertEqual(tiers, [2, 3, 4], "×2 at four in a row, ×3 at eight, ×4 at sixteen")
        // 3 notes at ×1, 4 at ×2, 8 at ×3 and the sixteenth at ×4.
        XCTAssertEqual(take.points, 300 + 800 + 2400 + 400)
        XCTAssertTrue(last.finished)
        XCTAssertTrue(take.finished)
        XCTAssertEqual(take.hits, 16)
        XCTAssertEqual(take.count(.perfect), 16)
        XCTAssertEqual(take.accuracy, 1, accuracy: 1e-9)
        XCTAssertNotNil(take.tierUp)
        XCTAssertTrue(take.tick(at: 1000).isEmpty, "nothing more once the take is over")
    }

    func testABrokenRunOfFourOrMoreIsReported() {
        var take = session(10)
        take.begin(at: 0)
        for index in 0..<5 { play(&take, index) }
        XCTAssertEqual(take.combo, 5)
        // Note 5 is never played: its window closes a third of a second after it is due.
        let missed = take.tick(at: take.startTime + take.countIn + take.judge.time(of: 5) + 0.4)
        XCTAssertEqual(missed.judgments.map(\.grade), [.miss])
        XCTAssertEqual(missed.brokenRun, 5)
        XCTAssertEqual(take.combo, 0)
        // A short run breaking is not worth a sound.
        play(&take, 6)
        play(&take, 7)
        let early = play(&take, 8, late: -0.18)
        XCTAssertEqual(early.judgments.map(\.grade), [.ok])
        XCTAssertNil(early.brokenRun)
    }

    func testAnUnplayedTakeEndsOnItsOwn() {
        var take = session(2)
        take.begin(at: 0)
        XCTAssertTrue(take.tick(at: 1).isEmpty, "the count-in")
        let end = take.tick(at: take.countIn + take.judge.duration + PlayAlongSession.tail + 0.1)
        XCTAssertEqual(end.judgments.map(\.grade), [.miss, .miss])
        XCTAssertTrue(end.finished)
        XCTAssertEqual(take.accuracy, 0, accuracy: 1e-9)
    }

    func testEachSectionScoresItsOwnNotes() {
        var take = session(8)
        take.begin(at: 0)
        for index in 0..<4 { play(&take, index) }
        _ = take.tick(at: take.countIn + take.judge.duration + PlayAlongSession.tail + 0.1)
        XCTAssertEqual(take.score(fromBeat: 0, toBeat: 4) ?? -1, 1, accuracy: 1e-9)
        XCTAssertEqual(take.score(fromBeat: 4, toBeat: 8) ?? -1, 0, accuracy: 1e-9)
        XCTAssertEqual(take.score(fromBeat: 2, toBeat: 6) ?? -1, 0.5, accuracy: 1e-9)
        XCTAssertNil(take.score(fromBeat: 8, toBeat: 12), "no notes there")
    }

    func testCuesNameEachNoteABeatAheadOnce() {
        var take = session(8)
        take.begin(at: 100)
        XCTAssertNil(take.cue(at: 100, lead: 1), "too early in the count-in")
        // Note 0 is due at 0.08 s on the take's clock: named from a beat before.
        XCTAssertEqual(take.cue(at: 103.1, lead: 1), 0)
        XCTAssertNil(take.cue(at: 103.2, lead: 1), "each note once")
        XCTAssertEqual(take.cue(at: 104.1, lead: 1), 1)
        // Fallen behind (a stalled frame): the note coming up is named, not the ones already passing.
        XCTAssertEqual(take.cue(at: 107.1, lead: 1), 4)
        XCTAssertEqual(take.cue(at: 108.1, lead: 1), 5)
    }

    func testOnlyPitchLanesKeepATrail() {
        var lanes = session(2, keepsTrail: true)
        lanes.begin(at: 0)
        _ = lanes.hear(midi: 61, cents: 12, level: -30, at: 1)
        XCTAssertEqual(lanes.trail.count, 1)
        XCTAssertEqual(lanes.trail.first?.1 ?? 0, 61.12, accuracy: 1e-9)
        var strings = session(2)
        strings.begin(at: 0)
        _ = strings.hear(midi: 61, cents: 12, level: -30, at: 1)
        XCTAssertTrue(strings.trail.isEmpty)
    }

    func testANewTakeStartsClean() {
        var take = session(4)
        take.begin(at: 0)
        for index in 0..<4 { play(&take, index) }
        XCTAssertTrue(take.finished)
        take.begin(at: 50)
        XCTAssertFalse(take.finished)
        XCTAssertEqual(take.points, 0)
        XCTAssertTrue(take.grades.isEmpty)
        XCTAssertEqual(take.nextIndex, 0)
        XCTAssertEqual(take.cue(at: 53.1, lead: 1), 0, "the cues start again too")
    }

    func testTheMultiplierSteps() {
        XCTAssertEqual([0, 3, 4, 7, 8, 15, 16, 40].map(PlayAlongSession.multiplier), [1, 1, 2, 2, 3, 3, 4, 4])
    }
}
