import Foundation

/// Where a widget tap sends the app (lock-screen-widget-spec §1b).
/// Current form: simplykana://word/<language>/<id>. The pre-§1b form
/// simplykana://word/<id>, which already-added widgets may still send, means Japanese.
public enum WordLinkTarget: Equatable, Sendable {
    case word(Language, id: String)
    /// Our link, but a language this build doesn't know: open the app on its current word.
    case current
}

private let idAllowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))

public func wordLink(for word: Word) -> URL {
    let id = word.id.addingPercentEncoding(withAllowedCharacters: idAllowed) ?? ""
    return URL(string: "simplykana://word/\(word.language.rawValue)/\(id)")!
}

/// nil when the URL isn't a simplyKANA word link at all.
public func parseWordLink(_ url: URL) -> WordLinkTarget? {
    guard url.scheme == "simplykana", url.host == "word" else { return nil }
    let parts = url.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    switch parts.count {
    case 1:
        return .word(.japanese, id: parts[0].removingPercentEncoding ?? parts[0])
    case 2:
        guard let lang = Language(rawValue: parts[0]) else { return .current }
        return .word(lang, id: parts[1].removingPercentEncoding ?? parts[1])
    default:
        return .current
    }
}

/// The word a link points to, looked up in that language's bundle.
public func word(for target: WordLinkTarget) -> Word? {
    guard case .word(let lang, let id) = target else { return nil }
    return WordIndex.shared.word(lang, id)
}

/// Bundles decoded once per language, indexed by id.
private final class WordIndex: @unchecked Sendable {
    static let shared = WordIndex()
    private let lock = NSLock()
    private var byLanguage: [Language: [String: Word]] = [:]

    func word(_ lang: Language, _ id: String) -> Word? {
        lock.lock(); defer { lock.unlock() }
        if byLanguage[lang] == nil {
            let words = (try? bundledWords(lang)) ?? []
            byLanguage[lang] = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        }
        return byLanguage[lang]?[id]
    }
}
