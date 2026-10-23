import AVFoundation

/// Short synthesized interface sounds (right answer, wrong answer, star, count-in click).
/// They play through AVAudioPlayer so they never interrupt the microphone capture.
@MainActor
final class SoundFX {
    static let shared = SoundFX()
    enum Cue: CaseIterable { case correct, wrong, star, click, accent, complete, hit, levelUp }
    var enabled = true
    private var players: [Cue: AVAudioPlayer] = [:]

    private init() {
        for cue in Cue.allCases {
            if let player = try? AVAudioPlayer(data: Self.render(cue)) {
                player.volume = cue == .click || cue == .accent ? 0.5 : 0.35
                player.prepareToPlay()
                players[cue] = player
            }
        }
    }

    func play(_ cue: Cue) {
        guard enabled, let player = players[cue] else { return }
        player.currentTime = 0
        player.play()
    }

    /// Notes (MIDI, start seconds, length seconds) of each cue: soft plucked partials with a fast decay.
    private static func notes(_ cue: Cue) -> [(Int, Double, Double)] {
        switch cue {
        case .correct: return [(76, 0, 0.25), (83, 0.08, 0.35)]
        case .wrong: return [(52, 0, 0.18), (51, 0.09, 0.22)]
        case .star: return [(84, 0, 0.35), (88, 0.06, 0.35), (91, 0.12, 0.5)]
        case .click: return [(96, 0, 0.03)]
        case .accent: return [(103, 0, 0.04)]
        case .complete: return [(72, 0, 0.4), (76, 0.1, 0.4), (79, 0.2, 0.4), (84, 0.3, 0.8)]
        case .hit: return [(91, 0, 0.12)]
        case .levelUp: return [(72, 0, 0.3), (76, 0.08, 0.3), (79, 0.16, 0.3), (84, 0.24, 0.35), (88, 0.32, 0.45), (91, 0.4, 0.9)]
        }
    }

    private static func render(_ cue: Cue) -> Data {
        let rate = 44_100.0
        let parts = notes(cue)
        let length = (parts.map { $0.1 + $0.2 }.max() ?? 0.1) + 0.05
        var samples = [Float](repeating: 0, count: Int(length * rate))
        for (midi, start, duration) in parts {
            let hz = 440 * pow(2, Double(midi - 69) / 12)
            let first = Int(start * rate), count = Int(duration * rate)
            for i in 0..<count where first + i < samples.count {
                let t = Double(i) / rate
                let envelope = min(1, t / 0.004) * exp(-t * (cue == .click || cue == .accent ? 90 : 7))
                let tone = sin(2 * .pi * hz * t) + 0.25 * sin(4 * .pi * hz * t) + 0.08 * sin(6 * .pi * hz * t)
                samples[first + i] += Float(0.32 * envelope * tone)
            }
        }
        return wav(samples, rate: Int(rate))
    }

    private static func wav(_ samples: [Float], rate: Int) -> Data {
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        let bytes = samples.count * 2
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + bytes)); data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(rate)); append(UInt32(rate * 2)); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(UInt32(bytes))
        for sample in samples { append(Int16(max(-1, min(1, sample)) * Float(Int16.max))) }
        return data
    }
}
