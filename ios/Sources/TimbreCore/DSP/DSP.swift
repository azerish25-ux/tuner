import Foundation

public struct DetectedPitch: Equatable, Sendable {
    public let frequencyHz: Double
    public let confidence: Double
    public let levelDbfs: Double
    public init(frequencyHz: Double, confidence: Double, levelDbfs: Double) {
        self.frequencyHz = frequencyHz
        self.confidence = DspMath.clamp01(confidence)
        self.levelDbfs = levelDbfs
    }
}

public enum DspMath {
    public static func clamp01(_ value: Double) -> Double { value.isNaN ? 0 : min(1, max(0, value)) }
    public static func rmsDbfs(_ samples: [Float]) -> Double {
        guard !samples.isEmpty else { return -200 }
        let power = samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count)
        guard power.isFinite, power > 1e-24 else { return -200 }
        return 10 * log10(power)
    }
    public static func levelFactor(_ level: Double, silence: Double, full: Double = -45) -> Double {
        full <= silence ? 1 : clamp01((level - silence) / (full - silence))
    }
}

/// Radix-2 transform matching the Android implementation. Instances cache twiddles and bit reversal.
public final class Fft {
    public let size: Int
    private let cosTable: [Double]
    private let sinTable: [Double]
    private let reverse: [Int]
    public init(size: Int) {
        precondition(size >= 2 && size & (size - 1) == 0)
        self.size = size
        cosTable = (0..<(size / 2)).map { cos(2 * Double.pi * Double($0) / Double(size)) }
        sinTable = (0..<(size / 2)).map { sin(2 * Double.pi * Double($0) / Double(size)) }
        let levels = size.trailingZeroBitCount
        reverse = (0..<size).map { index in
            var source = index, result = 0
            for _ in 0..<levels { result = (result << 1) | (source & 1); source >>= 1 }
            return result
        }
    }
    public static func nextPowerOfTwo(_ value: Int) -> Int {
        var n = 2
        while n < value { n <<= 1 }
        return n
    }
    public func transform(real: inout [Double], imaginary: inout [Double]) {
        precondition(real.count == size && imaginary.count == size)
        for i in 0..<size where reverse[i] > i {
            real.swapAt(i, reverse[i]); imaginary.swapAt(i, reverse[i])
        }
        var span = 2
        while span <= size {
            let half = span / 2, step = size / span
            for base in stride(from: 0, to: size, by: span) {
                for offset in 0..<half {
                    let j = base + offset, l = j + half, k = offset * step
                    let tre = real[l] * cosTable[k] + imaginary[l] * sinTable[k]
                    let tim = -real[l] * sinTable[k] + imaginary[l] * cosTable[k]
                    real[l] = real[j] - tre; imaginary[l] = imaginary[j] - tim
                    real[j] += tre; imaginary[j] += tim
                }
            }
            span <<= 1
        }
    }
    public func inverse(real: inout [Double], imaginary: inout [Double]) {
        for i in 0..<size { imaginary[i] = -imaginary[i] }
        transform(real: &real, imaginary: &imaginary)
        for i in 0..<size { real[i] /= Double(size); imaginary[i] /= -Double(size) }
    }
}

public final class Autocorrelation {
    public let windowSize: Int
    public private(set) var acf: [Double]
    public private(set) var head: [Double]
    public private(set) var tail: [Double]
    public var transformSize: Int { fft.size }
    private let fft: Fft
    private var real: [Double]
    private var imaginary: [Double]
    private var prefix: [Double]
    public init(windowSize: Int) {
        precondition(windowSize >= 8)
        self.windowSize = windowSize
        fft = Fft(size: Fft.nextPowerOfTwo(2 * windowSize))
        real = .init(repeating: 0, count: fft.size); imaginary = real
        acf = .init(repeating: 0, count: windowSize); head = acf; tail = acf
        prefix = .init(repeating: 0, count: windowSize + 1)
    }
    public func compute(_ samples: [Float], offset: Int = 0) {
        precondition(offset >= 0 && offset + windowSize <= samples.count)
        for j in 0..<fft.size { real[j] = j < windowSize ? Double(samples[offset + j]) : 0; imaginary[j] = 0 }
        fft.transform(real: &real, imaginary: &imaginary)
        for k in 0..<fft.size { real[k] = real[k] * real[k] + imaginary[k] * imaginary[k]; imaginary[k] = 0 }
        fft.inverse(real: &real, imaginary: &imaginary)
        prefix[0] = 0
        for j in 0..<windowSize {
            let s = Double(samples[offset + j]); prefix[j + 1] = prefix[j] + s * s
        }
        for lag in 0..<windowSize {
            acf[lag] = real[lag]; head[lag] = prefix[windowSize - lag]; tail[lag] = prefix[windowSize] - prefix[lag]
        }
    }
}
