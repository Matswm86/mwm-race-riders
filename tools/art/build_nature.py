"""Nature kit from Poly Haven CC0 scans, cut down for phones.

- Trees: the 4-7 million triangle Poly Haven pines are rendered from 4 sides into an impostor atlas
  (albedo + alpha, tangent normal) and rebuilt as a 4-plane "star" card tree (8 triangles). Far trees use the
  same GLB; Godot visibility_range fades them.
- Rocks: Poly Haven rocks decimated to 300-700 triangles, original 1K textures (diffuse, normal, roughness).
- Grass: Poly Haven grass clumps rendered to a card texture, 3 crossed quads.
- World 2: desert bush impostor (Poly Haven wild rooibos) and the dead trunk decimated.

blender -b --factory-startup -P tools/art/build_nature.py -- [names...]
"""

from __future__ import annotations

import math
import shutil
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).parent))
import rr_art as A  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
W1 = A.TEX / "world1"
W2 = A.TEX / "world2"
W1.mkdir(parents=True, exist_ok=True)
W2.mkdir(parents=True, exist_ok=True)
REPORT = {}


def import_ph(model: str, keep: list[str] | None = None):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(A.PH / "models" / model / f"{model}_1k.gltf"))
    new = [o for o in bpy.data.objects if o not in before]
    out = []
    for o in new:
        if o.type != "MESH" or (keep and o.name not in keep):
            bpy.data.objects.remove(o)
        else:
            out.append(o)
    bpy.context.view_layer.update()
    return out


def render_views(objs, n_views: int, cell: tuple[int, int], out_stem: str, outdir: Path):
    """Ortho renders of objs from n_views azimuths. Returns (albedo_rgba atlas, tangent normal atlas, w, h)."""
    sc = bpy.context.scene
    bpy.context.view_layer.update()
    A.cycles(32)
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    vl = sc.view_layers[0]
    vl.use_pass_diffuse_color = True
    vl.use_pass_normal = True
    w = sc.world or bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (1, 1, 1, 1)
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for o in objs:
        for c in o.bound_box:
            p = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
    ctr = (lo + hi) / 2
    width = max(hi.x - lo.x, hi.y - lo.y) * 1.02
    height = (hi.z - lo.z) * 1.02
    cw, ch = cell
    sc.render.resolution_x = cw
    sc.render.resolution_y = ch
    cam = bpy.data.cameras.new("ic")
    cam.type = "ORTHO"
    cam.ortho_scale = max(width, height * cw / ch) if width / height > cw / ch else height * 1.0
    cam.ortho_scale = max(width, height)  # Blender ortho scale spans the larger render side
    co = A.link(bpy.data.objects.new("ic", cam))
    sc.camera = co
    # compositor -> EXR files
    sc.use_nodes = True
    nt = sc.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    rl = nt.nodes.new("CompositorNodeRLayers")
    sa = nt.nodes.new("CompositorNodeSetAlpha")
    nt.links.new(rl.outputs["DiffCol"], sa.inputs["Image"])
    nt.links.new(rl.outputs["Alpha"], sa.inputs["Alpha"])
    fo = nt.nodes.new("CompositorNodeOutputFile")
    fo.format.file_format = "OPEN_EXR"
    fo.format.color_mode = "RGBA"
    fo.base_path = str(A.BUILD / "imp")
    fo.file_slots.clear()
    fo.file_slots.new("alb")
    fo.file_slots.new("nrm")
    nt.links.new(sa.outputs["Image"], fo.inputs["alb"])
    nt.links.new(rl.outputs["Normal"], fo.inputs["nrm"])
    alb_cells, nrm_cells = [], []
    for k in range(n_views):
        az = math.pi * k / n_views  # planes 0..180 deg, each seen from its front side
        d = Vector(
            (-math.sin(az), math.cos(az), 0)
        )  # camera sits on the card-normal side, looks along d
        co.location = ctr - d * 60
        co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        sc.frame_set(k + 1)
        bpy.ops.render.render(write_still=False)
        fa = A.BUILD / "imp" / f"alb{k + 1:04d}.exr"
        fn = A.BUILD / "imp" / f"nrm{k + 1:04d}.exr"
        ia = bpy.data.images.load(str(fa))
        inn = bpy.data.images.load(str(fn))
        a = A.px(ia).copy()
        nrm = A.px(inn)[..., :3].copy()
        bpy.data.images.remove(ia)
        bpy.data.images.remove(inn)
        # world normal -> card tangent space (T = camera right, B = up, N = towards camera)
        T = Vector((math.cos(az), math.sin(az), 0))
        Bv = Vector((0, 0, 1))
        Nv = -d
        tn = np.stack([nrm @ np.array(T), nrm @ np.array(Bv), nrm @ np.array(Nv)], -1)
        tn = tn / np.maximum(np.linalg.norm(tn, axis=-1, keepdims=True), 1e-6)
        alb_cells.append(a)
        nrm_cells.append(tn * 0.5 + 0.5)
    # atlas: cells side by side
    alb = np.concatenate(alb_cells, axis=1)
    nrm = np.concatenate(nrm_cells, axis=1)
    alpha = np.clip(alb[..., 3] * 2.2, 0, 1)
    # dilate colour into transparent texels so mips do not bleed white/black edges
    col = alb[..., :3].copy()
    mask = alpha > 0.5
    for _ in range(12):
        m2 = mask.copy()
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sh = np.roll(mask, (dy, dx), (0, 1))
            shc = np.roll(col, (dy, dx), (0, 1))
            fill = sh & ~m2
            col[fill] = shc[fill]
            nr = np.roll(nrm, (dy, dx), (0, 1))
            nrm[fill] = nr[fill]
            m2 |= fill
        mask = m2
    col = np.clip(
        col * 1.25, 0, 1
    )  # scans are dark under flat light; lift to a sunlit foliage albedo
    lin = np.where(
        col <= 0.0031308, col * 12.92, 1.055 * np.power(np.clip(col, 0, 1), 1 / 2.4) - 0.055
    )
    pa = A.write_png(lin, outdir / f"{out_stem}_albedo.png", alpha=alpha)
    pn = A.write_png(nrm, outdir / f"{out_stem}_normal.png")
    sc.use_nodes = False
    return pa, pn, ctr, width, height


def star_mesh(name: str, n: int, ctr, width: float, height: float, base_z: float = 0.0):
    """n vertical planes through the trunk axis; plane k uses atlas cell k."""
    verts, faces, uvs = [], [], []
    for k in range(n):
        az = math.pi * k / n
        T = Vector((math.cos(az), math.sin(az), 0))
        for u, v in ((0, 0), (1, 0), (1, 1), (0, 1)):
            p = Vector((0, 0, base_z)) + T * (u - 0.5) * width + Vector((0, 0, v * height))
            verts.append(tuple(p))
            uvs.append(((k + u) / n, v))
        b = k * 4
        faces.append((b, b + 1, b + 2, b + 3))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    uvl = me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        for li in p.loop_indices:
            uvl.data[li].uv = uvs[me.loops[li].vertex_index]
    o = A.link(bpy.data.objects.new(name, me))
    return o


def card_material(name, alb, nrm, rough=0.85):
    m = A.pbr_material(name, albedo=alb, normal=nrm, rough=rough, alpha_clip=True)
    # alpha scissor at 0.5 (glTF MASK, Godot alpha_scissor): texture alpha -> Round -> BSDF alpha
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = next(n for n in nt.nodes if n.type == "TEX_IMAGE" and n.outputs["Alpha"].is_linked)
    rd = nt.nodes.new("ShaderNodeMath")
    rd.operation = "ROUND"
    nt.links.new(tex.outputs["Alpha"], rd.inputs[0])
    nt.links.new(rd.outputs[0], bsdf.inputs["Alpha"])
    m.use_backface_culling = False
    m.surface_render_method = "DITHERED"
    try:
        m.alpha_threshold = 0.5
    except AttributeError:
        pass
    return m


def impostor(
    model: str, keep: list[str], name: str, outdir: Path, n=4, cell=(512, 1024), scale=1.0
):
    A.reset()
    objs = import_ph(model, keep)
    for o in objs:
        o.scale = (scale,) * 3
        o.location = (0, 0, 0)
    bpy.context.view_layer.update()
    pa, pn, ctr, width, height = render_views(objs, n, cell, name, outdir)
    for o in objs:
        bpy.data.objects.remove(o)
    # plane aspect follows the render cell (ortho scale = the larger of width/height)
    side = max(width, height)
    pw = side * cell[0] / max(cell)
    ph = side * cell[1] / max(cell)
    st = star_mesh(name, n, ctr, pw, ph, base_z=ctr.z - ph / 2)
    st.data.materials.append(card_material(name, pa, pn))
    out = A.export_glb([st], name)
    REPORT[name] = (A.size_godot([st]), A.tris(st), out.stat().st_size)
    print("NAT", name, REPORT[name])


def tree_pine_a():
    impostor("pine_tree_01", ["pine_tree_01_a_LOD0"], "tree_pine_a", W1)


def tree_pine_b():
    impostor("pine_tree_01", ["pine_tree_01_b_LOD0"], "tree_pine_b", W1)


def tree_pine_c():
    impostor("pine_tree_01", ["pine_tree_01_c_LOD0"], "tree_pine_c", W1)


def bush_desert():
    impostor(
        "wild_rooibos_bush",
        ["wild_rooibos_bush_a"],
        "bush_desert",
        W2,
        n=3,
        cell=(512, 512),
        scale=1.6,
    )


def grass_card():
    """Row of Poly Haven grass clumps rendered to one card; 3 crossed quads 1.2 x 0.45 m."""
    A.reset()
    objs = import_ph("grass_medium_01")
    xs = -0.55
    for o in sorted(objs, key=lambda o: o.name):
        if "tiny" in o.name:
            bpy.data.objects.remove(o)
            continue
        o.location = (xs, 0, 0)
        xs += 0.11
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    pa, pn, ctr, width, height = render_views(objs, 1, (1024, 512), "grass_card", W1)
    for o in objs:
        bpy.data.objects.remove(o)
    side = max(width, height)
    verts, faces, uvs = [], [], []
    for k in range(3):
        az = math.pi * k / 3
        T = Vector((math.cos(az), math.sin(az), 0))
        for u, v in ((0, 0), (1, 0), (1, 1), (0, 1)):
            verts.append(
                tuple(T * (u - 0.5) * side + Vector((0, 0, ctr.z - side * 0.25 + v * side * 0.5)))
            )
            uvs.append((u, v))
        faces.append((k * 4, k * 4 + 1, k * 4 + 2, k * 4 + 3))
    me = bpy.data.meshes.new("grass_card")
    me.from_pydata(verts, [], faces)
    uvl = me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        for li in p.loop_indices:
            uvl.data[li].uv = uvs[me.loops[li].vertex_index]
    o = A.link(bpy.data.objects.new("grass_card", me))
    for v in o.data.vertices:
        v.co.z -= min(v.co.z for v in o.data.vertices) if False else 0
    zmin = min(v.co.z for v in o.data.vertices)
    for v in o.data.vertices:
        v.co.z -= zmin
    o.data.materials.append(card_material("grass_card", pa, pn, 0.9))
    out = A.export_glb([o], "grass_card")
    REPORT["grass_card"] = (A.size_godot([o]), A.tris(o), out.stat().st_size)
    print("NAT grass_card", REPORT["grass_card"])


def decimated(
    model: str,
    keep: list[str],
    name: str,
    target: int,
    outdir: Path,
    scale=1.0,
    tex_prefix=None,
    tex_name=None,
):
    A.reset()
    objs = import_ph(model, keep)
    o = objs[0]
    if len(objs) > 1:
        o = A.join(objs, name)
    o.name = name
    o.scale = (scale,) * 3
    o.location = (0, 0, 0)
    A.apply_xform(o)
    zmin = min(v.co.z for v in o.data.vertices)
    for v in o.data.vertices:
        v.co.z -= zmin - 0.0
    for _ in range(3):
        n = A.tris(o)
        if n <= target * 1.1:
            break
        d = o.modifiers.new("d", "DECIMATE")
        d.ratio = target / n
        A.apply_all(o)
        if A.tris(o) > n * 0.9:  # collapse blocked by UV seams: merge by distance first
            activate_merge = True
            A.activate(o)
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.mesh.remove_doubles(threshold=0.002)
            bpy.ops.object.mode_set(mode="OBJECT")
    for p in o.data.polygons:
        p.use_smooth = True
    # textures: copy the 1K Poly Haven maps; roughness/ARM -> ORM
    tdir = A.PH / "models" / model / "textures"
    pre = tex_prefix or model
    diff = next(tdir.glob(f"{pre}_diff_1k.jpg"))
    nor = next(tdir.glob(f"{pre}_nor_gl_1k.jpg"))
    tn = tex_name or name
    dd = outdir / f"{tn}_albedo.jpg"
    nn = outdir / f"{tn}_normal.jpg"
    shutil.copy(diff, dd)
    shutil.copy(nor, nn)
    arm = list(tdir.glob(f"{pre}_arm_1k.jpg"))
    rough = list(tdir.glob(f"{pre}_rough_1k.jpg"))
    orm = outdir / f"{tn}_orm.png"
    if arm:
        img = A.load_image(arm[0], True)
        a = A.px(img)[..., :3].copy()
        bpy.data.images.remove(img)
        A.write_png(a, orm)
    else:
        img = A.load_image(rough[0], True)
        r = A.px(img)[..., 0].copy()
        bpy.data.images.remove(img)
        A.write_png(np.stack([np.ones_like(r), r, np.zeros_like(r)], -1), orm)
    o.data.materials.clear()
    o.data.materials.append(A.pbr_material(tn, albedo=dd, normal=nn, orm=orm))
    out = A.export_glb([o], name)
    REPORT[name] = (A.size_godot([o]), A.tris(o), out.stat().st_size)
    print("NAT", name, REPORT[name])


def rocks():
    for i, (rk, t) in enumerate(
        (
            ("rock_moss_set_01_rock01", 600),
            ("rock_moss_set_01_rock04", 600),
            ("rock_moss_set_01_rock03", 400),
        )
    ):
        decimated("rock_moss_set_01", [rk], f"rock_{'abc'[i]}", t, W1, tex_name="rock_moss")


def fern():
    decimated("fern_02", ["fern_02_b"], "fern", 900, W1)


def dead_trunk():
    decimated("dead_tree_trunk_02", ["dead_tree_trunk_02"], "dead_trunk", 1200, W2)


ALL = {
    f.__name__: f
    for f in (
        tree_pine_a,
        tree_pine_b,
        tree_pine_c,
        grass_card,
        rocks,
        fern,
        bush_desert,
        dead_trunk,
    )
}

if __name__ == "__main__":
    for n in argv or list(ALL):
        ALL[n]()
    for k, v in REPORT.items():
        print("SIZE", k, v)
