import XCTest
@testable import TimbreCore

final class ChartPlaybackTests: XCTestCase {
    private func chart(_ text: String) -> ChordChart { ChordProParser.parse(text) }

    func testTransposesAndWritesForTheCapo() throws {
        let inG = chart("{title: T}\n{key: G}\n[G]a [C]b [D]c [Em]d")
        let up = ChartTransform(transpose: 2)
        XCTAssertEqual(up.shape("G", in: inG), "A")
        XCTAssertEqual(up.shape("Em", in: inG), "F#m")
        let sounding = try XCTUnwrap(up.soundingKey(of: inG))
        XCTAssertEqual(sounding.tonic, 9)
        XCTAssertEqual(ChartTransform().shape("G", in: inG), "G", "nothing moved: as written")
        XCTAssertEqual(up.shape("N.C.", in: inG), "N.C.", "annotations stay")

        // Into a flat key: C up three is E flat.
        let inC = chart("{title: T}\n{key: C}\n[C]a [G]b [F]c")
        let toEb = ChartTransform(transpose: 3)
        XCTAssertEqual(toEb.shape("C", in: inC), "Eb")
        XCTAssertEqual(toEb.shape("G", in: inC), "Bb")
        XCTAssertEqual(toEb.shape("F", in: inC), "Ab")

        // A chart written for capo 2: the player's own capo defaults to it, so the shapes are as written.
        let capoChart = chart("{title: T}\n{key: G}\n{capo: 2}\n[G]a [C]b")
        let asWritten = ChartTransform(chartCapo: capoChart.capo)
        XCTAssertEqual(asWritten.capo, 2)
        XCTAssertEqual(asWritten.shape("G", in: capoChart), "G")
        XCTAssertEqual(asWritten.soundingKey(of: capoChart)?.tonic, 9, "G shapes at capo 2 sound in A")
        // Without the capo the same song is played in A shapes.
        XCTAssertEqual(ChartTransform(capo: 0, chartCapo: 2).shape("G", in: capoChart), "A")
    }

    func testFindsTheEasiestCapo() {
        let flatSong = ["Bb", "Eb", "F", "Gm", "Bb", "F"].compactMap { ChordSymbol($0) }
        XCTAssertEqual(CapoAdvisor.easiest(sounding: flatSong), 3, "capo 3: G, C, D and Em shapes")
        let openSong = ["G", "C", "D", "Em"].compactMap { ChordSymbol($0) }
        XCTAssertNil(CapoAdvisor.easiest(sounding: openSong), "already open chords")
        XCTAssertLessThan(CapoAdvisor.cost(flatSong, capo: 3), CapoAdvisor.cost(flatSong, capo: 0))
    }

    func testTimelineFindsTheChordAtATime() {
        let timeline = ChartTimeline(times: [0, 2, 4, 6])
        XCTAssertNil(timeline.index(at: -1))
        XCTAssertEqual(timeline.index(at: 0), 0)
        XCTAssertEqual(timeline.index(at: 3.9), 1)
        XCTAssertEqual(timeline.index(at: 4), 2)
        XCTAssertEqual(timeline.index(at: 100), 3)
        XCTAssertEqual(timeline.progress(of: 1, at: 3), 0.5, accuracy: 1e-9)
        XCTAssertEqual(ChartTimeline(times: [0, 3, 2]).times, [0, 3, 3], "kept rising")
        XCTAssertEqual(ChartTimeline.steady(count: 4, bpm: 120, beatsPerBar: 4).times, [0, 2, 4, 6])
        XCTAssertEqual(ChartTimeline.extended([0, 2, 4], count: 5, bpm: 60, beatsPerBar: 4).times, [0, 2, 4, 6, 8])
        XCTAssertEqual(ChartTimeline.extended([], count: 2, bpm: 60, beatsPerBar: 4).times, [0, 4])
    }

    func testTapAlong() {
        var taps = TapAlong(count: 3)
        XCTAssertTrue(taps.tap(at: 1.0))
        XCTAssertFalse(taps.tap(at: 1.05), "a double tap")
        XCTAssertFalse(taps.tap(at: 0.5), "never backwards")
        XCTAssertTrue(taps.tap(at: 2.0))
        taps.undo()
        XCTAssertEqual(taps.times, [1.0])
        XCTAssertEqual(taps.next, 1)
        taps.tap(at: 2.5)
        taps.tap(at: 3.5)
        XCTAssertTrue(taps.isFinished)
        XCTAssertFalse(taps.tap(at: 4))

        let resumed = TapAlong(count: 4, keeping: [1, 2, 3], from: 2)
        XCTAssertEqual(resumed.times, [1, 2])
        XCTAssertEqual(resumed.next, 2)
    }

    func testPracticePlan() throws {
        let song = chart("{title: T}\n{tempo: 120}\n[G]a [C]b [G]c [D]d")
        let plain = ChartTransform()
        XCTAssertEqual(ChartPractice.drill(song, transform: plain).map(\.text), ["G", "C", "D"])
        XCTAssertEqual(ChartPractice.progression(song, transform: plain).map { $0.chord.text }, ["G", "C", "G", "D"])
        let held = ChartPractice.progression(chart("{title: T}\n[G]a [G]b [C]c"), transform: plain)
        XCTAssertEqual(held.map { $0.bars }, [2, 1])
        XCTAssertEqual(ChartPractice.progression(chart("{title: T}\n" + String(repeating: "[G]x [C]y ", count: 10)), transform: plain)
            .reduce(0) { $0 + $1.bars }, 8, "eight bars at most")
        XCTAssertEqual(ChartPractice.tempo(for: song), 90)
        XCTAssertEqual(ChartPractice.tempo(for: chart("{title: T}\n[G]a")), 80)
        XCTAssertEqual(ChartPractice.tempo(for: chart("{title: T}\n{tempo: 200}\n[G]a")), 100)

        let g = try XCTUnwrap(ChartPractice.spec(for: ChordSymbol("G")!, openMidi: ChordLibrary.standardGuitar))
        XCTAssertEqual(g.frets, [3, 2, 0, 0, 0, 3])
        XCTAssertEqual(g.quality, "maj")
        XCTAssertNil(g.baseFret)
        let am = try XCTUnwrap(ChartPractice.spec(for: ChordSymbol("Am")!, openMidi: ChordLibrary.standardGuitar))
        XCTAssertEqual(am.frets, [-1, 0, 2, 2, 1, 0])
        XCTAssertEqual(ChordTarget(root: am.root, formulaId: am.quality), ChordTarget(root: 9, quality: .minor),
                       "the lesson's chord step can listen for it")
        // Ukulele (G C E A, re-entrant): a playable shape from the finder.
        let uke = try XCTUnwrap(ChartPractice.spec(for: ChordSymbol("C")!, openMidi: [67, 60, 64, 69]))
        XCTAssertEqual(uke.frets.count, 4)
    }

    func testFreeAndPro() {
        XCTAssertTrue(YourSongsPolicy.canAddChart(existing: 2, pro: false))
        XCTAssertFalse(YourSongsPolicy.canAddChart(existing: 3, pro: false))
        XCTAssertTrue(YourSongsPolicy.canAddChart(existing: 300, pro: true))
        XCTAssertTrue(YourSongsPolicy.canPlayAlongWithRecording(pro: false))
        XCTAssertFalse(YourSongsPolicy.canPlayAlongWithAppleMusic(pro: false))
        XCTAssertTrue(YourSongsPolicy.canPlayAlongWithAppleMusic(pro: true))
        XCTAssertFalse(YourSongsPolicy.canDetectChords(pro: false))
    }
}
