import Foundation

/// Pure computation engine for cycle predictions. No UI coupling, no SwiftData dependency.
/// All methods are static and deterministic for easy testing.
nonisolated struct CycleCalculationService {

    // MARK: - Cycle Day & Phase

    /// Returns the 1-based day number within the current cycle.
    static func currentCycleDay(cycleStart: Date, on date: Date = .now) -> Int {
        max(1, cycleStart.startOfDay.daysBetween(date.startOfDay) + 1)
    }

    /// Determines which phase the given date falls in relative to the cycle.
    static func phase(
        cycleStart: Date,
        cycleLength: Int = BloomConstants.defaultCycleLength,
        periodLength: Int = BloomConstants.defaultPeriodLength,
        on date: Date = .now
    ) -> CyclePhase {
        let day = currentCycleDay(cycleStart: cycleStart, on: date)
        let ovulationDay = cycleLength - BloomConstants.defaultLutealPhaseLength

        if day <= periodLength {
            return .menstrual
        } else if day < ovulationDay - 1 {
            return .follicular
        } else if day <= ovulationDay + 1 {
            return .ovulation
        } else {
            return .luteal
        }
    }

    // MARK: - Fertility

    /// Returns the fertility level for a given date in the cycle.
    static func fertilityLevel(
        cycleStart: Date,
        cycleLength: Int = BloomConstants.defaultCycleLength,
        on date: Date = .now
    ) -> FertilityLevel {
        let ovulationDate = estimatedOvulationDate(cycleStart: cycleStart, cycleLength: cycleLength)
        let daysFromOvulation = date.startOfDay.daysBetween(ovulationDate)

        // daysFromOvulation is positive if ovulation is in the future
        // Fertile window: ovulation day and 5 days before
        switch daysFromOvulation {
        case 0...1:
            return .peak
        case 2...3:
            return .high
        case 4...5:
            return .high
        default:
            // Also check if we're just past ovulation (day after)
            if daysFromOvulation == -1 {
                return .high
            }
            return .low
        }
    }

    /// Returns true if the given date is within the fertile window.
    static func isInFertileWindow(
        cycleStart: Date,
        cycleLength: Int = BloomConstants.defaultCycleLength,
        on date: Date = .now
    ) -> Bool {
        let window = fertileWindowRange(
            ovulationDate: estimatedOvulationDate(cycleStart: cycleStart, cycleLength: cycleLength)
        )
        return window.contains(date.startOfDay)
    }

    // MARK: - Ovulation Estimation

    /// Basic calendar-based ovulation prediction: cycle start + (cycle length - luteal phase length).
    static func estimatedOvulationDate(
        cycleStart: Date,
        cycleLength: Int = BloomConstants.defaultCycleLength
    ) -> Date {
        let ovulationDay = cycleLength - BloomConstants.defaultLutealPhaseLength
        return cycleStart.startOfDay.addingDays(ovulationDay - 1) // -1 because day 1 = start date
    }

    /// Fertile window: 5 days before ovulation through ovulation day (6 days total).
    static func fertileWindowRange(ovulationDate: Date) -> ClosedRange<Date> {
        let start = ovulationDate.startOfDay.addingDays(-BloomConstants.fertileWindowDaysBefore)
        return start...ovulationDate.startOfDay
    }

    // MARK: - Predictions from History

    /// Predicts next period start date based on historical cycle data.
    static func predictNextPeriodStart(lastCycleStart: Date, averageCycleLength: Double) -> Date {
        lastCycleStart.startOfDay.addingDays(Int(round(averageCycleLength)))
    }

    /// Calculates the average cycle length from completed cycles.
    static func averageCycleLength(from cycles: [Cycle]) -> Double? {
        let completedLengths = cycles.compactMap { $0.cycleLength }
        guard !completedLengths.isEmpty else { return nil }
        return Double(completedLengths.reduce(0, +)) / Double(completedLengths.count)
    }

    /// Calculates the standard deviation of cycle lengths.
    static func cycleLengthStdDev(from cycles: [Cycle]) -> Double? {
        let completedLengths = cycles.compactMap { $0.cycleLength }
        guard completedLengths.count >= 2 else { return nil }
        let mean = Double(completedLengths.reduce(0, +)) / Double(completedLengths.count)
        let variance = completedLengths.map { pow(Double($0) - mean, 2) }.reduce(0, +) / Double(completedLengths.count)
        return sqrt(variance)
    }

    /// Describes cycle regularity based on standard deviation.
    static func regularityDescription(stdDev: Double) -> String {
        if stdDev <= 2.0 {
            return "Regular"
        } else if stdDev <= 4.0 {
            return "Somewhat Regular"
        } else {
            return "Irregular"
        }
    }

    // MARK: - BBT Ovulation Detection

    /// Detects ovulation from BBT data using the "3 over 6" rule.
    /// Returns the estimated ovulation date (day before the thermal shift).
    ///
    /// Rule: ovulation is confirmed when 3 consecutive temperature readings
    /// are at least 0.3°F above the average of the preceding 6 readings.
    static func detectOvulationFromBBT(logs: [DailyLog]) -> Date? {
        // Filter to logs with BBT data, sorted by date
        let bbtLogs = logs
            .filter { $0.bbtTemperature != nil }
            .sorted { $0.date < $1.date }

        let minRequired = BloomConstants.bbtBaselineDays + BloomConstants.bbtConfirmationDays
        guard bbtLogs.count >= minRequired else { return nil }

        for i in BloomConstants.bbtBaselineDays..<(bbtLogs.count - BloomConstants.bbtConfirmationDays + 1) {
            // Calculate baseline: average of preceding 6 readings
            let baselineTemps = bbtLogs[(i - BloomConstants.bbtBaselineDays)..<i]
                .compactMap { $0.bbtTemperature }
            guard baselineTemps.count == BloomConstants.bbtBaselineDays else { continue }

            let baseline = baselineTemps.reduce(0, +) / Double(baselineTemps.count)
            let threshold = baseline + BloomConstants.bbtShiftThreshold

            // Check if next 3 readings are all above threshold
            let confirmationTemps = bbtLogs[i..<(i + BloomConstants.bbtConfirmationDays)]
                .compactMap { $0.bbtTemperature }
            guard confirmationTemps.count == BloomConstants.bbtConfirmationDays else { continue }

            let allAboveThreshold = confirmationTemps.allSatisfy { $0 >= threshold }

            if allAboveThreshold {
                // Ovulation occurred on the day before the first elevated reading
                return bbtLogs[i - 1].date
            }
        }

        return nil
    }

    // MARK: - Refined Ovulation Estimate

    /// Combines multiple data sources to produce the best ovulation estimate.
    /// Priority: OPK positive (most actionable) > BBT shift (most reliable retrospectively) > calendar.
    static func refineOvulationEstimate(
        cycleStart: Date,
        cycleLength: Int,
        logs: [DailyLog]
    ) -> (date: Date, confirmed: Bool) {
        // 1. Check for OPK positive — ovulation expected next day
        let opkPositiveLogs = logs
            .filter { $0.opkResult == .positive }
            .sorted { $0.date < $1.date }

        if let firstPositive = opkPositiveLogs.first {
            return (firstPositive.date.addingDays(1), false)
        }

        // 2. Check BBT shift — retrospective confirmation
        if let bbtOvulation = detectOvulationFromBBT(logs: logs) {
            return (bbtOvulation, true)
        }

        // 3. Fall back to calendar
        return (estimatedOvulationDate(cycleStart: cycleStart, cycleLength: cycleLength), false)
    }

    // MARK: - Prediction Confidence

    /// Calculates a confidence score (0.0–1.0) for predictions based on available data.
    static func predictionConfidence(
        completedCycleCount: Int,
        hasOPKData: Bool,
        hasBBTData: Bool,
        hasMucusData: Bool,
        cycleLengthStdDev: Double?
    ) -> Double {
        var confidence = 0.21 // Calendar-only baseline

        // Regularity bonus
        if let stdDev = cycleLengthStdDev {
            let regularityBonus = max(0, 1.0 - stdDev / 10.0) * 0.30
            confidence += regularityBonus
        }

        // Data volume bonus
        if completedCycleCount >= BloomConstants.goodAccuracyCycleCount {
            confidence += 0.10
        } else if completedCycleCount >= BloomConstants.minimumCyclesForPrediction {
            confidence += 0.05
        }

        // Additional data source bonuses
        if hasOPKData { confidence += 0.25 }
        if hasBBTData { confidence += 0.15 }
        if hasMucusData { confidence += 0.10 }

        return min(confidence, 0.99)
    }

    // MARK: - Conception Score

    /// Calculates a conception score (0–100) for a cycle based on intercourse timing and data quality.
    static func conceptionScore(
        ovulationDate: Date,
        logs: [DailyLog],
        isOvulationConfirmed: Bool
    ) -> Int {
        var score = 0

        // Intercourse timing score (0-50)
        let intercourseLogs = logs.filter { $0.hadIntercourse }
        var bestTimingScore = 0

        for log in intercourseLogs {
            let daysFromOvulation = log.date.startOfDay.daysBetween(ovulationDate.startOfDay)
            let dayScore: Int
            switch daysFromOvulation {
            case -1: dayScore = 50   // Day before ovulation (highest probability)
            case 0: dayScore = 45    // Ovulation day
            case -2: dayScore = 40   // 2 days before
            case -3: dayScore = 30   // 3 days before
            case -4: dayScore = 20   // 4 days before
            case -5: dayScore = 10   // 5 days before
            default: dayScore = 0
            }
            bestTimingScore = max(bestTimingScore, dayScore)
        }
        score += bestTimingScore

        // Data quality score (0-30)
        let hasBBT = logs.contains { $0.bbtTemperature != nil }
        let hasMucus = logs.contains { $0.cervicalMucus != nil }
        let hasOPK = logs.contains { $0.opkResult != nil }
        if hasBBT { score += 10 }
        if hasMucus { score += 10 }
        if hasOPK { score += 10 }

        // Favorable signs score (0-20)
        if logs.contains(where: { $0.cervicalMucus == .eggWhite }) { score += 10 }
        if logs.contains(where: { $0.opkResult == .positive }) { score += 10 }

        return min(score, 100)
    }
}
