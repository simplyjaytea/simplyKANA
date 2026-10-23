import SwiftUI
import UIKit
import KanaCore

/// Settings (docs/settings-spec.md §1, §5). Paper, hairlines, no icons, no
/// Save button. Each control commits once, when its edit ends. The selected
/// interval's checkmark is the screen's one accent.
struct SettingsScreen: View {
    @StateObject private var model = SettingsModel(store: SettingsStore())
    @State private var showsCredits = false

    var body: some View {
        ScrollView { SettingsContent(model: model, openCredits: { showsCredits = true }) }
            .navigationDestination(isPresented: $showsCredits) { CreditsScreen() }
            .background(Ink.paper.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $model.editing, onDismiss: model.finishEditing) { end in
                QuietTimeSheet(title: end == .start ? "Quiet from" : "Quiet until",
                               minutes: $model.draftMinutes,
                               done: model.done, cancel: model.cancel)
                    .presentationDetents([.height(320)])
            }
    }
}

// MARK: - Model

/// Holds the half-finished edit (a time picker being scrolled) so it is
/// never saved or validated until the sheet closes (settings-spec §2).
@MainActor
final class SettingsModel: ObservableObject {
    enum QuietEnd: String, Identifiable { case start, end; var id: String { rawValue } }
    enum Section { case interval, quiet }

    let store: SettingsStore
    private let now: () -> Date
    private let calendar: Calendar

    /// The time sheet that is open. Kept in `open` too, because SwiftUI clears
    /// `editing` before the sheet's onDismiss runs.
    @Published var editing: QuietEnd? { didSet { if let e = editing { open = e } } }
    @Published var draftMinutes = 0
    /// Which section the last refusal belongs to, so the sentence sits under it.
    @Published private(set) var refusalSection: Section?
    private var open: QuietEnd?

    /// Languages whose word list is in this build, in a fixed order.
    let packs: [Language]

    /// The app's own storage for its language (never the App Group).
    private let appDefaults: UserDefaults

    init(store: SettingsStore, now: @escaping () -> Date = Date.init, calendar: Calendar = .current,
         packs: [Language] = installedPacks, appDefaults: UserDefaults = .standard) {
        self.store = store
        self.now = now
        self.calendar = calendar
        self.packs = packs
        self.appDefaults = appDefaults
    }

    /// The app's language (lock-screen-widget-spec §1b). Widgets don't read it.
    var language: Language { AppLanguage.current(appDefaults, packs: packs) }

    /// Switches the app's word at once. No validation and no widget reload:
    /// each widget's language is the widget kind the user added.
    func select(language: Language) {
        guard language != self.language else { return }
        AppLanguage.set(language, appDefaults)
        objectWillChange.send()
    }

    var settings: Settings { store.settings }

    func refusal(in section: Section) -> String? {
        refusalSection == section ? store.lastRefusal?.message : nil
    }

    func select(interval: Int) {
        guard interval != settings.intervalMinutes else { return }
        var s = settings; s.intervalMinutes = interval
        commit(s, .interval)
    }

    func setQuiet(enabled: Bool) {
        guard enabled != settings.quietEnabled else { return }
        var s = settings; s.quietEnabled = enabled
        commit(s, .quiet)
    }

    func beginEditing(_ end: QuietEnd) {
        draftMinutes = end == .start ? settings.quietStartMinutes : settings.quietEndMinutes
        editing = end
    }

    /// Done saves; Cancel and swiping the sheet away both discard
    /// (most thumbs swipe to escape, not to save).
    func done() { saveOnClose = true; editing = nil }
    func cancel() { saveOnClose = false; editing = nil }
    private var saveOnClose = false

    /// Called once when the time sheet closes, however it closed. Only Done
    /// saves, and an unchanged time saves nothing.
    func finishEditing() {
        guard let which = open else { return }
        open = nil
        defer { saveOnClose = false }
        guard saveOnClose else { return }
        var s = settings
        if which == .start { s.quietStartMinutes = draftMinutes } else { s.quietEndMinutes = draftMinutes }
        guard s != settings else { return }
        commit(s, .quiet)
    }

    private func commit(_ s: Settings, _ section: Section) {
        let refused = store.commit(s, now: now(), calendar: calendar)
        refusalSection = refused == nil ? nil : section
        objectWillChange.send()
    }
}

// MARK: - Content (no ScrollView, so ImageRenderer can snapshot it)

struct SettingsContent: View {
    @ObservedObject var model: SettingsModel
    /// A plain button, not a NavigationLink: outside a navigation stack (as in
    /// ImageRenderer snapshots) a NavigationLink draws as disabled grey, and the
    /// snapshot must show what the user sees.
    var openCredits: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            SettingsSection(title: "New word every", footer: model.refusal(in: .interval)) {
                ForEach(Array(Settings.offeredIntervals.enumerated()), id: \.element) { index, minutes in
                    if index > 0 { Hairline() }
                    SelectRow(label: SettingsCopy.interval(minutes),
                                selected: model.settings.intervalMinutes == minutes) {
                        model.select(interval: minutes)
                    }
                }
            }

            SettingsSection(title: "Quiet hours", footer: SettingsCopy.join(
                                model.refusal(in: .quiet)
                                    ?? (model.settings.quietEnabled ? "No new words arrive in this window. The last word stays on the Lock Screen." : nil),
                                SettingsStore.isShared ? nil : SettingsCopy.scheduleNotShared)) {
                Toggle(isOn: Binding(get: { model.settings.quietEnabled },
                                     set: { model.setQuiet(enabled: $0) })) {
                    Text("Pause new words").foregroundStyle(Ink.ink)
                }
                .toggleStyle(InkToggleStyle())
                .rowPadding()
                if model.settings.quietEnabled {
                    Hairline()
                    TimeRow(label: "From", minutes: model.settings.quietStartMinutes) { model.beginEditing(.start) }
                    Hairline()
                    TimeRow(label: "Until", minutes: model.settings.quietEndMinutes) { model.beginEditing(.end) }
                }
            }

            SettingsSection(title: "Words", footer: model.packs.count > 1 ? SettingsCopy.widgetsChooseOwnLanguage : nil) {
                // A picker only when there is a real choice (Ian, 2026-10-22):
                // with one pack the row states the value and does nothing.
                if model.packs.count > 1 {
                    ForEach(Array(model.packs.enumerated()), id: \.element) { index, pack in
                        if index > 0 { Hairline() }
                        SelectRow(label: SettingsCopy.language(pack.rawValue),
                                  selected: model.language == pack) {
                            model.select(language: pack)
                        }
                    }
                } else {
                    ValueRow(label: "Language", value: SettingsCopy.language(model.language.rawValue))
                }
                Hairline()
                ValueRow(label: "Level", value: SettingsCopy.levelLabel(model.language))
            }

                SettingsSection(title: "About", footer: nil) {
                    Button(action: openCredits) {
                        HStack {
                            Text("Credits").foregroundStyle(Ink.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Ink.secondary)
                                .accessibilityHidden(true)
                        }
                        .rowPadding()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(.isButton)
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.paper)
    }
}

// MARK: - Rows

struct SettingsSection<Content: View>: View {
    let title: String
    let footer: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(Ink.secondary)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                Hairline()
                content
                Hairline()
            }
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// One option in a single-select list. The checkmark is ink, not the accent:
/// Settings can hold two selection lists, and two vermilion marks would break
/// the one-accent rule. A shape plus the .isSelected trait, never colour alone.
struct SelectRow: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label).foregroundStyle(Ink.ink)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Ink.ink)
                        .accessibilityHidden(true)
                }
            }
            .rowPadding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// Label and value side by side; stacked at accessibility sizes so neither
/// word gets hyphenated ("Ja-panese" in the first AX3 snapshot).
struct LabelValue: View {
    let label: String
    let value: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).foregroundStyle(Ink.ink)
                Text(value).monospacedDigit().foregroundStyle(Ink.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack {
                Text(label).foregroundStyle(Ink.ink)
                Spacer()
                Text(value).monospacedDigit().foregroundStyle(Ink.secondary)
            }
        }
    }
}

struct TimeRow: View {
    let label: String
    let minutes: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            LabelValue(label: label, value: SettingsCopy.time(minutes))
                .rowPadding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) \(SettingsCopy.time(minutes))")
        .accessibilityHint("Opens a time picker")
    }
}

struct ValueRow: View {
    let label: String
    let value: String

    var body: some View {
        LabelValue(label: label, value: value)
            .rowPadding()
        .accessibilityElement(children: .combine)
    }
}

struct Hairline: View {
    var body: some View { Rectangle().fill(Ink.rule).frame(height: 1).accessibilityHidden(true) }
}

/// Ink on paper instead of the system green, which would be a second colour.
struct InkToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack {
                configuration.label
                Spacer()
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(configuration.isOn ? Ink.ink : Ink.rule)
                        .frame(width: 51, height: 31)
                    Circle()
                        .fill(Ink.paper)
                        .padding(2)
                        .frame(width: 31, height: 31)
                }
                .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Pause new words during quiet hours"))
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .toggleTrait()
    }
}

private extension View {
    /// `.isToggle` is iOS 17; on 16 VoiceOver still reads the On/Off value.
    @ViewBuilder func toggleTrait() -> some View {
        if #available(iOS 17, *) { accessibilityAddTraits(.isToggle) } else { self }
    }
}

private extension View {
    /// 44 pt minimum tap height at every text size.
    func rowPadding() -> some View {
        frame(minHeight: 44).padding(.vertical, 4)
    }
}

// MARK: - Time sheet

struct QuietTimeSheet: View {
    let title: String
    @Binding var minutes: Int
    let done: () -> Void
    let cancel: () -> Void

    var body: some View {
        NavigationStack {
            QuarterHourPicker(minutes: $minutes)
                .frame(maxWidth: .infinity)
                .background(Ink.paper.ignoresSafeArea())
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: cancel).foregroundStyle(Ink.secondary)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: done).foregroundStyle(Ink.ink).fontWeight(.semibold)
                    }
                }
        }
    }
}

/// A wheel time picker in 15-minute steps. SwiftUI's DatePicker has no
/// minute interval, so this wraps UIDatePicker.
struct QuarterHourPicker: UIViewRepresentable {
    @Binding var minutes: Int

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        picker.minuteInterval = 15
        picker.timeZone = TimeZone(identifier: "UTC")
        picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        picker.date = Date(timeIntervalSinceReferenceDate: TimeInterval(minutes * 60))
    }

    func makeCoordinator() -> Coordinator { Coordinator(minutes: $minutes) }

    final class Coordinator: NSObject {
        let minutes: Binding<Int>
        init(minutes: Binding<Int>) { self.minutes = minutes }
        @objc func changed(_ picker: UIDatePicker) {
            var utc = Calendar(identifier: .gregorian)
            utc.timeZone = TimeZone(identifier: "UTC")!
            let c = utc.dateComponents([.hour, .minute], from: picker.date)
            minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
    }
}

// MARK: - Copy

enum SettingsCopy {
    static func interval(_ minutes: Int) -> String {
        switch minutes {
        case 30: return "30 minutes"
        case 60: return "1 hour"
        default: return "\(minutes / 60) hours"
        }
    }

    /// Interval and quiet hours are the only settings a widget must share
    /// (lock-screen-widget-spec §1b); without the App Group both stay default.
    static let scheduleNotShared =
        "On this install the schedule can't reach the Lock Screen widget, so the app and the widget both keep hourly words with quiet hours 22:00–07:00."

    /// Under the Language row (§1b): the row is the app's, not the widget's.
    static let widgetsChooseOwnLanguage = "Widgets show the language you chose when adding them."

    static func join(_ parts: String?...) -> String? {
        let present = parts.compactMap { $0 }
        return present.isEmpty ? nil : present.joined(separator: "\n\n")
    }

    static func time(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    static func language(_ pack: String) -> String {
        switch Language(rawValue: pack) {
        case .japanese: return "Japanese"
        case .chinese: return "Chinese"
        case .korean: return "Korean"
        case nil: return pack
        }
    }

    /// What each pack ships. One tier per pack, so Level is a plain row.
    static func levelLabel(_ language: Language) -> String {
        switch language {
        case .japanese: return "JLPT N5"
        case .chinese: return "HSK 1–3"
        case .korean: return "Beginner"
        }
    }

    static func levelKey(_ language: Language) -> String {
        switch language {
        case .japanese: return "N5"
        case .chinese: return "HSK1-3"
        case .korean: return "beginner"
        }
    }
}

/// Languages whose word list loads in this build. Japanese today; Chinese and
/// Korean appear here, and in Settings, the day their bundles land.
let installedPacks: [Language] = [.japanese, .chinese, .korean].filter {
    ((try? bundledWords($0))?.isEmpty == false)
}
