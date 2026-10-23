import QuartzCore
import TimbreCore

/// Chord recognition and onset detection for lessons. Fed raw microphone samples on the audio
/// analysis queue; results hop to the main actor. Strums and chords the pitch tracker can't hear.
final class LessonAnalyzer: @unchecked Sendable {
    private let lock = NSLock()
    private let wantsChords: Bool
    private let target: ChordTarget?
    private var recognizer: ChordRecognizer?
    private var onsets: OnsetDetector?
    private var pending: [Float] = []
    private var rate = 0.0
    /// The latest estimate, and whether it matches the target chord.
    private let onChord: @MainActor (ChordEstimate?, Bool) -> Void
    private let onOnset: @MainActor (CFTimeInterval) -> Void

    init(chords: Bool, target: ChordTarget? = nil, onChord: @escaping @MainActor (ChordEstimate?, Bool) -> Void = { _, _ in },
         onOnset: @escaping @MainActor (CFTimeInterval) -> Void = { _ in }) {
        wantsChords = chords
        self.target = target
        self.onChord = onChord
        self.onOnset = onOnset
    }

    func feed(_ samples: [Float], rate: Double) {
        let arrived = CACurrentMediaTime()
        lock.lock(); defer { lock.unlock() }
        if rate != self.rate {
            self.rate = rate
            recognizer = wantsChords ? ChordRecognizer(sampleRate: rate) : nil
            onsets = OnsetDetector(sampleRate: rate)
            pending = []
        }
        if let onsets {
            // Onset times are stream seconds; place them on the host clock relative to this chunk's arrival.
            for time in onsets.process(samples) {
                let host = arrived - (onsets.elapsed - time)
                let callback = onOnset
                Task { @MainActor in callback(host) }
            }
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
}
