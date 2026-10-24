import CoreHaptics
import UIKit

/// Tuning feel: a light detent per cent near the target, a firm lock, a soft chord when done.
@MainActor
final class Haptics {
    static let shared = Haptics()
    var enabled = true
    private var engine: CHHapticEngine?
    private let fallback = UIImpactFeedbackGenerator(style: .light)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private var lastDetent: Int?

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        engine?.resetHandler = { [weak self] in Task { @MainActor in try? self?.engine?.start() } }
    }

    private func play(_ events: [CHHapticEvent]) -> Bool {
        guard enabled, let engine else { return false }
        do {
            try engine.start()
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch { return false }
    }

    private static func tap(_ intensity: Float, _ sharpness: Float, at time: TimeInterval = 0) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time)
    }

    /// Call with every smoothed reading; fires once per whole cent inside ±5¢.
    func detent(cents: Double?) {
        guard enabled, let cents, abs(cents) <= 5 else { lastDetent = nil; return }
        let step = Int(cents.rounded())
        guard step != lastDetent else { return }
        lastDetent = step
        if !play([Self.tap(0.28 + Float(5 - abs(step)) * 0.05, 0.85)]) { fallback.impactOccurred(intensity: 0.35) }
    }

    func lock() {
        guard enabled else { return }
        let thump = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
        ], relativeTime: 0.02, duration: 0.09)
        if !play([Self.tap(1.0, 0.55), thump]) { rigid.impactOccurred() }
    }

    func done() {
        guard enabled else { return }
        if !play([Self.tap(0.6, 0.4), Self.tap(0.75, 0.5, at: 0.09), Self.tap(1.0, 0.65, at: 0.18)]) { rigid.impactOccurred() }
    }

    func selection() {
        guard enabled else { return }
        if !play([Self.tap(0.45, 0.7)]) { fallback.impactOccurred() }
    }

    func beat(accent: Bool) {
        guard enabled else { return }
        _ = play([Self.tap(accent ? 0.9 : 0.45, accent ? 0.75 : 0.5)])
    }
}
