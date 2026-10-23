import AppIntents
import SwiftUI

/// Where a Siri or Shortcuts request should land once the app is in front.
@MainActor
final class IntentRouter: ObservableObject {
    enum Destination: String { case tune, metronome, ear, daily }
    static let shared = IntentRouter()
    @Published var pending: Destination?
}

struct OpenTunerIntent: AppIntent {
    static let title: LocalizedStringResource = "Tune my instrument"
    static let description = IntentDescription("Opens Timbre on the tuner, ready to listen.")
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { IntentRouter.shared.pending = .tune; return .result() }
}

struct OpenMetronomeIntent: AppIntent {
    static let title: LocalizedStringResource = "Open the metronome"
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { IntentRouter.shared.pending = .metronome; return .result() }
}

struct EarTrainingIntent: AppIntent {
    static let title: LocalizedStringResource = "Train my ear"
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { IntentRouter.shared.pending = .ear; return .result() }
}

struct DailyPracticeIntent: AppIntent {
    static let title: LocalizedStringResource = "Start today's practice"
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { IntentRouter.shared.pending = .daily; return .result() }
}

struct TimbreShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenTunerIntent(), phrases: ["Tune with \(.applicationName)", "Open the \(.applicationName) tuner"],
                    shortTitle: "Tune", systemImageName: "tuningfork")
        AppShortcut(intent: DailyPracticeIntent(), phrases: ["Start my \(.applicationName) practice"],
                    shortTitle: "Daily practice", systemImageName: "flame.fill")
        AppShortcut(intent: OpenMetronomeIntent(), phrases: ["Open the \(.applicationName) metronome"],
                    shortTitle: "Metronome", systemImageName: "metronome.fill")
        AppShortcut(intent: EarTrainingIntent(), phrases: ["Train my ear with \(.applicationName)"],
                    shortTitle: "Ear training", systemImageName: "ear.fill")
    }
}
