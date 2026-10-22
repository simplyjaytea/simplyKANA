import Foundation

/// The user's choices (settings-spec §1). Pure value: storage lives in the app,
/// and this type reads and writes a plain dictionary so Linux can test it.
public struct Settings: Equatable, Sendable {
    public var intervalMinutes: Int
    public var quietEnabled: Bool
    public var quietStartMinutes: Int
    public var quietEndMinutes: Int
    public var languagePack: String   // Language.rawValue, e.g. "ja"
    public var level: String          // e.g. "N5"

    /// Offered on the screen. Daily and 12 h wait for the config preconditions.
    public static let offeredIntervals = [30, 60, 120, 180, 360]

    public static let defaults = Settings(intervalMinutes: 60, quietEnabled: true,
                                          quietStartMinutes: 22 * 60, quietEndMinutes: 7 * 60,
                                          languagePack: Language.japanese.rawValue, level: "N5")

    public init(intervalMinutes: Int, quietEnabled: Bool, quietStartMinutes: Int,
                quietEndMinutes: Int, languagePack: String, level: String) {
        self.intervalMinutes = intervalMinutes
        self.quietEnabled = quietEnabled
        self.quietStartMinutes = quietStartMinutes
        self.quietEndMinutes = quietEndMinutes
        self.languagePack = languagePack
        self.level = level
    }

    public enum Key {
        public static let intervalMinutes = "intervalMinutes"
        public static let quietEnabled = "quietEnabled"
        public static let quietStartMinutes = "quietStartMinutes"
        public static let quietEndMinutes = "quietEndMinutes"
        public static let languagePack = "languagePack"
        public static let level = "level"
    }

    /// Reads stored values. Missing or out-of-range values fall back to the
    /// defaults, so a fresh install and a damaged store both behave like defaults.
    public init(values: [String: Any]) {
        let d = Settings.defaults
        func int(_ k: String) -> Int? { (values[k] as? Int) ?? (values[k] as? NSNumber)?.intValue }
        let interval = int(Key.intervalMinutes) ?? d.intervalMinutes
        let start = int(Key.quietStartMinutes) ?? d.quietStartMinutes
        let end = int(Key.quietEndMinutes) ?? d.quietEndMinutes
        let validTime = (0..<1440).contains(start) && (0..<1440).contains(end)
        self.init(intervalMinutes: Settings.offeredIntervals.contains(interval) ? interval : d.intervalMinutes,
                  quietEnabled: (values[Key.quietEnabled] as? Bool) ?? d.quietEnabled,
                  quietStartMinutes: validTime ? start : d.quietStartMinutes,
                  quietEndMinutes: validTime ? end : d.quietEndMinutes,
                  languagePack: (values[Key.languagePack] as? String) ?? d.languagePack,
                  level: (values[Key.level] as? String) ?? d.level)
    }

    public var values: [String: Any] {
        [Key.intervalMinutes: intervalMinutes, Key.quietEnabled: quietEnabled,
         Key.quietStartMinutes: quietStartMinutes, Key.quietEndMinutes: quietEndMinutes,
         Key.languagePack: languagePack, Key.level: level]
    }
}

extension Schedule {
    /// The one way to build a Schedule from settings (settings-spec §2).
    /// Never produces quiet hours with start == end: that means "no quiet hours".
    public static func from(settings s: Settings) -> Schedule {
        let quiet = s.quietEnabled
            ? QuietHours(start: TimeOfDay(minutes: s.quietStartMinutes), end: TimeOfDay(minutes: s.quietEndMinutes))
            : nil
        return Schedule(intervalMinutes: s.intervalMinutes, quietHours: quiet)
    }
}

/// Why a save was refused, or nil when it may be saved (settings-spec §3).
public enum SettingsRefusal: Equatable, Sendable {
    case starves         // isSatisfiable is false
    case emptyQuietHours // start == end with quiet hours on
}

/// Validation for a save. `anchor` is the current date: the function reads no clock.
public func refusal(for s: Settings, calendar: Calendar, anchor: Date) -> SettingsRefusal? {
    if s.quietEnabled && s.quietStartMinutes == s.quietEndMinutes { return .emptyQuietHours }
    return isSatisfiable(schedule: Schedule.from(settings: s), calendar: calendar, anchor: anchor) ? nil : .starves
}
