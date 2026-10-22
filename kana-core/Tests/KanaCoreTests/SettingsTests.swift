import Foundation
import Testing
@testable import KanaCore

private func cal(_ id: String) -> Calendar {
    var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: id)!; return c
}
private let anchor = Date(timeIntervalSince1970: 1_767_225_600) // 2026-01-01Z

// Gate 1
@Test func settingsDefaultsWhenKeysMissing() {
    #expect(Settings(values: [:]) == .defaults)
    #expect(Schedule.from(settings: .defaults) == Schedule(intervalMinutes: 60,
        quietHours: QuietHours(start: TimeOfDay(minutes: 1320), end: TimeOfDay(minutes: 420))))
}

@Test func settingsRoundTripEveryOfferedCombination() {
    for iv in Settings.offeredIntervals {
        for on in [true, false] {
            for (s, e) in [(1320, 420), (0, 360), (1380, 1395), (600, 605)] {
                let x = Settings(intervalMinutes: iv, quietEnabled: on, quietStartMinutes: s,
                                 quietEndMinutes: e, languagePack: "ja", level: "N5")
                #expect(Settings(values: x.values) == x)
                let sched = Schedule.from(settings: x)
                #expect(sched.intervalMinutes == iv)
                #expect((sched.quietHours != nil) == on)
            }
        }
    }
}

@Test func settingsRejectDamagedValues() {
    let bad: [String: Any] = ["intervalMinutes": 7, "quietStartMinutes": 5000, "quietEndMinutes": -1,
                              "quietEnabled": "yes"]
    let s = Settings(values: bad)
    #expect(s.intervalMinutes == 60)
    #expect(s.quietStartMinutes == 1320 && s.quietEndMinutes == 420)
    #expect(s.quietEnabled == true)
}

@Test func scheduleNeverHasEmptyQuietHours() {
    var s = Settings.defaults
    s.quietStartMinutes = 600; s.quietEndMinutes = 600
    #expect(Schedule.from(settings: s).quietHours == nil)
    #expect(refusal(for: s, calendar: cal("UTC"), anchor: anchor) == .emptyQuietHours)
}

// Gate 2
@Test func everyOfferedIntervalIsSatisfiableEverywhere() {
    let zones = ["America/New_York", "Europe/London", "Australia/Sydney", "Asia/Tokyo", "Asia/Kolkata",
                 "Australia/Lord_Howe", "Pacific/Chatham", "America/Sao_Paulo", "Africa/Casablanca"]
    for iv in Settings.offeredIntervals {
        var s = Settings.defaults; s.intervalMinutes = iv
        for z in zones {
            #expect(refusal(for: s, calendar: cal(z), anchor: anchor) == nil, "\(iv) min in \(z)")
        }
    }
}

@Test func refusalCatchesAStarvingSchedule() {
    // 6-hourly with 22:00-07:00 quiet is fine; 6-hourly with 23 quiet hours starves.
    var s = Settings.defaults; s.intervalMinutes = 360
    s.quietStartMinutes = 60; s.quietEndMinutes = 0
    #expect(refusal(for: s, calendar: cal("Asia/Tokyo"), anchor: anchor) == .starves)
}

// Gate 3
@Test func bundleCountHasNoCommonFactorWithAnyOfferedInterval() throws {
    let n = try bundledWords().count
    func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
    for iv in Settings.offeredIntervals {
        #expect(gcd(n, 1440 / iv) == 1, "\(n) words, \(1440 / iv) slots a day")
    }
}

@Test func everyWordShownAtEveryOfferedInterval() throws {
    let words = try bundledWords()
    for iv in Settings.offeredIntervals {
        var s = Settings.defaults; s.intervalMinutes = iv
        let sched = Schedule.from(settings: s)
        let c = cal("America/New_York")
        var seen = Set<String>(); var cur = anchor
        // A word skipped by quiet hours comes back one slot-of-day later each cycle
        // (gcd = 1), so slots-per-day full cycles reach every word.
        let cycles = 1440 / iv + 1
        let end = anchor.addingTimeInterval(TimeInterval(words.count * iv * 60 * cycles))
        while cur < end, let next = nextDelivery(after: cur, schedule: sched, calendar: c) {
            seen.insert(pickWord(for: slot(for: next, intervalMinutes: iv), from: words)!.id)
            cur = next
        }
        #expect(seen.count == words.count, "\(iv) min: \(words.count - seen.count) never shown")
    }
}

// Gate 4b
@Test func changingIntervalChangesTheWordOnScreen() {
    let words = (0..<781).map { Word(id: "w\($0)", language: .japanese, orthography: "w\($0)", reading: "w\($0)",
                                     meanings: ["x"], partOfSpeech: nil, level: nil, isCommon: true) }
    let c = cal("America/New_York")
    let now = c.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 15, minute: 10))!
    var a = Settings.defaults; a.intervalMinutes = 60
    var b = Settings.defaults; b.intervalMinutes = 120
    let wa = timeline(after: now, schedule: .from(settings: a), words: words, calendar: c, limit: 0).entries[0].word
    let wb = timeline(after: now, schedule: .from(settings: b), words: words, calendar: c, limit: 0).entries[0].word
    #expect(wa != wb)
}

@Test func changingQuietHoursOutsideTheWindowKeepsTheWord() {
    let words = (0..<781).map { Word(id: "w\($0)", language: .japanese, orthography: "w\($0)", reading: "w\($0)",
                                     meanings: ["x"], partOfSpeech: nil, level: nil, isCommon: true) }
    let c = cal("America/New_York")
    let now = c.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 15, minute: 10))!
    var b = Settings.defaults; b.quietStartMinutes = 23 * 60; b.quietEndMinutes = 6 * 60
    let wa = timeline(after: now, schedule: .from(settings: .defaults), words: words, calendar: c, limit: 0).entries[0]
    let wb = timeline(after: now, schedule: .from(settings: b), words: words, calendar: c, limit: 0).entries[0]
    #expect(wa == wb)
}
