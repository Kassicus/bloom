import SwiftUI

struct CycleRingView: View {
    let segments: [(phase: CyclePhase, start: Double, end: Double)]
    let progress: Double
    let cycleDay: Int?
    let phase: CyclePhase?

    private let lineWidth: CGFloat = 14
    var ringSize: CGFloat = 220

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)

            // Phase segments
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                phaseArc(segment: segment)
            }

            // Today marker
            if progress > 0 {
                todayMarker
            }

            // Center content
            centerContent
        }
        .frame(width: ringSize, height: ringSize)
    }

    private func phaseArc(segment: (phase: CyclePhase, start: Double, end: Double)) -> some View {
        Circle()
            .trim(from: segment.start, to: segment.end)
            .stroke(
                segment.phase.color,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
            )
            .rotationEffect(.degrees(-90))
    }

    private var todayMarker: some View {
        let angle = Angle.degrees(progress * 360 - 90)
        let radius = (ringSize - lineWidth) / 2

        return Circle()
            .fill(.white)
            .frame(width: lineWidth + 6, height: lineWidth + 6)
            .overlay {
                Circle()
                    .fill(phase?.color ?? .accentColor)
                    .frame(width: lineWidth, height: lineWidth)
            }
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            .offset(
                x: cos(angle.radians) * radius,
                y: sin(angle.radians) * radius
            )
    }

    private var centerContent: some View {
        VStack(spacing: 4) {
            if let day = cycleDay {
                Text("Day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(day)")
                    .font(BloomTheme.appTitle)
                if let phase {
                    Text(phase.label)
                        .font(.caption.bold())
                        .foregroundStyle(phase.color)
                }
            } else {
                Image(systemName: "leaf")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Log a period\nto begin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
