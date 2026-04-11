import SwiftUI

struct BBTEntryView: View {
    let temperature: Double?
    let temperatureText: String
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onClear: () -> Void
    let onSet: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                Button(action: onDecrement) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 2) {
                    Text(temperatureText)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    if temperature != nil {
                        Text("\u{00B0}F")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 90)

                Button(action: onIncrement) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }

            if temperature == nil {
                Button(action: onSet) {
                    Text("Tap to log temperature")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            } else {
                Button(action: onClear) {
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
    }
}
