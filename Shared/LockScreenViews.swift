import SwiftUI
import WidgetKit
import KanaCore

// Lock Screen families (lock-screen-widget-spec §1). Vibrant monochrome: hierarchy
// is size and weight only. The orthography never truncates.

struct RectangularWordView: View {
    let word: Word
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if word.id == fallbackWord.id {
                Text("—").font(.headline)
            } else {
                Text(word.orthography)
                    .font(WidgetFonts.font(word.language, .orthography, size: 20, relativeTo: .title3))
                    .lineLimit(1).minimumScaleFactor(0.7) // shrinks; never truncates
                if word.reading != word.orthography {
                    // Secondary, so the glance goes word -> meaning; the
                    // reading is there when you look for it.
                    Text(word.reading)
                        .font(WidgetFonts.font(word.language, .reading, size: 12, relativeTo: .caption))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
                Text(word.meanings.first ?? "").font(.caption).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spokenText(for: word)))
    }
}

struct InlineWordView: View {
    let word: Word
    var body: some View {
        // One Text, word first: tail truncation cuts the meaning before the word.
        let reading = word.reading == word.orthography ? "" : " · \(word.reading)"
        // Inline is drawn by the system, which may ignore custom fonts; the per-language
        // font is applied anyway so the shapes are right wherever iOS honours it.
        (Text(word.orthography).font(WidgetFonts.font(word.language, .orthography, size: 15, relativeTo: .body))
         + Text("\(reading) · \(word.meanings.first ?? "")"))
            .lineLimit(1)
            .accessibilityLabel(Text(spokenText(for: word)))
    }
}

/// Font sizes the snapshot test checks against.
enum CircularMetrics {
    static let oneLineSize: CGFloat = 24
    static let twoLineSize: CGFloat = 17
    static let oneLineFloor: CGFloat = 0.6
    static let twoLineFloor: CGFloat = 0.5
}

struct CircularWordView: View {
    let word: Word
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let lines = circularLines(for: word.orthography), word.id != fallbackWord.id {
                let one = lines.count == 1
                VStack(spacing: -2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line).lineLimit(1)
                    }
                }
                .font(WidgetFonts.font(word.language, .orthography,
                                       size: one ? CircularMetrics.oneLineSize : CircularMetrics.twoLineSize,
                                       relativeTo: .title3))
                .minimumScaleFactor(one ? CircularMetrics.oneLineFloor : CircularMetrics.twoLineFloor)
                .padding(6)
            } else {
                Text("語").font(WidgetFonts.font(word.language, .orthography,
                                                 size: CircularMetrics.oneLineSize, relativeTo: .title3))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spokenText(for: word)))
    }
}

/// Widget text faces come from the same per-language table as the app (ScriptFonts),
/// so a Chinese widget draws 直骨角 in Chinese shapes even on a phone set to Japanese.
/// The system font would pick shapes from the phone's language instead.
enum WidgetFonts {
    static func font(_ language: Language, _ role: ScriptFonts.Role, size: CGFloat,
                     relativeTo style: Font.TextStyle) -> Font {
        guard let name = ScriptFonts.name(language, role) else { return .system(size: size) }
        return .custom(name, size: size, relativeTo: style)
    }
}
