import SwiftUI

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

    /// Fonts are credited only when bundled; until then the app uses the
    /// system's Hiragino Mincho and SF Pro, which need no credit.
    static let credits: [Credit] = [
        Credit(id: "jmdict",
               what: "Meanings, readings and parts of speech",
               who: "JMdict, © Electronic Dictionary Research and Development Group (EDRDG)",
               licence: "Creative Commons Attribution-ShareAlike 4.0. The word list in this app is adapted from JMdict and shared under the same licence."),
        Credit(id: "n5",
               what: "Which words are JLPT N5",
               who: "open-anki-jlpt-decks, © 2020 Jamie Sinclair, based on Jonathan Waller's JLPT lists (tanos.co.uk)",
               licence: "MIT License"),
    ]

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
