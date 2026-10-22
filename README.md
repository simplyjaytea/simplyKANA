# simplyKANA

A calm, glanceable language-learning widget for iOS: one word, on your schedule,
with quiet hours. Japanese first (kana → N5), Chinese and Korean as release two.

| Path | What |
|---|---|
| `kana-core/` | Pure Swift scheduler + word model. No UIKit/WidgetKit/I/O. Tests on Linux and macOS. |
| `docs/word-data-spec.md` | The contract: word model, cadence, validation, data sources, known risks. |
| `docs/hourly-kana-teardown.md` | Product teardown of the app this is inspired by. |
| `tools/join_n5.py` | Joins the N5 list to JMdict for ids, glosses, part of speech. |

CI runs `swift test` on Linux and on a macOS runner with Xcode, and builds the
core for the iOS Simulator. The widget and app shell are not here yet.

Team: Ian (creative lead), Poppy (engineering), Rachel (QA, release gate),
Mira (executive producer).
