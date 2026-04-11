import Foundation

enum Symptom: String, Codable, CaseIterable, Identifiable {
    // Physical
    case cramps
    case headache
    case bloating
    case breastTenderness
    case backache
    case nausea
    case fatigue
    case acne

    // Mood
    case happy
    case sad
    case anxious
    case irritable
    case moodSwings
    case calm

    // Energy
    case energetic
    case tired
    case exhausted

    // Other
    case cravings
    case insomnia
    case highLibido
    case lowLibido

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cramps: "Cramps"
        case .headache: "Headache"
        case .bloating: "Bloating"
        case .breastTenderness: "Breast Tenderness"
        case .backache: "Backache"
        case .nausea: "Nausea"
        case .fatigue: "Fatigue"
        case .acne: "Acne"
        case .happy: "Happy"
        case .sad: "Sad"
        case .anxious: "Anxious"
        case .irritable: "Irritable"
        case .moodSwings: "Mood Swings"
        case .calm: "Calm"
        case .energetic: "Energetic"
        case .tired: "Tired"
        case .exhausted: "Exhausted"
        case .cravings: "Cravings"
        case .insomnia: "Insomnia"
        case .highLibido: "High Libido"
        case .lowLibido: "Low Libido"
        }
    }

    var icon: String {
        switch self {
        case .cramps: "bolt.fill"
        case .headache: "brain.head.profile"
        case .bloating: "circle.fill"
        case .breastTenderness: "heart.fill"
        case .backache: "figure.stand"
        case .nausea: "stomach"
        case .fatigue: "battery.25percent"
        case .acne: "face.dashed"
        case .happy: "face.smiling"
        case .sad: "cloud.rain"
        case .anxious: "exclamationmark.triangle"
        case .irritable: "flame"
        case .moodSwings: "arrow.up.arrow.down"
        case .calm: "leaf"
        case .energetic: "bolt"
        case .tired: "moon.zzz"
        case .exhausted: "battery.0percent"
        case .cravings: "fork.knife"
        case .insomnia: "moon"
        case .highLibido: "heart.circle.fill"
        case .lowLibido: "heart.slash"
        }
    }

    var category: SymptomCategory {
        switch self {
        case .cramps, .headache, .bloating, .breastTenderness, .backache, .nausea, .fatigue, .acne:
            .physical
        case .happy, .sad, .anxious, .irritable, .moodSwings, .calm:
            .mood
        case .energetic, .tired, .exhausted:
            .energy
        case .cravings, .insomnia, .highLibido, .lowLibido:
            .other
        }
    }
}

enum SymptomCategory: String, CaseIterable, Identifiable {
    case physical = "Physical"
    case mood = "Mood"
    case energy = "Energy"
    case other = "Other"

    var id: String { rawValue }
}
