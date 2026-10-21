import Foundation
import SwiftData

/// Owns every change that affects cycle structure.
///
/// Logged period days (`DailyLog.isOnPeriod`) are the single source of truth. `Cycle` records
/// are derived from them by `rebuildCycles()`, which also assigns every log to the cycle that
/// contains its date. All period edits go through this type so the Log tab, the Calendar and the
/// period sheet always agree.
final class CycleManager {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Lookup

    func allCycles() -> [Cycle] {
        let descriptor = FetchDescriptor<Cycle>(sortBy: [SortDescriptor(\.startDate, order: .forward)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func log(for date: Date) -> DailyLog? {
        let start = date.startOfDay
        let end = start.addingDays(1)
        var descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    /// Logs whose date falls in `start..<end`, keyed by start of day.
    func logsByDay(from start: Date, to end: Date) -> [Date: DailyLog] {
        let lower = start.startOfDay
        let upper = end.startOfDay
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date >= lower && $0.date < upper },
            sortBy: [SortDescriptor(\.date)]
        )
        let logs = (try? modelContext.fetch(descriptor)) ?? []
        var byDay: [Date: DailyLog] = [:]
        for log in logs where byDay[log.date.startOfDay] == nil {
            byDay[log.date.startOfDay] = log
        }
        return byDay
    }

    func logOrCreate(for date: Date) -> DailyLog {
        if let existing = log(for: date) {
            return existing
        }
        let log = DailyLog(date: date)
        modelContext.insert(log)
        log.cycle = cycle(containing: date)
        return log
    }

    /// The cycle a date belongs to: the latest cycle that started on or before it.
    func cycle(containing date: Date) -> Cycle? {
        let day = date.startOfDay
        var descriptor = FetchDescriptor<Cycle>(
            predicate: #Predicate { $0.startDate <= day },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    /// Typical period length from recent cycles, used to pre-fill a new period.
    func expectedPeriodLength() -> Int {
        let recent = allCycles()
            .compactMap(\.periodLength)
            .filter { (2...10).contains($0) }
            .suffix(6)
        guard !recent.isEmpty else { return BloomConstants.defaultPeriodLength }
        return Int((Double(recent.reduce(0, +)) / Double(recent.count)).rounded())
    }

    // MARK: - Period Editing

    /// Marks or clears a single period day.
    ///
    /// Marking a day that starts a new period also pre-fills the expected period length after
    /// it, so a single tap gives a full period that can then be adjusted. Clearing the first
    /// day of a period whose remaining days are all still in the future clears those
    /// pre-filled days too (undoing an accidental start).
    func setPeriod(_ isOn: Bool, on date: Date, flow: FlowIntensity? = nil) {
        let day = date.startOfDay
        let log = logOrCreate(for: day)

        if isOn {
            let startsNewPeriod = !hasPeriodDay(near: day)
            log.isOnPeriod = true
            log.flowIntensity = flow ?? log.flowIntensity ?? .medium
            if startsNewPeriod {
                for offset in 1..<expectedPeriodLength() {
                    let filled = logOrCreate(for: day.addingDays(offset))
                    if !filled.isOnPeriod {
                        filled.isOnPeriod = true
                    }
                }
            }
        } else {
            let wasEpisodeStart = periodDays(in: day.addingDays(-BloomConstants.periodGapToleranceDays)..<day).isEmpty
            log.isOnPeriod = false
            log.flowIntensity = nil
            if wasEpisodeStart {
                let remaining = episode(after: day)
                let today = Date.now.startOfDay
                if !remaining.isEmpty, remaining.allSatisfy({ $0.date.startOfDay > today }) {
                    remaining.forEach(clearPeriod)
                }
            }
        }

        rebuildCycles()
    }

    /// Logs that a period started on `date`. If `date` falls inside an already-logged period,
    /// the days before it in that period are cleared so the period starts on `date`.
    func logPeriodStart(on date: Date, flow: FlowIntensity) {
        let day = date.startOfDay
        if log(for: day)?.isOnPeriod == true {
            episode(containing: day)
                .filter { $0.date.startOfDay < day }
                .forEach(clearPeriod)
            save()
        }
        setPeriod(true, on: day, flow: flow)
    }

    /// Records the last day of the period in the cycle containing `lastDay`: fills any unlogged
    /// days from the period start through `lastDay` and clears period days after it.
    func endPeriod(lastDay: Date) {
        let last = lastDay.startOfDay
        guard let cycle = cycle(containing: last) else { return }
        let start = cycle.startDate.startOfDay

        var day = start
        while day <= last {
            let log = logOrCreate(for: day)
            if !log.isOnPeriod {
                log.isOnPeriod = true
            }
            day = day.addingDays(1)
        }

        let periodWindowEnd = start.addingDays(BloomConstants.maxPlausiblePeriodLength)
        periodDays(in: last.addingDays(1)..<periodWindowEnd).forEach(clearPeriod)

        rebuildCycles()
    }

    /// Removes the whole period that `date` belongs to.
    func deletePeriod(containing date: Date) {
        let day = date.startOfDay
        var toClear = episode(containing: day)

        if let cycle = cycle(containing: day), let periodEnd = cycle.endDate,
           day >= cycle.startDate.startOfDay, day <= periodEnd.startOfDay {
            let lower = min(cycle.startDate.startOfDay, toClear.first?.date.startOfDay ?? day)
            let upper = max(periodEnd.startOfDay, toClear.last?.date.startOfDay ?? day)
            toClear = periodDays(in: lower..<upper.addingDays(1))
        }

        toClear.forEach(clearPeriod)
        rebuildCycles()
    }

    // MARK: - Rebuild

    /// Re-derives all `Cycle` records from logged period days, assigns every log to its cycle,
    /// and refreshes each cycle's ovulation estimate. Only writes values that actually changed,
    /// so running it repeatedly doesn't generate needless iCloud uploads.
    func rebuildCycles() {
        let logs = allLogs()
        let derived = CycleCalculationService.deriveCycles(from: logs.filter(\.isOnPeriod).map {
            PeriodDay(date: $0.date.startOfDay, isSpotting: $0.flowIntensity == .spotting)
        })

        // Reuse existing records where the start day matches; create the rest.
        var unmatched = allCycles()
        var cycles: [Cycle] = []
        for derivedCycle in derived {
            let cycle: Cycle
            if let index = unmatched.firstIndex(where: { $0.startDate.startOfDay == derivedCycle.startDate }) {
                cycle = unmatched.remove(at: index)
            } else {
                cycle = Cycle(startDate: derivedCycle.startDate)
                modelContext.insert(cycle)
            }
            setIfChanged(cycle, \.endDate, derivedCycle.periodEndDate)
            setIfChanged(cycle, \.periodLength, derivedCycle.periodLength)
            setIfChanged(cycle, \.cycleLength, derivedCycle.cycleLength)
            cycles.append(cycle)
        }

        // Each cycle covers [its start, next cycle's start).
        var logsByCycle: [ObjectIdentifier: [DailyLog]] = [:]
        var cycleIndex = -1
        for log in logs {
            let day = log.date.startOfDay
            while cycleIndex + 1 < cycles.count, cycles[cycleIndex + 1].startDate.startOfDay <= day {
                cycleIndex += 1
            }
            let target = cycleIndex >= 0 ? cycles[cycleIndex] : nil
            if log.cycle !== target {
                log.cycle = target
            }
            if let target {
                logsByCycle[ObjectIdentifier(target), default: []].append(log)
            }
        }

        // Anything left over no longer has period days behind it.
        for stale in unmatched {
            for log in stale.dailyLogs ?? [] where log.cycle === stale {
                log.cycle = nil
            }
            modelContext.delete(stale)
        }

        refreshOvulationEstimates(for: cycles) { logsByCycle[ObjectIdentifier($0)] ?? [] }
        save()
    }

    /// Recomputes the ovulation estimate for every cycle. Confirmed (BBT) estimates don't depend
    /// on the luteal phase length, so they're computed first and used to learn it.
    private func refreshOvulationEstimates(for cycles: [Cycle], logs: (Cycle) -> [DailyLog]) {
        let averageLength = CycleCalculationService.averageCycleLength(from: cycles)
            .map { Int($0.rounded()) } ?? BloomConstants.defaultCycleLength

        for cycle in cycles {
            updateOvulationEstimate(for: cycle, logs: logs(cycle), averageCycleLength: averageLength, lutealPhaseLength: BloomConstants.defaultLutealPhaseLength)
        }

        let luteal = CycleCalculationService.learnedLutealPhaseLength(from: cycles) ?? BloomConstants.defaultLutealPhaseLength
        guard luteal != BloomConstants.defaultLutealPhaseLength else { return }
        for cycle in cycles where !cycle.isOvulationConfirmed {
            updateOvulationEstimate(for: cycle, logs: logs(cycle), averageCycleLength: averageLength, lutealPhaseLength: luteal)
        }
    }

    /// Updates a cycle's stored ovulation estimate from its logs and returns it.
    @discardableResult
    func updateOvulationEstimate(for cycle: Cycle, logs: [DailyLog], averageCycleLength: Int, lutealPhaseLength: Int) -> (date: Date, confirmed: Bool) {
        let refined = CycleCalculationService.refineOvulationEstimate(
            cycleStart: cycle.startDate,
            cycleLength: cycle.cycleLength ?? averageCycleLength,
            lutealPhaseLength: lutealPhaseLength,
            logs: logs
        )
        setIfChanged(cycle, \.estimatedOvulationDate, refined.date)
        setIfChanged(cycle, \.isOvulationConfirmed, refined.confirmed)
        return refined
    }

    // MARK: - Data Repair

    /// Merges duplicate logs for the same day. Two devices logging the same day before iCloud
    /// syncs can create these; afterwards the app would only ever see one of them.
    func mergeDuplicateLogs() {
        var keepers: [Date: DailyLog] = [:]
        var merged = false
        for log in allLogs() {
            let day = log.date.startOfDay
            guard let keeper = keepers[day] else {
                keepers[day] = log
                continue
            }
            merge(log, into: keeper)
            modelContext.delete(log)
            merged = true
        }
        if merged { save() }
    }

    /// Runs `repairLegacyCycles()` once per device. It's only marked done once there is data, so
    /// a fresh install still waiting on iCloud gets repaired when the data arrives. Running it
    /// only once matters with iCloud: another device's edits can arrive in pieces (unmarked days
    /// before the updated cycle), and repairing that half-synced state would undo the edit.
    func repairLegacyCyclesIfNeeded(defaults: UserDefaults = .standard) {
        let key = "bloom.migration.legacyPeriodDaysRepaired"
        guard !defaults.bool(forKey: key), !allCycles().isEmpty else { return }
        repairLegacyCycles()
        defaults.set(true, forKey: key)
    }

    /// Repair for data saved by earlier versions.
    ///
    /// Earlier versions created a `Cycle` from the "Log Period" sheet but only logged its first
    /// day; the rest of the period was inferred on the fly (from `periodLength`, or 5 days).
    /// Those cycles are recognisable as having their start day as the only logged period day
    /// while their `periodLength` isn't 1. For each, the period days the old calendar showed are
    /// written as real logs so the new period-day model keeps showing the same periods.
    ///
    /// `periodLength` values above 10 days came from the old "End Period" bug (which defaulted
    /// the end date to today) and are replaced with the typical period length.
    func repairLegacyCycles() {
        let cycles = allCycles()
        guard !cycles.isEmpty else { return }

        let defaultLength = expectedPeriodLength()
        var periodDates = Set(allLogs().filter(\.isOnPeriod).map { $0.date.startOfDay })
        var changed = false

        for (index, cycle) in cycles.enumerated() {
            let start = cycle.startDate.startOfDay
            let windowEnd = start.addingDays(BloomConstants.maxPlausiblePeriodLength)
            let loggedDays = periodDates.filter { $0 >= start && $0 < windowEnd }
            guard loggedDays == [start], cycle.periodLength != 1 else { continue }

            let nextStart = cycles[(index + 1)...].first { $0.startDate.startOfDay > start }?.startDate.startOfDay
            let storedLength = cycle.periodLength.flatMap { (1...10).contains($0) ? $0 : nil }

            for offset in 0..<(storedLength ?? defaultLength) {
                let day = start.addingDays(offset)
                if let nextStart, day >= nextStart { break }

                if let existing = log(for: day) {
                    // The old calendar trusted a stored period length over the log; without one,
                    // a log that said "not on period" won.
                    guard storedLength != nil else { continue }
                    if !existing.isOnPeriod { existing.isOnPeriod = true }
                } else {
                    let log = DailyLog(date: day)
                    log.isOnPeriod = true
                    modelContext.insert(log)
                }
                periodDates.insert(day)
                changed = true
            }
        }

        if changed { save() }
    }

    func deleteAllData() throws {
        for entry in (try? modelContext.fetch(FetchDescriptor<IntercourseEntry>())) ?? [] {
            modelContext.delete(entry)
        }
        for log in allLogs() {
            modelContext.delete(log)
        }
        for cycle in allCycles() {
            modelContext.delete(cycle)
        }
        try modelContext.save()
    }

    // MARK: - Helpers

    private func allLogs() -> [DailyLog] {
        let descriptor = FetchDescriptor<DailyLog>(sortBy: [SortDescriptor(\.date, order: .forward)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func periodDays(in range: Range<Date>) -> [DailyLog] {
        let lower = range.lowerBound.startOfDay
        let upper = range.upperBound.startOfDay
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.isOnPeriod && $0.date >= lower && $0.date < upper },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// True if a period day is logged within the gap tolerance before or after `day`.
    private func hasPeriodDay(near day: Date) -> Bool {
        let tolerance = BloomConstants.periodGapToleranceDays
        return !periodDays(in: day.addingDays(-tolerance)..<day).isEmpty
            || !periodDays(in: day.addingDays(1)..<day.addingDays(tolerance + 1)).isEmpty
    }

    /// The chain of period days following `day` (each within the gap tolerance of the last).
    private func episode(after day: Date) -> [DailyLog] {
        var result: [DailyLog] = []
        var last = day
        for log in periodDays(in: day.addingDays(1)..<day.addingDays(60)) {
            guard last.daysBetween(log.date) <= BloomConstants.periodGapToleranceDays else { break }
            result.append(log)
            last = log.date.startOfDay
        }
        return result
    }

    /// The chain of period days that `day` belongs to, in date order.
    private func episode(containing day: Date) -> [DailyLog] {
        var before: [DailyLog] = []
        var first = day
        for log in periodDays(in: day.addingDays(-60)..<day).reversed() {
            guard log.date.daysBetween(first) <= BloomConstants.periodGapToleranceDays else { break }
            before.insert(log, at: 0)
            first = log.date.startOfDay
        }
        let current = log(for: day).map { $0.isOnPeriod ? [$0] : [] } ?? []
        return before + current + episode(after: day)
    }

    private func clearPeriod(_ log: DailyLog) {
        log.isOnPeriod = false
        log.flowIntensity = nil
    }

    private func merge(_ duplicate: DailyLog, into keeper: DailyLog) {
        if duplicate.isOnPeriod { keeper.isOnPeriod = true }
        keeper.flowIntensity = keeper.flowIntensity ?? duplicate.flowIntensity
        keeper.bbtTemperature = keeper.bbtTemperature ?? duplicate.bbtTemperature
        keeper.cervicalMucus = keeper.cervicalMucus ?? duplicate.cervicalMucus
        keeper.opkResult = keeper.opkResult ?? duplicate.opkResult

        let symptoms = Set(keeper.symptoms).union(duplicate.symptoms)
        if symptoms.count != keeper.symptoms.count {
            keeper.symptoms = Array(symptoms)
        }

        switch (keeper.notes, duplicate.notes) {
        case (nil, let notes?):
            keeper.notes = notes
        case (let kept?, let notes?) where kept != notes:
            keeper.notes = kept + "\n" + notes
        default:
            break
        }

        // Move entries explicitly on both sides before the duplicate (and its cascade) is deleted.
        let entries = duplicate.intercourseEntries ?? []
        if !entries.isEmpty {
            duplicate.intercourseEntries = []
            keeper.intercourseEntries = (keeper.intercourseEntries ?? []) + entries
        }
    }

    private func setIfChanged<Value: Equatable>(_ cycle: Cycle, _ keyPath: ReferenceWritableKeyPath<Cycle, Value>, _ value: Value) {
        if cycle[keyPath: keyPath] != value {
            cycle[keyPath: keyPath] = value
        }
    }

    private func save() {
        try? modelContext.save()
    }
}
