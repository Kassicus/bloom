import SwiftUI

enum CyclePhase: String, Codable, CaseIterable, Identifiable {
    case menstrual
    case follicular
    case ovulation
    case luteal

    var id: String { rawValue }

    var abbreviation: String {
        switch self {
        case .menstrual: "M"
        case .follicular: "F"
        case .ovulation: "O"
        case .luteal: "L"
        }
    }

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
        case .menstrual: BloomTheme.pinkAccent
        case .follicular: BloomTheme.pinkLight
        case .ovulation: BloomTheme.pinkDeep
        case .luteal: BloomTheme.pinkMedium
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

    var detailedDescription: String {
        switch self {
        case .menstrual:
            "Your uterine lining is shedding. Estrogen and progesterone are at their lowest, signaling your body to begin developing a new egg. A typical period lasts 3-7 days."
        case .follicular:
            "Your body is preparing to ovulate. Rising estrogen stimulates follicle growth in the ovaries. You may notice increasing energy, improved mood, and changes in cervical mucus becoming wetter and more slippery as ovulation approaches."
        case .ovulation:
            "An egg is released from the ovary and travels down the fallopian tube. This is triggered by a surge in luteinizing hormone (LH). The egg is viable for only 12-24 hours after release, making this the most time-sensitive part of your cycle for conception."
        case .luteal:
            "The empty follicle transforms into the corpus luteum and produces progesterone, which thickens the uterine lining for possible implantation. If the egg is not fertilized, progesterone drops after about 10-14 days, triggering your next period."
        }
    }
}
