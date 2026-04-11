import Foundation
import SwiftData

@Model
final class IntercourseEntry {
    var dateTime: Date = Date.distantPast
    var notes: String?
    var dailyLog: DailyLog?

    init(dateTime: Date = .now, notes: String? = nil) {
        self.dateTime = dateTime
        self.notes = notes
    }

    var timeFormatted: String {
        dateTime.formatted(date: .omitted, time: .shortened)
    }
}
