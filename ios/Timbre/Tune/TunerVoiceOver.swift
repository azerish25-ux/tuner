import SwiftUI
import UIKit
import TimbreCore

/// VoiceOver for the tuner. While a pitch is held the tuner speaks about every 1.5 s: the note, the cents and the
/// turn first ("F sharp 3, 12 cents flat, tighten"), then the cents and the turn alone while the note stays the same,
/// "Hold it…" inside the lock band. Notes are spoken as a musician says them in the app's language (`NoteNames.spoken`:
/// "E flat 3", "Es 3", "Mi bémol 3"). A lock is announced at once ("In tune") and felt as a pattern of its own after the
/// lock thump. A plain class, polled by the tuner, so speaking never redraws a view.
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
    ///   - note: the target note as the readout shows it ("G3", "Eb3").
    ///   - spoken: the same note as VoiceOver should say it ("G 3", "E flat 3"; `NoteNames.spoken`); nil says `note`.
    ///   - shown: the whole cents on screen; nil with no pitch (or while not listening).
    ///   - locked: the tracker's lock.
    func step(note: String, spoken: String? = nil, shown: Int?, locked: Bool, now: TimeInterval) {
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
        let cents = Self.guidance(shown)
        if note == lastNote {
            Self.post(cents)
        } else {
            lastNote = note
            Self.post((spoken ?? note) + ", " + cents)
        }
    }

    /// "Hold it…" inside the lock band; outside it the cents and the turn that fixes them: "12 cents flat, tighten",
    /// "8 cents sharp, loosen" (the words on screen under the meter).
    static func guidance(_ shown: Int) -> String {
        if Double(abs(shown)) <= Palette.tuningBand { return String(localized: "Hold it…") }
        return NoteReadout.guidance(shown, locked: false)
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

extension NoteNames {
    /// A note as VoiceOver should say it in the language the app is showing (`locale`, from the environment), in the
    /// player's naming system: "E flat 3", "Fis 3", "Fa dièse 3".
    static func spoken(_ note: String, locale: Locale, system: String) -> String {
        let language = locale.language.languageCode?.identifier ?? locale.identifier
        return spoken(note, language: language, system: system)
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
