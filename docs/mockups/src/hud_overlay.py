"""Draw the race HUD over the Blender render (DESIGN.md sections 4-5).

python3 docs/mockups/src/hud_overlay.py <raw.png> <out.png> [--zones <zones.png>]
State shown: player (fox, red) in 5th place, 38% of the track done, boost 70% charged.
"""

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
FONT = ROOT / "assets" / "fonts" / "Fredoka.ttf"
SS = 3

INK = (36, 33, 29)
WHITE = (255, 255, 255)
SUN = (255, 210, 63)
TRACK = (255, 255, 255, 235)
MEDAL = {1: (255, 210, 63), 2: (217, 222, 228), 3: (227, 160, 107), 4: WHITE, 5: WHITE, 6: WHITE}
RIDERS = {  # id: (team colour, hat)
    "fox": ((232, 65, 44), "fox"),
    "bobble": ((255, 194, 26), "bobble"),
    "shark": ((47, 111, 228), "fin"),
    "bunny": ((18, 160, 143), "bunny"),
    "bear": ((255, 126, 182), "bear"),
    "unicorn": ((242, 242, 238), "horn"),
}
# race state in the mock (progress 0..1); player = fox
STATE = {"bobble": 0.47, "shark": 0.44, "bear": 0.41, "bunny": 0.40, "fox": 0.38, "unicorn": 0.34}
PLAYER = "fox"
PLACE = 5
BOOST = 0.70


def S(v):
    return v * SS


def circ(d, cx, cy, r, fill, ring=None, w=0):
    if ring:
        d.ellipse([S(cx - r), S(cy - r), S(cx + r), S(cy + r)], fill=ring)
        r -= w
    d.ellipse([S(cx - r), S(cy - r), S(cx + r), S(cy + r)], fill=fill)


def poly(d, pts, fill):
    d.polygon([(S(x), S(y)) for x, y in pts], fill=fill)


def house(d, cx, cy, h):
    poly(d, [(cx, cy - h * 0.5), (cx + h * 0.52, cy - h * 0.02), (cx - h * 0.52, cy - h * 0.02)], INK)
    d.rectangle([S(cx - h * 0.36), S(cy - h * 0.05), S(cx + h * 0.36), S(cy + h * 0.5)], fill=INK)
    d.rectangle([S(cx - h * 0.11), S(cy + h * 0.15), S(cx + h * 0.11), S(cy + h * 0.5)], fill=WHITE)


def gear(d, cx, cy, r, teeth=8):
    pts = []
    for k in range(teeth):
        base = 2 * math.pi * k / teeth
        for da, rr in ((-0.42, 0.74), (-0.24, 1.0), (0.24, 1.0), (0.42, 0.74)):
            a = base + da * (2 * math.pi / teeth)
            pts.append((cx + r * rr * math.cos(a), cy + r * rr * math.sin(a)))
    poly(d, pts, INK)
    circ(d, cx, cy, r * 0.34, WHITE)


def bolt(d, cx, cy, h, col):
    w = h * 0.62
    pts = [
        (cx + w * 0.12, cy - h / 2),
        (cx - w * 0.42, cy + h * 0.06),
        (cx - w * 0.02, cy + h * 0.06),
        (cx - w * 0.14, cy + h / 2),
        (cx + w * 0.42, cy - h * 0.08),
        (cx + w * 0.02, cy - h * 0.08),
    ]
    poly(d, pts, col)


def head_token(d, cx, cy, r, rid, player=False):
    col, hat = RIDERS[rid]
    o = max(3, r * 0.12)

    def draw_hat(fill, g):
        if hat == "fox":
            for s in (-1, 1):
                poly(d, [(cx + s * (r * 0.2 - g), cy - r * 0.7), (cx + s * (r * 0.95 + g), cy - r * 1.3 - g), (cx + s * (r * 0.92 + g), cy - r * 0.15)], fill)
        elif hat == "bobble":
            circ(d, cx, cy - r * 1.12, r * 0.36 + g, fill if fill != col else (255, 241, 214))
        elif hat == "fin":
            poly(
                d,
                [
                    (cx - r * 0.42 - g, cy - r * 0.8),
                    (cx - r * 0.1, cy - r * 1.2 - g * 0.6),
                    (cx + r * 0.42, cy - r * 1.62 - g),
                    (cx + r * 0.3 + g, cy - r * 1.05),
                    (cx + r * 0.5 + g, cy - r * 0.7),
                ],
                fill,
            )
        elif hat == "bunny":
            for s in (-1, 1):
                ex = cx + s * r * 0.38
                d.ellipse([S(ex - r * 0.2 - g), S(cy - r * 1.75 - g), S(ex + r * 0.2 + g), S(cy - r * 0.55)], fill=fill)
        elif hat == "bear":
            for s in (-1, 1):
                circ(d, cx + s * r * 0.72, cy - r * 0.7, r * 0.34 + g, fill)
        elif hat == "horn":
            poly(d, [(cx - r * 0.2 - g, cy - r * 0.85), (cx, cy - r * 1.6 - g), (cx + r * 0.2 + g, cy - r * 0.85)], fill if fill == INK else SUN)

    if player:
        draw_hat(WHITE, o + r * 0.14)
        circ(d, cx, cy, r + o + r * 0.14, WHITE)
    draw_hat(INK, o)
    circ(d, cx, cy, r + o, INK)
    draw_hat(col, 0)
    circ(d, cx, cy, r, col)
    # visor with two eye shines (same face as the 3D helmet)
    d.ellipse([S(cx - r * 0.7), S(cy - r * 0.15), S(cx + r * 0.7), S(cy + r * 0.62)], fill=(30, 38, 51))
    for s in (-1, 1):
        d.ellipse([S(cx + s * r * 0.3 - r * 0.1), S(cy + r * 0.05), S(cx + s * r * 0.3 + r * 0.1), S(cy + r * 0.38)], fill=WHITE)


def checker_flag(d, x, y, h):
    d.rectangle([S(x - 3), S(y - h * 0.5), S(x + 3), S(y + h * 0.75)], fill=INK)
    cw = h * 0.22
    for i in range(4):
        for j in range(3):
            col = INK if (i + j) % 2 == 0 else WHITE
            d.rectangle([S(x + 3 + i * cw), S(y - h * 0.5 + j * cw), S(x + 3 + (i + 1) * cw), S(y - h * 0.5 + (j + 1) * cw)], fill=col)
    d.rectangle([S(x + 3), S(y - h * 0.5), S(x + 3 + 4 * cw), S(y - h * 0.5 + 3 * cw)], outline=INK, width=S(3))


def draw_hud(base: Image.Image, standalone=True) -> Image.Image:
    W, H = base.size
    layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    # home disc: stand-alone build only (inside MWM Play the shell draws it). Top-left 232 px square is its zone.
    if standalone:
        circ(d, 104, 104, 68, WHITE, ring=INK, w=5)
        house(d, 104, 106, 66)
    # gear, top-right
    circ(d, 976, 104, 68, WHITE, ring=INK, w=5)
    gear(d, 976, 104, 40)

    # place medal, top centre: rosette + ribbon tails + big digit
    cx, cy = 540, 112
    col = MEDAL[PLACE]
    for s in (-1, 1):
        poly(d, [(cx + s * 22, cy + 40), (cx + s * 70, cy + 128), (cx + s * 46, cy + 118), (cx + s * 36, cy + 146), (cx + s * 2, cy + 52)], INK)
        poly(d, [(cx + s * 26, cy + 46), (cx + s * 62, cy + 120), (cx + s * 46, cy + 112), (cx + s * 38, cy + 132), (cx + s * 8, cy + 56)], (52, 64, 90))
    pts_o, pts_i = [], []
    for i in range(36):
        a = math.pi * 2 * i / 36
        ro = 94 if i % 2 == 0 else 86
        pts_o.append((cx + (ro + 6) * math.cos(a), cy + (ro + 6) * math.sin(a)))
        pts_i.append((cx + ro * math.cos(a), cy + ro * math.sin(a)))
    poly(d, pts_o, INK)
    poly(d, pts_i, col)
    circ(d, cx, cy, 70, col, ring=INK, w=4)
    font = ImageFont.truetype(str(FONT), S(112))
    font.set_variation_by_name("SemiBold")
    d.text((S(cx), S(cy + 4)), str(PLACE), font=font, fill=INK, anchor="mm")

    # progress bar: the player's own head travels to the finish flag (place is the medal's job)
    x0, x1, yb = 92, 930, 312
    d.rounded_rectangle([S(x0 - 6), S(yb - 21), S(x1 + 6), S(yb + 21)], radius=S(21), fill=INK)
    d.rounded_rectangle([S(x0), S(yb - 15), S(x1), S(yb + 15)], radius=S(15), fill=TRACK)
    px = x0 + (x1 - x0) * STATE[PLAYER]
    d.rounded_rectangle([S(x0), S(yb - 15), S(px), S(yb + 15)], radius=S(15), fill=SUN)
    checker_flag(d, x1 + 34, yb - 6, 56)
    head_token(d, px, yb + 2, 36, PLAYER, player=True)

    # boost button: right edge, centre at 58% height; ring charges clockwise in sun yellow
    bx, by, br = 930, 1110, 110
    circ(d, bx, by, br + 6, INK)
    circ(d, bx, by, br, WHITE)
    d.arc([S(bx - br + 12), S(by - br + 12), S(bx + br - 12), S(by + br - 12)], start=-90, end=-90 + 360 * BOOST, fill=SUN, width=S(22))
    d.arc([S(bx - br + 12), S(by - br + 12), S(bx + br - 12), S(by + br - 12)], start=-90 + 360 * BOOST, end=270, fill=(232, 228, 220), width=S(22))
    bolt(d, bx, by, 110, INK)

    hud = layer.resize((W, H), Image.LANCZOS)
    out = base.convert("RGBA")
    out.alpha_composite(hud)
    return out.convert("RGB")


def draw_zones(img: Image.Image) -> Image.Image:
    z = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(z)
    d.rectangle([0, 768, 1079, 1663], fill=(31, 122, 90, 40))  # steering drag zone (lower 60%, above strip)
    d.rectangle([0, 0, 231, 231], outline=(255, 255, 255, 255), width=6)  # reserved home square
    d.rectangle([864, 0, 1079, 215], outline=(31, 122, 90, 255), width=6)  # gear hit area
    d.rectangle([800, 980, 1060, 1240], outline=(31, 122, 90, 255), width=6)  # boost hit area
    d.rectangle([0, 1664, 1079, 1919], fill=(220, 40, 40, 70))  # wrist strip: nothing tappable
    out = img.convert("RGBA")
    out.alpha_composite(z)
    return out.convert("RGB")


if __name__ == "__main__":
    raw, out = sys.argv[1], sys.argv[2]
    img = draw_hud(Image.open(raw).convert("RGB"))
    img.save(out, optimize=True)
    if "--zones" in sys.argv:
        draw_zones(img).save(sys.argv[sys.argv.index("--zones") + 1], optimize=True)
    print("wrote", out)
