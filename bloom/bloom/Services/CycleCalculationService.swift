import Foundation

/// Pure computation engine for cycle predictions. No UI coupling, no SwiftData dependency.
/// All methods are static and deterministic for easy testing.
///
/// Scientific references:
/// - Fertile window: Wilcox et al., NEJM 1995; 333:1517-1521
/// - Conception probabilities: Dunson et al., Human Reproduction 2002; 17(5):1399-1403
/// - Luteal phase length: Lenton et al., BJOG 1984; 91:681-684 (mean ~12.4 days, range 10-16)
/// - BBT "3 over 6" rule: Fertility awareness-based methods, WHO 2004
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
        lutealPhaseLength: Int = BloomConstants.defaultLutealPhaseLength,
        on date: Date = .now
    ) -> CyclePhase {
        let day = currentCycleDay(cycleStart: cycleStart, on: date)
        let ovulationDay = cycleLength - lutealPhaseLength

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

    /// Returns the fertility level for a given date in the cycle using calendar-based ovulation.
    ///
    /// `daysBeforeOvulation` (positive = ovulation is in the future):
    /// - 0-1: Peak (~20-31% per-cycle conception probability)
    /// - 2-3: High (~14-27%)
    /// - 4-5: Low (~3-11%)
    /// - Negative (post-ovulation): Low (egg viable only 12-24 hours)
    static func fertilityLevel(
        cycleStart: Date,
        cycleLength: Int = BloomConstants.defaultCycleLength,
        lutealPhaseLength: Int = BloomConstants.defaultLutealPhaseLength,
        on date: Date = .now
    ) -> FertilityLevel {
        let ovulationDate = estimatedOvulationDate(
            cycleStart: cycleStart,
            cycleLength: cycleLength,
            lutealPhaseLength: lutealPhaseLength
        )
        return fertilityLevel(ovulationDate: ovulationDate, on: date)
    }

    /// Returns the fertility level relative to a known or refined ovulation date.
    static func fertilityLevel(ovulationDate: Date, on date: Date = .now) -> FertilityLevel {
        // Positive = ovulation is in the future (date is before ovulation)
        let daysBeforeOvulation = date.startOfDay.daysBetween(ovulationDate)

        switch daysBeforeOvulation {
        case 0...1:
            return .peak   // Ovulation day and day before
        case 2...3:
            return .high   // Inner fertile window
        case 4...5:
            return .low    // Outer fertile window — possible but unlikely
        default:
            return .low    // Post-ovulation or far pre-ovulation
        }
    }

    /// Returns true if the given date is within the fertile window.
    static func isInFertileWindow(
        cycleStart: Date,
        cycleLength: Int = BloomConstants.defaultCycleLength,
        lutealPhaseLength: Int = BloomConstants.defaultLutealPhaseLength,
        on date: Date = .now
    ) -> Bool {
        let window = fertileWindowRange(
            ovulationDate: estimatedOvulationDate(
                cycleStart: cycleStart,
                cycleLength: cycleLength,
                lutealPhaseLength: lutealPhaseLength
            )
        )
        return window.contains(date.startOfDay)
    }

    /// Adjusts the base fertility level upward when today's logged data contains strong
    /// real-time indicators. Never lowers the level — only boosts.
    ///
    /// - OPK positive: at least `.peak` (ovulation imminent)
    /// - OPK near-positive or egg white mucus: at least `.high` (fertile window likely)
    /// - Watery mucus: at least `.high` if base is `.low` (approaching peak)
    static func adjustedFertilityLevel(base: FertilityLevel, log: DailyLog?) -> FertilityLevel {
        guard let log else { return base }

        // OPK positive overrides to peak
        if log.opkResult == .positive {
            return .peak
        }

        // Strong fertility signals boost to at least high (never lower peak to high)
        if log.opkResult == .nearPositive || log.cervicalMucus == .eggWhite || log.cervicalMucus == .watery {
            return base == .peak ? .peak : .high
        }

        return base
    }

    // MARK: - Ovulation Estimation

    /// Calendar-based ovulation prediction: cycle start + (cycle length - luteal phase length).
    ///
    /// The luteal phase (post-ovulation) is more consistent than the follicular phase,
    /// so counting backward from the expected next period is more reliable than counting
    /// forward from the period start.
    static func estimatedOvulationDate(
        cycleStart: Date,
        cycleLength: Int = BloomConstants.defaultCycleLength,
        lutealPhaseLength: Int = BloomConstants.defaultLutealPhaseLength
    ) -> Date {
        let ovulationDay = cycleLength - lutealPhaseLength
        return cycleStart.startOfDay.addingDays(ovulationDay - 1) // -1 because day 1 = start date
    }

    /// Fertile window: 5 days before ovulation through ovulation day (6 days total).
    ///
    /// Sperm can survive up to 5 days in fertile cervical mucus.
    /// The egg is viable for only 12-24 hours after release.
    static func fertileWindowRange(ovulationDate: Date) -> ClosedRange<Date> {
        let start = ovulationDate.startOfDay.addingDays(-BloomConstants.fertileWindowDaysBefore)
        return start...ovulationDate.startOfDay
    }

    // MARK: - Predictions from History

    /// Predicts next period start date based on historical cycle data.
    static func predictNextPeriodStart(lastCycleStart: Date, averageCycleLength: Double) -> Date {
        lastCycleStart.startOfDay.addingDays(Int(round(averageCycleLength)))
    }

    /// Calculates a weighted average cycle length from completed cycles.
    /// Recent cycles are weighted more heavily since cycle length can drift with age,
    /// stress, and health changes. Uses exponential decay: most recent cycle gets weight 1.0,
    /// each older cycle is multiplied by 0.7. Falls back to simple mean with < 3 cycles.
    static func averageCycleLength(from cycles: [Cycle]) -> Double? {
        let completedCycles = cycles
            .filter { $0.cycleLength != nil }
            .sorted { $0.startDate > $1.startDate } // Most recent first
        let lengths = completedCycles.compactMap { $0.cycleLength }
        guard !lengths.isEmpty else { return nil }

        // Simple mean when insufficient data for meaningful weighting
        guard lengths.count >= 3 else {
            return Double(lengths.reduce(0, +)) / Double(lengths.count)
        }

        let decay = 0.7
        var weightedSum = 0.0
        var totalWeight = 0.0

        for (index, length) in lengths.enumerated() {
            let weight = pow(decay, Double(index))
            weightedSum += Double(length) * weight
            totalWeight += weight
        }

        return weightedSum / totalWeight
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

    // MARK: - Luteal Phase Learning

    /// Calculates the user's personal luteal phase length from cycles where ovulation was
    /// confirmed via BBT shift. Returns nil if insufficient confirmed data.
    static func learnedLutealPhaseLength(from cycles: [Cycle]) -> Int? {
        let validLengths = cycles.compactMap { cycle -> Int? in
            guard cycle.isOvulationConfirmed,
                  let cycleLength = cycle.cycleLength,
                  let ovDate = cycle.estimatedOvulationDate else { return nil }

            let ovDay = cycle.startDate.daysBetween(ovDate) + 1
            let lutealLength = cycleLength - ovDay
            guard lutealLength >= BloomConstants.minLutealPhaseLength,
                  lutealLength <= BloomConstants.maxLutealPhaseLength else { return nil }
            return lutealLength
        }

        guard validLengths.count >= BloomConstants.minimumCyclesForLutealLearning else { return nil }
        let mean = Double(validLengths.reduce(0, +)) / Double(validLengths.count)
        return Int(round(mean))
    }

    // MARK: - BBT Ovulation Detection

    /// Detects ovulation from BBT data using the "3 over 6" rule.
    /// Returns the estimated ovulation date (day before the thermal shift).
    ///
    /// Rule: ovulation is confirmed when 3 consecutive temperature readings
    /// are at least 0.3°F above the average of the preceding 6 readings.
    static func detectOvulationFromBBT(logs: [DailyLog]) -> Date? {
        let bbtLogs = logs
            .filter { $0.bbtTemperature != nil }
            .sorted { $0.date < $1.date }

        let minRequired = BloomConstants.bbtBaselineDays + BloomConstants.bbtConfirmationDays
        guard bbtLogs.count >= minRequired else { return nil }

        for i in BloomConstants.bbtBaselineDays..<(bbtLogs.count - BloomConstants.bbtConfirmationDays + 1) {
            let baselineTemps = bbtLogs[(i - BloomConstants.bbtBaselineDays)..<i]
                .compactMap { $0.bbtTemperature }
            guard baselineTemps.count == BloomConstants.bbtBaselineDays else { continue }

            let baseline = baselineTemps.reduce(0, +) / Double(baselineTemps.count)
            let threshold = baseline + BloomConstants.bbtShiftThreshold

            let confirmationTemps = bbtLogs[i..<(i + BloomConstants.bbtConfirmationDays)]
                .compactMap { $0.bbtTemperature }
            guard confirmationTemps.count == BloomConstants.bbtConfirmationDays else { continue }

            if confirmationTemps.allSatisfy({ $0 >= threshold }) {
                return bbtLogs[i - 1].date
            }
        }

        return nil
    }

    // MARK: - Refined Ovulation Estimate

    /// Combines multiple data sources to produce the best ovulation estimate.
    /// Priority: OPK positive > OPK near-positive > BBT shift > EWCM peak > calendar.
    static func refineOvulationEstimate(
        cycleStart: Date,
        cycleLength: Int,
        lutealPhaseLength: Int = BloomConstants.defaultLutealPhaseLength,
        logs: [DailyLog]
    ) -> (date: Date, confirmed: Bool) {
        // 1. OPK positive — ovulation expected in ~24-48 hours (use +1 day as estimate)
        let opkPositiveLogs = logs
            .filter { $0.opkResult == .positive }
            .sorted { $0.date < $1.date }

        if let firstPositive = opkPositiveLogs.first {
            return (firstPositive.date.addingDays(1), false)
        }

        // 2. OPK near-positive — LH is rising, ovulation likely in ~2-3 days
        let opkNearPositiveLogs = logs
            .filter { $0.opkResult == .nearPositive }
            .sorted { $0.date < $1.date }

        if let firstNearPositive = opkNearPositiveLogs.first {
            return (firstNearPositive.date.addingDays(2), false)
        }

        // 3. BBT shift — retrospective confirmation (most accurate)
        if let bbtOvulation = detectOvulationFromBBT(logs: logs) {
            return (bbtOvulation, true)
        }

        // 4. Egg white cervical mucus — typically appears 1-2 days before ovulation
        let ewcmLogs = logs
            .filter { $0.cervicalMucus == .eggWhite }
            .sorted { $0.date < $1.date }

        if let firstEWCM = ewcmLogs.first {
            return (firstEWCM.date.addingDays(1), false)
        }

        // 5. Fall back to calendar-based estimate
        return (estimatedOvulationDate(cycleStart: cycleStart, cycleLength: cycleLength, lutealPhaseLength: lutealPhaseLength), false)
    }

    // MARK: - Prediction Confidence

    /// Calculates a confidence score (0.0–1.0) for predictions based on available data.
    ///
    /// Weights reflect each data source's predictive value:
    /// - OPK: highest (+0.25) — directly predicts ovulation 24-48h in advance
    /// - BBT confirmed: moderate (+0.15) — confirms ovulation, improves future predictions
    /// - BBT data only: low (+0.05) — retrospective, doesn't predict current cycle
    /// - Cervical mucus: moderate (+0.10) — real-time fertility indicator
    static func predictionConfidence(
        completedCycleCount: Int,
        hasOPKData: Bool,
        hasBBTData: Bool,
        hasBBTConfirmedOvulation: Bool = false,
        hasMucusData: Bool,
        cycleLengthStdDev: Double?
    ) -> Double {
        var confidence = 0.15 // Calendar-only baseline

        // Regularity bonus (up to 25%)
        if let stdDev = cycleLengthStdDev {
            let regularityBonus = max(0, 1.0 - stdDev / 10.0) * 0.25
            confidence += regularityBonus
        }

        // Data volume bonus
        if completedCycleCount >= BloomConstants.goodAccuracyCycleCount {
            confidence += 0.10
        } else if completedCycleCount >= BloomConstants.minimumCyclesForPrediction {
            confidence += 0.05
        }

        // Data source bonuses
        if hasOPKData { confidence += 0.25 }
        if hasBBTConfirmedOvulation {
            confidence += 0.15
        } else if hasBBTData {
            confidence += 0.05
        }
        if hasMucusData { confidence += 0.10 }

        return min(confidence, 0.99)
    }

    // MARK: - Intercourse Timing Score

    /// Returns a timing quality score (0-50) based on how many days before ovulation
    /// intercourse occurred. Scores are proportional to published per-cycle conception
    /// probabilities (Dunson et al., 2002).
    ///
    /// `daysBeforeOvulation`: positive = before ovulation, 0 = ovulation day, negative = after
    static func timingScore(daysBeforeOvulation: Int) -> Int {
        switch daysBeforeOvulation {
        case 1:  return 50   // O-1: ~31% per-cycle probability (highest)
        case 2:  return 44   // O-2: ~27%
        case 0:  return 33   // O day: ~20%
        case 3:  return 23   // O-3: ~14%
        case 4:  return 18   // O-4: ~11%
        case 5:  return 5    // O-5: ~3%
        default: return 0    // Post-ovulation or >5 days before: ~0%
        }
    }

    /// Maps a timing score back to an approximate per-cycle conception probability string.
    static func estimatedConceptionProbability(forTimingScore score: Int) -> String? {
        switch score {
        case 50: return "~31%"
        case 44: return "~27%"
        case 33: return "~20%"
        case 23: return "~14%"
        case 18: return "~11%"
        case 5:  return "~3%"
        default: return nil
        }
    }

    /// Returns a human-readable label for the best timing day.
    static func timingDayLabel(daysBeforeOvulation: Int) -> String {
        switch daysBeforeOvulation {
        case 0: return "Ovulation day"
        case 1: return "1 day before ovulation"
        default: return "\(daysBeforeOvulation) days before ovulation"
        }
    }

    // MARK: - Conception Score

    /// Calculates a conception score (0–100) for a cycle based on intercourse timing and data quality.
    ///
    /// Components:
    /// - Timing (0-50): Based on proximity of intercourse to ovulation, scaled to published probabilities
    /// - Data quality (0-30): Whether BBT, cervical mucus, and OPK data were tracked
    /// - Favorable signs (0-20): Whether peak fertility indicators were observed
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
            // Positive = ovulation is in the future (log is before ovulation)
            let daysBeforeOvulation = log.date.startOfDay.daysBetween(ovulationDate.startOfDay)
            let dayScore = timingScore(daysBeforeOvulation: daysBeforeOvulation)
            bestTimingScore = max(bestTimingScore, dayScore)
        }
        score += bestTimingScore

        // Data quality score (0-30)
        if logs.contains(where: { $0.bbtTemperature != nil }) { score += 10 }
        if logs.contains(where: { $0.cervicalMucus != nil }) { score += 10 }
        if logs.contains(where: { $0.opkResult != nil }) { score += 10 }

        // Favorable signs score (0-20)
        if logs.contains(where: { $0.cervicalMucus == .eggWhite }) { score += 10 }
        if logs.contains(where: { $0.opkResult == .positive }) { score += 10 }

        return min(score, 100)
    }
}
