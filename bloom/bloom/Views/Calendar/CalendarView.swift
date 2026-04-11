import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    let predictionService: PredictionService
    @State private var viewModel: CalendarViewModel?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    calendarContent(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Calendar")
                        .font(BloomTheme.sectionTitle)
                        .foregroundStyle(BloomTheme.brand)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel?.showingPeriodSheet = true
                    } label: {
                        Label("Log Period", systemImage: "drop.fill")
                    }
                    .tint(CyclePhase.menstrual.color)
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel?.showingPeriodSheet ?? false },
                set: { viewModel?.showingPeriodSheet = $0 }
            )) {
                if let viewModel {
                    PeriodLoggingSheet(viewModel: viewModel)
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = CalendarViewModel(modelContext: modelContext, predictionService: predictionService)
                }
            }
        }
    }

    @ViewBuilder
    private func calendarContent(viewModel: CalendarViewModel) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Month header
                monthHeader(viewModel: viewModel)

                // Weekday header
                weekdayHeader(viewModel: viewModel)

                // Day grid
                dayGrid(viewModel: viewModel)

                // Predictions summary
                predictionsSummary(viewModel: viewModel)

                // Cycle timeline
                if viewModel.predictionService.completedCycleCount > 0 {
                    CycleTimelineView(modelContext: modelContext, predictionService: viewModel.predictionService)
                        .padding(.top, 8)
                }
            }
            .padding()
        }
    }

    private func monthHeader(viewModel: CalendarViewModel) -> some View {
        HStack {
            Button(action: viewModel.previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
            }

            Spacer()

            Text(viewModel.monthTitle)
                .font(.title2.bold())

            Spacer()

            Button(action: viewModel.nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title3.bold())
            }
        }
        .padding(.horizontal, 4)
    }

    private func weekdayHeader(viewModel: CalendarViewModel) -> some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(viewModel.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayGrid(viewModel: CalendarViewModel) -> some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(viewModel.daysInMonthGrid.enumerated()), id: \.offset) { _, date in
                if let date {
                    CalendarDayCell(
                        date: date,
                        isToday: date.isToday,
                        isSelected: viewModel.selectedDate?.startOfDay == date.startOfDay,
                        phase: viewModel.phaseForDate(date),
                        fertility: viewModel.fertilityForDate(date),
                        isOnPeriod: viewModel.isOnPeriod(date),
                        onTap: { viewModel.selectedDate = date }
                    )
                } else {
                    Color.clear
                        .frame(minHeight: 40)
                }
            }
        }
    }

    @ViewBuilder
    private func predictionsSummary(viewModel: CalendarViewModel) -> some View {
        let ps = viewModel.predictionService

        VStack(spacing: 12) {
            // Selected date info
            if let selected = viewModel.selectedDate {
                selectedDateCard(date: selected, viewModel: viewModel)
            }

            // Predictions
            if ps.currentCycle != nil {
                HStack(spacing: 12) {
                    if let nextPeriod = ps.predictedNextPeriodStart {
                        predictionCard(
                            title: "Next Period",
                            value: nextPeriod.shortFormatted,
                            subtitle: ps.daysUntilNextPeriod.map { "\($0) days" },
                            color: CyclePhase.menstrual.color
                        )
                    }

                    if let ovulation = ps.predictedOvulationDate {
                        predictionCard(
                            title: "Ovulation",
                            value: ovulation.shortFormatted,
                            subtitle: ps.currentCycle?.isOvulationConfirmed == true ? "Confirmed" : "Estimated",
                            color: CyclePhase.ovulation.color
                        )
                    }
                }
            }

            // Phase legend + info panel
            phaseLegendAndInfo()
        }
    }

    private func selectedDateCard(date: Date, viewModel: CalendarViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.headline)

                if let cycleDay = viewModel.cycleDayFor(date) {
                    Text("Cycle Day \(cycleDay)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let phase = viewModel.phaseForDate(date) {
                Text(phase.label)
                    .font(.subheadline.bold())
                    .foregroundStyle(phase.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(phase.color.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(BloomTheme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func predictionCard(title: String, value: String, subtitle: String?, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func phaseLegendAndInfo() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Letter legend row
            HStack(spacing: 14) {
                ForEach(CyclePhase.allCases) { phase in
                    HStack(spacing: 4) {
                        Text(phase.abbreviation)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(phase.color)
                            .frame(width: 16, height: 16)
                            .background(phase.color.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text(phase.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Phase descriptions
            VStack(alignment: .leading, spacing: 10) {
                Text("Cycle Phases")
                    .font(.subheadline.bold())

                ForEach(CyclePhase.allCases) { phase in
                    phaseInfoRow(phase)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(BloomTheme.cardFill)
        }
    }

    private func phaseInfoRow(_ phase: CyclePhase) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(phase.abbreviation)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(phase.color)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(phase.label)
                    .font(.caption.bold())
                    .foregroundStyle(phase.color)
                Text(phase.detailedDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
