import SwiftUI

struct BBTEntryView: View {
    /// Stored temperature in °F.
    let temperature: Double?
    let unit: TemperatureUnit
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onClear: () -> Void
    let onStart: () -> Void
    /// Sets the temperature from typed text in `unit`; returns false if it isn't plausible.
    let onSubmit: (String) -> Bool

    @State private var text = ""
    @State private var isInvalid = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                Button(action: onDecrement) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Decrease temperature")

                VStack(spacing: 2) {
                    TextField("—", text: $text)
                        .keyboardType(.decimalPad)
                        .focused($isFocused)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 130)
                        .accessibilityLabel("Temperature in \(unit.symbol)")

                    Text(unit.symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(action: onIncrement) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Increase temperature")
            }

            if isInvalid {
                Text("Enter a temperature between \(unit.entryRangeDescription)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if temperature == nil, !isFocused {
                Button(action: onStart) {
                    Text("Tap to log temperature")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            } else if temperature != nil {
                Button {
                    isFocused = false
                    text = ""
                    onClear()
                } label: {
                    Text("Clear")
                        .font(.caption)
                        .foregroundStyle(BloomTheme.pinkDeepest)
                }
            }

            Text("Take your temperature first thing in the morning, before getting out of bed")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .onAppear { text = formattedTemperature }
        .onChange(of: temperature) {
            if !isFocused { text = formattedTemperature }
        }
        .onChange(of: unit) {
            text = formattedTemperature
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { commit() }
        }
        .toolbar {
            if isFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isFocused = false }
                        .bold()
                }
            }
        }
    }

    private var formattedTemperature: String {
        temperature.map { unit.format($0) } ?? ""
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            isInvalid = false
            if temperature != nil { onClear() }
            return
        }
        isInvalid = !onSubmit(trimmed)
        text = formattedTemperature
    }
}
