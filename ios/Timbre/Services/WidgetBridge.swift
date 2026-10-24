import Foundation
import WidgetKit

/// What the home-screen widgets show, written by the app into the shared App Group.
/// Shared by the app and the widget extension.
struct WidgetSnapshot: Codable, Equatable {
    var streak = 0
    var best = 0
    var practicedToday = false
    /// Oldest first: whether each of the last seven days had practice.
    var week: [Bool] = Array(repeating: false, count: 7)
    var instrument = ""
    var updated = Date.distantPast
    /// The next lesson in the course the learner last picked (nil before Learn is opened or once the course is done).
    var lesson: NextLesson?

    struct NextLesson: Codable, Equatable {
        var course: String
        var symbol: String
        var accent: String
        var title: String
        var minutes: Int
        var xp: Int
        var done: Int
        var total: Int
    }

    static let group = "group.com.shahradazerisharghi.timbre"
    private static let key = "widget.snapshot"

    static func read() -> WidgetSnapshot {
        guard let data = UserDefaults(suiteName: group)?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return WidgetSnapshot() }
        return snapshot
    }

    /// Saves and asks WidgetKit to redraw, only when something visible changed.
    static func write(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: group) else { return }
        var previous = read(); previous.updated = snapshot.updated
        guard previous != snapshot, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
