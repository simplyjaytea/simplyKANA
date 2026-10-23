import XCTest
import KanaCore
@testable import SimplyKANA

/// lock-screen-widget-spec §1b: deep links carry the language; the older form
/// without one opens as Japanese; the app's Language row changes the app's
/// word with no App Group present.
final class AppLanguageTests: XCTestCase {
    private func fresh() -> UserDefaults {
        let name = "app-lang-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func testDeepLinkWithLanguageOpensThatWord() throws {
        let w = try XCTUnwrap(AppLanguage.words(.japanese).first { $0.orthography == "日" })
        let url = try XCTUnwrap(URL(string: "simplykana://word/ja/\(w.id)"))
        XCTAssertEqual(AppLanguage.word(from: url), w)
    }

    func testLegacyDeepLinkOpensAsJapanese() throws {
        let w = try XCTUnwrap(AppLanguage.words(.japanese).first)
        let url = try XCTUnwrap(URL(string: "simplykana://word/\(w.id)"))
        XCTAssertEqual(AppLanguage.word(from: url), w)
    }

    /// Ids contain ":" (jmdict:1234); the current widget link percent-encodes them.
    func testPercentEncodedIdStillOpens() throws {
        let w = try XCTUnwrap(AppLanguage.words(.japanese).first { $0.id.contains(":") })
        XCTAssertEqual(AppLanguage.word(from: wordURL(w)), w)
    }

    func testUnknownLanguageOrIdOpensNothing() throws {
        XCTAssertNil(AppLanguage.word(from: try XCTUnwrap(URL(string: "simplykana://word/xx/123"))))
        XCTAssertNil(AppLanguage.word(from: try XCTUnwrap(URL(string: "simplykana://word/ja/not-a-word"))))
        XCTAssertNil(AppLanguage.word(from: try XCTUnwrap(URL(string: "https://example.com/word/1"))))
    }

    /// The sideload case: no App Group, and the Language row still changes the
    /// app's word. Runs once a second pack is installed.
    func testLanguageRowChangesTheAppsWordWithoutAppGroup() throws {
        try XCTSkipUnless(installedPacks.contains(.chinese), "needs the Chinese pack")
        let app = fresh()
        let now = Date(timeIntervalSince1970: 1_792_000_000)
        XCTAssertEqual(AppLanguage.currentWord(at: now, defaults: app).language, .japanese)
        AppLanguage.set(.chinese, app)
        XCTAssertEqual(AppLanguage.currentWord(at: now, defaults: app).language, .chinese)
    }
}
