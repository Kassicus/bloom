import SwiftUI

struct MucusPickerView: View {
    @Binding var selection: CervicalMucusType?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CervicalMucusType.allCases) { type in
                        mucusCard(type)
                    }
                }
                .padding(.horizontal, 1)
            }

            if let selected = selection {
                Text(selected.fertilityDescription)
                    .font(.caption)
                    .foregroundStyle(fertilityColor(for: selected))
                    .padding(.horizontal, 4)
            }
        }
    }

    private func mucusCard(_ type: CervicalMucusType) -> some View {
        let isSelected = selection == type

        return Button {
            if selection == type {
                selection = nil
            } else {
                selection = type
            }
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(mucusVisual(for: type))
                    .frame(width: 32, height: 32)

                Text(type.label)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(width: 68)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accentColor, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func mucusVisual(for type: CervicalMucusType) -> some ShapeStyle {
        switch type {
        case .dry: return AnyShapeStyle(BloomTheme.pinkPale.opacity(0.5))
        case .sticky: return AnyShapeStyle(BloomTheme.pinkSoft.opacity(0.6))
        case .creamy: return AnyShapeStyle(BloomTheme.pinkLight.opacity(0.7))
        case .watery: return AnyShapeStyle(BloomTheme.pinkMedium.opacity(0.5))
        case .eggWhite: return AnyShapeStyle(BloomTheme.pinkAccent.opacity(0.3))
        }
    }

    private func fertilityColor(for type: CervicalMucusType) -> Color {
        switch type {
        case .dry, .sticky: return .secondary
        case .creamy: return BloomTheme.pinkMedium
        case .watery, .eggWhite: return BloomTheme.pinkDeep
        }
    }
}
