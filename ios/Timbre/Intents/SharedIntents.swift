import AppIntents
import SwiftUI

// Shared by the app and the widget extension. A Control Center or Lock Screen control's intent must exist in both
// targets; because these intents open the app, the system performs them in the app's process.

/// Where a Siri, Shortcuts or control request should land once the app is in front. RootView follows both:
/// `pending` for the plain destinations, `link` for a `timbre://` link that carries a choice (an instrument, a
/// tempo, a key), so intents and links take one route (DeepLink.swift).
@MainActor
final class IntentRouter: ObservableObject {
    enum Destination: String { case tune, metronome, ear, daily, learn }
    static let shared = IntentRouter()
    @Published var pending: Destination?
    @Published var link: URL?
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
