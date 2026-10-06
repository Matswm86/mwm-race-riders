"""Build every MWM Race Riders model, export GLBs to assets/models/, render a check sheet.

blender -b -P docs/mockups/src/export_models.py -- <sheet_raw.png>
Prints one SIZE line per model (bounding box in metres, Godot axes x / y-up / z) and its triangle count.
"""

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).parent))
import rr_parts as P  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
SHEET = argv[0] if argv else str(Path(__file__).parent / "kit_sheet_raw.png")
MODELS = P.ROOT / "assets" / "models"
MODELS.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
mat = P.kit_material("rr_kit", team_hex=P.RIDERS[0]["team"])  # default team = fox red
report = {}


def export(objs, fname, anim=False):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    kw = dict(
        filepath=str(MODELS / f"{fname}.glb"),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_animations=anim,
    )
    if anim:
        kw.update(export_animation_mode="NLA_TRACKS", export_skins=True, export_def_bones=False)
    bpy.ops.export_scene.gltf(**kw)


def dims(objs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        if o.type != "MESH":
            continue
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    d = hi - lo
    return [round(d.x, 2), round(d.z, 2), round(d.y, 2)]  # Godot x, y(up), z(depth)


def tri_count(objs):
    n = 0
    for o in objs:
        if o.type == "MESH":
            n += sum(len(p.vertices) - 2 for p in o.data.polygons)
    return n


# ---- 1. rider (skinned, 3 pose tracks, 6 identity meshes) ---------------------
arm, rmeshes = P.build_rider_rig("rider", mat)
export([arm] + rmeshes, "rider", anim=True)
report["rider"] = {"size": dims(rmeshes[:1]), "tris_body": tri_count(rmeshes[:1]), "tris_id": {m.name: tri_count([m]) for m in rmeshes[1:]}}

# ---- 2. vehicles + kit ----------------------------------------------------------
builders = {
    "bike": P.bike_kit,
    "hoverboard": P.board_kit,
    "boost_pad": P.boost_pad_kit,
    "ramp": P.ramp_kit,
    "swap_gate_bike": lambda: P.swap_gate_kit("bike"),
    "swap_gate_board": lambda: P.swap_gate_kit("board"),
    "finish_arch": P.finish_arch_kit,
    "tree_round": P.tree_round_kit,
    "tree_pine": P.tree_pine_kit,
    "rock": P.rock_kit,
}
objs = {}
for name, fn in builders.items():
    ob = fn().build(name, mat)
    objs[name] = ob
    export([ob], name)
    report[name] = {"size": dims([ob]), "tris": tri_count([ob])}

for k, v in report.items():
    print("SIZE", k, json.dumps(v))

# ---- 3. check sheet: lay everything out and render ------------------------------
for o in list(sc.objects):
    bpy.data.objects.remove(o, do_unlink=True)

coll = sc.collection
place = []
# row A: six riders on bikes, rear three-quarter (what the chase camera sees)
for i, r in enumerate(P.RIDERS):
    m = P.kit_material(f"team_{r['id']}", team_hex=r["team"])
    x = (i - 2.5) * 1.45
    w = P.T(x, 6.0, 0) @ P.R(0, 0, 0)
    P.bike_kit().build(f"bike_{i}", m).matrix_world = w
    P.build_rider_posed(f"r_{i}", r, "bike", m, w)
# row B: board rider, bare board, bare bike, rider in cheer pose, standing rider (front)
mB = P.kit_material("team_bear", team_hex=P.RIDERS[4]["team"])
w = P.T(-3.6, 2.0, 0)
P.board_kit().build("boardB", mB).matrix_world = w
P.build_rider_posed("rB", P.RIDERS[4], "board", mB, w)
P.board_kit().build("board_bare", mat).matrix_world = P.T(-1.5, 2.0, 0)
P.bike_kit().build("bike_bare", mat).matrix_world = P.T(0.2, 2.0, 0)
mC = P.kit_material("team_shark", team_hex=P.RIDERS[2]["team"])
w = P.T(2.0, 2.0, 0)
P.bike_kit().build("bikeC", mC).matrix_world = w
P.build_rider_posed("rC", P.RIDERS[2], "cheer", mC, w)
mD = P.kit_material("team_bobble", team_hex=P.RIDERS[1]["team"])
P.build_rider_posed("rD", P.RIDERS[1], "stand", mD, P.T(3.7, 2.0, 0) @ P.R(0, 0, 200))
# row C: track kit, scaled down 0.25 to fit
small = 0.25
items = [("boost_pad", -4.2), ("ramp", -2.6), ("swap_gate_bike", -0.8), ("swap_gate_board", 1.6), ("finish_arch", 4.1)]
for name, x in items:
    o = builders[name]().build(name + "_s", mat)
    o.matrix_world = P.T(x, -2.0, 0) @ P.S(small)
for name, x in (("tree_round", -4.3), ("tree_pine", -3.2), ("rock", -2.2)):
    o = builders[name]().build(name + "_s", mat)
    o.matrix_world = P.T(x, -4.6, 0) @ P.S(small * 1.2)

# ground
gk = P.Kit()
gk.add(P.quad(40, 40), "meadow", smooth=False)
P.Kit.build(gk, "ground", mat).location = (0, 0, -0.001)

# camera, light, world
cam_d = bpy.data.cameras.new("cam")
cam_d.lens = 50
cam = bpy.data.objects.new("cam", cam_d)
coll.objects.link(cam)
cam.location = (0, -15.5, 9.5)
cam.rotation_euler = (math.radians(62), 0, 0)
sc.camera = cam
sun_d = bpy.data.lights.new("sun", "SUN")
sun_d.energy = 3.2
sun_d.color = P.lin("#FFF2DA")[:3]
sun = bpy.data.objects.new("sun", sun_d)
sun.rotation_euler = (math.radians(50), math.radians(-25), math.radians(-35))
coll.objects.link(sun)
wd = bpy.data.worlds.new("w")
sc.world = wd
wd.use_nodes = True
bg = next(n for n in wd.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Color"].default_value = P.lin("#CFEAFB")
bg.inputs["Strength"].default_value = 0.9
try:
    sc.render.engine = "BLENDER_EEVEE_NEXT"
except TypeError as e:
    print(e)
sc.render.resolution_x, sc.render.resolution_y = 1600, 1200
sc.eevee.taa_render_samples = 32
sc.view_settings.view_transform = "Standard"
sc.render.filepath = SHEET
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).parent / "kit_sheet.blend"))
print("SHEET", SHEET)
