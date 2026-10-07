"""Check renders of exported GLBs (imported back from assets/models, so this proves the files, not the build scene).
One 3/4 view per model, framed on its bounds, under the world's HDRI. Tiles are joined by sheet36.py.

blender -b --factory-startup -P tools/art/preview36.py -- <hdri file name> <out dir> world3/ice_cave world3/... [--night]
"""

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).parent))
import rr_art as A  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :]
night = "--night" in argv
argv = [a for a in argv if a != "--night"]
hdri, out_dir, names = argv[0], Path(argv[1]), argv[2:]
out_dir.mkdir(parents=True, exist_ok=True)


def setup():
    A.reset()
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        sc.render.engine = "BLENDER_EEVEE"
    sc.eevee.taa_render_samples = 32
    sc.render.resolution_x = 480
    sc.render.resolution_y = 480
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    env = w.node_tree.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(str(A.PH / "hdri" / hdri))
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Strength"].default_value = 4.0 if night else 1.0
    w.node_tree.links.new(env.outputs["Color"], bg.inputs["Color"])
    sc.view_settings.view_transform = "AgX"
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 0.6 if night else 3.0
    sun.angle = math.radians(2)
    A.link(bpy.data.objects.new("sun", sun)).rotation_euler = A.deg(50, 0, -35)
    bpy.ops.mesh.primitive_plane_add(size=4000, location=(0, 0, -0.01))
    g = bpy.context.active_object
    m = bpy.data.materials.new("g")
    m.use_nodes = True
    next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.18, 0.18, 0.18, 1)
    g.data.materials.append(m)


for n in names:
    setup()
    sc = bpy.context.scene
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(A.MODELS / f"{n}.glb"))
    new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for o in new:
        for c in o.bound_box:
            p = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
    ctr = (lo + hi) / 2
    r = max((hi - lo).length / 2, 0.3)
    cam = bpy.data.cameras.new("c")
    cam.lens = 50
    cam.clip_end = 20000
    cam.clip_start = 0.01 * r
    co = A.link(bpy.data.objects.new("c", cam))
    d = Vector((0.55, -1.0, 0.45)).normalized() * r * 2.9
    co.location = ctr + d
    co.rotation_euler = (ctr - co.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = co
    sc.render.filepath = str(out_dir / (n.replace("/", "__") + ".png"))
    bpy.ops.render.render(write_still=True)
