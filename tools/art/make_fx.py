#!/usr/bin/env python3
"""FX sprites (shared by every world): dust puff, sand streak, pollen dot, speed streak, soft contact shadow.
python3 tools/art/make_fx.py  -> assets/textures/fx/*.png (RGBA, white/tinted in the shader)
"""

from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "assets" / "textures" / "fx"
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(4)


def fbm(n, octaves=5):
    out = np.zeros((n, n))
    for o in range(octaves):
        f = 2 ** (o + 2)
        g = rng.random((f + 1, f + 1))
        xs = np.linspace(0, f, n, endpoint=False)
        xi = xs.astype(int)
        t = xs - xi
        t = t * t * (3 - 2 * t)
        a = g[xi][:, xi] * (1 - t)[None, :] + g[xi][:, xi + 1] * t[None, :]
        b = g[xi + 1][:, xi] * (1 - t)[None, :] + g[xi + 1][:, xi + 1] * t[None, :]
        out += (a * (1 - t)[:, None] + b * t[:, None]) / 2**o
    return out / out.max()


def save(name, alpha, rgb=(1, 1, 1)):
    n = alpha.shape[0]
    img = np.zeros((n, n, 4), np.uint8)
    img[..., 0] = int(rgb[0] * 255)
    img[..., 1] = int(rgb[1] * 255)
    img[..., 2] = int(rgb[2] * 255)
    img[..., 3] = np.clip(alpha * 255, 0, 255).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(OUT / name)


n = 256
y, x = np.mgrid[-1 : 1 : n * 1j, -1 : 1 : n * 1j]
r = np.sqrt(x * x + y * y)
save("dust_puff.png", np.clip(1 - r, 0, 1) ** 1.6 * (0.45 + 0.55 * fbm(n)))
save("contact_shadow.png", np.clip(1 - r, 0, 1) ** 1.8 * 0.85, (0, 0, 0))
save("pollen.png", np.clip(1 - r * 1.4, 0, 1) ** 2)
streak = np.clip(1 - np.abs(y) * 6, 0, 1) * np.clip(1 - np.abs(x), 0, 1) ** 0.6
save("speed_streak.png", streak)
sand = np.clip(1 - np.abs(y) * 3, 0, 1) * (0.3 + 0.7 * fbm(n)) * np.clip(1 - np.abs(x) ** 2, 0, 1)
save("sand_streak.png", sand)
print("fx ok", sorted(p.name for p in OUT.iterdir()))
