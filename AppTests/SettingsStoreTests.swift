import XCTest
import KanaCore
@testable import SimplyKANA

final class SettingsStoreTests: XCTestCase {
    private func fresh() -> UserDefaults {
        let name = "test-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }
    private let tokyo: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Tokyo")!; return c }()

    func testFreshStoreIsDefaults() {
        XCTAssertEqual(SettingsStore(defaults: fresh(), reload: {}).settings, .defaults)
    }

    func testCommitSavesAndReloadsOnce() {
        let d = fresh(); var reloads = 0
        let store = SettingsStore(defaults: d, reload: { reloads += 1 })
        var s = Settings.defaults; s.intervalMinutes = 120
        XCTAssertNil(store.commit(s, calendar: tokyo))
        XCTAssertEqual(SettingsStore.load(from: d).intervalMinutes, 120)
        XCTAssertEqual(reloads, 1)
    }

    /// Gate 4: a refused save leaves the previous settings stored, and no reload.
    func testRefusedSaveLeavesPreviousSettings() {
        let d = fresh(); var reloads = 0
        let store = SettingsStore(defaults: d, reload: { reloads += 1 })
        var bad = Settings.defaults
        bad.intervalMinutes = 360; bad.quietStartMinutes = 60; bad.quietEndMinutes = 0
        XCTAssertEqual(store.commit(bad, calendar: tokyo), .starves)
        XCTAssertEqual(SettingsStore.load(from: d), .defaults)
        XCTAssertEqual(store.settings, .defaults)
        XCTAssertEqual(store.lastRefusal, .starves)
        XCTAssertEqual(reloads, 0)
    }

    func testEveryRefusalHasOneSentence() {
        for r in [SettingsRefusal.starves, .emptyQuietHours] {
            XCTAssertFalse(r.message.isEmpty)
            XCTAssertTrue(r.message.hasSuffix("."))
        }
    }
}
