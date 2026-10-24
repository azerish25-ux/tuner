import Foundation
import TimbreCore

/// Timbre's `timbre://` routes, followed the same way from widgets, links, Siri, Shortcuts, Spotlight and the
/// Action button (an intent hands its link to `IntentRouter.link`; RootView passes both here).
///
///     timbre://tune                     the tuner
///     timbre://tune?instrument=<id>     the tuner on that catalog instrument
///     timbre://metronome[?bpm=120&start=1]
///     timbre://drone[?key=0…11&start=1] key is the pitch class, C = 0
///     timbre://lesson                   the next lesson of the course Learn shows
///     timbre://practice  timbre://ear  timbre://learn  timbre://songs
///
/// Access stays where it is: a Pro instrument on the free plan opens the paywall naming it (as the picker does), the
/// Drone tool opens its paywall, and a locked lesson opens the lesson paywall from Learn.
enum DeepLink {
    static let scheme = "timbre"

    static func tune(instrument id: String? = nil) -> URL {
        url("tune", id.map { [URLQueryItem(name: "instrument", value: $0)] } ?? [])
    }

    static func metronome(bpm: Int? = nil, start: Bool = false) -> URL {
        var items: [URLQueryItem] = []
        if let bpm { items.append(URLQueryItem(name: "bpm", value: String(bpm))) }
        if start { items.append(URLQueryItem(name: "start", value: "1")) }
        return url("metronome", items)
    }

    static func drone(pitchClass: Int? = nil, start: Bool = false) -> URL {
        var items: [URLQueryItem] = []
        if let pitchClass { items.append(URLQueryItem(name: "key", value: String(pitchClass))) }
        if start { items.append(URLQueryItem(name: "start", value: "1")) }
        return url("drone", items)
    }

    static var lesson: URL { url("lesson") }

    private static func url(_ host: String, _ items: [URLQueryItem] = []) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        if !items.isEmpty { components.queryItems = items }
        return components.url ?? URL(string: "timbre://tune")!
    }

    // MARK: Following a link

    @MainActor static func open(_ url: URL, store: AppStore) {
        guard url.scheme == scheme, let host = url.host else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        let start = value("start") == "1"
        // A covering sheet would hide where the link lands (the root paywall waits for both to close).
        store.showSettings = false
        store.showInstrumentPicker = false
        switch host {
        case "tune":
            guard let id = value("instrument"), let instrument = store.catalog.instrument(id: id) else { store.open(.tune); return }
            afterEntitlements(store) { tune(instrument, store: store) }
        case "metronome":
            if let bpm = value("bpm").flatMap({ Int($0) }) { store.setMetronome(bpm: bpm) }
            store.open(.metronome)
            if start { startSoon { if !store.audio.metronomeRunning { store.toggleMetronome() } } }
        case "drone":
            let pitchClass = value("key").flatMap { Int($0) }
            afterEntitlements(store) { drone(pitchClass: pitchClass, start: start, store: store) }
        case "lesson":
            afterEntitlements(store) { continueLesson(store: store) }
        case "practice": store.open(.daily)
        case "ear": store.open(.ear)
        case "learn": store.open(.learn)
        case "songs": store.selectedTab = .songs; Analytics.log("shortcut", ["destination": "songs"])
        default: break
        }
    }

    /// The tuner on `instrument`. Picking it goes through `selectInstrument`, which opens the paywall naming a Pro
    /// instrument on the free plan, exactly as the instrument picker does.
    @MainActor private static func tune(_ instrument: Instrument, store: AppStore) {
        store.open(.tune)
        guard store.referenceMode || store.instrument.id != instrument.id else { return }
        store.selectInstrument(instrument)
    }

    /// The Drone tool in `pitchClass` (kept in the octave the player last used). It is a Pro tool: on the free plan
    /// the Play tab shows its paywall, as tapping the tool there does.
    @MainActor private static func drone(pitchClass: Int?, start: Bool, store: AppStore) {
        store.selectedTab = .practice
        Analytics.log("shortcut", ["destination": "drone"])
        guard store.isPro else { store.presentPaywall("practice.drone"); return }
        if let pitchClass {
            let current = store.droneMidi
            var midi = current - current % 12 + ((pitchClass % 12) + 12) % 12
            if midi > 72 { midi -= 12 }
            if midi < 36 { midi += 12 }
            store.setDrone(midi: midi)
        }
        store.pendingPracticeRoute = .drone
        if start { startSoon { if !store.audio.droneRunning { store.toggleDrone() } } }
    }

    /// The next lesson of the course Learn shows; Learn opens it (or its paywall when it is locked). Learn alone
    /// once that course is complete.
    @MainActor private static func continueLesson(store: AppStore) {
        if let course = store.learnCourse, let next = store.learn.nextLesson(in: course) {
            store.pendingLessonId = next.id
        }
        store.selectedTab = .learn
        Analytics.log("shortcut", ["destination": "lesson"])
    }

    /// Runs `action` once StoreKit has said whether this player is Pro (at most about three seconds after a cold
    /// launch), so a Pro player is never shown a paywall only because entitlements were still loading.
    @MainActor private static func afterEntitlements(_ store: AppStore, _ action: @escaping @MainActor () -> Void) {
        guard !store.commerce.entitlementResolved else { action(); return }
        Task { @MainActor in
            for _ in 0..<30 where !store.commerce.entitlementResolved {
                try? await Task.sleep(for: .milliseconds(100))
            }
            action()
        }
    }

    /// Starts sound a moment after the screen has been pushed, so the first click lands with the screen on show.
    @MainActor private static func startSoon(_ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            action()
        }
    }
}
