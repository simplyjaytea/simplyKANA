import UIKit
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

    static func candidates(_ language: Language, _ role: Role) -> [String] {
        switch (language, role) {
        case (.japanese, .orthography): return ["NotoSerifJP-Medium", "HiraMinProN-W6", "HiraginoSans-W6"]
        case (.japanese, .reading):     return ["NotoSerifJP-Regular", "HiraMinProN-W3", "HiraginoSans-W3"]
        case (.chinese, .orthography):  return ["NotoSerifSC-Medium", "STSongti-SC-Bold", "PingFangSC-Medium"]
        // Pinyin is Latin with tone marks: a Latin serif, not a CJK face's Latin.
        case (.chinese, .reading):      return ["NotoSerif-Regular", "Georgia"]
        case (.korean, .orthography):   return ["NotoSerifKR-Medium", "AppleMyungjo", "AppleSDGothicNeo-Medium"]
        case (.korean, .reading):       return ["NotoSerifKR-Regular", "AppleMyungjo", "AppleSDGothicNeo-Regular"]
        }
    }

    /// The installed face for this language and role, or nil if none is.
    static func name(_ language: Language, _ role: Role) -> String? {
        candidates(language, role).first { UIFont(name: $0, size: 12) != nil }
    }

    static func uiFont(_ language: Language, _ role: Role, size: CGFloat) -> UIFont {
        if let n = name(language, role), let f = UIFont(name: n, size: size) { return f }
        return .systemFont(ofSize: size, weight: role == .orthography ? .medium : .regular)
    }
}
