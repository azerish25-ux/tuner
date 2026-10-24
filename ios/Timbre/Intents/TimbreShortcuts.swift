import AppIntents

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
