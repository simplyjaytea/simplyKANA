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

**Affix rule (rule 8, decided 2026-10-22 evening, refined after Poppy's
counter question):** an entry is dropped when it is (a) a pure grammatical
morpheme (honorific prefix or suffix, plural or verb suffix, particle), or
(b) an affix *sense* of a character that already has a standalone entry
(人 にん when 人 ひと exists). **Counters that are the character's only entry
stay** (枚, 回, 階, 台 and the rest): they are N5 vocabulary with a meaning of
their own. Loanword units used as nouns stay. The gate is this literal list,
not the prose:

| Dropped | Why |
|---|---|
| お | honorific prefix |
| さん, たち, がる | suffixes (honorific, plural, verb) |
| 人 じん "-ian", 人 にん counter | affix senses of 人; 人 ひと stays |
| 中 じゅう, 中 ちゅう | suffix senses of 中 |
| 屋 や | "-shop" suffix; the shops themselves (本屋) stay |
| 時 じ, 年 ねん | counter senses with a standalone sibling; 時 とき and 年 とし stay |
| ずつ, だけ, など | particles |

| Allowed | Why |
|---|---|
| キロ | used alone as a noun ("5キロ") |
| 日 にち | the N5 list has no 日 ひ, so にち is 日's only entry (corrected 2026-10-22 after Poppy's check) |
| 枚, 回, 階 and every other counter with no standalone sibling entry | the character's only entry; N5 vocabulary |

Expected count after the list: 781 (not a multiple of 24; にち restored, ねん dropped). Any new drop or
restore changes this table first and the bundle second.

**Chinese readings and tones (2026-10-23, from Rachel's 141-pair check):**
- Tones follow the official HSK list where the two sources disagree,
  including neutral tones (好处, 过来, 出来). CC-CEDICT supplies the reading
  everywhere else. Logged risk: the ~2,070 non-heteronym readings are
  CC-CEDICT, unchecked against the official list, because no licensed text
  copy of it exists. Accepted; revisit if a phone sample finds a wrong tone.
- 子 is dropped under rule 8 (HSK 1 lists it only as the noun suffix in 桌子).
  That leaves 2,208 = 48 × 46, which aliases the 30-minute interval, so the
  pack must shed or add one more word; the count gate catches it either way.
- 把 leads with the object-marker and measure-word senses, not "to hold".
  称 leads with "to call"; "to weigh" is an HSK 4 sense and goes second.

**First-meaning length (2026-10-22, from the first widget snapshots):** the
Lock Screen shows only `meanings[0]`, and it must fit the rectangular widget
on the smallest supported phone without truncation. Rachel's gate wins over
the "truncate the meaning first" wording in the widget spec: that wording
covers the inline family only. The build script enforces a character cap on
`meanings[0]` (Poppy sets the number from the snapshot measurement, with the
longest counter as the worst case) and fails when exceeded. Long glosses are
shortened by hand for position 0 (枚 → "flat things (counter)", one shared short form for every counter) and the full
JMdict gloss moves to `meanings[1]`. The Word screen leads with `meanings[0]`
and shows `meanings[1...]` as one quieter "also: …" line (design direction §4),
so the full gloss is reachable without ever leading.

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
- Korean (decided 2026-10-23): **NIKL's Basic Korean Dictionary
  (한국어기초사전) is the source of meanings, readings and ids**; the NIKL
  learner vocabulary list gives grade membership. Licence: CC BY-SA 2.0 KR
  per krdict.korean.go.kr/kor/kboardPolicy/copyRightTermsInfo, which carves
  out only audio and pronunciation files. **Accepted risk, recorded in
  tools/DATA-LICENSES.md in plain words:** the page does not name the
  English translations specifically; they fall under its "everything not
  otherwise marked" line. That is an inference. If the user wants it in
  writing from NIKL, the user sends the email; nobody on the team can.
  **kengdic (MPL 2.0) becomes Rachel's independent second dictionary** for
  the reading pass, reversing the earlier plan, so the check never compares
  a source against itself.

**Heteronym rule (Ian, 2026-10-22; applies to every pack).** A word with more
than one reading in the dictionary takes its reading **and** its first meaning
from the same dictionary entry, chosen by a person, never by a script. 行 read
xíng is "to walk"; read háng it is "row". Each pack keeps a hand-written table
(word, reading, Lock Screen meaning, a phrase that must appear in that
reading's entry); the build fails if a heteronym is missing from the table, if
a row's reading isn't an entry of that word, or if its phrase isn't in that
entry. Chinese: `tools/zh_heteronyms.tsv`, 141 rows, checked by Rachel against
the official HSK 3.0 PDF. Korean inherits the rule when its pack is built.

**Korean pack, first cut (user priority, 2026-10-23). What Poppy builds:**
- **Scope:** the 40 hangul jamo as the foundation tier (`partOfSpeech =
  "jamo"`, `level = nil`, meaning = the letter's sounds, both where it has
  two: ㄱ "g / k", ㄹ "r / l", ㅇ "silent / ng"; single-sound letters show
  one), then
  NIKL learner-list **grade A only** (초급, about a thousand words,
  `level = .nikl(1)`, UI label "Beginner"). Grades B and C later.
- **Sources:** NIKL Basic Korean Dictionary download for id (`krdict:<entry>`),
  orthography, English meanings and any reading; NIKL learner vocabulary list
  for grade membership. Readings are Revised Romanization **generated from
  the pronunciation NIKL lists for each entry**, not from the spelling:
  Korean changes sounds at syllable joins (국물 gungmul, 같이 gachi, 좋다
  jota), and a letter-by-letter converter gets every one of those wrong.
  Deterministic, tested on Linux with a table of about 30 known sound-change
  words (Rachel's gate). Where NIKL lists no pronunciation, the build fails
  on that word rather than guessing.
- **Homographs:** Korean has many identical spellings with unrelated meanings
  (배 pear / boat / belly) and the romanization is identical too, so the
  (orthography, reading) uniqueness key would collide. Rule for Korean:
  **one entry per orthography**, leading with the sense NIKL marks for the
  learner list; the other senses go to `meanings[1...]` as the "also:" line.
  A learner sees 배 once, not three times.
- **Affixes:** rule 8 applies: particles (은/는, 이/가, 을/를, 에, 에서…),
  verb endings and honorific suffixes (-님, -씨) drop. Verbs and adjectives
  keep NIKL's dictionary form (-다).
- **Font:** Noto Serif KR subset, same build check as Chinese; AppleMyungjo
  is not on iOS. Voice `ko-KR`; spoken text is the orthography.
- **Rachel's read:** every first meaning, with kengdic as the independent
  second dictionary. Expect fewer hand fixes than Chinese: NIKL's English is
  written for learners, not inherited from a general dictionary.
- **Licence:** CC BY-SA 2.0 KR, kept as its own notice, not relabelled 4.0.
- **Word count:** 40 jamo plus grade A lands near 1,000. The count must not
  be a multiple of 24 and must be coprime with every offered slots-per-day
  (48, 24, 12, 8, 4). If the natural count fails, **hold back one grade A
  word, not a jamo**, chosen in Rachel's reading pass and recorded in
  `drops.txt` with the reason "count". The build check enforces it; the
  choice of word is human.

**Done when**: a `Word` for each language loads through the same Swift loader,
the same tests pass with `language` swapped, and the credits screen names each
source. Owner: Ian (spec), Poppy (loader + data), Rachel (gate), Mira (dates
after the Japanese MVP has a Mac).
