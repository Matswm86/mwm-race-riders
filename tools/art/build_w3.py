"""World 3 "Isbreen / Glacier Run": signature ice cave + crevasse, hindrances, landmarks, scenery.

blender -b --factory-startup -P tools/art/build_w3.py -- [names...]
Needs: fetch_worlds36.py, make_terrain36.py (terrain sets are the texture sources).
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from w36_lib import *  # noqa: F401,F403,E402

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
W = 3


def snow_m(name="snow", scale=0.35):
    return mat(name, tset(W, "snow"), scale=scale, rough=0.62)


def ice_m(name="ice", scale=0.25, emit=None):
    return mat(name, tset(W, "blue_ice"), scale=scale, rough=0.12, emit=emit)


def rock_m(name="rock", scale=0.25):
    return mat(name, tset(W, "glacier_rock"), scale=scale)


# ---------------------------------------------------------------- signature: ice cave exit over a crevasse
def ice_cave():
    """Blue ice cave the track runs through (24 m long, 12 m wide, 7 m high inside), open at both ends.
    Inner faces carry a faint blue emission: fakes the light that real ice transmits (no GI on the phone)."""
    A.reset()
    L, n_r, n_s = 24.0, 25, 22
    inner, outer = [], []
    for j in range(n_r):
        y = L * j / (n_r - 1)
        for i in range(n_s):
            t = math.pi * i / (n_s - 1)
            wob = 1 + 0.06 * math.sin(3 * t + y * 0.4) + 0.04 * math.sin(7 * t - y * 0.9)
            inner.append((-6.2 * math.cos(t) * wob, y, 7.0 * math.sin(t) * wob - 0.4))
            th = 2.2 + 1.6 * (0.5 + 0.5 * math.sin(t * 2 + y * 0.3))
            outer.append((-(6.2 + th) * math.cos(t) * wob, y, (7.0 + th * 1.1) * math.sin(t) * wob - 0.4))
    verts = inner + outer
    faces = []
    off = n_r * n_s
    for j in range(n_r - 1):
        for i in range(n_s - 1):
            a = j * n_s + i
            faces.append((a, a + n_s, a + n_s + 1, a + 1))  # inner, normals point in
            b = off + a
            faces.append((b, b + 1, b + n_s + 1, b + n_s))
    for j in (0, n_r - 1):  # end rims
        for i in range(n_s - 1):
            a = j * n_s + i
            f = (a, a + 1, off + a + 1, off + a)
            faces.append(f if j == 0 else f[::-1])
    o = A.mesh_obj("ice_cave", verts, faces)
    smooth(o)
    # chunky blue ice: big low-frequency bulges + smaller facets
    for v in o.data.vertices:
        p = v.co
        d = noise.fractal(p / 3.5, 0.55, 2.0, 4, noise_basis="PERLIN_ORIGINAL")
        nrm = Vector((p.x, 0, p.z + 0.4)).normalized()
        if p.z < 0.2:
            nrm = Vector((math.copysign(1, p.x), 0, 0))
        v.co += nrm * d * 0.9
    ins = ice_m("ice_in", 0.18, emit=(0.05, 0.16, 0.26))
    outs = slope_mat("outer", tset(W, "snow"), tset(W, "blue_ice"), thresh=0.4, soft=0.15, scale_flat=0.25,
                     scale_steep=0.15, rough_flat=0.6, rough_steep=0.15, noise_scale=0.2)
    o.data.materials.append(ins)
    o.data.materials.append(outs)
    for k, p in enumerate(o.data.polygons):
        if k >= (n_r - 1) * (n_s - 1) * 2 or k % 2 == 1:
            p.material_index = 1
    bake(o, W, "ice_cave", 1024, ao_dist=2.5, ao_k=0.6, want_emission=True)
    done(o, W, "ice_cave", "track runs along +Y through it; inner width 12.4 m, height 6.6 m; emission = faint blue")


def crevasse():
    """Crevasse the ice-cave launch clears: 40 m across the track, 14 m gap (<= 18*1.6-6 = 22.8 m, GDD 6.3),
    blue ice walls 18 m deep, snow cornice lips. Origin at the take-off lip centre; the gap runs along +Y."""
    A.reset()
    prof = [(-5, 0.0), (-1.0, 0.05), (0.0, 0.0), (0.35, -0.5), (0.1, -1.6), (0.6, -5), (0.9, -10),
            (1.6, -18), (12.4, -18), (13.1, -10), (13.4, -5), (13.9, -1.6), (13.65, -0.5), (14.0, 0.0),
            (15.0, 0.05), (19.0, 0.0)]
    nx = 41
    verts, faces = [], []
    for i in range(nx):
        x = -20 + 40 * i / (nx - 1)
        for y, z in prof:
            verts.append((x, y, z))
    npf = len(prof)
    for i in range(nx - 1):
        for k in range(npf - 1):
            a = i * npf + k
            faces.append((a, a + 1, a + npf + 1, a + npf))
    o = A.mesh_obj("crevasse", verts, faces)
    smooth(o)
    for v in o.data.vertices:
        depth = -v.co.z
        if depth > 0.3:
            d = noise.fractal(Vector((v.co.x / 4, v.co.y / 4, v.co.z / 6)), 0.5, 2.0, 4, noise_basis="PERLIN_ORIGINAL")
            side = -1 if v.co.y < 7 else 1
            v.co.y += side * d * min(1.5, depth * 0.25)
    o.data.materials.append(snow_m("snow", 0.3))
    o.data.materials.append(ice_m("ice", 0.12))
    for p in o.data.polygons:
        if p.center.z < -0.35:
            p.material_index = 1
    bake(o, W, "crevasse", 1024, ao_dist=4.0, ao_k=0.85)
    done(o, W, "crevasse", "gap 14 m along +Y from the lip, 40 m across, 18 m deep")


def ramp_snow():
    """World-3 kicker skin: packed snow with a blue ice lip, same 4.6 x 3.65 x 1.15 footprint as ramp.glb."""
    A.reset()
    Wd, L, H = 4.6, 3.65, 1.15
    nx, ny = 12, 14
    verts, faces = [], []
    rnd = random.Random(3)
    for j in range(ny):
        for i in range(nx):
            u, v = i / (nx - 1), j / (ny - 1)
            z = H * v**1.7
            jit = 0.03 * rnd.uniform(-1, 1) if 0 < i < nx - 1 else 0
            verts.append(((u - 0.5) * (Wd + 1.2 * (1 - v)), v * L - L / 2, max(0.0, z + jit)))
    for j in range(ny - 1):
        for i in range(nx - 1):
            a = j * nx + i
            faces.append((a, a + 1, a + nx + 1, a + nx))
    o = A.mesh_obj("ramp_snow", verts, faces)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    ext = bmesh.ops.extrude_edge_only(bm, edges=[e for e in bm.edges if e.is_boundary])
    for v in [g for g in ext["geom"] if isinstance(g, bmesh.types.BMVert)]:
        v.co.z = -0.05
        v.co.x *= 1.12
        v.co.y = max(min(v.co.y, L / 2 + 0.2), -L / 2 - 0.6)
    bm.to_mesh(o.data)
    bm.free()
    smooth(o)
    o.data.materials.append(mat("packed", tset(W, "snow_groomed"), scale=0.5, rough=0.5))
    o.data.materials.append(ice_m("lip", 0.4))
    for p in o.data.polygons:
        if p.center.y > L / 2 - 0.45 and p.center.z > 0.85:
            p.material_index = 1
    bake(o, W, "ramp_snow", 512, ao_dist=0.5)
    done(o, W, "ramp_snow", "kicker skin, same footprint as ramp.glb")


# ---------------------------------------------------------------- hindrances
def ice_patch():
    """Patch (no slow, steering slides): bare blue glacier ice 6 m across x 14 m along, glossy, vertex-alpha edge."""
    A.reset()
    def edge(u, v):
        a = math.atan2(v, u * 2.3)
        r = math.hypot(u, v * 1.0)
        wob = 1 + 0.18 * noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, 0.5))) + 0.08 * math.sin(5 * a)
        return r / (0.95 * wob)

    o = grid(
        "ice_patch", 6.0, 14.0, 18, 36,
        hfn=lambda u, v: 0.015 * max(0.0, 1 - edge(u, v) ** 3),
        afn=lambda u, v: (1 - edge(u, v)) * 4.0 * (0.75 + 0.25 * noise.noise(Vector((u * 3, v * 5, 1.3)))),
    )
    o.data.materials.append(mat("ice", tset(W, "blue_ice"), scale=0.3, rough=0.08, tint=(0.85, 0.9, 0.95)))
    bake(o, W, "ice_patch", 512, ao_dist=0.05, ao_k=0.0, vertex_alpha=True)
    done(o, W, "ice_patch", "transparent (vertex alpha), roughness ~0.1, no shadow")


def snow_drift():
    """Patch x0.90: wind-sculpted snow drift tongue across the track, 15 m across x 4 m along, 0.35 m high,
    steep lee face towards the riders' left (wind from the right)."""
    A.reset()

    def h(u, v):
        e = max(abs(u) ** 2.4, abs(v) ** 5)
        crest = 0.35 * max(0.0, 1 - e) * (0.75 + 0.25 * math.sin(u * 4 + 1))
        return crest * (1 - 0.5 * max(0.0, v)) + 0.02 * math.sin(v * 30 + u * 5)

    o = grid("snow_drift", 15.0, 4.0, 20, 12, hfn=h, afn=lambda u, v: (1 - max(abs(u) ** 2.4, abs(v) ** 5)) * 3.0)
    o.data.materials.append(mat("snow", tset(W, "snow_wind"), scale=0.3, rough=0.8))
    bake(o, W, "snow_drift", 512, ao_dist=0.3, ao_k=0.5, vertex_alpha=True)
    done(o, W, "snow_drift", "vertex alpha = edge fade")


def snow_slough():
    """Roller: a tumbling clump of slough (loose snow balled up), 1.3 m. Roll about its centre, 0.65 m up."""
    A.reset()
    parts = [ico("c0", 0.62, 3, (0, 0, 0.65))]
    rnd = random.Random(9)
    for k in range(5):
        a = rnd.uniform(0, 6.28)
        e = rnd.uniform(-0.8, 0.8)
        r = rnd.uniform(0.22, 0.34)
        c = Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))) * 0.55
        parts.append(ico(f"c{k + 1}", r, 2, (c.x, c.y, c.z + 0.65)))
    o = join(parts, "snow_slough")
    displace(o, 0.06, 0.25, seed=4)
    smooth(o)
    o.data.materials.append(mat("snow", tset(W, "snow"), scale=1.2, rough=0.7))
    bake(o, W, "snow_slough", 512, ao_dist=0.25)
    done(o, W, "snow_slough", "Roller: rotate about (0, 0.65, 0)")


# ---------------------------------------------------------------- landmarks
def glacier_hut():
    """Red-painted wooden glacier hut on a stone footing, snow-loaded gable roof, chimney. 6.6 x 5.2 x 5.6 m."""
    A.reset()
    red = mat("walls", A.ph_tex("distressed_painted_planks"), scale=0.5, tint=(0.72, 0.17, 0.12))
    trim = mat("trim", {"albedo": A.ph_tex("distressed_painted_planks")["albedo"]}, scale=0.6, tint=(1.05, 1.05, 1.0), rough=0.7)
    dark = mat("under", A.ph_tex("weathered_planks"), scale=0.6, tint=(0.45, 0.4, 0.38))
    stone = rock_m("stone", 0.6)
    snow = snow_m("snow", 0.5)
    glass = flat("glass", "#1B2430", rough=0.08)
    parts = []
    parts.append(cube("foot", (6.4, 4.8, 0.5), (0, 0, 0.25), stone, bevel=0.05))
    parts.append(cube("body", (6.0, 4.4, 2.6), (0, 0, 0.5 + 1.3), red))
    # gable ends (triangles) as a prism along x
    ridge = 0.5 + 2.6 + 1.9
    verts = [(-3.0, -2.2, 3.1), (-3.0, 2.2, 3.1), (-3.0, 0, ridge), (3.0, -2.2, 3.1), (3.0, 2.2, 3.1), (3.0, 0, ridge)]
    g = A.mesh_obj("gable", verts, [(0, 2, 1), (3, 4, 5), (0, 3, 5, 2), (2, 5, 4, 1), (0, 1, 4, 3)])
    g.data.materials.append(red)
    parts.append(g)
    # roof slabs + snow load
    for s in (-1, 1):
        ang = math.atan2(1.9, 2.2)
        ln = math.hypot(2.2, 1.9) + 0.55
        c = Vector((0, s * 1.15, 3.1 + 0.98))
        parts.append(cube(f"roof{s}", (6.9, ln, 0.16), c, dark, rot=(s * -ang, 0, 0)))
        cs = c + Vector((0, s * math.sin(ang) * -0.0, 0)) + Vector((0, 0, 0.24 / math.cos(ang)))
        sn = cube(f"snow{s}", (7.0, ln - 0.1, 0.34), cs, snow, bevel=0.12, rot=(s * -ang, 0, 0))
        parts.append(sn)
    # corner boards, door, windows
    for x in (-3.02, 3.02):
        for y in (-2.22, 2.22):
            parts.append(cube(f"cb{x}{y}", (0.12, 0.12, 2.6), (x, y, 1.8), trim))
    parts.append(cube("door", (1.0, 0.08, 2.0), (-1.4, -2.24, 1.5), mat("doorm", A.ph_tex("weathered_planks"), scale=0.8, tint=(0.55, 0.16, 0.1))))
    parts.append(cube("doorframe", (1.2, 0.06, 2.15), (-1.4, -2.22, 1.55), trim))
    for x in (0.6, 2.0):
        parts.append(cube(f"wf{x}", (0.95, 0.06, 0.95), (x, -2.22, 2.1), trim))
        parts.append(cube(f"wg{x}", (0.8, 0.08, 0.8), (x, -2.24, 2.1), glass))
    parts.append(cube("wfs", (0.95, 0.06, 0.95), (3.02, 0.6, 2.1), trim, rot=(0, 0, math.pi / 2)))
    parts.append(cube("wgs", (0.8, 0.08, 0.8), (3.04, 0.6, 2.1), glass, rot=(0, 0, math.pi / 2)))
    parts.append(cube("chim", (0.6, 0.6, 1.6), (1.8, 0.7, 4.7), stone, bevel=0.03))
    parts.append(cube("chimsnow", (0.7, 0.7, 0.15), (1.8, 0.7, 5.55), snow, bevel=0.06))
    # snow banked against the walls
    bank = grid("bank", 9.0, 7.6, 16, 14, hfn=lambda u, v: 0.9 * max(0.0, 1 - max(abs(u), abs(v)) ** 2) - 0.25)
    bank.data.materials.append(snow)
    parts.append(bank)
    o = join(parts, "glacier_hut")
    bake(o, W, "glacier_hut", 1024, ao_dist=1.0)
    done(o, W, "glacier_hut", "door faces -Y (the track side when yaw = 0)")


def ladder_bridge():
    """Crevasse ladder-bridge: four aluminium ladders lashed end to end (14 m) with orange rope handlines on snow
    pickets. Scenery beside the track (GDD landmark), spans a 12 m side crevasse along X."""
    A.reset()
    alu = flat("alu", "#B9BEC4", rough=0.35, metal=1.0)
    rope = flat("rope", "#D9581C", rough=0.85)
    lash = flat("lash", "#1E1F22", rough=0.6)
    parts = []
    Lx = 14.0
    for y in (-0.22, 0.22):
        parts.append(cube(f"rail{y}", (Lx, 0.025, 0.07), (0, y, 0.035), alu))
    n = int(Lx / 0.3)
    for i in range(n + 1):
        x = -Lx / 2 + i * 0.3
        parts.append(cyl(f"rung{i}", 0.014, 0.44, (x, 0, 0.05), alu, 6, rot=(math.pi / 2, 0, 0)))
    for x in (-3.5, 0.0, 3.5):
        parts.append(cube(f"lash{x}", (0.18, 0.5, 0.09), (x, 0, 0.04), lash))
    for s in (-1, 1):
        y = s * 0.9
        for x in (-Lx / 2 - 0.5, Lx / 2 + 0.5):
            parts.append(cube(f"pk{x}{s}", (0.04, 0.04, 1.1), (x, y, 0.35), alu))
        pts = [Vector((-Lx / 2 - 0.5 + (Lx + 1) * t, y, 0.95 - 0.35 * math.sin(math.pi * t))) for t in np.linspace(0, 1, 15)]
        parts.append(tube(f"hl{s}", pts, 0.012, 5, rope))
    o = join(parts, "ladder_bridge")
    bake(o, W, "ladder_bridge", 512, ao_dist=0.3)
    done(o, W, "ladder_bridge", "spans 14 m along X")


def flag_pole():
    """Course marker flag: 3.2 m fibreglass pole, red flag 0.9 x 0.6 m (multiply the albedo for blue), snow foot."""
    A.reset()
    pole = flat("pole", "#E8E6E1", rough=0.4)
    cloth = flat("flag", "#C8202B", rough=0.85)
    parts = [cyl("pole", 0.022, 3.2, (0, 0, 1.6), pole, 8)]
    verts, faces = [], []
    for j in range(2):
        for i in range(7):
            x = 0.03 + 0.9 * i / 6
            verts.append((x, 0.04 * math.sin(i * 1.3) * (i / 6), 2.55 + 0.6 * j))
    for i in range(6):
        faces.append((i, i + 1, i + 8, i + 7))
    f = A.mesh_obj("flag", verts, faces)
    sol = f.modifiers.new("s", "SOLIDIFY")
    sol.thickness = 0.01
    A.apply_all(f)
    f.data.materials.append(cloth)
    parts.append(f)
    m = ico("foot", 0.28, 2, (0, 0, 0.0), snow_m("snow", 1.0))
    m.scale = (1, 1, 0.45)
    A.apply_xform(m)
    parts.append(m)
    o = join(parts, "flag_pole")
    bake(o, W, "flag_pole", 256, ao_dist=0.2)
    done(o, W, "flag_pole")


def _serac(name, size, seed):
    """Serac: a tall block of glacier ice broken by fracture planes, slumped and rounded by melt, layered
    (blue in the fractures, white on weathered faces), snow on the top facets. One or two blocks, buried 1 m."""
    A.reset()
    rnd = random.Random(seed)
    parts = []
    nb = 2 if size[2] > 8 else 1
    for k in range(nb):
        f = 1.0 - 0.25 * k
        sz = (size[0] * f, size[1] * f * rnd.uniform(0.8, 1.1), size[2] * (0.62 if nb == 2 and k == 0 else 1.0) * f)
        b = facet_block(f"{name}{k}", sz, seed * 10 + k, cuts=14, z0=-1.0)
        b.location = (rnd.uniform(-1.2, 1.2) * k, rnd.uniform(-1.0, 1.0) * k, 0)
        b.rotation_euler = (rnd.uniform(-0.12, 0.12), rnd.uniform(-0.12, 0.12), rnd.uniform(0, 6.28))
        A.apply_xform(b)
        parts.append(b)
    o = join(parts, name)
    rm = o.modifiers.new("r", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = max(size) / 28
    A.apply_all(o)
    for v in o.data.vertices:  # melt-rounding + horizontal layering
        p = v.co
        d = noise.fractal(p / (size[2] * 0.4) + Vector((seed, 0, 0)), 0.5, 2.0, 3, noise_basis="PERLIN_ORIGINAL")
        v.co += v.normal * d * size[0] * 0.12
        v.co += v.normal * 0.12 * math.sin(p.z * 2.2 + seed)
    decimate_to(o, 1100)
    smooth(o)
    o.data.materials.append(slope_mat("ice", tset(W, "snow"), tset(W, "blue_ice"), thresh=0.5, soft=0.12,
                                      scale_flat=0.4, scale_steep=0.07, rough_flat=0.6, rough_steep=0.15,
                                      tint_steep=(1.35, 1.3, 1.22), noise_scale=0.5, noise_amt=0.2))
    ground(o, -1.0)
    bake(o, W, name, 512, ao_dist=1.5, ao_k=0.9)
    done(o, W, name, "blue serac, melt-rounded fracture blocks, snow on top")


def serac_a():
    _serac("serac_a", (5.0, 4.0, 10.0), 1)


def serac_b():
    _serac("serac_b", (7.0, 5.0, 6.5), 5)


def mountain_ridge():
    """Far backdrop: 1.6 km band of snow peaks with rock ribs, for 500-900 m out (fog does the rest).
    Faces open towards -Y (towards the track when yaw = 0)."""
    A.reset()
    nx, ny = 97, 25
    verts, faces = [], []
    for j in range(ny):
        for i in range(nx):
            x = -800 + 1600 * i / (nx - 1)
            y = 700 * j / (ny - 1)
            p = Vector((x / 300, y / 300, 0.3))
            ridged = 0.0
            amp, fr = 1.0, 1.0
            for _o in range(5):  # ridged multifractal: sharp aretes, glacier valleys between them
                ridged += amp * (1 - abs(noise.noise(p * fr))) ** 2
                amp *= 0.5
                fr *= 2.1
            t = min(1.0, y / 450)
            prof = t * t * (3 - 2 * t) if y < 450 else 1 - 0.5 * (y - 450) / 250
            z = (40 + 230 * ridged) * prof
            verts.append((x, y, z - 10))
    for j in range(ny - 1):
        for i in range(nx - 1):
            a = j * nx + i
            faces.append((a, a + 1, a + nx + 1, a + nx))
    o = A.mesh_obj("mountain_ridge", verts, faces)
    smooth(o)
    o.data.materials.append(slope_mat("mtn", tset(W, "snow_wind"), tset(W, "glacier_rock"), thresh=0.6, soft=0.08,
                                      scale_flat=0.06, scale_steep=0.05, rough_flat=0.7, noise_scale=0.02, noise_amt=0.2))
    bake(o, W, "mountain_ridge", 1024, tile=20.0, ao_dist=40.0, ao_k=0.5)
    done(o, W, "mountain_ridge", "far backdrop, place 500-900 m out, no shadow, fogged")


# ---------------------------------------------------------------- scenery
def glacier_boulder():
    ph_decimated("boulder_01", None, W, "glacier_boulder", 600, scale=1.0, sat=0.15, tint=(0.95, 1.0, 1.1),
                 note="near rock; far = glacier_boulder_card.glb")


def glacier_boulder_card():
    card_of(lambda: import_glb(A.MODELS / "world3/glacier_boulder.glb"), W, "glacier_boulder_card", n=2,
            cell=(256, 256))


def serac_card():
    def b():
        o = import_glb(A.MODELS / "world3/serac_a.glb")
        return o
    card_of(b, W, "serac_card", n=2, cell=(256, 512), note="far/Lav card of serac_a")


ALL = {f.__name__: f for f in (ice_cave, crevasse, ramp_snow, ice_patch, snow_drift, snow_slough, glacier_hut,
                               ladder_bridge, flag_pole, serac_a, serac_b, mountain_ridge, glacier_boulder,
                               glacier_boulder_card, serac_card)}

if __name__ == "__main__":
    run(ALL, argv)
