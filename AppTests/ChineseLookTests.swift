import XCTest
import SwiftUI
import KanaCore
@testable import SimplyKANA

/// Integration-only look at real Chinese words on the Word screen.
@MainActor
final class ChineseLookTests: XCTestCase {
    func testRenderRealChineseWords() throws {
        let zh = try bundledWords(.chinese)
        XCTAssertTrue(installedPacks.contains(.chinese))
        let longest = try XCTUnwrap(zh.max { $0.orthography.count < $1.orthography.count })
        let longestReading = try XCTUnwrap(zh.max { $0.reading.count < $1.reading.count })
        let xing = zh.first { $0.orthography == "行" } ?? zh[0]
        print("zh longest:", longest.orthography, longest.reading, "| longest reading:", longestReading.orthography, longestReading.reading)
        for (name, w) in [("first", zh[0]), ("xing", xing), ("longest", longest), ("longest-reading", longestReading)] {
            let r = ImageRenderer(content: WordPage(word: w).frame(width: 375, height: 667).environment(\.colorScheme, .light))
            r.scale = 2
            let image = try XCTUnwrap(r.uiImage)
            if let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], let png = image.pngData() {
                try png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("zh-\(name).png"))
            }
        }
        let r = ImageRenderer(content: CreditsList().frame(width: 375).fixedSize(horizontal: false, vertical: true))
        r.scale = 2
        if let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], let png = r.uiImage?.pngData() {
            try png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("zh-credits.png"))
        }
    }
}
