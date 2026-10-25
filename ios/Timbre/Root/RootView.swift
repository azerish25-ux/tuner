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
            // One family of five, all solid in the bar (each has a fill form, or is solid already), so no tab reads
            // lighter than its neighbours: the tuner's needle, the cap, the song list, the metronome, rising bars.
            Tab("Tune", systemImage: "gauge.with.needle", value: AppTab.tune) { TuneView().underTabBar() }
            Tab("Learn", systemImage: "graduationcap", value: AppTab.learn) { LearnView().underTabBar() }
            // Songs sits beside Learn (both are the curriculum) and takes the centre of the bar. Its title is the
            // Songs course's own, already translated in every language. Instruments are chosen from the tuner's picker.
            Tab(SongsView.title(in: store.curriculum), systemImage: "music.note.list", value: AppTab.songs) { SongsView().underTabBar() }
            // The metronome, drone, chords, scales and ear games: practice, not a game controller's "Play".
            Tab("Practice", systemImage: "metronome", value: AppTab.practice) { PracticeView().underTabBar() }
            Tab("Progress", systemImage: "chart.bar", value: AppTab.journey) { JourneyView().underTabBar() }
        }
        // A subscription whose renewal failed (billing retry, grace period): one line over every tab until it's fixed.
        .safeAreaInset(edge: .top, spacing: 0) { BillingIssueBanner() }
        // VoiceOver stays on the paywall while it covers the tabs, rather than reaching the controls behind it.
        .accessibilityHidden(rootPaywall)
        .tint(Palette.mint)
        .preferredColorScheme(.dark)  // Studio Noir is a dark design
        .environment(\.locale, TimbreLocalization.locale(for: store.settings.language))
        .environment(\.layoutDirection, TimbreLocalization.isRightToLeft(store.settings.language) ? .rightToLeft : .leftToRight)
        // Every Sora face a weight heavier with Bold Text on (onboarding's cover and the sheets below inherit it).
        .boldTextAware()
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
            // and never touched, so it is never seen (and stays off the title) while its label stays readable.
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
        .task { store.applyStreakFreezes(); store.syncAchievements(); GameCenter.shared.launched(store) }
        // timbre://… from widgets and links, and from App Intents through `IntentRouter.link` (routes: Intents/DeepLink.swift).
        // A chord chart shared to Timbre ("Open in Timbre") goes to Your songs (YourSongs/YourSongsStore.swift).
        .onOpenURL { url in if !YourSongsStore.shared.receive(url, store: store) { DeepLink.open(url, store: store) } }
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

// MARK: - Under the tab bar

extension View {
    /// A tab's content under the floating tab bar: what scrolls beneath the bar dissolves into the stage (the soft
    /// scroll-edge effect on iOS 26, and a stage-coloured fade under the bar on every version), so body text and mint
    /// buttons never read through the glass or tint it. Content resting above the bar is untouched.
    func underTabBar() -> some View { modifier(TabBarFade()) }
}

/// The fade starts at the bar's top edge (the bottom safe-area edge) and reaches `depth` within `ramp` points, then
/// holds to the screen's foot. It shows only while the bar does: a pushed screen that hides the bar (the bottom inset
/// falls to the home indicator's) and iPad, whose bar is at the top, get none.
private struct TabBarFade: ViewModifier {
    /// The bottom safe-area inset: the bar's height (and the home indicator's) while the bar shows.
    @State private var inset: CGFloat = 0

    private static let ramp: CGFloat = 28
    private static let depth = 0.86
    /// The shortest bottom inset that is a tab bar (49 pt without a home indicator; the indicator alone is 34).
    private static let barMinimum: CGFloat = 44

    func body(content: Content) -> some View {
        let shown = inset >= Self.barMinimum
        return content
            .modifier(SoftBottomEdge())
            .onGeometryChange(for: CGFloat.self) { proxy in proxy.safeAreaInsets.bottom.rounded() } action: { value in
                inset = value
            }
            .overlay(alignment: .bottom) {
                fade
                    .frame(height: max(Self.ramp, inset))
                    .offset(y: max(Self.ramp, inset))
                    .opacity(shown ? 1 : 0)
                    .animation(Motion.fade, value: shown)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }

    private var fade: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Palette.stage.opacity(0), Palette.stage.opacity(Self.depth)], startPoint: .top, endPoint: .bottom)
                .frame(height: Self.ramp)
            Palette.stage.opacity(Self.depth)
        }
    }
}

/// iOS 26: the soft scroll-edge effect under the tab bar for every scroll view in the tab, asked for explicitly.
private struct SoftBottomEdge: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            content
        }
    }
}
