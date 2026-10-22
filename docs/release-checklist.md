# Release checklist (MVP: Japanese, Lock Screen widget)

Owner: Rachel (QA). Nothing ships until every box is checked or explicitly
moved to "Accepted risks" with an owner.

## Gates

- [x] Scheduler core (slot, quiet hours, nextDelivery, isSatisfiable with anchor). Gated 2026-10-22 at 19 tests, mutation-checked. (Main is at 21 after the model change; those two are gated with the word data.)
- [ ] Language-neutral `Word` model and `.topik` -> `.nikl` rename. Gate with Friday's word data PR.
- [ ] Word data: 92 kana + N5 list, hand-checked multi-matches, loader tests on Linux **and** macOS. Bundle checks:
  - [ ] No orthography or reading contains a space, bracket, `;` or `～`.
  - [ ] Unique (orthography, reading). Affix-only senses (お, 人 じん, 中 じゅう) absent.
  - [ ] Equal orthographies at least 24 slots apart, measured circularly.
  - [ ] Word count (kana + N5 combined) is not a multiple of 24. Planned 789.
  - [ ] One-year simulation of the default schedule shows every word at least once.
  - [ ] Count of 5+ character words reported (11 expected); count of 9+ reported.
  - [ ] Kana carry `hiragana` / `katakana` as part of speech.
  - Each of these re-runs per language bundle before release two.
- [ ] `previousDelivery(atOrBefore:)`, `timeline`, `circularLines`, `spokenLabel` in KanaCore (lock-screen-widget-spec §7.1-7.2, §5). `spokenLabel` parts: every Japanese part tagged `ja`.
- [ ] Widget extension builds for iOS Simulator; all three families pass the `ImageRenderer` snapshot test (previews do not run in CI). Includes every circular two-line case, the `語` fallback, and the longest first meaning in the rectangular family.
- [ ] Host app builds in CI with Word screen and Credits screen (minimum to install a widget).

## Process rules (not enforced by GitHub on the free plan)

- Every change lands by pull request. No merge on red CI.
- macOS CI runs on any change to `kana-core/**`, bundled data, or the workflow. Only `docs/**` skips it.

## Licensing (must be confirmed before release)

- [ ] Rachel: read the EDRDG licence page and CC-BY-SA 4.0, write a one-paragraph confirmation here of what share-alike covers (data only vs app code).
- [ ] Credits screen names EDRDG (JMdict, CC-BY-SA 4.0) and Jonathan Waller (N5 list, via open-anki-jlpt-decks, MIT).
- [ ] Bundled data file carries its licence notice.
- [ ] Marketing may say "covers TOPIK I vocabulary". The data and the UI may not use TOPIK levels; Korean uses NIKL grades. (Release two, recorded now.)

## Known gaps (cannot be verified by the team)

- **No real-phone testing.** The user has no Apple Developer account and will load the app later. What the team can prove is Linux + macOS CI and the iOS Simulator. Nothing on a physical iPhone.
- **Phone-only widget behaviour:** real refresh cadence, Lock Screen vibrant rendering, Always-On dimming, tap routing, and how the Japanese VoiceOver voice sounds (the `ja` tag itself is CI-tested). Expect bugs on the first phone run; plan a fix window after it.
- **Install path undecided:** free personal team in Xcode (re-sign every 7 days) or the $99 account. Decide before the first widget is ready for a phone.

## Accepted risks

- Timezone rules are only as current as the phone's tz database. (Mira, accepted.)
- A daily cadence can skip a day without being flagged. Unreachable in MVP (fixed hourly cadence). Revisit before any cadence >= 12h is exposed. (Ian.)
