import SwiftUI

struct IntercourseLogView: View {
    let entries: [IntercourseEntry]
    let fertilityLevel: FertilityLevel?
    let isInFertileWindow: Bool
    let onAdd: (Date) -> Void
    let onRemove: (IntercourseEntry) -> Void
    let onUpdateTime: (IntercourseEntry, Date) -> Void

    @State private var showingTimePicker = false
    @State private var newEntryTime = Date.now
    @State private var editingEntry: IntercourseEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Existing entries
            if !entries.isEmpty {
                ForEach(entries, id: \.dateTime) { entry in
                    entryRow(entry)
                }
            }

            // Add button
            Button {
                newEntryTime = Date.now
                showingTimePicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text(entries.isEmpty ? "Log Intercourse" : "Add Another")
                        .font(.subheadline)
                }
            }

            // Fertility context
            if !entries.isEmpty, let level = fertilityLevel {
                HStack(spacing: 6) {
                    Image(systemName: timingIcon(for: level))
                        .font(.caption)
                    Text(timingMessage(for: level))
                        .font(.caption)
                }
                .foregroundStyle(level.color)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(level.color.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .sheet(isPresented: $showingTimePicker) {
            timePickerSheet
        }
        .sheet(item: $editingEntry) { entry in
            editTimeSheet(entry: entry)
        }
    }

    // MARK: - Entry Row

    private func entryRow(_ entry: IntercourseEntry) -> some View {
        HStack {
            Image(systemName: "heart.fill")
                .font(.caption)
                .foregroundStyle(BloomTheme.pinkAccent)

            Text(entry.timeFormatted)
                .font(.subheadline)

            Spacer()

            Button {
                editingEntry = entry
            } label: {
                Image(systemName: "pencil.circle")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Button(role: .destructive) {
                onRemove(entry)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Time Picker Sheet (Add)

    private var timePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("What time?")
                    .font(.headline)

                DatePicker("Time", selection: $newEntryTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()

                Spacer()
            }
            .padding()
            .navigationTitle("Log Intercourse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingTimePicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onAdd(newEntryTime)
                        showingTimePicker = false
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Edit Time Sheet

    private func editTimeSheet(entry: IntercourseEntry) -> some View {
        EditIntercourseTimeSheet(entry: entry) { newTime in
            onUpdateTime(entry, newTime)
            editingEntry = nil
        } onCancel: {
            editingEntry = nil
        }
    }

    // MARK: - Helpers

    private func timingIcon(for level: FertilityLevel) -> String {
        switch level {
        case .peak: "sparkles"
        case .high: "sparkle"
        case .low: "leaf"
        }
    }

    private func timingMessage(for level: FertilityLevel) -> String {
        switch level {
        case .peak:
            "Great timing! This is the best time for conception."
        case .high:
            "Good timing — you're in the fertile window."
        case .low:
            if isInFertileWindow {
                "You're at the edge of your fertile window."
            } else {
                "Outside the fertile window this cycle."
            }
        }
    }
}

// MARK: - Edit Sheet (separate struct for @State management)

private struct EditIntercourseTimeSheet: View {
    let entry: IntercourseEntry
    let onSave: (Date) -> Void
    let onCancel: () -> Void

    @State private var selectedTime: Date

    init(entry: IntercourseEntry, onSave: @escaping (Date) -> Void, onCancel: @escaping () -> Void) {
        self.entry = entry
        self.onSave = onSave
        self.onCancel = onCancel
        self._selectedTime = State(initialValue: entry.dateTime)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Edit time")
                    .font(.headline)

                DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()

                Spacer()
            }
            .padding()
            .navigationTitle("Edit Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(selectedTime) }
                        .bold()
                }
            }
        }
        .presentationDetents([.medium])
    }
}

