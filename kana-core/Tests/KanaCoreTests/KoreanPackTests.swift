import Foundation
import Testing
@testable import KanaCore

// Korean pack gates (docs/word-data-spec.md, Korean pack, first cut).
private let ko: [Word] = try! bundledWords(.korean)
private func cal(_ id: String) -> Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: id)!; return c }

@Test func koreanPackShape() {
    #expect(ko.count == 1813)
    #expect(ko.allSatisfy { $0.language == .korean })
    // 40 jamo first, as the foundation tier, with no level.
    let jamo = ko.prefix(40)
    #expect(jamo.allSatisfy { $0.partOfSpeech == "jamo" && $0.level == nil && $0.orthography.count == 1 })
    #expect(ko.dropFirst(40).allSatisfy { $0.level == .nikl(1) && $0.partOfSpeech != "jamo" })
}

@Test func koreanJamoShowBothSoundsWhereTheyHaveTwo() {
    let byLetter = Dictionary(uniqueKeysWithValues: ko.prefix(40).map { ($0.orthography, $0.meanings[0]) })
    #expect(byLetter["ㄱ"] == "g / k")
    #expect(byLetter["ㄹ"] == "r / l")
    #expect(byLetter["ㅇ"] == "silent / ng")
    #expect(byLetter["ㅁ"] == "m")
}

@Test func koreanOneEntryPerSpelling() {
    // Homographs (배 pear / boat / belly) share spelling and romanization: one entry each.
    #expect(Set(ko.map(\.orthography)).count == ko.count)
    #expect(Set(ko.map(\.id)).count == ko.count)
}

@Test func koreanReadingsAreRevisedRomanization() {
    let byWord = Dictionary(uniqueKeysWithValues: ko.map { ($0.orthography, $0.reading) })
    // Sound changes written, tensing not (word-data-spec; Rachel's examples).
    #expect(byWord["학교"] == "hakgyo")
    #expect(byWord["같이"] == "gachi")
    #expect(byWord["맛있다"] == "masitda")   // NIKL lists 마딛따 first; the spelling-faithful one is used
    #expect(byWord["계단"] == "gyedan")      // vowel from the spelling (said 게단)
    for w in ko.dropFirst(40) {
        #expect(w.reading.unicodeScalars.allSatisfy { ("a"..."z").contains($0) }, "\(w.orthography): \(w.reading)")
    }
}

@Test func koreanCountIsSafeAndEveryWordShows() {
    func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
    for iv in Settings.offeredIntervals { #expect(gcd(ko.count, 1440 / iv) == 1, "\(iv) min") }
    let anchor = Date(timeIntervalSince1970: 1_767_225_600)
    for iv in Settings.offeredIntervals {
        var s = Settings.defaults; s.intervalMinutes = iv
        var seen = Set<String>(); var cur = anchor
        let end = anchor.addingTimeInterval(TimeInterval(ko.count * iv * 60 * (1440 / iv + 1)))
        while cur < end, let next = nextDelivery(after: cur, schedule: .from(settings: s), calendar: cal("Asia/Seoul")) {
            seen.insert(pickWord(for: slot(for: next, intervalMinutes: iv), from: ko)!.id)
            cur = next
        }
        #expect(seen.count == ko.count, "\(iv) min: \(ko.count - seen.count) never shown")
    }
}

@Test func koreanManifest() {
    let m = PackLibrary.shared.manifest(for: .korean)
    #expect(m?.levelLabel(.nikl(1)) == "Beginner")
    #expect(m?.credits.first?.licence == "CC BY-SA 2.0 KR")   // kept, not relabelled (Rachel)
    #expect(m?.speakReading == false)
    let jamo = ko[0]
    #expect(spokenLabel(for: jamo) == [SpokenPart("ㄱ", "ko"), SpokenPart(", jamo, sounds g / k", nil)])
    let water = ko.first { $0.orthography == "물" }!
    #expect(spokenLabel(for: water) == [SpokenPart("물", "ko"), SpokenPart(", means water", nil)])
}

@Test func koreanFirstMeaningsFit() {
    for w in ko {
        #expect(!w.meanings[0].isEmpty && w.meanings[0].count <= 22, "\(w.orthography): \(w.meanings[0])")
    }
}
