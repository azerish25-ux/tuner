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
