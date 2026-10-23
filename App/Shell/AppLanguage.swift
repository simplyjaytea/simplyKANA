import Foundation
import KanaCore

/// The app's own language (lock-screen-widget-spec §1b). Stored in the app's
/// standard UserDefaults, never the App Group: no widget reads it, so it works
/// on a sideloaded install with no shared storage. Widgets get their language
/// from which widget kind was added, not from here.
enum AppLanguage {
    static let key = "appLanguage"

    /// The stored language if its pack is installed, else the first pack.
    static func current(_ defaults: UserDefaults = .standard, packs: [Language] = installedPacks) -> Language {
        let stored = defaults.string(forKey: key).flatMap(Language.init(rawValue:))
        return stored.flatMap { packs.contains($0) ? $0 : nil } ?? packs.first ?? .japanese
    }

    static func set(_ language: Language, _ defaults: UserDefaults = .standard) {
        defaults.set(language.rawValue, forKey: key)
    }

    static func words(_ language: Language) -> [Word] {
        (try? bundledWords(language)) ?? []
    }

    /// The word the app shows now: the user's schedule, the app's language.
    static func currentWord(at date: Date = Date(), defaults: UserDefaults = .standard,
                            calendar: Calendar = .current) -> Word {
        timeline(after: date, schedule: currentSchedule, words: words(current(defaults)),
                 calendar: calendar, limit: 0).entries[0].word
    }

    /// Parses `simplykana://word/<lang>/<id>` and the pre-§1b `simplykana://word/<id>`
    /// (treated as Japanese). Unknown language or id: nil, and the app shows its
    /// current word instead of failing.
    static func word(from url: URL) -> Word? {
        // One parser, in KanaCore, tested on Linux against every word in every pack.
        parseWordLink(url).flatMap { KanaCore.word(for: $0) }
    }
}
