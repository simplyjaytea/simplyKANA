"""Build one language pack: packs/<lang>/pack.toml -> <lang>.pack.json (docs/pack-pipeline.md).

usage: python3 -I tools/build_pack.py <lang> [--sources DIR] [--out DIR]

Runs the pack's join (named in pack.toml), then the gates every pack shares, then
writes one file: {"manifest": {...}, "words": [...]}. The app and widget discover packs
by listing *.pack.json; nothing in Swift names a language.

--sources: directory holding the downloaded source files named in [join].inputs
           (never committed). Default: /tmp/packsrc/<lang>.
"""
import json, os, re, subprocess, sys, tempfile, tomllib
from math import gcd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
args = sys.argv[1:]
lang = args[0]
src_dir = args[args.index("--sources") + 1] if "--sources" in args else f"/tmp/packsrc/{lang}"
out_dir = args[args.index("--out") + 1] if "--out" in args else f"{ROOT}/kana-core/Sources/KanaCore/Resources/Packs"

conf = tomllib.load(open(f"{ROOT}/packs/{lang}/pack.toml", "rb"))
assert conf["language"] == lang, "pack.toml language must match its folder"

# 1. Join: the one language-specific step. Each join script reads its sources and the
#    pack's hand files and writes a plain word list.
join = conf["join"]
inputs = [p if p.startswith("tools/") else os.path.join(src_dir, p) for p in join["inputs"]]
inputs = [os.path.join(ROOT, p) if p.startswith("tools/") else p for p in inputs]
with tempfile.TemporaryDirectory() as tmp:
    words_path = os.path.join(tmp, "words.json")
    r = subprocess.run([sys.executable, "-I", os.path.join(ROOT, join["script"]), *inputs, words_path],
                       capture_output=True, text=True)
    sys.stdout.write(r.stdout)
    if r.returncode:
        sys.exit(f"join failed: {r.stderr.strip()}")
    words = json.load(open(words_path, encoding="utf-8"))

# 2. Gates every pack shares (the join may have stricter ones of its own).
OFFERED_SLOTS_PER_DAY = [1440 // m for m in (30, 60, 120, 180, 360)]
problems = []
if any(w["language"] != lang for w in words):
    problems.append("a word's language differs from the pack's")
if len({w["id"] for w in words}) != len(words):
    problems.append("duplicate ids")
for w in words:
    # Links carry the id: keep it safe to put in a URL path (Dana, #39 review).
    if re.search(r"[%/\s]", w["id"]):
        problems.append(f"{w['orthography']}: id has %, / or a space: {w['id']}")
if not conf["fonts"]["orthography"] or not conf["fonts"]["reading"]:
    problems.append("pack.toml [fonts] needs orthography and reading lists")
if len({(w["orthography"], w["reading"]) for w in words}) != len(words):
    problems.append("duplicate (orthography, reading)")
for w in words:
    m = w["meanings"][0] if w["meanings"] else ""
    if not m or len(m) > 22:
        problems.append(f"{w['orthography']}: first meaning empty or over 22: {m}")
    if m.count("(") != m.count(")"):
        problems.append(f"{w['orthography']}: unbalanced brackets")
    if re.search(r"[\s()（）;；～〜]", w["orthography"]):
        problems.append(f"{w['orthography']}: list formatting in orthography")
    if re.search(r"\d", w["reading"]):
        problems.append(f"{w['orthography']}: digit in reading")
for s in OFFERED_SLOTS_PER_DAY:
    if gcd(len(words), s) != 1:
        problems.append(f"{len(words)} words share a factor with {s} slots a day")
if problems:
    print("\n".join(problems))
    sys.exit(f"{len(problems)} problems")

# 3. One file.
ph = conf["placeholder"]
manifest = {
    "language": lang, "name": conf["name"], "widgetName": conf["widget_name"],
    "widgetSlot": conf["widget_slot"], "levelLabels": conf["level_labels"],
    "levelSummary": conf["level_summary"],
    "fonts": {"orthography": conf["fonts"]["orthography"], "reading": conf["fonts"]["reading"]},
    "voice": conf["voice"],
    "speakReading": conf["speak_reading"], "scriptPartsOfSpeech": conf["script_parts_of_speech"],
    "placeholder": {"id": "placeholder", "language": lang, "orthography": ph["orthography"],
                    "reading": ph["reading"], "meanings": [ph["meaning"]],
                    "partOfSpeech": ph.get("part_of_speech"), "level": ph.get("level"), "isCommon": True},
    "credits": [{"title": s["title"], "detail": s["detail"], "licence": s["licence"], "url": s.get("url")}
                for s in conf["source"]],
    "count": len(words),
}
os.makedirs(out_dir, exist_ok=True)
with open(os.path.join(out_dir, f"{lang}.pack.json"), "w", encoding="utf-8") as f:
    json.dump({"manifest": manifest, "words": words}, f, ensure_ascii=False, indent=1)
    f.write("\n")
print(f"{lang}.pack.json: {len(words)} words")
