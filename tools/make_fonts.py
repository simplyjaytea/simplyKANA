"""Cut the bundled Noto Serif faces down to what the app draws (design-direction §2).

For each pack, the orthography face gets every character of every orthography
(plus the pack placeholder and the fallback dash); the reading face gets every
character of every reading. Pinyin and romanized readings are Latin and use a
system serif, so packs whose reading list doesn't start with a Noto face skip it.

Usage (needs fonttools; not run in CI, the .ttf files are committed):
  python3 -m venv /tmp/ft && /tmp/ft/bin/pip install fonttools
  /tmp/ft/bin/python tools/make_fonts.py <dir with NotoSerif??[wght].ttf from google/fonts>

The AppTests check (BundledFontTests) fails if a pack character is missing.
"""
import json, os, subprocess, sys, tempfile
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKS = os.path.join(ROOT, "kana-core/Sources/KanaCore/Resources/Packs")
OUT = os.path.join(ROOT, "Shared/Fonts")
WEIGHTS = {"Medium": 500, "Regular": 400}

def cut(src, ps_name, chars, out):
    family, style = ps_name.split("-")
    f = instancer.instantiateVariableFont(TTFont(src), {"wght": WEIGHTS[style]})
    # Default layout features only (kern, liga, palt...); "*" pulls in vertical
    # and alternate glyphs for every character and doubles the file.
    opts = subset.Options(); opts.name_IDs = ["*"]; opts.hinting = False; opts.desubroutinize = True
    s = subset.Subsetter(opts); s.populate(text="".join(sorted(chars))); s.subset(f)
    name = f["name"]
    full = family.replace("NotoSerif", "Noto Serif ")
    for rec in list(name.names):
        if rec.nameID in (1, 2, 3, 4, 6, 16, 17, 25):
            name.removeNames(nameID=rec.nameID)
    for nid, val in {1: full, 2: "Regular" if style == "Regular" else style, 4: f"{full} {style}",
                     6: ps_name, 3: f"{ps_name};simplyKANA subset", 16: full, 17: style}.items():
        name.setName(val, nid, 3, 1, 0x409)
    f.save(out)

def main(src_dir):
    for fn in sorted(os.listdir(PACKS)):
        pack = json.load(open(os.path.join(PACKS, fn)))
        m, words = pack["manifest"], pack["words"]
        texts = {"orthography": {"—"} | set(m["placeholder"]["orthography"]),
                 "reading": {"—"} | set(m["placeholder"]["reading"])}
        for w in words:
            texts["orthography"] |= set(w["orthography"])
            texts["reading"] |= set(w["reading"])
        for role in ("orthography", "reading"):
            first = m["fonts"][role][0]
            if not first.startswith("NotoSerif") or first.startswith("NotoSerif-"):
                continue  # Latin readings use a system serif
            family = first.split("-")[0]
            src = os.path.join(src_dir, f"{family}[wght].ttf")
            out = os.path.join(OUT, f"{first}.ttf")
            cut(src, first, texts[role], out)
            print(f"{fn}: {role} -> {first}.ttf, {len(texts[role])} chars, {os.path.getsize(out)//1024} KB")

if __name__ == "__main__":
    main(sys.argv[1])
