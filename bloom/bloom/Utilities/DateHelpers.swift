import Foundation

nonisolated extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    func daysBetween(_ other: Date) -> Int {
        Calendar.current.dateComponents([.day], from: self.startOfDay, to: other.startOfDay).day ?? 0
    }

    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self)!
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var shortFormatted: String {
        formatted(.dateTime.month(.abbreviated).day())
    }
}
