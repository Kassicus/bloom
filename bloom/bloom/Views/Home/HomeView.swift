import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HomeViewModel?
    @State private var predictionService: PredictionService?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    homeContent(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Bloom")
            .onAppear {
                if viewModel == nil {
                    let ps = PredictionService(modelContext: modelContext)
                    ps.updatePredictions()
                    predictionService = ps
                    let vm = HomeViewModel(modelContext: modelContext, predictionService: ps)
                    vm.refresh()
                    viewModel = vm
                }
            }
        }
    }

    @ViewBuilder
    private func homeContent(viewModel: HomeViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.hasCycleData {
                    activeCycleContent(viewModel: viewModel)
                } else {
                    emptyStateView
                }
            }
            .padding()
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    private func activeCycleContent(viewModel: HomeViewModel) -> some View {
        VStack(spacing: 20) {
            // Fertile window banner
            if viewModel.isInFertileWindow {
                fertileWindowBanner(viewModel: viewModel)
            }

            // Cycle day header
            Text(viewModel.cycleDayText)
                .font(.title.bold())

            // Cycle ring
            CycleRingView(
                segments: viewModel.cycleRingSegments,
                progress: viewModel.cycleProgress,
                cycleDay: viewModel.predictionService.currentCycleDay,
                phase: viewModel.predictionService.currentPhase
            )
            .padding(.vertical, 4)

            // Fertility badge
            FertilityBadgeView(
                level: viewModel.fertilityLevel,
                recommendation: viewModel.recommendationText
            )

            // Countdown cards
            countdownCards(viewModel: viewModel)

            // Conception score
            if viewModel.conceptionScore != nil || viewModel.isInFertileWindow {
                let breakdown = viewModel.conceptionScoreBreakdown
                ConceptionScoreView(
                    score: viewModel.conceptionScore,
                    timingScore: breakdown.timing,
                    dataQualityScore: breakdown.dataQuality,
                    favorableSignsScore: breakdown.favorableSigns,
                    isCompact: true
                )
            }

            // Prediction confidence
            if viewModel.predictionService.completedCycleCount > 0 {
                confidenceBar(viewModel: viewModel)
            }

            // Daily summary
            DailySummaryCard(
                loggedItems: viewModel.todayLoggedItems,
                hasData: viewModel.todayHasData
            )
        }
    }

    private func fertileWindowBanner(viewModel: HomeViewModel) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Fertile Window Active")
                    .font(.subheadline.bold())

                if let level = viewModel.fertilityLevel {
                    Text(level.recommendation)
                        .font(.caption)
                        .opacity(0.9)
                }
            }

            Spacer()
        }
        .foregroundStyle(.white)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [FertilityLevel.peak.color, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }

    private func countdownCards(viewModel: HomeViewModel) -> some View {
        HStack(spacing: 12) {
            if let fertileCountdown = viewModel.fertileWindowCountdown {
                countdownCard(
                    title: "Fertile Window",
                    value: fertileCountdown,
                    icon: "sparkles",
                    color: FertilityLevel.peak.color
                )
            }

            if let periodCountdown = viewModel.nextPeriodCountdown {
                countdownCard(
                    title: "Next Period",
                    value: periodCountdown,
                    icon: "drop.fill",
                    color: CyclePhase.menstrual.color
                )
            }
        }
    }

    private func countdownCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func confidenceBar(viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Prediction Confidence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.confidenceText)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(confidenceColor(viewModel.predictionService.predictionConfidence))
                        .frame(width: geo.size.width * viewModel.predictionService.predictionConfidence)
                }
            }
            .frame(height: 6)

            if viewModel.predictionService.completedCycleCount < BloomConstants.goodAccuracyCycleCount {
                let remaining = BloomConstants.goodAccuracyCycleCount - viewModel.predictionService.completedCycleCount
                Text("Track \(remaining) more cycle\(remaining == 1 ? "" : "s") for better accuracy")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.7 { return .green }
        if confidence >= 0.4 { return .orange }
        return .red
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            CycleRingView(
                segments: [],
                progress: 0,
                cycleDay: nil,
                phase: nil
            )

            Text("Welcome to Bloom")
                .font(.title2.bold())

            Text("Start by logging your period on the Calendar tab to begin tracking your cycle and fertility.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical, 40)
    }
}
