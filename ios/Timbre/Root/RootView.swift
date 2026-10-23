import SwiftUI
import TimbreCore
import UIKit

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var commerce: CommerceService
    @Environment(\.scenePhase) private var scenePhase

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
        .tint(Palette.brass)
        .preferredColorScheme(.dark)  // Studio Noir is a dark design
        .environment(\.locale, Locale(identifier: store.settings.language == "system" ? Locale.current.identifier : store.settings.language))
        .environment(\.layoutDirection, Locale.Language(identifier: store.settings.language == "system" ? Locale.current.identifier : store.settings.language).characterDirection == .rightToLeft ? .rightToLeft : .leftToRight)
        .fullScreenCover(isPresented: Binding(get: { store.settings.onboardingCompleted != true }, set: { _ in })) {
            OnboardingView().environmentObject(store).environmentObject(audio).environmentObject(commerce)
        }
        // The root paywall is a plain overlay rather than a UIKit presentation: UI tests never saw a sheet
        // anchored at the root appear over the tabs. Settings and the instrument picker host their own sheet.
        .overlay {
            if store.showPaywall && !store.showSettings && !store.showInstrumentPicker {
                PaywallView().transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.9), value: store.showPaywall)
        // Rewards grow out of the Dynamic Island, inside the status-bar band (RewardToast places itself).
        .overlay { RewardToast() }
        #if DEBUG
        .overlay(alignment: .topLeading) {
            // UI-test probe (TIMBRE_DEBUG_STATE=1): the presentation flags, readable by XCUITest.
            if ProcessInfo.processInfo.environment["TIMBRE_DEBUG_STATE"] == "1" {
                Text("paywall=\(store.showPaywall) settings=\(store.showSettings) picker=\(store.showInstrumentPicker) reason=\(store.paywallReason ?? "-") pro=\(commerce.isPro) tab=\(String(describing: store.selectedTab))")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(.white).padding(4).background(.black.opacity(0.6))
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
            if phase == .active { store.applyStreakFreezes(); store.syncAchievements() }
        }
        .task { store.applyStreakFreezes(); store.syncAchievements() }
        .onChange(of: commerce.isPro) { _, pro in if pro { Analytics.log("pro_active") } }
        .onOpenURL { url in
            // timbre://tune, timbre://practice, timbre://metronome, timbre://ear, timbre://learn, timbre://songs (widgets and links)
            switch url.host {
            case "tune": IntentRouter.shared.pending = .tune
            case "practice": IntentRouter.shared.pending = .daily
            case "metronome": IntentRouter.shared.pending = .metronome
            case "ear": IntentRouter.shared.pending = .ear
            case "learn": IntentRouter.shared.pending = .learn
            case "songs": store.selectedTab = .songs; Analytics.log("shortcut", ["destination": "songs"])
            default: break
            }
        }
        .onReceive(IntentRouter.shared.$pending) { destination in
            guard let destination else { return }
            IntentRouter.shared.pending = nil
            store.open(destination)
        }
    }
}
