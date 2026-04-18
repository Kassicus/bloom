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

    // Energy (ordered high → low)
    case energetic
    case productive
    case balanced
    case sluggish
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
        case .productive: "Productive"
        case .balanced: "Balanced"
        case .sluggish: "Sluggish"
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
        case .productive: "checkmark.circle"
        case .balanced: "equal.circle"
        case .sluggish: "tortoise"
        case .tired: "moon.zzz"
        case .exhausted: "battery.0percent"
        case .cravings: "fork.knife"
        case .insomnia: "moon"
        case .highLibido: "heart.circle.fill"
        case .lowLibido: "heart.slash"
        }
    }

    var cycleContext: String {
        switch self {
        case .cramps:
            "Common during menstruation (uterine contractions) and sometimes at ovulation (mittelschmerz)."
        case .headache:
            "Can occur during menstruation due to hormone fluctuations, especially dropping estrogen levels."
        case .bloating:
            "Common in the luteal phase due to progesterone's effect on water retention and digestion."
        case .breastTenderness:
            "Caused by rising progesterone after ovulation. Can be an early sign that ovulation has occurred."
        case .backache:
            "Often accompanies menstrual cramps due to prostaglandin release during uterine contractions."
        case .nausea:
            "Can occur during menstruation or in the luteal phase. Also an early pregnancy sign after implantation."
        case .fatigue:
            "Common in the luteal phase as progesterone has a mildly sedating effect on the body."
        case .acne:
            "Often flares before menstruation when progesterone stimulates oil production in the skin."
        case .happy:
            "Mood often improves in the follicular phase as estrogen rises, peaking around ovulation."
        case .sad:
            "Low mood is common in the late luteal phase and during menstruation as hormones drop."
        case .anxious:
            "Anxiety can increase in the luteal phase as progesterone affects neurotransmitter activity."
        case .irritable:
            "Common in the late luteal phase (premenstrual) as estrogen and progesterone decline."
        case .moodSwings:
            "Rapid hormone shifts, especially around ovulation and before menstruation, can cause mood variability."
        case .calm:
            "A sense of calm is common in the mid-follicular phase as estrogen steadily rises."
        case .energetic:
            "Energy typically peaks around ovulation when estrogen is highest."
        case .productive:
            "Focus and drive often run high in the follicular phase as estrogen rises."
        case .balanced:
            "Steady, even energy — most common in the mid-follicular and early luteal phases."
        case .sluggish:
            "A slow start to the day is common in the early menstrual phase and mid-luteal phase."
        case .tired:
            "Mild tiredness is common in the early menstrual phase and luteal phase."
        case .exhausted:
            "Deep fatigue can signal the late luteal phase or may indicate other factors like poor sleep or illness."
        case .cravings:
            "Food cravings often increase in the luteal phase, driven by progesterone and metabolic changes."
        case .insomnia:
            "Sleep disruption is common in the late luteal phase as progesterone drops before menstruation."
        case .highLibido:
            "Desire often increases around ovulation, driven by rising estrogen and a small testosterone peak."
        case .lowLibido:
            "Lower desire is common in the early menstrual phase and late luteal phase."
        }
    }

    var category: SymptomCategory {
        switch self {
        case .cramps, .headache, .bloating, .breastTenderness, .backache, .nausea, .fatigue, .acne:
            .physical
        case .happy, .sad, .anxious, .irritable, .moodSwings, .calm:
            .mood
        case .energetic, .productive, .balanced, .sluggish, .tired, .exhausted:
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
