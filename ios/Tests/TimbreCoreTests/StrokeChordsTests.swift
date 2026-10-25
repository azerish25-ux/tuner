import XCTest
@testable import TimbreCore

/// Each stroke's reading beyond its chord, through the path a live take takes (`AudioClip` in the microphone tap's
/// buffers, `LessonListening`, `StrokeChords`, then `StrumTake`): a chunk or a chop stops dead and a strum rings on, an
/// accent stands out, and strokes close together are read apart.
final class StrokeChordsTests: XCTestCase {
    private static let ukulele = [67, 60, 64, 69]

    /// A take strummed on `pattern` (4/4, `bars` bars from 0.5 s) on `shape`. On the `muted` beats, a chunk: everything
    /// still ringing choked within about 12 ms, a dry strum and the slap of the hand; with `chunksRing`, a plain strum
    /// left ringing there instead (a chop that didn't stop). `accents` are played `accentGain` times as hard.
    /// Peak-normalised to 0.3, plus uniform noise of 0.002. Returns the audio, each stroke's time and its beat.
    private func take(_ shape: String, tuning: [Int] = Synth.guitar, pattern: [Double], bpm: Double, bars: Int = 2,
                      muted: [Double] = [], chunksRing: Bool = false, accents: [Double] = [], accentGain: Double = 3,
                      rate: Double, seed: UInt64) -> (clip: AudioClip, strokes: [Double], beats: [Double]) {
        var rng = TestRandom(seed: seed)
        let secondsPerBeat = 60 / bpm
        var strokes: [Double] = []
        var beats: [Double] = []
        for bar in 0..<bars {
            for position in pattern {
                strokes.append(0.5 + (Double(bar * 4) + position) * secondsPerBeat)
                beats.append(position)
            }
        }
        let count = Int(((strokes.last ?? 0) + 1) * rate)
        var sound = [Double](repeating: 0, count: count)
        let notes = Synth.voicing(shape, tuning: tuning)
        for (time, beat) in zip(strokes, beats) {
            let up = beat.truncatingRemainder(dividingBy: 1) != 0
            let level = accents.contains(where: { abs($0 - beat) < 0.02 }) ? accentGain : 1
            if muted.contains(where: { abs($0 - beat) < 0.02 }) && !chunksRing {
                damp(&sound, from: time, tau: 0.012, rate: rate)
                var burst = [Double](repeating: 0, count: count)
                Synth.strum(notes, at: time, into: &burst, sampleRate: rate, rng: &rng, spread: 0.004, up: up, level: level)
                damp(&burst, from: time + 0.008, tau: 0.012, rate: rate)
                Synth.click(at: time, amplitude: 0.6 * level, into: &burst, sampleRate: rate, rng: &rng)
                for i in 0..<count { sound[i] += burst[i] }
            } else {
                Synth.strum(notes, at: time, into: &sound, sampleRate: rate, rng: &rng, up: up, level: level)
            }
        }
        let peak = sound.map { abs($0) }.max() ?? 0
        let scale = peak > 0 ? 0.3 / peak : 0
        for i in sound.indices { sound[i] = sound[i] * scale + 0.002 * rng.uniform(-1, 1) }
        return (AudioClip(samples: sound.map { Float($0) }, sampleRate: rate), strokes, beats)
    }

    /// Everything from `from` (seconds) on dies away with time constant `tau`.
    private func damp(_ samples: inout [Double], from time: Double, tau: Double, rate: Double) {
        let first = Int(time * rate)
        guard first < samples.count else { return }
        for i in max(0, first)..<samples.count { samples[i] *= exp(-Double(i - first) / (tau * rate)) }
    }

    /// The strokes read in `clip`, each with the stroke of the take it is (within 30 ms).
    private func readings(_ clip: AudioClip, strokes: [Double]) -> [(index: Int, stroke: StrokeChords.Stroke)] {
        clip.strokes().compactMap { stroke in
            guard let nearest = strokes.indices.min(by: { abs(strokes[$0] - stroke.time) < abs(strokes[$1] - stroke.time) }),
                  abs(strokes[nearest] - stroke.time) <= 0.03 else { return nil }
            return (nearest, stroke)
        }
    }

    /// The take judged as a rhythm step judges it: every onset and every reading fed through `LessonListening` in the
    /// tap's buffers, its first stroke on the step's first beat.
    private func judge(_ clip: AudioClip, firstStroke: Double, into step: inout StrumTake) {
        let shift = (step.expected.first ?? 0) - firstStroke
        for event in clip.events(through: LessonListening(chords: false, strokes: true)) {
            switch event {
            case .onset(let time): step.heard(at: time + shift, stamp: time)
            case .stroke(let stroke): step.read(stroke, stamp: stroke.time)
            default: break
            }
        }
        step.finish()
    }

    // MARK: Chunks and chops

    /// uke-8-1's chunk: C on 1, 2, 3, the and of 3 and 4, beats 2 and 4 chunked. Every stroke is heard; the chunks
    /// have stopped 150 ms later, the strums still ring.
    func testChunksStopDeadAndStrumsRingOn() {
        for rate in [44100.0, 48000.0] {
            for seed: UInt64 in [1, 2] {
                let played = take("0003", tuning: Self.ukulele, pattern: [0, 1, 2, 2.5, 3], bpm: 63, muted: [1, 3], rate: rate, seed: seed)
                let heard = readings(played.clip, strokes: played.strokes)
                let context = "chunks at \(Int(rate)) Hz, seed \(seed)"
                XCTAssertEqual(Set(heard.map { $0.index }).count, played.strokes.count, context)
                for (index, stroke) in heard {
                    let chunk = played.beats[index] == 1 || played.beats[index] == 3
                    XCTAssertEqual(stroke.stopped, chunk, "\(context): stroke \(index) rang \(stroke.ring ?? -1) after \(stroke.attack)")
                    XCTAssertGreaterThan(stroke.level, -60, context)
                }
            }
        }
    }

    /// A correct chunk take, heard through the real path, scores full marks: every stroke on time, every chunk stopped.
    /// Judged with its chord too, the strummed strokes ring C (a reading may slip, as in any take).
    func testACorrectChunkTakeScoresFullMarks() throws {
        let c = try XCTUnwrap(ChordTarget(symbol: "C"))
        for rate in [44100.0, 48000.0] {
            let played = take("0003", tuning: Self.ukulele, pattern: [0, 1, 2, 2.5, 3], bpm: 63, muted: [1, 3], rate: rate, seed: 3)
            var timing = StrumTake(pattern: [0, 1, 2, 2.5, 3], bars: 2, bpm: 63, muted: [1, 3])
            judge(played.clip, firstStroke: played.strokes[0], into: &timing)
            XCTAssertEqual(timing.score, 1, accuracy: 1e-9, "\(Int(rate)) Hz: \(timing.grades)")
            XCTAssertEqual(timing.mutedStopped.stopped, 4)
            XCTAssertEqual(timing.mutedStopped.of, 4)
            XCTAssertTrue(timing.calls.isEmpty, "\(timing.calls)")

            var chords = StrumTake(pattern: [0, 1, 2, 2.5, 3], bars: 2, bpm: 63, muted: [1, 3], chords: [c])
            judge(played.clip, firstStroke: played.strokes[0], into: &chords)
            XCTAssertEqual(chords.mutedStopped.stopped, 4)
            XCTAssertGreaterThanOrEqual(chords.chordRight.values.filter { $0 }.count, 5, "\(chords.calls)")
            XCTAssertGreaterThanOrEqual(chords.score, 0.9)
            XCTAssertFalse(chords.chordsMostlyWrong)
        }
    }

    /// The same take with the chops left ringing: every muted stroke still rings 150 ms later, and those that rang the
    /// chord are called ("Let it stop").
    func testAChopLeftRingingIsCalled() throws {
        let c = try XCTUnwrap(ChordTarget(symbol: "C"))
        for rate in [44100.0, 48000.0] {
            let played = take("0003", tuning: Self.ukulele, pattern: [0, 1, 2, 2.5, 3], bpm: 63, muted: [1, 3], chunksRing: true,
                              rate: rate, seed: 4)
            for (index, stroke) in readings(played.clip, strokes: played.strokes) where played.beats[index] == 1 || played.beats[index] == 3 {
                XCTAssertEqual(stroke.stopped, false, "\(Int(rate)) Hz: stroke \(index)")
            }
            var judged = StrumTake(pattern: [0, 1, 2, 2.5, 3], bars: 2, bpm: 63, muted: [1, 3], chords: [c])
            judge(played.clip, firstStroke: played.strokes[0], into: &judged)
            let rang = judged.calls.values.filter { $0 == .ringing }.count
            XCTAssertGreaterThanOrEqual(rang, 3, "\(Int(rate)) Hz: \(judged.calls)")
            XCTAssertLessThan(judged.score, 0.9)
        }
    }

    // MARK: Accents

    /// uke-8-4's 3-3-2: eighths with 1, the and of 2 and 4 accented. Played three times as hard, each accent comes in
    /// at least 4 dB over the plain strokes; played evenly, none does.
    func testAccentsStandOutOnlyWhenPlayed() {
        let pattern = [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]
        let accents = [0, 1.5, 3.0]
        for rate in [44100.0, 48000.0] {
            for gain in [3.0, 1.0] {
                let played = take("0003", tuning: Self.ukulele, pattern: pattern, bpm: 60, accents: accents, accentGain: gain, rate: rate, seed: 2)
                let heard = readings(played.clip, strokes: played.strokes)
                let accented = heard.filter { accents.contains(played.beats[$0.index]) }.map { $0.stroke.level }
                let plain = heard.filter { !accents.contains(played.beats[$0.index]) }.map { $0.stroke.level }.sorted()
                XCTAssertGreaterThanOrEqual(plain.count, 4, "\(Int(rate)) Hz, ×\(gain)")
                XCTAssertFalse(accented.isEmpty)
                let median = plain[plain.count / 2]
                for level in accented {
                    if gain > 1 {
                        XCTAssertGreaterThanOrEqual(level, median + StrumTake.accentDb, "\(Int(rate)) Hz: an accent didn't stand out")
                    } else {
                        XCTAssertLessThan(level, median + StrumTake.accentDb, "\(Int(rate)) Hz: an even stroke read as an accent")
                    }
                }
            }
        }
    }

    // MARK: Close strokes

    /// A stroke is read up to just before the next one when that comes within the frame, never on less than the
    /// shortest frame; on its own it gets the full frame from 60 ms after it.
    func testAFrameStopsShortOfTheNextStroke() {
        let rate = 48000.0
        let reader = StrokeChords(sampleRate: rate)
        let alone = reader.readSpan(after: 1, next: nil)
        XCTAssertEqual(alone.begin, Int((1.06 * rate).rounded()))
        XCTAssertEqual(alone.length, reader.frameLength)
        XCTAssertEqual(reader.readSpan(after: 1, next: 1.5).length, reader.frameLength, "a stroke half a second later is clear")
        // Sixteenths at 90 BPM: 167 ms apart.
        let close = reader.readSpan(after: 1, next: 1.167)
        XCTAssertLessThanOrEqual(close.begin + close.length, Int((1.167 * rate).rounded()))
        XCTAssertLessThan(close.length, reader.frameLength)
        XCTAssertGreaterThanOrEqual(close.length, Int((StrokeChords.shortestFrame * rate).rounded()) - 1)
        // Closer than that, the frame keeps its shortest length and starts earlier.
        let closer = reader.readSpan(after: 1, next: 1.11)
        XCTAssertGreaterThanOrEqual(closer.length, Int((StrokeChords.shortestFrame * rate).rounded()) - 1)
        XCTAssertGreaterThanOrEqual(closer.begin, Int((1.02 * rate).rounded()))
    }

    /// A stroke's ring can't be told while the next stroke is already sounding: it comes back unknown, never a guess.
    func testRingIsUnknownWhenTheNextStrokeComesFirst() {
        let rate = 48000.0
        // The second stroke, 167 ms after the first, played hard so it is heard over the first one ringing.
        let played = take("x32010", pattern: [0, 0.25, 1, 2, 3], bpm: 90, bars: 1, accents: [0.25], rate: rate, seed: 7)
        let heard = readings(played.clip, strokes: played.strokes)
        XCTAssertNotNil(heard.first { $0.index == 1 }, "the second stroke wasn't heard")
        let first = heard.first { $0.index == 0 }
        XCTAssertNotNil(first)
        XCTAssertNil(first?.stroke.ring, "the next stroke came 167 ms later")
        XCTAssertNil(first?.stroke.stopped)
        let last = heard.first { $0.index == 4 }
        XCTAssertNotNil(last?.stroke.ring, "the last stroke rings on its own")
    }

    // MARK: The clip

    /// A clip hands its audio over in the tap's buffers, all of it, in order.
    func testAClipPlaysInTheTapsBuffers() {
        let samples = (0..<1300).map { Float($0) }
        let clip = AudioClip(samples: samples, sampleRate: 48000)
        let buffers = clip.buffers()
        XCTAssertEqual(buffers.map(\.count), [512, 512, 276])
        XCTAssertEqual(buffers.flatMap { $0 }, samples)
        var ends: [Double] = []
        clip.play { _, end in ends.append(end) }
        XCTAssertEqual(ends.last ?? 0, clip.duration, accuracy: 1e-12)
        XCTAssertEqual(AudioClip(samples: [], sampleRate: 48000).buffers().count, 0)
    }
}
