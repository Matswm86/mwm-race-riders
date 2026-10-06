#!/usr/bin/env python3
"""Number masks for jerseys and bikes: R = digit fill, G = outline ring. 512x512 PNG per rider number.

python3 tools/art/make_decals.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "_raw" / "build"
OUT.mkdir(parents=True, exist_ok=True)
FONT = ROOT / "assets" / "fonts" / "BarlowCondensed-Bold.ttf"
NUMS = [7, 12, 23, 31, 4, 88]

for n in NUMS:
    s = 512
    font = ImageFont.truetype(str(FONT), 470)
    fill = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(fill)
    txt = str(n)
    bb = d.textbbox((0, 0), txt, font=font)
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    d.text(((s - w) / 2 - bb[0], (s - h) / 2 - bb[1]), txt, font=font, fill=255)
    ring = fill.filter(ImageFilter.MaxFilter(25))
    img = Image.merge("RGB", (fill, ring, Image.new("L", (s, s), 0)))
    img.save(OUT / f"num_{n}.png")
    print("num", n, w, h)

# Gate icons (white on transparent, 512x512): side-view bike and side-view hoverboard; chequer 512 tile.
from PIL import Image as _I  # noqa: E402

S = 512
bike = _I.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(bike)
W = (255, 255, 255, 255)
for cx in (130, 382):
    d.ellipse((cx - 96, 300 - 96, cx + 96, 300 + 96), outline=W, width=26)
d.line(
    [(130, 300), (230, 300), (330, 180), (200, 180), (130, 300)], fill=W, width=24, joint="curve"
)
d.line([(230, 300), (190, 150)], fill=W, width=22)
d.line([(160, 150), (230, 150)], fill=W, width=24)
d.line([(330, 180), (382, 300)], fill=W, width=22)
d.line([(330, 180), (315, 120), (360, 110)], fill=W, width=22, joint="curve")
bike.save(OUT / "icon_bike.png")
board = _I.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(board)
d.rounded_rectangle((40, 230, 472, 280), radius=25, fill=W)
d.polygon([(40, 255), (10, 215), (40, 230)], fill=W)
d.polygon([(472, 255), (502, 215), (472, 230)], fill=W)
for cx in (150, 362):
    d.rounded_rectangle((cx - 60, 285, cx + 60, 318), radius=14, fill=W)
for y, x0 in ((360, 120), (395, 170), (430, 220)):
    d.line([(x0, y), (x0 + 220, y)], fill=W, width=14)
board.save(OUT / "icon_board.png")
chk = _I.new("RGBA", (S, S), (255, 255, 255, 255))
d = ImageDraw.Draw(chk)
n = 8
for j in range(n):
    for i in range(n):
        if (i + j) % 2:
            d.rectangle(
                (i * S // n, j * S // n, (i + 1) * S // n - 1, (j + 1) * S // n - 1),
                fill=(18, 19, 21, 255),
            )
chk.save(OUT / "chequer.png")
print("icons ok")
