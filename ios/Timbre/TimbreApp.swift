import CoreSpotlight
import SwiftUI
import TimbreCore

@main
struct TimbreApp: App {
    @StateObject private var bootstrap = Bootstrap()
    /// Coach marks load before any screen can show one (Tips/TimbreTips.swift).
    init() { TimbreTips.configure() }
    var body: some Scene {
        WindowGroup {
            Group {
                if let store = bootstrap.store {
                    RootView().environmentObject(store).environmentObject(store.audio).environmentObject(store.commerce)
                } else {
                    ZStack {
                        StageBackground()
                        ContentUnavailableView {
                            Label("Timbre couldn't open", systemImage: "exclamationmark.triangle")
                        } description: { Text(bootstrap.error ?? "Loading…") } actions: {
                            Button("Retry") { bootstrap.load() }.buttonStyle(BrassButtonStyle())
                        }
                    }
                }
            }
            .font(.body)
            .foregroundStyle(Palette.ink)
            // A Spotlight result handed over as an activity (its open intent normally runs instead): Intents/SpotlightIndex.swift.
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                if let store = bootstrap.store { SpotlightIndex.open(activity, store: store) }
            }
            // "Start today's practice" handed over from Apple Watch: Today (Services/WatchBridge.swift).
            .onContinueUserActivity(WatchBridge.todayActivity) { _ in
                if let store = bootstrap.store { DeepLink.open(WatchBridge.todayLink, store: store) }
            }
        }
    }
}

@MainActor
final class Bootstrap: ObservableObject {
    @Published var store: AppStore?
    @Published var error: String?
    init() { load() }
    func load() {
        do {
            var directory: URL?
            #if DEBUG
            let environment = ProcessInfo.processInfo.environment
            // Separate application state per UI test; release builds never read these values.
            if let identifier = environment["TIMBRE_TEST_STORAGE_ID"], UUID(uuidString: identifier) != nil {
                directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("TimbreUITests", isDirectory: true).appendingPathComponent(identifier, isDirectory: true)
            }
            #endif
            let store = try AppStore(directory: directory)
            #if DEBUG
            if environment["TIMBRE_SKIP_ONBOARDING"] == "1" { store.updateSettings { $0.onboardingCompleted = true; $0.goal = "practice" } }
            if environment["TIMBRE_STAGE_MODE"] == "studio" { store.updateSettings { $0.stageMode = "studio" } }
            if environment["TIMBRE_DEMO_DATA"] == "1", store.records.isEmpty { DemoData.seed(store) }
            DemoScene.start(store)  // TIMBRE_SCENE: an App Store screenshot's hero moment (Root/DemoScenes.swift)
            #endif
            self.store = store; error = nil
            SpotlightIndex.refresh(store)  // instruments, lessons and songs in Spotlight, only when they changed
        }
        catch { self.error = error.localizedDescription }
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
