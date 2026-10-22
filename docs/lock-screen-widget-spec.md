# Lock Screen Widget — "the drip" on the surface (MVP)

Owner: Ian (creative lead). Implementer: Poppy. QA: Rachel. Date: 2026-10-22.
Decision (user, 2026-10-22): **Lock Screen first.** Home Screen widget follows.

The Lock Screen is the whole product. A person glances at their phone forty
times a day without meaning to; this is where learning happens in the
background of a life. Everything below serves that one glance.

---

## 1. Families and what each shows

| Family | Size (approx.) | Content |
|---|---|---|
| `accessoryRectangular` | 3 lines | **orthography** large · reading (omitted when equal to orthography) · first meaning |
| `accessoryInline` | 1 line | `日 · にち · day` — truncate the meaning first, never the word |
| `accessoryCircular` | 1 glyph | orthography only, as large as fits; 2+ chars shrink, never wrap |

- Lock Screen widgets render in the system's vibrant monochrome. No colour
  decisions exist here; hierarchy is size and weight only.
- System font for MVP. Japanese glyphs fall back correctly on iOS; a custom
  serif (Noto Serif JP) is a Home Screen decision, later.
- Readings longer than the line (rectangular) truncate with an ellipsis. The
  orthography never truncates: if it does not fit, the font shrinks one step.
- No streaks, no counters, no badges, no "tap to learn more" copy. One word.

## 2. Timeline (the contract with the scheduler)

All timeline logic is **pure and lives in KanaCore**, so it is tested on Linux:

```swift
struct Entry: Equatable { let date: Date; let word: Word }

// Entries strictly after `after`, one per delivery, honoring interval and
// quiet hours via nextDelivery. `limit` caps the count (WidgetKit budget).
// Returns [] only when `words` is empty.
func timeline(after: Date, schedule: Schedule, words: [Word],
              calendar: Calendar, limit: Int) -> [Entry]
```

- `word` for an entry is `pickWord(for: slot(for: entry.date, …), from: words)`.
- `limit` default 24. WidgetKit's refresh budget is roughly 40–70 per day;
  24 hourly entries plus `.atEnd` reload policy stays well under it.
- **Quiet hours:** no entry is created inside the window. The previous entry
  stays on screen. The widget never blanks, never shows "paused".
- **First entry** is the current word (the entry for the slot containing
  `after`), so the widget is never empty at install; subsequent entries are
  future deliveries.
- The WidgetKit `TimelineProvider` is a thin adapter: build `schedule` and
  `words`, call `timeline`, map to `TimelineEntry`. No logic in the adapter.

## 3. Interaction

- Tap opens the app on that word: `simplykana://word/<Word.id>`. Until the app
  shell exists the URL opens the app and is ignored.
- No configuration intent for MVP (interval and quiet hours are the §5 defaults
  from the word data spec). Add `AppIntentConfiguration` when config ships.

## 4. States

| State | Behaviour |
|---|---|
| Placeholder / redacted | A real-looking word (`日 · にち · day`) with `.redacted(reason: .placeholder)` |
| Empty word list | Must not happen in a shipped bundle; render `—` and log. Rachel gates the bundle. |
| Quiet hours | Previous word stays. Timeline has no entry in the window. |
| Clock change / DST | Entries are absolute dates from the slot grid; nothing to do. |

## 5. Accessibility

- VoiceOver label: "`<orthography>`, read `<reading>`, means `<meaning>`".
- Dynamic Type: rectangular honours it up to the point the orthography would
  truncate, then stops scaling. The word wins.

## 6. What can and cannot be verified without a phone

- **Simulator / CI:** `timeline` on Linux and macOS; each family renders via
  Xcode previews on the macOS runner; the widget extension builds for the
  iOS Simulator.
- **Phone only (known gap, logged on the release checklist):** real refresh
  cadence, Lock Screen vibrant rendering, Always-On dimming, tap routing.
  Plan a fix window after the first real-phone run.

## 7. Done when

1. `timeline` is in KanaCore with tests: strictly-after, limit, quiet-hour gap,
   first-entry-is-current, empty-words-is-empty, determinism across reloads.
2. A `WidgetKit` extension target builds in CI for the iOS Simulator and
   renders all three families in previews.
3. Rachel has gated both, and the release checklist records the phone-only gap.
