import SwiftUI

struct PeriodLoggingSheet: View {
    let viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date = Date.now
    @State private var flowIntensity: FlowIntensity = .medium
    @State private var isEndingPeriod = false
    @State private var endDate: Date = Date.now

    private var hasActivePeriod: Bool {
        guard let cycle = viewModel.predictionService.currentCycle else { return false }
        return cycle.endDate == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if hasActivePeriod {
                    endPeriodSection
                } else {
                    startPeriodSection
                }
            }
            .navigationTitle(hasActivePeriod ? "End Period" : "Log Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var startPeriodSection: some View {
        Group {
            Section {
                DatePicker(
                    "Period Start",
                    selection: $startDate,
                    in: ...Date.now,
                    displayedComponents: .date
                )
            } header: {
                Text("When did your period start?")
            }

            Section {
                Picker("Flow Intensity", selection: $flowIntensity) {
                    ForEach(FlowIntensity.allCases) { flow in
                        Text(flow.label).tag(flow)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("How heavy is the flow?")
            }
        }
    }

    private var endPeriodSection: some View {
        Group {
            if let cycle = viewModel.predictionService.currentCycle {
                Section {
                    HStack {
                        Text("Period started")
                        Spacer()
                        Text(cycle.startDate.shortFormatted)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    DatePicker(
                        "Last Day of Period",
                        selection: $endDate,
                        in: cycle.startDate...Date.now,
                        displayedComponents: .date
                    )
                } header: {
                    Text("When did your period end?")
                }
            }
        }
    }

    private func save() {
        if hasActivePeriod {
            viewModel.endPeriod(on: endDate)
        } else {
            viewModel.startPeriod(on: startDate, flow: flowIntensity)
        }
    }
}
