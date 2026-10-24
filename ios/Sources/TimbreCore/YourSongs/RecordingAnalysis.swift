import Foundation

/// What Timbre heard in a recording of a song: its tempo, its beats, and the chord of each bar (or two, when a bar
/// changes halfway). A draft for the player to check by ear, never a transcription.
public struct RecordingAnalysis: Equatable, Sendable {
    public struct Bar: Equatable, Sendable {
        /// Seconds from the start of the recording.
        public let start: Double
        public let end: Double
        /// The bar's chords as symbols ("G", "Em7"): one, or two when it changes at the half-bar; nil where no chord
        /// was clear (silence, a drum break, speech).
        public let chords: [String?]
        /// How well the bar's sound fits its chord, 0…1 (the lowest of a split bar's two).
        public let confidence: Double

        public init(start: Double, end: Double, chords: [String?], confidence: Double) {
            self.start = start; self.end = end; self.chords = chords; self.confidence = confidence
        }
    }

    public let bpm: Double
    public let beatsPerBar: Int
    /// Every beat found, in seconds.
    public let beats: [Double]
    public let bars: [Bar]
    /// Seconds of audio analysed.
    public let duration: Double
    /// The key the chords suggest ("G", "Em"), when they suggest one.
    public let key: String?

    public init(bpm: Double, beatsPerBar: Int, beats: [Double], bars: [Bar], duration: Double, key: String?) {
        self.bpm = bpm; self.beatsPerBar = beatsPerBar; self.beats = beats; self.bars = bars; self.duration = duration; self.key = key
    }
}

// MARK: - Tempo

/// The tempo of an onset-strength envelope: its autocorrelation over 50–220 BPM, weighted toward 120 BPM over a span
/// of about an octave (the tempo people tap to), refined between lags, then moved up an octave when the beat at
/// double speed is nearly as strong (a song at 140 heard at 70 otherwise).
public enum TempoEstimator {
    public static func estimate(_ envelope: [Double], frameRate: Double, range: ClosedRange<Double> = 50...220,
                                center: Double = 120, octaveSpread: Double = 1) -> Double? {
        let n = envelope.count
        guard n > 16, frameRate > 0, range.lowerBound > 0 else { return nil }
        // Above a one-second running mean, so a loud passage doesn't read as a run of onsets.
        let window = max(1, Int(frameRate.rounded()))
        var prefix = [Double](repeating: 0, count: n + 1)
        for i in 0..<n { prefix[i + 1] = prefix[i] + (envelope[i].isFinite ? envelope[i] : 0) }
        var x = [Double](repeating: 0, count: n)
        for i in 0..<n {
            let low = max(0, i - window / 2), high = min(n, i + window / 2 + 1)
            let mean = (prefix[high] - prefix[low]) / Double(high - low)
            x[i] = max(0, (envelope[i].isFinite ? envelope[i] : 0) - mean)
        }
        func correlation(_ lag: Int) -> Double {
            guard lag >= 1, lag < n else { return 0 }
            var sum = 0.0
            for i in 0..<(n - lag) { sum += x[i] * x[i + lag] }
            return sum / Double(n - lag)
        }
        let minLag = max(1, Int((60 * frameRate / range.upperBound).rounded(.down)))
        let maxLag = min(n - 1, Int((60 * frameRate / range.lowerBound).rounded(.up)))
        guard maxLag > minLag + 1 else { return nil }
        var weighted: [Double] = []
        for lag in minLag...maxLag {
            let bpm = 60 * frameRate / Double(lag)
            let octaves = log2(bpm / center) / octaveSpread
            weighted.append(correlation(lag) * exp(-0.5 * octaves * octaves))
        }
        guard let best = weighted.indices.max(by: { weighted[$0] < weighted[$1] }), weighted[best] > 0 else { return nil }
        var lag = Double(minLag + best)
        if best > 0, best < weighted.count - 1 {
            let a = weighted[best - 1], b = weighted[best], c = weighted[best + 1]
            let curve = a - 2 * b + c
            if curve < 0 { lag += min(0.5, max(-0.5, 0.5 * (a - c) / curve)) }
        }
        // Double time when its beat is nearly as strong and still a tempo people play at.
        let half = lag / 2
        let halfLag = Int(half.rounded())
        if halfLag >= 2, 60 * frameRate / half <= 190 {
            let atHalf = max(correlation(halfLag - 1), correlation(halfLag), correlation(halfLag + 1))
            let atFull = correlation(Int(lag.rounded()))
            if atFull > 0, atHalf >= 0.55 * atFull { lag = half }
        }
        return 60 * frameRate / lag
    }
}

// MARK: - Beats

/// Beat tracking by dynamic programming (Ellis, 2007): every frame's best chain of beats ending there, a beat scoring
/// its onset strength and each gap paying for how far it strays from the tempo's period (on a log scale), so the beats
/// follow a recording that speeds up or slows down while staying on its pulse.
public enum BeatTracker {
    /// How strictly gaps keep to the period.
    public static let tightness = 100.0

    /// Beat positions (frame indices, rising) in `envelope` at about `bpm`.
    public static func track(_ envelope: [Double], frameRate: Double, bpm: Double, tightness: Double = BeatTracker.tightness) -> [Int] {
        let n = envelope.count
        guard n > 4, bpm > 0, frameRate > 0 else { return [] }
        let period = 60 * frameRate / bpm
        guard period >= 2, period * 2 < Double(n) else { return [] }
        let clean = envelope.map { $0.isFinite ? max(0, $0) : 0 }
        let mean = clean.reduce(0, +) / Double(n)
        let deviation = (clean.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(n)).squareRoot()
        let e = deviation > 0 ? clean.map { $0 / deviation } : clean
        // Onsets smoothed by a narrow Gaussian (a 32nd of the period), so a beat a frame off still lands.
        let sigma = period / 32
        let reach = max(1, Int((3 * sigma).rounded(.up)))
        let kernel = (-reach...reach).map { exp(-0.5 * pow(Double($0) / sigma, 2)) }
        var local = [Double](repeating: 0, count: n)
        for t in 0..<n {
            var sum = 0.0
            for k in -reach...reach where t + k >= 0 && t + k < n { sum += e[t + k] * kernel[k + reach] }
            local[t] = sum
        }
        let longest = Int((2 * period).rounded()), shortest = max(1, Int((period / 2).rounded()))
        guard longest > shortest else { return [] }
        let penalty = (shortest...longest).map { gap -> Double in
            let stretch = log(Double(gap) / period)
            return -tightness * stretch * stretch
        }
        var cumulative = [Double](repeating: 0, count: n)
        var previous = [Int](repeating: -1, count: n)
        let strongest = local.max() ?? 0
        var started = false
        for t in 0..<n {
            var best = -Double.infinity
            var from = -1
            let start = max(0, t - longest), end = t - shortest
            if end >= start {
                for tau in start...end {
                    let value = cumulative[tau] + penalty[t - tau - shortest]
                    if value > best { best = value; from = tau }
                }
            }
            cumulative[t] = local[t] + (from >= 0 ? best : 0)
            // Chains start at the first real onset, not in the silence before it.
            if !started && local[t] < 0.01 * strongest {
                previous[t] = -1
            } else {
                previous[t] = from
                started = true
            }
        }
        // The last beat: the latest peak of the cumulative score that is at least half the typical peak.
        var peaks: [Int] = []
        if n >= 3 {
            for t in 1..<(n - 1) where cumulative[t] >= cumulative[t - 1] && cumulative[t] >= cumulative[t + 1] { peaks.append(t) }
        }
        guard !peaks.isEmpty else { return [] }
        let sortedPeaks = peaks.map { cumulative[$0] }.sorted()
        let median = sortedPeaks[sortedPeaks.count / 2]
        guard let last = peaks.last(where: { cumulative[$0] >= 0.5 * median }) else { return [] }
        var beats = [last]
        var cursor = previous[last]
        while cursor >= 0 {
            beats.append(cursor)
            cursor = previous[cursor]
        }
        beats.reverse()
        // Weak beats at either end (the fade-in, the ringing out) go.
        let rms = (beats.reduce(0.0) { $0 + local[$1] * local[$1] } / Double(beats.count)).squareRoot()
        while let first = beats.first, local[first] < 0.5 * rms { beats.removeFirst() }
        while let final = beats.last, local[final] < 0.5 * rms { beats.removeLast() }
        return beats
    }

    /// The tempo of beat times by a straight-line fit (steadier than the median gap, which frames quantise).
    public static func bpm(of beats: [Double]) -> Double? {
        let n = beats.count
        guard n >= 3 else { return nil }
        let xm = Double(n - 1) / 2
        let ym = beats.reduce(0, +) / Double(n)
        var top = 0.0, bottom = 0.0
        for (i, time) in beats.enumerated() {
            top += (Double(i) - xm) * (time - ym)
            bottom += (Double(i) - xm) * (Double(i) - xm)
        }
        guard bottom > 0, top > 0 else { return nil }
        return 60 / (top / bottom)
    }
}

// MARK: - The recording, bar by bar

/// Listens through a recording (fed in order, any chunk size, mono) and finds its tempo, beats, bars and the chord of
/// each bar: onsets with the lessons' `OnsetDetector`, chords with their `ChordRecognizer` (no smoothing: each frame
/// stands alone and frames are summed per beat), the downbeat where the harmony changes most, a bar that changes
/// halfway split in two, and a chord kept from the bar before when it fits nearly as well (so a fill doesn't read as a
/// change). Not thread-safe: one analysis on one queue.
public final class RecordingAnalyzer {
    public let sampleRate: Double
    private let hop: Int
    private let chromaLength: Int
    private let detector: OnsetDetector
    private let recognizer: ChordRecognizer
    private var onsetPending: [Float] = []
    private var chromaPending: [Float] = []
    private var envelope: [Double] = []
    private var chroma: [[Double]] = []
    private var bass: [Int?] = []
    private var received = 0

    /// A chord needs at least this fit to be named; below it the bar is "no chord".
    public static let minimumConfidence = 0.3

    public init?(sampleRate: Double) {
        guard sampleRate.isFinite, sampleRate >= 8000, sampleRate <= 384_000 else { return nil }
        self.sampleRate = sampleRate
        hop = sampleRate > 30_000 ? 512 : 256
        detector = OnsetDetector(sampleRate: sampleRate, hopSize: hop, windowSize: hop * 4)
        // Frames of about 0.17 s: 8192 samples at 44.1 or 48 kHz, as the lessons listen.
        var length = 1024
        while Double(length * 2) <= 0.2 * sampleRate { length *= 2 }
        chromaLength = length
        recognizer = ChordRecognizer(sampleRate: sampleRate, smoothing: 0, minimumConfidence: 0)
    }

    /// Seconds received so far.
    public var seconds: Double { Double(received) / sampleRate }

    public func feed(_ samples: [Float]) {
        guard !samples.isEmpty else { return }
        received += samples.count
        onsetPending.append(contentsOf: samples)
        var start = 0
        while onsetPending.count - start >= hop {
            _ = detector.process(Array(onsetPending[start..<(start + hop)]))
            envelope.append(detector.strength)
            start += hop
        }
        onsetPending.removeFirst(start)
        chromaPending.append(contentsOf: samples)
        start = 0
        while chromaPending.count - start >= chromaLength {
            _ = recognizer.process(Array(chromaPending[start..<(start + chromaLength)]))
            chroma.append(recognizer.chroma)
            bass.append(recognizer.bassPitchClass)
            start += chromaLength
        }
        chromaPending.removeFirst(start)
    }

    /// The onset envelope frame `index`'s time: the detector reports an onset a little before the end of its frame.
    private func envelopeTime(_ index: Int) -> Double {
        (Double(index) + 1 - OnsetDetector.latencyHops) * Double(hop) / sampleRate
    }

    /// The analysis, in bars of `beatsPerBar`; nil for a recording too short (under six seconds) or without a beat.
    public func finish(beatsPerBar: Int = 4) -> RecordingAnalysis? {
        let meter = max(2, min(12, beatsPerBar))
        let duration = seconds
        let frameRate = sampleRate / Double(hop)
        guard duration >= 6, envelope.count > 32,
              let estimate = TempoEstimator.estimate(envelope, frameRate: frameRate) else { return nil }
        let frames = BeatTracker.track(envelope, frameRate: frameRate, bpm: estimate)
        guard frames.count >= 2 * meter else { return nil }
        let beats = frames.map { max(0, envelopeTime($0)) }
        let bpm = BeatTracker.bpm(of: beats) ?? estimate
        let period = 60 / bpm
        let beatChroma = beats.indices.map { summedChroma(from: beats[$0], to: $0 + 1 < beats.count ? beats[$0 + 1] : beats[$0] + period) }
        let strongest = envelope.max() ?? 1
        let accents = frames.map { strongest > 0 ? envelope[$0] / strongest : 0 }
        let phase = downbeat(beatChroma.map { $0.chroma }, accents: accents, meter: meter)
        var bars: [RecordingAnalysis.Bar] = []
        var targets: [[ChordTarget?]] = []
        var first = phase
        var previous: ChordTarget?
        while first + meter <= beats.count {
            let start = beats[first]
            let end = first + meter < beats.count ? beats[first + meter] : beats[first + meter - 1] + period
            let labelled = label(bar: Array(beatChroma[first..<(first + meter)]), meter: meter, previous: previous)
            targets.append(labelled.targets)
            bars.append(RecordingAnalysis.Bar(start: start, end: end, chords: [], confidence: labelled.confidence))
            previous = labelled.targets.last ?? nil
            first += meter
        }
        guard !bars.isEmpty else { return nil }
        // Spelled for the key the chords suggest.
        let common = targets.flatMap { $0 }.compactMap { $0 }.map { Self.symbol($0, names: ChordSpelling.commonNames) }
        let key = ChordSpelling.guessKey(common)
        let names = key.map { ChordSpelling.prefersFlats(tonic: $0.tonic, minor: $0.minor) ? ChordSpelling.flatNames : ChordSpelling.sharpNames }
            ?? ChordSpelling.commonNames
        let spelled = zip(bars, targets).map { bar, chords in
            RecordingAnalysis.Bar(start: bar.start, end: bar.end, chords: chords.map { $0.map { Self.symbol($0, names: names).text } },
                                  confidence: bar.confidence)
        }
        return RecordingAnalysis(bpm: bpm, beatsPerBar: meter, beats: beats, bars: spelled, duration: duration,
                                 key: key.map { ChordSpelling.keyName(tonic: $0.tonic, minor: $0.minor) })
    }

    static func symbol(_ target: ChordTarget, names: [String]) -> ChordSymbol {
        ChordSymbol(root: target.root, rootName: names[target.root], suffix: target.quality.suffix)
    }

    /// The chroma frames between two times summed (unit vectors, so loud and quiet frames count alike), and the bass
    /// heard most often among them.
    private func summedChroma(from start: Double, to end: Double) -> (chroma: [Double], bass: Int?) {
        let frameSeconds = Double(chromaLength) / sampleRate
        var sum = [Double](repeating: 0, count: 12)
        var votes: [Int: Int] = [:]
        var used = 0
        if !chroma.isEmpty {
            for j in chroma.indices {
                let center = (Double(j) + 0.5) * frameSeconds
                guard center >= start && center < end else { continue }
                for k in 0..<12 { sum[k] += chroma[j][k] }
                if let pitch = bass[j] { votes[pitch, default: 0] += 1 }
                used += 1
            }
            if used == 0 {
                // A beat shorter than a frame: the frame it falls in.
                let j = min(chroma.count - 1, max(0, Int((start / frameSeconds).rounded(.down))))
                sum = chroma[j]
                if let pitch = bass[j] { votes[pitch] = 1 }
            }
        }
        return (sum, votes.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }?.key)
    }

    /// The beat the bars start on (0 ..< meter): where the harmony changes most across the bar lines, with a little
    /// weight for the louder onset a downbeat often has.
    private func downbeat(_ beats: [[Double]], accents: [Double], meter: Int) -> Int {
        var best = 0
        var bestScore = -Double.infinity
        for phase in 0..<min(meter, beats.count) {
            var score = 0.0
            var count = 0
            var k = phase
            while k < beats.count {
                if k >= 1 {
                    score += Self.change(beats[k - 1], beats[k]) + 0.3 * accents[k]
                    count += 1
                }
                k += meter
            }
            let mean = count > 0 ? score / Double(count) : 0
            if mean > bestScore + 1e-9 { bestScore = mean; best = phase }
        }
        return best
    }

    /// How different two chromas are: 1 − their cosine; 0 when either is silent.
    static func change(_ a: [Double], _ b: [Double]) -> Double {
        let na = a.reduce(0) { $0 + $1 * $1 }.squareRoot(), nb = b.reduce(0) { $0 + $1 * $1 }.squareRoot()
        guard na > 0, nb > 0 else { return 0 }
        let dot = zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
        return 1 - dot / (na * nb)
    }

    static func normalized(_ chroma: [Double]) -> [Double] {
        let length = chroma.reduce(0) { $0 + $1 * $1 }.squareRoot()
        return length > 0 ? chroma.map { $0 / length } : chroma
    }

    /// A bar's chord (or its two halves' chords) from its beats' chromas.
    private func label(bar beats: [(chroma: [Double], bass: Int?)], meter: Int, previous: ChordTarget?) -> (targets: [ChordTarget?], confidence: Double) {
        func read(_ part: ArraySlice<(chroma: [Double], bass: Int?)>) -> (target: ChordTarget, confidence: Double, chroma: [Double])? {
            var sum = [Double](repeating: 0, count: 12)
            var votes: [Int: Int] = [:]
            for beat in part {
                for k in 0..<12 { sum[k] += beat.chroma[k] }
                if let pitch = beat.bass { votes[pitch, default: 0] += 1 }
            }
            let chroma = Self.normalized(sum)
            guard chroma.contains(where: { $0 > 0 }) else { return nil }
            let bass = votes.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }?.key
            guard let best = ChordRecognizer.bestChord(chroma: chroma, bass: bass) else { return nil }
            return (best.target, best.confidence, chroma)
        }
        let reading = read(beats[...])
        if meter % 2 == 0, meter >= 2, let firstHalf = read(beats[0..<(meter / 2)]), let secondHalf = read(beats[(meter / 2)...]),
           firstHalf.target != secondHalf.target, firstHalf.confidence >= 0.55, secondHalf.confidence >= 0.55,
           (reading?.confidence ?? 0) < min(firstHalf.confidence, secondHalf.confidence) - 0.08 {
            return ([firstHalf.target, secondHalf.target], min(firstHalf.confidence, secondHalf.confidence))
        }
        guard let whole = reading, whole.confidence >= Self.minimumConfidence else { return ([nil], reading?.confidence ?? 0) }
        if let previous, previous != whole.target,
           ChordRecognizer.templateConfidence(chroma: whole.chroma, target: previous) >= whole.confidence - 0.03 {
            return ([previous], whole.confidence)
        }
        return ([whole.target], whole.confidence)
    }
}

// MARK: - A draft chart

/// A chart written from an analysis: the details it found (key, tempo, time), then the bars four to a line
/// ("| [G] | [G] | [D] [A] | [Em] |"), a bar of no clear chord as N.C., and a blank line every eight bars.
public enum DraftChart {
    public static func chordPro(_ analysis: RecordingAnalysis, title: String, artist: String? = nil, barsPerLine: Int = 4) -> String {
        func clean(_ text: String) -> String { text.replacingOccurrences(of: "}", with: ")").replacingOccurrences(of: "\n", with: " ") }
        var lines = ["{title: \(clean(title))}"]
        if let artist, !artist.isEmpty { lines.append("{artist: \(clean(artist))}") }
        if let key = analysis.key { lines.append("{key: \(key)}") }
        lines.append("{tempo: \(Int(analysis.bpm.rounded()))}")
        lines.append("{time: \(analysis.beatsPerBar)/4}")
        lines.append("")
        let perLine = max(1, barsPerLine)
        var row = 0
        var index = 0
        while index < analysis.bars.count {
            let chunk = analysis.bars[index..<min(index + perLine, analysis.bars.count)]
            let cells = chunk.map { bar in bar.chords.map { "[\($0 ?? "N.C.")]" }.joined(separator: " ") }
            lines.append("| " + cells.joined(separator: " | ") + " |")
            row += 1
            index += perLine
            if row % 2 == 0 && index < analysis.bars.count { lines.append("") }
        }
        return lines.joined(separator: "\n")
    }

    /// When each chord of the draft changes, matching its `chordSequence` one to one (an N.C. bar has no chord to time).
    public static func timings(_ analysis: RecordingAnalysis) -> [Double] {
        var out: [Double] = []
        for bar in analysis.bars {
            let count = max(1, bar.chords.count)
            for (i, chord) in bar.chords.enumerated() {
                guard let chord, ChordSymbol(chord) != nil else { continue }
                out.append(bar.start + (bar.end - bar.start) * Double(i) / Double(count))
            }
        }
        return out
    }
}
