# Release checklist (MVP: Japanese, Lock Screen widget)

Owner: Rachel (QA). Nothing ships until every box is checked or explicitly
moved to "Accepted risks" with an owner.

## Gates

- [x] Scheduler core (slot, quiet hours, nextDelivery, isSatisfiable with anchor). Gated 2026-10-22, 19 tests, mutation-checked.
- [ ] Language-neutral `Word` model and `.topik` -> `.nikl` rename. Gate with Friday's word data PR.
- [ ] Word data: 92 kana + N5 list, hand-checked multi-matches, loader tests on Linux **and** macOS.
- [ ] `timeline` in KanaCore (lock-screen-widget-spec §7.1).
- [ ] Widget extension builds for iOS Simulator; all three families render in previews (§7.2).

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
- **Phone-only widget behaviour:** real refresh cadence, Lock Screen vibrant rendering, Always-On dimming, tap routing. Expect bugs on the first phone run; plan a fix window after it.
- **Install path undecided:** free personal team in Xcode (re-sign every 7 days) or the $99 account. Decide before the first widget is ready for a phone.

## Accepted risks

- Timezone rules are only as current as the phone's tz database. (Mira, accepted.)
- A daily cadence can skip a day without being flagged. Unreachable in MVP (fixed hourly cadence). Revisit before any cadence >= 12h is exposed. (Ian.)
