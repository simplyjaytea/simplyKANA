import XCTest
import SwiftUI
import UIKit
import KanaCore
@testable import SimplyKANA

/// Rachel's #39 gate: the widget draws shared characters in the word's own language's
/// shapes, not the phone's. 直, 骨 and 角 differ between Chinese and Japanese.
@MainActor
final class WidgetFontTests: XCTestCase {
    private func word(_ lang: Language) -> Word {
        // Same orthography, reading and meaning in both languages (Rachel, #39): the only
        // thing that differs is the language, so a system font would draw them identically.
        Word(id: "test", language: lang, orthography: "直骨角", reading: "直骨角",
             meanings: ["shapes test"], partOfSpeech: "noun", level: nil, isCommon: true)
    }

    private func png<V: View>(_ view: V, _ size: CGSize, _ name: String) throws -> Data {
        let r = ImageRenderer(content: view.frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark).background(Color.black).foregroundStyle(.white))
        r.scale = 3
        let data = try XCTUnwrap(r.uiImage?.pngData(), name)
        if let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
            try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
        return data
    }

    func testWidgetFontComesFromTheWordsLanguage() throws {
        try XCTSkipUnless(installedPacks.contains(.chinese), "Chinese pack is parked (planned); runs again when it ships")
        let ja = ScriptFonts.name(.japanese, .orthography)
        let zh = ScriptFonts.name(.chinese, .orthography)
        XCTAssertNotNil(ja, "no Japanese face installed")
        XCTAssertNotNil(zh, "no Chinese face installed")
        XCTAssertNotEqual(ja, zh)
    }

    func testChineseAndJapaneseWidgetsDrawDifferentShapes() throws {
        try XCTSkipUnless(installedPacks.contains(.chinese), "Chinese pack is parked (planned); runs again when it ships")
        let rect = CGSize(width: 160, height: 72), circ = CGSize(width: 76, height: 76)
        let rJa = try png(RectangularWordView(word: word(.japanese)), rect, "widget-rect-直骨角-ja")
        let rZh = try png(RectangularWordView(word: word(.chinese)), rect, "widget-rect-直骨角-zh")
        let cJa = try png(CircularWordView(word: word(.japanese)), circ, "widget-circ-直骨角-ja")
        let cZh = try png(CircularWordView(word: word(.chinese)), circ, "widget-circ-直骨角-zh")
        // The system font would draw both languages identically.
        XCTAssertNotEqual(rJa, rZh, "rectangular widget draws the same shapes for both languages")
        XCTAssertNotEqual(cJa, cZh, "circular widget draws the same shapes for both languages")
    }
}
