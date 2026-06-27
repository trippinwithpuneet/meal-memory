import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private let reminderIdentifier = "friday-plan-reminder"
    private let enabledKey = "friday_reminder_enabled"

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional: return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default: return false
        }
    }

    func scheduleFridayReminder(hour: Int = 18, minute: Int = 0) async {
        guard await requestPermission() else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Plan next week 📋"
        content.body = "Friday already! Take 5 minutes to fill in next week's meals."
        content.sound = .default

        var components = DateComponents()
        components.weekday = 6  // Friday
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)
        try? await center.add(request)
        isEnabled = true
    }

    func cancelFridayReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
        isEnabled = false
    }
}
