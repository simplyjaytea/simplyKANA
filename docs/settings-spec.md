# Settings — cadence and language pack (milestone 2, after the first simulator build)

Owner: Ian. Implementer: Poppy (storage, widget reload, core), Dana (screen).
QA: Rachel. Requested by the user 2026-10-22: "a setting menu to let the user
choose how often the word is rotated, plus what language pack."

Settings is the first screen where the user can hurt themselves. Every option
here is validated by `isSatisfiable` before it is saved, and the screen says
why when it refuses. Nothing here may produce a dead widget.

---

## 1. What the screen offers

| Row | Options (MVP of this milestone) | Default |
|---|---|---|
| New word every | 30 min · 1 h · 2 h · 3 h · 6 h | 1 h |
| Quiet hours | On/off, start, end (15-minute steps) | On, 22:00–07:00 |
| Language pack | Japanese (only pack installed today); the row shows every pack present in the bundle, no "coming soon" items | Japanese |
| Level | N5 (only level today); same rule, shows what the pack contains | N5 |
| Credits | pushes the Credits screen | — |

- **Daily and twice a day (12 h) are not on the list yet.** Both wait for
  the two config-milestone preconditions in the playbook: the wall-clock grid
  (so "daily" means the same hour every day across DST) and the picker
  aliasing fix. 12 h has the same daily-skip exposure as daily (the bound
  allows a full slot to vanish unflagged), so it waits with it. When both
  preconditions land, "Daily" and "Twice a day" are added as rows and nothing
  else changes.
- **Why those intervals:** each divides 24 h, so the slot grid reads naturally
  on a clock, and none of 48, 24, 12, 8, 4 slots-per-day divides the
  bundle count (781 = 11 × 71), so no word is ever hidden by aliasing. The
  bundle gate already checks "not a multiple of 24"; it grows to "no common
  factor with any offered slots-per-day" (see §4).
- **Language pack** changes the bundle the picker draws from. Changing it
  resets nothing else; the schedule is the user's, the words are the pack's.
  One language per widget instance stands (lock-screen spec); the pack
  setting is the widget's, surfaced in the app for MVP because the widget has
  no configuration intent yet.

## 2. Storage and reload (Poppy)

- Settings live in an App Group `UserDefaults` suite shared by the app and
  the widget extension. Keys: `intervalMinutes`, `quietEnabled`,
  `quietStartMinutes`, `quietEndMinutes`, `languagePack`, `level`.
- The widget reads them when building its timeline. Missing keys mean the
  defaults above, so a fresh install and a pre-settings install behave the
  same.
- Saving calls `WidgetCenter.shared.reloadAllTimelines()`. The next entry is
  recomputed from the new schedule with `previousDelivery` for entry 0, so the
  word on screen does not change on save unless the schedule says it should.
- `Schedule` and `QuietHours` are built from these values by one function in
  KanaCore, `Schedule.from(settings:)`, tested on Linux. The screen never
  builds a `Schedule` by hand.

## 3. Validation and the refusal copy

Before saving, the screen runs `isSatisfiable(schedule:calendar:anchor:)`
with the device calendar and `Date()`. If false, the save is refused and the
row shows one sentence in secondary ink under the control:

> "With these quiet hours, no word would arrive for days at a time. Shorten
> the quiet window or choose a shorter interval."

The previous saved settings stay in force. No alert, no modal; the sentence
is the whole refusal. Invalid quiet hours (start == end) are prevented by the
control, not refused after the fact.

## 4. Gates (Rachel)

1. `Schedule.from(settings:)` round-trips every combination of the offered
   rows; defaults when keys are missing; never produces `QuietHours` with
   start == end.
2. Every offered interval, with default quiet hours, passes `isSatisfiable`
   in New York, London, Sydney, Tokyo, Kolkata, Lord Howe, Chatham,
   São Paulo and Casablanca with a 2026 anchor.
3. Bundle gate grows: for each offered interval, `gcd(wordCount, 1440 /
   interval) == 1`, and a one-year simulation at that interval shows every
   word at least once.
4. A refused save leaves the previous settings in `UserDefaults` unchanged
   (unit test on the view model).
5. Snapshots of the screen in light and dark at default and largest
   accessibility size, including the refusal state. The accent appears at
   most once (the selected interval's mark).
6. Phone-only, logged as a known gap: that `reloadAllTimelines` actually
   refreshes the Lock Screen promptly.

## 5. Design notes (Dana)

- Plain grouped list on paper. Section headers in secondary ink, no icons.
- The interval row is a single-select list, not a stepper or slider;
  the selected row carries the accent mark, which is the screen's one accent.
- Quiet hours uses two system time pickers in a row, 15-minute steps, with a
  single toggle above them. When off, the pickers are hidden, not disabled.
- No "Save" button. Changes apply when the control changes, after validation.
  Refusal copy appears under the control that caused it.
- Language and Level rows render only when the pack contains more than one
  option. With one option they are static rows that state the value, so the
  user sees what they have without a dead picker.

## 6. Out of scope for this milestone

Daily / twice-daily (preconditions above), per-widget configuration intents,
notifications, custom word lists, iCloud sync of settings. Each one gets its
own spec when it comes.
