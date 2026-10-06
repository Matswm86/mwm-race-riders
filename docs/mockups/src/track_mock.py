"""Render the race mock (behind-the-rider chase camera), 1080x1920, no HUD.

blender -b -P docs/mockups/src/track_mock.py -- <out_raw.png>
Then: python3 docs/mockups/src/hud_overlay.py <out_raw.png> docs/mockups/track_mock.png

Scene: player (fox, red) on the bike just before a boost pad; AI riders ahead on the dirt
section, one airborne off a kicker ramp, one already on the hoverboard after the swap gate.
Camera = DESIGN.md section 6a: 4.5 m behind, 2.2 m up, pitch -12 deg, vertical FOV 70 deg.
"""

import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).parent))
import rr_parts as P  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = argv[0] if argv else str(Path(__file__).parent / "track_raw.png")

random.seed(11)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
coll = sc.collection

FOG = (55.0, 260.0, 0.7, "#D6EEFB")  # start m, end m, max amount, colour (= sky horizon)
mat = P.kit_material("rr_kit_fog", fog=FOG)
team_mat = {r["id"]: P.kit_material(f"team_{r['id']}", team_hex=r["team"], fog=FOG) for r in P.RIDERS}
RID = {r["id"]: r for r in P.RIDERS}

# ---- track centreline (Catmull-Rom) ------------------------------------------------
CTRL = [
    (0, -40, 4.2),
    (0, -20, 2.0),
    (0, 0, 0),
    (0.4, 18, -1.9),
    (2.6, 36, -3.9),
    (7.5, 56, -6.0),
    (10.5, 80, -8.4),
    (7.0, 106, -10.8),
    (-3.0, 132, -12.8),
    (-14, 160, -14.6),
    (-20, 200, -16.8),
    (-14, 240, -19.0),
    (0, 280, -21.0),
]


def catmull(p0, p1, p2, p3, t):
    t2, t3 = t * t, t * t * t
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)


pts = []
C = [Vector(c) for c in CTRL]
for i in range(1, len(C) - 2):
    for j in range(40):
        pts.append(catmull(C[i - 1], C[i], C[i + 1], C[i + 2], j / 40))
# resample at 1 m
samples = [pts[0]]
acc = 0.0
for a, b in zip(pts, pts[1:]):
    seg = (b - a).length
    acc += seg
    while acc >= 1.0:
        acc -= 1.0
        t = 1 - acc / seg
        samples.append(a.lerp(b, t))
N = len(samples)


def frame(i):
    i = max(0, min(N - 1, int(round(i))))
    t = (samples[min(i + 1, N - 1)] - samples[max(i - 1, 0)]).normalized()
    side = Vector((t.y, -t.x, 0)).normalized()  # right-hand side
    return samples[i], t, side


def s_at_y(y):
    return min(range(N), key=lambda i: abs(samples[i].y - y))


S_PLAYER = s_at_y(0.0)
S_PAD = S_PLAYER + 5
S_RAMP = S_PLAYER + 20
S_GATE = S_PLAYER + 32
CAM_BACK, CAM_UP, CAM_PITCH = 4.8, 2.8, 14.0  # DESIGN.md 6a
HW = 3.3  # half width: 6.6 m open track (about 10 rider widths)


def place(s, lateral=0.0, up=0.0):
    p, t, side = frame(s)
    yaw = math.atan2(-t.x, t.y)
    pitch = math.atan2(t.z, math.hypot(t.x, t.y))
    return P.T(*(p + side * lateral + Vector((0, 0, up)))) @ P.R(0, 0, math.degrees(yaw)) @ P.R(math.degrees(pitch), 0, 0)


# ---- track ribbon --------------------------------------------------------------------
def track_strip_cols(s):
    if s < S_GATE:
        return [
            (-HW, -2.2, "dirt"),
            (-2.2, -1.45, "dirt"),
            (-1.45, -1.15, "dirt_dark"),
            (-1.15, 0.0, "dirt"),
            (0.0, 1.15, "dirt"),
            (1.15, 1.45, "dirt_dark"),
            (1.45, 2.2, "dirt"),
            (2.2, HW, "dirt"),
        ]
    dash = "lane_stripe" if (s // 3) % 2 == 0 else "lane"
    return [
        (-HW, -HW + 0.35, "lane_dark"),
        (-HW + 0.35, -HW + 0.55, "lane_stripe"),
        (-HW + 0.55, -0.1, "lane"),
        (-0.1, 0.1, dash),
        (0.1, HW - 0.55, "lane"),
        (HW - 0.55, HW - 0.35, "lane_stripe"),
        (HW - 0.35, HW, "lane_dark"),
    ]


tk = P.Kit()
for i in range(N - 1):
    p0, _, s0 = frame(i)
    p1, _, s1 = frame(i + 1)
    for a, b, col in track_strip_cols(i):
        v = [tuple(p0 + s0 * a), tuple(p0 + s0 * b), tuple(p1 + s1 * b), tuple(p1 + s1 * a)]
        v = [(x, y, z + 0.05) for x, y, z in v]
        tk.add((v, [(0, 1, 2, 3)]), col, smooth=False)
# curbs: cream on dirt, sky-blue rails on the lane
for side_sign in (-1, 1):
    for rng, col, rad in (((0, S_GATE + 1), "curb", 0.22), ((S_GATE, N), "sky", 0.16)):
        line = []
        for i in range(rng[0], rng[1]):
            p, _, sd = frame(i)
            line.append(tuple(p + sd * (HW + 0.12) * side_sign + Vector((0, 0, 0.12))))
        tk.add(P.sweep(line, rad, 6), col)
tk.build("track", mat)

# ---- terrain ---------------------------------------------------------------------------
sub = samples[::2]


def nearest(x, y):
    best, bi = 1e18, 0
    for k, q in enumerate(sub):
        d = (q.x - x) ** 2 + (q.y - y) ** 2
        if d < best:
            best, bi = d, k
    return math.sqrt(best), sub[bi].z


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


STEP = 3.0
xs = [(-150 + STEP * i) for i in range(int(300 / STEP) + 1)]
ys = [(-30 + STEP * j) for j in range(int(330 / STEP) + 1)]
H = {}
for j, y in enumerate(ys):
    for i, x in enumerate(xs):
        d, tz = nearest(x, y)
        base = tz - 0.25 + max(0.0, d - HW - 0.4) * 0.18
        hills = P.noise2(x, y, 0.025) * 9 + P.noise2(x + 50, y, 0.07) * 2.5
        H[i, j] = base + smooth(HW + 4, 40, d) * (hills + 4) + smooth(60, 160, d) * 18
terr = P.Kit()
for j in range(len(ys) - 1):
    for i in range(len(xs) - 1):
        q = [(xs[i], ys[j], H[i, j]), (xs[i + 1], ys[j], H[i + 1, j]), (xs[i + 1], ys[j + 1], H[i + 1, j + 1]), (xs[i], ys[j + 1], H[i, j + 1])]
        n = P.noise2(xs[i], ys[j], 0.03)
        col = "grass_dark" if n > 0.3 else ("meadow" if n < -0.35 else "grass")
        terr.add(([q[0], q[1], q[2]], [(0, 1, 2)]), col, smooth=False)
        terr.add(([q[0], q[2], q[3]], [(0, 1, 2)]), col, smooth=False)
terr.build("terrain", mat)


def ground_z(x, y):
    i = int((x + 150) / STEP)
    j = int((y + 30) / STEP)
    i = max(0, min(len(xs) - 2, i))
    j = max(0, min(len(ys) - 2, j))
    return min(H[i, j], H[i + 1, j], H[i, j + 1], H[i + 1, j + 1])


# ---- scenery (linked duplicates = MultiMesh in Godot) ------------------------------------
proto = {
    "tree_round": P.tree_round_kit().build("proto_tree_round", mat),
    "tree_pine": P.tree_pine_kit().build("proto_tree_pine", mat),
    "rock": P.rock_kit().build("proto_rock", mat),
    "cloud": P.cloud_kit().build("proto_cloud", mat),
}
for o in proto.values():
    o.hide_render = True


def inst(kind, loc, rot=0.0, scale=1.0):
    o = bpy.data.objects.new(kind, proto[kind].data)
    coll.objects.link(o)
    o.location = loc
    o.rotation_euler = (0, 0, rot)
    o.scale = (scale, scale, scale)
    return o


placed = 0
tries = 0
while placed < 170 and tries < 6000:
    tries += 1
    x = random.uniform(-90, 90)
    y = random.uniform(-5, 260)
    d, _ = nearest(x, y)
    if d < HW + 2.6 or d > 70:
        continue
    if random.random() < smooth(10, 70, d) * 0.55:
        continue
    kind = "tree_pine" if (P.noise2(x, y, 0.04) > 0.0) else "tree_round"
    if random.random() < 0.16:
        kind = "rock"
    inst(kind, (x, y, ground_z(x, y)), random.uniform(0, 6.28), random.uniform(0.9, 1.5) * (1.0 if kind != "rock" else 0.8))
    placed += 1
for i in range(9):
    c = inst("cloud", (random.uniform(-120, 120), random.uniform(160, 380), random.uniform(28, 60)), 0, random.uniform(3.0, 5.0))
    c.rotation_euler = (0, 0, random.uniform(-0.3, 0.3))
for i in range(7):
    a = math.radians(-60 + i * 20)
    dist = 420 + random.uniform(-40, 40)
    mk = P.mountain_kit(seed=i, h=random.uniform(70, 120), r=random.uniform(70, 110)).build(f"mountain_{i}", mat)
    mk.location = (math.sin(a) * dist, 60 + math.cos(a) * dist, -40)

pk = P.Kit()
for i in range(S_PLAYER - 6, S_GATE, 1):
    for k in range(2):
        lat = random.choice((-1, 1)) * random.uniform(HW - 0.9, HW - 0.25)
        p, _, sd = frame(i)
        q = p + sd * lat + Vector((0, 0, 0.06))
        pk.add(P.ico(random.uniform(0.06, 0.13), 0, 0.2, i * 3 + k, (1.2, 1, 0.6)), "pebble", P.T(*q), smooth=False)
pk.build("pebbles", mat)

# ---- track kit ----------------------------------------------------------------------------
pad = P.boost_pad_kit().build("boost_pad", mat)
pad.matrix_world = place(S_PAD, 0.5, 0.05)
pad2 = P.boost_pad_kit().build("boost_pad2", mat)
pad2.matrix_world = place(S_PLAYER + 18, -1.4, 0.05)
ramp = P.ramp_kit().build("ramp", mat)
ramp.matrix_world = place(S_RAMP, 1.1, 0.04)
gate = P.swap_gate_kit("board").build("swap_gate_board", mat)
gate.matrix_world = place(S_GATE, 0.0, 0.0)

# ---- riders --------------------------------------------------------------------------------


def racer(rid, vehicle, s, lateral, up=0.0, pose=None, pitch_extra=0.0, yaw_extra=0.0, shadow=True):
    m = team_mat[rid]
    w = place(s, lateral, up) @ P.R(pitch_extra, 0, yaw_extra)
    vk = P.bike_kit() if vehicle == "bike" else P.board_kit()
    vk.build(f"{vehicle}_{rid}", m).matrix_world = w
    P.build_rider_posed(f"rider_{rid}", RID[rid], pose or vehicle, m, w)
    if shadow:
        p, t, sd = frame(s)
        b = P.blob(f"blob_{rid}", 1.0 if vehicle == "bike" else 0.9, 1.9 if vehicle == "bike" else 1.6)
        b.matrix_world = place(s, lateral, 0.08) @ P.S(1.0 if vehicle == "bike" else 0.9, 1.9 if vehicle == "bike" else 1.6, 1)


racer("fox", "bike", S_PLAYER, 0.0, yaw_extra=4)
racer("bunny", "bike", S_PLAYER + 9, 1.7, yaw_extra=3)
racer("bear", "bike", S_PLAYER + 13, -1.9, yaw_extra=-4)
# airborne off the ramp lip, cheer trick pose; its shadow is smaller and lighter on the track below
racer("shark", "bike", S_RAMP + 4.6, 1.2, up=1.8, pose="cheer", pitch_extra=14, shadow=False)
bs = P.blob("blob_air", 0.7, 1.3)
bs.matrix_world = place(S_RAMP + 4.6, 1.2, 0.08) @ P.S(0.7, 1.3, 1)
racer("bobble", "board", S_GATE + 2, -2.9, yaw_extra=-6)

# ---- camera ---------------------------------------------------------------------------------
cp, ct, _ = frame(S_PLAYER - 4)  # about 4.5 m of path behind the rider
pp, pt, _ = frame(S_PLAYER)
back = Vector((pt.x, pt.y, 0)).normalized()
cam_pos = pp - back * CAM_BACK
cam_pos.z = pp.z + CAM_UP
cam_d = bpy.data.cameras.new("chase")
cam_d.sensor_fit = "VERTICAL"
cam_d.angle_y = math.radians(70)
cam_d.clip_end = 1200
cam = bpy.data.objects.new("chase", cam_d)
coll.objects.link(cam)
cam.location = cam_pos
yaw = math.degrees(math.atan2(-pt.x, pt.y))
cam.rotation_euler = (math.radians(90 - CAM_PITCH), 0, math.radians(yaw))
sc.camera = cam

# ---- light + sky --------------------------------------------------------------------------
sun_d = bpy.data.lights.new("sun", "SUN")
sun_d.energy = 3.0
sun_d.color = P.lin("#FFF0D2")[:3]
sun_d.use_shadow = False  # spec: no real-time shadows; blob quads + baked tree discs instead
sun = bpy.data.objects.new("sun", sun_d)
sun.rotation_euler = Vector((0.3, 0.6, -0.75)).to_track_quat("-Z", "Y").to_euler()
coll.objects.link(sun)

w = bpy.data.worlds.new("sky")
sc.world = w
w.use_nodes = True
nt = w.node_tree
nt.nodes.clear()
tc = nt.nodes.new("ShaderNodeTexCoord")
sep = nt.nodes.new("ShaderNodeSeparateXYZ")
ramp_n = nt.nodes.new("ShaderNodeValToRGB")
cr = ramp_n.color_ramp
cr.elements[0].position = 0.0
cr.elements[0].color = P.lin("#D6EEFB")
cr.elements[1].position = 0.42
cr.elements[1].color = P.lin("#4FA9E8")
e = cr.elements.new(0.12)
e.color = P.lin("#93CDF2")
bg = nt.nodes.new("ShaderNodeBackground")
out = nt.nodes.new("ShaderNodeOutputWorld")
nt.links.new(tc.outputs["Generated"], sep.inputs[0])
nt.links.new(sep.outputs["Z"], ramp_n.inputs["Fac"])
nt.links.new(ramp_n.outputs["Color"], bg.inputs["Color"])
nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
bg.inputs["Strength"].default_value = 1.0

try:
    sc.render.engine = "BLENDER_EEVEE_NEXT"
except TypeError as e:
    print(e)
sc.render.resolution_x, sc.render.resolution_y = 1080, 1920
sc.render.resolution_percentage = 100
sc.eevee.taa_render_samples = 32
sc.view_settings.view_transform = "Standard"
sc.view_settings.look = "None"
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).parent / "track_mock.blend"))
print("OUT", OUT, "samples", N, "player_s", S_PLAYER)
