#!/usr/bin/env python3
"""Download Poly Haven (CC0) assets used by MWM Race Riders into assets/_raw/polyhaven/.

Usage: python3 tools/art/fetch_polyhaven.py
Raw downloads stay out of git (.gitignore: assets/_raw/). Each asset is listed in CREDITS.md.
"""

import json
import pathlib
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2] / "assets" / "_raw" / "polyhaven"
HDRIS = {"alps_field": ["2k", "4k"], "goegap": ["2k", "4k"]}
TEXTURES = {
    "rocky_trail_02": "2k",
    "rocky_trail": "1k",
    "forest_leaves_04": "1k",
    "gravel_floor_02": "1k",
    "weathered_planks": "1k",
    "pine_bark": "1k",
    "brown_mud_02": "1k",
    "sparse_grass": "1k",
    "forest_ground_04": "1k",
    # world 2 (Red Canyon)
    "red_laterite_soil_stones": "2k",
    "red_sand": "1k",
    "cliff_side": "1k",
    "worn_asphalt": "1k",
    "rusty_metal_02": "1k",
    "corrugated_iron_02": "1k",
}
MODELS = {
    "pine_tree_01": "1k",
    "rock_moss_set_01": "1k",
    "grass_medium_01": "1k",
    "fern_02": "1k",
    "wild_rooibos_bush": "1k",
    "dead_tree_trunk_02": "1k",
}
MAPS = ("Diffuse", "nor_gl", "Rough", "AO", "Displacement", "arm")


def get(url: str, dest: pathlib.Path) -> None:
    if dest.exists() and dest.stat().st_size > 0:
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "mwm-race-riders-art/1.0"})
    with urllib.request.urlopen(req) as r:
        dest.write_bytes(r.read())
    print("got", dest.relative_to(ROOT), dest.stat().st_size)


def files(asset: str) -> dict:
    req = urllib.request.Request(
        f"https://api.polyhaven.com/files/{asset}",
        headers={"User-Agent": "mwm-race-riders-art/1.0"},
    )
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def main() -> None:
    for h, sizes in HDRIS.items():
        f = files(h)
        for s in sizes:
            u = f["hdri"][s]["hdr"]["url"]
            get(u, ROOT / "hdri" / f"{h}_{s}.hdr")
    for t, s in TEXTURES.items():
        f = files(t)
        for m in MAPS:
            if m in f and s in f[m]:
                fmt = "jpg" if "jpg" in f[m][s] else "png"
                get(f[m][s][fmt]["url"], ROOT / "textures" / t / f"{t}_{m.lower()}_{s}.{fmt}")
    for mdl, s in MODELS.items():
        f = files(mdl)
        g = f["gltf"][s]["gltf"]
        get(g["url"], ROOT / "models" / mdl / pathlib.Path(g["url"]).name)
        for rel, inc in g.get("include", {}).items():
            get(inc["url"], ROOT / "models" / mdl / rel)


if __name__ == "__main__":
    main()
