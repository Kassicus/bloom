import SwiftUI

struct HealthKitSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            if !viewModel.isHealthKitAvailable {
                Section {
                    Text("HealthKit is not available on this device.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(viewModel.healthKitSyncStatus)
                            .foregroundStyle(statusColor)
                    }

                    Button(viewModel.healthKitEnabled ? "Disconnect" : "Connect to Apple Health") {
                        Task {
                            await viewModel.toggleHealthKit()
                        }
                    }
                } header: {
                    Text("Connection")
                } footer: {
                    Text("Bloom can read and write menstrual cycle data, basal body temperature, cervical mucus, ovulation test results, and sexual activity to Apple Health.")
                }

                if viewModel.healthKitEnabled {
                    Section {
                        Button("Sync Now") {
                            Task {
                                await viewModel.syncToHealthKit()
                            }
                        }
                        .disabled(viewModel.healthKitSyncStatus == "Syncing...")
                    } header: {
                        Text("Sync")
                    } footer: {
                        Text("Exports all logged data to Apple Health. Data already in Health will not be duplicated.")
                    }

                    Section("Data Synced") {
                        dataRow(icon: "drop.fill", label: "Menstrual Flow", color: BloomTheme.pinkAccent)
                        dataRow(icon: "thermometer", label: "Basal Body Temperature", color: BloomTheme.pinkDeep)
                        dataRow(icon: "drop", label: "Cervical Mucus Quality", color: BloomTheme.pinkMedium)
                        dataRow(icon: "testtube.2", label: "Ovulation Test Results", color: BloomTheme.pinkDeepest)
                        dataRow(icon: "heart.fill", label: "Sexual Activity", color: BloomTheme.pinkLight)
                    }
                }
            }
        }
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dataRow(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(BloomTheme.pinkDeep)
        }
    }

    private var statusColor: Color {
        switch viewModel.healthKitSyncStatus {
        case "Connected", "Synced": BloomTheme.pinkDeep
        case "Syncing...": BloomTheme.pinkMedium
        default: .secondary
        }
    }
}
