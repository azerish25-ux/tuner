import AppIntents
import Combine
import SwiftUI

// App-only intents (Siri, Shortcuts, Spotlight, the Action button). The ones that need the screen open Timbre and
// hand a `timbre://` link to RootView, so they land exactly where the same link from a widget would (DeepLink.swift).

/// "Tune my cello with Timbre": the tuner on that instrument.
struct TuneInstrumentIntent: AppIntent {
    static let title: LocalizedStringResource = "Tune an instrument"
    static let description = IntentDescription("Opens the tuner on the instrument you name.")
    static let openAppWhenRun = true

    @Parameter(title: "Instrument")
    var instrument: InstrumentEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Tune \(\.$instrument)")
    }

    @MainActor func perform() async throws -> some IntentResult {
        IntentRouter.shared.link = DeepLink.tune(instrument: instrument.id)
        return .result()
    }
}

/// "Start the Timbre metronome" (Siri asks for the tempo): the Metronome tool, clicking at that tempo.
struct StartMetronomeIntent: AppIntent {
    static let title: LocalizedStringResource = "Start the metronome"
    static let description = IntentDescription("Opens the metronome and starts it at the tempo you choose.")
    static let openAppWhenRun = true

    @Parameter(title: "Tempo", inclusiveRange: (lowerBound: 30, upperBound: 300), requestValueDialog: IntentDialog("What tempo?"))
    var bpm: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Start the metronome at \(\.$bpm) BPM")
    }

    @MainActor func perform() async throws -> some IntentResult {
        IntentRouter.shared.link = DeepLink.metronome(bpm: min(300, max(30, bpm)), start: true)
        return .result()
    }
}

/// "Start a drone in D with Timbre": the Drone tool sounding that key (a Pro tool: the free plan sees its paywall).
struct StartDroneIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a drone"
    static let description = IntentDescription("Opens the drone and starts it in the key you choose.")
    static let openAppWhenRun = true

    @Parameter(title: "Key")
    var key: DroneKey

    static var parameterSummary: some ParameterSummary {
        Summary("Start a drone in \(\.$key)")
    }

    @MainActor func perform() async throws -> some IntentResult {
        IntentRouter.shared.link = DeepLink.drone(pitchClass: key.pitchClass, start: true)
        return .result()
    }
}

/// "Continue my Timbre lesson": the next lesson of the course Learn shows.
struct ContinueLessonIntent: AppIntent {
    static let title: LocalizedStringResource = "Continue my lesson"
    static let description = IntentDescription("Opens your next lesson.")
    static let openAppWhenRun = true

    @MainActor func perform() async throws -> some IntentResult {
        IntentRouter.shared.link = DeepLink.lesson
        return .result()
    }
}

/// "Again in Timbre", "Next in Timbre", "Slower in Timbre": the lesson on screen, driven by voice while both hands are on
/// the instrument (Siri, Voice Control through Shortcuts, the Action button). With no lesson open, Start and Next open
/// the next one.
struct LessonCommandIntent: AppIntent {
    static let title: LocalizedStringResource = "Control my lesson"
    static let description = IntentDescription("Starts, repeats, slows down or moves on the lesson step on screen, so your hands can stay on your instrument.")
    static let openAppWhenRun = true

    @Parameter(title: "Action")
    var command: LessonCommand

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$command) in my lesson")
    }

    @MainActor func perform() async throws -> some IntentResult {
        let remote = LessonRemote.shared
        if remote.open > 0 {
            remote.commands.send(command)
        } else if command == .start || command == .next {
            IntentRouter.shared.link = DeepLink.lesson
        }
        return .result()
    }
}

/// What a lesson can be told to do (`LessonCommandIntent`); its buttons answer them (`LessonControl`).
enum LessonCommand: String, AppEnum {
    case start, next, again, slower

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Lesson action"
    static let caseDisplayRepresentations: [LessonCommand: DisplayRepresentation] = [
        .start: DisplayRepresentation(title: "Start", synonyms: ["Go", "Play"]),
        .next: DisplayRepresentation(title: "Next", synonyms: ["Continue", "Next step"]),
        .again: DisplayRepresentation(title: "Again", synonyms: ["Try again", "Repeat"]),
        .slower: DisplayRepresentation(title: "Slower", synonyms: ["Slow down"]),
    ]
}

/// The lesson on screen's ear for commands from outside it: intents send, the lesson's buttons listen.
@MainActor
final class LessonRemote {
    static let shared = LessonRemote()
    let commands = PassthroughSubject<LessonCommand, Never>()
    /// Lessons open now (the player counts itself in and out).
    var open = 0
    /// When a key or command last pressed a lesson button (system uptime): one press at a time.
    var lastFired: TimeInterval = 0
}

/// "What's my Timbre streak?": answered in Siri or Shortcuts without opening the app, from the snapshot the app
/// keeps for its widgets.
struct PracticeStreakIntent: AppIntent {
    static let title: LocalizedStringResource = "Practice streak"
    static let description = IntentDescription("Tells you your practice streak without opening Timbre.")

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let status = StreakStatus(WidgetSnapshot.read())
        return .result(dialog: status.dialog, view: StreakSnippet(status: status))
    }
}

/// The twelve drone keys. Titles are letter names (translators may use their own: H, Ré, Do …); the black keys
/// also answer to their spoken sharp and flat names.
enum DroneKey: String, AppEnum {
    case c, cSharp, d, eFlat, e, f, fSharp, g, aFlat, a, bFlat, b

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Key"
    static let caseDisplayRepresentations: [DroneKey: DisplayRepresentation] = [
        .c: "C",
        .cSharp: DisplayRepresentation(title: "C♯", synonyms: ["C sharp", "D flat"]),
        .d: "D",
        .eFlat: DisplayRepresentation(title: "E♭", synonyms: ["E flat", "D sharp"]),
        .e: "E",
        .f: "F",
        .fSharp: DisplayRepresentation(title: "F♯", synonyms: ["F sharp", "G flat"]),
        .g: "G",
        .aFlat: DisplayRepresentation(title: "A♭", synonyms: ["A flat", "G sharp"]),
        .a: "A",
        .bFlat: DisplayRepresentation(title: "B♭", synonyms: ["B flat", "A sharp"]),
        .b: "B",
    ]

    /// C = 0 … B = 11.
    var pitchClass: Int {
        switch self {
        case .c: return 0
        case .cSharp: return 1
        case .d: return 2
        case .eFlat: return 3
        case .e: return 4
        case .f: return 5
        case .fSharp: return 6
        case .g: return 7
        case .aFlat: return 8
        case .a: return 9
        case .bFlat: return 10
        case .b: return 11
        }
    }
}
