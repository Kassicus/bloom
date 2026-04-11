import SwiftUI

struct CycleHistoryView: View {
    let cycles: [CycleSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cycle History")
                .font(.headline)

            if cycles.isEmpty {
                emptyState
            } else {
                ForEach(cycles) { cycle in
                    cycleRow(cycle)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    private func cycleRow(_ cycle: CycleSummary) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(cycle.startDate.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(.subheadline.bold())

                        if cycle.isCurrent {
                            Text("Current")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 12) {
                        label(icon: "arrow.triangle.2.circlepath", text: cycle.lengthText)
                        label(icon: "drop", text: "Period: \(cycle.periodText)")
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    dataIndicators(cycle)
                }
            }
            .padding(.vertical, 10)

            if cycle.id != cycles.last?.id {
                Divider()
            }
        }
    }

    private func label(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func dataIndicators(_ cycle: CycleSummary) -> some View {
        HStack(spacing: 6) {
            if cycle.isOvulationConfirmed {
                indicatorDot(icon: "checkmark.circle.fill", color: BloomTheme.pinkDeep, tooltip: "Ovulation confirmed")
            }
            if cycle.hasOPKData {
                indicatorDot(icon: "testtube.2", color: BloomTheme.pinkDeepest, tooltip: "OPK data")
            }
            if cycle.hasBBTData {
                indicatorDot(icon: "thermometer", color: BloomTheme.pinkMedium, tooltip: "BBT data")
            }
            if cycle.intercourseCount > 0 {
                indicatorDot(icon: "heart.fill", color: BloomTheme.pinkAccent, tooltip: "\(cycle.intercourseCount)")
            }
        }
    }

    private func indicatorDot(icon: String, color: Color, tooltip: String) -> some View {
        Image(systemName: icon)
            .font(.caption2)
            .foregroundStyle(color)
    }

    private var emptyState: some View {
        HStack {
            Image(systemName: "list.bullet")
                .foregroundStyle(.secondary)
            Text("No cycles recorded yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 16)
    }
}
