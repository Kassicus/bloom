import Foundation
import SwiftData
import Observation

@Observable
final class InsightsViewModel {
    private let modelContext: ModelContext
    private let predictionService: PredictionService

    // Cycle statistics
    var averageCycleLength: Double?
    var averagePeriodLength: Double?
    var cycleLengthRange: ClosedRange<Int>?
    var cycleLengthStdDev: Double?
    var regularityDescription: String = "—"
    var completedCycleCount: Int = 0
    var confidencePercent: Int = 0

    // BBT chart data
    var bbtDataPoints: [BBTDataPoint] = []
    var coverlineTemp: Double?
    var detectedOvulationDate: Date?
    var fertileWindowStart: Date?
    var fertileWindowEnd: Date?

    // Conception score
    var conceptionScore: Int?
    var conceptionTimingScore: Int = 0
    var conceptionDataQualityScore: Int = 0
    var conceptionFavorableSignsScore: Int = 0

    // Cycle history
    var cycleHistory: [CycleSummary] = []

    // Selected cycle for chart
    var selectedCycleIndex: Int = 0

    init(modelContext: ModelContext, predictionService: PredictionService) {
        self.modelContext = modelContext
        self.predictionService = predictionService
    }

    func refresh() {
        predictionService.updatePredictions()
        selectedCycleIndex = min(selectedCycleIndex, max(availableCycles.count - 1, 0))
        loadStatistics()
        loadBBTData()
        loadCycleHistory()
        loadConceptionScore()
    }

    // MARK: - Available Cycles for Chart Picker

    /// Most recent first.
    var availableCycles: [Cycle] {
        predictionService.cycles.reversed()
    }

    var selectedCycle: Cycle? {
        let cycles = availableCycles
        guard selectedCycleIndex < cycles.count else { return nil }
        return cycles[selectedCycleIndex]
    }

    var selectedCycleLabel: String {
        guard let cycle = selectedCycle else { return "No Cycle" }
        if cycle === predictionService.currentCycle {
            return "Current Cycle"
        }
        return cycle.startDate.shortFormatted
    }

    func selectPreviousCycle() {
        let max = availableCycles.count - 1
        if selectedCycleIndex < max {
            selectedCycleIndex += 1
            loadBBTData()
        }
    }

    func selectNextCycle() {
        if selectedCycleIndex > 0 {
            selectedCycleIndex -= 1
            loadBBTData()
        }
    }

    var canSelectPrevious: Bool {
        selectedCycleIndex < availableCycles.count - 1
    }

    var canSelectNext: Bool {
        selectedCycleIndex > 0
    }

    // MARK: - Statistics

    private func loadStatistics() {
        let descriptor = FetchDescriptor<Cycle>(sortBy: [SortDescriptor(\.startDate, order: .forward)])
        guard let allCycles = try? modelContext.fetch(descriptor) else { return }

        let completed = allCycles.filter { $0.cycleLength != nil }
        completedCycleCount = completed.count

        averageCycleLength = CycleCalculationService.averageCycleLength(from: allCycles)
        cycleLengthStdDev = CycleCalculationService.cycleLengthStdDev(from: allCycles)

        if let stdDev = cycleLengthStdDev {
            regularityDescription = CycleCalculationService.regularityDescription(stdDev: stdDev)
        } else {
            regularityDescription = "—"
        }

        let lengths = completed.compactMap { $0.cycleLength }
        if let shortest = lengths.min(), let longest = lengths.max() {
            cycleLengthRange = shortest...longest
        } else {
            cycleLengthRange = nil
        }

        let periodLengths = allCycles.compactMap { $0.periodLength }
        averagePeriodLength = periodLengths.isEmpty
            ? nil
            : Double(periodLengths.reduce(0, +)) / Double(periodLengths.count)

        confidencePercent = Int(predictionService.predictionConfidence * 100)
    }

    // MARK: - BBT Chart

    private func loadBBTData() {
        guard let cycle = selectedCycle else {
            bbtDataPoints = []
            coverlineTemp = nil
            detectedOvulationDate = nil
            fertileWindowStart = nil
            fertileWindowEnd = nil
            return
        }

        let logs = (cycle.dailyLogs ?? [])
            .filter { $0.bbtTemperature != nil }
            .sorted { $0.date < $1.date }

        bbtDataPoints = logs.map { log in
            let day = CycleCalculationService.currentCycleDay(cycleStart: cycle.startDate, on: log.date)
            return BBTDataPoint(
                date: log.date,
                cycleDay: day,
                temperature: log.bbtTemperature!
            )
        }

        // Detect ovulation from BBT
        detectedOvulationDate = CycleCalculationService.detectOvulationFromBBT(logs: cycle.dailyLogs ?? [])

        // Calculate coverline: average of pre-ovulation temps + buffer
        if let ovDate = detectedOvulationDate ?? cycle.estimatedOvulationDate {
            let preOvTemps = logs
                .filter { $0.date < ovDate }
                .compactMap { $0.bbtTemperature }

            coverlineTemp = preOvTemps.isEmpty
                ? nil
                : preOvTemps.reduce(0, +) / Double(preOvTemps.count) + BloomConstants.bbtShiftThreshold

            // Fertile window
            let window = CycleCalculationService.fertileWindowRange(ovulationDate: ovDate)
            fertileWindowStart = window.lowerBound
            fertileWindowEnd = window.upperBound
        } else {
            coverlineTemp = nil
            fertileWindowStart = nil
            fertileWindowEnd = nil
        }
    }

    // MARK: - Cycle History

    private func loadCycleHistory() {
        let descriptor = FetchDescriptor<Cycle>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        guard let allCycles = try? modelContext.fetch(descriptor) else { return }

        cycleHistory = allCycles.map { cycle in
            let logs = cycle.dailyLogs ?? []
            let hasOPK = logs.contains { $0.opkResult == .positive }
            let hasBBT = logs.filter({ $0.bbtTemperature != nil }).count >= 5
            let intercourseCount = logs.reduce(0) { $0 + ($1.intercourseEntries ?? []).count }

            return CycleSummary(
                startDate: cycle.startDate,
                cycleLength: cycle.cycleLength,
                periodLength: cycle.periodLength,
                isOvulationConfirmed: cycle.isOvulationConfirmed,
                hasOPKData: hasOPK,
                hasBBTData: hasBBT,
                intercourseCount: intercourseCount,
                isCurrent: cycle === predictionService.currentCycle
            )
        }
    }

    // MARK: - Conception Score

    private func loadConceptionScore() {
        guard let breakdown = predictionService.currentConceptionScore else {
            conceptionScore = nil
            conceptionTimingScore = 0
            conceptionDataQualityScore = 0
            conceptionFavorableSignsScore = 0
            return
        }

        conceptionTimingScore = breakdown.timing
        conceptionDataQualityScore = breakdown.dataQuality
        conceptionFavorableSignsScore = breakdown.favorableSigns
        conceptionScore = breakdown.total
    }
}

// MARK: - Supporting Types

struct BBTDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let cycleDay: Int
    let temperature: Double
}

struct CycleSummary: Identifiable {
    let id = UUID()
    let startDate: Date
    let cycleLength: Int?
    let periodLength: Int?
    let isOvulationConfirmed: Bool
    let hasOPKData: Bool
    let hasBBTData: Bool
    let intercourseCount: Int
    let isCurrent: Bool

    var lengthText: String {
        if let length = cycleLength { return "\(length) days" }
        return "In progress"
    }

    var periodText: String {
        if let length = periodLength { return "\(length) days" }
        return "—"
    }
}
