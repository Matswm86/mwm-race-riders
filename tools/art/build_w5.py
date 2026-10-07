"""World 5 "Regnskogen / Rainforest": waterfall drop, river ford, logs, branch piles, rope bridge, buttress tree,
stone ruins, jungle trees and undergrowth (impostor cards).

blender -b --factory-startup -P tools/art/build_w5.py -- [names...]
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from w36_lib import *  # noqa: F401,F403,E402

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
W = 5
TD = A.TEX / "world5"


def wet_rock_m(name="rock"):
    return slope_mat(name, tset(W, "forest_moss"), tset(W, "mossy_rock"), thresh=0.6, soft=0.12,
                     scale_flat=0.3, scale_steep=0.2, rough_steep=0.3, rough_flat=0.6, noise_scale=0.6)


# ---------------------------------------------------------------- signature: waterfall drop
def waterfall_rock():
    """Rock lip and 8 m cliff of the waterfall drop. The track crosses the dry centre of the lip (|x| < 3, at
    z 0, origin); the river pours over both sides (3 < |x| < 12) into the pool 8 m below (+Y)."""
    A.reset()
    xs = np.linspace(-16, 16, 49)
    prof = [(-10, 0.2), (-4, 0.1), (-1.0, 0.0), (0.0, 0.0), (0.4, -0.5), (0.6, -2.5), (0.9, -5.0), (1.4, -7.4),
            (2.4, -8.3), (5.0, -8.6)]
    verts, faces = [], []
    for x in xs:
        chan = 0.0 if abs(x) < 3.0 else -0.35 * math.sin(min(1.0, (abs(x) - 3) / 2) * math.pi / 2)
        if abs(x) > 12.5:
            chan = 0.6 * min(1.0, (abs(x) - 12.5) / 2) + 0.0
        for y, z in prof:
            zz = z + (chan if y <= 0.0 else 0.0)
            yy = y + (0.6 if (y > 0 and abs(x) > 3) else 0.0)  # falls cut back behind the dry lip
            verts.append((x, yy, zz + (1.5 * min(1.0, (abs(x) - 12.5) / 2) if abs(x) > 12.5 and y > 0 else 0)))
    npf = len(prof)
    for i in range(len(xs) - 1):
        for k in range(npf - 1):
            a = i * npf + k
            faces.append((a, a + 1, a + npf + 1, a + npf))
    o = A.mesh_obj("waterfall_rock", verts, faces)
    smooth(o)
    for v in o.data.vertices:
        if v.co.z < -0.3:
            d = noise.fractal(Vector((v.co.x / 2.5, v.co.z / 2.5, 0.7)), 0.55, 2.0, 4, noise_basis="PERLIN_ORIGINAL")
            v.co.y += d * 0.9
    o.data.materials.append(wet_rock_m())
    bake(o, W, "waterfall_rock", 1024, ao_dist=1.5)
    done(o, W, "waterfall_rock", "lip at origin; dry riding line |x|<3; falls at 3<|x|<12; pool 8.4 m down")


def waterfall_water():
    """Two water curtains over the lip (3 < |x| < 12) + foam skirt at the pool. UV v runs with the flow: scroll
    v at about 1.6 tiles/s (Godot: UV1 offset in a tiny shader or StandardMaterial3D uv1_offset by script)."""
    A.reset()
    verts, faces, uvs = [], [], []
    path = [(0.0, -0.32), (0.55, -0.6), (0.9, -2.0), (1.15, -4.5), (1.35, -7.0), (1.5, -8.3)]
    for side in (-1, 1):
        base = len(verts)
        xs = np.linspace(3.2, 12.0, 12)
        for i, ax in enumerate(xs):
            x = side * ax
            for k, (y, z) in enumerate(path):
                verts.append((x, y + 0.6 + 0.05 * math.sin(ax * 2), z))
                uvs.append((ax / 4.0, -k / (len(path) - 1) * 2.0))
        n = len(path)
        for i in range(len(xs) - 1):
            for k in range(n - 1):
                a = base + i * n + k
                f = (a, a + 1, a + n + 1, a + n)
                faces.append(f if side > 0 else f[::-1])
        # foam skirt where the curtain hits the pool
        base = len(verts)
        for i, ax in enumerate(xs):
            for k, (dy, dz) in enumerate(((1.4, -8.25), (4.5, -8.33))):
                verts.append((side * ax, dy + 0.6, dz))
                uvs.append((ax / 4.0, k * 0.8))
        for i in range(len(xs) - 1):
            a = base + i * 2
            f = (a, a + 1, a + 3, a + 2)
            faces.append(f if side < 0 else f[::-1])
    o = A.mesh_obj("waterfall_water", verts, faces, uvs=None)
    me = o.data
    uvl = me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        for li in p.loop_indices:
            uvl.data[li].uv = uvs[me.loops[li].vertex_index]
    smooth(o)
    m = A.pbr_material("waterfall_water", albedo=TD / "waterfall_water_albedo.png", normal=TD / "water_ripple_normal.png",
                       rough=0.15, alpha_clip=False)
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    t = next(n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image.name.startswith("waterfall"))
    nt.links.new(t.outputs["Alpha"], b.inputs["Alpha"])
    m.surface_render_method = "BLENDED"
    m.use_backface_culling = False
    me.materials.append(m)
    done(o, W, "waterfall_water", "alpha blend, cull off, UV-scroll v; no shadow")


def pool_water():
    """Pool surface under the falls, 30 x 34 m, z = -8.35 (relative to the lip). Dark glossy water with the ripple
    normal (same look as the game's river material: Color(0.05, 0.08, 0.07), roughness 0.06)."""
    A.reset()
    o = grid("pool_water", 30.0, 34.0, 8, 8)
    for v in o.data.vertices:
        v.co.y += 17 + 1.4
        v.co.z = -8.35
    me = o.data
    uvl = me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        for li in p.loop_indices:
            c = me.vertices[me.loops[li].vertex_index].co
            uvl.data[li].uv = (c.x / 6, c.y / 6)
    m = A.pbr_material("pool_water", normal=TD / "water_ripple_normal.png", rough=0.06,
                       color=(0.01, 0.025, 0.02, 1))
    me.materials.append(m)
    done(o, W, "pool_water", "opaque dark glossy water, no shadow")


# ---------------------------------------------------------------- hindrances
def river_ford():
    """Patch (bike x0.85, board immune): shallow ford water 12 m across x 18 m along over river stones, glossy,
    vertex-alpha edge. The stones show through because they are baked into the albedo (no refraction needed)."""
    A.reset()

    def a(u, v):
        return (1 - (abs(u) ** 3 + abs(v) ** 6)) * 2.5

    o = grid("river_ford", 12.0, 18.0, 16, 24, hfn=lambda u, v: 0.04 + 0.01 * math.sin(u * 9 + v * 13), afn=a)
    o.data.materials.append(mat("ford", tset(W, "river_stones"), scale=0.35, tint=(0.42, 0.5, 0.46), rough=0.05,
                                normal_strength=0.35))
    bake(o, W, "river_ford", 512, ao_dist=0.05, ao_k=0.0, vertex_alpha=True)
    done(o, W, "river_ford", "transparent water patch (vertex alpha); put the river_stones layer under it")


def log_hop():
    ph_decimated("dead_tree_trunk", None, W, "log_hop", 1400, scale=(3.6, 2.2, 2.2), tint=(0.78, 0.95, 0.62),
                 rough_mul=0.7, note="Hop: mossy fallen log across the track (11 m along X, 0.6 m high)")


def branch_pile():
    def lay(objs):
        rnd = random.Random(4)
        base = list(objs)
        for k in range(2):
            for o in base:
                c = o.copy()
                c.data = o.data
                bpy.context.scene.collection.objects.link(c)
                objs.append(c)
        for i, o in enumerate(objs):
            o.rotation_euler = (rnd.uniform(-0.3, 0.3), rnd.uniform(-0.25, 0.25), rnd.uniform(0, 6.28))
            o.location = (rnd.uniform(-0.6, 0.6), rnd.uniform(-0.5, 0.5), 0.12 * (i % 3) + rnd.uniform(0, 0.15))
        for o in objs:
            o.scale = (1.7, 1.7, 1.7)
        bpy.context.view_layer.update()
        for o in objs:
            o.data = o.data.copy()
            A.apply_xform(o)

    ph_decimated("dry_branches_medium_01", None, W, "branch_pile", 1800, layout=lay, tint=(0.75, 0.72, 0.65),
                 note="Block: fallen-branch pile ~2.4 m wide, 0.8 m high")


def rope_bridge():
    """Rope suspension bridge for the bridge route: 36 m span along Y, 4.4 m wide plank deck, 0.9 m sag, hemp
    hand ropes and hangers, timber A-frame towers at both ends. Deck top at z 0 at both ends."""
    A.reset()
    planks = mat("planks", A.ph_tex("weathered_planks"), scale=0.6, rot=90, tint=(0.75, 0.72, 0.66))
    timber = mat("timber", A.ph_tex("pine_bark"), scale=0.6, tint=(0.6, 0.55, 0.5))
    rope = mat("rope", A.ph_tex("weathered_planks"), scale=3.0, tint=(0.75, 0.62, 0.42), rough=0.9)
    L, Wd, sag = 36.0, 4.4, 0.9
    parts = []

    def deck_z(y):
        t = y / L
        return -sag * 4 * t * (1 - t)

    n = int(L / 0.32)
    for i in range(n):
        y = (i + 0.5) * L / n
        parts.append(cube(f"pl{i}", (Wd, 0.27, 0.05), (0, y, deck_z(y) - 0.025), planks, rot=(0, 0, 0)))
    for s in (-1, 1):
        x = s * (Wd / 2 + 0.05)
        low = [Vector((x, y, deck_z(y) - 0.05)) for y in np.linspace(0, L, 25)]
        parts.append(tube(f"low{s}", low, 0.035, 6, rope))
        hand = [Vector((x, y, 1.15 + deck_z(y) * 0.55 + 0.25 * (1 - 4 * (y / L) * (1 - y / L)))) for y in np.linspace(0, L, 25)]
        parts.append(tube(f"hand{s}", hand, 0.04, 6, rope))
        for k in range(1, 24):
            y = L * k / 24
            parts.append(tube(f"hg{s}{k}", [Vector((x, y, deck_z(y) - 0.05)), Vector((x, y, 1.15 + deck_z(y) * 0.55 + 0.25 * (1 - 4 * (y / L) * (1 - y / L))))], 0.015, 4, rope, cap=False))
        for y0 in (-0.6, L + 0.6):
            parts.append(cyl(f"post{s}{y0}", 0.17, 4.0, (x * 1.08, y0, 1.6), timber, 8))
            parts.append(tube(f"anch{s}{y0}", [Vector((x * 1.08, y0, 3.3)), Vector((x * 1.5, y0 + (-3.5 if y0 < 0 else 3.5), -0.3))], 0.035, 6, rope))
    for y0 in (-0.6, L + 0.6):
        parts.append(cyl(f"beam{y0}", 0.13, Wd + 1.0, (0, y0, 3.45), timber, 8, rot=(0, math.pi / 2, 0)))
    o = join(parts, "rope_bridge")
    bake(o, W, "rope_bridge", 1024, ao_dist=0.6)
    done(o, W, "rope_bridge", "span along +Y from the origin; deck 4.4 m wide (narrow route)")


# ---------------------------------------------------------------- landmarks
def buttress_tree():
    """Giant rainforest tree: 2.4 m trunk rising 30 m into the canopy, seven plank buttress roots (4.5 m out,
    4 m up the trunk), moss on the up-facing surfaces. Crown is left to the canopy impostors."""
    A.reset()
    bark = slope_mat("bark", tset(W, "forest_moss"), A.ph_tex("bark_brown_02"), thresh=0.45, soft=0.2,
                     scale_flat=0.5, scale_steep=0.35, noise_scale=0.8, noise_amt=0.25, tint_steep=(0.5, 0.47, 0.42),
                     tint_flat=(0.7, 0.8, 0.6))
    parts = []
    pts = [Vector((0.25 * math.sin(z / 7), 0.2 * math.cos(z / 9), z)) for z in np.linspace(-0.5, 30, 14)]
    trunk = tube("trunk", pts, 1.2, 14, bark, cap=True, r_end=0.75)
    parts.append(trunk)
    rnd = random.Random(2)
    for k in range(7):
        a = 2 * math.pi * k / 7 + rnd.uniform(-0.2, 0.2)
        reach = rnd.uniform(4.5, 6.0)
        hgt = rnd.uniform(5.0, 7.0)
        # fin = thin curved wedge (profile in the radial plane), slight S-bend sideways
        prof = []
        nseg = 8
        for i in range(nseg + 1):
            t = i / nseg
            r = 0.9 + t * reach
            z = hgt * (1 - t) ** 2.2
            side = 0.35 * math.sin(t * math.pi * 1.5)
            prof.append((r, z, side))
        verts, faces = [], []
        for (r, z, side) in prof:
            c, s = math.cos(a), math.sin(a)
            px, py = -s, c
            for th, zz in ((-0.2, z), (0.2, z), (0.3, -0.3), (-0.3, -0.3)):
                w = th * (1 - 0.5 * (r / (0.9 + reach)))
                verts.append((c * r + px * (w + side), s * r + py * (w + side), zz))
        for i in range(nseg):
            b0 = i * 4
            for q in range(4):
                faces.append((b0 + q, b0 + (q + 1) % 4, b0 + 4 + (q + 1) % 4, b0 + 4 + q))
        fin = A.mesh_obj(f"fin{k}", verts, faces)
        fin.data.materials.append(bark)
        smooth(fin)
        parts.append(fin)
    for k in range(4):  # a few broken branch stubs
        z = rnd.uniform(9, 26)
        a = rnd.uniform(0, 6.28)
        p0 = Vector((math.cos(a) * 0.8, math.sin(a) * 0.8, z))
        parts.append(tube(f"stub{k}", [p0, p0 + Vector((math.cos(a) * 2.2, math.sin(a) * 2.2, 1.2))], 0.28, 8, bark, r_end=0.12))
    o = join(parts, "buttress_tree")
    displace(o, 0.05, 0.4, seed=7)
    bake(o, W, "buttress_tree", 1024, ao_dist=1.2)
    done(o, W, "buttress_tree", "landmark tree near the track; casts shadow on Høy")


def stone_ruin():
    """Moss-covered stone ruin: two broken wall runs of dressed blocks, a doorway with a lintel, a broken column,
    fallen blocks. 9 x 5 x 4.2 m."""
    A.reset()
    m = slope_mat("stone", tset(W, "forest_moss"), tset(W, "mossy_rock"), thresh=0.55, soft=0.15,
                  scale_flat=0.5, scale_steep=0.35, rough_steep=0.5, tint_steep=(0.62, 0.66, 0.58),
                  tint_flat=(0.6, 0.72, 0.5), noise_scale=1.2, noise_amt=0.3)
    rnd = random.Random(12)
    parts = []

    def wall(x0, x1, y, hmax, broken_at=None):
        x = x0
        row = 0
        while row < 8:
            z = row * 0.5
            x = x0 + (0.35 if row % 2 else 0)
            while x < x1:
                bl = rnd.uniform(0.7, 1.5)
                xe = min(x + bl, x1)
                hcap = hmax * (0.55 + 0.45 * math.cos((x - x0) / (x1 - x0) * 2.4)) if broken_at else hmax
                if z + 0.5 <= hcap and (broken_at is None or not (broken_at[0] < x < broken_at[1] and z > broken_at[2])):
                    hh = rnd.uniform(0.4, 0.5)
                    parts.append(cube(f"b{len(parts)}", (xe - x - rnd.uniform(0.02, 0.09), rnd.uniform(0.55, 0.7), hh),
                                      ((x + xe) / 2, y + rnd.uniform(-0.07, 0.07), z + hh / 2), m, bevel=0.09,
                                      rot=(rnd.uniform(-0.04, 0.04), rnd.uniform(-0.04, 0.04), rnd.uniform(-0.06, 0.06))))
                x = xe
            row += 1

    wall(-4.5, -0.8, 0.0, 3.8, broken_at=(-3.0, -1.5, 2.4))
    wall(0.8, 4.5, 0.0, 2.6, broken_at=(2.5, 4.5, 1.4))
    for s in (-1, 1):  # door jambs
        parts.append(cube(f"jamb{s}", (0.5, 0.7, 2.6), (s * 0.55, 0, 1.3), m, bevel=0.05))
    parts.append(cube("lintel", (2.2, 0.75, 0.55), (0, 0, 2.88), m, bevel=0.06, rot=(0, 0.04, 0)))
    for k in range(3):  # column drums, the top one fallen
        parts.append(cyl(f"drum{k}", 0.42, 0.7, (3.6, 2.4, 0.35 + 0.72 * k), m, 14) if k < 2 else
                     cyl(f"drum{k}", 0.42, 0.7, (4.6, 3.0, 0.42), m, 14, rot=(math.pi / 2, 0, 0.6)))
    for k in range(6):
        parts.append(cube(f"fall{k}", (rnd.uniform(0.6, 1.1), 0.6, 0.45),
                          (rnd.uniform(-4, 4), rnd.uniform(-2.2, -0.8), 0.18),
                          m, bevel=0.07, rot=(rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), rnd.uniform(0, 3))))
    o = join(parts, "stone_ruin")
    displace(o, 0.05, 0.35, seed=3)
    decimate_to(o, 2600)
    bake(o, W, "stone_ruin", 1024, ao_dist=0.6)
    done(o, W, "stone_ruin", "front faces -Y")


# ---------------------------------------------------------------- vegetation (cards) and scenery
def tree_jungle_a():
    impostor("island_tree_01", ["island_tree_01_LOD0"], W, "tree_jungle_a", n=4, cell=(512, 512), scale=4.6,
             note="canopy tree ~23 m, 4-plane impostor (8 tris)")


def tree_jungle_b():
    impostor("island_tree_02", ["island_tree_02_LOD0"], W, "tree_jungle_b", n=4, cell=(512, 512), scale=5.2,
             note="canopy tree ~18 m, 4-plane impostor (8 tris)")


def _cluster(objs, spread=0.35, seed=1):
    rnd = random.Random(seed)
    for i, o in enumerate(objs):
        a = 2 * math.pi * i / max(1, len(objs))
        o.location = (math.cos(a) * spread * rnd.uniform(0.3, 1), math.sin(a) * spread * rnd.uniform(0.3, 1), 0)
        o.rotation_euler = (0, 0, rnd.uniform(0, 6.28))


def plant_calathea():
    impostor("calathea_orbifolia_01", None, W, "plant_calathea", n=3, cell=(512, 512), scale=2.6,
             layout=lambda objs: _cluster(objs, 0.5, 3), note="broad-leaf undergrowth ~1.1 m, 3-plane card")


def plant_anthurium():
    impostor("anthurium_botany_01", None, W, "plant_anthurium", n=3, cell=(512, 512), scale=2.2,
             layout=lambda objs: _cluster(objs, 0.6, 5), note="undergrowth ~1.2 m, 3-plane card")


def shrub_jungle():
    impostor("pachira_aquatica_01", None, W, "shrub_jungle", n=3, cell=(512, 512), scale=2.4,
             layout=lambda objs: _cluster(objs, 0.5, 8), note="tropical shrub/sapling ~4 m, 3-plane card")


def buttress_tree_card():
    card_of(lambda: import_glb(A.MODELS / "world5/buttress_tree.glb"), W, "buttress_tree_card", n=2, cell=(512, 1024))


ALL = {f.__name__: f for f in (waterfall_rock, waterfall_water, pool_water, river_ford, log_hop, branch_pile,
                               rope_bridge, buttress_tree, stone_ruin, tree_jungle_a, tree_jungle_b, plant_calathea,
                               plant_anthurium, shrub_jungle, buttress_tree_card)}

if __name__ == "__main__":
    run(ALL, argv)
