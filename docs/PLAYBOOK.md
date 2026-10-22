# SimplyKANA Playbook

Last updated: 2026-10-22 (late) by Ian. Whoever changes a rule or an owner updates this file and the copy in the repo (`docs/PLAYBOOK.md`) in the same session.

## 1. What we are building

A calm, glanceable language-learning app for iOS. One word on a schedule, on the Lock Screen, with quiet hours. Japanese first (92 kana, then JLPT N5). Chinese (HSK 3.0) and Korean (NIKL grades) are release two. No streaks, no guilt, one word.

## 2. Where everything lives

- **Repo (source of truth):** https://github.com/simplyjaytea/simplyKANA, **public** since 2026-10-22 (user's decision, so Actions is free and unlimited), on the user's GitHub account. The `gh` CLI is authenticated on this host. Nothing secret goes in the repo, ever: no tokens, no personal data, no licensed dictionary dumps.
- **Code:** `kana-core/` is the pure Swift package (scheduler, word model, picker, timeline). Poppy owns it.
- **Docs, read in this order:** `docs/PLAYBOOK.md` (this file), `docs/word-data-spec.md` (word model, cadence, validation, data sources), `docs/lock-screen-widget-spec.md` (families, timeline contract, circular rule, VoiceOver), `docs/design-direction.md` (type, colour tokens, screens, icon), `docs/release-checklist.md` (gates, licensing, known gaps, accepted risks).
- **Tools:** `tools/join_n5.py` joins the N5 list to JMdict.
- **CI:** GitHub Actions. Linux runs `swift test`. macOS (Xcode 16.4) runs the tests and builds for the iOS Simulator. Public repo, so minutes are free; keep macOS jobs purposeful anyway (queue times).
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
9. Licence attribution is a real screen: EDRDG (JMdict, CC-BY-SA 4.0), Jonathan Waller / open-anki-jlpt-decks (N5, MIT), Noto fonts (OFL). The repo is public, so the bundled data file ships with its licence notice in the repo too, the day it lands.
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

## 8. Alpha: the finish line (user, 2026-10-22: "keep working until it's ready for alpha test")

Alpha means the user can open the project in Xcode on a Mac, run it on their
own iPhone with a free personal profile, add the Lock Screen widget, and see a
word change on schedule. Checklist, all proven in CI or simulator before the
user is asked to try:

1. Lock Screen widget, three families, real bundle, 781 words. **Done, on main.**
2. Word screen and Credits screen in the app. Dana, PR in progress.
3. Rule 8 drops, 22-character first-meaning cap, 枚 fixed. Poppy, PR #15 at the gate.
4. One human reading pass over all 781 first meanings by someone other than Poppy. Rachel. Before the first phone run.
5. Settings: interval, quiet hours, pack and level rows, App Group storage, one-commit-per-edit, `isSatisfiable` refusal. Poppy then Dana, from `docs/settings-spec.md`. Phone-only: whether the widget reads the App Group under a free profile.
6. Polish pass on the widget renders and the app screens. Dana.
7. Release checklist: every simulator-provable box checked, every phone-only line listed with its bound. Rachel.
8. A `README` section the user can follow: clone, `xcodegen`, open, select team, run on device. Poppy.

Not alpha: Home Screen widget, Chinese and Korean packs, daily cadence, notifications, audio, sync.

## 9. Open items as of 2026-10-22 (evening, one list, from Mira's tracker)

| Item | Owner | Next |
|---|---|---|
| PR #15 gate (781 words, 22-char cap) | Rachel | next in queue |
| Word and Credits screens, then polish pass | Dana | PR now; skeleton is on main |
| Rule 8 table corrections (日 にち stays, 年 ねん drops) | Ian → Poppy | in PR #11; two-line change to #15 |
| Settings spec #13 (swap-on-change, commit-once) | Ian | fixed; Rachel merges |
| Settings build | Poppy, then Dana | after #15 and the first Word screen are green |
| Meanings reading pass (781) | Rachel | before first phone run |
| App Group under free profile | Poppy | check before "settings work" is said |
| Time zone change on device | phone-only, bound ≈ one day on hourly | logged |
| Code licence (open or all rights reserved) | user | this week |
