import SwiftUI
import TimbreCore
import UIKit

/// Tune by feel's switch, as the tuner and Settings show it: the phone pulses at the beat between the string and its
/// note, slower as they meet, and stands still at the lock (`Haptics.feel`).
///
/// Off by default, except while VoiceOver runs, until the player chooses: once they flip it anywhere, their choice
/// (`UserSettings.tuneByFeel`) decides from then on, VoiceOver or not. It needs haptics on and a phone that has them.
enum TuneByFeel {
    /// Set once the player has chosen for themselves, on the tuner or in Settings.
    static let chosenKey = "tune.feel.chosen"

    /// Whether this phone can play haptics at all (an iPad can't).
    static let available = Haptics.hardwareSupported

    /// Whether Tune by feel is on: the player's choice once they have made one, else on while VoiceOver runs.
    static func isOn(_ settings: UserSettings, voiceOver: Bool, chosen: Bool) -> Bool {
        guard available, settings.hapticsEnabled else { return false }
        return settings.tuneByFeel || (voiceOver && !chosen)
    }

    /// The player's choice, from the tuner or Settings: remembered as theirs, so the VoiceOver default no longer applies.
    @MainActor static func choose(_ on: Bool, store: AppStore) {
        UserDefaults.standard.set(true, forKey: chosenKey)
        store.updateSettings { $0.tuneByFeel = on }
    }

    /// A switch bound to Tune by feel as it is in effect (for a Settings toggle): it reads `isOn` and writes `choose`.
    @MainActor static func binding(_ store: AppStore, voiceOver: Bool) -> Binding<Bool> {
        Binding(
            get: { isOn(store.settings, voiceOver: voiceOver, chosen: UserDefaults.standard.bool(forKey: chosenKey)) },
            set: { choose($0, store: store) }
        )
    }
}

/// Tune by feel on the tuner, among the stage's side controls: a hand tapping, "Feel" beneath, mint while on. Shown
/// only on a phone with haptics; dimmed while haptics are off in Settings.
struct FeelToggle: View {
    /// "Feel" under the disc, as the other side controls are captioned.
    var captioned = true
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(TuneByFeel.chosenKey) private var chosen = false

    var body: some View {
        if TuneByFeel.available {
            let on = TuneByFeel.isOn(store.settings, voiceOver: voiceOver, chosen: chosen)
            let enabled = store.settings.hapticsEnabled
            Button {
                TuneByFeel.choose(!on, store: store)
                Haptics.shared.selection()
            } label: {
                VStack(spacing: 3) {
                    disc(on: on)
                    if captioned { StageCaption(text: Text("Feel"), active: on) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleStyle())
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.45)
            .accessibilityLabel(Text("Tune by feel"))
            .accessibilityValue(on ? Text("On") : Text("Off"))
            .accessibilityHint(enabled ? Text("Tune by feel pulses at the beat between the string and its note, slower as they meet, still at the lock.")
                                       : Text("Turn on Haptics in Settings first"))
            .accessibilityAddTraits(.isToggle)
            .cappedControl(Text("Tune by feel"), symbol: "hand.tap")
            .accessibilityIdentifier("tune.feel")
        }
    }

    private func disc(on: Bool) -> some View {
        Image(systemName: on ? "hand.tap.fill" : "hand.tap")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(on ? Palette.mint : Palette.ink)
            .symbolEffect(.bounce, value: reduceMotion ? false : on)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 44, height: 44)
            .stageControlDisc(active: on)
            .animation(Motion.quick, value: on)
    }
}
