import XCTest
import SwiftUI
import UIKit
import KanaCore
@testable import SimplyKANA

/// Settings screen gates (settings-spec §4.4, §4.5): one save per finished
/// edit, refusals leave settings untouched and sit under their section, and
/// snapshots in light and dark at default and AX5, including the refusal.
@MainActor
final class SettingsScreenTests: XCTestCase {
    private var tokyo: Calendar = {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Tokyo")!; return c
    }()
    private let anchor = Date(timeIntervalSince1970: 1_792_000_000) // Oct 2026

    private func fresh() -> UserDefaults {
        let name = "settings-ui-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    final class Counter { var count = 0 }

    private func model(_ d: UserDefaults, reloads: Counter = Counter()) -> SettingsModel {
        let store = SettingsStore(defaults: d, reload: { reloads.count += 1 })
        return SettingsModel(store: store, now: { self.anchor }, calendar: tokyo)
    }

    /// Scrolling the picker from 22:00 to 08:00 is 40 ticks and exactly one save.
    func testScrollingAQuietTimeSavesOnceWhenTheSheetCloses() {
        let d = fresh()
        let reloads = Counter()
        let m = model(d, reloads: reloads)
        m.beginEditing(.start)
        for step in 0...40 { m.draftMinutes = (22 * 60 + step * 15) % 1440 }
        XCTAssertEqual(SettingsStore.load(from: d).quietStartMinutes, 22 * 60, "saved before the edit ended")
        m.editing = nil
        m.finishEditing()
        XCTAssertEqual(SettingsStore.load(from: d).quietStartMinutes, 8 * 60)
        XCTAssertEqual(reloads.count, 1)
    }

    func testClosingTheSheetUnchangedSavesNothing() {
        let d = fresh()
        let reloads = Counter()
        let m = model(d, reloads: reloads)
        m.beginEditing(.end)
        m.editing = nil
        m.finishEditing()
        XCTAssertEqual(reloads.count, 0)
    }

    func testSelectingAnIntervalSavesIt() {
        let d = fresh()
        let m = model(d)
        m.select(interval: 180)
        XCTAssertEqual(SettingsStore.load(from: d).intervalMinutes, 180)
        XCTAssertNil(m.refusal(in: .interval))
    }

    /// Quiet from 01:00 until 00:00 leaves one hour: 6-hourly starves. The
    /// refusal shows under Quiet hours, and the stored settings don't move.
    func testRefusalSitsUnderItsSectionAndSavesNothing() {
        let d = fresh()
        let m = model(d)
        m.select(interval: 360)
        m.beginEditing(.start); m.draftMinutes = 60; m.editing = nil; m.finishEditing()
        m.beginEditing(.end); m.draftMinutes = 0; m.editing = nil; m.finishEditing()
        XCTAssertNotNil(m.refusal(in: .quiet))
        XCTAssertNil(m.refusal(in: .interval))
        XCTAssertEqual(SettingsStore.load(from: d).quietEndMinutes, 7 * 60)
    }

    func testCopy() {
        XCTAssertEqual(Settings.offeredIntervals.map(SettingsCopy.interval),
                       ["30 minutes", "1 hour", "2 hours", "3 hours", "6 hours"])
        XCTAssertEqual(SettingsCopy.time(7 * 60), "07:00")
        XCTAssertEqual(SettingsCopy.level("N5"), "JLPT N5")
        XCTAssertEqual(SettingsCopy.language("ja"), "Japanese")
    }

    func testSnapshots() throws {
        let refused = model(fresh())
        refused.select(interval: 360)
        refused.beginEditing(.end); refused.draftMinutes = 0; refused.editing = nil; refused.finishEditing()
        refused.beginEditing(.start); refused.draftMinutes = 60; refused.editing = nil; refused.finishEditing()
        XCTAssertNotNil(refused.refusal(in: .quiet))

        let states: [(String, SettingsModel)] = [("default", model(fresh())), ("refused", refused)]
        for (state, m) in states {
            for scheme in [ColorScheme.light, .dark] {
                for type in [DynamicTypeSize.large, .accessibility3] {
                    let name = "settings-\(state)-\(scheme == .dark ? "dark" : "light")-\(type == .large ? "default" : "ax3")"
                    let view = SettingsContent(model: m)
                        .frame(width: 375)
                        .fixedSize(horizontal: false, vertical: true)
                        .environment(\.colorScheme, scheme)
                        .environment(\.dynamicTypeSize, type)
                    let r = ImageRenderer(content: view)
                    r.scale = 2
                    let image = try XCTUnwrap(r.uiImage, name)
                    XCTAssertEqual(image.size.width, 375, accuracy: 1)
                    if let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], let png = image.pngData() {
                        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                        try png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
                    }
                }
            }
        }
    }
}
