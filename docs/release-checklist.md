# Release checklist (alpha: Japanese, Lock Screen widget)

Owner: Rachel (QA). Nothing ships until every box is checked or explicitly
moved to "Accepted risks" with an owner. Updated 2026-10-22 (late).

## Gates (proven in CI or the iOS Simulator)

- [x] Scheduler core: slot, quiet hours, nextDelivery, isSatisfiable with anchor. Mutation-checked.
- [x] Language-neutral `Word` model, `.nikl` level. Gated with the word data (#8).
- [x] Word data, 781 words (92 kana + N5), hand-reviewed (#8, #15). Bundle checks, all as tests:
  - [x] No orthography or reading contains a space, bracket, `;` or `～`.
  - [x] Unique (orthography, reading); rule 8 table applied (word-data-spec).
  - [x] Equal orthographies at least 24 slots apart (actual minimum: 120).
  - [x] Count has no common factor with any offered slots-per-day (781 = 11 × 71).
  - [x] One-year simulation at every offered interval shows every word.
  - [x] First meaning at most 22 characters, balanced brackets, fits the rectangular widget on an iPhone SE.
  - [x] Human reading pass over all first meanings (Rachel, 2026-10-22). Repeat on every bundle change.
  - Each re-runs per language pack before release two.
- [x] `previousDelivery`, `timeline`, `circularLines`, `spokenLabel` (#14). Every Japanese VoiceOver part tagged `ja`.
- [x] Widget extension builds; all three families pass the `ImageRenderer` snapshots, including every circular two-line case and `語` (#12).
- [x] Host app with Word, Credits and Settings screens (#16, #19). Light and dark, default and AX5 text, SE and standard width.
- [x] Settings: commit once per edit, refusal leaves the store untouched, Done saves and swipe cancels (#18, #19).
- [x] Without the App Group, the app runs on the defaults like the widget, so tapping the widget opens the word on the Lock Screen (#24).
- [x] Minimum iOS 16.0; CI compiles against it (#24).
- [x] Unsigned IPA (#26): device build, widget inside, minimum iOS, word bundle; check proven able to fail; published only after tests pass and only for the latest main.
- [x] Public IPA link downloads without a login (HTTP 200, 337,924 bytes, sha256 5bea8682…4328, built from main 500be65). App and widget: iphoneos, arm64, minimum iOS 16.0, 781 words each (Rachel, 2026-10-22).

## Licensing

- [x] Credits screen names EDRDG (JMdict, CC-BY-SA 4.0) and open-anki-jlpt-decks / Jonathan Waller (MIT).
- [x] `tools/DATA-LICENSES.md` carries the data licence notice in the repo.
- [ ] Rachel: one-paragraph confirmation of what share-alike covers (data only vs app code). Before any public release beyond alpha.
- [ ] Code licence for the public repo: user's decision (open licence or all rights reserved).
- [ ] Noto fonts credited (OFL) when Noto Serif JP is bundled. Today the app uses the system's Hiragino.
- [ ] Release two: marketing may say "covers TOPIK I vocabulary"; data and UI use NIKL grades.

## Phone-only (cannot be proven by the team; check on the first real install)

| Check | Expected | Bound / fallback if it fails |
|---|---|---|
| App installs with a free Apple ID (Xcode or Sideloadly/AltStore) | Installs and opens | Send the exact error text |
| App Group under a free profile or after re-signing | Settings reach the widget (Xcode route only; the unsigned IPA carries no entitlements, so the sideload route will run on defaults) | Widget and app both use defaults (hourly, quiet 22:00–07:00); Settings shows a note |
| Widget refresh cadence | New word each hour, none in quiet hours | Depends on iOS refresh budget; timeline holds 24 entries |
| Settings change reaches the Lock Screen | Within a minute or two | Lock and unlock, or re-add the widget |
| Phone changes time zone | Quiet hours follow the new zone | Up to about one day on hourly, until the next timeline reload |
| Vibrant Lock Screen rendering, dimmed reading, Always-On | All three families legible | Snapshot cannot show vibrancy |
| Tap routing | Opens the app on the Lock Screen's word | — |
| Japanese VoiceOver voice | Japanese parts read in Japanese | `ja` tag is CI-tested; the voice is not |
| Chinese and Japanese character shapes on the Lock Screen (release two) | 直, 骨, 角 show the Chinese forms in a Chinese word and the Japanese forms in a Japanese word | Snapshots prove the app; the widget's font on a real Lock Screen is phone-only |
| Real iOS 16 device | Same as above | CI compiles for 16, simulator runs newer iOS |
| App icon | None yet: the app has no icon asset, so it shows a blank icon | Cosmetic, not a bug for this alpha |
| Free-profile expiry | App stops opening after 7 days | Re-install or refresh |

## Process rules

- Every change lands by pull request. No merge on red CI. Stacked PRs: never delete a base branch with dependents.
- macOS CI runs on any change except `docs/**`.

## Accepted risks

- Time zone rules are only as current as the phone's tz database. (Mira)
- Daily and 12 h cadences are not offered until the wall-clock grid and picker aliasing fix land. (Ian, Poppy)
- Word meanings are checked by people, not proven by tests; three wrong meanings were found by reading after both automated checks passed. (Rachel)
