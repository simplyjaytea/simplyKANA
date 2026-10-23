# SimplyKANA Playbook

Last updated: 2026-10-22 (late) by Ian. Whoever changes a rule or an owner updates this file and the copy in the repo (`docs/PLAYBOOK.md`) in the same session.

## 1. What we are building

A calm, glanceable language-learning app for iOS. One word on a schedule, on the Lock Screen, with quiet hours. Japanese first (92 kana, then JLPT N5). Chinese (HSK 3.0) and Korean (NIKL grades) are release two. No streaks, no guilt, one word.

## 2. Where everything lives

- **Repo (source of truth):** https://github.com/simplyjaytea/simplyKANA, **public** since 2026-10-22 (user's decision, so Actions is free and unlimited), on the user's GitHub account. The `gh` CLI is authenticated on this host. Nothing secret goes in the repo, ever: no tokens, no personal data, no licensed dictionary dumps.
- **Code:** `kana-core/` is the pure Swift package (scheduler, word model, picker, timeline). Poppy owns it.
- **Docs, in order:** `docs/PLAYBOOK.md`, `word-data-spec.md`, `lock-screen-widget-spec.md`, `design-direction.md`, `settings-spec.md`, `release-checklist.md`.
- **Tools:** `tools/join_n5.py` joins the N5 list to JMdict.
- **CI:** GitHub Actions. Linux runs `swift test`. macOS (Xcode 16.4) runs the tests and builds for the iOS Simulator. Public repo, so minutes are free; keep macOS jobs purposeful anyway (queue times).
- **Local Swift:** `/opt/swift/usr/bin/swift`. Build in a clean copy, never in another bot's workspace.

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
- Epoch-absolute slot grid; wall-clock grid is a precondition of daily cadence.
- `isSatisfiable` bound = 2 × interval + quiet span + 1 h, 366 days from a caller-supplied `anchor`.
- Word model is language-neutral: `language`, `Level` enum (`.jlpt`, `.hsk`, `.nikl`).
- Bundle: kana then N5, 781 words; equal orthographies ≥ 24 slots apart; count coprime with every offered slots-per-day.
- Circular widget: whole word or `語`; 5–8 chars on two lines, kinsoku-aware leftward split.
- `spokenLabel(for:)` returns language-tagged parts; screens build the attributed string.
- Repo name `simplyKANA` approved by the user.
- **Packs are one file per language** (user, 2026-10-23): `<lang>.pack.json` with words, manifest (fonts, voice, labels, widget slot) and licences; the app swaps by the Language preference; Swift names no language. Spec: `docs/pack-pipeline.md`. New language = one config + hand-judgement data files + Rachel's read.
- **One Lock Screen widget per language** (2026-10-22, user approved): language is chosen by which widget is added; no shared storage; Settings' Language row is app-only.
- **Minimum iOS: 16.0** (user, 2026-10-22). Lock Screen widgets need 16; nothing we use needs 17 except `containerBackground(for: .widget)`, which is shimmed with `#available`. CI compiles at the 16.0 target.

## 6. Accepted risks and known gaps

- Time zone verdicts are only as current as the phone's tz database.
- Daily and 12 h cadences wait on the wall-clock grid and the picker aliasing fix.
- Phone-only until the user installs: refresh cadence, vibrant rendering, Always-On, tap routing, Japanese VoiceOver voice, App Group under a free profile, time zone change (bound ≈ one day).
- Install path undecided: free personal Xcode profile (7-day) or the $99 account.

## 7. How to start a session

1. Read this file.
2. `gh pr list --repo simplyjaytea/simplyKANA` to see what is open and whose it is.
3. Read the newest room messages; the schedule is Mira's tracker, not this file.
4. Work in a clean clone. Open a PR. Tell the room the result, not the process.

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

## 9. Open items as of 2026-10-22 (night; alpha handed to the user)

On main: iOS 16 minimum, Settings screen, defaults fallback without App Group,
unsigned IPA published by CI to one rolling link:
https://github.com/simplyjaytea/simplyKANA/releases/download/alpha/SimplyKANA.ipa
Alpha items 1–6, 8, 9 done. Item 7 (checklist, PR #27) at the gate.

| Item | Owner | Next |
|---|---|---|
| Release checklist #27: close the two IPA boxes, merge | Rachel | now |
| User's bug report from the first phone run | user → Mira triages | after install |
| Settings-in-widget fallback (press and hold): build only if the user reports the App Group error | Poppy | on report |
| Code licence (open or all rights reserved) | user | this week |
| Home Screen widget, daily cadence, Chinese/Korean packs | after alpha feedback | no date |

Process notes: never delete a branch another PR is stacked on (cost us #9 and #25). The publish step runs only on main; a dry run of `tools/publish_alpha.sh` against a throwaway tag is how to test it.
