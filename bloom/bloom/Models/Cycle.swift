import Foundation
import SwiftData

@Model
final class Cycle {
    var startDate: Date = Date.distantPast
    var endDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \DailyLog.cycle)
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
