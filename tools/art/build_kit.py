"""Track kit (shared by every world) and the world-1 / world-2 props. Each GLB = one mesh, one baked atlas material.

blender -b --factory-startup -P tools/art/build_kit.py -- [names...]
Shared:  boost_pad, ramp, swap_gate, finish_arch, hoverboard
World 1: hay_bale, mud_puddle, fence_rail, tape_stake
World 2: tumbleweed, sand_drift, water_tower, ramp_rock
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).parent))
import rr_art as A  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
KT = A.TEX / "kit"
W1 = A.TEX / "world1"
W2 = A.TEX / "world2"
ICON = A.BUILD
REPORT = {}


def done(o, name, extra=""):
    A.apply_xform(o)
    out = A.export_glb([o], name)
    REPORT[name] = (A.size_godot([o]), A.tris(o), out.stat().st_size)
    print("KIT", name, REPORT[name], extra)


def cube(name, size, loc, mat, bevel=0.0, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    o.location = loc
    o.rotation_euler = rot
    A.apply_xform(o)
    if bevel:
        b = o.modifiers.new("b", "BEVEL")
        b.width = bevel
        b.segments = 2
        A.apply_all(o)
    o.data.materials.append(mat)
    return o


def cyl(name, r, depth, loc, mat, verts=16, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts, radius=r, depth=depth, location=loc, rotation=rot
    )
    o = bpy.context.active_object
    o.name = name
    A.apply_xform(o)
    o.data.materials.append(mat)
    for p in o.data.polygons:
        p.use_smooth = len(p.vertices) == 4
    return o


def truss(name, p0, p1, w, mat, chord_r=0.024, lace_r=0.009, step=0.45):
    """Square aluminium box truss between p0 and p1 (event-stage style)."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    L = d.length
    t = d.normalized()
    up = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((0, 1, 0))
    a = t.cross(up).normalized()
    b = t.cross(a)
    corners = [(a * s1 + b * s2) * (w / 2) for s1, s2 in ((1, 1), (-1, 1), (-1, -1), (1, -1))]
    parts = [
        A.tube(f"{name}_c{i}", [p0 + c, p1 + c], chord_r, 8, mat) for i, c in enumerate(corners)
    ]
    n = max(1, int(L / step))
    for i in range(n):
        q0 = p0 + t * (L * i / n)
        q1 = p0 + t * (L * (i + 1) / n)
        for k in range(4):
            c0, c1 = corners[k], corners[(k + 1) % 4]
            if i % 2 == 0:
                parts.append(
                    A.tube(f"{name}_l{i}_{k}", [q0 + c0, q1 + c1], lace_r, 4, mat, cap=False)
                )
            else:
                parts.append(
                    A.tube(f"{name}_l{i}_{k}", [q0 + c1, q1 + c0], lace_r, 4, mat, cap=False)
                )
    return parts


# ---------------------------------------------------------------- shared kit
def boost_pad():
    """3.0 x 4.0 m race-tech speed plate: steel frame, rubber mat, three amber LED chevrons (emissive)."""
    A.reset()
    steel = A.src_mat(
        "steel",
        A.ph_tex("rusty_metal_02"),
        scale=0.5,
        tint=(0.35, 0.36, 0.38),
        rough=0.45,
        metal=0.9,
    )
    rub = A.src_mat(
        "rubber", A.ph_tex("worn_asphalt"), scale=1.5, tint=(0.25, 0.25, 0.26), rough=0.88
    )
    led = A.src_mat("led", color=A.rgba("#FFB000"), rough=0.3, emit=A.hex_rgb("#FFB000"))
    parts = [cube("frame", (3.0, 4.0, 0.05), (0, 0, 0.025), steel, bevel=0.02)]
    parts.append(cube("mat", (2.76, 3.76, 0.03), (0, 0, 0.055), rub, bevel=0.008))
    for i in range(3):
        tip = Vector((0, -0.75 + i * 1.0 + 0.45, 0.072))
        for sgn in (-1, 1):
            end = Vector((sgn * 1.05, tip.y - 0.75, 0.072))
            mid = (tip + end) / 2
            ang = math.atan2(end.y - tip.y, end.x - tip.x)
            ln = (end - tip).length + 0.12
            parts.append(
                cube(f"ch{i}{sgn}", (ln, 0.20, 0.022), mid, led, bevel=0.006, rot=(0, 0, ang))
            )
    o = A.join(parts, "boost_pad")
    A.tile_uv(o)
    A.bake_down(o, 512, KT, "boost_pad", want_emission=True)
    done(o, "boost_pad")


def ramp():
    """Plank kicker 4.6 m wide, 3.65 m deck, 1.15 m lip (RrBalance KICKER_LIP_M / KICKER_LEN_M).
    Deck planks run across the track on timber stringers, steel lip edge."""
    A.reset()
    wood = A.src_mat("planks", A.ph_tex("weathered_planks"), scale=0.5, rot=90)
    frame = A.src_mat("timber", A.ph_tex("weathered_planks"), scale=0.7, tint=(0.75, 0.72, 0.7))
    steel = A.src_mat("lip", color=A.rgba("#6B6E72"), rough=0.4, metal=0.9)
    W, L, H = 4.6, 3.65, 1.15
    prof = [(L * i / 16, H * (i / 16) ** 1.7) for i in range(17)]  # (y, z) concave curve
    parts = []
    # planks (one board per segment, small gaps)
    for i in range(16):
        y0, z0 = prof[i]
        y1, z1 = prof[i + 1]
        c = Vector((0, (y0 + y1) / 2 - L / 2, (z0 + z1) / 2))
        ang = math.atan2(z1 - z0, y1 - y0)
        ln = math.hypot(y1 - y0, z1 - z0)
        parts.append(
            cube(f"plank{i}", (W, ln - 0.012, 0.035), c, wood, bevel=0.004, rot=(ang, 0, 0))
        )
    # stringers + uprights
    for x in (-W / 2 + 0.1, -0.75, 0.75, W / 2 - 0.1):
        pts = [Vector((x, y - L / 2, z - 0.06)) for y, z in prof]
        parts.append(A.tube(f"str{x}", pts, 0.05, 4, frame))
        for k in (6, 10, 13, 16):
            y, z = prof[k]
            if z > 0.15:
                parts.append(
                    cube(
                        f"up{x}{k}",
                        (0.09, 0.09, z - 0.05),
                        (x, y - L / 2 - 0.02, (z - 0.05) / 2),
                        frame,
                    )
                )
    parts.append(cube("back", (W, 0.06, H), (0, L / 2 - 0.03, H / 2 - 0.02), frame))
    parts.append(
        A.tube(
            "lipbar",
            [Vector((-W / 2, L / 2 - 0.005, H + 0.005)), Vector((W / 2, L / 2 - 0.005, H + 0.005))],
            0.025,
            8,
            steel,
        )
    )
    o = A.join(parts, "ramp")
    A.tile_uv(o)
    A.bake_down(o, 1024, KT, "ramp", ao_dist=0.5)
    done(o, "ramp")


def gate_common(name, span, height, icons, banner_mat_color, top_led):
    alu = A.src_mat("alu", color=A.rgba("#C9CDD2"), rough=0.32, metal=1.0)
    feet = A.src_mat(
        "feet", A.ph_tex("rusty_metal_02"), scale=0.6, tint=(0.25, 0.26, 0.28), rough=0.5, metal=0.8
    )
    parts = []
    x = span / 2
    w = 0.30
    for s in (-1, 1):
        parts += truss(f"leg{s}", (s * x, 0, 0.08), (s * x, 0, height), w, alu)
        parts.append(cube(f"base{s}", (0.7, 0.7, 0.08), (s * x, 0, 0.04), feet, bevel=0.01))
    parts += truss("top", (-x - w / 2, 0, height + w / 2), (x + w / 2, 0, height + w / 2), w, alu)
    for s in (-1, 1):
        parts.append(
            cube(
                f"corner{s}",
                (w + 0.04, w + 0.04, w + 0.04),
                (s * x, 0, height + w / 2),
                alu,
                bevel=0.01,
            )
        )
    return parts, alu


def banner(
    name, w, h, center, icon: Path | None, color_hex, emit_icon=False, facing=-1, chequer=False
):
    """Fabric banner (two-sided quad slab) with an icon decal; faces -Y (towards the riders) by default."""
    verts, faces = [], []
    th = 0.01
    for k, yy in enumerate((-th, th)):
        for u, v in ((0, 0), (1, 0), (1, 1), (0, 1)):
            verts.append((center[0] + (u - 0.5) * w, center[1] + yy, center[2] + (v - 0.5) * h))
    faces = [(0, 1, 2, 3), (5, 4, 7, 6), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    o = A.mesh_obj(name, verts, faces)
    if chequer:
        m = A.src_mat(name + "_m", {"albedo": ICON / "chequer.png"}, scale=1.0, rough=0.8)
    else:
        m = A.src_mat(
            name + "_m",
            color=A.rgba(color_hex),
            rough=0.85,
            decal=icon,
            decal_color=(1, 1, 1),
            emit=(0.9, 0.95, 1.0) if emit_icon else None,
        )
    m["keep_uv"] = 1
    o.data.materials.append(m)
    # tile UVs: the decal spans the panel, square, centred
    me = o.data
    uvl = me.uv_layers.new(name="tile")
    asp = w / h
    for p in me.polygons:
        for li in p.loop_indices:
            c = me.vertices[me.loops[li].vertex_index].co
            u = (c.x - center[0]) / w + 0.5
            v = (c.z - center[2]) / h + 0.5
            if chequer:
                uvl.data[li].uv = (u * w / 1.6, v * h / 1.6)
            elif asp < 1:
                uvl.data[li].uv = (u, (v - 0.5) / asp + 0.5)
            else:
                uvl.data[li].uv = ((u - 0.5) * asp + 0.5, v)
    return o


def swap_gate():
    """Aluminium truss arch 11.2 m span, 6 m tall. Bike icon on the left pillar, board icon on the right,
    LED strip along the header (emissive) for the swap light run."""
    A.reset()
    parts, alu = gate_common("swap_gate", 11.2, 6.0, None, None, True)
    led = A.src_mat("led", color=A.rgba("#EAF6FF"), rough=0.3, emit=A.hex_rgb("#EAF6FF"))
    parts.append(
        banner(
            "ban_l", 1.0, 2.6, (-5.6, -0.2, 3.3), ICON / "icon_bike.png", "#15181D", emit_icon=True
        )
    )
    parts.append(
        banner(
            "ban_r", 1.0, 2.6, (5.6, -0.2, 3.3), ICON / "icon_board.png", "#15181D", emit_icon=True
        )
    )
    parts.append(banner("ban_top", 9.6, 0.9, (0, -0.2, 6.15), None, "#15181D"))
    for s in (-1, 1):
        parts.append(cube(f"ledl{s}", (0.06, 0.03, 5.6), (s * 5.42, -0.17, 3.0), led))
    parts.append(cube("ledtop", (9.4, 0.03, 0.06), (0, -0.23, 5.75), led))
    parts.append(cube("ledtop2", (9.4, 0.03, 0.06), (0, -0.23, 6.55), led))
    o = A.join(parts, "swap_gate")
    A.tile_uv(o)
    A.bake_down(o, 1024, KT, "swap_gate", want_emission=True, ao_dist=0.4)
    done(o, "swap_gate")


def finish_arch():
    """13.6 m truss arch, 6.6 m tall, chequered banner both faces, chequered leg banners, no text."""
    A.reset()
    parts, alu = gate_common("finish", 13.6, 6.6, None, None, False)
    parts.append(banner("chk_top", 12.4, 1.3, (0, 0.0, 6.75), None, "#FFFFFF", chequer=True))
    for s in (-1, 1):
        parts.append(
            banner(f"chk_l{s}", 1.0, 3.0, (s * 6.8, -0.2, 3.0), None, "#FFFFFF", chequer=True)
        )
        # flag poles with chequered flags beside the arch
        pole = A.tube(
            f"pole{s}", [Vector((s * 7.8, 0.6, 0)), Vector((s * 7.8, 0.6, 4.2))], 0.03, 8, alu
        )
        parts.append(pole)
        parts.append(
            banner(
                f"flag{s}", 0.9, 0.6, (s * 7.8 - s * 0.47, 0.6, 3.85), None, "#FFFFFF", chequer=True
            )
        )
    o = A.join(parts, "finish_arch")
    A.tile_uv(o)
    A.bake_down(o, 1024, KT, "finish_arch", ao_dist=0.4)
    done(o, "finish_arch")


def hoverboard():
    """Sleek hoverboard: carbon deck 1.32 x 0.36 m with kicktails, grip top, team-colour rail,
    two hover pods with emissive ring (cool white-blue). Deck top at BOARD_DECK_Z (0.30 m)."""
    A.reset()
    carbon = A.src_mat(
        "carbon", A.ph_tex("worn_asphalt"), scale=6.0, tint=(0.09, 0.09, 0.1), rough=0.3, metal=0.0
    )
    grip = A.src_mat(
        "grip", A.ph_tex("worn_asphalt"), scale=3.0, tint=(0.15, 0.15, 0.16), rough=0.95
    )
    alu = A.src_mat("alu", color=A.rgba("#B8BCC2"), rough=0.3, metal=1.0)
    paint = A.src_mat("paint", color=A.rgba("#F2F3F5"), rough=0.25)
    glow = A.src_mat("glow", color=A.rgba("#BFEFFF"), rough=0.2, emit=A.hex_rgb("#8FDFFF"))
    D = A.BOARD_DECK_Z
    # deck outline: rounded rectangle with upturned tails
    nx, ny = 24, 7
    L, W = 1.32, 0.36
    verts, faces = [], []
    for j in range(ny):
        for i in range(nx):
            u = i / (nx - 1) * 2 - 1
            v = j / (ny - 1) * 2 - 1
            taper = 1 - 0.35 * max(0, abs(u) - 0.75) / 0.25
            x = v * W / 2 * taper
            y = u * L / 2
            z = D + 0.10 * max(0, abs(u) - 0.78) ** 2 / 0.22**2 * 0.6 - 0.012 * v * v
            verts.append((x, y, z))
    for j in range(ny - 1):
        for i in range(nx - 1):
            a = j * nx + i
            faces.append((a, a + 1, a + nx + 1, a + nx))
    deck = A.mesh_obj("deck", verts, faces)
    deck.data.materials.append(grip)
    deck.data.materials.append(carbon)
    so = deck.modifiers.new("s", "SOLIDIFY")
    so.thickness = 0.035
    so.material_offset = 1
    so.material_offset_rim = 1
    A.apply_all(deck)
    for p in deck.data.polygons:
        p.use_smooth = True
    parts = [deck]
    for s in (-1, 1):
        rail = A.tube(
            f"rail{s}",
            [
                Vector((s * W / 2 * 0.98, -L / 2 * 0.72, D - 0.02)),
                Vector((s * W / 2 * 0.98, L / 2 * 0.72, D - 0.02)),
            ],
            0.012,
            6,
            paint,
        )
        parts.append(rail)
    for py in (-0.36, 0.36):
        parts.append(cyl(f"pod{py}", 0.13, 0.08, (0, py, D - 0.09), alu, 20))
        parts.append(cyl(f"ring{py}", 0.115, 0.012, (0, py, D - 0.136), glow, 20))
        parts.append(cyl(f"core{py}", 0.06, 0.01, (0, py, D - 0.14), glow, 12))
    parts.append(cube("spine", (0.12, 0.62, 0.035), (0, 0, D - 0.06), carbon, bevel=0.01))
    o = A.join(parts, "hoverboard")
    A.tile_uv(o, 0.5)
    paths = A.bake_down(o, 512, KT, "hoverboard", want_emission=True, ao_dist=0.1)
    # team-colour variants: the white rail (paint) becomes the rider colour (atlas texels that are ~white)
    from_img = bpy.data.images.load(
        str(paths["albedo"]), check_existing=False
    )  # a copy: the material keeps its own
    from_img.colorspace_settings.name = "Non-Color"
    base = A.px(from_img).copy()
    bpy.data.images.remove(from_img)
    lum = base[..., :3].mean(-1)
    sat = base[..., :3].max(-1) - base[..., :3].min(-1)
    mask = (lum > 0.8) & (sat < 0.08)
    for r in A.RIDERS:
        c = base[..., :3].copy()
        c[mask] = A.srgb(r["hex"]) * (0.85 + 0.15 * lum[mask, None])
        A.write_png(c, KT / f"hoverboard_{r['id']}_albedo.png")
    done(o, "hoverboard")


# ---------------------------------------------------------------- world 1 props
def hay_bale():
    """Round straw bale lying across the track: 1.6 m long (x), 1.1 m diameter, net wrap. Block hindrance."""
    A.reset()
    straw_tex = {
        "albedo": A.RAW / "ambientcg/ThatchedRoof001A/ThatchedRoof001A_1K-JPG_Color.jpg",
        "normal": A.RAW / "ambientcg/ThatchedRoof001A/ThatchedRoof001A_1K-JPG_NormalGL.jpg",
    }
    straw = A.src_mat("straw", straw_tex, scale=0.8, tint=(1.0, 0.92, 0.75), rough=0.9)
    ends = A.src_mat("ends", straw_tex, scale=1.6, tint=(0.95, 0.85, 0.65), rough=0.92, rot=45)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=24, radius=0.55, depth=1.6, rotation=(0, math.pi / 2, 0), location=(0, 0, 0.55)
    )
    o = bpy.context.active_object
    o.data.materials.append(straw)
    o.data.materials.append(ends)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    for f in bm.faces:
        if len(f.verts) > 4:
            f.material_index = 1
    bmesh.ops.inset_region(
        bm, faces=[f for f in bm.faces if len(f.verts) > 4], thickness=0.06, depth=-0.03
    )
    bm.to_mesh(o.data)
    bm.free()
    b = o.modifiers.new("b", "BEVEL")
    b.width = 0.05
    b.segments = 3
    b.limit_method = "ANGLE"
    A.apply_all(o)
    rnd = random.Random(3)
    for v in o.data.vertices:  # slight sag and lumps
        v.co.z -= 0.04 * max(0, 0.55 - v.co.z) / 0.55 * 0
        v.co += Vector((0, 0, 0)) + v.co.normalized() * 0.0
        v.co.y += rnd.uniform(-0.006, 0.006)
        v.co.z += rnd.uniform(-0.006, 0.006)
    for p in o.data.polygons:
        p.use_smooth = True
    A.tile_uv(o, 1.0)
    A.bake_down(o, 512, W1, "hay_bale", ao_dist=0.3)
    done(o, "hay_bale")


def mud_puddle():
    """Wet mud patch 5 x 10 m, 2 cm proud, alpha-faded edge in vertex colour alpha. Patch hindrance."""
    A.reset()
    rnd = random.Random(5)
    nx, ny = 12, 22
    verts, faces, alpha = [], [], []
    for j in range(ny):
        for i in range(nx):
            u = i / (nx - 1) * 2 - 1
            v = j / (ny - 1) * 2 - 1
            a = math.atan2(v, u)
            wob = 1 + 0.16 * math.sin(3 * a + 1) + 0.08 * math.sin(7 * a + 2)
            r = math.hypot(u, v) / wob
            verts.append((u * 2.8, v * 5.6, 0.02 * max(0.0, 1 - r)))
            alpha.append(max(0.0, min(1.0, (1 - r) * 4.0)))
    for j in range(ny - 1):
        for i in range(nx - 1):
            a0 = j * nx + i
            faces.append((a0, a0 + 1, a0 + nx + 1, a0 + nx))
    o = A.mesh_obj("mud_puddle", verts, faces)
    for p in o.data.polygons:
        p.use_smooth = True
    ca = o.data.color_attributes.new("Col", "BYTE_COLOR", "POINT")
    for i, a in enumerate(alpha):
        ca.data[i].color = (1, 1, 1, a)
    mud = A.src_mat(
        "mud",
        A.ph_tex("brown_mud_02"),
        scale=0.5,
        tint=(0.62, 0.45, 0.30),
        rough=0.10,
        normal_strength=0.5,
    )
    o.data.materials.append(mud)
    A.tile_uv(o, 1.0)
    A.bake_down(o, 512, W1, "mud_puddle", ao_dist=0.05, ao_k=0.0, vertex_alpha=True)
    done(o, "mud_puddle", "vertex alpha = edge fade")


def fence_rail():
    """4 m farm rail fence section (two split rails on round posts). Soft rail of the world-1 track."""
    A.reset()
    wood = A.src_mat("wood", A.ph_tex("pine_bark"), scale=0.8, tint=(0.8, 0.75, 0.7))
    rail = A.src_mat("rail", A.ph_tex("weathered_planks"), scale=1.0)
    parts = []
    for x in (-2.0, 2.0):
        parts.append(cyl(f"post{x}", 0.07, 1.15, (x, 0, 0.575), wood, 8))
    for z in (0.45, 0.9):
        parts.append(
            A.tube(
                f"r{z}",
                [Vector((-2.15, 0, z)), Vector((0, 0.02, z - 0.02)), Vector((2.15, 0, z))],
                0.055,
                6,
                rail,
            )
        )
    o = A.join(parts, "fence_rail")
    A.tile_uv(o)
    A.bake_down(o, 512, W1, "fence_rail", ao_dist=0.2)
    done(o, "fence_rail")


def tape_stake():
    """Course-tape stake (1.1 m) with a 4 m red/white tape run to the next stake: the race-course edge line."""
    A.reset()
    wood = A.src_mat("stake", A.ph_tex("weathered_planks"), scale=1.2)
    red = A.src_mat("tape_r", color=A.rgba("#D2232A"), rough=0.4)
    white = A.src_mat("tape_w", color=A.rgba("#F3F3F3"), rough=0.4)
    parts = [cube("stake", (0.045, 0.045, 1.1), (0, 0, 0.55), wood)]
    segs = 16
    for i in range(segs):
        y0 = 4.0 * i / segs
        y1 = 4.0 * (i + 1) / segs
        sag0 = 0.10 * math.sin(math.pi * y0 / 4.0)
        sag1 = 0.10 * math.sin(math.pi * y1 / 4.0)
        verts = [
            (0.03, y0, 0.95 - sag0),
            (0.03, y1, 0.95 - sag1),
            (0.03, y1, 1.0 - sag1),
            (0.03, y0, 1.0 - sag0),
        ]
        q = A.mesh_obj(f"t{i}", verts, [(0, 1, 2, 3), (3, 2, 1, 0)])
        q.data.materials.append(red if i % 2 == 0 else white)
        parts.append(q)
    o = A.join(parts, "tape_stake")
    A.tile_uv(o)
    A.bake_down(o, 256, W1, "tape_stake", ao_dist=0.1)
    done(o, "tape_stake", "tape runs +Y 4 m; place stakes every 4 m")


# ---------------------------------------------------------------- world 2 props
def tumbleweed():
    """1.2 m ball of dry brush (Roller hindrance): curved twig tubes on a sphere, dry straw colour."""
    A.reset()
    rnd = random.Random(11)
    twig = A.src_mat("twig", A.ph_tex("pine_bark"), scale=3.0, tint=(0.95, 0.8, 0.6), rough=0.9)
    parts = []
    for i in range(70):
        a0 = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1))).normalized()
        ax = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1))).normalized()
        span = rnd.uniform(0.8, 2.0)
        pts = []
        for k in range(6):
            ang = span * (k / 5 - 0.5)
            p = Matrix.Rotation(ang, 3, ax) @ a0
            pts.append(p * (0.6 * rnd.uniform(0.75, 1.0)) + Vector((0, 0, 0.6)))
        parts.append(A.tube(f"tw{i}", pts, rnd.uniform(0.006, 0.012), 3, twig, cap=False))
    o = A.join(parts, "tumbleweed")
    A.tile_uv(o, 0.3)
    A.bake_down(o, 256, W2, "tumbleweed", ao_dist=0.4, ao_k=0.6)
    done(o, "tumbleweed", "origin at ground under the centre; roll about its centre (0,0.6,0)")


def sand_drift():
    """Pale wind-rippled sand tongue 4 x 15 m across the hard-pack, alpha-faded edge (Patch)."""
    A.reset()
    nx, ny = 16, 32
    verts, faces, alpha = [], [], []
    rnd = random.Random(7)
    for j in range(ny):
        for i in range(nx):
            u = i / (nx - 1) * 2 - 1
            v = j / (ny - 1) * 2 - 1
            edge = max(abs(u) ** 2.2 + 0.0 * rnd.random(), abs(v) ** 6)
            h = 0.12 * max(0.0, 1 - edge) + 0.015 * math.sin(v * 38 + u * 3)
            verts.append((u * 7.5, v * 2.0, h))
            alpha.append(max(0.0, min(1.0, (1 - edge) * 3.0)))
    for j in range(ny - 1):
        for i in range(nx - 1):
            a = j * nx + i
            faces.append((a, a + 1, a + nx + 1, a + nx))
    o = A.mesh_obj("sand_drift", verts, faces)
    for p in o.data.polygons:
        p.use_smooth = True
    ca = o.data.color_attributes.new("Col", "BYTE_COLOR", "POINT")
    for i, a in enumerate(alpha):
        ca.data[i].color = (1, 1, 1, a)
    sand = A.src_mat("sand", A.ph_tex("red_sand"), scale=0.4, tint=(1.55, 1.35, 1.15), rough=0.95)
    o.data.materials.append(sand)
    A.tile_uv(o)
    A.bake_down(o, 512, W2, "sand_drift", ao_dist=0.05, ao_k=0.0, vertex_alpha=True)
    done(o, "sand_drift", "15 m across (x), 4 m along the track; vertex alpha = edge fade")


def water_tower():
    """Rusty steel water tower 14 m (start grid / finish landmark): tank, conical roof, 4 legs with cross braces."""
    A.reset()
    rust = A.src_mat("rust", A.ph_tex("rusty_metal_02"), scale=0.35)
    roof = A.src_mat(
        "roof", A.ph_tex("corrugated_iron_02"), scale=0.6, tint=(0.6, 0.45, 0.35), metal=0.6
    )
    parts = []
    tank = cyl("tank", 3.0, 4.2, (0, 0, 10.6), rust, 28)
    parts.append(tank)
    bpy.ops.mesh.primitive_cone_add(
        vertices=28, radius1=3.3, radius2=0.3, depth=1.6, location=(0, 0, 13.5)
    )
    rf = bpy.context.active_object
    rf.data.materials.append(roof)
    parts.append(rf)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        top = Vector((math.cos(a) * 2.4, math.sin(a) * 2.4, 8.5))
        bot = Vector((math.cos(a) * 3.6, math.sin(a) * 3.6, 0))
        parts.append(A.tube(f"leg{k}", [bot, top], 0.16, 8, rust))
        a2 = a + math.pi / 2
        top2 = Vector((math.cos(a2) * 2.4, math.sin(a2) * 2.4, 8.5))
        bot2 = Vector((math.cos(a2) * 3.6, math.sin(a2) * 3.6, 0))
        for f0, f1 in ((0.15, 0.55), (0.55, 0.95)):
            parts.append(
                A.tube(f"br{k}{f0}", [bot.lerp(top, f0), bot2.lerp(top2, f1)], 0.05, 4, rust)
            )
            parts.append(
                A.tube(f"bs{k}{f0}", [bot.lerp(top, f1), bot2.lerp(top2, f0)], 0.05, 4, rust)
            )
    parts.append(
        A.tube(
            "catwalk",
            [
                Vector((math.cos(t) * 3.25, math.sin(t) * 3.25, 8.6))
                for t in np.linspace(0, 2 * math.pi, 29)
            ],
            0.06,
            4,
            rust,
            cap=False,
        )
    )
    o = A.join(parts, "water_tower")
    A.tile_uv(o)
    A.bake_down(o, 1024, W2, "water_tower", ao_dist=1.0)
    done(o, "water_tower")


def ramp_rock():
    """World-2 kicker skin: sandstone rock lip, same 4.6 x 3.65 x 1.15 footprint as ramp.glb."""
    A.reset()
    rock = A.src_mat("rock", A.ph_tex("cliff_side"), scale=0.45)
    W, L, H = 4.6, 3.65, 1.15
    nx, ny = 12, 14
    verts, faces = [], []
    rnd = random.Random(2)
    for j in range(ny):
        for i in range(nx):
            u = i / (nx - 1)
            v = j / (ny - 1)
            z = H * v**1.7
            jitter = 0.04 * rnd.uniform(-1, 1) if 0 < i < nx - 1 else 0
            verts.append(((u - 0.5) * (W + 0.6 * (1 - v)), v * L - L / 2, max(0.0, z + jitter)))
    for j in range(ny - 1):
        for i in range(nx - 1):
            a = j * nx + i
            faces.append((a, a + 1, a + nx + 1, a + nx))
    o = A.mesh_obj("ramp_rock", verts, faces)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    edge = [e for e in bm.edges if e.is_boundary]
    ext = bmesh.ops.extrude_edge_only(bm, edges=edge)
    for v in [g for g in ext["geom"] if isinstance(g, bmesh.types.BMVert)]:
        v.co.z = -0.05
        v.co.x *= 1.08
        v.co.y = max(min(v.co.y, L / 2 + 0.25), -L / 2 - 0.4)
    bm.to_mesh(o.data)
    bm.free()
    o.data.materials.append(rock)
    for p in o.data.polygons:
        p.use_smooth = True
    A.tile_uv(o)
    A.bake_down(o, 512, W2, "ramp_rock", ao_dist=0.5)
    done(o, "ramp_rock")


ALL = {
    f.__name__: f
    for f in (
        boost_pad,
        ramp,
        swap_gate,
        finish_arch,
        hoverboard,
        hay_bale,
        mud_puddle,
        fence_rail,
        tape_stake,
        tumbleweed,
        sand_drift,
        water_tower,
        ramp_rock,
    )
}

if __name__ == "__main__":
    for n in argv or list(ALL):
        ALL[n]()
    for k, v in REPORT.items():
        print("SIZE", k, v)
