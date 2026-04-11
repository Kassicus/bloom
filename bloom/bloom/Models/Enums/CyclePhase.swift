import SwiftUI

enum CyclePhase: String, Codable, CaseIterable, Identifiable {
    case menstrual
    case follicular
    case ovulation
    case luteal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .menstrual: "Menstrual"
        case .follicular: "Follicular"
        case .ovulation: "Ovulation"
        case .luteal: "Luteal"
        }
    }

    var color: Color {
        switch self {
        case .menstrual: Color(.systemPink)
        case .follicular: Color(.systemPurple)
        case .ovulation: Color(.systemOrange)
        case .luteal: Color(.systemTeal)
        }
    }

    var description: String {
        switch self {
        case .menstrual: "Period days"
        case .follicular: "Building up to ovulation"
        case .ovulation: "Most fertile days"
        case .luteal: "Post-ovulation"
        }
    }
}
