import SwiftUI
import KanaCore

/// The only screen that matters (design-direction §4). Reading above,
/// orthography huge, first meaning below, one quiet line at the bottom.
/// The level dot is the screen's one accent.
struct WordScreen: View {
    let word: Word

    var body: some View {
        // Scroll only when the page is taller than the screen (accessibility
        // sizes). The word itself never shrinks below its floor to avoid it.
        ViewThatFits(in: .vertical) {
            WordPage(word: word)
            ScrollView(.vertical) { WordPage(word: word) }
        }
        .background(Ink.paper.ignoresSafeArea())
    }
}

/// The page without scrolling, so ImageRenderer can snapshot it.
struct WordPage: View {
    let word: Word

    @ScaledMetric(relativeTo: .largeTitle) private var largeTitle: CGFloat = 34
    /// Side margin. 16 pt, not 24: at 24 the longest N5 word (テープレコーダー)
    /// does not fit an iPhone SE at the 40 pt floor.
    static let margin: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                WordBlock(word: word, width: proxy.size.width - Self.margin * 2, largeTitle: largeTitle)
                Spacer(minLength: 32)
                if let line = WordFormatting.footer(for: word) {
                    FooterLine(text: line, showsDot: word.level != nil || WordFormatting.isKana(word))
                        .padding(.bottom, 16)
                }
            }
            .padding(.horizontal, Self.margin)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(minHeight: 480)
        .background(Ink.paper)
    }
}

/// Reading, orthography, meaning. VoiceOver reads it as one element.
struct WordBlock: View {
    let word: Word
    let width: CGFloat
    let largeTitle: CGFloat

    var body: some View {
        let display = OrthographyMetrics.displaySize(scaledLargeTitle: largeTitle)
        let lang = word.language
        let size = OrthographyMetrics.fittedSize(for: word.orthography, width: width, display: display, language: lang)
        let scrolls = OrthographyMetrics.needsScroll(for: word.orthography, width: width, size: size, language: lang)

        VStack(spacing: size * 0.18) {
            if WordFormatting.showsReading(word) {
                Text(word.reading)
                    .font(Typeface.reading(word.language, size: size * 0.42))
                    .tracking(size * 0.42 * 0.02)
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            orthography(size: size, scrolls: scrolls)

            Text(WordFormatting.meaning(for: word))
                .font(.title3)
                .foregroundStyle(Ink.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spokenText(for: word)))
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func orthography(size: CGFloat, scrolls: Bool) -> some View {
        let text = Text(word.orthography)
            .font(Typeface.orthography(word.language, size: size))
            .foregroundStyle(Ink.ink)
            .lineLimit(1)
            .fixedSize()            // never truncate, never wrap
        if scrolls {
            ScrollView(.horizontal, showsIndicators: false) { text }
        } else {
            text
        }
    }
}

struct FooterLine: View {
    let text: String
    let showsDot: Bool

    var body: some View {
        HStack(spacing: 8) {
            if showsDot {
                Circle().fill(Ink.accent).frame(width: 6, height: 6)
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(.footnote)
                .foregroundStyle(Ink.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Pure formatting rules, kept apart from the views so tests can check them.
enum WordFormatting {
    /// A script entry (kana, jamo): the pack's manifest says which parts of speech those are.
    static func isKana(_ word: Word) -> Bool {
        guard let pos = word.partOfSpeech else { return false }
        return PackLibrary.shared.manifest(for: word.language)?.scriptPartsOfSpeech.contains(pos) ?? false
    }

    /// Hidden when it would repeat the orthography (kana, kana-only words).
    static func showsReading(_ word: Word) -> Bool {
        !isKana(word) && word.reading != word.orthography && word.id != fallbackWord.id
    }

    static func meaning(for word: Word) -> String {
        word.meanings.first ?? ""
    }

    /// `noun · N5`, `hiragana`, or nil for the fallback word.
    static func footer(for word: Word) -> String? {
        if word.id == fallbackWord.id { return nil }
        if isKana(word) { return word.partOfSpeech }
        var parts: [String] = []
        if let pos = word.partOfSpeech, !pos.isEmpty { parts.append(pos) }
        if let level = word.level { parts.append(levelName(level, language: word.language)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func levelName(_ level: Level, language: Language = .japanese) -> String {
        PackLibrary.shared.manifest(for: language)?.levelLabel(level) ?? "\(level.scale.uppercased()) \(level.value)"
    }

}
