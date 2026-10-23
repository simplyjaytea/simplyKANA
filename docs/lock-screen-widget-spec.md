# Lock Screen Widget — "the drip" on the surface (MVP)

Owner: Ian (creative lead). Implementer: Poppy. QA: Rachel. Date: 2026-10-22.
Revised 2026-10-22 after Rachel's review (PR #1): quiet-hours reload rule,
`previousDelivery`, edge cases, and the CI rendering correction.
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
| `accessoryCircular` | 1 glyph slot | the whole orthography or no word; see the circular rule below |

- Lock Screen widgets render in the system's vibrant monochrome. No colour
  decisions exist here; hierarchy is size and weight only.
- System font for MVP. Japanese glyphs fall back correctly on iOS; a custom
  serif (Noto Serif JP) is a Home Screen decision, later.
- Readings longer than the line (rectangular) truncate with an ellipsis. The
  orthography never truncates: if it does not fit, the font shrinks one step.
- No streaks, no counters, no badges, no "tap to learn more" copy. One word.

**Circular rule: never cut a word.** (Revised after Poppy's review: a cut
word is a different word. つまらない cut to つま‥ reads "wife"; おじいさん cut
to おじ‥ reads "uncle". The circular slot either shows the whole word or no
word.)

| Length | Rendering |
|---|---|
| 1–2 chars | One line, full size. |
| 3–4 chars | One line, shrink with `minimumScaleFactor` floor 0.6. |
| 5–8 chars | **Two lines**, at most 4 chars per line, floor 0.5. Split rule below. テープレコーダー → テープレ / コーダー. パーティー → パー / ティー. ワイシャツ → ワイ / シャツ. おじいさん → おじい / さん. |
| 9+ chars | Does not fit honestly. Show the **brand glyph** `語` alone, full size. It means "a word is waiting" and is the same for every such word, so it is never a wrong word. The rectangular and inline families still show the word in full. |

**Split rule (revised after Rachel's review; moving right broke パーティー).**
Kinsoku set `K` = ー, small kana (っ ゃ ゅ ょ ぁ ぃ ぅ ぇ ぉ and katakana
forms), ん, ン, ゎ, ヮ, ヵ, ヶ. A line never starts with a character in `K`.

1. Candidate split `s = ceil(n/2)`. Valid positions are `max(1, n-4) ... min(4, n-1)`
   so both lines are 1–4 characters.
2. If `w[s]` is in `K`, move the split **left** one position and re-check.
   Repeat while in range, so runs of kinsoku characters (ティー, シャツ) are
   handled. パーティー: s=3 → ィ, left → s=2 → テ, valid: パー / ティー.
3. If no leftward position is valid, try rightward positions in the range.
4. If no position in the range is valid, the word does not fit honestly:
   show the brand glyph `語` (same as 9+).

Reference implementation is a 15-line function; it lives in KanaCore as
`circularLines(for: String) -> [String]?` (nil means "show 語") so Linux CI
tests it against the whole bundle, not just the snapshot.

- The N5 bundle has 11 words of 5+ characters and none above 8, so the 9+
  branch is defined but unreachable in MVP. The word-data gate reports the
  count of 9+ words in any bundle; it does not reject them.
- Gate (§6, §7.3): every bundle word of 5+ characters (count comes from the
  joined bundle, not the raw list, which has multi-form entries like 伯父;
  叔父さん) renders in the circular snapshot test without clipping. Named
  cases: テープレコーダー (longest), パーティー and ワイシャツ (kinsoku runs),
  and a synthetic word with no valid split (expects `語`).

## 1b. One widget per language (decided 2026-10-22, Rachel's proposal, user approved)

The sideload route has no shared storage, so a language chosen in the app
cannot reach the widget. Rather than a picker that looks like it works, the
language is chosen by **which widget the user adds**:

- The extension registers one widget kind per installed pack:
  "simplyKANA · Japanese", "simplyKANA · Chinese", later "· Korean". Same
  three families each. iOS lists them side by side in the widget gallery.
- Each kind's timeline draws from its own pack. No storage, no App Group,
  no disagreement possible between what is on the Lock Screen and what a
  tap opens: the deep link carries the language and the word id
  (`simplykana://word/<lang>/<id>`), and the app opens exactly that word.
- The widget never reads a "current language" from anywhere. The pack is
  the kind.
- Interval and quiet hours stay on the defaults on the sideload route until
  press-and-hold configuration (milestone 2 fallback) exists.

Consequence for Settings: the Language row controls the **app only** (the
Word screen opened directly, the Today list) and says so in one line of
secondary ink: "Widgets show the language you chose when adding them." It
stays a plain row until two packs are installed.

Two rules Rachel added on review (2026-10-23):
- **The app reads its own language setting from its own `UserDefaults`,
  never from the App Group.** The #24 fallback to defaults applies to
  interval and quiet hours only, because those are the settings a widget
  must share. Language has no widget consumer any more, so it works on the
  sideload route without shared storage.
- **Deep links without a language segment still open.** `simplykana://word/<id>`
  (the pre-#38 form, which an already-added widget may still send) is
  treated as Japanese. Unknown language segments open the app on its current
  word rather than failing.

Gates: each kind registers (the #34 check runs per kind); a Chinese widget
never shows a Japanese word and vice versa (Linux, timeline per pack); the
deep link round-trips language and id, and the legacy form opens as
Japanese; the app opens the tapped word even when its own Language row says
otherwise (simulator); changing the Language row with no App Group present
changes the app's word (simulator, the sideload case).

## 2. Timeline (the contract with the scheduler)

All timeline logic is **pure and lives in KanaCore**, so it is tested on Linux.
The WidgetKit `TimelineProvider` is a thin adapter with no logic of its own.

```swift
struct Entry: Equatable { let date: Date; let word: Word }

struct DripTimeline: Equatable {
    let entries: [Entry]   // never empty; entries[0].date <= after < entries[1].date
    let reloadAt: Date     // when the provider asks WidgetKit to reload
}

// Most recent delivery at or before `date` that is outside quiet hours, on the
// slot grid. Same search guard and the same nil rule as nextDelivery: nil
// when no non-quiet slot exists within the guard. Mirror image of nextDelivery.
func previousDelivery(atOrBefore date: Date, schedule: Schedule, calendar: Calendar) -> Date?

// The widget's timeline. `limit` caps the number of future entries.
func timeline(after: Date, schedule: Schedule, words: [Word],
              calendar: Calendar, limit: Int = 24) -> DripTimeline
```

**One rule for the first entry, one rule for the rest.**

- `entries[0]` is the word of `previousDelivery(atOrBefore: after)`, dated at
  that delivery. It is at or before `after` by definition. This is the word
  that is on screen *now*, and it is the same word no matter when iOS reloads.
  Reloading at 23:30 inside a 22:00–07:00 quiet window yields the 21:00 word,
  not the 23:00 slot's word. That is the determinism promise.
- `entries[1...]` are the deliveries strictly after `after`, from
  `nextDelivery`, at most `limit` of them. No entry is ever dated inside quiet
  hours.
- `word` for any entry is `pickWord(for: slot(for: entry.date, …), from: words)`.

**Edge rules (each one is a test in §7).**

| Case | Rule |
|---|---|
| `previousDelivery` is nil (no non-quiet slot in the past guard) | `entries[0]` is the fallback word (below), dated `after`. |
| `nextDelivery` returns nil mid-walk | Stop. `entries` keeps what was built. `reloadAt = after + max(interval, 1h)` so the provider never uses `.atEnd` on a past-dated last entry (iOS would reload in a loop and burn the budget). |
| `limit <= 0` | Return `entries[0]` only. `reloadAt = after + interval`. |
| `words` is empty | One entry, the fallback word, dated `after`. `reloadAt = after + 1h`. The adapter logs it; the bundle gate (Rachel) makes it unreachable in a shipped build. |
| Normal | `reloadAt = entries.last!.date` (the provider maps this to `.after(reloadAt)`, which is `.atEnd` in effect but explicit). |

**Fallback word.** Lives in KanaCore so it is tested, not in the adapter:
`Word(id: "kanacore:fallback", language: .japanese, orthography: "—",
reading: "—", meanings: [""], partOfSpeech: nil, level: nil, isCommon: false)`.
The rectangular family renders it as a single `—` line.

- `limit` default 24. WidgetKit's refresh budget is roughly 40–70 reloads per
  day; 24 hourly entries with one reload at the end stays well under it.
- **Quiet hours:** no entry is created inside the window. The previous word
  stays on screen. The widget never blanks, never shows "paused".

## 3. Interaction

- Tap opens the app on that word: `simplykana://word/<Word.id>`. Until the app
  shell exists the URL opens the app and is ignored.
- No configuration intent for MVP (interval and quiet hours are the §5 defaults
  from the word data spec). Add `AppIntentConfiguration` when config ships.

## 4. States

| State | Behaviour |
|---|---|
| Placeholder / redacted | A real-looking word (`日 · にち · day`) with `.redacted(reason: .placeholder)` |
| Empty word list | Fallback word from §2, logged. Must not happen in a shipped bundle. |
| Quiet hours | `entries[0]` is the last non-quiet delivery. Previous word stays; no entry in the window. |
| Unsatisfiable schedule | Fallback or last word, bounded reload. Unreachable in MVP (fixed hourly), defined anyway. |
| Clock change / DST | Entries are absolute dates from the slot grid; nothing to do. |

## 5. Accessibility

- VoiceOver label: "`<orthography>`, read `<reading>`, means `<meaning>`".
  When `reading == orthography` the "read …" clause is dropped.
  Kana (`partOfSpeech` is `hiragana` or `katakana`): "`<kana>`, `<script>`,
  romaji `<meaning>`", so あ reads "あ, hiragana, romaji a" (Dana's rule; the
  app's Word screen uses the same one).
  The fallback word's label is "No word available".
- **One function, in parts (Poppy and Dana, 2026-10-22).** The wording lives
  once in KanaCore and returns parts so the language tag survives:

  ```swift
  struct SpokenPart: Equatable { let text: String; let language: String? } // "ja", or nil for the phone's language
  func spokenLabel(for word: Word) -> [SpokenPart]
  ```

  あ → `[("あ", "ja"), (", hiragana, romaji a", nil)]`. 日 → `[("日", "ja"),
  (", read ", nil), ("にち", "ja"), (", means day", nil)]`. The widget and the
  Word screen each build an `AttributedString` from the parts and tag each
  part's `languageIdentifier`, so VoiceOver switches to a Japanese voice for
  the Japanese text. Linux CI tests the wording and that every Japanese part
  is tagged `ja`. How the Japanese voice actually sounds is the only
  phone-only line. `spokenLabel` is Monday's work, with the widget, not
  Friday's.
- Dynamic Type: rectangular honours it up to the point the orthography would
  truncate, then stops scaling. The word wins.

## 6. What can and cannot be verified without a phone

- **Linux and macOS CI:** `previousDelivery` and `timeline`, every rule in §2.
- **macOS CI only:** the widget extension builds for the iOS Simulator, and a
  snapshot test renders each family to an image with `ImageRenderer` at the
  family's size. Xcode previews do **not** run on a headless runner, so the
  snapshot test is the rendering gate. It asserts: no crash, and for the
  circular family, every bundle word of 5+ characters (11 in N5, worst case
  テープレコーダー) renders on two lines at the §1 floor without clipping. This costs macOS minutes; Mira tracks them. It is the only
  rendering check we get before a phone.
- **Phone only (known gap, on the release checklist):** real refresh cadence,
  Lock Screen vibrant rendering, Always-On dimming, tap routing. Plan a fix
  window after the first real-phone run.

## 7. Done when

1. `previousDelivery(atOrBefore:)` is in KanaCore with tests: at-or-before,
   skips quiet hours backwards, crosses midnight, nil within the guard, and
   the **no-skip property** (Rachel's correction: the old "mirror" property
   returned `t` itself for non-quiet `t` and could not fail). For `t` inside
   quiet hours, across midnight, and on both DST change nights:
   `p = previousDelivery(atOrBefore: t)` is non-nil, outside quiet hours,
   `p <= t`, and `nextDelivery(after: p) > t` (no delivery between `p` and `t`
   was skipped).
   Plus `circularLines(for:)` tests: the four named §1 cases, every 5+ word in
   the bundle yields two lines of 1–4 with neither starting in `K`, and 1–4
   char words yield one line.
2. `timeline` is in KanaCore with tests:
   - `entries[0].date <= after` and `entries[1].date > after`;
   - reload at 23:30 inside quiet 22:00–07:00 returns the 21:00 word as
     `entries[0]` (the determinism case from Rachel's review);
   - no entry dated inside quiet hours;
   - `limit` respected; `limit <= 0` returns one entry;
   - `nextDelivery` nil mid-walk stops the walk and bounds `reloadAt`;
   - empty `words` returns the fallback word and a bounded `reloadAt`;
   - same inputs, same output (determinism across reloads).
3. The widget extension builds for the iOS Simulator in CI, and the
   `ImageRenderer` snapshot test passes for all three families, including
   every circular two-line case from the bundle and the `語` glyph for a
   synthetic word with no valid split.
4. Rachel has gated 1–3, and the release checklist records the phone-only gap.
