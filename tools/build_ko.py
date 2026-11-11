"""Korean join: NIKL Basic Korean Dictionary (한국어기초사전) -> word list.

usage: python3 -I tools/build_ko.py <dir with krdict *.xml> out.json   (normally via tools/build_pack.py ko)

Source: NIKL Basic Korean Dictionary, CC BY-SA 2.0 KR (docs/word-data-spec.md, Korean
pack). Grade A = vocabularyLevel 초급. Hand judgement lives in packs/ko/:
  overrides.tsv  word<TAB>first meaning      (Lock Screen line, max 22 chars)
  readings.tsv   word<TAB>romanization        (only where NIKL lists no pronunciation
                                               and the spelling has a sound-change join)
  drops.txt      word<TAB>reason              (rule 8, or "count")
Rules: one entry per spelling (homographs share spelling and romanization; the lowest
homonym number leads, the rest go to the "also" meanings); readings are Revised
Romanization from NIKL's listed pronunciation (tools/ko_romanize.py); the 40 jamo come
first as the foundation tier.
"""
import glob, io, json, os, re, sys
import xml.etree.ElementTree as ET
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ko_romanize import romanize, has_join, choose

src_dir, out_path = sys.argv[1:3]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HAND = os.path.join(ROOT, "packs", "ko")

def tsv(name):
    path = os.path.join(HAND, name)
    if not os.path.exists(path):
        return {}
    rows = {}
    for line in open(path, encoding="utf-8"):
        if line.strip() and not line.startswith("#"):
            k, v = line.rstrip("\n").split("\t", 1)
            rows[k] = v
    return rows

OVERRIDE, READING, DROP = tsv("overrides.tsv"), tsv("readings.tsv"), tsv("drops.txt")

# ---------------------------------------------------------------- jamo tier
JAMO = [  # letter, sounds (both where the letter has two)
    ("ㄱ", "g / k"), ("ㄴ", "n"), ("ㄷ", "d / t"), ("ㄹ", "r / l"), ("ㅁ", "m"), ("ㅂ", "b / p"),
    ("ㅅ", "s / t"), ("ㅇ", "silent / ng"), ("ㅈ", "j / t"), ("ㅊ", "ch / t"), ("ㅋ", "k"), ("ㅌ", "t"),
    ("ㅍ", "p"), ("ㅎ", "h / t"), ("ㄲ", "kk / k"), ("ㄸ", "tt"), ("ㅃ", "pp"), ("ㅆ", "ss / t"), ("ㅉ", "jj"),
    ("ㅏ", "a"), ("ㅐ", "ae"), ("ㅑ", "ya"), ("ㅒ", "yae"), ("ㅓ", "eo"), ("ㅔ", "e"), ("ㅕ", "yeo"),
    ("ㅖ", "ye"), ("ㅗ", "o"), ("ㅘ", "wa"), ("ㅙ", "wae"), ("ㅚ", "oe"), ("ㅛ", "yo"), ("ㅜ", "u"),
    ("ㅝ", "wo"), ("ㅞ", "we"), ("ㅟ", "wi"), ("ㅠ", "yu"), ("ㅡ", "eu"), ("ㅢ", "ui"), ("ㅣ", "i"),
]
assert len(JAMO) == 40
jamo = [{"id": f"jamo:{i:02d}", "language": "ko", "orthography": j, "reading": j, "meanings": [s],
         "partOfSpeech": "jamo", "level": None, "isCommon": True} for i, (j, s) in enumerate(JAMO)]

# ---------------------------------------------------------------- dictionary
POS = {"명사": "noun", "동사": "verb", "형용사": "adjective", "부사": "adverb", "관형사": "determiner",
       "수사": "numeral", "의존 명사": "bound noun", "대명사": "pronoun", "감탄사": "interjection"}
RULE8_POS = {"접사", "조사", "어미"}   # affixes, particles, endings: not words of the day

def parse(path):
    # The 2019 mirror has a raw '<' inside one attribute value; escape it on read, never edit the source.
    text = open(path, encoding="utf-8").read()
    text = re.sub(r'val="([^"]*)"', lambda m: 'val="' + m.group(1).replace("<", "&lt;").replace(">", "&gt;") + '"', text)
    for _, e in ET.iterparse(io.StringIO(text)):
        if e.tag == "LexicalEntry":
            yield e
            e.clear()

entries = []
for path in sorted(glob.glob(os.path.join(src_dir, "*.xml"))):
    for e in parse(path):
        top = {f.get("att"): f.get("val") for f in e.findall("feat")}
        if top.get("vocabularyLevel") != "초급":
            continue
        word = e.find('Lemma/feat[@att="writtenForm"]').get("val")
        prons = [p.get("val") for p in e.findall('WordForm/feat[@att="pronunciation"]') if p.get("val")]
        pron = choose(word, prons) if prons else None
        glosses = []
        for s in e.findall("Sense"):
            for q in s.findall("Equivalent"):
                d = {f.get("att"): f.get("val") for f in q.findall("feat")}
                if d.get("language") == "영어" and d.get("lemma"):
                    glosses.append(d["lemma"])
        entries.append({"id": e.get("val"), "word": word, "hom": int(top.get("homonym_number") or 0),
                        "pos": top.get("partOfSpeech"), "pron": pron, "glosses": glosses})

def strip(s):
    while True:
        n = re.sub(r"\s*\([^()]*\)", "", s)
        if n == s:
            return s.strip(" ;,")
        s = n

def parts(glosses):
    out = []
    for g in glosses:
        for p in re.split(r"[;,]", g):
            p = p.strip()
            if p and p not in out:
                out.append(p)
    return out

by_word = {}
for e in entries:
    by_word.setdefault(e["word"], []).append(e)

words, problems, report = [], [], {"homographs": [], "rule8": [], "dropped": []}
for word in sorted(by_word, key=lambda w: min(int(x["id"]) for x in by_word[w])):
    group = sorted(by_word[word], key=lambda x: (x["hom"], int(x["id"])))
    lead = group[0]
    if lead["pos"] in RULE8_POS:
        report["rule8"].append(word)
        continue
    if word in DROP:
        report["dropped"].append(f"{word} ({DROP[word]})")
        continue
    if len(group) > 1:
        report["homographs"].append(word)
    # Reading: from NIKL's pronunciation; spelling only when no sound can change.
    if word in READING:
        rd = READING[word]
    elif lead["pron"]:
        rd = romanize(word, lead["pron"])
    elif lead["pos"] == "명사" and not has_join(word):
        rd = romanize(word, word)
    else:
        problems.append(f"{word}: no NIKL pronunciation and the spelling has a sound-change join; "
                        f"add it to packs/ko/readings.tsv")
        continue
    lead_parts = parts(lead["glosses"])
    rest = [p for x in group[1:] for p in parts(x["glosses"])]
    if not lead_parts and word not in OVERRIDE:
        problems.append(f"{word}: NIKL's English headword is blank; add it to packs/ko/overrides.tsv")
        continue
    first = OVERRIDE[word] if word in OVERRIDE else strip(lead_parts[0])
    meanings = [first] + [p for p in lead_parts + rest if p != first][:3]
    words.append({"id": f"krdict:{lead['id']}", "language": "ko", "orthography": word, "reading": rd,
                  "meanings": meanings, "partOfSpeech": POS.get(lead["pos"], lead["pos"]),
                  "level": {"nikl": 1}, "isCommon": True})

for kind, rows in (("overrides.tsv", OVERRIDE), ("readings.tsv", READING), ("drops.txt", DROP)):
    for w in rows:
        if w not in by_word:
            problems.append(f"{w}: row in packs/ko/{kind} matches no grade A word")
if len({w["orthography"] for w in words}) != len(words):
    problems.append("duplicate orthography")
if problems:
    print("\n".join(problems))
    sys.exit(f"{len(problems)} problems")

out = jamo + words
json.dump(out, open(out_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"bundle {len(out)} = 40 jamo + {len(words)} grade A; {len(report['homographs'])} homographs merged, "
      f"rule 8 dropped {report['rule8']}, hand drops {report['dropped']}")
