import Foundation
import WidgetKit

/// What the configurable widgets choose from and show, written by the app into the App Group beside
/// `WidgetSnapshot` (WidgetBridge.swift): the instruments Quick tune can open the tuner on, and for each song shelf
/// (every song, or one instrument's, as the Songs tab's filter chips) the song to play next. Shared by the app,
/// which builds it (`WidgetLibrary.publish`, WidgetLibraryPublisher.swift), and the widget extension, which reads it.
struct WidgetLibrary: Codable, Equatable {
    var instruments: [Instrument] = []
    var shelves: [Shelf] = []

    /// A catalog instrument, named in the app's language.
    struct Instrument: Codable, Equatable {
        var id: String
        var name: String
        var family: String
        /// SF Symbol for its family.
        var symbol: String
    }

    /// One instrument's songs (`id` is the catalog instrument), or every song (`WidgetLibrary.allShelf`).
    struct Shelf: Codable, Equatable {
        var id: String
        var title: String
        var symbol: String
        var accent: String
        /// The Songs tab's song of the day for this shelf; nil when the shelf has no songs.
        var song: Song?
        var finished: Int
        var total: Int
    }

    struct Song: Codable, Equatable {
        var id: String
        var title: String
        var course: String
        var minutes: Int
        var xp: Int
        var stars: Int
        /// "open", "pro" (needs Timbre Pro) or "locked" (comes later in its course).
        var access: String
        /// Its sleeve's two colours (`CoverArt`), as 0xRRGGBB, so the widget wears the same record as the Songs tab.
        var colors: [UInt]
        /// Its chords in the order they come ("G", "D", "Em", "C"), at most four.
        var chords: [String]
        var bpm: Int?
    }

    static let allShelf = "all"
    static let quickTuneKind = "timbre.quicktune"
    static let nextSongKind = "timbre.nextsong"
    private static let key = "widget.library"

    static func read() -> WidgetLibrary {
        guard let data = UserDefaults(suiteName: WidgetSnapshot.group)?.data(forKey: key),
              let library = try? JSONDecoder().decode(WidgetLibrary.self, from: data) else { return WidgetLibrary() }
        return library
    }

    /// Saves and redraws the configurable widgets, only when something they show changed.
    static func write(_ library: WidgetLibrary) {
        guard let defaults = UserDefaults(suiteName: WidgetSnapshot.group), library != read(),
              let data = try? JSONEncoder().encode(library) else { return }
        defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadTimelines(ofKind: quickTuneKind)
        WidgetCenter.shared.reloadTimelines(ofKind: nextSongKind)
    }

    func instrument(id: String?) -> Instrument? {
        guard let id else { return nil }
        return instruments.first { $0.id == id }
    }

    /// The shelf with `id`; every song when `id` is nil or no longer has songs.
    func shelf(id: String?) -> Shelf? {
        shelves.first { $0.id == id } ?? shelves.first { $0.id == Self.allShelf }
    }

    // MARK: Links (the routes are Intents/DeepLink.swift's)

    /// timbre://tune, or timbre://tune?instrument=<id>.
    static func tuneURL(instrument id: String?) -> URL {
        link("tune", id.map { [URLQueryItem(name: "instrument", value: $0)] } ?? [])
    }

    /// timbre://lesson?id=<id> for a song, timbre://songs without one.
    static func songURL(_ id: String?) -> URL {
        guard let id else { return link("songs") }
        return link("lesson", [URLQueryItem(name: "id", value: id)])
    }

    private static func link(_ host: String, _ items: [URLQueryItem] = []) -> URL {
        var components = URLComponents()
        components.scheme = "timbre"
        components.host = host
        if !items.isEmpty { components.queryItems = items }
        return components.url ?? URL(string: "timbre://tune")!
    }
}
