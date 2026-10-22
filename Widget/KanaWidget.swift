import SwiftUI
import WidgetKit
import KanaCore

struct WordEntry: TimelineEntry {
    let date: Date
    let word: Word
}

/// Thin adapter: all logic is KanaCore.timeline (spec §2).
struct Provider: TimelineProvider {
    private let sample = Word(id: "placeholder", language: .japanese, orthography: "日", reading: "にち",
                              meanings: ["day"], partOfSpeech: "noun", level: .jlpt(5), isCommon: true)

    func placeholder(in context: Context) -> WordEntry { WordEntry(date: Date(), word: sample) }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        completion(context.isPreview ? WordEntry(date: Date(), word: sample)
                                     : WordEntry(date: Date(), word: currentWord()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let words = packWords()
        let t = timeline(after: Date(), schedule: currentSchedule, words: words, calendar: .current)
        if words.isEmpty { NSLog("simplyKANA: word bundle failed to load; showing fallback") }
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
        .widgetURL(wordURL(entry.word))
        .widgetBackground()
    }
}

struct KanaLockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KanaLockScreen", provider: Provider()) { entry in
            WordWidgetView(entry: entry)
        }
        .configurationDisplayName("Word")
        .description("One word, on schedule.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

@main
struct KanaWidgetBundle: WidgetBundle {
    var body: some Widget { KanaLockScreenWidget() }
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
