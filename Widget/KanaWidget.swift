import SwiftUI
import WidgetKit
import KanaCore

struct WordEntry: TimelineEntry {
    let date: Date
    let word: Word
}

/// Thin adapter: all logic is KanaCore.timeline (spec §2). One provider per pack
/// (spec §1b): the pack is the widget kind, never a stored "current language".
struct Provider: TimelineProvider {
    let language: Language

    private var sample: Word {
        switch language {
        case .chinese:
            return Word(id: "placeholder", language: .chinese, orthography: "水", reading: "shuǐ",
                        meanings: ["water"], partOfSpeech: "noun", level: .hsk(1), isCommon: true)
        default:
            return Word(id: "placeholder", language: .japanese, orthography: "日", reading: "にち",
                        meanings: ["day"], partOfSpeech: "noun", level: .jlpt(5), isCommon: true)
        }
    }

    private var words: [Word] { (try? bundledWords(language)) ?? [] }

    func placeholder(in context: Context) -> WordEntry { WordEntry(date: Date(), word: sample) }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        if context.isPreview { return completion(WordEntry(date: Date(), word: sample)) }
        let t = timeline(after: Date(), schedule: currentSchedule, words: words, calendar: .current, limit: 0)
        completion(WordEntry(date: Date(), word: t.entries[0].word))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let words = self.words
        let t = timeline(after: Date(), schedule: currentSchedule, words: words, calendar: .current)
        if words.isEmpty { NSLog("simplyKANA: \(language.rawValue) bundle failed to load; showing fallback") }
        completion(Timeline(entries: t.entries.map { WordEntry(date: $0.date, word: $0.word) },
                            policy: .after(t.reloadAt)))
    }
}

struct WordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry
    var body: some View {
        Group {
            switch family {
            case .accessoryInline: InlineWordView(word: entry.word)
            case .accessoryCircular: CircularWordView(word: entry.word)
            default: RectangularWordView(word: entry.word)
            }
        }
        .widgetURL(wordLink(for: entry.word))
        .widgetBackground()
    }
}

/// One widget kind per pack. WidgetKit needs a no-argument init, so each pack is
/// its own small type sharing one configuration. Japanese keeps the original kind
/// name so widgets already on a Lock Screen keep working after an update.
func wordWidgetConfiguration(_ language: Language) -> some WidgetConfiguration {
    let kind = language == .japanese ? "KanaLockScreen" : "KanaLockScreen.\(language.rawValue)"
    let name: String
    switch language {
    case .japanese: name = "simplyKANA · Japanese"
    case .chinese: name = "simplyKANA · Chinese"
    case .korean: name = "simplyKANA · Korean"
    }
    return StaticConfiguration(kind: kind, provider: Provider(language: language)) { entry in
        WordWidgetView(entry: entry)
    }
    .configurationDisplayName(name)
    .description("One word, on schedule.")
    .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
}

struct JapaneseWordWidget: Widget {
    var body: some WidgetConfiguration { wordWidgetConfiguration(.japanese) }
}

struct ChineseWordWidget: Widget {
    var body: some WidgetConfiguration { wordWidgetConfiguration(.chinese) }
}

/// Packs bundled in this build. Korean joins when its pack does.
@main
struct KanaWidgetBundle: WidgetBundle {
    var body: some Widget {
        JapaneseWordWidget()
        ChineseWordWidget()
    }
}

extension View {
    /// iOS 17 requires a container background for widgets; iOS 16 has no such API.
    @ViewBuilder func widgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { Color.clear }
        } else {
            self
        }
    }
}
