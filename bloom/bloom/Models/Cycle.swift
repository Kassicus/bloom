import Foundation
import SwiftData

@Model
final class Cycle {
    var startDate: Date
    var endDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \DailyLog.cycle)
    var dailyLogs: [DailyLog]

    // Calculated / cached values updated by CycleCalculationService
    var cycleLength: Int?
    var periodLength: Int?
    var estimatedOvulationDate: Date?
    var isOvulationConfirmed: Bool

    init(startDate: Date) {
        self.startDate = Calendar.current.startOfDay(for: startDate)
        self.endDate = nil
        self.dailyLogs = []
        self.cycleLength = nil
        self.periodLength = nil
        self.estimatedOvulationDate = nil
        self.isOvulationConfirmed = false
    }
}
