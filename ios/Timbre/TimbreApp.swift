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
        // App opens, sessions, MetricKit and the remote settings from launch; the player's sharing choice is applied
        // as soon as the saved settings open (`AppStore`), and drops anything queued before then if sharing is off.
        Analytics.start()
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
            }
        } else if let failure = bootstrap.failure {
            LaunchFailure(failure: failure, retry: { bootstrap.load() }, openWithoutSavedFile: { bootstrap.openWithoutSavedFile() })
        } else {
            StageBackground(motes: false)
        }
    }
}

/// Opens the store once the curriculum has decoded. Opening never dead-ends: a saved file that can't be read is
/// recovered by `LocalStore` (and `recovery` tells the player once), and one the system won't hand over yet is tried
/// again when it can be read, or set aside at the player's word.
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
            _ = await CurriculumStore.shared.load()
            self?.open()
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

    private func open() {
        defer { loading = false }
        do {
            let store = try AppStore(directory: directory)
            #if DEBUG
            let environment = ProcessInfo.processInfo.environment
            if environment["TIMBRE_SKIP_ONBOARDING"] == "1" { store.updateSettings { $0.onboardingCompleted = true; $0.goal = "practice" } }
            if environment["TIMBRE_STAGE_MODE"] == "studio" { store.updateSettings { $0.stageMode = "studio" } }
            if environment["TIMBRE_DEMO_DATA"] == "1", store.records.isEmpty { DemoData.seed(store) }
            DemoScene.start(store)  // TIMBRE_SCENE: an App Store screenshot's hero moment (Root/DemoScenes.swift)
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

    nonisolated private static func storageDirectory() -> URL {
        #if DEBUG
        // Separate application state per UI test; release builds never read these values.
        let environment = ProcessInfo.processInfo.environment
        if let identifier = environment["TIMBRE_TEST_STORAGE_ID"], UUID(uuidString: identifier) != nil {
            return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("TimbreUITests", isDirectory: true).appendingPathComponent(identifier, isDirectory: true)
        }
        #endif
        return LocalStore.defaultDirectory
    }
}

// MARK: - Before the first screen

/// Shown once after opening got past a saved file it couldn't read, before the app's screens.
private struct RecoveryNotice: View {
    let recovery: LocalStore.Recovery
    let dismiss: () -> Void

    var body: some View {
        LaunchMessage(symbol: restored ? "clock.arrow.circlepath" : "arrow.counterclockwise",
                      tint: restored ? Palette.mint : Palette.amber, title: title, message: message) {
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
        LaunchMessage(symbol: "exclamationmark.triangle", tint: Palette.amber, title: Text("Timbre couldn't open"), message: message) {
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

#if DEBUG
/// Realistic history for screenshots and UI tests: one state for every capture, whatever the hour a run starts. A
/// 7-day streak that already counts today (the flame lit), level 5 (1,240 XP), today's tune-up ticked off in Today.
/// A test's own practice adds nothing to the streak: today already counts, and today's streak freeze counts as awarded.
enum DemoData {
    @MainActor static func seed(_ store: AppStore) {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        // Records sit on calendar days, at 5 PM, and today's just before now: never after it (a record from the future
        // doesn't count) and never before midnight. Dating them "now − 1 h" put today's on yesterday for a run started
        // between midnight and 1 AM (CI runs in UTC), so captures showed 7 days with a grey flame until a test's own
        // practice made it 8.
        let latest = max(today, now.addingTimeInterval(-120))
        func moment(_ daysAgo: Int, minutes: Double = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today.addingTimeInterval(-Double(daysAgo) * 86400)
            return min(day.addingTimeInterval(17 * 3600 + minutes * 60), latest)
        }
        // Today first: each save checks the streak, and history saved after today's record never reaches a streak milestone.
        for day in [0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 13, 14, 15, 17, 20, 21, 22, 27, 28, 34] {
            store.save(PracticeRecord(date: moment(day), instrumentId: "guitar.acoustic.6", tuningId: "guitar.acoustic.6.standard", kind: "tuning",
                                      count: 180, stableCount: 120, meanAbsoluteCents: 0.6 + Double(day) * 0.09, durationMs: 90_000 + day * 4000))
            if day % 2 == 0 {
                store.save(PracticeRecord(date: moment(day, minutes: 10), instrumentId: "practice.ear", kind: "ear", count: 10, stableCount: 7 + day % 3, durationMs: 240_000))
            }
        }
        // A learner a few lessons in, level 5, with a G string that drifts flat. The three lessons were finished on three
        // days of this week's streak, each with the practice record a finished lesson saves (`AppStore.finishLesson`),
        // so Learn's three finished lessons, "Your week" and the stats below agree.
        var learn = LearnProgress()
        let first = store.curriculum.course(id: "guitar")?.lessons.prefix(3) ?? []
        for (i, lesson) in first.enumerated() {
            let stars = [3, 2, 3][i]
            let date = moment([3, 2, 1][i], minutes: 30)
            learn.record(LessonResult(lessonId: lesson.id, stars: stars, accuracy: [0.96, 0.81, 0.93][i], xp: 20, minutes: 4), courseId: "guitar", now: date)
            store.save(PracticeRecord(date: date, instrumentId: "learn.guitar", kind: "lesson", count: 3, stableCount: stars, durationMs: 4 * 60_000))
        }
        var progress = ProgressState()
        progress.xp = 1240
        progress.stats = ["stringsTuned": 140, "fullTunes": 14, "lessons": 3, "perfectLessons": 2, "earCorrect": 38, "bullseyes": 12, "sniperBest": 1650]
        progress.achievements = ["first_tune", "full_tune", "streak_7", "strings_100", "bullseye", "first_lesson"]
        progress.instrumentsTuned = ["guitar.acoustic.6"]
        // Day 7 of the run already earned its freeze: without this, a test's first practice would bank one and pop the
        // "streak freeze" banner (and a snowflake beside the flame) into whatever it captures next.
        progress.freezeAwardDay = Quests.dayKey(now)
        for (day, cents) in [(9, -2.0), (6, -9.0), (4, -14.0), (1, -23.0)] {
            progress.sample(StringSample(instrumentId: "guitar.acoustic.6", anchor: "s3", date: now.addingTimeInterval(-Double(day) * 86400), cents: cents))
            progress.sample(StringSample(instrumentId: "guitar.acoustic.6", anchor: "s1", date: now.addingTimeInterval(-Double(day) * 86400), cents: -0.5))
        }
        // Today's tune-up is the practice that lit the flame, so Today shows it done (1 of 3) on every capture, rather
        // than done only on the captures whose test happened to tune first. Today's plan is pinned too (ear training,
        // open on any plan), so every capture shows one plan whether its test has Pro or not.
        let todayKey = store.todayKey
        store.updateSettings {
            $0.fullTunes = 14; $0.learn = learn; $0.progress = progress
            $0.dailyDone = [todayKey: [DailyActivity.Kind.tune.rawValue]]
            $0.dailyPlan = [todayKey: [DailyActivity.Kind.ear.rawValue]]
        }
    }
}
#endif
