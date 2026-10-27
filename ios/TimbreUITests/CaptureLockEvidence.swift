import Foundation

/// Screenshot-test evidence only: a dense, fresh run of actual readout states, not elapsed
/// time extrapolated from a single accessibility snapshot. Both processes use system uptime.
enum CaptureLockEvidence {
    struct Sample: Codable {
        let time: Double
        let locked: Bool
        let active: Bool
        let target: Double
        let stage: String
    }

    static let maximumGap = 0.3

    static func samples(_ data: Data) -> [Sample] {
        // An in-flight final append is incomplete evidence, never a fabricated state.
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var result: [Sample] = []
        let lines = text.components(separatedBy: "\n")
        // Only a trailing unfinished line may be ignored. A malformed complete record fails closed.
        for line in lines.dropLast() where !line.isEmpty {
            guard let sample = try? JSONDecoder().decode(Sample.self, from: Data(line.utf8)) else { return [] }
            result.append(sample)
        }
        return result
    }

    static func held(_ samples: [Sample], since start: Double, now: Double,
                     seconds: Double = 1.5, window: Double = 7, stages: Set<String>) -> Bool {
        guard start.isFinite, now.isFinite, now >= start, now <= start + window,
              seconds.isFinite, window.isFinite, seconds > 0, seconds <= window else { return false }
        var began: Double?
        var previous: Sample?
        for sample in samples {
            guard sample.time.isFinite, sample.target.isFinite, sample.target > 0, sample.time <= now else { return false }
            if sample.time < start { continue }
            if let previous, sample.time <= previous.time { return false }
            let continuous = previous.map {
                sample.time > $0.time && sample.time - $0.time <= maximumGap &&
                abs(sample.target - $0.target) < 0.001 && sample.stage == $0.stage
            } ?? false
            if !continuous { began = nil }
            if sample.locked && sample.active && stages.contains(sample.stage) {
                if began == nil { began = sample.time }
            } else {
                began = nil
            }
            previous = sample
        }
        guard let began, let previous, now - previous.time <= maximumGap else { return false }
        return previous.time - began >= seconds
    }
}
