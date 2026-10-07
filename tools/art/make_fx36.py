#!/usr/bin/env python3
"""Weather and effect sprites for worlds 3-6 (white or tinted RGBA; the particle shader multiplies colour/alpha),
plus the waterfall water strip and a ripple normal for World 5, and ground light pools for World 6.

python3 tools/art/make_fx36.py  -> assets/textures/world3..6/fx_*.png
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
TEX = ROOT / "assets" / "textures"
rng = np.random.default_rng(36)


def value_noise(h, w, cells_y, cells_x, seed=0):
    r = np.random.default_rng(seed)
    g = r.random((cells_y + 1, cells_x + 1))
    g[-1, :] = g[0, :]
    g[:, -1] = g[:, 0]
    ys = np.linspace(0, cells_y, h, endpoint=False)
    xs = np.linspace(0, cells_x, w, endpoint=False)
    yi, xi = ys.astype(int), xs.astype(int)
    ty, tx = ys - yi, xs - xi
    ty = ty * ty * (3 - 2 * ty)
    tx = tx * tx * (3 - 2 * tx)
    a = g[yi][:, xi] * (1 - tx) + g[yi][:, xi + 1] * tx
    b = g[yi + 1][:, xi] * (1 - tx) + g[yi + 1][:, xi + 1] * tx
    return a * (1 - ty)[:, None] + b * ty[:, None]


def fbm(h, w, base_y, base_x, octaves=5, seed=0):
    out = np.zeros((h, w))
    amp = 1.0
    for o in range(octaves):
        out += amp * value_noise(h, w, base_y * 2**o, base_x * 2**o, seed + o)
        amp *= 0.5
    return out / (2 - 2 ** (1 - octaves))


def save(path: Path, alpha, rgb=(1.0, 1.0, 1.0)):
    alpha = np.clip(alpha, 0, 1)
    h, w = alpha.shape
    img = np.zeros((h, w, 4), np.uint8)
    rgb = np.broadcast_to(np.asarray(rgb, np.float32), (h, w, 3)) if np.ndim(rgb) == 1 else rgb
    img[..., :3] = np.clip(np.asarray(rgb) * 255, 0, 255).astype(np.uint8)
    img[..., 3] = (alpha * 255).astype(np.uint8)
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(img, "RGBA").save(path)
    print("fx", path.relative_to(ROOT), img.shape[1], "x", img.shape[0])


n = 128
y, x = np.mgrid[-1 : 1 : n * 1j, -1 : 1 : n * 1j]
r = np.sqrt(x * x + y * y)


def soft_disc(k=1.6):
    return np.clip(1 - r, 0, 1) ** k


# ---------------- World 3 glacier
w3 = TEX / "world3"
flake = np.clip(1 - r * 1.25, 0, 1) ** 1.2
for a in range(3):  # six-armed hint, blurred: at 2-4 cm on screen it reads as a soft flake
    t = a * np.pi / 3
    d = np.abs(x * np.sin(t) - y * np.cos(t))
    flake = np.maximum(flake, np.clip(1 - d * 9, 0, 1) * np.clip(1 - r, 0, 1) * 0.3)
save(w3 / "fx_snowflake.png", flake)
H, Wd = 128, 256
yy, xx = np.mgrid[-1 : 1 : H * 1j, -1 : 1 : Wd * 1j]
spin = fbm(H, Wd, 2, 6, seed=3) * np.clip(1 - np.abs(yy) ** 2, 0, 1) * np.clip(1 - np.abs(xx) ** 3, 0, 1)
save(w3 / "fx_spindrift.png", np.clip(spin * 1.4 - 0.25, 0, 1))  # wind-blown snow off ridges
glare = np.clip(1 - r, 0, 1) ** 3 * 0.9 + np.clip(1 - r * 4, 0, 1) ** 2
for t in (0, np.pi / 2):  # soft 4-point streak, 6% of screen: never a full flash
    d = np.abs(x * np.sin(t) - y * np.cos(t))
    glare += np.clip(1 - d * 30, 0, 1) * np.clip(1 - r, 0, 1) ** 2 * 0.5
save(w3 / "fx_sun_glare.png", np.clip(glare, 0, 1), (1.0, 0.97, 0.92))

# ---------------- World 4 ash mountain
w4 = TEX / "world4"
ash = np.clip(1 - (np.abs(x) * 1.1 + np.abs(y) * 1.6), 0, 1) ** 0.8 * (0.6 + 0.4 * fbm(n, n, 3, 3, seed=8))
save(w4 / "fx_ash_flake.png", ash, (0.30, 0.29, 0.28))
save(w4 / "fx_ember.png", np.clip(1 - r * 1.3, 0, 1) ** 2.5, (1.0, 0.55, 0.18))
smoke = soft_disc(1.3) * (0.35 + 0.65 * fbm(n, n, 3, 3, seed=11))
save(w4 / "fx_smoke.png", smoke, (0.42, 0.40, 0.38))
steam = soft_disc(1.1) * (0.45 + 0.55 * fbm(n, n, 4, 4, seed=12))
save(w4 / "fx_steam_puff.png", steam, (0.93, 0.93, 0.92))
H, Wd = 512, 256  # tall plume card for the crater: wider and thinner at the top
yy, xx = np.mgrid[0:1 : H * 1j, -1 : 1 : Wd * 1j]
width = 0.3 + 0.7 * (1 - yy) ** 0.7
plume = np.clip(1 - np.abs(xx) / width, 0, 1) ** 1.5 * fbm(H, Wd, 6, 3, seed=13) * np.clip(yy * 6, 0, 1) * np.clip((1 - yy) * 3, 0, 1)
save(w4 / "fx_smoke_plume.png", np.clip(plume * 2.6, 0, 1), (0.36, 0.34, 0.33))

# ---------------- World 5 rainforest
w5 = TEX / "world5"
H, Wd = 128, 16
yy, xx = np.mgrid[-1 : 1 : H * 1j, -1 : 1 : Wd * 1j]
save(w5 / "fx_rain_streak.png", np.clip(1 - np.abs(xx) * 1.2, 0, 1) ** 2 * np.clip(1 - np.abs(yy), 0, 1) ** 0.7 * 0.8,
     (0.85, 0.9, 0.95))
save(w5 / "fx_mist.png", soft_disc(1.2) * (0.4 + 0.6 * fbm(n, n, 3, 3, seed=21)), (0.9, 0.93, 0.92))
save(w5 / "fx_spray.png", soft_disc(0.9) * (0.3 + 0.7 * fbm(n, n, 6, 6, seed=22)), (0.95, 0.97, 1.0))
# butterfly: 2 frames side by side (wings open / half closed), blue morpho with dark rims
B = 128
fr = []
for open_k in (1.0, 0.45):
    yy, xx = np.mgrid[-1 : 1 : B * 1j, -1 : 1 : B * 1j]
    ax = np.abs(xx) / open_k
    wing_up = ((ax - 0.45) ** 2 / 0.2 + (yy + 0.25) ** 2 / 0.25) < 1
    wing_lo = ((ax - 0.35) ** 2 / 0.11 + (yy - 0.35) ** 2 / 0.12) < 1
    body = (np.abs(xx) < 0.05) & (np.abs(yy) < 0.6)
    m = (wing_up | wing_lo) & (np.abs(xx) < open_k * 0.95)
    rim = m & ~(((ax - 0.42) ** 2 / 0.14 + (yy + 0.22) ** 2 / 0.18) < 1) & ~(((ax - 0.33) ** 2 / 0.06 + (yy - 0.33) ** 2 / 0.07) < 1)
    rgb = np.zeros((B, B, 3), np.float32)
    rgb[m] = (0.12, 0.45, 0.85)
    rgb[rim] = (0.06, 0.06, 0.07)
    rgb[body] = (0.08, 0.07, 0.06)
    fr.append((rgb, (m | body).astype(np.float32)))
rgb = np.concatenate([f[0] for f in fr], 1)
alpha = np.concatenate([f[1] for f in fr], 1)
save(w5 / "fx_butterfly.png", alpha, rgb)

# waterfall water strip: tiles in V (flow direction); scroll V at 1.6 tiles/s in the shader
H, Wd = 1024, 256
streaks = fbm(H, Wd, 4, 24, seed=31)  # long vertical streaks: few cells along V, many along U
streaks = np.clip((streaks - 0.35) * 2.2, 0, 1)
foam = fbm(H, Wd, 16, 16, seed=32)
alpha = np.clip(0.35 + 0.65 * streaks, 0, 1) * (0.75 + 0.25 * foam)
col = np.stack([0.78 + 0.2 * streaks, 0.84 + 0.15 * streaks, 0.86 + 0.13 * streaks], -1)
save(w5 / "waterfall_water_albedo.png", alpha, col)
hgt = fbm(256, 256, 8, 8, seed=33)
gy, gx = np.gradient(hgt)
nrm = np.stack([-gx * 6, -gy * 6, np.ones_like(gx)], -1)
nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
Image.fromarray(((nrm * 0.5 + 0.5) * 255).astype(np.uint8)).save(w5 / "water_ripple_normal.png")
print("fx", "assets/textures/world5/water_ripple_normal.png")

# ---------------- World 6 night harbour
w6 = TEX / "world6"
H, Wd = 64, 8
yy, xx = np.mgrid[-1 : 1 : H * 1j, -1 : 1 : Wd * 1j]
save(w6 / "fx_drizzle.png", np.clip(1 - np.abs(xx), 0, 1) ** 2 * np.clip(1 - np.abs(yy), 0, 1) * 0.6, (0.9, 0.85, 0.75))
save(w6 / "fx_sodium_glow.png", np.clip(1 - r, 0, 1) ** 2.2 * 0.9 + np.clip(1 - r * 5, 0, 1) * 0.6, (1.0, 0.62, 0.22))
save(w6 / "fx_warning_light.png", np.clip(1 - r, 0, 1) ** 3 + np.clip(1 - r * 6, 0, 1), (1.0, 0.18, 0.1))
# ground light pool under a sodium lamp (additive decal): warm centre, long soft falloff
pool = np.clip(1 - r, 0, 1) ** 1.8
save(w6 / "fx_light_pool.png", pool * 0.85, (1.0, 0.66, 0.30))
# wet-ground streak reflection of a lamp (vertical smear on wet asphalt, additive, camera-facing card)
H, Wd = 256, 64
yy, xx = np.mgrid[0:1 : H * 1j, -1 : 1 : Wd * 1j]
refl = np.clip(1 - np.abs(xx) * 1.3, 0, 1) ** 2 * (1 - yy) ** 1.5 * (0.6 + 0.4 * fbm(H, Wd, 16, 2, seed=41))
save(w6 / "fx_wet_reflection.png", refl, (1.0, 0.62, 0.28))
