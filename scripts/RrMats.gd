class_name RrMats
extends RefCounted

## Materials of the realistic set (DESIGN 2b, 12). The GLBs are imported
## without their embedded textures (each texture ships once, as the loose
## file in assets/textures), so every surface is rebuilt here from
## <name>_albedo / _normal / _orm / _emission by the GLB material name.
## ORM = R ambient occlusion, G roughness, B metallic. Racers get a duplicate
## per livery with only the albedo swapped (DESIGN 2b).

const DIRS: Array[String] = [
	"rider", "bike", "kit", "world1", "world2", "world3", "world4", "world5", "world6", "fx"
]
## Alpha-scissor cards (DESIGN 9 / 11.0 rule 3: trees, grass, bush and far
## prop impostors).
const CARDS: Array[String] = [
	"tree_pine_a",
	"tree_pine_b",
	"tree_pine_c",
	"grass_card",
	"bush_desert",
	"serac_card",
	"glacier_boulder_card",
	"basalt_columns_card",
	"scoria_rock_card",
	"buttress_tree_card",
	"tree_jungle_a",
	"tree_jungle_b",
	"plant_calathea",
	"plant_anthurium",
	"shrub_jungle",
]
## Transparent ground patches with a vertex-alpha edge in COLOR_0 (DESIGN
## 11.0 rule 2): mud, sand drift, ice, snow drift, ash dune, river ford, wet
## steel plates.
const PATCHES: Array[String] = [
	"mud_puddle", "sand_drift", "ice_patch", "snow_drift", "ash_dune", "river_ford", "steel_plate"
]
## Glossy patches (roughness from DESIGN 11: ice 0.08, ford 0.05, wet steel 0.14).
const GLOSS: Dictionary = {
	"mud_puddle": 0.1, "ice_patch": 0.08, "river_ford": 0.05, "steel_plate": 0.14
}
## Emission strength per material (lava glows harder, DESIGN 11.2).
const EMISSION: Dictionary = {"lava_field": 2.5, "ice_cave": 1.2, "air_ring": 2.5}
## Moving water (DESIGN 11.3): alpha blend, cull off, drawn after the ground.
const WATER_FALLS: Array[String] = ["waterfall_water"]
const RACER_KINDS: Array[String] = ["rider", "bike", "hoverboard"]
## Models whose textures are mapped on their second UV set (glTF texCoord 1).
## StandardMaterial3D samples UV1, so these meshes get UV2 copied into UV1.
const UV2_MODELS: Array[String] = [
	"boost_pad",
	"fence_rail",
	"finish_arch",
	"hay_bale",
	"hoverboard",
	"ramp",
	"swap_gate",
	"tape_stake",
	"water_tower",
]

static var _tex: Dictionary = {}
static var _mats: Dictionary = {}
static var _high: bool = true
static var _meshes: Dictionary = {}


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


## res:// path of assets/textures/<dir>/<base>.png|.jpg, or "".
static func find(base: String) -> String:
	for d: String in DIRS:
		for ext: String in [".png", ".jpg"]:
			var p: String = "res://assets/textures/%s/%s%s" % [d, base, ext]
			if ResourceLoader.exists(p):
				return p
	return ""


static func map(base: String) -> Texture2D:
	var p: String = find(base)
	return tex(p) if p != "" else null


## The shared material for a GLB material name (cached).
static func for_name(name: String) -> StandardMaterial3D:
	if _mats.has(name):
		return _mats[name]
	var m := StandardMaterial3D.new()
	m.resource_name = name
	var alb: Texture2D = map(name + "_albedo")
	m.albedo_texture = alb
	var nrm: Texture2D = map(name + "_normal")
	if nrm != null:
		m.normal_enabled = _high or name in RACER_KINDS
		m.normal_texture = nrm
	var orm: Texture2D = map(name + "_orm")
	if orm != null:
		m.ao_enabled = true
		m.ao_texture = orm
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.ao_light_affect = 0.6
		m.roughness = 1.0
		m.roughness_texture = orm
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.metallic = 1.0
		m.metallic_texture = orm
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	else:
		m.roughness = 0.9
	var em: Texture2D = map(name + "_emission")
	if em != null:
		m.emission_enabled = true
		m.emission = Color(1, 1, 1)
		# Multiply: the default (add) would add the white colour everywhere.
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		m.emission_texture = em
		m.emission_energy_multiplier = float(EMISSION.get(name, 1.5))
	if name in WATER_FALLS:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.render_priority = 1
		m.roughness = 0.1
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		m.normal_texture = map("water_ripple_normal")
		m.normal_enabled = m.normal_texture != null and _high
		m.normal_scale = 0.4
	elif name == "pool_water":
		_water_into(m, Color(0.02, 0.035, 0.03), 0.05)
	elif name in CARDS:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.85
	elif name in PATCHES:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.render_priority = -1
		m.cull_mode = BaseMaterial3D.CULL_BACK
		if GLOSS.has(name):
			m.roughness_texture = null
			m.roughness = float(GLOSS[name])
	elif name == "fern":
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[name] = m
	return m


## Dark glossy water with a slow ripple normal (DESIGN 11.3 / 11.4).
static func _water_into(m: StandardMaterial3D, col: Color, rough: float) -> void:
	m.albedo_texture = null
	m.albedo_color = col
	m.roughness_texture = null
	m.roughness = rough
	m.metallic_texture = null
	m.metallic = 0.0
	m.metallic_specular = 0.7
	m.ao_enabled = false
	m.normal_texture = map("water_ripple_normal")
	m.normal_enabled = m.normal_texture != null
	m.normal_scale = 0.15
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.08, 0.08, 0.08)


## Open water for the river, the pool and the harbour basin (one per colour).
static func water(col: Color, rough: float = 0.06) -> StandardMaterial3D:
	var key: String = "water#%s" % col.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		_water_into(m, col, rough)
		_mats[key] = m
	return _mats[key]


## A racer's material: the shared one with the livery albedo swapped (r1-r6).
static func livery(kind: String, idx: int) -> StandardMaterial3D:
	var key: String = "%s#%d" % [kind, idx]
	if _mats.has(key):
		return _mats[key]
	var base: StandardMaterial3D = for_name(kind)
	var m: StandardMaterial3D = base.duplicate()
	var dir: String = "kit" if kind == "hoverboard" else kind
	var p: String = "res://assets/textures/%s/%s_r%d_albedo.png" % [dir, kind, idx + 1]
	var t: Texture2D = tex(p)
	if t != null:
		m.albedo_texture = t
	if idx > 0:
		# Rivals dither away when nearer the camera than the player (QA 2):
		# the player sits about 4.2 m from the camera.
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		m.distance_fade_min_distance = 2.0
		m.distance_fade_max_distance = 4.0
	_mats[key] = m
	return m


## The mesh with its texture UVs in UV1 (see UV2_MODELS), cached per mesh.
static func uv_fixed(mesh: Mesh) -> Mesh:
	var src: Material = mesh.surface_get_material(0)
	var name: String = src.resource_name if src != null else ""
	if not name in UV2_MODELS or not mesh is ArrayMesh:
		return mesh
	var key: String = mesh.resource_path + "|" + name
	if _meshes.has(key):
		return _meshes[key]
	var am := ArrayMesh.new()
	for i: int in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(i)
		if arr[Mesh.ARRAY_TEX_UV2] != null:
			arr[Mesh.ARRAY_TEX_UV] = arr[Mesh.ARRAY_TEX_UV2]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(i, mesh.surface_get_material(i))
	_meshes[key] = am
	return am


## Material of the first surface of a mesh, rebuilt from the loose textures.
static func for_mesh(mesh: Mesh) -> StandardMaterial3D:
	var src: Material = mesh.surface_get_material(0)
	var name: String = src.resource_name if src != null else ""
	return for_name(name)


## Give every MeshInstance3D under node its rebuilt material.
static func dress(node: Node) -> void:
	for mi: Node in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.material_override = for_mesh(m.mesh)


## Lav tier (DESIGN 13): normal maps stay on the racers only.
static func set_quality(high: bool) -> void:
	_high = high
	for k: String in _mats:
		var m: StandardMaterial3D = _mats[k]
		if m.normal_texture == null:
			continue
		var racer: bool = k.get_slice("#", 0) in RACER_KINDS
		m.normal_enabled = high or racer
