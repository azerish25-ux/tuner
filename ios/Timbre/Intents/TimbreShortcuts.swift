import AppIntents

/// Timbre's App Shortcuts: Siri phrases, Spotlight, the Shortcuts app and the Action button, with no setup.
/// Phrases are translated in <locale>.lproj/AppShortcuts.strings; "Tune my …" learns the catalog's instruments
/// from `InstrumentQuery.suggestedEntities()` when RootView calls `updateAppShortcutParameters()`.
/// At most ten shortcuts (this is ten); the most used come first, as Spotlight shows them in this order.
struct TimbreShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenTunerIntent(), phrases: ["Tune with \(.applicationName)", "Open the \(.applicationName) tuner"],
                    shortTitle: "Tune", systemImageName: "tuningfork")
        AppShortcut(intent: TuneInstrumentIntent(), phrases: ["Tune my \(\.$instrument) with \(.applicationName)",
                                                              "Tune my \(\.$instrument) in \(.applicationName)"],
                    shortTitle: "Tune an instrument", systemImageName: "guitars")
        AppShortcut(intent: StartMetronomeIntent(), phrases: ["Start the \(.applicationName) metronome",
                                                              "Start a metronome with \(.applicationName)"],
                    shortTitle: "Start the metronome", systemImageName: "metronome.fill")
        AppShortcut(intent: ContinueLessonIntent(), phrases: ["Continue my \(.applicationName) lesson",
                                                              "Continue my lesson in \(.applicationName)"],
                    shortTitle: "Continue my lesson", systemImageName: "graduationcap.fill")
        AppShortcut(intent: PracticeStreakIntent(), phrases: ["What's my \(.applicationName) streak",
                                                              "Show my \(.applicationName) practice streak"],
                    shortTitle: "Practice streak", systemImageName: "flame.fill")
        AppShortcut(intent: StartDroneIntent(), phrases: ["Start a drone in \(\.$key) with \(.applicationName)",
                                                          "Play a \(\.$key) drone with \(.applicationName)",
                                                          "Start a \(.applicationName) drone"],
                    shortTitle: "Drone", systemImageName: "waveform.path")
        AppShortcut(intent: DailyPracticeIntent(), phrases: ["Start my \(.applicationName) practice"],
                    shortTitle: "Daily practice", systemImageName: "checklist")
        AppShortcut(intent: OpenMetronomeIntent(), phrases: ["Open the \(.applicationName) metronome"],
                    shortTitle: "Metronome", systemImageName: "metronome")
        AppShortcut(intent: EarTrainingIntent(), phrases: ["Train my ear with \(.applicationName)"],
                    shortTitle: "Ear training", systemImageName: "ear.fill")
        // Mid-lesson, hands on the instrument: "Again in Timbre", "Next in Timbre", "Slower in Timbre".
        AppShortcut(intent: LessonCommandIntent(), phrases: ["\(\.$command) in \(.applicationName)",
                                                             "\(\.$command) in my \(.applicationName) lesson"],
                    shortTitle: "Lesson controls", systemImageName: "playpause.fill")
    }
}
