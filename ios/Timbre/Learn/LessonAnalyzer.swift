import QuartzCore
import TimbreCore

/// Chord recognition, strokes and strums for lessons: what the pitch tracker can't hear. Fed raw microphone samples on
/// the audio analysis queue; results hop to the main actor, their times on the host clock (`CACurrentMediaTime`).
///
/// - `chords`: a running chord reading every 4096 samples (`onChord`), matched against `target`.
/// - Onsets (`onOnset`) always.
/// - `strokes`: each stroke's own chord, about 0.25 s after it (`onStroke`, `StrokeChords`), so a rhythm step can grade
///   a stroke for its chord as well as its timing.
/// - `strings`: a strum's every string at once (`onStrum`, `PolyTuner` on these pitches), so a chord step can tell
///   which strings rang.
final class LessonAnalyzer: @unchecked Sendable {
    private let lock = NSLock()
    private let wantsChords: Bool
    private var target: ChordTarget?
    private let wantsStrokes: Bool
    private let strings: [Double]?
    private var recognizer: ChordRecognizer?
    private var onsets: OnsetDetector?
    private var strokes: StrokeChords?
    private var poly: PolyTuner?
    private var pending: [Float] = []
    private var rate = 0.0
    /// The latest estimate, and whether it matches the target chord.
    private let onChord: @MainActor (ChordEstimate?, Bool) -> Void
    private let onOnset: @MainActor (CFTimeInterval) -> Void
    private let onStroke: @MainActor (CFTimeInterval, ChordEstimate?) -> Void
    private let onStrum: @MainActor (PolyReading) -> Void

    init(chords: Bool, target: ChordTarget? = nil, strokes: Bool = false, strings: [Double]? = nil,
         onChord: @escaping @MainActor (ChordEstimate?, Bool) -> Void = { _, _ in },
         onOnset: @escaping @MainActor (CFTimeInterval) -> Void = { _ in },
         onStroke: @escaping @MainActor (CFTimeInterval, ChordEstimate?) -> Void = { _, _ in },
         onStrum: @escaping @MainActor (PolyReading) -> Void = { _ in }) {
        wantsChords = chords
        self.target = target
        wantsStrokes = strokes
        self.strings = strings.flatMap { $0.isEmpty ? nil : $0 }
        self.onChord = onChord
        self.onOnset = onOnset
        self.onStroke = onStroke
        self.onStrum = onStrum
    }

    /// Listens for another chord from the next frame on: the running reading starts afresh.
    func retarget(_ target: ChordTarget?) {
        lock.lock(); defer { lock.unlock() }
        self.target = target
        recognizer?.reset()
    }

    func feed(_ samples: [Float], rate: Double) {
        let arrived = CACurrentMediaTime()
        lock.lock(); defer { lock.unlock() }
        if rate != self.rate {
            self.rate = rate
            recognizer = wantsChords ? ChordRecognizer(sampleRate: rate) : nil
            strokes = wantsStrokes ? StrokeChords(sampleRate: rate) : nil
            onsets = wantsStrokes ? nil : OnsetDetector(sampleRate: rate)
            poly = strings.map { PolyTuner(strings: $0, sampleRate: rate) }
            pending = []
        }
        if let strokes {
            // Stream seconds onto the host clock, relative to this chunk's arrival.
            let found = strokes.feed(samples)
            for time in found.onsets { post(onOnset, arrived - (strokes.elapsed - time)) }
            for stroke in found.strokes {
                let host = arrived - (strokes.elapsed - stroke.time)
                let callback = onStroke
                let chord = stroke.chord
                Task { @MainActor in callback(host, chord) }
            }
        } else if let onsets {
            for time in onsets.process(samples) { post(onOnset, arrived - (onsets.elapsed - time)) }
        }
        if let poly, let reading = poly.feed(samples) {
            let callback = onStrum
            Task { @MainActor in callback(reading) }
        }
        guard let recognizer else { return }
        pending.append(contentsOf: samples)
        let frame = 8192, hop = 4096
        while pending.count >= frame {
            let estimate = recognizer.process(Array(pending.prefix(frame)))
            pending.removeFirst(hop)
            let matched = target.map { recognizer.matches($0) } ?? false
            let callback = onChord
            Task { @MainActor in callback(estimate, matched) }
        }
    }

    private func post(_ callback: @escaping @MainActor (CFTimeInterval) -> Void, _ time: CFTimeInterval) {
        Task { @MainActor in callback(time) }
    }
}
