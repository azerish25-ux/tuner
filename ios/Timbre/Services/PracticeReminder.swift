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

    /// Re-plans the reminders for new state (practice saved, lesson finished, course changed).
    @MainActor static func update(_ next: Context) {
        guard next != context else { return }
        context = next
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
            content.body = body(streak: atStake, lesson: context.nextLesson)
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
