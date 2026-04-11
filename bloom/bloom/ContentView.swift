import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }

            Tab("Calendar", systemImage: "calendar") {
                CalendarView()
            }

            Tab("Log", systemImage: "plus.circle.fill") {
                DailyLogView()
            }

            Tab("Insights", systemImage: "chart.line.uptrend.xyaxis") {
                InsightsView()
            }

            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Cycle.self, DailyLog.self], inMemory: true)
}
