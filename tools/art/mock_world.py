"""Race-frame mock for a world, rendered from the exported GLBs and the real textures, with the game camera
(4.8 m behind, 2.8 m up, -14 deg, 70 deg vertical FOV, 1080x1920). EEVEE, no screen-space reflections or
ray tracing (the phone has neither); fog is a depth mix like Godot's depth fog.

blender -b --factory-startup -P tools/art/mock_world.py -- <world 1|2> <out_raw.png> [scale]
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).parent))
import rr_art as A  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :]
WORLD = int(argv[0])
OUT = argv[1]
SCALE = float(argv[2]) if len(argv) > 2 else 1.0
rnd = random.Random(42 + WORLD)

CFG = {
    1: dict(
        hdri="alps_field_4k.hdr",
        hdri_rot=60,
        strength=1.0,
        sun_k=1.0,
        trail=("rocky_trail_02", "2k", 3.2),
        edge=("forest_leaves_04", "1k", 3.0),
        ground=("forest_ground_04", "1k", 4.0),
        ground2=("sparse_grass", "1k", 3.0),
        wall=("rocky_trail", "1k", 4.0),
        grade=0.10,
        fog=(0.62, 0.70, 0.78),
        fog_start=30,
        fog_depth=420,
        fog_max=0.42,
    ),
    2: dict(
        hdri="goegap_4k.hdr",
        hdri_rot=60,
        strength=1.0,
        sun_k=1.0,
        trail=("red_laterite_soil_stones", "2k", 3.2),
        edge=("red_sand", "1k", 3.0),
        ground=("red_sand", "1k", 4.0),
        ground2=("red_laterite_soil_stones", "2k", 5.0),
        wall=("cliff_side", "1k", 9.0),
        grade=0.08,
        fog=(0.82, 0.70, 0.58),
        fog_start=50,
        fog_depth=600,
        fog_max=0.30,
    ),
}[WORLD]

S_PLAYER = 196.0


# ---------------------------------------------------------------- track frame
def heading(s):
    if WORLD == 1:
        return 0.42 * math.sin((s - 150) / 48.0)
    return 0.22 * math.sin((s - 150) / 60.0) + 0.1


def build_centerline(s0=-40, s1=520, ds=1.0):
    pts = []
    p = Vector((0, 0, 0))
    s = s0
    # integrate from s=0 both ways so s=0 is the origin
    fw, bw = [], []
    q = Vector((0, 0, 0))
    for i in range(int(s1 / ds) + 1):
        si = i * ds
        h = heading(si)
        fw.append((si, q.copy(), h))
        q = q + Vector((math.sin(h), math.cos(h), 0)) * ds
        q.z = -CFG["grade"] * (si + ds) + 0.6 * math.sin((si + ds) / 23.0)
    q = Vector((0, 0, 0))
    for i in range(1, int(-s0 / ds) + 1):
        si = -i * ds
        h = heading(si)
        q = q - Vector((math.sin(h), math.cos(h), 0)) * ds
        q.z = -CFG["grade"] * si + 0.6 * math.sin(si / 23.0)
        bw.append((si, q.copy(), h))
    return list(reversed(bw)) + fw


CL = build_centerline()
S_ARR = np.array([c[0] for c in CL])


def frame(s):
    i = int(np.clip(np.searchsorted(S_ARR, s), 1, len(CL) - 1))
    s0, p0, h0 = CL[i - 1]
    s1, p1, h1 = CL[i]
    t = (s - s0) / (s1 - s0)
    p = p0.lerp(p1, t)
    h = h0 + (h1 - h0) * t
    fwd = (p1 - p0).normalized()
    right = Vector((math.cos(h), -math.sin(h), 0))
    return p, fwd, right, h


def lateral_h(x, s):
    ax = abs(x)
    if WORLD == 1:
        if ax <= 5.0:
            h = 0.04 * (1 - (x / 5) ** 2) - 0.035 * math.exp(-(((ax - 1.3) / 0.28) ** 2))
        elif ax <= 7.0:
            k = (ax - 5) / 2
            h = 0.45 * k * k * (3 - 2 * k)
        else:
            h = (
                0.45
                + 0.05 * (ax - 7)
                + 2.2 * (0.5 + 0.5 * math.sin(s / 37 + x / 19)) * min(1, (ax - 7) / 40)
            )
        return h
    # world 2: dry wash floor, sandstone walls rise from |x| 16
    if ax <= 5.0:
        h = 0.03 * (1 - (x / 5) ** 2)
    elif ax <= 16:
        h = 0.05 * (ax - 5) + 0.25 * math.sin(s / 13 + x)
    else:
        e = ax - 16
        r = (
            min(52.0, 2.4 * e)
            + 3.0 * math.sin(s / 17 + ax / 5)
            + 1.5 * math.sin(s / 6.3 + ax / 2.1)
            + min(1.0, e / 12) * (6.0 * math.sin(s / 9.0 + x) + 4.0 * math.sin(s / 3.7 + ax))
        )
        r = max(0.0, r)
        step = 4.5  # sandstone strata: steep faces with narrow ledges
        k = r / step
        fr = k - math.floor(k)
        h = 0.55 + step * (math.floor(k) + min(1.0, fr / 0.75)) * min(1.0, e / 3)
    return h


def world_at(s, x, h=None):
    p, fwd, right, _ = frame(s)
    return p + right * x + Vector((0, 0, lateral_h(x, s) if h is None else h))


# ---------------------------------------------------------------- terrain mesh with blend weights
def terrain():
    xs = sorted(
        set(
            [
                round(v, 3)
                for v in list(np.linspace(-7, 7, 29))
                + list(np.linspace(7.5, 30, 24))
                + list(np.linspace(-30, -7.5, 24))
                + list(np.linspace(32, 160, 30))
                + list(np.linspace(-160, -32, 30))
                + (
                    list(np.arange(16, 48, 0.75)) + list(np.arange(-48, -16, 0.75))
                    if WORLD == 2
                    else []
                )
            ]
        )
    )
    ss = list(np.arange(-30, 160, 1.0)) + list(np.arange(160, 520, 3.0))
    verts, faces, cols = [], [], []
    for s in ss:
        for x in xs:
            verts.append(tuple(world_at(s, x)))
            ax = abs(x)
            n1 = 0.5 + 0.5 * math.sin(s * 0.37 + x * 1.7) * math.sin(s * 0.11 - x * 0.6)
            trail = np.clip((5.3 + 0.6 * n1 - ax) / 0.9, 0, 1)
            rut = max(
                math.exp(-(((ax - 1.4 - 0.3 * math.sin(s / 17)) / 0.35) ** 2)),
                0.7 * math.exp(-(((ax - 3.3 + 0.4 * math.sin(s / 11)) / 0.5) ** 2)),
            ) * (ax < 5)
            if WORLD == 1:
                wall = 0.0
                grass = np.clip(
                    (math.sin(s / 9 + x / 5) * math.sin(x / 7 - s / 13) + 0.35) * 2, 0, 1
                ) * (ax > 6.2)
            else:
                wall = np.clip((ax - 17.5) / 4, 0, 1)
                grass = np.clip((math.sin(s / 9 + x / 5) + 0.3), 0, 1) * (ax > 6) * (1 - wall)
            cols.append((trail, wall, grass, rut))
    nx = len(xs)
    for j in range(len(ss) - 1):
        for i in range(nx - 1):
            a = j * nx + i
            faces.append((a, a + 1, a + nx + 1, a + nx))
    me = bpy.data.meshes.new("terrain")
    me.from_pydata(verts, [], faces)
    ca = me.color_attributes.new("blend", "FLOAT_COLOR", "POINT")
    for i, c in enumerate(cols):
        ca.data[i].color = c
    # world UVs: u = lateral metres, v = s metres
    uvl = me.uv_layers.new(name="UVMap")
    uvs = []
    for s in ss:
        for x in xs:
            uvs.append((x, s))
    for p in me.polygons:
        p.use_smooth = True
        for li in p.loop_indices:
            uvl.data[li].uv = uvs[me.loops[li].vertex_index]
    o = A.link(bpy.data.objects.new("terrain", me))
    o.data.materials.append(terrain_material())
    return o


def tex_set(nt, uvnode, name, res, tile, seed_rot=0.0, triplanar=False):
    """triplanar=True: Godot uv1_triplanar (box projection on world position) for steep rock faces."""
    t = A.ph_tex(name, res)
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1 / tile, 1 / tile, 1 / tile if triplanar else 1)
    mp.inputs["Rotation"].default_value = (0, 0, seed_rot)
    if triplanar:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    else:
        nt.links.new(uvnode.outputs["UV"], mp.inputs["Vector"])
    out = {}
    for key, nc in (("albedo", False), ("normal", True), ("arm", True)):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = A.load_image(t[key], nc)
        if triplanar:
            n.projection = "BOX"
            n.projection_blend = 0.25
        nt.links.new(mp.outputs["Vector"], n.inputs["Vector"])
        out[key] = n.outputs["Color"]
    sp = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(out["arm"], sp.inputs["Color"])
    out["rough"] = sp.outputs["Green"]
    out["ao"] = sp.outputs["Red"]
    return out


def mixc(nt, fac, a, b):
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    nt.links.new(fac, m.inputs["Factor"])
    nt.links.new(a, m.inputs[6])
    nt.links.new(b, m.inputs[7])
    return m.outputs[2]


def mixf(nt, fac, a, b):
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = "FLOAT"
    nt.links.new(fac, m.inputs["Factor"])
    nt.links.new(a, m.inputs[2])
    nt.links.new(b, m.inputs[3])
    return m.outputs[0]


def terrain_material():
    """Godot equivalent: one spatial shader, 3-4 PBR layers blended by vertex colour (R trail, G rock/cliff,
    B grass) with a height-aware edge, plus a low-frequency tint noise against tiling."""
    m = bpy.data.materials.new("terrain")
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    uv = nt.nodes.new("ShaderNodeUVMap")
    va = nt.nodes.new("ShaderNodeVertexColor")
    va.layer_name = "blend"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(va.outputs["Color"], sep.inputs["Color"])
    T = tex_set(nt, uv, *CFG["trail"])
    G = tex_set(nt, uv, *CFG["ground"], seed_rot=0.6)
    G2 = tex_set(nt, uv, *CFG["ground2"], seed_rot=1.3)
    Wl = tex_set(nt, uv, *CFG["wall"], seed_rot=0.0, triplanar=True)
    # height-blend the trail edge: trail shows where its own displacement (approximated by albedo luma) wins
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 0.04
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeMapRange")
    ramp.inputs["To Min"].default_value = 0.82
    ramp.inputs["To Max"].default_value = 1.12
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Value"])
    gcol = mixc(nt, sep.outputs["Blue"], G["albedo"], G2["albedo"])
    gr = mixf(nt, sep.outputs["Blue"], G["rough"], G2["rough"])
    gn = mixc(nt, sep.outputs["Blue"], G["normal"], G2["normal"])
    c1 = mixc(nt, sep.outputs["Red"], gcol, T["albedo"])
    r1 = mixf(nt, sep.outputs["Red"], gr, T["rough"])
    n1 = mixc(nt, sep.outputs["Red"], gn, T["normal"])
    c2 = mixc(nt, sep.outputs["Green"], c1, Wl["albedo"])
    r2 = mixf(nt, sep.outputs["Green"], r1, Wl["rough"])
    n2 = mixc(nt, sep.outputs["Green"], n1, Wl["normal"])
    rutm = nt.nodes.new("ShaderNodeMapRange")  # packed riding lines are darker and smoother
    rutm.inputs["To Min"].default_value = 1.0
    rutm.inputs["To Max"].default_value = 0.62
    nt.links.new(va.outputs["Alpha"], rutm.inputs["Value"])
    rmul = nt.nodes.new("ShaderNodeMath")
    rmul.operation = "MULTIPLY"
    nt.links.new(ramp.outputs["Result"], rmul.inputs[0])
    nt.links.new(rutm.outputs["Result"], rmul.inputs[1])
    ramp = rmul
    tint = nt.nodes.new("ShaderNodeMixRGB")
    tint.blend_type = "MULTIPLY"
    tint.inputs["Fac"].default_value = 1.0
    nt.links.new(c2, tint.inputs["Color1"])
    nt.links.new(ramp.outputs[0], tint.inputs["Color2"])
    nt.links.new(tint.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(r2, b.inputs["Roughness"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nm.inputs["Strength"].default_value = 1.0
    nt.links.new(n2, nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    return m


# ---------------------------------------------------------------- GLB placement
_CACHE: dict[str, list] = {}
LIB = None


def lib_coll():
    global LIB
    if LIB is None:
        LIB = bpy.data.collections.new("lib")
        bpy.context.scene.collection.children.link(LIB)
        LIB.hide_render = True
        LIB.hide_viewport = True
    return LIB


def imp(name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(A.MODELS / f"{name}.glb"))
    return [o for o in bpy.data.objects if o not in before]


def proto(name):
    if name not in _CACHE:
        objs = imp(name)
        for o in objs:
            for c in o.users_collection:
                c.objects.unlink(o)
            lib_coll().objects.link(o)
        _CACHE[name] = [o for o in objs if o.type == "MESH"]
    return _CACHE[name]


def tint_proto(name, rgb):
    """Multiply a prototype's albedo (Godot: StandardMaterial3D.albedo_color)."""
    for o in proto(name):
        for slot in o.material_slots:
            nt = slot.material.node_tree
            b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
            if not b.inputs["Base Color"].is_linked:
                continue
            src = b.inputs["Base Color"].links[0].from_socket
            mx = nt.nodes.new("ShaderNodeMixRGB")
            mx.blend_type = "MULTIPLY"
            mx.inputs["Fac"].default_value = 1.0
            mx.inputs["Color2"].default_value = (*rgb, 1)
            nt.links.new(src, mx.inputs["Color1"])
            nt.links.new(mx.outputs["Color"], b.inputs["Base Color"])


def place(name, s, x, yaw=0.0, scale=1.0, zoff=0.0, tilt_to_ground=False, h=None):
    p, fwd, right, hd = frame(s)
    pos = world_at(s, x, h) + Vector((0, 0, zoff))
    out = []
    for src in proto(name):
        o = src.copy()
        bpy.context.scene.collection.objects.link(o)
        o.matrix_world = (
            Matrix.Translation(pos) @ Matrix.Rotation(-hd + yaw, 4, "Z") @ Matrix.Scale(scale, 4)
        )
        out.append(o)
    return out


def rider(livery, s, x, action="bike", lean=0.0, frame_no=0):
    objs = imp("rider") + imp("bike")
    p, fwd, right, hd = frame(s)
    pos = world_at(s, x)
    pitch = math.atan2(fwd.z, math.hypot(fwd.x, fwd.y))
    M = (
        Matrix.Translation(pos)
        @ Matrix.Rotation(-hd, 4, "Z")
        @ Matrix.Rotation(pitch, 4, "X")
        @ Matrix.Rotation(lean, 4, "Y")
    )
    for o in objs:
        if o.parent is None:
            o.matrix_world = M @ o.matrix_world
        if o.type == "ARMATURE":
            o.animation_data_create()
            act = (
                bpy.data.actions.get(action)
                if "rider" in o.name or any(c.name.startswith("rider") for c in o.children)
                else bpy.data.actions.get("ride")
            )
            if o.animation_data.nla_tracks:
                for t in o.animation_data.nla_tracks:
                    t.mute = True
        if o.type == "MESH":
            for slot in o.material_slots:
                for n in slot.material.node_tree.nodes:
                    if n.type == "TEX_IMAGE" and n.image and "_r1_albedo" in n.image.name:
                        kind = "rider" if "rider" in n.image.name else "bike"
                        n.image = A.load_image(A.TEX / kind / f"{kind}_{livery}_albedo.png")
    # set poses: rider armature gets `action`, bike armature 'ride'
    for o in objs:
        if o.type == "ARMATURE":
            names = [c.name for c in o.children]
            is_rider = any("rider" in n for n in names) or "rider" in o.name
            o.animation_data.action = bpy.data.actions.get(action if is_rider else "ride")
    return objs


def dust(s, x, n=4, size=1.1, col=(0.72, 0.64, 0.55), alpha=0.16):
    img = A.load_image(A.TEX / "fx" / "dust_puff.png")
    m = bpy.data.materials.get("dust")
    if m is None:
        m = bpy.data.materials.new("dust")
        m.use_nodes = True
        nt = m.node_tree
        b = next(nn for nn in nt.nodes if nn.type == "BSDF_PRINCIPLED")
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = img
        b.inputs["Base Color"].default_value = (*col, 1)
        b.inputs["Roughness"].default_value = 1.0
        mth = nt.nodes.new("ShaderNodeMath")
        mth.operation = "MULTIPLY"
        mth.inputs[1].default_value = alpha
        nt.links.new(t.outputs["Alpha"], mth.inputs[0])
        nt.links.new(mth.outputs[0], b.inputs["Alpha"])
        m.surface_render_method = "BLENDED"
    cam = bpy.context.scene.camera
    for i in range(n):
        ss = s - 0.8 - i * 0.7
        xx = x + rnd.uniform(-0.3, 0.3)
        pos = world_at(ss, xx) + Vector((0, 0, 0.22 + i * 0.10))
        bpy.ops.mesh.primitive_plane_add(size=size * (1 + i * 0.35), location=pos)
        q = bpy.context.active_object
        q.data.materials.append(m)
        d = (cam.location - pos).normalized()
        q.rotation_euler = d.to_track_quat("Z", "Y").to_euler()


# ---------------------------------------------------------------- scene
def setup_world():
    sc = bpy.context.scene
    w = bpy.data.worlds.new("sky")
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    env = nt.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(str(A.PH / "hdri" / CFG["hdri"]))
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Rotation"].default_value = (0, 0, math.radians(CFG["hdri_rot"]))
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nt.links.new(tc.outputs["Generated"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], env.inputs["Vector"])
    bg = nt.nodes["Background"]
    bg.inputs["Strength"].default_value = CFG["strength"]
    nt.links.new(env.outputs["Color"], bg.inputs["Color"])
    try:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        sc.render.engine = "BLENDER_EEVEE"
    ee = sc.eevee
    ee.taa_render_samples = 64
    for attr, val in (
        ("use_raytracing", False),
        ("use_shadows", True),
        ("shadow_ray_count", 2),
        ("shadow_step_count", 8),
        ("use_gtao", False),
        ("use_bloom", True),
        ("use_volumetric_shadows", False),
    ):
        if hasattr(ee, attr):
            setattr(ee, attr, val)
    # sun extracted from the HDRI: real direction, real colour, shadows (Godot: DirectionalLight3D matched to the HDRI)
    for attr, val in (
        ("sun_threshold", 10.0),
        ("sun_angle", math.radians(1.2)),
        ("use_sun_shadow", True),
        ("sun_shadow_maximum_resolution", 0.002),
    ):
        if hasattr(w, attr):
            setattr(w, attr, val)
    sc.view_settings.view_transform = "AgX"
    try:
        sc.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    sc.view_settings.exposure = 0.0
    w.mist_settings.start = CFG["fog_start"]
    w.mist_settings.depth = CFG["fog_depth"]
    w.mist_settings.falloff = "LINEAR"


def compositor_fog():
    """Depth fog on geometry only (Godot: fog_sky_affect low): fogged scene over the HDRI sky."""
    sc = bpy.context.scene
    sc.render.film_transparent = True
    vl = sc.view_layers[0]
    vl.use_pass_mist = True
    vl.use_pass_environment = True
    sc.use_nodes = True
    nt = sc.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    rl = nt.nodes.new("CompositorNodeRLayers")
    mul = nt.nodes.new("CompositorNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = CFG["fog_max"]
    nt.links.new(rl.outputs["Mist"], mul.inputs[0])
    mix = nt.nodes.new("CompositorNodeMixRGB")
    mix.inputs[2].default_value = (*CFG["fog"], 1)
    nt.links.new(mul.outputs[0], mix.inputs[0])
    nt.links.new(rl.outputs["Image"], mix.inputs[1])
    sa = nt.nodes.new("CompositorNodeSetAlpha")
    nt.links.new(mix.outputs[0], sa.inputs["Image"])
    nt.links.new(rl.outputs["Alpha"], sa.inputs["Alpha"])
    env = nt.nodes.new("CompositorNodeMixRGB")  # sky with a light horizon haze
    env.inputs[0].default_value = 0.12
    env.inputs[2].default_value = (*CFG["fog"], 1)
    nt.links.new(rl.outputs["Env"], env.inputs[1])
    ao = nt.nodes.new("CompositorNodeAlphaOver")
    nt.links.new(env.outputs[0], ao.inputs[1])
    nt.links.new(sa.outputs[0], ao.inputs[2])
    comp = nt.nodes.new("CompositorNodeComposite")
    nt.links.new(ao.outputs[0], comp.inputs["Image"])


def camera():
    sc = bpy.context.scene
    p, fwd, right, hd = frame(S_PLAYER)
    base = world_at(S_PLAYER, 0.3)
    flat = Vector((fwd.x, fwd.y, 0)).normalized()
    loc = base - flat * 4.8 + Vector((0, 0, 2.8))
    cam = bpy.data.cameras.new("game_cam")
    cam.sensor_fit = "VERTICAL"
    cam.angle_y = math.radians(70)
    cam.clip_start = 0.3
    cam.clip_end = 900
    co = A.link(bpy.data.objects.new("game_cam", cam))
    co.location = loc
    look = Matrix.Rotation(math.radians(-14), 3, flat.cross(Vector((0, 0, 1))).normalized()) @ flat
    co.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    sc.camera = co
    sc.render.resolution_x = int(1080 * SCALE)
    sc.render.resolution_y = int(1920 * SCALE)
    return co


def scatter_world1():
    # forest: Poly Haven pines as impostor cards, denser further out
    kinds = ["tree_pine_a", "tree_pine_b", "tree_pine_c"]
    s = -30.0
    while s < 520:
        for side in (-1, 1):
            for _ in range(2):
                x = side * rnd.uniform(8.5, 16)
                place(
                    rnd.choice(kinds),
                    s + rnd.uniform(-2, 2),
                    x,
                    yaw=rnd.uniform(0, 6.28),
                    scale=rnd.uniform(0.75, 1.15),
                    zoff=-0.1,
                )
            for _ in range(5):
                x = side * rnd.uniform(16, 150)
                place(
                    rnd.choice(kinds),
                    s + rnd.uniform(-4, 4),
                    x,
                    yaw=rnd.uniform(0, 6.28),
                    scale=rnd.uniform(0.7, 1.2),
                    zoff=-0.2,
                )
        s += rnd.uniform(4.0, 7.0)
    # rocks, ferns, grass cards along the trail
    s = -20.0
    while s < 420:
        side = rnd.choice((-1, 1))
        if rnd.random() < 0.35:
            place(
                rnd.choice(["rock_a", "rock_b", "rock_c"]),
                s,
                side * rnd.uniform(7.2, 12),
                yaw=rnd.uniform(0, 6.28),
                scale=rnd.uniform(0.35, 0.8),
                zoff=-0.25,
            )
        if rnd.random() < 0.8:
            place(
                "fern",
                s + 1,
                side * rnd.uniform(6.2, 11),
                yaw=rnd.uniform(0, 6.28),
                scale=rnd.uniform(1.0, 1.6),
                zoff=-0.03,
            )
        for _ in range(6):
            sd = rnd.choice((-1, 1))
            place(
                "grass_card",
                s + rnd.uniform(-2, 2),
                sd * rnd.uniform(5.6, 14),
                yaw=rnd.uniform(0, 6.28),
                scale=rnd.uniform(1.1, 1.9),
                zoff=-0.04,
            )
        s += rnd.uniform(2.0, 3.5)
    # course tape on stakes, both edges, every 4 m
    s = -20.0
    while s < 330:
        for side in (-1, 1):
            place("tape_stake", s, side * 5.7, yaw=0.0)
        s += 4.0
    # kit from the GDD section table (pine slope): P2 pad, H1 hay, gate G1
    place("boost_pad", 210, -3.0)
    place("hay_bale", 260, 2.5, yaw=0.15)
    place("swap_gate", 300, 0.0)
    place("mud_puddle", 236, 3.0, yaw=0.1, scale=0.9)
    place("fence_rail", 290, -7.0, yaw=0.0)
    place("fence_rail", 294, -7.0, yaw=0.0)


def scatter_world2():
    for k in ("rock_a", "rock_b", "rock_c"):
        tint_proto(k, (1.25, 0.62, 0.42))
    s = -20.0
    while s < 480:  # fallen sandstone blocks at the foot of both walls break the smooth wall line
        for side in (-1, 1):
            if rnd.random() < 0.7:
                place(
                    rnd.choice(["rock_a", "rock_b", "rock_c"]),
                    s,
                    side * rnd.uniform(15.5, 19),
                    yaw=rnd.uniform(0, 6.28),
                    scale=rnd.uniform(1.5, 3.5),
                    zoff=-0.4,
                )
        s += rnd.uniform(5, 11)
    s = -20.0
    while s < 520:
        for _ in range(2):
            side = rnd.choice((-1, 1))
            if rnd.random() < 0.55:
                place(
                    "bush_desert",
                    s + rnd.uniform(-2, 2),
                    side * rnd.uniform(6.5, 17),
                    yaw=rnd.uniform(0, 6.28),
                    scale=rnd.uniform(0.6, 1.2),
                    zoff=-0.05,
                )
        if rnd.random() < 0.12:
            side = rnd.choice((-1, 1))
            place(
                rnd.choice(["rock_a", "rock_b", "rock_c"]),
                s,
                side * rnd.uniform(8, 15),
                yaw=rnd.uniform(0, 6.28),
                scale=rnd.uniform(0.4, 1.0),
                zoff=-0.2,
            )
        s += rnd.uniform(3, 6)
    place("boost_pad", 205, 0.0)
    place("sand_drift", 232, -1.2, yaw=0.0)
    place("tumbleweed", 214, 3.9, yaw=0.4, scale=1.0)
    place("ramp_rock", 262, 0.0, scale=1.0)
    place("water_tower", 330, 13.5, yaw=0.5)
    place("dead_trunk", 222, -8.5, yaw=1.2, zoff=-0.1)


def main():
    A.reset()
    setup_world()
    cam = camera()
    terrain()
    if WORLD == 1:
        scatter_world1()
        riders = [("r3", 206.0, 2.4, 0.06), ("r2", 213.5, -1.7, -0.08), ("r4", 224.0, 0.8, 0.03)]
        dcol = (0.62, 0.55, 0.47)
    else:
        scatter_world2()
        riders = [("r5", 207.0, -2.3, -0.06), ("r6", 213.0, 2.0, 0.08), ("r3", 225.0, -0.4, 0.0)]
        dcol = (0.80, 0.58, 0.44)
    rider("r1", S_PLAYER, 0.3, lean=-0.04)
    for lv, s, x, lean in riders:
        rider(lv, s, x, lean=lean)
        dust(s, x, col=dcol)
    compositor_fog()
    sc = bpy.context.scene
    sc.render.filepath = OUT
    sc.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(A.BUILD / f"mock_w{WORLD}.blend"))
    # report rough on-screen budget numbers from the scene (my calc)
    n_obj = sum(1 for o in sc.objects if o.type == "MESH" and not o.hide_render)
    print("MOCK objects", n_obj)


main()
