import Foundation

enum FlowIntensity: String, Codable, CaseIterable, Identifiable {
    case spotting
    case light
    case medium
    case heavy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spotting: "Spotting"
        case .light: "Light"
        case .medium: "Medium"
        case .heavy: "Heavy"
        }
    }
}
