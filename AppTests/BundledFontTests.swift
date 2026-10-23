import XCTest
import UIKit
import CoreText
import KanaCore
@testable import SimplyKANA

/// The build check for the bundled Noto subsets (design-direction §2, Ian
/// 2026-10-23): every character a pack draws must be in the face that draws
/// it, so no word ever falls halfway into the system font.
final class BundledFontTests: XCTestCase {
    func testBundledFontsShipAndRegister() {
        XCTAssertFalse(ScriptFonts.bundledFontURLs.isEmpty, "no .ttf in the app bundle")
        ScriptFonts.registerBundledFonts()
        XCTAssertNotNil(UIFont(name: "NotoSerifJP-Medium", size: 12))
        XCTAssertNotNil(UIFont(name: "NotoSerifJP-Regular", size: 12))
    }

    /// For each pack and role whose first choice is a bundled Noto face: that
    /// face is the one used, and it covers every character the role draws.
    func testEveryPackCharacterIsInItsBundledFace() throws {
        ScriptFonts.registerBundledFonts()
        var checked = 0
        for lang in installedPacks {
            let pack = try PackLibrary.shared.pack(lang)
            for role in [ScriptFonts.Role.orthography, .reading] {
                guard let first = ScriptFonts.candidates(lang, role).first,
                      first.hasPrefix("NotoSerif"), first.contains("-"),
                      !first.hasPrefix("NotoSerif-") else { continue } // Latin readings: system serif
                XCTAssertEqual(ScriptFonts.name(lang, role), first, "\(lang) \(role) is not using its bundled face")
                let font = CTFontCreateWithName(first as CFString, 40, nil)
                var text = "—"
                let words = pack.words + [pack.manifest.placeholder]
                for w in words { text += role == .orthography ? w.orthography : w.reading }
                let missing = Set(text.unicodeScalars.filter { !covers(font, $0) }.map { String($0) })
                XCTAssertTrue(missing.isEmpty, "\(first) lacks \(missing.sorted().joined()); re-run tools/make_fonts.py")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 0, "no bundled face was checked")
    }

    func testCreditsNameTheBundledTypeface() {
        let fonts = CreditsList.fontCredits
        XCTAssertTrue(fonts.contains { $0.what.contains("Noto Serif JP") && $0.licence.contains("Open Font License") },
                      "fonts: \(fonts.map(\.what))")
        XCTAssertFalse(fonts.first?.who.isEmpty ?? true, "copyright line read from the font is empty")
    }

    private func covers(_ font: CTFont, _ scalar: Unicode.Scalar) -> Bool {
        let utf16 = Array(String(scalar).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
        return CTFontGetGlyphsForCharacters(font, utf16, &glyphs, utf16.count) && glyphs.allSatisfy { $0 != 0 }
    }
}
