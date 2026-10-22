# Text to speech — hear the word (milestone 3)

Owner: Ian. Implementer: Poppy (core + audio), Dana (control). QA: Rachel.
Requested by the user 2026-10-22. Minimum iOS stays 16.

The point is one tap, one word, spoken once, clearly, and then silence. No
autoplay, no audio icon shouting from the Lock Screen, nothing that pauses the
user's music.

---

## 1. Decisions

- **Engine: the system synthesizer (`AVSpeechSynthesizer`).** On device,
  offline, free, no licence, iOS 16, with voices for ja-JP, zh-CN and ko-KR.
  No bundled audio clips: size, licensing and recording three languages are
  not alpha problems. Revisit only if the system voices prove unusable on a
  phone.
- **Where: the Word screen only.** Widgets cannot play audio. The Today list
  does not speak; one place, one gesture.
- **What is spoken, per language.** This is the rule that keeps TTS from
  teaching a wrong word:

  | Language | Spoken text | Why |
  |---|---|---|
  | Japanese | `reading` (kana) | Speaking kanji lets the synthesizer guess the reading; 生 has a dozen. The kana is the word. Kana-only entries speak themselves. |
  | Chinese | `orthography` (hanzi), **with the pronunciation fixed for every heteronym** | The synthesizer guesses readings from context and a lone word has none. For the 141 hand-picked words the utterance carries the chosen reading explicitly (§2), so the voice cannot say háng over "to walk". A heteronym with no table entry does not get a speaker at all. |
  | Korean | `orthography` (hangul) | Hangul is phonetic. |

- **Voice and rate.** `AVSpeechSynthesisVoice(language:)` for the pack's
  language. If no voice for that language is installed, the control is
  **hidden**, not disabled: an app that cannot speak does not show a mouth.
  Rate 0.45 (slower than default, for learners). A second tap within two
  seconds speaks again at 0.35. No pitch or volume changes.
- **Audio session: playback, mixing with others (decided 2026-10-22, Rachel's
  point).** The user tapped to hear a word, so it plays even with the silent
  switch on; most phones live on silent and a silent tap reads as broken.
  Music keeps playing underneath. The app never takes the audio focus and
  never plays unasked, which is what the silent switch is really protecting.
- **No autoplay.** A "Speak word on open" toggle is **not** in this
  milestone. The product is quiet by default; the user asks, the app answers.

## 2. Core (Poppy)

```swift
struct SpokenWord: Equatable { let text: String; let language: String; let rate: Float }

// Pure. Chooses the text per §1 and the BCP-47 language for the voice.
// Returns nil for the fallback word.
func spokenWord(for word: Word, slow: Bool = false) -> SpokenWord?
```

- Language codes: `ja-JP`, `zh-CN`, `ko-KR`. Chinese is `zh-CN` because the
  pack is simplified; a traditional pack would be `zh-TW`.
- **Heteronym pronunciation (Chinese).** `SpokenWord` gains
  `pronunciation: String?`. For words in the hand-picked (word, reading,
  gloss) table from the word-data spec, the core supplies the reading as a
  pronunciation hint and `Speaker` builds the utterance with it: an
  attributed string carrying `AVSpeechSynthesisIPANotationAttribute` (iOS 10+)
  derived from the pinyin, or the iOS 16 SSML form, whichever Rachel's phone
  sample proves the voices honour. The pinyin-to-IPA table is pure and tested
  on Linux. If a heteronym has no table entry, `spokenWord` returns nil and
  the speaker is hidden for that word; the build check already fails on such
  a word, so this is belt and braces.
- `Speaker`, in the app target, wraps the synthesizer: configures the
  session once, cancels any in-progress utterance before speaking a new one,
  and exposes `isAvailable(for language:)` by checking installed voices.

## 3. Control (Dana)

- On the Word screen, a single speaker glyph in secondary ink beneath the
  bottom line (`noun · N5`), 44 pt tap target. Not the accent; the level dot
  keeps that. Tapping the word itself also speaks it, so the glyph is a hint,
  not the only path.
- While speaking, the glyph goes to `ink` and returns to secondary when done.
  No waveform, no animation.
- VoiceOver: label "Speak", hint "Speaks the word aloud". When VoiceOver is
  running, the glyph remains, and speaking still uses the synthesizer.
- Hidden entirely when `isAvailable` is false.

## 4. Gates (Rachel)

1. Linux: `spokenWord(for:)` picks the reading for Japanese, the orthography
   for Chinese and Korean, the right language code per pack, nil for the
   fallback word, rate 0.45 normal and 0.35 slow.
2. Simulator: the glyph is present when a voice exists and absent when
   `isAvailable` is false (inject a fake voice list). Tapping the word calls
   the speaker once; a second tap within two seconds calls it with `slow`.
3. Simulator: the audio session is playback and mixes with others.
3b. Linux: every one of the 141 heteronyms yields a non-nil pronunciation
   from the table, and a synthetic heteronym with no entry yields nil.
4. Phone-only, logged with a bound: whether the Japanese voice reads kana
   naturally; whether the Chinese voice reads the 141 heteronyms with the
   reading in the hand-picked table (Rachel samples ten); whether the enhanced
   voice is used when the user has downloaded one; silent switch behaviour.

## 5. Known risks

- **Chinese heteronyms.** Handled in §2 with explicit pronunciation from the
  hand-picked table. Residual risk: whether Apple's zh-CN voices honour the
  IPA attribute or SSML for every syllable is phone-only. Rachel samples
  all four words with a vulgar reading plus six others; if any misreads, the
  speaker is hidden for the 141 until a method that works is found.
- **Default voices are mediocre.** Apple's compact voices sound robotic. The
  Credits/Settings screen may tell the user how to download an enhanced voice
  in iOS Settings, in one sentence, no link bait.

## 6. Not in this milestone

Bundled native recordings, autoplay on open, speaking from the widget or the
Today list, speed slider, pitch accent display.
