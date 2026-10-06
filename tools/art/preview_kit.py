"""Import the exported GLBs and render check views (proves the GLBs, not the build scene).

blender -b --factory-startup -P tools/art/preview_kit.py -- out.png [rider_action] [view] [livery]
"""

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).parent))
import rr_art as A  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :]
out = argv[0]
action = argv[1] if len(argv) > 1 else "bike"
view = argv[2] if len(argv) > 2 else "rear"
liv = argv[3] if len(argv) > 3 else "r1"
A.reset()
sc = bpy.context.scene
A.cycles(48)
sc.render.resolution_x = 900
sc.render.resolution_y = 900
w = bpy.data.worlds.new("w")
sc.world = w
w.use_nodes = True
env = w.node_tree.nodes.new("ShaderNodeTexEnvironment")
env.image = bpy.data.images.load(str(A.PH / "hdri" / "alps_field_2k.hdr"))
w.node_tree.links.new(env.outputs["Color"], w.node_tree.nodes["Background"].inputs["Color"])
sc.view_settings.view_transform = "AgX"
bpy.ops.mesh.primitive_plane_add(size=20)
g = bpy.context.active_object
g.data.materials.append(
    A.pbr_material(
        "g",
        **{
            k: v
            for k, v in {
                "albedo": A.ph_tex("rocky_trail_02", "2k")["albedo"],
                "normal": A.ph_tex("rocky_trail_02", "2k")["normal"],
            }.items()
        },
        uv_scale=5,
    )
)


def imp(name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(A.MODELS / f"{name}.glb"))
    return [o for o in bpy.data.objects if o not in before]


rider = imp("rider")
rig = next(o for o in rider if o.type == "ARMATURE")
rig.animation_data_create()
rig.animation_data.action = bpy.data.actions[action]
for t in rig.animation_data.nla_tracks:
    t.mute = True
sc.frame_set(0)
if (
    action not in ("board", "board_grab", "lying", "getup")
    and "bike" in argv[1:]
    or action in ("bike", "cheer", "trick_nohands", "trick_superman")
):
    imp("bike")
if liv != "r1":
    for o in bpy.data.objects:
        for s in getattr(o, "material_slots", []):
            for n in s.material.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image and "_r1_albedo" in n.image.name:
                    pass
cams = {
    "rear": ((0.0, -4.8, 2.8), (0, 0.6, 1.0), 35),
    "q": ((2.2, -2.6, 1.6), (0, 0, 0.8), 45),
    "side": ((3.4, 0.0, 1.1), (0, 0, 0.75), 45),
    "front": ((1.2, 3.2, 1.3), (0, 0, 0.9), 50),
    "close": ((0.7, -1.8, 1.7), (0, 0, 1.1), 50),
}
loc, tgt, lens = cams[view]
cam = bpy.data.cameras.new("c")
cam.lens = lens
co = A.link(bpy.data.objects.new("c", cam))
co.location = loc
co.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
sc.camera = co
sun = bpy.data.lights.new("sun", "SUN")
sun.energy = 4.0
sun.angle = math.radians(1.5)
A.link(bpy.data.objects.new("sun", sun)).rotation_euler = A.deg(42, 0, 150)
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
