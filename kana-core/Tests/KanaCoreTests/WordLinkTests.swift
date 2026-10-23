import Foundation
import Testing
@testable import KanaCore

@Test func wordLinkRoundTripsEveryWordInEveryPack() throws {
    for lang in PackLibrary.shared.manifests.map(\.language) {
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
    for words in [try bundledWords(.japanese), try parkedPacks.pack(.chinese).words] {
        let lang = words[0].language
        let t = timeline(after: now, schedule: s, words: words, calendar: c, limit: 48)
        #expect(t.entries.allSatisfy { $0.word.language == lang })
    }
}

// MARK: - Packs (docs/pack-pipeline.md)

@Test func packsAreDiscoveredNotNamed() {
    let m = PackLibrary.shared.manifests
    // Chinese is parked (status "planned"): it's not in the app, so not discovered.
    #expect(m.map(\.language.rawValue) == ["ja"])
    #expect(m.map(\.widgetSlot) == [0])
    #expect(parkedPacks.manifests.map(\.language.rawValue) == ["zh-Hans"])
    #expect(Set(m.map(\.widgetSlot)).count == m.count, "two packs claim the same widget slot")
    for p in m {
        #expect(p.count == (try? bundledWords(p.language).count))
        #expect(p.placeholder.language == p.language)
        #expect(!p.credits.isEmpty)
    }
}

@Test func levelLabelsComeFromTheManifest() {
    #expect(PackLibrary.shared.manifest(for: .japanese)?.levelLabel(.jlpt(5)) == "N5")
    #expect(parkedPacks.manifest(for: .chinese)?.levelLabel(.hsk(2)) == "HSK 2")
}

@Test func aPackInATemporaryFolderIsPickedUp() throws {
    // Drop-in: a new language is a file. Copy the Japanese pack under a new code and
    // a new slot, and the library finds it without code changes.
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let ja = try PackLibrary.shared.pack(.japanese)
    let xx = Language("x-test")
    func relabel(_ w: Word) -> Word {
        Word(id: w.id, language: xx, orthography: w.orthography, reading: w.reading, meanings: w.meanings,
             partOfSpeech: w.partOfSpeech, level: w.level, isCommon: w.isCommon)
    }
    let m = ja.manifest
    let manifest = PackManifest(language: xx, name: "Test", widgetName: "simplyKANA · Test", widgetSlot: 2,
                                levelLabels: m.levelLabels, levelSummary: m.levelSummary, fonts: m.fonts,
                                voice: "en", speakReading: true, scriptPartsOfSpeech: [], placeholder: relabel(m.placeholder),
                                credits: m.credits, count: m.count)
    let data = try JSONEncoder().encode(Pack(manifest: manifest, words: ja.words.map(relabel)))
    try data.write(to: dir.appendingPathComponent("x-test.pack.json"))
    let lib = PackLibrary(directory: dir)
    #expect(lib.manifests.map(\.name) == ["Test"])
    #expect(try lib.pack(xx).words.count == 781)
}

@Test func aPackWithAWrongCountIsRejected() throws {
    let ja = try PackLibrary.shared.pack(.japanese)
    let bad = Pack(manifest: ja.manifest, words: Array(ja.words.dropLast()))
    #expect(throws: PackError.self) { try decodePack(from: JSONEncoder().encode(bad)) }
}

@Test func idsAreSafeInLinksAndStableAcrossToneFixes() throws {
    for m in PackLibrary.shared.manifests {
        for w in try bundledWords(m.language) {
            #expect(w.id.rangeOfCharacter(from: CharacterSet(charactersIn: "%/ ")) == nil, "\(w.id)")
        }
    }
    // 好处 is shown with the official tone (hǎochù) but keeps the dictionary entry's id,
    // so correcting a shown tone never breaks a link on a Lock Screen.
    for w in try parkedPacks.pack(.chinese).words {
        #expect(w.id.rangeOfCharacter(from: CharacterSet(charactersIn: "%/ ")) == nil, "\(w.id)")
    }
    let haochu = try parkedPacks.pack(.chinese).words.first { $0.orthography == "好处" }
    #expect(haochu?.reading == "hǎochù")
    #expect(haochu?.id == "cedict:好处:hao3chu5")
}

@Test func packsCarryTwoOrderedFontLists() {
    for m in PackLibrary.shared.manifests {
        #expect(!m.fonts.orthography.isEmpty && !m.fonts.reading.isEmpty, "\(m.language)")
    }
    #expect(parkedPacks.manifest(for: .chinese)?.fonts.reading.first == "NotoSerif-Regular")
}
