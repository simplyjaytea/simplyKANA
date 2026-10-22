import Foundation
import Testing
@testable import KanaCore

// NOTE: these tests run on Linux. Passing here does NOT prove iOS behavior.
// Every calendar uses an explicit TimeZone, never the system zone.

private func utcCalendar(_ id: String = "UTC") -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: id)!
    return c
}

private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, tz: String = "UTC") -> Date {
    var c = utcCalendar(tz)
    c.locale = Locale(identifier: "en_US_POSIX")
    return c.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
}

/// Fixed anchors: tests never read the clock.
private let anchor2026 = Date(timeIntervalSince1970: 1_767_225_600) // 2026-01-01Z
private let anchor2001 = Date(timeIntervalSinceReferenceDate: 0)     // old default

private func word(_ id: String, level: Level? = .jlpt(5), language: Language = .japanese) -> Word {
    Word(id: id, language: language, orthography: "日", reading: "にち", meanings: ["day"],
         partOfSpeech: "noun", level: level, isCommon: true)
}

private func qh(_ s: Int, _ e: Int) -> QuietHours {
    QuietHours(start: TimeOfDay(minutes: s), end: TimeOfDay(minutes: e))!
}

@Test func slotIsMonotonicAcrossMidnight() {
    let before = slot(for: date(2026, 10, 21, 23, 59), intervalMinutes: 60)
    let after = slot(for: date(2026, 10, 22, 0, 0), intervalMinutes: 60)
    #expect(after == before + 1)
}

@Test func quietHoursCrossingMidnight() {
    let cal = utcCalendar()
    let q = qh(22 * 60, 7 * 60)
    #expect(isQuiet(at: date(2026, 10, 21, 23, 0), quietHours: q, calendar: cal))
    #expect(isQuiet(at: date(2026, 10, 21, 3, 0), quietHours: q, calendar: cal))
    #expect(!isQuiet(at: date(2026, 10, 21, 7, 0), quietHours: q, calendar: cal)) // end exclusive
    #expect(isQuiet(at: date(2026, 10, 21, 22, 0), quietHours: q, calendar: cal)) // start inclusive
}

@Test func quietHoursEqualStartEndIsRejected() {
    #expect(QuietHours(start: TimeOfDay(minutes: 600), end: TimeOfDay(minutes: 600)) == nil)
}

@Test func quietHoursOutOfRangeIsRejected() {
    #expect(QuietHours(start: TimeOfDay(minutes: -1), end: TimeOfDay(minutes: 600)) == nil)
    #expect(QuietHours(start: TimeOfDay(minutes: 600), end: TimeOfDay(minutes: 1440)) == nil)
}

@Test func nextDeliverySkipsQuietHours() {
    let cal = utcCalendar()
    let s = Schedule(intervalMinutes: 60, quietHours: qh(22 * 60, 7 * 60))
    let next = nextDelivery(after: date(2026, 10, 21, 21, 30), schedule: s, calendar: cal)
    #expect(next != nil)
    #expect(next! > date(2026, 10, 21, 21, 30))
    #expect(!isQuiet(at: next!, quietHours: qh(22 * 60, 7 * 60), calendar: cal))
}

@Test func nextDeliveryIsStrictlyAfter() {
    let cal = utcCalendar()
    let s = Schedule(intervalMinutes: 60, quietHours: nil)
    let at = date(2026, 10, 21, 12, 0)
    #expect((nextDelivery(after: at, schedule: s, calendar: cal) ?? at) > at)
}

@Test func quietWindowSwallowingEverySlotReturnsNil() {
    // Tokyo, daily slot aligned to epoch-UTC, quiet 09:00-10:00 local.
    let cal = utcCalendar("Asia/Tokyo")
    let s = Schedule(intervalMinutes: 1440, quietHours: qh(9 * 60, 10 * 60))
    #expect(nextDelivery(after: date(2026, 10, 21, 12, 0, tz: "Asia/Tokyo"), schedule: s, calendar: cal) == nil)
    #expect(!isSatisfiable(schedule: s, calendar: cal, anchor: anchor2026))
}

@Test func satisfiableScheduleReportsTrue() {
    let cal = utcCalendar()
    let s = Schedule(intervalMinutes: 60, quietHours: qh(22 * 60, 7 * 60))
    #expect(isSatisfiable(schedule: s, calendar: cal, anchor: anchor2026))
}

@Test func pickWordEmptyReturnsNil() {
    #expect(pickWord(for: 5, from: []) == nil)
}

@Test func pickWordAcceptsNilLevel() {
    #expect(pickWord(for: 0, from: [word("a", level: nil)])?.level == nil)
}

@Test func pickWordIgnoresLanguage() {
    // Selection is by slot only; language never changes which index is picked.
    let words = [word("a", level: .jlpt(5)), word("b", level: .hsk(1), language: .chinese),
                 word("c", level: .nikl(1), language: .korean)]
    #expect((0..<6).map { pickWord(for: $0, from: words)!.id } == ["a", "b", "c", "a", "b", "c"])
}

@Test func levelsFromDifferentExamsAreDistinct() {
    #expect(Level.jlpt(1) != Level.hsk(1))
    #expect(Level.hsk(1) != Level.nikl(1))
}

@Test func pickWordDeterministicAndWraps() {
    let words = [word("a"), word("b"), word("c")]
    #expect(pickWord(for: 0, from: words)?.id == "a")
    #expect(pickWord(for: 3, from: words)?.id == "a")
    #expect(pickWord(for: -1, from: words)?.id == "c")
}

@Test func dstTransitionKeepsSlotsMonotonic() {
    // Slot arithmetic is timezone-free; this checks only monotonicity across a DST date.
    let a = slot(for: date(2026, 3, 8, 1, 30, tz: "America/New_York"), intervalMinutes: 60)
    let b = slot(for: date(2026, 3, 8, 3, 30, tz: "America/New_York"), intervalMinutes: 60)
    #expect(b >= a + 1)
}

@Test func isSatisfiableCatchesSeasonalFreeze() {
    // America/New_York, daily slot at 00:00 UTC, quiet 19:00-20:00 local.
    // 00:00 UTC is 19:00 EST (quiet) in winter, 20:00 EDT (not quiet) in summer.
    // A year-long walk therefore hits a winter freeze from either start date.
    let cal = utcCalendar("America/New_York")
    let s = Schedule(intervalMinutes: 1440, quietHours: qh(19 * 60, 20 * 60))
    #expect(!isSatisfiable(schedule: s, calendar: cal, anchor: anchor2026))
    // January: the next delivery is weeks away. July: within a day.
    let jan = date(2026, 1, 10, 12, 0, tz: "America/New_York")
    let jul = date(2026, 7, 10, 12, 0, tz: "America/New_York")
    #expect(nextDelivery(after: jan, schedule: s, calendar: cal)!.timeIntervalSince(jan) > 30 * 86_400)
    #expect(nextDelivery(after: jul, schedule: s, calendar: cal)!.timeIntervalSince(jul) <= 86_400)
}

@Test func isSatisfiableControlHourlyIsTrue() {
    let cal = utcCalendar("America/New_York")
    let s = Schedule(intervalMinutes: 60, quietHours: qh(19 * 60, 20 * 60))
    #expect(isSatisfiable(schedule: s, calendar: cal, anchor: anchor2026))
}


// Bug #3 regression gate (Ian): the shipped default must validate in DST zones.
@Test func defaultScheduleIsSatisfiableInDSTZones() {
    let s = Schedule(intervalMinutes: 60, quietHours: qh(22 * 60, 7 * 60))
    for z in ["America/New_York", "Europe/London", "Australia/Sydney", "Asia/Tokyo"] {
        #expect(isSatisfiable(schedule: s, calendar: utcCalendar(z), anchor: anchor2026), "default schedule rejected in \(z)")
    }
}

// Rachel: quiet hours that don't end on a slot boundary need 2x interval slack.
@Test func quietEndOffSlotBoundaryIsSatisfiable() {
    for z in ["America/New_York", "Europe/London", "Australia/Sydney"] {
        let s = Schedule(intervalMinutes: 60, quietHours: qh(22 * 60, 6 * 60 + 30))
        #expect(isSatisfiable(schedule: s, calendar: utcCalendar(z), anchor: anchor2026), "\(z)")
    }
}

@Test func oddIntervalsAreSatisfiable() {
    for z in ["America/New_York", "Australia/Sydney", "Australia/Lord_Howe", "Asia/Kolkata"] {
        for iv in [7, 45, 90, 180] {
            let s = Schedule(intervalMinutes: iv, quietHours: qh(22 * 60, 7 * 60))
            #expect(isSatisfiable(schedule: s, calendar: utcCalendar(z), anchor: anchor2026), "\(z) \(iv)")
        }
    }
}

// Bug #4 gate (Rachel): validation must use current tz rules, not 2001's.
// Each case must give the wrong answer on a 2001 anchor and the right one on 2026.
@Test func saoPauloLostDSTUsesCurrentRules() {
    // SP has been UTC-3 all year since 2019: 00:00Z = 21:00 local, never quiet.
    let cal = utcCalendar("America/Sao_Paulo")
    let s = Schedule(intervalMinutes: 1440, quietHours: qh(22 * 60, 23 * 60))
    #expect(!isSatisfiable(schedule: s, calendar: cal, anchor: anchor2001))
    #expect(isSatisfiable(schedule: s, calendar: cal, anchor: anchor2026))
}

@Test func casablancaGainedDSTUsesCurrentRules() {
    // Morocco is UTC+1 except Ramadan: 00:00Z = 01:00 local, quiet most of the year.
    let cal = utcCalendar("Africa/Casablanca")
    let s = Schedule(intervalMinutes: 1440, quietHours: qh(1 * 60, 2 * 60))
    #expect(isSatisfiable(schedule: s, calendar: cal, anchor: anchor2001))
    #expect(!isSatisfiable(schedule: s, calendar: cal, anchor: anchor2026))
}


// MARK: - Word bundle gate (Rachel, Friday 23 Oct)

private let bundle: [Word] = try! bundledWords()

@Test func bundleCountIsNotAMultipleOf24() {
    #expect(bundle.count == 789)
    #expect(bundle.count % 24 != 0)
}

@Test func bundleStartsWith92KanaThenN5() {
    let kana = bundle.prefix(92)
    #expect(kana.allSatisfy { $0.partOfSpeech == "hiragana" || $0.partOfSpeech == "katakana" })
    #expect(kana.allSatisfy { $0.level == nil && $0.orthography == $0.reading })
    #expect(kana.filter { $0.partOfSpeech == "hiragana" }.count == 46)
    #expect(bundle.dropFirst(92).allSatisfy { $0.level == .jlpt(5) && $0.language == .japanese })
}

@Test func bundleOrthographyReadingPairsAndIdsAreUnique() {
    #expect(Set(bundle.map { "\($0.orthography)|\($0.reading)" }).count == bundle.count)
    #expect(Set(bundle.map(\.id)).count == bundle.count)
}

@Test func bundleTextHasNoListFormatting() {
    let banned = CharacterSet(charactersIn: " ()（）;；～〜").union(.whitespacesAndNewlines)
    for w in bundle {
        #expect(w.orthography.rangeOfCharacter(from: banned) == nil, "\(w.orthography)")
        #expect(w.reading.rangeOfCharacter(from: banned) == nil, "\(w.reading)")
        #expect(!w.meanings.isEmpty && !w.meanings[0].isEmpty, "\(w.orthography)")
    }
}

@Test func bundleHasExactly11LongWords() {
    #expect(bundle.filter { $0.orthography.count >= 5 }.count == 11)
}

@Test func bundleDroppedAffixes() {
    // N5 part only: hiragana お is a kana entry, and stays.
    let pairs = Set(bundle.dropFirst(92).map { "\($0.orthography)|\($0.reading)" })
    for p in ["お|お", "人|じん", "中|じゅう", "たち|たち", "がる|がる", "さん|さん"] {
        #expect(!pairs.contains(p), "\(p)")
    }
}

@Test func bundleEqualOrthographiesAre24SlotsApart() {
    var at: [String: [Int]] = [:]
    for (i, w) in bundle.enumerated() { at[w.orthography, default: []].append(i) }
    let n = bundle.count
    for (o, ps) in at where ps.count > 1 {
        for a in 0..<ps.count { for b in (a + 1)..<ps.count {
            let d = abs(ps[a] - ps[b])
            #expect(min(d, n - d) >= 24, "\(o) at \(ps[a]) and \(ps[b])")
        } }
    }
}

@Test func everyBundleWordIsShownWithinAYear() {
    // Default schedule: hourly, quiet 22:00-07:00, in a DST zone and a non-DST zone.
    let s = Schedule(intervalMinutes: 60, quietHours: qh(22 * 60, 7 * 60))
    for z in ["America/New_York", "Asia/Tokyo"] {
        let cal = utcCalendar(z)
        var seen = Set<String>()
        var cur = anchor2026
        let end = anchor2026.addingTimeInterval(366 * 86_400)
        while cur < end, let next = nextDelivery(after: cur, schedule: s, calendar: cal) {
            seen.insert(pickWord(for: slot(for: next, intervalMinutes: 60), from: bundle)!.id)
            cur = next
        }
        #expect(seen.count == bundle.count, "\(z): \(bundle.count - seen.count) words never shown")
    }
}

@Test func levelRoundTripsInBundleFormat() throws {
    let w = Word(id: "x", language: .chinese, orthography: "你", reading: "nǐ", meanings: ["you"],
                 partOfSpeech: "pronoun", level: .hsk(1), isCommon: true)
    let json = String(decoding: try JSONEncoder().encode(w), as: UTF8.self)
    #expect(json.contains("\"level\":{\"hsk\":1}"))
    #expect(try JSONDecoder().decode(Word.self, from: Data(json.utf8)) == w)
    #expect(throws: (any Error).self) { try decodeWords(from: Data(#"[{"id":"x","language":"ja","orthography":"a","reading":"a","meanings":[],"isCommon":true,"level":{"jlpt":5,"hsk":1}}]"#.utf8)) }
}
