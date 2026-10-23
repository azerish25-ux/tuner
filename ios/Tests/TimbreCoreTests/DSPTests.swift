import XCTest
@testable import TimbreCore

final class DSPTests: XCTestCase {
    private func tone(_ hz: Double, rate: Double = 48000, count: Int = 4096, harmonics: Bool = false) -> [Float] {
        (0..<count).map { i in
            let phase = 2 * Double.pi * hz * Double(i) / rate
            return Float(0.45 * sin(phase) + (harmonics ? 0.25 * sin(2 * phase) + 0.15 * sin(3 * phase) : 0))
        }
    }
    func testYinAccuracyAcrossRangeAndSampleRates() throws {
        for rate in [44100.0, 48000.0] {
            for hz in [30.3, 41.203, 82.86, 110, 440, 880, 1760, 4040.17, 4186] {
                let reading = try XCTUnwrap(YinPitchDetector(sampleRate: rate).detect(tone(hz, rate: rate)))
                XCTAssertLessThan(abs(1200 * log2(reading.frequencyHz / hz)), 1.0, "\(rate) Hz sample rate, \(hz) Hz tone")
                XCTAssertGreaterThan(reading.confidence, 0.9)
            }
        }
    }
    func testSilenceShortFramesAndNoiseAreRejected() {
        let detector = YinPitchDetector()
        XCTAssertNil(detector.detect([]))
        XCTAssertNil(detector.detect([Float](repeating: 0, count: 4096)))
        var seed: UInt64 = 42
        let noise: [Float] = (0..<4096).map { _ in
            seed = seed &* 6364136223846793005 &+ 1
            return Float(Double(seed >> 32) / Double(UInt32.max) - 0.5)
        }
        XCTAssertNil(detector.detect(noise))
        XCTAssertNil(MpmPitchDetector().detect(noise))
    }
    func testHarmonicsDoNotCauseOctaveErrors() throws {
        for hz in [41.203, 82.41, 146.83, 440] {
            let samples = tone(hz, harmonics: true)
            let yin = try XCTUnwrap(YinPitchDetector().detect(samples))
            let mpm = try XCTUnwrap(MpmPitchDetector().detect(samples))
            XCTAssertLessThan(abs(1200 * log2(yin.frequencyHz / hz)), 2)
            XCTAssertLessThan(abs(1200 * log2(mpm.frequencyHz / hz)), 2)
        }
    }
    func testFFTAutocorrelationMatchesDirectDefinition() {
        let samples = tone(423, count: 100)
        let ac = Autocorrelation(windowSize: samples.count)
        ac.compute(samples)
        for lag in 0..<samples.count {
            let direct = (0..<(samples.count - lag)).reduce(0.0) { $0 + Double(samples[$1]) * Double(samples[$1 + lag]) }
            XCTAssertEqual(ac.acf[lag], direct, accuracy: 1e-8)
        }
    }
    func testLevelConfidenceFallsNearSilence() throws {
        let quiet = tone(440).map { $0 * 0.006 }
        XCTAssertGreaterThan(DspMath.rmsDbfs(quiet), -60)
        XCTAssertLessThan(DspMath.rmsDbfs(quiet), -51)
        let reading = try XCTUnwrap(YinPitchDetector().detect(quiet))
        XCTAssertLessThan(reading.confidence, 0.6)
        XCTAssertGreaterThan(reading.confidence, 0)
        XCTAssertNil(YinPitchDetector().detect(tone(440).map { $0 * 0.003 }), "Below Android's -60 dBFS floor must remain silence")
    }
    func testNoisyRehearsalSignalRetainsPitch() throws {
        for hz in [82.86, 440, 1760] {
            let clean = tone(hz)
            var seed: UInt64 = 123
            let noisy: [Float] = clean.map { sample in
                seed = seed &* 6364136223846793005 &+ 1
                // Uniform noise scaled to approximately 30 dB signal-to-noise ratio.
                let noise = (Double(seed >> 32) / Double(UInt32.max) - 0.5) * 0.03485
                return sample + Float(noise)
            }
            let reading = try XCTUnwrap(YinPitchDetector().detect(noisy))
            XCTAssertLessThan(abs(1200 * log2(reading.frequencyHz / hz)), 3)
        }
    }
    func testLowToneOutsideWindowReachIsRejected() {
        XCTAssertNil(YinPitchDetector().detect(tone(30, count: 2048)))
    }
    func testFFTForwardInverseRoundTrip() {
        let fft = Fft(size: 128)
        let original = (0..<128).map { sin(Double($0) * 0.37) }
        var real = original
        var imaginary = [Double](repeating: 0, count: 128)
        fft.transform(real: &real, imaginary: &imaginary)
        fft.inverse(real: &real, imaginary: &imaginary)
        for i in 0..<128 {
            XCTAssertEqual(real[i], original[i], accuracy: 1e-10)
            XCTAssertEqual(imaginary[i], 0, accuracy: 1e-10)
        }
    }
    func testAndroidAdaptiveWindowDetunedSweep() throws {
        let frequencies = [30.0, 41.2, 55, 65.41, 82.41, 110, 146.83, 196, 246.94, 329.63, 440, 587.33, 880, 1174.66, 1760, 2349.32, 3000, 3520, 4000]
        for anchor in frequencies {
            let expected = anchor * pow(2, 17.3 / 1200)
            let count = anchor < 82 ? 4096 : 2048
            let reading = try XCTUnwrap(YinPitchDetector().detect(tone(expected, count: count)))
            XCTAssertLessThan(abs(1200 * log2(reading.frequencyHz / expected)), 1, "Adaptive \(count)-sample window, \(expected) Hz")
        }
    }
    func testExtendedCalibratedPianoBounds() throws {
        let detector = YinPitchDetector(minFrequency: 18, maxFrequency: 5100)
        for expected in [20.0, 25.0, 4433.0, 4700.0] {
            let count = AnalysisWindowPolicy.windowSizeForTuningRange(minFrequencyHz: 18, sampleRateHz: 48000)
            let reading = try XCTUnwrap(detector.detect(tone(expected, count: count)))
            XCTAssertLessThan(abs(1200 * log2(reading.frequencyHz / expected)), 2)
        }
    }

    /// Accuracy bench: decaying plucks with noise, detuned off the grid, analysed with the
    /// production window policy at 48 kHz. Harmonic strings must read within 0.75 cent.
    /// Stiff strings run their upper partials sharp, so the periodicity (and the pitch a
    /// listener hears) sits slightly above the fundamental: the reading may be up to
    /// 5.5 cents sharp of the fundamental partial, and never flat of it.
    func testPluckedStringAccuracyBench() throws {
        let rate = 48000.0
        var seed: UInt64 = 7
        func noise() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33) / Double(1 << 31) - 0.5 }
        var worst: [Bool: Double] = [:]
        for stiff in [false, true] {
            for midi in [28, 33, 40, 45, 50, 55, 59, 64, 67, 69, 76] {
                for detune in [-23.0, -3.7, 0.0, 4.2, 31.0] {
                    let f0 = 440 * pow(2, (Double(midi) - 69 + detune / 100) / 12)
                    let window = AnalysisWindowPolicy.windowSizeForTuningRange(minFrequencyHz: f0 / 1.12, sampleRateHz: Int(rate))
                    let b = stiff ? (midi < 45 ? 1.2e-4 : 4e-5) : 0
                    let samples: [Float] = (0..<window).map { i in
                        let t = Double(i) / rate + 0.15
                        var v = 0.0
                        for n in 1...12 {
                            let fn = Double(n) * f0 * sqrt(1 + b * Double(n * n))
                            v += exp(-t * (0.8 + 0.35 * Double(n))) / Double(n) * sin(2 * .pi * fn * t + Double(n))
                        }
                        return Float(0.35 * v + 0.004 * noise())
                    }
                    let detector = YinPitchDetector(sampleRate: rate, minFrequency: f0 / 1.12 / 1.12, maxFrequency: f0 * 2.5)
                    let reading = try XCTUnwrap(detector.detect(samples), "midi \(midi) detune \(detune)")
                    let error = 1200 * log2(reading.frequencyHz / f0)
                    worst[stiff] = max(worst[stiff] ?? 0, abs(error))
                    if stiff {
                        XCTAssert((-0.75...5.5).contains(error), "stiff midi \(midi) detune \(detune): \(error) cents")
                    } else {
                        XCTAssertLessThan(abs(error), 0.75, "midi \(midi) detune \(detune): \(error) cents")
                    }
                }
            }
        }
        print("Accuracy bench worst error: harmonic \(worst[false] ?? 0) cents, stiff \(worst[true] ?? 0) cents")
    }
}


