#!/usr/bin/env python3
"""Write Godot import settings for the realistic art set before the first import.

Godot only compresses a texture for VRAM and builds mipmaps when the editor sees it
used in 3D, which never happens for textures the game loads from code. This writes
the .import files up front (DESIGN 12, import settings):

- every albedo / ORM / emission / terrain map: VRAM compressed, mipmaps on
- every normal map: VRAM compressed, normal-map mode on, mipmaps on
- HDRIs: VRAM uncompressed (half float), no mipmaps; the game loads the 1K
  .exr copies (the 2K .hdr sources stay out of the export)
- 2D UI textures (assets/textures/ui): lossless, no mipmaps
- every GLB: textures discarded on import (the game builds its materials from the
  loose files in assets/textures, so each texture ships once), LODs on

Existing .import files are left alone unless --force is given.

python3 tools/write_imports.py [--force]
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

TEX_HEAD = '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
SCENE_HEAD = '[remap]\n\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n\n[params]\n\n'


def tex_params(p: Path) -> str:
    name = p.stem.lower()
    rel = p.relative_to(ROOT).as_posix()
    if p.suffix.lower() in (".hdr", ".exr"):
        return "compress/mode=3\nmipmaps/generate=false\ncompress/hdr_compression=0\ndetect_3d/compress_to=0\n"
    if rel.startswith("assets/textures/ui/"):
        return "compress/mode=0\nmipmaps/generate=false\nprocess/fix_alpha_border=true\ndetect_3d/compress_to=0\n"
    normal = name.endswith("_normal") or name.endswith("_nrm")
    out = [
        "compress/mode=2",
        "compress/high_quality=false",
        f"compress/normal_map={1 if normal else 2}",
        "mipmaps/generate=true",
        "mipmaps/limit=-1",
        "roughness/mode=0",
        "process/fix_alpha_border=true",
        "process/premult_alpha=false",
        "detect_3d/compress_to=0",
    ]
    return "\n".join(out) + "\n"


SCENE_PARAMS = (
    "\n".join(
        [
            "nodes/apply_root_scale=true",
            "nodes/root_scale=1.0",
            "meshes/ensure_tangents=true",
            "meshes/generate_lods=true",
            "meshes/create_shadow_meshes=true",
            "meshes/light_baking=1",
            "skins/use_named_skins=true",
            "animation/import=true",
            "animation/fps=30",
            "animation/remove_immutable_tracks=true",
            "gltf/naming_version=2",
            "gltf/embedded_image_handling=0",
        ]
    )
    + "\n"
)


def main() -> None:
    force = "--force" in sys.argv
    n = 0
    for p in sorted((ROOT / "assets/textures").rglob("*")):
        if p.suffix.lower() not in (".png", ".jpg", ".jpeg", ".hdr", ".exr"):
            continue
        imp = p.with_name(p.name + ".import")
        if imp.exists() and not force:
            continue
        imp.write_text(TEX_HEAD + tex_params(p))
        n += 1
    for p in sorted((ROOT / "assets/models").glob("*.glb")):
        imp = p.with_name(p.name + ".import")
        if imp.exists() and not force:
            continue
        imp.write_text(SCENE_HEAD + SCENE_PARAMS)
        n += 1
    print(f"wrote {n} import files")


if __name__ == "__main__":
    main()
