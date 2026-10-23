import AppIntents
import SwiftUI

// Shared by the app and the widget extension (Control Center control).

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
