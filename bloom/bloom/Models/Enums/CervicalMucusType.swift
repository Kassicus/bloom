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

    var detailedDescription: String {
        switch self {
        case .dry:
            "Little to no mucus present. Common right after your period and during the luteal phase. Sperm survival is limited in dry conditions."
        case .sticky:
            "Thick, tacky, or crumbly mucus that breaks easily. Sperm have difficulty traveling through this type. Typical in the early follicular phase as estrogen begins to rise."
        case .creamy:
            "Smooth, lotion-like, whitish mucus. Some sperm can survive but conditions are not yet optimal. Estrogen is rising and ovulation may be approaching."
        case .watery:
            "Clear, thin, and wet mucus. Indicates rising estrogen and approaching ovulation. Sperm can survive several days in this environment."
        case .eggWhite:
            "Clear, stretchy, and slippery \u{2014} similar to raw egg whites. This is the most fertile mucus type. It nourishes sperm and helps them travel to the egg. Sperm can survive up to 5 days in egg white cervical mucus."
        }
    }
}
