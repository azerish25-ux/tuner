import Foundation

/// One Euro filter (Casiez et al. 2012): heavy smoothing when the value is still,
/// little lag when it moves fast. Used to drive the needle, strobe and 3D peg at the
/// display rate from pitch readings that arrive at a lower, irregular rate.
public struct OneEuroFilter: Sendable {
    public var minCutoff: Double
    public var beta: Double
    public var derivativeCutoff: Double
    private var value: Double?
    private var derivative = 0.0
    private var lastTime: Double?

    public init(minCutoff: Double = 1.6, beta: Double = 0.02, derivativeCutoff: Double = 1.0) {
        self.minCutoff = minCutoff; self.beta = beta; self.derivativeCutoff = derivativeCutoff
    }

    public var current: Double? { value }

    public mutating func reset() { value = nil; derivative = 0; lastTime = nil }

    /// - Parameters: sample is the latest raw value, time is seconds on a monotonic clock.
    public mutating func filter(_ sample: Double, at time: Double) -> Double {
        guard sample.isFinite else { return value ?? 0 }
        guard let previous = value, let last = lastTime, time > last else {
            value = sample; lastTime = time; derivative = 0
            return sample
        }
        let dt = min(0.25, time - last)
        let rawDerivative = (sample - previous) / dt
        derivative += Self.alpha(cutoff: derivativeCutoff, dt: dt) * (rawDerivative - derivative)
        let cutoff = minCutoff + beta * abs(derivative)
        let next = previous + Self.alpha(cutoff: cutoff, dt: dt) * (sample - previous)
        value = next; lastTime = time
        return next
    }

    static func alpha(cutoff: Double, dt: Double) -> Double {
        let tau = 1 / (2 * Double.pi * cutoff)
        return 1 / (1 + tau / dt)
    }
}

/// Integrates a strobe pattern's phase: it drifts at a speed proportional to the
/// pitch error and stands still in tune. Positive cents (sharp) drift right.
public struct StrobePhase: Sendable {
    public var bandsPerSecondPerCent: Double
    public private(set) var phase = 0.0
    public init(bandsPerSecondPerCent: Double = 0.06) { self.bandsPerSecondPerCent = bandsPerSecondPerCent }
    public mutating func advance(cents: Double?, dt: Double) -> Double {
        guard let cents, cents.isFinite, dt.isFinite, dt > 0 else { return phase }
        let clamped = max(-50, min(50, cents))
        phase = (phase + clamped * bandsPerSecondPerCent * min(dt, 0.1)).truncatingRemainder(dividingBy: 1)
        if phase < 0 { phase += 1 }
        return phase
    }
}
