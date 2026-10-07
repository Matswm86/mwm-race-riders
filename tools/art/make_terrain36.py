#!/usr/bin/env python3
"""Terrain texture sets for worlds 3-6 (and the new World 2 canyon-wall layer), from CC0 scans.

Per layer: terrain_<name>_albedo.jpg (1024, sRGB, tint baked in), terrain_<name>_normal.jpg (512, OpenGL),
terrain_<name>_arm.jpg (512, R = AO, G = roughness, B = metal). Same names and channel layout as worlds 1-2,
so RrWorld._terrain_material() can load them unchanged.

python3 -I tools/art/make_terrain36.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PH = ROOT / "assets/_raw/polyhaven/textures"
ACG = ROOT / "assets/_raw/ambientcg"
TEX = ROOT / "assets/textures"


def ph(name: str) -> dict:
    d = PH / name
    return {
        "albedo": d / f"{name}_diffuse_1k.jpg",
        "normal": d / f"{name}_nor_gl_1k.jpg",
        "arm": d / f"{name}_arm_1k.jpg",
        "rough": d / f"{name}_rough_1k.jpg",
    }


def acg(name: str) -> dict:
    d = ACG / name
    ao = d / f"{name}_1K-JPG_AmbientOcclusion.jpg"
    return {
        "albedo": d / f"{name}_1K-JPG_Color.jpg",
        "normal": d / f"{name}_1K-JPG_NormalGL.jpg",
        "rough": d / f"{name}_1K-JPG_Roughness.jpg",
        "ao": ao if ao.exists() else None,
    }


def load(p: Path, size: int, mode="RGB") -> np.ndarray:
    im = Image.open(p).convert(mode)
    if im.size != (size, size):
        im = im.resize((size, size), Image.LANCZOS)
    return np.asarray(im).astype(np.float32) / 255.0


def save_jpg(a: np.ndarray, p: Path, q: int = 90) -> None:
    Image.fromarray(np.clip(a * 255 + 0.5, 0, 255).astype(np.uint8)).save(p, quality=q)


def layer(
    world: int,
    name: str,
    src: dict,
    tint=(1, 1, 1),
    gamma: float = 1.0,
    sat: float = 1.0,
    rough_mul: float = 1.0,
    rough_add: float = 0.0,
    flatten_normal: float = 1.0,
    contrast: float = 1.0,
    post=None,
) -> None:
    out = TEX / f"world{world}"
    out.mkdir(parents=True, exist_ok=True)
    a = load(src["albedo"], 1024)
    if sat != 1.0:
        g = a.mean(-1, keepdims=True)
        a = g + (a - g) * sat
    if contrast != 1.0:
        mu = a.reshape(-1, 3).mean(0)
        a = mu + (a - mu) * contrast
    a = np.clip(a, 0, 1) ** gamma * np.array(tint, np.float32)
    n = load(src["normal"], 512)
    if post is not None:
        a, n = post(a, n)
    save_jpg(np.clip(a, 0, 1), out / f"terrain_{name}_albedo.jpg")
    if flatten_normal != 1.0:
        v = n * 2 - 1
        v[..., :2] *= flatten_normal
        v /= np.linalg.norm(v, axis=-1, keepdims=True)
        n = v * 0.5 + 0.5
    save_jpg(n, out / f"terrain_{name}_normal.jpg", 92)
    if src.get("arm") and Path(src["arm"]).exists():
        arm = load(src["arm"], 512)
    else:
        r = load(src["rough"], 512, "L")
        ao = load(src["ao"], 512, "L") if src.get("ao") else np.ones_like(r)
        arm = np.stack([ao, r, np.zeros_like(r)], -1)
    arm[..., 1] = np.clip(arm[..., 1] * rough_mul + rough_add, 0.02, 1)
    save_jpg(arm, out / f"terrain_{name}_arm.jpg", 92)
    m = (a.reshape(-1, 3).mean(0) * 255).astype(int)
    print(f"world{world} terrain_{name}: mean albedo #{m[0]:02X}{m[1]:02X}{m[2]:02X}")


def _resample(arr: np.ndarray, size: int) -> np.ndarray:
    im = Image.fromarray(np.clip(arr * 255, 0, 255).astype(np.uint8))
    return np.asarray(im.resize((size, size), Image.LANCZOS)).astype(np.float32) / 255.0


def strata(a: np.ndarray, n: np.ndarray):
    """Horizontal sandstone beds: rows = world height in world-aligned triplanar (texture v = up).
    Beds of 0.3-1.6 m (tile 9 m), tone and hardness vary per bed; hard beds stand out as small ledges."""
    rng = np.random.default_rng(11)
    h = a.shape[0]
    edges, y = [0], 0
    while y < h:
        y += int(rng.uniform(0.035, 0.18) * h)
        edges.append(min(y, h))
    tone = np.ones(h, np.float32)
    ledge = np.zeros(h, np.float32)
    for i in range(len(edges) - 1):
        y0, y1 = edges[i], edges[i + 1]
        t = rng.uniform(0.84, 1.14)
        tone[y0:y1] = t
        k = max(1, (y1 - y0) // 10)
        ledge[y0 : y0 + k] = 1.0 if t > 1.0 else 0.4
    xs = np.arange(h)
    wob = (np.sin(xs / h * 2 * np.pi * 2) * 0.012 * h + np.sin(xs / h * 2 * np.pi * 5 + 1) * 0.004 * h).astype(int)
    rows = (np.arange(h)[:, None] + wob[None, :]) % h
    T = tone[rows][..., None]
    hue = np.stack([T[..., 0], T[..., 0] ** 1.15, T[..., 0] ** 1.3], -1)  # pale beds are also less red
    a = np.clip(a * hue, 0, 1)
    L = ledge[rows]
    a = a * (1 - 0.22 * L[..., None])  # shadow line under each bed lip
    nn = n.shape[0]
    Ls = _resample(np.repeat(L[..., None], 3, -1), nn)[..., 0]
    v = n * 2 - 1
    v[..., 1] += 0.55 * Ls  # lip faces up (OpenGL green = +v)
    v /= np.linalg.norm(v, axis=-1, keepdims=True)
    return a, v * 0.5 + 0.5


def corduroy(a: np.ndarray, n: np.ndarray):
    """Groomed piste: fine snow-cat corduroy ribs along the texture v axis (lay v along the track)."""
    h = a.shape[1]
    x = np.arange(h) / h
    rib = np.sin(x * 2 * np.pi * 96)  # 96 ribs per tile; at a 3 m tile = 3.1 cm ribs (real: 2-4 cm)
    a = a * (0.93 + 0.05 * rib)[None, :, None]
    nn = n.shape[1]
    xn = np.arange(nn) / nn
    d = np.cos(xn * 2 * np.pi * 96) * 0.35
    v = n * 2 - 1
    v[..., 0] += d[None, :]
    v /= np.linalg.norm(v, axis=-1, keepdims=True)
    return a, v * 0.5 + 0.5


def snowcat(a: np.ndarray, n: np.ndarray):
    """snow_04 tread marks re-coloured from mud to compacted, shadowed snow."""
    lum = a.mean(-1, keepdims=True)
    packed = np.array([0.66, 0.72, 0.80], np.float32)
    white = np.array([0.90, 0.92, 0.96], np.float32)
    k = np.clip((lum - 0.25) / 0.55, 0, 1)
    return packed * (1 - k) + white * k, n


def main() -> None:
    # World 2 fix: a layered sandstone wall that tiles cleanly in world-aligned triplanar (strata stay level)
    layer(2, "canyon_wall", ph("cliff_side"), post=strata)  # the approved cliff scan + level beds
    # World 3 Glacier Run
    layer(3, "snow_groomed", ph("snow_02"), tint=(1.30, 1.33, 1.40), flatten_normal=0.6, contrast=0.3, post=corduroy)
    layer(3, "snowcat_tracks", ph("snow_04"), post=snowcat)
    layer(3, "snow", ph("snow_02"), tint=(1.36, 1.38, 1.42), contrast=0.4)
    layer(3, "snow_wind", ph("snow_field_aerial"), tint=(1.55, 1.58, 1.62), sat=0.3)
    layer(3, "glacier_rock", acg("Rock030"), tint=(0.78, 0.82, 0.88), sat=0.2)
    layer(3, "blue_ice", acg("Ice003"), tint=(0.78, 1.0, 1.22), sat=0.7, gamma=0.62, rough_mul=0.35)
    # World 4 Ash Mountain
    layer(4, "ash_trail", ph("low_tide_rocks"), tint=(0.92, 0.88, 0.84), sat=0.45, gamma=1.0)  # grey packed ash: racers must read on it
    layer(4, "ash", ph("burned_ground_01"), tint=(0.55, 0.53, 0.52), sat=0.15, gamma=1.1)
    layer(4, "ash_soft", ph("low_tide_rocks"), tint=(0.80, 0.78, 0.76), sat=0.3, flatten_normal=0.5)
    layer(4, "basalt", acg("Rock035"), tint=(2.1, 2.1, 2.2), sat=0.0, gamma=0.9, contrast=0.45)
    layer(4, "lava_crust", acg("Lava001"), tint=(0.95, 0.9, 0.9), sat=0.12, contrast=0.6)  # no glow on the track
    # World 5 Rainforest (after rain: roughness down)
    layer(5, "mud_wet", ph("mud_forest"), tint=(0.95, 0.92, 0.88), rough_mul=0.55)
    layer(5, "forest_moss", ph("forest_leaves_02"), tint=(0.92, 1.0, 0.86), rough_mul=0.8)
    layer(5, "mud_leaves", ph("brown_mud_leaves_01"), rough_mul=0.6)
    layer(5, "mossy_rock", ph("mossy_rock"), rough_mul=0.75)
    layer(5, "river_stones", ph("river_small_rocks"), rough_mul=0.4)
    # World 6 Night Harbour (wet: roughness 0.2-0.35 on flat ground)
    layer(6, "asphalt_wet", ph("asphalt_02"), tint=(0.78, 0.78, 0.8), rough_mul=0.45)
    layer(6, "quay_concrete", ph("concrete_floor_worn_001"), tint=(0.8, 0.8, 0.8), rough_mul=0.55)
    layer(6, "quay_wall", ph("concrete_wall_003"), tint=(0.62, 0.62, 0.6), sat=0.4)
    layer(6, "steel_plate", ph("metal_plate"), tint=(1.25, 1.25, 1.28), sat=0.35, rough_mul=0.5)


if __name__ == "__main__":
    main()
