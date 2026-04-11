import Foundation
import SwiftData
import Observation

@Observable
final class DailyLogViewModel {
    private let modelContext: ModelContext
    private let predictionService: PredictionService

    var currentDate: Date {
        didSet { loadLog() }
    }

    // DailyLog fields — kept in sync with the persisted model
    var isOnPeriod: Bool = false { didSet { syncField { log in log.isOnPeriod = isOnPeriod } } }
    var flowIntensity: FlowIntensity = .medium { didSet { syncField { log in log.flowIntensity = flowIntensity } } }
    var bbtTemperature: Double? = nil { didSet { syncField { log in log.bbtTemperature = bbtTemperature } } }
    var cervicalMucus: CervicalMucusType? = nil { didSet { syncField { log in log.cervicalMucus = cervicalMucus } } }
    var opkResult: OPKResult? = nil { didSet { syncField { log in log.opkResult = opkResult } } }
    var symptoms: Set<Symptom> = [] { didSet { syncField { log in log.symptoms = Array(symptoms) } } }
    var intercourseEntries: [IntercourseEntry] = []
    var notes: String = "" { didSet { syncField { log in log.notes = notes.isEmpty ? nil : notes } } }

    // Derived display state
    var currentPhase: CyclePhase? { predictionService.currentPhase }
    var currentFertilityLevel: FertilityLevel? { predictionService.currentFertilityLevel }
    var isInFertileWindow: Bool {
        guard let window = predictionService.currentFertileWindow else { return false }
        return window.contains(currentDate.startOfDay)
    }

    private var currentLog: DailyLog?
    private var isSyncing = false

    init(modelContext: ModelContext, predictionService: PredictionService, date: Date = .now) {
        self.modelContext = modelContext
        self.predictionService = predictionService
        self.currentDate = date.startOfDay
        loadLog()
    }

    // MARK: - Date Navigation

    var dateText: String {
        if currentDate.isToday {
            return "Today"
        }
        return currentDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    var canGoForward: Bool {
        currentDate.startOfDay < Date.now.startOfDay
    }

    func previousDay() {
        currentDate = currentDate.addingDays(-1)
    }

    func nextDay() {
        guard canGoForward else { return }
        currentDate = currentDate.addingDays(1)
    }

    func goToToday() {
        currentDate = Date.now.startOfDay
    }

    // MARK: - Temperature Helpers

    var temperatureText: String {
        guard let temp = bbtTemperature else { return "—" }
        return String(format: "%.1f", temp)
    }

    func incrementTemperature() {
        let current = bbtTemperature ?? 97.5
        let newTemp = min(current + 0.1, BloomConstants.bbtBaselineMax)
        bbtTemperature = (newTemp * 10).rounded() / 10
    }

    func decrementTemperature() {
        let current = bbtTemperature ?? 97.5
        let newTemp = max(current - 0.1, BloomConstants.bbtBaselineMin)
        bbtTemperature = (newTemp * 10).rounded() / 10
    }

    func setTemperature(_ value: Double?) {
        if let value {
            let clamped = min(max(value, BloomConstants.bbtBaselineMin), BloomConstants.bbtBaselineMax)
            bbtTemperature = (clamped * 10).rounded() / 10
        } else {
            bbtTemperature = nil
        }
    }

    // MARK: - Symptom Helpers

    func toggleSymptom(_ symptom: Symptom) {
        if symptoms.contains(symptom) {
            symptoms.remove(symptom)
        } else {
            symptoms.insert(symptom)
        }
    }

    func hasSymptom(_ symptom: Symptom) -> Bool {
        symptoms.contains(symptom)
    }

    // MARK: - Intercourse Helpers

    func addIntercourseEntry(at time: Date = .now) {
        ensureLogExists()
        guard let log = currentLog else { return }

        // Combine the current date with the chosen time
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        let dateTime = calendar.date(from: dateComponents) ?? time

        let entry = IntercourseEntry(dateTime: dateTime)
        entry.dailyLog = log
        modelContext.insert(entry)
        try? modelContext.save()

        intercourseEntries = (log.intercourseEntries ?? []).sorted { $0.dateTime < $1.dateTime }
        predictionService.updatePredictions()
    }

    func removeIntercourseEntry(_ entry: IntercourseEntry) {
        modelContext.delete(entry)
        try? modelContext.save()

        if let log = currentLog {
            intercourseEntries = (log.intercourseEntries ?? []).sorted { $0.dateTime < $1.dateTime }
        } else {
            intercourseEntries = []
        }
        predictionService.updatePredictions()
    }

    func updateIntercourseEntryTime(_ entry: IntercourseEntry, to newTime: Date) {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: newTime)
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        entry.dateTime = calendar.date(from: dateComponents) ?? newTime
        try? modelContext.save()

        if let log = currentLog {
            intercourseEntries = (log.intercourseEntries ?? []).sorted { $0.dateTime < $1.dateTime }
        }
    }

    // MARK: - Completion

    var completionItems: Int {
        var count = 0
        if isOnPeriod { count += 1 }
        if bbtTemperature != nil { count += 1 }
        if cervicalMucus != nil { count += 1 }
        if opkResult != nil { count += 1 }
        if !symptoms.isEmpty { count += 1 }
        if !intercourseEntries.isEmpty { count += 1 }
        return count
    }

    var totalTrackableItems: Int { 6 }

    // MARK: - Private

    private func loadLog() {
        isSyncing = true
        defer { isSyncing = false }

        let startOfDay = currentDate.startOfDay
        let nextDay = startOfDay.addingDays(1)
        var descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < nextDay }
        )
        descriptor.fetchLimit = 1
        currentLog = try? modelContext.fetch(descriptor).first

        if let log = currentLog {
            isOnPeriod = log.isOnPeriod
            flowIntensity = log.flowIntensity ?? .medium
            bbtTemperature = log.bbtTemperature
            cervicalMucus = log.cervicalMucus
            opkResult = log.opkResult
            symptoms = Set(log.symptoms)
            intercourseEntries = (log.intercourseEntries ?? []).sorted { $0.dateTime < $1.dateTime }
            notes = log.notes ?? ""
        } else {
            isOnPeriod = false
            flowIntensity = .medium
            bbtTemperature = nil
            cervicalMucus = nil
            opkResult = nil
            symptoms = []
            intercourseEntries = []
            notes = ""
        }
    }

    private func ensureLogExists() {
        if currentLog == nil {
            let log = DailyLog(date: currentDate)
            modelContext.insert(log)
            if let cycle = predictionService.currentCycle,
               currentDate >= cycle.startDate {
                log.cycle = cycle
            }
            currentLog = log
        }
    }

    private func syncField(_ update: (DailyLog) -> Void) {
        guard !isSyncing else { return }

        if currentLog == nil {
            let log = DailyLog(date: currentDate)
            modelContext.insert(log)

            // Attach to current cycle if applicable
            if let cycle = predictionService.currentCycle,
               currentDate >= cycle.startDate {
                log.cycle = cycle
            }

            currentLog = log
        }

        if let log = currentLog {
            update(log)
            try? modelContext.save()
            predictionService.updatePredictions()
        }
    }
}
