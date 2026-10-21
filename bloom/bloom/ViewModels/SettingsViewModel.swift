import Foundation
import SwiftData
import Observation
import UserNotifications

@Observable
final class SettingsViewModel {
    private let modelContext: ModelContext
    private let predictionService: PredictionService

    // Notification preferences. Initial values come straight from storage; observers only run
    // for user changes afterwards (property observers don't fire during init), so loading can
    // never overwrite stored settings.
    var bbtReminderEnabled = Preferences.bbtReminderEnabled {
        didSet {
            Preferences.bbtReminderEnabled = bbtReminderEnabled
            remindersChanged(enabling: bbtReminderEnabled)
        }
    }
    var bbtReminderHour = Preferences.bbtReminderHour {
        didSet {
            Preferences.bbtReminderHour = bbtReminderHour
            remindersChanged(enabling: false)
        }
    }
    var bbtReminderMinute = Preferences.bbtReminderMinute {
        didSet {
            Preferences.bbtReminderMinute = bbtReminderMinute
            remindersChanged(enabling: false)
        }
    }
    var periodReminderEnabled = Preferences.periodReminderEnabled {
        didSet {
            Preferences.periodReminderEnabled = periodReminderEnabled
            remindersChanged(enabling: periodReminderEnabled)
        }
    }
    var fertileWindowAlertEnabled = Preferences.fertileWindowAlertEnabled {
        didSet {
            Preferences.fertileWindowAlertEnabled = fertileWindowAlertEnabled
            remindersChanged(enabling: fertileWindowAlertEnabled)
        }
    }

    // HealthKit
    var healthKitEnabled = Preferences.healthKitEnabled {
        didSet { Preferences.healthKitEnabled = healthKitEnabled }
    }
    var healthKitSyncStatus: String
    var isHealthKitAvailable: Bool { HealthKitService.shared.isAvailable }

    // Display
    var selectedTheme: AppTheme = ThemeManager.shared.activeTheme {
        didSet {
            ThemeManager.shared.activeTheme = selectedTheme
        }
    }

    // Notification permission
    var notificationStatus: UNAuthorizationStatus = .notDetermined
    var notificationPermissionGranted: Bool {
        notificationStatus == .authorized || notificationStatus == .provisional
    }

    init(modelContext: ModelContext, predictionService: PredictionService) {
        self.modelContext = modelContext
        self.predictionService = predictionService
        self.healthKitSyncStatus = Preferences.healthKitEnabled ? "Connected" : "Not Connected"
    }

    // MARK: - Notifications

    func refreshNotificationStatus() async {
        notificationStatus = await NotificationService.shared.authorizationStatus
    }

    func requestNotificationPermission() async {
        _ = await NotificationService.shared.requestPermission()
        await refreshNotificationStatus()
        predictionService.refreshNotifications(force: true)
    }

    private func remindersChanged(enabling: Bool) {
        if enabling, notificationStatus == .notDetermined {
            Task { await requestNotificationPermission() }
        }
        predictionService.refreshNotifications(force: true)
    }

    // MARK: - HealthKit

    func toggleHealthKit() async {
        if !healthKitEnabled {
            do {
                try await HealthKitService.shared.requestAuthorization()
            } catch {
                healthKitSyncStatus = "Authorization Failed"
                return
            }
            guard HealthKitService.shared.isSharingAuthorized else {
                healthKitSyncStatus = "Not Allowed"
                return
            }
            healthKitEnabled = true
            healthKitSyncStatus = "Connected"
            await syncToHealthKit()
        } else {
            healthKitEnabled = false
            healthKitSyncStatus = "Not Connected"
        }
    }

    func syncToHealthKit() async {
        guard healthKitEnabled else { return }
        healthKitSyncStatus = "Syncing..."

        let descriptor = FetchDescriptor<DailyLog>(sortBy: [SortDescriptor(\.date, order: .forward)])
        guard let logs = try? modelContext.fetch(descriptor) else {
            healthKitSyncStatus = "Sync Failed"
            return
        }

        do {
            try await HealthKitService.shared.mirror(logs)
            healthKitSyncStatus = "Synced"
        } catch {
            healthKitSyncStatus = "Sync Failed"
        }
    }

    // MARK: - Data Management

    var totalCycleCount: Int {
        _ = predictionService.dataVersion
        return (try? modelContext.fetchCount(FetchDescriptor<Cycle>())) ?? 0
    }

    var totalLogCount: Int {
        _ = predictionService.dataVersion
        return (try? modelContext.fetchCount(FetchDescriptor<DailyLog>())) ?? 0
    }

    func deleteAllData() {
        try? predictionService.cycleManager.deleteAllData()
        predictionService.reloadAll()
    }
}
