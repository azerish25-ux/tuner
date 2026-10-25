import Foundation
import TimbreCore
import UserNotifications

/// The practice reminder at the player's chosen time; nothing leaves the device.
/// Rather than one repeating alert, the next two weeks are planned as single reminders and re-planned
/// whenever practice is saved: no reminder on a day already practised, and each names the next lesson
/// and the streak at stake. If the app goes unopened for two weeks, the reminders stop.
/// The first Sunday ahead carries "Your week" in place of that day's reminder: the minutes and days played in the
/// seven days ending that Sunday. One a week, never alongside a reminder, and only with reminders turned on.
enum PracticeReminder {
    static let enabledKey = "reminder.enabled"
    static let minutesKey = "reminder.minutes"
    static let askedKey = "reminder.asked"
    private static let identifier = "timbre.practice.daily"
    /// Sunday's "Your week": one fixed identifier, so planning again replaces it and there is never a second.
    private static let weekIdentifier = "timbre.practice.week"
    private static let days = 14
    private static var identifiers: [String] { [identifier, weekIdentifier] + (0..<days).map { "\(identifier).\($0)" } }

    /// What the next reminders say; refreshed from the app's state.
    struct Context: Equatable {
        var streak = 0
        var practicedToday = false
        var nextLesson: String?
        /// Minutes played on each of the last two weeks' days (keyed by the start of the day; a day played without timed
        /// practice counts 0), for Sunday's "Your week".
        var minutesByDay: [Date: Int] = [:]
        /// The day a spaced review is first due in Learn's course (nil: nothing to review); reminders from then say so.
        var reviewDue: Date?
    }

    /// The latest context, so a change of time or a fresh enable can re-plan without the app's state.
    @MainActor private static var context = Context()

    /// Minutes after midnight, 7 pm by default.
    static var minutes: Int {
        get { UserDefaults.standard.object(forKey: minutesKey) as? Int ?? 19 * 60 }
        set { UserDefaults.standard.set(newValue, forKey: minutesKey) }
    }

    /// Minutes played per day over the last two weeks, from the practice history (`Context.minutesByDay`).
    static func minutesByDay(_ records: [PracticeRecord], now: Date = Date(), calendar: Calendar = .current) -> [Date: Int] {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [:] }
        var milliseconds: [Date: Int] = [:]
        for record in records where record.date >= start && record.date <= now {
            milliseconds[calendar.startOfDay(for: record.date), default: 0] += max(0, record.durationMs ?? 0)
        }
        return milliseconds.mapValues { Int((Double($0) / 60_000).rounded()) }
    }

    /// Asks for permission if needed; returns whether the reminder is now on.
    @MainActor @discardableResult static func enable(at minutes: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true else {
            UserDefaults.standard.set(false, forKey: enabledKey)
            return false
        }
        self.minutes = minutes
        UserDefaults.standard.set(true, forKey: enabledKey)
        await plan(context)
        return true
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        UserDefaults.standard.set(false, forKey: enabledKey)
    }

    /// The app's state as last handed over (`update`).
    @MainActor static var latest: Context { context }

    /// Re-plans the reminders for new state (practice saved, lesson finished, course changed), and rewrites a waiting
    /// trial reminder with what the trial has been used for.
    @MainActor static func update(_ next: Context) {
        guard next != context else { return }
        context = next
        Task { await TrialReminder.refresh(next) }
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return }
        Task { await plan(next) }
    }

    @MainActor private static func plan(_ context: Context) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        var weekPlanned = false
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(byAdding: .minute, value: minutes, to: day), fire > now else { continue }
            let when = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            // The first Sunday ahead: "Your week" instead of the reminder, played or not.
            if !weekPlanned && calendar.component(.weekday, from: day) == 1 {
                weekPlanned = true
                let content = UNMutableNotificationContent()
                content.title = String(localized: "Your week")
                content.body = weekBody(ending: day, context.minutesByDay, calendar: calendar)
                content.sound = .default
                try? await center.add(UNNotificationRequest(identifier: weekIdentifier, content: content, trigger: trigger))
                continue
            }
            if offset == 0 && context.practicedToday { continue }
            // The streak is only known to be at stake today (not yet practised) or tomorrow (practised today).
            let atStake = (offset == 0 && !context.practicedToday) || (offset == 1 && context.practicedToday) ? context.streak : 0
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Time to play")
            content.body = body(streak: atStake, lesson: context.nextLesson) + (context.reviewDue.map { $0 <= fire } == true ? " " + String(localized: "Your review is ready.") : "")
            content.sound = .default
            try? await center.add(UNNotificationRequest(identifier: "\(identifier).\(offset)", content: content, trigger: trigger))
        }
    }

    private static func body(streak: Int, lesson: String?) -> String {
        switch (streak > 0, lesson) {
        case (true, let lesson?): return String(localized: "Keep your \(streak)-day streak alive. Next up: \(lesson)")
        case (false, let lesson?): return String(localized: "Next up: \(lesson)")
        default: return String(localized: "A five-minute lesson keeps your streak going.")
        }
    }

    /// The seven days ending `sunday`, as played so far: re-planned with every practice saved, so it is the week's
    /// total by the time it shows (the days still ahead count as not played until they are).
    private static func weekBody(ending sunday: Date, _ minutesByDay: [Date: Int], calendar: Calendar) -> String {
        let start = calendar.date(byAdding: .day, value: -6, to: sunday) ?? sunday
        let week = minutesByDay.filter { $0.key >= start && $0.key <= sunday }
        guard !week.isEmpty else { return String(localized: "No practice this week yet. Five minutes today gets you going again.") }
        let minutes = week.values.reduce(0, +)
        return String(localized: "\(minutes) min of practice across \(week.count) of 7 days. Keep the run going.")
    }
}

/// The local reminder two days before a free trial renews. The paywall promises it only when it can arrive. It names
/// what the trial has been used for so far ("You've practised 95 min on 8 days with Pro"), rewritten whenever
/// practice is saved, so the person decides on what they actually did.
enum TrialReminder {
    private static let identifier = "timbre.trial.reminder"
    private static let fireKey = "trial.reminder.fire"
    private static let startKey = "trial.reminder.start"

    /// True when notifications are turned off for Timbre, so a reminder would never be shown.
    static func isBlocked() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .denied
    }

    /// Called right after a trial starts. A first-time user is asked for permission here, never before.
    @MainActor static func schedule(afterDays days: Int) async {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .denied:
            return
        case .notDetermined:
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        default:
            break
        }
        let start = Date()
        UserDefaults.standard.set(start, forKey: startKey)
        UserDefaults.standard.set(start.addingTimeInterval(max(3600, TimeInterval(days - 2) * 86_400)), forKey: fireKey)
        await plan(PracticeReminder.latest)
    }

    /// Rewrites a reminder still to come with the practice so far.
    @MainActor static func refresh(_ context: PracticeReminder.Context) async {
        guard let fire = UserDefaults.standard.object(forKey: fireKey) as? Date, fire > Date() else { return }
        await plan(context)
    }

    @MainActor private static func plan(_ context: PracticeReminder.Context) async {
        guard let fire = UserDefaults.standard.object(forKey: fireKey) as? Date, fire > Date() else { return }
        let start = UserDefaults.standard.object(forKey: startKey) as? Date ?? Date()
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your Timbre Pro trial ends soon")
        content.body = body(since: start, context.minutesByDay)
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, fire.timeIntervalSinceNow), repeats: false)
        // The same identifier: a rewrite replaces the reminder rather than adding a second.
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    /// The days played since the trial began and their minutes, then when it renews and how to stop it.
    private static func body(since start: Date, _ minutesByDay: [Date: Int]) -> String {
        let first = Calendar.current.startOfDay(for: start)
        let played = minutesByDay.filter { $0.key >= first }
        let minutes = played.values.reduce(0, +)
        let renews = String(localized: "It renews in two days; cancel anytime in Settings.")
        switch (played.count, minutes > 0) {
        case (0, _): return String(localized: "It renews in two days. Keep playing, or cancel anytime in Settings.")
        case (1, true): return String(localized: "You've practised \(minutes) min with Pro so far.") + " " + renews
        case (1, false): return String(localized: "You've played with Pro once so far.") + " " + renews
        case (_, true): return String(localized: "You've practised \(minutes) min on \(played.count) days with Pro.") + " " + renews
        default: return String(localized: "You've practised on \(played.count) days with Pro.") + " " + renews
        }
    }
}
