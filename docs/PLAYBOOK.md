# PLAYBOOK.md — simplyKANA

> **Read this first.** This is the single entry point for any agent (or human) with
> zero prior context. It tells you what the project is, where things live, how to
> build/test, what's done, what's left, and what's broken. Last updated 2026-11-07.

---

## 1. What we are building

A calm, glanceable language-learning app for iOS. One word on a schedule, on the
Lock Screen, with quiet hours. Japanese first (92 kana + 689 N5 = 781 words).
Chinese (HSK 3.0) and Korean (NIKL) packs are built but Chinese is parked and
Korean is in draft PR #44. No streaks, no guilt, one word.

Core differentiator vs. competitors (Hourly Kana): quiet editorial aesthetic,
no gamification, one surface (Lock Screen widget), deterministic drip schedule.

## 2. Where everything lives

| Path | What |
|---|---|
| `kana-core/` | Pure Swift package (scheduler, word model, timeline, settings, pack loader). Tests on Linux and macOS. No UIKit/WidgetKit. |
| `App/` | iOS app shell (SwiftUI): WordScreen, CreditsScreen, SettingsScreen, theme, fonts. |
| `Widget/` | Lock Screen widget extension (WidgetKit). Thin adapter over KanaCore. |
| `Shared/` | Code both app and widget use: Drip, fonts, settings store, lock screen views. |
| `AppTests/` | Simulator tests (snapshots, settings UI, fonts). |
| `project.yml` | XcodeGen source of truth. `.xcodeproj` is generated, not committed. |
| `tools/` | Python build scripts (packs, fonts, icons, IPA checks, publishing). |
| `packs/` | Pack source folders (`ja/`, `zh-Hans/`, `ko/`) with `pack.toml`, hand files. |
| `docs/` | Specs: design-direction, word-data-spec, lock-screen-widget-spec, pack-pipeline, settings-spec, tts-spec, release-checklist. |
| `.github/workflows/` | `ci.yml` (Linux, cheap) and `ci-macos.yml` (macOS, expensive, PR-only). |

## 3. How to build and test

### Linux (kana-core only)
```sh
cd kana-core && swift test
```
Swift toolchain at `/opt/swift/usr/bin/swift`. 75 tests on main (82 on the Korean branch PR #44).

### macOS (full build, needs Xcode 16+)
```sh
brew install xcodegen && xcodegen generate
# Then open SimplyKANA.xcodeproj in Xcode, or:
xcodebuild test -project SimplyKANA.xcodeproj -scheme SimplyKANA \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### CI
- **Linux CI** (`ci.yml`): runs on every push and PR. `swift test` in `kana-core/`. Cheap.
- **macOS CI** (`ci-macos.yml`): runs only on PRs touching allowlisted paths, or manual dispatch. Runs core tests + simulator tests + unsigned IPA build + alpha publish. Expensive (~10x minutes). Path allowlist: `kana-core/**`, `App/**`, `AppTests/**`, `Shared/**`, `Widget/**`, `packs/**`, `project.yml`, `tools/**`, `.github/workflows/ci-macos.yml`.

### Rebuild packs
```sh
python3 -I tools/build_pack.py ja      # Japanese
python3 -I tools/build_pack.py zh-Hans  # Chinese (parked)
# Korean: in progress via PR #44
```
Sources go in `/tmp/packsrc/<lang>/`. See `tools/DATA-LICENSES.md`.

## 4. Architecture (key contracts)

- **Language-neutral core.** `Language` is a struct (not enum), `Level` is `{scale, value}`. Packs are JSON files discovered at runtime. Swift never names a language.
- **Pack = one JSON file.** `ja.pack.json`, `zh-Hans.pack.json`, `ko.pack.json`. Words + manifest (fonts, voice, credits, level labels) in one file.
- **Widget slots.** 4 slots (0-3), one widget kind per slot. Pack manifests claim a slot. Adding a language = adding a file + a free slot.
- **Timeline is pure.** `timeline(after:schedule:words:calendar:limit:)` in KanaCore. WidgetKit adapter has no logic.
- **Settings in App Group UserDefaults.** Falls back to defaults without App Group (unsigned builds).
- **Quiet hours pause, don't shift.** Slots inside quiet hours are skipped. `isSatisfiable` validates configs at save time.
- **Epoch-absolute slot grid.** Slots from 2001-01-01Z. Drifts ±1h across DST (accepted risk for hourly MVP).

## 5. Current state (as of 2026-11-07)

### Done
- Japanese pack: 781 words (92 kana + 689 N5), hand-reviewed, all gates pass.
- Chinese pack: 2,207 words (HSK 1-3), built and gated, parked (not shipped) at user request.
- Korean pack: draft PR #44 (40 jamo + 1,773 grade A words). Waiting on Rachel's reading pass + Dana's font subset.
- Lock Screen widget: 3 families (rectangular, inline, circular) with kinsoku-aware splitting.
- App: Word screen, Credits screen, Settings screen. Light/dark, Dynamic Type.
- TTS spec written (milestone 3, not implemented).
- CI: Linux + macOS (PR-only after recent change).
- Unsigned IPA published to rolling alpha link.
- Pack pipeline: modular, one file per language, discovered at runtime.
- One widget per language (no shared storage, App Group not needed for widgets).

### In progress
- PR #44: Korean pack (draft, waiting on review).
- Pack pipeline refactor (steps 3-5 in `docs/pack-pipeline.md` §4b): fold build scripts, move hand files, verify equivalence.

### Not started
- TTS (milestone 3).
- Home Screen widget.
- Daily/12h cadence (needs wall-clock grid).
- Chinese/Korean shipped in alpha.
- Code licence decision (user).
- Noto font bundling in app (currently uses system Hiragino).

## 6. Known bugs and gaps

### Phone-only (cannot test without a device)
- App Group under free profile: settings may not reach widget. Fallback: both use defaults.
- Widget refresh cadence: depends on iOS refresh budget.
- Vibrant rendering, Always-On, tap routing: untested.
- Japanese VoiceOver voice quality.
- App icon: none yet (blank icon in alpha).
- Free-profile expiry: app stops after 7 days.

### Accepted risks
- Epoch grid drifts ±1h across DST (harmless for hourly MVP).
- Daily schedule can skip one day unflagged (bound allows it; accepted for MVP since daily isn't offered).
- Time zone rules only as current as phone's tz database.
- Word meanings checked by humans, not tests. 3 wrong meanings found after automated checks passed.
- Chinese heteronym readings: ~2,070 non-heteronym readings unchecked against official HSK list (no licensed text copy exists).
- Korean pack: 3 provisional count holds (오래간만, 그거, 하숙비) pending Rachel's confirmation.
- Korean romanization: NIKL lists relaxed pronunciations first; build uses vowel-from-spelling + most-spelling-faithful alternative.

### Known limitations
- No audio, example sentences, handwriting, flashcards (deferred).
- No Home Screen widget (after Lock Screen ships).
- No iCloud sync of settings.
- No per-widget configuration intents.
- Chinese pack parked (not shipped) at user request.

## 7. Todo list

### Immediate (before alpha ships to user)
- [ ] Rachel: release checklist item 7 (PR #27 was at gate, now merged). Verify all boxes.
- [ ] Rachel: reading pass on Korean pack (PR #44).
- [ ] Dana: Noto Serif KR font subset for Korean pack.
- [ ] User: code licence decision (open vs all rights reserved).
- [ ] User: first phone install test (alpha link is live).

### Milestone 2 (settings, already merged)
- [x] Settings core, storage, widget wiring.
- [x] Settings screen.
- [x] Without App Group, app uses defaults.

### Milestone 3 (TTS, not started)
- [ ] Implement `spokenWord(for:)` in KanaCore.
- [ ] Implement `Speaker` in app target.
- [ ] Add speaker glyph to Word screen.
- [ ] Chinese heteronym pronunciation table + IPA/SSML.

### Release two (Chinese + Korean)
- [ ] Ship Chinese pack (un-park, add to pack list).
- [ ] Complete Korean pack (PR #44 merge after review).
- [ ] Home Screen widget.
- [ ] Wall-clock grid for daily cadence.
- [ ] Chinese/Korean VoiceOver voices.

### Infrastructure
- [ ] Pack pipeline refactor: fold build scripts, move hand files, verify equivalence (§4b in pack-pipeline.md).
- [ ] Noto font bundling in app (currently system Hiragino).
- [ ] App icon (currently blank).

## 8. Workflow rules

1. **Every change is a PR.** No direct pushes to main.
2. **No merge on red CI.** Rachel's sign-off is a PR comment.
3. **macOS CI runs only on PRs** touching allowlisted paths (see §3). Linux CI runs on every push/PR.
4. **Nobody has a Mac or iPhone.** A thing exists when CI, a test, or a simulator snapshot proves it. Real-phone behaviour is a logged known gap.
5. **Quiet hours pause the drip, they don't shift it.** Widget never blanks, never says "paused".
6. **Orthography never truncates or wraps mid-word.** A cut Japanese word is a different word.
7. **One accent element per screen max.** Accent is never text.
8. **Affix-only senses are not words of the day.** One entry per (orthography, reading).
9. **Licence attribution is a real screen.** Credits screen names EDRDG (JMdict, CC-BY-SA 4.0), open-anki-jlpt-decks (MIT), Noto (OFL).
10. **Keep chat short.** Result first, then the one thing that needs a decision.

### How to start a session
1. Read this file.
2. `gh pr list --repo simplyjaytea/simplyKANA` to see open PRs.
3. Read the newest commit messages.
4. Work in a clean clone. Open a PR. Tell the room the result, not the process.

## 9. Key decisions (do not reopen without a reason)

- Lock Screen widget first; Home Screen after it ships.
- Epoch-absolute slot grid; wall-clock grid is precondition of daily cadence.
- `isSatisfiable` bound = 2 × interval + quiet span + 1 h, 366 days from caller-supplied anchor.
- Word model is language-neutral: `Language` struct, `Level` with scale+value.
- One entry per (orthography, reading). Affix drops per rule 8 table.
- Packs are one file per language. App discovers `*.pack.json`. No Swift names a language.
- One Lock Screen widget per language (language chosen by which widget is added).
- Minimum iOS: 16.0. CI compiles against it.
- Repo is public (Actions free).
- Repo name `simplyKANA` approved by user.
- Chinese ships simplified first. Traditional is a second orthography on the same word.
- Korean levels: NIKL grades, not TOPIK. Store as `.nikl(1...3)`, label "Beginner/Intermediate/Advanced".
- HSK version: 3.0.
- Korean romanization: Revised Romanization from NIKL's pronunciation, not spelling.
- One entry per orthography for Korean (homographs merged, lead sense first).

## 10. Owner map

| Who | Owns |
|---|---|
| Ian | Vision, every spec in docs/, product decisions, final call on scope |
| Poppy | kana-core/, widget extension, data bundle, CI workflow, pack pipeline |
| Rachel | Release gate, release-checklist.md, bundle gate, every review |
| Mira | Schedule, owners, dates, risks, macOS minutes, follow-ups |
| Dana | App shell look and feel, Home Screen widget, Lock Screen rendering with Poppy, design-direction.md with Ian |
| User (simplyjaytee) | GitHub account, Apple side (no Developer account yet), every scope decision |

## 11. Alpha finish line

Alpha = user can open project in Xcode on a Mac, run on their iPhone with free personal profile, add Lock Screen widget, see a word change on schedule. IPA is live at:
https://github.com/simplyjaytea/simplyKANA/releases/download/alpha/SimplyKANA.ipa

Remaining before alpha: release checklist verification, code licence decision, first phone install test.

## 12. Open PRs

- #44 (DRAFT): Korean pack (40 jamo + 1,773 grade A). Waiting on Rachel's reading pass + Dana's font subset.
