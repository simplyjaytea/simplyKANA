import XCTest
import SwiftUI
import UIKit
import KanaCore
@testable import SimplyKANA

/// Rendering gate for the Word and Credits screens (design-direction §2–4).
/// Each case renders in light and dark, at the default size and the largest
/// accessibility size, on a 6.1" iPhone and an iPhone SE. PNGs go to
/// $SNAPSHOT_DIR when set; CI uploads them as the `snapshots` artifact.
@MainActor
final class WordScreenSnapshotTests: XCTestCase {
    static let phone = CGSize(width: 393, height: 852)  // iPhone 15/16
    static let se = CGSize(width: 375, height: 667)     // iPhone SE (3rd gen), narrowest on iOS 17

    private func bundleWord(_ orthography: String, _ reading: String? = nil) throws -> Word {
        try XCTUnwrap(appWords.first { $0.orthography == orthography && (reading == nil || $0.reading == reading) },
                      "\(orthography) not in bundle")
    }

    private func cases() throws -> [(String, Word)] {
        let longestMeaning = try XCTUnwrap(appWords.max { ($0.meanings.first?.count ?? 0) < ($1.meanings.first?.count ?? 0) })
        return [
            ("hiragana-a", try bundleWord("あ")),
            ("katakana-a", try bundleWord("ア")),
            ("kanji-hito", try bundleWord("人", "ひと")),
            ("tapurekoda", try bundleWord("テープレコーダー")),
            ("longest-meaning", longestMeaning),
            ("fallback", fallbackWord),
        ]
    }

    @discardableResult
    private func render<V: View>(_ view: V, _ size: CGSize, _ scheme: ColorScheme,
                                 _ type: DynamicTypeSize, _ name: String) throws -> UIImage {
        let content = view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, scheme)
            .environment(\.dynamicTypeSize, type)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage, "\(name) did not render")
        XCTAssertEqual(image.size.width, size.width, accuracy: 1, name)
        save(image, name)
        return image
    }

    func testWordPageRendersEveryCase() throws {
        for (name, word) in try cases() {
            for scheme in [ColorScheme.light, .dark] {
                for type in [DynamicTypeSize.large, .accessibility5] {
                    for device in [Self.phone, Self.se] {
                        let tag = "word-\(name)-\(scheme == .dark ? "dark" : "light")-\(type == .large ? "default" : "ax5")-\(Int(device.width))"
                        try render(WordPage(word: word), device, scheme, type, tag)
                    }
                }
            }
        }
    }

    func testCreditsRenders() throws {
        for scheme in [ColorScheme.light, .dark] {
            try render(CreditsList(), CGSize(width: Self.se.width, height: 520), scheme, .large,
                       "credits-\(scheme == .dark ? "dark" : "light")")
        }
    }

    /// The orthography never truncates: every bundle word fits the iPhone SE
    /// at or above the 40 pt floor, at the default size and the largest.
    func testEveryBundleWordFitsTheSEWithoutScrolling() {
        let width = Self.se.width - WordPage.margin * 2
        for largeTitle in [CGFloat(34), 60] {
            let display = OrthographyMetrics.displaySize(scaledLargeTitle: largeTitle)
            // Every installed pack, measured in its own face.
            for word in installedPacks.flatMap({ (try? bundledWords($0)) ?? [] }) {
                let lang = word.language
                let size = OrthographyMetrics.fittedSize(for: word.orthography, width: width, display: display, language: lang)
                XCTAssertGreaterThanOrEqual(size, OrthographyMetrics.floor, word.orthography)
                XCTAssertFalse(OrthographyMetrics.needsScroll(for: word.orthography, width: width, size: size, language: lang),
                               "\(word.orthography) at \(size) pt is wider than \(width) pt")
            }
        }
    }

    func testDisplaySizeClamp() {
        XCTAssertEqual(OrthographyMetrics.displaySize(scaledLargeTitle: 10), 56)
        XCTAssertEqual(OrthographyMetrics.displaySize(scaledLargeTitle: 34), 84, accuracy: 0.01)
        XCTAssertEqual(OrthographyMetrics.displaySize(scaledLargeTitle: 200), 96)
    }

    func testFormattingRules() throws {
        let a = try bundleWord("あ"), hito = try bundleWord("人", "ひと")
        XCTAssertFalse(WordFormatting.showsReading(a))
        XCTAssertTrue(WordFormatting.showsReading(hito))
        XCTAssertEqual(WordFormatting.footer(for: a), "hiragana")
        XCTAssertEqual(WordFormatting.footer(for: hito), "noun · N5")
        XCTAssertNil(WordFormatting.footer(for: fallbackWord))
        XCTAssertFalse(WordFormatting.showsReading(fallbackWord))
    }

    /// Every Japanese part of the Word screen's VoiceOver label carries "ja".
    func testAccessibilityLabelTagsJapanese() throws {
        let hito = try bundleWord("人", "ひと")
        let label = spokenText(for: hito)
        XCTAssertTrue(String(label.characters).hasPrefix("人, read ひと, means "))
        for run in label.runs {
            let text = String(label[run.range].characters)
            let isJapanese = text == "人" || text == "ひと"
            XCTAssertEqual(run.languageIdentifier, isJapanese ? "ja" : nil, "run '\(text)'")
        }
    }

    private func save(_ image: UIImage, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"],
              let data = image.pngData() else { return }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }
}
