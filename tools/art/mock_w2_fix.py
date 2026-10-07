"""World 2 fix check: re-renders the saved World 2 mock scene with (a) the sky-only goegap HDRI, (b) the level-strata
canyon-wall layer, (c) the mesa ring on the horizon and (d) scanned cliff tops on the canyon walls.

blender -b --factory-startup assets/_raw/build/mock_w2.blend -P tools/art/mock_w2_fix.py -- <out.png> [yaw_deg] [before]
yaw_deg turns the camera left (+) to look at the canyon opening; 'before' renders the old setup from the same view.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).parent))
import rr_art as A  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :]
out = argv[0]
yaw = float(argv[1]) if len(argv) > 1 else 0.0
before = len(argv) > 2 and argv[2] == "before"
sc = bpy.context.scene
cam = sc.camera
if yaw:
    loc = cam.matrix_world.translation.copy()
    cam.matrix_world = Matrix.Translation(loc) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Translation(-loc) @ cam.matrix_world
cam.data.clip_end = 1400

if not before:
    # (a) sky-only HDRI
    env = next(n for n in sc.world.node_tree.nodes if n.type == "TEX_ENVIRONMENT")
    env.image = bpy.data.images.load(str(A.TEX / "world2/sky_goegap_skyonly_2k.hdr"))
    # (b) canyon-wall layer: swap the triplanar wall images in the terrain material
    ter = bpy.data.materials["terrain"]
    for n in ter.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image and "cliff_side" in n.image.name:
            kind = "albedo" if "diffuse" in n.image.name else "normal" if "nor_gl" in n.image.name else "arm"
            n.image = A.load_image(A.TEX / f"world2/terrain_canyon_wall_{kind}.jpg", kind != "albedo")

    def imp(name):
        before_objs = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(A.MODELS / f"{name}.glb"))
        return [o for o in bpy.data.objects if o not in before_objs and o.type == "MESH"]

    # (c) mesa ring: three 120-degree segments round the camera's track position, scale 1.25
    c = cam.matrix_world.translation.copy()
    base = imp("world2/mesa_backdrop")
    for k in range(3):
        objs = base if k == 0 else [o.copy() for o in base]
        for o in objs:
            if k:
                sc.collection.objects.link(o)
            o.matrix_world = Matrix.Translation(Vector((c.x, c.y, c.z - 30))) @ Matrix.Rotation(math.radians(120 * k), 4, "Z") @ Matrix.Scale(1.25, 4)
            o.visible_shadow = False
    # (d) cliff tops along both canyon walls
    terrain = bpy.data.objects["terrain"]
    me = terrain.data
    import random

    rnd = random.Random(3)
    cl = [imp("world2/canyon_cliff_a"), imp("world2/canyon_cliff_b")]
    fwd = (cam.matrix_world.to_3x3() @ Vector((0, 0, -1)))
    fwd.z = 0
    fwd.normalize()
    rt = Vector((fwd.y, -fwd.x, 0))
    for i in range(6):
        d = 45 + i * 50
        for side in (-1, 1):
            if side > 0 and 110 < d < 170:
                continue  # keep the water tower in view
            p = c + fwd * d + rt * side * rnd.uniform(19, 23)  # against the wall foot, breaking its line
            # drop onto the terrain
            hit, loc, *_ = sc.ray_cast(bpy.context.evaluated_depsgraph_get(), Vector((p.x, p.y, p.z + 300)), Vector((0, 0, -1)))
            if not hit:
                continue
            src = cl[(i + (side > 0)) % 2]
            for s in src:
                o = s.copy()
                sc.collection.objects.link(o)
                o.matrix_world = Matrix.Translation(loc - Vector((0, 0, 2.5))) @ Matrix.Rotation(rnd.uniform(0, 6.28), 4, "Z") @ Matrix.Scale(rnd.uniform(0.5, 0.75), 4)
    for src in cl:
        for s in src:
            s.hide_render = True

sc.render.filepath = out
bpy.ops.render.render(write_still=True)
