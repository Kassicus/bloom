import SwiftUI
import SwiftData

struct CycleTimelineView: View {
    let modelContext: ModelContext
    let predictionService: PredictionService

    @State private var cycles: [Cycle] = []

    var body: some View {
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
                            ForEach(cycles, id: \.startDate) { cycle in
                                cycleBar(cycle, availableWidth: geo.size.width)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(height: 48)
            }
        }
        .onAppear { loadCycles() }
    }

    private func cycleBar(_ cycle: Cycle, availableWidth: CGFloat) -> some View {
        let length = cycle.cycleLength ?? BloomConstants.defaultCycleLength
        let periodLen = cycle.periodLength ?? BloomConstants.defaultPeriodLength
        let ovulationDay = length - BloomConstants.defaultLutealPhaseLength
        // Scale each bar so ~3 cycles fit in the visible width
        let targetBars = max(1, cycles.count > 3 ? 3 : cycles.count)
        let scale = (availableWidth - CGFloat(targetBars - 1) * 8) / (CGFloat(targetBars) * CGFloat(BloomConstants.defaultCycleLength))

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Rectangle().fill(CyclePhase.menstrual.color)
                    .frame(width: CGFloat(periodLen) * scale)
                Rectangle().fill(CyclePhase.follicular.color)
                    .frame(width: CGFloat(max(0, ovulationDay - 2 - periodLen)) * scale)
                Rectangle().fill(CyclePhase.ovulation.color)
                    .frame(width: 3 * scale)
                Rectangle().fill(CyclePhase.luteal.color)
                    .frame(width: CGFloat(max(0, length - ovulationDay - 1)) * scale)
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

    private func loadCycles() {
        let descriptor = FetchDescriptor<Cycle>(sortBy: [SortDescriptor(\.startDate, order: .forward)])
        cycles = (try? modelContext.fetch(descriptor))?.filter { $0.cycleLength != nil } ?? []
    }
}
