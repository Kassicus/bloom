import SwiftUI

struct SymptomPickerView: View {
    let symptoms: Set<Symptom>
    let onToggle: (Symptom) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(SymptomCategory.allCases) { category in
                VStack(alignment: .leading, spacing: 8) {
                    Text(category.rawValue)
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(symptomsFor(category)) { symptom in
                            symptomChip(symptom)
                        }
                    }
                }
            }
        }
    }

    private func symptomChip(_ symptom: Symptom) -> some View {
        let isSelected = symptoms.contains(symptom)

        return Button {
            onToggle(symptom)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: symptom.icon)
                    .font(.caption)
                Text(symptom.label)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.accentColor, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func symptomsFor(_ category: SymptomCategory) -> [Symptom] {
        Symptom.allCases.filter { $0.category == category }
    }
}
