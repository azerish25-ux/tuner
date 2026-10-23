import SwiftUI
import TimbreCore

@main
struct TimbreApp: App {
    @StateObject private var bootstrap = Bootstrap()
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
            #endif
            self.store = store; error = nil
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
        store.updateSettings { $0.fullTunes = 14 }
    }
}
#endif
