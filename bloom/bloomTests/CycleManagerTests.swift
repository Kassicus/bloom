import Foundation
import SwiftData
import Testing
@testable import bloom

@MainActor
struct CycleManagerTests {
    let container: ModelContainer
    let context: ModelContext
    let manager: CycleManager

    init() throws {
        let schema = Schema([Cycle.self, DailyLog.self, IntercourseEntry.self])
        container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        context = container.mainContext
        manager = CycleManager(modelContext: context)
    }

    private func periodDates() -> [Date] {
        let logs = (try? context.fetch(FetchDescriptor<DailyLog>(sortBy: [SortDescriptor(\.date)]))) ?? []
        return logs.filter(\.isOnPeriod).map(\.date)
    }

    private func dates(_ first: String, through last: String) -> [Date] {
        let start = day(first)
        return (0...start.daysBetween(day(last))).map { start.addingDays($0) }
    }

    @discardableResult
    private func addLog(_ date: String, configure: (DailyLog) -> Void = { _ in }) -> DailyLog {
        let log = DailyLog(date: day(date))
        context.insert(log)
        configure(log)
        return log
    }

    // MARK: - Period editing

    @Test func startingAPeriodPrefillsExpectedDaysAndCreatesACycle() {
        manager.setPeriod(true, on: day("2026-03-01"), flow: .heavy)

        #expect(periodDates() == dates("2026-03-01", through: "2026-03-05"))
        let cycles = manager.allCycles()
        #expect(cycles.count == 1)
        #expect(cycles[0].startDate == day("2026-03-01"))
        #expect(cycles[0].periodLength == 5)
        #expect(manager.log(for: day("2026-03-01"))?.flowIntensity == .heavy)
    }

    @Test func markingADayNextToAPeriodExtendsItWithoutPrefilling() {
        manager.setPeriod(true, on: day("2026-03-01"))
        manager.setPeriod(true, on: day("2026-03-06"))

        #expect(periodDates() == dates("2026-03-01", through: "2026-03-06"))
        #expect(manager.allCycles().first?.periodLength == 6)
    }

    @Test func secondPeriodClosesTheFirstCycle() {
        manager.setPeriod(true, on: day("2026-03-01"))
        manager.setPeriod(true, on: day("2026-03-29"))

        let cycles = manager.allCycles()
        #expect(cycles.map(\.startDate) == [day("2026-03-01"), day("2026-03-29")])
        #expect(cycles.map(\.cycleLength) == [28, nil])
    }

    @Test func backfillingAnOlderPeriodGivesItACycleLength() {
        // Entered newest first — the old app never computed a length for the older one.
        manager.logPeriodStart(on: day("2026-03-29"), flow: .medium)
        manager.logPeriodStart(on: day("2026-03-01"), flow: .medium)

        #expect(manager.allCycles().map(\.cycleLength) == [28, nil])
    }

    @Test func loggingTheSameStartTwiceDoesNotDuplicateCycles() {
        manager.logPeriodStart(on: day("2026-03-01"), flow: .medium)
        manager.logPeriodStart(on: day("2026-03-01"), flow: .light)

        #expect(manager.allCycles().count == 1)
    }

    @Test func turningOffAnAccidentalStartClearsItsFuturePrefill() {
        let today = Date.now.startOfDay
        manager.setPeriod(true, on: today)
        manager.setPeriod(false, on: today)

        #expect(periodDates().isEmpty)
        #expect(manager.allCycles().isEmpty)
    }

    @Test func turningOffAPastFirstDayKeepsTheRestOfThePeriod() {
        manager.setPeriod(true, on: day("2026-03-01"))
        manager.setPeriod(false, on: day("2026-03-01"))

        #expect(periodDates() == dates("2026-03-02", through: "2026-03-05"))
        #expect(manager.allCycles().first?.startDate == day("2026-03-02"))
    }

    @Test func logPeriodStartInsideAPeriodMovesTheStart() {
        manager.setPeriod(true, on: day("2026-03-01"))
        manager.logPeriodStart(on: day("2026-03-03"), flow: .medium)

        #expect(manager.allCycles().first?.startDate == day("2026-03-03"))
        #expect(periodDates() == dates("2026-03-03", through: "2026-03-05"))
    }

    @Test func endPeriodTrimsAndFillsDays() {
        manager.setPeriod(true, on: day("2026-03-01")) // pre-fills through Mar 5
        manager.endPeriod(lastDay: day("2026-03-03"))
        #expect(periodDates() == dates("2026-03-01", through: "2026-03-03"))

        manager.endPeriod(lastDay: day("2026-03-07"))
        #expect(periodDates() == dates("2026-03-01", through: "2026-03-07"))
        #expect(manager.allCycles().first?.periodLength == 7)
    }

    @Test func deletePeriodRemovesTheCycleButKeepsOtherLogData() {
        manager.setPeriod(true, on: day("2026-03-01"))
        manager.logOrCreate(for: day("2026-03-02")).bbtTemperature = 97.4
        manager.deletePeriod(containing: day("2026-03-03"))

        #expect(periodDates().isEmpty)
        #expect(manager.allCycles().isEmpty)
        #expect(manager.log(for: day("2026-03-02"))?.bbtTemperature == 97.4)
    }

    // MARK: - Rebuild

    @Test func rebuildAssignsEveryLogToTheCycleContainingIt() {
        addLog("2026-02-20") { $0.bbtTemperature = 97.0 } // before any cycle
        addLog("2026-03-10") { $0.opkResult = .positive }
        addLog("2026-04-02") { $0.bbtTemperature = 97.2 }
        manager.setPeriod(true, on: day("2026-03-01"))
        manager.setPeriod(true, on: day("2026-03-29"))

        let cycles = manager.allCycles()
        #expect(manager.log(for: day("2026-02-20"))?.cycle == nil)
        #expect(manager.log(for: day("2026-03-10"))?.cycle === cycles[0])
        #expect(manager.log(for: day("2026-04-02"))?.cycle === cycles[1])
    }

    @Test func rebuildUsesOPKForTheOvulationEstimate() {
        manager.setPeriod(true, on: day("2026-03-01"))
        manager.logOrCreate(for: day("2026-03-17")).opkResult = .positive
        manager.rebuildCycles()

        #expect(manager.allCycles().first?.estimatedOvulationDate == day("2026-03-18"))
    }

    // MARK: - Legacy repair

    @Test func legacyCycleWithOnlyAStartDayGetsItsInferredPeriodDays() {
        // What the old "Log Period" sheet saved: a cycle plus a single logged day.
        let cycle = Cycle(startDate: day("2026-03-01"))
        context.insert(cycle)
        addLog("2026-03-01") { $0.isOnPeriod = true; $0.flowIntensity = .medium; $0.cycle = cycle }
        // A BBT-only log on day 2 said "not on period", which the old calendar respected.
        addLog("2026-03-02") { $0.bbtTemperature = 97.3; $0.cycle = cycle }

        manager.repairLegacyCycles()
        manager.rebuildCycles()

        #expect(periodDates() == [day("2026-03-01")] + dates("2026-03-03", through: "2026-03-05"))
        #expect(manager.allCycles().count == 1)
        #expect(manager.allCycles().first?.periodLength == 5)
    }

    @Test func legacyBogusPeriodLengthFromEndPeriodBugIsReplaced() {
        // The old "End Period" sheet defaulted to today, so a 27-day "period" got saved.
        let first = Cycle(startDate: day("2026-03-01"))
        first.periodLength = 27
        first.endDate = day("2026-03-27")
        let second = Cycle(startDate: day("2026-03-29"))
        context.insert(first)
        context.insert(second)
        addLog("2026-03-01") { $0.isOnPeriod = true; $0.cycle = first }
        addLog("2026-03-29") { $0.isOnPeriod = true; $0.cycle = second }

        manager.repairLegacyCycles()
        manager.rebuildCycles()

        let cycles = manager.allCycles()
        #expect(cycles.map(\.periodLength) == [5, 5])
        #expect(cycles.map(\.cycleLength) == [28, nil])
    }

    @Test func legacyStoredPeriodLengthIsKept() {
        let cycle = Cycle(startDate: day("2026-03-01"))
        cycle.periodLength = 3
        context.insert(cycle)
        addLog("2026-03-01") { $0.isOnPeriod = true; $0.cycle = cycle }

        manager.repairLegacyCycles()
        manager.rebuildCycles()

        #expect(periodDates() == dates("2026-03-01", through: "2026-03-03"))
    }

    @Test func legacyDuplicateCyclesCollapse() {
        for _ in 0..<2 {
            let cycle = Cycle(startDate: day("2026-03-01"))
            context.insert(cycle)
        }
        addLog("2026-03-01") { $0.isOnPeriod = true }

        manager.repairLegacyCycles()
        manager.rebuildCycles()

        #expect(manager.allCycles().count == 1)
    }

    @Test func cycleWithNoLoggedPeriodDaysIsNotRefilled() {
        // A period deleted on another device: iCloud delivered the unmarked days before the
        // cycle's deletion. Repairing it would bring the deleted period back.
        let cycle = Cycle(startDate: day("2026-03-01"))
        cycle.periodLength = 5
        context.insert(cycle)
        addLog("2026-03-01") { $0.cycle = cycle }

        manager.repairLegacyCycles()

        #expect(periodDates().isEmpty)
    }

    @Test func repairRunsOncePerDeviceOnceThereIsData() throws {
        let defaults = try #require(UserDefaults(suiteName: "CycleManagerTests.\(UUID().uuidString)"))

        manager.repairLegacyCyclesIfNeeded(defaults: defaults) // empty store: still pending
        let cycle = Cycle(startDate: day("2026-03-01"))
        context.insert(cycle)
        addLog("2026-03-01") { $0.isOnPeriod = true; $0.cycle = cycle }
        manager.repairLegacyCyclesIfNeeded(defaults: defaults)
        #expect(periodDates().count == 5)

        manager.setPeriod(false, on: day("2026-03-05"))
        let second = Cycle(startDate: day("2026-04-01"))
        context.insert(second)
        addLog("2026-04-01") { $0.isOnPeriod = true; $0.cycle = second }
        manager.repairLegacyCyclesIfNeeded(defaults: defaults)

        // Already ran on this device, so the new single-day period is left alone.
        #expect(periodDates() == dates("2026-03-01", through: "2026-03-04") + [day("2026-04-01")])
    }

    @Test func repairIsIdempotent() {
        let cycle = Cycle(startDate: day("2026-03-01"))
        context.insert(cycle)
        addLog("2026-03-01") { $0.isOnPeriod = true; $0.cycle = cycle }

        manager.repairLegacyCycles()
        manager.rebuildCycles()
        manager.setPeriod(false, on: day("2026-03-05")) // user trims the inferred period
        manager.repairLegacyCycles()
        manager.rebuildCycles()

        #expect(periodDates() == dates("2026-03-01", through: "2026-03-04"))
    }

    // MARK: - Duplicate logs

    @Test func duplicateLogsForADayAreMerged() {
        addLog("2026-03-10") { $0.bbtTemperature = 97.8; $0.symptoms = [.cramps] }
        let duplicate = addLog("2026-03-10") { $0.opkResult = .positive; $0.symptoms = [.bloating] }
        let entry = IntercourseEntry(dateTime: day("2026-03-10").addingTimeInterval(3600 * 22))
        context.insert(entry)
        entry.dailyLog = duplicate
        try? context.save()

        manager.mergeDuplicateLogs()

        let logs = (try? context.fetch(FetchDescriptor<DailyLog>())) ?? []
        #expect(logs.count == 1)
        #expect(logs[0].bbtTemperature == 97.8)
        #expect(logs[0].opkResult == .positive)
        #expect(Set(logs[0].symptoms) == [.cramps, .bloating])
        #expect(logs[0].intercourseEntries?.count == 1)
        #expect(((try? context.fetch(FetchDescriptor<IntercourseEntry>())) ?? []).count == 1)
    }
}
