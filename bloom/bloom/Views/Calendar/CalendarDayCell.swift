import SwiftUI

struct CalendarDayCell: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let info: DayInfo
    let onTap: () -> Void
    var minCellHeight: CGFloat = 40

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 1) {
                Text("\(calendar.component(.day, from: date))")
                    .font(isToday ? .callout.bold() : .callout)
                    .foregroundStyle(foregroundColor)

                HStack(spacing: 2) {
                    // Phase letter indicator (hidden on period days, which are already shaded)
                    if let phase = info.phase, !info.isPeriod, !info.isPredictedPeriod {
                        Text(phase.abbreviation)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(phase.color.opacity(info.isProjected ? 0.6 : 1))
                    }

                    if let fertilityDot {
                        Circle()
                            .fill(fertilityDot)
                            .frame(width: info.isOvulationDay ? 6 : 4, height: info.isOvulationDay ? 6 : 4)
                    }
                }
                .frame(height: 10)
            }
            .frame(maxWidth: .infinity, minHeight: minCellHeight)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                if info.isPredictedPeriod {
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
        .accessibilityLabel(accessibilityText)
    }

    /// Fertile days get a dot in their fertility color; ovulation day's dot is larger.
    private var fertilityDot: Color? {
        guard let fertility = info.fertility,
              info.isInFertileWindow || fertility != .low,
              !info.isPeriod else { return nil }
        let color = fertility == .low ? FertilityLevel.high.color.opacity(0.5) : fertility.color
        return info.isProjected ? color.opacity(0.6) : color
    }

    private var backgroundColor: Color {
        if info.isPeriod {
            return CyclePhase.menstrual.color.opacity(0.25)
        }
        if info.isPredictedPeriod {
            return .clear
        }
        guard let phase = info.phase else { return .clear }
        return phase.color.opacity(info.isProjected ? 0.06 : 0.12)
    }

    private var foregroundColor: Color {
        if info.isPeriod || info.isPredictedPeriod {
            return CyclePhase.menstrual.color
        }
        return .primary
    }

    private var accessibilityText: String {
        var parts = [date.formatted(.dateTime.weekday(.wide).month(.wide).day())]
        if info.isPeriod { parts.append("period day") }
        if info.isPredictedPeriod { parts.append("predicted period") }
        if info.isOvulationDay { parts.append(info.isProjected ? "predicted ovulation" : "estimated ovulation") }
        if let fertility = info.fertility, info.isInFertileWindow || fertility != .low {
            parts.append(fertility.label)
        }
        return parts.joined(separator: ", ")
    }
}
