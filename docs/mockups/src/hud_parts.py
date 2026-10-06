"""HUD parts sheet: six head tokens (normal + player ring) and the place medal 1-6.

python3 docs/mockups/src/hud_parts.py docs/mockups/hud_parts.png
"""

import sys

import hud_overlay as H
from PIL import Image, ImageDraw, ImageFont


def medal(d, cx, cy, place, font):
    import math

    col = H.MEDAL[place]
    pts_o, pts_i = [], []
    for i in range(36):
        a = math.pi * 2 * i / 36
        ro = 94 if i % 2 == 0 else 86
        pts_o.append((cx + (ro + 6) * math.cos(a), cy + (ro + 6) * math.sin(a)))
        pts_i.append((cx + ro * math.cos(a), cy + ro * math.sin(a)))
    H.poly(d, pts_o, H.INK)
    H.poly(d, pts_i, col)
    H.circ(d, cx, cy, 70, col, ring=H.INK, w=4)
    d.text((H.S(cx), H.S(cy + 4)), str(place), font=font, fill=H.INK, anchor="mm")
    if place == 1:  # crown on first place: a shape cue on top of gold
        H.poly(
            d,
            [(cx - 46, cy - 92), (cx - 52, cy - 140), (cx - 22, cy - 112), (cx, cy - 150), (cx + 22, cy - 112), (cx + 52, cy - 140), (cx + 46, cy - 92)],
            H.INK,
        )
        H.poly(
            d,
            [(cx - 40, cy - 97), (cx - 44, cy - 128), (cx - 20, cy - 105), (cx, cy - 138), (cx + 20, cy - 105), (cx + 44, cy - 128), (cx + 40, cy - 97)],
            H.SUN,
        )


W, Ht = 1500, 760
bg = Image.new("RGB", (W, Ht), (120, 185, 232))
layer = Image.new("RGBA", (W * H.SS, Ht * H.SS), (0, 0, 0, 0))
d = ImageDraw.Draw(layer)
for i, rid in enumerate(H.RIDERS):
    x = 140 + i * 245
    H.head_token(d, x, 140, 52, rid)
    H.head_token(d, x, 330, 36, rid, player=True)
font = ImageFont.truetype(str(H.FONT), H.S(112))
font.set_variation_by_name("SemiBold")
for p in range(1, 7):
    medal(d, 140 + (p - 1) * 245, 590, p, font)
out = bg.convert("RGBA")
out.alpha_composite(layer.resize((W, Ht), Image.LANCZOS))
out.convert("RGB").save(sys.argv[1], optimize=True)
print("wrote", sys.argv[1])
