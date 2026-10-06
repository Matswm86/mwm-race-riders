"""Downhill mountain bike (own modelling, real geometry): 29 in wheels, 63 deg head angle, dual-crown fork,
coil shock, flat pedals, 800 mm bar, front number plate. One skinned mesh, one material, bones for wheel spin,
steering and cranks. Per-rider albedo (frame paint + number plate) + shared ORM.

blender -b --factory-startup -P tools/art/build_bike.py
Outputs: assets/models/bike.glb, assets/textures/bike/bike_r1..r6_albedo.png, bike_orm.png
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).parent))
import rr_art as A  # noqa: E402

TEXDIR = A.TEX / "bike"
TEXDIR.mkdir(parents=True, exist_ok=True)
RES = 1024
B = A.BIKE
NAMES = ["paint", "anod", "rubber", "tread", "silver", "gold", "spring", "plate", "saddle", "rim"]
ROUGH = {
    "paint": 0.22,
    "anod": 0.42,
    "rubber": 0.85,
    "tread": 0.9,
    "silver": 0.28,
    "gold": 0.22,
    "spring": 0.35,
    "plate": 0.4,
    "saddle": 0.6,
    "rim": 0.45,
}
METAL = {"anod": 0.6, "silver": 1.0, "gold": 1.0, "rim": 0.5}

FA = Vector(B["axle_front"])
RA = Vector(B["axle_rear"])
BB = Vector(B["bb"])
HT = Vector(B["head_top"])
STEER = Vector(
    (0, math.cos(math.radians(63)), -math.sin(math.radians(63)))
)  # down the steering axis
HB = HT + STEER * 0.115  # head tube bottom
WR = B["wheel_r"]


def M(n):
    return A.get_mat(n)


def wheel(name: str, c: Vector) -> list:
    parts = []
    # tyre: profile ring with knob blocks on alternating segments
    seg, prof = 64, 10
    verts, faces = [], []
    tube_r = 0.034
    ring_r = WR - tube_r
    for i in range(seg):
        a = 2 * math.pi * i / seg
        knob = i % 2 == 0
        for k in range(prof):
            b = 2 * math.pi * k / prof
            nr = tube_r
            if math.cos(b) > 0.25:  # tread half
                lat = abs(math.sin(b))
                if knob and (lat < 0.35 or 0.6 < lat < 0.95):
                    nr += 0.006
                elif not knob and 0.35 <= lat <= 0.6:
                    nr += 0.004
            rr = ring_r + math.cos(b) * nr
            verts.append(
                (c.x + math.sin(b) * nr * 1.05, c.y + math.cos(a) * rr, c.z + math.sin(a) * rr)
            )
    for i in range(seg):
        for k in range(prof):
            a = i * prof + k
            b = i * prof + (k + 1) % prof
            a2 = ((i + 1) % seg) * prof + k
            b2 = ((i + 1) % seg) * prof + (k + 1) % prof
            faces.append((a, b, b2, a2))
    ty = A.mesh_obj(name + "_tyre", verts, faces)
    ty.data.materials.append(M("tread"))
    for p in ty.data.polygons:
        p.use_smooth = True
    parts.append(ty)
    # rim: flat ring
    rim_r0, rim_r1, w = WR - 0.075, WR - 0.035, 0.016
    verts, faces = [], []
    n = 48
    for i in range(n):
        a = 2 * math.pi * i / n
        for rr, x in ((rim_r0, -w * 0.6), (rim_r1, -w), (rim_r1, w), (rim_r0, w * 0.6)):
            verts.append((c.x + x, c.y + math.cos(a) * rr, c.z + math.sin(a) * rr))
    for i in range(n):
        for k in range(4):
            a = i * 4 + k
            b = i * 4 + (k + 1) % 4
            faces.append((a, b, ((i + 1) % n) * 4 + (k + 1) % 4, ((i + 1) % n) * 4 + k))
    rim = A.mesh_obj(name + "_rim", verts, faces)
    rim.data.materials.append(M("rim"))
    parts.append(rim)
    # hub + spokes
    hub = A.tube(
        name + "_hub", [c + Vector((-0.06, 0, 0)), c + Vector((0.06, 0, 0))], 0.022, 10, M("anod")
    )
    parts.append(hub)
    for i in range(28):
        a = 2 * math.pi * i / 28
        side = 1 if i % 2 else -1
        p0 = c + Vector(
            (side * 0.035, math.cos(a + side * 0.18) * 0.03, math.sin(a + side * 0.18) * 0.03)
        )
        p1 = c + Vector(
            (side * 0.006, math.cos(a) * (rim_r0 + 0.004), math.sin(a) * (rim_r0 + 0.004))
        )
        parts.append(A.tube(f"{name}_sp{i}", [p0, p1], 0.0016, 3, M("silver"), cap=False))
    # brake rotor (left side, -x)
    rot = A.tube(
        name + "_rotor",
        [c + Vector((-0.045, 0, 0)), c + Vector((-0.043, 0, 0))],
        0.10,
        28,
        M("silver"),
    )
    parts.append(rot)
    return parts


def frame() -> list:
    P = []
    pm = M("paint")
    st_top = Vector((0, -0.29, 0.80))
    # main tubes (oversized, slightly curved down tube)
    dt_mid = (HB + BB) / 2 + Vector((0, 0.03, -0.03))
    P.append(
        A.tube("down_tube", [HB, dt_mid, BB + Vector((0, 0.04, 0.05))], 0.046, 12, pm, r_end=0.036)
    )
    P.append(
        A.tube(
            "top_tube",
            [HT + Vector((0, -0.01, -0.03)), Vector((0, -0.02, 0.86)), st_top],
            0.032,
            10,
            pm,
            r_end=0.026,
        )
    )
    P.append(A.tube("seat_tube", [BB, st_top, Vector((0, -0.33, 0.86))], 0.030, 10, pm))
    P.append(A.tube("head_tube", [HT + Vector((0, 0, 0.01)), HB], 0.036, 12, pm))
    P.append(
        A.tube(
            "gusset",
            [
                HB + Vector((0, -0.03, 0.03)),
                HT + Vector((0, -0.06, -0.06)),
                Vector((0, -0.08, 0.84)),
            ],
            0.012,
            6,
            pm,
        )
    )
    # rear triangle (both sides)
    rocker = Vector((0, -0.27, 0.70))
    for s in (-1, 1):
        ra = RA + Vector((s * 0.068, 0, 0))
        P.append(
            A.tube(
                f"chainstay{s}",
                [
                    BB + Vector((s * 0.03, -0.03, 0.0)),
                    (BB + ra) / 2 + Vector((s * 0.02, 0, 0.01)),
                    ra,
                ],
                0.024,
                8,
                pm,
                r_end=0.016,
            )
        )
        P.append(
            A.tube(
                f"seatstay{s}",
                [
                    ra,
                    (ra + rocker) / 2 + Vector((s * 0.025, 0, 0.02)),
                    rocker + Vector((s * 0.03, 0, 0)),
                ],
                0.019,
                8,
                pm,
                r_end=0.022,
            )
        )
        P.append(
            A.tube(
                f"dropout{s}",
                [ra + Vector((0, 0, -0.02)), ra + Vector((0, 0, 0.03))],
                0.012,
                8,
                M("anod"),
            )
        )
    P.append(
        A.tube(
            "rocker",
            [rocker + Vector((-0.04, 0, 0)), rocker + Vector((0.04, 0, 0))],
            0.022,
            10,
            M("anod"),
        )
    )
    # coil shock: body, shaft, spring
    s0, s1 = Vector((0, -0.05, 0.52)), Vector((0, -0.25, 0.70))
    P.append(A.tube("shock_body", [s0, s0 + (s1 - s0) * 0.55], 0.018, 10, M("anod")))
    P.append(A.tube("shock_shaft", [s0 + (s1 - s0) * 0.5, s1], 0.010, 8, M("silver")))
    P.append(
        A.tube(
            "shock_res",
            [
                s0 + (s1 - s0) * 0.15 + Vector((0, 0, 0.035)),
                s0 + (s1 - s0) * 0.55 + Vector((0, 0, 0.035)),
            ],
            0.012,
            8,
            M("anod"),
        )
    )
    d = (s1 - s0).normalized()
    x = d.cross(Vector((1, 0, 0))).normalized()
    y = d.cross(x)
    pts = []
    for i in range(80):
        t = i / 79
        a = t * 2 * math.pi * 7
        pts.append(s0 + d * (0.05 + t * 0.14) + (x * math.cos(a) + y * math.sin(a)) * 0.030)
    P.append(A.tube("spring", pts, 0.0045, 5, M("spring"), cap=False))
    # saddle + post
    sad = Vector(B["saddle"])
    P.append(
        A.tube(
            "post", [Vector((0, -0.33, 0.84)), sad + Vector((0, 0.01, -0.02))], 0.0155, 8, M("anod")
        )
    )
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=1)
    sd = bpy.context.active_object
    sd.name = "saddle"
    sd.scale = (0.065, 0.135, 0.022)
    sd.location = sad + Vector((0, 0.02, 0.0))
    A.apply_xform(sd)
    for v in sd.data.vertices:  # narrow nose
        if v.co.y > sad.y + 0.02:
            k = (v.co.y - sad.y - 0.02) / 0.13
            v.co.x *= 1 - 0.65 * k
    sd.data.materials.append(M("saddle"))
    for p in sd.data.polygons:
        p.use_smooth = True
    P.append(sd)
    return P


def drivetrain() -> tuple[list, list]:
    """(static parts on the frame, crank parts on the crank bone)."""
    st, cr = [], []
    # chainring + chain to cassette (drive side +x)
    ring = A.tube(
        "chainring", [BB + Vector((0.05, 0, 0)), BB + Vector((0.054, 0, 0))], 0.075, 24, M("anod")
    )
    cr.append(ring)
    cas = A.tube(
        "cassette", [RA + Vector((0.025, 0, 0)), RA + Vector((0.050, 0, 0))], 0.045, 16, M("silver")
    )
    st.append(cas)
    for z0, r0, r1 in ((1, 0.075, 0.045), (-1, 0.075, 0.03)):
        p0 = BB + Vector((0.052, 0, z0 * r0))
        p1 = RA + Vector((0.040, 0, z0 * r1))
        st.append(A.tube(f"chain{z0}", [p0, p1], 0.004, 4, M("silver"), cap=False))
    # crank arms + pedals (level cranks, left foot forward)
    for s, fwd in ((-1, 1), (1, -1)):
        tip = BB + Vector((s * 0.085, fwd * B["crank"], 0))
        cr.append(
            A.tube(
                f"crank{s}", [BB + Vector((s * 0.065, 0, 0)), tip], 0.014, 8, M("anod"), r_end=0.010
            )
        )
        bpy.ops.mesh.primitive_cube_add(size=1)
        pd = bpy.context.active_object
        pd.name = f"pedal{s}"
        pd.scale = (0.10, 0.100, 0.016)
        pd.location = tip + Vector((s * 0.06, 0, 0.0))
        bv = pd.modifiers.new("bv", "BEVEL")
        bv.width = 0.006
        bv.segments = 2
        A.apply_xform(pd)
        A.apply_all(pd)
        pd.data.materials.append(M("anod"))
        cr.append(pd)
    return st, cr


def fork_and_bar() -> list:
    P = []
    top_crown = HT + STEER * -0.035
    low_crown = HB + STEER * 0.02
    off = Vector((0, 0.035, 0.015))
    for s in (-1, 1):
        x = Vector((s * 0.068, 0, 0))
        st0 = top_crown + x + off * 0.3
        st1 = FA + x + Vector((0, -0.01, 0.30))
        P.append(A.tube(f"stanchion{s}", [st0, st1], 0.0185, 12, M("gold")))
        P.append(
            A.tube(
                f"lower{s}",
                [st1 + (st0 - st1).normalized() * 0.07, FA + x + Vector((0, 0.005, -0.015))],
                0.026,
                12,
                M("anod"),
                r_end=0.022,
            )
        )
    for c, w in ((top_crown, 0.20), (low_crown, 0.21)):
        bpy.ops.mesh.primitive_cube_add(size=1)
        cb = bpy.context.active_object
        cb.scale = (w, 0.06, 0.03)
        cb.location = c + off * 0.3
        cb.rotation_euler = (math.radians(-27), 0, 0)
        bv = cb.modifiers.new("bv", "BEVEL")
        bv.width = 0.01
        bv.segments = 2
        A.apply_xform(cb)
        A.apply_all(cb)
        cb.data.materials.append(M("anod"))
        P.append(cb)
    P.append(A.tube("steerer", [top_crown + STEER * -0.03, low_crown], 0.016, 8, M("anod")))
    # direct-mount stem + 800 mm riser bar
    gx, gy, gz = B["grip"]
    stem_top = top_crown + Vector((0, 0.045, 0.03))
    bar = []
    for i in range(13):
        t = i / 12 * 2 - 1
        x = t * 0.40
        rise = 0.025 * min(1.0, abs(t) * 3)
        sweep = -0.02 * abs(t) ** 2
        bar.append(Vector((x, stem_top.y + 0.01 + sweep, stem_top.z + 0.015 + rise)))
    # make the grip centre hit B["grip"] exactly
    shift = Vector((0, gy - bar[-2].y, gz - bar[-2].z))
    bar = [p + shift for p in bar]
    P.append(A.tube("bar", bar, 0.0115, 10, M("anod")))
    for s in (-1, 1):
        P.append(
            A.tube(
                f"grip{s}",
                [Vector((s * 0.29, gy, gz)), Vector((s * 0.405, gy + shift.y * 0, gz))],
                0.0165,
                10,
                M("rubber"),
            )
        )
        P.append(
            A.tube(
                f"lever{s}",
                [Vector((s * 0.24, gy + 0.0, gz + 0.01)), Vector((s * 0.33, gy + 0.05, gz - 0.02))],
                0.006,
                5,
                M("anod"),
            )
        )
    P.append(
        A.tube(
            "stem",
            [
                top_crown + off * 0.3 + Vector((0, 0, 0.02)),
                Vector((0, gy - 0.005, gz - 0.005)) - Vector((0, 0, 0.0)),
            ],
            0.02,
            8,
            M("anod"),
        )
    )
    # number plate (faces +y), held off the bar
    pl_c = Vector((0, gy + 0.075, gz - 0.07))
    verts, faces = [], []
    nx, nz = 6, 5
    for j in range(nz):
        for i in range(nx):
            u = i / (nx - 1) * 2 - 1
            v = j / (nz - 1) * 2 - 1
            verts.append((u * 0.10, pl_c.y - 0.03 * u * u, pl_c.z + v * 0.085 - 0.012 * u * u))
    for j in range(nz - 1):
        for i in range(nx - 1):
            a = j * nx + i
            faces.append((a, a + 1, a + nx + 1, a + nx))
    pl = A.mesh_obj("plate", verts, faces)
    pl.data.materials.append(M("plate"))
    so = pl.modifiers.new("s", "SOLIDIFY")
    so.thickness = 0.004
    A.apply_all(pl)
    P.append(pl)
    return P


def livery(maps, rider) -> np.ndarray:
    P, N, Mi = maps["pos"][..., :3], maps["nrm"][..., :3], maps["mid"]
    x, y, z = P[..., 0], P[..., 1], P[..., 2]
    col = np.zeros(P.shape[:2] + (3,), np.float32) + 0.5
    base, acc, trim = A.srgb(rider["hex"]), A.srgb(rider["accent"]), A.srgb(rider["trim"])

    def put(m, c):
        col[m] = c

    paint = Mi == NAMES.index("paint")
    put(paint, base)
    # accent band along the down tube and a trim pinstripe on the top tube
    dt = paint & (y > -0.12) & (y < 0.22) & (z < 0.75) & (z > 0.45)
    put(dt & (np.abs((z - 0.62) + 0.9 * (y - 0.05)) < 0.03), acc)
    put(paint & (z > 0.84) & (np.abs(x) > 0.012) & (y < 0.2) & (y > -0.2), trim)
    put(paint & (y < -0.40), acc)  # rear triangle tips
    put(Mi == NAMES.index("anod"), A.srgb("#1B1C1F"))
    put(Mi == NAMES.index("rubber"), A.srgb("#151515"))
    put(Mi == NAMES.index("tread"), A.srgb("#1E1D1C"))
    put(Mi == NAMES.index("silver"), A.srgb("#B9BCC0"))
    put(Mi == NAMES.index("gold"), A.srgb("#C7A253"))
    put(
        Mi == NAMES.index("spring"),
        acc
        if rider["accent"] not in ("#16181C",)
        else A.srgb("#F2A900")
        if rider["id"] == "r1"
        else base,
    )
    put(Mi == NAMES.index("saddle"), A.srgb("#17181A"))
    put(Mi == NAMES.index("rim"), A.srgb("#202124"))
    # rim decal in the rider colour
    rimm = Mi == NAMES.index("rim")
    put(rimm & (np.abs(x) > 0.012), base)
    # number plate: white with the number (front face only)
    pl = Mi == NAMES.index("plate")
    put(pl, A.srgb("#F4F5F6"))
    nm = A.num_mask(rider["num"])
    gx, gy, gz = B["grip"]
    s = A.sample(nm, (x + 0.085) / 0.17, (z - (gz - 0.07) + 0.075) / 0.15)
    front = pl & (N[..., 1] > 0.3)
    put(front & (s[..., 1] > 0.5), base)
    put(front & (s[..., 0] > 0.5), A.srgb("#16181C"))
    return col


def build() -> None:
    A.reset()
    fr = frame()
    st, cr = drivetrain()
    fk = fork_and_bar()
    wf = wheel("wf", FA)
    wr = wheel("wr", RA)
    groups = {"frame": fr + st, "crank": cr, "fork": fk, "wheel_front": wf, "wheel_rear": wr}
    objs = []
    for g, lst in groups.items():
        for o in lst:
            A.rigid_group(o, g)
            objs.append(o)
    bike = A.join(objs, "bike")
    # make sure every NAMES material exists in slot order
    print("BIKE tris", A.tris(bike), [m.name for m in bike.data.materials])
    A.atlas_unwrap(bike, 0.003)
    maps = A.bake_maps(bike, NAMES, RES, ao_dist=0.08)
    for r in A.RIDERS:
        c = A.fill_invalid(livery(maps, r), maps["valid"])
        A.write_png(c, TEXDIR / f"bike_{r['id']}_albedo.png")
    A.write_png(A.orm_from(maps, NAMES, ROUGH, METAL, 0.8), TEXDIR / "bike_orm.png")
    fm = A.pbr_material("bike", albedo=TEXDIR / "bike_r1_albedo.png", orm=TEXDIR / "bike_orm.png")
    bike.data.materials.clear()
    bike.data.materials.append(fm)
    # skeleton: wheel bones point along +X so spinning = rotate around the bone's own Y axis
    ad = bpy.data.armatures.new("bike_rig")
    rig = A.link(bpy.data.objects.new("bike_rig", ad))
    A.activate(rig)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = ad.edit_bones

    def bone(n, h, t, par=None):
        b = eb.new(n)
        b.head, b.tail = h, t
        b.roll = 0
        if par:
            b.parent = eb[par]

    bone("root", (0, 0, 0), (0, 0.25, 0))
    bone("frame", (0, 0, 0.45), (0, 0.25, 0.45), "root")
    bone("fork", HT, HT + STEER * 0.2, "frame")
    bone("wheel_front", FA, FA + Vector((0.12, 0, 0)), "fork")
    bone("wheel_rear", RA, RA + Vector((0.12, 0, 0)), "frame")
    bone("crank", BB, BB + Vector((0.12, 0, 0)), "frame")
    bpy.ops.object.mode_set(mode="OBJECT")
    bike.parent = rig
    md = bike.modifiers.new("Armature", "ARMATURE")
    md.object = rig
    # animations: ride (rest), crash (0.5 s fall onto the left side), lying (static)
    rig.animation_data_create()
    pbs = rig.pose.bones
    for pb in pbs:
        pb.rotation_mode = "QUATERNION"
    import mathutils

    # lying height: lowest vertex after a roll of 74 deg about Y at the origin
    co = np.array([v.co[:] for v in bike.data.vertices])

    def low_z(roll):
        r = math.radians(roll)
        zz = co[:, 0] * math.sin(r) + co[:, 2] * math.cos(r)
        return zz.min()

    acts = {}
    for name, keys in (
        ("ride", [(0, 0, 0, 0)]),
        ("lying", [(0, 74, 0, 25)]),
        ("crash", [(0, 0, 0, 0), (6, 30, 0.4, 10), (12, 74, 0.9, 25), (15, 74, 1.0, 25)]),
    ):
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        rig.animation_data.action = act
        for f, roll, slide, steer in keys:
            r = math.radians(roll)
            # rotate about the world Y axis through the ground point under the left grips side, then drop to ground
            q = mathutils.Quaternion((0, 1, 0), -r)
            lift = -low_z(roll) if roll else 0.0
            pbs["root"].rotation_quaternion = q
            # root bone rest: head at origin, y along world +Y, z along world +Z, x = world +X
            pbs["root"].location = Vector((0.0, slide, lift))
            pbs["fork"].rotation_quaternion = mathutils.Quaternion((0, 1, 0), math.radians(steer))
            for pb in pbs:
                pb.keyframe_insert("rotation_quaternion", frame=f)
                pb.keyframe_insert("location", frame=f)
        tr = rig.animation_data.nla_tracks.new()
        tr.name = name
        tr.strips.new(name, 0, act)
        rig.animation_data.action = None
        acts[name] = act
    bpy.context.scene.render.fps = 30
    bpy.ops.wm.save_as_mainfile(filepath=str(A.BUILD / "bike_rigged.blend"))
    out = A.export_glb([rig, bike], "bike", anim=True, skins=True)
    print("EXPORT", out, out.stat().st_size, "tris", A.tris(bike), "size", A.size_godot([bike]))


if __name__ == "__main__":
    build()
