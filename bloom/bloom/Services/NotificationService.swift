import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    var isAuthorized: Bool {
        get async {
            let settings = await center.notificationSettings()
            return settings.authorizationStatus == .authorized
        }
    }

    // MARK: - BBT Reminder

    func scheduleBBTReminder(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Log Your Temperature"
        content.body = "Take your BBT before getting out of bed for accurate tracking."
        content.sound = .default
        content.categoryIdentifier = "bbt_reminder"

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "bloom.bbt.daily", content: content, trigger: trigger)

        center.add(request)
    }

    func cancelBBTReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["bloom.bbt.daily"])
    }

    // MARK: - Period Reminder

    func schedulePeriodReminder(expectedDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Period Expected"
        content.body = "Your period may start today. Open Bloom to log it."
        content.sound = .default
        content.categoryIdentifier = "period_reminder"

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: expectedDate)
        var triggerComponents = components
        triggerComponents.hour = 9 // 9 AM on the expected day

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "bloom.period.expected", content: content, trigger: trigger)

        center.add(request)
    }

    func cancelPeriodReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["bloom.period.expected"])
    }

    // MARK: - Fertile Window Alert

    func scheduleFertileWindowAlert(startDate: Date) {
        // Alert 1 day before
        let alertDate = startDate.addingDays(-1)
        guard alertDate > Date.now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Fertile Window Starting"
        content.body = "Your fertile window starts tomorrow. This is the best time for conception."
        content.sound = .default
        content.categoryIdentifier = "fertile_window"

        let components = Calendar.current.dateComponents([.year, .month, .day], from: alertDate)
        var triggerComponents = components
        triggerComponents.hour = 9

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "bloom.fertile.alert", content: content, trigger: trigger)

        center.add(request)
    }

    func cancelFertileWindowAlert() {
        center.removePendingNotificationRequests(withIdentifiers: ["bloom.fertile.alert"])
    }

    // MARK: - Ovulation Day Alert

    func scheduleOvulationDayAlert(ovulationDate: Date) {
        guard ovulationDate > Date.now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Peak Fertility Today"
        content.body = "Today is likely your ovulation day — peak fertility for conception."
        content.sound = .default
        content.categoryIdentifier = "ovulation_day"

        let components = Calendar.current.dateComponents([.year, .month, .day], from: ovulationDate)
        var triggerComponents = components
        triggerComponents.hour = 9

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "bloom.ovulation.day", content: content, trigger: trigger)

        center.add(request)
    }

    func cancelOvulationDayAlert() {
        center.removePendingNotificationRequests(withIdentifiers: ["bloom.ovulation.day"])
    }

    // MARK: - Reschedule All

    func rescheduleAll(
        bbtReminderEnabled: Bool,
        bbtHour: Int,
        bbtMinute: Int,
        periodReminderEnabled: Bool,
        predictedPeriodDate: Date?,
        fertileWindowAlertEnabled: Bool,
        fertileWindowStart: Date?,
        predictedOvulationDate: Date?
    ) {
        // Cancel all first
        cancelBBTReminder()
        cancelPeriodReminder()
        cancelFertileWindowAlert()
        cancelOvulationDayAlert()

        // Reschedule based on preferences
        if bbtReminderEnabled {
            scheduleBBTReminder(hour: bbtHour, minute: bbtMinute)
        }

        if periodReminderEnabled, let periodDate = predictedPeriodDate {
            schedulePeriodReminder(expectedDate: periodDate)
        }

        if fertileWindowAlertEnabled {
            if let windowStart = fertileWindowStart {
                scheduleFertileWindowAlert(startDate: windowStart)
            }
            if let ovDate = predictedOvulationDate {
                scheduleOvulationDayAlert(ovulationDate: ovDate)
            }
        }
    }

    // MARK: - Cancel All

    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }
}
