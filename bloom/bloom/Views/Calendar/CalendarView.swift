import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(AppNavigation.self) private var navigation
    let predictionService: PredictionService
    @State private var viewModel: CalendarViewModel?
    @State private var periodToDelete: Date?

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
                    BloomTheme.brandText("Calendar")
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
                    viewModel = CalendarViewModel(predictionService: predictionService)
                }
                showRequestedPeriodSheet()
            }
            .onChange(of: navigation.requestedPeriodSheet) {
                showRequestedPeriodSheet()
            }
        }
    }

    private func showRequestedPeriodSheet() {
        guard navigation.requestedPeriodSheet, let viewModel else { return }
        viewModel.showingPeriodSheet = true
        navigation.requestedPeriodSheet = false
    }

    private var isWide: Bool { sizeClass == .regular }

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
                    CycleTimelineView(predictionService: viewModel.predictionService)
                        .padding(.top, 8)
                }
            }
            .padding(isWide ? 24 : 16)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var cellHeight: CGFloat { isWide ? 56 : 40 }

    private func monthHeader(viewModel: CalendarViewModel) -> some View {
        HStack {
            Button(action: viewModel.previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.monthTitle)
                    .font(.title2.bold())

                if !viewModel.isShowingCurrentMonth {
                    Button("Today", action: viewModel.goToToday)
                        .font(.caption)
                }
            }

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
        let dayInfo = viewModel.monthDayInfo

        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(viewModel.daysInMonthGrid.enumerated()), id: \.offset) { _, date in
                if let date {
                    CalendarDayCell(
                        date: date,
                        isToday: date.isToday,
                        isSelected: viewModel.selectedDate?.startOfDay == date.startOfDay,
                        info: dayInfo[date.startOfDay] ?? DayInfo(),
                        onTap: { viewModel.selectedDate = date },
                        minCellHeight: cellHeight
                    )
                } else {
                    Color.clear
                        .frame(minHeight: cellHeight)
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
                            subtitle: ps.daysPeriodLate.map { "\($0) day\($0 == 1 ? "" : "s") late" }
                                ?? ps.daysUntilNextPeriod.map { "in \($0) day\($0 == 1 ? "" : "s")" },
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
        let info = viewModel.dayInfo(for: date)
        let isPastOrToday = date.startOfDay <= Date.now.startOfDay

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.headline)

                    if let cycleDay = info.cycleDay {
                        Text(info.isProjected ? "Predicted cycle day \(cycleDay)" : "Cycle Day \(cycleDay)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let phase = info.phase {
                    Text(phase.label)
                        .font(.subheadline.bold())
                        .foregroundStyle(phase.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(phase.color.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            if let fertility = info.fertility, info.isInFertileWindow || fertility != .low {
                HStack(spacing: 6) {
                    Image(systemName: info.isOvulationDay ? "sparkles" : "sparkle")
                    Text(info.isOvulationDay ? "\(fertility.label) \u{00B7} likely ovulation day" : fertility.label)
                }
                .font(.caption.bold())
                .foregroundStyle(fertility.color)
            }

            if viewModel.canTogglePeriod(on: date) {
                Divider()

                Toggle(isOn: Binding(
                    get: { info.isPeriod },
                    set: { _ in viewModel.togglePeriod(on: date) }
                )) {
                    Label("Period day", systemImage: "drop.fill")
                        .foregroundStyle(CyclePhase.menstrual.color)
                }
                .tint(CyclePhase.menstrual.color)

                HStack {
                    if info.isPeriod {
                        Button("Delete This Period", role: .destructive) {
                            periodToDelete = date
                        }
                    }

                    Spacer()

                    if isPastOrToday {
                        Button("Open Daily Log") {
                            navigation.openLog(for: date)
                        }
                    }
                }
                .font(.subheadline)
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(BloomTheme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .confirmationDialog(
            "Delete this period?",
            isPresented: Binding(get: { periodToDelete != nil }, set: { if !$0 { periodToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Period", role: .destructive) {
                if let periodToDelete {
                    viewModel.deletePeriod(containing: periodToDelete)
                }
                periodToDelete = nil
            }
        } message: {
            Text("All days of this period will be unmarked. Your other logs for these days are kept.")
        }
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

            HStack(spacing: 14) {
                // Logged period
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(CyclePhase.menstrual.color.opacity(0.25))
                        .frame(width: 16, height: 16)
                    Text("Period")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Estimated next period marker
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            CyclePhase.menstrual.color,
                            style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])
                        )
                        .frame(width: 16, height: 16)
                    Text("Predicted period")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Fertile days
                HStack(spacing: 4) {
                    Circle()
                        .fill(FertilityLevel.peak.color)
                        .frame(width: 6, height: 6)
                        .frame(width: 16, height: 16)
                    Text("Fertile day")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
