import SwiftUI

struct FertilityIndicatorView: View {
    let level: FertilityLevel

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.caption)
                .foregroundStyle(level.color)
            Text(level.label)
                .font(.caption.bold())
                .foregroundStyle(level.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(level.color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var iconName: String {
        switch level {
        case .low: "circle"
        case .high: "circle.inset.filled"
        case .peak: "circle.fill"
        }
    }
}
