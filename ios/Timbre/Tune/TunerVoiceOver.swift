import SwiftUI
import UIKit
import TimbreCore

/// VoiceOver for the tuner. While a pitch is held the tuner speaks about every 1.5 s: the note and cents
/// first ("G3, 12 cents flat"), then the cents alone while the note stays the same ("8 cents flat"),
/// "Hold it…" inside the lock band. A lock is announced at once ("In tune") and felt as a pattern of its
/// own after the lock thump. A plain class, polled by the tuner, so speaking never redraws a view.
@MainActor
final class TunerAnnouncer {
    /// Seconds between spoken updates while the pitch is held.
    static let interval: TimeInterval = 1.5
    /// A pitch must hold this long before the first update, so a passing blip stays quiet.
    static let settle: TimeInterval = 0.5
    private var heldSince: TimeInterval?
    private var lastSpoken: TimeInterval = 0
    private var lastNote: String?
    private var wasLocked = false

    /// - Parameters:
    ///   - note: the target note as the readout shows it ("G3").
    ///   - shown: the whole cents on screen; nil with no pitch (or while not listening).
    ///   - locked: the tracker's lock.
    func step(note: String, shown: Int?, locked: Bool, now: TimeInterval) {
        guard let shown else { reset(); return }
        if note != lastNote { wasLocked = false }
        if locked {
            guard !wasLocked else { return }
            wasLocked = true
            lastNote = note
            lastSpoken = now
            Self.post(String(localized: "In tune"))
            TunerHaptics.inTune()
            return
        }
        wasLocked = false
        let held = heldSince ?? now
        heldSince = held
        guard now - held >= Self.settle, now - lastSpoken >= Self.interval else { return }
        lastSpoken = now
        let amount = abs(shown)
        let cents = Double(amount) <= Palette.tuningBand ? String(localized: "Hold it…") : NoteReadout.spoken(shown, locked: false)
        if note == lastNote {
            Self.post(cents)
        } else {
            lastNote = note
            Self.post(note + ", " + cents)
        }
    }

    /// Silence: the next held pitch starts again with its note.
    func reset() {
        heldSince = nil
        lastNote = nil
        wasLocked = false
    }

    private static func post(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }
}

/// The in-tune pattern for VoiceOver: a bright double tap ("da-dum") just after the lock thump,
/// unlike the soft per-cent detents on the way in.
enum TunerHaptics {
    @MainActor static func inTune() {
        guard Haptics.shared.enabled else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}
