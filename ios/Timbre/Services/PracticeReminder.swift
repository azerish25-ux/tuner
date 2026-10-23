import Foundation
import UserNotifications

/// A daily local notification at the player's chosen time; nothing leaves the device.
enum PracticeReminder {
    static let enabledKey = "reminder.enabled"
    static let minutesKey = "reminder.minutes"
    static let askedKey = "reminder.asked"
    private static let identifier = "timbre.practice.daily"

    /// Minutes after midnight, 7 pm by default.
    static var minutes: Int {
        get { UserDefaults.standard.object(forKey: minutesKey) as? Int ?? 19 * 60 }
        set { UserDefaults.standard.set(newValue, forKey: minutesKey) }
    }

    /// Asks for permission if needed; returns whether the reminder is now on.
    @discardableResult static func enable(at minutes: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true else {
            UserDefaults.standard.set(false, forKey: enabledKey)
            return false
        }
        self.minutes = minutes
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time to play")
        content.body = String(localized: "A five-minute lesson keeps your streak going.")
        content.sound = .default
        var when = DateComponents()
        when.hour = minutes / 60
        when.minute = minutes % 60
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)))
        UserDefaults.standard.set(true, forKey: enabledKey)
        return true
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UserDefaults.standard.set(false, forKey: enabledKey)
    }
}
