import Foundation
import SwiftData
import Observation

@Observable
final class DailyLogViewModel {
    private let modelContext: ModelContext
    private let predictionService: PredictionService
    private var cycleManager: CycleManager { predictionService.cycleManager }

    var currentDate: Date {
        didSet { loadLog() }
    }

    /// Display unit for temperatures; set by the view from the user's preference.
    var temperatureUnit: TemperatureUnit = .fahrenheit

    // DailyLog fields — kept in sync with the persisted model.
    // Period fields change cycle structure, so they're edited through `setOnPeriod`/`setFlow`.
    private(set) var isOnPeriod: Bool = false
    private(set) var flowIntensity: FlowIntensity = .medium
    var bbtTemperature: Double? = nil { didSet { syncField { log in log.bbtTemperature = bbtTemperature } } }
    var cervicalMucus: CervicalMucusType? = nil { didSet { syncField { log in log.cervicalMucus = cervicalMucus } } }
    var opkResult: OPKResult? = nil { didSet { syncField { log in log.opkResult = opkResult } } }
    var symptoms: Set<Symptom> = [] { didSet { syncField(affectsPredictions: false) { log in log.symptoms = Array(symptoms) } } }
    var intercourseEntries: [IntercourseEntry] = []
    var notes: String = "" { didSet { syncField(affectsPredictions: false) { log in log.notes = notes.isEmpty ? nil : notes } } }

    // Derived display state for the selected day (not today)
    var dayInfo: DayInfo { predictionService.dayInfo(for: currentDate, log: currentLog) }
    var currentFertilityLevel: FertilityLevel? { dayInfo.fertility }
    var isInFertileWindow: Bool { dayInfo.isInFertileWindow }

    private var currentLog: DailyLog?
    private var isSyncing = false
    /// The day that was "today" when the log was last loaded, to follow the date across midnight.
    private var lastKnownToday = Date.now.startOfDay

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

    func show(_ date: Date) {
        currentDate = min(date.startOfDay, Date.now.startOfDay)
    }

    /// Re-reads the log from the store (other screens may have changed it). If the log was
    /// showing today and the date has since changed, moves on to the new today.
    func reload() {
        let today = Date.now.startOfDay
        defer { lastKnownToday = today }
        if currentDate == lastKnownToday, today != lastKnownToday {
            currentDate = today
        } else {
            loadLog()
        }
    }

    // MARK: - Period

    func setOnPeriod(_ isOn: Bool) {
        let date = currentDate
        let flow = flowIntensity
        predictionService.editPeriods(around: date) { $0.setPeriod(isOn, on: date, flow: isOn ? flow : nil) }
        loadLog()
    }

    func setFlow(_ flow: FlowIntensity) {
        let date = currentDate
        predictionService.editPeriods(around: date) { manager in
            manager.logOrCreate(for: date).flowIntensity = flow
            // Spotting doesn't start a cycle, so switching to/from it can move cycle boundaries.
            manager.rebuildCycles()
        }
        loadLog()
    }

    /// Shown on the first day of a period, which pre-fills the days after it.
    var periodPrefillNote: String? {
        guard isOnPeriod,
              let cycle = predictionService.cycles.last(where: { $0.startDate.startOfDay == currentDate }),
              let periodLength = cycle.periodLength, periodLength > 1 else { return nil }
        return "Day 1 of your cycle. Bloom marked \(periodLength) days as your period — turn days off from the Calendar or this screen if it ends sooner."
    }

    // MARK: - Temperature Helpers

    func incrementTemperature() {
        adjustTemperature(by: temperatureUnit.step)
    }

    func decrementTemperature() {
        adjustTemperature(by: -temperatureUnit.step)
    }

    /// Starts a reading from the most recent logged temperature, so only a small adjustment is needed.
    func startTemperatureEntry() {
        setTemperature(fahrenheit: lastLoggedTemperature ?? BloomConstants.bbtDefaultFahrenheit)
    }

    func clearTemperature() {
        bbtTemperature = nil
    }

    /// Sets the temperature from typed text in the display unit. Returns false if it isn't a
    /// plausible reading.
    @discardableResult
    func setTemperature(text: String) -> Bool {
        guard let fahrenheit = temperatureUnit.parseToFahrenheit(text) else { return false }
        setTemperature(fahrenheit: fahrenheit)
        return true
    }

    private func adjustTemperature(by delta: Double) {
        let base = bbtTemperature ?? lastLoggedTemperature ?? BloomConstants.bbtDefaultFahrenheit
        let step = temperatureUnit.step
        let shown = (temperatureUnit.fromFahrenheit(base) / step).rounded() * step
        setTemperature(fahrenheit: temperatureUnit.toFahrenheit(shown + delta))
    }

    private func setTemperature(fahrenheit value: Double) {
        let clamped = min(max(value, BloomConstants.bbtEntryMinFahrenheit), BloomConstants.bbtEntryMaxFahrenheit)
        bbtTemperature = (clamped * 100).rounded() / 100
    }

    private var lastLoggedTemperature: Double? {
        let date = currentDate
        var descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.bbtTemperature != nil && $0.date < date },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor).first)?.bbtTemperature
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
        let log = currentLog ?? cycleManager.logOrCreate(for: currentDate)
        currentLog = log

        let entry = IntercourseEntry(dateTime: combine(currentDate, withTimeOf: time))
        modelContext.insert(entry)
        entry.dailyLog = log
        intercourseDidChange()
    }

    func removeIntercourseEntry(_ entry: IntercourseEntry) {
        modelContext.delete(entry)
        intercourseDidChange()
    }

    func updateIntercourseEntryTime(_ entry: IntercourseEntry, to newTime: Date) {
        entry.dateTime = combine(currentDate, withTimeOf: newTime)
        intercourseDidChange()
    }

    private func intercourseDidChange() {
        try? modelContext.save()
        intercourseEntries = (currentLog?.intercourseEntries ?? []).sorted { $0.dateTime < $1.dateTime }
        predictionService.updatePredictions()
        HealthKitService.shared.scheduleSync(for: currentDate, using: cycleManager)
    }

    private func combine(_ day: Date, withTimeOf time: Date) -> Date {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: day)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        return calendar.date(from: dateComponents) ?? time
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

        currentLog = cycleManager.log(for: currentDate)

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

    private func syncField(affectsPredictions: Bool = true, _ update: (DailyLog) -> Void) {
        guard !isSyncing else { return }

        let log = currentLog ?? cycleManager.logOrCreate(for: currentDate)
        currentLog = log
        update(log)
        try? modelContext.save()

        if affectsPredictions {
            predictionService.updatePredictions()
        }
        HealthKitService.shared.scheduleSync(for: currentDate, using: cycleManager)
    }
}
