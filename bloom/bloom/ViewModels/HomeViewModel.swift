import Foundation
import Observation

@Observable
final class HomeViewModel {
    let predictionService: PredictionService

    init(predictionService: PredictionService) {
        self.predictionService = predictionService
    }

    func refresh() {
        predictionService.updatePredictions()
    }

    /// Today's log, fetched fresh each time so edits from other tabs show up.
    var todayLog: DailyLog? {
        predictionService.cycleManager.log(for: .now)
    }

    // MARK: - Display Properties

    var cycleDayText: String {
        guard let day = predictionService.currentCycleDay else { return "No cycle logged" }
        return "Cycle Day \(day)"
    }

    var phaseText: String {
        predictionService.currentPhase?.label ?? "—"
    }

    var phaseDescription: String {
        predictionService.currentPhase?.description ?? "Log a period to start tracking"
    }

    var fertilityLevel: FertilityLevel? {
        predictionService.currentFertilityLevel
    }

    var recommendationText: String {
        guard let level = predictionService.currentFertilityLevel else {
            return "Log your period to get started"
        }

        if let late = predictionService.daysPeriodLate {
            return "Your period is \(late) day\(late == 1 ? "" : "s") later than expected. If you've been trying to conceive, this could be a good time to take a pregnancy test."
        }

        switch level {
        case .peak:
            return "Peak fertility \u{2014} intercourse today or tomorrow has the highest chance of conception (~20-31% per cycle)"
        case .high:
            return "You are in your fertile window. Sperm can survive up to 5 days in fertile mucus, so intercourse now can lead to conception when ovulation occurs"
        case .low:
            if let daysUntil = predictionService.daysUntilFertileWindow, daysUntil > 0 {
                if daysUntil <= 5 {
                    return "Fertile window starts in \(daysUntil) day\(daysUntil == 1 ? "" : "s") \u{2014} consider starting OPK testing to pinpoint your LH surge"
                }
                return "Fertile window starts in \(daysUntil) day\(daysUntil == 1 ? "" : "s")"
            }
            return "Outside the fertile window \u{2014} the egg is viable for only 12-24 hours after ovulation"
        }
    }

    var nextPeriodCountdown: String? {
        if let late = predictionService.daysPeriodLate {
            return "\(late) day\(late == 1 ? "" : "s") late"
        }
        guard let days = predictionService.daysUntilNextPeriod else { return nil }
        if days == 0 { return "Today" }
        return "\(days) day\(days == 1 ? "" : "s")"
    }

    var fertileWindowCountdown: String? {
        guard let days = predictionService.daysUntilFertileWindow else { return nil }
        if days == 0 { return "Now" }
        return "\(days) day\(days == 1 ? "" : "s")"
    }

    var hasCycleData: Bool {
        predictionService.currentCycle != nil
    }

    var confidenceText: String {
        let pct = Int(predictionService.predictionConfidence * 100)
        return "\(pct)%"
    }

    // MARK: - Today's Log Summary

    var todayHasData: Bool {
        guard let log = todayLog else { return false }
        return log.isOnPeriod
            || log.bbtTemperature != nil
            || log.cervicalMucus != nil
            || log.opkResult != nil
            || !log.symptoms.isEmpty
            || log.hadIntercourse
    }

    func todayLoggedItems(unit: TemperatureUnit) -> [String] {
        guard let log = todayLog else { return [] }
        var items: [String] = []
        if log.isOnPeriod { items.append("Period") }
        if let temp = log.bbtTemperature { items.append(unit.format(temp) + unit.symbol) }
        if let mucus = log.cervicalMucus { items.append(mucus.label) }
        if let opk = log.opkResult { items.append("OPK: \(opk.label)") }
        if !log.symptoms.isEmpty { items.append("\(log.symptoms.count) symptom\(log.symptoms.count == 1 ? "" : "s")") }
        if !(log.intercourseEntries ?? []).isEmpty {
            let count = (log.intercourseEntries ?? []).count
            items.append(count == 1 ? "Intercourse" : "\(count)x Intercourse")
        }
        return items
    }

    // MARK: - Conception Score

    var conceptionScore: Int? {
        predictionService.currentConceptionScore?.total
    }

    var isInFertileWindow: Bool {
        guard let window = predictionService.currentFertileWindow else { return false }
        return window.contains(Date.now.startOfDay)
    }

    /// Breakdown of the conception score into its three components.
    var conceptionScoreBreakdown: ConceptionScoreBreakdown {
        predictionService.currentConceptionScore ?? ConceptionScoreBreakdown()
    }

    /// Description of the best-timed intercourse day and its estimated probability.
    var bestTimingDescription: String? {
        let breakdown = conceptionScoreBreakdown
        guard let days = breakdown.bestTimingDaysBeforeOvulation,
              let prob = CycleCalculationService.estimatedConceptionProbability(forTimingScore: breakdown.timing) else {
            return nil
        }
        return "Best timing: \(CycleCalculationService.timingDayLabel(daysBeforeOvulation: days)) (\(prob) per-cycle probability)"
    }

    // MARK: - Cycle Ring Data

    /// Days shown around the ring: the expected cycle length, stretched if the cycle runs long.
    private var ringLength: Int {
        max(predictionService.effectiveCycleLength, predictionService.currentCycleDay ?? 0)
    }

    /// Returns phase segments as (phase, startFraction, endFraction) for the cycle ring.
    /// Cycle day `d` occupies the arc from (d-1)/length to d/length, matching how phases are
    /// assigned to days everywhere else.
    var cycleRingSegments: [(phase: CyclePhase, start: Double, end: Double)] {
        guard let cycle = predictionService.currentCycle else { return [] }

        let length = Double(ringLength)
        let periodEnd = Double(predictionService.currentPeriodLength)
        let ovulationDay = Double(predictionService.predictedOvulationDate.map {
            CycleCalculationService.ovulationDay(cycleStart: cycle.startDate, ovulationDate: $0)
        } ?? (predictionService.effectiveCycleLength - predictionService.effectiveLutealPhaseLength))

        // Ovulation phase covers days ovulationDay-1 ... ovulationDay+1.
        let ovulationStart = max(periodEnd, ovulationDay - 2)
        let ovulationEnd = max(periodEnd, ovulationDay + 1)

        func fraction(_ days: Double) -> Double { min(max(days / length, 0), 1) }

        return [
            (.menstrual, 0, fraction(periodEnd)),
            (.follicular, fraction(periodEnd), fraction(ovulationStart)),
            (.ovulation, fraction(ovulationStart), fraction(ovulationEnd)),
            (.luteal, fraction(ovulationEnd), 1.0),
        ].filter { $0.end > $0.start }
    }

    /// Position of today's marker: the middle of today's arc.
    var cycleProgress: Double {
        guard let day = predictionService.currentCycleDay else { return 0 }
        return min((Double(day) - 0.5) / Double(ringLength), 1)
    }
}
