import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var commerce: CommerceService
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        NavigationStack {
            TabView(selection: $store.selectedTab) {
                LibraryView().tabItem { Label("timbre_tab_shelf", systemImage: "square.grid.2x2").accessibilityIdentifier("tab.collection") }.tag(0)
                BenchView().tabItem { Label("timbre_tab_bench", systemImage: "tuningfork").accessibilityIdentifier("tab.bench") }.tag(1)
                VoiceView().tabItem { Label("timbre_tab_voice", systemImage: "waveform").accessibilityIdentifier("tab.voice") }.tag(2)
                StudioView().tabItem { Label("timbre_studio_title", systemImage: "metronome") }.tag(3)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Text("TIMBRE").font(TimbreTheme.title(20)).tracking(3) }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }.accessibilityLabel("timbre_settings_content_description").accessibilityIdentifier("settings.open")
                }
            }
            .toolbarBackground(TimbreTheme.canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(isPresented: $store.showSettings) { SettingsView() }
        }
        .font(.custom("Inter-Regular", size: 16, relativeTo: .body))
        .foregroundStyle(TimbreTheme.primary)
        .tint(TimbreTheme.action)
        .transaction { if store.settings.reducedMotion { $0.disablesAnimations = true } }
        .preferredColorScheme(store.settings.theme == "system" ? nil : store.settings.theme == "light" ? .light : .dark)
        .environment(\.locale, Locale(identifier: store.settings.language == "system" ? Locale.current.identifier : store.settings.language))
        .environment(\.layoutDirection, Locale.Language(identifier: store.settings.language == "system" ? Locale.current.identifier : store.settings.language).characterDirection == .rightToLeft ? .rightToLeft : .leftToRight)
        .sheet(isPresented: $store.showPlus) { PlusView() }
        .alert("Timbre", isPresented: Binding(get: { store.error != nil || audio.error != nil }, set: { if !$0 { store.error = nil; audio.clearError() } })) {
            if audio.permissionDenied {
                Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
            }
            Button("OK") { store.error = nil; audio.clearError() }
        } message: { Text(store.error ?? audio.error ?? "") }
        .onChange(of: audio.error) { _, error in if error != nil && store.voiceRunning { store.cancelVoice() } }
        .onChange(of: store.selectedTab) { _, _ in store.stopActivity() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { store.stopActivity() } }
        .onChange(of: commerce.isPlus) { _, isPlus in if !isPlus { store.stopActivity() } }
        .onChange(of: commerce.entitlementResolved) { _, _ in Task { await store.ads.prepare(entitlement: store.adEntitlement) } }
        .onChange(of: commerce.pending) { _, _ in store.ads.updateEntitlement(store.adEntitlement) }
        .onChange(of: commerce.isPlus) { _, _ in Task { await store.ads.prepare(entitlement: store.adEntitlement) } }
        .task { await store.ads.prepare(entitlement: store.adEntitlement) }
    }
}
