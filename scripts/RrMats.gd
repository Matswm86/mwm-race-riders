class_name RrMats
extends RefCounted

## Materials of the realistic set (DESIGN 2b, 12). The GLBs are imported
## without their embedded textures (each texture ships once, as the loose
## file in assets/textures), so every surface is rebuilt here from
## <name>_albedo / _normal / _orm / _emission by the GLB material name.
## ORM = R ambient occlusion, G roughness, B metallic. Racers get a duplicate
## per livery with only the albedo swapped (DESIGN 2b).

const DIRS: Array[String] = ["rider", "bike", "kit", "world1", "world2", "fx"]
## Alpha-scissor cards (DESIGN 9: trees, grass, bush impostors).
const CARDS: Array[String] = [
	"tree_pine_a", "tree_pine_b", "tree_pine_c", "grass_card", "bush_desert"
]
## Transparent ground patches with a vertex-alpha edge (mud, sand drift).
const PATCHES: Array[String] = ["mud_puddle", "sand_drift"]
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
		m.emission_energy_multiplier = 1.5
	if name in CARDS:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.85
	elif name in PATCHES:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.render_priority = -1
		m.cull_mode = BaseMaterial3D.CULL_BACK
		if name == "mud_puddle":
			m.roughness_texture = null
			m.roughness = 0.1
	elif name == "fern":
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[name] = m
	return m


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
