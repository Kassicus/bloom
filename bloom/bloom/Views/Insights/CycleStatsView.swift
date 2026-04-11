import SwiftUI

struct CycleStatsView: View {
    let averageCycleLength: Double?
    let averagePeriodLength: Double?
    let cycleLengthRange: ClosedRange<Int>?
    let regularityDescription: String
    let completedCycleCount: Int
    let confidencePercent: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cycle Statistics")
                .font(.headline)

            if completedCycleCount == 0 {
                emptyState
            } else {
                statsGrid
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(
                title: "Avg Cycle",
                value: averageCycleLength.map { String(format: "%.0f days", $0) } ?? "—",
                icon: "arrow.triangle.2.circlepath",
                color: .blue
            )
            statCard(
                title: "Avg Period",
                value: averagePeriodLength.map { String(format: "%.0f days", $0) } ?? "—",
                icon: "drop.fill",
                color: CyclePhase.menstrual.color
            )
            statCard(
                title: "Regularity",
                value: regularityDescription,
                icon: "waveform.path.ecg",
                color: regularityColor
            )
            statCard(
                title: "Range",
                value: cycleLengthRange.map { "\($0.lowerBound)–\($0.upperBound) days" } ?? "—",
                icon: "ruler",
                color: .purple
            )
            statCard(
                title: "Cycles Tracked",
                value: "\(completedCycleCount)",
                icon: "chart.bar",
                color: .teal
            )
            statCard(
                title: "Confidence",
                value: "\(confidencePercent)%",
                icon: "target",
                color: confidenceColor
            )
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var regularityColor: Color {
        switch regularityDescription {
        case "Regular": .green
        case "Somewhat Regular": .orange
        default: .red
        }
    }

    private var confidenceColor: Color {
        if confidencePercent >= 70 { return .green }
        if confidencePercent >= 40 { return .orange }
        return .red
    }

    private var emptyState: some View {
        HStack {
            Image(systemName: "chart.bar")
                .foregroundStyle(.secondary)
            Text("Complete at least one full cycle to see statistics")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 16)
    }
}
