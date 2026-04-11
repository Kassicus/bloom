import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?
    @State private var predictionService: PredictionService?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    settingsContent(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                if viewModel == nil {
                    let ps = PredictionService(modelContext: modelContext)
                    ps.updatePredictions()
                    predictionService = ps
                    let vm = SettingsViewModel(modelContext: modelContext, predictionService: ps)
                    vm.loadPreferences()
                    viewModel = vm
                }
            }
        }
    }

    private func settingsContent(viewModel: SettingsViewModel) -> some View {
        Form {
            Section("Notifications") {
                NavigationLink {
                    NotificationSettingsView(viewModel: viewModel)
                } label: {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundStyle(.orange)
                            .frame(width: 24)
                        Text("Reminders")
                    }
                }
            }

            Section("Apple Health") {
                NavigationLink {
                    HealthKitSettingsView(viewModel: viewModel)
                } label: {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                            .frame(width: 24)
                        Text("HealthKit Integration")
                        Spacer()
                        Text(viewModel.healthKitEnabled ? "On" : "Off")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Display") {
                Toggle(isOn: Binding(
                    get: { viewModel.useCelsius },
                    set: {
                        viewModel.useCelsius = $0
                        viewModel.savePreferences()
                    }
                )) {
                    HStack {
                        Image(systemName: "thermometer")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text("Temperature in \u{00B0}C")
                    }
                }
            }

            Section("Data") {
                HStack {
                    Text("Cycles")
                    Spacer()
                    Text("\(viewModel.totalCycleCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Daily Logs")
                    Spacer()
                    Text("\(viewModel.totalLogCount)")
                        .foregroundStyle(.secondary)
                }

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .frame(width: 24)
                        Text("Delete All Data")
                    }
                }
                .confirmationDialog(
                    "Delete all cycle and log data? This cannot be undone.",
                    isPresented: $showingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete All Data", role: .destructive) {
                        viewModel.deleteAllData()
                    }
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Bloom")
                    Spacer()
                    Text("Fertility & Cycle Tracking")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
