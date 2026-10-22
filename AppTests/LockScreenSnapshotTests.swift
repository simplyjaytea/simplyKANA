import XCTest
import SwiftUI
import UIKit
import KanaCore
@testable import SimplyKANA

/// Rendering gate (lock-screen-widget-spec §6): ImageRenderer per family.
/// PNGs go to $SNAPSHOT_DIR when set (CI uploads them as an artifact).
@MainActor
final class LockScreenSnapshotTests: XCTestCase {
    // Approximate Lock Screen family sizes on a 6.1" iPhone, in points.
    static let rectangular = CGSize(width: 160, height: 72)
    static let inline = CGSize(width: 234, height: 26)
    static let circular = CGSize(width: 76, height: 76)

    private func render<V: View>(_ view: V, _ size: CGSize, _ name: String) throws -> UIImage {
        let r = ImageRenderer(content: view.frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark).background(Color.black).foregroundStyle(.white))
        r.scale = 3
        let image = try XCTUnwrap(r.uiImage, "\(name) did not render")
        if let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], let png = image.pngData() {
            try png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
        return image
    }

    func testBundleLoadsInTheApp() {
        XCTAssertEqual(appWords.count, try bundledWords().count)
        XCTAssertGreaterThan(appWords.count, 0)
    }

    func testEveryFamilyRendersNamedCases() throws {
        let names = ["日", "テープレコーダー", "パーティー", "ワイシャツ", "あ"]
        for o in names {
            let w = try XCTUnwrap(appWords.first { $0.orthography == o }, o)
            _ = try render(RectangularWordView(word: w), Self.rectangular, "rect-\(o)")
            _ = try render(InlineWordView(word: w), Self.inline, "inline-\(o)")
            _ = try render(CircularWordView(word: w), Self.circular, "circ-\(o)")
        }
        _ = try render(CircularWordView(word: fallbackWord), Self.circular, "circ-fallback")
        _ = try render(RectangularWordView(word: fallbackWord), Self.rectangular, "rect-fallback")
    }

    /// Every 5+ character word must fit two lines in the circle at the floor size.
    /// Measured with UIKit text metrics at the same font the view uses.
    func testEveryLongWordFitsTheCircleAtTheFloor() throws {
        let inner = Self.circular.width - 12 // the view's padding
        let font = UIFont.systemFont(ofSize: CircularMetrics.twoLineSize * CircularMetrics.twoLineFloor,
                                     weight: .semibold)
        let long = appWords.filter { $0.orthography.count >= 5 }
        XCTAssertEqual(long.count, 11)
        for w in long {
            let lines = try XCTUnwrap(circularLines(for: w.orthography), w.orthography)
            for line in lines {
                let width = (line as NSString).size(withAttributes: [.font: font]).width
                XCTAssertLessThanOrEqual(width, inner, "\(w.orthography): \(line) is \(width)pt")
            }
            _ = try render(CircularWordView(word: w), Self.circular, "circ-long-\(w.orthography)")
        }
    }

    /// The rectangular family's longest first meaning, rendered for review.
    func testLongestFirstMeaningRenders() throws {
        let w = try XCTUnwrap(appWords.max { ($0.meanings.first?.count ?? 0) < ($1.meanings.first?.count ?? 0) })
        _ = try render(RectangularWordView(word: w), Self.rectangular, "rect-longest-meaning")
    }

    func testVoiceOverTagsJapanese() throws {
        let w = try XCTUnwrap(appWords.first { $0.orthography == "日" && $0.reading == "にち" } ?? appWords.first)
        let label = spokenText(for: w)
        let tagged = label.runs.filter { $0.languageIdentifier == "ja" }.map { String(label[$0.range].characters) }
        XCTAssertTrue(tagged.contains(w.orthography))
    }
}
