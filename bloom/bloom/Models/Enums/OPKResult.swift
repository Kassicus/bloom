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
        case .nearPositive: "LH rising \u{2014} test again tomorrow"
        case .positive: "LH surge detected \u{2014} ovulation likely in 24-48 hours"
        }
    }

    var detailedDescription: String {
        switch self {
        case .negative:
            "The test line is lighter than the control line. Continue testing daily, ideally in the afternoon when LH concentration in urine is highest. LH surges can be brief (12-24 hours), so testing twice daily near your expected ovulation can help catch it."
        case .nearPositive:
            "The test line is close to the control line's intensity. Your LH is rising and ovulation may be 1-2 days away. Test again in 12 hours for a clearer result. This is a good time to begin timing intercourse."
        case .positive:
            "The test line is as dark or darker than the control line, confirming an LH surge. Ovulation typically occurs 24-48 hours after the surge begins. The day of and day after a positive OPK are the highest-probability days for conception."
        }
    }
}
