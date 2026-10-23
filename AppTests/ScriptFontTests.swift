import XCTest
import SwiftUI
import UIKit
import KanaCore
@testable import SimplyKANA

/// Han characters are drawn differently in Chinese and Japanese (直, 骨, 角).
/// Each language must resolve to its own face, and the shapes must differ.
@MainActor
final class ScriptFontTests: XCTestCase {
    func testEveryLanguageResolvesToAnInstalledFace() {
        // Fonts come from each pack's manifest, so every installed pack must resolve.
        // (Korean joins this list when its pack lands, with its own font lists.)
        XCTAssertFalse(installedPacks.isEmpty)
        for lang in installedPacks {
            for role in [ScriptFonts.Role.orthography, .reading] {
                XCTAssertNotNil(ScriptFonts.name(lang, role), "\(lang) \(role): no installed face")
            }
        }
    }

    func testChineseAndJapaneseUseDifferentFaces() throws {
        try XCTSkipUnless(installedPacks.contains(.chinese), "Chinese pack is parked (planned); runs again when it ships")
        let ja = try XCTUnwrap(ScriptFonts.name(.japanese, .orthography))
        let zh = try XCTUnwrap(ScriptFonts.name(.chinese, .orthography))
        XCTAssertNotEqual(ja, zh)
        XCTAssertFalse(zh.lowercased().contains("hiragino"), "Chinese is set in a Japanese face: \(zh)")
        print("ScriptFonts resolved: ja=\(ja) zh=\(zh) ko=\(ScriptFonts.name(.korean, .orthography) ?? "nil") pinyin=\(ScriptFonts.name(.chinese, .reading) ?? "nil")")
    }

    /// Side by side, for a human look: Japanese, then Chinese.
    func testRenderShapeComparison() throws {
        try XCTSkipUnless(installedPacks.contains(.chinese), "Chinese pack is parked (planned); runs again when it ships")
        func page(_ lang: Language, _ o: String, _ r: String) -> some View {
            WordPage(word: Word(id: "shape:\(lang.rawValue):\(o)", language: lang, orthography: o, reading: r,
                                meanings: ["shape check"], partOfSpeech: "noun", level: nil, isCommon: true))
                .frame(width: 375, height: 520)
        }
        let view = HStack(spacing: 0) {
            page(.japanese, "直骨角", "ちょく")
            page(.chinese, "直骨角", "zhí gǔ jiǎo")
        }
        let r = ImageRenderer(content: view.environment(\.colorScheme, .light))
        r.scale = 2
        let image = try XCTUnwrap(r.uiImage)
        if let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], let png = image.pngData() {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("shapes-ja-vs-zh.png"))
        }
    }
}
