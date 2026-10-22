import SwiftUI
import KanaCore

/// Placeholder host screen. Dana's Word screen replaces this.
struct ContentView: View {
    @State private var word = currentWord()
    var body: some View {
        VStack(spacing: 12) {
            if word.reading != word.orthography { Text(word.reading).font(.title3) }
            Text(word.orthography).font(.system(size: 72, weight: .regular)).lineLimit(1).minimumScaleFactor(0.5)
            Text(word.meanings.first ?? "").font(.body)
        }
        .padding(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spokenText(for: word)))
    }
}
