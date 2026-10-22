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
                    .font(.system(.title3, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.7) // shrinks; never truncates
                if word.reading != word.orthography {
                    Text(word.reading).font(.caption).lineLimit(1)
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
        Text("\(word.orthography)\(reading) · \(word.meanings.first ?? "")")
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
                .font(.system(size: one ? CircularMetrics.oneLineSize : CircularMetrics.twoLineSize,
                              weight: .semibold))
                .minimumScaleFactor(one ? CircularMetrics.oneLineFloor : CircularMetrics.twoLineFloor)
                .padding(6)
            } else {
                Text("語").font(.system(size: CircularMetrics.oneLineSize, weight: .semibold))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spokenText(for: word)))
    }
}
