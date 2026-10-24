import XCTest
@testable import TimbreCore

final class SongOfTheDayTests: XCTestCase {
    private func song(_ id: String, original: Bool = false, unit: Int = 0, finished: Bool = false,
                      access: SongOfTheDay.Access = .open) -> SongOfTheDay.Candidate {
        SongOfTheDay.Candidate(id: id, original: original, unit: unit, finished: finished, access: access)
    }

    /// The Songs tab on a fresh start: the first nursery rhyme and the first Original are open, the rest wait.
    private var shelf: [SongOfTheDay.Candidate] {
        [song("mary"), song("twinkle", access: .locked),
         song("kite", original: true), song("porchlight", original: true, access: .locked),
         song("rust", original: true, unit: 1, access: .locked)]
    }

    func testEmptyShelfHasNoSong() {
        XCTAssertNil(SongOfTheDay.pick([], level: 5, finishedLessons: 3, day: 1))
    }

    func testABeginnerGetsAnOpenFirstSongThatHoldsAllDay() {
        for day in 0..<40 {
            let pick = SongOfTheDay.pick(shelf, level: 1, finishedLessons: 0, day: day)
            XCTAssertTrue(["mary", "kite"].contains(pick ?? ""), "day \(day): \(pick ?? "nil")")
            XCTAssertEqual(pick, SongOfTheDay.pick(shelf, level: 1, finishedLessons: 0, day: day))
        }
        // Both open first songs come up over a few weeks.
        let picks = Set((0..<40).compactMap { SongOfTheDay.pick(shelf, level: 1, finishedLessons: 0, day: $0) })
        XCTAssertEqual(picks, ["mary", "kite"])
    }

    func testPastTheBeginnerUnitsAnOriginalLeads() {
        // Level 5 on a 7-day streak, three lessons in: never "Mary Had a Little Lamb" while an Original is open.
        for day in 0..<40 {
            XCTAssertEqual(SongOfTheDay.pick(shelf, level: 5, finishedLessons: 3, day: day), "kite")
        }
        // Six finished lessons, or a placement, count as past the beginner units at any level.
        XCTAssertEqual(SongOfTheDay.pick(shelf, level: 1, finishedLessons: 6, day: 3), "kite")
        XCTAssertEqual(SongOfTheDay.pick(shelf, level: 1, finishedLessons: 0, placed: true, day: 3), "kite")
    }

    func testTheNextProOriginalComesBeforeATraditionalTune() {
        let songs = [song("mary", finished: true), song("twinkle"),
                     song("kite", original: true, finished: true), song("rust", original: true, unit: 1, access: .pro)]
        XCTAssertEqual(SongOfTheDay.pick(songs, level: 5, finishedLessons: 8, day: 9), "rust")
        // A beginner gets the open song rather than the Pro one.
        XCTAssertEqual(SongOfTheDay.pick(songs, level: 1, finishedLessons: 2, day: 9), "twinkle")
    }

    func testAPlayedSongComesBackOnlyWhenNothingIsNew() {
        let played = [song("mary", finished: true), song("kite", original: true, finished: true)]
        XCTAssertNotNil(SongOfTheDay.pick(played, level: 5, finishedLessons: 10, day: 2))
        let withNew = played + [song("twinkle", unit: 0)]
        XCTAssertEqual(SongOfTheDay.pick(withNew, level: 5, finishedLessons: 10, day: 2), "twinkle")
        // Nothing open at all: the next Pro song still beats one that is order-locked.
        let shut = [song("a", access: .locked), song("b", access: .pro)]
        XCTAssertEqual(SongOfTheDay.pick(shut, level: 1, finishedLessons: 0, day: 2), "b")
    }

    func testSongsNearTheLearnersUnitWin() {
        let songs = [song("easy", unit: 0), song("middle", unit: 2), song("hard", unit: 4)]
        XCTAssertEqual(SongOfTheDay.targetUnit(level: 8, pastBeginner: true), 2)
        XCTAssertEqual(SongOfTheDay.pick(songs, level: 8, finishedLessons: 20, day: 5), "middle")
        XCTAssertEqual(SongOfTheDay.pick(songs, level: 1, finishedLessons: 0, day: 5), "easy")
    }

    func testHashIsStable() {
        XCTAssertEqual(SongOfTheDay.hash("orig-kite-weather"), SongOfTheDay.hash("orig-kite-weather"))
        XCTAssertNotEqual(SongOfTheDay.hash("orig-kite-weather", salt: 1), SongOfTheDay.hash("orig-kite-weather", salt: 2))
    }

    // MARK: Preview

    private func lesson(_ steps: [LessonStep]) -> Lesson {
        Lesson(id: "s", title: LearnText("S"), kind: .song, minutes: 5, xp: 30, free: true, steps: steps)
    }

    func testPreviewPlaysTheOpeningBarsAtThePerformanceTempo() throws {
        let opening = (0..<16).map { TimedNote(midi: 60 + $0 % 5, beat: Double($0), beats: 1) }
        let phrase = try XCTUnwrap(SongPreview.opening(of: lesson([
            .explain(title: LearnText("T"), body: LearnText("B"), visual: .none),
            .playAlong(notes: opening, bpm: 72, beatsPerBar: 4, title: nil),
            .playAlong(notes: [TimedNote(midi: 50, beat: 0, beats: 1)], bpm: 88, beatsPerBar: 4, title: nil),
        ])))
        XCTAssertEqual(phrase.bpm, 88)
        XCTAssertEqual(phrase.notes.count, 8)  // two bars of 4/4
        XCTAssertEqual(phrase.notes.first?.midi, 60)
        XCTAssertEqual(phrase.time(of: 1), 60.0 / 88, accuracy: 1e-9)
        XCTAssertEqual(phrase.duration, 8 * 60.0 / 88, accuracy: 1e-9)
    }

    func testPreviewStretchesASparseOpeningAndStopsInTime() throws {
        // Two long notes in the first two bars: four bars instead, from beat 0.
        let sparse = [TimedNote(midi: 60, beat: 2, beats: 4), TimedNote(midi: 62, beat: 6, beats: 4),
                      TimedNote(midi: 64, beat: 10, beats: 2), TimedNote(midi: 65, beat: 12, beats: 2), TimedNote(midi: 67, beat: 14, beats: 2)]
        let phrase = try XCTUnwrap(SongPreview.opening(of: lesson([.playAlong(notes: sparse, bpm: 60, beatsPerBar: 4, title: nil)])))
        XCTAssertEqual(phrase.notes.first?.beat, 0)
        XCTAssertEqual(phrase.notes.map(\.midi), [60, 62])  // beat 10 and on start at or past the 8 s cut at 60 BPM
        XCTAssertEqual(phrase.duration, 8, accuracy: 1e-9)
    }

    func testPreviewFallsBackToNotesAndSkipsSongsWithout() throws {
        let notes = (0..<6).map { TimedNote(midi: 64, beat: Double($0), beats: 1) }
        let phrase = try XCTUnwrap(SongPreview.opening(of: lesson([.playNotes(notes: notes, hint: nil)])))
        XCTAssertEqual(phrase.bpm, 92)
        XCTAssertEqual(phrase.notes.count, 6)
        XCTAssertNil(SongPreview.opening(of: lesson([.explain(title: LearnText("T"), body: LearnText("B"), visual: .none)])))
    }

    /// A whole song: a two-bar intro with a riff of its own, a verse from an upbeat on the intro's last beat, a chorus.
    private func arranged() -> Lesson {
        let arrangement = SongArrangement(
            bpm: 60, beatsPerBar: 4, bars: 8,
            sections: [SongArrangement.Section(name: LearnText("Intro"), kind: .intro, bar: 0, bars: 2),
                       SongArrangement.Section(name: LearnText("Verse 1"), kind: .verse, bar: 2, bars: 4, pickup: 1),
                       SongArrangement.Section(name: LearnText("Chorus"), kind: .chorus, bar: 6, bars: 2)])
        let riff = (0..<7).map { TimedNote(midi: 40 + $0, beat: Double($0), beats: 1) }
        let upbeat = TimedNote(midi: 60, beat: 7, beats: 1, lyric: "The", startsLine: true)
        let verse = (8..<24).map { TimedNote(midi: 62 + $0 % 5, beat: Double($0), beats: 1, lyric: "la") }
        let chorus = (24..<32).map { TimedNote(midi: 70, beat: Double($0), beats: 1, lyric: "hey") }
        let fragment = Array(verse.prefix(4))
        return Lesson(id: "whole", title: LearnText("Whole"), kind: .song, minutes: 6, xp: 40, free: true,
                      steps: [.playAlong(notes: fragment, bpm: 50, beatsPerBar: 4, title: LearnText("The verse")),
                              .playAlong(notes: riff + [upbeat] + verse + chorus, bpm: 60, beatsPerBar: 4, title: nil)],
                      arrangement: arrangement)
    }

    func testAWholeSongPreviewsItsFirstVerseNotItsIntro() throws {
        let phrase = try XCTUnwrap(SongPreview.opening(of: arranged()))
        XCTAssertEqual(phrase.bpm, 60)
        XCTAssertEqual(phrase.notes.first?.midi, 60, "it opens on the verse's upbeat")
        XCTAssertEqual(phrase.notes.first?.beat, 0)
        XCTAssertEqual(phrase.notes.count, 8, "two bars from the upbeat")
        XCTAssertTrue(phrase.notes.allSatisfy { $0.midi >= 60 }, "nothing of the intro's riff")
    }

    func testAWholeSongExcerptRunsInWholeBarsFromItsOpening() throws {
        let song = arranged()
        let sample = try XCTUnwrap(SongPreview.excerpt(of: song, maxSeconds: 20))
        XCTAssertEqual(sample.section.kind, .verse)
        XCTAssertEqual(sample.firstBar, 1, "the bar before the verse holds its upbeat")
        XCTAssertEqual(sample.bars, 5, "four-second bars, twenty seconds at most")
        XCTAssertEqual(sample.seconds, 20, accuracy: 1e-9)
        XCTAssertEqual(sample.notes.first?.beat, 3, "the upbeat on the lead-in bar's last beat")
        XCTAssertEqual(sample.lead, 3)
        XCTAssertEqual(sample.notes.first?.lyric, "The", "the words come along")
        XCTAssertEqual(sample.notes.count, 17)
        XCTAssertLessThanOrEqual(sample.notes.map { $0.beat + $0.beats }.max() ?? 0, 20 + 1e-9)

        let short = try XCTUnwrap(SongPreview.excerpt(of: song, bars: 2))
        XCTAssertEqual(short.bars, 2)
        XCTAssertEqual(short.notes.map(\.beat), [3, 4, 5, 6, 7])
        // Never past the end of the song.
        XCTAssertEqual(SongPreview.excerpt(of: song, bars: 40, maxSeconds: 600)?.bars, 7)
        // A song without an arrangement has no excerpt (its sample plays from the top).
        XCTAssertNil(SongPreview.excerpt(of: lesson([.playAlong(notes: [TimedNote(midi: 60, beat: 0, beats: 1)], bpm: 80, beatsPerBar: 4, title: nil)])))
    }

    func testTheOpeningSectionPassesOverSilentSections() {
        let arrangement = SongArrangement(
            bpm: 80, beatsPerBar: 4, bars: 3,
            sections: [SongArrangement.Section(name: LearnText("Intro"), kind: .intro, bar: 0, bars: 1),
                       SongArrangement.Section(name: LearnText("Verse 1"), kind: .verse, bar: 1, bars: 1),
                       SongArrangement.Section(name: LearnText("Solo"), kind: .solo, bar: 2, bars: 1)])
        let intro = [TimedNote(midi: 60, beat: 0, beats: 1)]
        let solo = [TimedNote(midi: 67, beat: 8, beats: 1)]
        XCTAssertEqual(SongPreview.openingSection(of: arrangement, notes: intro + solo)?.kind, .solo, "a verse with no notes is passed over")
        XCTAssertEqual(SongPreview.openingSection(of: arrangement, notes: intro)?.kind, .intro, "an intro is better than nothing")
        XCTAssertNil(SongPreview.openingSection(of: arrangement, notes: []))
    }

    func testEverySongWithAMelodyHasAShortPreview() throws {
        let curriculum = try Curriculum.bundled()
        for course in curriculum.courses {
            for lesson in course.lessons where lesson.kind == .song {
                let melodic = lesson.steps.contains { step in
                    switch step {
                    case .playAlong, .playNotes: return true
                    default: return false
                    }
                }
                // Chords-only songs ("Greensleeves: the chords") have nothing to preview.
                guard melodic else { continue }
                let phrase = SongPreview.opening(of: lesson)
                XCTAssertNotNil(phrase, lesson.id)
                XCTAssertLessThanOrEqual(phrase?.duration ?? 0, 12, lesson.id)
                XCTAssertGreaterThanOrEqual(phrase?.notes.count ?? 0, 3, lesson.id)
            }
        }
        // Every song in the two song courses can be previewed from the Songs tab's hero.
        for id in ["songs", "originals"] {
            let course = try XCTUnwrap(curriculum.course(id: id))
            for lesson in course.lessons where lesson.kind == .song {
                XCTAssertNotNil(SongPreview.opening(of: lesson), lesson.id)
            }
        }
    }

    func testWholeSongsPreviewTheirFirstVerseOrHook() throws {
        let curriculum = try Curriculum.bundled()
        var checked = 0
        for course in curriculum.courses {
            for lesson in course.lessons {
                guard let arrangement = lesson.arrangement, let take = lesson.songTake else { continue }
                checked += 1
                let section = try XCTUnwrap(SongPreview.openingSection(of: arrangement, notes: take.notes), lesson.id)
                XCTAssertTrue(section.kind.isSung, "\(lesson.id) opens on \(section.name.defaultValue)")
                // The cover's few seconds start on that section's first note.
                let first = take.notes.first { $0.beat >= arrangement.startBeat(of: section) - 1e-6 }
                XCTAssertEqual(SongPreview.opening(of: lesson)?.notes.first?.midi, first?.midi, lesson.id)
                // "Hear it": whole bars, twenty seconds at most, with the words when the song has them.
                let sample = try XCTUnwrap(SongPreview.excerpt(of: lesson, maxSeconds: 20), lesson.id)
                XCTAssertLessThanOrEqual(sample.seconds, 20 + 1e-6, lesson.id)
                XCTAssertGreaterThanOrEqual(sample.seconds, 12, "\(lesson.id): long enough to hear the tune")
                XCTAssertGreaterThanOrEqual(sample.notes.count, 5, lesson.id)
                XCTAssertLessThan(sample.lead, Double(sample.beatsPerBar), "\(lesson.id): at most a bar of rest first")
                XCTAssertEqual(LyricSheet(notes: sample.notes).isEmpty, LyricSheet(notes: take.notes).isEmpty, "\(lesson.id): the words come along")
            }
        }
        XCTAssertEqual(checked, 52)
    }
}
