import Foundation

/// A chord a lesson asks for, or one the recognizer heard: root pitch class and quality.
public struct ChordTarget: Hashable, Sendable, CustomStringConvertible {
    /// Pitch class 0–11 (C = 0).
    public let root: Int
    public let quality: ChordRecognizer.Quality

    public init(root: Int, quality: ChordRecognizer.Quality) {
        self.root = PitchMath.pitchClass(midi: root)
        self.quality = quality
    }

    /// Bridges lesson data that names the quality by `ChordFormula.id` ("maj", "min", "7", …).
    public init?(root: Int, formulaId: String) {
        guard let quality = ChordRecognizer.Quality(formulaId: formulaId) else { return nil }
        self.init(root: root, quality: quality)
    }

    /// Parses chord symbols such as "C", "Am", "F#7", "Bbmaj7", "Em7", "Dsus2", "Asus4", "E5".
    public init?(symbol: String) {
        var rest = Substring(symbol.trimmingCharacters(in: .whitespaces))
        let letters: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard let letter = rest.first, var root = letters[letter] else { return nil }
        rest = rest.dropFirst()
        if let accidental = rest.first, accidental == "#" || accidental == "♯" { root += 1; rest = rest.dropFirst() }
        else if let accidental = rest.first, accidental == "b" || accidental == "♭" { root -= 1; rest = rest.dropFirst() }
        let suffixes: [String: ChordRecognizer.Quality] = [
            "": .major, "maj": .major, "M": .major,
            "m": .minor, "min": .minor, "-": .minor,
            "7": .dominant7, "dom7": .dominant7,
            "maj7": .major7, "M7": .major7, "Δ7": .major7, "Δ": .major7,
            "m7": .minor7, "min7": .minor7, "-7": .minor7,
            "sus2": .sus2, "sus4": .sus4, "sus": .sus4, "5": .power,
        ]
        guard let quality = suffixes[String(rest)] else { return nil }
        self.init(root: root, quality: quality)
    }

    /// The pitch classes the chord is made of.
    public var pitchClasses: Set<Int> { Set(quality.intervals.map { (root + $0) % 12 }) }
    public var symbol: String { NoteNames.name(root) + quality.suffix }
    public var description: String { symbol }
}

/// One chord reading: the best template for the smoothed chroma of the frames heard so far.
public struct ChordEstimate: Equatable, Sendable {
    public let root: Int
    public let quality: ChordRecognizer.Quality
    /// 0…1: how well the chroma fits the chord's template (1 = only the chord's notes, evenly).
    public let confidence: Double
    /// Twelve pitch-class weights (C first), unit length, after overtone removal and smoothing.
    public let chroma: [Double]
    /// Pitch class of the lowest sounding note, when one stands out.
    public let bass: Int?
    public var target: ChordTarget { ChordTarget(root: root, quality: quality) }
    public var symbol: String { target.symbol }
}

/// Real-time chord recognition for chord lessons: feed mono frames of 4096–8192 samples
/// (hop about half a frame) and read back the chord being strummed.
///
/// Pipeline per frame: Hann window and zero-padded FFT; spectral peaks above the band's noise floor
/// (parabolic interpolation); global tuning offset from the peaks; peaks folded onto a semitone grid
/// (C2…C7); overtones removed from low to high with a harmonic model, so the third and fifth
/// harmonics of each string do not pose as extra chord tones; semitones folded into a compressed
/// 12-bin chroma; exponential smoothing across frames (reset by silence or a new, louder strum);
/// cosine match against major, minor, 7, maj7, m7, sus2, sus4 and power-chord templates on all
/// 12 roots, with a small preference for the root in the bass. Each instance belongs to one serial
/// audio-analysis queue.
public final class ChordRecognizer {
    public enum Quality: String, CaseIterable, Codable, Sendable {
        case major, minor, dominant7, major7, minor7, sus2, sus4, power

        public var intervals: [Int] {
            switch self {
            case .major: return [0, 4, 7]
            case .minor: return [0, 3, 7]
            case .dominant7: return [0, 4, 7, 10]
            case .major7: return [0, 4, 7, 11]
            case .minor7: return [0, 3, 7, 10]
            case .sus2: return [0, 2, 7]
            case .sus4: return [0, 5, 7]
            case .power: return [0, 7]
            }
        }

        /// Chord-symbol suffix: "", "m", "7", "maj7", "m7", "sus2", "sus4", "5".
        public var suffix: String {
            switch self {
            case .major: return ""
            case .minor: return "m"
            case .dominant7: return "7"
            case .major7: return "maj7"
            case .minor7: return "m7"
            case .sus2: return "sus2"
            case .sus4: return "sus4"
            case .power: return "5"
            }
        }

        /// The matching `ChordFormula.id`.
        public var formulaId: String {
            switch self {
            case .major: return "maj"
            case .minor: return "min"
            default: return suffix
            }
        }

        public init?(formulaId: String) {
            guard let quality = Quality.allCases.first(where: { $0.formulaId == formulaId }) else { return nil }
            self = quality
        }
    }

    /// Relative strength assumed for harmonics 2…8 of each note when removing overtones.
    static let harmonicGains: [Double] = [0.6, 0.5, 0.36, 0.3, 0.3, 0.3, 0.25]
    /// Rank bonus for chords whose root is the lowest note heard.
    static let bassBonus = 0.12
    /// `matches` accepts a target this close (in confidence) to the best reading.
    static let matchTolerance = 0.05
    /// A spectral peak must stand this far above the band's median magnitude…
    static let peakFloorFactor = 4.0
    /// …and within 60 dB of the strongest peak.
    static let dynamicRange = 0.001
    /// Chroma bins below this fraction of the strongest bin count as empty.
    static let chromaFloor = 0.1
    /// A level jump this large (dB) between frames is a new strum: smoothing restarts.
    static let restrikeDb = 6.0

    public let sampleRate: Double
    public let minFrequency: Double
    public let maxFrequency: Double
    public let silenceDbfs: Double
    /// Weight of the earlier frames in the running average (0 = no smoothing).
    public let smoothing: Double
    /// Readings below this confidence are reported as no chord.
    public let minimumConfidence: Double

    /// Smoothed chroma of the frames so far (zeros before the first chord).
    public private(set) var chroma = [Double](repeating: 0, count: 12)
    /// Pitch class of the lowest note in the smoothed reading.
    public private(set) var bassPitchClass: Int?
    /// The last reading `process` returned.
    public private(set) var current: ChordEstimate?

    private let lowestNote: Int
    private let noteCount: Int
    private let harmonicOffsets: [Int]
    private let harmonicWeights: [Double]
    private var smoothedNotes: [Double]?
    private var smoothedSpectrum: [Double]?
    private var previousLevel = -200.0
    private var transform: Transform?

    private final class Transform {
        let frameLength: Int
        let fft: Fft
        let window: [Double]
        let windowSum: Double
        var real: [Double]
        var imaginary: [Double]
        init(frameLength: Int) {
            self.frameLength = frameLength
            let size = Fft.nextPowerOfTwo(2 * frameLength)
            fft = Fft(size: size)
            let hann = (0..<frameLength).map { 0.5 - 0.5 * cos(2 * Double.pi * (Double($0) + 0.5) / Double(frameLength)) }
            window = hann
            windowSum = hann.reduce(0, +)
            real = .init(repeating: 0, count: size)
            imaginary = .init(repeating: 0, count: size)
        }
    }

    public init(sampleRate: Double = 48000, minFrequency: Double = 65, maxFrequency: Double = 2100, silenceDbfs: Double = -60, smoothing: Double = 0.5, minimumConfidence: Double = 0.4) {
        precondition(sampleRate.isFinite && sampleRate > 0 && minFrequency > 0 && maxFrequency > minFrequency && maxFrequency < sampleRate / 2)
        precondition(smoothing >= 0 && smoothing < 1)
        self.sampleRate = sampleRate; self.minFrequency = minFrequency; self.maxFrequency = maxFrequency
        self.silenceDbfs = silenceDbfs; self.smoothing = smoothing; self.minimumConfidence = minimumConfidence
        let lowest = Int(floor(PitchMath.midi(frequency: minFrequency)))
        lowestNote = lowest
        noteCount = Int(ceil(PitchMath.midi(frequency: maxFrequency))) - lowest + 1
        // Harmonic h sits 12·log2(h) semitones up; h5 and h7 fall between grid notes, so they are
        // predicted with the same cos² weight the semitone mapping gives them.
        let exact = (2...8).map { 12 * log2(Double($0)) }
        let offsets = exact.map { Int($0.rounded(.toNearestOrEven)) }
        var weights: [Double] = []
        for index in 0..<exact.count {
            let deviation = exact[index] - Double(offsets[index])
            weights.append(ChordRecognizer.harmonicGains[index] * pow(cos(Double.pi * deviation), 2))
        }
        harmonicOffsets = offsets
        harmonicWeights = weights
    }

    /// Forgets the smoothed reading, e.g. when a lesson moves to the next chord.
    public func reset() {
        smoothedNotes = nil; smoothedSpectrum = nil; previousLevel = -200
        chroma = .init(repeating: 0, count: 12); bassPitchClass = nil; current = nil
    }

    /// Analyses one frame (consecutive frames should overlap or follow each other) and returns the
    /// chord heard so far, or nil for silence, noise, a single note, or an unclear reading.
    public func process(_ frame: [Float]) -> ChordEstimate? {
        guard frame.count >= 1024, frame.allSatisfy({ $0.isFinite }) else { reset(); return nil }
        let level = DspMath.rmsDbfs(frame)
        guard level >= silenceDbfs else { reset(); return nil }
        var spectrum = semitoneSpectrum(spectralPeaks(frame))
        guard let peak = spectrum.max(), peak > 0 else { reset(); return nil }
        for i in spectrum.indices { spectrum[i] /= peak }
        let notes = Self.removeOvertones(spectrum, offsets: harmonicOffsets, weights: harmonicWeights)
        if let previousNotes = smoothedNotes, let previousSpectrum = smoothedSpectrum, level <= previousLevel + Self.restrikeDb {
            smoothedNotes = zip(previousNotes, notes).map { smoothing * $0 + (1 - smoothing) * $1 }
            smoothedSpectrum = zip(previousSpectrum, spectrum).map { smoothing * $0 + (1 - smoothing) * $1 }
        } else {
            smoothedNotes = notes; smoothedSpectrum = spectrum
        }
        previousLevel = level
        let smoothed = smoothedNotes ?? notes
        chroma = Self.chroma(notes: smoothed, lowestNote: lowestNote)
        bassPitchClass = Self.bass(notes: smoothed, spectrum: smoothedSpectrum ?? spectrum, lowestNote: lowestNote)
        let strongest = chroma.max() ?? 0
        let strong = chroma.filter { $0 >= 0.3 * strongest && $0 > 0 }.count
        guard strong >= 2, let best = Self.bestChord(chroma: chroma, bass: bassPitchClass), best.confidence >= minimumConfidence else {
            current = nil
            return nil
        }
        let estimate = ChordEstimate(root: best.target.root, quality: best.target.quality, confidence: best.confidence, chroma: chroma, bass: bassPitchClass)
        current = estimate
        return estimate
    }

    /// How well the current smoothed chroma fits `target`'s template, 0…1 (0 while no chord is heard).
    public func confidence(for target: ChordTarget) -> Double {
        current == nil ? 0 : Self.templateConfidence(chroma: chroma, target: target)
    }

    /// Lesson check: is the player sounding `target`? Accepts inversions and other voicings of the same
    /// chord, and readings with the same notes (Asus2 = Esus4); rejects other chords, single notes and silence.
    public func matches(_ target: ChordTarget, minConfidence: Double = 0.5) -> Bool {
        guard let current else { return false }
        let confidence = Self.templateConfidence(chroma: chroma, target: target)
        guard confidence >= minConfidence else { return false }
        if target.pitchClasses == current.target.pitchClasses { return true }
        let rank = confidence + (bassPitchClass == target.root ? Self.bassBonus : 0)
        let bestRank = current.confidence + (bassPitchClass == current.root ? Self.bassBonus : 0)
        return rank >= bestRank - Self.matchTolerance
    }

    // MARK: - Stages

    struct Peak { let frequency: Double; let magnitude: Double }

    /// Interpolated spectral peaks between `minFrequency` and `maxFrequency`, magnitudes in full-scale units.
    func spectralPeaks(_ frame: [Float]) -> [Peak] {
        if transform?.frameLength != frame.count { transform = Transform(frameLength: frame.count) }
        guard let t = transform else { return [] }
        let size = t.fft.size
        for i in 0..<size {
            t.real[i] = i < frame.count ? Double(frame[i]) * t.window[i] : 0
            t.imaginary[i] = 0
        }
        t.fft.transform(real: &t.real, imaginary: &t.imaginary)
        let half = size / 2
        let scale = 2 / t.windowSum
        var magnitude = [Double](repeating: 0, count: half)
        for k in 0..<half { magnitude[k] = (t.real[k] * t.real[k] + t.imaginary[k] * t.imaginary[k]).squareRoot() * scale }
        let binHz = sampleRate / Double(size)
        let low = max(2, Int(floor(minFrequency / binHz)))
        let high = min(half - 2, Int(ceil(maxFrequency / binHz)))
        guard high > low else { return [] }
        let band = magnitude[low...high]
        guard let strongest = band.max(), strongest > 0 else { return [] }
        let median = band.sorted()[band.count / 2]
        let threshold = max(strongest * Self.dynamicRange, Self.peakFloorFactor * median)
        var peaks: [Peak] = []
        for k in low...high {
            let m = magnitude[k]
            guard m > magnitude[k - 1], m >= magnitude[k + 1], m >= threshold else { continue }
            let a = log(max(magnitude[k - 1], 1e-30)), b = log(m), c = log(max(magnitude[k + 1], 1e-30))
            let denominator = a - 2 * b + c
            var shift = denominator < 0 ? 0.5 * (a - c) / denominator : 0
            shift = min(0.5, max(-0.5, shift))
            let frequency = (Double(k) + shift) * binHz
            guard frequency >= minFrequency, frequency <= maxFrequency else { continue }
            peaks.append(Peak(frequency: frequency, magnitude: exp(b - 0.25 * (a - c) * shift)))
        }
        return peaks
    }

    /// Peaks on a semitone grid starting at `lowestNote`, after removing the instrument's overall
    /// tuning offset (a weighted circular mean of the peaks' distance from equal temperament).
    func semitoneSpectrum(_ peaks: [Peak]) -> [Double] {
        var spectrum = [Double](repeating: 0, count: noteCount)
        guard !peaks.isEmpty else { return spectrum }
        let midi = peaks.map { PitchMath.midi(frequency: $0.frequency) }
        var re = 0.0, im = 0.0
        for (m, peak) in zip(midi, peaks) {
            re += peak.magnitude * cos(2 * Double.pi * m); im += peak.magnitude * sin(2 * Double.pi * m)
        }
        let offset = re != 0 || im != 0 ? atan2(im, re) / (2 * Double.pi) : 0
        for (m, peak) in zip(midi, peaks) {
            let note = m - offset
            let nearest = note.rounded(.toNearestOrEven)
            let index = Int(nearest) - lowestNote
            guard index >= 0, index < noteCount else { continue }
            spectrum[index] += peak.magnitude * pow(cos(Double.pi * (note - nearest)), 2)
        }
        return spectrum
    }

    /// Note salience: walking up from the lowest semitone, each note keeps what its lower notes'
    /// predicted harmonics do not explain, then predicts its own harmonics further up.
    static func removeOvertones(_ spectrum: [Double], offsets: [Int], weights: [Double]) -> [Double] {
        let count = spectrum.count
        var notes = [Double](repeating: 0, count: count)
        var predicted = [Double](repeating: 0, count: count)
        for i in 0..<count {
            notes[i] = max(0, spectrum[i] - predicted[i])
            guard notes[i] > 0 else { continue }
            for (offset, weight) in zip(offsets, weights) where i + offset < count {
                predicted[i + offset] += notes[i] * weight
            }
        }
        return notes
    }

    /// Folds note salience into 12 pitch classes, drops near-empty bins, compresses (square root)
    /// so a chord tone played on one string still counts beside doubled roots, and normalises.
    public static func chroma(notes: [Double], lowestNote: Int) -> [Double] {
        var chroma = [Double](repeating: 0, count: 12)
        for (i, value) in notes.enumerated() { chroma[PitchMath.pitchClass(midi: lowestNote + i)] += value }
        guard let strongest = chroma.max(), strongest > 0 else { return chroma }
        chroma = chroma.map { (max(0, $0 / strongest - chromaFloor) / (1 - chromaFloor)).squareRoot() }
        let length = chroma.reduce(0) { $0 + $1 * $1 }.squareRoot()
        return length > 0 ? chroma.map { $0 / length } : chroma
    }

    /// Lowest note with clear support from its own fundamental, octave and twelfth.
    static func bass(notes: [Double], spectrum: [Double], lowestNote: Int) -> Int? {
        let count = spectrum.count
        var support = spectrum
        for i in 0..<count {
            if i + 12 < count { support[i] += 0.5 * spectrum[i + 12] }
            if i + 19 < count { support[i] += 0.33 * spectrum[i + 19] }
        }
        guard let strongestSupport = support.max(), strongestSupport > 0, let strongestNote = notes.max() else { return nil }
        for i in 0..<count where notes[i] > 0.05 * strongestNote && support[i] >= 0.3 * strongestSupport {
            return PitchMath.pitchClass(midi: lowestNote + i)
        }
        return nil
    }

    /// Cosine of the chroma with the chord's template, rescaled so a flat chroma (noise) scores 0
    /// and the template itself scores 1.
    public static func templateConfidence(chroma: [Double], target: ChordTarget) -> Double {
        guard chroma.count == 12 else { return 0 }
        let intervals = target.quality.intervals
        let k = Double(intervals.count)
        let cosine = intervals.reduce(0.0) { $0 + chroma[(target.root + $1) % 12] } / k.squareRoot()
        let flat = (k / 12).squareRoot()
        return DspMath.clamp01((cosine - flat) / (1 - flat))
    }

    /// Best template for a chroma: highest confidence, plus `bassBonus` when its root is the bass.
    public static func bestChord(chroma: [Double], bass: Int?) -> (target: ChordTarget, confidence: Double)? {
        guard chroma.count == 12, chroma.contains(where: { $0 > 0 }) else { return nil }
        var best: (target: ChordTarget, confidence: Double, rank: Double)?
        for quality in Quality.allCases {
            for root in 0..<12 {
                let target = ChordTarget(root: root, quality: quality)
                let confidence = templateConfidence(chroma: chroma, target: target)
                let rank = confidence + (bass == root ? bassBonus : 0)
                if best == nil || rank > best!.rank { best = (target, confidence, rank) }
            }
        }
        return best.map { ($0.target, $0.confidence) }
    }
}
