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

## Install the IPA without a Mac (alpha)

Every green build of `main` publishes an unsigned IPA here, always at the same link:

**https://github.com/simplyjaytea/simplyKANA/releases/download/alpha/SimplyKANA.ipa**

It isn't signed, so it can't be tapped to install. A sideloading tool signs it with
your free Apple ID and installs it over USB:

- **Windows or Mac: [Sideloadly](https://sideloadly.io).** Install iTunes and iCloud
  from Apple's website first (not the Microsoft Store versions) if you're on Windows.
  Plug in the iPhone, drop `SimplyKANA.ipa` on Sideloadly, sign in with your Apple ID, *Start*.
- **Or [AltStore](https://altstore.io)**, via AltServer on Windows or Mac. It can
  refresh the app over Wi-Fi, but AltStore itself takes one of your three app slots.

**Keep the app extensions.** The Lock Screen widget *is* an app extension. If the
tool offers to remove app extensions (Sideloadly's *Remove app extensions* option,
or AltStore's prompt when you're short of app IDs), say no. Removing them installs
the app with no widget at all. If AltStore says you're out of app IDs, wait for
old ones to expire (*My Apps → View App IDs*) rather than removing extensions.

Then, on the iPhone: turn on *Settings → Privacy & Security → Developer Mode*, trust
your Apple ID under *Settings → General → VPN & Device Management*, **open simplyKANA
once** (iOS often doesn't list a new app's widgets until it has run), and add the
widget from the Lock Screen (step 6 above).

**Limits of a free Apple ID:**

| Limit | What it means here |
|---|---|
| The app stops opening 7 days after install | Re-install with the same tool (AltStore can refresh it for you). |
| 10 new app IDs per 7 days, 3 sideloaded apps at once | simplyKANA uses **two** app IDs: the app and its widget. |
| App Groups may not survive re-signing | The app then shows that the widget uses the defaults (hourly, quiet 22:00–07:00), and the app uses them too, so they always agree. |

If it fails, send the tool's exact error text. If the app installs but simplyKANA
isn't in the Lock Screen widget list, say which tool you used and whether it
mentioned extensions.

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
