import Foundation
import Observation

@Observable
final class CalendarViewModel {
    let predictionService: PredictionService
    private var cycleManager: CycleManager { predictionService.cycleManager }

    var displayedMonth: Date = Date.now.startOfDay
    var selectedDate: Date? = nil
    var showingPeriodSheet = false

    private let calendar = Calendar.current

    init(predictionService: PredictionService) {
        self.predictionService = predictionService
    }

    // MARK: - Month Navigation

    var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    var isShowingCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month)
    }

    func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    func goToToday() {
        displayedMonth = Date.now.startOfDay
        selectedDate = Date.now.startOfDay
    }

    // MARK: - Calendar Grid Data

    /// Weekday initials ordered to match the grid, which starts on the locale's first weekday.
    var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    /// Returns all dates to display in the month grid (including leading/trailing days from adjacent months).
    var daysInMonthGrid: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }

        let firstDay = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leadingEmptyDays = firstWeekday - calendar.firstWeekday
        let adjustedLeading = leadingEmptyDays < 0 ? leadingEmptyDays + 7 : leadingEmptyDays

        let daysInMonth = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30

        var grid: [Date?] = Array(repeating: nil, count: adjustedLeading)

        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: firstDay) {
                grid.append(date)
            }
        }

        // Pad to complete the last row
        while grid.count % 7 != 0 {
            grid.append(nil)
        }

        return grid
    }

    /// Day info for every date in the displayed month, using a single fetch for the month's logs.
    var monthDayInfo: [Date: DayInfo] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [:] }
        let logs = cycleManager.logsByDay(from: interval.start, to: interval.end)

        var result: [Date: DayInfo] = [:]
        var day = interval.start.startOfDay
        while day < interval.end {
            result[day] = predictionService.dayInfo(for: day, log: logs[day])
            day = day.addingDays(1)
        }
        return result
    }

    func dayInfo(for date: Date) -> DayInfo {
        predictionService.dayInfo(for: date, log: cycleManager.log(for: date))
    }

    // MARK: - Period Editing

    /// Period days can be added up to today; pre-filled future days can still be removed.
    func canTogglePeriod(on date: Date) -> Bool {
        date.startOfDay <= Date.now.startOfDay || dayInfo(for: date).isPeriod
    }

    func togglePeriod(on date: Date) {
        let isOn = cycleManager.log(for: date)?.isOnPeriod == true
        predictionService.editPeriods(around: date) { $0.setPeriod(!isOn, on: date) }
    }

    func deletePeriod(containing date: Date) {
        predictionService.editPeriods(around: date) { $0.deletePeriod(containing: date) }
    }

    func logPeriodStart(on date: Date, flow: FlowIntensity) {
        predictionService.editPeriods(around: date) { $0.logPeriodStart(on: date, flow: flow) }
    }

    func endPeriod(lastDay: Date) {
        predictionService.editPeriods(around: lastDay) { $0.endPeriod(lastDay: lastDay) }
    }

    // MARK: - Period Sheet Support

    /// Start of the current period, if it could still be ongoing (started within the longest
    /// plausible period length). Used to offer "Period ended".
    var ongoingPeriodStart: Date? {
        guard let start = predictionService.currentCycle?.startDate.startOfDay else { return nil }
        let daysSinceStart = start.daysBetween(.now)
        return (0..<BloomConstants.maxPlausiblePeriodLength).contains(daysSinceStart) ? start : nil
    }

    /// Default "last day" for ending the current period: its last logged day, capped at today.
    var suggestedPeriodEnd: Date {
        let today = Date.now.startOfDay
        guard let end = predictionService.currentCycle?.endDate?.startOfDay else { return today }
        return min(end, today)
    }

    var expectedPeriodLength: Int {
        predictionService.expectedPeriodLength
    }
}
