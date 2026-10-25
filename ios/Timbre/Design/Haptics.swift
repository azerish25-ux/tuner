import CoreHaptics
import UIKit

/// Tuning feel. By default: a light detent per cent near the target, a firm lock, a soft chord when done.
///
/// With Tune by feel (`byFeel`), the detents give way to beating: while a string is heard, the phone throbs at the
/// rate the string beats against its target (as two strings a few cents apart beat when you tune by ear), fast when
/// far, slower and slower as it comes in, then still at the lock and one firm thump. The tuner feeds it every reading
/// through `feel(_:)` (installed as `AppStore.onTunerFrame`); everything else (lessons, games, the metronome) taps
/// as before.
@MainActor
final class Haptics {
    static let shared = Haptics()
    var enabled = true {
        didSet { if !enabled { stopBeating() } }
    }
    /// Settings › Tune by feel: beating in place of the per-cent detents.
    var byFeel = false {
        didSet { if !byFeel { stopBeating() } }
    }
    private var engine: CHHapticEngine?
    private let fallback = UIImpactFeedbackGenerator(style: .light)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private var lastDetent: Int?

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        // Haptics only: the engine never claims the audio session the tuner records through.
        engine?.playsHapticsOnly = true
        engine?.isAutoShutdownEnabled = true
        engine?.resetHandler = { [weak self] in
            Task { @MainActor in
                // A reset invalidates every player: the beat starts again on its next frame.
                self?.beatPlayer = nil
                try? self?.engine?.start()
            }
        }
        engine?.stoppedHandler = { [weak self] _ in
            Task { @MainActor in self?.beatPlayer = nil }
        }
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

    // MARK: - Tune by feel

    /// One continuous event, looped, whose strength the tuner's frames modulate into the beat.
    private var beatPlayer: CHHapticAdvancedPatternPlayer?
    /// Where the beat is in its cycle (whole cycles counted), and when it was last advanced.
    private var beatPhase = 0.0
    private var lastFrame: TimeInterval?
    /// The strength last sent, so a still beat isn't sent again every frame.
    private var sentIntensity: Float = -1

    /// The slowest and fastest beats the hand is given, in pulses a second.
    static let slowestBeat = 0.5
    static let fastestBeat = 8.0
    /// Quieter than this (dBFS), the tuner hears no string worth beating against: the beat rests, so the phone's own
    /// buzz can never be what keeps it going.
    static let beatFloor = -48.0

    /// The beat rate for a string `cents` off a `target` (Hz). Tuning by ear, players listen high, to harmonics, where
    /// the beats are quick enough to count: the beat is taken an octave up at a time while the target is below
    /// 220 Hz, |f·(2^(c/1200) − 1)|, then held between `slowestBeat` and `fastestBeat`.
    static func beatRate(cents: Double, target: Double) -> Double {
        guard cents.isFinite, target.isFinite, target > 1 else { return slowestBeat }
        var heard = target
        while heard < 220 { heard *= 2 }
        let beat = abs(heard * (pow(2, cents / 1200) - 1))
        return min(fastestBeat, max(slowestBeat, beat))
    }

    /// The tuner's feel, frame by frame: installed as `AppStore.onTunerFrame` by the tuner. Without Tune by feel, or
    /// for readings that aren't tuning a string (an ear game, the intonation check), the standard detents and lock
    /// (`TunerFrame.standardFeel`). With it, the lock's thump and the beat.
    func feel(_ frame: TunerFrame) {
        guard enabled, byFeel, frame.measuring else {
            rest()
            TunerFrame.standardFeel(frame)
            return
        }
        if frame.enteredTune { lock() }
        // The smoothed cents whether or not the tracker calls them stable: a string moving under a turning peg is
        // exactly when the beat must keep speaking.
        let cents = frame.reading.frequency == nil ? nil : frame.reading.cents
        throb(cents: cents, target: frame.targetHz, still: frame.reading.inTune, level: frame.level, now: frame.time)
    }

    /// Advances the beat by one frame: `cents` off a `target` (Hz), at input `level` (dBFS), at `now` (uptime
    /// seconds). In tune (`still`), or with nothing heard, it stands still.
    private func throb(cents: Double?, target: Double, still: Bool, level: Double, now: TimeInterval) {
        let dt = lastFrame.map { min(0.1, max(0, now - $0)) } ?? 0
        lastFrame = now
        guard !still, let cents, level > Self.beatFloor else {
            // Still: in tune, or nothing heard. The carrier stops (so the engine can sleep) and the phase starts
            // again with the next string.
            rest()
            return
        }
        beatPhase += Self.beatRate(cents: cents, target: target) * dt
        send(intensity: Self.pulse(beatPhase, cents: cents))
    }

    /// The beat's strength at `phase` (cycles): a smooth swell and fall once a cycle, as the loudness of two beating
    /// strings rises and falls, a little stronger the further off the string is.
    static func pulse(_ phase: Double, cents: Double) -> Float {
        let cycle = phase - floor(phase)
        let swell = 0.5 - 0.5 * cos(2 * .pi * cycle)
        let depth = 0.45 + 0.25 * min(1, abs(cents) / 30)
        return Float(depth * pow(swell, 1.6))
    }

    /// Settings › Diagnostics › Feel test: the beat of a string 45 cents flat slowing to the lock over three seconds,
    /// then the thump, without the microphone.
    func feelTest() {
        guard enabled else { return }
        let target = 220.0
        let steps = 90
        Task { @MainActor in
            for step in 0..<steps {
                let left = 1 - Double(step) / Double(steps)
                throb(cents: -45 * left * left, target: target, still: false, level: -20,
                      now: ProcessInfo.processInfo.systemUptime)
                try? await Task.sleep(for: .milliseconds(33))
            }
            rest()
            lock()
        }
    }

    private func send(intensity: Float) {
        let value = max(0, min(1, intensity))
        guard let player = beatPlayer ?? startBeating() else { return }
        guard abs(value - sentIntensity) > 0.01 else { return }
        sentIntensity = value
        let control = CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: value, relativeTime: 0)
        try? player.sendParameters([control], atTime: CHHapticTimeImmediate)
    }

    /// The beat stands still: the carrier stops until a string is heard off its note again.
    private func rest() {
        guard beatPlayer != nil else { beatPhase = 0; return }
        try? beatPlayer?.stop(atTime: CHHapticTimeImmediate)
        beatPlayer = nil
        beatPhase = 0
        sentIntensity = -1
    }

    /// The beat's carrier: a soft, low continuous vibration (sharpness 0.25 reads as a throb rather than a buzz),
    /// looped, at no strength until the frames give it one.
    private func startBeating() -> CHHapticAdvancedPatternPlayer? {
        guard let engine else { return nil }
        do {
            try engine.start()
            let carrier = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25),
            ], relativeTime: 0, duration: 30)
            let player = try engine.makeAdvancedPlayer(with: CHHapticPattern(events: [carrier], parameters: []))
            player.loopEnabled = true
            try player.sendParameters([CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: 0, relativeTime: 0)],
                                      atTime: CHHapticTimeImmediate)
            try player.start(atTime: CHHapticTimeImmediate)
            beatPlayer = player
            sentIntensity = 0
            watch()
            return player
        } catch {
            return nil
        }
    }

    /// While the carrier runs, a watch that stills it once the frames stop coming (listening paused, the tuner left),
    /// so the phone never keeps throbbing on its own.
    private func watch() {
        Task { @MainActor [weak self] in
            while let self, self.beatPlayer != nil {
                try? await Task.sleep(for: .milliseconds(200))
                let quiet = self.lastFrame.map { ProcessInfo.processInfo.systemUptime - $0 > 0.25 } ?? true
                if quiet { self.rest() }
            }
        }
    }

    /// The beat stops (Tune by feel off, haptics off, the tuner gone).
    func stopBeating() {
        try? beatPlayer?.stop(atTime: CHHapticTimeImmediate)
        beatPlayer = nil
        beatPhase = 0
        lastFrame = nil
        sentIntensity = -1
    }
}
