#!/usr/bin/env python3
"""Crop the capture bot's track pictures into the track-card thumbnails.

Run the bot first (Xvfb recipe in the studio CLAUDE.md) with CAPTURE_PHASE=thumbs, then:
  python3 tools/make_thumbs.py <capture dir>
Each thumb_<key>.png (1080x1920, HUD hidden) becomes assets/textures/ui/tracks/<key>.jpg:
a 1080 px square from y 420 (sky, the trail ahead and the rider), scaled to 320 px, with a
Godot import file set to lossy compression so 96 pictures cost about 2 MB.
World pictures (the world discs and the world page): thumb_w<N>_t1.png also becomes
assets/textures/ui/world_<N>.jpg (512 px) for worlds 3-6; worlds 1 and 2 keep their hand-picked
frames.
"""

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "textures" / "ui" / "tracks"
SIZE = 320
TOP = 420
IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/textures/ui/tracks/{name}"

[params]

compress/mode=1
compress/high_quality=false
compress/lossy_quality=0.8
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def main() -> int:
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    if src is None or not src.is_dir():
        print(__doc__)
        return 1
    OUT.mkdir(parents=True, exist_ok=True)
    n = 0
    for png in sorted(src.glob("thumb_w*_t*.png")):
        key = png.stem.removeprefix("thumb_")
        im = Image.open(png).convert("RGB")
        w = im.width
        sq = im.crop((0, TOP, w, TOP + w)).resize((SIZE, SIZE), Image.LANCZOS)
        name = f"{key}.jpg"
        sq.save(OUT / name, quality=86, optimize=True)
        imp = OUT / f"{name}.import"
        if not imp.exists():
            imp.write_text(IMPORT.format(name=name), encoding="utf-8")
        n += 1
        w_id = int(key[1])
        if key.endswith("_t1") and w_id >= 3:
            big = im.crop((0, TOP, w, TOP + w)).resize((512, 512), Image.LANCZOS)
            big.save(OUT.parent / f"world_{w_id}.jpg", quality=88, optimize=True)
            wimp = OUT.parent / f"world_{w_id}.jpg.import"
            if not wimp.exists():
                wimp.write_text(
                    IMPORT.format(name=f"../world_{w_id}.jpg")
                    .replace("ui/tracks/../", "ui/")
                    .replace("compress/mode=1", "compress/mode=0"),
                    encoding="utf-8",
                )
    print(f"wrote {n} thumbnails to {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
