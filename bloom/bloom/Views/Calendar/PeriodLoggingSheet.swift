import SwiftUI

struct PeriodLoggingSheet: View {
    let viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss

    private enum Mode: Hashable {
        case started
        case ended
    }

    @State private var mode: Mode = .started
    @State private var startDate: Date = Date.now
    @State private var flowIntensity: FlowIntensity = .medium
    @State private var endDate: Date = Date.now

    var body: some View {
        NavigationStack {
            Form {
                if let ongoingStart = viewModel.ongoingPeriodStart {
                    Section {
                        Picker("What happened?", selection: $mode) {
                            Text("Period started").tag(Mode.started)
                            Text("Period ended").tag(Mode.ended)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                    }

                    if mode == .ended {
                        endPeriodSection(start: ongoingStart)
                    } else {
                        startPeriodSection
                    }
                } else {
                    startPeriodSection
                }
            }
            .navigationTitle("Log Period")
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
            .onAppear {
                endDate = viewModel.suggestedPeriodEnd
            }
        }
        .presentationDetents([.medium, .large])
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
            } footer: {
                Text("Bloom marks \(viewModel.expectedPeriodLength) days as your period. You can turn individual days on or off from the calendar or the Log tab.")
            }
        }
    }

    private func endPeriodSection(start: Date) -> some View {
        Group {
            Section {
                HStack {
                    Text("Period started")
                    Spacer()
                    Text(start.shortFormatted)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                DatePicker(
                    "Last Day of Period",
                    selection: $endDate,
                    in: start...min(Date.now, start.addingDays(BloomConstants.maxPlausiblePeriodLength - 1)),
                    displayedComponents: .date
                )
            } header: {
                Text("When was the last day of your period?")
            }
        }
    }

    private func save() {
        if mode == .ended, viewModel.ongoingPeriodStart != nil {
            viewModel.endPeriod(lastDay: endDate)
        } else {
            viewModel.logPeriodStart(on: startDate, flow: flowIntensity)
        }
    }
}
