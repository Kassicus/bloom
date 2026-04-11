import SwiftUI

struct IntercourseLogView: View {
    @Binding var hadIntercourse: Bool
    let fertilityLevel: FertilityLevel?
    let isInFertileWindow: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Log Intercourse", isOn: $hadIntercourse)

            if hadIntercourse, let level = fertilityLevel {
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
    }

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
