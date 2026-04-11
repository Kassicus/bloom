import SwiftUI

struct CalendarDayCell: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let phase: CyclePhase?
    let fertility: FertilityLevel?
    let isOnPeriod: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(isToday ? .callout.bold() : .callout)
                    .foregroundStyle(foregroundColor)

                // Fertility dot
                if let fertility {
                    Circle()
                        .fill(fertility.color)
                        .frame(width: 5, height: 5)
                } else {
                    Circle()
                        .fill(.clear)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.primary, lineWidth: 1.5)
                }
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isOnPeriod {
            return CyclePhase.menstrual.color.opacity(0.25)
        }
        guard let phase else { return .clear }
        return phase.color.opacity(0.12)
    }

    private var foregroundColor: Color {
        if isOnPeriod {
            return CyclePhase.menstrual.color
        }
        return .primary
    }
}
