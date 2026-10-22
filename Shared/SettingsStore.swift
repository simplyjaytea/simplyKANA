import Foundation
import Combine
import WidgetKit
import KanaCore

/// Where settings live (settings-spec §2). The App Group suite is shared by the
/// app and the widget. If the App Group isn't available (unsigned simulator
/// builds, or a signing team that can't use App Groups), settings still save in
/// the app, but the widget can't see them and uses the defaults. `isShared` says which.
final class SettingsStore: ObservableObject {
    static let groupID = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as? String

    /// True when the app and the widget really share storage.
    static var isShared: Bool {
        guard let g = groupID, !g.isEmpty else { return false }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: g) != nil
    }

    static var sharedDefaults: UserDefaults {
        if isShared, let g = groupID, let d = UserDefaults(suiteName: g) { return d }
        return .standard
    }

    /// What the widget and the app read. Missing keys mean defaults.
    static func load(from defaults: UserDefaults = sharedDefaults) -> Settings {
        Settings(values: defaults.dictionaryRepresentation())
    }

    private let defaults: UserDefaults
    private let reload: () -> Void
    @Published private(set) var settings: Settings
    @Published private(set) var lastRefusal: SettingsRefusal?

    init(defaults: UserDefaults = SettingsStore.sharedDefaults,
         reload: @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() }) {
        self.defaults = defaults
        self.reload = reload
        self.settings = SettingsStore.load(from: defaults)
    }

    /// Validate once and save once (settings-spec §2, §3). Call when an edit ends,
    /// never per picker tick. A refusal leaves the stored settings untouched.
    @discardableResult
    func commit(_ new: Settings, now: Date = Date(), calendar: Calendar = .current) -> SettingsRefusal? {
        if let r = refusal(for: new, calendar: calendar, anchor: now) {
            lastRefusal = r
            return r
        }
        for (k, v) in new.values { defaults.set(v, forKey: k) }
        settings = new
        lastRefusal = nil
        reload()
        return nil
    }
}

/// Refusal copy, one sentence (settings-spec §3).
extension SettingsRefusal {
    var message: String {
        switch self {
        case .starves:
            return "With these quiet hours, no word would arrive for days at a time. Shorten the quiet window or choose a shorter interval."
        case .emptyQuietHours:
            return "Quiet hours need a start and an end that differ."
        }
    }
}
