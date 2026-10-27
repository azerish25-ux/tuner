import SwiftUI

/// Timbre on Apple Watch: a haptic metronome on the wrist, today's streak and set, and "Start today's practice" on the
/// iPhone. A companion of the iPhone app (WKCompanionAppBundleIdentifier), fed by Timbre/Services/WatchBridge.swift.
@main
struct TimbreWatchApp: App {
    @StateObject private var sync = WatchSync.shared
    @StateObject private var metronome = WristMetronome()

    init() {
        WatchSync.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchPages()
                .environmentObject(sync)
                .environmentObject(metronome)
                .tint(Palette.mint)
        }
        // What the iPhone sent while Timbre wasn't running arrives in a background wake: it is saved for the
        // complications before the wake ends.
        .backgroundTask(.watchConnectivity) {
            await WatchSync.drainPending()
        }
    }
}

/// Two pages, swiped sideways so the Digital Crown is free for the tempo: Today, then the metronome.
struct WatchPages: View {
    enum Page: Hashable { case today, metronome }

    @EnvironmentObject private var sync: WatchSync
    @EnvironmentObject private var metronome: WristMetronome
    @Environment(\.scenePhase) private var scenePhase
    @State private var page = Page.today

    init() {
        #if DEBUG
        _page = State(initialValue: WatchCapture.page == "metronome" ? .metronome : .today)
        #endif
    }

    var body: some View {
        TabView(selection: $page) {
            TodayScreen()
                .tag(Page.today)
            MetronomeScreen(selected: page == .metronome)
                .tag(Page.metronome)
        }
        .tabViewStyle(.page)
        #if DEBUG
        .task {
            await WatchCapture.observe(selected: page == .today ? "today" : "metronome", sync: sync, metronome: metronome)
        }
        #endif
        // Taps play only while Timbre is on screen and awake; leaving the app stops the beat.
        .onChange(of: scenePhase, initial: true) { _, phase in
            metronome.active = phase == .active
            if phase == .background { metronome.stop() }
        }
        .onChange(of: sync.snapshot, initial: true) { _, snapshot in
            if let snapshot { metronome.adopt(tempo: snapshot.tempo, beats: snapshot.beats) }
        }
    }
}
