import Foundation
import Testing
@testable import KanaCore

@Test func wordLinkRoundTripsEveryWordInEveryPack() throws {
    for lang in [Language.japanese, .chinese] {
        for w in try bundledWords(lang) {
            let target = parseWordLink(wordLink(for: w))
            #expect(target == .word(lang, id: w.id), "\(w.id)")
            #expect(word(for: target!) == w)
        }
    }
}

@Test func legacyLinkOpensAsJapanese() throws {
    let w = try bundledWords(.japanese)[100]
    let legacy = URL(string: "simplykana://word/\(w.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)")!
    #expect(parseWordLink(legacy) == .word(.japanese, id: w.id))
    #expect(word(for: parseWordLink(legacy)!) == w)
}

@Test func unknownLanguageOpensCurrentWord() {
    #expect(parseWordLink(URL(string: "simplykana://word/xx/abc")!) == .current)
    #expect(parseWordLink(URL(string: "simplykana://word/ja/a/b")!) == .current)
    #expect(parseWordLink(URL(string: "https://example.com/word/ja/x")!) == nil)
    #expect(parseWordLink(URL(string: "simplykana://other/ja/x")!) == nil)
}

@Test func linkToMissingWordFindsNothing() {
    #expect(word(for: .word(.chinese, id: "cedict:不存在:x")) == nil)
    #expect(word(for: .current) == nil)
}

@Test func eachPackTimelineStaysInItsLanguage() throws {
    // §1b gate: a Chinese widget never shows a Japanese word, and vice versa.
    var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    let s = Schedule.from(settings: .defaults)
    let now = Date(timeIntervalSince1970: 1_767_225_600)
    for lang in [Language.japanese, .chinese] {
        let t = timeline(after: now, schedule: s, words: try bundledWords(lang), calendar: c, limit: 48)
        #expect(t.entries.allSatisfy { $0.word.language == lang })
    }
}
