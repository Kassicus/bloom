import Foundation

nonisolated enum BloomConstants {
    static let defaultCycleLength = 28
    static let defaultPeriodLength = 5
    static let defaultLutealPhaseLength = 13
    static let minLutealPhaseLength = 8
    static let maxLutealPhaseLength = 18
    static let fertileWindowDaysBefore = 5
    static let minimumCyclesForPrediction = 2
    static let minimumCyclesForLutealLearning = 2
    static let goodAccuracyCycleCount = 6

    // Cycle derivation from period days
    /// Period days at most this many days apart are part of the same period (allows missed logs).
    static let periodGapToleranceDays = 3
    /// Bleeding that starts sooner than this after the last period started is not a new cycle.
    static let minimumCycleLength = 15
    /// Longest stretch (from the first day) still treated as a single period.
    static let maxPlausiblePeriodLength = 12

    // Ovulation estimate
    /// A BBT shift further than this from the OPK-based estimate is treated as noise.
    static let maxOPKBBTDisagreementDays = 3

    // BBT (stored in °F)
    static let bbtEntryMinFahrenheit: Double = 95.0
    static let bbtEntryMaxFahrenheit: Double = 100.5
    static let bbtDefaultFahrenheit: Double = 97.5
    static let bbtShiftThreshold: Double = 0.3
    static let bbtConfirmationDays = 3
    static let bbtBaselineDays = 6
}
