import CoreSpotlight
import SwiftUI
import TimbreCore
import UIKit

@main
struct TimbreApp: App {
    @StateObject private var bootstrap = Bootstrap()

    init() {
        // The curriculum (a few MB) starts decoding on a background queue at once; the store waits for it without
        // holding the main thread (`Bootstrap.load`).
        CurriculumStore.shared.preload()
        // Coach marks load before any screen can show one (Tips/TimbreTips.swift).
        TimbreTips.configure()
    }

    var body: some Scene {
        WindowGroup {
            content
                .font(.body)
                .foregroundStyle(Palette.ink)
                // A Spotlight result handed over as an activity (its open intent normally runs instead): Intents/SpotlightIndex.swift.
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    bootstrap.whenReady { SpotlightIndex.open(activity, store: $0) }
                }
                // "Start today's practice" handed over from Apple Watch: Today (Services/WatchBridge.swift).
                .onContinueUserActivity(WatchBridge.todayActivity) { _ in
                    bootstrap.whenReady { DeepLink.open(WatchBridge.todayLink, store: $0) }
                }
                // A saved file the system wouldn't hand over before the first unlock can be read now.
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
                    bootstrap.retryIfNeeded()
                }
        }
    }

    @ViewBuilder private var content: some View {
        if let store = bootstrap.store {
            if let recovery = bootstrap.recovery {
                RecoveryNotice(recovery: recovery) { bootstrap.acknowledgeRecovery() }
            } else {
                RootView().environmentObject(store).environmentObject(store.audio).environmentObject(store.commerce)
                    .environment(store.tuner)
            }
        } else if let failure = bootstrap.failure {
            LaunchFailure(failure: failure, retry: { bootstrap.load() }, openWithoutSavedFile: { bootstrap.openWithoutSavedFile() })
        } else {
            StageBackground(motes: false)
        }
    }
}

/// Opens the store once the catalogue and the curriculum have decoded, both off the main thread. Opening never
/// dead-ends: a saved file that can't be read is recovered by `LocalStore` (and `recovery` tells the player once), and
/// one the system won't hand over yet is tried again when it can be read, or set aside at the player's word.
@MainActor
final class Bootstrap: ObservableObject {
    /// Why the app couldn't open.
    struct Failure: Equatable {
        let message: String
        /// The saved file couldn't be read (rather than the app's own resources), so setting it aside can help.
        let storage: Bool
    }

    @Published private(set) var store: AppStore?
    @Published private(set) var failure: Failure?
    /// How the saved state was recovered on opening, until the player has read it.
    @Published private(set) var recovery: LocalStore.Recovery?
    private let directory = Bootstrap.storageDirectory()
    private var loading = false
    /// Hand-offs (Spotlight, Apple Watch) that arrived before the store was open.
    private var waiting: [(AppStore) -> Void] = []

    init() { load() }

    func load() {
        guard store == nil, !loading else { return }
        loading = true
        failure = nil
        Task { [weak self] in
            // The curriculum started decoding at launch (`TimbreApp.init`); the catalogue decodes beside it.
            let catalog = await Task.detached(priority: .userInitiated) { Result { try Catalog() } }.value
            _ = await CurriculumStore.shared.load()
            self?.open(catalog: catalog)
        }
    }

    func retryIfNeeded() {
        if store == nil { load() }
    }

    /// Moves the saved file aside (it is kept) and opens from the backup, or afresh.
    func openWithoutSavedFile() {
        do {
            try LocalStore.setAside(in: directory)
        } catch {
            failure = Failure(message: error.localizedDescription, storage: false)
            return
        }
        load()
    }

    func acknowledgeRecovery() { recovery = nil }

    /// Runs `action` with the store now, or as soon as it is open.
    func whenReady(_ action: @escaping (AppStore) -> Void) {
        if let store { action(store) } else { waiting.append(action) }
    }

    private func open(catalog: Result<Catalog, any Error>) {
        defer { loading = false }
        do {
            let store = try AppStore(directory: directory, catalog: catalog.get())
            #if DEBUG
            if TestSupport.isOn(.skipOnboarding) { store.updateSettings { $0.onboardingCompleted = true; $0.goal = "practice" } }
            if TestSupport.value(.stageMode) == "studio" { store.updateSettings { $0.stageMode = "studio" } }
            if TestSupport.isOn(.demoData), store.records.isEmpty { DemoData.seed(store) }
            DemoScene.start(store)  // a capture scene's moment, when the run names one (Root/DemoScenes.swift)
            #endif
            recovery = store.storageRecovery
            failure = nil
            self.store = store
            SpotlightIndex.refresh(store)  // instruments, lessons and songs in Spotlight, only when they changed
            let ready = waiting
            waiting = []
            for action in ready { action(store) }
        } catch {
            // A file read the system refused is a Cocoa error; the catalogue's own failures are not.
            failure = Failure(message: error.localizedDescription, storage: error is CocoaError)
        }
    }

    /// Application Support/Timbre; an automated run that names its own storage keeps its state apart.
    nonisolated private static func storageDirectory() -> URL {
        TestSupport.storageRoot ?? LocalStore.defaultDirectory
    }
}

// MARK: - Before the first screen

/// Shown once after opening got past a saved file it couldn't read, before the app's screens.
private struct RecoveryNotice: View {
    let recovery: LocalStore.Recovery
    let dismiss: () -> Void

    var body: some View {
        LaunchMessage(symbol: restored ? "clock.arrow.circlepath" : "arrow.counterclockwise",
                      tint: restored ? Palette.mint : Palette.accentNeutral, title: title, message: message) {
            Button("Continue", action: dismiss)
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("launch.recovery.continue")
        }
    }

    private var restored: Bool { recovery == .restoredBackup }

    private var title: Text {
        restored ? Text("Your progress is back") : Text("Timbre started fresh")
    }

    private var message: Text {
        if restored {
            return Text("Timbre couldn't read its saved file, so it opened the copy kept before your last change. That change may be missing.")
        }
        return Text("Timbre couldn't read its saved progress on this device, so it started over. Timbre Pro isn't affected.")
    }
}

/// Why Timbre couldn't open, with a way forward: try again (a file protected until the first unlock is readable
/// then), or open without the saved file, which is kept.
private struct LaunchFailure: View {
    let failure: Bootstrap.Failure
    let retry: () -> Void
    let openWithoutSavedFile: () -> Void
    @State private var confirming = false

    init(failure: Bootstrap.Failure, retry: @escaping () -> Void, openWithoutSavedFile: @escaping () -> Void) {
        self.failure = failure
        self.retry = retry
        self.openWithoutSavedFile = openWithoutSavedFile
    }

    var body: some View {
        LaunchMessage(symbol: "exclamationmark.triangle", tint: Palette.accentNeutral, title: Text("Timbre couldn't open"), message: message) {
            Button("Try again", action: retry)
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("launch.retry")
            if failure.storage {
                Button("Open without it") { confirming = true }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("launch.openWithout")
            }
        }
        .confirmationDialog("Open Timbre without its saved file?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Open without it", action: openWithoutSavedFile)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The file stays on this device. Timbre opens from its last backup, or starts fresh.")
        }
    }

    private var message: Text {
        let reason = failure.storage
            ? Text("Your saved progress couldn't be read just now. It's still on this device: try again once it's unlocked.")
            : Text("Something went wrong while Timbre was opening.")
        return reason + Text(verbatim: "\n\n") + Text(verbatim: failure.message).foregroundStyle(Palette.inkFaint)
    }
}

/// A full-window message over the stage: a glyph, a title, a few lines and the actions under them. The words scroll
/// at the largest text sizes; the actions stay put.
private struct LaunchMessage<Actions: View>: View {
    let symbol: String
    let tint: Color
    let title: Text
    let message: Text
    @ViewBuilder let actions: Actions

    var body: some View {
        ZStack {
            StageBackground(motes: false)
            VStack(spacing: 12) {
                GeometryReader { proxy in
                    ScrollView {
                        words.frame(maxWidth: .infinity, minHeight: proxy.size.height)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                actions
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 16)
            .frame(maxWidth: 560)
        }
    }

    private var words: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            title
                .font(Typeface.screenTitle)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            message
                .font(.body)
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Metrics.proseInset)
        }
        .padding(.vertical, 24)
    }
}
