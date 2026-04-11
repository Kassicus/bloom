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
    var predictionConfidence: Double = 0.15

    // Luteal phase
    var effectiveLutealPhaseLength: Int = BloomConstants.defaultLutealPhaseLength

    // Conception
    var currentConceptionScore: Int?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func updatePredictions() {
        let today = Date.now.startOfDay

        let descriptor = FetchDescriptor<Cycle>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        guard let allCycles = try? modelContext.fetch(descriptor) else { return }

        currentCycle = allCycles.first

        let completedCycles = allCycles.filter { $0.cycleLength != nil }
        completedCycleCount = completedCycles.count
        avgCycleLength = CycleCalculationService.averageCycleLength(from: allCycles)
        cycleLengthStdDev = CycleCalculationService.cycleLengthStdDev(from: allCycles)

        // Learn personal luteal phase length from BBT-confirmed cycles
        effectiveLutealPhaseLength = CycleCalculationService.learnedLutealPhaseLength(from: allCycles)
            ?? BloomConstants.defaultLutealPhaseLength

        guard let cycle = currentCycle else {
            clearPredictions()
            return
        }

        let effectiveCycleLength = avgCycleLength.map { Int(round($0)) } ?? BloomConstants.defaultCycleLength
        let effectivePeriodLength = cycle.periodLength ?? BloomConstants.defaultPeriodLength

        currentCycleDay = CycleCalculationService.currentCycleDay(cycleStart: cycle.startDate, on: today)

        currentPhase = CycleCalculationService.phase(
            cycleStart: cycle.startDate,
            cycleLength: effectiveCycleLength,
            periodLength: effectivePeriodLength,
            lutealPhaseLength: effectiveLutealPhaseLength,
            on: today
        )

        // Ovulation — refine with available data BEFORE computing fertility level
        let logs = cycle.dailyLogs ?? []
        let refined = CycleCalculationService.refineOvulationEstimate(
            cycleStart: cycle.startDate,
            cycleLength: effectiveCycleLength,
            lutealPhaseLength: effectiveLutealPhaseLength,
            logs: logs
        )
        predictedOvulationDate = refined.date
        cycle.estimatedOvulationDate = refined.date
        cycle.isOvulationConfirmed = refined.confirmed

        currentFertileWindow = CycleCalculationService.fertileWindowRange(ovulationDate: refined.date)

        // Fertility level uses the refined ovulation date, boosted by today's real-time signals
        let baseFertility = CycleCalculationService.fertilityLevel(ovulationDate: refined.date, on: today)
        let todayLog = logs.first { $0.date.startOfDay == today }
        currentFertilityLevel = CycleCalculationService.adjustedFertilityLevel(base: baseFertility, log: todayLog)

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
        let hasBBTConfirmedOvulation = CycleCalculationService.detectOvulationFromBBT(logs: logs) != nil
        let hasMucus = logs.contains { $0.cervicalMucus != nil }

        predictionConfidence = CycleCalculationService.predictionConfidence(
            completedCycleCount: completedCycleCount,
            hasOPKData: hasOPK,
            hasBBTData: hasBBT,
            hasBBTConfirmedOvulation: hasBBTConfirmedOvulation,
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
        predictionConfidence = 0.15
    }
}
