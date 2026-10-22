import Foundation
import Testing
@testable import KanaCore

private func cal(_ id: String) -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: id)!
    return c
}
private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ tz: String) -> Date {
    cal(tz).date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
}
private func quiet(_ s: Int, _ e: Int) -> QuietHours {
    QuietHours(start: TimeOfDay(minutes: s), end: TimeOfDay(minutes: e))!
}
private let NY = "America/New_York"
private let hourly = Schedule(intervalMinutes: 60, quietHours: quiet(22 * 60, 7 * 60))
private func w(_ id: String) -> Word {
    Word(id: id, language: .japanese, orthography: id, reading: id, meanings: [id],
         partOfSpeech: "noun", level: .jlpt(5), isCommon: true)
}
private let words = (0..<7).map { w("w\($0)") }

// MARK: previousDelivery

@Test func previousDeliveryIsAtOrBefore() {
    let t = at(2026, 10, 21, 12, 30, NY)
    let p = previousDelivery(atOrBefore: t, schedule: hourly, calendar: cal(NY))!
    #expect(p == at(2026, 10, 21, 12, 0, NY))
    let onSlot = at(2026, 10, 21, 12, 0, NY)
    #expect(previousDelivery(atOrBefore: onSlot, schedule: hourly, calendar: cal(NY)) == onSlot)
}

@Test func previousDeliverySkipsQuietHoursBackwardsAcrossMidnight() {
    let t = at(2026, 10, 22, 3, 15, NY) // inside 22:00-07:00, after midnight
    #expect(previousDelivery(atOrBefore: t, schedule: hourly, calendar: cal(NY)) == at(2026, 10, 21, 21, 0, NY))
}

@Test func previousDeliveryNilWithinGuard() {
    // Tokyo, daily slot at 00:00Z = 09:00 local, quiet 09:00-10:00: every slot is quiet.
    let s = Schedule(intervalMinutes: 1440, quietHours: quiet(9 * 60, 10 * 60))
    #expect(previousDelivery(atOrBefore: at(2026, 10, 21, 12, 0, "Asia/Tokyo"), schedule: s, calendar: cal("Asia/Tokyo")) == nil)
}

@Test func previousDeliveryNoSkipProperty() {
    // Rachel's property: p is outside quiet hours, p <= t, and nothing between p and t was skipped.
    let starts = [at(2026, 10, 21, 22, 0, NY),  // ordinary night
                  at(2026, 3, 7, 22, 0, NY),    // spring-forward night
                  at(2026, 10, 31, 22, 0, NY),  // fall-back night
                  at(2026, 12, 31, 22, 0, NY)]  // across New Year
    let c = cal(NY)
    for s in starts {
        for step in stride(from: 0, through: 10 * 3600, by: 7 * 60) { // every 7 min through the night
            let t = s.addingTimeInterval(TimeInterval(step))
            guard let p = previousDelivery(atOrBefore: t, schedule: hourly, calendar: c) else {
                Issue.record("nil at \(t)"); continue
            }
            #expect(p <= t)
            #expect(!isQuiet(at: p, quietHours: hourly.quietHours!, calendar: c))
            #expect(nextDelivery(after: p, schedule: hourly, calendar: c)! > t, "skipped a delivery between \(p) and \(t)")
        }
    }
}

// MARK: timeline

@Test func timelineFirstEntryAtOrBeforeRestStrictlyAfter() {
    let t = at(2026, 10, 21, 12, 30, NY)
    let tl = timeline(after: t, schedule: hourly, words: words, calendar: cal(NY))
    #expect(tl.entries[0].date <= t)
    #expect(tl.entries[1].date > t)
    #expect(zip(tl.entries, tl.entries.dropFirst()).allSatisfy { $0.date < $1.date })
}

@Test func timelineReloadInsideQuietHoursKeepsThe2100Word() {
    let c = cal(NY)
    let t = at(2026, 10, 21, 23, 30, NY)
    let tl = timeline(after: t, schedule: hourly, words: words, calendar: c)
    let nine = at(2026, 10, 21, 21, 0, NY)
    #expect(tl.entries[0].date == nine)
    #expect(tl.entries[0].word == pickWord(for: slot(for: nine, intervalMinutes: 60), from: words))
    #expect(tl.entries[1].date == at(2026, 10, 22, 7, 0, NY))
    // And it's the same word that a reload at 21:00 itself would show.
    #expect(timeline(after: nine, schedule: hourly, words: words, calendar: c).entries[0] == tl.entries[0])
}

@Test func timelineHasNoEntryInsideQuietHours() {
    let c = cal(NY)
    for night in [at(2026, 3, 7, 20, 0, NY), at(2026, 10, 31, 20, 0, NY)] {
        let tl = timeline(after: night, schedule: hourly, words: words, calendar: c, limit: 48)
        #expect(tl.entries.allSatisfy { !isQuiet(at: $0.date, quietHours: hourly.quietHours!, calendar: c) })
    }
}

@Test func timelineLimit() {
    let t = at(2026, 10, 21, 12, 30, NY)
    let tl = timeline(after: t, schedule: hourly, words: words, calendar: cal(NY), limit: 5)
    #expect(tl.entries.count == 6) // current + 5
    #expect(tl.reloadAt == tl.entries.last!.date)
    for l in [0, -3] {
        let one = timeline(after: t, schedule: hourly, words: words, calendar: cal(NY), limit: l)
        #expect(one.entries.count == 1)
        #expect(one.reloadAt == t.addingTimeInterval(3600))
    }
}

@Test func timelineUnsatisfiableIsBoundedAndNeverEmpty() {
    // Every slot quiet: previous and next are both nil. Fallback now, bounded reload.
    let s = Schedule(intervalMinutes: 1440, quietHours: quiet(9 * 60, 10 * 60))
    let t = at(2026, 10, 21, 12, 0, "Asia/Tokyo")
    let tl = timeline(after: t, schedule: s, words: words, calendar: cal("Asia/Tokyo"))
    #expect(tl.entries == [Entry(date: t, word: fallbackWord)])
    #expect(tl.reloadAt == t.addingTimeInterval(86_400))
    #expect(tl.reloadAt > t)
}

@Test func timelineEmptyWordsUsesFallback() {
    let t = at(2026, 10, 21, 12, 30, NY)
    let tl = timeline(after: t, schedule: hourly, words: [], calendar: cal(NY))
    #expect(tl.entries == [Entry(date: t, word: fallbackWord)])
    #expect(tl.reloadAt == t.addingTimeInterval(3600))
}

@Test func timelineIsDeterministic() {
    let t = at(2026, 10, 21, 12, 30, NY)
    let a = timeline(after: t, schedule: hourly, words: words, calendar: cal(NY))
    let b = timeline(after: t, schedule: hourly, words: words, calendar: cal(NY))
    #expect(a == b)
}

// MARK: circularLines

@Test func circularNamedCases() {
    #expect(circularLines(for: "テープレコーダー") == ["テープレ", "コーダー"])
    #expect(circularLines(for: "パーティー") == ["パー", "ティー"])
    #expect(circularLines(for: "ワイシャツ") == ["ワイ", "シャツ"])
    #expect(circularLines(for: "おじいさん") == ["おじい", "さん"])
    #expect(circularLines(for: "ーーーーー") == nil)      // no valid split: 語
    #expect(circularLines(for: "あいうえおかきくけ") == nil) // 9+: 語
    #expect(circularLines(for: "日") == ["日"])
    #expect(circularLines(for: "図書館") == ["図書館"])
}

@Test func circularEveryBundleWordFits() throws {
    for word in try bundledWords() {
        let o = word.orthography
        guard let lines = circularLines(for: o) else { Issue.record("\(o) falls back to 語"); continue }
        #expect(lines.joined() == o, "\(o) lost characters")
        #expect(lines.allSatisfy { (1...4).contains($0.count) }, "\(o) \(lines)")
        // The rule is about where we break: a line we start never begins with K.
        // (Single-line ん and ン start with K by being ん and ン.)
        #expect(lines.dropFirst().allSatisfy { !kinsoku.contains($0.first!) }, "\(o) \(lines)")
        #expect(lines.count == (o.count <= 4 ? 1 : 2), "\(o)")
    }
}

// MARK: spokenLabel

@Test func spokenLabelWording() {
    let a = Word(id: "kana:hiragana:a", language: .japanese, orthography: "あ", reading: "あ",
                 meanings: ["a"], partOfSpeech: "hiragana", level: nil, isCommon: true)
    #expect(spokenLabel(for: a) == [SpokenPart("あ", "ja"), SpokenPart(", hiragana, romaji a", nil)])
    let day = Word(id: "jmdict:1", language: .japanese, orthography: "日", reading: "にち",
                   meanings: ["day"], partOfSpeech: "noun", level: .jlpt(5), isCommon: true)
    #expect(spokenLabel(for: day) == [SpokenPart("日", "ja"), SpokenPart(", read ", nil),
                                      SpokenPart("にち", "ja"), SpokenPart(", means day", nil)])
    let ah = Word(id: "jmdict:2", language: .japanese, orthography: "ああ", reading: "ああ",
                  meanings: ["ah!"], partOfSpeech: "interjection", level: .jlpt(5), isCommon: true)
    #expect(spokenLabel(for: ah) == [SpokenPart("ああ", "ja"), SpokenPart(", means ah!", nil)])
    #expect(spokenLabel(for: fallbackWord) == [SpokenPart("No word available", nil)])
}

@Test func spokenLabelTagsEveryJapanesePart() throws {
    let japanese = CharacterSet(charactersIn: "\u{3040}"..."\u{30FF}").union(CharacterSet(charactersIn: "\u{4E00}"..."\u{9FFF}"))
    for word in try bundledWords() {
        for part in spokenLabel(for: word) {
            let hasJapanese = part.text.unicodeScalars.contains { japanese.contains($0) }
            #expect(hasJapanese == (part.language == "ja"), "\(word.orthography): \(part)")
        }
    }
}
