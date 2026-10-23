import Foundation

/// Streaming onset detection for rhythm lessons: SuperFlux-style spectral flux (log-compressed
/// magnitudes, compared with a frequency max-filtered previous frame so vibrato and beating do not
/// count as attacks), an adaptive threshold over the last half second, one frame of look-ahead for
/// peak picking, and a refractory interval so a strum or a ringing note reports one onset.
/// Feed consecutive audio in chunks of any size; each instance belongs to one serial queue.
public final class OnsetDetector {
    public let sampleRate: Double
    public let hopSize: Int
    public let windowSize: Int
    /// Shortest gap between two reported onsets (seconds).
    public let minimumInterval: Double
    /// Onset strength must exceed `thresholdMultiplier` × recent mean + `thresholdOffset`.
    public let thresholdMultiplier: Double
    public let thresholdOffset: Double
    /// Latest onset strength (mean positive log-magnitude change per bin), e.g. for a level meter.
    public private(set) var strength = 0.0
    /// Seconds of audio received since the start or the last `reset()`.
    public var elapsed: Double { Double(samplesReceived) / sampleRate }

    /// Magnitude compression: log(1 + compression · |X|), effectively logarithmic above -80 dBFS.
    static let compression = 10_000.0
    static let maxFrequency = 8000.0
    static let historySeconds = 0.5
    /// A candidate must be at least as strong as this many frames before it.
    static let peakSpan = 3
    /// Reported time sits this many hops before the end of the frame where the flux peaks.
    static let latencyHops = 1.25

    private let fft: Fft
    private let window: [Double]
    private let windowSum: Double
    private let binCount: Int
    private let historyLength: Int
    private var buffer: [Double]
    private var pending: [Float] = []
    private var real: [Double]
    private var imaginary: [Double]
    private var previous: [Double]?
    private var flux: [Double] = []
    private var frameIndex = 0
    private var samplesReceived = 0
    private var lastOnset = -Double.infinity

    public init(sampleRate: Double = 48000, hopSize: Int = 512, windowSize: Int = 2048, minimumInterval: Double = 0.06, thresholdMultiplier: Double = 2.0, thresholdOffset: Double = 0.1) {
        precondition(sampleRate.isFinite && sampleRate > 0 && hopSize > 0 && windowSize >= hopSize)
        precondition(windowSize >= 64 && windowSize & (windowSize - 1) == 0)
        self.sampleRate = sampleRate; self.hopSize = hopSize; self.windowSize = windowSize
        self.minimumInterval = minimumInterval; self.thresholdMultiplier = thresholdMultiplier; self.thresholdOffset = thresholdOffset
        fft = Fft(size: windowSize)
        let hann = (0..<windowSize).map { 0.5 - 0.5 * cos(2 * Double.pi * (Double($0) + 0.5) / Double(windowSize)) }
        window = hann
        windowSum = hann.reduce(0, +)
        binCount = max(1, min(windowSize / 2, Int(OnsetDetector.maxFrequency * Double(windowSize) / sampleRate)))
        historyLength = max(4, Int((OnsetDetector.historySeconds * sampleRate / Double(hopSize)).rounded()))
        buffer = .init(repeating: 0, count: windowSize)
        real = .init(repeating: 0, count: windowSize)
        imaginary = .init(repeating: 0, count: windowSize)
    }

    public func reset() {
        buffer = .init(repeating: 0, count: windowSize)
        pending.removeAll(keepingCapacity: true)
        previous = nil; flux.removeAll(keepingCapacity: true)
        frameIndex = 0; samplesReceived = 0; lastOnset = -.infinity; strength = 0
    }

    /// Consumes the next chunk of audio; returns the onsets found in it, in seconds since the start.
    /// An onset is reported one hop after its frame (one frame of look-ahead).
    public func process(_ samples: [Float]) -> [Double] {
        var onsets: [Double] = []
        var index = 0
        samplesReceived += samples.count
        while index < samples.count {
            let take = min(hopSize - pending.count, samples.count - index)
            pending.append(contentsOf: samples[index..<(index + take)])
            index += take
            guard pending.count == hopSize else { continue }
            buffer.removeFirst(hopSize)
            buffer.append(contentsOf: pending.map { $0.isFinite ? Double($0) : 0 })
            pending.removeAll(keepingCapacity: true)
            if let onset = analyseFrame() { onsets.append(onset) }
        }
        return onsets
    }

    private func analyseFrame() -> Double? {
        let index = frameIndex
        frameIndex += 1
        for i in 0..<windowSize { real[i] = buffer[i] * window[i]; imaginary[i] = 0 }
        fft.transform(real: &real, imaginary: &imaginary)
        let scale = 2 / windowSum
        var spectrum = [Double](repeating: 0, count: binCount)
        for k in 0..<binCount {
            let magnitude = (real[k + 1] * real[k + 1] + imaginary[k + 1] * imaginary[k + 1]).squareRoot() * scale
            spectrum[k] = log1p(Self.compression * magnitude)
        }
        var value = 0.0
        if let previous {
            for k in 0..<binCount {
                var reference = previous[k]
                if k > 0 { reference = max(reference, previous[k - 1]) }
                if k + 1 < binCount { reference = max(reference, previous[k + 1]) }
                value += max(0, spectrum[k] - reference)
            }
            value /= Double(binCount)
        }
        previous = spectrum
        strength = value
        flux.append(value)
        defer { if flux.count > historyLength + Self.peakSpan + 4 { flux.removeFirst() } }
        // Decide on the previous frame now that the one after it is known.
        guard flux.count >= 3 else { return nil }
        let candidateIndex = index - 1
        let last = flux.count - 2
        let candidate = flux[last]
        let prior = flux[max(0, last - Self.peakSpan)..<last]
        let history = flux[max(0, last - historyLength)..<last]
        let mean = history.isEmpty ? 0 : history.reduce(0, +) / Double(history.count)
        let threshold = thresholdMultiplier * mean + thresholdOffset
        let time = (Double(candidateIndex + 1) - Self.latencyHops) * Double(hopSize) / sampleRate
        let warmedUp = (candidateIndex + 1) * hopSize >= windowSize
        guard warmedUp, candidate > flux[last + 1], prior.allSatisfy({ candidate >= $0 }), candidate >= threshold,
              time - lastOnset >= minimumInterval else { return nil }
        lastOnset = time
        return time
    }
}

/// Grades played onsets against the beats a rhythm lesson expects. Pure: give it beat times and
/// onset times (seconds, same clock) and it pairs them one to one, in order, to maximise hits,
/// then perfect hits, then closeness.
public struct RhythmJudge: Sendable {
    public enum Grade: String, Codable, Sendable { case perfect, good, miss }

    public struct Judgment: Equatable, Sendable {
        /// Index of the beat in the `expected` array.
        public let beat: Int
        public let expected: Double
        /// The onset paired with this beat (latency already removed); nil for a miss.
        public let onset: Double?
        public let grade: Grade
        /// Seconds late (positive) or early (negative); nil for a miss.
        public var offset: Double? { onset.map { $0 - expected } }
    }

    public struct Report: Equatable, Sendable {
        /// One judgment per expected beat, in the order given.
        public let judgments: [Judgment]
        /// Onsets inside the exercise (first beat − good window … last beat + good window) that no beat claimed.
        public let extraOnsets: [Double]
        /// 0…1: perfect 1, good 0.5, over the beats plus any extra onsets (1 when nothing was expected).
        public let accuracy: Double
        public var perfectCount: Int { judgments.filter { $0.grade == .perfect }.count }
        public var goodCount: Int { judgments.filter { $0.grade == .good }.count }
        public var missCount: Int { judgments.filter { $0.grade == .miss }.count }
        /// Mean signed offset of the hits: negative rushes, positive drags.
        public var meanOffset: Double? {
            let offsets = judgments.compactMap(\.offset)
            return offsets.isEmpty ? nil : offsets.reduce(0, +) / Double(offsets.count)
        }
    }

    /// Inclusive limits (seconds) for perfect and good hits.
    public let perfectWindow: Double
    public let goodWindow: Double
    /// Input latency subtracted from every onset before judging.
    public let latency: Double

    /// Absorbs floating-point error so a hit exactly on a window edge counts as inside.
    private static let edge = 1e-9

    public init(perfectWindow: Double = 0.040, goodWindow: Double = 0.090, latency: Double = 0) {
        precondition(perfectWindow >= 0 && goodWindow >= perfectWindow)
        self.perfectWindow = perfectWindow; self.goodWindow = goodWindow; self.latency = latency
    }

    /// Beat times for a lesson pattern: beat positions within a bar (0 = downbeat), repeated for `bars`.
    /// `beatsPerBar` nil means 4, or longer if the pattern reaches past beat 4.
    public static func beatTimes(pattern: [Double], bpm: Double, bars: Int, beatsPerBar: Int? = nil, start: Double = 0) -> [Double] {
        guard bpm > 0, bars > 0 else { return [] }
        let positions = pattern.filter(\.isFinite).sorted()
        let perBar = beatsPerBar ?? max(4, Int(floor(positions.last ?? 0)) + 1)
        let secondsPerBeat = 60 / bpm
        return (0..<bars).flatMap { bar in positions.map { start + (Double(bar * perBar) + $0) * secondsPerBeat } }
    }

    public func grade(offset: Double) -> Grade {
        let distance = abs(offset)
        return distance <= perfectWindow + Self.edge ? .perfect : distance <= goodWindow + Self.edge ? .good : .miss
    }

    public func judge(expected: [Double], onsets: [Double]) -> Report {
        let beats = expected.indices.filter { expected[$0].isFinite }.sorted { expected[$0] < expected[$1] }
        let hits = onsets.filter(\.isFinite).map { $0 - latency }.sorted()
        var pairedOnset = [Int: Double]()
        var used = [Bool](repeating: false, count: hits.count)
        // Beats whose windows cannot reach each other are judged independently.
        var groupStart = 0
        while groupStart < beats.count {
            var groupEnd = groupStart + 1
            while groupEnd < beats.count, expected[beats[groupEnd]] - expected[beats[groupEnd - 1]] <= 2 * goodWindow { groupEnd += 1 }
            let low = expected[beats[groupStart]] - goodWindow - Self.edge
            let high = expected[beats[groupEnd - 1]] + goodWindow + Self.edge
            let candidates = hits.indices.filter { hits[$0] >= low && hits[$0] <= high }
            let group = Array(beats[groupStart..<groupEnd])
            for (beat, hit) in align(beats: group.map { expected[$0] }, onsets: candidates.map { hits[$0] }) {
                pairedOnset[group[beat]] = hits[candidates[hit]]
                used[candidates[hit]] = true
            }
            groupStart = groupEnd
        }
        let judgments = expected.indices.map { index -> Judgment in
            guard let onset = pairedOnset[index] else { return Judgment(beat: index, expected: expected[index], onset: nil, grade: .miss) }
            return Judgment(beat: index, expected: expected[index], onset: onset, grade: grade(offset: onset - expected[index]))
        }
        var extras: [Double] = []
        if let first = beats.first.map({ expected[$0] }), let last = beats.last.map({ expected[$0] }) {
            extras = hits.indices.filter { !used[$0] && hits[$0] >= first - goodWindow - Self.edge && hits[$0] <= last + goodWindow + Self.edge }.map { hits[$0] }
        }
        let points = judgments.reduce(0.0) { sum, judgment in
            switch judgment.grade { case .perfect: return sum + 1; case .good: return sum + 0.5; case .miss: return sum }
        }
        let accuracy = expected.isEmpty ? 1 : points / Double(expected.count + extras.count)
        return Report(judgments: judgments, extraOnsets: extras, accuracy: accuracy)
    }

    private struct Score: Comparable {
        var hits = 0
        var perfects = 0
        var error = 0.0
        static func < (a: Score, b: Score) -> Bool {
            if a.hits != b.hits { return a.hits < b.hits }
            if a.perfects != b.perfects { return a.perfects < b.perfects }
            return a.error > b.error
        }
    }

    /// Order-preserving one-to-one pairing of sorted beats and onsets (dynamic programming).
    private func align(beats: [Double], onsets: [Double]) -> [(beat: Int, onset: Int)] {
        let n = beats.count, m = onsets.count
        guard n > 0, m > 0 else { return [] }
        let width = m + 1
        var table = [Score](repeating: Score(), count: (n + 1) * width)
        // 0: beat unmatched, 1: onset unmatched, 2: paired.
        var move = [UInt8](repeating: 0, count: (n + 1) * width)
        for i in 1...n {
            for j in 1...m {
                var best = table[(i - 1) * width + j]
                var choice: UInt8 = 0
                let skipOnset = table[i * width + j - 1]
                if best < skipOnset { best = skipOnset; choice = 1 }
                let distance = abs(onsets[j - 1] - beats[i - 1])
                if distance <= goodWindow + Self.edge {
                    var paired = table[(i - 1) * width + j - 1]
                    paired.hits += 1
                    if distance <= perfectWindow + Self.edge { paired.perfects += 1 }
                    paired.error += distance
                    if best < paired { best = paired; choice = 2 }
                }
                table[i * width + j] = best
                move[i * width + j] = choice
            }
        }
        var pairs: [(beat: Int, onset: Int)] = []
        var i = n, j = m
        while i > 0 && j > 0 {
            switch move[i * width + j] {
            case 2: pairs.append((i - 1, j - 1)); i -= 1; j -= 1
            case 1: j -= 1
            default: i -= 1
            }
        }
        return pairs.reversed()
    }
}
