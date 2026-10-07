"""World 4 "Askefjellet / Ash Mountain": steam-vent launch, ash dunes, falling rocks, lava-crust ridges,
crater cone, basalt columns, research station, lava field (glow only behind the rails), scenery.

blender -b --factory-startup -P tools/art/build_w4.py -- [names...]
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from w36_lib import *  # noqa: F401,F403,E402

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
W = 4


def basalt_m(name="basalt", scale=0.3):
    return mat(name, tset(W, "basalt"), scale=scale)


def ash_m(name="ash", scale=0.3, kind="ash_soft"):
    return mat(name, tset(W, kind), scale=scale)


def crust_m(name="crust", scale=0.35):
    return mat(name, tset(W, "lava_crust"), scale=scale)


# ---------------------------------------------------------------- signature + hindrance: steam vent
def steam_vent():
    """Fumarole mound 3.6 m across, 0.45 m high, with a 0.7 m throat; sulphur crust round the mouth.
    The puff is particles (fx_steam_puff.png); this mesh is the rideable mound."""
    A.reset()
    na, nr = 40, 14
    verts, faces = [(0.0, 0.0, -0.35)], []
    for j in range(1, nr + 1):
        r = 1.8 * (j / nr) ** 1.2
        for i in range(na):
            a = 2 * math.pi * i / na
            wob = 1 + 0.08 * math.sin(3 * a) + 0.05 * math.sin(7 * a + 1)
            rr = r * wob
            if r < 0.35:
                z = -0.35 + (r / 0.35) * 0.75
            else:
                z = 0.45 * (1 - ((r - 0.35) / 1.45) ** 1.6)
            verts.append((rr * math.cos(a), rr * math.sin(a), z))
    for i in range(na):
        faces.append((0, 1 + i, 1 + (i + 1) % na))
    for j in range(nr - 1):
        for i in range(na):
            a = 1 + j * na + i
            b = 1 + j * na + (i + 1) % na
            faces.append((a, a + na, b + na, b))
    o = A.mesh_obj("steam_vent", verts, faces)
    smooth(o)
    displace(o, 0.06, 0.3, seed=2)
    o.data.materials.append(crust_m("crust", 0.6))
    o.data.materials.append(mat("sulphur", tset(W, "ash_soft"), scale=0.8, tint=(1.9, 1.55, 0.55), rough=0.85))
    o.data.materials.append(basalt_m("throat", 0.8))
    for p in o.data.polygons:
        r = math.hypot(p.center.x, p.center.y)
        if r < 0.32:
            p.material_index = 2
        elif r < 0.62 + 0.15 * math.sin(math.atan2(p.center.y, p.center.x) * 5):
            p.material_index = 1
    bake(o, W, "steam_vent", 512, ao_dist=0.4)
    done(o, W, "steam_vent", "rideable mound; puff = fx_steam_puff particles every 2 s")


def ash_dune():
    """Patch x0.88: soft grey ash dune across the track, 15 m across x 4.5 m along, 0.3 m high."""
    A.reset()

    def h(u, v):
        e = max(abs(u) ** 2.2, abs(v) ** 4)
        return 0.3 * max(0.0, 1 - e) * (0.8 + 0.2 * math.sin(u * 5)) + 0.01 * math.sin(v * 40 + u * 9)

    o = grid("ash_dune", 15.0, 4.5, 20, 12, hfn=h, afn=lambda u, v: (1 - max(abs(u) ** 2.2, abs(v) ** 4)) * 3.0)
    o.data.materials.append(ash_m("ash", 0.35))
    bake(o, W, "ash_dune", 512, ao_dist=0.2, ao_k=0.4, vertex_alpha=True)
    done(o, W, "ash_dune", "vertex alpha = edge fade")


def falling_rock_a():
    ph_decimated("moon_rock_01", ["moon_rock_01_LOD0"], W, "falling_rock_a", 500, scale=6.0, sat=0.2,
                 tint=(0.17, 0.155, 0.15), note="Roller from the uphill side; spin about the centre (0, 0.25, 0)")


def falling_rock_b():
    ph_decimated("moon_rock_03", ["moon_rock_03_LOD0"], W, "falling_rock_b", 500, scale=9.0, sat=0.2,
                 tint=(0.2, 0.15, 0.13), note="Roller; spin about the centre (0, 0.27, 0)")


def lava_crust_ridge():
    """Hop: a ropy pahoehoe crust ridge across the track, 11 m across x 1.6 m along, 0.4 m high, cooled (no glow)."""
    A.reset()

    def h(u, v):
        x = u * 5.5
        core = 0.4 * math.exp(-((v * 0.8 / 0.55) ** 2)) * (0.85 + 0.15 * math.sin(x * 1.3))
        ropes = 0.035 * math.sin(v * 9 + 2.5 * math.sin(x * 0.9)) * math.exp(-((v / 0.9) ** 2))
        taper = min(1.0, (1 - abs(u)) * 6)
        return (core + ropes) * taper - 0.03

    o = grid("lava_crust_ridge", 11.0, 1.6, 44, 14, hfn=h)
    displace(o, 0.03, 0.15, seed=5, axis=(0, 0, 1))
    o.data.materials.append(crust_m("crust", 0.7))
    bake(o, W, "lava_crust_ridge", 512, ao_dist=0.3)
    done(o, W, "lava_crust_ridge", "Hop; lies across the track, cooled crust, no emission")


# ---------------------------------------------------------------- landmarks
def crater_cone():
    """Far landmark: smoking cinder cone, 900 m across, 270 m high with a summit crater. Place 600-900 m out.
    Plume = smoke cards/particles (fx_smoke_plume.png), not geometry."""
    A.reset()
    na, nr = 72, 26
    verts, faces = [], []
    for j in range(nr):
        r = 450 * (j / (nr - 1))
        for i in range(na):
            a = 2 * math.pi * i / na
            if r < 70:
                z = 268 - 70 * (1 - (r / 70) ** 2)  # bowl
            elif r < 85:
                z = 268 + 4 * math.sin((r - 70) / 15 * math.pi)
            else:
                z = 268 * (1 - (r - 85) / 365) ** 1.25
            gully = noise.noise(Vector((math.cos(a) * 4, math.sin(a) * 4, r / 160)))
            z += gully * 12 * min(1.0, r / 120) * (1 - r / 470)
            verts.append((r * math.cos(a), r * math.sin(a), z))
    for j in range(nr - 1):
        for i in range(na):
            a = j * na + i
            b = j * na + (i + 1) % na
            faces.append((a, b, b + na, a + na))
    o = A.mesh_obj("crater_cone", verts, faces)
    smooth(o)
    A.activate(o)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.5)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    o.data.materials.append(slope_mat("cone", tset(W, "ash_soft"), tset(W, "basalt"), thresh=0.86, soft=0.06,
                                      scale_flat=0.05, scale_steep=0.04, noise_scale=0.01, noise_amt=0.06,
                                      tint_flat=(0.5, 0.46, 0.43), tint_steep=(0.8, 0.75, 0.72)))
    bake(o, W, "crater_cone", 1024, tile=25.0, ao_dist=60.0, ao_k=0.6)
    done(o, W, "crater_cone", "far landmark; no shadow; fogged; smoke = cards")


def basalt_columns():
    """Columnar basalt outcrop: 26 hexagonal columns (0.8-1.0 m across, 1.5-8.5 m tall) stepped like an
    organ, ash dust on the tops. 7 x 6 m footprint."""
    A.reset()
    rnd = random.Random(7)
    parts = []
    m = slope_mat("basalt", tset(W, "ash_soft"), tset(W, "basalt"), thresh=0.8, soft=0.1, scale_flat=0.6,
                  scale_steep=0.35, tint_flat=(0.8, 0.78, 0.76))
    k = 0
    for row in range(-3, 4):
        for col in range(-2, 3):
            x = col * 0.88 + (row % 2) * 0.44
            y = row * 0.76
            if rnd.random() < 0.15:
                continue
            hgt = 1.5 + 7.0 * math.exp(-((x + 1.2) ** 2) / 6) * (0.75 + 0.25 * rnd.random()) * (1 - abs(y) / 4)
            bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.47 * rnd.uniform(0.92, 1.05), depth=hgt,
                                                location=(x, y, hgt / 2 - 0.3), rotation=(0, 0, rnd.uniform(-0.1, 0.1)))
            c = bpy.context.active_object
            c.data.materials.append(m)
            # broken, slanted top
            for v in c.data.vertices:
                if v.co.z > 0:
                    v.co.z += (v.co.x * rnd.uniform(-0.25, 0.25) + v.co.y * rnd.uniform(-0.25, 0.25))
            for p in c.data.polygons:
                p.use_smooth = False
            parts.append(c)
            k += 1
    o = join(parts, "basalt_columns")
    bv = o.modifiers.new("b", "BEVEL")
    bv.width = 0.03
    bv.segments = 1
    A.apply_all(o)
    bake(o, W, "basalt_columns", 1024, ao_dist=0.8)
    done(o, W, "basalt_columns", f"{k} columns")


def research_station():
    """Volcano research station: two white instrument modules on steel stilts, steps, a 12 m antenna mast with
    guy lines, a solar panel frame and a weather mast. 14 x 8 x 13 m."""
    A.reset()
    g = gray_tex(A.ph_tex("container_side"), "container_side", gain=1.0)
    paint = mat("paint", g, scale=0.5, tint=(1.9, 1.9, 1.85), rough=0.45)
    paint2 = mat("paint2", g, scale=0.5, tint=(2.0, 0.62, 0.2), rough=0.45)
    steel = flat("steel", "#6E7176", rough=0.45, metal=0.9)
    dark = flat("dark", "#1C1E22", rough=0.5)
    glass = flat("glass", "#202A33", rough=0.08)
    solar = flat("solar", "#18263A", rough=0.15, metal=0.3)
    grate = mat("grate", A.ph_tex("metal_plate"), scale=1.0, tint=(0.8, 0.8, 0.8), metal=0.8)
    parts = []
    for k, (x, y, pm) in enumerate(((-3.2, 0.0, paint), (3.4, 0.6, paint2))):
        parts.append(cube(f"mod{k}", (6.0, 2.5, 2.6), (x, y, 1.5 + 1.3), pm, bevel=0.04))
        parts.append(cube(f"base{k}", (6.1, 2.6, 0.12), (x, y, 1.45), steel))
        for sx in (-2.7, 0, 2.7):
            for sy in (-1.1, 1.1):
                parts.append(cube(f"leg{k}{sx}{sy}", (0.14, 0.14, 1.5), (x + sx, y + sy, 0.75), steel))
        parts.append(cube(f"door{k}", (0.9, 0.05, 2.0), (x - 1.8, y - 1.27, 2.6), dark))
        parts.append(cube(f"win{k}", (1.4, 0.05, 0.7), (x + 1.0, y - 1.27, 3.2), glass))
        parts.append(cube(f"ac{k}", (0.8, 0.5, 0.6), (x + 2.2, y + 1.5, 2.0), steel))
    parts.append(cube("deck", (3.0, 1.6, 0.08), (-4.6, -2.0, 1.45), grate))
    for i in range(5):
        parts.append(cube(f"step{i}", (1.0, 0.3, 0.05), (-6.4, -2.0 - 0.3 * (i + 1), 1.45 - 0.29 * (i + 1)), grate))
    # antenna mast (lattice) with guy lines
    parts += K.truss("mast", (6.5, 3.5, 0.0), (6.5, 3.5, 12.5), 0.35, steel, chord_r=0.03, lace_r=0.012, step=0.6)
    for a in (0.3, 2.4, 4.5):
        parts.append(tube(f"guy{a}", [Vector((6.5, 3.5, 11.5)), Vector((6.5 + 6 * math.cos(a), 3.5 + 6 * math.sin(a), 0))], 0.008, 4, dark))
    parts.append(cyl("dish", 0.45, 0.12, (6.5, 3.0, 10.5), paint, 16, rot=(math.pi / 2, 0, 0)))
    # solar panel on a frame
    parts.append(cube("solar", (3.2, 1.8, 0.06), (-1.0, 3.8, 1.6), solar, rot=(math.radians(-35), 0, 0)))
    for sx in (-2.4, 0.4):
        parts.append(cube(f"sl{sx}", (0.08, 0.08, 1.6), (sx, 3.4, 0.8), steel))
        parts.append(cube(f"sh{sx}", (0.08, 0.08, 2.4), (sx, 4.3, 1.2), steel))
    # weather mast
    parts.append(cyl("wm", 0.04, 4.0, (-7.0, 2.0, 2.0), steel, 8))
    parts.append(cube("wmx", (0.9, 0.05, 0.05), (-7.0, 2.0, 3.9), steel))
    for sx in (-0.45, 0.45):
        parts.append(cyl(f"cup{sx}", 0.07, 0.1, (-7.0 + sx, 2.0, 3.95), paint, 8))
    o = join(parts, "research_station")
    bake(o, W, "research_station", 1024, ao_dist=1.0)
    done(o, W, "research_station")


def lava_field():
    """Cooled lava river with glowing cracks, 40 m along x 14 m across: ONLY behind the safety rails, never on
    the track (GDD 6.0). Emission from the ambientCG Lava001 emission map."""
    A.reset()
    o = grid("lava_field", 14.0, 40.0, 13, 31,
             hfn=lambda u, v: 0.25 * noise.fractal(Vector((u * 2.5, v * 8, 0.5)), 0.6, 2.0, 3) + 0.15)
    src = tset(W, "lava_crust")  # black crust albedo (glow removed); the glow is emission only, in the cracks
    m = mat("lava", src, scale=0.18, rough=0.8, tint=(0.75, 0.72, 0.72))
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    mp = next(n for n in nt.nodes if n.type == "MAPPING")
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = A.load_image(A.RAW / "ambientcg/Lava001/Lava001_1K-JPG_Emission.jpg", True)  # raw values
    nt.links.new(mp.outputs["Vector"], t.inputs["Vector"])
    bw = nt.nodes.new("ShaderNodeRGBToBW")
    nt.links.new(t.outputs["Color"], bw.inputs["Color"])
    mr = nt.nodes.new("ShaderNodeMapRange")  # map's hot cracks (top ~15%) -> full glow, the rest stays black
    mr.inputs["From Min"].default_value = 0.09
    mr.inputs["From Max"].default_value = 0.32
    nt.links.new(bw.outputs["Val"], mr.inputs["Value"])
    mx = nt.nodes.new("ShaderNodeMixRGB")
    mx.blend_type = "MULTIPLY"
    mx.inputs["Fac"].default_value = 1.0
    mx.inputs["Color2"].default_value = (0.9, 0.16, 0.015, 1)  # deep red-orange: tonemapping pushes bright orange to yellow
    nt.links.new(mr.outputs["Result"], mx.inputs["Color1"])
    nt.links.new(mx.outputs["Color"], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 1.0
    m["emit"] = 1
    o.data.materials.append(m)
    bake(o, W, "lava_field", 1024, ao_dist=0.5, ao_k=0.4, want_emission=True)
    done(o, W, "lava_field", "emissive; behind safety_rail only; Godot emission_energy 2-3 + glow on Høy")


def safety_rail():
    """Galvanised W-beam guardrail, 4 m section (posts every 2 m), 0.75 m high. Separates the lava field."""
    A.reset()
    galv = flat("galv", "#A7ABB0", rough=0.38, metal=1.0)
    post = flat("post", "#7D8086", rough=0.5, metal=0.9)
    prof = [(0, 0.0), (0.04, 0.05), (0.08, 0.1), (0.04, 0.16), (0.0, 0.2), (0.04, 0.26), (0.08, 0.31)]
    verts, faces = [], []
    for i, x in enumerate((-2.0, 2.0)):
        for y, z in prof:
            verts.append((x, -y, 0.45 + z))
    n = len(prof)
    for k in range(n - 1):
        faces.append((k, k + 1, n + k + 1, n + k))
    beam = A.mesh_obj("beam", verts, faces)
    s = beam.modifiers.new("s", "SOLIDIFY")
    s.thickness = 0.006
    A.apply_all(beam)
    beam.data.materials.append(galv)
    parts = [beam]
    for x in (-2.0, 0.0):
        parts.append(cube(f"p{x}", (0.1, 0.15, 0.8), (x + 0.05, 0.12, 0.4), post))
        parts.append(cube(f"blk{x}", (0.08, 0.12, 0.3), (x + 0.05, 0.03, 0.6), post))
    o = join(parts, "safety_rail")
    bake(o, W, "safety_rail", 256, ao_dist=0.2)
    done(o, W, "safety_rail", "4 m section along X; beam faces -Y (track side)")


# ---------------------------------------------------------------- scenery
def scoria_rock():
    ph_decimated("moon_rock_05", ["moon_rock_05_LOD0"], W, "scoria_rock", 500, scale=24.0, sat=0.15,
                 tint=(0.16, 0.15, 0.145), note="near volcanic rock; far = scoria_rock_card.glb")


def scoria_rock_card():
    card_of(lambda: import_glb(A.MODELS / "world4/scoria_rock.glb"), W, "scoria_rock_card", n=2, cell=(256, 256))


def burnt_snag():
    ph_decimated("dead_tree_trunk_02", None, W, "burnt_snag", 1200, scale=1.2, sat=0.1, tint=(0.22, 0.21, 0.2),
                 note="charred fallen trunk (old forest killed by the ash)")


def basalt_columns_card():
    card_of(lambda: import_glb(A.MODELS / "world4/basalt_columns.glb"), W, "basalt_columns_card", n=2,
            cell=(512, 512))


ALL = {f.__name__: f for f in (steam_vent, ash_dune, falling_rock_a, falling_rock_b, lava_crust_ridge, crater_cone,
                               basalt_columns, research_station, lava_field, safety_rail, scoria_rock,
                               scoria_rock_card, burnt_snag, basalt_columns_card)}

if __name__ == "__main__":
    run(ALL, argv)
