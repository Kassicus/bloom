import Foundation

nonisolated enum BloomConstants {
    static let defaultCycleLength = 28
    static let defaultPeriodLength = 5
    static let defaultLutealPhaseLength = 14
    static let fertileWindowDaysBefore = 5
    static let minimumCyclesForPrediction = 2
    static let goodAccuracyCycleCount = 6

    // BBT
    static let bbtBaselineMin: Double = 96.0
    static let bbtBaselineMax: Double = 99.0
    static let bbtShiftThreshold: Double = 0.3
    static let bbtConfirmationDays = 3
    static let bbtBaselineDays = 6
}
