import SwiftUI

struct NotificationSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            if !viewModel.notificationPermissionGranted {
                Section {
                    Button("Enable Notifications") {
                        Task {
                            await viewModel.requestNotificationPermission()
                        }
                    }
                } footer: {
                    Text("Bloom needs permission to send you reminders.")
                }
            }

            Section {
                Toggle("BBT Morning Reminder", isOn: $viewModel.bbtReminderEnabled)

                if viewModel.bbtReminderEnabled {
                    HStack {
                        Text("Reminder Time")
                        Spacer()
                        Picker("Hour", selection: $viewModel.bbtReminderHour) {
                            ForEach(4..<10, id: \.self) { hour in
                                Text("\(hour):00").tag(hour)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)

                        Text(":")

                        Picker("Minute", selection: $viewModel.bbtReminderMinute) {
                            Text("00").tag(0)
                            Text("15").tag(15)
                            Text("30").tag(30)
                            Text("45").tag(45)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }
            } header: {
                Text("Temperature")
            } footer: {
                Text("Set this for when you normally wake up, before getting out of bed.")
            }

            Section {
                Toggle("Period Prediction", isOn: $viewModel.periodReminderEnabled)
            } header: {
                Text("Period")
            } footer: {
                Text("Get notified on the day your period is expected to start.")
            }

            Section {
                Toggle("Fertile Window & Ovulation", isOn: $viewModel.fertileWindowAlertEnabled)
            } header: {
                Text("Fertility")
            } footer: {
                Text("Get alerted the day before your fertile window opens and on your estimated ovulation day.")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}
