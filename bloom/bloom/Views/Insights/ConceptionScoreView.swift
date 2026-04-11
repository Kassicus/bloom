import SwiftUI

struct ConceptionScoreView: View {
    let score: Int?
    let timingScore: Int
    let dataQualityScore: Int
    let favorableSignsScore: Int
    let isCompact: Bool

    init(score: Int?, timingScore: Int = 0, dataQualityScore: Int = 0, favorableSignsScore: Int = 0, isCompact: Bool = false) {
        self.score = score
        self.timingScore = timingScore
        self.dataQualityScore = dataQualityScore
        self.favorableSignsScore = favorableSignsScore
        self.isCompact = isCompact
    }

    var body: some View {
        if isCompact {
            compactView
        } else {
            fullView
        }
    }

    // MARK: - Compact (for Home dashboard)

    private var compactView: some View {
        HStack(spacing: 14) {
            scoreRing(size: 52, lineWidth: 5)

            VStack(alignment: .leading, spacing: 2) {
                Text("Conception Score")
                    .font(.subheadline.bold())
                Text(scoreDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(BloomTheme.cardFill)
        }
    }

    // MARK: - Full (for Insights tab)

    private var fullView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Conception Score")
                    .font(.headline)
                Spacer()
            }

            if let score, score > 0 {
                HStack(spacing: 24) {
                    scoreRing(size: 80, lineWidth: 7)

                    VStack(alignment: .leading, spacing: 10) {
                        breakdownRow(label: "Timing", value: timingScore, maxValue: 50, color: BloomTheme.pinkDeep)
                        breakdownRow(label: "Data Quality", value: dataQualityScore, maxValue: 30, color: BloomTheme.pinkMedium)
                        breakdownRow(label: "Favorable Signs", value: favorableSignsScore, maxValue: 20, color: BloomTheme.pinkLight)
                    }
                }

                Text(scoreDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Probability context
                if let prob = CycleCalculationService.estimatedConceptionProbability(forTimingScore: timingScore) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption)
                            .foregroundStyle(BloomTheme.pinkMedium)
                        Text("Estimated per-cycle probability based on timing: \(prob)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                EducationalTipView(
                    title: "What this score means",
                    detail: "This score reflects how well your intercourse timing aligns with your estimated fertile window, combined with data quality. It is not a pregnancy probability. Actual per-cycle conception probability for healthy couples with optimal timing is approximately 20-30%. Factors like age, overall health, and partner fertility significantly affect real outcomes."
                )
            } else {
                emptyState
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(BloomTheme.cardFill)
        }
    }

    // MARK: - Score Ring

    private func scoreRing(size: CGFloat, lineWidth: CGFloat) -> some View {
        let fraction = Double(score ?? 0) / 100.0

        return ZStack {
            Circle()
                .stroke(.secondary.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(score ?? 0)")
                .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Breakdown Row

    private func breakdownRow(label: String, value: Int, maxValue: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(value)/\(maxValue)")
                    .font(.caption.bold())
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.secondary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * Double(value) / Double(maxValue))
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Helpers

    private var scoreColor: Color {
        guard let score else { return .secondary }
        if score >= 60 { return BloomTheme.pinkSoft }
        if score >= 30 { return BloomTheme.pinkMedium }
        return BloomTheme.pinkDeepest
    }

    private var scoreDescription: String {
        guard let score else { return "Log data to see your conception score" }
        if score >= 70 {
            return "Excellent timing and data quality this cycle"
        } else if score >= 50 {
            return "Good effort — timing intercourse closer to ovulation can improve your score"
        } else if score >= 30 {
            return "Try to log more data and time intercourse during your fertile window"
        } else if score > 0 {
            return "Log BBT, cervical mucus, and OPK results to improve accuracy"
        } else {
            return "Log data during your fertile window to get a score"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.pie")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No score yet for this cycle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Log intercourse during your fertile window to see your conception score")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
