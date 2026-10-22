"""Render the simplyKANA app icon: one 語 in Noto Serif JP, ink on paper
(design-direction §6). Usage: make_icon.py NotoSerifJP[wght].ttf OUTDIR WEIGHT"""
import sys
from PIL import Image, ImageDraw, ImageFont

GLYPH = "語"
SIZE = 1024

def render(path, weight, bg, fg, scale=0.60):
    f = ImageFont.truetype(path, int(SIZE * scale))
    f.set_variation_by_axes([weight])
    img = Image.new("RGB", (SIZE, SIZE), bg)
    d = ImageDraw.Draw(img)
    l, t, r, b = d.textbbox((0, 0), GLYPH, font=f)
    # Centre the ink, not the em box; lift 1% so it sits optically centred.
    x = (SIZE - (r - l)) / 2 - l
    y = (SIZE - (b - t)) / 2 - t - SIZE * 0.01
    d.text((x, y), GLYPH, font=f, fill=fg)
    return img

if __name__ == "__main__":
    path, out, weight = sys.argv[1], sys.argv[2], int(sys.argv[3])
    render(path, weight, "#F6F1E7", "#1B1714").save(f"{out}/AppIcon.png")       # paper, ink
    render(path, weight, "#15120F", "#EDE6DA").save(f"{out}/AppIcon-Dark.png")  # dark paper, dark ink
    # Tinted: iOS 18 tints a greyscale glyph on its own dark background.
    render(path, weight, "#000000", "#FFFFFF").convert("L").save(f"{out}/AppIcon-Tinted.png")
