#!/usr/bin/env python3
"""Re-encode opaque loose PNG textures as JPEG (albedo/emission q90, normal/ORM q94) and drop the PNG and its
stale Godot .import. RrMats.find() accepts .png or .jpg, so nothing in the game changes; cards with real alpha
stay PNG. Godot re-imports every texture to ETC2/ASTC, so the APK does not change; the repo does.

python3 tools/art/tex_slim.py assets/textures/world3/*.png ...
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

saved = 0
for a in sys.argv[1:]:
    p = Path(a)
    if p.suffix != ".png" or not p.exists():
        continue
    im = Image.open(p)
    if im.mode in ("RGBA", "LA") or "transparency" in im.info:
        if np.asarray(im.convert("RGBA"))[..., 3].min() < 250:
            continue
    data_map = p.stem.endswith(("_normal", "_orm", "_arm"))
    out = p.with_suffix(".jpg")
    im.convert("RGB").save(out, "JPEG", quality=94 if data_map else 90, optimize=True)
    saved += p.stat().st_size - out.stat().st_size
    p.unlink()
    imp = p.with_name(p.name + ".import")
    if imp.exists():
        imp.unlink()
    print(f"{p.name} -> {out.name}")
print(f"saved {saved / 1048576:.1f} MB")
