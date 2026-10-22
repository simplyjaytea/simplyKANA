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

    /// Without the App Group the widget can't see saved settings, so the app must
    /// not use them either: the word in the app has to match the Lock Screen.
    func testWithoutAppGroupTheAppRunsOnDefaults() {
        let d = fresh()
        let store = SettingsStore(defaults: d, reload: {})
        var s = Settings.defaults; s.intervalMinutes = 30
        XCTAssertNil(store.commit(s))
        XCTAssertEqual(SettingsStore.effective(shared: false, from: d), .defaults)
        XCTAssertEqual(SettingsStore.effective(shared: true, from: d).intervalMinutes, 30)
    }

    /// CI builds are unsigned, so this is the no-App-Group path end to end:
    /// the schedule the app uses is the default one.
    func testUnsignedBuildUsesDefaultSchedule() throws {
        try XCTSkipIf(SettingsStore.isShared, "App Group available on this run")
        XCTAssertEqual(currentSchedule, Schedule.from(settings: .defaults))
    }
}

