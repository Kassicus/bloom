import SwiftUI

struct OPKLogView: View {
    @Binding var selection: OPKResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ForEach(OPKResult.allCases) { result in
                    opkCard(result)
                }
            }

            if let selected = selection {
                HStack(spacing: 6) {
                    Image(systemName: selected == .positive ? "exclamationmark.circle.fill" : "info.circle")
                        .font(.caption)
                    Text(selected.description)
                        .font(.caption)
                }
                .foregroundStyle(selected == .positive ? FertilityLevel.peak.color : .secondary)
                .padding(.horizontal, 4)
            }
        }
    }

    private func opkCard(_ result: OPKResult) -> some View {
        let isSelected = selection == result

        return Button {
            if selection == result {
                selection = nil
            } else {
                selection = result
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: iconName(for: result))
                    .font(.title3)
                    .foregroundStyle(iconColor(for: result))

                Text(result.label)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? iconColor(for: result).opacity(0.12) : Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(iconColor(for: result), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func iconName(for result: OPKResult) -> String {
        switch result {
        case .negative: "minus.circle"
        case .nearPositive: "circle.dotted.circle"
        case .positive: "plus.circle.fill"
        }
    }

    private func iconColor(for result: OPKResult) -> Color {
        switch result {
        case .negative: .secondary
        case .nearPositive: .orange
        case .positive: FertilityLevel.peak.color
        }
    }
}
