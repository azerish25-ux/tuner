import Foundation

/// The chord of each stroke in a strummed take: what a rhythm step needs to grade a stroke for its chord as well as
/// its timing. Feed it the microphone stream; it finds the strokes (`OnsetDetector`) and, once `delay + frame` of
/// audio has followed one, reads that one frame with a fresh `ChordRecognizer`. Nothing carries over from the stroke
/// before (no smoothing across a chord change, no ringing reading standing in for a muted stroke), and the verdict is
/// in about 0.25 s after the stroke. Body taps and fully muted strokes come back with no chord.
///
/// Each instance belongs to one serial audio-analysis queue.
public final class StrokeChords {
    /// One stroke: when it was heard (seconds of audio since the start or `reset()`) and the chord it rang, nil when
    /// it rang none (a tap on the body, a muted strum, a single string).
    public struct Stroke: Equatable, Sendable {
        public let time: Double
        public let chord: ChordEstimate?
    }

    /// Seconds after a stroke's onset where its frame starts: past the pick noise and most of the strum's spread.
    public static let delay = 0.06
    /// The frame's length in seconds (8192 samples at 48 kHz); with `delay`, the reading covers 60–230 ms after the
    /// onset.
    public static let frameSeconds = 0.17

    public let sampleRate: Double
    /// Samples per frame.
    public let frameLength: Int
    /// Seconds of audio received since the start or the last `reset()`.
    public var elapsed: Double { Double(received) / sampleRate }

    private let onsets: OnsetDetector
    private let recognizer: ChordRecognizer
    private var ring: [Float]
    private var received = 0
    /// Onsets whose frame hasn't fully arrived yet (seconds).
    private var waiting: [Double] = []

    public init(sampleRate: Double = 48000) {
        precondition(sampleRate.isFinite && sampleRate >= 8000)
        self.sampleRate = sampleRate
        // 8192 at 44.1 and 48 kHz (what the recognizer is tuned on), the same duration elsewhere.
        frameLength = sampleRate >= 40000 && sampleRate <= 50000 ? 8192 : max(1024, Int((Self.frameSeconds * sampleRate).rounded()))
        onsets = OnsetDetector(sampleRate: sampleRate)
        recognizer = ChordRecognizer(sampleRate: sampleRate)
        ring = .init(repeating: 0, count: frameLength + Int(sampleRate))
    }

    public func reset() {
        onsets.reset()
        recognizer.reset()
        received = 0
        waiting = []
    }

    /// Consumes the next chunk of audio. Returns the onsets found in it (seconds, as `OnsetDetector` reports them)
    /// and the strokes whose chord can now be read, in time order.
    public func feed(_ samples: [Float]) -> (onsets: [Double], strokes: [Stroke]) {
        let found = onsets.process(samples)
        waiting += found
        let count = ring.count
        for value in samples {
            ring[received % count] = value.isFinite ? value : 0
            received += 1
        }
        var strokes: [Stroke] = []
        var still: [Double] = []
        for time in waiting {
            let begin = Int(((time + Self.delay) * sampleRate).rounded())
            guard received >= begin + frameLength else {
                still.append(time)
                continue
            }
            // Already overwritten (a very long chunk): nothing left to read.
            guard begin >= 0, begin >= received - count else { continue }
            var frame = [Float](repeating: 0, count: frameLength)
            for i in 0..<frameLength { frame[i] = ring[(begin + i) % count] }
            recognizer.reset()
            strokes.append(Stroke(time: time, chord: recognizer.process(frame)))
        }
        waiting = still
        return (found, strokes)
    }
}
