import Foundation

public enum WordBundleError: Error, Equatable {
    case missing(String)
}

/// Decodes a word bundle. Pure: takes bytes, reads no files.
public func decodeWords(from data: Data) throws -> [Word] {
    try JSONDecoder().decode([Word].self, from: data)
}

/// The bundled Japanese list: 92 kana, then JLPT N5, in drip order.
/// Built by tools/build_bundle.py. Data: JMdict (EDRDG, CC-BY-SA 4.0) and the
/// open-anki-jlpt-decks N5 list (MIT, from Jonathan Waller's lists).
public func bundledWords(_ language: Language = .japanese) throws -> [Word] {
    let name: String
    switch language {
    case .japanese: name = "words-ja"
    case .chinese, .korean: throw WordBundleError.missing(language.rawValue)
    }
    guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
        throw WordBundleError.missing(name)
    }
    return try decodeWords(from: Data(contentsOf: url))
}
