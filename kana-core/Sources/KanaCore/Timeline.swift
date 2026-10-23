import Foundation

// MARK: - Backward search

/// Most recent delivery at or before `date` that is outside quiet hours, on the
/// slot grid. Mirror of `nextDelivery`: same 10,000-slot guard, nil when no
/// non-quiet slot exists within it.
public func previousDelivery(atOrBefore date: Date, schedule: Schedule, calendar: Calendar) -> Date? {
    let interval = TimeInterval(schedule.intervalMinutes * 60)
    let current = slot(for: date, intervalMinutes: schedule.intervalMinutes)
    var candidate = epoch.addingTimeInterval(TimeInterval(current) * interval) // <= date
    guard let q = schedule.quietHours else { return candidate }
    for _ in 0..<10_000 {
        if !isQuiet(at: candidate, quietHours: q, calendar: calendar) { return candidate }
        candidate = candidate.addingTimeInterval(-interval)
    }
    return nil
}

// MARK: - Timeline

public struct Entry: Equatable, Sendable {
    public let date: Date
    public let word: Word
    public init(date: Date, word: Word) { self.date = date; self.word = word }
}

public struct DripTimeline: Equatable, Sendable {
    /// Never empty. entries[0].date <= after; every later entry is strictly after.
    public let entries: [Entry]
    /// When the provider asks WidgetKit to reload.
    public let reloadAt: Date
}

/// Shown only when there is no word to show. Unreachable in a shipped bundle.
public let fallbackWord = Word(id: "kanacore:fallback", language: .japanese, orthography: "—",
                               reading: "—", meanings: [""], partOfSpeech: nil, level: nil,
                               isCommon: false)

/// The widget's timeline (lock-screen-widget-spec §2). Pure: no clock, no I/O.
public func timeline(after: Date, schedule: Schedule, words: [Word],
                     calendar: Calendar, limit: Int = 24) -> DripTimeline {
    let interval = TimeInterval(schedule.intervalMinutes * 60)
    guard !words.isEmpty else {
        return DripTimeline(entries: [Entry(date: after, word: fallbackWord)],
                            reloadAt: after.addingTimeInterval(3_600))
    }
    func entry(_ d: Date) -> Entry {
        Entry(date: d, word: pickWord(for: slot(for: d, intervalMinutes: schedule.intervalMinutes), from: words)!)
    }

    var entries: [Entry]
    if let p = previousDelivery(atOrBefore: after, schedule: schedule, calendar: calendar) {
        entries = [entry(p)]
    } else {
        entries = [Entry(date: after, word: fallbackWord)]
    }
    guard limit > 0 else {
        return DripTimeline(entries: entries, reloadAt: after.addingTimeInterval(interval))
    }

    var cur = after
    for _ in 0..<limit {
        guard let next = nextDelivery(after: cur, schedule: schedule, calendar: calendar) else {
            // Bounded, never .atEnd on a past-dated entry: that reloads in a loop.
            return DripTimeline(entries: entries, reloadAt: after.addingTimeInterval(max(interval, 3_600)))
        }
        entries.append(entry(next))
        cur = next
    }
    return DripTimeline(entries: entries, reloadAt: entries.last!.date)
}

// MARK: - Circular widget

/// Line-start kinsoku set: a line never starts with one of these.
let kinsoku: Set<Character> = Set("ーっゃゅょぁぃぅぇぉッャュョァィゥェォんンゎヮヵヶ")

/// Lines for the circular widget (spec §1). One line for 1–4 characters, two lines
/// of 1–4 for 5–8, split left-first so no line starts with a kinsoku character.
/// nil means "show 語": the word does not fit honestly, so no word is shown.
public func circularLines(for word: String) -> [String]? {
    let c = Array(word)
    let n = c.count
    if n == 0 || n > 8 { return nil }
    if n <= 4 { return [word] }
    let lo = max(1, n - 4), hi = min(4, n - 1)
    let start = (n + 1) / 2
    let order = Array(stride(from: start, through: lo, by: -1)) + Array(stride(from: start + 1, through: hi, by: 1))
    for s in order where !kinsoku.contains(c[s]) {
        return [String(c[..<s]), String(c[s...])]
    }
    return nil
}

// MARK: - VoiceOver

public struct SpokenPart: Equatable, Sendable {
    public let text: String
    public let language: String? // BCP-47 tag, or nil for the phone's language
    public init(_ text: String, _ language: String?) { self.text = text; self.language = language }
}

/// The VoiceOver label in language-tagged parts (spec §5). Screens build an
/// AttributedString and set each part's languageIdentifier.
public func spokenLabel(for word: Word) -> [SpokenPart] {
    if word.id == fallbackWord.id { return [SpokenPart("No word available", nil)] }
    let lang = word.language.rawValue
    let meaning = word.meanings.first ?? ""
    if word.partOfSpeech == "hiragana" || word.partOfSpeech == "katakana" {
        return [SpokenPart(word.orthography, lang), SpokenPart(", \(word.partOfSpeech!), romaji \(meaning)", nil)]
    }
    if word.language == .chinese {
        // The Chinese voice reads the characters; pinyin read aloud by any voice is
        // noise. Tagged zh-Hans so VoiceOver doesn't use a Japanese voice.
        return [SpokenPart(word.orthography, lang), SpokenPart(", means \(meaning)", nil)]
    }
    if word.reading == word.orthography {
        return [SpokenPart(word.orthography, lang), SpokenPart(", means \(meaning)", nil)]
    }
    return [SpokenPart(word.orthography, lang), SpokenPart(", read ", nil),
            SpokenPart(word.reading, lang), SpokenPart(", means \(meaning)", nil)]
}
