import SwiftUI
import TimbreCore

/// The tuner header's menu for the instrument on the stage: its tunings (a lock beside one that needs Timbre Pro; picking
/// it opens the paywall, as `AppStore.selectTuning` decides), a new custom tuning, and the instrument picker. Tunings
/// belong here, one tap from the tuner, rather than in a chip row at the head of the instrument picker. `label` is
/// the header's own face (the instrument and its tuning); `onNewCustom` opens the tuning editor where the caller
/// hosts it.
///
///     TuningMenu(onNewCustom: { creating = true }) { header }
struct TuningMenu<Face: View>: View {
    let onNewCustom: () -> Void
    private let face: Face
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService

    init(onNewCustom: @escaping () -> Void, @ViewBuilder label: () -> Face) {
        self.onNewCustom = onNewCustom
        self.face = label()
    }

    var body: some View {
        Menu {
            if !store.referenceMode {
                Section("Tunings") {
                    ForEach(store.tunings) { tuning in tuningButton(tuning) }
                }
                if !store.courses.isEmpty {
                    // A lock in place of the plus where the free plan has used its custom tuning.
                    Button { newCustom() } label: {
                        Label("New tuning", systemImage: CustomTuningAccess.canCreate(store: store, pro: commerce.isPro) ? "plus" : "lock.fill")
                    }
                    .accessibilityIdentifier("tunings.menu.custom")
                }
            }
            Button { store.showInstrumentPicker = true } label: {
                Label("Choose instrument", systemImage: "guitars")
            }
        } label: {
            face
        }
        .accessibilityIdentifier("tunings.menu")
    }

    /// One tuning: a check on the one in use, a lock on one that needs Timbre Pro.
    private func tuningButton(_ tuning: Tuning) -> some View {
        let available = AccessPolicy.canUse(tuning: tuning, of: store.instrument, pro: commerce.isPro)
        let current = tuning.id == store.tuning.id
        return Button {
            store.selectTuning(tuning)
            Haptics.shared.selection()
        } label: {
            if current {
                Label(tuning.name.localized, systemImage: "checkmark")
            } else if !available {
                Label(tuning.name.localized, systemImage: "lock.fill")
            } else {
                Text(tuning.name.localized)
            }
        }
        .accessibilityAddTraits(current ? .isSelected : [])
    }

    private func newCustom() {
        if CustomTuningAccess.canCreate(store: store, pro: commerce.isPro) {
            onNewCustom()
        } else {
            store.presentPaywall("custom_tuning")
        }
    }
}

/// Whether this player may make another custom tuning on the instrument on the stage: always with Timbre Pro; on the
/// free plan, the free tier's one, on a free instrument (`FreeTier.customTunings`).
@MainActor enum CustomTuningAccess {
    static func canCreate(store: AppStore, pro: Bool) -> Bool {
        if pro { return true }
        return store.instrument.isFree && FreeTier.canAddCustomTuning(saved: store.settings.customTunings?.count ?? 0, pro: false)
    }
}
