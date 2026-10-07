#!/usr/bin/env python3
"""Download the CC0 sources for worlds 3-6 and the W1/W2 landmarks into assets/_raw/ (not in git).

Poly Haven (CC0 1.0): HDRIs, textures, models.  ambientCG (CC0 1.0): ice, lava, basalt, layered rock.
Every asset is listed in CREDITS.md.

Usage: python3 -I tools/art/fetch_worlds36.py
"""

import io
import json
import pathlib
import urllib.request
import zipfile

RAW = pathlib.Path(__file__).resolve().parents[2] / "assets" / "_raw"
PH = RAW / "polyhaven"
ACG = RAW / "ambientcg"
UA = {"User-Agent": "mwm-race-riders-art/1.0"}

HDRIS = {
    "horn-koppe_snow": ["2k", "4k"],  # W3 Glacier Run: clear pale-blue winter sky over snow
    "belfast_sunset_puresky": ["2k", "4k"],  # W4 Ash Mountain: overcast, low orange sun
    "rainforest_trail": ["2k", "4k"],  # W5 Rainforest: lush canopy, soft light
    "qwantani_moonrise_puresky": ["2k", "4k"],  # W6 Night Harbour: deep-blue night sky, low moon
}
TEXTURES = {
    # W3 Glacier
    "snow_02": "1k",
    "snow_04": "1k",
    "snow_field_aerial": "1k",
    # W4 Ash Mountain
    "low_tide_rocks": "1k",
    "burned_ground_01": "1k",
    # W5 Rainforest
    "mud_forest": "1k",
    "brown_mud_leaves_01": "1k",
    "forest_leaves_02": "1k",
    "river_small_rocks": "1k",
    "mossy_rock": "1k",
    "bark_brown_02": "1k",
    # W6 Night Harbour
    "asphalt_02": "1k",
    "concrete_floor_worn_001": "1k",
    "metal_plate": "1k",
    "container_side": "1k",
    "factory_wall": "1k",
    # W1 / W2 landmarks
    "rock_face_03": "1k",
    "distressed_painted_planks": "1k",
    "leafy_grass": "1k",
    "concrete_wall_003": "1k",
    "painted_concrete": "1k",
}
MODELS = {
    "boulder_01": "1k",
    "moon_rock_01": "1k",
    "moon_rock_03": "1k",
    "moon_rock_05": "1k",
    "namaqualand_cliff_01": "1k",
    "namaqualand_cliff_02": "1k",
    "island_tree_01": "1k",
    "island_tree_02": "1k",
    "pachira_aquatica_01": "1k",
    "calathea_orbifolia_01": "1k",
    "anthurium_botany_01": "1k",
    "dry_branches_medium_01": "1k",
    "dead_tree_trunk": "1k",
    "concrete_road_barrier": "1k",
    "lateral_sea_marker": "1k",
}
ACG_MATS = ["Ice003", "Lava001", "Rock035", "Rock030"]
MAPS = ("Diffuse", "nor_gl", "Rough", "AO", "Displacement", "arm")


def get(url: str, dest: pathlib.Path) -> None:
    if dest.exists() and dest.stat().st_size > 0:
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA)) as r:
        dest.write_bytes(r.read())
    print("got", dest.relative_to(RAW), dest.stat().st_size)


def files(asset: str) -> dict:
    req = urllib.request.Request(f"https://api.polyhaven.com/files/{asset}", headers=UA)
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def main() -> None:
    for h, sizes in HDRIS.items():
        f = files(h)
        for s in sizes:
            get(f["hdri"][s]["hdr"]["url"], PH / "hdri" / f"{h}_{s}.hdr")
    for t, s in TEXTURES.items():
        f = files(t)
        for m in MAPS:
            if m in f and s in f[m]:
                fmt = "jpg" if "jpg" in f[m][s] else "png"
                get(f[m][s][fmt]["url"], PH / "textures" / t / f"{t}_{m.lower()}_{s}.{fmt}")
    for mdl, s in MODELS.items():
        f = files(mdl)
        g = f["gltf"][s]["gltf"]
        get(g["url"], PH / "models" / mdl / pathlib.Path(g["url"]).name)
        for rel, inc in g.get("include", {}).items():
            get(inc["url"], PH / "models" / mdl / rel)
    for a in ACG_MATS:
        d = ACG / a
        if d.exists() and any(d.glob("*_Color.jpg")):
            continue
        d.mkdir(parents=True, exist_ok=True)
        url = f"https://ambientcg.com/get?file={a}_1K-JPG.zip"
        with urllib.request.urlopen(urllib.request.Request(url, headers=UA)) as r:
            z = zipfile.ZipFile(io.BytesIO(r.read()))
        for n in z.namelist():
            if n.endswith((".jpg", ".png")) and "/" not in n:
                (d / n).write_bytes(z.read(n))
        print("got ambientCG", a, sorted(p.name for p in d.iterdir()))


if __name__ == "__main__":
    main()
