import Foundation

/// What a pack says about itself (docs/pack-pipeline.md §1). Everything the app and
/// widget need to show a language comes from here, so Swift never names a language.
public struct PackManifest: Codable, Equatable, Sendable {
    public let language: Language
    /// English name for settings, e.g. "Japanese".
    public let name: String
    /// Widget gallery name, e.g. "simplyKANA · Japanese".
    public let widgetName: String
    /// Stable widget slot (0, 1, 2, ...). Slot 0 keeps the original widget kind.
    public let widgetSlot: Int
    /// Level label template per scale, "{n}" replaced by the number: {"jlpt": "N{n}"}.
    public let levelLabels: [String: String]
    /// Plain label shown for the pack's level range, e.g. "JLPT N5", "HSK 1–3".
    public let levelSummary: String
    /// Preferred font family for the words (nil = system), and a fallback.
    public let font: String?
    public let fallbackFont: String?
    /// Voice / VoiceOver language, e.g. "zh-CN".
    public let voice: String
    /// Whether VoiceOver should speak the reading line (kana yes, pinyin no).
    public let speakReading: Bool
    /// Parts of speech that are scripts, e.g. ["hiragana", "katakana"]: the reading line is hidden.
    public let scriptPartsOfSpeech: [String]
    /// Word shown in widget previews.
    public let placeholder: Word
    /// Credits screen text: sources and licences.
    public let credits: [Credit]
    public let count: Int

    public struct Credit: Codable, Equatable, Sendable {
        public let title: String
        public let detail: String
        public let licence: String
        public let url: String?
    }

    public func levelLabel(_ level: Level) -> String {
        (levelLabels[level.scale] ?? "\(level.scale.uppercased()) {n}")
            .replacingOccurrences(of: "{n}", with: String(level.value))
    }
}

public struct Pack: Codable, Sendable {
    public let manifest: PackManifest
    public let words: [Word]
}

public enum PackError: Error, Equatable {
    case missing(String)
    case countMismatch(String)
}

/// Decodes one pack file. Pure: bytes in, pack out. Checks the manifest count and that
/// every word belongs to the pack's language.
public func decodePack(from data: Data) throws -> Pack {
    let pack = try JSONDecoder().decode(Pack.self, from: data)
    guard pack.words.count == pack.manifest.count,
          pack.words.allSatisfy({ $0.language == pack.manifest.language }) else {
        throw PackError.countMismatch(pack.manifest.language.rawValue)
    }
    return pack
}

/// The packs in the app, discovered by listing `*.pack.json`; nothing names a language.
/// Cached: each pack is decoded once per process.
public final class PackLibrary: @unchecked Sendable {
    public static let shared = PackLibrary(directory: Bundle.module.resourceURL?.appendingPathComponent("Packs"))

    private let directory: URL?
    private let lock = NSLock()
    private var cache: [Language: Pack] = [:]
    private var index: [Language: [String: Word]] = [:]

    public init(directory: URL?) { self.directory = directory }

    private var files: [URL] {
        guard let dir = directory,
              let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return [] }
        return names.filter { $0.hasSuffix(".pack.json") }.sorted().map { dir.appendingPathComponent($0) }
    }

    /// Manifests of every installed pack, in widget-slot order.
    public var manifests: [PackManifest] {
        files.compactMap { url in
            let lang = Language(String(url.lastPathComponent.dropLast(".pack.json".count)))
            return try? pack(lang).manifest
        }.sorted { $0.widgetSlot < $1.widgetSlot }
    }

    public func pack(_ language: Language) throws -> Pack {
        lock.lock(); defer { lock.unlock() }
        if let p = cache[language] { return p }
        guard let dir = directory else { throw PackError.missing(language.rawValue) }
        let url = dir.appendingPathComponent("\(language.rawValue).pack.json")
        guard FileManager.default.fileExists(atPath: url.path) else { throw PackError.missing(language.rawValue) }
        let p = try decodePack(from: Data(contentsOf: url))
        cache[language] = p
        return p
    }

    public func manifest(for language: Language) -> PackManifest? { try? pack(language).manifest }

    public func word(_ language: Language, id: String) -> Word? {
        guard let words = try? pack(language).words else { return nil }
        lock.lock(); defer { lock.unlock() }
        if index[language] == nil {
            index[language] = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        }
        return index[language]?[id]
    }
}
