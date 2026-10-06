"""MWM Race Riders look-dev parts for Blender 4.5 (run inside Blender, background mode).

Axes (Blender): X right, Y forward (direction of travel), Z up, metres.
glTF export with +Y up turns Blender +Y forward into Godot -Z forward.

Every model uses ONE material ("rr_kit") that samples a 64x64 palette texture
(8x8 cells of 8 px). Each face's UVs sit on the centre of one cell, so a model is
one surface and one draw call. Two cell bands are special (rows counted from the top):
  row 6  = glow colours (unshaded/emissive in Godot)
  row 7, col 0 = TEAM cell (white, multiplied by the racer's team colour)
"""

import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

GRID = 8
CELL_PX = 8

# ---- palette: name -> (hex, col, row-from-top) ---------------------------
PAL = {
    # row 0: land
    "grass": ("#7DC75A", 0, 0),
    "grass_dark": ("#5AA845", 1, 0),
    "meadow": ("#A9DB72", 2, 0),
    "hill_far": ("#A7D3A6", 3, 0),
    "mountain": ("#9CC3D3", 4, 0),
    "snow": ("#F4F8F7", 5, 0),
    "flower": ("#FFD23F", 6, 0),
    "petal": ("#FFFFFF", 7, 0),
    # row 1: track
    "dirt": ("#D39A63", 0, 1),
    "dirt_dark": ("#B47A47", 1, 1),
    "curb": ("#FFF1D6", 2, 1),
    "lane": ("#74BEE0", 3, 1),
    "lane_dark": ("#4A93C2", 4, 1),
    "lane_stripe": ("#FFFFFF", 5, 1),
    "rock": ("#B9AC9F", 6, 1),
    "rock_dark": ("#948677", 7, 1),
    # row 2: plants and sky props
    "trunk": ("#8A5A3B", 0, 2),
    "leaf": ("#4CAF50", 1, 2),
    "leaf_light": ("#7CCB52", 2, 2),
    "pine": ("#2F8F5B", 3, 2),
    "pine_dark": ("#22744A", 4, 2),
    "shadow_grass": ("#4E9440", 5, 2),
    "cloud": ("#FFFFFF", 6, 2),
    "cloud_shade": ("#E3EFF7", 7, 2),
    # row 3: track kit
    "tangerine": ("#FF8A3D", 0, 3),
    "wood": ("#C77B45", 1, 3),
    "cream": ("#FFF1D6", 2, 3),
    "sun": ("#FFD23F", 3, 3),
    "sky": ("#3E9BDB", 4, 3),
    "white": ("#FFFFFF", 5, 3),
    "ink": ("#24211D", 6, 3),
    "red": ("#F2543D", 7, 3),
    # row 4: racers
    "pants": ("#34405A", 0, 4),
    "dark": ("#2B2F3A", 1, 4),
    "visor": ("#1E2633", 2, 4),
    "metal": ("#B9C2CC", 3, 4),
    "deck": ("#FFF8EE", 4, 4),
    "tangerine_dark": ("#EE7429", 5, 4),
    "sole": ("#FFFFFF", 6, 4),
    "grey": ("#8A94A0", 7, 4),
    # row 5: extra track tones
    "dirt_mid": ("#C98B55", 0, 5),
    "pebble": ("#E6D3B8", 1, 5),
    # row 6: glow (unshaded / emissive)
    "g_white": ("#FFFFFF", 0, 6),
    "g_yellow": ("#FFE680", 1, 6),
    "g_cyan": ("#8FEFFF", 2, 6),
    "g_sun": ("#FFD23F", 3, 6),
    # row 7: team cell (white, tinted per racer)
    "team": ("#FFFFFF", 0, 7),
}

# Six rider identities: colour + hat silhouette + back badge (colour is never the only cue)
RIDERS = [
    {"id": "fox", "team": "#E8412C", "hat": "fox", "badge": "triangle", "badge_col": "white"},
    {"id": "bobble", "team": "#FFC21A", "hat": "bobble", "badge": "circle", "badge_col": "white"},
    {"id": "shark", "team": "#2F6FE4", "hat": "fin", "badge": "diamond", "badge_col": "white"},
    {"id": "bunny", "team": "#12A08F", "hat": "bunny", "badge": "square", "badge_col": "white"},
    {"id": "bear", "team": "#FF7EB6", "hat": "bear", "badge": "heart", "badge_col": "white"},
    {"id": "unicorn", "team": "#F2F2EE", "hat": "horn", "badge": "star", "badge_col": "ink"},
]

ROOT = Path(__file__).resolve().parents[3]  # game folder
TEX_PATH = ROOT / "assets" / "textures" / "rr_palette.png"


def srgb_to_lin(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgb(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


def lin(h: str) -> tuple:
    r, g, b = hex_rgb(h)
    return (srgb_to_lin(r), srgb_to_lin(g), srgb_to_lin(b), 1.0)


def cell_uv(name: str) -> tuple:
    _, col, row = PAL[name]
    return ((col + 0.5) / GRID, 1.0 - (row + 0.5) / GRID)


# ---- palette image + kit material ------------------------------------------
def palette_image(save: bool = True):
    img = bpy.data.images.get("rr_palette")
    if img:
        return img
    size = GRID * CELL_PX
    img = bpy.data.images.new("rr_palette", size, size, alpha=False)
    px = [1.0] * (size * size * 4)
    for hexv, col, row in PAL.values():
        r, g, b = hex_rgb(hexv)
        for yy in range(CELL_PX):
            for xx in range(CELL_PX):
                x = col * CELL_PX + xx
                y = (GRID - 1 - row) * CELL_PX + yy  # Blender pixel rows start at the bottom
                i = (y * size + x) * 4
                px[i : i + 4] = [r, g, b, 1.0]
    img.pixels = px
    if save:
        TEX_PATH.parent.mkdir(parents=True, exist_ok=True)
        img.filepath_raw = str(TEX_PATH)
        img.file_format = "PNG"
        img.save()
    img.colorspace_settings.name = "sRGB"
    return img


def _bsdf(mat):
    return next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def kit_material(name: str = "rr_kit", team_hex: str = "#FFFFFF", glow: float = 2.0, rough: float = 0.62, fog=None):
    """Palette material. team cell is multiplied by team_hex; glow row emits."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = _bsdf(m)
    b.inputs["Roughness"].default_value = rough
    try:
        b.inputs["Specular IOR Level"].default_value = 0.35
    except KeyError:
        pass
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = palette_image()
    tex.interpolation = "Closest"
    uv = nt.nodes.new("ShaderNodeUVMap")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs["UV"], tex.inputs["Vector"])
    nt.links.new(uv.outputs["UV"], sep.inputs[0])

    def math_node(op, a=None, bval=None):
        n = nt.nodes.new("ShaderNodeMath")
        n.operation = op
        if bval is not None:
            n.inputs[1].default_value = bval
        if a is not None:
            nt.links.new(a, n.inputs[0])
        return n

    # team mask: u < 1/8 and v < 1/8
    tu = math_node("LESS_THAN", sep.outputs["X"], 0.125)
    tv = math_node("LESS_THAN", sep.outputs["Y"], 0.125)
    team_mask = math_node("MULTIPLY", tu.outputs[0])
    nt.links.new(tv.outputs[0], team_mask.inputs[1])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    nt.links.new(team_mask.outputs[0], mix.inputs["Factor"])
    nt.links.new(tex.outputs["Color"], mix.inputs["A"])
    mix.inputs["B"].default_value = lin(team_hex)
    nt.links.new(mix.outputs["Result"], b.inputs["Base Color"])
    # glow mask: 1/8 <= v < 2/8
    g0 = math_node("GREATER_THAN", sep.outputs["Y"], 0.125)
    g1 = math_node("LESS_THAN", sep.outputs["Y"], 0.25)
    gm = math_node("MULTIPLY", g0.outputs[0])
    nt.links.new(g1.outputs[0], gm.inputs[1])
    gs = math_node("MULTIPLY", gm.outputs[0], glow)
    nt.links.new(tex.outputs["Color"], b.inputs["Emission Color"])
    nt.links.new(gs.outputs[0], b.inputs["Emission Strength"])
    if fog:  # mock only: depth fog on surfaces like Godot's (sky not fogged). Not for GLB export.
        start, end, amount, fog_hex = fog
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        camd = nt.nodes.new("ShaderNodeCameraData")
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = start
        mr.inputs["From Max"].default_value = end
        mr.inputs["To Max"].default_value = amount
        mr.clamp = True
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = lin(fog_hex)
        mx = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(camd.outputs["View Distance"], mr.inputs["Value"])
        nt.links.new(mr.outputs["Result"], mx.inputs["Fac"])
        nt.links.new(b.outputs["BSDF"], mx.inputs[1])
        nt.links.new(em.outputs["Emission"], mx.inputs[2])
        nt.links.new(mx.outputs["Shader"], out.inputs["Surface"])
    return m


def mat_blob():
    """Soft dark ellipse for fake contact shadows (Godot: unshaded alpha quad)."""
    m = bpy.data.materials.get("rr_blob")
    if m:
        return m
    m = bpy.data.materials.new("rr_blob")
    m.use_nodes = True
    nt = m.node_tree
    b = _bsdf(m)
    b.inputs["Base Color"].default_value = lin("#2A4A22")
    b.inputs["Roughness"].default_value = 1.0
    tc = nt.nodes.new("ShaderNodeTexCoord")
    grad = nt.nodes.new("ShaderNodeTexGradient")
    grad.gradient_type = "SPHERICAL"
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (2.0, 2.0, 2.0)
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = 0.75
    ramp.color_ramp.elements[1].color = (0.45, 0.45, 0.45, 1)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], grad.inputs["Vector"])
    nt.links.new(grad.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Alpha"])
    try:
        m.surface_render_method = "BLENDED"
    except (AttributeError, TypeError):
        m.blend_method = "BLEND"
    return m


# ---- geometry accumulator --------------------------------------------------
class Kit:
    """Collects parts; each face carries a palette colour, a smooth flag and a bone."""

    def __init__(self):
        self.v: list = []
        self.vb: list = []
        self.f: list = []
        self.fc: list = []
        self.fs: list = []

    def add(self, geo, color: str, m: Matrix = None, smooth: bool = True, bone: str = None):
        verts, faces = geo
        m = m or Matrix.Identity(4)
        base = len(self.v)
        for co in verts:
            self.v.append(tuple(m @ Vector(co)))
            self.vb.append(bone)
        for face in faces:
            self.f.append(tuple(i + base for i in face))
            self.fc.append(color)
            self.fs.append(smooth)
        return self

    def build(self, name: str, mat=None, coll=None):
        me = bpy.data.meshes.new(name)
        me.from_pydata(self.v, [], self.f)
        me.update()
        me.materials.append(mat or kit_material())
        uvl = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            u, v = cell_uv(self.fc[poly.index])
            poly.use_smooth = self.fs[poly.index]
            for li in poly.loop_indices:
                uvl.data[li].uv = (u, v)
        try:
            me.set_sharp_from_angle(angle=math.radians(48))
        except (AttributeError, TypeError):
            pass
        ob = bpy.data.objects.new(name, me)
        (coll or bpy.context.scene.collection).objects.link(ob)
        bones = sorted({b for b in self.vb if b})
        for bn in bones:
            vg = ob.vertex_groups.new(name=bn)
            idx = [i for i, b in enumerate(self.vb) if b == bn]
            vg.add(idx, 1.0, "REPLACE")
        return ob

    def tris(self) -> int:
        return sum(len(f) - 2 for f in self.f)


# ---- primitives (return verts, faces) -------------------------------------
def _out(bm):
    bm.verts.ensure_lookup_table()
    bm.verts.index_update()
    v = [tuple(x.co) for x in bm.verts]
    f = [tuple(x.index for x in face.verts) for face in bm.faces]
    bm.free()
    return v, f


def sphere(r=1.0, seg=16, rings=10, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    for x in bm.verts:
        x.co = Vector((x.co.x * scale[0], x.co.y * scale[1], x.co.z * scale[2]))
    return _out(bm)


def ico(r=1.0, subdiv=1, jitter=0.0, seed=1, scale=(1, 1, 1)):
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    for x in bm.verts:
        j = 1.0 + rnd.uniform(-jitter, jitter)
        x.co = Vector((x.co.x * j * scale[0], x.co.y * j * scale[1], x.co.z * j * scale[2]))
    return _out(bm)


def cyl(r1=1.0, r2=1.0, depth=1.0, seg=12, caps=True):
    """Along Z, base at z=0."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=depth)
    for x in bm.verts:
        x.co.z += depth / 2
    return _out(bm)


def rbox(sx, sy, sz, bevel=0.03, seg=2):
    """Box centred on origin, rounded edges."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for x in bm.verts:
        x.co = Vector((x.co.x * sx, x.co.y * sy, x.co.z * sz))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)
    return _out(bm)


def capsule(p0, p1, r, seg=10, rings=6):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    L = d.length
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    for x in bm.verts:
        x.co.z += L / 2 if x.co.z >= 0 else -L / 2
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    m = Matrix.Translation((p0 + p1) / 2) @ rot
    for x in bm.verts:
        x.co = m @ x.co
    return _out(bm)


def torus(R=1.0, r=0.2, seg=24, sides=8):
    """Ring in the XY plane around Z."""
    v, f = [], []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        for j in range(sides):
            b = 2 * math.pi * j / sides
            rr = R + r * math.cos(b)
            v.append((rr * math.cos(a), rr * math.sin(a), r * math.sin(b)))
    for i in range(seg):
        for j in range(sides):
            a = i * sides + j
            bb = ((i + 1) % seg) * sides + j
            c = ((i + 1) % seg) * sides + (j + 1) % sides
            d = i * sides + (j + 1) % sides
            f.append((a, bb, c, d))
    return v, f


def prism(pts2d, depth):
    """Extrude a 2D outline (XY, counter-clockwise) from z=0 to z=depth; triangulated caps."""
    bm = bmesh.new()
    bottom = [bm.verts.new((x, y, 0.0)) for x, y in pts2d]
    top = [bm.verts.new((x, y, depth)) for x, y in pts2d]
    bm.faces.new(list(reversed(bottom)))
    bm.faces.new(top)
    n = len(pts2d)
    for i in range(n):
        bm.faces.new((bottom[i], bottom[(i + 1) % n], top[(i + 1) % n], top[i]))
    caps = [f for f in bm.faces if len(f.verts) > 4]
    if caps:
        bmesh.ops.triangulate(bm, faces=caps)
    return _out(bm)


def sweep(points, r, sides=8, caps=True, radii=None):
    """Tube along a polyline (list of 3D points)."""
    pts = [Vector(p) for p in points]
    v, f = [], []
    n = len(pts)
    prev_side = None
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        if prev_side is None:
            up = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            side = t.cross(up).normalized()
        else:
            side = (prev_side - t * prev_side.dot(t)).normalized()
        prev_side = side
        nrm = side.cross(t).normalized()
        rad = radii[i] if radii else r
        for j in range(sides):
            a = 2 * math.pi * j / sides
            v.append(tuple(p + (side * math.cos(a) + nrm * math.sin(a)) * rad))
    for i in range(n - 1):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            c = (i + 1) * sides + (j + 1) % sides
            d = (i + 1) * sides + j
            f.append((a, b, c, d))
    if caps:
        f.append(tuple(reversed(range(sides))))
        f.append(tuple((n - 1) * sides + j for j in range(sides)))
    return v, f


def disc(r, seg=20, depth=0.02):
    pts = [(r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg)) for i in range(seg)]
    return prism(pts, depth)


def quad(sx, sy):
    return [(-sx / 2, -sy / 2, 0), (sx / 2, -sy / 2, 0), (sx / 2, sy / 2, 0), (-sx / 2, sy / 2, 0)], [(0, 1, 2, 3)]


# ---- 2D outlines -----------------------------------------------------------
def stadium(w, h, n=10):
    """Pill outline, long axis Y (length h), width w."""
    r = w / 2
    cy = h / 2 - r
    pts = []
    for i in range(n + 1):
        a = math.pi * i / n
        pts.append((r * math.cos(a), cy + r * math.sin(a)))
    for i in range(n + 1):
        a = math.pi + math.pi * i / n
        pts.append((r * math.cos(a), -cy + r * math.sin(a)))
    return pts


def star_pts(ro, ri, n=5, rot=90):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot) + math.pi * i / n
        rr = ro if i % 2 == 0 else ri
        pts.append((rr * math.cos(a), rr * math.sin(a)))
    return pts


def heart_pts(s, n=28):
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x * s / 17, y * s / 17))
    return pts


def badge_pts(kind, s):
    if kind == "triangle":
        return [(0, s), (-s * 0.95, -s * 0.65), (s * 0.95, -s * 0.65)]
    if kind == "circle":
        return [(s * math.cos(2 * math.pi * i / 18), s * math.sin(2 * math.pi * i / 18)) for i in range(18)]
    if kind == "diamond":
        return [(0, s * 1.1), (-s * 0.8, 0), (0, -s * 1.1), (s * 0.8, 0)]
    if kind == "square":
        q = s * 0.82
        return [(-q, -q), (q, -q), (q, q), (-q, q)]
    if kind == "heart":
        return heart_pts(s * 1.05)
    if kind == "star":
        return star_pts(s * 1.15, s * 0.5)
    raise ValueError(kind)


def rounded_tri(r, k=0.22, n=4):
    """Play-triangle pointing +Y with rounded corners (outline in XY)."""
    corners = [Vector((0, r)), Vector((-r * 0.9, -r * 0.6)), Vector((r * 0.9, -r * 0.6))]
    pts = []
    for i, c in enumerate(corners):
        a = corners[i - 1]
        b = corners[(i + 1) % 3]
        p0 = c + (a - c) * k
        p1 = c + (b - c) * k
        for j in range(n + 1):
            t = j / n
            q = (1 - t) ** 2 * p0 + 2 * (1 - t) * t * c + t**2 * p1
            pts.append((q.x, q.y))
    pts.reverse()
    return pts


# ---- matrices --------------------------------------------------------------
def T(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))


def R(rx=0.0, ry=0.0, rz=0.0):
    from mathutils import Euler

    return Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ").to_matrix().to_4x4()


def S(x, y=None, z=None):
    y = x if y is None else y
    z = x if z is None else z
    return Matrix.Diagonal((x, y, z, 1.0))


FACE_CAM = R(90, 0, 0)  # XY-plane outline -> XZ plane, extruded toward -Y (faces the camera behind)


# ---- rider rig ---------------------------------------------------------------
# name: (head, tail, parent). Rider faces +Y; rider's left is -X.
BONES = {
    "root": ((0, 0, 0), (0, 0, 0.2), None),
    "hips": ((0, 0, 0.55), (0, 0, 0.66), "root"),
    "spine": ((0, 0, 0.62), (0, 0, 0.95), "hips"),
    "head": ((0, 0, 0.97), (0, 0, 1.40), "spine"),
    "arm.L": ((-0.2, 0, 0.9), (-0.22, 0, 0.53), "spine"),
    "arm.R": ((0.2, 0, 0.9), (0.22, 0, 0.53), "spine"),
    "thigh.L": ((-0.09, 0, 0.55), (-0.09, 0, 0.31), "hips"),
    "shin.L": ((-0.09, 0, 0.31), (-0.09, 0, 0.04), "thigh.L"),
    "thigh.R": ((0.09, 0, 0.55), (0.09, 0, 0.31), "hips"),
    "shin.R": ((0.09, 0, 0.31), (0.09, 0, 0.04), "thigh.R"),
}

# Rotations in degrees, rest-world axes, about each bone head; applied down the chain.
# +X on a down-pointing limb swings it forward (+Y); -X on the spine leans forward.
POSES = {
    "stand": {},
    "bike": {
        "root": {"loc": (0, -0.17, 0.30)},
        "spine": {"rot": (-38, 0, 0)},
        "head": {"rot": (30, 0, 0)},
        "arm.L": {"rot": (104, 0, 8)},
        "arm.R": {"rot": (104, 0, -8)},
        "thigh.L": {"rot": (62, 4, 0)},
        "shin.L": {"rot": (-70, 0, 0)},
        "thigh.R": {"rot": (48, -4, 0)},
        "shin.R": {"rot": (-38, 0, 0)},
    },
    "board": {
        "root": {"loc": (0, 0, 0.22), "rot": (0, 0, -70)},
        "hips": {"rot": (0, 0, 0)},
        "spine": {"rot": (-14, 0, 38)},
        "head": {"rot": (6, 0, 28)},
        "arm.L": {"rot": (10, 62, 0)},
        "arm.R": {"rot": (10, -58, 0)},
        "thigh.L": {"rot": (30, 20, 0)},
        "shin.L": {"rot": (-55, 0, 0)},
        "thigh.R": {"rot": (30, -20, 0)},
        "shin.R": {"rot": (-55, 0, 0)},
    },
    "cheer": {
        "root": {"loc": (0, -0.17, 0.30)},
        "spine": {"rot": (-8, 0, 0)},
        "head": {"rot": (-6, 0, 0)},
        "arm.L": {"rot": (0, 150, 0)},
        "arm.R": {"rot": (0, -150, 0)},
        "thigh.L": {"rot": (62, 4, 0)},
        "shin.L": {"rot": (-70, 0, 0)},
        "thigh.R": {"rot": (48, -4, 0)},
        "shin.R": {"rot": (-38, 0, 0)},
    },
}


def pose_matrices(pose_name: str) -> dict:
    pose = POSES[pose_name]
    out = {}
    for bn, (head, _tail, parent) in BONES.items():
        spec = pose.get(bn, {})
        h = Vector(head)
        local = T(*spec.get("loc", (0, 0, 0))) @ T(*h) @ R(*spec.get("rot", (0, 0, 0))) @ T(*(-h))
        out[bn] = (out[parent] if parent else Matrix.Identity(4)) @ local
    return out


def rider_body_kit() -> Kit:
    """Toy rider in rest pose (standing, facing +Y). Team cell = jacket + helmet."""
    k = Kit()
    # legs
    for s, side in ((-1, "L"), (1, "R")):
        x = 0.09 * s
        k.add(capsule((x, 0, 0.53), (x, 0, 0.33), 0.078, 10, 6), "pants", bone=f"thigh.{side}")
        k.add(capsule((x, 0, 0.31), (x, 0, 0.1), 0.068, 10, 6), "pants", bone=f"shin.{side}")
        k.add(rbox(0.13, 0.22, 0.09, 0.035, 2), "dark", T(x, 0.04, 0.05), bone=f"shin.{side}")
        k.add(rbox(0.135, 0.225, 0.025, 0.01, 1), "sole", T(x, 0.04, 0.012), bone=f"shin.{side}")
        # arms (jacket sleeves) + gloves
        ax = 0.2 * s
        k.add(capsule((ax, 0, 0.88), (ax + 0.02 * s, 0, 0.62), 0.065, 10, 6), "team", bone=f"arm.{side}")
        k.add(sphere(0.07, 10, 6, (1, 1, 1.1)), "dark", T(ax + 0.022 * s, 0, 0.56), bone=f"arm.{side}")
    # pelvis + torso
    k.add(rbox(0.30, 0.21, 0.15, 0.06, 2), "pants", T(0, 0, 0.58), bone="hips")
    k.add(sphere(0.19, 14, 8, (1.0, 0.82, 1.05)), "team", T(0, 0, 0.8), bone="spine")
    k.add(torus(0.13, 0.03, 16, 6), "dark", T(0, 0, 0.96), bone="spine")  # collar
    # helmet head
    k.add(sphere(0.235, 16, 10, (1.0, 1.0, 0.94)), "team", T(0, 0, 1.17), bone="head")
    k.add(sphere(0.2, 14, 8, (0.86, 0.5, 0.62)), "visor", T(0, 0.1, 1.14), bone="head")
    for s in (-1, 1):  # two friendly eye shines on the visor
        k.add(sphere(0.042, 8, 6, (0.8, 0.5, 1.25)), "white", T(0.075 * s, 0.205, 1.165), bone="head")
    return k


def add_hat(k: Kit, rider: dict, bone_head="head", bone_spine="spine"):
    """Identity pieces: hat on the helmet (head bone) and badge on the back (spine bone)."""
    hat = rider["hat"]
    top = 1.38
    if hat == "fox":
        for s in (-1, 1):
            k.add(cyl(0.14, 0.0, 0.27, 4), "team", T(0.13 * s, -0.02, 1.3) @ R(0, -24 * s, 45), bone=bone_head, smooth=False)
            k.add(cyl(0.08, 0.0, 0.17, 4), "cream", T(0.135 * s, 0.035, 1.32) @ R(0, -24 * s, 45), bone=bone_head, smooth=False)
    elif hat == "bobble":
        k.add(cyl(0.035, 0.035, 0.07, 8), "team", T(0, -0.01, top - 0.03), bone=bone_head)
        k.add(sphere(0.11, 12, 8), "cream", T(0, -0.01, top + 0.1), bone=bone_head)
    elif hat == "fin":
        pts = [(-0.26, 0.0), (0.2, 0.0), (0.02, 0.14), (-0.22, 0.38)]
        k.add(prism(pts, 0.08), "team", T(0.04, -0.0, 1.29) @ R(90, 0, 90) @ T(0, 0, -0.03), bone=bone_head, smooth=False)
    elif hat == "bunny":
        for s in (-1, 1):
            k.add(sphere(0.06, 10, 8, (1.0, 0.6, 3.1)), "team", T(0.08 * s, -0.04, 1.5) @ R(-10, 12 * s, 0), bone=bone_head)
            k.add(sphere(0.032, 8, 6, (1.0, 0.5, 2.6)), "cream", T(0.08 * s, -0.005, 1.5) @ R(-10, 12 * s, 0), bone=bone_head)
    elif hat == "bear":
        for s in (-1, 1):
            k.add(sphere(0.085, 12, 8, (1, 0.6, 1)), "team", T(0.17 * s, -0.01, 1.33), bone=bone_head)
            k.add(sphere(0.05, 10, 6, (1, 0.4, 1)), "cream", T(0.17 * s, 0.02, 1.335), bone=bone_head)
    elif hat == "horn":
        k.add(cyl(0.07, 0.0, 0.26, 10), "sun", T(0, 0.06, 1.33) @ R(-14, 0, 0), bone=bone_head, smooth=False)
        k.add(torus(0.06, 0.015, 12, 5), "sun", T(0, 0.055, 1.37) @ R(-14, 0, 0), bone=bone_head)
    # back badge (seen by the chase camera)
    pts = badge_pts(rider["badge"], 0.085)
    k.add(prism(pts, 0.02), rider["badge_col"], T(0, -0.148, 0.84) @ FACE_CAM @ T(0, 0, 0), bone=bone_spine, smooth=False)
    return k


def build_rider_posed(name, rider: dict, pose: str, mat, world: Matrix, coll=None):
    """Rider body + identity, posed by FK into one static mesh (for mock renders)."""
    k = rider_body_kit()
    add_hat(k, rider)
    mats = pose_matrices(pose)
    k.v = [tuple(world @ mats[b] @ Vector(co)) for co, b in zip(k.v, k.vb)]
    k.vb = [None] * len(k.v)
    return k.build(name, mat, coll)


def build_rider_rig(name="rider", mat=None, coll=None):
    """Armature + skinned body + 6 identity meshes; actions bike/board/cheer as NLA tracks."""
    coll = coll or bpy.context.scene.collection
    arm_data = bpy.data.armatures.new(name + "_skel")
    arm = bpy.data.objects.new(name, arm_data)
    coll.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = {}
    for bn, (head, tail, parent) in BONES.items():
        b = arm_data.edit_bones.new(bn)
        b.head, b.tail = head, tail
        b.roll = 0.0
        if parent:
            b.parent = eb[parent]
            b.use_connect = False
        eb[bn] = b
    bpy.ops.object.mode_set(mode="OBJECT")

    meshes = []
    body = rider_body_kit().build(name + "_body", mat, coll)
    meshes.append(body)
    for r in RIDERS:
        k = Kit()
        add_hat(k, r)
        meshes.append(k.build("id_" + r["id"], mat, coll))
    for ob in meshes:
        ob.parent = arm
        md = ob.modifiers.new("Armature", "ARMATURE")
        md.object = arm

    arm.animation_data_create()
    for pose_name in ("bike", "board", "cheer"):
        mats = pose_matrices(pose_name)
        act = bpy.data.actions.new(pose_name)
        act.use_fake_user = True
        arm.animation_data.action = act
        for bn in BONES:  # parents first (dict order)
            pb = arm.pose.bones[bn]
            pb.rotation_mode = "QUATERNION"
            pb.matrix = mats[bn] @ arm_data.bones[bn].matrix_local
            bpy.context.view_layer.update()
        for bn in BONES:
            pb = arm.pose.bones[bn]
            for frame in (1, 2):
                pb.keyframe_insert("location", frame=frame)
                pb.keyframe_insert("rotation_quaternion", frame=frame)
        trk = arm.animation_data.nla_tracks.new()
        trk.name = pose_name
        trk.strips.new(pose_name, 1, act)
        arm.animation_data.action = None
        for pb in arm.pose.bones:
            pb.matrix_basis = Matrix.Identity(4)
        bpy.context.view_layer.update()
    return arm, meshes


# ---- vehicles -----------------------------------------------------------------
def bike_kit() -> Kit:
    """Chunky toy bike. Origin on the ground under the bike centre, front +Y. Frame in team colour."""
    k = Kit()
    wz = 0.31
    for y in (-0.52, 0.52):
        k.add(torus(0.235, 0.075, 18, 6), "dark", T(0, y, wz) @ R(0, 90, 0))
        k.add(cyl(0.15, 0.15, 0.07, 10), "cream", T(-0.035, y, wz) @ R(0, 90, 0))
        k.add(cyl(0.045, 0.045, 0.12, 8), "metal", T(-0.06, y, wz) @ R(0, 90, 0))
    crank = (0, -0.02, 0.33)
    seat = (0, -0.17, 0.80)
    head_top = (0, 0.36, 0.92)
    head_bot = (0, 0.40, 0.74)
    tr = 0.042
    k.add(capsule(crank, seat, tr, 8, 4), "team")
    k.add(capsule((0, -0.13, 0.72), head_top, tr, 8, 4), "team")
    k.add(capsule(crank, head_bot, tr * 1.1, 8, 4), "team")
    for s in (-1, 1):
        k.add(capsule((0.06 * s, -0.02, 0.33), (0.06 * s, -0.52, wz), 0.028, 8, 4), "team")
        k.add(capsule((0.05 * s, -0.15, 0.72), (0.06 * s, -0.52, wz), 0.026, 8, 4), "team")
        k.add(capsule((0.075 * s, 0.4, 0.78), (0.075 * s, 0.52, wz), 0.03, 8, 4), "metal")
    k.add(capsule(head_bot, head_top, 0.05, 8, 4), "metal")
    k.add(capsule(head_top, (0, 0.38, 1.0), 0.03, 8, 4), "metal")
    k.add(capsule((-0.3, 0.4, 1.0), (0.3, 0.4, 1.0), 0.026, 8, 4), "metal")
    for s in (-1, 1):
        k.add(capsule((0.22 * s, 0.4, 1.0), (0.33 * s, 0.4, 1.0), 0.04, 8, 4), "dark")
    k.add(rbox(0.16, 0.27, 0.07, 0.03, 2), "dark", T(0, -0.19, 0.84))
    k.add(cyl(0.07, 0.07, 0.05, 12), "dark", T(-0.03, -0.02, 0.33) @ R(0, 90, 0))
    for s in (-1, 1):
        k.add(rbox(0.1, 0.06, 0.025, 0.01, 1), "dark", T(0.14 * s, -0.02 + 0.08 * s, 0.33 - 0.1 * s))
    # front number plate (round, cream) – faces forward
    k.add(disc(0.11, 14, 0.02), "cream", T(0, 0.42, 0.9) @ R(-90 + 15, 0, 0))
    return k


def board_kit() -> Kit:
    """Hoverboard: cream deck with a team stripe, two hover pods with glow discs. Deck top z 0.30."""
    k = Kit()
    k.add(prism(stadium(0.48, 1.38, 10), 0.07), "deck", T(0, 0, 0.23))
    k.add(prism(stadium(0.5, 1.4, 10), 0.03), "team", T(0, 0, 0.215))
    k.add(prism(stadium(0.2, 1.0, 8), 0.008), "team", T(0, 0, 0.3))
    for y in (-0.42, 0.42):
        k.add(cyl(0.15, 0.12, 0.08, 14), "dark", T(0, y, 0.15))
        k.add(disc(0.1, 14, 0.012), "g_cyan", T(0, y, 0.138))
    # nose and tail bumpers
    for s in (-1, 1):
        k.add(sphere(0.05, 10, 6, (2.2, 1, 0.7)), "dark", T(0, 0.66 * s, 0.245))
    return k


# ---- track kit -----------------------------------------------------------------
def boost_pad_kit() -> Kit:
    """2.4 m wide x 2.0 m long pad, top at z 0.08. Three glowing play-triangles point +Y."""
    k = Kit()
    k.add(rbox(2.4, 2.0, 0.06, 0.03, 2), "sun", T(0, 0, 0.03))
    k.add(rbox(2.5, 2.1, 0.03, 0.012, 1), "tangerine_dark", T(0, 0, 0.015))
    for i, y in enumerate((-0.6, 0.0, 0.6)):
        k.add(prism(rounded_tri(0.36), 0.025), "g_white", T(0, y, 0.06), smooth=False)
    return k


def ramp_kit(width=4.4, length=3.6, height=1.15, n=8) -> Kit:
    """Parabolic kicker. Starts flush at y=0, lip at y=length."""
    k = Kit()
    hw = width / 2
    prof = [(length * i / n, height * (i / n) ** 1.8) for i in range(n + 1)]
    # deck planks
    for i in range(n):
        (y0, z0), (y1, z1) = prof[i], prof[i + 1]
        verts = [(-hw, y0, z0 + 0.02), (hw, y0, z0 + 0.02), (hw, y1, z1 + 0.02), (-hw, y1, z1 + 0.02)]
        k.add((verts, [(0, 1, 2, 3)]), "tangerine" if i % 2 == 0 else "tangerine_dark", smooth=False)
    # side panels (wood) and back
    for s in (-1, 1):
        x = hw * s
        pts = [(x, y, z + 0.02) for y, z in prof] + [(x, length, 0.0), (x, 0.0, 0.0)]
        idx = list(range(len(pts)))
        face = idx if s > 0 else list(reversed(idx))
        bm = bmesh.new()
        vs = [bm.verts.new(p) for p in pts]
        bm.faces.new([vs[i] for i in face])
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        k.add(_out(bm), "wood", smooth=False)
    back = [(-hw, length, 0.0), (hw, length, 0.0), (hw, length, height + 0.02), (-hw, length, height + 0.02)]
    k.add((back, [(3, 2, 1, 0)]), "wood", smooth=False)
    # cream rails along both edges + rounded lip
    for s in (-1, 1):
        k.add(sweep([(hw * s, y, z + 0.06) for y, z in prof], 0.08, 6), "cream")
    k.add(capsule((-hw, length - 0.05, height + 0.04), (hw, length - 0.05, height + 0.04), 0.1, 10, 6), "cream")
    return k


def swap_gate_kit(kind: str, span=8.0, height=4.2) -> Kit:
    """kind 'bike' (round arch, round sign, bike icon) or 'board' (flat beam, pill sign, board icon).
    Riders approach from -Y; the sign faces -Y."""
    k = Kit()
    col = "tangerine" if kind == "bike" else "sky"
    hx = span / 2
    for s in (-1, 1):
        k.add(capsule((hx * s, 0, 0.2), (hx * s, 0, height), 0.32, 12, 6), col)
        for z in (1.2, 2.4):
            k.add(torus(0.33, 0.07, 16, 6), "cream", T(hx * s, 0, z))
        k.add(rbox(1.0, 1.0, 0.4, 0.08, 2), "cream", T(hx * s, 0, 0.2))
    if kind == "bike":
        arc = [(hx * math.cos(math.pi * i / 20), 0, height + hx * 0.45 * math.sin(math.pi * i / 20)) for i in range(21)]
        k.add(sweep(arc, 0.28, 10, caps=False), col)
        cz = height + hx * 0.45 + 1.15
        k.add(capsule((0, 0, height + hx * 0.45), (0, 0, cz - 1.0), 0.2, 8, 4), col)
        k.add(cyl(1.15, 1.15, 0.22, 24), "white", T(0, 0.11, cz) @ R(90, 0, 0))
        k.add(torus(1.15, 0.09, 24, 6), "ink", T(0, 0, cz) @ R(90, 0, 0))
        # bike icon (ink), on the -Y face
        for x in (-0.42, 0.42):
            k.add(torus(0.3, 0.085, 18, 6), "ink", T(x, -0.15, cz - 0.25) @ R(90, 0, 0))
        tri = [(-0.42, cz - 0.25), (0.0, cz - 0.25), (0.25, cz + 0.22), (-0.2, cz + 0.22)]
        for i in range(4):
            a, b = tri[i], tri[(i + 1) % 4]
            k.add(capsule((a[0], -0.15, a[1]), (b[0], -0.15, b[1]), 0.07, 8, 4), "ink")
        k.add(capsule((0.25, -0.15, cz + 0.22), (0.42, -0.15, cz - 0.25), 0.07, 8, 4), "ink")
        k.add(capsule((0.15, -0.15, cz + 0.42), (0.38, -0.15, cz + 0.42), 0.07, 8, 4), "ink")
        k.add(capsule((0.25, -0.15, cz + 0.22), (0.25, -0.15, cz + 0.42), 0.07, 8, 4), "ink")
    else:
        k.add(capsule((-hx, 0, height), (hx, 0, height), 0.3, 12, 6), col)
        cz = height + 1.05
        k.add(prism(stadium(1.5, 3.2, 12), 0.22), "white", T(0, 0.11, cz) @ FACE_CAM @ R(0, 0, 90))
        rim = [(p[1], 0, cz + p[0]) for p in stadium(1.5, 3.2, 12)]
        k.add(sweep(rim + rim[:1], 0.08, 6, caps=False), "ink")
        # board icon: side view of a tilted board, two pods under it, three speed lines behind
        tilt = 8
        k.add(prism(stadium(0.36, 1.7, 8), 0.06), "ink", T(0.2, -0.11, cz + 0.1) @ FACE_CAM @ R(0, 0, 90 + tilt))
        for x in (-0.18, 0.62):
            zz = cz + 0.1 - 0.24 + x * math.tan(math.radians(tilt)) * 0.9
            k.add(cyl(0.13, 0.13, 0.06, 12), "ink", T(x, -0.11, zz) @ R(90, 0, 0))
        for i, z in enumerate((0.28, 0.08, -0.12)):
            x0 = -1.25 + 0.12 * i
            k.add(capsule((x0, -0.13, cz + z), (x0 + 0.38, -0.13, cz + z), 0.045, 6, 4), "ink")
        for s in (-1, 1):
            k.add(capsule((1.0 * s, 0, height), (0.6 * s, 0, cz - 0.6), 0.1, 8, 4), col)
    return k


def finish_arch_kit(span=9.0) -> Kit:
    """Inflatable-look arch, alternating white/sun segments, checker banner, balloons."""
    k = Kit()
    R0 = span / 2
    nseg = 14
    for i in range(nseg):
        a0 = math.pi * i / nseg
        a1 = math.pi * (i + 1) / nseg
        pts = [(R0 * math.cos(a0 + (a1 - a0) * t / 3), 0, 0.3 + R0 * 1.05 * math.sin(a0 + (a1 - a0) * t / 3)) for t in range(4)]
        k.add(sweep(pts, 0.5, 10, caps=True), "white" if i % 2 == 0 else "sun")
    for s in (-1, 1):
        k.add(rbox(1.3, 1.3, 0.5, 0.15, 2), "sky", T(R0 * s, 0, 0.25))
    # checker banner across the top, both faces
    bw, bh, nx, ny = 5.6, 1.1, 10, 2
    z0 = 0.3 + R0 * 1.05 - 0.55 - bh
    for ix in range(nx):
        for iy in range(ny):
            x0 = -bw / 2 + bw * ix / nx
            x1 = x0 + bw / nx
            za = z0 + bh * iy / ny
            zb = za + bh / ny
            col = "ink" if (ix + iy) % 2 == 0 else "white"
            for y, flip in ((-0.42, False), (-0.38, True)):
                v = [(x0, y, za), (x1, y, za), (x1, y, zb), (x0, y, zb)]
                f = [(0, 1, 2, 3)] if flip else [(3, 2, 1, 0)]
                k.add((v, f), col, smooth=False)
    for s in (-1, 1):
        k.add(capsule((bw / 2 * s, -0.4, z0 + bh), (bw / 2 * s * 0.92, -0.2, z0 + bh + 0.55), 0.03, 6, 3), "ink")
    # balloon clusters at the feet
    rnd = random.Random(7)
    for s in (-1, 1):
        for j, col in enumerate(("red", "sun", "sky", "white")):
            bx = R0 * s + rnd.uniform(-0.5, 0.5)
            bz = 1.0 + j * 0.45 + rnd.uniform(0, 0.2)
            k.add(sphere(0.32, 12, 8, (1, 1, 1.18)), col, T(bx + 0.55 * s, -0.4, bz))
    return k


def tree_round_kit(seed=3) -> Kit:
    k = Kit()
    k.add(disc(1.35, 10, 0.02), "shadow_grass", T(0, 0, 0.02), smooth=False)
    k.add(cyl(0.2, 0.13, 1.6, 6), "trunk", smooth=False)
    k.add(ico(1.25, 1, 0.12, seed, (1, 1, 0.92)), "leaf", T(0, 0, 2.5), smooth=False)
    k.add(ico(0.85, 1, 0.15, seed + 1), "leaf_light", T(0.55, -0.35, 3.15), smooth=False)
    k.add(ico(0.7, 1, 0.15, seed + 2), "leaf", T(-0.6, 0.25, 3.1), smooth=False)
    return k


def tree_pine_kit() -> Kit:
    k = Kit()
    k.add(disc(1.2, 10, 0.02), "shadow_grass", T(0, 0, 0.02), smooth=False)
    k.add(cyl(0.17, 0.12, 1.2, 6), "trunk", smooth=False)
    for i, (r, z, h) in enumerate(((1.25, 0.9, 1.9), (0.98, 2.0, 1.7), (0.7, 3.05, 1.6))):
        k.add(cyl(r, 0.0, h, 7), "pine" if i % 2 == 0 else "pine_dark", T(0, 0, z) @ R(0, 0, 20 * i), smooth=False)
    return k


def rock_kit(seed=5) -> Kit:
    k = Kit()
    k.add(ico(0.9, 1, 0.22, seed, (1.25, 1.0, 0.72)), "rock", T(0, 0, 0.42), smooth=False)
    k.add(ico(0.45, 1, 0.25, seed + 3, (1.1, 1.0, 0.8)), "rock_dark", T(0.95, 0.35, 0.22), smooth=False)
    return k


def cloud_kit(seed=1) -> Kit:
    rnd = random.Random(seed)
    k = Kit()
    for i in range(5):
        x = (i - 2) * 1.6 + rnd.uniform(-0.3, 0.3)
        r = 1.6 - abs(i - 2) * 0.35 + rnd.uniform(-0.1, 0.2)
        k.add(ico(r, 1, 0.06, seed + i, (1, 0.8, 0.85)), "cloud" if i % 2 == 0 else "cloud_shade", T(x, 0, r * 0.5), smooth=False)
    return k


def mountain_kit(seed=2, h=60.0, r=70.0) -> Kit:
    rnd = random.Random(seed)
    k = Kit()
    k.add(cyl(r, r * 0.08, h, 9), "mountain", R(0, 0, rnd.uniform(0, 40)), smooth=False)
    k.add(cyl(r * 0.25, r * 0.03, h * 0.25, 9), "snow", T(0, 0, h * 0.74) @ R(0, 0, rnd.uniform(0, 40)), smooth=False)
    return k


def blob(name, sx, sy, coll=None):
    me = bpy.data.meshes.new(name)
    v, f = quad(1, 1)
    me.from_pydata(v, [], f)
    me.materials.append(mat_blob())
    ob = bpy.data.objects.new(name, me)
    ob.scale = (sx, sy, 1)
    (coll or bpy.context.scene.collection).objects.link(ob)
    return ob


def noise2(x, y, s=0.02):
    return noise.noise(Vector((x * s, y * s, 0.37)))
