import Foundation
import SwiftData

@Model
final class DailyLog {
    var date: Date
    var cycle: Cycle?

    // Period
    var isOnPeriod: Bool
    var flowIntensity: FlowIntensity?

    // Fertility markers
    var bbtTemperature: Double?
    var cervicalMucus: CervicalMucusType?
    var opkResult: OPKResult?

    // Symptoms (stored as JSON-encoded array by SwiftData)
    var symptoms: [Symptom]

    // Intercourse
    @Relationship(deleteRule: .cascade, inverse: \IntercourseEntry.dailyLog)
    var intercourseEntries: [IntercourseEntry]

    // Notes
    var notes: String?

    /// Convenience check for whether any intercourse was logged this day.
    var hadIntercourse: Bool {
        !intercourseEntries.isEmpty
    }

    init(date: Date, cycle: Cycle? = nil) {
        self.date = Calendar.current.startOfDay(for: date)
        self.cycle = cycle
        self.isOnPeriod = false
        self.flowIntensity = nil
        self.bbtTemperature = nil
        self.cervicalMucus = nil
        self.opkResult = nil
        self.symptoms = []
        self.intercourseEntries = []
        self.notes = nil
    }
}
