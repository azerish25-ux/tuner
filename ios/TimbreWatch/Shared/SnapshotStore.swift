import Foundation
import WidgetKit

/// The last snapshot from the iPhone, kept in the watch's App Group so the complications draw it too.
enum SnapshotStore {
    static let group = "group.com.shahradazerisharghi.timbre"
    private static let key = "watch.snapshot"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: group) }

    static func read() -> WatchSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WatchSnapshot.self, from: data)
    }

    /// Keeps `data` when it is a snapshot newer than the one kept, and redraws the complications; returns it then.
    /// Called on WatchConnectivity's queue, so the complications are reloaded before a background wake ends.
    static func accept(_ data: Data) -> WatchSnapshot? {
        guard let next = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else { return nil }
        if let kept = read(), kept.sent >= next.sent { return nil }
        defaults?.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
        return next
    }
}
