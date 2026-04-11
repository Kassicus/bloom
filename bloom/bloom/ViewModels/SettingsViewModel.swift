import Foundation
import SwiftData
import Observation

@Observable
final class SettingsViewModel {
    private let modelContext: ModelContext
    private let predictionService: PredictionService

    // Notification preferences (persisted via UserDefaults through AppStorage in the view)
    var bbtReminderEnabled: Bool = false {
        didSet { updateNotifications() }
    }
    var bbtReminderHour: Int = 6 {
        didSet { updateNotifications() }
    }
    var bbtReminderMinute: Int = 30 {
        didSet { updateNotifications() }
    }
    var periodReminderEnabled: Bool = false {
        didSet { updateNotifications() }
    }
    var fertileWindowAlertEnabled: Bool = false {
        didSet { updateNotifications() }
    }

    // HealthKit
    var healthKitEnabled: Bool = false
    var healthKitSyncStatus: String = "Not Connected"
    var isHealthKitAvailable: Bool { HealthKitService.shared.isAvailable }

    // Display
    var useCelsius: Bool = false

    // Notification permission
    var notificationPermissionGranted: Bool = false

    init(modelContext: ModelContext, predictionService: PredictionService) {
        self.modelContext = modelContext
        self.predictionService = predictionService
    }

    func loadPreferences() {
        let defaults = UserDefaults.standard
        bbtReminderEnabled = defaults.bool(forKey: "bloom.bbtReminderEnabled")
        bbtReminderHour = defaults.object(forKey: "bloom.bbtReminderHour") as? Int ?? 6
        bbtReminderMinute = defaults.object(forKey: "bloom.bbtReminderMinute") as? Int ?? 30
        periodReminderEnabled = defaults.bool(forKey: "bloom.periodReminderEnabled")
        fertileWindowAlertEnabled = defaults.bool(forKey: "bloom.fertileWindowAlertEnabled")
        healthKitEnabled = defaults.bool(forKey: "bloom.healthKitEnabled")
        useCelsius = defaults.bool(forKey: "bloom.useCelsius")

        Task {
            notificationPermissionGranted = await NotificationService.shared.isAuthorized
        }
    }

    func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(bbtReminderEnabled, forKey: "bloom.bbtReminderEnabled")
        defaults.set(bbtReminderHour, forKey: "bloom.bbtReminderHour")
        defaults.set(bbtReminderMinute, forKey: "bloom.bbtReminderMinute")
        defaults.set(periodReminderEnabled, forKey: "bloom.periodReminderEnabled")
        defaults.set(fertileWindowAlertEnabled, forKey: "bloom.fertileWindowAlertEnabled")
        defaults.set(healthKitEnabled, forKey: "bloom.healthKitEnabled")
        defaults.set(useCelsius, forKey: "bloom.useCelsius")
    }

    // MARK: - Notifications

    func requestNotificationPermission() async {
        let granted = await NotificationService.shared.requestPermission()
        notificationPermissionGranted = granted
    }

    private func updateNotifications() {
        savePreferences()

        predictionService.updatePredictions()

        let fertileStart = predictionService.currentFertileWindow?.lowerBound

        NotificationService.shared.rescheduleAll(
            bbtReminderEnabled: bbtReminderEnabled,
            bbtHour: bbtReminderHour,
            bbtMinute: bbtReminderMinute,
            periodReminderEnabled: periodReminderEnabled,
            predictedPeriodDate: predictionService.predictedNextPeriodStart,
            fertileWindowAlertEnabled: fertileWindowAlertEnabled,
            fertileWindowStart: fertileStart,
            predictedOvulationDate: predictionService.predictedOvulationDate
        )
    }

    // MARK: - HealthKit

    func toggleHealthKit() async {
        if !healthKitEnabled {
            // Enabling
            do {
                try await HealthKitService.shared.requestAuthorization()
                healthKitEnabled = true
                healthKitSyncStatus = "Connected"
                savePreferences()
            } catch {
                healthKitSyncStatus = "Authorization Failed"
            }
        } else {
            // Disabling
            healthKitEnabled = false
            healthKitSyncStatus = "Not Connected"
            savePreferences()
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

        for log in logs {
            let isCycleStart = log.cycle?.startDate.startOfDay == log.date.startOfDay
            await HealthKitService.shared.syncLog(log, isCycleStart: isCycleStart)
        }

        healthKitSyncStatus = "Synced"
    }

    // MARK: - Data Management

    var totalCycleCount: Int {
        let descriptor = FetchDescriptor<Cycle>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    var totalLogCount: Int {
        let descriptor = FetchDescriptor<DailyLog>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    func deleteAllData() {
        do {
            try modelContext.delete(model: DailyLog.self)
            try modelContext.delete(model: Cycle.self)
            try modelContext.save()
            predictionService.updatePredictions()
            NotificationService.shared.cancelAllNotifications()
        } catch {
            // Handle silently — UI shows counts which will update
        }
    }
}
