import SwiftUI
import CoreText
import KanaCore

/// The one screen allowed to be plain (design-direction §4, playbook rule 9).
struct CreditsScreen: View {
    var body: some View {
        ScrollView { CreditsList() }
            .background(Ink.paper.ignoresSafeArea())
            .navigationTitle("Credits")
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// The content without scrolling, so ImageRenderer can snapshot it.
struct CreditsList: View {
    struct Credit: Identifiable {
        let id: String
        let what: String
        let who: String
        let licence: String
    }

    /// Every installed pack's own credits (pack.toml), then the bundled
    /// typefaces. Swift names no language: a new pack brings its own lines.
    static var credits: [Credit] {
        let packs = installedPacks.flatMap { lang in
            (PackLibrary.shared.manifest(for: lang)?.credits ?? []).map {
                Credit(id: "\(lang.rawValue):\($0.title)", what: $0.title, who: $0.detail, licence: $0.licence)
            }
        }
        return packs + fontCredits
    }

    /// One line per bundled family, copyright read from the font file itself.
    static var fontCredits: [Credit] {
        ScriptFonts.registerBundledFonts()
        var seen = Set<String>()
        return ScriptFonts.bundledFontURLs.compactMap { url in
            guard let descs = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
                  let desc = descs.first else { return nil }
            let font = CTFontCreateWithFontDescriptor(desc, 12, nil)
            let family = CTFontCopyFamilyName(font) as String
            guard seen.insert(family).inserted else { return nil }
            let copyright = (CTFontCopyName(font, kCTFontCopyrightNameKey) as String?) ?? ""
            return Credit(id: "font:\(family)", what: "Typeface: \(family)", who: copyright,
                          licence: "SIL Open Font License 1.1")
        }.sorted { $0.id < $1.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(Self.credits.enumerated()), id: \.element.id) { index, credit in
                if index > 0 { Rectangle().fill(Ink.rule).frame(height: 1) }
                VStack(alignment: .leading, spacing: 6) {
                    Text(credit.what).font(.headline).foregroundStyle(Ink.ink)
                    Text(credit.who).font(.body).foregroundStyle(Ink.ink)
                    Text(credit.licence).font(.subheadline).foregroundStyle(Ink.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 16)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.paper)
    }
}
