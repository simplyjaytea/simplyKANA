import UIKit
import CoreText
import KanaCore

/// Which face sets a word, by the word's language (design-direction §2).
///
/// Chinese, Japanese and Korean share many code points but draw some of them
/// differently (直, 骨, 角). A Chinese word set in a Japanese font shows the
/// Japanese shapes, so a learner would learn the wrong form. Every place that
/// draws an orthography or a reading picks its face here, by language, with
/// explicit font names: `.typesettingLanguage` is iOS 17 and we target 16.
///
/// Each list is tried in order; the first installed face wins. Bundled Noto
/// first (when we ship it), then a serif iOS ships, then a sans iOS always
/// ships for that script. The sans is the floor: right shapes beat serifs.
enum ScriptFonts {
    enum Role { case orthography, reading }

    /// The pack's ordered list for this role (pack.toml [fonts]); empty if no pack.
    static func candidates(_ language: Language, _ role: Role) -> [String] {
        guard let fonts = PackLibrary.shared.manifest(for: language)?.fonts else { return [] }
        return role == .orthography ? fonts.orthography : fonts.reading
    }

    /// The installed face for this language and role, or nil if none is.
    static func name(_ language: Language, _ role: Role) -> String? {
        registerBundledFonts()
        return candidates(language, role).first { UIFont(name: $0, size: 12) != nil }
    }

    /// The Noto Serif subsets in Shared/Fonts (tools/make_fonts.py), registered
    /// once per process. Shared/ is in both targets, so the app and the widget
    /// each carry and register their own copy. No Info.plist entry needed.
    static let bundledFontURLs: [URL] = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []

    private static let registration: Void = {
        for url in bundledFontURLs {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    static func registerBundledFonts() { _ = registration }

    static func uiFont(_ language: Language, _ role: Role, size: CGFloat) -> UIFont {
        if let n = name(language, role), let f = UIFont(name: n, size: size) { return f }
        return .systemFont(ofSize: size, weight: role == .orthography ? .medium : .regular)
    }
}
