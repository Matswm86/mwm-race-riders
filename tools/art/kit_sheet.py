"""Lineup render of exported GLBs (imported back from assets/models) for checking.
blender -b --factory-startup -P tools/art/kit_sheet.py -- out.png name1 name2 ...
"""

import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).parent))
import rr_art as A  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :]
out, names = argv[0], argv[1:]
A.reset()
sc = bpy.context.scene
A.cycles(48)
sc.render.resolution_x = 1600
sc.render.resolution_y = 900
w = bpy.data.worlds.new("w")
sc.world = w
w.use_nodes = True
env = w.node_tree.nodes.new("ShaderNodeTexEnvironment")
env.image = bpy.data.images.load(str(A.PH / "hdri" / "alps_field_2k.hdr"))
w.node_tree.links.new(env.outputs["Color"], w.node_tree.nodes["Background"].inputs["Color"])
sc.view_settings.view_transform = "AgX"
bpy.ops.mesh.primitive_plane_add(size=200)
g = bpy.context.active_object
g.data.materials.append(
    A.pbr_material("g", albedo=A.ph_tex("rocky_trail_02", "2k")["albedo"], uv_scale=40)
)
x = 0.0
widths = []
for n in names:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(A.MODELS / f"{n}.glb"))
    new = [o for o in bpy.data.objects if o not in before]
    roots = [o for o in new if o.parent is None]
    sx = A.size_godot(new)[0]
    for r in roots:
        r.location.x += x + sx / 2
    x += sx + 1.0
cx = x / 2
cam = bpy.data.cameras.new("c")
cam.lens = 35
co = A.link(bpy.data.objects.new("c", cam))
d = max(4.0, x * 0.62)
co.location = (cx, -d, d * 0.38)
co.rotation_euler = (Vector((cx, 0, 1.0)) - co.location).to_track_quat("-Z", "Y").to_euler()
sc.camera = co
sun = bpy.data.lights.new("sun", "SUN")
sun.energy = 4.0
A.link(bpy.data.objects.new("sun", sun)).rotation_euler = A.deg(45, 0, 30)
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
