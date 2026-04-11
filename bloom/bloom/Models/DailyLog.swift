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

    // Conception
    var hadIntercourse: Bool
    var intercourseNotes: String?

    // Notes
    var notes: String?

    init(date: Date, cycle: Cycle? = nil) {
        self.date = Calendar.current.startOfDay(for: date)
        self.cycle = cycle
        self.isOnPeriod = false
        self.flowIntensity = nil
        self.bbtTemperature = nil
        self.cervicalMucus = nil
        self.opkResult = nil
        self.symptoms = []
        self.hadIntercourse = false
        self.intercourseNotes = nil
        self.notes = nil
    }
}
