import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var predictionService: PredictionService?
    @State private var navigation = AppNavigation()

    var body: some View {
        Group {
            if let predictionService {
                TabView(selection: $navigation.selectedTab) {
                    Tab("Home", systemImage: "house", value: AppTab.home) {
                        HomeView(predictionService: predictionService)
                    }

                    Tab("Calendar", systemImage: "calendar", value: AppTab.calendar) {
                        CalendarView(predictionService: predictionService)
                    }

                    Tab("Log", systemImage: "plus.circle.fill", value: AppTab.log) {
                        DailyLogView(predictionService: predictionService)
                    }

                    Tab("Insights", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.insights) {
                        InsightsView(predictionService: predictionService)
                    }

                    Tab("Settings", systemImage: "gear", value: AppTab.settings) {
                        SettingsView(predictionService: predictionService)
                    }
                }
                .environment(navigation)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if predictionService == nil {
                let ps = PredictionService(modelContext: modelContext)
                ps.reloadAll()
                predictionService = ps
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // The date may have changed or iCloud may have synced while in the background.
            if phase == .active {
                predictionService?.reloadAll()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Cycle.self, DailyLog.self, IntercourseEntry.self], inMemory: true)
}
