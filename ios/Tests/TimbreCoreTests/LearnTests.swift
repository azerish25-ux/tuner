import XCTest
@testable import TimbreCore

final class LearnTests: XCTestCase {
    private func note(_ midi: Int, _ beat: Double) -> TimedNote { TimedNote(midi: midi, beat: beat, beats: 1) }

    func testBundledCurriculumDecodesAndIsConsistent() throws {
        let curriculum = try Curriculum.bundled()
        XCTAssertFalse(curriculum.courses.isEmpty)
        let ids = curriculum.courses.flatMap(\.lessons).map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "lesson ids are unique")
        for course in curriculum.courses {
            XCTAssertTrue(course.units.first?.lessons.allSatisfy(\.free) ?? false, "\(course.id): first unit is free")
            for lesson in course.lessons { XCTAssertGreaterThanOrEqual(lesson.steps.count, 3, lesson.id) }
        }
        let first = try XCTUnwrap(curriculum.courses.first?.lessons.first)
        XCTAssertEqual(curriculum.lesson(id: first.id)?.lesson.id, first.id)
    }

    func testPlayAlongGradesTimingAndIntonation() {
        // 120 bpm: a beat is 0.5 s; latency 0 to keep the arithmetic plain.
        var judge = PlayAlongJudge(notes: [note(64, 0), note(65, 1), note(67, 2)], bpm: 120, latency: 0)
        XCTAssertEqual(judge.update(time: -0.5, midi: 64, cents: 0), [], "too early to count")
        XCTAssertEqual(judge.update(time: 0.03, midi: 64, cents: 5).first?.grade, .perfect)
        XCTAssertEqual(judge.update(time: 0.62, midi: 65, cents: 30).first?.grade, .good, "on time but 30 cents off is not perfect")
        // The third note is never played: it expires as a miss once its window closes.
        XCTAssertEqual(judge.update(time: 1.2, midi: nil, cents: nil), [])
        XCTAssertEqual(judge.update(time: 1.4, midi: nil, cents: nil).first?.grade, .miss)
        XCTAssertTrue(judge.isFinished)
        XCTAssertEqual(judge.accuracy, (1 + 0.8) / 3, accuracy: 1e-9)
        XCTAssertEqual(judge.bestCombo, 2)
        XCTAssertEqual(judge.combo, 0)
    }

    func testCombosCountOnlyPerfectAndGoodNotes() {
        // Six notes all played 0.2 s late: every one counts as late/early, so there is no combo at all.
        var late = PlayAlongJudge(notes: (0..<6).map { note(52 + $0, Double($0)) }, bpm: 60, latency: 0)
        for i in 0..<6 { _ = late.update(time: Double(i) + 0.2, midi: 52 + i, cents: 0, onset: true) }
        XCTAssertTrue(late.isFinished)
        XCTAssertTrue(late.judgments.allSatisfy { $0.grade == .ok })
        XCTAssertEqual(late.bestCombo, 0)
        XCTAssertEqual(late.combo, 0)

        // Perfect, good, late, perfect: the late note breaks the run of two.
        var mixed = PlayAlongJudge(notes: [note(60, 0), note(62, 1), note(64, 2), note(65, 3)], bpm: 60, latency: 0)
        XCTAssertEqual(mixed.update(time: 0.01, midi: 60, cents: 0).first?.grade, .perfect)
        XCTAssertEqual(mixed.update(time: 1.1, midi: 62, cents: 0).first?.grade, .good)
        XCTAssertEqual(mixed.combo, 2)
        XCTAssertEqual(mixed.update(time: 2.25, midi: 64, cents: 0).first?.grade, .ok)
        XCTAssertEqual(mixed.combo, 0)
        XCTAssertEqual(mixed.update(time: 3.0, midi: 65, cents: 0).first?.grade, .perfect)
        XCTAssertEqual(mixed.combo, 1)
        XCTAssertEqual(mixed.bestCombo, 2)
    }

    func testTempoLadderStepsUpAndCapsSlowFinishes() {
        var ladder = TempoLadder(bpm: 60)
        XCTAssertEqual(ladder.rung, TempoLadder.lessonRung, "starts at the lesson tempo")
        XCTAssertEqual(ladder.tempo, 60)
        XCTAssertNil(ladder.outcome)

        // An easier run: 75 %.
        ladder.select(0)
        XCTAssertEqual(ladder.tempo, 45)
        XCTAssertEqual(ladder.percent, 75)
        XCTAssertFalse(ladder.record(accuracy: 0.85), "under 90 % stays on the rung")
        XCTAssertEqual(ladder.outcome, TempoLadder.Outcome(score: 0.85, starCap: TempoLadder.slowStarCap))
        XCTAssertTrue(ladder.record(accuracy: 0.95))
        XCTAssertEqual(ladder.percent, 90)
        XCTAssertEqual(ladder.tempo, 54)
        XCTAssertTrue(ladder.improvesOutcome(0.96))
        XCTAssertTrue(ladder.record(accuracy: 0.96))
        XCTAssertEqual(ladder.rung, TempoLadder.lessonRung)
        XCTAssertEqual(ladder.outcome?.starCap, TempoLadder.slowStarCap, "nothing at full tempo yet")

        // Any take at the lesson tempo beats the slower ones, even a weaker one.
        XCTAssertTrue(ladder.improvesOutcome(0.7))
        XCTAssertFalse(ladder.record(accuracy: 0.7))
        XCTAssertEqual(ladder.outcome, TempoLadder.Outcome(score: 0.7, starCap: nil))
        XCTAssertTrue(ladder.record(accuracy: 0.92))
        XCTAssertEqual(ladder.percent, 110)
        XCTAssertEqual(ladder.tempo, 66)
        // A rough take at 110 % doesn't undo the full-tempo result; the top rung stays put.
        XCTAssertFalse(ladder.improvesOutcome(0.5))
        XCTAssertFalse(ladder.record(accuracy: 0.5))
        XCTAssertFalse(ladder.record(accuracy: 1))
        XCTAssertEqual(ladder.percent, 110)
        XCTAssertEqual(ladder.outcome, TempoLadder.Outcome(score: 1, starCap: nil))
    }

    func testRunHonoursAStarCapAndCollectsItems() {
        var run = LessonRun(lesson: lesson("a"), now: Date(timeIntervalSince1970: 0))
        let e = PracticeItem.note(midi: 64, at: Fretting(string: 1, fret: 0))
        let em = PracticeItem.chord(ChordSpec(name: "Em", root: 4, quality: "min", frets: [0, 2, 2, 0, 0, 0]))
        run.score(e, 1); run.score(e, 0.4); run.score(em, 0.6)
        run.complete(score: 1); run.complete(score: 1); run.complete(score: 0.95)
        run.capStars(TempoLadder.slowStarCap)
        let result = run.result(now: Date(timeIntervalSince1970: 60))
        XCTAssertEqual(result.stars, 2, "3 stars of accuracy, capped by a slow play-along")
        XCTAssertEqual(result.xp, 20)
        XCTAssertEqual(result.items.map(\.item), [em, e], "weakest first")
        XCTAssertEqual(result.items.last?.score ?? 0, 0.7, accuracy: 1e-9)
    }

    func testTapAlongCalibrationFindsTheHeardDelay() {
        let spb = 0.75, first = 100.0
        // A Bluetooth-like 210 ms with a little human scatter and one stray tap; the warm-up taps don't count.
        let jitter = [0.0, 0.012, -0.015, 0.02, -0.008, 0.005, 0.01, -0.012, 0.0, 0.018, -0.02]
        var taps = (0..<11).map { first + Double($0 + 2) * spb + 0.21 + jitter[$0] }
        taps += [first + 0.05, first + spb + 0.3, first + 7.5 * spb + 0.21]
        let estimate = try? XCTUnwrap(LatencyCalibration.estimate(taps: taps, firstClick: first, secondsPerBeat: spb))
        XCTAssertEqual(estimate ?? 0, 0.21, accuracy: 0.012)
        // On a speaker people tap a touch early: clamped at zero rather than negative.
        let early = (2..<12).map { first + Double($0) * spb - 0.03 }
        XCTAssertEqual(LatencyCalibration.estimate(taps: early, firstClick: first, secondsPerBeat: spb), 0)
        // Too few, or all over the place: no answer.
        XCTAssertNil(LatencyCalibration.estimate(taps: Array(taps.prefix(4)), firstClick: first, secondsPerBeat: spb))
        let scattered = (2..<12).map { first + Double($0) * spb + ($0 % 2 == 0 ? 0.0 : 0.35) }
        XCTAssertNil(LatencyCalibration.estimate(taps: scattered, firstClick: first, secondsPerBeat: spb))
    }

    func testWeakSpotsAreTrackedAndReviewed() throws {
        let em = ChordSpec(name: "Em", root: 4, quality: "min", frets: [0, 2, 2, 0, 0, 0], fingers: [0, 2, 3, 0, 0, 0])
        let c = ChordSpec(name: "C", root: 0, quality: "maj", frets: [-1, 3, 2, 0, 1, 0])
        let g3 = PracticeItem.note(midi: 55, at: Fretting(string: 3, fret: 0))
        let b3 = PracticeItem.note(midi: 59, at: Fretting(string: 2, fret: 0))
        let course = LearnCourse(id: "c", title: LearnText("C"), subtitle: LearnText("s"), instrument: "guitar.acoustic.6", symbol: "guitars.fill", accent: "mint",
                                 units: [LearnUnit(id: "u", title: LearnText("U"), summary: LearnText("s"), lessons: [lesson("a"), lesson("b"), lesson("c"), lesson("d")])])
        var progress = LearnProgress()
        func finish(_ id: String, _ items: [ItemScore], at time: Double) {
            progress.record(LessonResult(lessonId: id, stars: 2, accuracy: 0.8, xp: 20, minutes: 3, items: items), courseId: "c", now: Date(timeIntervalSince1970: time))
        }
        finish("a", [ItemScore(item: g3, score: 0.5), ItemScore(item: b3, score: 1)], at: 10)
        finish("b", [ItemScore(item: .chord(em), score: 0.6), ItemScore(item: g3, score: 0.7)], at: 20)
        XCTAssertFalse(progress.reviewDue(in: course), "two lessons: not yet")
        finish("c", [ItemScore(item: .chord(c), score: 0.3)], at: 30)
        XCTAssertTrue(progress.reviewDue(in: course))
        XCTAssertEqual(progress.weakSpots(in: course).map(\.item), [.chord(c), g3, .chord(em)], "weakest first, each once, played-well notes left out")
        XCTAssertTrue(progress.isValid)

        // The review: notes and chords from the usual steps, an intro first, the play-along through the notes.
        let text = ReviewText(title: LearnText("Review"), intro: LearnText("i"), notesHint: LearnText("h"), alongTitle: LearnText("t"))
        let review = try XCTUnwrap(WeakSpotReview.lesson(for: course, progress: progress, text: text, strings: 6, strums: true))
        XCTAssertEqual(review.kind, .review)
        XCTAssertTrue(LearnProgress.isReview(review.id))
        XCTAssertTrue((4...6).contains(review.steps.count), "\(review.steps.count) steps")
        guard case .explain(_, _, .fretboard(6, let dots, _, _))? = review.steps.first else { return XCTFail("intro shows the notes on the neck") }
        XCTAssertEqual(dots, [Fretting(string: 3, fret: 0)])
        XCTAssertTrue(review.steps.contains(.playChord(chord: c)))
        XCTAssertTrue(review.steps.contains(.playChord(chord: em)))
        XCTAssertTrue(review.steps.contains { if case .playAlong = $0 { return true } else { return false } })
        XCTAssertTrue(review.steps.contains { if case .progression = $0 { return true } else { return false } })
        XCTAssertNil(course.lessons.first { $0.id == review.id }, "never part of the path")

        // Finishing it clears what was played well and keeps no stars or place of its own.
        let starsBefore = progress.stars
        progress.record(LessonResult(lessonId: review.id, stars: 3, accuracy: 0.9, xp: 25, minutes: 4,
                                     items: [ItemScore(item: g3, score: 1), ItemScore(item: .chord(c), score: 0.5), ItemScore(item: .chord(em), score: 0.9)]),
                        courseId: "c", now: Date(timeIntervalSince1970: 40))
        XCTAssertEqual(progress.stars, starsBefore)
        XCTAssertEqual(progress.lastLessonId, "c")
        XCTAssertEqual(progress.weakSpots(in: course).map(\.item), [.chord(c)])
        XCTAssertEqual(progress.weakSpots(in: course).first?.score, 0.5)
        XCTAssertFalse(progress.reviewDue(in: course), "the count starts again")
        XCTAssertEqual(progress.nextLesson(in: course)?.id, "d", "unlock order untouched")

        // A replay of a lesson replaces what it found weak.
        finish("c", [ItemScore(item: .chord(c), score: 0.95)], at: 50)
        XCTAssertTrue(progress.weakSpots(in: course).isEmpty)
        XCTAssertNil(WeakSpotReview.lesson(for: course, progress: progress, text: text, strings: 6, strums: true))

        // Saves from before weak spots decode; weak spots round-trip.
        let old = try JSONDecoder().decode(LearnProgress.self, from: Data(#"{"stars":{"a":2},"bestAccuracy":{"a":0.8},"finishedDates":{},"placedThrough":{}}"#.utf8))
        XCTAssertTrue(old.weakSpots.isEmpty)
        XCTAssertTrue(old.sinceReview.isEmpty)
        finish("a", [ItemScore(item: g3, score: 0.4), ItemScore(item: .chord(em), score: 0.2)], at: 60)
        XCTAssertEqual(try JSONDecoder().decode(LearnProgress.self, from: JSONEncoder().encode(progress)), progress)
    }

    func testNotesOnlyReviewRepeatsTheNotes() throws {
        let spots = [55, 57, 59].map { WeakSpot(item: .note(midi: $0, at: nil), score: 0.5, seen: Date(timeIntervalSince1970: 0)) }
        let text = ReviewText(title: LearnText("Review"), intro: LearnText("i"), notesHint: LearnText("h"), alongTitle: LearnText("t"))
        let review = try XCTUnwrap(WeakSpotReview.lesson(courseId: "voice", spots: spots, text: text, strings: 0, strums: false))
        XCTAssertEqual(review.steps.count, 4)
        guard case .explain(_, _, .staff(let midi, "treble"))? = review.steps.first else { return XCTFail("a staff without a neck") }
        XCTAssertEqual(midi, [55, 57, 59])
        guard case .playAlong(let line, _, _, _)? = review.steps.first(where: { if case .playAlong = $0 { return true } else { return false } }) else { return XCTFail() }
        XCTAssertEqual(line.map(\.midi), [55, 57, 59, 57, 55])
        XCTAssertEqual(line.map(\.beat), [0, 2, 4, 6, 8])
    }

    func testRepeatedNoteNeedsAFreshAttack() {
        var judge = PlayAlongJudge(notes: [note(60, 0), note(60, 1)], bpm: 60, latency: 0)
        XCTAssertEqual(judge.update(time: 0, midi: 60, cents: 0).count, 1)
        // Still ringing into the second note's window: not a new hit.
        XCTAssertEqual(judge.update(time: 0.95, midi: 60, cents: 0), [])
        XCTAssertEqual(judge.update(time: 1.0, midi: 60, cents: 0, onset: true).first?.grade, .perfect)
    }

    func testVoiceAcceptsAnyOctave() {
        var judge = PlayAlongJudge(notes: [note(72, 0)], bpm: 90, latency: 0, anyOctave: true)
        XCTAssertEqual(judge.update(time: 0.05, midi: 60, cents: 0).first?.grade, .perfect)
    }

    func testNoteSequenceHoldsAndCountsWrongNotesOnce() {
        var judge = NoteSequenceJudge(notes: [64, 65], holdSeconds: 0.3)
        XCTAssertEqual(judge.update(time: 0, midi: 62, cents: 0), .wrong(62))
        XCTAssertNil(judge.update(time: 0.1, midi: 62, cents: 0), "the same wrong note counts once")
        XCTAssertEqual(judge.update(time: 0.2, midi: 64, cents: 10), .holding(0))
        XCTAssertEqual(judge.update(time: 0.55, midi: 64, cents: 10), .hit(0))
        XCTAssertEqual(judge.current, 65)
        XCTAssertNil(judge.update(time: 0.6, midi: 65, cents: 45), "outside the tolerance")
        _ = judge.update(time: 0.7, midi: 65, cents: 0)
        XCTAssertEqual(judge.update(time: 1.0, midi: 65, cents: 0), .hit(1))
        XCTAssertTrue(judge.isFinished)
        XCTAssertEqual(judge.accuracy, 2.0 / 3.0, accuracy: 1e-9)
    }

    private func lesson(_ id: String, steps: Int = 3) -> Lesson {
        Lesson(id: id, title: LearnText(id), kind: .lesson, minutes: 3, xp: 20, free: true,
               steps: Array(repeating: .quiz(prompt: LearnText("q"), options: [LearnText("a"), LearnText("b")], answer: 0, why: nil, visual: .none), count: steps))
    }

    func testRunScoresStarsAndXP() {
        var run = LessonRun(lesson: lesson("a"), now: Date(timeIntervalSince1970: 0))
        run.complete(score: 1); run.complete(score: nil); run.complete(score: 0.6)
        XCTAssertTrue(run.isFinished)
        let result = run.result(now: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(result.accuracy, 0.8, accuracy: 1e-9)
        XCTAssertEqual(result.stars, 2)
        XCTAssertEqual(result.xp, 20)
        XCTAssertEqual(result.minutes, 3)
    }

    func testLessonsUnlockInOrderAndKeepBestStars() {
        let course = LearnCourse(id: "c", title: LearnText("C"), subtitle: LearnText("s"), instrument: nil, symbol: "music.note", accent: "mint",
                                 units: [LearnUnit(id: "u", title: LearnText("U"), summary: LearnText("s"), lessons: [lesson("a"), lesson("b"), lesson("c")])])
        var progress = LearnProgress()
        XCTAssertTrue(progress.isUnlocked(course.lessons[0], in: course))
        XCTAssertFalse(progress.isUnlocked(course.lessons[1], in: course))
        XCTAssertTrue(progress.record(LessonResult(lessonId: "a", stars: 2, accuracy: 0.8, xp: 20, minutes: 3), courseId: "c"))
        XCTAssertTrue(progress.isUnlocked(course.lessons[1], in: course))
        XCTAssertFalse(progress.record(LessonResult(lessonId: "a", stars: 1, accuracy: 0.5, xp: 16, minutes: 3), courseId: "c"))
        XCTAssertEqual(progress.stars["a"], 2)
        XCTAssertEqual(progress.bestAccuracy["a"], 0.8)
        XCTAssertEqual(progress.nextLesson(in: course)?.id, "b")
        XCTAssertTrue(progress.isValid)
    }

    func testPlacementOpensEarlierUnitsWithoutFinishingThem() throws {
        func unit(_ id: String, _ lessons: [String]) -> LearnUnit { LearnUnit(id: id, title: LearnText(id), summary: LearnText("s"), lessons: lessons.map { lesson($0) }) }
        let course = LearnCourse(id: "c", title: LearnText("C"), subtitle: LearnText("s"), instrument: "guitar.acoustic.6", symbol: "guitars.fill", accent: "mint",
                                 units: [unit("u1", ["a", "b"]), unit("u2", ["c", "d"]), unit("u3", ["e"]), unit("u4", ["f", "g"])])
        func open(_ progress: LearnProgress) -> [String] { course.lessons.filter { progress.isUnlocked($0, in: course) }.map(\.id) }
        var progress = LearnProgress()

        progress.place(level: "beginner", in: course)
        XCTAssertTrue(progress.placedThrough.isEmpty)
        XCTAssertEqual(open(progress), ["a"])
        XCTAssertEqual(progress.nextLesson(in: course)?.id, "a")

        // A few years: unit 1 open, starting at the first lesson of unit 2.
        progress.place(level: "intermediate", in: course)
        XCTAssertEqual(progress.placedThrough["c"], 0)
        XCTAssertEqual(open(progress), ["a", "b", "c"])
        XCTAssertEqual(progress.nextLesson(in: course)?.id, "c")
        XCTAssertEqual(progress.finishedCount(in: course), 0, "placed lessons are not finished")
        XCTAssertTrue(progress.stars.isEmpty)

        // Many years or professional: units 1–3 open.
        progress.place(level: "pro", in: course)
        XCTAssertEqual(progress.placedThrough["c"], 2)
        XCTAssertEqual(open(progress), ["a", "b", "c", "d", "e", "f"])
        XCTAssertEqual(progress.nextLesson(in: course)?.id, "f")
        progress.record(LessonResult(lessonId: "f", stars: 3, accuracy: 1, xp: 20, minutes: 3), courseId: "c", now: Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(progress.nextLesson(in: course)?.id, "g")
        progress.record(LessonResult(lessonId: "g", stars: 3, accuracy: 1, xp: 20, minutes: 3), courseId: "c", now: Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(progress.nextLesson(in: course)?.id, "a", "placed lessons are still there to play")
        XCTAssertTrue(progress.isValid)

        // Always at least one unit ahead.
        XCTAssertEqual(LearnProgress.placementUnit(level: "advanced", unitCount: 3), 1)
        XCTAssertEqual(LearnProgress.placementUnit(level: "advanced", unitCount: 2), 0)
        XCTAssertNil(LearnProgress.placementUnit(level: "intermediate", unitCount: 1))

        // Saves from before placement still decode; placement round-trips.
        let old = try JSONDecoder().decode(LearnProgress.self, from: Data(#"{"stars":{"a":2},"bestAccuracy":{"a":0.8},"finishedDates":{}}"#.utf8))
        XCTAssertEqual(old.stars["a"], 2)
        XCTAssertTrue(old.placedThrough.isEmpty)
        XCTAssertEqual(try JSONDecoder().decode(LearnProgress.self, from: JSONEncoder().encode(progress)), progress)
    }

    func testLessonsEarnXPAndCountTowardQuestsAndBadges() {
        var state = ProgressState()
        let update = state.record(.lessonCompleted(stars: 3, xp: 25))
        XCTAssertEqual(update.xpGained, 25)
        XCTAssertTrue(update.achievementsEarned.contains { $0.id == "first_lesson" })
        XCTAssertEqual(state.stats["perfectLessons"], 1)
    }

    func testStepsRoundTripThroughJSON() throws {
        let steps: [LessonStep] = [
            .explain(title: LearnText(key: "k", "T"), body: LearnText("B"), visual: .fretboard(strings: 6, dots: [Fretting(string: 1, fret: 3, finger: 3)], frets: 5, start: 1)),
            .progression(chords: [ChordSpec(name: "G", root: 7, quality: "maj", frets: [3, 2, 0, 0, 0, 3]), ChordSpec(name: "C", root: 0, quality: "maj", frets: [-1, 3, 2, 0, 1, 0])], bars: [2, 2], pattern: [0, 1, 2, 3], bpm: 70, beatsPerBar: nil),
            .playAlong(notes: [TimedNote(midi: 64, beat: 0, beats: 1, at: Fretting(string: 1, fret: 0))], bpm: 80, beatsPerBar: 4, title: nil),
            .strum(chord: ChordSpec(name: "Em", root: 4, quality: "min", frets: [0, 2, 2, 0, 0, 0], fingers: nil, baseFret: nil), pattern: [0, 1, 2, 3], bpm: 60, bars: 2, beatsPerBar: nil),
            .tapRhythm(pattern: [0, 1, 2], bpm: 90, bars: 2, beatsPerBar: 3),
            .listen(prompt: LearnText("Which?"), sound: [[60], [64, 67]], options: [LearnText("a"), LearnText("b")], answer: 1),
        ]
        let data = try JSONEncoder().encode(steps)
        XCTAssertEqual(try JSONDecoder().decode([LessonStep].self, from: data), steps)
    }
}
