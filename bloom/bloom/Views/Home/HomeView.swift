import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    let predictionService: PredictionService
    @State private var viewModel: HomeViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    homeContent(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Bloom")
                        .font(BloomTheme.appTitle)
                        .foregroundStyle(BloomTheme.brand)
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = HomeViewModel(modelContext: modelContext, predictionService: predictionService)
                }
                viewModel?.refresh()
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

            // Phase education card
            if let phase = viewModel.predictionService.currentPhase {
                phaseEducationCard(phase: phase)
            }

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

            // How to improve accuracy
            EducationalTipView(
                title: "How to improve prediction accuracy",
                detail: "OPK tests predict ovulation 24-48 hours in advance and are the most actionable indicator. Cervical mucus provides real-time fertility cues. BBT confirms ovulation after it occurs and helps the app learn your personal luteal phase length for more accurate future predictions. Using all three gives the most complete picture."
            )
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(BloomTheme.cardFill)
            }
        }
    }

    private func phaseEducationCard(phase: CyclePhase) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(phase.color)
                    .frame(width: 10, height: 10)
                Text("\(phase.label) Phase")
                    .font(.subheadline.bold())
                    .foregroundStyle(phase.color)
            }
            Text(phase.detailedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(phase.color.opacity(0.06))
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
                        colors: [BloomTheme.brand, BloomTheme.brand.opacity(0.7)],
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
                .fill(BloomTheme.cardFill)
        }
    }

    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.7 { return BloomTheme.pinkSoft }
        if confidence >= 0.4 { return BloomTheme.pinkMedium }
        return BloomTheme.pinkDeepest
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
                .font(BloomTheme.sectionTitle)
                .foregroundStyle(BloomTheme.brand)

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
