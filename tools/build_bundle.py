"""Build the Japanese word bundle: 92 kana, then JLPT N5 joined to JMdict.

usage: python3 -I tools/build_bundle.py JMdict_e tools/n5.csv kana-core/Sources/KanaCore/Resources/words-ja.json

Sources (credits screen, playbook rule 9):
  JMdict, EDRDG, CC-BY-SA 4.0. https://www.edrdg.org/edrdg/licence.html
  N5 list: open-anki-jlpt-decks (MIT), from Jonathan Waller's JLPT lists.

The bundle is an adaptation of JMdict, so it ships under CC-BY-SA 4.0.
"""
import csv, json, re, sys
import xml.etree.ElementTree as ET

jm_path, n5_path, out_path = sys.argv[1:4]

# ---------------------------------------------------------------- kana
HIRA = ("あいうえお かきくけこ さしすせそ たちつてと なにぬねの はひふへほ まみむめも やゆよ らりるれろ わをん")
ROMA = ("a i u e o ka ki ku ke ko sa shi su se so ta chi tsu te to na ni nu ne no "
        "ha hi fu he ho ma mi mu me mo ya yu yo ra ri ru re ro wa wo n").split()
hira = [c for c in HIRA if c != " "]
assert len(hira) == len(ROMA) == 46
kata = [chr(ord(c) + 0x60) for c in hira]  # hiragana -> katakana block offset

kana = []
for script, chars in (("hiragana", hira), ("katakana", kata)):
    for c, r in zip(chars, ROMA):
        kana.append({"id": f"kana:{script}:{r}", "language": "ja", "orthography": c,
                     "reading": c, "meanings": [r], "partOfSpeech": script,
                     "level": None, "isCommon": True})

# ---------------------------------------------------------------- JMdict
index = {}
for _, el in ET.iterparse(jm_path, events=("end",)):
    if el.tag != "entry":
        continue
    seq = el.findtext("ent_seq")
    kebs = [(k.findtext("keb"), bool(k.findall("ke_pri"))) for k in el.findall("k_ele")]
    rebs = [(r.findtext("reb"), bool(r.findall("re_pri"))) for r in el.findall("r_ele")]
    common = any(p for _, p in kebs) or any(p for _, p in rebs)
    senses, last_pos = [], None
    for s in el.findall("sense"):
        pos = s.findtext("pos") or last_pos  # pos carries over to following senses
        last_pos = pos
        senses.append({"glosses": [g.text for g in s.findall("gloss")], "pos": pos})
    entry = {"seq": seq, "senses": senses, "common": common}
    for reb, _ in rebs:
        index.setdefault((reb, reb), []).append(entry)
        for keb, _ in kebs:
            index.setdefault((keb, reb), []).append(entry)
    el.clear()

# ---------------------------------------------------------------- hand decisions
# Not words of the day (playbook rule 8): prefixes and affix-only senses.
# Rule 8, the literal table in docs/word-data-spec.md (PR #11). Table first, bundle second.
DROP = {("お", "お"), ("人", "じん"), ("中", "じゅう"),
        ("人", "にん"), ("中", "ちゅう"), ("屋", "や"), ("年", "ねん"), ("時", "じ"),  # 日 にち stays: 日 has no other entry
        ("ずつ", "ずつ"), ("だけ", "だけ"), ("など", "など"),
        ("たち", "たち"), ("がる", "がる"), ("さん", "さん")}  # grammatical suffixes
# Rows that do not match JMdict as written: list form -> JMdict form.
FIX = {("十", "(〜を) とお"): ("十", "とお"),
       ("ゆっくりと", "ゆっくりと"): ("ゆっくり", "ゆっくり"),
       ("ラジオカセ", "ラジオカセ"): ("ラジカセ", "ラジカセ")}
# Reviewed by hand (all 52 multi-match rows, 2026-10-23) where the automatic
# choice was wrong: (orth, reading) -> (ent_seq, sense index).
PIN = {("コート", "コート"): ("1049000", 0),   # coat, not court
       ("あれ", "あれ"): ("1000580", 0),       # "that", not "that place"
       ("すぎ", "すぎ"): ("1195960", 0)}       # "past, after"
# First meaning written by hand where JMdict's best sense reads wrong on its own.
MEANING = {("キロ", "キロ"): ["kilogram", "kilometre"],
           ("日", "にち"): ["day of the month", "nth day (of the month)", "for ... days"],
           # Counters: one short form, "<things> (counter)", so the Lock Screen fits
           # (cap below). The JMdict gloss follows for the Word screen.
           ("回", "かい"): ["times (counter)", "counter for occurrences"],
           ("階", "かい"): ["floors (counter)", "counter for storeys and floors of a building"],
           ("個", "こ"): ["small items (counter)", "counter for (small) things or pieces"],
           ("台", "だい"): ["machines (counter)", "counter for machines and vehicles"],
           ("度", "ど"): ["times; degrees", "counter for occurrences", "degree (angle, temperature, scale, etc.)"],
           ("杯", "はい"): ["cupfuls (counter)", "counter for cupfuls, bowlfuls, spoonfuls, etc."],
           ("匹", "ひき"): ["animals (counter)", "counter for small animals"],
           ("枚", "まい"): ["flat things (counter)", "counter for thin, flat objects (e.g. sheets of paper, plates, coins)"],
           ("冊", "さつ"): ["books (counter)", "counter for books"],
           ("か月", "かげつ"): ["months (counter)", "counter for months"],
           # Rachel's reading pass over all 689 N5 first meanings (PR #15).
           ("呼ぶ", "よぶ"): ["to call", "to call out (to)", "to invite"],
           ("軽い", "かるい"): ["light", "not heavy"],
           ("余り", "あまり"): ["not very", "remainder", "too much"],
           ("皆さん", "みなさん"): ["everyone", "all"],
           ("おじいさん", "おじいさん"): ["grandfather", "old man"],
           ("おばあさん", "おばあさん"): ["grandmother", "old woman"],
           ("明るい", "あかるい"): ["bright", "light", "cheerful"],
           ("曲る", "まがる"): ["to turn", "to bend", "to curve"],
           ("在る", "ある"): ["to be", "to exist", "to have"],
           ("吸う", "すう"): ["to smoke", "to breathe in", "to suck"],
           ("美味しい", "おいしい"): ["delicious", "tasty"],
           # Found when bracket stripping exposed them (PR: rule 8 drops).
           ("鳥", "とり"): ["bird", "bird meat (esp. chicken meat)", "fowl"],
           ("欲しい", "ほしい"): ["want", "wanted", "desired"],
           ("横", "よこ"): ["side", "beside", "width"],
           ("差す", "さす"): ["to open (umbrella)", "to hold up (an umbrella, etc.)"],
           ("居る", "いる"): ["to be (living things)", "to be (of animate objects)", "to exist"],
           ("かかる", "かかる"): ["to take (time, money)", "to take (a resource, e.g. time or money)"],
           # Rachel's review of PR #8: these led with a sense that teaches the wrong word.
           ("いいえ", "いいえ"): ["no", "not at all"],
           ("一つ", "ひとつ"): ["one (thing)", "one"],
           ("切る", "きる"): ["to cut", "to cut through"],
           ("私", "わたくし"): ["I (formal)", "me"],
           ("どうも", "どうも"): ["thanks", "very", "much"],
           ("方", "かた"): ["person (polite)", "direction"],
           ("先", "さき"): ["ahead", "tip", "future"],
           ("引く", "ひく"): ["to pull", "to draw"],
           ("浴びる", "あびる"): ["to bathe", "to shower"],
           ("よく", "よく"): ["often", "well", "frequently"],
           ("たて", "たて"): ["length", "height", "vertical"],
           ("先生", "せんせい"): ["teacher", "instructor", "sensei"],
           # Poppy, same review: technically right, but not what a learner needs first.
           ("大丈夫", "だいじょうぶ"): ["all right", "OK", "safe"],
           ("本当", "ほんとう"): ["truth", "reality", "really"],
           ("ない", "ない"): ["there isn't", "nonexistent"]}

STOP = set("a an the to of e g eg etc be is in on for or and as at by".split())
def toks(s):
    return {w for w in re.findall(r"[a-z]+", s.lower()) if w not in STOP}

def forms(x):
    out = []
    for v in x.split(";"):
        v = v.replace("～", "").replace("〜", "").replace("(する)", "").strip()
        out.append(v)
        if v.endswith("する") and len(v) > 2:
            out.append(v[:-2])
    return [v for v in out if v]

POS_SHORT = [("noun", "noun"), ("pronoun", "pronoun"), ("verb", "verb"),
             ("adjectival noun", "na-adjective"), ("adjective", "adjective"),
             ("adverb", "adverb"), ("conjunction", "conjunction"),
             ("interjection", "interjection"), ("counter", "counter"),
             ("numeric", "number"), ("expression", "expression"),
             ("suffix", "suffix"), ("prefix", "prefix"), ("particle", "particle")]
# The Lock Screen shows meanings[0] only, and it must fit the rectangular widget
# without truncation (word-data-spec, first-meaning length). JMdict's bracketed
# notes come off position 0; the full gloss moves to position 1 for the Word screen.
MEANING_CAP = 22  # characters; from the first snapshots: 22 fits, 28 truncated

def lock_screen_meanings(glosses):
    full = glosses[:3]
    short = full[0]
    while True:  # innermost first, so "dog (Canis (lupus) familiaris)" -> "dog"
        nxt = re.sub(r"\s*\([^()]*\)", "", short)
        if nxt == short:
            break
        short = nxt
    short = short.strip()
    if short and short != full[0]:
        return [short] + full
    return full

def short_pos(p):
    if not p:
        return None
    pl = p.lower()
    if pl.startswith("adjectival nouns"):
        return "na-adjective"
    for key, val in POS_SHORT:
        if key in pl:
            return val
    return None

words, unmatched, report = [], [], []
used_meaning, no_overlap = set(), []
seen_ids, seen_pairs = set(), set()
with open(n5_path, encoding="utf-8") as f:
    for row in csv.DictReader(f):
        expr, reading = row["expression"].strip(), row["reading"].strip()
        expr, reading = FIX.get((expr, reading), (expr, reading))
        cands = index.get((expr, reading)) or []
        if not cands:
            for e in forms(expr):
                for r in forms(reading):
                    cands = index.get((e, r)) or []
                    if cands:
                        expr, reading = e, r
                        break
                if cands:
                    break
        if not cands:
            unmatched.append((expr, reading))
            continue
        if (expr, reading) in DROP:
            continue
        want = toks(row["meaning"])
        best = None  # (score, entry, sense index)
        for e in cands:
            for i, s in enumerate(e["senses"]):
                score = len(want & toks(" ".join(s["glosses"])))
                key = (score, e["common"], -int(e["seq"]), -i)
                if best is None or key > best[0]:
                    best = (key, e, i)
        _, e, i = best
        if (expr, reading) in PIN:
            seq, i = PIN[(expr, reading)]
            e = next(c for c in cands if c["seq"] == seq)
        sense = e["senses"][i]
        meanings = MEANING.get((expr, reading)) or lock_screen_meanings(sense["glosses"])
        wid = "jmdict:" + e["seq"]
        if wid in seen_ids or (expr, reading) in seen_pairs:
            continue
        seen_ids.add(wid)
        seen_pairs.add((expr, reading))
        if (expr, reading) in MEANING:
            used_meaning.add((expr, reading))
        elif not (want & toks(meanings[0])):
            no_overlap.append(f"{expr}|{reading}")
        if len(cands) > 1:
            report.append(f"{expr}\t{reading}\tlist: {row['meaning']}\t-> {e['seq']} {sense['glosses'][:3]}")
        words.append({"id": wid, "language": "ja", "orthography": expr, "reading": reading,
                      "meanings": meanings, "partOfSpeech": short_pos(sense["pos"]),
                      "level": {"jlpt": 5}, "isCommon": e["common"]})

unused = set(MEANING) - used_meaning
assert not unused, f"MEANING overrides that match no row: {unused}"

# First meanings that share no word with the N5 list's own meaning. Each one
# was read by a person (Rachel and Poppy, PR #8 review) and is a fine synonym. A new
# entry here fails the build until someone reads it.
REVIEWED_NO_OVERLAP_FILE = __file__.replace("build_bundle.py", "reviewed_meanings.txt")
if "--write-reviewed" in sys.argv:
    open(REVIEWED_NO_OVERLAP_FILE, "w", encoding="utf-8").write("\n".join(sorted(no_overlap)) + "\n")
reviewed = set(open(REVIEWED_NO_OVERLAP_FILE, encoding="utf-8").read().split())
new = sorted(set(no_overlap) - reviewed)
assert not new, f"first meanings nobody has reviewed: {new}"

too_long = [f"{w['orthography']}|{w['reading']}: {w['meanings'][0]}" for w in words
            if len(w["meanings"][0]) > MEANING_CAP]
assert not too_long, f"first meanings over {MEANING_CAP} characters: {too_long}"

# ---------------------------------------------------------------- order
# Common first within N5 (spec §3), stable by source order otherwise.
words.sort(key=lambda w: not w["isCommon"])
bundle = kana + words

# Equal orthographies at least 24 slots apart, circularly (PR #4).
def violations(b):
    pos = {}
    for i, w in enumerate(b):
        pos.setdefault(w["orthography"], []).append(i)
    n, bad = len(b), []
    for o, ps in pos.items():
        for a in range(len(ps)):
            for c in range(a + 1, len(ps)):
                d = abs(ps[a] - ps[c])
                if min(d, n - d) < 24:
                    bad.append((o, ps[a], ps[c]))
    return bad

for _ in range(50):
    bad = violations(bundle)
    if not bad:
        break
    o, a, c = bad[0]
    w = bundle.pop(c)
    target = (a + 30) % len(bundle)
    while target < len(kana):  # never move a word into the kana block
        target += 30
    bundle.insert(target, w)
assert not violations(bundle), violations(bundle)
assert len(bundle) % 24 != 0, f"bundle count {len(bundle)} is a multiple of 24"

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(bundle, f, ensure_ascii=False, indent=1)
    f.write("\n")
print(f"bundle {len(bundle)} = {len(kana)} kana + {len(words)} N5; unmatched {unmatched}")
if "--report" in sys.argv:
    print("\n".join(report))
