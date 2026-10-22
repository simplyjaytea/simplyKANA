import SwiftUI
import KanaCore

@main
struct SimplyKANAApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

/// The app opens on the word that is on the Lock Screen now. A widget tap
/// (simplykana://word/<id>) opens that word instead, until the app is left.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var pinned: Word?
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            // Re-evaluated every minute so the page turns with the drip.
            TimelineView(.everyMinute) { context in
                let word = pinned ?? currentWord(at: context.date)
                WordScreen(word: word)
                    .id(word.id)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.24), value: word.id)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { // .topBarTrailing is iOS 17
                    // Quiet, secondary ink. Credits lives inside Settings.
                    Button { showsSettings = true } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Ink.secondary)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showsSettings) { SettingsScreen() }
        }
        .tint(Ink.ink)
        .onOpenURL { url in pinned = word(from: url) }
        .onChange(of: scenePhase) { phase in // iOS 16 form
            if phase == .background { pinned = nil }
        }
    }

    private func word(from url: URL) -> Word? {
        guard url.scheme == "simplykana", url.host == "word" else { return nil }
        let id = url.path.dropFirst().removingPercentEncoding ?? ""
        return packWords().first { $0.id == id } ?? appWords.first { $0.id == id }
    }
}
