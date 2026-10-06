#!/usr/bin/env python3
"""Race HUD sprite atlas (DESIGN 3-5), drawn with the same shapes as the approved mock overlay
(tools/art/hud_overlay.py): ink discs with the 4 px white ring and a soft drop shadow, place discs,
rider tokens with numbers, the boost disc, flag, hands, arrows, lamps. The game draws every HUD
sprite from this one texture, so the HUD batches into a few draw calls (QA finding 2).

python3 tools/art/make_hud_atlas.py   ->  assets/textures/ui/hud_atlas.png

The rects are mirrored in scripts/RrHudAtlas.gd (SPRITES); keep both in step.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import hud_overlay as H  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/textures/ui/hud_atlas.png"
INK = H.INK
WHITE = H.WHITE
AMBER = H.AMBER

# name: (x, y, w, h, anchor_x, anchor_y) in atlas px; anchor = the point placed at the HUD position
SPRITES = {
    "home": (0, 0, 184, 188, 92, 92),
    "gear": (184, 0, 184, 188, 92, 92),
    "boost": (368, 0, 290, 296, 145, 145),
    "boost_full": (660, 0, 224, 224, 112, 112),
    "place1": (0, 300, 150, 154, 75, 75),
    "place2": (150, 300, 150, 154, 75, 75),
    "place3": (300, 300, 150, 154, 75, 75),
    "place4": (450, 300, 150, 154, 75, 75),
    "place5": (600, 300, 150, 154, 75, 75),
    "place6": (750, 300, 150, 154, 75, 75),
    "bar": (0, 460, 600, 60, 18, 17),
    "flag": (610, 460, 48, 64, 6, 44),
    "tok0": (0, 530, 40, 40, 20, 20),
    "tok1": (40, 530, 40, 40, 20, 20),
    "tok2": (80, 530, 40, 40, 20, 20),
    "tok3": (120, 530, 40, 40, 20, 20),
    "tok4": (160, 530, 40, 40, 20, 20),
    "tok5": (200, 530, 40, 40, 20, 20),
    "player0": (250, 524, 76, 96, 38, 36),
    "knock1": (340, 530, 70, 70, 35, 35),
    "knock2": (410, 530, 70, 70, 35, 35),
    "knock3": (480, 530, 70, 70, 35, 35),
    "knock4": (550, 530, 70, 70, 35, 35),
    "knock5": (620, 530, 70, 70, 35, 35),
    "hand": (0, 630, 190, 230, 95, 14),
    "arrow_l": (196, 630, 150, 230, 75, 115),
    "arrow_r": (350, 630, 150, 230, 75, 115),
    "chevron": (504, 630, 96, 60, 48, 30),
    "star": (600, 700, 116, 116, 58, 58),
    "lamp_off": (720, 630, 100, 100, 50, 50),
    "lamp_amber": (820, 630, 100, 100, 50, 50),
    "lamp_green": (920, 630, 100, 100, 50, 50),
    "lights_bg": (0, 870, 420, 150, 210, 75),
    "chip": (430, 870, 190, 70, 95, 35),
    "dot": (640, 870, 16, 16, 8, 8),
    "ghost_icon": (680, 870, 120, 120, 60, 60),
}


def shadow(img, box, shape, blur=10, alpha=115, off=4, radius=0):
    x0, y0, w, h = box
    layer = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(layer)
    shape(d, off)
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    blk = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    blk.putalpha(layer.point(lambda v: v * alpha // 255))
    img.alpha_composite(blk, (x0, y0))


def sub(img, name):
    x, y, w, h, ax, ay = SPRITES[name]
    return (x, y, w, h), (x + ax, y + ay)


def disc_icon(img, name, kind):
    box, c = sub(img, name)
    r = 68
    lx, ly = c[0] - box[0], c[1] - box[1]
    shadow(img, box, lambda d, o: d.ellipse((lx - r, ly - r + o, lx + r, ly + r + o), fill=255))
    d = ImageDraw.Draw(img)
    H.disc(d, c, r, INK + (235,), ring=(255, 255, 255, 235), ring_w=4)
    if kind == "home":
        H.home_icon(d, c, 30, WHITE)
    else:
        H.gear_icon(d, c, 34, WHITE)


def boost(img):
    box, c = sub(img, "boost")
    br = 110
    lx, ly = c[0] - box[0], c[1] - box[1]
    shadow(
        img,
        box,
        lambda d, o: d.ellipse((lx - br, ly - br + o, lx + br, ly + br + o), fill=255),
        blur=12,
        alpha=130,
    )
    d = ImageDraw.Draw(img)
    H.disc(d, c, br, INK + (232,), ring=WHITE + (240,), ring_w=4)
    d.ellipse(
        (c[0] - br + 10, c[1] - br + 10, c[0] + br - 10, c[1] + br - 10),
        outline=(255, 255, 255, 62),
        width=14,
    )
    H.bolt(d, c, 56, WHITE)
    _, c2 = sub(img, "boost_full")
    d.ellipse(
        (c2[0] - br + 10, c2[1] - br + 10, c2[0] + br - 10, c2[1] + br - 10),
        outline=AMBER + (255,),
        width=14,
    )


def place(img, n):
    box, c = sub(img, f"place{n}")
    lx, ly = c[0] - box[0], c[1] - box[1]
    shadow(img, box, lambda d, o: d.ellipse((lx - 55, ly - 55 + o, lx + 55, ly + 55 + o), fill=255))
    d = ImageDraw.Draw(img)
    fill = H.PLACE.get(n, (255, 255, 255))
    H.disc(d, c, 55, fill + (255,), ring=INK + (255,), ring_w=5)
    d.ellipse((c[0] - 45, c[1] - 45, c[0] + 45, c[1] + 45), outline=(255, 255, 255, 120), width=2)
    fp = ImageFont.truetype(H.F_XBI, 84)
    d.text((c[0] + 1, c[1] + 3), str(n), font=fp, fill=INK, anchor="mm")


def bar(img):
    box, a = sub(img, "bar")
    x0, y0 = a  # top-left of the ink bar
    w, h = 572, 26
    lx, ly = x0 - box[0], y0 - box[1]
    shadow(
        img,
        box,
        lambda d, o: d.rounded_rectangle((lx, ly + o, lx + w, ly + h + o), radius=13, fill=255),
        blur=8,
    )
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((x0, y0, x0 + w, y0 + h), radius=13, fill=INK + (225,))
    d.rounded_rectangle((x0 + 6, y0 + 6, x0 + w - 6, y0 + 20), radius=7, fill=(255, 255, 255, 70))
    _, f = sub(img, "flag")
    fx, fy = f  # pole foot
    d.rectangle((fx - 2, fy - 54, fx + 2, fy), fill=WHITE)
    for j in range(3):
        for i in range(4):
            col = WHITE if (i + j) % 2 == 0 else INK
            d.rectangle(
                (fx + 2 + i * 9, fy - 54 + j * 9, fx + 2 + (i + 1) * 9, fy - 54 + (j + 1) * 9),
                fill=col,
            )


def tokens(img):
    fs = ImageFont.truetype(H.F_BOLD, 22)
    fl = ImageFont.truetype(H.F_BOLD, 32)
    for i, (rid, num, hx) in enumerate(H.RIDERS):
        col = H.hexrgb(hx)
        _, c = sub(img, f"tok{i}")
        d = ImageDraw.Draw(img)
        H.disc(d, c, 17, col + (255,), ring=INK + (255,), ring_w=3)
        d.text(
            (c[0], c[1] + 1),
            str(num),
            font=fs,
            fill=INK if H.lum(col) > 0.35 else WHITE,
            anchor="mm",
        )
    box, c = sub(img, "player0")
    col = H.hexrgb(H.RIDERS[0][2])
    lx, ly = c[0] - box[0], c[1] - box[1]
    shadow(
        img,
        box,
        lambda d, o: d.ellipse((lx - 27, ly - 27 + o, lx + 27, ly + 27 + o), fill=255),
        blur=6,
    )
    d = ImageDraw.Draw(img)
    H.disc(d, c, 26, col + (255,), ring=WHITE + (255,), ring_w=5)
    d.text((c[0], c[1] + 1), str(H.RIDERS[0][1]), font=fl, fill=WHITE, anchor="mm")
    d.polygon([(c[0] - 11, c[1] + 30), (c[0] + 11, c[1] + 30), (c[0], c[1] + 42)], fill=WHITE)


def bike_side(d, c, s, ang, col):
    """White side-view bike (DESIGN 2c tumbling-bike icon), rotated by ang degrees."""
    a = math.radians(ang)

    def p(x, y):
        return (
            c[0] + (x * math.cos(a) - y * math.sin(a)) * s,
            c[1] + (x * math.sin(a) + y * math.cos(a)) * s,
        )

    w = max(2, int(s * 0.09))
    for wx in (-0.62, 0.62):
        x, y = p(wx, 0.25)
        r = 0.36 * s
        d.ellipse((x - r, y - r, x + r, y + r), outline=col, width=w)
    pts = [(-0.62, 0.25), (-0.1, 0.25), (0.35, -0.3), (-0.25, -0.3), (-0.1, 0.25)]
    d.line([p(*q) for q in pts], fill=col, width=w, joint="curve")
    d.line([p(0.35, -0.3), p(0.62, 0.25)], fill=col, width=w)
    d.line([p(0.3, -0.45), p(0.5, -0.45)], fill=col, width=w)
    d.line([p(-0.25, -0.3), p(-0.3, -0.42)], fill=col, width=w)


def knock_icons(img):
    for i in range(1, 6):
        col = H.hexrgb(H.RIDERS[i][2])
        _, c = sub(img, f"knock{i}")
        d = ImageDraw.Draw(img)
        H.disc(d, c, 30, INK + (235,), ring=col + (255,), ring_w=5)
        bike_side(d, c, 30, 60, WHITE)


def hand(img):
    box, tip = sub(img, "hand")
    s = 180
    d = ImageDraw.Draw(img)
    ox, oy = tip
    finger = (ox - 0.13 * s, oy, ox + 0.13 * s, oy + 0.7 * s)
    palm = (ox - 0.38 * s, oy + 0.55 * s, ox + 0.48 * s, oy + 1.18 * s)
    w = 7
    d.rounded_rectangle(finger, radius=int(s * 0.13), fill=WHITE, outline=INK, width=w)
    d.rounded_rectangle(palm, radius=int(s * 0.2), fill=WHITE, outline=INK, width=w)
    d.rectangle((ox - 0.13 * s + w, oy + 0.5 * s, ox + 0.13 * s - w, oy + 0.62 * s), fill=WHITE)


def arrows(img):
    for name, dirx in (("arrow_l", -1), ("arrow_r", 1)):
        _, c = sub(img, name)
        s = 180
        pts = [
            (c[0] - 0.25 * dirx * s, c[1] - 0.5 * s),
            (c[0] + 0.25 * dirx * s, c[1]),
            (c[0] - 0.25 * dirx * s, c[1] + 0.5 * s),
        ]
        d = ImageDraw.Draw(img)
        d.line(pts, fill=INK + (150,), width=int(s * 0.24), joint="curve")
        d.line(pts, fill=WHITE + (255,), width=int(s * 0.14), joint="curve")


def chevron_star(img):
    _, c = sub(img, "chevron")
    d = ImageDraw.Draw(img)
    pts = [(c[0] - 36, c[1] + 14), (c[0], c[1] - 14), (c[0] + 36, c[1] + 14)]
    d.line(pts, fill=INK, width=18, joint="curve")
    d.line(pts, fill=AMBER, width=10, joint="curve")
    _, c = sub(img, "star")
    pts = []
    for i in range(10):
        a = -math.pi / 2 + math.tau * i / 10
        r = 54 if i % 2 == 0 else 24
        pts.append((c[0] + math.cos(a) * r, c[1] + math.sin(a) * r))
    d.polygon(pts, fill=AMBER, outline=INK, width=5)


def lamps(img):
    for name, col in (
        ("lamp_off", (92, 97, 107)),
        ("lamp_amber", AMBER),
        ("lamp_green", (76, 175, 80)),
    ):
        _, c = sub(img, name)
        d = ImageDraw.Draw(img)
        H.disc(d, c, 46, col + (255,), ring=WHITE + (230,), ring_w=4)
    box, c = sub(img, "lights_bg")
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(
        (c[0] - 200, c[1] - 66, c[0] + 200, c[1] + 66),
        radius=66,
        fill=INK + (235,),
        outline=WHITE + (235,),
        width=4,
    )
    box, c = sub(img, "chip")
    d.rounded_rectangle((c[0] - 88, c[1] - 30, c[0] + 88, c[1] + 30), radius=10, fill=INK + (200,))
    box, c = sub(img, "dot")
    d.rectangle((box[0] + 2, box[1] + 2, box[0] + 13, box[1] + 13), fill=WHITE)


def ghost_icon(img):
    _, c = sub(img, "ghost_icon")
    d = ImageDraw.Draw(img)
    s = 48
    body = []
    for i in range(13):
        a = math.pi + math.pi * i / 12
        body.append((c[0] + math.cos(a) * 0.6 * s, c[1] + (math.sin(a) * 0.6 - 0.1) * s))
    for i in range(7):
        fx = 0.6 - 1.2 * i / 6
        fy = 0.75 if i % 2 == 0 else 0.5
        body.append((c[0] + fx * s, c[1] + fy * s))
    d.polygon(body, fill=(235, 242, 250), outline=INK, width=4)
    for ex in (-0.22, 0.22):
        d.ellipse(
            (c[0] + ex * s - 6, c[1] - 0.15 * s - 6, c[0] + ex * s + 6, c[1] - 0.15 * s + 6),
            fill=INK,
        )


def main():
    img = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    disc_icon(img, "home", "home")
    disc_icon(img, "gear", "gear")
    boost(img)
    for n in range(1, 7):
        place(img, n)
    bar(img)
    tokens(img)
    knock_icons(img)
    hand(img)
    arrows(img)
    chevron_star(img)
    lamps(img)
    ghost_icon(img)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    print(f"wrote {OUT.relative_to(ROOT)} {img.size}")


if __name__ == "__main__":
    main()
