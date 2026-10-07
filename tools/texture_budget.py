#!/usr/bin/env python3
"""APK size budget (owner 10-07: keep the APK under 300 MB; the first six-world build was 359 MB):
cap the import size of the world textures (DESIGN 12: ETC2/ASTC, mipmaps on).
- Trail and smooth-lane albedos (they fill half the screen): 1024 px (the 2K W1/W2 trails too).
- Other terrain albedos (base, verge, patch, rock layers, tiled every 3-9 m): 512 px.
- Terrain normal/ARM maps: 512 px on trails and lanes, 256 px on the other layers. Prop albedos: 512 px. Prop normal/ORM maps: 256 px.
- Tree and plant card atlases: albedo kept, normal 1024 px. Skies: 1024 px wide (the W1/W2 skies were
  re-saved as half float, like the others).
Edits process/size_limit in the existing .import files in place (uids kept).

python3 tools/texture_budget.py
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRAILS = {
    "terrain_rocky_trail_02",
    "terrain_gravel_floor_02",
    "terrain_red_laterite_soil_stones",
    "terrain_worn_asphalt",
    "terrain_snow_groomed",
    "terrain_blue_ice",
    "terrain_ash_trail",
    "terrain_basalt",
    "terrain_mud_wet",
    "terrain_asphalt_wet",
    "terrain_quay_concrete",
}
CARDS = ("tree_", "grass_card", "plant_", "shrub_", "bush_desert")


def limit(p: Path) -> int:
    n = p.stem
    if n.startswith("sky_"):
        return 1024
    if n.startswith("fx_") or "_" not in n:
        return 0
    base, kind = n.rsplit("_", 1)
    if n.startswith(CARDS):
        return 1024 if kind == "normal" else 0
    if n.startswith("terrain_"):
        if kind == "albedo":
            return 1024 if base in TRAILS else 512
        return 512 if base in TRAILS else 256
    if kind in ("normal", "orm", "arm"):
        return 256
    if kind == "albedo":
        return 512
    return 0


def main() -> None:
    n = 0
    for d in range(1, 7):
        for p in sorted((ROOT / f"assets/textures/world{d}").glob("*")):
            if p.suffix.lower() not in (".jpg", ".png", ".exr"):
                continue
            imp = p.with_name(p.name + ".import")
            lim = limit(p)
            if not imp.exists() or lim == 0:
                continue
            t = imp.read_text()
            if "compress/mode=2" not in t and p.suffix.lower() != ".exr":
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
