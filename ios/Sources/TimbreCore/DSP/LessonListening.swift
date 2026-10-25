import Foundation

/// What a lesson hears in the microphone stream besides pitch, in stream time: the analysis the app's
/// `LessonAnalyzer` runs on the audio queue before it moves each result onto the host clock and the main actor. Kept
/// here, in one place, so a recording fed through it in the microphone tap's own buffers (`AudioClip`) takes exactly
/// the path a live take does.
///
/// - `chords`: a running chord reading every 4096 samples (8192-sample frames), matched against `target`.
/// - Onsets, always: from the stroke reader when there is one, else from an `OnsetDetector` of its own.
/// - `strokes`: each stroke's own chord, attack and ring about 0.25 s after it (`StrokeChords`).
/// - `strings`: a strum's every string at once (`PolyTuner` on these pitches, Hz).
///
/// A change of sample rate starts every analysis afresh. Each instance belongs to one serial audio-analysis queue.
public final class LessonListening {
    /// One thing heard, its time in seconds of audio since the analysis (re)started at this sample rate.
    public enum Event: Equatable {
        /// The running chord reading, and whether it matches the target.
        case chord(ChordEstimate?, matched: Bool)
        /// A stroke or a note began.
        case onset(Double)
        /// A stroke read: its chord, attack and ring (`StrokeChords.Stroke.time` is its onset).
        case stroke(StrokeChords.Stroke)
        /// One strum, every string at once.
        case strum(PolyReading)
    }

    public let readsChords: Bool
    public let readsStrokes: Bool
    /// The pitches (Hz) a strum is read on, lowest string first; nil reads none.
    public let strings: [Double]?
    /// The chord the running reading is matched against.
    public private(set) var target: ChordTarget?
    /// The sample rate the analysis runs at (0 before the first audio).
    public private(set) var sampleRate = 0.0
    /// Seconds of audio fed since the analysis (re)started at this sample rate.
    public var elapsed: Double { sampleRate > 0 ? Double(received) / sampleRate : 0 }

    private var recognizer: ChordRecognizer?
    private var onsets: OnsetDetector?
    private var strokes: StrokeChords?
    private var poly: PolyTuner?
    private var pending: [Float] = []
    private var received = 0

    /// The running chord reading's frame and hop, in samples.
    public static let chordFrame = 8192
    public static let chordHop = 4096

    public init(chords: Bool, target: ChordTarget? = nil, strokes: Bool = false, strings: [Double]? = nil) {
        readsChords = chords
        self.target = target
        readsStrokes = strokes
        self.strings = strings.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Matches the running reading against another chord from the next frame on, starting it afresh.
    public func retarget(_ target: ChordTarget?) {
        self.target = target
        recognizer?.reset()
    }

    /// Consumes the next chunk of audio at `rate` and returns what it held, in this order: onsets, strokes read,
    /// a strum, chord readings.
    public func feed(_ samples: [Float], rate: Double) -> [Event] {
        guard rate.isFinite, rate >= 8000 else { return [] }
        if rate != sampleRate { start(at: rate) }
        received += samples.count
        var events: [Event] = []
        if let strokes {
            let found = strokes.feed(samples)
            events += found.onsets.map { Event.onset($0) }
            events += found.strokes.map { Event.stroke($0) }
        } else if let onsets {
            events += onsets.process(samples).map { Event.onset($0) }
        }
        if let poly, let reading = poly.feed(samples) { events.append(.strum(reading)) }
        guard let recognizer else { return events }
        pending.append(contentsOf: samples)
        while pending.count >= Self.chordFrame {
            let estimate = recognizer.process(Array(pending.prefix(Self.chordFrame)))
            pending.removeFirst(Self.chordHop)
            let matched = target.map { recognizer.matches($0) } ?? false
            events.append(.chord(estimate, matched: matched))
        }
        return events
    }

    /// Every analysis afresh at `rate`.
    private func start(at rate: Double) {
        sampleRate = rate
        received = 0
        pending = []
        recognizer = readsChords ? ChordRecognizer(sampleRate: rate) : nil
        strokes = readsStrokes ? StrokeChords(sampleRate: rate) : nil
        onsets = readsStrokes ? nil : OnsetDetector(sampleRate: rate)
        poly = strings.map { PolyTuner(strings: $0, sampleRate: rate) }
    }
}
