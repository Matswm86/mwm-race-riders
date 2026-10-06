"""Build the realistic race rider: body (Blender Studio Human Base Meshes, CC0) dressed as a downhill racer
(loose jersey, baggy pants, gloves, shoes), full-face helmet + goggles (own modelling), one UV atlas,
baked textures (6 liveries: jersey colour + back number + helmet design), skeleton and animations.

blender -b --factory-startup -P tools/art/build_rider.py -- [--stage mesh|all] [--preview out.png]

Outputs: assets/models/rider.glb (skinned, 1 mesh, 1 material, livery r1 embedded),
assets/textures/rider/rider_r1..r6_albedo.png, rider_normal.png, rider_orm.png
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).parent))
import rr_art as A  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
STAGE = argv[argv.index("--stage") + 1] if "--stage" in argv else "all"
PREVIEW = argv[argv.index("--preview") + 1] if "--preview" in argv else None
TEXDIR = A.TEX / "rider"
TEXDIR.mkdir(parents=True, exist_ok=True)
SRC = A.RAW / "human" / "human-base-meshes-bundle-v1.4.1" / "human_base_meshes_bundle.blend"
RES = 1024
TARGET_BODY_TRIS = 4200

# Material ids (slot order) -> bake/livery logic
MAT = ["jersey", "pants", "gloves", "shoes", "neck", "shell", "trim", "lens", "strap", "liner"]
ROUGH = {
    "jersey": 0.78,
    "pants": 0.82,
    "gloves": 0.72,
    "shoes": 0.62,
    "neck": 0.85,
    "shell": 0.28,
    "trim": 0.55,
    "lens": 0.06,
    "strap": 0.7,
    "liner": 0.9,
}
METAL = {"lens": 0.85}

# Landmarks after turning the body to face +Y (rider's left = -X). |x| used for both sides.
SHOULDER = Vector((0.18, 0.0, 1.40))
ELBOW = Vector((0.27, 0.0, 1.12))
WRIST = Vector((0.375, 0.056, 0.875))
TIP = Vector((0.42, 0.12, 0.72))
HELM_C = Vector((0.0, 0.018, 1.600))


def load_body() -> bpy.types.Object:
    with bpy.data.libraries.load(str(SRC)) as (_a, b):
        b.objects = ["GEO-body_male_realistic"]
    o = A.link(b.objects[0])
    o.location = (0, 0, 0)
    o.name = "rider_body"
    mr = o.modifiers[0]
    mr.levels = 1
    mr.render_levels = 1
    A.apply_all(o)
    o.rotation_euler = (0, 0, math.pi)
    A.apply_xform(o)
    return o


def seg_t(p: Vector, a: Vector, b: Vector) -> tuple[float, float]:
    ab = b - a
    t = (p - a).dot(ab) / ab.length_squared
    q = a + ab * max(0.0, min(1.0, t))
    return t, (p - q).length


def dress_body(o: bpy.types.Object) -> None:
    """Cut the head (helmet covers it), curl the fingers into a grip, inflate clothes, assign materials."""
    for name in MAT:
        o.data.materials.append(bpy.data.materials.new(name))
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.verts.ensure_lookup_table()
    # 1. delete head above the helmet line
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > 1.565], context="VERTS")
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    # 2. classify + curl fingers
    hand_dir = (TIP - WRIST).normalized()
    kn = WRIST + (TIP - WRIST) * 0.42
    region = {}
    for v in bm.verts:
        p = Vector((abs(v.co.x), v.co.y, v.co.z))
        ta, da = seg_t(p, SHOULDER, WRIST)
        is_arm = (p.x > 0.165 and p.z > 0.70 and da < 0.11 and ta > 0.05) or (
            p.x > 0.30 and p.z > 0.66 and p.z < 1.2
        )
        if is_arm and ta > 0.985:
            r = "gloves"
        elif is_arm:
            r = "jersey_arm"
        elif p.z < 0.118:
            r = "shoes"
        elif p.z < 0.955:
            r = "pants"
        elif p.z > 1.47:
            r = "neck"
        else:
            r = "jersey"
        region[v.index] = (r, ta)
    for v in bm.verts:
        r, ta = region[v.index]
        if r != "gloves":
            continue
        s = 1.0 if v.co.x >= 0 else -1.0
        p = Vector((abs(v.co.x), v.co.y, v.co.z))
        t = (p - kn).dot(hand_dir)
        if t > 0:
            palm_n = Vector((-1.0, 0.0, 0.0))  # palm faces the body (towards x=0)
            axis = hand_dir.cross(palm_n).normalized()
            ang = min(1.0, t / 0.09) * math.radians(95)
            q = Matrix.Rotation(-ang, 3, axis) @ (p - kn) + kn
            v.co = Vector((q.x * s, q.y, q.z))
    bm.normal_update()
    # 3. smooth the cloth (no muscle definition through a loose jersey), then inflate along normals
    cloth = [v for v in bm.verts if region[v.index][0] not in ("gloves",)]
    for _ in range(4):
        bmesh.ops.smooth_vert(
            bm, verts=cloth, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True
        )
        bmesh.ops.smooth_vert(
            bm,
            verts=[v for v in cloth if region[v.index][0] in ("shoes", "pants")],
            factor=0.5,
            use_axis_x=True,
            use_axis_y=True,
            use_axis_z=True,
        )
    bm.normal_update()
    new = {}
    for v in bm.verts:
        r, ta = region[v.index]
        p = Vector((abs(v.co.x), v.co.y, v.co.z))
        if r == "gloves":
            d = 0.006
        elif r == "jersey_arm":
            d = 0.024
            ed = (Vector((0.27, -0.03, 1.12)) - p).length
            d += 0.012 * math.exp(-((ed / 0.06) ** 2))  # elbow pads
            d -= 0.008 * max(0.0, min(1.0, (ta - 0.8) / 0.2))  # sleeve narrows to the cuff
        elif r == "shoes":
            d = 0.018
        else:
            d = 0.025
            d += 0.010 * max(0.0, min(1.0, (p.z - 0.55) / 0.3)) * (p.z < 1.0)  # baggy thighs
            kd = (Vector((0.125, 0.06, 0.49)) - p).length
            d += 0.020 * math.exp(-((kd / 0.06) ** 2))  # knee pads under the pants
            d += 0.010 * math.exp(-(((p.z - 0.975) / 0.02) ** 2))  # jersey hem over the waistband
            d -= 0.016 * max(0.0, min(1.0, (p.z - 1.46) / 0.05))  # collar hugs the neck
            d -= 0.008 * max(0.0, min(1.0, (0.20 - p.z) / 0.08))  # pant cuff over the shoe
        new[v.index] = v.co + v.normal * d
    for v in bm.verts:
        v.co = new[v.index]
        if region[v.index][0] == "shoes" and v.co.z < 0.004:
            v.co.z = 0.004  # flat sole
    # 4. material per face (majority region)
    mid = {"jersey": 0, "jersey_arm": 0, "pants": 1, "gloves": 2, "shoes": 3, "neck": 4}
    for f in bm.faces:
        votes = [mid[region[v.index][0]] for v in f.verts]
        f.material_index = max(set(votes), key=votes.count)
    # 5. shoes: replace the bare feet by a convex hull (flat sole, round toe, no toes)
    foot = [v for v in bm.verts if v.co.z < 0.095]
    hulls = []
    for side in (-1, 1):
        pts = [v.co.copy() for v in foot if v.co.x * side > 0]
        hulls.append(pts)
    bmesh.ops.delete(bm, geom=foot, context="VERTS")
    for pts in hulls:
        hv = [bm.verts.new(c) for c in pts]
        res = bmesh.ops.convex_hull(bm, input=hv)
        for g in res["geom_interior"] + res["geom_unused"]:
            if isinstance(g, bmesh.types.BMVert) and g.is_valid and not g.link_faces:
                bm.verts.remove(g)
        for g in res["geom"]:
            if isinstance(g, bmesh.types.BMFace):
                g.material_index = 3
    bm.to_mesh(o.data)
    bm.free()
    for p in o.data.polygons:
        p.use_smooth = True


def sphere_helmet() -> list[bpy.types.Object]:
    """Full-face downhill helmet: shell with chin bar and eye port, liner, peak, goggles and strap."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=16, radius=1.0)
    sh = bpy.context.active_object
    sh.name = "helmet_shell"
    bm = bmesh.new()
    bm.from_mesh(sh.data)
    for v in bm.verts:
        x, y, z = v.co
        X, Y, Z = x * 0.146, y * 0.176, z * 0.170
        if y > 0 and z < 0.15:  # chin bar juts forward and down
            k = y * min(1.0, (0.15 - z) / 0.8)
            Y += 0.075 * k
            Z -= 0.030 * k
            X *= 1.0 - 0.18 * k  # chin bar narrows
        if y < 0 and z < 0.2:  # occipital flare at the back, reaching down over the neck
            Y -= 0.016 * (-y)
            Z -= 0.030 * (-y) * max(0.0, -z)
        v.co = Vector((X, Y, Z)) + HELM_C
    # cut the open bottom (front a little higher than the back)
    cut = [v for v in bm.verts if v.co.z < 1.452 - 0.012 * max(0.0, (v.co.y - HELM_C.y) / 0.15)]
    bmesh.ops.delete(bm, geom=cut, context="VERTS")
    # eye port
    port = []
    for f in bm.faces:
        c = f.calc_center_median() - HELM_C
        if c.y > 0.05 and -0.040 < c.z < 0.066 and abs(c.x) < 0.100:
            port.append(f)
    bmesh.ops.delete(bm, geom=port, context="FACES")
    bm.to_mesh(sh.data)
    bm.free()
    for p in sh.data.polygons:
        p.use_smooth = True
        p.material_index = 0
    sh.data.materials.append(bpy.data.materials["shell"])
    sh.data.materials.append(bpy.data.materials["liner"])
    so = sh.modifiers.new("solid", "SOLIDIFY")
    so.thickness = 0.011
    so.offset = -1
    so.material_offset = 1
    so.use_rim = True
    A.apply_all(sh)

    # peak (visor) above the eye port
    nx, ny = 9, 4
    verts, faces = [], []
    for j in range(ny):
        for i in range(nx):
            u = i / (nx - 1) * 2 - 1
            w = j / (ny - 1)
            ang = u * 0.85
            r = 0.176 + w * 0.085
            x = math.sin(ang) * (0.125 + 0.035 * w)
            y = HELM_C.y + math.cos(ang) * r * 0.86 + 0.012
            z = HELM_C.z + 0.088 + w * 0.036 - (u * u) * 0.018 * (1 - w)
            verts.append((x, y, z))
    for j in range(ny - 1):
        for i in range(nx - 1):
            a = j * nx + i
            faces.append((a, a + 1, a + nx + 1, a + nx))
    pk = A.mesh_obj("helmet_peak", verts, faces)
    pk.data.materials.append(bpy.data.materials["shell"])
    s2 = pk.modifiers.new("solid", "SOLIDIFY")
    s2.thickness = 0.007
    s2.material_offset = 0
    A.apply_all(pk)
    for p in pk.data.polygons:
        p.use_smooth = True

    # goggles: lens band inside the port, frame + strap around the shell
    def band(name, r_x, r_y, z0, h, a0, a1, seg, mat):
        vs, fs = [], []
        for i in range(seg + 1):
            a = a0 + (a1 - a0) * i / seg
            for k, dz in enumerate((-h / 2, h / 2)):
                vs.append((math.sin(a) * r_x, HELM_C.y + math.cos(a) * r_y, z0 + dz))
        for i in range(seg):
            b = i * 2
            fs.append((b, b + 2, b + 3, b + 1))
        ob = A.mesh_obj(name, vs, fs)
        ob.data.materials.append(bpy.data.materials[mat])
        sd = ob.modifiers.new("s", "SOLIDIFY")
        sd.thickness = 0.008
        sd.offset = 1
        A.apply_all(ob)
        for p in ob.data.polygons:
            p.use_smooth = True
        return ob

    zg = HELM_C.z + 0.012
    from mathutils.bvhtree import BVHTree

    bvh = BVHTree.FromObject(sh, bpy.context.evaluated_depsgraph_get())

    def wrap(name, z0, h, a0, a1, seg, mat, gap, fallback):
        vs, fs = [], []
        for i in range(seg + 1):
            a = a0 + (a1 - a0) * i / seg
            d = Vector((math.sin(a), math.cos(a), 0.0))
            for dz in (-h / 2, h / 2):
                o = Vector((0.0, HELM_C.y, z0 + dz))
                hit = bvh.ray_cast(o + d * 0.4, -d, 0.4)
                r = (0.4 - hit[3] + gap) if hit[0] is not None else fallback(a)
                vs.append(tuple(o + d * r))
        for i in range(seg):
            b = i * 2
            fs.append((b, b + 2, b + 3, b + 1))
        ob = A.mesh_obj(name, vs, fs)
        ob.data.materials.append(bpy.data.materials[mat])
        sd = ob.modifiers.new("s", "SOLIDIFY")
        sd.thickness = 0.007
        sd.offset = 1
        A.apply_all(ob)
        for p in ob.data.polygons:
            p.use_smooth = True
        return ob

    def ell(rx, ry):
        return lambda a: 1.0 / math.sqrt((math.sin(a) / rx) ** 2 + (math.cos(a) / ry) ** 2)

    lens = band("goggle_lens", 0.128, 0.170, zg, 0.064, -1.0, 1.0, 16, "lens")
    frame = wrap("goggle_frame", zg, 0.078, -1.25, 1.25, 20, "trim", 0.004, ell(0.140, 0.182))
    strap = wrap(
        "goggle_strap",
        zg + 0.006,
        0.042,
        1.15,
        2 * math.pi - 1.15,
        24,
        "strap",
        0.003,
        ell(0.150, 0.19),
    )
    return [sh, pk, lens, frame, strap]


def uv_and_join(body: bpy.types.Object, parts: list[bpy.types.Object]) -> bpy.types.Object:
    for p in parts:
        A.activate(p)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
        if not p.data.uv_layers:
            continue
        p.data.uv_layers[0].name = "UVMap"
    # helmet/goggle materials -> body slot order
    for p in parts:
        for i, slot in enumerate(p.material_slots):
            pass
    # the shoe hulls are new faces without UVs: unwrap them on their own
    A.activate(body)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    body.active_material_index = MAT.index("shoes")
    bpy.ops.object.material_slot_select()
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    for p in parts:
        vg = p.vertex_groups.new(name="rigid_head")
        vg.add(list(range(len(p.data.vertices))), 1.0, "REPLACE")
        p.select_set(True)
    bpy.ops.object.join()
    o = bpy.context.active_object
    # keep only one UV layer
    while len(o.data.uv_layers) > 1:
        o.data.uv_layers.remove(o.data.uv_layers[1])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.context.scene.tool_settings.use_uv_select_sync = True
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(rotate=True, margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    return o


def decimate(o: bpy.types.Object, target: int) -> None:
    n = A.tris(o)
    if n <= target:
        return
    d = o.modifiers.new("dec", "DECIMATE")
    d.ratio = target / n
    d.use_symmetry = True
    d.symmetry_axis = "X"
    A.apply_all(o)


def main_mesh() -> bpy.types.Object:
    A.reset()
    body = load_body()
    dress_body(body)
    decimate(body, TARGET_BODY_TRIS)
    parts = sphere_helmet()
    # material slot remap happens through shared material datablocks: join merges slots by material
    rider = uv_and_join(body, parts)
    rider.name = "rider_body"
    # reorder isn't needed: materials are looked up by name later
    print("RIDER tris", A.tris(rider), "mats", [m.name for m in rider.data.materials])
    return rider


# ---------------------------------------------------------------- textures
LIVERY = {  # per rider: number fill / outline, helmet base / second colour
    "r1": {"nf": "#FFFFFF", "no": "#16181C", "hb": "#16181C", "h2": "#C8202B"},
    "r2": {"nf": "#16181C", "no": "#FFFFFF", "hb": "#F2A900", "h2": "#16181C"},
    "r3": {"nf": "#FFFFFF", "no": "#0B1F4A", "hb": "#F2F3F5", "h2": "#1E5BD6"},
    "r4": {"nf": "#FFFFFF", "no": "#0A3B2E", "hb": "#0F8F6E", "h2": "#F2F3F5"},
    "r5": {"nf": "#16181C", "no": "#C8202B", "hb": "#F2F3F5", "h2": "#C8202B"},
    "r6": {"nf": "#FFFFFF", "no": "#FF6A13", "hb": "#2A2E35", "h2": "#FF6A13"},
}


def _emit_mat(name, socket_fn):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(socket_fn(nt), em.inputs["Color"])
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m


def _bump_mat(name, kind):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    bump = nt.nodes.new("ShaderNodeBump")
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    cfg = {  # scale, detail, strength, distance
        "jersey": (9.0, 4.0, 0.55, 0.010),
        "pants": (11.0, 5.0, 0.65, 0.012),
        "gloves": (30.0, 3.0, 0.4, 0.003),
        "shoes": (40.0, 2.0, 0.25, 0.002),
        "neck": (25.0, 2.0, 0.3, 0.003),
        "strap": (60.0, 2.0, 0.3, 0.002),
    }.get(kind)
    if cfg is None:
        return m
    nz.inputs["Scale"].default_value = cfg[0]
    nz.inputs["Detail"].default_value = cfg[1]
    nz.inputs["Distortion"].default_value = 0.6
    bump.inputs["Strength"].default_value = cfg[2]
    bump.inputs["Distance"].default_value = cfg[3]
    # fold lines: stretched noise (wrinkles run round the limbs)
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.0, 1.0, 3.2)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], nz.inputs["Vector"])
    nt.links.new(nz.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


def _swap_slots(o, mats):
    for i, slot in enumerate(o.material_slots):
        slot.material = mats[i]


def bake_maps(o: bpy.types.Object) -> dict:
    A.cycles(8)
    sc = bpy.context.scene
    sc.world = sc.world or bpy.data.worlds.new("w")
    sc.world.light_settings.distance = 0.12
    orig = [s.material.name for s in o.material_slots]
    out = {}
    # position + object normal + material id (float bakes)
    for key, fn in (
        ("pos", lambda nt: nt.nodes.new("ShaderNodeNewGeometry").outputs["Position"]),
        ("nrm", lambda nt: nt.nodes.new("ShaderNodeNewGeometry").outputs["Normal"]),
    ):
        mt = _emit_mat("__" + key, fn)
        _swap_slots(o, [mt] * len(o.material_slots))
        img = A.new_image("__" + key, RES, alpha=True, non_color=True, float_buf=True)
        A.bake(o, img, "EMIT", samples=1, margin=6)
        out[key] = A.px(img).copy()
    mids = []
    for i, nm in enumerate(orig):
        v = (MAT.index(nm) + 1) / 16.0
        mids.append(_emit_mat(f"__mid{i}", lambda nt, v=v: _rgb(nt, (v, v, v))))
    _swap_slots(o, mids)
    img = A.new_image("__mid", RES, alpha=True, non_color=True, float_buf=True)
    A.bake(o, img, "EMIT", samples=1, margin=6)
    mid = A.px(img)
    out["mid"] = np.rint(mid[..., 0] * 16.0).astype(int) - 1
    # tangent normal map from fabric bump
    bumps = [_bump_mat(f"__b{i}", nm) for i, nm in enumerate(orig)]
    _swap_slots(o, bumps)
    nimg = A.new_image("rider_normal", RES, non_color=True)
    A.bake(o, nimg, "NORMAL", samples=4, margin=8)
    A.save_png(nimg, TEXDIR / "rider_normal.png")
    # ambient occlusion
    _swap_slots(o, [bpy.data.materials[n] for n in orig])
    for m in o.data.materials:
        m.use_nodes = True
    aimg = A.new_image("__ao", RES, non_color=True)
    A.bake(o, aimg, "AO", samples=64, margin=8)
    out["ao"] = A.px(aimg)[..., 0].copy()
    return out


def _rgb(nt, c):
    n = nt.nodes.new("ShaderNodeRGB")
    n.outputs[0].default_value = (*c, 1.0)
    return n.outputs[0]


def _srgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4)])


def _num_mask(n):
    img = A.load_image(A.BUILD / f"num_{n}.png", non_color=True)
    return A.px(img)[..., :3].copy()  # Blender pixel rows start at the bottom, so v grows upwards


def _sample(mask, u, v):
    h, w = mask.shape[:2]
    ok = (u >= 0) & (u < 1) & (v >= 0) & (v < 1)
    iu = np.clip((u * w).astype(int), 0, w - 1)
    iv = np.clip((v * h).astype(int), 0, h - 1)
    s = mask[iv, iu]
    s[~ok] = 0
    return s


def livery(maps: dict, rider: dict) -> np.ndarray:
    """sRGB albedo (H, W, 3) for one racer, computed per texel from rest-pose position, normal and material."""
    P, N, M = maps["pos"][..., :3], maps["nrm"][..., :3], maps["mid"]
    x, y, z = P[..., 0], P[..., 1], P[..., 2]
    ax = np.abs(x)
    L = LIVERY[rider["id"]]
    base, acc, trim = _srgb(rider["hex"]), _srgb(rider["accent"]), _srgb(rider["trim"])
    col = np.zeros(P.shape[:2] + (3,), np.float32) + _srgb("#808080")

    def put(mask, c):
        col[mask] = c

    # arm parameter t (shoulder 0 -> wrist 1) and distance to the arm axis
    S, W = np.array(SHOULDER), np.array(WRIST)
    Q = np.stack([ax, y, z], -1)
    ab = W - S
    t = ((Q - S) @ ab) / ab.dot(ab)
    proj = S + np.clip(t, 0, 1)[..., None] * ab
    dist = np.linalg.norm(Q - proj, axis=-1)
    arm = (dist < 0.14) & (ax > 0.19) & (z > 0.72)
    body = (M == 0) | (M == 1) | (M == 4)
    jersey = body & ((z >= 0.975) | arm)
    pants = body & ~jersey
    # jersey
    put(jersey, base)
    side = jersey & ~arm & (ax > 0.128 + 0.02 * np.clip((z - 1.0) / 0.4, 0, 1))
    put(side, acc)
    put(jersey & arm & (t > 0.55), acc)
    put(jersey & arm & (t > 0.86) & (t < 0.905), trim)
    chev = jersey & ~arm & (np.abs(z - (1.385 - 0.42 * ax)) < 0.010) & (N[..., 1] < 0.2)
    put(chev, trim)
    put(jersey & (z > 1.425), acc)
    put(jersey & (z > 0.975) & (z < 1.005) & ~arm, acc)
    put(M == 4, acc)
    # back number
    nm = _num_mask(rider["num"])
    u = (x + 0.150) / 0.300
    v = (z - 1.055) / 0.300
    back = jersey & ~arm & (N[..., 1] < -0.35)
    s = _sample(nm, u, v)
    put(back & (s[..., 1] > 0.5), _srgb(L["no"]))
    put(back & (s[..., 0] > 0.5), _srgb(L["nf"]))
    # front number (small, chest left)
    front = jersey & ~arm & (N[..., 1] > 0.35)
    s = _sample(nm, (-x - 0.01) / 0.10, (z - 1.24) / 0.10)
    put(front & (s[..., 0] > 0.5), _srgb(L["nf"]) if rider["id"] != "r5" else trim)
    # pants: dark with a team-colour outer panel and trim line
    put(pants, _srgb("#1C1E22"))
    legc = np.interp(z, [0.08, 0.49, 0.95], [0.165, 0.125, 0.095])
    put(pants & (np.abs(ax - legc - 0.066) < 0.010), base)  # team-colour side stripe
    put(pants & (np.abs(ax - legc - 0.080) < 0.003), trim)
    put(pants & (z > 0.40) & (z < 0.58) & (y > 0.04), _srgb("#2A2D33"))  # knee panel
    put(pants & (z > 0.90) & (z < 0.975), _srgb("#26292E"))  # waistband
    # gloves
    g = M == 2
    put(g, base)
    palm = g & (N[..., 0] * np.sign(x) < -0.2)
    put(palm, _srgb("#202226"))
    # shoes
    sh = M == 3
    put(sh, _srgb("#1A1B1E"))
    put(sh & (z < 0.032), _srgb("#C9CBCF"))
    put(sh & (z < 0.010), _srgb("#2A2B2E"))
    # helmet shell and peak
    q = P - np.array(HELM_C)
    qx, qy, qz = q[..., 0], q[..., 1], q[..., 2]
    hs = M == 5
    hb, h2 = _srgb(L["hb"]), _srgb(L["h2"])
    put(hs, hb)
    d = rider["design"]
    if d == "stripe":
        put(hs & (np.abs(qx) < 0.030), h2)
        put(hs & (np.abs(np.abs(qx) - 0.036) < 0.004), _srgb("#FFFFFF"))
    elif d == "split":
        put(hs & (qx > 0), h2)
        put(hs & (np.abs(qx) < 0.005), _srgb("#FFFFFF"))
    elif d == "slash":
        band = qz + 0.55 * qy
        put(hs & (np.abs(band - 0.01) < 0.032), h2)
        put(hs & (np.abs(np.abs(band - 0.01) - 0.040) < 0.005), _srgb("#0B1F4A"))
    elif d == "checker":
        ang = np.arctan2(qx, qy)
        ck = ((np.floor(ang * 0.165 / 0.028) + np.floor((qz - 0.035) / 0.028)) % 2).astype(bool)
        bandm = hs & (qz > 0.035) & (qz < 0.091)
        put(bandm & ck, _srgb("#16181C"))
        put(bandm & ~ck, _srgb("#F2F3F5"))
    elif d == "twin":
        put(hs & (np.abs(np.abs(qx) - 0.030) < 0.012), h2)
    elif d == "fade":
        k = np.clip((-qz + 0.02) / 0.12, 0, 1)[..., None]
        dots = ((np.sin(qy * 260) * np.sin(qz * 260)) > 0.55) & (qz > -0.02) & (qz < 0.06)
        col[hs] = (hb * (1 - k) + h2 * k)[hs]
        put(hs & dots, h2)
    # vents, lower rim, helmet back number
    put(
        hs & (np.abs(np.abs(qx) - 0.042) < 0.010) & (qy < -0.02) & (qy > -0.12) & (qz > 0.10),
        _srgb("#121314"),
    )
    put(hs & (qz < -0.125 + 0.03 * np.clip(qy / 0.15, 0, 1)), _srgb("#121314"))
    s = _sample(nm, (qx + 0.032) / 0.064, (qz + 0.085) / 0.064)
    hb_back = hs & (N[..., 1] < -0.5)
    put(hb_back & (s[..., 1] > 0.5), _srgb("#121314") if d != "fade" else _srgb("#FFFFFF"))
    put(hb_back & (s[..., 0] > 0.5), _srgb("#FFFFFF") if d != "fade" else _srgb("#121314"))
    # goggles
    put(M == 6, _srgb("#141517"))
    put(M == 7, _srgb("#B4561C"))
    st = M == 8
    put(st, acc if rider["id"] not in ("r5",) else base)
    angs = np.arctan2(qx, qy)
    put(st & (np.sin(angs * 18 + qz * 120) > 0.35), base if rider["id"] not in ("r5",) else acc)
    put(M == 9, _srgb("#1A1A1A"))
    return col


def orm(maps: dict) -> np.ndarray:
    M = maps["mid"]
    r = np.full(M.shape, 0.75, np.float32)
    m = np.zeros(M.shape, np.float32)
    for i, nm in enumerate(MAT):
        r[i == M] = ROUGH[nm]
        m[i == M] = METAL.get(nm, 0.0)
    ao = np.clip(maps["ao"] * 0.85 + 0.15, 0, 1)
    return np.stack([ao, r, m], -1)


def write_png(arr: np.ndarray, path: Path, srgb: bool = True) -> None:
    h, w = arr.shape[:2]
    img = bpy.data.images.new(path.stem, w, h, alpha=False)
    img.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
    rgba = np.ones((h, w, 4), np.float32)
    rgba[..., :3] = np.clip(arr, 0, 1)
    if srgb:  # Blender stores byte images as display values; write the sRGB values directly
        img.colorspace_settings.name = "Non-Color"
    A.set_px(img, rgba)
    A.save_png(img, path)
    bpy.data.images.remove(img)


def make_textures(o: bpy.types.Object) -> None:
    maps = bake_maps(o)
    np.savez_compressed(
        A.BUILD / "rider_maps.npz", pos=maps["pos"], nrm=maps["nrm"], mid=maps["mid"], ao=maps["ao"]
    )
    valid = maps["pos"][..., 3] > 0.5
    for r in A.RIDERS:
        c = livery(maps, r)
        c[~valid] = c[valid].mean(0) if valid.any() else 0.5
        write_png(c, TEXDIR / f"rider_{r['id']}_albedo.png")
    write_png(orm(maps), TEXDIR / "rider_orm.png")
    # final single material
    fm = A.pbr_material(
        "rider",
        albedo=TEXDIR / "rider_r1_albedo.png",
        normal=TEXDIR / "rider_normal.png",
        orm=TEXDIR / "rider_orm.png",
    )
    o.data.materials.clear()
    o.data.materials.append(fm)
    for p in o.data.polygons:
        p.material_index = 0


# ---------------------------------------------------------------- skeleton and poses
# name: (head, tail, parent). Rider faces +Y; rider's left is -X. Mirrored ".R" bones are generated.
BONES = {
    "root": ((0, 0, 0), (0, 0.25, 0), None),
    "hips": ((0, 0.0, 0.95), (0, 0.0, 1.10), "root"),
    "spine": ((0, 0.0, 1.10), (0, -0.01, 1.27), "hips"),
    "chest": ((0, -0.01, 1.27), (0, 0.0, 1.44), "spine"),
    "neck": ((0, 0.0, 1.44), (0, 0.02, 1.54), "chest"),
    "head": ((0, 0.02, 1.54), (0, 0.02, 1.76), "neck"),
    "shoulder.L": ((-0.03, 0.0, 1.41), (-0.17, -0.01, 1.40), "chest"),
    "upper_arm.L": ((-0.18, -0.01, 1.40), (-0.27, 0.0, 1.12), "shoulder.L"),
    "forearm.L": ((-0.27, 0.0, 1.12), (-0.375, 0.056, 0.875), "upper_arm.L"),
    "hand.L": ((-0.375, 0.056, 0.875), (-0.42, 0.12, 0.72), "forearm.L"),
    "thigh.L": ((-0.09, 0.0, 0.92), (-0.12, 0.015, 0.49), "hips"),
    "shin.L": ((-0.12, 0.015, 0.49), (-0.16, -0.04, 0.085), "thigh.L"),
    "foot.L": ((-0.16, -0.04, 0.085), (-0.17, 0.14, 0.02), "shin.L"),
}


def build_armature() -> bpy.types.Object:
    ad = bpy.data.armatures.new("rider_rig")
    ob = A.link(bpy.data.objects.new("rider_rig", ad))
    A.activate(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = ad.edit_bones
    spec = dict(BONES)
    for n, (h, t, par) in BONES.items():
        if n.endswith(".L"):
            m = lambda v: (-v[0], v[1], v[2])  # noqa: E731
            pr = par.replace(".L", ".R") if par and par.endswith(".L") else par
            spec[n[:-2] + ".R"] = (m(h), m(t), pr)
    for n, (h, t, _p) in spec.items():
        b = eb.new(n)
        b.head, b.tail = h, t
        d = Vector(t) - Vector(h)
        b.align_roll(Vector((0, 0, 1)) if abs(d.normalized().z) < 0.6 else Vector((0, -1, 0)))
    for n, (_h, _t, par) in spec.items():
        if par:
            eb[n].parent = eb[par]
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def skin(mesh: bpy.types.Object, rig: bpy.types.Object) -> None:
    A.activate(mesh)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    vg_r = mesh.vertex_groups.get("rigid_head")
    if vg_r is None:
        return
    ri = vg_r.index
    head = mesh.vertex_groups.get("head") or mesh.vertex_groups.new(name="head")
    neck = mesh.vertex_groups.get("neck")
    for v in mesh.data.vertices:
        rigid = any(g.group == ri and g.weight > 0.5 for g in v.groups)
        if rigid or v.co.z > 1.50:
            for g in list(v.groups):
                if g.group != ri:
                    mesh.vertex_groups[g.group].remove([v.index])
            head.add([v.index], 1.0, "REPLACE")
        elif v.co.z > 1.42 and neck is not None:  # collar follows the neck softly
            pass
    mesh.vertex_groups.remove(vg_r)
    mesh.vertex_groups.remove(mesh.vertex_groups["root"]) if mesh.vertex_groups.get(
        "root"
    ) else None


# --- pose solver (armature space == rider space; the rig object sits at the origin)
def _rest3(pb):
    return pb.bone.matrix_local.to_3x3()


def _cur_rot(pb):
    """Rotation that takes this bone from rest to its current pose (armature space)."""
    return pb.matrix.to_3x3() @ _rest3(pb).inverted()


def _head_now(pb):
    if pb.parent is None:
        return pb.bone.head_local.copy()
    par = pb.parent
    return par.matrix @ (par.bone.matrix_local.inverted() @ pb.bone.head_local)


def _upd():
    bpy.context.view_layer.update()


def place(pb, rot3, head=None):
    h = head if head is not None else _head_now(pb)
    pb.matrix = Matrix.Translation(h) @ (rot3 @ _rest3(pb)).to_4x4()
    _upd()


def aim(pb, direction, twist=0.0):
    base = (_cur_rot(pb.parent) if pb.parent else Matrix.Identity(3)) @ _rest3(pb)
    y = base.col[1]
    rd = y.rotation_difference(Vector(direction).normalized()).to_matrix()
    m3 = rd @ base
    if twist:
        m3 = Matrix.Rotation(twist, 3, m3.col[1]) @ m3
    pb.matrix = Matrix.Translation(_head_now(pb)) @ m3.to_4x4()
    _upd()


def two_bone(up, lo, target, pole):
    s = _head_now(up)
    l1 = (up.bone.tail_local - up.bone.head_local).length
    l2 = (lo.bone.tail_local - lo.bone.head_local).length
    t = Vector(target)
    d = min((t - s).length, l1 + l2 - 1e-3)
    n = (t - s).normalized()
    pv = Vector(pole) - n * Vector(pole).dot(n)
    pv.normalize()
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    hh = math.sqrt(max(0.0, l1 * l1 - a * a))
    j = s + n * a + pv * hh
    aim(up, j - s)
    aim(lo, (s + n * d) - j)


def RX(a):
    return Matrix.Rotation(math.radians(a), 3, "X")


def RY(a):
    return Matrix.Rotation(math.radians(a), 3, "Y")


def RZ(a):
    return Matrix.Rotation(math.radians(a), 3, "Z")


def pose(rig, P: dict) -> None:
    """P: hips (pos), R (3x3 body orientation), bend (spine, chest, neck, head pitch deg, + = forward),
    head_yaw, wrists {L,R}, elbow_pole {L,R}, ankles {L,R}, knee_pole {L,R}, foot_dir {L,R}, hand_dir {L,R}."""
    pbs = rig.pose.bones
    for pb in pbs:
        pb.rotation_mode = "QUATERNION"
        pb.matrix_basis = Matrix.Identity(4)
    _upd()
    R = P["R"]
    place(pbs["hips"], R, Vector(P["hips"]))
    cum = 0.0
    for name, b in zip(("spine", "chest", "neck", "head"), P.get("bend", (0, 0, 0, 0))):
        cum += b
        aim(
            pbs[name],
            R @ (RX(-cum) @ Vector((0, 0, 1))),
            twist=math.radians(P.get("head_yaw", 0)) if name == "neck" else 0.0,
        )
    for s in ("L", "R"):
        aim(
            pbs[f"shoulder.{s}"],
            (
                _cur_rot(pbs["chest"])
                @ (pbs[f"shoulder.{s}"].bone.tail_local - pbs[f"shoulder.{s}"].bone.head_local)
            ),
        )
        if f"wrist_{s}" in P:
            two_bone(pbs[f"upper_arm.{s}"], pbs[f"forearm.{s}"], P[f"wrist_{s}"], P[f"elbow_{s}"])
        if f"hand_{s}" in P:
            aim(pbs[f"hand.{s}"], P[f"hand_{s}"])
        if f"ankle_{s}" in P:
            two_bone(pbs[f"thigh.{s}"], pbs[f"shin.{s}"], P[f"ankle_{s}"], P[f"knee_{s}"])
        if f"foot_{s}" in P:
            aim(pbs[f"foot.{s}"], P[f"foot_{s}"])


def key_all(rig, frame: int) -> None:
    for pb in rig.pose.bones:
        pb.keyframe_insert("location", frame=frame)
        pb.keyframe_insert("rotation_quaternion", frame=frame)


B = A.BIKE
GX, GY, GZ = B["grip"]
BBY, BBZ = B["bb"][1], B["bb"][2]
CR = B["crank"]
PX = B["pedal_x"]


def bike_pose(**over):
    P = {
        "hips": (0, -0.33, 1.02),
        "R": RX(-30),
        "bend": (28, 22, -40, -12),
        "wrist_L": (-GX + 0.02, GY - 0.055, GZ + 0.035),
        "elbow_L": (-0.7, -0.5, -0.5),
        "wrist_R": (GX - 0.02, GY - 0.055, GZ + 0.035),
        "elbow_R": (0.7, -0.5, -0.5),
        "hand_L": (-0.12, 1, -0.25),
        "hand_R": (0.12, 1, -0.25),
        "ankle_L": (-PX, BBY + CR - 0.065, BBZ + 0.088),
        "knee_L": (-0.35, 1, 0.2),
        "ankle_R": (PX, BBY - CR - 0.065, BBZ + 0.088),
        "knee_R": (0.35, 1, 0.2),
        "foot_L": (0, 1, -0.38),
        "foot_R": (0, 1, -0.38),
    }
    P.update(over)
    return P


D = A.BOARD_DECK_Z
POSES = {
    "bike": bike_pose(),
    "cheer": bike_pose(
        **{
            "wrist_R": (0.32, -0.12, 1.86),
            "elbow_R": (1, 0, -0.2),
            "hand_R": (0, 0, 1),
            "bend": (22, 14, -30, -10),
        }
    ),
    "trick_nohands": bike_pose(
        **{
            "wrist_L": (-0.78, -0.25, 1.30),
            "elbow_L": (0, -1, -0.5),
            "hand_L": (-1, 0, 0),
            "wrist_R": (0.78, -0.25, 1.30),
            "elbow_R": (0, -1, -0.5),
            "hand_R": (1, 0, 0),
            "hips": (0, -0.36, 1.08),
            "R": RX(-12),
            "bend": (10, 6, -10, -4),
        }
    ),
    "trick_superman": bike_pose(
        **{
            "hips": (0, -0.62, 1.18),
            "R": RX(-78),
            "bend": (8, 4, -45, -25),
            "ankle_L": (-0.16, -1.42, 1.22),
            "knee_L": (-0.2, 0, -1),
            "ankle_R": (0.16, -1.42, 1.28),
            "knee_R": (0.2, 0, -1),
            "foot_L": (0, -1, -0.3),
            "foot_R": (0, -1, -0.3),
        }
    ),
    "board": {
        "hips": (0.02, 0.0, D + 0.72),
        "R": RZ(-90) @ RX(-8),
        "bend": (10, 6, -8, 0),
        "head_yaw": 70,
        "wrist_L": (0.10, 0.62, D + 0.80),
        "elbow_L": (0, 0, -1),
        "hand_L": (0, 1, -0.4),
        "wrist_R": (0.12, -0.55, D + 0.70),
        "elbow_R": (0, 0, -1),
        "hand_R": (0, -1, -0.6),
        "ankle_L": (-0.02, 0.24, D + 0.09),
        "knee_L": (1, 0.3, 0),
        "ankle_R": (-0.02, -0.24, D + 0.09),
        "knee_R": (1, -0.3, 0),
        "foot_L": (1, 0.25, -0.35),
        "foot_R": (1, -0.1, -0.35),
    },
}
POSES["board_grab"] = dict(
    POSES["board"],
    **{
        "hips": (0.06, 0.0, D + 0.52),
        "bend": (35, 20, -25, 0),
        "wrist_L": (0.22, 0.10, D + 0.12),
        "elbow_L": (1, 0, 0.5),
        "hand_L": (0, 0, -1),
    },
)

LIE = {
    "hips": (0.40, 2.20, 0.13),
    "R": RX(-270),
    "bend": (0, 0, 0, 0),
    "wrist_L": (-0.10, 1.95, 0.07),
    "elbow_L": (-1, 0, 0.3),
    "hand_L": (-1, 0, 0),
    "wrist_R": (0.92, 1.92, 0.07),
    "elbow_R": (1, 0, 0.3),
    "hand_R": (1, 0, 0),
    "ankle_L": (0.28, 2.98, 0.09),
    "knee_L": (0, 0, 1),
    "ankle_R": (0.58, 2.92, 0.10),
    "knee_R": (0.2, 0, 1),
    "foot_L": (-0.1, 0.3, 1),
    "foot_R": (0.2, 0.3, 1),
}
FALL = [  # (frame @30 fps, pose) over-the-bars tumble: dive, shoulder roll, end on the back, feet downhill
    (0, POSES["bike"]),
    (
        6,
        {
            "hips": (0.08, 0.35, 1.38),
            "R": RX(-62) @ RY(12),
            "bend": (15, 10, -20, -10),
            "wrist_L": (-0.30, 1.05, 0.95),
            "elbow_L": (-1, 0, -0.3),
            "wrist_R": (0.35, 1.05, 0.90),
            "elbow_R": (1, 0, -0.3),
            "ankle_L": (-0.15, -0.25, 1.05),
            "knee_L": (0, 1, -0.3),
            "ankle_R": (0.18, -0.35, 1.15),
            "knee_R": (0, 1, -0.3),
        },
    ),
    (
        13,
        {
            "hips": (0.22, 1.00, 1.02),
            "R": RX(-115) @ RY(25),
            "bend": (20, 15, -10, 0),
            "wrist_L": (-0.10, 1.55, 0.10),
            "elbow_L": (-1, -0.5, 0),
            "wrist_R": (0.55, 1.50, 0.12),
            "elbow_R": (1, -0.5, 0),
            "ankle_L": (0.05, 0.35, 1.70),
            "knee_L": (0, 1, 0),
            "ankle_R": (0.35, 0.30, 1.62),
            "knee_R": (0, 1, 0),
        },
    ),
    (
        20,
        {
            "hips": (0.32, 1.52, 0.55),
            "R": RX(-205) @ RY(20),
            "bend": (30, 25, 20, 10),
            "wrist_L": (0.05, 1.30, 0.30),
            "elbow_L": (-1, 0, 0),
            "wrist_R": (0.60, 1.30, 0.35),
            "elbow_R": (1, 0, 0),
            "ankle_L": (0.25, 1.55, 1.05),
            "knee_L": (0, 1, 1),
            "ankle_R": (0.45, 1.65, 0.95),
            "knee_R": (0, 1, 1),
        },
    ),
    (
        27,
        {
            "hips": (0.38, 2.02, 0.20),
            "R": RX(-262),
            "bend": (8, 6, 10, 5),
            "wrist_L": (-0.05, 1.85, 0.12),
            "elbow_L": (-1, 0, 0.5),
            "wrist_R": (0.85, 1.85, 0.12),
            "elbow_R": (1, 0, 0.5),
            "ankle_L": (0.25, 2.60, 0.45),
            "knee_L": (0, 0, 1),
            "ankle_R": (0.55, 2.55, 0.35),
            "knee_R": (0, 0, 1),
        },
    ),
    (36, LIE),
]
GETUP = [
    (0, LIE),
    (
        9,
        {
            "hips": (0.40, 2.22, 0.16),
            "R": RX(-8),
            "bend": (14, 8, -6, -4),
            "wrist_L": (0.12, 2.00, 0.06),
            "elbow_L": (-1, -1, 0),
            "wrist_R": (0.68, 2.00, 0.06),
            "elbow_R": (1, -1, 0),
            "hand_L": (0, -0.3, -1),
            "hand_R": (0, -0.3, -1),
            "ankle_L": (0.30, 2.92, 0.09),
            "knee_L": (0, 0.3, 1),
            "ankle_R": (0.55, 2.82, 0.10),
            "knee_R": (0, 0.3, 1),
            "foot_L": (0, 0.2, 1),
            "foot_R": (0, 0.2, 1),
        },
    ),
    (
        17,
        {
            "hips": (0.40, 2.42, 0.58),
            "R": RX(-25),
            "bend": (15, 10, -15, -5),
            "wrist_L": (0.30, 2.70, 0.55),
            "elbow_L": (-1, 0, -1),
            "wrist_R": (0.58, 2.72, 0.58),
            "elbow_R": (1, 0, -1),
            "ankle_L": (0.32, 2.05, 0.10),
            "knee_L": (0, 1, -1),
            "ankle_R": (0.56, 2.78, 0.09),
            "knee_R": (0, 1, 0.3),
            "foot_L": (0, -1, 0.1),
            "foot_R": (0, 1, -0.3),
        },
    ),
    (
        24,
        {
            "hips": (0.40, 2.55, 0.84),
            "R": RX(-18),
            "bend": (10, 6, -12, -4),
            "wrist_L": (0.12, 2.60, 0.86),
            "elbow_L": (-1, -0.5, 0),
            "wrist_R": (0.70, 2.62, 0.86),
            "elbow_R": (1, -0.5, 0),
            "ankle_L": (0.32, 2.42, 0.09),
            "knee_L": (0, 1, 0),
            "ankle_R": (0.52, 2.70, 0.09),
            "knee_R": (0, 1, 0),
            "foot_L": (0, 1, -0.3),
            "foot_R": (0, 1, -0.3),
        },
    ),
    (
        30,
        {
            "hips": (0.40, 2.60, 0.95),
            "R": RX(-3),
            "bend": (2, 2, -2, 0),
            "wrist_L": (0.06, 2.62, 0.88),
            "elbow_L": (-1, -1, 0),
            "wrist_R": (0.74, 2.62, 0.88),
            "elbow_R": (1, -1, 0),
            "ankle_L": (0.31, 2.60, 0.085),
            "knee_L": (0, 1, 0),
            "ankle_R": (0.49, 2.60, 0.085),
            "knee_R": (0, 1, 0),
            "foot_L": (0, 1, -0.35),
            "foot_R": (0, 1, -0.35),
        },
    ),
]


def make_actions(rig) -> list[str]:
    rig.animation_data_create()
    names = []
    seqs = {k: [(0, v)] for k, v in POSES.items()}
    seqs["fall"] = FALL
    seqs["lying"] = [(0, LIE)]
    seqs["getup"] = GETUP
    for name, keys in seqs.items():
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        rig.animation_data.action = act
        for f, P in keys:
            pose(rig, P)
            key_all(rig, f)
        tr = rig.animation_data.nla_tracks.new()
        tr.name = name
        tr.strips.new(name, 0, act)
        rig.animation_data.action = None
        names.append(name)
    return names


def build_rig_and_export(mesh: bpy.types.Object) -> None:
    rig = build_armature()
    skin(mesh, rig)
    names = make_actions(rig)
    bpy.context.scene.render.fps = 30
    # leave the rig in the bike pose for previews
    pose(rig, POSES["bike"])
    bpy.ops.wm.save_as_mainfile(filepath=str(A.BUILD / "rider_rigged.blend"))
    out = A.export_glb([rig, mesh], "rider", anim=True, skins=True)
    print("EXPORT", out, out.stat().st_size, "anims", names, "tris", A.tris(mesh))


def preview(objs, out: str, cam_loc=(1.6, -2.6, 1.6), target=(0, 0, 0.95), lens=55) -> None:
    sc = bpy.context.scene
    A.cycles(32)
    sc.render.resolution_x = 900
    sc.render.resolution_y = 900
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.6, 0.65, 0.7, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.5
    so = A.link(bpy.data.objects.new("sun", sun))
    so.rotation_euler = A.deg(50, 10, 30)
    cam = bpy.data.cameras.new("c")
    cam.lens = lens
    co = A.link(bpy.data.objects.new("c", cam))
    co.location = cam_loc
    d = Vector(target) - Vector(cam_loc)
    co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.camera = co
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    r = main_mesh()
    if STAGE in ("tex", "all"):
        make_textures(r)
        bpy.ops.wm.save_as_mainfile(filepath=str(A.BUILD / "rider_tex.blend"))
        if PREVIEW and STAGE == "tex":
            r2 = r.copy()
            A.link(r2)
            r2.location.x = 1.0
            r2.rotation_euler.z = math.pi
            preview([r, r2], PREVIEW, cam_loc=(0.5, -3.4, 1.3), target=(0.5, 0, 0.95), lens=50)
    if STAGE == "all":
        build_rig_and_export(r)
