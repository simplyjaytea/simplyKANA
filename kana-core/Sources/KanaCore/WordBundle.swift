import Foundation

public typealias WordBundleError = PackError

/// Decodes a bare word list (tests and tools). Pure: takes bytes, reads no files.
public func decodeWords(from data: Data) throws -> [Word] {
    try JSONDecoder().decode([Word].self, from: data)
}

/// A pack's words, in drip order. Packs live in Resources/Packs as `<language>.pack.json`,
/// built by tools/build_pack.py; sources and licences are in each manifest.
public func bundledWords(_ language: Language = .japanese) throws -> [Word] {
    try PackLibrary.shared.pack(language).words
}
