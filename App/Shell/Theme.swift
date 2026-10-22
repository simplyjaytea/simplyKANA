import SwiftUI
import UIKit

// Design tokens from docs/design-direction.md §2–3. Tokens, not hex, in views.

enum Ink {
    static let paper = dynamic(light: 0xF6F1E7, dark: 0x15120F)
    static let ink = dynamic(light: 0x1B1714, dark: 0xEDE6DA)
    static let secondary = dynamic(light: 0x6B625A, dark: 0xA89D91)
    static let rule = dynamic(light: 0xE2D9CA, dark: 0x2A251F)
    /// One element per screen at most. Never text (4.3:1 on light paper).
    static let accent = dynamic(light: 0xC8452A, dark: 0xE0674A)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? uiColor(dark) : uiColor(light) })
    }

    private static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1)
    }
}

enum Typeface {
    /// Noto Serif JP when bundled; Hiragino Mincho (ships with iOS) until then.
    /// Both are Japanese serif faces, so the page reads the same either way.
    static func serif(size: CGFloat, medium: Bool) -> Font {
        if let name = fontName(medium: medium) { return .custom(name, fixedSize: size) }
        return .system(size: size, weight: medium ? .medium : .regular, design: .serif)
    }

    static func uiSerif(size: CGFloat, medium: Bool) -> UIFont {
        if let name = fontName(medium: medium), let font = UIFont(name: name, size: size) { return font }
        return .systemFont(ofSize: size, weight: medium ? .medium : .regular)
    }

    private static func fontName(medium: Bool) -> String? {
        let candidates = medium
            ? ["NotoSerifJP-Medium", "HiraMinProN-W6"]
            : ["NotoSerifJP-Regular", "HiraMinProN-W3"]
        return candidates.first { UIFont(name: $0, size: 12) != nil }
    }
}

/// The orthography's point size: scales with Dynamic Type (relative to
/// .largeTitle), clamped to 56–96 pt, then shrinks to fit the width down to
/// a 40 pt floor. It never truncates and never wraps; below the floor the
/// caller scrolls instead (design-direction §2).
enum OrthographyMetrics {
    static let minDisplay: CGFloat = 56
    static let maxDisplay: CGFloat = 96
    static let floor: CGFloat = 40
    /// Measured width of the orthography at `size` in the face we render with.
    static func width(of text: String, size: CGFloat) -> CGFloat {
        let font = Typeface.uiSerif(size: size, medium: true)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    static func displaySize(scaledLargeTitle: CGFloat) -> CGFloat {
        // .largeTitle is 34 pt at the default size; 64 pt is our default display size.
        min(max(scaledLargeTitle * (64.0 / 34.0), minDisplay), maxDisplay)
    }

    static func fittedSize(for text: String, width: CGFloat, display: CGFloat) -> CGFloat {
        let natural = Self.width(of: text, size: display)
        guard natural > width else { return display }
        // Width scales linearly with point size.
        return max((display * width / natural).rounded(.down), floor)
    }

    static func needsScroll(for text: String, width: CGFloat, size: CGFloat) -> Bool {
        Self.width(of: text, size: size) > width
    }
}
