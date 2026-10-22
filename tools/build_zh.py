"""Build the Chinese bundle: HSK 3.0 (2021) levels 1-3, simplified, with CC-CEDICT
pinyin and glosses as packaged in complete-hsk-vocabulary.

usage: python3 -I tools/build_zh.py complete.json kana-core/Sources/KanaCore/Resources/words-zh.json

Sources (credits screen): CC-CEDICT (MDBG, CC-BY-SA 4.0) for pinyin and meanings;
complete-hsk-vocabulary (MIT) for HSK 3.0 level membership. See tools/DATA-LICENSES.md.

Heteronym rule (word-data-spec): a word with more than one reading takes its reading
and its first meaning from the same dictionary entry, chosen by hand in
tools/zh_heteronyms.tsv. The build fails if any heteronym is missing from the table,
or if a row's reading isn't an entry of that word, or its evidence phrase isn't in
that entry's meanings.
"""
import json, re, sys
from math import gcd

src, out_path = sys.argv[1:3]
here = __file__.rsplit("/", 1)[0]
LEVELS = (1, 2, 3)
CAP = 22
OFFERED_SLOTS_PER_DAY = [1440 // m for m in (30, 60, 120, 180, 360)]

JUNK = re.compile(r"^(variant of|old variant of|surname|see |also written|abbr\. for|erhua variant|"
                  r"used in|CL:|Taiwan pr\.|euphemistic|\(old\)|\(archaic\)|\(dialect\)|\(Tw\))", re.I)
BANNED = re.compile(r"\(vulgar\)|euphemis|obscene|屄|肏", re.I)

def strip(s):
    while True:
        n = re.sub(r"\s*\([^()]*\)", "", s)
        if n == s:
            break
        s = n
    return s.strip(" ;,")

def reading(f):
    return f["transcriptions"]["pinyin"].replace(" ", "")

def parts(f):
    return [p.strip() for m in f["meanings"] for p in m.split(";") if p.strip()]

def senses(f):
    return [p for p in parts(f) if not JUNK.match(p) and strip(p)]

POS = {"n": "noun", "v": "verb", "a": "adjective", "d": "adverb", "m": "number", "q": "classifier",
       "r": "pronoun", "p": "preposition", "c": "conjunction", "u": "particle", "e": "interjection",
       "y": "particle", "t": "noun", "f": "noun", "s": "noun", "vn": "verb", "an": "adjective",
       "nz": "noun", "ns": "noun", "nr": "noun", "nt": "noun", "o": "onomatopoeia", "i": "expression",
       "l": "expression", "j": "noun", "b": "adjective", "z": "adjective", "ad": "adverb", "vd": "verb"}

table = {}
for line in open(f"{here}/zh_heteronyms.tsv", encoding="utf-8"):
    if not line.strip() or line.startswith("#"):
        continue
    w, rd, gloss, evidence = line.rstrip("\n").split("\t")
    table[w] = (rd, gloss, evidence)

# Hand-written first meanings for words whose dictionary gloss is too long or reads wrong.
MEANING = {}
for line in open(f"{here}/zh_meanings.tsv", encoding="utf-8"):
    if line.strip() and not line.startswith("#"):
        w, gloss = line.rstrip("\n").split("\t")
        MEANING[w] = gloss

data = json.load(open(src, encoding="utf-8"))
words, problems, used_table, used_meaning = [], [], set(), set()
for lv in LEVELS:
    for w in data:
        if f"new-{lv}" not in w.get("level", []):
            continue
        o = w["simplified"]
        distinct = {reading(f).lower() for f in w["forms"]}
        if len(distinct) > 1:
            if o not in table:
                problems.append(f"{o}: heteronym missing from zh_heteronyms.tsv ({'/'.join(sorted(distinct))})")
                continue
            rd, gloss, evidence = table[o]
            forms = [f for f in w["forms"] if reading(f) == rd]
            text = " ; ".join(parts(f)[i] for f in forms for i in range(len(parts(f))))
            if not forms:
                problems.append(f"{o}: table reading {rd} is not an entry of this word")
                continue
            if evidence.lower() not in text.lower():
                problems.append(f"{o} {rd}: evidence '{evidence}' not in that entry")
                continue
            used_table.add(o)
            rest = [p for f in forms for p in senses(f)][:3]
            meanings = [gloss] + rest
        else:
            # One reading, possibly several entries (a surname or a brand under the
            # same pinyin). Common-noun entries (lowercase pinyin) first.
            forms = sorted(w["forms"], key=lambda f: reading(f)[:1].isupper())
            ss = [p for f in forms for p in senses(f)]
            rd = reading(next((f for f in forms if senses(f)), forms[0]))
            if not ss and o not in MEANING:
                problems.append(f"{o}: no usable meaning")
                continue
            first = MEANING[o] if o in MEANING else strip(ss[0])
            if o in MEANING:
                used_meaning.add(o)
            # Full dictionary glosses follow the short one, for the Word screen.
            meanings = [first] + [m for m in ss if m != first][:3]
        if len(meanings[0]) > CAP:
            problems.append(f"{o}: first meaning over {CAP}: {meanings[0]}")
        if any(BANNED.search(m) for m in meanings):
            problems.append(f"{o}: banned sense in {meanings}")
        pos = POS.get((w.get("pos") or [""])[0])
        words.append({"id": f"cedict:{o}:{rd}", "language": "zh-Hans", "orthography": o, "reading": rd,
                      "meanings": meanings, "partOfSpeech": pos, "level": {"hsk": lv}, "isCommon": True})

for o in set(table) - used_table:
    problems.append(f"{o}: row in zh_heteronyms.tsv matches no heteronym in the list")
for o in set(MEANING) - used_meaning:
    problems.append(f"{o}: row in zh_meanings.tsv matches no word")
pairs = {(w["orthography"], w["reading"]) for w in words}
if len(pairs) != len(words):
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
print(f"bundle {len(words)} words, {len(used_table)} heteronyms from the table, "
      f"{len(used_meaning)} hand-written first meanings")
