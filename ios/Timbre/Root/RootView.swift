import SwiftUI
import TimbreCore
import UIKit

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var commerce: CommerceService
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The paywall drawn over the tabs (Settings and the instrument picker host their own).
    private var rootPaywall: Bool { store.showPaywall && !store.showSettings && !store.showInstrumentPicker }

    /// Hands are on the instrument while the tuner or a lesson listens, a click or the drone plays, or a reference
    /// note sounds: the screen stays on, since Auto-Lock would send the app to the background and stop the
    /// microphone mid-take. Only while Timbre is in front; Auto-Lock is back the moment all of it stops.
    private var keepAwake: Bool {
        scenePhase == .active && (audio.running || audio.metronomeRunning || audio.droneRunning || audio.tonePlaying)
    }

    var body: some View {
        TabView(selection: $store.selectedTab) {
            Tab("Tune", systemImage: "tuningfork", value: AppTab.tune) { TuneView() }
            Tab("Learn", systemImage: "graduationcap", value: AppTab.learn) { LearnView() }
            // Songs sits beside Learn (both are the curriculum) and takes the centre of the bar. Its title is the
            // Songs course's own, already translated in every language. Instruments are chosen from the tuner's picker.
            Tab(SongsView.title(in: store.curriculum), systemImage: "music.note.list", value: AppTab.songs) { SongsView() }
            Tab("Play", systemImage: "gamecontroller", value: AppTab.practice) { PracticeView() }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.journey) { JourneyView() }
        }
        // VoiceOver stays on the paywall while it covers the tabs, rather than reaching the controls behind it.
        .accessibilityHidden(rootPaywall)
        .tint(Palette.mint)
        .preferredColorScheme(.dark)  // Studio Noir is a dark design
        .environment(\.locale, Locale(identifier: store.settings.language == "system" ? Locale.current.identifier : store.settings.language))
        .environment(\.layoutDirection, Locale.Language(identifier: store.settings.language == "system" ? Locale.current.identifier : store.settings.language).characterDirection == .rightToLeft ? .rightToLeft : .leftToRight)
        .fullScreenCover(isPresented: Binding(get: { store.settings.onboardingCompleted != true }, set: { _ in })) {
            OnboardingView().environmentObject(store).environmentObject(audio).environmentObject(commerce)
        }
        // The root paywall is a plain overlay rather than a UIKit presentation: UI tests never saw a sheet
        // anchored at the root appear over the tabs. Settings and the instrument picker host their own sheet.
        .overlay {
            if rootPaywall {
                // Rises from the bottom; a plain fade under Reduce Motion.
                PaywallView().transition(AnyTransition.adaptive(.move(edge: .bottom).combined(with: .opacity), reduceMotion: reduceMotion))
            }
        }
        .animation(Motion.adaptive(Motion.settle, reduceMotion: reduceMotion), value: store.showPaywall)
        // A 7/30/100-day run reached outside a lesson: its share card (lesson results show their own).
        .overlay { StreakMilestoneOverlay() }
        // Rewards grow out of the Dynamic Island, inside the status-bar band (RewardToast places itself).
        .overlay { RewardToast() }
        #if DEBUG
        .overlay(alignment: .topLeading) {
            // UI-test probe (TIMBRE_DEBUG_STATE=1): the presentation flags, readable by XCUITest. Drawn in clear ink
            // and never touched, so it stays out of the screenshots (and off the title) while its label stays readable.
            if ProcessInfo.processInfo.environment["TIMBRE_DEBUG_STATE"] == "1" {
                Text(verbatim: "paywall=\(store.showPaywall) settings=\(store.showSettings) picker=\(store.showInstrumentPicker) reason=\(store.paywallReason ?? "-") pro=\(commerce.isPro) tab=\(String(describing: store.selectedTab))")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(Color.clear)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("debug.state")
            }
        }
        #endif
        .background {
            Color.clear.sheet(isPresented: $store.showSettings) {
                SettingsView().environmentObject(store).environmentObject(commerce).presentationBackground(Palette.stage)
            }
        }
        .alert("Timbre", isPresented: Binding(get: { store.error != nil || audio.error != nil }, set: { if !$0 { store.error = nil; audio.clearError() } })) {
            if audio.permissionDenied {
                Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
            }
            Button("OK", role: .cancel) { store.error = nil; audio.clearError() }
        } message: { Text(store.error ?? audio.error ?? "") }
        .onChange(of: store.selectedTab) { old, _ in if old == .tune { store.stopActivity() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { store.stopActivity() }
            // Settings writes are coalesced (`AppStore.updateSettings`): what is waiting is saved before the app can be suspended.
            if phase != .active { store.flushSettings() }
            if phase == .active { store.applyStreakFreezes(); store.syncAchievements() }
        }
        .onChange(of: keepAwake, initial: true) { _, awake in UIApplication.shared.isIdleTimerDisabled = awake }
        .task { store.applyStreakFreezes(); store.syncAchievements() }
        .onChange(of: commerce.isPro) { _, pro in if pro { Analytics.log("pro_active") } }
        // timbre://… from widgets and links, and from App Intents through `IntentRouter.link` (routes: Intents/DeepLink.swift).
        .onOpenURL { url in DeepLink.open(url, store: store) }
        .onReceive(IntentRouter.shared.$link) { url in
            guard let url else { return }
            // Cleared after this change has landed, so the link is followed once.
            Task { @MainActor in if IntentRouter.shared.link == url { IntentRouter.shared.link = nil } }
            DeepLink.open(url, store: store)
        }
        .onReceive(IntentRouter.shared.$pending) { destination in
            guard let destination else { return }
            IntentRouter.shared.pending = nil
            store.open(destination)
        }
        // Teaches Siri the catalog's instruments for "Tune my … with Timbre".
        .task { TimbreShortcuts.updateAppShortcutParameters() }
    }
}
