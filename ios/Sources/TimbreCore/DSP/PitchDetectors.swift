import Foundation

/// FFT-accelerated YIN, including Android's raw-difference least-squares interpolation corrections.
/// Each instance belongs to one serial audio-analysis queue.
public final class YinPitchDetector {
    private final class Frame {
        let ac: Autocorrelation
        var difference: [Double]
        var cmnd: [Double]
        init(_ n: Int) { ac = Autocorrelation(windowSize: n); difference = .init(repeating: 0, count: n); cmnd = difference }
    }
    public let sampleRate: Double
    public let minFrequency: Double
    public let maxFrequency: Double
    public let silenceDbfs: Double
    public let threshold: Double
    private var frames: [Int: Frame] = [:]
    public init(sampleRate: Double = 48000, minFrequency: Double = 25, maxFrequency: Double = 4200, silenceDbfs: Double = -60, threshold: Double = 0.30) {
        precondition(sampleRate.isFinite && sampleRate > 0 && minFrequency > 0 && maxFrequency > minFrequency)
        self.sampleRate = sampleRate; self.minFrequency = minFrequency; self.maxFrequency = maxFrequency
        self.silenceDbfs = silenceDbfs; self.threshold = threshold
    }
    public func reset() {}
    public func detect(_ samples: [Float]) -> DetectedPitch? {
        let n = samples.count
        guard n >= 64, samples.allSatisfy({ $0.isFinite }) else { return nil }
        let level = DspMath.rmsDbfs(samples)
        guard level >= silenceDbfs else { return nil }
        let minLag = max(2, Int(ceil(sampleRate / maxFrequency)))
        let maxLag = min(n / 2 - 1, Int(floor(sampleRate / minFrequency)))
        guard maxLag > minLag + 1 else { return nil }
        let frame: Frame
        if let cached = frames[n] { frame = cached } else {
            frame = Frame(n)
            // The production pipeline uses two frame lengths; bound cache for arbitrary callers too.
            if frames.count >= 2 { frames.removeAll(keepingCapacity: true) }
            frames[n] = frame
        }
        frame.ac.compute(samples)
        frame.cmnd[0] = 1
        var running = 0.0
        for tau in 0..<n {
            frame.difference[tau] = frame.ac.head[tau] + frame.ac.tail[tau] - 2 * frame.ac.acf[tau]
            if tau > 0 {
                running += frame.difference[tau]
                frame.cmnd[tau] = running <= 0 ? 1 : frame.difference[tau] * Double(tau) / running
            }
        }
        var selected: Int?
        for t in minLag..<maxLag where frame.cmnd[t] < threshold {
            var tau = t
            while tau > minLag && frame.difference[tau - 1] < frame.difference[tau] { tau -= 1 }
            while tau + 1 < maxLag && frame.difference[tau + 1] < frame.difference[tau] { tau += 1 }
            selected = tau; break
        }
        guard let tau = selected else { return nil }
        let period = interpolatedPeriod(frame.difference, tau: tau)
        guard period > 0 else { return nil }
        let frequency = sampleRate / period
        guard frequency >= minFrequency && frequency <= maxFrequency else { return nil }
        return DetectedPitch(frequencyHz: frequency, confidence: DspMath.clamp01(1 - frame.cmnd[tau]) * DspMath.levelFactor(level, silence: silenceDbfs), levelDbfs: level)
    }
    private func interpolatedPeriod(_ difference: [Double], tau: Int) -> Double {
        let h = min(8, max(1, tau / 32))
        guard tau - h >= 1 && tau + h < difference.count else { return Double(tau) }
        var s0 = 0.0, s1 = 0.0, s2 = 0.0, sumU2 = 0.0, sumU4 = 0.0
        for u in -h...h {
            let d = difference[tau + u], u2 = Double(u * u)
            s0 += d; s1 += Double(u) * d; s2 += u2 * d; sumU2 += u2; sumU4 += u2 * u2
        }
        let count = Double(2 * h + 1), denominator = count * sumU4 - sumU2 * sumU2
        guard denominator != 0 else { return Double(tau) }
        let curvature = (count * s2 - sumU2 * s0) / denominator
        guard curvature > 0 else { return Double(tau) }
        let shift = -s1 / (2 * sumU2 * curvature)
        guard shift.isFinite && abs(shift) <= Double(h) else { return Double(tau) }
        return Double(tau) + shift
    }
}

/// McLeod alternative with the Android shoulder exclusion and first qualifying NSDF peak selection.
public final class MpmPitchDetector {
    private let sampleRate: Double, minFrequency: Double, maxFrequency: Double, silenceDbfs: Double
    private var cached: Autocorrelation?
    public init(sampleRate: Double = 48000, minFrequency: Double = 25, maxFrequency: Double = 4200, silenceDbfs: Double = -60) {
        precondition(sampleRate.isFinite && sampleRate > 0 && minFrequency > 0 && maxFrequency > minFrequency)
        self.sampleRate = sampleRate; self.minFrequency = minFrequency; self.maxFrequency = maxFrequency; self.silenceDbfs = silenceDbfs
    }
    public func reset() {}
    public func detect(_ samples: [Float]) -> DetectedPitch? {
        let n = samples.count, level = DspMath.rmsDbfs(samples)
        guard n >= 64, level >= silenceDbfs, samples.allSatisfy({ $0.isFinite }) else { return nil }
        let minLag = max(2, Int(floor(sampleRate / maxFrequency)))
        let maxLag = min(n / 2 - 1, Int(floor(sampleRate / minFrequency)))
        guard maxLag > minLag + 1 else { return nil }
        if cached?.windowSize != n { cached = Autocorrelation(windowSize: n) }
        guard let ac = cached else { return nil }
        ac.compute(samples)
        let nsdf = (0..<n).map { tau -> Double in
            let m = ac.head[tau] + ac.tail[tau]
            return m <= 1e-12 ? 0 : 2 * ac.acf[tau] / m
        }
        var shoulder = 1
        while shoulder <= maxLag && nsdf[shoulder] > 0 { shoulder += 1 }
        let start = max(minLag, shoulder)
        guard start < maxLag, let peakHeight = nsdf[start...maxLag].max(), peakHeight >= 0.50 else { return nil }
        guard var tau = (start...maxLag).first(where: { nsdf[$0] >= 0.85 * peakHeight }) else { return nil }
        while tau + 1 <= maxLag && nsdf[tau + 1] > nsdf[tau] { tau += 1 }
        let denominator = 2 * (2 * nsdf[tau] - nsdf[tau + 1] - nsdf[tau - 1])
        let shift = denominator == 0 ? 0 : (nsdf[tau + 1] - nsdf[tau - 1]) / denominator
        let period = Double(tau) + (shift.isFinite && abs(shift) <= 1 ? shift : 0)
        let frequency = sampleRate / period
        guard frequency >= minFrequency && frequency <= maxFrequency else { return nil }
        return DetectedPitch(frequencyHz: frequency, confidence: DspMath.clamp01(nsdf[tau]) * DspMath.levelFactor(level, silence: silenceDbfs), levelDbfs: level)
    }
}
