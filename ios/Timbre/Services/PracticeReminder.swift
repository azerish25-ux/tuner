import Foundation
import UserNotifications

/// The practice reminder at the player's chosen time; nothing leaves the device.
/// Rather than one repeating alert, the next two weeks are planned as single reminders and re-planned
/// whenever practice is saved: no reminder on a day already practised, and each names the next lesson
/// and the streak at stake. If the app goes unopened for two weeks, the reminders stop.
enum PracticeReminder {
    static let enabledKey = "reminder.enabled"
    static let minutesKey = "reminder.minutes"
    static let askedKey = "reminder.asked"
    private static let identifier = "timbre.practice.daily"
    private static let days = 14
    private static var identifiers: [String] { [identifier] + (0..<days).map { "\(identifier).\($0)" } }

    /// What the next reminders say; refreshed from the app's state.
    struct Context: Equatable {
        var streak = 0
        var practicedToday = false
        var nextLesson: String?
    }

    /// The latest context, so a change of time or a fresh enable can re-plan without the app's state.
    @MainActor private static var context = Context()

    /// Minutes after midnight, 7 pm by default.
    static var minutes: Int {
        get { UserDefaults.standard.object(forKey: minutesKey) as? Int ?? 19 * 60 }
        set { UserDefaults.standard.set(newValue, forKey: minutesKey) }
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
        for offset in 0..<days {
            if offset == 0 && context.practicedToday { continue }
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(byAdding: .minute, value: minutes, to: day), fire > now else { continue }
            // The streak is only known to be at stake today (not yet practised) or tomorrow (practised today).
            let atStake = (offset == 0 && !context.practicedToday) || (offset == 1 && context.practicedToday) ? context.streak : 0
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Time to play")
            content.body = body(streak: atStake, lesson: context.nextLesson)
            content.sound = .default
            let when = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            try? await center.add(UNNotificationRequest(identifier: "\(identifier).\(offset)", content: content,
                                                        trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)))
        }
    }

    private static func body(streak: Int, lesson: String?) -> String {
        switch (streak > 0, lesson) {
        case (true, let lesson?): return String(localized: "Keep your \(streak)-day streak alive. Next up: \(lesson)")
        case (false, let lesson?): return String(localized: "Next up: \(lesson)")
        default: return String(localized: "A five-minute lesson keeps your streak going.")
        }
    }
}
