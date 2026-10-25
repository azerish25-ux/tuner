import ActivityKit
import Combine
import Foundation
import TimbreCore
import UIKit

/// Shows the practice session as a Live Activity (Lock Screen, Dynamic Island, Apple Watch Smart Stack) while the
/// Metronome or Drone tool plays, the player tunes or sings, or a lesson is open. One activity at a time.
///
/// - Local updates only (no push), at most one a second; the clock is drawn by the system from `since`.
/// - Starts only in the foreground with Live Activities allowed; tuning and lessons show after a short dwell,
///   so opening the app is not a session. It is never a reminder: without practice, nothing stays behind.
/// - Ends when the last source stops (in the foreground after a short grace, as a reference tone briefly pauses
///   the microphone). After a real practice (a record today, a minute or more) the final frame stays on the
///   Lock Screen for two minutes; otherwise it goes at once.
/// - Ends everything when the app quits; a fresh launch clears anything an earlier run left behind.
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()
    typealias State = PracticeActivityAttributes.ContentState

    /// An automated run never starts Live Activities (as Analytics stays local there).
    private let enabled = !TestSupport.isAutomated

    private static let minInterval: TimeInterval = 1
    private static let dwell: TimeInterval = 10
    private static let grace: TimeInterval = 3
    private static let heartbeat: TimeInterval = 600
    private static let staleAfter: TimeInterval = 900
    private static let resumeWindow: TimeInterval = 90
    private static let summaryMinimum = 60
    private static let summaryShown: TimeInterval = 120

    private weak var store: AppStore?
    private var subscriptions: Set<AnyCancellable> = []
    private var observers: [NSObjectProtocol] = []
    private var activity: Activity<PracticeActivityAttributes>?

    /// The Metronome tool owns the click (a lesson's own click is not a session of its own).
    private var metronomeClaimed = false
    private var lessons: Set<String> = []
    private var lessonTitle = ""
    private var lessonSymbol = "graduationcap.fill"
    /// When the session began, and when its tuning or lesson began (for the dwell).
    private var since: Date?
    private var practiceSince: Date?
    private var lastEnded: (at: Date, since: Date)?
    /// Left the app with nothing sounding (a lesson left open).
    private var awaySince: Date?
    /// The player swiped the activity away, or it could not start: leave this session alone.
    private var dismissed = false

    private var pushed: State?
    private var pushedAt = Date.distantPast
    private var lastPush: TimeInterval = -.infinity
    private var refreshQueued = false
    private var wakeTask: Task<Void, Never>?
    private var wakeAt: TimeInterval = .infinity
    private var endTask: Task<Void, Never>?

    private init() {}

    // MARK: Hooks

    /// Called once by the store: follows its audio and the app's life cycle.
    func attach(_ store: AppStore) {
        guard enabled else { return }
        self.store = store
        subscriptions = []
        let audio = store.audio
        audio.$metronomeRunning.sink { [weak self] running in
            if !running { self?.metronomeClaimed = false }
            self?.setNeedsRefresh()
        }.store(in: &subscriptions)
        audio.$droneRunning.merge(with: audio.$running).sink { [weak self] _ in self?.setNeedsRefresh() }.store(in: &subscriptions)
        if observers.isEmpty {
            let center = NotificationCenter.default
            observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.cameBack() }
            })
            observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.wentAway() }
            })
            observers.append(center.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { _ in
                LiveActivityController.endAllBeforeExit()
            })
        }
        // A fresh launch has no session yet: anything still showing was left by an earlier run.
        let leftovers = Activity<PracticeActivityAttributes>.activities
        activity = nil; since = nil; pushed = nil
        Task { for old in leftovers { await old.end(nil, dismissalPolicy: .immediate) } }
    }

    /// The Metronome tool started the click or changed its tempo or meter.
    func metronomeChanged() {
        metronomeClaimed = store?.audio.metronomeRunning ?? false
        setNeedsRefresh()
    }

    func lessonOpened(_ id: String, title: String, symbol: String) {
        lessons.insert(id); lessonTitle = title; lessonSymbol = symbol
        setNeedsRefresh()
    }

    func lessonClosed(_ id: String) {
        lessons.remove(id)
        setNeedsRefresh()
    }

    // MARK: Session

    /// Every change lands in one refresh on the next turn of the main actor, after the store's own bookkeeping
    /// (a stopped metronome saves its practice first, so the last frame shows the streak it earned).
    private func setNeedsRefresh() {
        guard enabled, !refreshQueued else { return }
        refreshQueued = true
        Task { @MainActor [weak self] in
            self?.refreshQueued = false
            self?.refresh()
        }
    }

    private func refresh() {
        guard let store else { return }
        let audio = store.audio
        let metronome = metronomeClaimed && audio.metronomeRunning
        let drone = audio.droneRunning
        // The tuner, intonation, Pitch Sniper and voice listen here; lessons and onboarding listen through their own.
        let practicing = !lessons.isEmpty || (audio.running && store.lessonListener == nil)
        guard metronome || drone || practicing else { scheduleEnd(); return }
        endTask?.cancel(); endTask = nil
        let now = Date()
        let start = since ?? resumedSince(now)
        since = start
        if practicing { practiceSince = practiceSince ?? now } else { practiceSince = nil }

        guard let activity else {
            guard !dismissed else { return }
            if !metronome && !drone, let begun = practiceSince, now.timeIntervalSince(begun) < Self.dwell {
                wake(after: Self.dwell - now.timeIntervalSince(begun))
                return
            }
            request(compose(store, since: start, metronome: metronome, drone: drone))
            return
        }
        guard activity.activityState == .active || activity.activityState == .stale else {
            self.activity = nil; dismissed = true
            return
        }
        let wait = lastPush + Self.minInterval - ProcessInfo.processInfo.systemUptime
        if wait > 0 { wake(after: wait); return }
        let state = compose(store, since: start, metronome: metronome, drone: drone)
        let age = now.timeIntervalSince(pushedAt)
        // Unchanged: only the heartbeat that keeps it from going stale while the app runs.
        if state == pushed && age < Self.heartbeat { wake(after: Self.heartbeat - age); return }
        pushed = state; pushedAt = now; lastPush = ProcessInfo.processInfo.systemUptime
        let content = Self.content(state)
        Task { await activity.update(content) }
        wake(after: Self.heartbeat)
    }

    private func compose(_ store: AppStore, since: Date, metronome: Bool, drone: Bool) -> State {
        var state = State(mode: .practice, since: since)
        if metronome {
            state.mode = .metronome
            state.bpm = store.bpm; state.beats = store.beats; state.levels = store.beatLevels
            state.detail = NSLocalizedString("Metronome", comment: "")
        } else if drone {
            state.mode = .drone
            state.detail = NSLocalizedString("Drone", comment: "")
        } else if !lessons.isEmpty {
            state.detail = lessonTitle; state.symbol = lessonSymbol
        } else if store.voiceRunning {
            state.detail = NSLocalizedString("Voice", comment: ""); state.symbol = "music.mic"
        } else {
            state.detail = store.instrumentDisplayName
        }
        if drone {
            let pc = store.droneMidi % 12
            state.drone = NoteNames.name(pc, preferFlats: [1, 3, 8, 10].contains(pc))
        }
        state.streak = store.streak.current
        return state
    }

    private func request(_ state: State) {
        guard UIApplication.shared.applicationState == .active, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let previous = Activity<PracticeActivityAttributes>.activities
        do {
            activity = try Activity.request(attributes: PracticeActivityAttributes(), content: Self.content(state), pushType: nil)
            pushed = state; pushedAt = Date(); lastPush = ProcessInfo.processInfo.systemUptime
            wake(after: Self.heartbeat)
            Analytics.log("live_activity", ["mode": state.mode.rawValue])
        } catch {
            dismissed = true
        }
        // One at a time: a summary still on the Lock Screen gives way to the new session.
        Task { for old in previous { await old.end(nil, dismissalPolicy: .immediate) } }
    }

    private static func content(_ state: State) -> ActivityContent<State> {
        ActivityContent(state: state, staleDate: Date().addingTimeInterval(staleAfter))
    }

    /// A session picked up again within a minute and a half (tuner, then a lesson) keeps its clock.
    private func resumedSince(_ now: Date) -> Date {
        if let lastEnded, now.timeIntervalSince(lastEnded.at) < Self.resumeWindow { return lastEnded.since }
        return now
    }

    /// Nothing plays or is practised: the session ends, after a short grace in the foreground (on the way to the
    /// background at once, so the Lock Screen never flashes a session that just stopped). A background-task
    /// assertion keeps the app awake until the end reaches the system.
    private func scheduleEnd() {
        practiceSince = nil
        guard since != nil || activity != nil, endTask == nil else { return }
        let grace = UIApplication.shared.applicationState == .active ? Self.grace : 0
        endTask = Task { @MainActor [weak self] in
            let assertion = UIApplication.shared.beginBackgroundTask(withName: "Timbre.liveActivity")
            defer { UIApplication.shared.endBackgroundTask(assertion) }
            if grace > 0 { try? await Task.sleep(for: .seconds(grace)) }
            guard !Task.isCancelled, let self else { return }
            self.endTask = nil
            await self.finish()
        }
    }

    private func finish() async {
        let current = activity, last = pushed, start = since
        activity = nil; since = nil; practiceSince = nil; pushed = nil; dismissed = false
        wakeTask?.cancel(); wakeTask = nil; wakeAt = .infinity
        let now = Date()
        if let start { lastEnded = (now, start) }
        guard let ending = current, ending.activityState == .active || ending.activityState == .stale else { return }
        let seconds = start.map { Int(now.timeIntervalSince($0)) } ?? 0
        guard var closing = last, let streak = store?.streak, streak.practicedToday, seconds >= Self.summaryMinimum else {
            await ending.end(nil, dismissalPolicy: .immediate)
            return
        }
        closing.mode = .done; closing.seconds = seconds; closing.streak = streak.current
        await ending.end(ActivityContent(state: closing, staleDate: nil), dismissalPolicy: .after(now.addingTimeInterval(Self.summaryShown)))
    }

    // MARK: Timing and life cycle

    /// Refreshes again after `seconds` (the dwell, the one-a-second limit, the heartbeat); the soonest wins.
    private func wake(after seconds: TimeInterval) {
        let at = ProcessInfo.processInfo.systemUptime + max(0, seconds)
        guard at < wakeAt else { return }
        wakeTask?.cancel()
        wakeAt = at
        wakeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(max(0, seconds)))
            guard !Task.isCancelled, let self else { return }
            self.wakeTask = nil; self.wakeAt = .infinity
            self.refresh()
        }
    }

    private func wentAway() {
        let sounding = store.map { ($0.audio.metronomeRunning && metronomeClaimed) || $0.audio.droneRunning } ?? false
        awaySince = sounding ? nil : Date()
    }

    /// Back in front: starts what waited for the foreground. A lesson left open past the stale time starts a new
    /// session rather than a clock that kept running while nobody played.
    private func cameBack() {
        if let awaySince, Date().timeIntervalSince(awaySince) > Self.staleAfter, activity != nil || since != nil {
            let ending = activity
            activity = nil; since = nil; practiceSince = nil; pushed = nil; lastEnded = nil; dismissed = false
            endTask?.cancel(); endTask = nil
            if let ending { Task { await ending.end(nil, dismissalPolicy: .immediate) } }
        }
        awaySince = nil
        setNeedsRefresh()
    }

    /// The app is quitting: end every activity before the process goes (a bounded wait, never a hang).
    nonisolated static func endAllBeforeExit() {
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            for activity in Activity<PracticeActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            done.signal()
        }
        _ = done.wait(timeout: .now() + 2)
    }
}
