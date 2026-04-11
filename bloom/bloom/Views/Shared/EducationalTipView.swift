import SwiftUI

struct EducationalTipView: View {
    let title: String
    let detail: String

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
    }
}
