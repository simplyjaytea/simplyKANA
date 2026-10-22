# simplyKANA

A calm, glanceable language-learning widget for iOS: one word, on your schedule,
with quiet hours. Japanese first (92 kana, then JLPT N5), Chinese and Korean later.

## Run it on your iPhone (alpha)

You need a Mac with Xcode 16 or newer, an iPhone on iOS 16 or newer, a USB cable,
and an Apple ID. A free Apple ID works; the paid developer account is not needed
for this.

1. **Get the code and the generator.**
   ```sh
   git clone https://github.com/simplyjaytea/simplyKANA.git
   cd simplyKANA
   brew install xcodegen        # needs Homebrew: https://brew.sh
   xcodegen generate
   open SimplyKANA.xcodeproj
   ```
2. **Sign in.** Xcode → Settings → Accounts → **+** → Apple ID.
3. **Pick your team, twice.** In the left sidebar click the blue **SimplyKANA**
   project, then:
   - target **SimplyKANA** → *Signing & Capabilities* → *Team*: your name (Personal Team);
   - target **SimplyKANAWidget** → same tab → same team.
4. **Plug in the iPhone**, unlock it, tap *Trust*. On the iPhone turn on
   *Settings → Privacy & Security → Developer Mode* (it restarts).
5. In Xcode's toolbar choose your iPhone as the run destination and press **▶︎ Run**.
   The first time, the iPhone says the developer isn't trusted: open
   *Settings → General → VPN & Device Management*, tap your Apple ID, *Trust*.
   Press ▶︎ again.
6. **Add the widget.** Lock the phone, long-press the Lock Screen → *Customize* →
   *Lock Screen* → tap the widget area → find **simplyKANA** → pick a size → *Done*.
   A new word arrives every hour outside quiet hours (22:00–07:00).

### If something goes wrong

| Xcode says | Do this |
|---|---|
| "…bundle identifier is not available" | In `project.yml` change `BUNDLE_ID_BASE` to something of your own (e.g. `com.yourname.simplyKANA`), run `xcodegen generate` again, redo step 3. |
| An error mentioning **App Groups** | Your team can't use App Groups. On both targets, *Signing & Capabilities* → App Groups → **–** to remove it, then Run. The app and widget still work; the widget then ignores the Settings screen and uses the defaults. Tell Poppy, it decides how settings ship. |
| "Developer Mode disabled" | Step 4. |
| Nothing after 7 days | Free-profile apps expire after 7 days. Plug in and press ▶︎ again. |

Every time `project.yml` changes (after `git pull`), run `xcodegen generate` again.

## What's where

| Path | What |
|---|---|
| `kana-core/` | Pure Swift: scheduler, word model, timeline, settings, word bundle. Tests on Linux and macOS. |
| `App/`, `Widget/`, `Shared/`, `AppTests/` | The iOS app, the Lock Screen widget, code both use, and simulator tests. |
| `project.yml` | XcodeGen project; the `.xcodeproj` is generated, not committed. |
| `tools/build_bundle.py` | Builds the Japanese bundle from JMdict and the N5 list. Licences in `tools/DATA-LICENSES.md`. |
| `docs/` | Specs, the release checklist and the team playbook. |

CI runs the core tests on Linux and macOS, and builds and tests the app and
widget on the iOS Simulator, uploading widget snapshots as an artifact.

Word data: JMdict © EDRDG, CC-BY-SA 4.0; N5 list from open-anki-jlpt-decks
(MIT, based on Jonathan Waller's lists).
