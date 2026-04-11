import Foundation

enum OPKResult: String, Codable, CaseIterable, Identifiable {
    case negative
    case nearPositive
    case positive

    var id: String { rawValue }

    var label: String {
        switch self {
        case .negative: "Negative"
        case .nearPositive: "Near Positive"
        case .positive: "Positive"
        }
    }

    var description: String {
        switch self {
        case .negative: "No LH surge detected"
        case .nearPositive: "LH rising — test again tomorrow"
        case .positive: "LH surge detected — ovulation likely in 24-48 hours"
        }
    }
}
