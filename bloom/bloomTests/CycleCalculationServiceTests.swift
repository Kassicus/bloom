import Foundation
import Testing
@testable import bloom

/// Builds a start-of-day date from a "yyyy-MM-dd" string in the current calendar.
func day(_ string: String) -> Date {
    let parts = string.split(separator: "-").compactMap { Int($0) }
    let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
    return Calendar.current.date(from: components)!.startOfDay
}

/// Period days for every date in `first...last`.
func periodDays(_ first: String, through last: String, spotting: Bool = false) -> [PeriodDay] {
    let start = day(first)
    let count = start.daysBetween(day(last)) + 1
    return (0..<count).map { PeriodDay(date: start.addingDays($0), isSpotting: spotting) }
}

struct CycleDerivationTests {

    @Test func noPeriodDaysMeansNoCycles() {
        #expect(CycleCalculationService.deriveCycles(from: []).isEmpty)
    }

    @Test func singlePeriodStartsAnOpenCycle() {
        let cycles = CycleCalculationService.deriveCycles(from: periodDays("2026-03-01", through: "2026-03-05"))

        #expect(cycles.count == 1)
        #expect(cycles[0].startDate == day("2026-03-01"))
        #expect(cycles[0].periodEndDate == day("2026-03-05"))
        #expect(cycles[0].periodLength == 5)
        #expect(cycles[0].cycleLength == nil)
    }

    @Test func consecutivePeriodsSetCycleLengths() {
        let days = periodDays("2026-01-01", through: "2026-01-05")
            + periodDays("2026-01-29", through: "2026-02-02")
            + periodDays("2026-02-27", through: "2026-03-02")

        let cycles = CycleCalculationService.deriveCycles(from: days)

        #expect(cycles.map(\.startDate) == [day("2026-01-01"), day("2026-01-29"), day("2026-02-27")])
        #expect(cycles.map(\.cycleLength) == [28, 29, nil])
        #expect(cycles.map(\.periodLength) == [5, 5, 4])
    }

    @Test func inputOrderAndDuplicateDaysDoNotMatter() {
        let ordered = periodDays("2026-01-01", through: "2026-01-04") + periodDays("2026-01-30", through: "2026-02-02")
        let shuffled = ordered.reversed() + ordered.prefix(2)

        #expect(CycleCalculationService.deriveCycles(from: Array(shuffled)) == CycleCalculationService.deriveCycles(from: ordered))
    }

    @Test func shortUnloggedGapStaysInTheSamePeriod() {
        // Days 1, 2 and 5 logged: two missed days in between still count as one period.
        let days = periodDays("2026-03-01", through: "2026-03-02") + periodDays("2026-03-05", through: "2026-03-05")
        let cycles = CycleCalculationService.deriveCycles(from: days)

        #expect(cycles.count == 1)
        #expect(cycles[0].periodLength == 5)
    }

    @Test func bleedingSoonAfterAPeriodExtendsItInsteadOfStartingACycle() {
        // A gap longer than the tolerance, but still within a plausible period length.
        let days = periodDays("2026-03-01", through: "2026-03-02") + periodDays("2026-03-07", through: "2026-03-08")
        let cycles = CycleCalculationService.deriveCycles(from: days)

        #expect(cycles.count == 1)
        #expect(cycles[0].periodEndDate == day("2026-03-08"))
    }

    @Test func midCycleBleedingIsIgnored() {
        // Day 14 bleeding is too soon to be a new cycle and too late to be part of the period.
        let days = periodDays("2026-03-01", through: "2026-03-05") + periodDays("2026-03-14", through: "2026-03-14")
        let cycles = CycleCalculationService.deriveCycles(from: days)

        #expect(cycles.count == 1)
        #expect(cycles[0].periodLength == 5)
    }

    @Test func spottingOnlyNeverStartsACycle() {
        let days = periodDays("2026-03-01", through: "2026-03-05")
            + periodDays("2026-03-20", through: "2026-03-21", spotting: true)
        let cycles = CycleCalculationService.deriveCycles(from: days)

        #expect(cycles.count == 1)
    }

    @Test func cycleStartsOnFirstRealFlowDayAfterSpotting() {
        let days = periodDays("2026-03-01", through: "2026-03-02", spotting: true)
            + periodDays("2026-03-03", through: "2026-03-06")
        let cycles = CycleCalculationService.deriveCycles(from: days)

        #expect(cycles.count == 1)
        #expect(cycles[0].startDate == day("2026-03-03"))
        #expect(cycles[0].periodEndDate == day("2026-03-06"))
    }
}

struct PhaseTests {

    @Test func phaseBoundariesFollowOvulationDay() {
        // 28-day cycle, ovulation on day 15, 5-day period.
        let phase = { (cycleDay: Int) in
            CycleCalculationService.phase(cycleDay: cycleDay, periodLength: 5, ovulationDay: 15)
        }
        #expect(phase(1) == .menstrual)
        #expect(phase(5) == .menstrual)
        #expect(phase(6) == .follicular)
        #expect(phase(13) == .follicular)
        #expect(phase(14) == .ovulation)
        #expect(phase(16) == .ovulation)
        #expect(phase(17) == .luteal)
    }

    @Test func calendarPhaseMatchesOvulationDayPhase() {
        let start = day("2026-03-01")
        for offset in 0..<28 {
            let date = start.addingDays(offset)
            let calendarPhase = CycleCalculationService.phase(
                cycleStart: start, cycleLength: 28, periodLength: 5, lutealPhaseLength: 13, on: date
            )
            let direct = CycleCalculationService.phase(cycleDay: offset + 1, periodLength: 5, ovulationDay: 15)
            #expect(calendarPhase == direct)
        }
    }
}

@MainActor
struct OvulationEstimateTests {

    private func log(_ date: String, configure: (DailyLog) -> Void) -> DailyLog {
        let log = DailyLog(date: day(date))
        configure(log)
        return log
    }

    /// Six low readings followed by three high readings starting on `shiftDay`.
    private func bbtLogs(startingOn first: String, shiftAfter lowDays: Int) -> [DailyLog] {
        (0..<(lowDays + 3)).map { offset in
            let log = DailyLog(date: day(first).addingDays(offset))
            log.bbtTemperature = offset < lowDays ? 97.3 : 97.9
            return log
        }
    }

    @Test func bbtShiftConfirmsOvulationEvenWhenOPKIsLogged() {
        // Low temps Mar 8–15, rise Mar 16 → BBT ovulation Mar 15. Positive OPK Mar 14 → estimate Mar 15.
        var logs = bbtLogs(startingOn: "2026-03-08", shiftAfter: 8)
        logs.append(log("2026-03-14") { $0.opkResult = .positive })

        let result = CycleCalculationService.refineOvulationEstimate(
            cycleStart: day("2026-03-01"), cycleLength: 28, logs: logs
        )

        #expect(result.date == day("2026-03-15"))
        #expect(result.confirmed)
    }

    @Test func opkWinsWhenBBTShiftDisagreesWildly() {
        var logs = bbtLogs(startingOn: "2026-03-01", shiftAfter: 6) // "shift" on Mar 7, ovulation Mar 6
        logs.append(log("2026-03-20") { $0.opkResult = .positive })

        let result = CycleCalculationService.refineOvulationEstimate(
            cycleStart: day("2026-03-01"), cycleLength: 28, logs: logs
        )

        #expect(result.date == day("2026-03-21"))
        #expect(!result.confirmed)
    }

    @Test func calendarFallbackWithoutSignals() {
        let result = CycleCalculationService.refineOvulationEstimate(
            cycleStart: day("2026-03-01"), cycleLength: 28, lutealPhaseLength: 13, logs: []
        )
        #expect(result.date == day("2026-03-15"))
        #expect(!result.confirmed)
    }
}

struct CycleLengthStatisticsTests {

    @Test func outlierCycleIsIgnoredInAverage() {
        // A forgotten period shows up as one 56-day cycle.
        let lengths = [28, 29, 56, 27, 28]
        let typical = CycleCalculationService.typicalCycleLengths(lengths)
        #expect(!typical.contains(56))
        #expect(typical.count == 4)
    }

    @Test func fewCyclesAreNeverFiltered() {
        #expect(CycleCalculationService.typicalCycleLengths([28, 56]) == [28, 56])
    }
}
