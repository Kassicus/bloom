import SwiftUI

enum BloomTheme {
    // MARK: - Brand Font

    /// Yellowtail — used for app title, section headers, and branded display text.
    static func brandFont(size: CGFloat) -> Font {
        .custom("Yellowtail-Regular", size: size)
    }

    static let appTitle = brandFont(size: 32)
    static let sectionTitle = brandFont(size: 24)
    static let brandAccent = brandFont(size: 18)

    // MARK: - Monochrome Pink Palette
    // All shades derived from the accent color #FF7BAD (HSB 338°, 52%, 100%)

    /// The primary brand color — #FF7BAD
    static let brand = Color.accentColor

    /// Deepest shade — for strong emphasis, critical indicators — #B33573
    static let pinkDeepest = Color(red: 0.70, green: 0.21, blue: 0.45)

    /// Deep shade — for secondary emphasis — #CC528C
    static let pinkDeep = Color(red: 0.80, green: 0.32, blue: 0.55)

    /// Medium-deep — for data visualization, active elements — #E672A3
    static let pinkMedium = Color(red: 0.90, green: 0.45, blue: 0.64)

    /// The accent itself — #FF7BAD
    static let pinkAccent = Color.accentColor

    /// Medium-light — for secondary data, lighter indicators — #FFA5C6
    static let pinkLight = Color(red: 1.0, green: 0.65, blue: 0.78)

    /// Light — for subtle indicators, muted elements — #FFBFD7
    static let pinkSoft = Color(red: 1.0, green: 0.75, blue: 0.84)

    /// Pale — for backgrounds, gentle fills — #FFD9E7
    static let pinkPale = Color(red: 1.0, green: 0.85, blue: 0.91)

    /// Faintest — for very subtle backgrounds — #FFECF3
    static let pinkFaintest = Color(red: 1.0, green: 0.93, blue: 0.95)

    // MARK: - Semantic Aliases

    /// Positive outcome / confirmed / good
    static let positive = pinkDeep

    /// Warning / moderate / approaching
    static let moderate = pinkMedium

    /// Subtle / low / inactive
    static let subtle = pinkLight

    /// Card or section background tint
    static let cardTint = pinkFaintest

    /// Stronger card background (selected state)
    static let cardTintActive = pinkPale
}
