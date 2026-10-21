import SwiftUI

struct CycleTimelineView: View {
    let predictionService: PredictionService

    /// Completed cycles, oldest first. Read through an observed property so the timeline
    /// refreshes whenever predictions update.
    private var cycles: [Cycle] {
        _ = predictionService.completedCycleCount
        return predictionService.cycles.filter { $0.cycleLength != nil }
    }

    var body: some View {
        let cycles = cycles

        VStack(alignment: .leading, spacing: 8) {
            Text("Cycle History")
                .font(.headline)

            if cycles.isEmpty {
                Text("No completed cycles yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                GeometryReader { geo in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(cycles) { cycle in
                                cycleBar(cycle, cycleCount: cycles.count, availableWidth: geo.size.width)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .defaultScrollAnchor(.trailing)
                }
                .frame(height: 48)
            }
        }
    }

    private func cycleBar(_ cycle: Cycle, cycleCount: Int, availableWidth: CGFloat) -> some View {
        let length = cycle.cycleLength ?? BloomConstants.defaultCycleLength
        let periodLen = min(cycle.periodLength ?? BloomConstants.defaultPeriodLength, length)
        let ovulationDay = cycle.estimatedOvulationDate.map {
            CycleCalculationService.ovulationDay(cycleStart: cycle.startDate, ovulationDate: $0)
        } ?? (length - predictionService.effectiveLutealPhaseLength)
        // Ovulation phase covers days ovulationDay-1 ... ovulationDay+1
        let ovulationStart = min(max(periodLen, ovulationDay - 2), length)
        let ovulationEnd = min(max(periodLen, ovulationDay + 1), length)

        // Scale each bar so ~3 cycles fit in the visible width
        let targetBars = max(1, min(cycleCount, 3))
        let scale = (availableWidth - CGFloat(targetBars - 1) * 8) / (CGFloat(targetBars) * CGFloat(BloomConstants.defaultCycleLength))

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Rectangle().fill(CyclePhase.menstrual.color)
                    .frame(width: CGFloat(periodLen) * scale)
                Rectangle().fill(CyclePhase.follicular.color)
                    .frame(width: CGFloat(ovulationStart - periodLen) * scale)
                Rectangle().fill(CyclePhase.ovulation.color)
                    .frame(width: CGFloat(ovulationEnd - ovulationStart) * scale)
                Rectangle().fill(CyclePhase.luteal.color)
                    .frame(width: CGFloat(length - ovulationEnd) * scale)
            }
            .frame(height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            HStack {
                Text(cycle.startDate.shortFormatted)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(length)d")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
            .frame(width: CGFloat(length) * scale)
        }
    }
}
