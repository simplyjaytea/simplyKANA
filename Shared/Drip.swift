import Foundation
import KanaCore

/// MVP defaults (word-data-spec §5): hourly, quiet 22:00–07:00. No config screen yet.
let defaultSchedule = Schedule(intervalMinutes: 60,
                               quietHours: QuietHours(start: TimeOfDay(minutes: 22 * 60),
                                                      end: TimeOfDay(minutes: 7 * 60)))

/// Loaded once per process. An empty list means the bundle failed to load;
/// timeline() then shows the fallback word instead of crashing.
let appWords: [Word] = (try? bundledWords()) ?? []

/// The word that is on screen now, the same one the widget shows.
func currentWord(at date: Date = Date(), calendar: Calendar = .current) -> Word {
    timeline(after: date, schedule: defaultSchedule, words: appWords, calendar: calendar, limit: 0)
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

func wordURL(_ word: Word) -> URL {
    URL(string: "simplykana://word/\(word.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")")!
}
