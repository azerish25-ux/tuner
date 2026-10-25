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

    /// "The open strings": four steps played clean, then a 50 % "Keep going" play-along. The average is 90 %, but the
    /// lesson can't read better than its test: two stars, never "Great work" with three.
    func testTheFinalPlayAlongGatesTheStars() {
        let quiz = LessonStep.quiz(prompt: LearnText("q"), options: [LearnText("a"), LearnText("b")], answer: 0, why: nil, visual: .none)
        let along = LessonStep.playAlong(notes: [note(40, 0), note(45, 1)], bpm: 60, beatsPerBar: 4, title: nil)
        let lesson = Lesson(id: "g-1-2", title: LearnText("g"), kind: .lesson, minutes: 3, xp: 20, free: true, steps: [quiz, quiz, quiz, quiz, along])
        func finish(along score: Double) -> LessonResult {
            var run = LessonRun(lesson: lesson, now: Date(timeIntervalSince1970: 0))
            XCTAssertEqual(run.finalAlongIndex, 4)
            for _ in 0..<4 { run.complete(score: 1) }
            XCTAssertNil(run.finalTake, "not played yet")
            run.complete(score: score)
            return run.result(now: Date(timeIntervalSince1970: 120))
        }

        let keepGoing = finish(along: 0.5)
        XCTAssertEqual(keepGoing.accuracy, 0.9, accuracy: 1e-9)
        XCTAssertEqual(keepGoing.stars, 2, "a Keep going take holds the lesson at two stars")
        XCTAssertEqual(keepGoing.finalTake, 0.5)
        XCTAssertEqual(keepGoing.xp, 20)
        XCTAssertFalse(Coach.isFlawless(keepGoing))

        // Just warming up (under 50 %): one star, though the average alone would give two.
        let warmUp = finish(along: 0.3)
        XCTAssertEqual(warmUp.accuracy, 0.86, accuracy: 1e-9)
        XCTAssertEqual(warmUp.stars, 1)

        // A Great work take (90 %, as its card rounds it) leaves the stars to the average.
        XCTAssertEqual(finish(along: 0.896).stars, 3)
        XCTAssertEqual(finish(along: 0.884).stars, 2)
        XCTAssertEqual(finish(along: 1).stars, 3)

        XCTAssertEqual(LessonRun.starCap(finalTake: 0.9), 3)
        XCTAssertEqual(LessonRun.starCap(finalTake: 0.5), 2)
        XCTAssertEqual(LessonRun.starCap(finalTake: 0.49), 1)

        // The last play-along is the test even when a question follows it; a lesson without one has no gate.
        var trailing = LessonRun(lesson: Lesson(id: "t", title: LearnText("t"), kind: .lesson, minutes: 3, xp: 20, free: true, steps: [along, quiz]))
        trailing.complete(score: 0.6); trailing.complete(score: 1)
        XCTAssertEqual(trailing.result().stars, 2)
        var plain = LessonRun(lesson: self.lesson("p"))
        plain.complete(score: 1); plain.complete(score: 1); plain.complete(score: 0.9)
        XCTAssertNil(plain.finalAlongIndex)
        XCTAssertNil(plain.result().finalTake)
        XCTAssertEqual(plain.result().stars, 3)
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

        // Professional, in a course without its own starts: 80 % of the way in, so units 1–2 open.
        progress.place(level: "pro", in: course)
        XCTAssertEqual(progress.placedThrough["c"], 1)
        XCTAssertEqual(open(progress), ["a", "b", "c", "d", "e"])
        XCTAssertEqual(progress.nextLesson(in: course)?.id, "e")
        progress.record(LessonResult(lessonId: "e", stars: 3, accuracy: 1, xp: 20, minutes: 3), courseId: "c", now: Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(progress.nextLesson(in: course)?.id, "f")
        progress.record(LessonResult(lessonId: "f", stars: 3, accuracy: 1, xp: 20, minutes: 3), courseId: "c", now: Date(timeIntervalSince1970: 2_000))
        progress.record(LessonResult(lessonId: "g", stars: 3, accuracy: 1, xp: 20, minutes: 3), courseId: "c", now: Date(timeIntervalSince1970: 3_000))
        XCTAssertEqual(progress.nextLesson(in: course)?.id, "a", "placed lessons are still there to play")
        XCTAssertTrue(progress.isValid)

        // By share, always at least one unit ahead (courses with their own starts: PlacementTests).
        XCTAssertEqual(LearnProgress.placementUnit(level: "advanced", unitCount: 3), 0)
        XCTAssertEqual(LearnProgress.placementUnit(level: "pro", unitCount: 3), 1)
        XCTAssertEqual(LearnProgress.placementUnit(level: "pro", unitCount: 2), 0)
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

    /// Muted and accented beats on strum and progression steps round-trip; a step written without them reads as
    /// having none, and a plain step encodes without the keys.
    func testMutedAndAccentedBeatsDecode() throws {
        let c = ChordSpec(name: "C", root: 0, quality: "maj", frets: [-1, 3, 2, 0, 1, 0])
        let chunk = LessonStep.strum(chord: c, pattern: [0, 1, 2, 2.5, 3], bpm: 80, bars: 2, beatsPerBar: nil, muted: [1, 3], accents: [2.5])
        let chop = LessonStep.progression(chords: [c], bars: [2], pattern: [1, 3], bpm: 90, beatsPerBar: 4, muted: [1, 3])
        XCTAssertEqual(try JSONDecoder().decode([LessonStep].self, from: JSONEncoder().encode([chunk, chop])), [chunk, chop])
        XCTAssertEqual(chunk.muted, [1, 3])
        XCTAssertEqual(chunk.accents, [2.5])
        XCTAssertEqual(chop.muted, [1, 3])
        XCTAssertEqual(chop.accents, [])

        let old = Data(#"{"type":"strum","pattern":[0,1,2,3],"bpm":70,"bars":2}"#.utf8)
        let plain = try JSONDecoder().decode(LessonStep.self, from: old)
        XCTAssertEqual(plain, .strum(chord: nil, pattern: [0, 1, 2, 3], bpm: 70, bars: 2, beatsPerBar: nil))
        XCTAssertEqual(plain.muted, [])
        let written = try XCTUnwrap(String(data: JSONEncoder().encode(plain), encoding: .utf8))
        XCTAssertFalse(written.contains("muted"))
        XCTAssertFalse(written.contains("accents"))
        XCTAssertEqual(LessonStep.tapRhythm(pattern: [0, 1], bpm: 60, bars: 1, beatsPerBar: nil).muted, [])
    }

    /// A shape played behind a capo, and a technique clip: both round-trip, and older data without them still reads.
    func testCapoAndClipDecode() throws {
        let capoA = ChordSpec(name: "A", root: 9, quality: "maj", frets: [5, 4, 2, 2, 2, 5], fingers: [2, 1, 0, 0, 0, 3], capo: 2)
        let steps: [LessonStep] = [
            .playChord(chord: capoA),
            .explain(title: LearnText("Hold the bow"), body: LearnText("Soft and round."), visual: .clip(name: "bow_hold")),
        ]
        XCTAssertEqual(try JSONDecoder().decode([LessonStep].self, from: JSONEncoder().encode(steps)), steps)

        let written = Data(#"{"type":"explain","title":{"k":"","t":"Hold the bow"},"body":{"k":"","t":"Soft."},"visual":{"type":"clip","name":"bow_hold"}}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(LessonStep.self, from: written),
                       .explain(title: LearnText("Hold the bow"), body: LearnText("Soft."), visual: .clip(name: "bow_hold")))
        let chord = try JSONDecoder().decode(ChordSpec.self, from: Data(#"{"name":"G","root":7,"quality":"maj","frets":[3,2,0,0,0,3]}"#.utf8))
        XCTAssertNil(chord.capo)
        let capo = try JSONDecoder().decode(ChordSpec.self, from: Data(#"{"name":"A","root":9,"quality":"maj","frets":[5,4,2,2,2,5],"capo":2}"#.utf8))
        XCTAssertEqual(capo.capo, 2)
    }

    // MARK: Strummed takes, stroke by stroke

    /// How a stroke sounded: the chord it rang (nil: none), whether it had stopped 150 ms on, and how loud.
    private struct Sounded {
        var chord: ChordTarget?
        var stopped = false
        var db = -20.0
    }

    /// `sound` as `StrokeChords` reads it: the chord's notes evenly, its root lowest.
    private func reading(_ sound: Sounded) -> StrokeChords.Stroke {
        let attack = pow(10, sound.db / 20)
        let chord = sound.chord.map { target -> ChordEstimate in
            var chroma = [Double](repeating: 0, count: 12)
            for pitchClass in target.pitchClasses { chroma[pitchClass] = 1 / Double(target.pitchClasses.count).squareRoot() }
            return ChordEstimate(root: target.root, quality: target.quality, confidence: 1, chroma: chroma, bass: target.root)
        }
        return StrokeChords.Stroke(time: 0, chord: chord, attack: attack, ring: attack * (sound.stopped ? 0.05 : 0.7))
    }

    /// Plays every stroke of `take` on its beat (`late` seconds after it), each sounding as `sound` says, read a
    /// moment later as a rhythm step reads it; then the take ends.
    private func play(_ take: inout StrumTake, late: (Int) -> Double = { _ in 0 }, _ sound: (Int) -> Sounded) {
        for (index, due) in take.expected.enumerated() {
            let at = due + late(index)
            take.heard(at: at, stamp: 1000 + at)
            take.read(reading(sound(index)), stamp: 1000 + at)
        }
        take.finish()
    }

    /// uke-8-1 "The chunk": C on 1, 2, 3, the and of 3 and 4, beats 2 and 4 chunked. Played right, the take scores
    /// 100 %: every chunk stopped, every strum rang C. Judged as plain strokes (no muted beats) the same take missed
    /// every chunk and scored 60 %.
    func testACorrectChunkTakeScoresFullMarks() throws {
        let c = try XCTUnwrap(ChordTarget(root: 0, formulaId: "maj"))
        let pattern: [Double] = [0, 1, 2, 2.5, 3]
        func played(_ index: Int) -> Sounded {
            [1.0, 3.0].contains(pattern[index % pattern.count]) ? Sounded(chord: nil, stopped: true) : Sounded(chord: c)
        }
        var take = StrumTake(pattern: pattern, bars: 2, bpm: 63, muted: [1, 3], chords: [c])
        play(&take, played)
        XCTAssertEqual(take.score, 1, accuracy: 1e-9)
        XCTAssertTrue(take.calls.isEmpty, "\(take.calls)")
        XCTAssertEqual(take.mutedStopped.stopped, 4)
        XCTAssertEqual(take.mutedStopped.of, 4)
        XCTAssertEqual(take.chordRight.count, 6, "muted strokes count for no chord")
        XCTAssertTrue(take.chordRight.values.allSatisfy { $0 })
        XCTAssertFalse(take.chordsMostlyWrong)

        // A chunk the reader caught ringing C in its first instants, stopped by 150 ms, is a chunk all the same.
        var choked = StrumTake(pattern: pattern, bars: 2, bpm: 63, muted: [1, 3], chords: [c])
        play(&choked) { index in [1.0, 3.0].contains(pattern[index % pattern.count]) ? Sounded(chord: c, stopped: true) : Sounded(chord: c) }
        XCTAssertEqual(choked.score, 1, accuracy: 1e-9)

        var unmarked = StrumTake(pattern: pattern, bars: 2, bpm: 63, chords: [c])
        play(&unmarked, played)
        XCTAssertEqual(unmarked.score, 0.6, accuracy: 1e-9)
        XCTAssertEqual(unmarked.calls.values.filter { $0 == .noChord }.count, 4)
    }

    /// A chop left ringing is held to OK and called; the lesson's chords don't count it against them.
    func testAChopLeftRingingIsCalled() throws {
        let a = try XCTUnwrap(ChordTarget(root: 9, formulaId: "maj"))
        var take = StrumTake(pattern: [1, 3], bars: 2, bpm: 66, muted: [1, 3], chords: [a])
        play(&take) { _ in Sounded(chord: a, stopped: false) }
        XCTAssertEqual(take.calls.values.filter { $0 == .ringing }.count, 4)
        XCTAssertTrue(take.grades.values.allSatisfy { $0 == .ok })
        XCTAssertEqual(take.score, 0.5, accuracy: 1e-9)
        XCTAssertEqual(take.mutedStopped.stopped, 0)
        XCTAssertTrue(take.chordRight.isEmpty)
        XCTAssertFalse(take.chordsMostlyWrong)
    }

    /// man-4-4 "The chop" (every stroke a chop on 2 and 4): played right, the lesson earns three stars. Judged without
    /// its muted beats, the same playing scored nothing on its strums and kept the lesson to one star.
    func testACorrectChopLessonEarnsThreeStars() throws {
        let found = try XCTUnwrap(try Curriculum.bundled().lesson(id: "man-4-4")?.lesson)
        let marked = Self.marking(found, muted: [1, 3])
        XCTAssertEqual(stars(marked), 3)
        XCTAssertEqual(stars(Self.marking(found, muted: [])), 1)
    }

    /// `lesson` with `muted` beats (those its pattern plays) on every strum and progression step, and no others.
    private static func marking(_ lesson: Lesson, muted: [Double]) -> Lesson {
        let steps = lesson.steps.map { step -> LessonStep in
            switch step {
            case let .strum(chord, pattern, bpm, bars, meter, _, accents):
                return .strum(chord: chord, pattern: pattern, bpm: bpm, bars: bars, beatsPerBar: meter,
                              muted: muted.filter { pattern.contains($0) }, accents: accents)
            case let .progression(chords, bars, pattern, bpm, meter, _, accents):
                return .progression(chords: chords, bars: bars, pattern: pattern, bpm: bpm, beatsPerBar: meter,
                                    muted: muted.filter { pattern.contains($0) }, accents: accents)
            default:
                return step
            }
        }
        return Lesson(id: lesson.id, title: lesson.title, kind: lesson.kind, minutes: lesson.minutes, xp: lesson.xp, free: lesson.free,
                      steps: steps)
    }

    /// The stars `lesson` earns played right throughout: every question answered, every note and chord heard, and
    /// every strum on the beat with its chord, each chop (a beat of the pattern on 2 and 4) choked with no chord.
    private func stars(_ lesson: Lesson) -> Int {
        var run = LessonRun(lesson: lesson, now: Date(timeIntervalSince1970: 0))
        for step in lesson.steps {
            switch step {
            case .explain:
                run.complete(score: nil)
            case let .strum(chord, pattern, bpm, bars, meter, muted, accents):
                let target = chord.flatMap { ChordTarget(root: $0.root, formulaId: $0.quality) }
                var take = StrumTake(pattern: pattern, beatsPerBar: meter, bars: bars, bpm: bpm, muted: muted, accents: accents, chords: [target])
                play(&take) { index in pattern[index % pattern.count] == 1 || pattern[index % pattern.count] == 3 ? Sounded(chord: nil, stopped: true) : Sounded(chord: target) }
                if take.chordsMostlyWrong { run.capStars(1) }
                run.complete(score: take.score)
            case let .progression(chords, bars, pattern, bpm, meter, muted, accents):
                let targets = zip(chords, bars).flatMap { chord, count in
                    Array(repeating: ChordTarget(root: chord.root, formulaId: chord.quality), count: count)
                }
                var take = StrumTake(pattern: pattern, beatsPerBar: meter, bars: bars.reduce(0, +), bpm: bpm, muted: muted, accents: accents,
                                     chords: targets)
                play(&take) { index in
                    let beat = pattern[index % pattern.count]
                    let bar = min(index / pattern.count, targets.count - 1)
                    return beat == 1 || beat == 3 ? Sounded(chord: nil, stopped: true) : Sounded(chord: targets[bar])
                }
                if take.chordsMostlyWrong { run.capStars(1) }
                run.complete(score: take.score)
            case let .tapRhythm(pattern, bpm, bars, meter):
                var take = StrumTake(pattern: pattern, beatsPerBar: meter, bars: bars, bpm: bpm)
                play(&take) { _ in Sounded(chord: nil) }
                run.complete(score: take.score)
            default:
                run.complete(score: 1)
            }
        }
        return run.result(now: Date(timeIntervalSince1970: 300)).stars
    }

    /// uke-8-4's 3-3-2: accents on 1, the and of 2 and 4. Pushed 6 dB over the rest they pass; played evenly they are
    /// held to OK and the beat to push is named.
    func testAccentsMustStandOut() throws {
        let c = try XCTUnwrap(ChordTarget(root: 0, formulaId: "maj"))
        let pattern: [Double] = [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]
        let accents: [Double] = [0, 1.5, 3]
        var pushed = StrumTake(pattern: pattern, bars: 2, bpm: 60, accents: accents, chords: [c])
        play(&pushed) { index in Sounded(chord: c, db: accents.contains(pattern[index % pattern.count]) ? -14 : -20) }
        XCTAssertEqual(pushed.score, 1, accuracy: 1e-9)
        XCTAssertNil(pushed.accentToPush)

        var even = StrumTake(pattern: pattern, bars: 2, bpm: 60, accents: accents, chords: [c])
        play(&even) { _ in Sounded(chord: c) }
        XCTAssertEqual(even.calls.values.filter { $0 == .softAccent }.count, 6)
        XCTAssertEqual(even.score, (10 + 6 * 0.5) / 16, accuracy: 1e-9)
        XCTAssertEqual(even.accentToPush, 0)

        // Only the and of 2 left soft: that's the one to push.
        var one = StrumTake(pattern: pattern, bars: 2, bpm: 60, accents: accents, chords: [c])
        play(&one) { index in
            let beat = pattern[index % pattern.count]
            return Sounded(chord: c, db: beat == 0 || beat == 3 ? -14 : -20)
        }
        XCTAssertEqual(one.accentToPush, 1.5)
        // Unheard levels (no stroke reading, as when the screen stands in for the instrument) judge no accents.
        var tapped = StrumTake(pattern: pattern, bars: 2, bpm: 60, accents: accents)
        for due in tapped.expected { tapped.heard(at: due, stamp: due) }
        let score = tapped.finish()
        XCTAssertEqual(score, 1, accuracy: 1e-9)
        XCTAssertTrue(tapped.calls.isEmpty)
    }

    /// Every chord the curriculum asks for (a chord to ring, a strum, a progression) is one the recognizer checks:
    /// none is passed unheard for want of a template.
    func testEveryChordTheCurriculumAsksForIsChecked() throws {
        var unchecked: Set<String> = []
        for lesson in try Curriculum.bundled().courses.flatMap(\.lessons) {
            for step in lesson.steps {
                var chords: [ChordSpec] = []
                switch step {
                case let .playChord(chord): chords = [chord]
                case let .strum(chord, _, _, _, _, _, _): chords = chord.map { [$0] } ?? []
                case let .progression(list, _, _, _, _, _, _): chords = list
                default: break
                }
                for chord in chords where ChordTarget(root: chord.root, formulaId: chord.quality) == nil {
                    unchecked.insert("\(lesson.id): \(chord.symbol) (\(chord.quality))")
                }
            }
        }
        XCTAssertTrue(unchecked.isEmpty, "\(unchecked.sorted())")
    }

    /// gtr-15-2's E9: a stroke of E9 is checked as E7, and passes; an E major stroke doesn't.
    func testANinthChordStrokeIsChecked() throws {
        let e9 = try XCTUnwrap(ChordTarget(root: 4, formulaId: "9"))
        XCTAssertEqual(e9, ChordTarget(root: 4, quality: .dominant7))
        var chroma = [Double](repeating: 0, count: 12)
        for pitchClass in [4, 8, 11, 2, 6] { chroma[pitchClass] = 1 / 5.0.squareRoot() }    // E G♯ B D F♯
        let best = try XCTUnwrap(ChordRecognizer.bestChord(chroma: chroma, bass: 4))
        let heard = ChordEstimate(root: best.target.root, quality: best.target.quality, confidence: best.confidence, chroma: chroma, bass: 4)
        var take = StrumTake(pattern: [0, 0.75, 1.5, 2, 2.75, 3.5], bars: 1, bpm: 60, chords: [e9])
        for (index, due) in take.expected.enumerated() {
            take.heard(at: due, stamp: due)
            let chord = index == 5 ? ChordEstimate(root: 4, quality: .major, confidence: 1, chroma: [], bass: 4) : heard
            take.read(StrokeChords.Stroke(time: 0, chord: chord, attack: 0.1, ring: 0.07), stamp: due)
        }
        take.finish()
        XCTAssertEqual(take.chordRight.values.filter { $0 }.count, 5)
        XCTAssertEqual(take.chordRight[5], false)
        XCTAssertNotNil(take.calls[5], "the E major stroke is called")
    }

    /// Timing: a stroke 120 ms late is OK, one never played is missed once its window has passed, and one far outside
    /// every window is kept as the reason its beat was missed.
    func testStrokesAreTimedAndMissed() {
        var take = StrumTake(pattern: [0, 1, 2, 3], bars: 1, bpm: 60)
        XCTAssertEqual(take.countIn, 4, accuracy: 1e-9)
        XCTAssertEqual(take.heard(at: 4.02, stamp: 0), 0)
        XCTAssertEqual(take.heard(at: 5.12, stamp: 1), 1)
        XCTAssertNil(take.heard(at: 5.7, stamp: 2), "300 ms early for beat 3")
        take.expire(at: 6.3)
        XCTAssertEqual(take.grades[2], .miss)
        XCTAssertEqual(take.strays[2] ?? 0, -0.3, accuracy: 1e-9)
        XCTAssertFalse(take.isOver(at: 7.3, reading: true))
        XCTAssertTrue(take.isOver(at: 7.7, reading: true))
        take.finish()
        XCTAssertEqual(take.grades, [0: .perfect, 1: .ok, 2: .miss, 3: .miss])
        XCTAssertEqual(take.score, 1.5 / 4, accuracy: 1e-9)
    }

    // MARK: Spoken cues

    /// At the roll call's 60 BPM, each note is named two beats ahead, briefly once notes come a beat apart, and no cue
    /// runs into the next or into its note.
    func testSpokenCuesComeTwoBeatsAheadWithoutColliding() {
        let times = (0..<6).map { 4 + Double($0) }    // a bar of count-in, then a note a beat
        let cues = CuePlan.plan(times: times, secondsPerBeat: 1)
        XCTAssertEqual(cues.map { $0.index }, Array(0..<6), "every note is named")
        XCTAssertFalse(cues[0].brief, "the first note is named in full")
        XCTAssertTrue(cues.dropFirst().allSatisfy { $0.brief }, "a beat apart, the brief form")
        for (k, cue) in cues.enumerated() {
            XCTAssertLessThanOrEqual(cue.at + cue.length, times[cue.index] - CuePlan.clearance + 1e-9, "cue \(k) runs into its note")
            XCTAssertLessThanOrEqual(times[cue.index] - cue.at, 2 + 1e-9, "never more than two beats ahead")
            if k + 1 < cues.count { XCTAssertLessThanOrEqual(cue.at + cue.length, cues[k + 1].at + 1e-9, "cue \(k) runs into the next") }
        }
        XCTAssertEqual(times[5] - cues[5].at, 2, accuracy: 1e-9, "settles two beats ahead")
        XCTAssertEqual(CuePlan.lead(secondsPerBeat: 1), 2)
        XCTAssertEqual(CuePlan.lead(secondsPerBeat: 2), 2, "a beat ahead once a beat is long")

        // Two beats apart there is room for every name in full.
        let spaced = CuePlan.plan(times: [4, 6, 8, 10], secondsPerBeat: 1)
        XCTAssertEqual(spaced.count, 4)
        XCTAssertTrue(spaced.allSatisfy { !$0.brief })

        // Eighths at 120 BPM: too fast to name every note; those named never overlap.
        let fast = (0..<12).map { 2 + 0.25 * Double($0) }
        let named = CuePlan.plan(times: fast, secondsPerBeat: 0.5)
        XCTAssertFalse(named.isEmpty)
        XCTAssertLessThan(named.count, fast.count)
        for (k, cue) in named.enumerated() where k + 1 < named.count {
            XCTAssertLessThanOrEqual(cue.at + cue.length, named[k + 1].at + 1e-9)
        }
        XCTAssertTrue(CuePlan.plan(times: [3], secondsPerBeat: 0.5, from: 2.9).isEmpty, "no time left before the note")
    }
}
