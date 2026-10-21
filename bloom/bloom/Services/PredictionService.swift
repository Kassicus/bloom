import Foundation
import SwiftData
import Observation

/// What the app knows about a single calendar day.
struct DayInfo {
    var cycleDay: Int?
    var phase: CyclePhase?
    var fertility: FertilityLevel?
    var isInFertileWindow = false
    var isOvulationDay = false
    /// A logged period day (including days pre-filled for a period the user started).
    var isPeriod = false
    /// An expected period day in a projected future cycle.
    var isPredictedPeriod = false
    /// Phase and fertility come from projecting future cycles rather than a logged cycle.
    var isProjected = false
}

/// Upcoming dates used for reminders, current cycle first.
struct UpcomingEvents: Equatable {
    var periodStarts: [Date] = []
    var fertileWindowStarts: [Date] = []
    var ovulationDates: [Date] = []
}

@Observable
final class PredictionService {
    private let modelContext: ModelContext
    let cycleManager: CycleManager

    // Current cycle state
    var currentCycle: Cycle?
    var currentCycleDay: Int?
    var currentPhase: CyclePhase?
    var currentFertilityLevel: FertilityLevel?
    var currentPeriodLength: Int = BloomConstants.defaultPeriodLength

    // Predictions
    var predictedNextPeriodStart: Date?
    var predictedOvulationDate: Date?
    var currentFertileWindow: ClosedRange<Date>?

    // Countdowns
    var daysUntilNextPeriod: Int?
    var daysPeriodLate: Int?
    var daysUntilFertileWindow: Int?

    // Statistics
    var avgCycleLength: Double?
    var cycleLengthStdDev: Double?
    var completedCycleCount: Int = 0
    var predictionConfidence: Double = 0.15
    var effectiveCycleLength: Int = BloomConstants.defaultCycleLength
    var expectedPeriodLength: Int = BloomConstants.defaultPeriodLength

    // Luteal phase
    var effectiveLutealPhaseLength: Int = BloomConstants.defaultLutealPhaseLength

    // Conception
    var currentConceptionScore: ConceptionScoreBreakdown?

    /// Bumped when cycles are rebuilt or data is reloaded, so views holding fetched models
    /// (like the Daily Log) know to refetch.
    private(set) var dataVersion = 0

    /// All cycles, oldest first. Refreshed by `updatePredictions()`.
    @ObservationIgnored private(set) var cycles: [Cycle] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.cycleManager = CycleManager(modelContext: modelContext)
    }

    // MARK: - Refresh

    /// Repairs data, rebuilds cycles and recomputes everything. Used at launch and whenever the
    /// app returns to the foreground (the date may have changed, or iCloud may have synced).
    func reloadAll() {
        cycleManager.repairLegacyCyclesIfNeeded()
        cycleManager.mergeDuplicateLogs()
        cycleManager.rebuildCycles()
        updatePredictions()
        dataVersion += 1
    }

    /// Applies a period edit, then refreshes predictions and mirrors the affected days to Health.
    func editPeriods(around date: Date, _ edit: (CycleManager) -> Void) {
        edit(cycleManager)
        updatePredictions()
        dataVersion += 1
        let day = date.startOfDay
        HealthKitService.shared.scheduleSync(
            from: day.addingDays(-BloomConstants.maxPlausiblePeriodLength),
            to: day.addingDays(BloomConstants.maxPlausiblePeriodLength + 1),
            using: cycleManager
        )
    }

    func updatePredictions() {
        let today = Date.now.startOfDay

        cycles = cycleManager.allCycles()
        currentCycle = cycles.last

        completedCycleCount = cycles.filter { $0.cycleLength != nil }.count
        avgCycleLength = CycleCalculationService.averageCycleLength(from: cycles)
        cycleLengthStdDev = CycleCalculationService.cycleLengthStdDev(from: cycles)
        effectiveCycleLength = avgCycleLength.map { Int($0.rounded()) } ?? BloomConstants.defaultCycleLength
        expectedPeriodLength = cycleManager.expectedPeriodLength()

        // Learn personal luteal phase length from BBT-confirmed cycles
        effectiveLutealPhaseLength = CycleCalculationService.learnedLutealPhaseLength(from: cycles)
            ?? BloomConstants.defaultLutealPhaseLength

        guard let cycle = currentCycle else {
            clearPredictions()
            refreshNotifications()
            return
        }

        let logs = cycle.dailyLogs ?? []
        let cycleStart = cycle.startDate.startOfDay

        // Ovulation — refine with available data BEFORE computing phase and fertility
        let refined = cycleManager.updateOvulationEstimate(
            for: cycle,
            logs: logs,
            averageCycleLength: effectiveCycleLength,
            lutealPhaseLength: effectiveLutealPhaseLength
        )
        predictedOvulationDate = refined.date
        currentFertileWindow = CycleCalculationService.fertileWindowRange(ovulationDate: refined.date)

        currentCycleDay = CycleCalculationService.currentCycleDay(cycleStart: cycleStart, on: today)
        currentPeriodLength = cycle.periodLength ?? expectedPeriodLength
        currentPhase = CycleCalculationService.phase(
            cycleDay: currentCycleDay ?? 1,
            periodLength: currentPeriodLength,
            ovulationDay: CycleCalculationService.ovulationDay(cycleStart: cycleStart, ovulationDate: refined.date)
        )

        // Fertility level uses the refined ovulation date, boosted by today's real-time signals
        let baseFertility = CycleCalculationService.fertilityLevel(ovulationDate: refined.date, on: today)
        let todayLog = logs.first { $0.date.startOfDay == today }
        currentFertilityLevel = CycleCalculationService.adjustedFertilityLevel(base: baseFertility, log: todayLog)

        // When ovulation has been pinned down by OPK/BBT/mucus, the luteal phase is the most
        // reliable way to predict the next period; otherwise use the average cycle length.
        let calendarOvulation = CycleCalculationService.estimatedOvulationDate(
            cycleStart: cycleStart,
            cycleLength: effectiveCycleLength,
            lutealPhaseLength: effectiveLutealPhaseLength
        )
        if refined.date != calendarOvulation {
            predictedNextPeriodStart = refined.date.addingDays(effectiveLutealPhaseLength + 1)
        } else {
            predictedNextPeriodStart = CycleCalculationService.predictNextPeriodStart(
                lastCycleStart: cycleStart,
                averageCycleLength: Double(effectiveCycleLength)
            )
        }

        // Countdowns
        if let nextPeriod = predictedNextPeriodStart {
            let days = today.daysBetween(nextPeriod)
            daysUntilNextPeriod = days >= 0 ? days : nil
            daysPeriodLate = days < 0 ? -days : nil
        }

        if let window = currentFertileWindow {
            let daysToStart = today.daysBetween(window.lowerBound)
            daysUntilFertileWindow = daysToStart > 0 ? daysToStart : (today <= window.upperBound ? 0 : nil)
        }

        // Prediction confidence
        predictionConfidence = CycleCalculationService.predictionConfidence(
            completedCycleCount: completedCycleCount,
            hasOPKData: logs.contains { $0.opkResult == .positive },
            hasBBTData: logs.filter({ $0.bbtTemperature != nil }).count >= 10,
            hasBBTConfirmedOvulation: refined.confirmed,
            hasMucusData: logs.contains { $0.cervicalMucus != nil },
            cycleLengthStdDev: cycleLengthStdDev
        )

        currentConceptionScore = CycleCalculationService.conceptionScore(ovulationDate: refined.date, logs: logs)

        refreshNotifications()
    }

    private func clearPredictions() {
        currentCycleDay = nil
        currentPhase = nil
        currentFertilityLevel = nil
        currentPeriodLength = BloomConstants.defaultPeriodLength
        predictedNextPeriodStart = nil
        predictedOvulationDate = nil
        currentFertileWindow = nil
        daysUntilNextPeriod = nil
        daysPeriodLate = nil
        daysUntilFertileWindow = nil
        currentConceptionScore = nil
        predictionConfidence = 0.15
    }

    // MARK: - Day Lookup

    /// The first day of projected future cycles: the predicted next period, or tomorrow if the
    /// period is late.
    var projectionStart: Date? {
        guard let next = predictedNextPeriodStart?.startOfDay else { return nil }
        let today = Date.now.startOfDay
        return next >= today ? next : today.addingDays(1)
    }

    /// Phase, fertility and period status for a day, consistent with the Home screen: logged
    /// cycles use their (refined) ovulation estimate, and days after the current cycle are
    /// projected forward using the average cycle length.
    func dayInfo(for date: Date, log: DailyLog?) -> DayInfo {
        let day = date.startOfDay
        var info = DayInfo()
        info.isPeriod = log?.isOnPeriod == true

        guard let cycle = cycles.last(where: { $0.startDate.startOfDay <= day }) else { return info }
        let isCurrent = cycle === currentCycle

        if isCurrent, let projectionStart, day >= projectionStart {
            return projectedDayInfo(for: day, from: projectionStart, base: info)
        }

        let start = cycle.startDate.startOfDay
        let ovulationDate = (isCurrent ? predictedOvulationDate : cycle.estimatedOvulationDate)
            ?? CycleCalculationService.estimatedOvulationDate(
                cycleStart: start,
                cycleLength: cycle.cycleLength ?? effectiveCycleLength,
                lutealPhaseLength: effectiveLutealPhaseLength
            )

        let cycleDay = start.daysBetween(day) + 1
        info.cycleDay = cycleDay
        info.phase = CycleCalculationService.phase(
            cycleDay: cycleDay,
            periodLength: cycle.periodLength ?? expectedPeriodLength,
            ovulationDay: CycleCalculationService.ovulationDay(cycleStart: start, ovulationDate: ovulationDate)
        )
        info.fertility = CycleCalculationService.adjustedFertilityLevel(
            base: CycleCalculationService.fertilityLevel(ovulationDate: ovulationDate, on: day),
            log: log
        )
        info.isInFertileWindow = CycleCalculationService.fertileWindowRange(ovulationDate: ovulationDate).contains(day)
        info.isOvulationDay = day == ovulationDate.startOfDay
        return info
    }

    private func projectedDayInfo(for day: Date, from projectionStart: Date, base: DayInfo) -> DayInfo {
        var info = base
        let length = max(effectiveCycleLength, BloomConstants.minimumCycleLength)
        let offset = projectionStart.daysBetween(day)
        let cycleStart = projectionStart.addingDays((offset / length) * length)
        let cycleDay = offset % length + 1
        let ovulationDate = CycleCalculationService.estimatedOvulationDate(
            cycleStart: cycleStart,
            cycleLength: length,
            lutealPhaseLength: effectiveLutealPhaseLength
        )

        info.isProjected = true
        info.cycleDay = cycleDay
        info.phase = CycleCalculationService.phase(
            cycleDay: cycleDay,
            periodLength: expectedPeriodLength,
            ovulationDay: length - effectiveLutealPhaseLength
        )
        info.fertility = CycleCalculationService.fertilityLevel(ovulationDate: ovulationDate, on: day)
        info.isInFertileWindow = CycleCalculationService.fertileWindowRange(ovulationDate: ovulationDate).contains(day)
        info.isOvulationDay = day == ovulationDate
        info.isPredictedPeriod = !info.isPeriod && cycleDay <= expectedPeriodLength
        return info
    }

    // MARK: - Notifications

    /// Period starts, fertile windows and ovulation days for the current cycle and the next
    /// `cycleCount - 1` projected ones.
    func upcomingEvents(cycleCount: Int = 3) -> UpcomingEvents {
        var events = UpcomingEvents()
        guard let ovulation = predictedOvulationDate, let projectionStart else { return events }

        events.ovulationDates.append(ovulation)
        events.fertileWindowStarts.append(CycleCalculationService.fertileWindowRange(ovulationDate: ovulation).lowerBound)

        let length = max(effectiveCycleLength, BloomConstants.minimumCycleLength)
        for index in 0..<cycleCount {
            let start = projectionStart.addingDays(index * length)
            events.periodStarts.append(start)
            guard index < cycleCount - 1 else { break }
            let projectedOvulation = CycleCalculationService.estimatedOvulationDate(
                cycleStart: start,
                cycleLength: length,
                lutealPhaseLength: effectiveLutealPhaseLength
            )
            events.ovulationDates.append(projectedOvulation)
            events.fertileWindowStarts.append(CycleCalculationService.fertileWindowRange(ovulationDate: projectedOvulation).lowerBound)
        }
        return events
    }

    /// Reschedules reminders from the latest predictions. Cheap to call often: nothing is
    /// rescheduled unless the dates or preferences changed (or `force` is set).
    func refreshNotifications(force: Bool = false) {
        NotificationService.shared.refresh(events: upcomingEvents(), force: force)
    }
}
