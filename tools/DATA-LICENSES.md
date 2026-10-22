# Data licences

`kana-core/Sources/KanaCore/Resources/words-ja.json` is built by `tools/build_bundle.py` from:

- **JMdict** (meanings, part of speech, ids, common flag). © Electronic Dictionary Research and Development Group (EDRDG). CC-BY-SA 4.0. https://www.edrdg.org/edrdg/licence.html
  The bundle is an adaptation of JMdict and is distributed under CC-BY-SA 4.0.
- **JLPT N5 list** (`tools/n5.csv`, which words are N5). open-anki-jlpt-decks, © 2020 Jamie Sinclair, MIT. Based on Jonathan Waller's JLPT lists (tanos.co.uk).

Rebuild: download `http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz`, gunzip, then
`python3 -I tools/build_bundle.py JMdict_e tools/n5.csv kana-core/Sources/KanaCore/Resources/words-ja.json --report`
