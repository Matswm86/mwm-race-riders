"""Render every rider pose/animation key to a contact sheet for checking.

blender -b --factory-startup assets/_raw/build/rider_rigged.blend -P tools/art/preview_poses.py -- out_dir
"""

import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).parent))
import rr_art as A  # noqa: E402

out = Path(sys.argv[sys.argv.index("--") + 1])
out.mkdir(parents=True, exist_ok=True)
sc = bpy.context.scene
A.cycles(24)
sc.render.resolution_x = 420
sc.render.resolution_y = 420
w = bpy.data.worlds.new("w")
sc.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.6, 0.65, 1)
w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.7
sun = bpy.data.lights.new("sun", "SUN")
sun.energy = 3.5
A.link(bpy.data.objects.new("sun", sun)).rotation_euler = A.deg(50, 10, 30)
bpy.ops.mesh.primitive_plane_add(size=8)
cam = bpy.data.cameras.new("c")
cam.lens = 40
co = A.link(bpy.data.objects.new("c", cam))
sc.camera = co
rig = bpy.data.objects["rider_rig"]
bike = bpy.data.objects.get("bike_ref")
views = {"rear": (1.6, -3.6, 2.2), "side": (3.8, 0.4, 1.4)}
items = [
    ("bike", 0),
    ("cheer", 0),
    ("trick_nohands", 0),
    ("trick_superman", 0),
    ("board", 0),
    ("board_grab", 0),
    ("fall", 6),
    ("fall", 13),
    ("fall", 20),
    ("fall", 27),
    ("lying", 0),
    ("getup", 9),
    ("getup", 17),
    ("getup", 30),
]
for tr in rig.animation_data.nla_tracks:
    tr.mute = True
for i, (name, f) in enumerate(items):
    act = bpy.data.actions[name]
    rig.animation_data.action = act
    sc.frame_set(f)
    hips = rig.pose.bones["hips"].head
    tgt = Vector((hips.x, hips.y, max(0.5, hips.z * 0.8)))
    for vn, loc in views.items():
        if name in ("fall", "lying", "getup"):
            loc = (loc[0] + 0.4, loc[1] + 1.2, loc[2])
        co.location = loc
        co.rotation_euler = (tgt - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = str(out / f"{i:02d}_{name}_{f}_{vn}.png")
        bpy.ops.render.render(write_still=True)
