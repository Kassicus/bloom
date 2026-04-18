import SwiftUI

struct CalendarDayCell: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let phase: CyclePhase?
    let fertility: FertilityLevel?
    let isOnPeriod: Bool
    var isPredictedNextPeriod: Bool = false
    let onTap: () -> Void
    var minCellHeight: CGFloat = 40

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 1) {
                Text("\(calendar.component(.day, from: date))")
                    .font(isToday ? .callout.bold() : .callout)
                    .foregroundStyle(foregroundColor)

                // Phase letter indicator (hidden for predicted-next-period marker)
                if let phase, !isPredictedNextPeriod {
                    Text(phase.abbreviation)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(phase.color)
                } else {
                    Text(" ")
                        .font(.system(size: 8))
                }
            }
            .frame(maxWidth: .infinity, minHeight: minCellHeight)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                if isPredictedNextPeriod {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            CyclePhase.menstrual.color,
                            style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])
                        )
                }
                if isToday {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.primary, lineWidth: 1.5)
                }
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(BloomTheme.pinkAccent, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isOnPeriod {
            return CyclePhase.menstrual.color.opacity(0.25)
        }
        if isPredictedNextPeriod {
            return .clear
        }
        guard let phase else { return .clear }
        return phase.color.opacity(0.12)
    }

    private var foregroundColor: Color {
        if isOnPeriod || isPredictedNextPeriod {
            return CyclePhase.menstrual.color
        }
        return .primary
    }
}
