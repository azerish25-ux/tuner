import QuartzCore
import TimbreCore

/// Chord recognition, strokes and strums for lessons: what the pitch tracker can't hear. Fed raw microphone samples on
/// the audio analysis queue; the analysis itself is `LessonListening` (TimbreCore, where a recording can be fed through
/// it the same way), and this moves each result onto the host clock (`CACurrentMediaTime`) and the main actor.
///
/// - `chords`: a running chord reading every 4096 samples (`onChord`), matched against `target`.
/// - Onsets (`onOnset`) always.
/// - `strokes`: each stroke's own chord, about 0.25 s after it (`onStroke`), with its attack and ring too
///   (`onStrokeRead`, `StrokeChords.Stroke`), so a rhythm step can grade a stroke for its chord, a chop for stopping
///   and an accent for standing out, as well as its timing.
/// - `strings`: a strum's every string at once (`onStrum`, `PolyTuner` on these pitches), so a chord step can tell
///   which strings rang.
final class LessonAnalyzer: @unchecked Sendable {
    private let lock = NSLock()
    private let listening: LessonListening
    private var rate = 0.0
    /// Each onset's host time as it was reported, so its stroke's reading comes back with exactly the same time.
    private var onsetHost: [Double: CFTimeInterval] = [:]
    /// The latest estimate, and whether it matches the target chord.
    private let onChord: @MainActor (ChordEstimate?, Bool) -> Void
    private let onOnset: @MainActor (CFTimeInterval) -> Void
    private let onStroke: @MainActor (CFTimeInterval, ChordEstimate?) -> Void
    private let onStrokeRead: @MainActor (CFTimeInterval, StrokeChords.Stroke) -> Void
    private let onStrum: @MainActor (PolyReading) -> Void

    init(chords: Bool, target: ChordTarget? = nil, strokes: Bool = false, strings: [Double]? = nil,
         onChord: @escaping @MainActor (ChordEstimate?, Bool) -> Void = { _, _ in },
         onOnset: @escaping @MainActor (CFTimeInterval) -> Void = { _ in },
         onStroke: @escaping @MainActor (CFTimeInterval, ChordEstimate?) -> Void = { _, _ in },
         onStrokeRead: @escaping @MainActor (CFTimeInterval, StrokeChords.Stroke) -> Void = { _, _ in },
         onStrum: @escaping @MainActor (PolyReading) -> Void = { _ in }) {
        listening = LessonListening(chords: chords, target: target, strokes: strokes, strings: strings)
        self.onChord = onChord
        self.onOnset = onOnset
        self.onStroke = onStroke
        self.onStrokeRead = onStrokeRead
        self.onStrum = onStrum
    }

    /// Listens for another chord from the next frame on: the running reading starts afresh.
    func retarget(_ target: ChordTarget?) {
        lock.lock(); defer { lock.unlock() }
        listening.retarget(target)
    }

    func feed(_ samples: [Float], rate: Double) {
        let arrived = CACurrentMediaTime()
        lock.lock(); defer { lock.unlock() }
        if rate != self.rate {
            self.rate = rate
            onsetHost = [:]
        }
        let events = listening.feed(samples, rate: rate)
        // Stream seconds onto the host clock, relative to this chunk's arrival.
        let elapsed = listening.elapsed
        for event in events {
            switch event {
            case .onset(let time):
                let host = arrived - (elapsed - time)
                if listening.readsStrokes { onsetHost[time] = host }
                let callback = onOnset
                Task { @MainActor in callback(host) }
            case .stroke(let stroke):
                let host = onsetHost.removeValue(forKey: stroke.time) ?? arrived - (elapsed - stroke.time)
                let callback = onStroke, read = onStrokeRead
                Task { @MainActor in
                    callback(host, stroke.chord)
                    read(host, stroke)
                }
            case .strum(let reading):
                let callback = onStrum
                Task { @MainActor in callback(reading) }
            case .chord(let estimate, let matched):
                let callback = onChord
                Task { @MainActor in callback(estimate, matched) }
            }
        }
    }
}
