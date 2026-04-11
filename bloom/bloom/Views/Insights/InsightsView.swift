import SwiftUI
import SwiftData

struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext
    let predictionService: PredictionService
    @State private var viewModel: InsightsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    insightsContent(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Insights")
                        .font(BloomTheme.sectionTitle)
                        .foregroundStyle(BloomTheme.brand)
                }
            }
            .onAppear {
                if viewModel == nil {
                    let vm = InsightsViewModel(modelContext: modelContext, predictionService: predictionService)
                    viewModel = vm
                }
                viewModel?.refresh()
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

                // Understanding Your Cycle
                understandingYourCycleSection
            }
            .padding()
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    private var understandingYourCycleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Understanding Your Cycle")
                .font(.headline)

            EducationalTipView(
                title: "Cycle length variation",
                detail: "Cycle lengths of 21-35 days are considered normal. Variation of up to 7 days between cycles is common. The luteal phase (after ovulation) tends to be more consistent than the follicular phase (before ovulation), which is why ovulation day varies even when cycle length is similar."
            )

            EducationalTipView(
                title: "BBT is retrospective",
                detail: "Your basal body temperature rises after ovulation due to progesterone. This means BBT confirms that ovulation occurred but cannot predict it in advance. Its value is in building an accurate model of your personal luteal phase length, which improves calendar-based predictions for future cycles."
            )

            EducationalTipView(
                title: "OPK is predictive",
                detail: "Ovulation test kits detect the LH surge that triggers egg release. A positive OPK predicts ovulation 24-48 hours in advance, making it the most actionable fertility indicator available without clinical monitoring."
            )

            EducationalTipView(
                title: "Cervical mucus is real-time",
                detail: "Cervical mucus changes in response to rising estrogen. The progression from dry to sticky to creamy to egg-white gives you real-time information about approaching ovulation. Peak mucus (egg white) is strongly correlated with peak fertility."
            )
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(BloomTheme.cardFill)
        }
    }
}
