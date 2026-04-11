import SwiftUI
import Charts

struct BBTChartView: View {
    let dataPoints: [BBTDataPoint]
    let coverlineTemp: Double?
    let ovulationDate: Date?
    let fertileWindowStart: Date?
    let fertileWindowEnd: Date?
    let cycleLabel: String
    let canSelectPrevious: Bool
    let canSelectNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with cycle selector
            HStack {
                Text("Temperature")
                    .font(.headline)
                Spacer()
                cycleSelector
            }

            if dataPoints.isEmpty {
                emptyState
            } else {
                chart
                    .frame(height: 200)

                legend
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            // Fertile window shading
            if let start = fertileWindowStart, let end = fertileWindowEnd {
                RectangleMark(
                    xStart: .value("Start", start),
                    xEnd: .value("End", end),
                    yStart: nil,
                    yEnd: nil
                )
                .foregroundStyle(FertilityLevel.peak.color.opacity(0.08))
            }

            // Coverline
            if let coverline = coverlineTemp {
                RuleMark(y: .value("Coverline", coverline))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .foregroundStyle(.orange.opacity(0.6))
                    .annotation(position: .topLeading) {
                        Text("Coverline")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
            }

            // Temperature line
            ForEach(dataPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Temp", point.temperature)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Temp", point.temperature)
                )
                .foregroundStyle(pointColor(for: point))
                .symbolSize(30)
            }

            // Ovulation marker
            if let ovDate = ovulationDate,
               let point = dataPoints.first(where: { Calendar.current.isDate($0.date, inSameDayAs: ovDate) }) {
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Temp", point.temperature)
                )
                .symbol(.diamond)
                .symbolSize(80)
                .foregroundStyle(.orange)
                .annotation(position: .top, spacing: 4) {
                    Text("Ov")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: xStride)) { value in
                AxisValueLabel(format: .dateTime.day())
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .stride(by: 0.5)) { value in
                AxisValueLabel {
                    if let temp = value.as(Double.self) {
                        Text(String(format: "%.1f", temp))
                            .font(.caption2)
                    }
                }
                AxisGridLine()
            }
        }
    }

    // MARK: - Helpers

    private var yDomain: ClosedRange<Double> {
        let temps = dataPoints.map(\.temperature)
        guard let minT = temps.min(), let maxT = temps.max() else {
            return 96.5...99.0
        }
        let floor = Swift.min(minT - 0.3, 96.5)
        let ceil = Swift.max(maxT + 0.3, 98.5)
        return floor...ceil
    }

    private var xStride: Int {
        if dataPoints.count > 20 { return 5 }
        if dataPoints.count > 10 { return 3 }
        return 2
    }

    private func pointColor(for point: BBTDataPoint) -> Color {
        if let coverline = coverlineTemp, point.temperature >= coverline {
            return .orange
        }
        return .blue
    }

    // MARK: - Subviews

    private var cycleSelector: some View {
        HStack(spacing: 8) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.caption.bold())
            }
            .disabled(!canSelectPrevious)
            .opacity(canSelectPrevious ? 1 : 0.3)

            Text(cycleLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
            }
            .disabled(!canSelectNext)
            .opacity(canSelectNext ? 1 : 0.3)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "thermometer.medium")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No temperature data for this cycle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Log your BBT daily for the chart to populate")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: .blue, label: "Pre-ovulation")
            legendItem(color: .orange, label: "Post-ovulation")
            if coverlineTemp != nil {
                HStack(spacing: 4) {
                    Rectangle()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                        .foregroundStyle(.orange.opacity(0.6))
                        .frame(width: 16, height: 1)
                    Text("Coverline")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
