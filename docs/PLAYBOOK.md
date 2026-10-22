# SimplyKANA Playbook

Last updated: 2026-10-22 by Ian. Whoever changes a rule or an owner updates this file and the copy in the repo (`docs/PLAYBOOK.md`) in the same session.

## 1. What we are building

A calm, glanceable language-learning app for iOS. One word on a schedule, on the Lock Screen, with quiet hours. Japanese first (92 kana, then JLPT N5). Chinese (HSK 3.0) and Korean (NIKL grades) are release two. No streaks, no guilt, one word.

## 2. Where everything lives

- **Repo (source of truth):** https://github.com/simplyjaytea/simplyKANA, private, on the user's GitHub account. The `gh` CLI is authenticated on this host.
- **Code:** `kana-core/` is the pure Swift package (scheduler, word model, picker, timeline). Poppy owns it.
- **Docs, read in this order:** `docs/PLAYBOOK.md` (this file), `docs/word-data-spec.md` (word model, cadence, validation, data sources), `docs/lock-screen-widget-spec.md` (families, timeline contract, circular rule, VoiceOver), `docs/design-direction.md` (type, colour tokens, screens, icon), `docs/release-checklist.md` (gates, licensing, known gaps, accepted risks).
- **Tools:** `tools/join_n5.py` joins the N5 list to JMdict.
- **CI:** GitHub Actions. Linux runs `swift test`. macOS (Xcode 16.4) runs the tests and builds for the iOS Simulator. macOS minutes are limited (about 200 a month on the free plan). Mira tracks usage.
- **Local Swift on this host:** `/opt/swift/usr/bin/swift` (6.1.2). Build in a clean copy, never inside another bot's workspace.

## 3. Who owns what

| Who | Owns | Does not |
|---|---|---|
| Ian | Vision, every spec in `docs/`, product decisions, the final call on scope | Write production code |
| Poppy | `kana-core/`, the widget extension, data bundle, CI workflow | Merge her own code without Rachel |
| Rachel | The release gate, `docs/release-checklist.md`, bundle gate, every review | Say "pass" without running it |
| Mira | Schedule, owners, dates, risks, macOS minutes, follow-ups | Invent progress |
| Dana | App shell look and feel, Home Screen widget, Lock Screen rendering with Poppy, `design-direction.md` with Ian | Edit `kana-core/` |

The user (simplyjaytee) owns the GitHub account, the Apple side (no Developer account yet, will load the app later), and every scope decision we escalate.

## 4. Rules that always apply

1. Every change is a pull request. Nobody pushes to main. GitHub cannot enforce this on the free plan, so it is discipline.
2. Nothing merges on red CI. Rachel's sign-off is a PR comment (same account cannot approve its own PR).
3. macOS CI runs on any change to `kana-core/**`, bundled data or the workflow. Only `docs/**` skips it.
4. Nobody has a Mac or an iPhone. A thing exists when CI, a test, or a simulator snapshot proves it. Real-phone behaviour is a logged known gap.
5. Quiet hours pause the drip, they do not shift it. The widget never blanks and never says "paused".
6. The orthography never truncates and never wraps mid-word. A cut Japanese word is a different word.
7. One accent element per screen at most. The accent is never text.
8. Affix-only senses are not words of the day. One entry per (orthography, reading).
9. Licence attribution is a real screen: EDRDG (JMdict, CC-BY-SA 4.0), Jonathan Waller / open-anki-jlpt-decks (N5, MIT), Noto fonts (OFL).
10. Keep chat short. Result first, then the one thing that needs a decision.

## 5. Decisions already made (do not reopen without a reason)

- Lock Screen widget first; Home Screen after it ships.
- Slot grid is epoch-absolute from 2001-01-01Z; wall-clock grid is a precondition of the config milestone.
- `isSatisfiable` bound = 2 × interval + quiet span + 1 h, walked 366 days from an `anchor` the caller supplies (the current date).
- Word model is language-neutral: `language`, `Level` enum (`.jlpt`, `.hsk`, `.nikl`).
- Bundle order: kana first, then N5; equal orthographies at least 24 slots apart; count never a multiple of 24 (planned 789).
- Circular widget: whole word or the glyph `語`. 5–8 chars on two lines with a kinsoku-aware leftward split.
- `spokenLabel(for:)` returns language-tagged parts; screens build the attributed string.
- Repo name `simplyKANA` approved by the user.

## 6. Accepted risks and known gaps

- Time zone verdicts are only as current as the phone's tz database.
- A daily cadence can skip a day unflagged. Unreachable in MVP. Precondition of config milestone, with the picker aliasing fix (interval divisors of the word count).
- No real-phone testing until the user loads the app. Refresh cadence, vibrant rendering, Always-On, tap routing, the Japanese VoiceOver voice.
- Install path undecided: free personal Xcode profile (7-day) or the $99 account.

## 7. How to start a session

1. Read this file.
2. `gh pr list --repo simplyjaytea/simplyKANA` to see what is open and whose it is.
3. Read the newest messages in the SimplyKANA room before acting; the schedule lives in Mira's tracker, not here.
4. Work in your own workspace or a clean clone. Open a PR. Tell the room the result, not the process.

## 8. Open items as of 2026-10-22

- PRs #2 (release checklist), #3 (design direction), #4 (bundle rules, kana handling): docs, awaiting Rachel's merge.
- Fri 23 Oct: Poppy's word data PR (92 kana + 697 N5, hand-reviewed, spacing sort, credits data last). Rachel gates by Mon 26 Oct with four bundle checks.
- Mon 26 Oct: Poppy starts `previousDelivery`, `timeline`, `circularLines`, `spokenLabel`, then the widget extension and the `ImageRenderer` snapshot test. Dana starts the Word screen.
- Release two (Chinese, Korean): scoped in `word-data-spec.md` §7, no date, licence checks are a start condition.
