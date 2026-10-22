import XCTest
@testable import TimbreCore
final class OutputAudioTests: XCTestCase {
    private func amplitude(_ samples: [Float], frequency: Double, rate: Double = 48000) -> Double {
        var sine = 0.0, cosine = 0.0
        for index in samples.indices {
            let phase = 2 * Double.pi * frequency * Double(index) / rate
            sine += Double(samples[index]) * sin(phase); cosine += Double(samples[index]) * cos(phase)
        }
        return 2 * sqrt(sine * sine + cosine * cosine) / Double(samples.count)
    }
    func testLowReferencesRetainFundamentalAndAudibleHarmonics() {
        for hz in [27.5, 30.87, 41.2, 55] {
            let waveform = ReferenceToneWaveform(frequencyHz: hz)
            let samples = (0..<48000).map { waveform.sample(frame: Int64($0)) }
            XCTAssertGreaterThan(amplitude(samples, frequency: hz), 0.35)
            XCTAssertGreaterThan(amplitude(samples, frequency: hz * 4), 0.18)
            XCTAssertGreaterThan(amplitude(samples, frequency: hz * 6), 0.18)
            XCTAssertGreaterThan(amplitude(samples, frequency: hz * ceil(200 / hz)), 0.18)
            let rms = sqrt(samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count))
            XCTAssertTrue((0.68...0.73).contains(rms))
            XCTAssertLessThan(samples.map { abs($0) }.max()!, 1.6)
        }
    }
    func testHigherReferencesRemainPureAndDetectorFindsLowFundamental() throws {
        for hz in [220.0, 440, 4186.01] {
            let waveform = ReferenceToneWaveform(frequencyHz: hz)
            let samples = (0..<48000).map { waveform.sample(frame: Int64($0)) }
            XCTAssertLessThan(amplitude(samples, frequency: hz * 2), 0.02)
        }
        let low = ReferenceToneWaveform(frequencyHz: 27.5)
        let pitch = try XCTUnwrap(YinPitchDetector().detect((0..<8192).map { low.sample(frame: Int64($0)) * 0.2 }))
        XCTAssertLessThan(abs(1200 * log2(pitch.frequencyHz / 27.5)), 1)
    }
    func testFiniteToneEnvelopeAndNaturalEnd() {
        let renderer = ReferenceToneRenderer(frequencyHz: 440, durationMs: 100)
        XCTAssertEqual(renderer.nextSample(), 0)
        for _ in 1..<4800 { _ = renderer.nextSample() }
        XCTAssertEqual(renderer.nextSample(), 0)
        XCTAssertFalse(renderer.isPlaying)
    }
    func testMetronomePulsesAndAccentsFollowSampleTime() {
        let renderer = MetronomeRenderer(initial: MetronomePattern(bpm: 120, beatsPerBar: 3, subdivision: 2))
        var buffer = [Float](repeating: 0, count: 96000)
        let pulses = renderer.render(&buffer)
        XCTAssertEqual(pulses.map(\.frame), [0,12000,24000,36000,48000,60000,72000,84000])
        XCTAssertEqual(pulses.map(\.beat), [0,0,1,1,2,2,0,0])
        XCTAssertEqual(pulses.filter(\.accent).map(\.frame), [0,72000])
        XCTAssertTrue(buffer.allSatisfy { $0.isFinite && abs($0) <= 0.3 })
    }
    func testMetronomeChunkIndependenceAndTempoPhase() {
        let pattern = MetronomePattern(bpm: 137, beatsPerBar: 4, subdivision: 3)
        let single = MetronomeRenderer(initial: pattern), chunked = MetronomeRenderer(initial: pattern)
        var expected = [Float](repeating: 0, count: 48000)
        let expectedPulses = single.render(&expected)
        var actual: [Float] = [], pulses: [MetronomePulse] = []
        while actual.count < 48000 {
            var block = [Float](repeating: 0, count: min(1024, 48000 - actual.count))
            pulses += chunked.render(&block); actual += block
        }
        XCTAssertEqual(actual, expected); XCTAssertEqual(pulses, expectedPulses)
        let renderer = MetronomeRenderer(initial: MetronomePattern(bpm: 120))
        var first = [Float](repeating: 0, count: 12000); _ = renderer.render(&first)
        renderer.update(MetronomePattern(bpm: 60))
        var second = [Float](repeating: 0, count: 24001)
        XCTAssertEqual(renderer.render(&second).map(\.frame), [36000])
    }
}
