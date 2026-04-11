import Foundation
import SwiftData
import Observation

@Observable
final class CalendarViewModel {
    private let modelContext: ModelContext
    let predictionService: PredictionService

    var displayedMonth: Date = Date.now.startOfDay
    var selectedDate: Date? = nil
    var showingPeriodSheet = false

    // Period logging state
    var periodStartDate: Date = Date.now
    var periodFlowIntensity: FlowIntensity = .medium

    private let calendar = Calendar.current

    init(modelContext: ModelContext, predictionService: PredictionService) {
        self.modelContext = modelContext
        self.predictionService = predictionService
    }

    // MARK: - Month Navigation

    var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    // MARK: - Calendar Grid Data

    var weekdaySymbols: [String] {
        calendar.veryShortWeekdaySymbols
    }

    /// Returns all dates to display in the month grid (including leading/trailing days from adjacent months).
    var daysInMonthGrid: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }

        let firstDay = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leadingEmptyDays = firstWeekday - calendar.firstWeekday
        let adjustedLeading = leadingEmptyDays < 0 ? leadingEmptyDays + 7 : leadingEmptyDays

        let daysInMonth = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30

        var grid: [Date?] = Array(repeating: nil, count: adjustedLeading)

        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: firstDay) {
                grid.append(date)
            }
        }

        // Pad to complete the last row
        while grid.count % 7 != 0 {
            grid.append(nil)
        }

        return grid
    }

    // MARK: - Date Lookups

    func phaseForDate(_ date: Date) -> CyclePhase? {
        guard let cycle = cycleContaining(date) else { return nil }
        let effectiveLength = effectiveCycleLength(for: cycle)
        let effectivePeriod = cycle.periodLength ?? BloomConstants.defaultPeriodLength
        return CycleCalculationService.phase(
            cycleStart: cycle.startDate,
            cycleLength: effectiveLength,
            periodLength: effectivePeriod,
            lutealPhaseLength: predictionService.effectiveLutealPhaseLength,
            on: date
        )
    }

    func fertilityForDate(_ date: Date) -> FertilityLevel? {
        guard let cycle = cycleContaining(date) else { return nil }
        let effectiveLength = effectiveCycleLength(for: cycle)
        return CycleCalculationService.fertilityLevel(
            cycleStart: cycle.startDate,
            cycleLength: effectiveLength,
            lutealPhaseLength: predictionService.effectiveLutealPhaseLength,
            on: date
        )
    }

    func isOnPeriod(_ date: Date) -> Bool {
        if let log = dailyLog(for: date), log.isOnPeriod {
            return true
        }
        // If no explicit log, infer from cycle phase
        guard let cycle = cycleContaining(date) else { return false }
        let day = CycleCalculationService.currentCycleDay(cycleStart: cycle.startDate, on: date)
        let periodLen = cycle.periodLength ?? BloomConstants.defaultPeriodLength
        return day <= periodLen
    }

    func dailyLog(for date: Date) -> DailyLog? {
        let startOfDay = date.startOfDay
        let nextDay = startOfDay.addingDays(1)
        var descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < nextDay }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func cycleDayFor(_ date: Date) -> Int? {
        guard let cycle = cycleContaining(date) else { return nil }
        return CycleCalculationService.currentCycleDay(cycleStart: cycle.startDate, on: date)
    }

    // MARK: - Period Logging

    func startPeriod(on date: Date, flow: FlowIntensity) {
        let normalizedDate = date.startOfDay

        // Close the previous cycle if one exists
        if let previousCycle = predictionService.currentCycle,
           previousCycle.startDate < normalizedDate {
            let length = previousCycle.startDate.daysBetween(normalizedDate)
            previousCycle.cycleLength = length
        }

        // Create new cycle
        let newCycle = Cycle(startDate: normalizedDate)
        modelContext.insert(newCycle)

        // Create daily log for the start date
        let log = getOrCreateLog(for: normalizedDate)
        log.cycle = newCycle
        log.isOnPeriod = true
        log.flowIntensity = flow

        save()
        predictionService.updatePredictions()
    }

    func endPeriod(on date: Date) {
        guard let cycle = predictionService.currentCycle else { return }
        cycle.endDate = date.startOfDay
        cycle.periodLength = cycle.startDate.daysBetween(date.startOfDay) + 1
        save()
        predictionService.updatePredictions()
    }

    func togglePeriodDay(_ date: Date, flow: FlowIntensity = .medium) {
        let log = getOrCreateLog(for: date)
        log.isOnPeriod.toggle()
        log.flowIntensity = log.isOnPeriod ? flow : nil

        // Attach to current cycle if applicable
        if log.cycle == nil, let cycle = cycleContaining(date) {
            log.cycle = cycle
        }

        // Update period length on the cycle
        if let cycle = log.cycle {
            updatePeriodLength(for: cycle)
        }

        save()
        predictionService.updatePredictions()
    }

    // MARK: - Helpers

    private func cycleContaining(_ date: Date) -> Cycle? {
        let normalizedDate = date.startOfDay
        let descriptor = FetchDescriptor<Cycle>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        guard let cycles = try? modelContext.fetch(descriptor) else { return nil }

        for cycle in cycles {
            if cycle.startDate <= normalizedDate {
                // If cycle has a known length, check if date is within it
                if let length = cycle.cycleLength {
                    let cycleEnd = cycle.startDate.addingDays(length - 1)
                    if normalizedDate <= cycleEnd {
                        return cycle
                    }
                } else {
                    // Active cycle (no end known yet) — assume this date belongs to it
                    return cycle
                }
            }
        }
        return nil
    }

    private func effectiveCycleLength(for cycle: Cycle) -> Int {
        if let length = cycle.cycleLength { return length }
        if let avg = predictionService.avgCycleLength { return Int(round(avg)) }
        return BloomConstants.defaultCycleLength
    }

    private func getOrCreateLog(for date: Date) -> DailyLog {
        if let existing = dailyLog(for: date) {
            return existing
        }
        let log = DailyLog(date: date)
        modelContext.insert(log)
        return log
    }

    private func updatePeriodLength(for cycle: Cycle) {
        let periodLogs = (cycle.dailyLogs ?? []).filter { $0.isOnPeriod }.sorted { $0.date < $1.date }
        if let first = periodLogs.first, let last = periodLogs.last {
            cycle.endDate = last.date
            cycle.periodLength = first.date.daysBetween(last.date) + 1
        }
    }

    private func save() {
        try? modelContext.save()
    }
}
