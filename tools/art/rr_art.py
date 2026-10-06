"""Shared helpers for the MWM Race Riders realistic art scripts (Blender 4.5, run with `blender -b`).

Conventions (same as the old kit so RrWorld/RrRiderView keep their axes):
- Blender metres, Z up, models face +Y. glTF export with +Y up turns Blender +Y forward into Godot -Z.
- Origin on the ground under the model centre.
- Every GLB has ONE material per mesh: albedo + normal (OpenGL) + ORM (R = AO, G = roughness, B = metal).
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "assets" / "_raw"
PH = RAW / "polyhaven"
MODELS = ROOT / "assets" / "models"
TEX = ROOT / "assets" / "textures"
FONTS = ROOT / "assets" / "fonts"
BUILD = RAW / "build"  # intermediate bakes (not in git)
for p in (MODELS, TEX, BUILD):
    p.mkdir(parents=True, exist_ok=True)

# The six racers. Colour is never the only cue: number + helmet design differ too.
# hex: jersey base; accent: panels, gloves, helmet second colour; design: helmet paint scheme.
RIDERS = [
    {
        "id": "r1",
        "num": 7,
        "hex": "#C8202B",
        "accent": "#16181C",
        "trim": "#FFFFFF",
        "design": "stripe",
    },
    {
        "id": "r2",
        "num": 12,
        "hex": "#F2A900",
        "accent": "#16181C",
        "trim": "#FFFFFF",
        "design": "split",
    },
    {
        "id": "r3",
        "num": 23,
        "hex": "#1E5BD6",
        "accent": "#FFFFFF",
        "trim": "#0B1F4A",
        "design": "slash",
    },
    {
        "id": "r4",
        "num": 31,
        "hex": "#0F8F6E",
        "accent": "#E9ECEF",
        "trim": "#0A3B2E",
        "design": "checker",
    },
    {
        "id": "r5",
        "num": 4,
        "hex": "#E9ECEF",
        "accent": "#C8202B",
        "trim": "#16181C",
        "design": "twin",
    },
    {
        "id": "r6",
        "num": 88,
        "hex": "#2A2E35",
        "accent": "#FF6A13",
        "trim": "#FFFFFF",
        "design": "fade",
    },
]


def hex_rgb(h: str) -> tuple[float, float, float]:
    """sRGB hex -> linear RGB floats (Blender colour sockets are linear)."""
    h = h.lstrip("#")
    out = []
    for i in range(3):
        c = int(h[i * 2 : i * 2 + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def rgba(h: str, a: float = 1.0) -> tuple[float, float, float, float]:
    return (*hex_rgb(h), a)


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def link(o: bpy.types.Object) -> bpy.types.Object:
    bpy.context.scene.collection.objects.link(o)
    return o


def mesh_obj(name: str, verts, faces, uvs=None) -> bpy.types.Object:
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    me.update()
    if uvs is not None:
        uvl = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            for li in poly.loop_indices:
                uvl.data[li].uv = uvs[me.loops[li].vertex_index]
    return link(bpy.data.objects.new(name, me))


def activate(o: bpy.types.Object, only: bool = True) -> None:
    if only:
        for x in bpy.context.view_layer.objects:
            if x is not None:
                x.select_set(False)
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def apply_all(o: bpy.types.Object) -> None:
    activate(o)
    for m in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def apply_xform(o: bpy.types.Object) -> None:
    activate(o)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def tris(o: bpy.types.Object) -> int:
    dg = bpy.context.evaluated_depsgraph_get()
    e = o.evaluated_get(dg)
    m = e.to_mesh()
    n = sum(len(p.vertices) - 2 for p in m.polygons)
    e.to_mesh_clear()
    return n


def load_image(path: Path, non_color: bool = False) -> bpy.types.Image:
    img = bpy.data.images.load(str(path), check_existing=True)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def pbr_material(
    name: str,
    albedo: Path | bpy.types.Image | None = None,
    normal: Path | None = None,
    orm: Path | None = None,
    rough: float = 0.7,
    metal: float = 0.0,
    color=None,
    uv_scale: float = 1.0,
    alpha_clip: bool = False,
) -> bpy.types.Material:
    """Principled material from albedo / normal(GL) / ORM maps, like Godot StandardMaterial3D."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if color is not None:
        bsdf.inputs["Base Color"].default_value = color
    uvn = None
    if uv_scale != 1.0:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (uv_scale, uv_scale, uv_scale)
        nt.links.new(tc.outputs["UV"], mp.inputs["Vector"])
        uvn = mp.outputs["Vector"]

    def tex(img, nc):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = img if isinstance(img, bpy.types.Image) else load_image(img, nc)
        if uvn is not None:
            nt.links.new(uvn, t.inputs["Vector"])
        return t

    if albedo is not None:
        t = tex(albedo, False)
        nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
        if alpha_clip:
            nt.links.new(t.outputs["Alpha"], bsdf.inputs["Alpha"])
            m.blend_method = "CLIP" if hasattr(m, "blend_method") else m.blend_method
    if normal is not None:
        t = tex(normal, True)
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(t.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if orm is not None:
        t = tex(orm, True)
        sp = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(t.outputs["Color"], sp.inputs["Color"])
        nt.links.new(sp.outputs["Green"], bsdf.inputs["Roughness"])
        nt.links.new(sp.outputs["Blue"], bsdf.inputs["Metallic"])
    return m


def ph_tex(name: str, res: str = "1k") -> dict[str, Path]:
    d = PH / "textures" / name
    return {
        "albedo": d / f"{name}_diffuse_{res}.jpg",
        "normal": d / f"{name}_nor_gl_{res}.jpg",
        "arm": d / f"{name}_arm_{res}.jpg",
        "rough": d / f"{name}_rough_{res}.jpg",
        "disp": d / f"{name}_displacement_{res}.jpg",
    }


def export_glb(objs, name: str, anim: bool = False, skins: bool = False) -> Path:
    for x in bpy.context.view_layer.objects:
        x.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    out = MODELS / f"{name}.glb"
    kw = dict(
        filepath=str(out),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=not skins,
        export_animations=anim,
        export_image_format="AUTO",
        export_materials="EXPORT",
        export_tangents=False,
    )
    if anim:
        kw.update(
            export_animation_mode="ACTIONS",
            export_skins=True,
            export_def_bones=True,
            export_force_sampling=True,
            export_frame_range=False,
        )
    bpy.ops.export_scene.gltf(**kw)
    return out


def size_godot(objs) -> list[float]:
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for o in objs:
        if o.type != "MESH":
            continue
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    d = hi - lo
    return [round(d.x, 2), round(d.z, 2), round(d.y, 2)]


def cycles(samples: int = 64, gpu: bool = True) -> None:
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = samples
    if gpu:
        try:
            prefs = bpy.context.preferences.addons["cycles"].preferences
            prefs.compute_device_type = "OPTIX"
            prefs.get_devices()
            for d in prefs.devices:
                d.use = d.type == "OPTIX"
            sc.cycles.device = "GPU"
        except Exception as e:  # noqa: BLE001
            print("GPU setup failed, CPU:", e)


def new_image(
    name: str, size: int, alpha: bool = False, non_color: bool = False, float_buf: bool = False
):
    img = bpy.data.images.new(name, size, size, alpha=alpha, float_buffer=float_buf)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def bake(
    obj: bpy.types.Object, img: bpy.types.Image, kind: str, margin: int = 8, samples: int = 16, **kw
) -> None:
    """Bake `kind` (EMIT, NORMAL, AO, ROUGHNESS, DIFFUSE) of obj into img (active image node in every material)."""
    sc = bpy.context.scene
    sc.cycles.samples = samples
    for slot in obj.material_slots:
        m = slot.material
        nt = m.node_tree
        n = nt.nodes.get("__bake__") or nt.nodes.new("ShaderNodeTexImage")
        n.name = "__bake__"
        n.image = img
        nt.nodes.active = n
    activate(obj)
    sc.render.bake.margin = margin
    sc.render.bake.use_clear = True
    if kind == "DIFFUSE":
        sc.render.bake.use_pass_direct = False
        sc.render.bake.use_pass_indirect = False
        sc.render.bake.use_pass_color = True
    bpy.ops.object.bake(type=kind, **kw)


def save_png(img: bpy.types.Image, path: Path) -> Path:
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    return path


def px(img: bpy.types.Image) -> np.ndarray:
    a = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(img.size[1], img.size[0], 4)


def set_px(img: bpy.types.Image, arr: np.ndarray) -> None:
    img.pixels.foreach_set(arr.astype(np.float32).ravel())
    img.update()


def deg(*a):
    return tuple(math.radians(x) for x in a)


# Bike contact points (bike space: origin on the ground at the wheelbase centre, front +Y). The rider poses
# are solved against these, so the rider's hands and feet land on the real grips and pedals.
BIKE = {
    "wheel_r": 0.372,  # 29 x 2.5 in tyre outer radius (m)
    "axle_front": (0.0, 0.64, 0.372),
    "axle_rear": (0.0, -0.64, 0.372),
    "bb": (0.0, -0.20, 0.355),
    "crank": 0.165,
    "pedal_x": 0.135,
    "grip": (0.33, 0.31, 1.065),  # right grip centre; left = -x
    "saddle": (0.0, -0.36, 0.80),
    "head_top": (0.0, 0.25, 0.985),
}
BOARD_DECK_Z = 0.30


# ---------------------------------------------------------------- generic atlas baking
def emit_mat(name, socket_fn):
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


def rgb_node(nt, c):
    n = nt.nodes.new("ShaderNodeRGB")
    n.outputs[0].default_value = (*c, 1.0)
    return n.outputs[0]


def bake_maps(
    o,
    names: list[str],
    res: int,
    ao_dist: float = 0.15,
    ao_samples: int = 64,
    bump_fn=None,
    normal_out: Path | None = None,
) -> dict:
    """Bake rest-pose position, object normal, material id (index into `names`) and AO for an atlas-UV mesh.
    Material slot names must be in `names`. If bump_fn(name)->Material is given, a tangent normal map is baked."""
    cycles(8)
    sc = bpy.context.scene
    sc.world = sc.world or bpy.data.worlds.new("w")
    sc.world.light_settings.distance = ao_dist
    orig = [s.material for s in o.material_slots]

    def swap(ms):
        for i, s in enumerate(o.material_slots):
            s.material = ms[i]

    out = {}
    for key, sock in (("pos", "Position"), ("nrm", "Normal")):
        mt = emit_mat(
            "__" + key, lambda nt, sock=sock: nt.nodes.new("ShaderNodeNewGeometry").outputs[sock]
        )
        swap([mt] * len(orig))
        img = new_image("__" + key, res, alpha=True, non_color=True, float_buf=True)
        bake(o, img, "EMIT", samples=1, margin=6)
        out[key] = px(img).copy()
    mids = []
    for i, m in enumerate(orig):
        v = (names.index(m.name) + 1) / 32.0
        mids.append(emit_mat(f"__mid{i}", lambda nt, v=v: rgb_node(nt, (v, v, v))))
    swap(mids)
    img = new_image("__mid", res, alpha=True, non_color=True, float_buf=True)
    bake(o, img, "EMIT", samples=1, margin=6)
    out["mid"] = np.rint(px(img)[..., 0] * 32.0).astype(int) - 1
    if bump_fn is not None and normal_out is not None:
        swap([bump_fn(m.name) for m in orig])
        nimg = new_image(normal_out.stem, res, non_color=True)
        bake(o, nimg, "NORMAL", samples=4, margin=8)
        save_png(nimg, normal_out)
        bpy.data.images.remove(nimg)
    swap(orig)
    for m in orig:
        m.use_nodes = True
    aimg = new_image("__ao", res, non_color=True)
    bake(o, aimg, "AO", samples=ao_samples, margin=8)
    out["ao"] = px(aimg)[..., 0].copy()
    out["valid"] = out["pos"][..., 3] > 0.5
    return out


def srgb(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def sample(mask: np.ndarray, u, v):
    h, w = mask.shape[:2]
    ok = (u >= 0) & (u < 1) & (v >= 0) & (v < 1)
    iu = np.clip((u * w).astype(int), 0, w - 1)
    iv = np.clip((v * h).astype(int), 0, h - 1)
    s = mask[iv, iu].copy()
    s[~ok] = 0
    return s


def num_mask(n: int) -> np.ndarray:
    img = load_image(BUILD / f"num_{n}.png", non_color=True)
    a = px(img)[..., :3].copy()
    bpy.data.images.remove(img)
    return a


def write_png(arr: np.ndarray, path: Path, alpha: np.ndarray | None = None) -> Path:
    """Write values as-is (already sRGB for colour maps, linear for data maps). Rows bottom-up (Blender order)."""
    h, w = arr.shape[:2]
    img = bpy.data.images.new(path.stem + "__w", w, h, alpha=alpha is not None)
    img.colorspace_settings.name = "Non-Color"
    rgba = np.ones((h, w, 4), np.float32)
    rgba[..., :3] = np.clip(arr[..., :3], 0, 1)
    if alpha is not None:
        rgba[..., 3] = np.clip(alpha, 0, 1)
    set_px(img, rgba)
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return path


def fill_invalid(col: np.ndarray, valid: np.ndarray) -> np.ndarray:
    if valid.any():
        col[~valid] = col[valid].mean(0)
    return col


def orm_from(
    maps: dict, names: list[str], rough: dict, metal: dict, ao_k: float = 0.85
) -> np.ndarray:
    M = maps["mid"]
    r = np.full(M.shape, 0.7, np.float32)
    m = np.zeros(M.shape, np.float32)
    for i, nm in enumerate(names):
        r[i == M] = rough.get(nm, 0.7)
        m[i == M] = metal.get(nm, 0.0)
    ao = np.clip(maps["ao"] * ao_k + (1 - ao_k), 0, 1)
    return np.stack([ao, r, m], -1)


def atlas_unwrap(o, margin: float = 0.004) -> None:
    activate(o)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.context.scene.tool_settings.use_uv_select_sync = True
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(55), island_margin=margin)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(rotate=True, margin=margin)
    bpy.ops.object.mode_set(mode="OBJECT")


def tube(name, pts, r, sides=10, mat=None, cap=True, r_end=None):
    """Polyline tube through pts (list of xyz) with radius r (or tapering to r_end)."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    verts, faces = [], []
    prev_x = None
    for i, p in enumerate(pts):
        if i == 0:
            t = (pts[1] - pts[0]).normalized()
        elif i == n - 1:
            t = (pts[-1] - pts[-2]).normalized()
        else:
            t = (
                (pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()
            ).normalized()
        if prev_x is None:
            up = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            x = t.cross(up).normalized()
        else:
            x = (prev_x - t * prev_x.dot(t)).normalized()
        y = t.cross(x)
        prev_x = x
        rr = r if r_end is None else r + (r_end - r) * i / (n - 1)
        for k in range(sides):
            a = 2 * math.pi * k / sides
            verts.append(tuple(p + (x * math.cos(a) + y * math.sin(a)) * rr))
    for i in range(n - 1):
        for k in range(sides):
            a = i * sides + k
            b = i * sides + (k + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    if cap:
        faces.append(tuple(range(sides))[::-1])
        faces.append(tuple(range((n - 1) * sides, n * sides)))
    ob = mesh_obj(name, verts, faces)
    for p in ob.data.polygons:
        p.use_smooth = len(p.vertices) == 4
    if mat:
        ob.data.materials.append(mat)
    return ob


def get_mat(name: str) -> bpy.types.Material:
    return bpy.data.materials.get(name) or bpy.data.materials.new(name)


def join(objs, name: str):
    activate(objs[0])
    for o in objs[1:]:
        o.select_set(True)
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    return o


def rigid_group(o, group: str) -> None:
    vg = o.vertex_groups.new(name=group)
    vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")


# ---------------------------------------------------------------- bake-down of tiled multi-material props
def src_mat(
    name: str,
    tex: dict | None = None,
    scale: float = 1.0,
    tint=None,
    rough: float | None = None,
    metal: float = 0.0,
    emit=None,
    emit_tex: Path | None = None,
    color=None,
    rot: float = 0.0,
    normal_strength: float = 1.0,
    decal: Path | None = None,
    decal_color=None,
) -> bpy.types.Material:
    """Source material on UV layer 'tile' (world-scale UVs). Baked into one atlas by bake_down()."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m["metal"] = metal
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = "tile"
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (scale, scale, scale)
    mp.inputs["Rotation"].default_value = (0, 0, math.radians(rot))
    nt.links.new(uv.outputs["UV"], mp.inputs["Vector"])
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = 0.7 if rough is None else rough
    col_out = None
    if color is not None:
        b.inputs["Base Color"].default_value = color if len(color) == 4 else (*color, 1)
    if tex:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = load_image(tex["albedo"])
        nt.links.new(mp.outputs["Vector"], t.inputs["Vector"])
        col_out = t.outputs["Color"]
        if tint is not None:
            mx = nt.nodes.new("ShaderNodeMixRGB")
            mx.blend_type = "MULTIPLY"
            mx.inputs["Fac"].default_value = 1.0
            mx.inputs["Color2"].default_value = (*tint, 1)
            nt.links.new(col_out, mx.inputs["Color1"])
            col_out = mx.outputs["Color"]
        if tex.get("normal") and Path(tex["normal"]).exists():
            tn = nt.nodes.new("ShaderNodeTexImage")
            tn.image = load_image(tex["normal"], True)
            nt.links.new(mp.outputs["Vector"], tn.inputs["Vector"])
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nm.inputs["Strength"].default_value = normal_strength
            nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
        if rough is None and tex.get("arm") and Path(tex["arm"]).exists():
            ta = nt.nodes.new("ShaderNodeTexImage")
            ta.image = load_image(tex["arm"], True)
            nt.links.new(mp.outputs["Vector"], ta.inputs["Vector"])
            sp = nt.nodes.new("ShaderNodeSeparateColor")
            nt.links.new(ta.outputs["Color"], sp.inputs["Color"])
            nt.links.new(sp.outputs["Green"], b.inputs["Roughness"])
    if decal is not None:  # RGBA image on the 'tile' UVs without the mapping (0..1 = the decal)
        td = nt.nodes.new("ShaderNodeTexImage")
        td.image = load_image(decal)
        td.extension = "CLIP"
        nt.links.new(uv.outputs["UV"], td.inputs["Vector"])
        mx = nt.nodes.new("ShaderNodeMixRGB")
        nt.links.new(td.outputs["Alpha"], mx.inputs["Fac"])
        if col_out is not None:
            nt.links.new(col_out, mx.inputs["Color1"])
        else:
            mx.inputs["Color1"].default_value = b.inputs["Base Color"].default_value
        mx.inputs["Color2"].default_value = (*(decal_color or (1, 1, 1)), 1)
        col_out = mx.outputs["Color"]
        if emit is not None:
            mm = nt.nodes.new("ShaderNodeMixRGB")
            mm.inputs["Color1"].default_value = (0, 0, 0, 1)
            mm.inputs["Color2"].default_value = (*emit, 1)
            nt.links.new(td.outputs["Alpha"], mm.inputs["Fac"])
            nt.links.new(mm.outputs["Color"], b.inputs["Emission Color"])
            b.inputs["Emission Strength"].default_value = 1.0
            emit = None
    if col_out is not None:
        nt.links.new(col_out, b.inputs["Base Color"])
    if emit is not None:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = 1.0
    m["emit"] = 1 if (emit is not None or decal is not None) else 0
    return m


def tile_uv(o, size: float = 1.0) -> None:
    """World-scale box UVs on layer 'tile' (1 UV unit = `size` metres)."""
    me = o.data
    if "tile" not in me.uv_layers:
        me.uv_layers.new(name="tile")
    uvl = me.uv_layers["tile"]
    for p in me.polygons:
        if me.materials and me.materials[p.material_index].get("keep_uv"):
            continue
        n = p.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in p.loop_indices:
            c = o.matrix_world @ me.vertices[me.loops[li].vertex_index].co
            if ax == 0:
                u, v = c.y, c.z
            elif ax == 1:
                u, v = c.x, c.z
            else:
                u, v = c.x, c.y
            uvl.data[li].uv = (u / size, v / size)


def bake_down(
    o,
    res: int,
    out_dir: Path,
    stem: str,
    ao_dist: float = 0.3,
    ao_k: float = 0.8,
    margin: float = 0.004,
    want_emission: bool = False,
    vertex_alpha: bool = False,
) -> dict:
    """Bake a multi-material tiled prop into one atlas material (albedo, normal, ORM [+ emission])."""
    out_dir.mkdir(parents=True, exist_ok=True)
    me = o.data
    if "atlas" not in me.uv_layers:
        me.uv_layers.new(name="atlas")
    me.uv_layers.active = me.uv_layers["atlas"]
    for u in me.uv_layers:
        u.active_render = u.name == "atlas"
    activate(o)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.context.scene.tool_settings.use_uv_select_sync = True
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(55), island_margin=margin)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(rotate=True, margin=margin)
    bpy.ops.object.mode_set(mode="OBJECT")
    cycles(8)
    sc = bpy.context.scene
    sc.world = sc.world or bpy.data.worlds.new("w")
    sc.world.light_settings.distance = ao_dist
    paths = {}
    alb = new_image(stem + "_albedo", res)
    saved = []
    for m in me.materials:  # metals have no diffuse colour: bake base colour with metallic = 0
        b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        saved.append((b, b.inputs["Metallic"].default_value))
        b.inputs["Metallic"].default_value = 0.0
    bake(o, alb, "DIFFUSE", samples=4)
    for b, v in saved:
        b.inputs["Metallic"].default_value = v
    paths["albedo"] = out_dir / f"{stem}_albedo.png"
    a = px(alb)
    write_png(a, paths["albedo"])
    nrm = new_image(stem + "_normal", res, non_color=True)
    bake(o, nrm, "NORMAL", samples=4)
    paths["normal"] = out_dir / f"{stem}_normal.png"
    write_png(px(nrm), paths["normal"])
    rgh = new_image(stem + "_rough", res, non_color=True)
    bake(o, rgh, "ROUGHNESS", samples=2)
    r = px(rgh)[..., 0].copy()
    orig = [s.material for s in o.material_slots]
    mets = [
        emit_mat(f"__met{i}", lambda nt, v=float(m.get("metal", 0.0)): rgb_node(nt, (v, v, v)))
        for i, m in enumerate(orig)
    ]
    for i, s in enumerate(o.material_slots):
        s.material = mets[i]
    met = new_image("__met", res, non_color=True)
    bake(o, met, "EMIT", samples=1)
    mt = px(met)[..., 0].copy()
    for i, s in enumerate(o.material_slots):
        s.material = orig[i]
    ao = new_image("__ao", res, non_color=True)
    bake(o, ao, "AO", samples=48)
    aov = np.clip(px(ao)[..., 0] * ao_k + (1 - ao_k), 0, 1)
    paths["orm"] = out_dir / f"{stem}_orm.png"
    write_png(np.stack([aov, r, mt], -1), paths["orm"])
    if want_emission:
        em = new_image("__em", res)
        bake(o, em, "EMIT", samples=2)
        paths["emission"] = out_dir / f"{stem}_emission.png"
        write_png(px(em), paths["emission"])
    for img in (alb, nrm, rgh, met, ao):
        bpy.data.images.remove(img)
    # final material on the atlas UVs only
    me.uv_layers.remove(me.uv_layers["tile"])
    me.uv_layers["atlas"].name = "UVMap"
    fm = pbr_material(stem, albedo=paths["albedo"], normal=paths["normal"], orm=paths["orm"])
    if want_emission:
        nt = fm.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = load_image(paths["emission"])
        nt.links.new(t.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 2.0
    if vertex_alpha:
        nt = fm.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        ca = nt.nodes.new("ShaderNodeVertexColor")
        ca.layer_name = "Col"
        nt.links.new(ca.outputs["Alpha"], bsdf.inputs["Alpha"])
        fm.surface_render_method = "BLENDED"
    me.materials.clear()
    me.materials.append(fm)
    for p in me.polygons:
        p.material_index = 0
    return paths
