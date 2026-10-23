import Foundation
import Testing
@testable import KanaCore

private let zh: [Word] = try! bundledWords(.chinese)
private func cal(_ id: String) -> Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: id)!; return c }

@Test func chinesePackLoads() {
    #expect(zh.count == 2207)
    #expect(zh.allSatisfy { $0.language == .chinese })
    for lv in 1...3 { #expect(zh.contains { $0.level == .hsk(lv) }) }
    #expect(zh.allSatisfy { $0.level?.scale == "hsk" && (1...3).contains($0.level!.value) })
}

@Test func chineseCountIsSafeForEveryOfferedInterval() {
    func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
    for iv in Settings.offeredIntervals { #expect(gcd(zh.count, 1440 / iv) == 1, "\(iv) min") }
}

@Test func chineseEveryWordShownAtEveryOfferedInterval() {
    let anchor = Date(timeIntervalSince1970: 1_767_225_600)
    for iv in Settings.offeredIntervals {
        var s = Settings.defaults; s.intervalMinutes = iv
        let sched = Schedule.from(settings: s)
        var seen = Set<String>(); var cur = anchor
        let end = anchor.addingTimeInterval(TimeInterval(zh.count * iv * 60 * (1440 / iv + 1)))
        while cur < end, let next = nextDelivery(after: cur, schedule: sched, calendar: cal("Asia/Shanghai")) {
            seen.insert(pickWord(for: slot(for: next, intervalMinutes: iv), from: zh)!.id)
            cur = next
        }
        #expect(seen.count == zh.count, "\(iv) min: \(zh.count - seen.count) never shown")
    }
}

@Test func chineseTextRules() {
    #expect(Set(zh.map { "\($0.orthography)|\($0.reading)" }).count == zh.count)
    #expect(Set(zh.map(\.id)).count == zh.count)
    for w in zh {
        #expect(!w.meanings[0].isEmpty && w.meanings[0].count <= 22, "\(w.orthography): \(w.meanings[0])")
        #expect(w.meanings[0].filter { $0 == "(" }.count == w.meanings[0].filter { $0 == ")" }.count, "\(w.orthography)")
        #expect(w.orthography.count <= 8, "\(w.orthography) too long for the circular widget")
        #expect(!w.meanings.contains { $0.localizedCaseInsensitiveContains("(vulgar)") || $0.localizedCaseInsensitiveContains("euphemis") }, "\(w.orthography)")
        #expect(w.reading.rangeOfCharacter(from: .decimalDigits) == nil, "\(w.orthography): \(w.reading)")
    }
}

@Test func chineseHeteronymsUseTheHandPickedPair() {
    // A sample from tools/zh_heteronyms.tsv; the build script checks all 141.
    let byWord = Dictionary(uniqueKeysWithValues: zh.map { ($0.orthography, $0) })
    for (w, r, m) in [("比", "bǐ", "to compare"), ("了", "le", "completed action"), ("行", "xíng", "to walk; OK"),
                      ("告诉", "gàosu", "to tell"), ("厂", "chǎng", "factory"), ("鸟", "niǎo", "bird"),
                      ("干", "gàn", "to do; to work"), ("差", "chà", "to lack; poor")] {
        #expect(byWord[w]?.reading == r, "\(w)")
        #expect(byWord[w]?.meanings.first == m, "\(w)")
    }
}

@Test func chineseVoiceOverIsTaggedChinese() {
    for w in zh {
        let parts = spokenLabel(for: w)
        #expect(parts.first == SpokenPart(w.orthography, "zh-Hans"))
        #expect(!parts.contains { $0.language == "ja" })
    }
}

@Test func chineseRachelsReadFixes() {
    let byWord = Dictionary(uniqueKeysWithValues: zh.map { ($0.orthography, $0) })
    #expect(byWord["子"] == nil && byWord["们"] == nil)             // rule 8
    #expect(byWord["女儿"]?.reading == "nǚ'ér")                      // apostrophe
    #expect(byWord["笑话儿"]?.reading == "xiàohuar")                 // no tone digit
    #expect(byWord["好处"]?.reading == "hǎochù")                     // official tone wins
    for (w, m) in [("药", "medicine"), ("后", "back; after"), ("云", "cloud"), ("钱", "money"),
                   ("奶", "milk"), ("可乐", "cola"), ("本", "measure word: books"), ("称", "to call; to weigh")] {
        #expect(byWord[w]?.meanings.first == m, "\(w)")
    }
}
