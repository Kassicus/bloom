import SwiftUI

struct FertilityBadgeView: View {
    let level: FertilityLevel?
    let recommendation: String

    var body: some View {
        HStack(spacing: 12) {
            if let level {
                Image(systemName: iconName(for: level))
                    .font(.title2)
                    .foregroundStyle(level.color)
                    .frame(width: 40, height: 40)
                    .background(level.color.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.label)
                        .font(.headline)
                        .foregroundStyle(level.color)
                    Text(recommendation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            } else {
                Image(systemName: "leaf")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .background(.secondary.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("No Data Yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(recommendation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(badgeBackground)
        }
    }

    private var badgeBackground: some ShapeStyle {
        if let level {
            return AnyShapeStyle(level.color.opacity(0.08))
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    private func iconName(for level: FertilityLevel) -> String {
        switch level {
        case .low: "leaf"
        case .high: "sparkle"
        case .peak: "sparkles"
        }
    }
}
