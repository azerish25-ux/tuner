import Foundation
import TimbreCore
import UIKit
import WatchConnectivity

/// The iPhone end of the Apple Watch companion (TimbreWatch). Whenever the widgets are published
/// (`AppStore.publishWidgets`), the watch is sent a small snapshot: the streak, Today's set, the open quest, the next
/// lesson and the metronome's tempo (`WatchSnapshot`). It goes as application context, where only the latest counts and
/// the watch picks it up when it next runs; and, when a Timbre complication is on the watch face and something it draws
/// changed, also as a complication transfer, which wakes the watch app at once (the system allows about fifty a day).
///
/// "Start today's practice" on the watch arrives as a message. The watch can't bring this app to the front, so: with
/// Timbre on screen it opens Today at once; otherwise the reply says so, the watch offers Handoff (continued in
/// TimbreApp, `WatchLink.todayActivity`), and opening Timbre within ten minutes lands on Today too.
@MainActor
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()
    /// Where the watch's "Start today's practice" lands: Today on the Play tab.
    static let todayLink = URL(string: "timbre://practice")!
    static let todayActivity = WatchLink.todayActivity

    private weak var store: AppStore?
    private var started = false
    /// The latest snapshot built, and the last one the watch was sent.
    private var latest: WatchSnapshot?
    private var sent: WatchSnapshot?
    /// When the watch asked for Today while Timbre was not on screen.
    private var todayAsked: Date?
    /// Whether Timbre is on screen, readable from WatchConnectivity's queue so the reply can say whether it opened.
    nonisolated private let foreground = SharedFlag()

    private override init() { super.init() }

    /// Builds the snapshot from the store and sends it when it differs from what the watch has. Phones without a
    /// paired watch (and iPads) send nothing.
    func publish(_ store: AppStore) {
        guard WCSession.isSupported() else { return }
        self.store = store
        start()
        latest = Self.snapshot(of: store)
        flush()
    }

    private func start() {
        guard !started else { return }
        started = true
        foreground.set(UIApplication.shared.applicationState == .active)
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func flush() {
        guard var next = latest else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled, !next.sameContent(as: sent) else { return }
        next.sent = Date()
        guard let data = try? JSONEncoder().encode(next) else { return }
        do {
            try session.updateApplicationContext([WatchLink.snapshot: data])
        } catch {
            return
        }
        if session.isComplicationEnabled, session.remainingComplicationUserInfoTransfers > 0, next.complicationChanged(from: sent) {
            _ = session.transferCurrentComplicationUserInfo([WatchLink.snapshot: data])
        }
        sent = next
    }

    /// Today on screen now, or as soon as Timbre is.
    private func openToday(onScreen: Bool) {
        guard let store else { return }
        if onScreen {
            todayAsked = nil
            DeepLink.open(Self.todayLink, store: store)
        } else {
            todayAsked = Date()
        }
    }

    @objc private func didBecomeActive() {
        foreground.set(true)
        guard let asked = todayAsked else { return }
        todayAsked = nil
        if Date().timeIntervalSince(asked) < 10 * 60, let store { DeepLink.open(Self.todayLink, store: store) }
    }

    @objc private func willResignActive() {
        foreground.set(false)
    }

    // MARK: Snapshot

    private static func snapshot(of store: AppStore) -> WatchSnapshot {
        let summary = store.streak
        let steps = store.dailySet.map { activity in
            WatchSnapshot.Step(kind: activity.kind.rawValue, symbol: activity.kind.symbol, tint: tint(activity.kind),
                               title: title(activity.kind), minutes: activity.minutes, done: store.dailyDone(activity.kind))
        }
        let quests = store.quests
        let shown = quests.first { store.questProgress($0) < $0.target } ?? quests.first
        let quest = shown.map { quest -> WatchSnapshot.QuestLine in
            let count = store.questCounter(quest)
            return WatchSnapshot.QuestLine(title: title(quest), symbol: quest.symbol, done: count.done, total: count.total, xp: quest.xp,
                                           claimed: store.questProgress(quest) >= quest.target)
        }
        let lesson = store.learnCourse.flatMap { course in
            store.learn.nextLesson(in: course).map {
                WatchSnapshot.LessonLine(course: course.title.localized, title: $0.title.localized, symbol: course.symbol, accent: course.accent)
            }
        }
        return WatchSnapshot(day: Calendar.current.startOfDay(for: Date()), streak: summary.current, best: summary.best,
                             practicedToday: summary.practicedToday, steps: steps, quest: quest, lesson: lesson,
                             tempo: store.bpm, beats: store.beats)
    }

    /// The Today row's name (`DailyActivity.Kind.rowTitle`), in the language picked in Timbre.
    private static func title(_ kind: DailyActivity.Kind) -> String {
        switch kind {
        case .tune: return NSLocalizedString("Tune up", comment: "")
        case .ear: return NSLocalizedString("Ear training", comment: "")
        case .chord: return NSLocalizedString("Chord of the day", comment: "")
        case .scale: return NSLocalizedString("Scale workout", comment: "")
        case .rhythm: return NSLocalizedString("Rhythm", comment: "")
        case .voice: return NSLocalizedString("Voice warm-up", comment: "")
        case .drone: return NSLocalizedString("Drone", comment: "")
        case .lesson: return NSLocalizedString("Next lesson", comment: "")
        case .review: return NSLocalizedString("Review", comment: "")
        }
    }

    /// The arc colour on the Today ring (`DailyActivity.Kind.tint`), by accent name.
    private static func tint(_ kind: DailyActivity.Kind) -> String {
        switch kind {
        case .tune: return "amber"
        case .ear, .review: return "mint"
        case .chord, .scale, .voice, .drone: return "sky"
        case .rhythm: return "coral"
        case .lesson: return "violet"
        }
    }

    /// The quest's title (`Quest.title`), in the language picked in Timbre.
    private static func title(_ quest: Quest) -> String {
        func counted(_ key: String) -> String { String.localizedStringWithFormat(NSLocalizedString(key, comment: ""), quest.target) }
        switch quest.kind {
        case .tuneAll: return NSLocalizedString("Tune every string", comment: "")
        case .holdInTune: return counted("Lock %lld strings in tune")
        case .sniperWin: return NSLocalizedString("Win a round of Pitch Sniper", comment: "")
        case .bullseyes: return counted("Hit %lld bullseyes")
        case .practiceMinutes: return counted("Practice for %lld minutes")
        case .earCorrect: return counted("Get %lld ear questions right")
        case .lessons: return counted("Finish %lld lessons")
        }
    }

    // MARK: WCSessionDelegate (called on WatchConnectivity's queue)

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Task { @MainActor in self.flush() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// The person switched to another watch: activate again for it, and send it everything.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            self.sent = nil
            WCSession.default.activate()
        }
    }

    /// Paired, unpaired, or the watch app installed: send again.
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.sent = nil
            self.flush()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let asked = (message[WatchLink.action] as? String) == WatchLink.startToday
        let onScreen = foreground.value
        replyHandler([WatchLink.opened: asked && onScreen])
        guard asked else { return }
        Task { @MainActor in self.openToday(onScreen: onScreen) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard (message[WatchLink.action] as? String) == WatchLink.startToday else { return }
        let onScreen = foreground.value
        Task { @MainActor in self.openToday(onScreen: onScreen) }
    }
}

/// A Bool written on the main queue and read from WatchConnectivity's.
private final class SharedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = false

    var value: Bool {
        lock.lock(); defer { lock.unlock() }
        return stored
    }

    func set(_ value: Bool) {
        lock.lock(); stored = value; lock.unlock()
    }
}
