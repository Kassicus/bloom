import SwiftUI

enum FertilityLevel: String, Codable, CaseIterable, Identifiable {
    case low
    case high
    case peak

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: "Low Fertility"
        case .high: "High Fertility"
        case .peak: "Peak Fertility"
        }
    }

    var color: Color {
        switch self {
        case .low: BloomTheme.pinkSoft
        case .high: BloomTheme.pinkMedium
        case .peak: BloomTheme.pinkDeep
        }
    }

    var recommendation: String {
        switch self {
        case .low: "Regular days"
        case .high: "Good time for intercourse"
        case .peak: "Best time for conception"
        }
    }
}
