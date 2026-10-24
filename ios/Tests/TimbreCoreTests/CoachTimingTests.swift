import XCTest
@testable import TimbreCore

final class CoachTimingTests: XCTestCase {
    private let em = ChordSpec(name: "Em", root: 4, quality: "min", frets: [0, 2, 2, 0, 0, 0])
    private let c = ChordSpec(name: "C", root: 0, quality: "maj", frets: [-1, 3, 2, 0, 1, 0])

    /// Em, C, Em, C, a bar each, four strokes a bar at 60 BPM: strokes 4 and 12 are the changes into C.
    private func progression(offsets: [Int: Double], strays: [Int: Double] = [:]) -> CoachTake? {
        CoachTake.strummed(chords: [em, c, em, c], bars: [1, 1, 1, 1], pattern: [0, 1, 2, 3], beatsPerBar: 4, bpm: 60,
                           offsets: offsets, strays: strays)
    }

    private func onTime(except changed: [Int: Double], steady: Double = 0.02) -> [Int: Double] {
        var offsets: [Int: Double] = [:]
        for stroke in 0..<16 { offsets[stroke] = changed[stroke] ?? steady }
        return offsets
    }

    private func melody(_ offsets: [Double?]) -> CoachTake {
        let hits = offsets.enumerated().map { index, offset in CoachHit(item: .note(midi: 60 + index * 2, at: nil), beat: Double(index), offset: offset) }
        return CoachTake(kind: .melody, hits: hits, bpm: 80, beatsPerBar: 4)
    }

    func testStrummedTakeMapsStrokesToChordsAndBeats() throws {
        let take = try XCTUnwrap(CoachTake.strummed(chords: [em, c], bars: [1, 1], pattern: [0, 1, 2, 3], beatsPerBar: 4, bpm: 60,
                                                    offsets: [0: 0.01, 4: 0.2], strays: [5: 0.4]))
        XCTAssertEqual(take.kind, .chords)
        XCTAssertEqual(take.hits.count, 8)
        XCTAssertEqual(take.hits[3].item, .chord(em))
        XCTAssertEqual(take.hits[4].item, .chord(c))
        XCTAssertEqual(take.hits[4].beat, 4)
        XCTAssertEqual(take.hits[4].offset, 0.2)
        XCTAssertEqual(take.hits[5].offset, 0.4, "a missed stroke keeps the stroke heard outside its window")
        XCTAssertNil(take.hits[6].offset)
        XCTAssertNil(CoachTake.strummed(chords: [], bars: [], pattern: [0], beatsPerBar: 4, bpm: 60, offsets: [:]))
        XCTAssertNil(CoachTake.strummed(chords: [em], bars: [2], pattern: [], beatsPerBar: 4, bpm: 60, offsets: [:]))
    }

    func testPlayAlongTakeKeepsEachJudgedNoteAndItsTiming() {
        var judge = PlayAlongJudge(notes: [TimedNote(midi: 60, beat: 0, beats: 1), TimedNote(midi: 62, beat: 1, beats: 1), TimedNote(midi: 64, beat: 2, beats: 1)],
                                   bpm: 120, latency: 0)
        _ = judge.update(time: 0.01, midi: 60, cents: 0)
        _ = judge.update(time: 0.53, midi: 62, cents: 0)
        _ = judge.update(time: 1.4, midi: nil, cents: nil)
        let take = CoachTake(judge: judge, beatsPerBar: 4) { .note(midi: $0.midi, at: nil) }
        XCTAssertEqual(take.kind, .melody)
        XCTAssertEqual(take.bpm, 120, accuracy: 1e-9)
        XCTAssertEqual(take.hits.map(\.item), [.note(midi: 60, at: nil), .note(midi: 62, at: nil), .note(midi: 64, at: nil)])
        XCTAssertEqual(take.hits[0].offset ?? -1, 0.01, accuracy: 1e-9)
        XCTAssertEqual(take.hits[1].offset ?? -1, 0.03, accuracy: 1e-9)
        XCTAssertNil(take.hits[2].offset, "a miss has no timing")
    }

    func testTheLateChangeIntoCStandsOut() throws {
        // Every stroke on time, except the change into C: 410 ms late both times (heard outside the window).
        var offsets = onTime(except: [8: 0.03])
        offsets[4] = nil
        offsets[12] = nil
        let take = try XCTUnwrap(progression(offsets: offsets, strays: [4: 0.41, 12: 0.41]))
        let change = try XCTUnwrap(Coach.worstChange(in: [take]))
        XCTAssertEqual(change.from, .chord(em))
        XCTAssertEqual(change.to, .chord(c))
        XCTAssertEqual(change.meanOffset ?? 0, 0.41, accuracy: 1e-9)
        XCTAssertEqual(change.count, 2)
        XCTAssertEqual(change.missed, 0)
        XCTAssertEqual(change.beat, 1, "a change at the top of the bar lands on beat 1")
        XCTAssertEqual(change.bpm, 60)
    }

    func testChangesNeverHeardStillCount() throws {
        var offsets = onTime(except: [:])
        offsets[4] = nil
        offsets[12] = nil
        let take = try XCTUnwrap(progression(offsets: offsets))
        let change = try XCTUnwrap(Coach.worstChange(in: [take]))
        XCTAssertEqual(change.to, .chord(c))
        XCTAssertNil(change.meanOffset)
        XCTAssertEqual(change.missed, 2)
        XCTAssertEqual(change.cost, Coach.missCost, accuracy: 1e-9)
    }

    func testAnEvenlyLateTakeIsNotAChangeProblem() throws {
        let take = try XCTUnwrap(progression(offsets: onTime(except: [:], steady: 0.15)))
        XCTAssertNil(Coach.worstChange(in: [take]), "the changes are no later than everything else")
        let clean = try XCTUnwrap(progression(offsets: onTime(except: [:])))
        XCTAssertNil(Coach.worstChange(in: [clean]))
    }

    func testOneSlightlyLateNoteInAMelodyIsNoise() {
        XCTAssertNil(Coach.worstChange(in: [melody([0, 0, 0.15, 0])]))
        // Twice in a row it is a pattern: two takes, the same move late each time.
        let found = Coach.worstChange(in: [melody([0, 0, 0.15, 0]), melody([0, 0, 0.17, 0])])
        XCTAssertEqual(found?.from, .note(midi: 62, at: nil))
        XCTAssertEqual(found?.to, .note(midi: 64, at: nil))
        XCTAssertEqual(found?.count, 2)
        XCTAssertEqual(found?.beat, 3)
        // One clear miss is enough.
        XCTAssertEqual(Coach.worstChange(in: [melody([0, 0, nil, 0])])?.missed, 1)
    }

    func testLeanNeedsSixNotesAndSomeSpread() throws {
        let leaning = melody([0.08, 0.14, 0.08, 0.14, 0.08, 0.14, 0.08, 0.14])
        let lean = try XCTUnwrap(Coach.lean(in: [leaning]))
        XCTAssertEqual(lean.offset, 0.11, accuracy: 1e-9)
        XCTAssertEqual(lean.notes, 8)
        XCTAssertEqual(lean.bpm, 80)
        XCTAssertNil(Coach.lean(in: [melody(Array(repeating: 0.12, count: 8))]), "a steady delay is the audio route, not the player")
        XCTAssertNil(Coach.lean(in: [melody([0.08, 0.14, 0.08, 0.14, 0.08])]), "too few notes")
        XCTAssertNil(Coach.lean(in: [melody([0.0, 0.04, -0.02, 0.03, 0.01, 0.02, 0.0])]), "on the click")
    }

    func testBeatsInTheBar() {
        XCTAssertEqual(Coach.beatInBar(0, 4), 1)
        XCTAssertEqual(Coach.beatInBar(6.5, 4), 3, "the and of 3")
        XCTAssertEqual(Coach.beatInBar(11, 4), 4)
        XCTAssertEqual(Coach.beatInBar(3, 3), 1)
    }

    func testLoopTempoIsARungDownOnAMultipleOfFive() {
        XCTAssertEqual(Coach.loopTempo(60), 45)
        XCTAssertEqual(Coach.loopTempo(120), 90)
        XCTAssertEqual(Coach.loopTempo(90), 70)
        XCTAssertEqual(Coach.loopTempo(48), 40, "never below 40")
        XCTAssertEqual(Coach.loopTempo(40), 40)
        XCTAssertEqual(Coach.loopTempo(0), 40)
        XCTAssertEqual(Coach.milliseconds(0.413), 410)
        XCTAssertEqual(Coach.milliseconds(-0.126), -130)
    }
}
