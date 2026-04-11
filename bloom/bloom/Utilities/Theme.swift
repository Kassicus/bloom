import SwiftUI
import UIKit

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

    /// Creates a Color that adapts to light/dark appearance automatically.
    static func adaptive(
        light: (r: Double, g: Double, b: Double),
        dark: (r: Double, g: Double, b: Double)
    ) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: dark.r, green: dark.g, blue: dark.b, alpha: 1)
                : UIColor(red: light.r, green: light.g, blue: light.b, alpha: 1)
        })
    }

    // MARK: - Bloom (Monochrome Pink)
    // All shades derived from the accent color #FF7BAD (HSB 338°, 52%, 100%)
    // Uses .ultraThinMaterial for cards which auto-adapts to dark mode.

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
    // Multi-hue pastel palette with dark mode adaptations.
    // Light mode: soft pastels on light tinted backgrounds.
    // Dark mode: richer, more saturated variants on dark tinted backgrounds.

    static let garden = ThemeColors(
        brand:   adaptive(light: (0.53, 0.72, 0.57), dark: (0.42, 0.62, 0.46)),   // sage
        deepest: adaptive(light: (0.61, 0.42, 0.56), dark: (0.77, 0.56, 0.70)),   // orchid
        deep:    adaptive(light: (0.83, 0.52, 0.61), dark: (0.83, 0.52, 0.61)),   // dusty rose (works both)
        medium:  adaptive(light: (0.91, 0.66, 0.54), dark: (0.83, 0.56, 0.43)),   // coral
        accent:  adaptive(light: (0.53, 0.72, 0.57), dark: (0.42, 0.62, 0.46)),   // sage
        light:   adaptive(light: (0.72, 0.65, 0.81), dark: (0.63, 0.54, 0.75)),   // lavender
        soft:    adaptive(light: (0.66, 0.83, 0.72), dark: (0.48, 0.72, 0.58)),   // mint
        pale:    adaptive(light: (0.90, 0.95, 0.91), dark: (0.12, 0.17, 0.13)),   // sage bg
        faintest: adaptive(light: (0.94, 0.92, 0.97), dark: (0.12, 0.11, 0.14)),  // lavender bg
        cardFill: AnyShapeStyle(Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.14, green: 0.18, blue: 0.15, alpha: 0.85)   // dark sage tint
                : UIColor(red: 0.94, green: 0.96, blue: 0.94, alpha: 0.85)   // light sage tint
        }))
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
