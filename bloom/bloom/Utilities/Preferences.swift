import Foundation

/// User preferences stored in UserDefaults. Keys are unchanged from earlier versions so
/// existing settings carry over.
nonisolated enum Preferences {
    enum Key {
        static let bbtReminderEnabled = "bloom.bbtReminderEnabled"
        static let bbtReminderHour = "bloom.bbtReminderHour"
        static let bbtReminderMinute = "bloom.bbtReminderMinute"
        static let periodReminderEnabled = "bloom.periodReminderEnabled"
        static let fertileWindowAlertEnabled = "bloom.fertileWindowAlertEnabled"
        static let healthKitEnabled = "bloom.healthKitEnabled"
        static let useCelsius = "bloom.useCelsius"
    }

    private static var defaults: UserDefaults { .standard }

    static var bbtReminderEnabled: Bool {
        get { defaults.bool(forKey: Key.bbtReminderEnabled) }
        set { defaults.set(newValue, forKey: Key.bbtReminderEnabled) }
    }

    static var bbtReminderHour: Int {
        get { defaults.object(forKey: Key.bbtReminderHour) as? Int ?? 6 }
        set { defaults.set(newValue, forKey: Key.bbtReminderHour) }
    }

    static var bbtReminderMinute: Int {
        get { defaults.object(forKey: Key.bbtReminderMinute) as? Int ?? 30 }
        set { defaults.set(newValue, forKey: Key.bbtReminderMinute) }
    }

    static var periodReminderEnabled: Bool {
        get { defaults.bool(forKey: Key.periodReminderEnabled) }
        set { defaults.set(newValue, forKey: Key.periodReminderEnabled) }
    }

    static var fertileWindowAlertEnabled: Bool {
        get { defaults.bool(forKey: Key.fertileWindowAlertEnabled) }
        set { defaults.set(newValue, forKey: Key.fertileWindowAlertEnabled) }
    }

    static var healthKitEnabled: Bool {
        get { defaults.bool(forKey: Key.healthKitEnabled) }
        set { defaults.set(newValue, forKey: Key.healthKitEnabled) }
    }

    static var useCelsius: Bool {
        get { defaults.bool(forKey: Key.useCelsius) }
        set { defaults.set(newValue, forKey: Key.useCelsius) }
    }
}

/// Display unit for basal body temperature. Temperatures are always stored in °F (existing
/// data, HealthKit writes and the BBT shift threshold all use °F) and converted for display.
nonisolated enum TemperatureUnit {
    case fahrenheit
    case celsius

    init(useCelsius: Bool) {
        self = useCelsius ? .celsius : .fahrenheit
    }

    var symbol: String {
        switch self {
        case .fahrenheit: "\u{00B0}F"
        case .celsius: "\u{00B0}C"
        }
    }

    /// Increment used by the +/- buttons, in display units.
    var step: Double {
        switch self {
        case .fahrenheit: 0.1
        case .celsius: 0.05
        }
    }

    /// Spacing of chart axis labels, in display units.
    var chartStride: Double {
        switch self {
        case .fahrenheit: 0.5
        case .celsius: 0.25
        }
    }

    func fromFahrenheit(_ fahrenheit: Double) -> Double {
        switch self {
        case .fahrenheit: fahrenheit
        case .celsius: (fahrenheit - 32) * 5 / 9
        }
    }

    func toFahrenheit(_ value: Double) -> Double {
        switch self {
        case .fahrenheit: value
        case .celsius: value * 9 / 5 + 32
        }
    }

    /// Converts a temperature difference (e.g. the 0.3°F shift threshold).
    func deltaFromFahrenheit(_ delta: Double) -> Double {
        switch self {
        case .fahrenheit: delta
        case .celsius: delta * 5 / 9
        }
    }

    /// Formats a stored °F value in this unit, e.g. "97.6" or "36.45".
    func format(_ fahrenheit: Double) -> String {
        fromFahrenheit(fahrenheit).formatted(.number.precision(.fractionLength(1...2)))
    }

    /// Formats a value that is already in this unit.
    func formatDisplayValue(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1...2)))
    }

    /// Parses user input in this unit (accepts either decimal separator) into °F, or nil if
    /// it isn't a plausible BBT reading.
    func parseToFahrenheit(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else { return nil }
        let fahrenheit = toFahrenheit(value)
        let range = BloomConstants.bbtEntryMinFahrenheit...BloomConstants.bbtEntryMaxFahrenheit
        return range.contains(fahrenheit) ? fahrenheit : nil
    }

    var entryRangeDescription: String {
        let low = formatDisplayValue(fromFahrenheit(BloomConstants.bbtEntryMinFahrenheit))
        let high = formatDisplayValue(fromFahrenheit(BloomConstants.bbtEntryMaxFahrenheit))
        return "\(low)–\(high)\(symbol)"
    }
}
