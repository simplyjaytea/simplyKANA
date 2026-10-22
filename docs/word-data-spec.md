# Word Data Spec & Slot Cadence — "the drip" (MVP)

Owner: Ian (creative lead). Implementer: Poppy. QA: Rachel. Date: 2026-10-21.

This is the contract that turns `pickWord(for:from:)` from a stub into the
product. Everything here is pure Swift with no UIKit/WidgetKit and no I/O, so it
compiles and tests on Linux.

---

## 1. Word model

Revised 2026-10-22: the model is **language-neutral** so Chinese and Korean
(see §7) are a data drop, not a rewrite. The change lands now, before the N5
loader is written, because it is one field today and a migration next month.

```swift
enum Language: String, Codable { case japanese = "ja", chinese = "zh-Hans", korean = "ko" }

enum Level: Equatable, Hashable {
    case jlpt(Int)     // 5 = N5 (easiest) ... 1 = N1 (hardest)
    case hsk(Int)      // HSK 3.0 bands 1 (easiest) ... 9; decision 2026-10-22, see §7
    case nikl(Int)     // Korean: NIKL learner grades 1 = A/beginner, 2 = B, 3 = C; see §7
    var rank: Int      // 1 = easiest, for ordering the drip across any scale
    var label: String  // "N5", "HSK 1", "TOPIK 1" — what the UI shows
}

struct Word: Identifiable, Equatable, Hashable {
    let id: String            // stable source id: "jmdict:1000000", "cedict:…", "nikl:…"
    let language: Language
    let orthography: String   // shown large: kanji/kana (ja), hanzi (zh), hangul (ko)
    let reading: String       // furigana (ja), pinyin with tone marks (zh), Revised Romanization (ko);
                              // equals orthography for kana-only words
    let meanings: [String]    // English glosses (primary language for MVP)
    let partOfSpeech: String? // short label: "noun", "verb", ... nil = unspecified
    let level: Level?         // nil = unleveled (foundation kana, hangul jamo, level-unknown)
    let isCommon: Bool        // frequency flag, orders the drip toward useful words
}
```

Level encoding decision: keep each scale's raw number inside its own case so a
source list maps 1:1 with no mental arithmetic; `rank` normalises for sorting.
JLPT N5 is `.jlpt(5)`, which is what Poppy's loader already produces, now
wrapped. `pickWord`, `slot`, `nextDelivery` and `isSatisfiable` never look at
`language`; a word list handed to the scheduler is already one language.

MVP surface is orthography + reading + meaning. Example sentences, audio,
handwriting, flashcards, quizzes, Anki import, progress/history, iCloud sync,
and paywall are **explicitly deferred** — not part of this contract.

## 2. Cadence / schedule types

```swift
struct TimeOfDay: Equatable {          // minutes since midnight, 0..<1440
    let minutes: Int                   // 0 = 00:00, 1320 = 22:00
}

struct QuietHours: Equatable {         // start > end means it crosses midnight
    let start: TimeOfDay               // e.g. 1320 (22:00)
    let end: TimeOfDay                 // e.g. 420  (07:00) -> 22:00–07:00
}                                      // start == end is INVALID config (reject, not "always quiet")

struct Schedule: Equatable {
    let intervalMinutes: Int           // drip cadence; MVP default 60
    let quietHours: QuietHours?        // nil = deliver around the clock
    static let slotEpoch = Date(timeIntervalSinceReferenceDate: 0) // 2001-01-01T00:00:00Z
}
// wordsPerSlot removed (2026-10-21): MVP delivers one word per slot.
```

## 3. Function contracts (Poppy's signatures, pinned)

```swift
// Monotonic slot index: whole intervals elapsed since the epoch.
// Pure Date arithmetic; no Calendar — never resets at midnight.
func slot(for date: Date, intervalMinutes: Int) -> Int

// True when `at` is inside the quiet window (start inclusive, end exclusive).
// Must handle windows that cross midnight.
func isQuiet(at date: Date, quietHours: QuietHours, calendar: Calendar) -> Bool

// Next delivery time strictly after `date`, honoring interval + skipping quiet hours.
// A slot that lands in quiet hours is SKIPPED (suppressed) to the next non-quiet
// slot boundary — quiet hours pause the drip, they do not shift it. A sparse cadence
// whose slot sits inside quiet hours for a long stretch is a misconfiguration;
// isSatisfiable detects that so config can reject it. Returns nil when no non-quiet
// slot exists within the search guard — never a quiet time.
func nextDelivery(after date: Date, schedule: Schedule, calendar: Calendar) -> Date?

// Deterministic selection: same (slot, words) -> same Word across reloads.
// Spreads across the list (slot 0 -> words[0], slot 1 -> words[1], wraps).
// Returns nil iff `words` is empty.
func pickWord(for slot: Int, from words: [Word]) -> Word?

// True when no delivery in a full year starves the user. Walks every delivery
// across the 366 days AFTER `anchor` in `calendar`'s time zone.
//
// `anchor` is required, with no default, on purpose. The caller (the config
// screen) passes the current date so the walk uses the DST rules the user
// lives under now. Walking from the 2001 epoch judged schedules by 2001 rules:
// São Paulo (lost DST) was falsely rejected, Casablanca (gained Ramadan DST)
// was approved and then froze for 8 months (Bug #4). The function itself reads
// no clock, so it stays pure and tests pass a fixed date. Accepted residual
// risk: the verdict is only as current as the device's time zone database.
//
// A delivery is "starved" when its successor is nil, OR lands beyond the
// schedule's legitimate worst case:
//
//     maxGap = 2 * interval + quiet span + 1 hour
//
// Why each term (bound revised 2026-10-22, third and final revision):
//   * 2 * interval — quiet hours rarely align to the slot grid. The last word
//     before quiet can land up to one interval before the window opens, and the
//     first word after can land up to one interval after it closes. Each edge
//     costs an interval, so the bound needs two. (1× rejected "quiet until
//     06:30" and every non-hour interval; Rachel's Bug #3b.)
//   * quiet span — the pause itself, measured in wall-clock minutes.
//   * 1 hour — fall-back night repeats an hour, so a healthy quiet window that
//     crosses the transition runs one real hour longer than its wall-clock span.
//     (Without it the default 22:00–07:00 was rejected in every DST zone; Bug #3.)
//
// This is what catches seasonal DST drift: a daily slot that sits inside
// quiet hours for only part of the year. A single epoch probe is NOT enough —
// "non-nil" is always true because nextDelivery skips, so the check must
// measure the gap, not just nil-vs-non-nil.
func isSatisfiable(schedule: Schedule, calendar: Calendar, anchor: Date) -> Bool
```

### nil behavior (the product answer)

`nextDelivery` returning nil means the schedule is unsatisfiable (e.g. a daily
cadence whose only slot always lands inside quiet hours). The widget must NOT
silently freeze: keep showing the last delivered word. At config time,
`isSatisfiable == false` means the config screen states the problem in plain
language and **refuses to save** — a dead widget with no explanation is a bug,
and a saved-but-starved schedule is the same bug wearing a mask.

Determinism rule for `pickWord`: `words[slot.modulo(words.count)]`, but ordered so
the drip reads naturally (kana foundation first, then N5). `isCommon` sorts within
a level; exact ordering is Poppy's to implement, the guarantee is determinism.

**Uniqueness (2026-10-22):** one entry per (orthography, reading). 人 ひと and
一日 ついたち are different words and each shows its own reading.

**Affix rule (rule 8, decided 2026-10-22 evening):** an entry is dropped when it
cannot stand alone as something a learner would say by itself: honorific
prefixes and suffixes, plural and verb suffixes, counters, and particles.
Loanword units that are used as nouns on their own stay. The gate is this
literal list, not the prose:

| Dropped | Why |
|---|---|
| お | honorific prefix |
| さん, たち, がる | suffixes (honorific, plural, verb) |
| 人 じん "-ian", 人 にん counter | affix senses of 人; 人 ひと stays |
| 中 じゅう, 中 ちゅう | suffix senses of 中 |
| 屋 や | "-shop" suffix; the shops themselves (本屋) stay |
| 日 にち, 時 じ | counters; 日 ひ and 時 とき stay |
| ずつ | particle |

| Allowed | Why |
|---|---|
| キロ | used alone as a noun ("5キロ") |

Expected count after the list: 783 (not a multiple of 24). Any new drop or
restore changes this table first and the bundle second.

**Spacing rule (2026-10-22):** entries that share an orthography are placed at
least 24 slots apart in the ordered list, measured circularly (the list wraps,
so the last and first entries are neighbours). The picker stays pure; the
constraint lives in the bundle's order and is gated there. Gate test: for every
pair of entries with equal orthography, circular distance ≥ 24.

## 4. Data source

- Foundation kana: 46 hiragana + 46 katakana. Each is a `Word` with
  `orthography == reading == kana`, `meaning = romaji`, `language = .japanese`, `level = nil`,
  `partOfSpeech = "hiragana"` or `"katakana"` (revised 2026-10-22, was `"kana"`:
  the UI and VoiceOver name the script, so the data must carry it).
- JLPT vocabulary is a **join of two sources** (revised 2026-10-22; JMdict
  carries no JLPT tags, and the JLPT stopped publishing official lists in 2010):
  - **Level membership** comes from the open-anki-jlpt-decks N5 list
    (MIT licence; derived from Jonathan Waller's tanos.co.uk lists). 717
    entries. `level = .jlpt(5)` means "on that list", nothing more.
  - **Everything else** (`id` as `jmdict:<ent_seq>`, `meanings`,
    `partOfSpeech`, `isCommon`) comes from JMdict/EDRDG (CC-BY-SA 4.0), matched
    on (expression, reading). Join script: Poppy's `word-data/join_n5.py`.
  - Match rules: a word with no JMdict match is fixed by hand or dropped, never
    guessed. A word with several matches is resolved by hand before it ships;
    a wrong meaning on a lock screen is worse than a missing word.
  - `partOfSpeech` is normalised to short labels ("noun", "verb", "adjective",
    "counter", ...), never JMdict's long form.
  - Bundle N5 for the free MVP; N4–N1 later use the same join.
- **Attribution (required, in-app credits screen):** "EDRDG" for JMdict under
  CC-BY-SA 4.0, and Jonathan Waller / open-anki-jlpt-decks for the N5 list.

No Hourly Kana assets, copy, or layout. Our own data, our own UI.

## 5. Defaults (the "out of the box" product)

interval = 60 min, wordsPerSlot = 1, quiet hours = 22:00–07:00, level = N5.
Quiet hours on by default; user toggles them later (config is out of MVP scope).

## 6. Known limitations and accepted risks

1. **Epoch-absolute grid drifts across DST.** Slots are fixed intervals from
   2001-01-01Z, so a word's wall-clock time drifts by ±1h across DST. Harmless
   for the MVP's fixed hourly cadence; revisit with a wall-clock (calendar-aware)
   grid when daily/custom cadence config ships, so a "daily 8am" word stays at
   8am instead of wandering.

2. **A daily schedule can skip one day unflagged.** Because the bound scales
   with the interval (2 × 1440 min), `isSatisfiable` allows a daily schedule to
   miss a single day without rejecting it. Long freezes (the 52-day New York
   case) are still caught. **Decision (Ian, 2026-10-22): accepted for MVP.**
   Reasons: (a) the MVP ships a fixed 60-minute interval with no cadence config,
   so no user can create a daily schedule; (b) a one-day skip on a daily cadence
   is the epoch-grid drift in item 1 wearing a different hat, and the fix is the
   same wall-clock grid, not a tighter bound. **Revisit condition:** before any
   cadence ≥ 12h is exposed in config, replace the epoch grid per item 1 and
   tighten the daily bound to "never skip a day". Mira tracks this as a
   pre-condition of the config milestone, not a launch item.

3. **Validation is only as current as the device's time zone database.**
   (Replaces the former "2001 DST rules" risk, fixed as Bug #4 via `anchor`.)
   If a country changes its DST rules after launch, `isSatisfiable` judges by
   whatever rules the phone has until the OS ships updated zone data. Not
   fixable in this code. Accepted, owner Mira.

## 7. Chinese and Korean (requested 2026-10-22, second release)

Decision (Ian): **yes to the feature, no to the MVP.** The Japanese MVP ships
first on the language-neutral model above; Chinese and Korean follow as data
packs plus a language picker. Nothing in the scheduler changes.

**Product rules**
- One language per widget instance. A user who wants two languages adds two
  widgets. Mixing languages inside one drip is not a feature; it is noise.
- Level picker shows the native scale (N5 / HSK 1 / Beginner), never `rank`.
- **HSK version: 3.0 (decided 2026-10-22).** It is the exam people sit now. Ship
  bands 1–3 first as the free entry tier, the way N5 is for Japanese. Do not
  mix 2.0 and 3.0 lists; a word's band comes from one list only.
- **Korean levels: NIKL grades, not TOPIK (decided 2026-10-22).** TOPIK has no
  official word list, and we do not invent one. Store NIKL's A/B/C as
  `.nikl(1...3)`, label them "Beginner / Intermediate / Advanced" in the UI,
  and credit NIKL. Marketing may say "covers TOPIK I vocabulary"; the data
  model may not. If an official TOPIK list ever appears, add `.topik` then.
- Chinese ships **simplified** first. Traditional is a later toggle, stored as
  a second orthography on the same word, not a second word.
- Korean foundation = the 40 hangul jamo (as kana are for Japanese), then
  NIKL grade A vocabulary. Chinese has no foundation tier; HSK 1 is the entry.

**Candidate data sources (Poppy to verify licence and coverage before use)**
- Chinese: CC-CEDICT (CC-BY-SA 4.0, credit MDBG/CC-CEDICT) for id, pinyin,
  glosses; the MIT-licensed HSK 3.0 list for band membership. Same join as §4.
- Korean: NIKL Korean Basic Dictionary (한국어기초사전) or kengdic for id,
  romanization, glosses; NIKL learner vocabulary list for grade membership.
  Licences for all three unconfirmed as of 2026-10-22 (Poppy, before release two).

**Done when**: a `Word` for each language loads through the same Swift loader,
the same tests pass with `language` swapped, and the credits screen names each
source. Owner: Ian (spec), Poppy (loader + data), Rachel (gate), Mira (dates
after the Japanese MVP has a Mac).
