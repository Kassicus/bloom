import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    let predictionService: PredictionService
    @State private var viewModel: SettingsViewModel?
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(BloomTheme.sectionTitle)
                        .foregroundStyle(BloomTheme.brand)
                }
            }
            .onAppear {
                if viewModel == nil {
                    let vm = SettingsViewModel(modelContext: modelContext, predictionService: predictionService)
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
                            .foregroundStyle(BloomTheme.pinkMedium)
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
                            .foregroundStyle(BloomTheme.pinkDeep)
                            .frame(width: 24)
                        Text("HealthKit Integration")
                        Spacer()
                        Text(viewModel.healthKitEnabled ? "On" : "Off")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Display") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "paintpalette.fill")
                            .foregroundStyle(BloomTheme.brand)
                            .frame(width: 24)
                        Text("Theme")
                    }

                    HStack(spacing: 12) {
                        ForEach(AppTheme.allCases) { theme in
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    viewModel.selectedTheme = theme
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    HStack(spacing: 4) {
                                        ForEach(theme.swatchColors, id: \.self) { color in
                                            Circle()
                                                .fill(color)
                                                .frame(width: 18, height: 18)
                                        }
                                    }
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(theme.colors.faintest)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(
                                                viewModel.selectedTheme == theme ? theme.colors.brand : .clear,
                                                lineWidth: 2
                                            )
                                    )

                                    Text(theme.label)
                                        .font(.caption)
                                        .foregroundStyle(viewModel.selectedTheme == theme ? BloomTheme.brand : .secondary)

                                    Text(theme.description)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 4)

                Toggle(isOn: Binding(
                    get: { viewModel.useCelsius },
                    set: {
                        viewModel.useCelsius = $0
                        viewModel.savePreferences()
                    }
                )) {
                    HStack {
                        Image(systemName: "thermometer")
                            .foregroundStyle(BloomTheme.pinkMedium)
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

            Section("iCloud Sync") {
                HStack {
                    Image(systemName: "icloud.fill")
                        .foregroundStyle(BloomTheme.brand)
                        .frame(width: 24)
                    Text("Sync Status")
                    Spacer()
                    Text(FileManager.default.ubiquityIdentityToken != nil ? "Active" : "Unavailable")
                        .foregroundStyle(FileManager.default.ubiquityIdentityToken != nil ? .green : .secondary)
                }

                if FileManager.default.ubiquityIdentityToken != nil {
                    Text("Your data syncs automatically across all devices signed into the same iCloud account.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Sign in to iCloud in Settings to enable sync across your devices.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1")
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
