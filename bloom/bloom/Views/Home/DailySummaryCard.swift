import SwiftUI

struct DailySummaryCard: View {
    let loggedItems: [String]
    let hasData: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today's Log")
                    .font(.headline)
                Spacer()
                if hasData {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BloomTheme.pinkDeep)
                }
            }

            if hasData {
                FlowLayout(spacing: 8) {
                    ForEach(loggedItems, id: \.self) { item in
                        Text(item)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            } else {
                HStack {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.secondary)
                    Text("Tap to log today's data")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }
}

/// Simple horizontal flow layout that wraps chips to the next line.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private struct LayoutResult {
        var positions: [CGPoint]
        var size: CGSize
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return LayoutResult(
            positions: positions,
            size: CGSize(width: maxX, height: y + rowHeight)
        )
    }
}
