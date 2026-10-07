"""Race-frame mocks for worlds 3-6, rendered from the exported GLBs and terrain sets with the game camera
(4.8 m behind, 2.8 m up, -14 deg, 70 deg vertical FOV, 1080x1920). EEVEE without ray tracing or screen-space
reflections (the phone has neither); depth fog like Godot's; particles are camera-facing sprite cards.

blender -b --factory-startup -P tools/art/mock_w36.py -- <world 3..6> <out_raw.png> [scale]
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector, noise

sys.path.insert(0, str(Path(__file__).parent))
import rr_art as A  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :]
WORLD = int(argv[0])
OUT = argv[1]
SCALE = float(argv[2]) if len(argv) > 2 else 1.0
rnd = random.Random(42 + WORLD)
S_PLAYER = 196.0


def T(w, name, tile, rot=0.0):
    return (A.TEX / f"world{w}" / f"terrain_{name}", tile, rot)


CFG = {
    3: dict(hdri="horn-koppe_snow_4k.hdr", hdri_rot=60, strength=1.0, exposure=-0.6, grade=0.10,
            sun_lamp=(28.0, 35.0, 4.0, (1.0, 0.965, 0.925)),
            trail=T(3, "snow_groomed", 3.0, 1.5708), ground=T(3, "snow", 4.0), ground2=T(3, "snow_wind", 9.0),
            wall=T(3, "glacier_rock", 8.0), fog=(0.80, 0.86, 0.94), fog_start=40, fog_depth=700, fog_max=0.35,
            look="AgX - Medium High Contrast"),
    4: dict(hdri=str(A.TEX / "world4/sky_belfast_sunset_puresky_2k.hdr"), hdri_rot=60, strength=1.0, exposure=0.15, grade=0.09,
            trail=T(4, "ash_trail", 3.2), ground=T(4, "ash", 4.0), ground2=T(4, "ash_soft", 5.0),
            wall=T(4, "basalt", 7.0), fog=(0.50, 0.37, 0.27), fog_start=25, fog_depth=520, fog_max=0.42,
            look="AgX - Medium High Contrast"),
    5: dict(hdri="rainforest_trail_4k.hdr", hdri_rot=60, strength=1.0, exposure=0.1, grade=0.03,
            trail=T(5, "mud_wet", 3.0), ground=T(5, "forest_moss", 4.0), ground2=T(5, "mud_leaves", 3.5),
            wall=T(5, "mossy_rock", 6.0), fog=(0.62, 0.68, 0.62), fog_start=18, fog_depth=260, fog_max=0.5,
            look="AgX - Medium High Contrast"),
    6: dict(hdri="qwantani_moonrise_puresky_4k.hdr", hdri_rot=60, strength=0.035, exposure=0.9, grade=0.0,
            trail=T(6, "asphalt_wet", 4.0), ground=T(6, "quay_concrete", 5.0), ground2=T(6, "steel_plate", 3.0),
            wall=T(6, "quay_wall", 4.0), fog=(0.10, 0.11, 0.14), fog_start=30, fog_depth=600, fog_max=0.45,
            look="AgX - Medium High Contrast"),
}[WORLD]


# ---------------------------------------------------------------- track frame
def heading(s):
    if WORLD == 3:
        return 0.18 * math.sin((s - 120) / 70.0)
    if WORLD == 4:
        return 0.25 * math.sin((s - 160) / 55.0) + 0.05
    if WORLD == 5:
        return 0.30 * math.sin((s - 150) / 50.0)
    return 0.08 * math.sin((s - 150) / 90.0)


def build_centerline(s0=-40, s1=1000, ds=1.0):
    fw, bw = [], []
    q = Vector((0, 0, 0))
    for i in range(int(s1 / ds) + 1):
        si = i * ds
        h = heading(si)
        fw.append((si, q.copy(), h))
        q = q + Vector((math.sin(h), math.cos(h), 0)) * ds
        q.z = -CFG["grade"] * (si + ds) + (0.6 * math.sin((si + ds) / 23.0) if WORLD != 6 else 0.0)
    q = Vector((0, 0, 0))
    for i in range(1, int(-s0 / ds) + 1):
        si = -i * ds
        h = heading(si)
        q = q - Vector((math.sin(h), math.cos(h), 0)) * ds
        q.z = -CFG["grade"] * si + (0.6 * math.sin(si / 23.0) if WORLD != 6 else 0.0)
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


def sstep(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def nz(x, y, sc=1.0):
    return noise.noise(Vector((x * sc, y * sc, 0.37)))


# ---------------------------------------------------------------- lateral profiles (metres above the centre line)
def lateral_h(x, s):
    ax = abs(x)
    if WORLD == 3:
        if ax <= 5:
            h = 0.03 * (1 - (x / 5) ** 2)
        elif ax <= 7:
            h = 0.45 * sstep(5, 7, ax)
        else:
            h = 0.45 + 0.05 * (ax - 7) + 1.6 * nz(x, s, 0.05) * min(1, (ax - 7) / 12)
            if ax > 28:  # valley walls; the sun side (left, behind the camera) stays under the 28 deg sun
                e = ax - 28
                h += (0.25 if x < 0 else 0.75) * e + 10 * nz(x, s, 0.02) * min(1, e / 20) + 4 * abs(nz(x, s, 0.08)) * min(1, e / 10)
        # icefall around the ice cave (s 300-324): glacier rises to the cave roof on both sides
        m = sstep(286, 298, s) * (1 - sstep(330, 345, s)) * sstep(9.5, 12.5, ax)
        h += 9.5 * m
        return h
    if WORLD == 4:
        if ax <= 5:
            h = 0.04 * (1 - (x / 5) ** 2)
        elif ax <= 7:
            h = 0.25 * sstep(5, 7, ax)
        else:
            h = 0.25 + 0.04 * (ax - 7) + 0.9 * nz(x, s, 0.07) * min(1, (ax - 7) / 8)
            if x < -9:  # lava basin on the left, behind the rail
                h = 0.25 - 0.55 * sstep(9, 11, ax) * (1 - sstep(28, 32, ax)) + (0.0 if ax < 30 else 0.6 * (ax - 30))
            if ax > 34:
                e = ax - 34
                h += (0.55 if x < 0 else 0.18) * e + 12 * nz(x, s, 0.015) * min(1, e / 25)
        return h
    if WORLD == 5:
        h = 0.0
        if ax <= 5:
            h = 0.03 * (1 - (x / 5) ** 2)
        elif ax <= 7.5:
            h = 0.6 * sstep(5, 7.5, ax)
        else:
            h = 0.6 + 1.6 * nz(x, s, 0.06) * min(1, (ax - 7.5) / 8) + 0.02 * (ax - 7.5)
        if s > 208:  # split: left = bridge route (x -3), right = ford route (x +9); keep both beds clear
            for c, wdt in ((-3.0, 2.6), (9.0, 5.5)):
                k = 1 - sstep(wdt, wdt + 2.0, abs(x - c))
                h = h * (1 - k * sstep(208, 222, s))
        # river crossing s 232-268: deep under the bridge, shallow ford on the right
        r = sstep(229, 235, s) * (1 - sstep(265, 271, s))
        depth = 3.4 + (0.35 - 3.4) * sstep(1.0, 4.0, x)
        h -= depth * r
        return h
    # WORLD 6: flat quay; harbour basin left of x -14, channel beyond s 292
    h = 0.0
    if x < -14.0:
        h = -2.6
    if s > 292.0:
        h = -2.6
    return h


def world_at(s, x, h=None):
    p, fwd, right, _ = frame(s)
    return p + right * x + Vector((0, 0, lateral_h(x, s) if h is None else h))


def blend_at(x, s):
    """Vertex colour: R trail, G rock/wall (triplanar), B second ground layer, A riding-line darkening."""
    ax = abs(x)
    n1 = 0.5 + 0.5 * math.sin(s * 0.37 + x * 1.7) * math.sin(s * 0.11 - x * 0.6)
    trail = min(1.0, max(0.0, (5.3 + 0.6 * n1 - ax) / 0.9))
    rut = max(math.exp(-(((ax - 1.4 - 0.3 * math.sin(s / 17)) / 0.35) ** 2)),
              0.7 * math.exp(-(((ax - 3.3 + 0.4 * math.sin(s / 11)) / 0.5) ** 2))) * (ax < 5)
    if WORLD == 5 and s > 208:
        k = sstep(208, 222, s)
        tl = min(1.0, max(0.0, (2.4 + 0.4 * n1 - abs(x + 3)) / 0.7))
        tr = min(1.0, max(0.0, (5.2 + 0.6 * n1 - abs(x - 9)) / 0.9))
        trail = trail * (1 - k) + max(tl, tr) * k
        rut = rut * (1 - k)
    wall = 0.0
    patch = 0.0
    if WORLD == 3:
        wall = sstep(34, 44, ax) * sstep(-0.1, 0.4, nz(x, s, 0.04))
        patch = sstep(0.0, 0.5, nz(x, s, 0.03)) * (ax > 6.5)
    elif WORLD == 4:
        wall = sstep(36, 42, ax)
        patch = (sstep(5.3, 6.3, ax) * (1 - sstep(9, 10, ax)) * 0.9) + sstep(0.1, 0.5, nz(x, s, 0.05)) * (ax > 10) * 0.6
        if x < -10 and ax < 30:
            patch = 0.0
            wall = 0.0
    elif WORLD == 5:
        patch = max(sstep(5.4, 6.6, ax) * (1 - sstep(9, 11, ax)), sstep(0.2, 0.6, nz(x, s, 0.08)) * (ax > 7))
    else:
        patch = 0.0
        wall = 1.0 if x < -13.9 else 0.0
        trail = min(1.0, max(0.0, (6.0 - ax) / 0.3)) if s < 292 else 0.0
        rut = rut * 0.6
    return (trail, wall, patch, rut)


# ---------------------------------------------------------------- terrain
def terrain():
    xs = sorted(set([round(v, 3) for v in list(np.linspace(-7.5, 7.5, 31)) + list(np.linspace(8, 30, 23)) +
                     list(np.linspace(-30, -8, 23)) + list(np.linspace(32, 200, 36)) + list(np.linspace(-200, -32, 36)) +
                     ([-14.05, -13.95] if WORLD == 6 else [])]))
    ss = list(np.arange(-30, 360, 1.0)) + list(np.arange(360, 900, 4.0))
    verts, faces, cols = [], [], []
    for s in ss:
        for x in xs:
            verts.append(tuple(world_at(s, x)))
            cols.append(blend_at(x, s))
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
    uvl = me.uv_layers.new(name="UVMap")
    uvs = [(x, s) for s in ss for x in xs]
    for p in me.polygons:
        p.use_smooth = True
        for li in p.loop_indices:
            uvl.data[li].uv = uvs[me.loops[li].vertex_index]
    o = A.link(bpy.data.objects.new("terrain", me))
    o.data.materials.append(terrain_material())
    return o


def tex_set(nt, uvnode, layer, triplanar=False):
    stem, tile, rot = layer
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1 / tile, 1 / tile, 1 / tile if triplanar else 1)
    mp.inputs["Rotation"].default_value = (0, 0, rot)
    if triplanar:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    else:
        nt.links.new(uvnode.outputs["UV"], mp.inputs["Vector"])
    out = {}
    for key, nc in (("albedo", False), ("normal", True), ("arm", True)):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = A.load_image(Path(f"{stem}_{key}.jpg"), nc)
        if triplanar:
            n.projection = "BOX"
            n.projection_blend = 0.25
        nt.links.new(mp.outputs["Vector"], n.inputs["Vector"])
        out[key] = n.outputs["Color"]
    sp = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(out["arm"], sp.inputs["Color"])
    out["rough"] = sp.outputs["Green"]
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
    m = bpy.data.materials.new("terrain")
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    uv = nt.nodes.new("ShaderNodeUVMap")
    va = nt.nodes.new("ShaderNodeVertexColor")
    va.layer_name = "blend"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(va.outputs["Color"], sep.inputs["Color"])
    Tl = tex_set(nt, uv, CFG["trail"])
    G = tex_set(nt, uv, CFG["ground"])
    G2 = tex_set(nt, uv, CFG["ground2"])
    Wl = tex_set(nt, uv, CFG["wall"], triplanar=True)
    noise_n = nt.nodes.new("ShaderNodeTexNoise")
    noise_n.inputs["Scale"].default_value = 0.04
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nt.links.new(tc.outputs["Object"], noise_n.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeMapRange")
    ramp.inputs["To Min"].default_value = 0.85
    ramp.inputs["To Max"].default_value = 1.1
    nt.links.new(noise_n.outputs["Fac"], ramp.inputs["Value"])
    gcol = mixc(nt, sep.outputs["Blue"], G["albedo"], G2["albedo"])
    gr = mixf(nt, sep.outputs["Blue"], G["rough"], G2["rough"])
    gn = mixc(nt, sep.outputs["Blue"], G["normal"], G2["normal"])
    c1 = mixc(nt, sep.outputs["Red"], gcol, Tl["albedo"])
    r1 = mixf(nt, sep.outputs["Red"], gr, Tl["rough"])
    n1 = mixc(nt, sep.outputs["Red"], gn, Tl["normal"])
    c2 = mixc(nt, sep.outputs["Green"], c1, Wl["albedo"])
    r2 = mixf(nt, sep.outputs["Green"], r1, Wl["rough"])
    n2 = mixc(nt, sep.outputs["Green"], n1, Wl["normal"])
    rutm = nt.nodes.new("ShaderNodeMapRange")
    rutm.inputs["To Min"].default_value = 1.0
    rutm.inputs["To Max"].default_value = 0.8 if WORLD == 3 else 0.62
    nt.links.new(va.outputs["Alpha"], rutm.inputs["Value"])
    rmul = nt.nodes.new("ShaderNodeMath")
    rmul.operation = "MULTIPLY"
    nt.links.new(ramp.outputs["Result"], rmul.inputs[0])
    nt.links.new(rutm.outputs["Result"], rmul.inputs[1])
    tint = nt.nodes.new("ShaderNodeMixRGB")
    tint.blend_type = "MULTIPLY"
    tint.inputs["Fac"].default_value = 1.0
    nt.links.new(c2, tint.inputs["Color1"])
    nt.links.new(rmul.outputs[0], tint.inputs["Color2"])
    nt.links.new(tint.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(r2, b.inputs["Roughness"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
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


def proto(name, tint=None):
    key = name + (str(tint) if tint else "")
    if key not in _CACHE:
        objs = imp(name)
        for o in objs:
            for c in o.users_collection:
                c.objects.unlink(o)
            lib_coll().objects.link(o)
        meshes = [o for o in objs if o.type == "MESH"]
        for o in meshes:  # vertex-colour alpha = edge fade (Godot: vertex_color_use_as_albedo + alpha blend)
            if o.data.color_attributes:
                for slot in o.material_slots:
                    m = slot.material
                    nt = m.node_tree
                    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
                    if bsdf.inputs["Alpha"].is_linked:
                        continue
                    va = nt.nodes.new("ShaderNodeVertexColor")
                    va.layer_name = o.data.color_attributes[0].name
                    nt.links.new(va.outputs["Alpha"], bsdf.inputs["Alpha"])
                    m.surface_render_method = "BLENDED"
        if tint is not None:  # Godot: per-instance colour / albedo_color multiply
            for o in meshes:
                o.data = o.data.copy()
                for i, slot in enumerate(o.material_slots):
                    m = slot.material.copy()
                    o.material_slots[i].material = m
                    nt = m.node_tree
                    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
                    if bsdf.inputs["Base Color"].is_linked:
                        src = bsdf.inputs["Base Color"].links[0].from_socket
                        mx = nt.nodes.new("ShaderNodeMixRGB")
                        mx.blend_type = "MULTIPLY"
                        mx.inputs["Fac"].default_value = 1.0
                        mx.inputs["Color2"].default_value = (*tint, 1)
                        nt.links.new(src, mx.inputs["Color1"])
                        nt.links.new(mx.outputs["Color"], bsdf.inputs["Base Color"])
        _CACHE[key] = meshes
    return _CACHE[key]


def place(name, s, x, yaw=0.0, scale=1.0, zoff=0.0, h=None, tint=None, pitch=0.0):
    p, fwd, right, hd = frame(s)
    pos = world_at(s, x, h) + Vector((0, 0, zoff))
    sc = scale if isinstance(scale, (tuple, list)) else (scale,) * 3
    out = []
    for src in proto(name, tint):
        o = src.copy()
        bpy.context.scene.collection.objects.link(o)
        o.matrix_world = (Matrix.Translation(pos) @ Matrix.Rotation(-hd + yaw, 4, "Z") @ Matrix.Rotation(pitch, 4, "X")
                          @ Matrix.Diagonal((*sc, 1)))
        out.append(o)
    return out


def rider(livery, s, x, action="bike", lean=0.0, z_extra=0.0):
    objs = imp("rider") + imp("bike")
    p, fwd, right, hd = frame(s)
    pos = world_at(s, x) + Vector((0, 0, z_extra))
    pitch = math.atan2(fwd.z, math.hypot(fwd.x, fwd.y))
    M = (Matrix.Translation(pos) @ Matrix.Rotation(-hd, 4, "Z") @ Matrix.Rotation(pitch, 4, "X")
         @ Matrix.Rotation(lean, 4, "Y"))
    for o in objs:
        if o.parent is None:
            o.matrix_world = M @ o.matrix_world
        if o.type == "ARMATURE":
            o.animation_data_create()
            for t in o.animation_data.nla_tracks:
                t.mute = True
        if o.type == "MESH":
            for slot in o.material_slots:
                for n in slot.material.node_tree.nodes:
                    if n.type == "TEX_IMAGE" and n.image and "_r1_albedo" in n.image.name:
                        kind = "rider" if "rider" in n.image.name else "bike"
                        n.image = A.load_image(A.TEX / kind / f"{kind}_{livery}_albedo.png")
    for o in objs:
        if o.type == "ARMATURE":
            names = [c.name for c in o.children]
            is_rider = any("rider" in n for n in names) or "rider" in o.name
            o.animation_data.action = bpy.data.actions.get(action if is_rider else "ride")
    return objs


# ---------------------------------------------------------------- sprites, decals, water
def sprite_mat(name, tex: Path, color=(1, 1, 1), alpha=1.0, additive=False, emit=0.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = A.load_image(tex)
    t.extension = "CLIP"
    am = nt.nodes.new("ShaderNodeMath")
    am.operation = "MULTIPLY"
    am.inputs[1].default_value = alpha
    nt.links.new(t.outputs["Alpha"], am.inputs[0])
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    if additive:
        em = nt.nodes.new("ShaderNodeEmission")
        cm = nt.nodes.new("ShaderNodeMixRGB")
        cm.blend_type = "MULTIPLY"
        cm.inputs["Fac"].default_value = 1.0
        cm.inputs["Color2"].default_value = (*color, 1)
        nt.links.new(t.outputs["Color"], cm.inputs["Color1"])
        nt.links.new(cm.outputs["Color"], em.inputs["Color"])
        st = nt.nodes.new("ShaderNodeMath")
        st.operation = "MULTIPLY"
        st.inputs[1].default_value = max(emit, 1.0)
        nt.links.new(am.outputs[0], st.inputs[0])
        nt.links.new(st.outputs[0], em.inputs["Strength"])
        add = nt.nodes.new("ShaderNodeAddShader")
        nt.links.new(em.outputs[0], add.inputs[0])
        nt.links.new(tr.outputs[0], add.inputs[1])
        nt.links.new(add.outputs[0], out.inputs["Surface"])
    else:
        bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
        cm = nt.nodes.new("ShaderNodeMixRGB")
        cm.blend_type = "MULTIPLY"
        cm.inputs["Fac"].default_value = 1.0
        cm.inputs["Color2"].default_value = (*color, 1)
        nt.links.new(t.outputs["Color"], cm.inputs["Color1"])
        nt.links.new(cm.outputs["Color"], bs.inputs["Base Color"])
        bs.inputs["Roughness"].default_value = 1.0
        if emit:
            nt.links.new(cm.outputs["Color"], bs.inputs["Emission Color"])
            bs.inputs["Emission Strength"].default_value = emit
        mx = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(am.outputs[0], mx.inputs["Fac"])
        nt.links.new(tr.outputs[0], mx.inputs[1])
        nt.links.new(bs.outputs[0], mx.inputs[2])
        nt.links.new(mx.outputs[0], out.inputs["Surface"])
    m.surface_render_method = "BLENDED"
    m.use_backface_culling = False
    try:
        m.use_transparent_shadow = True
    except AttributeError:
        pass
    return m


def card(m, pos: Vector, w: float, h: float, face_cam=True, upright=True, roll=0.0):
    me = bpy.data.meshes.new("card")
    me.from_pydata([(-w / 2, -h / 2, 0), (w / 2, -h / 2, 0), (w / 2, h / 2, 0), (-w / 2, h / 2, 0)], [], [(0, 1, 2, 3)])
    uvl = me.uv_layers.new(name="UVMap")
    for li, uv in zip(range(4), ((0, 0), (1, 0), (1, 1), (0, 1))):
        uvl.data[li].uv = uv
    o = A.link(bpy.data.objects.new("card", me))
    o.data.materials.append(m)
    o.location = pos
    o.visible_shadow = False
    cam = bpy.context.scene.camera
    if face_cam:
        d = cam.location - pos
        if upright:
            d.z = 0
        q = d.normalized().to_track_quat("Z", "Y")
        o.rotation_euler = (q.to_matrix() @ Matrix.Rotation(roll, 3, "Z")).to_euler()
    return o


def ground_decal(m, s, x, w, l, zoff=0.03):
    p, fwd, right, hd = frame(s)
    me = bpy.data.meshes.new("decal")
    nx, ny = 6, 6
    verts, faces, uvs = [], [], []
    for j in range(ny):
        for i in range(nx):
            u, v = i / (nx - 1), j / (ny - 1)
            ss = s + (v - 0.5) * l
            xx = x + (u - 0.5) * w
            verts.append(tuple(world_at(ss, xx) + Vector((0, 0, zoff))))
            uvs.append((u, v))
    for j in range(ny - 1):
        for i in range(nx - 1):
            a = j * nx + i
            faces.append((a, a + 1, a + nx + 1, a + nx))
    me.from_pydata(verts, [], faces)
    uvl = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            uvl.data[li].uv = uvs[me.loops[li].vertex_index]
    o = A.link(bpy.data.objects.new("decal", me))
    o.data.materials.append(m)
    o.visible_shadow = False
    return o


def water_plane(z_world, x0, x1, s0, s1, color=(0.01, 0.02, 0.025), rough=0.05, normal=None):
    m = bpy.data.materials.new("water")
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    if normal is not None:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (0.15, 0.15, 0.15)
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = A.load_image(normal, True)
        nt.links.new(mp.outputs["Vector"], t.inputs["Vector"])
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = 0.25
        nt.links.new(t.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    verts, faces = [], []
    ns = 40
    for j in range(ns + 1):
        s = s0 + (s1 - s0) * j / ns
        for x in (x0, x1):
            p = world_at(s, x, 0.0)
            verts.append((p.x, p.y, z_world))
    for j in range(ns):
        a = 2 * j
        faces.append((a, a + 1, a + 3, a + 2))
    me = bpy.data.meshes.new("water")
    me.from_pydata(verts, [], faces)
    o = A.link(bpy.data.objects.new("water", me))
    o.data.materials.append(m)
    return o


def line_strip(m, s0, s1, x, w, uv_v=False, zoff=0.025):
    verts, faces, uvs = [], [], []
    ns = int((s1 - s0) / 1.0)
    for j in range(ns + 1):
        s = s0 + (s1 - s0) * j / ns
        for k, dx in enumerate((-w / 2, w / 2)):
            verts.append(tuple(world_at(s, x + dx) + Vector((0, 0, zoff))))
            uvs.append((k, (s - s0) / (s1 - s0)) if uv_v else (0.5 + (k - 0.5) * 0.9, 0.5))
    for j in range(ns):
        a = 2 * j
        faces.append((a, a + 1, a + 3, a + 2))
    me = bpy.data.meshes.new("strip")
    me.from_pydata(verts, [], faces)
    uvl = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            uvl.data[li].uv = uvs[me.loops[li].vertex_index]
    o = A.link(bpy.data.objects.new("strip", me))
    o.data.materials.append(m)
    o.visible_shadow = False
    return o


def dust(s, x, n=4, size=1.1, col=(0.72, 0.64, 0.55), alpha=0.16):
    m = sprite_mat(f"dust{col}", A.TEX / "fx" / "dust_puff.png", col, alpha)
    for i in range(n):
        ss = s - 0.8 - i * 0.7
        pos = world_at(ss, x + rnd.uniform(-0.3, 0.3)) + Vector((0, 0, 0.22 + i * 0.10))
        card(m, pos, size * (1 + i * 0.35), size * (1 + i * 0.35), upright=False)


def particles(tex: Path, n, size, col=(1, 1, 1), alpha=1.0, near=3.0, far=45.0, spread=1.0, zlo=0.3, zhi=9.0,
              additive=False, emit=0.0, stretch=1.0, upright=False):
    m = sprite_mat(f"pt_{tex.stem}{col}", tex, col, alpha, additive, emit)
    cam = bpy.context.scene.camera
    fwd = (cam.matrix_world.to_3x3() @ Vector((0, 0, -1)))
    fwd.z = 0
    fwd.normalize()
    rt = fwd.cross(Vector((0, 0, 1)))
    for _ in range(n):
        d = near + (far - near) * rnd.random() ** 1.6
        x = (rnd.random() * 2 - 1) * d * 0.45 * spread
        base = cam.location + fwd * d + rt * x
        z = world_at(S_PLAYER + d, x).z + rnd.uniform(zlo, zhi)
        pos = Vector((base.x, base.y, z))
        sz = size * rnd.uniform(0.7, 1.3)
        card(m, pos, sz, sz * stretch, upright=upright, roll=rnd.uniform(0, 6.28) if stretch == 1.0 else 0.0)


# ---------------------------------------------------------------- scene
def setup_world():
    sc = bpy.context.scene
    w = bpy.data.worlds.new("sky")
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    env = nt.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(CFG["hdri"] if "/" in CFG["hdri"] else str(A.PH / "hdri" / CFG["hdri"]))
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
    for attr, val in (("use_raytracing", False), ("use_shadows", True), ("shadow_ray_count", 2),
                      ("shadow_step_count", 8), ("use_gtao", False), ("use_bloom", True)):
        if hasattr(ee, attr):
            setattr(ee, attr, val)
    for attr, val in (("sun_threshold", 10.0 if WORLD != 6 else 3.0), ("sun_angle", math.radians(1.2)),
                      ("use_sun_shadow", True), ("sun_shadow_maximum_resolution", 0.002)):
        if hasattr(w, attr):
            setattr(w, attr, val)
    sc.view_settings.view_transform = "AgX"
    try:
        sc.view_settings.look = CFG["look"]
    except TypeError:
        pass
    sc.view_settings.exposure = CFG["exposure"]
    w.mist_settings.start = CFG["fog_start"]
    w.mist_settings.depth = CFG["fog_depth"]
    w.mist_settings.falloff = "LINEAR"


def sun_lamp():
    """Explicit DirectionalLight like the game's (elevation, degrees right of 'straight behind', energy, colour),
    instead of EEVEE's sun extraction from the panorama."""
    if "sun_lamp" not in CFG:
        return
    el, az, energy, col = CFG["sun_lamp"]
    sc = bpy.context.scene
    sc.world.sun_threshold = 1e9
    cam = sc.camera
    f = cam.matrix_world.to_3x3() @ Vector((0, 0, -1))
    f.z = 0
    f.normalize()
    r = Vector((f.y, -f.x, 0))
    a = math.radians(az)
    to_sun = (-f * math.cos(a) + r * math.sin(a)) * math.cos(math.radians(el)) + Vector((0, 0, math.sin(math.radians(el))))
    L = bpy.data.lights.new("sun", "SUN")
    L.energy = energy
    L.color = col
    L.angle = math.radians(1.2)
    o = A.link(bpy.data.objects.new("sun", L))
    o.rotation_euler = to_sun.to_track_quat("Z", "Y").to_euler()


def compositor_fog():
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
    env = nt.nodes.new("CompositorNodeMixRGB")
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
    cam.clip_end = 1600
    co = A.link(bpy.data.objects.new("game_cam", cam))
    co.location = loc
    look = Matrix.Rotation(math.radians(-14), 3, flat.cross(Vector((0, 0, 1))).normalized()) @ flat
    co.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    sc.camera = co
    sc.render.resolution_x = int(1080 * SCALE)
    sc.render.resolution_y = int(1920 * SCALE)
    return co


def far_place(name, dist, side_x, yaw=0.0, scale=1.0, z=None):
    """Backdrop pieces far ahead of the camera along the view heading (not along the track)."""
    p, fwd, right, hd = frame(S_PLAYER)
    flat = Vector((fwd.x, fwd.y, 0)).normalized()
    rt = Vector((flat.y, -flat.x, 0))
    pos = p + flat * dist + rt * side_x
    pos.z = (z if z is not None else p.z - CFG["grade"] * dist * 0.5)
    out = []
    for src in proto(name):
        o = src.copy()
        bpy.context.scene.collection.objects.link(o)
        o.matrix_world = Matrix.Translation(pos) @ Matrix.Rotation(-hd + yaw, 4, "Z") @ Matrix.Scale(scale, 4)
        o.visible_shadow = False
        out.append(o)
    return out


# ---------------------------------------------------------------- worlds
def scatter_w3():
    s = 140.0
    while s < 400:  # course flags on both edges
        for side in (-1, 1):
            place("world3/flag_pole", s, side * 6.3, yaw=math.pi / 2 if side > 0 else -math.pi / 2)
        s += 10.0
    s = 150.0
    while s < 620:
        for side in (-1, 1):
            if rnd.random() < 0.55:
                place(rnd.choice(["world3/serac_a", "world3/serac_b"]), s + rnd.uniform(-4, 4), side * rnd.uniform(17, 30),
                      yaw=rnd.uniform(0, 6.28), scale=rnd.uniform(0.8, 1.6), zoff=-0.8)
            if rnd.random() < 0.5:
                place("world3/serac_card", s + rnd.uniform(-6, 6), side * rnd.uniform(34, 70), yaw=0, scale=rnd.uniform(1.2, 2.4), zoff=-1)
            for _ in range(2):
                if rnd.random() < 0.6:
                    place("world3/glacier_boulder", s + rnd.uniform(-5, 5), side * rnd.uniform(8.5, 26),
                          yaw=rnd.uniform(0, 6.28), scale=rnd.uniform(0.5, 2.2), zoff=-0.25)
        s += rnd.uniform(9, 16)
    # icefall seracs flanking the cave mouth
    for side, x, sc_ in ((-1, 13.5, 1.4), (1, 14.0, 1.7), (-1, 19, 1.9), (1, 21, 1.5)):
        place(rnd.choice(["world3/serac_a", "world3/serac_b"]), 296 + rnd.uniform(-2, 3), side * x, yaw=rnd.uniform(0, 6.28),
              scale=sc_, zoff=-1.5)
    place("world3/ice_cave", 300, 0.0, zoff=-0.25, h=0.0)
    place("world3/glacier_hut", 262, 16.5, yaw=-math.pi / 2 - 0.2)
    dye = sprite_mat("dye", A.TEX / "fx/pollen.png", (0.12, 0.30, 0.85), 0.6)  # blue course-edge dye
    line_strip(dye, 150, 330, 5.4, 0.5)
    line_strip(dye, 150, 330, -5.4, 0.5)
    cat = bpy.data.materials.new("snowcat")
    cat.use_nodes = True
    ntc = cat.node_tree
    bc = next(n for n in ntc.nodes if n.type == "BSDF_PRINCIPLED")
    tci = ntc.nodes.new("ShaderNodeTexImage")
    tci.image = A.load_image(A.TEX / "world3/terrain_snowcat_tracks_albedo.jpg")
    uvn = ntc.nodes.new("ShaderNodeUVMap")
    mpn = ntc.nodes.new("ShaderNodeMapping")
    mpn.inputs["Scale"].default_value = (1.0, 12.0, 1.0)
    ntc.links.new(uvn.outputs["UV"], mpn.inputs["Vector"])
    ntc.links.new(mpn.outputs["Vector"], tci.inputs["Vector"])
    ntc.links.new(tci.outputs["Color"], bc.inputs["Base Color"])
    bc.inputs["Roughness"].default_value = 0.7
    line_strip(cat, 150, 330, 10.5, 3.2, uv_v=True)
    place("boost_pad", 205, 0.0)
    place("world3/ice_patch", 214, 2.4)
    place("world3/snow_drift", 236, -1.5)
    place("world3/snow_slough", 223, 5.0, yaw=0.7)
    for side in (-1, 1):
        far_place("world3/mountain_ridge", 640, side * 180, yaw=side * 0.25)
    far_place("world3/mountain_ridge", 820, 0, yaw=0.0, scale=1.2)
    # weather: light snowfall + spindrift off the icefall
    particles(A.TEX / "world3/fx_snowflake.png", 420, 0.07, alpha=0.9, near=2.5, far=40, zlo=0.2, zhi=8)
    sm = sprite_mat("spin", A.TEX / "world3/fx_spindrift.png", (1, 1, 1), 0.35)
    for side in (-1, 1):
        for k in range(4):
            card(sm, world_at(298 + k * 6, side * (12 + k * 2)) + Vector((0, 0, 9.5 + k * 0.6)), 14, 5)


def scatter_w4():
    s = 140.0
    while s < 420:
        place("world4/safety_rail", s, -7.6, yaw=math.pi / 2)
        s += 4.0
    s = 150.0
    while s < 430:
        place("world4/lava_field", s + 20, -18.0, h=-0.25)
        s += 40.0
    s = 150.0
    while s < 620:
        if rnd.random() < 0.45:
            place("world4/basalt_columns", s, rnd.uniform(14, 26), yaw=rnd.uniform(0, 6.28), scale=rnd.uniform(0.8, 1.5), zoff=-0.6)
        if rnd.random() < 0.5:
            place("world4/basalt_columns_card", s + 5, rnd.choice((-1, 1)) * rnd.uniform(40, 80), scale=rnd.uniform(1.2, 2.5), zoff=-1)
        for _ in range(3):
            side = rnd.choice((-1, 1)) if s > 0 else 1
            x = side * rnd.uniform(8.5, 30)
            if side < 0 and abs(x) < 31:
                x = -rnd.uniform(31, 40)
            place("world4/scoria_rock", s + rnd.uniform(-4, 4), x, yaw=rnd.uniform(0, 6.28), scale=rnd.uniform(0.5, 2.0), zoff=-0.3)
        if rnd.random() < 0.35:
            place("world4/burnt_snag", s, rnd.uniform(9, 22), yaw=rnd.uniform(0, 6.28), zoff=-0.15)
        s += rnd.uniform(8, 14)
    place("boost_pad", 204, 0.0)
    place("world4/steam_vent", 216, -1.8, zoff=-0.1)
    stm = sprite_mat("steam", A.TEX / "world4/fx_steam_puff.png", (1, 1, 1), 0.55)
    for k in range(7):
        card(stm, world_at(216, -1.8) + Vector((rnd.uniform(-0.3, 0.3), 0, 0.6 + k * 0.75)), 1.4 + k * 0.45, 1.4 + k * 0.45, upright=False)
    place("world4/ash_dune", 236, 2.0)
    place("world4/lava_crust_ridge", 252, 0.0)
    place("world4/falling_rock_a", 226, 5.2, yaw=0.5, zoff=0.0)
    place("world4/research_station", 300, 28, yaw=-math.pi / 2 + 0.3)
    far_place("world4/crater_cone", 1050, 150, yaw=0.0)
    plume = sprite_mat("plume", A.TEX / "world4/fx_smoke_plume.png", (1, 1, 1), 0.85)
    p, fwd, right, hd = frame(S_PLAYER)
    flat = Vector((fwd.x, fwd.y, 0)).normalized()
    rt = Vector((flat.y, -flat.x, 0))
    top = p + flat * 1050 + rt * 150
    top.z = p.z - CFG["grade"] * 525 + 268
    for k in range(4):
        card(plume, top + Vector((rnd.uniform(-40, 40), 0, 120 + k * 45)), 300 + k * 70, 300 + k * 40)
    particles(A.TEX / "world4/fx_ash_flake.png", 260, 0.06, alpha=0.95, near=2.5, far=35, zlo=0.2, zhi=7)
    particles(A.TEX / "world4/fx_ember.png", 40, 0.05, col=(1.0, 0.55, 0.18), alpha=1.0, near=6, far=40, spread=1.4,
              zlo=0.2, zhi=4, additive=True, emit=6.0)
    hz = sprite_mat("haze", A.TEX / "world4/fx_smoke.png", (1, 1, 1), 0.35)
    for k in range(10):
        d = 60 + k * 35
        card(hz, world_at(S_PLAYER + d, rnd.uniform(-40, 40)) + Vector((0, 0, 8)), 70, 26)


def scatter_w5():
    s = 140.0
    kinds = ["world5/tree_jungle_a", "world5/tree_jungle_b"]
    while s < 560:
        for side in (-1, 1):
            for _ in range(3):
                x = side * rnd.uniform(9.5, 22)
                if 205 < s < 285 and -8 < x < 17:
                    continue
                place(rnd.choice(kinds), s + rnd.uniform(-2, 2), x, yaw=rnd.uniform(0, 6.28), scale=rnd.uniform(0.8, 1.25), zoff=-0.2)
            for _ in range(4):
                place(rnd.choice(kinds), s + rnd.uniform(-4, 4), side * rnd.uniform(22, 110), yaw=rnd.uniform(0, 6.28),
                      scale=rnd.uniform(0.9, 1.4), zoff=-0.3)
        s += rnd.uniform(4.0, 6.5)
    s = 150.0
    while s < 420:
        for side in (-1, 1):
            for _ in range(3):
                x = side * rnd.uniform(5.9, 12)
                if s > 205 and (-6.5 < x < -0.5 or 3.0 < x < 15.5):
                    continue
                k = rnd.random()
                name = "world5/plant_calathea" if k < 0.35 else "world5/plant_anthurium" if k < 0.65 else "fern" if k < 0.85 else "world5/shrub_jungle"
                place(name, s + rnd.uniform(-1.5, 1.5), x, yaw=rnd.uniform(0, 6.28), scale=rnd.uniform(1.4, 2.4), zoff=-0.05)
        s += rnd.uniform(1.6, 2.6)
    place("world5/buttress_tree", 214, -12.5, yaw=0.4)
    place("world5/buttress_tree", 236, 22.0, yaw=2.0, scale=1.1)
    place("world5/log_hop", 207, 0.0, yaw=0.08, zoff=-0.06)
    place("world5/branch_pile", 220, 10.5, yaw=0.3)
    place("world5/stone_ruin", 226, -15.0, yaw=math.pi / 2 - 0.35)
    place("world5/rope_bridge", 232, -3.0, h=0.0)
    place("world5/river_ford", 250, 9.0, h=lateral_h(9.0, 250) + 0.03)
    p0 = world_at(250, 0.0, 0.0)
    water_plane(p0.z - 2.9, -60, 60, 230, 272, color=(0.02, 0.035, 0.03), rough=0.04,
                normal=A.TEX / "world5/water_ripple_normal.png")
    place("boost_pad", 205, 0.0)
    rain = sprite_mat("rain", A.TEX / "world5/fx_rain_streak.png", (0.85, 0.9, 0.95), 0.18)
    for _ in range(200):
        d = 5.0 + 30 * rnd.random() ** 1.3
        x = (rnd.random() * 2 - 1) * d * 0.45
        pos = world_at(S_PLAYER + d - 4.8, x) + Vector((0, 0, rnd.uniform(0.3, 7)))
        card(rain, pos, 0.006 * d ** 0.5, 0.35, upright=True)
    mist = sprite_mat("mist", A.TEX / "world5/fx_mist.png", (1, 1, 1), 0.28)
    for k in range(14):
        d = 30 + k * 18
        card(mist, world_at(S_PLAYER + d, rnd.uniform(-25, 25)) + Vector((0, 0, 3)), 30, 12)
    bf = sprite_mat("bf", A.TEX / "world5/fx_butterfly.png", (1, 1, 1), 1.0)
    for k in range(3):
        card(bf, world_at(S_PLAYER + 9 + k * 6, rnd.uniform(-5, 5)) + Vector((0, 0, 1.4 + k * 0.4)), 0.14, 0.07)


def scatter_w6():
    cols = [(0.56, 0.16, 0.12), (0.12, 0.30, 0.55), (0.18, 0.42, 0.23), (0.55, 0.57, 0.6), (0.72, 0.33, 0.12)]
    for c in cols:
        proto("world6/container", c)
        proto("world6/container_far", c)
    # container yard on the right: rows of stacks along the track
    for row in range(5):
        x = 9.6 + row * 2.6
        s = 150.0
        while s < 290:
            if rnd.random() < 0.85:
                for lvl in range(rnd.choice((1, 2, 2, 3, 3, 4))):
                    kind = "world6/container" if s - S_PLAYER < 45 else "world6/container_far"  # LOD swap at 45 m
                    place(kind, s, x, yaw=math.pi / 2, h=lvl * 2.6, tint=rnd.choice(cols))
            s += 12.5
    # quay side (left): barrier line, bollards, lamps
    s = 150.0
    while s < 292:
        place("world6/concrete_barrier", s, -7.2, yaw=math.pi / 2)
        s += 1.6
    s = 150.0
    while s < 292:
        place("world6/bollard", s, -13.4)
        s += 14.0
    lamp_s = [166, 198, 230, 262]
    pool = sprite_mat("pool", A.TEX / "world6/fx_light_pool.png", (1.0, 0.66, 0.3), 0.22, additive=True, emit=1.0)
    glow = sprite_mat("glow", A.TEX / "world6/fx_sodium_glow.png", (1.0, 0.62, 0.22), 0.8, additive=True, emit=2.5)
    refl = sprite_mat("refl", A.TEX / "world6/fx_wet_reflection.png", (1.0, 0.62, 0.28), 0.35, additive=True, emit=2.0)
    for s in lamp_s:
        for side in (-1, 1):
            place("world6/sodium_lamp", s, side * 8.2, yaw=0.0 if side > 0 else math.pi)
            if s > S_PLAYER + 4:
                ground_decal(pool, s, side * 5.6, 8, 9)
            head = world_at(s, side * (8.2 - 1.75)) + Vector((0, 0, 11.8))
            if s > S_PLAYER + 10:
                card(glow, head, 1.1, 1.1, upright=False)
            if s > S_PLAYER + 10:  # lamp smear on the wet asphalt, lying on the ground, long axis towards the camera
                ground_decal(refl, s - 7.0, side * 5.0, 1.4, 12.0, zoff=0.035)
    # two real omni lights near the camera (DESIGN 11)
    for side in (-1, 1):
        L = bpy.data.lights.new(f"omni{side}", "POINT")
        L.energy = 6000
        L.color = (1.0, 0.62, 0.3)
        L.shadow_soft_size = 0.4
        o = A.link(bpy.data.objects.new(f"omni{side}", L))
        o.location = world_at(230, side * 6.5) + Vector((0, 0, 11.5))
    place("world6/steel_plate", 213, 1.5)
    for k, (ds, x) in enumerate(((228, -2.0), (229.5, -3.2), (231, -1.4))):
        place("world6/traffic_cone", ds, x, yaw=k)
    place("world6/cable_spool", 220, 5.4, yaw=0.0)
    place("boost_pad", 204, 0.0)
    place("world6/crane_jump_stack", 252, 0.0)
    place("world6/gantry_crane", 300, 0.0, h=0.0, zoff=0.0)
    place("world6/air_ring", 304, 0.0, h=0.0, zoff=8.5)
    place("world6/warehouse", 268, 48, yaw=-math.pi / 2)
    place("world6/sea_marker", 360, -20, h=-2.6, zoff=-1.2)
    p0 = world_at(300, 0, 0.0)
    water_plane(p0.z - 2.2, -400, 400, 292, 900, color=(0.006, 0.01, 0.014), rough=0.06,
                normal=A.TEX / "world5/water_ripple_normal.png")
    water_plane(p0.z - 2.2, -400, -14, 120, 292, color=(0.006, 0.01, 0.014), rough=0.06,
                normal=A.TEX / "world5/water_ripple_normal.png")
    far_place("world6/ferry", 230, -75, yaw=math.pi / 2 + 0.2, z=p0.z - 2.2)
    far_place("world6/lit_bridge_far", 1150, 120, yaw=0.15, z=p0.z - 2.2)
    for k in range(3):
        far_place("world6/container_stack_far", 420 + k * 18, 40 + k * 30, yaw=0.0, z=p0.z)
    far_place("world6/warehouse", 470, -60, yaw=0.0, z=p0.z)
    particles(A.TEX / "world6/fx_drizzle.png", 260, 0.02, col=(0.9, 0.85, 0.75), alpha=0.55, near=2.5, far=26,
              zlo=0.2, zhi=8, stretch=18.0, upright=True)


def main():
    A.reset()
    setup_world()
    camera()
    terrain()
    sun_lamp()
    {3: scatter_w3, 4: scatter_w4, 5: scatter_w5, 6: scatter_w6}[WORLD]()
    riders = {
        3: [("r3", 207.0, 2.2, 0.05), ("r6", 214.0, -1.8, -0.07), ("r2", 226.0, 0.6, 0.03)],
        4: [("r4", 206.0, -2.4, -0.06), ("r5", 213.0, 1.8, 0.07), ("r2", 224.0, -0.4, 0.0)],
        5: [("r2", 207.0, 2.0, 0.06), ("r4", 213.0, -2.0, -0.05), ("r3", 236.0, -1.2, 0.02)],
        6: [("r5", 207.0, -2.2, -0.05), ("r3", 214.0, 2.2, 0.07), ("r6", 240.0, 0.5, 0.0)],
    }[WORLD]
    dcol = {3: (0.92, 0.95, 1.0), 4: (0.42, 0.40, 0.38), 5: (0.40, 0.33, 0.24), 6: (0.55, 0.55, 0.58)}[WORLD]
    dal = {3: 0.22, 4: 0.2, 5: 0.12, 6: 0.10}[WORLD]
    rider("r1", S_PLAYER, 0.3, lean=-0.04)
    for lv, s, x, lean in riders:
        rider(lv, s, x, lean=lean, z_extra=(0.68 if WORLD == 6 and s > 252 else 0.0))
        dust(s, x, col=dcol, alpha=dal)
    compositor_fog()
    sc = bpy.context.scene
    sc.render.filepath = OUT
    sc.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(A.BUILD / f"mock_w{WORLD}.blend"))
    n_obj = sum(1 for o in sc.objects if o.type == "MESH" and not o.hide_render)
    print("MOCK objects", n_obj)


main()
