#!/usr/bin/env python3
"""Race HUD (GDD 10.1 positions) over a raw mock render, in the realistic style: solid dark discs, white
icons, amber for "speed for you", rider-colour tokens with numbers. Prints contrast numbers (my calc).

python3 tools/art/hud_overlay.py raw.png out.png --place 4 --progress 0.21 [--time 0:12.4] [--zones zones.png]
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
F_BOLD = str(ROOT / "assets/fonts/BarlowCondensed-Bold.ttf")
F_XBI = str(ROOT / "assets/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
F_SEMI = str(ROOT / "assets/fonts/BarlowCondensed-SemiBold.ttf")

INK = (20, 23, 28)  # #14171C disc fill
WHITE = (255, 255, 255)
AMBER = (255, 176, 0)  # #FFB000
TRACK = (255, 255, 255)
PLACE = {
    1: (242, 193, 78),
    2: (201, 206, 214),
    3: (201, 138, 85),
}  # gold, silver, bronze; 4-6 white
RIDERS = [
    ("r1", 7, "#C8202B"),
    ("r2", 12, "#F2A900"),
    ("r3", 23, "#1E5BD6"),
    ("r4", 31, "#0F8F6E"),
    ("r5", 4, "#E9ECEF"),
    ("r6", 88, "#2A2E35"),
]


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def lum(c):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

    r, g, b = c[:3]
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def contrast(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def soft_shadow(base: Image.Image, shape_fn, blur=10, alpha=110, offset=(0, 4)):
    sh = Image.new("L", base.size, 0)
    shape_fn(ImageDraw.Draw(sh), offset)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    black = Image.new("RGBA", base.size, (0, 0, 0, 0))
    black.putalpha(sh.point(lambda v: v * alpha // 255))
    base.alpha_composite(black)


def disc(d: ImageDraw.ImageDraw, c, r, fill, ring=None, ring_w=4):
    x, y = c
    d.ellipse((x - r, y - r, x + r, y + r), fill=fill)
    if ring:
        d.ellipse((x - r, y - r, x + r, y + r), outline=ring, width=ring_w)


def gear_icon(d, c, r, col):
    x, y = c
    teeth = 8
    pts = []
    for i in range(teeth * 2):
        a = math.pi * i / teeth
        rr = r if i % 2 == 0 else r * 0.78
        for da in (-0.17, 0.17):
            pts.append((x + math.cos(a + da) * rr, y + math.sin(a + da) * rr))
    d.polygon(pts, fill=col)
    d.ellipse((x - r * 0.36, y - r * 0.36, x + r * 0.36, y + r * 0.36), fill=INK)


def home_icon(d, c, s, col):
    x, y = c
    d.polygon([(x - s, y - 2), (x, y - s), (x + s, y - 2)], fill=col)
    d.rectangle((x - s * 0.68, y - 4, x + s * 0.68, y + s * 0.8), fill=col)
    d.rectangle((x - s * 0.18, y + s * 0.2, x + s * 0.18, y + s * 0.8), fill=INK)


def bolt(d, c, s, col):
    x, y = c
    p = [
        (x + 0.10 * s, y - 0.95 * s),
        (x - 0.45 * s, y + 0.12 * s),
        (x - 0.02 * s, y + 0.12 * s),
        (x - 0.14 * s, y + 0.95 * s),
        (x + 0.45 * s, y - 0.18 * s),
        (x + 0.02 * s, y - 0.18 * s),
    ]
    d.polygon(p, fill=col)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("raw")
    ap.add_argument("out")
    ap.add_argument("--place", type=int, default=4)
    ap.add_argument("--progress", type=float, default=0.21)
    ap.add_argument("--rivals", default="0.29,0.25,0.235,0.18,0.15")
    ap.add_argument("--time", default="")
    ap.add_argument("--charge", type=float, default=0.7)
    ap.add_argument("--zones", default="")
    ap.add_argument("--player", default="r1")
    a = ap.parse_args()
    raw = Image.open(a.raw).convert("RGBA")
    if raw.size != (1080, 1920):
        raw = raw.resize((1080, 1920), Image.LANCZOS)
    bg = raw.copy()
    img = raw.copy()
    # ---- top band: home (stand-alone build only) and gear
    for c, kind in (((104, 104), "home"), ((976, 104), "gear")):
        soft_shadow(
            img,
            lambda dd, o, c=c: dd.ellipse(
                (c[0] - 68 + o[0], c[1] - 68 + o[1], c[0] + 68 + o[0], c[1] + 68 + o[1]), fill=255
            ),
        )
        d = ImageDraw.Draw(img)
        disc(d, c, 68, INK + (235,), ring=(255, 255, 255, 235), ring_w=4)
        if kind == "home":
            home_icon(d, c, 30, WHITE)
        else:
            gear_icon(d, c, 34, WHITE)
    # ---- progress bar x 260-820, y 250-286
    x0, x1, yc, h = 260, 820, 268, 14
    soft_shadow(
        img,
        lambda dd, o: dd.rounded_rectangle(
            (x0 - 6 + o[0], yc - 13 + o[1], x1 + 6 + o[0], yc + 13 + o[1]), radius=13, fill=255
        ),
        blur=8,
    )
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((x0 - 6, yc - 13, x1 + 6, yc + 13), radius=13, fill=INK + (225,))
    d.rounded_rectangle((x0, yc - h // 2, x1, yc + h // 2), radius=7, fill=(255, 255, 255, 70))
    px = x0 + (x1 - x0) * a.progress
    d.rounded_rectangle((x0, yc - h // 2, px, yc + h // 2), radius=7, fill=AMBER + (255,))
    # finish flag (chequered square on a pole) at the right end
    fx = x1 + 30
    d.rectangle((fx - 2, yc - 34, fx + 2, yc + 20), fill=WHITE)
    for j in range(3):
        for i in range(4):
            col = WHITE if (i + j) % 2 == 0 else INK
            d.rectangle(
                (fx + 2 + i * 9, yc - 34 + j * 9, fx + 2 + (i + 1) * 9, yc - 34 + (j + 1) * 9),
                fill=col,
            )
    # rider tokens (rivals first, player last and 1.5x)
    font_s = ImageFont.truetype(F_BOLD, 22)
    font_l = ImageFont.truetype(F_BOLD, 32)
    rv = [float(v) for v in a.rivals.split(",")]
    others = [r for r in RIDERS if r[0] != a.player]
    for (rid, num, hx), p in zip(others, rv):
        cx = x0 + (x1 - x0) * p
        col = hexrgb(hx)
        disc(d, (cx, yc), 17, col + (255,), ring=(20, 23, 28, 255), ring_w=3)
        txt_col = INK if lum(col) > 0.35 else WHITE
        d.text((cx, yc + 1), str(num), font=font_s, fill=txt_col, anchor="mm")
    me = next(r for r in RIDERS if r[0] == a.player)
    col = hexrgb(me[2])
    soft_shadow(
        img,
        lambda dd, o: dd.ellipse(
            (px - 27 + o[0], yc - 27 + o[1], px + 27 + o[0], yc + 27 + o[1]), fill=255
        ),
        blur=6,
    )
    d = ImageDraw.Draw(img)
    disc(d, (px, yc), 26, col + (255,), ring=WHITE + (255,), ring_w=5)
    d.text(
        (px, yc + 1), str(me[1]), font=font_l, fill=WHITE if lum(col) < 0.35 else INK, anchor="mm"
    )
    d.polygon([(px - 11, yc + 30), (px + 11, yc + 30), (px, yc + 42)], fill=WHITE)
    # ---- place badge dia 110 at (540, 350)
    pc = (540, 350)
    soft_shadow(
        img,
        lambda dd, o: dd.ellipse(
            (pc[0] - 55 + o[0], pc[1] - 55 + o[1], pc[0] + 55 + o[0], pc[1] + 55 + o[1]), fill=255
        ),
    )
    d = ImageDraw.Draw(img)
    fill = PLACE.get(a.place, (255, 255, 255))
    disc(d, pc, 55, fill + (255,), ring=INK + (255,), ring_w=5)
    d.ellipse(
        (pc[0] - 45, pc[1] - 45, pc[0] + 45, pc[1] + 45), outline=(255, 255, 255, 120), width=2
    )
    fp = ImageFont.truetype(F_XBI, 84)
    d.text((pc[0] + 1, pc[1] + 3), str(a.place), font=fp, fill=INK, anchor="mm")
    # ---- race time (Vanlig only) at (780, 350)
    if a.time:
        ft = ImageFont.truetype(F_SEMI, 40)
        bb = d.textbbox((780, 350), a.time, font=ft, anchor="mm")
        d.rounded_rectangle(
            (bb[0] - 14, bb[1] - 8, bb[2] + 14, bb[3] + 8), radius=10, fill=INK + (200,)
        )
        d.text((780, 350), a.time, font=ft, fill=WHITE, anchor="mm")
    # ---- boost disc centre (540, 1490), dia 220
    bc, br = (540, 1490), 110
    soft_shadow(
        img,
        lambda dd, o: dd.ellipse(
            (bc[0] - br + o[0], bc[1] - br + o[1], bc[0] + br + o[0], bc[1] + br + o[1]), fill=255
        ),
        blur=12,
        alpha=130,
    )
    d = ImageDraw.Draw(img)
    disc(d, bc, br, INK + (230,), ring=WHITE + (235,), ring_w=4)
    d.ellipse(
        (bc[0] - br + 10, bc[1] - br + 10, bc[0] + br - 10, bc[1] + br - 10),
        outline=(255, 255, 255, 60),
        width=14,
    )
    d.arc(
        (bc[0] - br + 10, bc[1] - br + 10, bc[0] + br - 10, bc[1] + br - 10),
        -90,
        -90 + 360 * a.charge,
        fill=AMBER + (255,),
        width=14,
    )
    bolt(d, bc, 56, WHITE)
    img = img.convert("RGB")
    img.save(a.out)

    # ---- contrast (my calc) against the pixels behind each element in the raw render
    def avg(box):
        crop = bg.crop(box).convert("RGB").resize((1, 1), Image.BOX)
        return crop.getpixel((0, 0))

    rows = [
        ("white icon on ink disc", WHITE, INK),
        ("ink disc vs sky/forest behind gear", INK, avg((900, 30, 1050, 180))),
        ("white ring vs background behind gear", WHITE, avg((900, 30, 1050, 180))),
        ("amber fill vs ink bar", AMBER, INK),
        ("ink bar vs background behind bar", INK, avg((260, 240, 820, 296))),
        ("ink digit on place disc", INK, fill),
        ("place disc vs background behind it", fill, avg((485, 295, 595, 405))),
        ("amber charge ring vs ink disc", AMBER, INK),
        ("ink boost disc vs track behind it", INK, avg((430, 1380, 650, 1600))),
        ("white boost ring vs track behind it", WHITE, avg((430, 1380, 650, 1600))),
        ("white bolt on ink disc", WHITE, INK),
    ]
    for name, c1, c2 in rows:
        print(f"CONTRAST {name}: {contrast(c1, c2):.1f}:1 (my calc) bg={c2}")
    if a.zones:
        z = img.convert("RGBA")
        zd = ImageDraw.Draw(z, "RGBA")
        zd.rectangle((0, 0, 232, 232), outline=(255, 255, 255, 255), width=4)
        zd.rectangle((848, 0, 1080, 232), outline=(60, 220, 120, 255), width=4)
        zd.ellipse(
            (540 - 140, 1490 - 140, 540 + 140, 1490 + 140), outline=(60, 220, 120, 255), width=4
        )
        ov = Image.new("RGBA", z.size, (0, 0, 0, 0))
        ImageDraw.Draw(ov).rectangle((0, 1664, 1080, 1920), fill=(230, 40, 40, 90))
        z.alpha_composite(ov)
        z.convert("RGB").save(a.zones)


if __name__ == "__main__":
    main()
