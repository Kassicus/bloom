import Foundation
import SwiftData
import Observation

@Observable
final class PredictionService {
    private let modelContext: ModelContext

    // Current cycle state
    var currentCycle: Cycle?
    var currentCycleDay: Int?
    var currentPhase: CyclePhase?
    var currentFertilityLevel: FertilityLevel?

    // Predictions
    var predictedNextPeriodStart: Date?
    var predictedOvulationDate: Date?
    var currentFertileWindow: ClosedRange<Date>?

    // Countdowns
    var daysUntilNextPeriod: Int?
    var daysUntilFertileWindow: Int?

    // Statistics
    var avgCycleLength: Double?
    var cycleLengthStdDev: Double?
    var completedCycleCount: Int = 0
    var predictionConfidence: Double = 0.21

    // Conception
    var currentConceptionScore: Int?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func updatePredictions() {
        let today = Date.now.startOfDay

        // Fetch all cycles sorted by start date
        let descriptor = FetchDescriptor<Cycle>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        guard let allCycles = try? modelContext.fetch(descriptor) else { return }

        // Current cycle is the most recent
        currentCycle = allCycles.first

        // Calculate statistics from completed cycles (those with a known cycle length)
        let completedCycles = allCycles.filter { $0.cycleLength != nil }
        completedCycleCount = completedCycles.count
        avgCycleLength = CycleCalculationService.averageCycleLength(from: allCycles)
        cycleLengthStdDev = CycleCalculationService.cycleLengthStdDev(from: allCycles)

        guard let cycle = currentCycle else {
            clearPredictions()
            return
        }

        let effectiveCycleLength = avgCycleLength.map { Int(round($0)) } ?? BloomConstants.defaultCycleLength
        let effectivePeriodLength = cycle.periodLength ?? BloomConstants.defaultPeriodLength

        // Current cycle day
        currentCycleDay = CycleCalculationService.currentCycleDay(cycleStart: cycle.startDate, on: today)

        // Phase and fertility
        currentPhase = CycleCalculationService.phase(
            cycleStart: cycle.startDate,
            cycleLength: effectiveCycleLength,
            periodLength: effectivePeriodLength,
            on: today
        )
        currentFertilityLevel = CycleCalculationService.fertilityLevel(
            cycleStart: cycle.startDate,
            cycleLength: effectiveCycleLength,
            on: today
        )

        // Ovulation — refine with available data
        let logs = cycle.dailyLogs
        let refined = CycleCalculationService.refineOvulationEstimate(
            cycleStart: cycle.startDate,
            cycleLength: effectiveCycleLength,
            logs: logs
        )
        predictedOvulationDate = refined.date
        cycle.estimatedOvulationDate = refined.date
        cycle.isOvulationConfirmed = refined.confirmed

        // Fertile window
        currentFertileWindow = CycleCalculationService.fertileWindowRange(ovulationDate: refined.date)

        // Next period
        if let avg = avgCycleLength {
            predictedNextPeriodStart = CycleCalculationService.predictNextPeriodStart(
                lastCycleStart: cycle.startDate,
                averageCycleLength: avg
            )
        } else {
            predictedNextPeriodStart = cycle.startDate.addingDays(BloomConstants.defaultCycleLength)
        }

        // Countdowns
        if let nextPeriod = predictedNextPeriodStart {
            let days = today.daysBetween(nextPeriod)
            daysUntilNextPeriod = days >= 0 ? days : nil
        }

        if let window = currentFertileWindow {
            let daysToStart = today.daysBetween(window.lowerBound)
            daysUntilFertileWindow = daysToStart > 0 ? daysToStart : (today <= window.upperBound ? 0 : nil)
        }

        // Prediction confidence
        let hasOPK = logs.contains { $0.opkResult == .positive }
        let hasBBT = logs.filter({ $0.bbtTemperature != nil }).count >= 10
        let hasMucus = logs.contains { $0.cervicalMucus != nil }

        predictionConfidence = CycleCalculationService.predictionConfidence(
            completedCycleCount: completedCycleCount,
            hasOPKData: hasOPK,
            hasBBTData: hasBBT,
            hasMucusData: hasMucus,
            cycleLengthStdDev: cycleLengthStdDev
        )

        // Conception score
        if let ovDate = predictedOvulationDate {
            currentConceptionScore = CycleCalculationService.conceptionScore(
                ovulationDate: ovDate,
                logs: logs,
                isOvulationConfirmed: cycle.isOvulationConfirmed
            )
        }
    }

    private func clearPredictions() {
        currentCycleDay = nil
        currentPhase = nil
        currentFertilityLevel = nil
        predictedNextPeriodStart = nil
        predictedOvulationDate = nil
        currentFertileWindow = nil
        daysUntilNextPeriod = nil
        daysUntilFertileWindow = nil
        currentConceptionScore = nil
        predictionConfidence = 0.21
    }
}
