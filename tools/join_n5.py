"""Prototype: join the N5 list (expression, reading) to JMdict for stable ids,
glosses, part of speech and the common flag. Reports match quality.

usage: python3 -I join_n5.py JMdict_e n5.csv out.json
"""
import csv, json, sys
import xml.etree.ElementTree as ET

jm_path, n5_path, out_path = sys.argv[1:4]

# index: (kanji-or-kana form, reading) -> list of entries
index = {}
for _, el in ET.iterparse(jm_path, events=("end",)):
    if el.tag != "entry":
        continue
    seq = el.findtext("ent_seq")
    kebs = [(k.findtext("keb"), bool(k.findall("ke_pri"))) for k in el.findall("k_ele")]
    rebs = [(r.findtext("reb"), bool(r.findall("re_pri"))) for r in el.findall("r_ele")]
    common = any(p for _, p in kebs) or any(p for _, p in rebs)
    senses = el.findall("sense")
    glosses = [g.text for g in senses[0].findall("gloss")] if senses else []
    pos = senses[0].findtext("pos") if senses else None
    entry = {"seq": seq, "glosses": glosses, "pos": pos, "common": common}
    for reb, _ in rebs:
        index.setdefault((reb, reb), []).append(entry)
        for keb, _ in kebs:
            index.setdefault((keb, reb), []).append(entry)
    el.clear()

words, unmatched, ambiguous = [], [], 0
seen = set()
with open(n5_path, encoding="utf-8") as f:
    for row in csv.DictReader(f):
        expr, reading = row["expression"].strip(), row["reading"].strip()
        cands = index.get((expr, reading)) or []
        if not cands:
            # Normalize list formatting: "a; b" variants, "～" affix marks, "(する)".
            def forms(x):
                out = []
                for v in x.split(";"):
                    v = v.replace("～", "").replace("(する)", "").strip()
                    out.append(v)
                    if v.endswith("する") and len(v) > 2:
                        out.append(v[:-2])
                return [v for v in out if v]
            es, rs = forms(expr), forms(reading)
            for e in es:
                for r in rs:
                    cands = index.get((e, r)) or []
                    if cands:
                        expr, reading = e, r
                        break
                if cands:
                    break
        if not cands:
            unmatched.append((expr, reading, row["meaning"]))
            continue
        if len(cands) > 1:
            ambiguous += 1
        best = sorted(cands, key=lambda e: (not e["common"], int(e["seq"])))[0]
        wid = "jmdict:" + best["seq"]
        if wid in seen:
            continue
        seen.add(wid)
        words.append({"id": wid, "orthography": expr, "reading": reading,
                      "meanings": best["glosses"][:3], "partOfSpeech": best["pos"],
                      "jlptLevel": 5, "isCommon": best["common"]})

json.dump(words, open(out_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"matched {len(words)}, unmatched {len(unmatched)}, ambiguous {ambiguous}")
for u in unmatched:
    print("  UNMATCHED", u)
