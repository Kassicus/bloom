import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    /// What was last scheduled, so repeated refreshes with unchanged inputs are no-ops.
    private var lastScheduled: ScheduleInputs?

    private init() {}

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    var authorizationStatus: UNAuthorizationStatus {
        get async {
            await center.notificationSettings().authorizationStatus
        }
    }

    // MARK: - Scheduling

    private struct ScheduleInputs: Equatable {
        var bbtReminderEnabled: Bool
        var bbtHour: Int
        var bbtMinute: Int
        var periodReminderEnabled: Bool
        var fertileWindowAlertEnabled: Bool
        var events: UpcomingEvents
    }

    /// Replaces all pending reminders based on current preferences and predictions.
    ///
    /// Reminders for the next few cycles are scheduled up front, so they keep arriving even if
    /// the app isn't opened for a while; every prediction update reschedules them.
    func refresh(events: UpcomingEvents, force: Bool = false) {
        let inputs = ScheduleInputs(
            bbtReminderEnabled: Preferences.bbtReminderEnabled,
            bbtHour: Preferences.bbtReminderHour,
            bbtMinute: Preferences.bbtReminderMinute,
            periodReminderEnabled: Preferences.periodReminderEnabled,
            fertileWindowAlertEnabled: Preferences.fertileWindowAlertEnabled,
            events: events
        )
        guard force || inputs != lastScheduled else { return }
        lastScheduled = inputs

        center.removeAllPendingNotificationRequests()

        if inputs.bbtReminderEnabled {
            scheduleBBTReminder(hour: inputs.bbtHour, minute: inputs.bbtMinute)
        }

        if inputs.periodReminderEnabled {
            for (index, date) in events.periodStarts.enumerated() {
                schedule(
                    id: "bloom.period.\(index)",
                    title: "Period Expected",
                    body: "Your period may start today. Open Bloom to log it.",
                    category: "period_reminder",
                    on: date
                )
            }
        }

        if inputs.fertileWindowAlertEnabled {
            for (index, start) in events.fertileWindowStarts.enumerated() {
                schedule(
                    id: "bloom.fertile.\(index)",
                    title: "Fertile Window Starting",
                    body: "Your fertile window starts tomorrow. This is the best time for conception.",
                    category: "fertile_window",
                    on: start.addingDays(-1)
                )
            }
            for (index, date) in events.ovulationDates.enumerated() {
                schedule(
                    id: "bloom.ovulation.\(index)",
                    title: "Peak Fertility Today",
                    body: "Today is likely your ovulation day — peak fertility for conception.",
                    category: "ovulation_day",
                    on: date
                )
            }
        }
    }

    private func scheduleBBTReminder(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Log Your Temperature"
        content.body = "Take your BBT before getting out of bed for accurate tracking."
        content.sound = .default
        content.categoryIdentifier = "bbt_reminder"

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        center.add(UNNotificationRequest(identifier: "bloom.bbt.daily", content: content, trigger: trigger))
    }

    /// Schedules a one-off reminder at 9 AM on `day`, if that's still in the future.
    private func schedule(id: String, title: String, body: String, category: String, on day: Date) {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        components.hour = 9
        guard let fireDate = Calendar.current.date(from: components), fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
