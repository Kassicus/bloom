import Foundation
import SwiftData

@Model
final class Cycle {
    var startDate: Date = Date.distantPast
    var endDate: Date?

    // Cycles are derived from logged period days and get recreated when periods are edited,
    // so deleting one must never take the user's logs with it.
    @Relationship(deleteRule: .nullify, inverse: \DailyLog.cycle)
    var dailyLogs: [DailyLog]?

    // Calculated / cached values updated by CycleCalculationService
    var cycleLength: Int?
    var periodLength: Int?
    var estimatedOvulationDate: Date?
    var isOvulationConfirmed: Bool = false

    init(startDate: Date) {
        self.startDate = Calendar.current.startOfDay(for: startDate)
        self.endDate = nil
        self.dailyLogs = nil
        self.cycleLength = nil
        self.periodLength = nil
        self.estimatedOvulationDate = nil
        self.isOvulationConfirmed = false
    }
}
