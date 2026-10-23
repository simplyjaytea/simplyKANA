# Data licences

`kana-core/Sources/KanaCore/Resources/Packs/ja.pack.json` is built by `tools/build_pack.py ja` (join: `tools/build_bundle.py`) from:

- **JMdict** (meanings, part of speech, ids, common flag). © Electronic Dictionary Research and Development Group (EDRDG). CC-BY-SA 4.0. https://www.edrdg.org/edrdg/licence.html
  The bundle is an adaptation of JMdict and is distributed under CC-BY-SA 4.0.
- **JLPT N5 list** (`tools/n5.csv`, which words are N5). open-anki-jlpt-decks, © 2020 Jamie Sinclair, MIT. Based on Jonathan Waller's JLPT lists (tanos.co.uk).

Rebuild: download `http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz`, gunzip, then
put `JMdict_e` in `/tmp/packsrc/ja/`, then `python3 -I tools/build_pack.py ja`

## Chinese bundle

`kana-core/Sources/KanaCore/Resources/Packs/zh-Hans.pack.json` is built by `tools/build_pack.py zh-Hans` (join: `tools/build_zh.py`):

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
put `complete.json` and `cedict_ts.u8` in `/tmp/packsrc/zh-Hans/`, then `python3 -I tools/build_pack.py zh-Hans`

## Korean pack

`kana-core/Sources/KanaCore/Resources/Packs/ko.pack.json` is built by `tools/build_pack.py ko`
(join: `tools/build_ko.py`, readings: `tools/ko_romanize.py`) from:

- **Basic Korean Dictionary (한국어기초사전)**, National Institute of Korean Language (국립국어원):
  words, learner level (초급 = grade A), pronunciation, English meanings.
  Licence **CC BY-SA 2.0 KR**, per https://krdict.korean.go.kr/kor/kboardPolicy/copyRightTermsInfo
  ("everything not otherwise marked"). The English translations aren't named on that page; using
  them under it is a recorded inference (word-data-spec, PR #42). The pack keeps this licence; it
  is not relabelled 4.0. Data: the 2019 snapshot at github.com/spellcheck-ko/korean-dict-nikl-krdict.
- **Written by hand** (Poppy, reviewed by Rachel): `packs/ko/overrides.tsv`, `readings.tsv`, `drops.txt`.

Rebuild: put the snapshot's `*.xml` in `/tmp/packsrc/ko/`, then `python3 -I tools/build_pack.py ko`.

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
