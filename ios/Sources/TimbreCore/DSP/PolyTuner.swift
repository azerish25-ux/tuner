import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

/// One strum heard by `PolyTuner`: every string's pitch at once.
public struct PolyReading: Equatable, Sendable {
    /// How a string's pitch was found.
    public enum Evidence: String, Codable, Sendable {
        /// The string's own fundamental, clear of (or separated from) the other strings' partials.
        case fundamental
        /// The string's 2nd or 3rd partial: its fundamental was weak, or sat on another string's harmonic.
        case harmonics
        /// Its fundamental coincides with another string's harmonic (B3 on E2's 3rd, a 12-string's octave
        /// partner) and could not be told apart; the shared peak is reported because the rest of the
        /// strum was heard. Good to a few cents; worth a single-string check when it matters.
        case shared
    }

    /// One string of the strum.
    public struct StringReading: Equatable, Sendable {
        /// Position in the `strings` array the tuner was made with.
        public let index: Int
        /// The pitch the string should have (Hz).
        public let targetHz: Double
        /// The pitch heard (Hz); nil when the string was not heard (muted, not strummed, out of range).
        public let frequencyHz: Double?
        /// Offset from `targetHz` in cents (positive = sharp); nil when not heard.
        public let cents: Double?
        /// 0…1 (0 when not heard).
        public let confidence: Double
        /// How the pitch was found; nil when not heard.
        public let evidence: Evidence?
        public var isHeard: Bool { frequencyHz != nil }

        public init(index: Int, targetHz: Double, frequencyHz: Double?, confidence: Double, evidence: Evidence?) {
            self.index = index
            self.targetHz = targetHz
            self.frequencyHz = frequencyHz
            cents = frequencyHz.map { PitchMath.cents(target: targetHz, measured: $0) }
            self.confidence = frequencyHz == nil ? 0 : DspMath.clamp01(confidence)
            self.evidence = frequencyHz == nil ? nil : evidence
        }
    }

    /// One entry per string, in the order the tuner was given them (strings of a unison course share a pitch).
    public let strings: [StringReading]
    /// When the strum started, in seconds of audio since the tuner began or was reset.
    public let onsetTime: Double
    /// RMS level of the analysed window (dBFS).
    public let levelDbfs: Double

    public init(strings: [StringReading], onsetTime: Double, levelDbfs: Double) {
        self.strings = strings
        self.onsetTime = onsetTime
        self.levelDbfs = levelDbfs
    }

    public var heardCount: Int { strings.filter(\.isHeard).count }

    /// Every string heard and within `cents` of its target.
    public func allInTune(within cents: Double) -> Bool {
        strings.allSatisfy { reading in reading.cents.map { abs($0) <= cents } ?? false }
    }
}

/// "Strum to tune": a polyphonic tuner. The player strums every open string once and `feed` returns,
/// about 0.65 s later (0.85 s on a bass), each string's offset from its target, on any instrument whose
/// open-string pitches are known. Strings of a course tuned in unison count as one pitch.
///
/// Per strum:
/// 1. `OnsetDetector` finds the strum. The analysed window starts `settle` (150 ms) later, after the
///    pick noise and the strum's spread across the strings, and lasts `window` (0.5 s; 0.7 s when the
///    lowest string is below 50 Hz).
/// 2. Hann window and zero-padded FFT (vDSP); noise floor from the median magnitude.
/// 3. Strings are solved lowest first. Each fundamental is searched ±`searchCents` around its target
///    by fitting the complex spectrum there as a sum of decaying partials, each in closed form (the
///    exact transform of a Hann-windowed damped sinusoid): one free partial for the string, plus every
///    partial of the other strings predicted from their own fit and inharmonicity,
///    fₙ = n·f₁·√((1 + Bn²)/(1 + B)). Amplitudes come from ridge least squares; the string's frequency
///    and each partial's damping from golden-section search. That separates a string from another
///    string's harmonic a fraction of a hertz away (B3 from E2's 3rd, E4 from E2's 4th and A2's 3rd),
///    which peak picking cannot do in half a second.
/// 4. Harmonic support: a fit close to another string's partial is confirmed at the string's 2nd and
///    3rd partials; a weak fundamental (bass, small body, phone microphone) is refined from them; a
///    fundamental lying exactly on another string's harmonic is looked for at its 2nd and 3rd partials,
///    where the two strings' inharmonicity pulls the series apart.
/// 5. A fundamental that still cannot be told from another string's harmonic is reported as `shared`
///    when at least two other strings were heard (a strum), and as not heard otherwise (a single pluck).
///
/// Limits: a muted string whose fundamental coincides with a ringing lower string's harmonic (B3 or
/// E4 on a guitar) reads as that harmonic in a full strum; exact octave pairs (12-string) are `shared`
/// and good to a few cents; strings below about 35 Hz need the 0.7 s window. Each instance belongs to
/// one serial audio-analysis queue: `feed` is cheap per buffer and runs the analysis (tens of
/// milliseconds) once per strum, with no allocation inside its fitting loops.
public final class PolyTuner {
    /// The strings' target pitches (Hz), in the order readings are returned.
    public let strings: [Double]
    public let sampleRate: Double
    /// Seconds of ringing analysed per strum.
    public let window: Double
    /// Seconds skipped after the strum's onset: pick noise and the strum's spread across strings.
    public let settle: Double
    /// How far from its target (cents) a string is looked for.
    public let searchCents: Double
    /// Windows quieter than this (RMS dBFS) are ignored.
    public let silenceDbfs: Double
    /// Samples per analysed window.
    public var windowLength: Int { frameLength }
    /// Seconds of audio received since the start or the last `reset()`.
    public var elapsed: Double { Double(received) / sampleRate }

    // MARK: Tuning constants (lengths in units of 1/window Hz scale with the frequency resolution)

    /// A partial must stand this far above the median magnitude…
    static let floorFactor = 4.0
    /// …and within about 50 dB of the strongest peak.
    static let dynamicRange = 0.003
    /// A string must explain this fraction of its band's energy.
    static let explainMin = 0.002
    /// Partials above this are neither modelled nor used.
    static let maxPartialHz = 4000.0
    static let maxHarmonic = 12
    /// Inharmonicity assumed for a string not measured yet, and the most a string is credited with.
    static let defaultInharmonicity = 5e-5
    static let maxInharmonicity = 6e-4
    /// Ridge (relative to the mean column energy): stops two nearly equal partials trading huge,
    /// opposite amplitudes.
    static let ridge = 1e-3
    /// ×1/window Hz: partials closer than this read as one peak.
    static let coincide = 0.5
    /// ×1/window Hz: a fit this close to another string's partial is checked against its harmonics.
    static let close = 2.0
    /// ×1/window Hz: other strings' partials this far beyond a band are modelled too.
    static let margin = 6.0
    /// ×1/window Hz: a fit pinned this close to its search edge is a neighbour's skirt, not a string.
    static let edge = 0.1
    /// ×1/window Hz: a fitted band extends this far beyond its search range.
    static let pad = 2.5
    /// A string near another string's partial counts as separated when it carries at least this share of
    /// that partial's amplitude and two partials fit at least `gainMin` times better than one.
    static let ratioMin = 0.2
    static let gainMin = 1.0
    static let rounds = 2
    /// Damping (1/s) the search starts from, and its ceiling.
    static let initialDamping = 2.0
    static let maxDamping = 15.0
    /// A `shared` reading needs this many other strings heard (a strum, not one plucked string).
    static let contextMin = 2
    /// A harmonic found by a probe must reach this share of the level it is tested against…
    static let probeRatio = 0.05
    /// …and leave at most this share of its band unexplained.
    static let probeResidual = 0.01
    /// A fundamental weaker than this share of its 2nd or 3rd partial is refined from them.
    static let weakRatio = 0.5
    /// Strings closer than this (cents) are one target (a course in unison).
    static let unisonCents = 10.0
    /// Onsets this close after a strum's first one belong to the same strum.
    static let strumSpan = 0.25
    /// `feed` hands audio to the detector in slices of at most this many samples.
    static let slice = 4096

    // MARK: State

    private let targets: [Double]
    private let stringTarget: [Int]
    private let low: [Double]
    private let high: [Double]
    private let frameLength: Int
    private let spectrum: Spectrum
    private let model: PartialModel
    private let half: Int
    private let binHz: Double
    /// Converts transform magnitudes to sinusoid amplitudes.
    private let scale: Double
    private let partialLimit: Double
    private var re: [Double]
    private var im: [Double]
    private var mag: [Double]
    private var floorLevel = 0.0
    private var strongest = 0.0
    private var threshold = 0.0
    private var coarse: [Double?] = []
    private var estimates: [Estimate?] = []

    private let onsets: OnsetDetector
    private var ring: [Float]
    private var received = 0
    private var pendingStart: Int?
    private var pendingOnset = 0.0
    private var segment: [Float]

    /// - Parameters:
    ///   - strings: each string's open pitch (Hz), e.g. `tuning.courses.map(store.target(for:))`.
    ///   - window: seconds analysed per strum; nil picks `defaultWindow(lowestHz:)`.
    public init(strings: [Double], sampleRate: Double = 48000, window: Double? = nil, settle: Double = 0.15,
                searchCents: Double = 100, silenceDbfs: Double = -65) {
        precondition(!strings.isEmpty && strings.allSatisfy { $0.isFinite && $0 > 0 }, "PolyTuner needs the strings' pitches")
        precondition(sampleRate.isFinite && sampleRate >= 8000 && settle >= 0 && searchCents > 0)
        self.strings = strings
        self.sampleRate = sampleRate
        self.settle = settle
        self.searchCents = searchCents
        self.silenceDbfs = silenceDbfs
        let length = window ?? PolyTuner.defaultWindow(lowestHz: strings.min() ?? 82)
        precondition(length >= 0.1 && length <= 4)
        self.window = length

        // Distinct pitches, lowest first; a unison course is one target.
        let order = strings.indices.sorted { strings[$0] < strings[$1] }
        var targets: [Double] = []
        var map = [Int](repeating: 0, count: strings.count)
        for index in order {
            if let last = targets.last, abs(PitchMath.cents(target: last, measured: strings[index])) < PolyTuner.unisonCents {
                map[index] = targets.count - 1
            } else {
                targets.append(strings[index])
                map[index] = targets.count - 1
            }
        }
        self.targets = targets
        stringTarget = map
        // Search ranges stop halfway to the neighbouring targets.
        var low: [Double] = [], high: [Double] = []
        for (i, f) in targets.enumerated() {
            let below = i == 0 ? searchCents : min(searchCents, 0.5 * PitchMath.cents(target: targets[i - 1], measured: f))
            let above = i == targets.count - 1 ? searchCents : min(searchCents, 0.5 * PitchMath.cents(target: f, measured: targets[i + 1]))
            low.append(f * PitchMath.ratio(cents: -below))
            high.append(f * PitchMath.ratio(cents: above))
        }
        self.low = low
        self.high = high

        frameLength = max(256, Int((length * sampleRate).rounded()))
        spectrum = Spectrum(length: frameLength)
        half = spectrum.size / 2
        binHz = sampleRate / Double(spectrum.size)
        scale = 2 / (spectrum.windowSum * spectrum.gain)
        model = PartialModel(length: frameLength, size: spectrum.size, sampleRate: sampleRate)
        partialLimit = min(PolyTuner.maxPartialHz, 0.45 * sampleRate)
        re = .init(repeating: 0, count: half)
        im = re
        mag = re
        onsets = OnsetDetector(sampleRate: sampleRate)
        ring = .init(repeating: 0, count: frameLength + Int(sampleRate) + Int((settle * sampleRate).rounded()) + PolyTuner.slice)
        segment = .init(repeating: 0, count: frameLength)
    }

    /// Analysis length for an instrument: 0.5 s, or 0.7 s when its lowest string is below 50 Hz, where a
    /// bass's partials crowd closer together in hertz.
    public static func defaultWindow(lowestHz: Double) -> Double { lowestHz < 50 ? 0.7 : 0.5 }

    /// Forgets any strum in progress and restarts the stream clock.
    public func reset() {
        onsets.reset()
        received = 0
        pendingStart = nil
        pendingOnset = 0
    }

    /// Consumes the next chunk of microphone audio (any length, mono, at `sampleRate`). Returns a reading
    /// once a strum has rung for `settle + window` seconds, once per strum; nil otherwise.
    public func feed(_ samples: [Float]) -> PolyReading? {
        var reading: PolyReading?
        var start = 0
        while start < samples.count {
            let end = min(samples.count, start + PolyTuner.slice)
            let chunk = start == 0 && end == samples.count ? samples : Array(samples[start..<end])
            if let next = consume(chunk) { reading = next }
            start = end
        }
        return reading
    }

    private func consume(_ chunk: [Float]) -> PolyReading? {
        for time in onsets.process(chunk) {
            // A slow strum can trip the detector once per group of strings: the window always starts
            // after the latest attack, and the strum keeps its first onset time.
            if pendingStart == nil || time - pendingOnset > PolyTuner.strumSpan { pendingOnset = time }
            pendingStart = Int(((time + settle) * sampleRate).rounded())
        }
        let count = ring.count
        for value in chunk {
            ring[received % count] = value.isFinite ? value : 0
            received += 1
        }
        guard let begin = pendingStart, received >= begin + frameLength else { return nil }
        pendingStart = nil
        guard begin >= 0, begin >= received - count else { return nil }
        for i in 0..<frameLength { segment[i] = ring[(begin + i) % count] }
        return analyze(segment, onsetTime: pendingOnset)
    }

    // MARK: Analysis

    /// Analyses one window that starts after a strum's attack: the first `windowLength` samples of
    /// `segment`. Returns nil for silence, or when no string is heard.
    public func analyze(_ segment: [Float], onsetTime: Double = 0) -> PolyReading? {
        guard segment.count >= frameLength else { return nil }
        var power = 0.0
        for i in 0..<frameLength {
            let value = Double(segment[i])
            guard value.isFinite else { return nil }
            power += value * value
        }
        let level = power > 1e-24 ? 10 * log10(power / Double(frameLength)) : -200
        guard level >= silenceDbfs else { return nil }
        spectrum.transform(segment, re: &re, im: &im)
        for k in 0..<half { mag[k] = (re[k] * re[k] + im[k] * im[k]).squareRoot() * scale }
        guard measureFloor() else { return nil }

        let n = targets.count
        coarse = targets.indices.map { peak(from: low[$0], to: high[$0])?.frequency }
        estimates = [Estimate?](repeating: nil, count: n)
        var outcomes: [Outcome] = []
        for i in 0..<n {
            let outcome = solve(i)
            switch outcome {
            case .resolved(let f, _, _, _), .harmonic(let f, _, _):
                estimates[i] = Estimate(frequency: f, inharmonicity: inharmonicity(i, f))
            case .hidden(let f, _, _, _):
                estimates[i] = Estimate(frequency: f, inharmonicity: PolyTuner.defaultInharmonicity)
            case .none:
                estimates[i] = nil
            }
            outcomes.append(outcome)
        }

        let heard = Set(outcomes.indices.filter { outcomes[$0].isHeard })
        var perTarget: [TargetReading] = []
        for (i, outcome) in outcomes.enumerated() {
            switch outcome {
            case .resolved(let f, let amplitude, let quality, _):
                perTarget.append(TargetReading(frequency: f, confidence: confidence(amplitude, quality), evidence: .fundamental))
            case .harmonic(let f, let amplitude, let quality):
                perTarget.append(TargetReading(frequency: f, confidence: 0.8 * confidence(amplitude, quality), evidence: .harmonics))
            case .hidden(let f, let amplitude, let quality, let owners):
                if heard.subtracting(owners).subtracting([i]).count >= PolyTuner.contextMin {
                    perTarget.append(TargetReading(frequency: f, confidence: 0.5 * confidence(amplitude, quality), evidence: .shared))
                } else {
                    perTarget.append(TargetReading(frequency: nil, confidence: 0, evidence: nil))
                }
            case .none:
                perTarget.append(TargetReading(frequency: nil, confidence: 0, evidence: nil))
            }
        }
        guard perTarget.contains(where: { $0.frequency != nil }) else { return nil }
        let readings = strings.indices.map { s -> PolyReading.StringReading in
            let target = perTarget[stringTarget[s]]
            return PolyReading.StringReading(index: s, targetHz: strings[s], frequencyHz: target.frequency,
                                             confidence: target.confidence, evidence: target.evidence)
        }
        return PolyReading(strings: readings, onsetTime: onsetTime, levelDbfs: level)
    }

    /// One target string, after its own fit and the harmonic checks.
    private func solve(_ i: Int) -> Outcome {
        var outcome = measure(i, rejectClose: false)
        if case .resolved(let f, let amplitude, let quality, let gap) = outcome {
            let check = support(i, f, gap: gap)
            if gap < PolyTuner.close / window && check.verdict == .no {
                // Next to another string's partial and none of its own harmonics there: not this string.
                outcome = measure(i, rejectClose: true)
            } else if let loudest = check.found.map({ $0.amplitude }).max(), amplitude < PolyTuner.weakRatio * loudest {
                // Weak fundamental: lean on the stronger partials (variance ∝ 1/(h·amplitude)²).
                var weights = amplitude * amplitude
                var sum = weights * f
                for partial in check.found {
                    let weight = Double(partial.harmonic * partial.harmonic) * partial.amplitude * partial.amplitude
                    weights += weight
                    sum += weight * partial.frequency
                }
                outcome = .resolved(frequency: sum / weights, amplitude: amplitude, quality: quality, gap: gap)
            }
        }
        switch outcome {
        case .none:
            // No fundamental at all: perhaps one too weak to see under the noise (a bass on a phone).
            let stretch = PolyTuner.stretch(PolyTuner.defaultInharmonicity, 2)
            if let found = probe(i, harmonic: 2, from: 2 * low[i] * stretch, to: 2 * high[i] * stretch,
                                 floor: PolyTuner.probeRatio * strongest) {
                outcome = .harmonic(frequency: found.frequency, amplitude: found.amplitude, quality: found.quality)
            }
        case .hidden(_, let amplitude, _, _):
            if let found = unhide(i, amplitude: amplitude) {
                outcome = .harmonic(frequency: found.frequency, amplitude: found.amplitude, quality: found.quality)
            }
        default:
            break
        }
        return outcome
    }

    /// The fundamental search: the string's band fitted with every other string's partials there.
    private func measure(_ i: Int, rejectClose: Bool) -> Outcome {
        let t = window, lo = low[i], hi = high[i]
        let nearby = partials(excluding: i, from: lo - PolyTuner.margin / t, to: hi + PolyTuner.margin / t)
        let freqs = nearby.map { $0.frequency }
        guard let r = fit(from: lo - PolyTuner.pad / t, to: hi + PolyTuner.pad / t, partials: freqs,
                          searchLow: lo, searchHigh: hi) else { return .none }
        let near = freqs.indices.filter { abs(freqs[$0] - r.frequency) < PolyTuner.coincide / t }
        let atEdge = r.frequency - lo < PolyTuner.edge / t || hi - r.frequency < PolyTuner.edge / t
        let strong = r.amplitude >= threshold && r.explained >= PolyTuner.explainMin && !atEdge
        let gap = freqs.map { abs($0 - r.frequency) }.min() ?? .infinity
        let close = gap < PolyTuner.close / t
        if strong && near.isEmpty && !(close && rejectClose) {
            return .resolved(frequency: r.frequency, amplitude: r.amplitude, quality: r.quality, gap: gap)
        }
        var shared: (centre: Double, merged: Merged)?
        if strong, let nearest = near.max(by: { r.partialAmplitudes[$0] < r.partialAmplitudes[$1] }),
           let single = merge(i, nearby, centre: freqs[nearest]) {
            // Two partials or one? The string counts as separated only when two fit clearly better.
            let gain = (single.fit.residual - r.residual) / max(r.residual, 1e-300)
            if gain >= PolyTuner.gainMin && r.amplitude >= PolyTuner.ratioMin * r.partialAmplitudes[nearest] && !rejectClose {
                return .resolved(frequency: r.frequency, amplitude: r.amplitude, quality: r.quality, gap: gap)
            }
            shared = (centre: freqs[nearest], merged: single)
        }
        // Hidden: the string may sit under another string's partial inside its range; take the one
        // closest to its target and fit the two as one peak.
        let target = targets[i]
        let inside = freqs.indices.filter { freqs[$0] >= lo && freqs[$0] <= hi }
        guard let star = inside.min(by: { abs(log2(freqs[$0] / target)) < abs(log2(freqs[$1] / target)) }) else { return .none }
        let merged: Merged
        if let shared, abs(freqs[star] - shared.centre) < PolyTuner.coincide / t {
            merged = shared.merged
        } else if let other = merge(i, nearby, centre: freqs[star]) {
            merged = other
        } else {
            return .none
        }
        guard merged.fit.amplitude >= threshold else { return .none }
        return .hidden(frequency: merged.fit.frequency, amplitude: merged.fit.amplitude, quality: merged.fit.quality,
                       owners: merged.owners)
    }

    /// The string's band with the partials near `centre` replaced by one free partial.
    private func merge(_ i: Int, _ nearby: [(frequency: Double, owner: Int)], centre: Double) -> Merged? {
        let t = window, lo = low[i], hi = high[i], reach = PolyTuner.coincide / t
        let keep = nearby.filter { abs($0.frequency - centre) >= reach }.map { $0.frequency }
        let owners = Set(nearby.filter { abs($0.frequency - centre) < reach }.map { $0.owner })
        guard let r = fit(from: lo - PolyTuner.pad / t, to: hi + PolyTuner.pad / t, partials: keep,
                          searchLow: max(lo, centre - reach), searchHigh: min(hi, centre + reach)) else { return nil }
        return Merged(fit: r, owners: owners)
    }

    /// Looks for the string's h-th partial between fLo and fHi (Hz). Returns the fundamental it implies
    /// when the partial stands clear of every other string's partials.
    private func probe(_ i: Int, harmonic h: Int, from fLo: Double, to fHi: Double,
                       floor floorAmplitude: Double) -> (frequency: Double, amplitude: Double, quality: Double)? {
        let t = window
        guard fHi > fLo, fHi + PolyTuner.pad / t <= partialLimit else { return nil }
        let nearby = partials(excluding: i, from: fLo - PolyTuner.margin / t, to: fHi + PolyTuner.margin / t).map { $0.frequency }
        guard let r = fit(from: fLo - PolyTuner.pad / t, to: fHi + PolyTuner.pad / t, partials: nearby,
                          searchLow: fLo, searchHigh: fHi) else { return nil }
        let near = nearby.contains { abs($0 - r.frequency) < PolyTuner.coincide / t }
        let atEdge = r.frequency - fLo < PolyTuner.edge / t || fHi - r.frequency < PolyTuner.edge / t
        guard r.amplitude >= max(threshold, floorAmplitude), r.explained >= PolyTuner.explainMin, !near, !atEdge,
              r.quality <= PolyTuner.probeResidual else { return nil }
        let fundamental = r.frequency / (Double(h) * PolyTuner.stretch(PolyTuner.defaultInharmonicity, h))
        return (frequency: fundamental, amplitude: r.amplitude, quality: r.quality)
    }

    /// The string's 2nd and 3rd partials near h·f: `yes` if one is there, `no` if none is and no other
    /// string's partial could hide it, `unknown` otherwise. `gap` is how far the fit sat from the nearest
    /// other partial: a fit that close may be pulled by up to half of it, so the windows widen to match.
    private func support(_ i: Int, _ f: Double, gap: Double) -> (verdict: Support, found: [(frequency: Double, amplitude: Double, harmonic: Int)]) {
        let t = window
        let pull = gap < PolyTuner.close / t ? 0.5 * gap : 0
        var verdicts: [Support] = []
        var found: [(frequency: Double, amplitude: Double, harmonic: Int)] = []
        for h in 2...3 {
            let centre = PolyTuner.partial(f, PolyTuner.defaultInharmonicity, h)
            let width = max(0.5 / t, centre * (PitchMath.ratio(cents: 3) - 1), Double(h) * pull)
            if centre + width + PolyTuner.pad / t > partialLimit { break }
            if let partial = probe(i, harmonic: h, from: centre - width, to: centre + width, floor: 0) {
                verdicts.append(.yes)
                found.append((frequency: partial.frequency, amplitude: partial.amplitude, harmonic: h))
                continue
            }
            let crowded = !partials(excluding: i, from: centre - width - PolyTuner.coincide / t,
                                    to: centre + width + PolyTuner.coincide / t).isEmpty
            verdicts.append(crowded ? .unknown : .no)
        }
        let verdict: Support
        if verdicts.contains(.yes) {
            verdict = .yes
        } else if !verdicts.isEmpty && verdicts.allSatisfy({ $0 == .no }) {
            verdict = .no
        } else {
            verdict = .unknown
        }
        return (verdict: verdict, found: found)
    }

    /// A string hidden under other strings' partials: looks for its 2nd and 3rd partials near each
    /// shared peak in its range, wherever the sharing partials' own multiples have moved clear of them.
    private func unhide(_ i: Int, amplitude: Double) -> (frequency: Double, amplitude: Double, quality: Double)? {
        let t = window, lo = low[i], hi = high[i], reach = PolyTuner.coincide / t
        var members: [(frequency: Double, base: Double, inharmonicity: Double, harmonic: Int)] = []
        for j in targets.indices where j != i {
            guard let e = estimate(j, from: i) else { continue }
            for m in 1...PolyTuner.maxHarmonic {
                let nu = PolyTuner.partial(e.frequency, e.inharmonicity, m)
                if nu > hi { break }
                if nu >= lo { members.append((frequency: nu, base: e.frequency, inharmonicity: e.inharmonicity, harmonic: m)) }
            }
        }
        let target = targets[i]
        members.sort { abs(log2($0.frequency / target)) < abs(log2($1.frequency / target)) }
        var centres: [Double] = []
        for member in members {
            if centres.allSatisfy({ abs(member.frequency - $0) >= reach }) { centres.append(member.frequency) }
        }
        for centre in centres {
            let group = members.filter { abs($0.frequency - centre) < reach }
            for h in 2...3 {
                let mid = PolyTuner.partial(centre, PolyTuner.defaultInharmonicity, h)
                let spread = group.map { abs(PolyTuner.partial($0.base, $0.inharmonicity, $0.harmonic * h) - mid) }.min() ?? 0
                if spread < reach { continue }
                let stretch = PolyTuner.stretch(PolyTuner.defaultInharmonicity, h)
                let fLo = max(Double(h) * lo * stretch, mid - Double(h) * reach)
                let fHi = min(Double(h) * hi * stretch, mid + Double(h) * reach)
                let level = max(magnitude(at: centre), amplitude)
                if let found = probe(i, harmonic: h, from: fLo, to: fHi, floor: PolyTuner.probeRatio * level) { return found }
            }
        }
        return nil
    }

    /// Inharmonicity from the string's clean partials (no other string's partial within 3/window Hz).
    private func inharmonicity(_ i: Int, _ f: Double) -> Double {
        let t = window
        var sum = 0.0, weight = 0.0
        for h in 2...PolyTuner.maxHarmonic {
            let lowest = Double(h) * f
            let highest = PolyTuner.partial(f, PolyTuner.maxInharmonicity, h)
            if highest > partialLimit { break }
            if !partials(excluding: i, from: lowest - 3 / t, to: highest + 3 / t).isEmpty { continue }
            guard let found = peak(from: lowest - 1 / t, to: highest + 1 / t) else { continue }
            let ratio = pow(found.frequency / lowest, 2)
            let b = (ratio - 1) / (Double(h * h) - ratio)
            let w = found.amplitude * Double(h * h - 1)
            sum += w * b
            weight += w
        }
        guard weight > 0 else { return PolyTuner.defaultInharmonicity }
        return min(PolyTuner.maxInharmonicity, max(0, sum / weight))
    }

    // MARK: Spectrum helpers

    private func measureFloor() -> Bool {
        let lowBin = max(2, Int(low[0] * 0.8 / binHz))
        let highBin = min(half - 2, Int(partialLimit / binHz))
        guard highBin > lowBin + 8 else { return false }
        var band = Array(mag[lowBin..<highBin])
        band.sort()
        floorLevel = band[band.count / 2]
        strongest = band[band.count - 1]
        guard strongest > 0 else { return false }
        threshold = max(PolyTuner.floorFactor * floorLevel, PolyTuner.dynamicRange * strongest)
        return true
    }

    /// The strongest local maximum above the threshold between lo and hi Hz (log-parabolic interpolation).
    private func peak(from lo: Double, to hi: Double) -> (frequency: Double, amplitude: Double)? {
        let k0 = max(2, Int(ceil(lo / binHz)))
        let k1 = min(half - 2, Int(floor(hi / binHz)))
        guard k1 >= k0 else { return nil }
        var best: Int?
        for k in k0...k1 where mag[k] > mag[k - 1] && mag[k] >= mag[k + 1] && mag[k] >= threshold {
            if let current = best, mag[current] >= mag[k] { continue }
            best = k
        }
        guard let k = best else { return nil }
        let a = log(max(mag[k - 1], 1e-30)), b = log(mag[k]), c = log(max(mag[k + 1], 1e-30))
        let d = a - 2 * b + c
        let shift = d < 0 ? min(0.5, max(-0.5, 0.5 * (a - c) / d)) : 0
        return (frequency: (Double(k) + shift) * binHz, amplitude: exp(b - 0.25 * (a - c) * shift))
    }

    private func magnitude(at frequency: Double) -> Double {
        mag[min(half - 1, max(0, Int((frequency / binHz).rounded())))]
    }

    /// The latest estimate of string j as seen from string i: solved strings below, coarse peaks above.
    private func estimate(_ j: Int, from i: Int) -> Estimate? {
        if j < i { return estimates[j] }
        return coarse[j].map { Estimate(frequency: $0, inharmonicity: PolyTuner.defaultInharmonicity) }
    }

    /// The other strings' partials between lo and hi Hz, with the string each belongs to.
    private func partials(excluding i: Int, from lo: Double, to hi: Double) -> [(frequency: Double, owner: Int)] {
        var out: [(frequency: Double, owner: Int)] = []
        for j in targets.indices where j != i {
            guard let e = estimate(j, from: i) else { continue }
            for h in 1...PolyTuner.maxHarmonic {
                let nu = PolyTuner.partial(e.frequency, e.inharmonicity, h)
                if nu > hi { break }
                if nu >= lo { out.append((frequency: nu, owner: j)) }
            }
        }
        return out
    }

    private func confidence(_ amplitude: Double, _ quality: Double) -> Double {
        let snr = 20 * log10(max(amplitude, 1e-30) / max(floorLevel, 1e-30))
        return DspMath.clamp01((snr - 6) / 24) * DspMath.clamp01(1 - 10 * quality)
    }

    // MARK: Fitting

    /// Fits the bins between bandLow and bandHigh (Hz) as the fixed `partials` plus one free partial
    /// searched between searchLow and searchHigh: grid, golden section, then per-partial damping.
    private func fit(from bandLow: Double, to bandHigh: Double, partials: [Double], searchLow: Double, searchHigh: Double) -> FitResult? {
        let k0 = max(2, Int(floor(bandLow / binHz)))
        let k1 = min(half - 2, Int(ceil(bandHigh / binHz)))
        guard k1 > k0 + 2, searchHigh >= searchLow else { return nil }
        let state = BandFit(model: model, re: re, im: im, k0: k0, count: k1 - k0 + 1, partials: partials,
                            damping: PolyTuner.initialDamping)
        let lo = searchLow, hi = max(searchHigh, searchLow + 1e-9)
        let step = 0.25 / window
        let points = max(2, Int(ceil((hi - lo) / step)) + 1)
        func gridPoint(_ g: Int) -> Double { lo + (hi - lo) * Double(min(points - 1, max(0, g))) / Double(points - 1) }
        var damping = PolyTuner.initialDamping
        var best = 0, bestValue = Double.infinity
        for g in 0..<points {
            state.setFree(gridPoint(g), damping: damping)
            let value = state.residual()
            if value < bestValue { bestValue = value; best = g }
        }
        var f = PolyTuner.golden(gridPoint(best - 1), gridPoint(best + 1), iterations: 24) { x in
            state.setFree(x, damping: damping)
            return state.residual()
        }
        for _ in 0..<PolyTuner.rounds {
            state.setFree(f, damping: damping)
            for j in partials.indices {
                let value = PolyTuner.golden(0, PolyTuner.maxDamping, iterations: 20) { a in
                    state.setPartial(j, damping: a)
                    return state.residual()
                }
                state.setPartial(j, damping: value)
            }
            let current = f
            damping = PolyTuner.golden(0, PolyTuner.maxDamping, iterations: 20) { a in
                state.setFree(current, damping: a)
                return state.residual()
            }
            let settled = damping
            f = PolyTuner.golden(max(lo, f - step), min(hi, f + step), iterations: 24) { x in
                state.setFree(x, damping: settled)
                return state.residual()
            }
        }
        f = min(max(f, lo), hi)
        state.setFree(f, damping: damping)
        let residual = state.residual()
        let coefficients = state.coefficients
        let baseline = partials.isEmpty ? state.energy : state.residual(using: partials.count)
        let amplitude = height(f, damping, coefficients[partials.count])
        let amplitudes = partials.indices.map { height(partials[$0], state.damping[$0], coefficients[$0]) }
        return FitResult(frequency: f, amplitude: amplitude, residual: residual, baseline: baseline, energy: state.energy,
                         partialAmplitudes: amplitudes)
    }

    /// Spectrum height (sinusoid amplitude) of a fitted partial at its own frequency.
    private func height(_ f: Double, _ damping: Double, _ c: Complex) -> Double {
        let k = model.value(frequency: f, damping: damping, at: f)
        return (c * k).magnitudeSquared.squareRoot() * scale
    }

    static func stretch(_ b: Double, _ h: Int) -> Double {
        let n = Double(h)
        return ((1 + b * n * n) / (1 + b)).squareRoot()
    }

    /// Frequency of partial h of a stiff string whose fundamental (partial 1) is f.
    static func partial(_ f: Double, _ b: Double, _ h: Int) -> Double { Double(h) * f * stretch(b, h) }

    /// Golden-section minimum of a unimodal function on [low, high].
    static func golden(_ low: Double, _ high: Double, iterations: Int, _ f: (Double) -> Double) -> Double {
        let g = (5.0.squareRoot() - 1) / 2
        var a = low, b = high
        var c1 = b - g * (b - a), c2 = a + g * (b - a)
        var f1 = f(c1), f2 = f(c2)
        for _ in 0..<iterations {
            if f1 < f2 {
                b = c2; c2 = c1; f2 = f1
                c1 = b - g * (b - a); f1 = f(c1)
            } else {
                a = c1; c1 = c2; f1 = f2
                c2 = a + g * (b - a); f2 = f(c2)
            }
        }
        return (a + b) / 2
    }

    // MARK: Types

    private struct Estimate {
        let frequency: Double
        let inharmonicity: Double
    }

    private enum Support { case yes, no, unknown }

    private struct TargetReading {
        let frequency: Double?
        let confidence: Double
        let evidence: PolyReading.Evidence?
    }

    private enum Outcome {
        case none
        /// `gap`: distance (Hz) from the fit to the nearest other string's partial.
        case resolved(frequency: Double, amplitude: Double, quality: Double, gap: Double)
        case harmonic(frequency: Double, amplitude: Double, quality: Double)
        case hidden(frequency: Double, amplitude: Double, quality: Double, owners: Set<Int>)

        var isHeard: Bool {
            switch self {
            case .resolved, .harmonic: return true
            case .hidden, .none: return false
            }
        }
    }

    private struct FitResult {
        let frequency: Double
        /// Height of the free partial in the spectrum (sinusoid amplitude).
        let amplitude: Double
        /// Unexplained energy with and without the free partial.
        let residual: Double
        let baseline: Double
        let energy: Double
        let partialAmplitudes: [Double]
        var explained: Double { (baseline - residual) / max(energy, 1e-300) }
        var quality: Double { residual / max(energy, 1e-300) }
    }

    private struct Merged {
        let fit: FitResult
        /// Strings whose partials the free partial absorbed.
        let owners: Set<Int>
    }

    struct Complex {
        var re: Double
        var im: Double
        static let zero = Complex(re: 0, im: 0)
        static func + (a: Complex, b: Complex) -> Complex { Complex(re: a.re + b.re, im: a.im + b.im) }
        static func - (a: Complex, b: Complex) -> Complex { Complex(re: a.re - b.re, im: a.im - b.im) }
        static func * (a: Complex, b: Complex) -> Complex {
            Complex(re: a.re * b.re - a.im * b.im, im: a.re * b.im + a.im * b.re)
        }
        static func / (a: Complex, b: Complex) -> Complex {
            let d = b.re * b.re + b.im * b.im
            return Complex(re: (a.re * b.re + a.im * b.im) / d, im: (a.im * b.re - a.re * b.im) / d)
        }
        var magnitudeSquared: Double { re * re + im * im }
    }

    /// Transform of a Hann-windowed decaying partial x[n] = e^{(−α + 2πif)·n/fs}, n = 0..<N, in closed
    /// form. The house Hann window ½ − ½cos(2π(n + ½)/N) is three complex exponentials, so the transform
    /// is three geometric sums (1 − zᴺ)/(1 − z); along a run of bins z turns by a fixed rotation.
    struct PartialModel {
        let length: Double
        let size: Double
        let sampleRate: Double
        private let edgeRe: Double
        private let edgeIm: Double

        init(length: Int, size: Int, sampleRate: Double) {
            self.length = Double(length)
            self.size = Double(size)
            self.sampleRate = sampleRate
            // −¼·e^{±iπ/N}: the weights of the window's two outer exponentials.
            edgeRe = -0.25 * cos(Double.pi / Double(length))
            edgeIm = 0.25 * sin(Double.pi / Double(length))
        }

        /// The transform at frequency theta (Hz).
        func value(frequency f: Double, damping alpha: Double, at theta: Double) -> Complex {
            let decayOne = exp(-alpha / sampleRate), decayAll = exp(-alpha * length / sampleRate)
            var sum = Complex.zero
            for shift in -1...1 {
                let weight = shift == 0 ? Complex(re: 0.5, im: 0) : Complex(re: edgeRe, im: -Double(shift) * edgeIm)
                let phase = 2 * Double.pi * (f - theta) / sampleRate + 2 * Double.pi * Double(shift) / length
                let one = Complex(re: decayOne * cos(phase), im: decayOne * sin(phase))
                let all = Complex(re: decayAll * cos(phase * length), im: decayAll * sin(phase * length))
                sum = sum + weight * PartialModel.geometric(one, all, length)
            }
            return sum
        }

        /// Writes the transform at bins k0..<k0+count (bin k at k·fs/size Hz) to re/im[offset...].
        func write(frequency f: Double, damping alpha: Double, k0: Int, count: Int,
                   re: inout [Double], im: inout [Double], offset: Int) {
            for k in 0..<count {
                re[offset + k] = 0
                im[offset + k] = 0
            }
            let decayOne = exp(-alpha / sampleRate), decayAll = exp(-alpha * length / sampleRate)
            let step = -2 * Double.pi / size
            let turnOneRe = cos(step), turnOneIm = sin(step)
            let turnAllRe = cos(step * length), turnAllIm = sin(step * length)
            let base = 2 * Double.pi * (f - Double(k0) * sampleRate / size) / sampleRate
            for shift in -1...1 {
                let weightRe = shift == 0 ? 0.5 : edgeRe
                let weightIm = shift == 0 ? 0 : -Double(shift) * edgeIm
                let phase = base + 2 * Double.pi * Double(shift) / length
                var oneRe = decayOne * cos(phase), oneIm = decayOne * sin(phase)
                var allRe = decayAll * cos(phase * length), allIm = decayAll * sin(phase * length)
                for k in 0..<count {
                    let g = PartialModel.geometric(Complex(re: oneRe, im: oneIm), Complex(re: allRe, im: allIm), length)
                    re[offset + k] += weightRe * g.re - weightIm * g.im
                    im[offset + k] += weightRe * g.im + weightIm * g.re
                    let nextOne = oneRe * turnOneRe - oneIm * turnOneIm
                    oneIm = oneRe * turnOneIm + oneIm * turnOneRe
                    oneRe = nextOne
                    let nextAll = allRe * turnAllRe - allIm * turnAllIm
                    allIm = allRe * turnAllIm + allIm * turnAllRe
                    allRe = nextAll
                }
            }
        }

        /// (1 − zᴺ)/(1 − z) given z and zᴺ; N at z = 1.
        private static func geometric(_ one: Complex, _ all: Complex, _ n: Double) -> Complex {
            let dr = 1 - one.re, di = -one.im
            let d = dr * dr + di * di
            guard d > 1e-28 else { return Complex(re: n, im: 0) }
            let nr = 1 - all.re, ni = -all.im
            return Complex(re: (nr * dr + ni * di) / d, im: (ni * dr - nr * di) / d)
        }
    }

    /// Ridge least squares of a band of bins as a sum of partials: fixed-frequency ones (other strings)
    /// and one free one, each with its own damping. Column energies and cross products are kept, so a
    /// change to one partial costs one column; evaluations allocate nothing.
    final class BandFit {
        let energy: Double
        let partials: [Double]
        private(set) var damping: [Double]
        private(set) var coefficients: [Complex]
        private let model: PartialModel
        private let k0: Int
        private let count: Int
        private let observedRe: [Double]
        private let observedIm: [Double]
        private var columnRe: [Double]
        private var columnIm: [Double]
        private var gram: [Complex]
        private var projection: [Complex]
        private var matrix: [Complex]
        private var vector: [Complex]

        init(model: PartialModel, re: [Double], im: [Double], k0: Int, count: Int, partials: [Double], damping: Double) {
            self.model = model
            self.k0 = k0
            self.count = count
            self.partials = partials
            observedRe = Array(re[k0..<(k0 + count)])
            observedIm = Array(im[k0..<(k0 + count)])
            var total = 0.0
            for k in 0..<count { total += re[k0 + k] * re[k0 + k] + im[k0 + k] * im[k0 + k] }
            energy = total
            let size = partials.count + 1
            self.damping = .init(repeating: damping, count: size)
            coefficients = .init(repeating: .zero, count: size)
            columnRe = .init(repeating: 0, count: size * count)
            columnIm = .init(repeating: 0, count: size * count)
            gram = .init(repeating: .zero, count: size * size)
            projection = .init(repeating: .zero, count: size)
            matrix = .init(repeating: .zero, count: size * size)
            vector = .init(repeating: .zero, count: size)
            for j in partials.indices { refresh(j, frequency: partials[j]) }
        }

        func setPartial(_ j: Int, damping value: Double) {
            damping[j] = value
            refresh(j, frequency: partials[j])
        }

        func setFree(_ frequency: Double, damping value: Double) {
            damping[partials.count] = value
            refresh(partials.count, frequency: frequency)
        }

        /// Rewrites column j and its cross products.
        private func refresh(_ j: Int, frequency: Double) {
            let size = partials.count + 1
            model.write(frequency: frequency, damping: damping[j], k0: k0, count: count, re: &columnRe, im: &columnIm, offset: j * count)
            var pr = 0.0, pq = 0.0
            for k in 0..<count {
                let ar = columnRe[j * count + k], ai = columnIm[j * count + k]
                pr += ar * observedRe[k] + ai * observedIm[k]
                pq += ar * observedIm[k] - ai * observedRe[k]
            }
            projection[j] = Complex(re: pr, im: pq)
            for i in 0..<size {
                var gr = 0.0, gq = 0.0
                for k in 0..<count {
                    let ar = columnRe[i * count + k], ai = columnIm[i * count + k]
                    let br = columnRe[j * count + k], bi = columnIm[j * count + k]
                    gr += ar * br + ai * bi
                    gq += ar * bi - ai * br
                }
                gram[i * size + j] = Complex(re: gr, im: gq)
                gram[j * size + i] = Complex(re: gr, im: -gq)
            }
        }

        /// Unexplained energy ‖x − Σ cⱼ·columnⱼ‖² for the ridge solution over the first `used` columns
        /// (all by default); the coefficients are kept in `coefficients`.
        @discardableResult
        func residual(using used: Int? = nil) -> Double {
            let size = partials.count + 1
            let m = min(size, used ?? size)
            guard m > 0 else { return energy }
            var trace = 0.0
            for i in 0..<m { trace += gram[i * size + i].re }
            let ridge = PolyTuner.ridge * trace / Double(m)
            for i in 0..<m {
                for j in 0..<m { matrix[i * m + j] = gram[i * size + j] }
                matrix[i * m + i].re += ridge
                vector[i] = projection[i]
            }
            // Hermitian positive definite once ridged: elimination without pivoting.
            for p in 0..<m {
                let pivot = matrix[p * m + p]
                guard pivot.magnitudeSquared > 1e-300 else { continue }
                for r in (p + 1)..<m {
                    let factor = matrix[r * m + p] / pivot
                    for c in p..<m { matrix[r * m + c] = matrix[r * m + c] - factor * matrix[p * m + c] }
                    vector[r] = vector[r] - factor * vector[p]
                }
            }
            for p in stride(from: m - 1, through: 0, by: -1) {
                var sum = vector[p]
                for c in (p + 1)..<m { sum = sum - matrix[p * m + c] * coefficients[c] }
                let pivot = matrix[p * m + p]
                coefficients[p] = pivot.magnitudeSquared > 1e-300 ? sum / pivot : .zero
            }
            for j in m..<size { coefficients[j] = .zero }
            var e = energy
            for i in 0..<m {
                let c = coefficients[i], b = projection[i]
                e -= 2 * (c.re * b.re + c.im * b.im)
                var g = Complex.zero
                for j in 0..<m { g = g + gram[i * size + j] * coefficients[j] }
                e += c.re * g.re + c.im * g.im
            }
            return max(0, e)
        }
    }

    /// Hann-windowed, zero-padded (×2) real transform: vDSP where available, `Fft` elsewhere.
    final class Spectrum {
        let length: Int
        let size: Int
        let window: [Double]
        let windowSum: Double
        /// |X| of a unit impulse; vDSP's packed real transform is scaled by 2.
        private(set) var gain = 1.0
        /// Set if the transform runs e^{+iωn}: outputs are conjugated so the model's phase always matches.
        private var conjugate = false
        #if canImport(Accelerate)
        private let log2n: vDSP_Length
        private let setup: FFTSetupD
        private let packed: UnsafeMutablePointer<Double>
        private let real: UnsafeMutablePointer<Double>
        private let imaginary: UnsafeMutablePointer<Double>
        #else
        private let fft: Fft
        private var real: [Double]
        private var imaginary: [Double]
        #endif

        init(length: Int) {
            self.length = length
            size = 2 * Fft.nextPowerOfTwo(length)
            let hann = (0..<length).map { 0.5 - 0.5 * cos(2 * Double.pi * (Double($0) + 0.5) / Double(length)) }
            window = hann
            windowSum = hann.reduce(0, +)
            #if canImport(Accelerate)
            log2n = vDSP_Length(size.trailingZeroBitCount)
            setup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2))!
            packed = .allocate(capacity: size)
            real = .allocate(capacity: size / 2)
            imaginary = .allocate(capacity: size / 2)
            packed.update(repeating: 0, count: size)
            packed[1] = 1
            #else
            fft = Fft(size: size)
            real = .init(repeating: 0, count: size)
            imaginary = .init(repeating: 0, count: size)
            real[1] = 1
            #endif
            // Calibrate on an impulse at n = 1, whose bin 1 is gain·e^{−2πi/size}.
            run()
            let r1 = real[1], i1 = imaginary[1]
            gain = (r1 * r1 + i1 * i1).squareRoot()
            conjugate = i1 > 0
        }

        #if canImport(Accelerate)
        deinit {
            vDSP_destroy_fftsetupD(setup)
            packed.deallocate(); real.deallocate(); imaginary.deallocate()
        }
        #endif

        /// Transforms samples[0..<length] into re/im (bins 0..<size/2, as Σ x[n]w[n]e^{−2πikn/size} × gain).
        func transform(_ samples: [Float], re: inout [Double], im: inout [Double]) {
            let halfSize = size / 2
            #if canImport(Accelerate)
            let n = length
            samples.withUnsafeBufferPointer { source in
                vDSP_vspdp(source.baseAddress!, 1, packed, 1, vDSP_Length(n))
            }
            window.withUnsafeBufferPointer { w in
                vDSP_vmulD(packed, 1, w.baseAddress!, 1, packed, 1, vDSP_Length(n))
            }
            (packed + n).update(repeating: 0, count: size - n)
            #else
            for j in 0..<size {
                real[j] = j < length ? Double(samples[j]) * window[j] : 0
                imaginary[j] = 0
            }
            #endif
            run()
            for k in 0..<halfSize {
                re[k] = real[k]
                im[k] = conjugate ? -imaginary[k] : imaginary[k]
            }
            // Bin 0 holds DC and Nyquist packed together; never used.
            re[0] = 0
            im[0] = 0
        }

        private func run() {
            #if canImport(Accelerate)
            let halfSize = size / 2
            var split = DSPDoubleSplitComplex(realp: real, imagp: imaginary)
            packed.withMemoryRebound(to: DSPDoubleComplex.self, capacity: halfSize) {
                vDSP_ctozD($0, 2, &split, 1, vDSP_Length(halfSize))
            }
            vDSP_fft_zripD(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
            #else
            fft.transform(real: &real, imaginary: &imaginary)
            #endif
        }
    }
}
