import Foundation
import TimbreCore
import UIKit

/// Timbre's `timbre://` routes, followed the same way from widgets, links, Siri, Shortcuts, Spotlight and the
/// Action button (an intent hands its link to `IntentRouter.link`; RootView passes both here).
///
///     timbre://tune                     the tuner
///     timbre://tune?instrument=<id>     the tuner on that catalog instrument
///     timbre://metronome[?bpm=120&start=1]
///     timbre://drone[?key=0…11&start=1] key is the pitch class, C = 0
///     timbre://lesson                   the next lesson of the course Learn shows
///     timbre://lesson?id=<id>           that lesson or song (Spotlight, Siri, the Next song widget)
///     timbre://challenge?game=sniper&score=<n>
///                                       Pitch Sniper with a friend's score to beat (a "Beat my score" card)
///     timbre://practice  timbre://ear  timbre://learn  timbre://songs
///
/// Access stays where it is: a Pro instrument on the free plan opens the paywall naming it (as the picker does), the
/// Drone tool opens its paywall, and a locked lesson opens the lesson paywall from Learn. A lesson further on in its
/// course than the player has reached shows where it sits instead (its course in Learn, a song on its Songs shelf).
///
/// Settings and the instrument picker close for a link. A full-screen cover (a lesson, Strum, an alert or a share
/// sheet) is left as it is, since closing it would lose its progress: the link waits until it has gone, and then lands
/// on screen rather than under it. The latest link wins.
///
/// Before onboarding is done, a `tune?instrument=` link (an instrument's Custom Product Page, say) chooses that
/// instrument on the welcome screen instead (`OnboardingLink`), so the plan, the first tune and the course follow it.
/// The share page's https links (`ShareDestination`) open as the route they stand for.
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

    static func lesson(id: String) -> URL { url("lesson", [URLQueryItem(name: "id", value: id)]) }

    /// Pitch Sniper with `score` to beat: the link a "Beat my score" card is sent with.
    static func challenge(score: Int) -> URL {
        url("challenge", [URLQueryItem(name: "game", value: PlayGame.sniper.rawValue), URLQueryItem(name: "score", value: String(score))])
    }

    private static func url(_ host: String, _ items: [URLQueryItem] = []) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        if !items.isEmpty { components.queryItems = items }
        return components.url ?? URL(string: "timbre://tune")!
    }

    // MARK: Following a link

    @MainActor static func open(_ link: URL, store: AppStore) {
        let url = ShareDestination.route(from: link) ?? link
        guard url.scheme == scheme, url.host != nil else { return }
        // Onboarding picks the instrument itself: the link chooses it there, and nothing waits for onboarding to close.
        if store.settings.onboardingCompleted != true, url.host == "tune" {
            OnboardingLink.shared.offer(url, catalog: store.catalog)
            return
        }
        // A covering sheet would hide where the link lands (the root paywall waits for both to close).
        store.showSettings = false
        store.showInstrumentPicker = false
        // Anything still presented (those sheets on their way out included) keeps the link waiting.
        guard !coverShowing else { park(url, store: store); return }
        follow(url, store: store)
    }

    /// The link that waits for a cover to close, and whether something is already waiting for it.
    @MainActor private static var parked: URL?
    @MainActor private static var waiting = false

    /// Holds `url` until nothing is presented over the tabs (checked a few times a second, for up to fifteen minutes),
    /// then follows it once the screen has settled. A newer link replaces a waiting one.
    @MainActor private static func park(_ url: URL, store: AppStore) {
        parked = url
        guard !waiting else { return }
        waiting = true
        Task { @MainActor in
            let deadline = Date().addingTimeInterval(15 * 60)
            while Date() < deadline {
                if !coverShowing {
                    // Settled: still clear a moment later (a cover going away can hand over to the next one).
                    try? await Task.sleep(for: .milliseconds(300))
                    if !coverShowing { break }
                }
                try? await Task.sleep(for: .milliseconds(400))
            }
            waiting = false
            guard let next = parked else { return }
            parked = nil
            guard !coverShowing else { return }
            follow(next, store: store)
        }
    }

    /// Something is presented over the tabs (or still on its way out): a lesson, Strum, onboarding, a sheet, an alert.
    @MainActor private static var coverShowing: Bool {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        return (windows.first(where: \.isKeyWindow) ?? windows.first)?.rootViewController?.presentedViewController != nil
    }

    @MainActor private static func follow(_ url: URL, store: AppStore) {
        guard let host = url.host else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        let start = value("start") == "1"
        switch host {
        case "tune":
            guard let id = value("instrument"), let instrument = store.catalog.instrument(id: id) else { store.open(.tune); return }
            afterEntitlements(store) { DeepLink.openTuner(on: instrument, store: store) }
        case "metronome":
            if let bpm = value("bpm").flatMap({ Int($0) }) { store.setMetronome(bpm: bpm) }
            store.open(.metronome)
            if start { startSoon { if !store.audio.metronomeRunning { store.toggleMetronome() } } }
        case "drone":
            let pitchClass = value("key").flatMap { Int($0) }
            afterEntitlements(store) { DeepLink.openDrone(pitchClass: pitchClass, start: start, store: store) }
        case "lesson":
            if let id = value("id") {
                afterEntitlements(store) { DeepLink.openLesson(id: id, store: store) }
            } else {
                afterEntitlements(store) { DeepLink.openNextLesson(store: store) }
            }
        case "practice": store.open(.daily)
        case "ear": store.open(.ear)
        case "learn": store.open(.learn)
        case "songs": store.selectedTab = .songs; Analytics.log("shortcut", ["destination": "songs"])
        case "challenge": openChallenge(game: value("game"), score: value("score"), store: store)
        default: break
        }
    }

    /// Pitch Sniper (a free game) with a friend's score to beat: shown on its card and in the game's header until a game
    /// passes it. A link for another game, or with a score no game can reach, opens the Play tab alone.
    @MainActor private static func openChallenge(game: String?, score: String?, store: AppStore) {
        store.selectedTab = .practice
        guard game == PlayGame.sniper.rawValue, let target = score.flatMap({ Int($0) }),
              (1...SniperChallenge.maxScore).contains(target) else { return }
        GameCenter.shared.accept(sniperTarget: target)
        GameCenter.shared.activate(store)
        store.pendingPracticeRoute = .sniper
    }

    /// The tuner on `instrument`. Picking it goes through `selectInstrument`, which opens the paywall naming a Pro
    /// instrument on the free plan, exactly as the instrument picker does.
    @MainActor private static func openTuner(on instrument: Instrument, store: AppStore) {
        store.open(.tune)
        guard store.referenceMode || store.instrument.id != instrument.id else { return }
        store.selectInstrument(instrument)
    }

    /// The Drone tool in `pitchClass` (kept in the octave the player last used). It is a Pro tool: on the free plan
    /// the Play tab shows its paywall, as tapping the tool there does.
    @MainActor private static func openDrone(pitchClass: Int?, start: Bool, store: AppStore) {
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
    @MainActor private static func openNextLesson(store: AppStore) {
        if let course = store.learnCourse, let next = store.learn.nextLesson(in: course) {
            store.pendingLessonId = next.id
        }
        store.selectedTab = .learn
        Analytics.log("shortcut", ["destination": "lesson"])
    }

    /// One lesson or song by id, with Learn's access (`LessonAccess`): Learn opens it when it plays, or its paywall
    /// naming it when it needs Pro (`pendingLessonId`, as Today's lesson). One the player hasn't reached yet shows
    /// where it sits: a song on the Songs tab, a lesson on its course's path. An unknown id opens Learn.
    @MainActor private static func openLesson(id: String, store: AppStore) {
        Analytics.log("shortcut", ["destination": "lesson_by_id"])
        guard let found = store.curriculum.lesson(id: id) else { store.selectedTab = .learn; return }
        switch LessonAccess.of(found.lesson, in: found.course, store: store) {
        case .play, .pro:
            let ownCourse = UserDefaults.standard.string(forKey: "learn.course") ?? "guitar"
            store.pendingLessonId = found.lesson.id
            store.selectedTab = .learn
            if found.lesson.kind == .song && ownCourse != found.course.id {
                keepLearnCourse(ownCourse, replacing: found.course.id, store: store)
            }
        case .locked:
            if found.lesson.kind == .song {
                store.selectedTab = .songs
            } else {
                UserDefaults.standard.set(found.course.id, forKey: "learn.course")
                store.selectedTab = .learn
            }
        }
    }

    /// A song is a detour, as it is from the Songs tab, not a change of course: Learn shows the song's course while it
    /// opens it (`LearnView.openPendingLesson`), then goes back to the player's own once the song is on screen, so
    /// Today's lesson and the Next lesson widget stay where they were.
    @MainActor private static func keepLearnCourse(_ own: String, replacing songCourse: String, store: AppStore) {
        Task { @MainActor in
            for _ in 0..<30 where store.pendingLessonId != nil { try? await Task.sleep(for: .milliseconds(100)) }
            // Past Learn's own wait for covering screens, so the switch happens behind the open song.
            try? await Task.sleep(for: .milliseconds(2500))
            guard UserDefaults.standard.string(forKey: "learn.course") == songCourse else { return }
            UserDefaults.standard.set(own, forKey: "learn.course")
        }
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

/// The instrument a link chose while onboarding is up (or before it has appeared, on a launch from the link): the
/// welcome screen selects it, adding its chip when it isn't one of the usual ones. Kept until onboarding reads it.
@MainActor
final class OnboardingLink: ObservableObject {
    static let shared = OnboardingLink()

    @Published private(set) var instrumentID: String?

    /// Takes the instrument of a `tune?instrument=<id>` link, when the catalogue knows it.
    func offer(_ url: URL, catalog: Catalog) {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let id = items.first(where: { $0.name == "instrument" })?.value, catalog.instrument(id: id) != nil else { return }
        instrumentID = id
        Analytics.log("onboarding_link", ["instrument": id])
    }

    /// Onboarding has chosen the instrument: the link is spent.
    func consume() { instrumentID = nil }
}
