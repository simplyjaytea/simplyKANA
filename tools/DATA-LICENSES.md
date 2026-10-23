# Data licences

`kana-core/Sources/KanaCore/Resources/words-ja.json` is built by `tools/build_bundle.py` from:

- **JMdict** (meanings, part of speech, ids, common flag). © Electronic Dictionary Research and Development Group (EDRDG). CC-BY-SA 4.0. https://www.edrdg.org/edrdg/licence.html
  The bundle is an adaptation of JMdict and is distributed under CC-BY-SA 4.0.
- **JLPT N5 list** (`tools/n5.csv`, which words are N5). open-anki-jlpt-decks, © 2020 Jamie Sinclair, MIT. Based on Jonathan Waller's JLPT lists (tanos.co.uk).

Rebuild: download `http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz`, gunzip, then
`python3 -I tools/build_bundle.py JMdict_e tools/n5.csv kana-core/Sources/KanaCore/Resources/words-ja.json --report`

## Chinese bundle

`kana-core/Sources/KanaCore/Resources/words-zh.json` is built by `tools/build_zh.py`:

- **Which words, and their HSK band**: complete-hsk-vocabulary (MIT), levels `new-1`..`new-3`
  (HSK 3.0, GF 0025-2021), from elkmovie/hsk30 (MIT). Only the word list is used; the
  packager's pinyin and glosses are not, because 8 of its glosses come from an unnamed source.
- **Pinyin and meanings**: CC-CEDICT (MDBG, CC-BY-SA 4.0), read directly from
  `cedict_ts.u8`. The bundle is an adaptation and is distributed under CC-BY-SA 4.0.
- **Written by hand** (Poppy, reviewed by Rachel): `tools/zh_heteronyms.tsv`,
  `tools/zh_meanings.tsv`, `tools/zh_manual.tsv` (8 HSK words CC-CEDICT lacks),
  `tools/zh_measure_words.txt`.

Rebuild: download `https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip`
and complete-hsk-vocabulary's `complete.json`, then
`python3 -I tools/build_zh.py complete.json cedict_ts.u8 kana-core/Sources/KanaCore/Resources/words-zh.json`

## Release two: licence checks (Poppy, 2026-10-22)

Checked before any Chinese or Korean data is bundled (start condition, word-data-spec §7).

| Source | Used for | Licence | Verdict |
|---|---|---|---|
| **CC-CEDICT** (MDBG) | Chinese pinyin and English glosses | CC-BY-SA 4.0, stated on mdbg.net | **OK.** Same terms as JMdict: credit, bundle file under CC-BY-SA. |
| **HSK 3.0 list**, drkameleon/complete-hsk-vocabulary | which words are HSK 1–3 | MIT (repo). Built from elkmovie/hsk30 (MIT), an OCR of the Ministry of Education's published standard (GF 0025-2021) | **OK, with a note.** MIT covers the extraction; the level list itself is a published government standard. Take level membership only; glosses come from CC-CEDICT. Don't use its frequency data: that comes from krmanik/HSK-3.0-words-list, which has no clear licence. |
| **NIKL 한국어 학습용 어휘 목록** (2003, 5,965 words, grades 1–3) | which Korean words, and their grade | KOGL Type 1 (공공누리 제1유형): free use incl. commercial and modification, with source credited | **OK.** Credit "국립국어원 (National Institute of Korean Language)". It has **no English glosses**. |
| **kengdic** (garfieldnate/kengdic) | Korean → English glosses | Dual MPL 2.0 / LGPL 2.0+ (README; no LICENSE file in the repo) | **OK under MPL 2.0.** MPL is per file: the bundled Korean file must stay available under MPL with its notice. Our repo is public, so that's met. Credit kengdic. |

Open points, none blocking:
- The Korean bundle mixes KOGL (word list) and MPL (glosses); the credits screen lists both.
- kengdic glosses are sparse for some entries; expect more hand fixes per word than JMdict needed.
