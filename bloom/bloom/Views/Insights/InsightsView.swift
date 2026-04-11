import SwiftUI
import SwiftData

struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: InsightsViewModel?
    @State private var predictionService: PredictionService?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    insightsContent(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Insights")
            .onAppear {
                if viewModel == nil {
                    let ps = PredictionService(modelContext: modelContext)
                    ps.updatePredictions()
                    predictionService = ps
                    let vm = InsightsViewModel(modelContext: modelContext, predictionService: ps)
                    vm.refresh()
                    viewModel = vm
                }
            }
        }
    }

    @ViewBuilder
    private func insightsContent(viewModel: InsightsViewModel) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Cycle statistics
                CycleStatsView(
                    averageCycleLength: viewModel.averageCycleLength,
                    averagePeriodLength: viewModel.averagePeriodLength,
                    cycleLengthRange: viewModel.cycleLengthRange,
                    regularityDescription: viewModel.regularityDescription,
                    completedCycleCount: viewModel.completedCycleCount,
                    confidencePercent: viewModel.confidencePercent
                )

                // BBT chart
                BBTChartView(
                    dataPoints: viewModel.bbtDataPoints,
                    coverlineTemp: viewModel.coverlineTemp,
                    ovulationDate: viewModel.detectedOvulationDate,
                    fertileWindowStart: viewModel.fertileWindowStart,
                    fertileWindowEnd: viewModel.fertileWindowEnd,
                    cycleLabel: viewModel.selectedCycleLabel,
                    canSelectPrevious: viewModel.canSelectPrevious,
                    canSelectNext: viewModel.canSelectNext,
                    onPrevious: viewModel.selectPreviousCycle,
                    onNext: viewModel.selectNextCycle
                )

                // Conception score
                ConceptionScoreView(
                    score: viewModel.conceptionScore,
                    timingScore: viewModel.conceptionTimingScore,
                    dataQualityScore: viewModel.conceptionDataQualityScore,
                    favorableSignsScore: viewModel.conceptionFavorableSignsScore
                )

                // Cycle history
                CycleHistoryView(cycles: viewModel.cycleHistory)
            }
            .padding()
        }
        .refreshable {
            viewModel.refresh()
        }
    }
}
