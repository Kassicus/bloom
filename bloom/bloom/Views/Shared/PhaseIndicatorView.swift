import SwiftUI

struct PhaseIndicatorView: View {
    let phase: CyclePhase

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(phase.color)
                .frame(width: 10, height: 10)
            Text(phase.label)
                .font(.subheadline)
                .foregroundStyle(phase.color)
        }
    }
}
