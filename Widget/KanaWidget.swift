import SwiftUI
import WidgetKit
import KanaCore

struct WordEntry: TimelineEntry {
    let date: Date
    let word: Word
}

/// Thin adapter: all logic is KanaCore.timeline (spec §2). One provider per widget
/// slot; the slot's pack comes from the manifests (docs/pack-pipeline.md).
struct Provider: TimelineProvider {
    let slot: Int

    private var manifest: PackManifest? { PackLibrary.shared.manifests.first { $0.widgetSlot == slot } }
    private var words: [Word] { manifest.flatMap { try? bundledWords($0.language) } ?? [] }
    private var sample: Word { manifest?.placeholder ?? fallbackWord }

    func placeholder(in context: Context) -> WordEntry { WordEntry(date: Date(), word: sample) }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        if context.isPreview { return completion(WordEntry(date: Date(), word: sample)) }
        let t = timeline(after: Date(), schedule: currentSchedule, words: words, calendar: .current, limit: 0)
        completion(WordEntry(date: Date(), word: t.entries[0].word))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let words = self.words
        let t = timeline(after: Date(), schedule: currentSchedule, words: words, calendar: .current)
        if words.isEmpty { NSLog("simplyKANA: no pack in widget slot \(slot); showing fallback") }
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

/// One widget kind per pack slot. WidgetKit needs every widget kind as a Swift type
/// with a no-argument init, known at build time, so the number of slots is fixed here.
/// Which language fills a slot, and its gallery name, come from the pack manifests:
/// adding a pack is a file, as long as a free slot exists. Slot 0 keeps the original
/// kind name so widgets already on a Lock Screen keep working. A slot with no pack
/// offers no sizes, so it doesn't appear in the gallery.
func packWidgetConfiguration(slot: Int) -> some WidgetConfiguration {
    let manifest = PackLibrary.shared.manifests.first { $0.widgetSlot == slot }
    return StaticConfiguration(kind: slot == 0 ? "KanaLockScreen" : "KanaLockScreen.slot\(slot)",
                               provider: Provider(slot: slot)) { entry in
        WordWidgetView(entry: entry)
    }
    .configurationDisplayName(manifest?.widgetName ?? "simplyKANA")
    .description("One word, on schedule.")
    .supportedFamilies(manifest == nil ? [] : [.accessoryRectangular, .accessoryInline, .accessoryCircular])
}

struct PackWidget0: Widget { var body: some WidgetConfiguration { packWidgetConfiguration(slot: 0) } }
struct PackWidget1: Widget { var body: some WidgetConfiguration { packWidgetConfiguration(slot: 1) } }
struct PackWidget2: Widget { var body: some WidgetConfiguration { packWidgetConfiguration(slot: 2) } }
struct PackWidget3: Widget { var body: some WidgetConfiguration { packWidgetConfiguration(slot: 3) } }

@main
struct KanaWidgetBundle: WidgetBundle {
    var body: some Widget {
        PackWidget0()
        PackWidget1()
        PackWidget2()
        PackWidget3()
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
