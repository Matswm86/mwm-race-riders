"""World 6 "Nattehavna / Night Harbour": containers, crane-jump stack, gantry crane, air ring, wet steel plates,
traffic cones, cable spools, sodium lamps, ferry, warehouse, distant lit bridge, quay props.

Night rule (DESIGN 11): light comes from emissive textures + additive glow/light-pool sprites; at most 2 real
omni lights near the track. Every lamp head / window / warning light is in the GLB's emission map.

blender -b --factory-startup -P tools/art/build_w6.py -- [names...]
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from w36_lib import *  # noqa: F401,F403,E402

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
W = 6
SODIUM = (1.0, 0.55, 0.18)
CONTAINER_COLOURS = {"red": "#8E2A1F", "blue": "#1F4E8C", "green": "#2E6B3A", "grey": "#8C9196", "orange": "#B8541E",
                     "white": "#D8D8D2"}


def grime(name, hexc, rough=0.5, metal=0.3, scale=0.4):
    """Painted steel with real wear: the grey of a rust scan, multiplied by the paint colour."""
    g = gray_tex(A.ph_tex("rusty_metal_02"), "rusty_metal_02", sat=0.25, gain=1.35)
    c = A.hex_rgb(hexc)
    return mat(name, g, scale=scale, tint=c, rough=rough, metal=metal)


def corrugated_panel(name, length, width, pitch=0.3, depth=0.035, m=None):
    """Trapezoid corrugation (real ISO container sides) as geometry, in the XY plane (x = length, y = 0..width),
    ribs bulging to +Z, normals +Z. Reads at chase distance and costs ~8 tris per wave."""
    prof = []
    n = int(length / pitch)
    for i in range(n):
        x0 = -length / 2 + i * pitch
        prof += [(x0, 0.0), (x0 + pitch * 0.18, depth), (x0 + pitch * 0.5, depth), (x0 + pitch * 0.68, 0.0)]
    prof.append((length / 2, 0.0))
    verts, faces = [], []
    for x, d in prof:
        verts += [(x, 0.0, d), (x, width, d)]
    for k in range(len(prof) - 1):
        a = 2 * k
        faces.append((a, a + 2, a + 3, a + 1))
    o = A.mesh_obj(name, verts, faces)
    if sum(p.normal.z for p in o.data.polygons) < 0:
        for p in o.data.polygons:
            p.flip()
    if m is not None:
        o.data.materials.append(m)
    return o


def container_parts(prefix, paint, frame, loc=(0, 0, 0), rot=0.0, doors=True):
    """40 ft ISO container (12.19 x 2.44 x 2.59 m) along X, corrugated long sides and roof, frame, doors at +X."""
    L, Wd, H = 12.19, 2.44, 2.59
    parts = []
    hs = H - 0.32
    for s in (-1, 1):
        side = corrugated_panel(f"{prefix}side{s}", L - 0.3, hs, m=paint)
        if s < 0:
            side.rotation_euler = (math.pi / 2, 0, 0)
            side.location = (0, -Wd / 2 + 0.05, 0.16)
        else:
            side.rotation_euler = (-math.pi / 2, 0, 0)
            side.location = (0, Wd / 2 - 0.05, 0.16 + hs)
        A.apply_xform(side)
        parts.append(side)
    roof = corrugated_panel(f"{prefix}roof", L - 0.3, Wd - 0.2, pitch=0.25, depth=0.02, m=paint)
    roof.location = (0, -(Wd - 0.2) / 2, H - 0.06)
    A.apply_xform(roof)
    parts.append(roof)
    parts.append(cube(f"{prefix}core", (L - 0.32, Wd - 0.12, H - 0.3), (0, 0, H / 2), paint))
    for x in (-L / 2 + 0.08, L / 2 - 0.08):
        for y in (-Wd / 2 + 0.08, Wd / 2 - 0.08):
            parts.append(cube(f"{prefix}post{x}{y}", (0.17, 0.17, H), (x, y, H / 2), frame))
    for z in (0.08, H - 0.08):
        for y in (-Wd / 2 + 0.06, Wd / 2 - 0.06):
            parts.append(cube(f"{prefix}rail{z}{y}", (L, 0.12, 0.16), (0, y, z), frame))
        for x in (-L / 2 + 0.06, L / 2 - 0.06):
            parts.append(cube(f"{prefix}end{z}{x}", (0.12, Wd, 0.16), (x, 0, z), frame))
    parts.append(cube(f"{prefix}endwall", (0.06, Wd - 0.2, H - 0.3), (-L / 2 + 0.05, 0, H / 2), paint))
    if doors:
        parts.append(cube(f"{prefix}doors", (0.06, Wd - 0.2, H - 0.3), (L / 2 - 0.05, 0, H / 2), paint))
        for y in (-0.85, -0.35, 0.35, 0.85):
            parts.append(cyl(f"{prefix}bar{y}", 0.022, H - 0.35, (L / 2 + 0.0, y, H / 2), frame, 6))
    M = Matrix.Translation(Vector(loc)) @ Matrix.Rotation(rot, 4, "Z")
    for p in parts:
        p.matrix_world = M @ p.matrix_world
        A.apply_xform(p)
    return parts


# ---------------------------------------------------------------- containers
def container():
    """One 40 ft container in neutral light-grey paint: dress it per instance with MultiMesh instance colours
    (CONTAINER_COLOURS in this script; Godot: use_colors + vertex_color_use_as_albedo). ~1.3k tris."""
    A.reset()
    paint = grime("paint", "#C9CBCB", rough=0.45)
    frame = grime("frame", "#9A9C9C", rough=0.5)
    parts = container_parts("c", paint, frame)
    o = join(parts, "container")
    bake(o, W, "container", 1024, ao_dist=0.6)
    done(o, W, "container", "40 ft, along X; tint per instance: red #8E2A1F, blue #1F4E8C, green #2E6B3A, grey #8C9196, orange #B8541E")


def container_far():
    """LOD / far version of container.glb (beyond 40 m): a 12-triangle box whose albedo and normal carry the
    corrugation (container_side scan, greyed so the same per-instance colours apply)."""
    A.reset()
    g = gray_tex(A.ph_tex("container_side"), "container_side_light", sat=0.0, gain=1.25)
    paint = mat("paint", g, scale=0.42, tint=(0.95, 0.95, 0.95), rough=0.45, metal=0.3, rot=90)
    o = cube("container_far", (12.19, 2.44, 2.59), (0, 0, 1.295), paint)
    bake(o, W, "container_far", 256, ao_dist=0.5, ao_k=0.4)
    done(o, W, "container_far", "LOD1 of container.glb (swap at 40 m); same per-instance tint")


def container_stack_far():
    """Background container rows: 48 boxes (4 rows x 6 x 2 high) in mixed paint, 12 tris each, one baked atlas.
    For 150 m+ (no corrugation geometry; the albedo carries it)."""
    A.reset()
    cols = list(CONTAINER_COLOURS.values())
    rnd = random.Random(6)
    mats = {h: grime(f"p{h}", h, scale=0.25) for h in cols}
    parts = []
    for row in range(4):
        for i in range(6):
            for lvl in range(rnd.choice((1, 2, 2, 3))):
                h = rnd.choice(cols)
                parts.append(cube(f"b{row}{i}{lvl}", (12.15, 2.4, 2.55), (i * 12.4 - 31, row * 2.6, 1.28 + lvl * 2.6), mats[h]))
    o = join(parts, "container_stack_far")
    bake(o, W, "container_stack_far", 512, ao_dist=1.0)
    done(o, W, "container_stack_far", "far rows only (150 m+)")


def crane_jump_stack():
    """Signature launch: a steel approach ramp (10.6 m wide, 16 m long, up 2.75 m) onto a row of four containers
    (9.8 m wide, rides along their roofs), ending in the steel kicker lip at +Y. Origin = foot of the ramp; the
    kicker lip (top) is at y 31.2, z 3.9."""
    A.reset()
    galv = flat("galv", "#8F949A", rough=0.4, metal=1.0)
    plate = mat("plate", tset(W, "steel_plate"), scale=0.6, rough=0.3, metal=0.9)
    frame = grime("frame", "#77797B")
    parts = []
    cols = ["#8E2A1F", "#1F4E8C", "#2E6B3A", "#B8541E"]
    for k, h in enumerate(cols):
        parts += container_parts(f"k{k}", grime(f"p{k}", h), frame, loc=(-3.66 + k * 2.44, 16.0 + 6.1, 0.0), rot=math.pi / 2, doors=(k % 2 == 0))
    # approach ramp: deck plate + girders + legs
    L, Hh, Wd = 16.0, 2.75, 10.6
    ang = math.atan2(Hh, L)
    ln = math.hypot(L, Hh)
    parts.append(cube("deck", (Wd, ln, 0.06), (0, L / 2, Hh / 2), plate, rot=(ang, 0, 0)))
    for x in (-Wd / 2 + 0.15, -1.8, 1.8, Wd / 2 - 0.15):
        parts.append(cube(f"gird{x}", (0.25, ln, 0.45), (x, L / 2, Hh / 2 - 0.26), galv, rot=(ang, 0, 0)))
        for t in (0.35, 0.65, 0.95):
            parts.append(cube(f"leg{x}{t}", (0.2, 0.2, Hh * t), (x, L * t, Hh * t / 2), galv))
    # roof walkway plates over the container corrugation + kicker lip at the far end
    parts.append(cube("roofplate", (Wd, 12.4, 0.04), (0, 16.0 + 6.2, 2.62), plate))
    kL, kH = 3.0, 1.2
    prof = [(kL * i / 10, kH * (i / 10) ** 1.7) for i in range(11)]
    for i in range(10):
        y0, z0 = prof[i]
        y1, z1 = prof[i + 1]
        c = Vector((0, 28.2 + (y0 + y1) / 2, 2.64 + (z0 + z1) / 2))
        parts.append(cube(f"kick{i}", (Wd, math.hypot(y1 - y0, z1 - z0) + 0.01, 0.05), c, plate,
                          rot=(math.atan2(z1 - z0, y1 - y0), 0, 0)))
    parts.append(cube("kickback", (Wd, 0.1, kH), (0, 28.2 + kL, 2.64 + kH / 2), galv))
    for s in (-1, 1):  # handrails along the approach (side safety, at the outer edge)
        pts = [Vector((s * (Wd / 2 + 0.05), y, Hh * min(1, y / L) + 1.0)) for y in np.linspace(0, 28, 15)]
        parts.append(tube(f"hr{s}", pts, 0.03, 6, galv))
    o = join(parts, "crane_jump_stack")
    bake(o, W, "crane_jump_stack", 1024, ao_dist=0.8)
    done(o, W, "crane_jump_stack", "ride along +Y; lip at y 31.2 m, z 3.84 m; flight goes through gantry_crane")


def ramp_steel():
    """World-6 kicker skin for K1/K2/K4: steel plate kicker, same 4.6 x 3.65 x 1.15 footprint as ramp.glb."""
    A.reset()
    plate = mat("plate", tset(W, "steel_plate"), scale=0.6, rough=0.3, metal=0.9)
    galv = flat("galv", "#8F949A", rough=0.4, metal=1.0)
    paint = flat("edge", "#E6E3DA", rough=0.5)
    Wd, L, H = 4.6, 3.65, 1.15
    prof = [(L * i / 12, H * (i / 12) ** 1.7) for i in range(13)]
    parts = []
    for i in range(12):
        y0, z0 = prof[i]
        y1, z1 = prof[i + 1]
        parts.append(cube(f"p{i}", (Wd, math.hypot(y1 - y0, z1 - z0) + 0.005, 0.03),
                          (0, (y0 + y1) / 2 - L / 2, (z0 + z1) / 2), plate, rot=(math.atan2(z1 - z0, y1 - y0), 0, 0)))
    for x in (-Wd / 2 + 0.08, 0, Wd / 2 - 0.08):
        parts.append(tube(f"s{x}", [Vector((x, y - L / 2, z - 0.06)) for y, z in prof], 0.05, 4, galv))
    parts.append(cube("back", (Wd, 0.05, H), (0, L / 2 - 0.025, H / 2), galv))
    parts.append(cube("lip", (Wd, 0.12, 0.04), (0, L / 2 - 0.06, H + 0.0), paint))  # white painted lip (no stripes)
    o = join(parts, "ramp_steel")
    bake(o, W, "ramp_steel", 512, ao_dist=0.4)
    done(o, W, "ramp_steel", "kicker skin, same footprint as ramp.glb")


def gantry_crane():
    """Ship-to-shore gantry crane: legs 30 m apart across the track (riders fly through the portal along +Y),
    portal beam at 38 m, boom from -22 m (backreach) to +55 m over the water at 44 m, A-frame apex 66 m,
    trolley + spreader, machinery house, red aviation lights and sodium floods in the emission map."""
    A.reset()
    paint = grime("paint", "#C7CDD1", rough=0.45)
    accent = grime("accent", "#9E2A22", rough=0.45)
    dark = flat("dark", "#2A2D31", rough=0.6, metal=0.4)
    red_l = flat("redlight", "#FF2A1A", rough=0.3, emit=(1.0, 0.12, 0.06))
    flood = flat("flood", "#FFD08A", rough=0.3, emit=SODIUM)
    parts = []
    X, Y = 15.0, 9.0  # legs at x +-15, y +-9
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(cube(f"leg{sx}{sy}", (1.6, 1.6, 38), (sx * X, sy * Y, 19), paint))
            parts.append(cube(f"bogie{sx}{sy}", (1.4, 4.5, 1.6), (sx * X, sy * Y, 0.8), dark))
        parts.append(cube(f"sill{sx}", (1.4, 2 * Y + 1.6, 1.8), (sx * X, 0, 12), paint))
        parts.append(cube(f"tsill{sx}", (1.6, 2 * Y + 1.6, 2.2), (sx * X, 0, 38.5), paint))
        for sy in (-1, 1):  # diagonal braces in the side frames
            parts.append(tube(f"brace{sx}{sy}", [Vector((sx * X, sy * Y, 13)), Vector((sx * X, -sy * Y, 37))], 0.35, 6, paint))
    for sy in (-1, 1):
        parts.append(cube(f"portal{sy}", (2 * X + 1.6, 1.8, 2.4), (0, sy * Y, 38.5), paint))
    # boom: two box girders along Y with lacing
    for sx in (-1, 1):
        parts.append(cube(f"boom{sx}", (1.2, 77, 3.2), (sx * 4.0, 16.5, 44.0), paint))
        for k in range(16):
            y = -21 + k * 5
            parts.append(cube(f"cross{sx}{k}", (8.0, 0.4, 0.4), (0, y, 42.6), paint) if sx < 0 else
                         tube(f"lace{k}", [Vector((-4, y, 45.4)), Vector((4, y + 2.5, 42.6))], 0.12, 4, paint))
    # A-frame + forestays + backstays
    for sx in (-1, 1):
        parts.append(tube(f"af{sx}", [Vector((sx * X, -Y, 39.5)), Vector((sx * 4.0, -2, 66))], 0.7, 6, accent))
        parts.append(tube(f"af2{sx}", [Vector((sx * X, Y, 39.5)), Vector((sx * 4.0, -2, 66))], 0.6, 6, accent))
        parts.append(tube(f"fs{sx}", [Vector((sx * 4.0, -2, 66)), Vector((sx * 4.0, 48, 45.5))], 0.12, 4, dark))
        parts.append(tube(f"bs{sx}", [Vector((sx * 4.0, -2, 66)), Vector((sx * 4.0, -20, 45.5))], 0.12, 4, dark))
    parts.append(cube("apex", (9.5, 2.0, 1.6), (0, -2, 66.4), accent))
    parts.append(cube("house", (10, 12, 6), (0, -14, 49.5), paint))
    parts.append(cube("cab", (3.0, 3.0, 2.6), (2.5, 14, 41.4), dark))
    parts.append(cube("trolley", (7.5, 4.5, 1.6), (0, 14, 46.4), dark))
    for sx in (-2.5, 2.5):
        parts.append(tube(f"wire{sx}", [Vector((sx, 14, 45.5)), Vector((sx, 14, 30.5))], 0.04, 4, dark))
    parts.append(cube("spreader", (6.5, 2.6, 0.8), (0, 14, 30.0), accent))
    # lights: aviation red at the apex and boom tip, sodium floods under the boom and portal
    for p in ((0, -2, 67.4), (4.0, 54.5, 46), (-4.0, 54.5, 46), (X, 0, 40), (-X, 0, 40)):
        parts.append(cube(f"av{p}", (0.5, 0.5, 0.5), p, red_l))
    for y in (-15, -5, 5, 15, 25, 35, 45):
        for sx in (-4.0, 4.0):
            parts.append(cube(f"fl{y}{sx}", (0.9, 0.6, 0.25), (sx, y, 42.3), flood))
    for sx in (-1, 1):
        parts.append(cube(f"pfl{sx}", (1.0, 0.6, 0.3), (sx * 9, 0, 37.2), flood))
    o = join(parts, "gantry_crane")
    bake(o, W, "gantry_crane", 1024, ao_dist=3.0, ao_k=0.6, want_emission=True)
    done(o, W, "gantry_crane", "legs at x +-15 m (track passes between), boom over +Y; aviation lights blink < 1 Hz")


def air_ring():
    """Air ring (GDD 6.0): 5.2 m ring, steel tube with an amber LED band on the inner face ("speed for you" amber,
    DESIGN 3). Hangs from two thin cables to the crane boom (cables included, 12 m)."""
    A.reset()
    steel = flat("steel", "#4A4E54", rough=0.35, metal=0.9)
    led = flat("led", "#FFB000", rough=0.3, emit=(1.0, 0.69, 0.0))
    bpy.ops.mesh.primitive_torus_add(major_radius=2.6, minor_radius=0.2, major_segments=40, minor_segments=10,
                                     rotation=(math.pi / 2, 0, 0), location=(0, 0, 0))
    o = bpy.context.active_object
    A.apply_xform(o)
    o.data.materials.append(steel)
    o.data.materials.append(led)
    for p in o.data.polygons:
        r = Vector((p.center.x, 0, p.center.z)).length
        if r < 2.47:
            p.material_index = 1
    smooth(o)
    parts = [o]
    for sx in (-1.6, 1.6):
        z0 = math.sqrt(2.6**2 - sx**2) + 0.15
        parts.append(tube(f"cab{sx}", [Vector((sx, 0, z0)), Vector((sx * 0.6, 0, 12.0))], 0.012, 4, steel))
    o = join(parts, "air_ring")
    for v in o.data.vertices:
        v.co.z += 2.8  # origin at the bottom of the ring
    bake(o, W, "air_ring", 512, ao_dist=0.2, want_emission=True)
    done(o, W, "air_ring", "ring plane faces +-Y (fly along +Y through it); origin at ring bottom; cables to 14.8 m")


# ---------------------------------------------------------------- hindrances
def steel_plate():
    """Patch (slides like ice): three wet steel road plates (2.4 x 6 m, 25 mm) laid over the asphalt, 7 x 10 m."""
    A.reset()
    plate = mat("plate", tset(W, "steel_plate"), scale=0.5, rough=0.14, metal=0.85)
    parts = []
    rnd = random.Random(3)
    for k, x in enumerate((-2.4, 0.0, 2.4)):
        p = cube(f"pl{k}", (2.38, 6.0, 0.025), (x + rnd.uniform(-0.08, 0.08), rnd.uniform(-1.5, 1.5), 0.0125), plate,
                 bevel=0.008, rot=(0, 0, rnd.uniform(-0.03, 0.03)))
        parts.append(p)
        for bx in (-0.95, 0.95):
            for by in (-2.7, 2.7):
                parts.append(cyl(f"bolt{k}{bx}{by}", 0.03, 0.02, (x + bx, p.location.y + by, 0.03), flat("bolt", "#55585C", 0.4, 0.9), 6))
    o = join(parts, "steel_plate")
    bake(o, W, "steel_plate", 512, ao_dist=0.1)
    done(o, W, "steel_plate", "opaque, glossy (roughness 0.14); slide like ice")


def traffic_cone():
    """Block x0.95: 75 cm road cone, fluorescent orange with two white retro-reflective bands, black base."""
    A.reset()
    orange = flat("orange", "#F05A1A", rough=0.55)
    white = flat("band", "#EDEDE8", rough=0.35)
    base = flat("base", "#1B1C1E", rough=0.7)
    parts = [cube("base", (0.4, 0.4, 0.035), (0, 0, 0.0175), base, bevel=0.02)]
    bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=0.15, radius2=0.03, depth=0.72, location=(0, 0, 0.39))
    c = bpy.context.active_object
    c.data.materials.append(orange)
    c.data.materials.append(white)
    sub = c.modifiers.new("s", "SUBSURF")
    sub.levels = 2
    sub.subdivision_type = "SIMPLE"
    A.apply_all(c)
    for p in c.data.polygons:
        if 0.42 < p.center.z < 0.52 or 0.6 < p.center.z < 0.66:
            p.material_index = 1
    smooth(c)
    parts.append(c)
    o = join(parts, "traffic_cone")
    decimate_to(o, 420)
    bake(o, W, "traffic_cone", 256, ao_dist=0.1)
    done(o, W, "traffic_cone")


def cable_spool():
    """Roller: wooden cable drum, 1.6 m flanges, 1.0 m wide, black cable wound on it. Axle along Y, so it rolls
    across the track (X). Spin about (0, 0.8, 0) Godot."""
    A.reset()
    wood = mat("wood", A.ph_tex("weathered_planks"), scale=0.8, tint=(0.85, 0.75, 0.6))
    cable = flat("cable", "#141517", rough=0.45)
    steel = flat("steel", "#6E7176", rough=0.4, metal=0.9)
    parts = []
    for y in (-0.47, 0.47):
        parts.append(cyl(f"fl{y}", 0.8, 0.06, (0, y, 0.8), wood, 28, rot=(math.pi / 2, 0, 0)))
    parts.append(cyl("cable", 0.62, 0.88, (0, 0, 0.8), cable, 28, rot=(math.pi / 2, 0, 0)))
    for k in range(8):  # cable wraps (rings) for silhouette
        y = -0.4 + k * 0.115
        bpy.ops.mesh.primitive_torus_add(major_radius=0.62, minor_radius=0.04, major_segments=24, minor_segments=6,
                                         rotation=(math.pi / 2, 0, 0), location=(0, y, 0.8))
        t = bpy.context.active_object
        t.data.materials.append(cable)
        parts.append(t)
    parts.append(cyl("hub", 0.12, 1.1, (0, 0, 0.8), steel, 12, rot=(math.pi / 2, 0, 0)))
    for k in range(6):
        a = k * math.pi / 3
        for y in (-0.51, 0.51):
            parts.append(cyl(f"bolt{k}{y}", 0.025, 0.04, (math.cos(a) * 0.35, y, 0.8 + math.sin(a) * 0.35), steel, 6, rot=(math.pi / 2, 0, 0)))
    o = join(parts, "cable_spool")
    smooth(o)
    bake(o, W, "cable_spool", 512, ao_dist=0.3)
    done(o, W, "cable_spool", "Roller: axle along Godot Z (Blender Y); rolls across the track; spin about (0, 0.8, 0)")


# ---------------------------------------------------------------- landmarks and props
def sodium_lamp():
    """Quay lamp mast, 12 m, two sodium heads (emission). Pair with fx_sodium_glow (billboard) and fx_light_pool
    (ground decal); only the 2 lamps nearest the camera get a real OmniLight on Høy."""
    A.reset()
    galv = flat("galv", "#8A8F95", rough=0.45, metal=0.9)
    head = flat("head", "#2C2F33", rough=0.5, metal=0.6)
    lens = flat("lens", "#FFC27A", rough=0.2, emit=SODIUM)
    parts = [cyl("mast", 0.11, 12.0, (0, 0, 6.0), galv, 10), cyl("foot", 0.25, 0.4, (0, 0, 0.2), galv, 10)]
    for s in (-1, 1):
        parts.append(tube(f"arm{s}", [Vector((0, 0, 11.6)), Vector((s * 0.9, 0, 12.0)), Vector((s * 1.6, 0, 12.0))], 0.05, 6, galv))
        parts.append(cube(f"head{s}", (0.75, 0.35, 0.18), (s * 1.75, 0, 11.95), head, bevel=0.03))
        parts.append(cube(f"lens{s}", (0.6, 0.26, 0.03), (s * 1.75, 0, 11.85), lens))
    o = join(parts, "sodium_lamp")
    bake(o, W, "sodium_lamp", 256, ao_dist=0.2, want_emission=True)
    done(o, W, "sodium_lamp", "heads along X at 11.85 m (+-1.75 m)")


def ferry():
    """Moored car ferry, 112 m: dark-blue hull, white superstructure with lit window rows, bridge, funnel,
    lifeboats, mast lights. For 120 m+ (across the channel)."""
    A.reset()
    hull = grime("hull", "#1C2E4A", rough=0.4, scale=0.1)
    white = grime("white", "#DADAD4", rough=0.45, scale=0.15)
    win = flat("win", "#FFDCA0", rough=0.2, emit=(1.0, 0.78, 0.45))
    dark = flat("dark", "#1A1C1F", rough=0.5)
    orange = flat("boat", "#D8661E", rough=0.5)
    red_l = flat("red", "#FF2A1A", rough=0.3, emit=(1.0, 0.12, 0.06))
    parts = []
    L, B = 112.0, 20.0
    prof = []  # hull plan: pointed bow at +X
    for i in range(17):
        t = i / 16
        x = -L / 2 + t * L
        half = B / 2 * (1 - max(0.0, (t - 0.78) / 0.22) ** 1.8)
        prof.append((x, half))
    verts, faces = [], []
    for (x, h) in prof:
        verts += [(x, -h * 0.92, 0.0), (x, -h, 9.0), (x, h, 9.0), (x, h * 0.92, 0.0)]
    for i in range(len(prof) - 1):
        a = 4 * i
        for q in range(4):
            faces.append((a + q, a + (q + 1) % 4, a + 4 + (q + 1) % 4, a + 4 + q))
    faces.append((0, 1, 2, 3)[::-1])
    faces.append(tuple(range(4 * (len(prof) - 1), 4 * len(prof))))
    h = A.mesh_obj("hull", verts, faces)
    h.data.materials.append(hull)
    parts.append(h)
    decks = [(-46, 34, 9, 4.0), (-40, 26, 13, 3.4), (-30, 14, 16.4, 3.2)]
    for k, (x0, x1, z, hh) in enumerate(decks):
        parts.append(cube(f"deck{k}", (x1 - x0, B - 2 - 2 * k, hh), ((x0 + x1) / 2, 0, z + hh / 2), white))
        for s in (-1, 1):
            n = int((x1 - x0) / 2.2)
            for i in range(n):
                if (i * 7 + k * 3) % 5 == 0:
                    continue  # a few dark windows
                parts.append(cube(f"w{k}{s}{i}", (1.4, 0.05, 1.0), (x0 + 1.1 + i * 2.2, s * ((B - 2 - 2 * k) / 2 + 0.03), z + hh * 0.55), win))
    parts.append(cube("bridge", (8, B - 4, 3), (16, 0, 21.2), white))
    for s in (-1, 1):
        parts.append(cube(f"bw{s}", (7.6, 0.05, 1.2), (16, s * (B / 2 - 1.97), 21.8), win))
    parts.append(cube("bwf", (0.05, B - 5, 1.2), (20.03, 0, 21.8), win))
    parts.append(cube("funnel", (7, 5, 9), (-26, 0, 24), white))
    parts.append(cube("funneltop", (7.2, 5.2, 1.6), (-26, 0, 29.3), dark))
    for i in range(4):
        for s in (-1, 1):
            parts.append(cube(f"lb{i}{s}", (6, 2.2, 1.8), (-32 + i * 12, s * (B / 2 - 0.2), 14.2), orange, bevel=0.3))
    parts.append(cyl("mast", 0.3, 14, (24, 0, 29.6), white, 8))
    parts.append(cube("mastlight", (0.6, 0.6, 0.6), (24, 0, 36.8), red_l))
    o = join(parts, "ferry")
    bake(o, W, "ferry", 1024, ao_dist=2.0, ao_k=0.6, want_emission=True)
    done(o, W, "ferry", "waterline at z 0; place 120 m+ across the channel")


def warehouse():
    """Port warehouse 50 x 24 x 12 m: corrugated cladding, low-pitch roof, three roller doors, a few lit office
    windows and door lamps (emission)."""
    A.reset()
    g = gray_tex(A.ph_tex("factory_wall"), "factory_wall", sat=0.15, gain=1.2)
    clad = mat("clad", g, scale=0.25, tint=(0.55, 0.6, 0.62), rough=0.5, metal=0.4)
    roof = grime("roof", "#5B5F63", scale=0.1)
    door = grime("door", "#8B8F93", scale=0.3)
    conc = mat("conc", tset(W, "quay_wall"), scale=0.4)
    win = flat("win", "#FFE2B0", rough=0.2, emit=(1.0, 0.82, 0.55))
    lamp = flat("lamp", "#FFC27A", rough=0.2, emit=SODIUM)
    parts = [cube("plinth", (50.4, 24.4, 1.0), (0, 0, 0.5), conc), cube("body", (50, 24, 11), (0, 0, 6.5), clad)]
    verts = [(-25.4, -12.4, 12), (25.4, -12.4, 12), (25.4, 0, 14.2), (-25.4, 0, 14.2), (25.4, 12.4, 12), (-25.4, 12.4, 12)]
    r = A.mesh_obj("roof", verts, [(0, 1, 2, 3), (3, 2, 4, 5)])
    s = r.modifiers.new("s", "SOLIDIFY")
    s.thickness = 0.25
    A.apply_all(r)
    r.data.materials.append(roof)
    parts.append(r)
    for x in (-25, 25):
        g2 = A.mesh_obj(f"gab{x}", [(x, -12, 12), (x, 12, 12), (x, 0, 14.0)], [(0, 1, 2)])
        g2.data.materials.append(clad)
        parts.append(g2)
    for k, x in enumerate((-15, 0, 15)):
        parts.append(cube(f"door{k}", (6.0, 0.15, 6.5), (x, -12.05, 4.25), door))
        parts.append(cube(f"dl{k}", (0.5, 0.35, 0.25), (x, -12.3, 8.2), lamp))
    for x in (-22, -20, 20, 22):
        parts.append(cube(f"win{x}", (1.4, 0.06, 1.1), (x, -12.04, 8.8), win))
    o = join(parts, "warehouse")
    bake(o, W, "warehouse", 1024, ao_dist=2.0, ao_k=0.6, want_emission=True)
    done(o, W, "warehouse", "doors face -Y")


def lit_bridge_far():
    """Distant cable-stayed bridge (1.1 km) with deck lights and red pylon-top lights, for 700 m+ out."""
    A.reset()
    conc = flat("conc", "#7F8285", rough=0.7)
    dark = flat("deck", "#3A3D41", rough=0.6)
    lamp = flat("lamp", "#FFC27A", rough=0.2, emit=SODIUM)
    red_l = flat("red", "#FF2A1A", rough=0.3, emit=(1.0, 0.12, 0.06))
    white_l = flat("pylonlight", "#D8E4F0", rough=0.3, emit=(0.55, 0.62, 0.7))
    parts = [cube("deck", (1100, 24, 2.5), (0, 0, 42), dark)]
    for x in (-180, 180):
        for s in (-1, 1):
            parts.append(cube(f"py{x}{s}", (5, 3, 150), (x, s * 9, 75), conc))
            parts.append(cube(f"pyl{x}{s}", (5.2, 0.2, 140), (x, s * 9 - 1.6, 75), white_l))  # floodlit face
        parts.append(cube(f"pyx{x}", (5, 21, 4), (x, 0, 146), conc))
        parts.append(cube(f"av{x}", (3, 3, 3), (x, 0, 150), red_l))
        for k in range(1, 12):
            for d in (-1, 1):
                xe = x + d * k * 16
                for s in (-1, 1):
                    parts.append(tube(f"st{x}{k}{d}{s}", [Vector((x, s * 9, 140 - k * 4)), Vector((xe, s * 11, 43))], 0.25, 3, conc, cap=False))
    for x in range(-540, 541, 30):
        for s in (-1, 1):
            parts.append(cube(f"dl{x}{s}", (1.2, 0.8, 0.8), (x, s * 11.5, 44.2), lamp))
    for x in range(-500, 501, 125):
        if abs(x) != 125:
            parts.append(cube(f"pier{x}", (8, 14, 42), (x, 0, 21), conc))
    o = join(parts, "lit_bridge_far")
    bake(o, W, "lit_bridge_far", 1024, ao_dist=5.0, ao_k=0.4, want_emission=True)
    done(o, W, "lit_bridge_far", "deck at 42 m; place 700-1500 m out across the water, no shadow")


def bollard():
    """Cast-iron mooring bollard (0.6 m) on the quay edge."""
    A.reset()
    iron = grime("iron", "#2B2D30", rough=0.5, metal=0.7)
    prof = [(0.0, 0.0), (0.28, 0.0), (0.28, 0.06), (0.18, 0.12), (0.16, 0.42), (0.24, 0.5), (0.25, 0.58), (0.0, 0.6)]
    verts, faces = [], []
    n = 16
    for (r, z) in prof:
        for i in range(n):
            a = 2 * math.pi * i / n
            verts.append((r * math.cos(a), r * math.sin(a), z))
    for k in range(len(prof) - 1):
        for i in range(n):
            a = k * n + i
            b = k * n + (i + 1) % n
            faces.append((a, b, b + n, a + n))
    o = A.mesh_obj("bollard", verts, faces)
    smooth(o)
    A.activate(o)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.001)
    bpy.ops.object.mode_set(mode="OBJECT")
    o.data.materials.append(iron)
    bake(o, W, "bollard", 256, ao_dist=0.1)
    done(o, W, "bollard")


def concrete_barrier():
    ph_decimated("concrete_road_barrier", None, W, "concrete_barrier", 160, scale=1.0, rough_mul=0.7,
                 note="quay/jersey barrier 1.55 m (track edge in the container yard)")


def sea_marker():
    ph_decimated("lateral_sea_marker", None, W, "sea_marker", 1200, scale=1.0,
                 note="channel buoy (6.8 m, 1.3 m under the waterline)")


ALL = {f.__name__: f for f in (container, container_far, container_stack_far, crane_jump_stack, ramp_steel, gantry_crane, air_ring,
                               steel_plate, traffic_cone, cable_spool, sodium_lamp, ferry, warehouse, lit_bridge_far,
                               bollard, concrete_barrier, sea_marker)}

if __name__ == "__main__":
    run(ALL, argv)
