import XCTest
@testable import TimbreCore

final class SongArrangementTests: XCTestCase {
    /// The Songs tab's own courses (Songs, Originals, Standards & Classics): every song in them is a whole arrangement.
    private static let fullSongCourses = ["songs", "originals", "standards"]

    private func songs() throws -> [(course: LearnCourse, lesson: Lesson)] {
        let curriculum = try Curriculum.bundled()
        return curriculum.courses
            .filter { Self.fullSongCourses.contains($0.id) }
            .flatMap { course in course.lessons.filter { $0.kind == .song }.map { (course: course, lesson: $0) } }
    }

    func testEverySongIsAWholeArrangementOfOneAndAHalfToThreeMinutes() throws {
        let all = try songs()
        XCTAssertEqual(all.count, 120)  // Songs 32, Originals 50, Standards & Classics 38
        var lengths: [Double] = []
        for (_, lesson) in all {
            let arrangement = try XCTUnwrap(lesson.arrangement, "\(lesson.id) has an arrangement")
            let take = try XCTUnwrap(lesson.songTake, "\(lesson.id) ends on the whole song")
            XCTAssertEqual(arrangement.bpm, take.bpm, lesson.id)
            XCTAssertEqual(arrangement.beatsPerBar, take.beatsPerBar, lesson.id)
            let end = take.notes.map { $0.beat + $0.beats }.max() ?? 0
            XCTAssertLessThanOrEqual(end, arrangement.beats + 1e-6, "\(lesson.id): the bars hold every note")
            XCTAssertGreaterThan(end, arrangement.beats - Double(arrangement.beatsPerBar), "\(lesson.id): no empty bar at the end")
            XCTAssertTrue((90...180).contains(arrangement.seconds), "\(lesson.id) runs \(Int(arrangement.seconds)) s")
            XCTAssertGreaterThanOrEqual(lesson.minutes, Int(arrangement.seconds / 60), "\(lesson.id): the lesson's length covers the song")
            lengths.append(arrangement.seconds)
        }
        let sorted = lengths.sorted()
        XCTAssertGreaterThanOrEqual(sorted[sorted.count / 2], 110, "a typical song runs about two minutes")
    }

    func testSectionsCoverEveryBarInOrder() throws {
        for (_, lesson) in try songs() {
            let arrangement = try XCTUnwrap(lesson.arrangement)
            XCTAssertGreaterThanOrEqual(arrangement.sections.count, 4, "\(lesson.id): a real structure, not one loop")
            var cursor = 0
            for section in arrangement.sections {
                XCTAssertEqual(section.bar, cursor, "\(lesson.id): \(section.name.defaultValue) follows on")
                XCTAssertGreaterThanOrEqual(section.bars, 1)
                XCTAssertLessThan(section.pickup, Double(arrangement.beatsPerBar), "\(lesson.id): an upbeat is under a bar")
                XCTAssertFalse(section.name.key.isEmpty, "\(lesson.id): section names are localized")
                cursor += section.bars
            }
            XCTAssertEqual(cursor, arrangement.bars, "\(lesson.id): sections cover the song")
            XCTAssertTrue(arrangement.sections.contains { $0.kind == .verse || $0.kind == .chorus }, lesson.id)
            // Every bar lies in exactly one section, and every beat finds the section that plays it.
            for bar in 0..<arrangement.bars {
                XCTAssertEqual(arrangement.sections.filter { $0.barRange.contains(bar) }.count, 1, "\(lesson.id) bar \(bar)")
            }
            XCTAssertEqual(arrangement.section(atBeat: 0), arrangement.sections.first)
            XCTAssertEqual(arrangement.section(atBeat: arrangement.beats - 0.01), arrangement.sections.last)
        }
    }

    func testChordChartNamesKnownShapesInOrder() throws {
        for (_, lesson) in try songs() {
            let arrangement = try XCTUnwrap(lesson.arrangement)
            XCTAssertFalse(arrangement.changes.isEmpty, "\(lesson.id) has a chord chart")
            var last = (bar: -1, beat: -1.0)
            for change in arrangement.changes {
                XCTAssertTrue(change.bar > last.bar || (change.bar == last.bar && change.beat > last.beat), "\(lesson.id): changes in order")
                XCTAssertTrue((0..<arrangement.bars).contains(change.bar), lesson.id)
                XCTAssertTrue(change.symbol == "N" || arrangement.shape(named: change.symbol) != nil, "\(lesson.id): a shape for \(change.symbol)")
                last = (bar: change.bar, beat: change.beat)
            }
            XCTAssertEqual(arrangement.chordPerBar.count, arrangement.bars)
            XCTAssertNotNil(arrangement.chord(atBar: arrangement.bars - 1), "\(lesson.id) ends on a chord")
        }
    }

    /// What the band and "Chords & words" play, bar by bar (`played(inBar:)`), is the chart's own harmonic rhythm: read
    /// back in order, its chords change exactly where the chart's do, half-bar changes included, and every bar opens on
    /// a chord once the first has come.
    func testEverySongPlaysItsChartChangeByChange() throws {
        var split = 0
        for (_, lesson) in try songs() {
            let arrangement = try XCTUnwrap(lesson.arrangement)
            let meter = Double(arrangement.beatsPerBar)
            let bars = arrangement.playedBars
            XCTAssertEqual(bars.count, arrangement.bars, lesson.id)
            var played: [(beat: Double, symbol: String)] = []
            for (index, bar) in bars.enumerated() {
                if !played.isEmpty { XCTAssertEqual(bar.first?.beat, 0, "\(lesson.id) bar \(index) opens on a chord") }
                var last = -1.0
                for change in bar {
                    XCTAssertEqual(change.bar, index, lesson.id)
                    XCTAssertTrue(change.beat > last && change.beat < meter, "\(lesson.id) bar \(index): changes in order, inside the bar")
                    XCTAssertNotNil(arrangement.shape(named: change.symbol), "\(lesson.id): a shape for \(change.symbol)")
                    last = change.beat
                    let beat = Double(index) * meter + change.beat
                    if played.last?.symbol != change.symbol { played.append((beat: beat, symbol: change.symbol)) }
                }
                if bar.count > 1 { split += 1 }
            }
            var charted: [(beat: Double, symbol: String)] = []
            for change in arrangement.changes where change.symbol != "N" && charted.last?.symbol != change.symbol {
                charted.append((beat: Double(change.bar) * meter + change.beat, symbol: change.symbol))
            }
            XCTAssertEqual(played.map { $0.symbol }, charted.map { $0.symbol }, "\(lesson.id): the chords, in order")
            XCTAssertEqual(played.map { $0.beat }, charted.map { $0.beat }, "\(lesson.id): each where the chart changes")
        }
        XCTAssertGreaterThan(split, 400, "songs that change chord inside a bar keep those changes")
    }

    func testTheSmallSongChangesOnTheThirdBeatOfItsThirdBar() {
        let (song, _) = smallSong()
        XCTAssertEqual(song.played(inBar: 0).map(\.symbol), ["C"])
        XCTAssertEqual(song.played(inBar: 1).map(\.symbol), ["C"], "a bar with no change holds the chord before it")
        XCTAssertEqual(song.played(inBar: 2).map(\.symbol), ["C", "G"])
        XCTAssertEqual(song.played(inBar: 2).map(\.beat), [0, 2])
        XCTAssertEqual(song.played(inBar: 3).map(\.symbol), ["G"])
        let silent = SongArrangement(bpm: 60, beatsPerBar: 4, bars: 2, sections: [],
                                     changes: [SongArrangement.ChordChange(bar: 0, beat: 2, symbol: "C"),
                                               SongArrangement.ChordChange(bar: 1, beat: 0, symbol: "N"),
                                               SongArrangement.ChordChange(bar: 1, beat: 2, symbol: "C")])
        XCTAssertEqual(silent.played(inBar: 0).map(\.beat), [2], "nothing before the first chord")
        XCTAssertEqual(silent.played(inBar: 1).map(\.symbol), ["C"], "no chord rings on what came before; a repeat isn't a change")
    }

    func testLyricsAlignWithTheirNotes() throws {
        var sung = 0
        for (_, lesson) in try songs() {
            let arrangement = try XCTUnwrap(lesson.arrangement)
            let take = try XCTUnwrap(lesson.songTake)
            let sheet = LyricSheet(notes: take.notes)
            let syllables = take.notes.filter { $0.syllable != nil }
            XCTAssertEqual(sheet.lines.reduce(0) { $0 + $1.syllables.count }, syllables.count, "\(lesson.id): every syllable is on a line")
            guard !sheet.isEmpty else {
                XCTAssertNil(arrangement.words, "\(lesson.id): words credited but none sung")
                continue
            }
            sung += 1
            XCTAssertNotNil(arrangement.words, "\(lesson.id): the words are credited")
            XCTAssertTrue(take.notes.first { $0.syllable != nil }?.startsLine ?? false, "\(lesson.id): the words start a line")
            var previousEnd = -Double.infinity
            for line in sheet.lines {
                XCTAssertFalse(line.text.trimmingCharacters(in: .whitespaces).isEmpty, lesson.id)
                XCTAssertFalse(line.text.contains("_"), "\(lesson.id): no hold marks in the words")
                XCTAssertGreaterThanOrEqual(line.start, previousEnd - 1e-6, "\(lesson.id): lines don't overlap")
                XCTAssertGreaterThan(line.end, line.start, lesson.id)
                var beat = -Double.infinity
                for syllable in line.syllables {
                    let note = take.notes[syllable.note]
                    XCTAssertEqual(note.beat, syllable.beat, "\(lesson.id): a syllable sits on its note")
                    XCTAssertEqual(note.syllable, syllable.text)
                    XCTAssertGreaterThan(syllable.beat, beat, "\(lesson.id): one syllable a note, in order")
                    beat = syllable.beat
                }
                // A line is sung inside one section.
                XCTAssertEqual(arrangement.section(atBeat: line.start), arrangement.section(atBeat: line.end - 0.01),
                               "\(lesson.id): \"\(line.text)\" crosses a section")
                previousEnd = line.end
            }
            // A held note always follows a syllable (or another held note).
            var lastLyric: String?
            for note in take.notes {
                if note.holdsSyllable { XCTAssertNotNil(lastLyric, "\(lesson.id): a held note with nothing to hold") }
                lastLyric = note.lyric
            }
        }
        XCTAssertGreaterThanOrEqual(sung, 40, "most songs carry their words")
    }

    func testEarlierStepsKeepTheirWordsToo() throws {
        // The verse or chorus a lesson teaches before the whole song shows the same words.
        let twinkle = try XCTUnwrap(try songs().first { $0.lesson.id == "song-twinkle" }?.lesson)
        let alongs = twinkle.steps.compactMap { step -> [TimedNote]? in
            if case let .playAlong(notes, _, _, _) = step { return notes }
            return nil
        }
        XCTAssertGreaterThanOrEqual(alongs.count, 3)
        XCTAssertEqual(LyricSheet(notes: alongs[alongs.count - 2]).lines.first?.text, "Twinkle, twinkle, little star,")
        XCTAssertEqual(LyricSheet(notes: try XCTUnwrap(twinkle.songTake).notes).lines.count, 18)
    }

    // MARK: The model, on a made-up song

    /// Bars: intro (1), verse (2, from an upbeat on beat 4 of the intro), chorus (1).
    private func smallSong() -> (SongArrangement, [TimedNote]) {
        let arrangement = SongArrangement(
            bpm: 60, beatsPerBar: 4, bars: 4,
            sections: [SongArrangement.Section(name: LearnText("Intro"), kind: .intro, bar: 0, bars: 1),
                       SongArrangement.Section(name: LearnText("Verse"), kind: .verse, bar: 1, bars: 2, pickup: 1),
                       SongArrangement.Section(name: LearnText("Chorus"), kind: .chorus, bar: 3, bars: 1)],
            changes: [SongArrangement.ChordChange(bar: 0, symbol: "C"), SongArrangement.ChordChange(bar: 2, beat: 2, symbol: "G")],
            shapes: [ChordSpec(name: "C", root: 0, quality: "maj", frets: [-1, 3, 2, 0, 1, 0]),
                     ChordSpec(name: "G", root: 7, quality: "maj", frets: [3, 2, 0, 0, 0, 3])])
        let notes = [TimedNote(midi: 60, beat: 0, beats: 3),
                     TimedNote(midi: 62, beat: 3, beats: 1, lyric: "Twin-", startsLine: true),
                     TimedNote(midi: 64, beat: 4, beats: 2, lyric: "kle,"),
                     TimedNote(midi: 65, beat: 6, beats: 2, lyric: TimedNote.held),
                     TimedNote(midi: 67, beat: 8, beats: 4, lyric: "star!"),
                     TimedNote(midi: 69, beat: 12, beats: 2, lyric: "Hey", startsLine: true),
                     TimedNote(midi: 71, beat: 14, beats: 2)]
        return (arrangement, notes)
    }

    func testSectionTimesAndChordsReadTheChart() {
        let (song, _) = smallSong()
        XCTAssertEqual(song.seconds, 16)
        XCTAssertEqual(song.seconds(atBpm: 120), 8)
        let verse = song.sections[1]
        XCTAssertEqual(song.startBeat(of: verse), 3, "the upbeat belongs to the verse")
        XCTAssertEqual(song.endBeat(of: verse), 12)
        XCTAssertEqual(song.section(atBeat: 2.5)?.kind, .intro)
        XCTAssertEqual(song.section(atBeat: 3)?.kind, .verse)
        XCTAssertEqual(song.section(containingBar: 3)?.kind, .chorus)
        XCTAssertEqual(song.chord(atBar: 2)?.symbol, "C")
        XCTAssertEqual(song.chord(atBar: 2, beat: 2)?.symbol, "G")
        XCTAssertEqual(song.chordPerBar.map { $0?.symbol }, ["C", "C", "C", "G"])
        XCTAssertEqual(song.changes(inBar: 2).count, 1)
    }

    func testASectionLoopsWithItsUpbeatAndWords() {
        let (song, take) = smallSong()
        let verse = song.sections[1]
        let once = song.notes(of: verse, in: take)
        XCTAssertEqual(once.map(\.midi), [62, 64, 65, 67])
        XCTAssertEqual(once.map(\.beat), [3, 4, 6, 8], "a bar of lead-in keeps the upbeat on beat 4")
        XCTAssertEqual(once.first?.lyric, "Twin-")
        XCTAssertTrue(once.first?.startsLine ?? false)

        let twice = song.notes(of: verse, in: take, passes: 2)
        XCTAssertEqual(twice.map(\.beat), [3, 4, 6, 8, 11, 12, 14, 16])
        XCTAssertEqual(twice[3].beats, 3, "the first pass gives way to the second's upbeat")
        XCTAssertEqual(LyricSheet(notes: twice).lines.map(\.text), ["Twinkle, star!", "Twinkle, star!"])

        let practice = song.practice(verse, in: take)
        XCTAssertEqual(practice.bpm, 45)
        XCTAssertEqual(practice.passes, 2)
        XCTAssertEqual(practice.notes.count, 8)
        XCTAssertEqual(song.practice(verse, in: take, speed: 0.1).bpm, Double(MetronomePattern.tempoRange.lowerBound), "never under the click's floor")
    }

    func testLyricSheetCuesTheLineAndSyllable() {
        let (_, take) = smallSong()
        let sheet = LyricSheet(notes: take)
        XCTAssertEqual(sheet.lines.map(\.text), ["Twinkle, star!", "Hey"])
        XCTAssertEqual(sheet.lines[0].start, 3)
        XCTAssertEqual(sheet.lines[0].end, 12, "held notes keep the line")
        XCTAssertEqual(sheet.lines[1].end, 14, "a note without words ends the line")

        XCTAssertEqual(sheet.cue(atBeat: 0), LyricSheet.Cue(line: nil, syllable: nil, next: 0), "the intro shows what's coming")
        XCTAssertEqual(sheet.cue(atBeat: 2.5), LyricSheet.Cue(line: 0, syllable: nil, next: 1), "a beat early it lights up")
        XCTAssertEqual(sheet.cue(atBeat: 3), LyricSheet.Cue(line: 0, syllable: 0, next: 1))
        XCTAssertEqual(sheet.cue(atBeat: 6.5), LyricSheet.Cue(line: 0, syllable: 1, next: 1), "a held note keeps its syllable")
        XCTAssertEqual(sheet.cue(atBeat: 9), LyricSheet.Cue(line: 0, syllable: 2, next: 1))
        XCTAssertEqual(sheet.cue(atBeat: 12), LyricSheet.Cue(line: 1, syllable: 0, next: nil))
        XCTAssertEqual(sheet.cue(atBeat: 20), LyricSheet.Cue(line: nil, syllable: nil, next: nil), "after the words, nothing")
        XCTAssertTrue(LyricSheet(notes: [TimedNote(midi: 60, beat: 0, beats: 1)]).isEmpty)
    }

    func testNotesKeepTheirWordsThroughJSON() throws {
        let json = #"[{"m":62,"b":0,"d":1,"y":"Twin-","yl":1},{"m":64,"b":1,"d":1,"y":"_"},{"m":60,"b":2,"d":1}]"#
        let notes = try JSONDecoder().decode([TimedNote].self, from: Data(json.utf8))
        XCTAssertEqual(notes[0].syllable, "Twin")
        XCTAssertTrue(notes[0].joinsNextSyllable)
        XCTAssertTrue(notes[0].startsLine)
        XCTAssertTrue(notes[1].holdsSyllable)
        XCTAssertNil(notes[1].syllable)
        XCTAssertNil(notes[2].lyric)
        XCTAssertFalse(notes[2].startsLine)
        XCTAssertEqual(try JSONDecoder().decode([TimedNote].self, from: JSONEncoder().encode(notes)), notes)
        // Notes from before lyrics existed decode unchanged.
        let old = try JSONDecoder().decode(TimedNote.self, from: Data(#"{"m":64,"b":0,"d":1,"at":{"s":1,"f":0}}"#.utf8))
        XCTAssertEqual(old, TimedNote(midi: 64, beat: 0, beats: 1, at: Fretting(string: 1, fret: 0)))
    }
}
