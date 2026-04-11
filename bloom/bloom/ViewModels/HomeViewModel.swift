import Foundation
import SwiftData
import Observation

@Observable
final class HomeViewModel {
    private let modelContext: ModelContext
    let predictionService: PredictionService

    var todayLog: DailyLog?

    init(modelContext: ModelContext, predictionService: PredictionService) {
        self.modelContext = modelContext
        self.predictionService = predictionService
    }

    func refresh() {
        predictionService.updatePredictions()
        loadTodayLog()
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
        return log.bbtTemperature != nil
            || log.cervicalMucus != nil
            || log.opkResult != nil
            || !log.symptoms.isEmpty
            || log.hadIntercourse
    }

    var todayLoggedItems: [String] {
        guard let log = todayLog else { return [] }
        var items: [String] = []
        if log.isOnPeriod { items.append("Period") }
        if let temp = log.bbtTemperature { items.append(String(format: "%.1f\u{00B0}F", temp)) }
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
        predictionService.currentConceptionScore
    }

    var isInFertileWindow: Bool {
        guard let window = predictionService.currentFertileWindow else { return false }
        return window.contains(Date.now.startOfDay)
    }

    /// Breakdown of the conception score into its three components.
    var conceptionScoreBreakdown: (timing: Int, dataQuality: Int, favorableSigns: Int) {
        guard let cycle = predictionService.currentCycle,
              let ovDate = predictionService.predictedOvulationDate else {
            return (0, 0, 0)
        }

        let logs = cycle.dailyLogs ?? []

        // Timing (0-50) — uses shared scoring aligned with published probabilities
        var bestTiming = 0
        for log in logs where log.hadIntercourse {
            let daysBeforeOv = log.date.startOfDay.daysBetween(ovDate.startOfDay)
            bestTiming = max(bestTiming, CycleCalculationService.timingScore(daysBeforeOvulation: daysBeforeOv))
        }

        // Data quality (0-30)
        var dq = 0
        if logs.contains(where: { $0.bbtTemperature != nil }) { dq += 10 }
        if logs.contains(where: { $0.cervicalMucus != nil }) { dq += 10 }
        if logs.contains(where: { $0.opkResult != nil }) { dq += 10 }

        // Favorable signs (0-20)
        var fs = 0
        if logs.contains(where: { $0.cervicalMucus == .eggWhite }) { fs += 10 }
        if logs.contains(where: { $0.opkResult == .positive }) { fs += 10 }

        return (bestTiming, dq, fs)
    }

    /// Description of the best-timed intercourse day and its estimated probability.
    var bestTimingDescription: String? {
        guard let cycle = predictionService.currentCycle,
              let ovDate = predictionService.predictedOvulationDate else { return nil }

        var bestScore = 0
        var bestDays = 0
        for log in (cycle.dailyLogs ?? []) where log.hadIntercourse {
            let d = log.date.startOfDay.daysBetween(ovDate.startOfDay)
            let s = CycleCalculationService.timingScore(daysBeforeOvulation: d)
            if s > bestScore { bestScore = s; bestDays = d }
        }

        guard bestScore > 0,
              let prob = CycleCalculationService.estimatedConceptionProbability(forTimingScore: bestScore) else {
            return nil
        }

        return "Best timing: \(CycleCalculationService.timingDayLabel(daysBeforeOvulation: bestDays)) (\(prob) per-cycle probability)"
    }

    // MARK: - Cycle Ring Data

    /// Returns phase segments as (phase, startFraction, endFraction) for the cycle ring.
    var cycleRingSegments: [(phase: CyclePhase, start: Double, end: Double)] {
        guard hasCycleData else { return [] }

        let cycleLength = Double(effectiveCycleLength)
        let periodLength = Double(predictionService.currentCycle?.periodLength ?? BloomConstants.defaultPeriodLength)
        let ovulationDay = Double(effectiveCycleLength - predictionService.effectiveLutealPhaseLength)

        return [
            (.menstrual, 0, periodLength / cycleLength),
            (.follicular, periodLength / cycleLength, (ovulationDay - 1) / cycleLength),
            (.ovulation, (ovulationDay - 1) / cycleLength, (ovulationDay + 2) / cycleLength),
            (.luteal, (ovulationDay + 2) / cycleLength, 1.0),
        ]
    }

    var cycleProgress: Double {
        guard let day = predictionService.currentCycleDay else { return 0 }
        return Double(day) / Double(effectiveCycleLength)
    }

    var effectiveCycleLength: Int {
        if let avg = predictionService.avgCycleLength { return Int(round(avg)) }
        return predictionService.currentCycle?.cycleLength ?? BloomConstants.defaultCycleLength
    }

    // MARK: - Private

    private func loadTodayLog() {
        let today = Date.now.startOfDay
        let tomorrow = today.addingDays(1)
        var descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow }
        )
        descriptor.fetchLimit = 1
        todayLog = try? modelContext.fetch(descriptor).first
    }
}
