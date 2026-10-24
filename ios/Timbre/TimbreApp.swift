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
/// Realistic history for screenshots and UI tests.
enum DemoData {
    @MainActor static func seed(_ store: AppStore) {
        let now = Date()
        for day in [0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 13, 14, 15, 17, 20, 21, 22, 27, 28, 34] {
            let date = now.addingTimeInterval(-Double(day) * 86400 - 3600)
            store.save(PracticeRecord(date: date, instrumentId: "guitar.acoustic.6", tuningId: "guitar.acoustic.6.standard", kind: "tuning",
                                      count: 180, stableCount: 120, meanAbsoluteCents: 0.6 + Double(day) * 0.09, durationMs: 90_000 + day * 4000))
            if day % 2 == 0 {
                store.save(PracticeRecord(date: date.addingTimeInterval(600), instrumentId: "practice.ear", kind: "ear", count: 10, stableCount: 7 + day % 3, durationMs: 240_000))
            }
        }
        // A learner a few lessons in, level 5, with a G string that drifts flat.
        var learn = LearnProgress()
        let first = store.curriculum.course(id: "guitar")?.lessons.prefix(3) ?? []
        for (i, lesson) in first.enumerated() {
            learn.record(LessonResult(lessonId: lesson.id, stars: [3, 2, 3][i], accuracy: [0.96, 0.81, 0.93][i], xp: 20, minutes: 4), courseId: "guitar", now: now)
        }
        var progress = ProgressState()
        progress.xp = 1240
        progress.stats = ["stringsTuned": 140, "fullTunes": 14, "lessons": 3, "perfectLessons": 2, "earCorrect": 38, "bullseyes": 12, "sniperBest": 1650]
        progress.achievements = ["first_tune", "full_tune", "streak_7", "strings_100", "bullseye", "first_lesson"]
        progress.instrumentsTuned = ["guitar.acoustic.6"]
        for (day, cents) in [(9, -2.0), (6, -9.0), (4, -14.0), (1, -23.0)] {
            progress.sample(StringSample(instrumentId: "guitar.acoustic.6", anchor: "s3", date: now.addingTimeInterval(-Double(day) * 86400), cents: cents))
            progress.sample(StringSample(instrumentId: "guitar.acoustic.6", anchor: "s1", date: now.addingTimeInterval(-Double(day) * 86400), cents: -0.5))
        }
        store.updateSettings { $0.fullTunes = 14; $0.learn = learn; $0.progress = progress }
    }
}
#endif
