import Foundation

// Pure Swift core: no UIKit, WidgetKit, or I/O.

/// A language code (BCP-47), e.g. "ja", "zh-Hans", "ko". Open-ended: a new language
/// is a new pack file, not a new case. The constants are conveniences, not a list.
public struct Language: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ code: String) { self.rawValue = code }
    public var description: String { rawValue }

    public static let japanese = Language("ja")
    public static let chinese = Language("zh-Hans")
    public static let korean = Language("ko")

    public init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}

/// Learner level on a pack's own scale: JLPT 5 (easiest) ... 1; HSK 1 (easiest) ... 9;
/// NIKL 1 ... 3. Open-ended: the scale name comes from the pack. Labels for the UI
/// come from the pack manifest, not from Swift.
public struct Level: Hashable, Sendable, Codable {
    public let scale: String
    public let value: Int
    public init(scale: String, value: Int) { self.scale = scale; self.value = value }

    public static func jlpt(_ n: Int) -> Level { Level(scale: "jlpt", value: n) }
    public static func hsk(_ n: Int) -> Level { Level(scale: "hsk", value: n) }
    public static func nikl(_ n: Int) -> Level { Level(scale: "nikl", value: n) }

    // Pack format is a one-key object, e.g. {"jlpt": 5}.
    private struct Key: CodingKey {
        let stringValue: String
        init(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        guard c.allKeys.count == 1, let k = c.allKeys.first else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath,
                debugDescription: "level must have exactly one key, the scale"))
        }
        self.init(scale: k.stringValue, value: try c.decode(Int.self, forKey: k))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        try c.encode(value, forKey: Key(stringValue: scale))
    }
}

public struct Word: Identifiable, Equatable, Hashable, Sendable, Codable {
    public let id: String          // stable source id, e.g. "jmdict:1000000"
    public let language: Language
    public let orthography: String
    public let reading: String     // kana, pinyin, or hangul/romanization
    public let meanings: [String]
    public let partOfSpeech: String?
    public let level: Level?       // nil = foundation tier (kana, jamo) or unleveled
    public let isCommon: Bool

    public init(id: String, language: Language, orthography: String, reading: String,
                meanings: [String], partOfSpeech: String?, level: Level?, isCommon: Bool) {
        self.id = id
        self.language = language
        self.orthography = orthography
        self.reading = reading
        self.meanings = meanings
        self.partOfSpeech = partOfSpeech
        self.level = level
        self.isCommon = isCommon
    }
}

public struct TimeOfDay: Equatable, Sendable {
    public let minutes: Int // 0..<1440
    public init(minutes: Int) { self.minutes = minutes }
}

public struct QuietHours: Equatable, Sendable {
    public let start: TimeOfDay
    public let end: TimeOfDay   // start > end crosses midnight

    /// Returns nil for invalid config: start == end is rejected, not "no quiet hours".
    public init?(start: TimeOfDay, end: TimeOfDay) {
        guard (0..<1440).contains(start.minutes), (0..<1440).contains(end.minutes),
              start.minutes != end.minutes else { return nil }
        self.start = start
        self.end = end
    }
}

public struct Schedule: Equatable, Sendable {
    public let intervalMinutes: Int
    public let quietHours: QuietHours?
    public init(intervalMinutes: Int, quietHours: QuietHours?) {
        self.intervalMinutes = intervalMinutes
        self.quietHours = quietHours
    }
}

let epoch = Date(timeIntervalSinceReferenceDate: 0) // 2001-01-01Z

/// Monotonic slot index from 2001-01-01Z. Pure epoch arithmetic; no timezone.
public func slot(for date: Date, intervalMinutes: Int) -> Int {
    precondition(intervalMinutes > 0)
    let seconds = date.timeIntervalSince(epoch)
    return Int((seconds / Double(intervalMinutes * 60)).rounded(.down))
}

/// Start inclusive, end exclusive; handles midnight crossing.
public func isQuiet(at date: Date, quietHours: QuietHours, calendar: Calendar) -> Bool {
    let comps = calendar.dateComponents([.hour, .minute], from: date)
    let m = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    let s = quietHours.start.minutes
    let e = quietHours.end.minutes
    if s < e { return m >= s && m < e }
    return m >= s || m < e
}

/// Strictly after `date`, skips quiet hours. Returns nil when no non-quiet slot
/// exists within the search bound (e.g. a daily slot always inside quiet hours).
public func nextDelivery(after date: Date, schedule: Schedule, calendar: Calendar) -> Date? {
    let interval = TimeInterval(schedule.intervalMinutes * 60)
    let current = slot(for: date, intervalMinutes: schedule.intervalMinutes)
    var candidate = epoch.addingTimeInterval(TimeInterval(current + 1) * interval)
    guard let q = schedule.quietHours else { return candidate }
    for _ in 0..<10_000 {
        if !isQuiet(at: candidate, quietHours: q, calendar: calendar) { return candidate }
        candidate = candidate.addingTimeInterval(interval)
    }
    return nil
}

/// Config-time check, not for the delivery path. Walks deliveries across the 366
/// days after `anchor`. Pass the current date so the check uses the timezone
/// rules the user lives under now; the function reads no clock. Returns false if any
/// delivery's successor is nil or lands more than (2 * interval + quiet span + 1h)
/// after it. Two intervals: the last slot before quiet hours and the first slot
/// after can each sit up to one interval outside the window when quiet hours
/// don't align to slots. One hour: fall-back nights run an hour long. Quiet
/// hours pause the drip; they do not shift it.
public func isSatisfiable(schedule: Schedule, calendar: Calendar, anchor: Date) -> Bool {
    let intervalSec = schedule.intervalMinutes * 60
    let quietSec = (schedule.quietHours.map { ($0.end.minutes - $0.start.minutes + 1440) % 1440 } ?? 0) * 60
    let maxGap = TimeInterval(2 * intervalSec + quietSec + 3_600)
    let horizon = anchor.addingTimeInterval(366 * 86_400)
    var cur = anchor
    while cur < horizon {
        guard let next = nextDelivery(after: cur, schedule: schedule, calendar: calendar) else { return false }
        if next.timeIntervalSince(cur) > maxGap { return false }
        cur = next
    }
    return true
}

/// nil iff words is empty.
public func pickWord(for slot: Int, from words: [Word]) -> Word? {
    guard !words.isEmpty else { return nil }
    let i = ((slot % words.count) + words.count) % words.count
    return words[i]
}
