#!/usr/bin/env python3
"""APK size budget (owner 10-07: keep the APK under 300 MB): cap the import size of the world
textures. Terrain albedos (the trail fills half the screen), the tree / plant card atlases and
the skies keep their size; terrain normal/ARM maps, every prop's normal and ORM map and the far
backdrops are imported at 512 px, prop albedos at 1024 px (DESIGN 12: ETC2/ASTC, mipmaps on).
Edits process/size_limit in the existing .import files in place (uids kept).

python3 tools/texture_budget.py
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FAR = {
    "mountain_ridge",
    "crater_cone",
    "mesa_backdrop",
    "lit_bridge_far",
    "container_stack_far",
    "ferry",
    "warehouse",
    "sea_marker",
}


def limit(p: Path) -> int:
    n = p.stem
    if n.startswith("sky_") or n.startswith("fx_") or n.startswith("tree_") or "_" not in n:
        return 0
    base, kind = n.rsplit("_", 1)
    if n.startswith("terrain_"):
        return 0 if kind == "albedo" else 512
    if base in FAR:
        return 512
    if kind in ("normal", "orm", "arm"):
        return 512
    if kind == "albedo":
        return 1024
    return 0


def main() -> None:
    n = 0
    for d in range(1, 7):
        for p in sorted((ROOT / f"assets/textures/world{d}").glob("*")):
            if p.suffix.lower() not in (".jpg", ".png"):
                continue
            imp = p.with_name(p.name + ".import")
            lim = limit(p)
            if not imp.exists() or lim == 0:
                continue
            t = imp.read_text()
            if "compress/mode=2" not in t:
                continue
            line = f"process/size_limit={lim}"
            if re.search(r"^process/size_limit=\d+$", t, re.M):
                t2 = re.sub(r"^process/size_limit=\d+$", line, t, flags=re.M)
            else:
                t2 = t.rstrip("\n") + "\n" + line + "\n"
            if t2 != t:
                imp.write_text(t2)
                n += 1
    print(f"capped {n} textures")


if __name__ == "__main__":
    main()
