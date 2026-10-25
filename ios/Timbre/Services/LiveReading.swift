import Foundation
import Observation
import TimbreCore

/// High-rate values (about 60 updates a second). Kept apart from `AppStore` so only the
/// views that draw the reading re-render; everything else stays still.
@Observable
@MainActor
final class LiveReading {
    /// No string heard.
    static let silence = TuningReading(frequency: nil, cents: nil, stable: false, inTune: false, status: "noSignal")
    /// Sound, but no pitch steady enough to read: "Let the string ring".
    static let unclear = TuningReading(frequency: nil, cents: nil, stable: false, inTune: false, status: "uncertain")

    var reading = LiveReading.silence
    var level: Double = -120
    var preserved = false
    var updatedAt: TimeInterval = 0
    // Voice practice
    var trace: [Double?] = []
    var voiceElapsed = 0
    var voiceLiveHoldMs = 0

    func clear() {
        reading = Self.silence
        preserved = false
    }
}

/// One tuner reading, as the tuner's feel receives it (`AppStore.onTunerFrame`): about 60 a second on the main actor
/// while the tuner listens, then one silent frame (no frequency) when listening stops. None arrive while a lesson,
/// strum to tune or voice practice takes the microphone's readings; treat a gap as silence.
struct TunerFrame {
    /// The smoothed reading: cents from the target, stable, in tune, its status.
    let reading: TuningReading
    /// The pitch being tuned to, Hz: the string, the reference note, an ear game's note, or the octave the
    /// intonation check compares.
    let targetHz: Double
    /// Input level, dBFS.
    let level: Double
    /// This frame is in tune and the one before it wasn't.
    let enteredTune: Bool
    /// The readings count as tuning (not an ear game, not the intonation check): only then does a lock ring.
    let measuring: Bool
    /// When the reading arrived, system uptime in seconds.
    let time: TimeInterval

    /// How fast the string beats against its target, Hz: |f · (2^(c/1200) − 1)|, from a stable reading only.
    var beatHz: Double? {
        guard reading.stable, let cents = reading.cents, cents.isFinite, targetHz > 0 else { return nil }
        return abs(targetHz * (pow(2, cents / 1200) - 1))
    }

    /// For the device check on the detents' vibration reaching the microphone: with this key on, the detents fire only
    /// within ±`detentGateCents` (fewer pulses while the string is still far off). Off until a device test calls for it.
    static let detentGateKey = "haptics.detentGate"
    static let detentGateCents = 3.0

    /// The tuner's feel as it is today: a detent per whole cent inside ±5 on a stable reading (`Haptics.detent`) and
    /// the lock pattern when a measured string comes into tune (`Haptics.lock`).
    @MainActor static func standardFeel(_ frame: TunerFrame) {
        var cents = frame.reading.stable ? frame.reading.cents : nil
        if let value = cents, abs(value) > detentGateCents, UserDefaults.standard.bool(forKey: detentGateKey) { cents = nil }
        Haptics.shared.detent(cents: cents)
        if frame.enteredTune && frame.measuring { Haptics.shared.lock() }
    }
}
