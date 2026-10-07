"""Skies for worlds 3-6 (and the World 2 sky-only fix), from Poly Haven CC0 HDRIs.

Writes per world: assets/textures/world<N>/sky_<name>_2k.hdr (Radiance) and sky_<name>_1k.exr (half float, the
size the game loads since the APK diet). World 2 gets sky_goegap_skyonly_*: the hills that rise above the horizon
in the goegap panorama (the "open-left hill" seen past the canyon mouth) are painted out with the sky colour of
the same column, with a warm haze band at the horizon; the ground below the horizon is kept (warm bounce light).
Also prints the sun pixel (u, v from the top) and elevation for the DirectionalLight match.

blender -b --factory-startup -P tools/art/make_skies36.py
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
import rr_art as A  # noqa: E402

SKIES = {3: "horn-koppe_snow", 4: "belfast_sunset_puresky", 5: "rainforest_trail", 6: "qwantani_moonrise_puresky"}


def load(name):
    img = bpy.data.images.load(str(A.PH / "hdri" / f"{name}_2k.hdr"))
    a = A.px(img).copy()  # rows bottom-up
    w, h = img.size
    bpy.data.images.remove(img)
    return a, w, h


def save(a, w, h, path: Path, fmt: str, size=None):
    img = bpy.data.images.new(path.stem, w, h, alpha=False, float_buffer=True)
    img.pixels.foreach_set(a.astype(np.float32).ravel())
    if size is not None:
        img.scale(*size)
    sc = bpy.context.scene
    s = sc.render.image_settings
    s.file_format = fmt
    if fmt == "OPEN_EXR":
        s.color_depth = "16"
        s.exr_codec = "ZIP"  # Godot (tinyexr) reads ZIP; it cannot read DWAA
    s.color_mode = "RGB"
    sc.view_settings.view_transform = "Standard"
    img.save_render(str(path), scene=sc)
    bpy.data.images.remove(img)
    print("sky", path.relative_to(A.ROOT), path.stat().st_size)


def sun_info(a, w, h):
    lum = a[..., :3].mean(-1)
    iy, ix = np.unravel_index(np.argmax(lum), lum.shape)
    v_top = 1 - (iy + 0.5) / h
    u = (ix + 0.5) / w
    elev = 90 - v_top * 180
    return round(u, 3), round(v_top, 3), round(elev, 1)


def skyonly_goegap():
    a, w, h = load("goegap")
    hz = h // 2  # horizon row (rows are bottom-up: rows >= hz are above the horizon)
    rgb = a[..., :3]
    top = hz + int(h * 0.14)  # hills reach about 21 deg above the horizon on the left
    out = a.copy()
    blend = int(h * 0.04)  # soft hand-over into the real sky above the band
    ref_row = np.median(rgb[top + blend], axis=0)
    haze = ref_row.max() * np.array([1.55, 1.45, 1.35], np.float32)  # pale warm horizon haze
    for y in range(hz, top + blend):
        t = min(1.0, (y - hz) / (top - hz)) ** 0.6
        sky = haze * (1 - t) + ref_row * t
        k = 0.0 if y < top else (y - top) / blend  # 0 = synthetic, 1 = original
        out[y, :, :3] = sky[None, :] * (1 - k) + rgb[y] * k
    # soften the seam
    band = out[hz - 3 : hz + 3, :, :3]
    out[hz - 3 : hz + 3, :, :3] = band.mean(0, keepdims=True) * 0.5 + band * 0.5
    d = A.TEX / "world2"
    save(out, w, h, d / "sky_goegap_skyonly_2k.hdr", "HDR")
    save(out, w, h, d / "sky_goegap_skyonly_1k.exr", "OPEN_EXR", size=(1024, 512))
    print("SUN world2", sun_info(a, w, h))


def main():
    for wld, name in SKIES.items():
        a, w, h = load(name)
        if wld == 4:  # volcanic haze: warm the overcast sunset and dim it (baked in, so the phone pays nothing)
            a[..., :3] *= np.array([1.05, 0.80, 0.62], np.float32) * 0.85
        d = A.TEX / f"world{wld}"
        d.mkdir(parents=True, exist_ok=True)
        stem = name.replace("-", "_")
        save(a, w, h, d / f"sky_{stem}_2k.hdr", "HDR")
        save(a, w, h, d / f"sky_{stem}_1k.exr", "OPEN_EXR", size=(1024, 512))
        print(f"SUN world{wld}", name, "u, v_top, elevation:", sun_info(a, w, h))
    skyonly_goegap()


main()
