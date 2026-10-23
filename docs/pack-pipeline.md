# Language packs — one pipeline, drop-in packs

Owner: Ian. Implementer: Poppy. QA: Rachel. Date: 2026-10-23.
The user's rule: "download the vocab and place it. No need to manually do
everything. This way it's modular for other languages."

Adding a language must never mean writing a new build. It means: one config
file that names the sources, and at most three small data files that record
human judgement. Everything else is the same code for every language.

---

## 1. What a pack is

A pack is a folder, `packs/<lang>/`, that the generic build turns into the
`words-<lang>.json` the app and widget load. The app discovers packs by
listing the bundle; nothing in Swift names a language except the font table
and the voice code.

```
packs/zh/
  pack.toml          # the only required file
  readings.tsv       # optional: word, reading, gloss for heteronyms (hand judgement)
  overrides.tsv      # optional: word, reading, first meaning (hand judgement)
  drops.txt          # optional: entries dropped under rule 8, one per line with a reason
  NOTICE             # licence text for the pack's sources (required if any source needs attribution)
```

`pack.toml` names the language code, the level scale, the sources with their
URLs and licences, and the rules to apply. Example:

```toml
language = "zh-Hans"
level_scale = "hsk"
font = "NotoSerifSC"
voice = "zh-CN"

[[source]]            # which words, and their level
kind = "list"
url = "https://…/hsk30.csv"
licence = "MIT"
fields = { word = "simplified", level = "level" }

[[source]]            # what they mean and how they are read
kind = "dictionary"
url = "https://…/cedict_ts.u8"
licence = "CC-BY-SA-4.0"
format = "cedict"

[rules]
affix_drop = true          # rule 8, generic
first_meaning_max = 22     # rectangular widget cap
strip_parenthetical = true # "(esp. the domestic cat…)" → gone from meanings[0]
measure_word_leads = true  # a measure word's first meaning starts "measure word:"
no_digits_in_reading = true
```

## 2. What the pipeline does, for every language, without edits

`tools/build_pack.py <lang>` reads `pack.toml` and:

1. Downloads the sources into a cache (never committed), verifying a hash
   recorded in `pack.toml` so a changed upstream file is noticed, not silently
   absorbed.
2. Joins the word list to the dictionary on (word, reading) with the
   language's normaliser (kana folding for ja, simplified for zh, none for ko).
3. Applies `drops.txt`, then `readings.tsv`, then `overrides.tsv`, in that
   order, so a human decision always beats the automatic one.
4. Runs every gate that exists today as code, not as memory: unique
   (orthography, reading); no spaces, brackets, `;`, `～`; first-meaning cap;
   no digits in readings; measure-word rule; count not aliasing any offered
   interval; one-year simulation shows every word; 24-slot spacing for equal
   orthographies; every character present in the pack's font subset.
5. Writes `words-<lang>.json` plus a `manifest.json` with counts, source
   hashes, and the licence list the Credits screen renders.

The three hand files are **data**, reviewed like data, and are the whole of
what "manual" means. For Japanese they are 15 overrides and 12 drops. For
Chinese they are 152 readings, about 270 overrides and 2 drops. That is the
cost of free dictionaries listing a character's oldest sense first; no
pipeline removes it, it can only keep it small and honest.

## 3. What stays human, and why

- **Rachel's reading pass.** Sixty of 2,209 automatic Chinese first meanings
  taught the wrong word (后 "empress", 奶 "breast"). No rule we can write
  catches "the dictionary's first sense is archaic". A new pack gets one
  full read, then samples. This is the product's failure mode, so it is the
  one thing we do not automate away.
- **Heteronym readings** where the licensed sources do not say which reading
  the level list means.
- **Affix drops** beyond what the generic rule can detect from part of speech.

Everything else that was done by hand for Japanese and Chinese is now a
rule in §1 or a gate in §2, and Korean inherits all of it.

## 4. Drop-in later: downloadable packs

The format above is already what a downloaded pack would be. When a pack
can be fetched at runtime (not alpha), the app verifies the manifest's
signature and hash, places the folder, and reloads. Nothing in the loader
changes; only where the folder comes from. Not built now; the format is
designed so it never needs a rewrite.

## 5. Gates for the pipeline itself (Rachel)

- Building Japanese and Chinese from their `pack.toml` reproduces today's
  bundles byte for byte.
- A new `packs/xx/pack.toml` with sources and no hand files builds and
  passes every gate or fails with a named rule, never with a stack trace.
- Removing one override line changes exactly one word in the output.
