"""Landmarks skipped for worlds 1-2 (GDD 6.0) and the World 2 canyon fix.

World 1: cabin (log cabin with a turf roof), river_bridge (K2 bridge hump, 10.4 m deck), rock_tunnel_portal +
         rock_tunnel_segment (8 m wide, 6 m high, 10 m segments).
World 2: sandstone_arch, gas_station, canyon_cliff_a/b (real cliff scans re-skinned with the level-strata wall
         layer), mesa_backdrop (120-degree ring segment that closes the horizon; use three copies).

blender -b --factory-startup -P tools/art/build_landmarks12.py -- [names...]
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from w36_lib import *  # noqa: F401,F403,E402

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def w2set(name):
    return tset(2, name)


# ---------------------------------------------------------------- World 1
def cabin():
    """Norwegian log cabin, 7.2 x 5.2 m, notched corners with protruding log ends, turf (sod) roof with birch
    edge boards, stone footing, white-framed windows, stone chimney. Door faces -Y."""
    A.reset()
    W = 1
    logs = mat("logs", A.ph_tex("pine_bark"), scale=0.7, tint=(0.42, 0.32, 0.24))
    ends = mat("ends", A.ph_tex("weathered_planks"), scale=2.0, tint=(0.75, 0.62, 0.45))
    trim = flat("trim", "#E9E6DD", rough=0.6)
    stone = mat("stone", w1set("rocky_trail"), scale=0.6)
    turf = mat("turf", A.ph_tex("leafy_grass"), scale=0.5, tint=(0.55, 0.68, 0.4), rough=0.9)
    edge = mat("edge", A.ph_tex("weathered_planks"), scale=0.6, tint=(0.55, 0.5, 0.45))
    glass = flat("glass", "#1A222B", rough=0.08)
    door = mat("door", A.ph_tex("weathered_planks"), scale=0.8, tint=(0.5, 0.36, 0.25))
    parts = [cube("foot", (7.6, 5.6, 0.55), (0, 0, 0.27), stone, bevel=0.06)]
    Lx, Ly, r = 7.2, 5.2, 0.13
    n = 11
    for i in range(n):
        z = 0.55 + r + i * 2 * r * 0.92
        off = r if i % 2 else 0.0
        for s in (-1, 1):
            parts.append(cyl(f"lx{i}{s}", r, Lx + 0.7, (0, s * Ly / 2, z + off * 0.0), logs, 8, rot=(0, math.pi / 2, 0)))
            parts.append(cyl(f"ly{i}{s}", r, Ly + 0.7, (s * Lx / 2, 0, z + r * 0.92), logs, 8, rot=(math.pi / 2, 0, 0)))
    wall_top = 0.55 + n * 2 * r * 0.92
    # gables (logs shortening up to the ridge) on the short ends
    ridge = wall_top + 1.7
    k = 0
    z = wall_top + r
    while z < ridge - 0.1:
        half = (Ly / 2) * (1 - (z - wall_top) / (ridge - wall_top))
        for s in (-1, 1):
            parts.append(cyl(f"g{k}{s}", r, 2 * half, (s * Lx / 2, 0, z), logs, 8, rot=(math.pi / 2, 0, 0)))
        z += 2 * r * 0.92
        k += 1
    # turf roof: two thick slabs, grass on top, edge boards
    ang = math.atan2(ridge - wall_top, Ly / 2)
    ln = math.hypot(Ly / 2, ridge - wall_top) + 0.6
    for s in (-1, 1):
        c = Vector((0, s * (Ly / 4 + 0.15), (wall_top + ridge) / 2 + 0.12))
        parts.append(cube(f"board{s}", (Lx + 1.2, ln, 0.08), c, edge, rot=(-s * ang, 0, 0)))
        t = cube(f"turf{s}", (Lx + 1.0, ln - 0.15, 0.28), c + Vector((0, 0, 0.18 / math.cos(ang))), turf, bevel=0.1, rot=(-s * ang, 0, 0))
        displace(t, 0.06, 0.6, seed=s + 5)
        parts.append(t)
        parts.append(cube(f"lip{s}", (Lx + 1.2, 0.06, 0.3), (0, s * (Ly / 2 + 0.55), wall_top - 0.18 + 0.2), edge))
    # windows and door (front -Y), side window
    for x in (-2.2, 1.8):
        parts.append(cube(f"wf{x}", (1.0, 0.1, 1.0), (x, -Ly / 2 - 0.12, 1.9), trim))
        parts.append(cube(f"wg{x}", (0.82, 0.12, 0.82), (x, -Ly / 2 - 0.13, 1.9), glass))
        parts.append(cube(f"wm{x}", (0.06, 0.13, 0.82), (x, -Ly / 2 - 0.14, 1.9), trim))
    parts.append(cube("door", (1.0, 0.12, 2.0), (-0.2, -Ly / 2 - 0.12, 1.55), door))
    parts.append(cube("doorframe", (1.2, 0.1, 2.15), (-0.2, -Ly / 2 - 0.1, 1.6), trim))
    parts.append(cube("step", (1.6, 0.8, 0.25), (-0.2, -Ly / 2 - 0.55, 0.12), stone, bevel=0.04))
    parts.append(cube("sw", (0.12, 0.9, 0.9), (Lx / 2 + 0.14, 0.6, 1.9), trim))
    parts.append(cube("swg", (0.13, 0.75, 0.75), (Lx / 2 + 0.15, 0.6, 1.9), glass))
    parts.append(cube("chim", (0.7, 0.7, 2.2), (2.0, 0.8, ridge - 0.2), stone, bevel=0.04))
    o = join(parts, "cabin")
    bake(o, W, "cabin", 1024, ao_dist=1.0)
    done(o, W, "cabin", "door faces -Y; turf roof")


def river_bridge():
    """K2 'bridge hump' (World 1, s 645): timber road bridge, 16 m long (+Y), 10.4 m deck, 1.2 m arch rise,
    three glulam arches, stone abutments, post-and-rail parapets. Deck top at z 0 at both ends."""
    A.reset()
    W = 1
    planks = mat("planks", A.ph_tex("weathered_planks"), scale=0.55, rot=90)
    timber = mat("timber", A.ph_tex("weathered_planks"), scale=0.8, tint=(0.62, 0.55, 0.48))
    stone = mat("stone", w1set("rocky_trail"), scale=0.45)
    L, Wd, rise = 16.0, 10.4, 1.2

    def z(y):
        t = y / L
        return rise * 4 * t * (1 - t)

    parts = []
    n = int(L / 0.24)
    for i in range(n):
        y = (i + 0.5) * L / n
        dz = (z(y + 0.01) - z(y - 0.01)) / 0.02
        parts.append(cube(f"pl{i}", (Wd, 0.22, 0.07), (0, y, z(y) - 0.035), planks, rot=(math.atan(dz), 0, 0)))
    for x in (-Wd / 2 + 0.4, 0.0, Wd / 2 - 0.4):
        pts = [Vector((x, y, z(y) - 0.5 - 0.6 * (1 - 4 * (y / L) * (1 - y / L)))) for y in np.linspace(0, L, 17)]
        parts.append(tube(f"arch{x}", pts, 0.28, 6, timber))
    for s in (-1, 1):
        x = s * (Wd / 2 + 0.1)
        for k in range(9):
            y = k * L / 8
            parts.append(cube(f"post{s}{k}", (0.16, 0.16, 1.15), (x, y, z(y) + 0.5), timber))
        for h in (0.55, 1.05):
            pts = [Vector((x, y, z(y) + h)) for y in np.linspace(0, L, 17)]
            parts.append(tube(f"rail{s}{h}", pts, 0.07, 6, timber))
    for y0, d in ((0.0, -1), (L, 1)):
        parts.append(cube(f"abut{y0}", (Wd + 2.0, 3.0, 3.2), (0, y0 + d * 1.3, -1.65), stone, bevel=0.15))
        for s in (-1, 1):
            parts.append(cube(f"wing{y0}{s}", (1.0, 3.6, 3.0), (s * (Wd / 2 + 1.3), y0 + d * 1.6, -1.5), stone, bevel=0.12))
    o = join(parts, "river_bridge")
    displace(o, 0.02, 0.5, seed=1)
    bake(o, W, "river_bridge", 1024, ao_dist=0.8)
    done(o, W, "river_bridge", "drive along +Y; 1.2 m hump; abutments go 3.2 m down to the river")


def _tunnel_ring(n_s, y, wob_seed, r=4.0, wall=2.0, rough=0.35):
    pts = []
    for i in range(n_s):
        t = math.pi * i / (n_s - 1)  # 0 = right floor edge, pi = left
        # straight walls up to `wall`, then a half circle of radius r on top
        perim = t / math.pi
        if perim < 0.18:
            k = perim / 0.18
            p = Vector((r, y, wall * k))
        elif perim > 0.82:
            k = (1 - perim) / 0.18
            p = Vector((-r, y, wall * k))
        else:
            a = (perim - 0.18) / 0.64 * math.pi
            p = Vector((r * math.cos(a), y, wall + r * math.sin(a)))
        d = noise.fractal(Vector((p.x / 1.3, y / 1.3 + wob_seed, p.z / 1.3)), 0.55, 2.0, 3, noise_basis="PERLIN_ORIGINAL")
        nrm = Vector((p.x, 0, max(0.0, p.z - wall))).normalized() if p.z > wall else Vector((math.copysign(1, p.x), 0, 0))
        pts.append(p + nrm * (rough * d + rough * 0.5))
    return pts


def rock_tunnel_segment():
    """10 m of rough-hewn rock tunnel (inner faces only: the hill outside is terrain). 8 m wide, 6 m high. One
    warm wall lamp in the emission map. Tile along +Y."""
    A.reset()
    W = 1
    n_r, n_s = 11, 24
    verts, faces = [], []
    for j in range(n_r):
        y = 10.0 * j / (n_r - 1)
        verts += [tuple(p) for p in _tunnel_ring(n_s, y, 0.0)]
    # make it tile: first and last ring identical (noise on y wrapped by using the same y for both)
    for i in range(n_s):
        verts[(n_r - 1) * n_s + i] = (verts[i][0], 10.0, verts[i][2])
    for j in range(n_r - 1):
        for i in range(n_s - 1):
            a = j * n_s + i
            faces.append((a, a + 1, a + n_s + 1, a + n_s))
    o = A.mesh_obj("rock_tunnel_segment", verts, faces)
    smooth(o)
    rock = mat("rock", gray_tex(A.ph_tex("rock_face_03"), "rock_face_03", sat=0.35), scale=0.35, tint=(0.72, 0.72, 0.7))
    lamp = flat("lamp", "#FFC27A", rough=0.3, emit=(1.0, 0.62, 0.28))
    o.data.materials.append(rock)
    lp = cube("lamp", (0.5, 0.15, 0.25), (3.85, 5.0, 3.6), lamp)
    o = join([o, lp], "rock_tunnel_segment")
    bake(o, W, "rock_tunnel_segment", 1024, ao_dist=2.0, ao_k=0.7, want_emission=True)
    done(o, W, "rock_tunnel_segment", "inner faces only; tile every 10 m along +Y; lower ambient inside (DESIGN 9a)")


def rock_tunnel_portal():
    """Tunnel mouth: a 34 x 16 m rock face with the 8 x 6 m opening at x 0, 6 m of rock mass behind it, and the
    first 6 m of tunnel lining. The face looks at -Y (towards the riders)."""
    A.reset()
    W = 1
    nx, nz = 35, 17
    verts, faces = [], []
    for j in range(nz):
        for i in range(nx):
            x = -17 + 34 * i / (nx - 1)
            zz = 16 * j / (nz - 1)
            top = 16 - 3.5 * (x / 17) ** 2 + 1.5 * noise.noise(Vector((x / 6, 0.3, 0)))
            zz = min(zz, top)
            lean = 1.6 * (zz / 16)  # face leans back
            d = noise.fractal(Vector((x / 3.0, 0.7, zz / 3.0)), 0.55, 2.0, 4, noise_basis="PERLIN_ORIGINAL")
            verts.append((x, lean + d * 0.9, zz))
    for j in range(nz - 1):
        for i in range(nx - 1):
            a = j * nx + i
            faces.append((a, a + 1, a + nx + 1, a + nx))
    face = A.mesh_obj("face", verts, faces)
    # cut the opening: delete faces inside the tunnel profile (|x| < 4.2, z < 2 + sqrt(r^2 - x^2))
    bm = bmesh.new()
    bm.from_mesh(face.data)
    kill = []
    for f in bm.faces:
        c = f.calc_center_median()
        if abs(c.x) < 4.5 and c.z < 2.0 + math.sqrt(max(0.0, 4.6**2 - c.x**2)):
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(face.data)
    bm.free()
    smooth(face)
    # lining: 6 m of tunnel behind the face
    n_r, n_s = 7, 24
    lv, lf = [], []
    for j in range(n_r):
        y = -0.5 + 6.5 * j / (n_r - 1)
        lv += [tuple(p) for p in _tunnel_ring(n_s, y, 3.0)]
    for j in range(n_r - 1):
        for i in range(n_s - 1):
            a = j * n_s + i
            lf.append((a, a + 1, a + n_s + 1, a + n_s))
    lining = A.mesh_obj("lining", lv, lf)
    smooth(lining)
    rock = slope_mat("rock", w1set("forest_leaves_04"), gray_tex(A.ph_tex("rock_face_03"), "rock_face_03", sat=0.35),
                     thresh=0.7, soft=0.1, scale_flat=0.4, scale_steep=0.3, tint_steep=(0.72, 0.72, 0.7))
    face.data.materials.append(rock)
    lining.data.materials.append(rock)
    o = join([face, lining], "rock_tunnel_portal")
    bake(o, W, "rock_tunnel_portal", 1024, ao_dist=2.5, ao_k=0.7)
    done(o, W, "rock_tunnel_portal", "face at y~0 looking -Y; opening 8 m wide at x 0; add rock_tunnel_segment from y 6")


# ---------------------------------------------------------------- World 2
def sandstone_arch():
    """Natural sandstone arch spanning 30 m with 17 m clearance (track passes under it), level strata
    (canyon_wall layer), wind-rounded edges. Arch runs along X, opening along Y."""
    A.reset()
    W = 2
    pts = []
    for t in np.linspace(0, 1, 23):
        a = math.pi * t
        pts.append(Vector((-17 * math.cos(a), 0, 19.5 * math.sin(a) ** 0.85)))
    radii = [5.2 - 3.0 * math.sin(math.pi * t) ** 0.6 for t in np.linspace(0, 1, 23)]
    rings = []
    verts, faces = [], []
    n_s = 16
    for i, p in enumerate(pts):
        if i == 0:
            tdir = (pts[1] - pts[0]).normalized()
        elif i == len(pts) - 1:
            tdir = (pts[-1] - pts[-2]).normalized()
        else:
            tdir = (pts[i + 1] - pts[i - 1]).normalized()
        x = Vector((0, 1, 0))
        y = tdir.cross(x).normalized()
        r = radii[i]
        for k in range(n_s):
            a = 2 * math.pi * k / n_s
            off = x * math.cos(a) * r * 1.35 + y * math.sin(a) * r  # deeper than tall
            verts.append(tuple(p + off))
    for i in range(len(pts) - 1):
        for k in range(n_s):
            a = i * n_s + k
            b = i * n_s + (k + 1) % n_s
            faces.append((a, b, b + n_s, a + n_s))
    o = A.mesh_obj("sandstone_arch", verts, faces)
    sub = o.modifiers.new("s", "SUBSURF")
    sub.levels = 1
    A.apply_all(o)
    displace(o, 1.1, 4.0, seed=4)
    for v in o.data.vertices:  # strata: small level steps
        v.co.x += 0.25 * math.sin(v.co.z * 2.1)
        v.co.z = max(v.co.z, -2.0)
    smooth(o)
    o.data.materials.append(slope_mat("ss", w2set("red_sand"), w2set("canyon_wall"), thresh=0.75, soft=0.1,
                                      scale_flat=0.3, scale_steep=1 / 9))
    decimate_to(o, 3200)
    ground(o, -1.5)
    bake(o, W, "sandstone_arch", 1024, ao_dist=3.0, ao_k=0.6)
    done(o, W, "sandstone_arch", "span along X (legs at x +-17 m), ride along Y under it; clearance ~16 m")


def gas_station():
    """Abandoned 1950s roadside gas station: cracked forecourt slab, flat canopy on two steel posts, two old pumps,
    a small kiosk with boarded windows, a blank sign on a pole (no text), oil drums. 22 x 14 m."""
    A.reset()
    W = 2
    slab = mat("slab", w2set("worn_asphalt"), scale=0.35, tint=(1.15, 1.05, 0.95))
    wall = mat("wall", A.ph_tex("concrete_wall_003"), scale=0.5, tint=(0.95, 0.85, 0.75))
    paint = mat("paint", A.ph_tex("painted_concrete"), scale=0.5, tint=(1.4, 0.7, 0.5))
    rust = mat("rust", A.ph_tex("rusty_metal_02"), scale=0.5)
    roof = mat("roof", A.ph_tex("corrugated_iron_02"), scale=0.5, tint=(0.8, 0.7, 0.6), metal=0.5)
    boards = mat("boards", A.ph_tex("weathered_planks"), scale=0.8, tint=(0.8, 0.7, 0.6))
    pumpm = flat("pump", "#8E3B2E", rough=0.55)
    cream = flat("cream", "#D9CDB0", rough=0.6)
    glass = flat("glass", "#2A2622", rough=0.2)
    parts = [cube("slab", (22, 14, 0.15), (0, 0, 0.075), slab)]
    # canopy
    for x in (-4.5, 4.5):
        parts.append(cube(f"post{x}", (0.25, 0.25, 4.6), (x, -2.5, 2.4), rust))
    parts.append(cube("canopy", (12.5, 6.5, 0.45), (0, -2.5, 4.9), cream, bevel=0.05))
    parts.append(cube("fascia", (12.6, 6.6, 0.18), (0, -2.5, 4.62), paint))
    # pumps on an island
    parts.append(cube("island", (7.0, 1.2, 0.2), (0, -2.5, 0.25), wall, bevel=0.03))
    for x in (-2.0, 2.0):
        parts.append(cube(f"pump{x}", (0.65, 0.5, 1.5), (x, -2.5, 1.1), pumpm, bevel=0.05))
        parts.append(cyl(f"globe{x}", 0.28, 0.4, (x, -2.5, 2.05), cream, 14, rot=(math.pi / 2, 0, 0)))
        parts.append(cube(f"face{x}", (0.4, 0.52, 0.35), (x, -2.5, 1.45), glass))
        parts.append(tube(f"hose{x}", [Vector((x + 0.33, -2.5, 1.3)), Vector((x + 0.5, -2.5, 0.6)), Vector((x + 0.36, -2.75, 0.9))], 0.025, 5, glass))
    # kiosk
    parts.append(cube("kiosk", (7.0, 5.0, 3.2), (3.5, 4.0, 1.75), wall))
    parts.append(cube("kroof", (7.6, 5.6, 0.2), (3.5, 4.0, 3.45), roof))
    parts.append(cube("kband", (7.05, 5.05, 0.5), (3.5, 4.0, 3.0), paint))
    for x in (1.6, 4.2):
        parts.append(cube(f"board{x}", (1.8, 0.08, 1.3), (x, 1.47, 1.7), boards, rot=(0, 0.06 if x > 2 else -0.04, 0)))
    parts.append(cube("door", (1.0, 0.08, 2.1), (6.0, 1.47, 1.2), rust))
    # sign pole + blank sign (no text)
    parts.append(cyl("signpole", 0.12, 7.5, (-8.5, -4.5, 3.75), rust, 10))
    parts.append(cube("sign", (2.8, 0.25, 1.8), (-8.5, -4.5, 7.2), cream, bevel=0.06))
    parts.append(cube("signrim", (2.95, 0.2, 1.95), (-8.5, -4.43, 7.2), paint))
    for k, (x, y) in enumerate(((7.5, 1.0), (8.2, 1.4), (-6.0, 5.0))):
        parts.append(cyl(f"drum{k}", 0.29, 0.88, (x, y, 0.59), rust, 14))
    o = join(parts, "gas_station")
    bake(o, W, "gas_station", 1024, ao_dist=1.2)
    done(o, W, "gas_station", "forecourt faces -Y (the road side)")


def _cliff(model, name, keep, scale, target):
    A.reset()
    W = 2
    objs = ph_objs(model, keep)
    o = objs[0] if len(objs) == 1 else join(objs, name)
    o.name = name
    o.scale = (scale,) * 3
    A.apply_xform(o)
    ground(o, -1.0)
    decimate_to(o, target)
    smooth(o)
    o.data.materials.clear()
    o.data.materials.append(slope_mat("cliff", w2set("red_sand"), w2set("canyon_wall"), thresh=0.78, soft=0.08,
                                      scale_flat=0.3, scale_steep=1 / 9, noise_scale=0.3))
    for uv in list(o.data.uv_layers):
        o.data.uv_layers.remove(uv)
    bake(o, W, name, 1024, ao_dist=4.0, ao_k=0.7)
    done(o, W, name, "real cliff scan re-skinned with level strata; or override with the world-triplanar wall material")


def canyon_cliff_a():
    _cliff("namaqualand_cliff_01", "canyon_cliff_a", None, 4.6, 2600)


def canyon_cliff_b():
    _cliff("namaqualand_cliff_02", "canyon_cliff_b", ["drone_rock_02_LOD0"], 2.6, 3000)


def mesa_backdrop():
    """Far horizon closer: a 120-degree ring segment of mesas and buttes, radius 620-800 m, 35-140 m high, flat
    caprock tops, cliff bands and talus. Place three copies (yaw 0, 120, 240) around the track centre."""
    A.reset()
    W = 2
    na, nr = 121, 12
    verts, faces = [], []
    for j in range(nr):
        r = 620 + 180 * j / (nr - 1)
        for i in range(na):
            a = math.radians(-60 + 120 * i / (na - 1))
            m = noise.noise(Vector((math.cos(a) * 6.0, math.sin(a) * 6.0, r / 140)))
            mesa = max(0.0, min(1.0, (m + 0.05) * 6))  # plateau mask with steep edges
            hgt = 35 + 105 * mesa * (0.7 + 0.3 * noise.noise(Vector((a * 3, 1.7, 0))))
            edge = min(1.0, (r - 620) / 40) * min(1.0, (800 - r) / 25 + 0.3)
            z = hgt * edge
            k = z / 18  # caprock steps
            z = 18 * (math.floor(k) + min(1.0, (k - math.floor(k)) / 0.7))
            verts.append((math.sin(a) * r, math.cos(a) * r, z - 5))
    for j in range(nr - 1):
        for i in range(na - 1):
            a = j * na + i
            faces.append((a, a + na, a + na + 1, a + 1))
    o = A.mesh_obj("mesa_backdrop", verts, faces)
    smooth(o)
    o.data.materials.append(slope_mat("mesa", w2set("red_sand"), w2set("canyon_wall"), thresh=0.72, soft=0.08,
                                      scale_flat=0.08, scale_steep=1 / 9 / 3, noise_scale=0.02))
    bake(o, W, "mesa_backdrop", 1024, tile=6.0, ao_dist=30.0, ao_k=0.5)
    done(o, W, "mesa_backdrop", "120 deg segment centred on +Y; 3 copies close the horizon; no shadow, fogged")


ALL = {f.__name__: f for f in (cabin, river_bridge, rock_tunnel_segment, rock_tunnel_portal, sandstone_arch,
                               gas_station, canyon_cliff_a, canyon_cliff_b, mesa_backdrop)}

if __name__ == "__main__":
    run(ALL, argv)
