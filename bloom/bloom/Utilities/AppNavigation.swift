import Foundation
import Observation

enum AppTab: Hashable {
    case home
    case calendar
    case log
    case insights
    case settings
}

/// App-wide navigation state, shared through the environment so any screen can jump to the
/// Daily Log for a particular day.
@Observable
final class AppNavigation {
    var selectedTab: AppTab = .home

    /// A day the Daily Log should show next. The Daily Log consumes it and resets it to nil.
    var requestedLogDate: Date?

    /// Set to ask the Calendar to show the period logging sheet; it resets this to false.
    var requestedPeriodSheet = false

    func openLog(for date: Date) {
        requestedLogDate = date.startOfDay
        selectedTab = .log
    }

    func openPeriodLogging() {
        requestedPeriodSheet = true
        selectedTab = .calendar
    }
}
