"""Shared helpers for the world 3-6 art scripts and the W1/W2 landmarks (Blender 4.5, `blender -b`).

Same conventions as rr_art.py: metres, Z up, models face +Y (= Godot -Z, the race direction), origin on the
ground, ONE baked atlas material per GLB (albedo + normal + ORM [+ emission]).
GLBs go to assets/models/world<N>/, textures to assets/textures/world<N>/.
"""

from __future__ import annotations

import json
import math
import random
import shutil
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, noise

sys.path.insert(0, str(Path(__file__).parent))
import build_kit as K  # noqa: E402
import glb_fix  # noqa: E402  (cube, cyl, truss; import has no side effects)
import build_nature as N  # noqa: E402  (impostor rendering helpers)
import rr_art as A  # noqa: E402

REPORT: dict[str, tuple] = {}
REPORT_FILE = A.BUILD / "w36_report.json"


def tdir(w: int) -> Path:
    d = A.TEX / f"world{w}"
    d.mkdir(parents=True, exist_ok=True)
    (A.MODELS / f"world{w}").mkdir(parents=True, exist_ok=True)
    return d


def fix_vertex_alpha(path: Path) -> bool:
    """Kept for callers; glb_fix.fix() now does the vertex-alpha and the UV-set fix."""
    return bool(glb_fix.fix(path))


def done(o, w: int, name: str, note: str = "") -> Path:
    A.apply_xform(o)
    tdir(w)
    out = A.export_glb([o], f"world{w}/{name}")
    fixed = glb_fix.fix(out)  # COLOR_0 = edge-fade alpha, TEXCOORD_0 = baked atlas
    if "COLOR_0 = vertex alpha" in fixed:
        note = (note + "; " if note else "") + "COLOR_0 = edge-fade alpha"
    REPORT[f"world{w}/{name}"] = (A.size_godot([o]), A.tris(o), out.stat().st_size, note)
    print("W36", f"world{w}/{name}", REPORT[f"world{w}/{name}"])
    return out


def save_report() -> None:
    old = json.loads(REPORT_FILE.read_text()) if REPORT_FILE.exists() else {}
    old.update({k: list(v) for k, v in REPORT.items()})
    REPORT_FILE.write_text(json.dumps(old, indent=1))


def tset(w: int, name: str) -> dict:
    """A terrain texture set made by make_terrain36.py, usable as a src_mat source."""
    d = A.TEX / f"world{w}"
    return {
        "albedo": d / f"terrain_{name}_albedo.jpg",
        "normal": d / f"terrain_{name}_normal.jpg",
        "arm": d / f"terrain_{name}_arm.jpg",
    }


def w1set(name: str) -> dict:
    d = A.TEX / "world1"
    return {
        "albedo": d / f"terrain_{name}_albedo.jpg",
        "normal": d / f"terrain_{name}_normal.jpg",
        "arm": d / f"terrain_{name}_arm.jpg",
    }


def acg(name: str) -> dict:
    d = A.RAW / "ambientcg" / name
    return {"albedo": d / f"{name}_1K-JPG_Color.jpg", "normal": d / f"{name}_1K-JPG_NormalGL.jpg"}


def mat(name, tex=None, **kw):
    return A.src_mat(name, tex, **kw)


def flat(name, hexc, rough=0.6, metal=0.0, emit=None):
    return A.src_mat(name, color=A.rgba(hexc), rough=rough, metal=metal, emit=emit)


# ---------------------------------------------------------------- geometry helpers
cube = K.cube
cyl = K.cyl
tube = A.tube
join = A.join


def smooth(o, on=True):
    for p in o.data.polygons:
        p.use_smooth = on
    return o


def displace(o, strength: float, size: float, seed: int = 0, octaves: int = 4, axis=None):
    """Fractal noise displacement along the vertex normal (or a fixed axis), applied in place."""
    me = o.data
    off = Vector((seed * 17.3, seed * 5.1, seed * 11.7))
    me.calc_normals_split() if hasattr(me, "calc_normals_split") else None
    for v in me.vertices:
        p = (o.matrix_world @ v.co) / size + off
        d = noise.fractal(p, 0.5, 2.0, octaves, noise_basis="PERLIN_ORIGINAL")
        n = Vector(axis) if axis is not None else v.normal
        v.co += n * d * strength
    me.update()
    return o


def ico(name, r, subdiv, loc=(0, 0, 0), m=None):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=r, location=loc)
    o = bpy.context.active_object
    o.name = name
    if m is not None:
        o.data.materials.append(m)
    return o


def grid(name, sx, sy, nx, ny, hfn=None, afn=None, origin=(0, 0)):
    """Grid in X (across) and Y (along) centred on origin. hfn(u, v) -> z, afn(u, v) -> vertex alpha (u, v in -1..1)."""
    verts, faces, alpha = [], [], []
    for j in range(ny):
        for i in range(nx):
            u = i / (nx - 1) * 2 - 1
            v = j / (ny - 1) * 2 - 1
            z = hfn(u, v) if hfn else 0.0
            verts.append((origin[0] + u * sx / 2, origin[1] + v * sy / 2, z))
            alpha.append(afn(u, v) if afn else 1.0)
    for j in range(ny - 1):
        for i in range(nx - 1):
            a = j * nx + i
            faces.append((a, a + 1, a + nx + 1, a + nx))
    o = A.mesh_obj(name, verts, faces)
    smooth(o)
    if afn is not None:
        ca = o.data.color_attributes.new("Col", "BYTE_COLOR", "POINT")
        for i, a in enumerate(alpha):
            ca.data[i].color = (1, 1, 1, max(0.0, min(1.0, a)))
    return o


def decimate_to(o, target: int):
    if A.tris(o) > target * 1.1:  # glTF imports split vertices at UV seams: weld first so collapse can work
        A.activate(o)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=0.0005)
        bpy.ops.object.mode_set(mode="OBJECT")
    for _ in range(4):
        n = A.tris(o)
        if n <= target * 1.1:
            break
        d = o.modifiers.new("d", "DECIMATE")
        d.ratio = max(0.01, target / n)
        A.apply_all(o)
        if A.tris(o) > n * 0.9:
            A.activate(o)
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.mesh.remove_doubles(threshold=0.002)
            bpy.ops.object.mode_set(mode="OBJECT")
    return o


def ground(o, z: float = 0.0):
    zmin = min((o.matrix_world @ v.co).z for v in o.data.vertices)
    o.location.z += z - zmin
    A.apply_xform(o)
    return o


def faces_by_normal(o, mat_up_index: int, thresh: float = 0.55, noise_amt: float = 0.0, seed: int = 0):
    """Faces whose normal points up (z > thresh, with optional noise) get material index mat_up_index."""
    rnd = random.Random(seed)
    for p in o.data.polygons:
        t = thresh + (rnd.uniform(-noise_amt, noise_amt) if noise_amt else 0.0)
        if p.normal.z > t:
            p.material_index = mat_up_index


def bake(o, w: int, stem: str, res: int = 512, tile: float = 1.0, **kw) -> dict:
    A.tile_uv(o, tile)
    return A.bake_down(o, res, tdir(w), stem, **kw)


def vert_alpha(o, fn):
    """fn(world co) -> alpha; adds/overwrites the 'Col' colour attribute (glTF COLOR_0 alpha = edge fade)."""
    me = o.data
    ca = me.color_attributes.get("Col") or me.color_attributes.new("Col", "BYTE_COLOR", "POINT")
    for i, v in enumerate(me.vertices):
        ca.data[i].color = (1, 1, 1, max(0.0, min(1.0, fn(o.matrix_world @ v.co))))


# ---------------------------------------------------------------- Poly Haven sources
def ph_objs(model: str, keep: list[str] | None = None):
    return N.import_ph(model, keep)


def ph_decimated(
    model: str,
    keep: list[str] | None,
    w: int,
    name: str,
    target: int,
    scale=1.0,
    tint=None,
    rough_mul: float = 1.0,
    tex_name: str | None = None,
    note: str = "",
    layout=None,
    sat: float = 1.0,
):
    """Poly Haven scan -> decimated GLB with its own 1K maps (albedo tinted with numpy, ORM from ARM)."""
    A.reset()
    objs = ph_objs(model, keep)
    if layout is not None:
        layout(objs)
    o = objs[0] if len(objs) == 1 else A.join(objs, name)
    o.name = name
    if not isinstance(scale, (tuple, list)):
        scale = (scale,) * 3
    o.scale = scale
    o.location = (0, 0, 0)
    A.apply_xform(o)
    ground(o)
    decimate_to(o, target)
    smooth(o)
    tn = tex_name or name
    td = tdir(w)
    texd = A.PH / "models" / model / "textures"
    diff = next(texd.glob("*_diff_1k.jpg"))
    nor = next(texd.glob("*_nor_gl_1k.jpg"))
    arm = next(texd.glob("*_arm_1k.jpg"), None)
    img = A.load_image(diff)
    a = A.px(img).copy()
    bpy.data.images.remove(img)
    if sat != 1.0:
        g = a[..., :3].mean(-1, keepdims=True)
        a[..., :3] = np.clip(g + (a[..., :3] - g) * sat, 0, 1)
    if tint is not None:
        lin = np.where(a[..., :3] <= 0.04045, a[..., :3] / 12.92, ((a[..., :3] + 0.055) / 1.055) ** 2.4)
        lin = lin * np.array(tint, np.float32)
        a[..., :3] = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(np.clip(lin, 0, 1), 1 / 2.4) - 0.055)
    pa = A.write_png(a, td / f"{tn}_albedo.png")
    pn = td / f"{tn}_normal.jpg"
    shutil.copy(nor, pn)
    po = td / f"{tn}_orm.png"
    if arm is not None:
        img = A.load_image(arm, True)
        r = A.px(img)[..., :3].copy()
        bpy.data.images.remove(img)
        r[..., 1] = np.clip(r[..., 1] * rough_mul, 0.03, 1)
        A.write_png(r, po)
    o.data.materials.clear()
    o.data.materials.append(A.pbr_material(tn, albedo=pa, normal=pn, orm=po))
    return done(o, w, name, note), o


def impostor(
    model: str,
    keep,
    w: int,
    name: str,
    n: int = 4,
    cell=(512, 1024),
    scale=1.0,
    layout=None,
    lift: float = 1.25,
    note: str = "",
):
    """Poly Haven plant/tree -> n-plane star card (2n tris) with an albedo+alpha / normal atlas."""
    A.reset()
    objs = ph_objs(model, keep)
    for o in objs:
        o.scale = (scale,) * 3
    if layout is not None:
        layout(objs)
    bpy.context.view_layer.update()
    pa, pn, ctr, width, height = N.render_views(objs, n, cell, name, tdir(w))
    if lift != 1.25:  # render_views lifts albedo x1.25; re-scale if asked
        img = A.load_image(pa)
        a = A.px(img).copy()
        bpy.data.images.remove(img)
        a[..., :3] = np.clip(a[..., :3] * lift / 1.25, 0, 1)
        A.write_png(a, pa, alpha=a[..., 3])
    zmin = min((o.matrix_world @ Vector(c)).z for o in objs for c in o.bound_box)
    for o in objs:
        bpy.data.objects.remove(o)
    side = max(width, height)
    pw = side * cell[0] / max(cell)
    ph = side * cell[1] / max(cell)
    st = N.star_mesh(name, n, ctr, pw, ph, base_z=ctr.z - ph / 2)
    st.data.materials.append(N.card_material(name, pa, pn))
    # put the plant's real base (not the card's bottom edge) on the ground
    for v in st.data.vertices:
        v.co.z -= zmin
    return done(st, w, name, note or f"{n}-plane impostor, alpha scissor 0.5")


def card_of(build_fn, w: int, name: str, n: int = 2, cell=(512, 512), note: str = ""):
    """Far/Lav card version of a built prop: build_fn() -> list of mesh objects in the scene (already textured)."""
    A.reset()
    objs = build_fn()
    bpy.context.view_layer.update()
    pa, pn, ctr, width, height = N.render_views(objs, n, cell, name, tdir(w))
    zmin = min((o.matrix_world @ Vector(c)).z for o in objs for c in o.bound_box)
    for o in objs:
        bpy.data.objects.remove(o)
    side = max(width, height)
    pw = side * cell[0] / max(cell)
    ph = side * cell[1] / max(cell)
    st = N.star_mesh(name, n, ctr, pw, ph, base_z=ctr.z - ph / 2)
    st.data.materials.append(N.card_material(name, pa, pn))
    for v in st.data.vertices:
        v.co.z -= zmin
    return done(st, w, name, note or f"far card ({n} planes) of the near model")


def import_glb(path: Path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [o for o in bpy.data.objects if o not in before and o.type == "MESH"]


def run(all_fns: dict, argv: list[str]) -> None:
    names = argv or list(all_fns)
    for n in names:
        all_fns[n]()
    save_report()
    for k, v in REPORT.items():
        print("SIZE", k, v)


__all__ = [
    "A", "K", "N", "REPORT", "Matrix", "Vector", "bmesh", "bpy", "math", "np", "random", "noise",
    "tdir", "done", "fix_vertex_alpha", "tset", "w1set", "acg", "mat", "flat", "cube", "cyl", "tube", "join", "smooth",
    "displace", "ico", "grid", "decimate_to", "ground", "faces_by_normal", "bake", "vert_alpha",
    "ph_objs", "ph_decimated", "impostor", "card_of", "import_glb", "run",
]


def slope_mat(name, tex_flat: dict, tex_steep: dict, thresh: float = 0.6, soft: float = 0.12,
              scale_flat: float = 0.3, scale_steep: float = 0.3, noise_scale: float = 0.15, noise_amt: float = 0.15,
              tint_flat=None, tint_steep=None, rough_flat=None, rough_steep=None, emit=None):
    """One Principled material that blends two tiled texture sets by surface slope (flat = up-facing), with a
    noise-broken edge. Uses the 'tile' UV layer like src_mat, so bake_down() can bake it into the atlas."""
    m = A.src_mat(name, tex_steep, scale=scale_steep, tint=tint_steep, rough=rough_steep, emit=emit)
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    uv = next(n for n in nt.nodes if n.type == "UVMAP")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (scale_flat,) * 3
    nt.links.new(uv.outputs["UV"], mp.inputs["Vector"])

    def tex(path, nc):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = A.load_image(path, nc)
        nt.links.new(mp.outputs["Vector"], t.inputs["Vector"])
        return t

    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs["Vector"])
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = noise_scale
    nt.links.new(geo.outputs["Position"], nz.inputs["Vector"])
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "MULTIPLY_ADD"
    add.inputs[1].default_value = noise_amt * 2
    add.inputs[2].default_value = -noise_amt
    nt.links.new(nz.outputs["Fac"], add.inputs[0])
    s2 = nt.nodes.new("ShaderNodeMath")
    s2.operation = "ADD"
    nt.links.new(sep.outputs["Z"], s2.inputs[0])
    nt.links.new(add.outputs[0], s2.inputs[1])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.interpolation_type = "SMOOTHSTEP"
    mr.inputs["From Min"].default_value = thresh - soft
    mr.inputs["From Max"].default_value = thresh + soft
    nt.links.new(s2.outputs[0], mr.inputs["Value"])
    fac = mr.outputs["Result"]
    # colour
    ta = tex(tex_flat["albedo"], False)
    col_flat = ta.outputs["Color"]
    if tint_flat is not None:
        mx = nt.nodes.new("ShaderNodeMixRGB")
        mx.blend_type = "MULTIPLY"
        mx.inputs["Fac"].default_value = 1.0
        mx.inputs["Color2"].default_value = (*tint_flat, 1)
        nt.links.new(col_flat, mx.inputs["Color1"])
        col_flat = mx.outputs["Color"]
    steep_col = b.inputs["Base Color"].links[0].from_socket
    mix = nt.nodes.new("ShaderNodeMixRGB")
    nt.links.new(fac, mix.inputs["Fac"])
    nt.links.new(steep_col, mix.inputs["Color1"])
    nt.links.new(col_flat, mix.inputs["Color2"])
    nt.links.new(mix.outputs["Color"], b.inputs["Base Color"])
    # roughness
    if rough_flat is not None:
        rf_val = nt.nodes.new("ShaderNodeValue")
        rf_val.outputs[0].default_value = rough_flat
        rf = rf_val.outputs[0]
    else:
        tr = tex(tex_flat["arm"], True)
        sp = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(tr.outputs["Color"], sp.inputs["Color"])
        rf = sp.outputs["Green"]
    if b.inputs["Roughness"].is_linked:
        rs = b.inputs["Roughness"].links[0].from_socket
    else:
        v = nt.nodes.new("ShaderNodeValue")
        v.outputs[0].default_value = b.inputs["Roughness"].default_value
        rs = v.outputs[0]
    mxr = nt.nodes.new("ShaderNodeMix")
    mxr.data_type = "FLOAT"
    nt.links.new(fac, mxr.inputs["Factor"])
    nt.links.new(rs, mxr.inputs[2])
    nt.links.new(rf, mxr.inputs[3])
    nt.links.new(mxr.outputs[0], b.inputs["Roughness"])
    # normal
    if tex_flat.get("normal") and b.inputs["Normal"].is_linked:
        nm_steep = b.inputs["Normal"].links[0].from_node  # NormalMap node
        tn = tex(tex_flat["normal"], True)
        mxn = nt.nodes.new("ShaderNodeMixRGB")
        nt.links.new(fac, mxn.inputs["Fac"])
        nt.links.new(nm_steep.inputs["Color"].links[0].from_socket, mxn.inputs["Color1"])
        nt.links.new(tn.outputs["Color"], mxn.inputs["Color2"])
        nt.links.new(mxn.outputs["Color"], nm_steep.inputs["Color"])
    return m


def facet_block(name, size, seed: int, cuts: int = 9, z0: float = 0.0):
    """Convex fractured block: a box cut by random planes (flat facets like broken ice or basalt)."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2] + size[2] / 2 + z0))
    ctr = Vector((0, 0, size[2] / 2 + z0))
    for _ in range(cuts):
        n = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.6, 1.0))).normalized()
        ext = abs(n.x) * size[0] / 2 + abs(n.y) * size[1] / 2 + abs(n.z) * size[2] / 2
        co = ctr + n * ext * rnd.uniform(0.55, 0.85)
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=n, clear_outer=True)
        edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        if edges:
            bmesh.ops.edgeloop_fill(bm, edges=edges)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = A.link(bpy.data.objects.new(name, me))
    return o


__all__ += ["slope_mat", "facet_block"]


def gray_tex(src: dict, name: str, sat: float = 0.0, gain: float = 1.0) -> dict:
    """Desaturated copy of a texture set's albedo (written to the build folder) for painted surfaces that are
    re-coloured with a tint (white, orange, container liveries)."""
    img = A.load_image(src["albedo"])
    a = A.px(img).copy()
    bpy.data.images.remove(img)
    g = a[..., :3].mean(-1, keepdims=True)
    a[..., :3] = np.clip((g + (a[..., :3] - g) * sat) * gain, 0, 1)
    p = A.BUILD / f"gray_{name}.png"
    A.write_png(a, p)
    out = dict(src)
    out["albedo"] = p
    return out


__all__ += ["gray_tex"]
