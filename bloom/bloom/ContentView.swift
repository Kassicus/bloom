import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var predictionService: PredictionService?

    var body: some View {
        Group {
            if let predictionService {
                TabView {
                    Tab("Home", systemImage: "house") {
                        HomeView(predictionService: predictionService)
                    }

                    Tab("Calendar", systemImage: "calendar") {
                        CalendarView(predictionService: predictionService)
                    }

                    Tab("Log", systemImage: "plus.circle.fill") {
                        DailyLogView(predictionService: predictionService)
                    }

                    Tab("Insights", systemImage: "chart.line.uptrend.xyaxis") {
                        InsightsView(predictionService: predictionService)
                    }

                    Tab("Settings", systemImage: "gear") {
                        SettingsView(predictionService: predictionService)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if predictionService == nil {
                let ps = PredictionService(modelContext: modelContext)
                ps.updatePredictions()
                predictionService = ps
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Cycle.self, DailyLog.self, IntercourseEntry.self], inMemory: true)
}
