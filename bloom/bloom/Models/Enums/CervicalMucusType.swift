import Foundation

/// Ordered from least to most fertile.
/// `eggWhite` represents peak-fertility "egg white cervical mucus" (EWCM).
enum CervicalMucusType: String, Codable, CaseIterable, Identifiable {
    case dry
    case sticky
    case creamy
    case watery
    case eggWhite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dry: "Dry"
        case .sticky: "Sticky"
        case .creamy: "Creamy"
        case .watery: "Watery"
        case .eggWhite: "Egg White"
        }
    }

    var fertilityDescription: String {
        switch self {
        case .dry: "Not fertile"
        case .sticky: "Low fertility"
        case .creamy: "Moderate fertility"
        case .watery: "High fertility"
        case .eggWhite: "Peak fertility"
        }
    }
}
