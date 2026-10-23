"""Build the Chinese bundle: HSK 3.0 (GF 0025-2021) bands 1-3, simplified.

usage: python3 -I tools/build_zh.py complete.json cedict_ts.u8 kana-core/Sources/KanaCore/Resources/words-zh.json

Sources (credits screen; see tools/DATA-LICENSES.md):
  - Which words, and their band: complete-hsk-vocabulary (MIT), levels new-1..new-3.
    Only the word list is used from it; its pinyin and glosses are not.
  - Pinyin and meanings: CC-CEDICT (MDBG, CC-BY-SA 4.0), read directly from the file.
  - Hand tables in tools/: zh_heteronyms.tsv (words with more than one reading),
    zh_meanings.tsv (first meanings rewritten for learners), zh_manual.tsv (HSK words
    CC-CEDICT doesn't have, written by hand).

Rules the build enforces (it exits non-zero on any problem):
  - Heteronym rule (word-data-spec): reading and first meaning come from one entry,
    chosen by hand. Every word with more than one CC-CEDICT reading must be in the table.
  - Official HSK list wins on tones; the table's 5th column names the CC-CEDICT entry
    when the shown reading differs from it.
  - First meaning: <= 22 characters, balanced brackets, no vulgar or euphemistic sense.
  - Words tagged as measure words lead with "measure word".
  - Readings contain no digits.
  - Word count shares no factor with any offered slots-per-day.
"""
import json, re, sys
from math import gcd
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from zh_pinyin import marks

hsk_path, cedict_path, out_path = sys.argv[1:4]
here = __file__.rsplit("/", 1)[0]
LEVELS = (1, 2, 3)
CAP = 22
OFFERED_SLOTS_PER_DAY = [1440 // m for m in (30, 60, 120, 180, 360)]
# Rule 8 (affixes are not words of the day): 子 as in 桌子 (Rachel's check against
# the official list), 们 the plural suffix (as たち was dropped for Japanese).
DROP = {"子", "们"}

JUNK = re.compile(r"^(variant of|old variant of|surname|see |also written|abbr\. for|erhua variant|"
                  r"used in|erhua|CL:|Taiwan pr\.|euphemistic|\(old\)|\(archaic\)|\(dialect\)|\(Tw\)|\(classical\))", re.I)
BANNED = re.compile(r"\(vulgar\)|euphemis|obscene|屄|肏", re.I)

def strip(s):
    while True:
        n = re.sub(r"\s*\([^()]*\)", "", s)
        if n == s:
            break
        s = n
    return s.strip(" ;,")

def tsv(name, cols):
    rows = {}
    for line in open(f"{here}/{name}", encoding="utf-8"):
        if line.strip() and not line.startswith("#"):
            f = line.rstrip("\n").split("\t")
            rows[f[0]] = f[1:] + [""] * (cols - len(f))
    return rows

table = tsv("zh_heteronyms.tsv", 5)    # reading, gloss, evidence, entry reading
MEANING = {w: v[0] for w, v in tsv("zh_meanings.tsv", 2).items()}
MANUAL = tsv("zh_manual.tsv", 3)       # reading, gloss
# Words whose HSK 1-3 sense is a measure word: the first meaning must say so (Rachel).
# A hand list: the packager's part-of-speech tags come from an automatic tagger.
MEASURE = {l.split("#")[0].strip() for l in open(f"{here}/zh_measure_words.txt", encoding="utf-8")} - {""}

# CC-CEDICT: simplified -> [(reading with tone marks, [senses])]
cedict = {}
for line in open(cedict_path, encoding="utf-8"):
    if line.startswith("#"):
        continue
    m = re.match(r"(\S+) (\S+) \[([^\]]+)\] /(.*)/$", line.strip())
    if m:
        senses = [p.strip() for g in m.group(4).split("/") for p in g.split(";") if p.strip()]
        cedict.setdefault(m.group(2), []).append((marks(m.group(3)), senses))

def usable(senses):
    return [p for p in senses if not JUNK.match(p) and strip(p)]

data = json.load(open(hsk_path, encoding="utf-8"))
words, problems, used = [], [], {"table": set(), "meaning": set(), "manual": set()}
for lv in LEVELS:
    for w in data:
        if f"new-{lv}" not in w.get("level", []):
            continue
        o = w["simplified"]
        if o in DROP:
            continue
        entries = cedict.get(o, [])
        if not entries:
            if o not in MANUAL:
                problems.append(f"{o}: not in CC-CEDICT and not in zh_manual.tsv")
                continue
            used["manual"].add(o)
            rd, gloss = MANUAL[o][0], MANUAL[o][1]
            meanings = [gloss]
        elif len({r.lower() for r, _ in entries}) > 1:
            if o not in table:
                problems.append(f"{o}: heteronym missing from zh_heteronyms.tsv "
                                f"({'/'.join(sorted({r for r, _ in entries}))})")
                continue
            rd, gloss, evidence, entry_rd = table[o]
            entry_rd = entry_rd or rd
            chosen = [s for r, s in entries if r == entry_rd]
            if not chosen:
                problems.append(f"{o}: {entry_rd} is not a CC-CEDICT entry of this word")
                continue
            text = " ; ".join(p for s in chosen for p in s)
            if evidence.lower() not in text.lower():
                problems.append(f"{o} {entry_rd}: evidence '{evidence}' not in that entry")
                continue
            used["table"].add(o)
            meanings = [gloss] + [p for s in chosen for p in usable(s) if p != gloss][:3]
        else:
            # One reading. Common-noun entries (lowercase pinyin) before surnames/brands.
            entries = sorted(entries, key=lambda e: e[0][:1].isupper())
            senses = [p for _, s in entries for p in usable(s)]
            rd = next((r for r, s in entries if usable(s)), entries[0][0])
            if o in MEANING:
                used["meaning"].add(o)
                first = MEANING[o]
            elif senses:
                first = strip(senses[0])
            else:
                problems.append(f"{o}: no usable meaning")
                continue
            meanings = [first] + [p for p in senses if p != first][:3]
        if re.search(r"\d", rd):
            problems.append(f"{o}: digit in reading {rd}")
        first = meanings[0]
        if not first or len(first) > CAP:
            problems.append(f"{o}: first meaning empty or over {CAP}: {first}")
        if first.count("(") != first.count(")"):
            problems.append(f"{o}: unbalanced brackets: {first}")
        if any(BANNED.search(m) for m in meanings):
            problems.append(f"{o}: banned sense in {meanings}")
        if o in MEASURE and not first.startswith("measure word"):
            problems.append(f"{o}: measure word, first meaning is '{first}'")
        pos = POS.get((w.get("pos") or [""])[0]) if (POS := {
            "n": "noun", "v": "verb", "a": "adjective", "d": "adverb", "m": "number", "q": "measure word",
            "r": "pronoun", "p": "preposition", "c": "conjunction", "u": "particle", "e": "interjection",
            "y": "particle", "t": "noun", "f": "noun", "s": "noun", "vn": "verb", "an": "adjective",
            "nz": "noun", "ns": "noun", "nr": "noun", "nt": "noun", "o": "onomatopoeia", "i": "expression",
            "l": "expression", "j": "noun", "b": "adjective", "z": "adjective", "ad": "adverb", "vd": "verb"}) else None
        words.append({"id": f"cedict:{o}:{rd}", "language": "zh-Hans", "orthography": o, "reading": rd,
                      "meanings": meanings, "partOfSpeech": pos, "level": {"hsk": lv}, "isCommon": True})

for kind, rows in (("table", table), ("meaning", MEANING), ("manual", MANUAL)):
    for o in set(rows) - used[kind]:
        problems.append(f"{o}: row in the {kind} table matches nothing")
if len({(w["orthography"], w["reading"]) for w in words}) != len(words):
    problems.append("duplicate (orthography, reading)")
for s in OFFERED_SLOTS_PER_DAY:
    if gcd(len(words), s) != 1:
        problems.append(f"{len(words)} words share a factor with {s} slots a day")
if problems:
    print("\n".join(problems))
    sys.exit(f"{len(problems)} problems")

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(words, f, ensure_ascii=False, indent=1)
    f.write("\n")
print(f"bundle {len(words)} words: {len(used['table'])} heteronyms, {len(used['meaning'])} hand-written "
      f"meanings, {len(used['manual'])} hand-written words")
