import SwiftUI
import SwiftData

struct DailyLogView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DailyLogViewModel?
    @State private var predictionService: PredictionService?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    logContent(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Daily Log")
            .onAppear {
                if viewModel == nil {
                    let ps = PredictionService(modelContext: modelContext)
                    ps.updatePredictions()
                    predictionService = ps
                    viewModel = DailyLogViewModel(modelContext: modelContext, predictionService: ps)
                }
            }
        }
    }

    @ViewBuilder
    private func logContent(viewModel: DailyLogViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Date navigator
                dateNavigator(viewModel: viewModel)

                // Fertile window banner
                if viewModel.isInFertileWindow {
                    fertileWindowBanner(viewModel: viewModel)
                }

                // Completion indicator
                completionRing(viewModel: viewModel)

                // Log sections
                periodSection(viewModel: viewModel)
                bbtSection(viewModel: viewModel)
                mucusSection(viewModel: viewModel)
                opkSection(viewModel: viewModel)
                intercourseSection(viewModel: viewModel)
                symptomSection(viewModel: viewModel)
                notesSection(viewModel: viewModel)
            }
            .padding()
        }
    }

    // MARK: - Date Navigator

    private func dateNavigator(viewModel: DailyLogViewModel) -> some View {
        HStack {
            Button(action: viewModel.previousDay) {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.dateText)
                    .font(.title3.bold())

                if !viewModel.currentDate.isToday {
                    Button("Go to Today", action: viewModel.goToToday)
                        .font(.caption)
                }
            }

            Spacer()

            Button(action: viewModel.nextDay) {
                Image(systemName: "chevron.right")
                    .font(.title3.bold())
            }
            .disabled(!viewModel.canGoForward)
            .opacity(viewModel.canGoForward ? 1 : 0.3)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Fertile Window Banner

    private func fertileWindowBanner(viewModel: DailyLogViewModel) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Fertile Window Active")
                    .font(.subheadline.bold())
                if let level = viewModel.currentFertilityLevel {
                    Text("\(level.label) — \(level.recommendation)")
                        .font(.caption)
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

    // MARK: - Completion

    private func completionRing(viewModel: DailyLogViewModel) -> some View {
        let fraction = viewModel.totalTrackableItems > 0
            ? Double(viewModel.completionItems) / Double(viewModel.totalTrackableItems)
            : 0

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 28, height: 28)

            Text("\(viewModel.completionItems) of \(viewModel.totalTrackableItems) logged")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Sections

    private func periodSection(viewModel: DailyLogViewModel) -> some View {
        logSection(title: "Period", icon: "drop.fill", color: CyclePhase.menstrual.color) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("On Period", isOn: Binding(
                    get: { viewModel.isOnPeriod },
                    set: { viewModel.isOnPeriod = $0 }
                ))

                if viewModel.isOnPeriod {
                    Picker("Flow", selection: Binding(
                        get: { viewModel.flowIntensity },
                        set: { viewModel.flowIntensity = $0 }
                    )) {
                        ForEach(FlowIntensity.allCases) { flow in
                            Text(flow.label).tag(flow)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private func bbtSection(viewModel: DailyLogViewModel) -> some View {
        logSection(title: "Temperature (BBT)", icon: "thermometer.medium", color: .blue) {
            VStack(spacing: 8) {
                BBTEntryView(
                    temperature: viewModel.bbtTemperature,
                    temperatureText: viewModel.temperatureText,
                    onIncrement: viewModel.incrementTemperature,
                    onDecrement: viewModel.decrementTemperature,
                    onClear: { viewModel.setTemperature(nil) },
                    onSet: { viewModel.setTemperature(97.5) }
                )

                EducationalTipView(
                    title: "Why track BBT?",
                    detail: "After ovulation, your temperature rises ~0.5-1.0\u{00B0}F and stays elevated. Tracking daily helps confirm when ovulation occurred and improves prediction accuracy for future cycles."
                )
            }
        }
    }

    private func mucusSection(viewModel: DailyLogViewModel) -> some View {
        logSection(title: "Cervical Mucus", icon: "drop", color: .teal) {
            VStack(spacing: 8) {
                MucusPickerView(selection: Binding(
                    get: { viewModel.cervicalMucus },
                    set: { viewModel.cervicalMucus = $0 }
                ))

                EducationalTipView(
                    title: "What to look for",
                    detail: "As ovulation approaches, mucus changes from dry/sticky to wet, slippery, and stretchy (like egg whites). Egg white cervical mucus is a strong sign of peak fertility."
                )
            }
        }
    }

    private func opkSection(viewModel: DailyLogViewModel) -> some View {
        logSection(title: "Ovulation Test (OPK)", icon: "testtube.2", color: .purple) {
            VStack(spacing: 8) {
                OPKLogView(selection: Binding(
                    get: { viewModel.opkResult },
                    set: { viewModel.opkResult = $0 }
                ))

                EducationalTipView(
                    title: "When to test",
                    detail: "Test in the afternoon or evening for best results. A positive OPK means ovulation is likely in 24-48 hours — the best time for intercourse is the day of and day after a positive test."
                )
            }
        }
    }

    private func intercourseSection(viewModel: DailyLogViewModel) -> some View {
        logSection(title: "Intercourse", icon: "heart.fill", color: .pink) {
            IntercourseLogView(
                hadIntercourse: Binding(
                    get: { viewModel.hadIntercourse },
                    set: { viewModel.hadIntercourse = $0 }
                ),
                fertilityLevel: viewModel.currentFertilityLevel,
                isInFertileWindow: viewModel.isInFertileWindow
            )
        }
    }

    private func symptomSection(viewModel: DailyLogViewModel) -> some View {
        logSection(title: "Symptoms", icon: "list.bullet.clipboard", color: .orange) {
            SymptomPickerView(
                symptoms: viewModel.symptoms,
                onToggle: viewModel.toggleSymptom
            )
        }
    }

    private func notesSection(viewModel: DailyLogViewModel) -> some View {
        logSection(title: "Notes", icon: "note.text", color: .secondary) {
            TextField("Add notes...", text: Binding(
                get: { viewModel.notes },
                set: { viewModel.notes = $0 }
            ), axis: .vertical)
            .lineLimit(3...6)
        }
    }

    // MARK: - Section Container

    private func logSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
            }

            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }
}
