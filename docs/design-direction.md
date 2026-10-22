# Design Direction — "calm, editorial, paper"

Owner: Ian. Date: 2026-10-22. Applies to the app shell and the Home Screen
widget. The Lock Screen widget is monochrome by platform rule and takes only
the typography and spacing from here.

The user's brief: **make it a beautiful app.** Beautiful here means quiet.
The competitor field is gamified and loud. We own the other end: one word,
set like a line of poetry on good paper, and nothing asking for anything.

---

## 1. Principles

1. **One word is the hero.** Every screen is built outward from a single
   large orthography. Nothing on screen competes with it.
2. **No guilt mechanics.** No streaks, no flames, no "you missed yesterday",
   no confetti. Progress is shown as a quiet count, never a chart.
3. **Paper, not glass.** Warm off-white surfaces, ink-dark text, one accent.
   No gradients, no glass blur, no drop shadows.
4. **Motion is a page turn.** One crossfade, 240 ms, when a word changes.
   Nothing bounces.

## 2. Type

| Role | Face | Notes |
|---|---|---|
| Orthography (ja) | Noto Serif JP, weight 500 | Display sizes 56–96 pt in the app; bundled font, licence OFL. |
| Reading / furigana | Noto Serif JP, weight 400 | 40–45% of orthography size, set above it, letter-spaced 2%. |
| Meaning, UI, labels | SF Pro (system) | Dynamic Type throughout. Never serif for English UI. |
| Chinese / Korean (release two) | Noto Serif SC / Noto Serif KR | Same roles, same weights, so the three languages feel like one family. |

Rule: the orthography never truncates and never wraps in the app. It scales
down to a floor of 40 pt; the rest of the layout yields to it.

## 3. Colour

Light and dark are both first-class. Tokens, not hex, in code.

| Token | Light | Dark | Use |
|---|---|---|---|
| `paper` | `#F6F1E7` | `#15120F` | Background. |
| `ink` | `#1B1714` | `#EDE6DA` | Orthography, body. |
| `ink.secondary` | `#6B625A` | `#A89D91` | Reading, meaning, labels. |
| `rule` | `#E2D9CA` | `#2A251F` | Hairlines, 1 px. |
| `accent` (朱, vermilion) | `#C8452A` | `#E0674A` | One element per screen at most: the level mark, a selected state, the kana tier dot. Never body text. |

Contrast: `ink` on `paper` ≥ 12:1 both modes; `ink.secondary` ≥ 4.6:1.
The accent is the only colour in the app. If a screen has two red things,
one of them is wrong.

## 4. Screens (MVP)

**Word (the only screen that matters).** Reached by tapping the widget.
Reading small above, orthography huge in the centre, first meaning below in
secondary ink, part of speech and level as a single quiet line at the bottom
(`noun · N5`). Swipe down to dismiss. Nothing else. No share button, no
favourite star, no audio icon in MVP.

**Today.** The list of words delivered so far today, newest at the top, each
row orthography + meaning. A hairline between rows. The top of the list shows
the next delivery time in secondary ink ("Next word at 14:00" or "Quiet until
07:00"). That line is the only place the schedule is visible.

**Settings.** Level (N5 only in MVP, shown anyway), quiet hours (read-only in
MVP, shows the defaults), Credits. Credits is a real screen, not a link:
EDRDG, Jonathan Waller / open-anki-jlpt-decks, Noto fonts, each with its
licence named. It is the one screen allowed to be plain.

## 5. Home Screen widget (after the Lock Screen one ships)

`systemSmall`: paper background, orthography centred in Noto Serif JP, reading
above, meaning below, accent dot for level in a corner. `systemMedium`: the
same, with room for two meanings. Same timeline, same `KanaCore.timeline`.

## 6. Icon

A single `語` in Noto Serif JP, ink on paper, no border, no gradient. Dark
variant inverts. Tinted variant uses the system tint. One glyph is the whole
brand; it is also the circular widget's "word waiting" glyph, so the icon and
the widget speak the same word.

## 7. What this does not decide

Audio, example sentences, handwriting, flashcards: deferred with the data
spec. When they arrive they obey §1. A feature that needs a badge to be
noticed does not ship.
