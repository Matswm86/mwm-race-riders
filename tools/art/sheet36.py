#!/usr/bin/env python3
"""Join preview36.py tiles into one labelled sheet, with tris and file size from the build report.
python3 tools/art/sheet36.py <tile dir> <out.jpg>
"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
rep_f = ROOT / "assets/_raw/build/w36_report.json"
rep = json.loads(rep_f.read_text()) if rep_f.exists() else {}
tiles = sorted(Path(sys.argv[1]).glob("*.png"))
W = 5
T = 320
sheet = Image.new("RGB", (W * T, ((len(tiles) + W - 1) // W) * (T + 34)), "white")
d = ImageDraw.Draw(sheet)
for i, t in enumerate(tiles):
    x, y = (i % W) * T, (i // W) * (T + 34)
    sheet.paste(Image.open(t).convert("RGB").resize((T, T)), (x, y + 34))
    key = t.stem.replace("__", "/")
    r = rep.get(key)
    d.text((x + 4, y + 3), key, fill="black")
    if r:
        d.text((x + 4, y + 18), f"{r[0]} m  {r[1]} tris  {r[2] / 1024:.0f} KB", fill="black")
sheet.save(sys.argv[2], quality=88)
print(sys.argv[2], len(tiles))
