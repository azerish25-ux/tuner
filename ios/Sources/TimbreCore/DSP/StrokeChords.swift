import Foundation

/// The chord of each stroke in a strummed take: what a rhythm step needs to grade a stroke for its chord as well as
/// its timing. Feed it the microphone stream; it finds the strokes (`OnsetDetector`) and, once `delay + frame` of
/// audio has followed one, reads that one frame with a fresh `ChordRecognizer`. Nothing carries over from the stroke
/// before (no smoothing across a chord change, no ringing reading standing in for a muted stroke), and the verdict is
/// in about 0.25 s after the stroke. Body taps and fully muted strokes come back with no chord.
///
/// A stroke followed closely by the next (sixteenths, a quick up-down) is read only up to that next stroke, so the
/// two never blend into one reading; never on less than `shortestFrame`.
///
/// Each stroke also carries how hard it was played (`attack`) and what was still ringing 150 ms later (`ring`): a
/// chop or a chunk stops dead, a strum rings on, and an accent stands out from the strokes around it.
///
/// Each instance belongs to one serial audio-analysis queue.
public final class StrokeChords {
    /// One stroke: when it was heard (seconds of audio since the start or `reset()`), the chord it rang (nil when it
    /// rang none: a tap on the body, a muted strum, a single string), and its loudness.
    public struct Stroke: Equatable, Sendable {
        public let time: Double
        public let chord: ChordEstimate?
        /// The loudest 10 ms of the attack, from just before the onset to `attackSeconds` after it (RMS, full scale).
        public let attack: Double
        /// The RMS around 150 ms after the onset (`ringWindow`); nil when the next stroke came first, so what rang
        /// then can't be told from the next stroke.
        public let ring: Double?

        public init(time: Double, chord: ChordEstimate?, attack: Double = 0, ring: Double? = nil) {
            self.time = time
            self.chord = chord
            self.attack = attack
            self.ring = ring
        }

        /// The attack in dBFS (−200 for silence), for comparing strokes with each other.
        public var level: Double { attack > 1e-10 ? 20 * log10(attack) : -200 }

        /// The stroke had stopped 150 ms after it (`ring` under `StrokeChords.stopShare` of the attack): a chop, a
        /// chunk, a palm-muted scratch. Nil when that couldn't be heard (the next stroke came first, or no attack).
        public var stopped: Bool? {
            guard let ring, attack > 1e-10 else { return nil }
            return ring < StrokeChords.stopShare * attack
        }
    }

    /// Seconds after a stroke's onset where its frame starts: past the pick noise and most of the strum's spread.
    public static let delay = 0.06
    /// The frame's length in seconds (8192 samples at 48 kHz); with `delay`, the reading covers 60–230 ms after the
    /// onset.
    public static let frameSeconds = 0.17
    /// The shortest frame a stroke is read on when the next one follows closely (4096 samples at 48 kHz): below this
    /// the low strings can't be told apart.
    public static let shortestFrame = 0.085
    /// A shortened frame ends this long before the next stroke's onset, clear of its pick noise.
    public static let clearOfNext = 0.01
    /// Onsets are reported a few hops after they happen: a frame is read only once a stroke this close behind it would
    /// have been reported, so a full frame never runs into a stroke not yet known.
    public static let reportLag = 0.035
    /// The attack is the loudest 10 ms from 10 ms before the onset to this long after it (a strum's spread).
    public static let attackSeconds = 0.08
    /// Where the ring is measured: 135–165 ms after the onset.
    public static let ringWindow = 0.135...0.165
    /// A stroke whose ring is under this share of its attack has stopped (about −10 dB).
    public static let stopShare = 0.3

    public let sampleRate: Double
    /// Samples per full frame.
    public let frameLength: Int
    /// Seconds of audio received since the start or the last `reset()`.
    public var elapsed: Double { Double(received) / sampleRate }

    private let onsets: OnsetDetector
    private let recognizer: ChordRecognizer
    private var ring: [Float]
    private var received = 0
    /// Onsets whose frame hasn't fully arrived yet (seconds), in time order.
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
        for (k, time) in waiting.enumerated() {
            let next = k + 1 < waiting.count ? waiting[k + 1] : nil
            let span = readSpan(after: time, next: next)
            // The ring window must have arrived too (unless the next stroke cuts it off).
            let ringEnd = next == nil ? sample(at: time + Self.ringWindow.upperBound) : 0
            let lag = next == nil ? Int((Self.reportLag * sampleRate).rounded()) : 0
            guard received >= max(span.begin + span.length, ringEnd) + lag else {
                still.append(time)
                continue
            }
            // Already overwritten (a very long chunk): nothing left to read.
            guard span.begin >= 0, span.begin >= received - count else { continue }
            var chunk = [Float](repeating: 0, count: span.length)
            for i in 0..<span.length { chunk[i] = ring[(span.begin + i) % count] }
            recognizer.reset()
            let chord = recognizer.process(chunk)
            strokes.append(Stroke(time: time, chord: chord, attack: attackLevel(at: time), ring: ringLevel(after: time, next: next)))
        }
        waiting = still
        return (found, strokes)
    }

    // MARK: Where a stroke is read

    private func sample(at seconds: Double) -> Int { Int((seconds * sampleRate).rounded()) }

    /// The stroke's frame in samples: a full frame (`frameLength`) from `delay` after its onset, or up to just before
    /// the next stroke when that comes sooner, never shorter than `shortestFrame` (it then starts earlier, but not
    /// before 20 ms after the onset, and may reach into the next stroke only when the two are closer than that).
    func readSpan(after time: Double, next: Double?) -> (begin: Int, length: Int) {
        let begin = sample(at: time + Self.delay)
        guard let next else { return (begin, frameLength) }
        let stop = sample(at: next - Self.clearOfNext)
        guard stop < begin + frameLength else { return (begin, frameLength) }
        let shortest = min(frameLength, max(1024, sample(at: Self.shortestFrame)))
        var start = begin
        if stop - start < shortest { start = max(sample(at: time + 0.02), stop - shortest) }
        return (start, min(frameLength, max(shortest, stop - start)))
    }

    /// The loudest 10 ms RMS (5 ms apart) from 10 ms before the onset to `attackSeconds` after it.
    private func attackLevel(at time: Double) -> Double {
        let width = max(1, sample(at: 0.01))
        let step = max(1, width / 2)
        var from = sample(at: time - 0.01)
        let last = sample(at: time + Self.attackSeconds) - width
        var loudest = 0.0
        while from <= last {
            loudest = max(loudest, rms(from: from, count: width))
            from += step
        }
        return loudest
    }

    /// The RMS in `ringWindow` after the onset; nil when the next stroke comes before the window has ended.
    private func ringLevel(after time: Double, next: Double?) -> Double? {
        if let next, next < time + Self.ringWindow.upperBound + Self.clearOfNext { return nil }
        let from = sample(at: time + Self.ringWindow.lowerBound)
        let to = sample(at: time + Self.ringWindow.upperBound)
        return rms(from: from, count: max(1, to - from))
    }

    /// RMS of `count` samples from stream sample `from`, over what the ring still holds (zeros outside it).
    private func rms(from: Int, count: Int) -> Double {
        let size = ring.count
        var sum = 0.0
        var n = 0
        for index in from..<(from + count) where index >= 0 && index < received && index >= received - size {
            let value = Double(ring[index % size])
            sum += value * value
            n += 1
        }
        return n > 0 ? (sum / Double(n)).squareRoot() : 0
    }
}
