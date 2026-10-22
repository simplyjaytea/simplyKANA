# Hourly Kana — Product Teardown & Rebuild Spec

Target: **Hourly Kana: Learn Japanese** · Radish Retail, LLC · bundle `com.radish.kana`
Current: v3.4.4 (Oct 2026) · iOS 17+ · iPhone/iPad/Apple Watch/Mac (Apple Silicon)/visionOS · ~500 MB

Reverse-engineering status: binary-level RE is **blocked** (see "The honest blocker").
This document is the part that actually matters for building an inspired app:
a complete feature map + inferred technical architecture, from public listings,
screenshots, and the competitor landscape. Observed vs. inferred is labeled throughout.

---

## 1. The honest blocker (read first)

Hourly Kana is a native Swift app distributed as a FairPlay-DRM-encrypted IPA from the
App Store. To disassemble its Mach-O I would need a **decrypted IPA** (only obtainable
from a jailbroken device or the developer's own build) plus a native engine
(Hopper/Ghidra/IDA). This host is Linux with **no IPA, no Mac, no engine configured**
(`rea doctor` reports ghidra/ida/jadx/kuna all missing).

So: no binary RE of Hourly Kana today, and no legal/authorized path to it either.
Everything below is product-level teardown — which is exactly what "build an app
*inspired by* it" requires. If you later hand me a decrypted IPA (or any binary you
own), the REA skill is now installed and we can go byte-level.

---

## 2. Feature map (observed, from App Store listing)

**Core loop — "a new word, throughout your day"**
- Lock Screen + Home Screen widget that surfaces a fresh word on a schedule.
- Scheduled word reminders (notifications) on a user cadence, with **quiet hours**.
- Tap a word → reading (kana), meaning, example sentences, native Japanese audio.

**Learning content**
- Foundations: hiragana + katakana, with listening drills and tap-to-build character exercises.
- JLPT N5–N1 vocabulary; placement test or manual level selection.
- Two reading modes: **Kana First** vs **Kanji First** (progressive furigana suppression).

**Retention**
- Personal "difficult words" flashcards + short quizzes.
- Handwriting, reading, and listening practice.
- Grammar via example sentences + answer explanations.
- Anki plain-text export import + custom decks.
- Collection, learning history, and progress tracking.

**Delivery/platform**
- Offline access; private iCloud sync; no ads; 11 interface languages; Apple Watch app.

**Monetization (observed IAPs)**
- 7-day free trial, then paid. Price points: $4.99/mo, $6.99, $7.99, $34.99, $69.99
  (monthly / one-time / lifetime tiers). Subscriptions via StoreKit.

**Competitors (same niche, useful design data)**
- Kioku — passive lock-screen word, "no streaks", Noto Serif JP typography, $1.99/mo.
- VocabPin — CEFR/JLPT levels, furigana toggle, pitch-accent, native audio.
- Gojuon — kana alphabet widget grid (hiragana/katakana, dakuten), $1.99.

---

## 3. Inferred technical architecture (design-level, not decompiled)

| Concern | Likely stack (iOS 17+) |
|---|---|
| UI | SwiftUI, iOS 17+ (supports new Lock Screen / widget APIs) |
| Widgets | WidgetKit — `AppIntentConfiguration` for configurable widgets; `TimelineProvider` drives hourly word cadence; `accessoryRectangular`/`accessoryCircular`/`accessoryInline` for Lock Screen, `systemSmall/Medium` for Home Screen |
| Scheduling | Widget timeline entries + `UNUserNotificationCenter` scheduled reminders; quiet-hours = time-window filter on the schedule |
| Persistence & sync | Core Data via `NSPersistentCloudKitContainer` (private iCloud sync, offline-first) |
| Audio | `AVSpeechSynthesizer` (native Japanese TTS) and/or bundled clips — the ~500 MB size hints at bundled content |
| Content DB | Bundled JLPT N5–N1 word data (competitor Kioku credits JMdict/EDRDG, CC-BY-SA) |
| Payments | StoreKit 2 subscriptions + non-consumable lifetime IAP, 7-day trial |
| Handwriting | `PencilKit` or custom stroke recognition for kana |
| Anki import | parse Anki plain-text export (tab/`;`-delimited) into decks |

**The one feature that defines the app** — and the thing to get right — is the
**scheduled, glanceable word surface**: a WidgetKit timeline that drip-feeds words
through the day while respecting quiet hours, backed by a deck engine that knows
what the user has seen, what's due (SRS-lite), and their level. Everything else
(foundations, flashcards, audio) is table-stakes around that loop.

---

## 4. Rebuild spec — "iOS-first, inspired by Hourly Kana"

Goal in one line: an iOS-first app that teaches Japanese by drip-feeding kana→kanji→JLPT
vocabulary through Lock Screen / Home Screen widgets on a user cadence with quiet hours.

**Next 3 steps (proposed owners/dates pending the room's sign-off):**
1. **Deck + scheduler core** (Poppy) — word data model (kana/kanji/reading/meaning/example/audio),
   JLPT leveling, seen-due state, quiet-hours-aware next-word selection. Pure Swift package, unit-tested.
2. **WidgetKit surface** (Poppy) — Lock Screen (rectangular/circular) + Home Screen widget,
   `TimelineProvider` feeding scheduled entries; settings via App Intents.
3. **App shell + word detail** (Ian/Poppy) — SwiftUI list/detail, audio, trial paywall (StoreKit 2),
   iCloud sync via CloudKit.

**Design direction (the vision):** calm, editorial, Japanese-paper typography (Noto Serif JP /
Hiragino), a warm accent color, no streaks, no guilt — "learning happens in the background of
your life." Differentiate from Hourly Kana by owning the *quiet* aesthetic and doing one thing
(scheduled glanceable words) exceptionally, rather than bolting on a full course marketplace.

**Open questions for the user:**
- Scope: widget-first MVP (Kioku-style, ~37 MB) vs full foundations+flashcards (Hourly Kana-scale)?
- Content licensing: use JMdict/EDRDG (CC-BY-SA, attribution required) for the word DB?
- Do you have an Apple Developer account + a Mac for building/signing the IPA?
