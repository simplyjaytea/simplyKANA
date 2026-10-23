import Foundation
import KanaCore

/// The user's schedule, from settings (defaults until they change something).
var currentSchedule: Schedule { Schedule.from(settings: SettingsStore.effective()) }

/// Words for the chosen pack. Falls back to Japanese if a stored pack isn't bundled;
/// an empty list means the bundle failed to load, and timeline() shows the fallback word.
func packWords(_ settings: Settings = SettingsStore.effective()) -> [Word] {
    let lang = Language(rawValue: settings.languagePack) ?? .japanese
    return (try? bundledWords(lang)) ?? (try? bundledWords(.japanese)) ?? []
}

/// The Japanese bundle, loaded once (tests and placeholders).
let appWords: [Word] = (try? bundledWords()) ?? []

/// The word that is on screen now, the same one the widget shows.
func currentWord(at date: Date = Date(), calendar: Calendar = .current) -> Word {
    timeline(after: date, schedule: currentSchedule, words: packWords(), calendar: calendar, limit: 0)
        .entries[0].word
}

/// VoiceOver label with every Japanese part tagged, so VoiceOver uses a Japanese voice.
func spokenText(for word: Word) -> AttributedString {
    var out = AttributedString()
    for part in spokenLabel(for: word) {
        var s = AttributedString(part.text)
        if let lang = part.language { s.languageIdentifier = lang }
        out += s
    }
    return out
}

/// Kept for callers that still use the old name; the link carries language and id.
func wordURL(_ word: Word) -> URL { wordLink(for: word) }
