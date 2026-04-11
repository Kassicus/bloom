import SwiftUI

// MARK: - Theme Colors

struct ThemeColors {
    let brand: Color
    let deepest: Color
    let deep: Color
    let medium: Color
    let accent: Color
    let light: Color
    let soft: Color
    let pale: Color
    let faintest: Color

    /// Card background style — material for Bloom, tinted color for Garden.
    let cardFill: AnyShapeStyle

    // MARK: - Bloom (Monochrome Pink)
    // All shades derived from the accent color #FF7BAD (HSB 338°, 52%, 100%)

    static let bloom = ThemeColors(
        brand: Color("AccentColor"),
        deepest: Color(red: 0.70, green: 0.21, blue: 0.45),   // #B33573
        deep: Color(red: 0.80, green: 0.32, blue: 0.55),       // #CC528C
        medium: Color(red: 0.90, green: 0.45, blue: 0.64),     // #E672A3
        accent: Color("AccentColor"),                            // #FF7BAD
        light: Color(red: 1.0, green: 0.65, blue: 0.78),       // #FFA5C6
        soft: Color(red: 1.0, green: 0.75, blue: 0.84),        // #FFBFD7
        pale: Color(red: 1.0, green: 0.85, blue: 0.91),        // #FFD9E7
        faintest: Color(red: 1.0, green: 0.93, blue: 0.95),    // #FFECF3
        cardFill: AnyShapeStyle(.ultraThinMaterial)
    )

    // MARK: - Garden (Colorful Pastels)
    // Multi-hue pastel palette — each intensity level uses a different color family
    // while maintaining a coherent warm-to-cool visual hierarchy.
    // Backgrounds use tinted colors rather than neutral materials.

    static let garden = ThemeColors(
        brand: Color(red: 0.53, green: 0.72, blue: 0.57),      // #88B891 — soft sage
        deepest: Color(red: 0.61, green: 0.42, blue: 0.56),    // #9B6B8E — deep orchid
        deep: Color(red: 0.83, green: 0.52, blue: 0.61),       // #D4849B — dusty rose
        medium: Color(red: 0.91, green: 0.66, blue: 0.54),     // #E8A889 — warm coral
        accent: Color(red: 0.53, green: 0.72, blue: 0.57),     // #88B891 — soft sage
        light: Color(red: 0.72, green: 0.65, blue: 0.81),      // #B8A5CF — soft lavender
        soft: Color(red: 0.66, green: 0.83, blue: 0.72),       // #A8D4B8 — pale mint
        pale: Color(red: 0.90, green: 0.95, blue: 0.91),       // #E6F2E8 — light sage
        faintest: Color(red: 0.94, green: 0.92, blue: 0.97),   // #F0EBF7 — light lavender
        cardFill: AnyShapeStyle(Color(red: 0.94, green: 0.96, blue: 0.94).opacity(0.85)) // light sage tint
    )
}

// MARK: - Theme Identifier

enum AppTheme: String, CaseIterable, Identifiable {
    case bloom
    case garden

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bloom: "Bloom"
        case .garden: "Garden"
        }
    }

    var description: String {
        switch self {
        case .bloom: "Classic pink"
        case .garden: "Colorful pastels"
        }
    }

    var colors: ThemeColors {
        switch self {
        case .bloom: .bloom
        case .garden: .garden
        }
    }

    /// Preview swatch colors for the theme picker.
    var swatchColors: [Color] {
        switch self {
        case .bloom: [colors.deep, colors.accent, colors.light]
        case .garden: [colors.deep, colors.brand, colors.light]
        }
    }
}

// MARK: - Theme Manager

@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    var activeTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(activeTheme.rawValue, forKey: "bloom.theme")
        }
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: "bloom.theme") ?? AppTheme.bloom.rawValue
        self.activeTheme = AppTheme(rawValue: stored) ?? .bloom
    }
}

// MARK: - BloomTheme (Static Accessors)

enum BloomTheme {
    private static var colors: ThemeColors { ThemeManager.shared.activeTheme.colors }

    // MARK: - Brand Font

    /// Yellowtail — used for app title, section headers, and branded display text.
    static func brandFont(size: CGFloat) -> Font {
        .custom("Yellowtail-Regular", size: size)
    }

    static let appTitle = brandFont(size: 32)
    static let sectionTitle = brandFont(size: 24)
    static let brandAccent = brandFont(size: 18)

    // MARK: - Color Palette

    static var brand: Color { colors.brand }
    static var pinkDeepest: Color { colors.deepest }
    static var pinkDeep: Color { colors.deep }
    static var pinkMedium: Color { colors.medium }
    static var pinkAccent: Color { colors.accent }
    static var pinkLight: Color { colors.light }
    static var pinkSoft: Color { colors.soft }
    static var pinkPale: Color { colors.pale }
    static var pinkFaintest: Color { colors.faintest }

    // MARK: - Semantic Aliases

    static var positive: Color { colors.deep }
    static var moderate: Color { colors.medium }
    static var subtle: Color { colors.light }
    static var cardTint: Color { colors.faintest }
    static var cardTintActive: Color { colors.pale }
    static var cardFill: AnyShapeStyle { colors.cardFill }
}
