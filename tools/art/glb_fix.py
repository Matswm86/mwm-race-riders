#!/usr/bin/env python3
"""Small GLB fixes after Blender's glTF export (pure JSON edits, no re-encode). Used by w36_lib.done() and runnable:

    python3 tools/art/glb_fix.py assets/models/world3/*.glb

1. Vertex alpha: Blender 4.5 writes an all-white COLOR_0 and the real vertex colour (our edge-fade alpha) as
   COLOR_1. Godot reads only COLOR_0, so patches lost their soft edge. COLOR_0 now points at the real data.
2. UV set: meshes that started from Blender primitives keep the primitive's UV layer as TEXCOORD_0 and the baked
   atlas as TEXCOORD_1 (the reason RrMats.UV2_MODELS exists). The atlas becomes TEXCOORD_0 and every texture
   reference uses texCoord 0, so no per-model UV2 copy is needed in the game.
"""

from __future__ import annotations

import json
import struct
import sys
from pathlib import Path


def _load(path: Path):
    b = path.read_bytes()
    jlen = struct.unpack("<I", b[12:16])[0]
    return b, jlen, json.loads(b[20 : 20 + jlen])


def _save(path: Path, b: bytes, jlen: int, j: dict) -> None:
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    rest = b[20 + jlen :]
    total = 12 + 8 + len(js) + len(rest)
    path.write_bytes(b[:8] + struct.pack("<I", total) + struct.pack("<I", len(js)) + b"JSON" + js + rest)


def fix(path: Path) -> list[str]:
    b, jlen, j = _load(path)
    done = []
    mats_uv1 = set()
    for i, m in enumerate(j.get("materials", [])):
        refs = [m.get("pbrMetallicRoughness", {}).get("baseColorTexture"),
                m.get("pbrMetallicRoughness", {}).get("metallicRoughnessTexture"),
                m.get("normalTexture"), m.get("occlusionTexture"), m.get("emissiveTexture")]
        if any(r and r.get("texCoord", 0) == 1 for r in refs):
            mats_uv1.add(i)
            for r in refs:
                if r:
                    r["texCoord"] = 0
    for me in j.get("meshes", []):
        for prim in me["primitives"]:
            at = prim["attributes"]
            if "COLOR_1" in at:
                at["COLOR_0"] = at.pop("COLOR_1")
                done.append("COLOR_0 = vertex alpha")
            if prim.get("material") in mats_uv1 and "TEXCOORD_1" in at:
                at["TEXCOORD_0"] = at.pop("TEXCOORD_1")
                done.append("TEXCOORD_0 = atlas")
    if done:
        _save(path, b, jlen, j)
    return sorted(set(done))


if __name__ == "__main__":
    for a in sys.argv[1:]:
        r = fix(Path(a))
        if r:
            print(a, ", ".join(r))
