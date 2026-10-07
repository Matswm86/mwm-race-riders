#!/usr/bin/env python3
"""Shrink GLBs on disk: re-encode embedded PNG textures that have no real alpha as JPEG (colour q90, normal and
ORM q94, the same as the JPEG normal/ARM maps the terrain already uses). Alpha cards keep their PNG. Godot
re-imports every texture to ETC2/ASTC, so the APK is unchanged; the repo and the download shrink.

python3 tools/art/glb_slim.py assets/models/world3/*.glb ...
"""

from __future__ import annotations

import io
import json
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def slim(path: Path) -> tuple[int, int]:
    b = path.read_bytes()
    assert b[:4] == b"glTF"
    jlen = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20 : 20 + jlen])
    off = 20 + jlen
    blen = struct.unpack("<I", b[off : off + 4])[0]
    bin_ = b[off + 8 : off + 8 + blen]
    views = j["bufferViews"]
    data = [bin_[v.get("byteOffset", 0) : v.get("byteOffset", 0) + v["byteLength"]] for v in views]
    # which images are colour (baseColor / emissive)?
    colour_tex = set()
    for m in j.get("materials", []):
        pbr = m.get("pbrMetallicRoughness", {})
        for key in (pbr.get("baseColorTexture"), m.get("emissiveTexture")):
            if key is not None:
                colour_tex.add(j["textures"][key["index"]]["source"])
    changed = False
    for idx, img in enumerate(j.get("images", [])):
        if img.get("mimeType") != "image/png" or "bufferView" not in img:
            continue
        bv = img["bufferView"]
        im = Image.open(io.BytesIO(data[bv]))
        if im.mode in ("RGBA", "LA") or "transparency" in im.info:
            a = np.asarray(im.convert("RGBA"))[..., 3]
            if a.min() < 250:
                continue  # real alpha (cards, decals): keep PNG
        out = io.BytesIO()
        im.convert("RGB").save(out, "JPEG", quality=90 if idx in colour_tex else 94, optimize=True)
        data[bv] = out.getvalue()
        img["mimeType"] = "image/jpeg"
        changed = True
    if not changed:
        return len(b), len(b)
    new_bin = b""
    for i, v in enumerate(views):
        pad = (-len(new_bin)) % 4
        new_bin += b"\0" * pad
        v["byteOffset"] = len(new_bin)
        v["byteLength"] = len(data[i])
        new_bin += data[i]
    new_bin += b"\0" * ((-len(new_bin)) % 4)
    j["buffers"][0]["byteLength"] = len(new_bin)
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * ((-len(js)) % 4)
    total = 12 + 8 + len(js) + 8 + len(new_bin)
    out = (b"glTF" + struct.pack("<II", 2, total) + struct.pack("<I", len(js)) + b"JSON" + js
           + struct.pack("<I", len(new_bin)) + b"BIN\0" + new_bin)
    path.write_bytes(out)
    return len(b), len(out)


if __name__ == "__main__":
    t0 = t1 = 0
    for a in sys.argv[1:]:
        p = Path(a)
        o, n = slim(p)
        t0 += o
        t1 += n
        if o != n:
            print(f"{p}: {o / 1024:.0f} KB -> {n / 1024:.0f} KB")
    print(f"total {t0 / 1048576:.1f} MB -> {t1 / 1048576:.1f} MB")
