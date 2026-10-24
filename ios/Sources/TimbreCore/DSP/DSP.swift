import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

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
    public var transformSize: Int { size }
    private let size: Int
    private var prefix: [Double]
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
    public init(windowSize: Int) {
        precondition(windowSize >= 8)
        self.windowSize = windowSize
        size = Fft.nextPowerOfTwo(2 * windowSize)
        acf = .init(repeating: 0, count: windowSize); head = acf; tail = acf
        prefix = .init(repeating: 0, count: windowSize + 1)
        #if canImport(Accelerate)
        log2n = vDSP_Length(size.trailingZeroBitCount)
        setup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2))!
        packed = .allocate(capacity: size)
        real = .allocate(capacity: size / 2)
        imaginary = .allocate(capacity: size / 2)
        #else
        fft = Fft(size: size)
        real = .init(repeating: 0, count: size); imaginary = real
        #endif
    }
    #if canImport(Accelerate)
    deinit {
        vDSP_destroy_fftsetupD(setup)
        packed.deallocate(); real.deallocate(); imaginary.deallocate()
    }
    #endif
    /// Linear (zero-padded) autocorrelation via the power spectrum, plus prefix energies for YIN.
    public func compute(_ samples: [Float], offset: Int = 0) {
        precondition(offset >= 0 && offset + windowSize <= samples.count)
        #if canImport(Accelerate)
        let n = windowSize, half = size / 2
        samples.withUnsafeBufferPointer { source in
            vDSP_vspdp(source.baseAddress! + offset, 1, packed, 1, vDSP_Length(n))
        }
        (packed + n).update(repeating: 0, count: size - n)
        var split = DSPDoubleSplitComplex(realp: real, imagp: imaginary)
        packed.withMemoryRebound(to: DSPDoubleComplex.self, capacity: half) { vDSP_ctozD($0, 2, &split, 1, vDSP_Length(half)) }
        vDSP_fft_zripD(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
        // Packed format: real[0] = DC, imaginary[0] = Nyquist.
        let dc = real[0] * real[0], nyquist = imaginary[0] * imaginary[0]
        vDSP_zvmagsD(&split, 1, real, 1, vDSP_Length(half))
        imaginary.update(repeating: 0, count: half)
        real[0] = dc; imaginary[0] = nyquist
        vDSP_fft_zripD(setup, &split, 1, log2n, FFTDirection(FFT_INVERSE))
        packed.withMemoryRebound(to: DSPDoubleComplex.self, capacity: half) { vDSP_ztocD(&split, 1, $0, 2, vDSP_Length(half)) }
        // Forward real FFT is scaled by 2 and the inverse by N, so |2X|^2 returns 4N r.
        var scale = 1.0 / (4.0 * Double(size))
        acf.withUnsafeMutableBufferPointer { vDSP_vsmulD(packed, 1, &scale, $0.baseAddress!, 1, vDSP_Length(n)) }
        #else
        for j in 0..<size { real[j] = j < windowSize ? Double(samples[offset + j]) : 0; imaginary[j] = 0 }
        fft.transform(real: &real, imaginary: &imaginary)
        for k in 0..<size { real[k] = real[k] * real[k] + imaginary[k] * imaginary[k]; imaginary[k] = 0 }
        fft.inverse(real: &real, imaginary: &imaginary)
        for lag in 0..<windowSize { acf[lag] = real[lag] }
        #endif
        prefix[0] = 0
        for j in 0..<windowSize {
            let s = Double(samples[offset + j]); prefix[j + 1] = prefix[j] + s * s
        }
        for lag in 0..<windowSize {
            head[lag] = prefix[windowSize - lag]; tail[lag] = prefix[windowSize] - prefix[lag]
        }
    }
}
