# gdlint: disable=max-file-lines
class_name RrWorld
extends Node3D

## The 3D scene of one world (DESIGN 6-10): HDRI sky, matching sun, depth
## fog, the baked ground and props, the track kit, the hindrances, the six
## racers and the ghost, weather, a dust pool and the chase camera. It only
## draws; RrMain owns the RrRace and calls sync() and the fx_* calls. One
## RrWorld per race: switching worlds builds a new one.

const GHOST_TINT := Color(0.86, 0.94, 1.0)
## Ground layers per world (DESIGN 9, 10, 11.1-11.4): texture set names under
## assets/textures/world<N>/ and the shader tiles and knobs.
const TERRAIN: Dictionary = {
	3:
	{
		"trail": "terrain_snow_groomed",
		"base": "terrain_snow",
		"rock": "terrain_glacier_rock",
		"verge": "terrain_snow_wind",
		"patch": "terrain_snow_wind",
		"tiles": [3.0, 4.0, 8.0, 5.0, 9.0],
		"dye": true,
		"line_dark": 0.06,
	},
	4:
	{
		"trail": "terrain_ash_trail",
		"base": "terrain_ash",
		"rock": "terrain_basalt",
		"verge": "terrain_ash_soft",
		"patch": "terrain_lava_crust",
		"tiles": [3.2, 4.0, 7.0, 5.0, 6.0],
	},
	5:
	{
		"trail": "terrain_mud_wet",
		"base": "terrain_forest_moss",
		"rock": "terrain_mossy_rock",
		"verge": "terrain_mud_leaves",
		"patch": "terrain_mud_leaves",
		"tiles": [3.0, 4.0, 6.0, 3.5, 3.5],
		"rough": 0.55,
	},
	6:
	{
		"trail": "terrain_asphalt_wet",
		"base": "terrain_quay_concrete",
		"rock": "terrain_quay_wall",
		"verge": "terrain_quay_concrete",
		"patch": "terrain_steel_plate",
		"tiles": [4.0, 5.0, 4.0, 5.0, 3.0],
		"rough": 0.45,
		"line_dark": 0.05,
	},
}
## Smooth (hoverboard) lane surface per world: [texture set, tile, tint, edge lines].
const LANES: Dictionary = {
	3: ["res://assets/textures/world3/terrain_blue_ice", 4.0, Vector3(0.92, 0.95, 1.0), 0.0],
	4: ["res://assets/textures/world4/terrain_basalt", 6.0, Vector3(0.78, 0.74, 0.72), 0.0],
	5:
	["res://assets/textures/world1/terrain_gravel_floor_02", 2.5, Vector3(0.42, 0.44, 0.36), 0.0],
	6: ["res://assets/textures/world6/terrain_quay_concrete", 5.0, Vector3(0.75, 0.75, 0.75), 1.0],
}
## Far versions of near props (DESIGN 11.0 rule 3): model -> [card, swap m].
const LODS: Dictionary = {
	"world3/serac_a": ["world3/serac_card", 60.0],
	"world3/serac_b": ["world3/serac_card", 60.0],
	"world3/glacier_boulder": ["world3/glacier_boulder_card", 60.0],
	"world4/basalt_columns": ["world4/basalt_columns_card", 80.0],
	"world4/scoria_rock": ["world4/scoria_rock_card", 60.0],
	"world5/buttress_tree": ["world5/buttress_tree_card", 70.0],
	"world6/container": ["world6/container_far", 40.0],
}
## Props that cast the sun's shadow on Høy (near ones only: the shadow
## distance is 40 m).
const CASTERS: Array[String] = [
	"world1/cabin",
	"world1/river_bridge",
	"world1/rock_tunnel_portal",
	"world2/sandstone_arch",
	"world2/gas_station",
	"world2/canyon_cliff_a",
	"world2/canyon_cliff_b",
	"world3/ice_cave",
	"world3/glacier_hut",
	"world3/serac_a",
	"world3/serac_b",
	"world4/research_station",
	"world4/safety_rail",
	"world4/basalt_columns",
	"world5/rope_bridge",
	"world5/stone_ruin",
	"world5/buttress_tree",
	"world6/crane_jump_stack",
	"world6/gantry_crane",
	"world6/container",
]
## Patch model -> [native x (across), native z (along), turned 90 deg, pad x, pad z].
const PATCH_FIT: Dictionary = {
	"mud_puddle": [5.6, 11.2, false, 1.35, 1.3],
	"sand_drift": [15.0, 4.0, true, 1.3, 1.25],
	"world3/ice_patch": [6.0, 14.0, false, 1.25, 1.2],
	"world3/snow_drift": [15.0, 4.0, true, 1.3, 1.25],
	"world4/ash_dune": [15.0, 4.5, true, 1.3, 1.25],
	"world5/river_ford": [12.0, 18.0, false, 1.08, 1.1],
	"world6/steel_plate": [7.2, 6.9, false, 1.15, 1.15],
}
## Visibility (m) of scatter props of worlds 3-6: model -> [Høy, Lav].
const VIS: Dictionary = {
	"world3/flag_pole": [160.0, 110.0],
	"world4/burnt_snag": [150.0, 100.0],
	"world5/shrub_jungle": [35.0, 15.0],
	"world5/plant_calathea": [35.0, 15.0],
	"world6/concrete_barrier": [120.0, 80.0],
	"world6/bollard": [120.0, 70.0],
	"world6/sodium_lamp": [420.0, 260.0],
	"fxq_light_pool": [200.0, 80.0],
	"fxb_sodium_glow": [600.0, 250.0],
	"world6/sea_marker": [600.0, 200.0],
	"rock_b": [160.0, 110.0],
}
## Far end of the cards that replace near props: model -> [Høy, Lav].
const CARD_END: Dictionary = {
	"world3/serac_a": [420.0, 260.0],
	"world3/serac_b": [420.0, 260.0],
	"world3/glacier_boulder": [200.0, 120.0],
	"world4/basalt_columns": [420.0, 260.0],
	"world4/scoria_rock": [180.0, 110.0],
	"world5/buttress_tree": [500.0, 300.0],
	"world6/container": [420.0, 260.0],
}
## Roller model -> [centre height, bounces].
const ROLLER_FIT: Dictionary = {
	"tumbleweed": [0.6, true],
	"world3/snow_slough": [0.65, true],
	"world4/falling_rock_a": [0.25, false],
	"world6/cable_spool": [0.8, false],
}

static var _glb_cache: Dictionary = {}

var track: RrTrack
var look: Dictionary = {}
var camera: Camera3D
var env: Environment
var sun: DirectionalLight3D
var views: Array[RrRiderView] = []
var ghost_view: RrRiderView
var less_motion: bool = false
var gates_live: bool = false
## Build time of the static world (ms) and whether it came from the bake.
var world_ms: int = 0
var world_baked: bool = false
## Graphics features in use (Høy = all on, Lav = all off), see apply_quality.
var features: Dictionary = {}
## Ghost opacity this frame (0 = hidden), for tests.
var ghost_alpha: float = 0.0
## Test hook: leave the camera where a test put it.
var hold_camera: bool = false
## Dust, flakes, stones, contact quads, board glow and weather.
var fx: RrWorldFx

var _sky: Sky
var _terrain_mat: ShaderMaterial
var _terrain_far_mat: ShaderMaterial
var _lane_mat: ShaderMaterial
var _pad_mat: ShaderMaterial
var _gate_mats: Array[ShaderMaterial] = []
var _gate_run: PackedFloat32Array = PackedFloat32Array([9.0, 9.0])
var _ghost_mat: StandardMaterial3D
var _pads: MultiMeshInstance3D
var _pad_flare: PackedFloat32Array = PackedFloat32Array()
var _hay: MultiMeshInstance3D
var _hay_xf: Array[Transform3D] = []
var _weeds: MultiMeshInstance3D
var _veg: Array = []
var _casters: Array[GeometryInstance3D] = []
## Parent of the baked ground and props; mirrored in X on Pro tracks.
var _static_root: Node3D
var _near_trees: Array[MultiMeshInstance3D] = []
var _cast_t: float = 0.0
## Hop hindrances (W4 crust ridges, W5 logs) and W6 air rings.
var _hops: MultiMeshInstance3D
var _rings: MultiMeshInstance3D
## W5 waterfall material (its v scrolls), W6 lamp heads and the two omni
## lights that follow the nearest ones.
var _falls: Array[StandardMaterial3D] = []
var _lamp_heads: PackedVector3Array = PackedVector3Array()
var _omnis: Array[OmniLight3D] = []
var _vent_prev: bool = false
var _ambient: float = 1.0

# Camera state
var _cam_mode: String = "chase"
var _cam_x: float = 0.0
var _cam_yaw: float = 0.0
var _cam_h: float = 0.0
var _cam_t: float = 0.0
var _fov_t: float = 99.0
var _boost_end_t: float = 99.0
var _dip_t: float = 99.0
var _shake_t: float = 99.0
var _rumble_t: float = 0.0
var _fov_base: float = RrBalance.CAM_FOV
var _boost_blend: float = 0.0
var _intro_from: Transform3D
var _finish_from: Transform3D
var _rng := RandomNumberGenerator.new()
var _col_mats: Dictionary = {}


func _ready() -> void:
	_rng.seed = 5
	camera = Camera3D.new()
	camera.fov = RrBalance.CAM_FOV
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.3
	camera.far = RrBalance.CAM_FAR  # raised per world in setup (look "far")
	camera.current = true
	add_child(camera)


func setup(trk: RrTrack) -> void:
	track = trk
	look = trk.look
	camera.far = float(look.get("far", RrBalance.CAM_FAR))
	var path := Path3D.new()
	path.name = "CentreLine"
	path.curve = track.make_curve()
	add_child(path)
	_build_environment()
	_build_static()
	_build_kit()
	fx = RrWorldFx.new()
	add_child(fx)
	fx.setup(track)


# ---------------------------------------------------------------- build


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	_sky = Sky.new()
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = load(String(look["sky"]))
	pm.energy_multiplier = float(look.get("sky_energy", 1.0))
	_sky.sky_material = pm
	_sky.radiance_size = Sky.RADIANCE_SIZE_256
	_sky.process_mode = Sky.PROCESS_MODE_AUTOMATIC
	env.sky = _sky
	env.sky_rotation = Vector3(0.0, deg_to_rad(float(look["sky_yaw"])), 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	if look.has("ambient"):
		# W6 night: a little blue-grey fill so the quay is never pure black.
		env.ambient_light_color = look["ambient"]
		env.ambient_light_sky_contribution = 0.35
		env.ambient_light_energy = float(look.get("ambient_energy", 1.0))
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# AgX: matches the approved Blender AgX mocks better than ACES (side by
	# side on the real build: ACES pushed the pine-needle verge to orange).
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = float(look.get("exposure", 1.0))
	env.tonemap_white = 6.0
	env.ssao_enabled = false
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = look["fog_color"]
	env.fog_light_energy = 1.0
	env.fog_density = float(look["fog_max"])
	env.fog_depth_begin = float(look["fog_begin"])
	env.fog_depth_end = float(look["fog_end"])
	env.fog_depth_curve = 1.0
	env.fog_sky_affect = 0.12
	env.fog_sun_scatter = 0.0
	env.glow_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = look["sun_rot"]
	sun.light_color = look["sun_color"]
	sun.light_energy = float(look["sun_energy"])
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 40.0
	sun.directional_shadow_split_1 = 0.22
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.0
	sun.shadow_blur = 1.5
	sun.shadow_enabled = true
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	_ambient = env.ambient_light_energy
	if look.has("rim_light"):
		# W6 night: two lights that touch only the riders (render layer 2) so
		# they read against the asphalt: a rim from ahead and above that edges
		# their outlines, and a soft key from behind the camera on their backs.
		var rl: Array = look["rim_light"]  # [rim colour, rim energy, key colour, key energy]
		# Camera space directions the light travels (rim: down and back toward
		# the camera; key: down and forward, a little from the left).
		var dirs: Array[Vector3] = [Vector3(0.35, -0.75, 1.0), Vector3(0.3, -0.7, -1.0)]
		for i: int in 2:
			var dl := DirectionalLight3D.new()
			dl.light_color = rl[2 * i]
			dl.light_energy = float(rl[2 * i + 1])
			dl.light_cull_mask = RrRiderView.RIM_LAYER
			dl.shadow_enabled = false
			dl.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
			camera.add_child(dl)
			dl.transform = Transform3D.IDENTITY.looking_at(dirs[i], Vector3.UP)


## Terrain material per world (DESIGN 9 / 10 layer tables).
func _terrain_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/rr_terrain.gdshader")
	var w: int = track.world_id
	var d: String = "res://assets/textures/world%d/" % w
	var layers: Dictionary
	if TERRAIN.has(w):
		layers = TERRAIN[w]
		var tl: Array = layers["tiles"]
		m.set_shader_parameter("trail_tile", tl[0])
		m.set_shader_parameter("base_tile", tl[1])
		m.set_shader_parameter("rock_tile", tl[2])
		m.set_shader_parameter("verge_tile", tl[3])
		m.set_shader_parameter("patch_tile", tl[4])
		m.set_shader_parameter("trail_rot", bool(layers.get("trail_rot", false)))
		m.set_shader_parameter("dye", bool(layers.get("dye", false)))
		m.set_shader_parameter("rough_mult", float(layers.get("rough", 1.0)))
		m.set_shader_parameter("line_dark", float(layers.get("line_dark", 0.14)))
	elif w == 2:
		# DESIGN 10a: the canyon-wall set (level strata) replaces cliff_side;
		# Høy samples it world-aligned triplanar (apply_features).
		layers = {
			"trail": "terrain_red_laterite_soil_stones",
			"base": "terrain_red_sand",
			"rock": "terrain_canyon_wall",
			"verge": "terrain_red_sand",
			"patch": "terrain_red_sand",
		}
		m.set_shader_parameter("rock_tile", 9.0)
		m.set_shader_parameter("base_tile", 3.5)
		m.set_shader_parameter("verge_tile", 6.0)
		m.set_shader_parameter("line_dark", 0.10)
	else:
		m.set_shader_parameter("verge_tint", Vector3(0.72, 0.66, 0.6))
		layers = {
			"trail": "terrain_rocky_trail_02",
			"base": "terrain_forest_ground_04",
			"rock": "terrain_rocky_trail",
			"verge": "terrain_forest_leaves_04",
			"patch": "terrain_sparse_grass",
		}
	m.set_shader_parameter("trail_alb", load(d + layers["trail"] + "_albedo.jpg"))
	m.set_shader_parameter("trail_nrm", load(d + layers["trail"] + "_normal.jpg"))
	m.set_shader_parameter("trail_arm", load(d + layers["trail"] + "_arm.jpg"))
	m.set_shader_parameter("base_alb", load(d + layers["base"] + "_albedo.jpg"))
	m.set_shader_parameter("base_nrm", load(d + layers["base"] + "_normal.jpg"))
	m.set_shader_parameter("base_arm", load(d + layers["base"] + "_arm.jpg"))
	m.set_shader_parameter("rock_alb", load(d + layers["rock"] + "_albedo.jpg"))
	m.set_shader_parameter("rock_nrm", load(d + layers["rock"] + "_normal.jpg"))
	m.set_shader_parameter("verge_alb", load(d + layers["verge"] + "_albedo.jpg"))
	m.set_shader_parameter("patch_alb", load(d + layers["patch"] + "_albedo.jpg"))
	return m


func _lane_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/rr_lane.gdshader")
	var w: int = track.world_id
	var base: String
	if LANES.has(w):
		var ln: Array = LANES[w]
		base = ln[0]
		m.set_shader_parameter("tile", ln[1])
		m.set_shader_parameter("tint", ln[2])
		m.set_shader_parameter("edge_line", ln[3])
	elif w == 2:
		base = "res://assets/textures/world2/terrain_worn_asphalt"
		m.set_shader_parameter("tile", 4.0)
		m.set_shader_parameter("edge_line", 1.0)
	else:
		base = "res://assets/textures/world1/terrain_gravel_floor_02"
		m.set_shader_parameter("tile", 2.5)
		# QA look 5: the pale gravel read as snow; tint it to a used road.
		m.set_shader_parameter("tint", Vector3(0.58, 0.55, 0.5))
	m.set_shader_parameter("alb", load(base + "_albedo.jpg"))
	m.set_shader_parameter("nrm", load(base + "_normal.jpg"))
	m.set_shader_parameter("arm", load(base + "_arm.jpg"))
	return m


func _build_static() -> void:
	var t0: int = Time.get_ticks_msec()
	var data: Dictionary = {}
	var path: String = RrWorldBake.path_for(track.key)
	if ResourceLoader.exists(path):
		var baked: Resource = load(path)
		if baked != null and int(baked.get_meta(&"version", -1)) == RrWorldBake.VERSION:
			data = baked.get_meta(&"world", {})
			world_baked = true
	if data.is_empty():
		var gen := RrWorldGen.new()
		gen.build(RrTrack.new(RrTracks.base_key(track.key)) if track.mirrored else track)
		data = gen.result()
	# A Pro track is its base track mirrored (x -> -x): the base world in X.
	_static_root = Node3D.new()
	_static_root.name = "Static"
	if track.mirrored:
		_static_root.scale = Vector3(-1.0, 1.0, 1.0)
	add_child(_static_root)
	_terrain_mat = _terrain_material()
	# The far grid sits 60 m+ away under the fog: no normal maps, no patches.
	_terrain_far_mat = _terrain_mat.duplicate()
	_terrain_far_mat.set_shader_parameter("use_normals", false)
	_terrain_far_mat.set_shader_parameter("cheap", true)
	for e: Array in data["ground"]:
		var mi := MeshInstance3D.new()
		mi.mesh = e[0]
		mi.material_override = _terrain_far_mat if e.size() > 3 and bool(e[3]) else _terrain_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_static_root.add_child(mi)
	_lane_mat = _lane_material()
	for e: Array in data["lanes"]:
		var ml := MeshInstance3D.new()
		ml.mesh = e[0]
		ml.material_override = _lane_mat
		ml.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ml.visibility_range_end = 420.0
		_static_root.add_child(ml)
	var wm: StandardMaterial3D = _water_material()
	for e: Array in data["water"]:
		var mw := MeshInstance3D.new()
		mw.mesh = e[0]
		mw.material_override = wm
		mw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_static_root.add_child(mw)
	var protos: Dictionary = {}
	for e: Array in data["props"]:
		var kind: String = e[0]
		var model: String = RrWorld.model_of(kind)
		if not protos.has(model):
			protos[model] = _proto(model)
		var buf: PackedFloat32Array = e[1]
		var colored: bool = kind.contains("col_")
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = colored
		mm.mesh = protos[model]
		mm.instance_count = buf.size() / (16 if colored else 12)
		mm.buffer = buf
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var mat: Material = _prop_material(kind, model, mm.mesh)
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		_static_root.add_child(mmi)
		_veg.append([kind, mmi])
		if kind.begins_with("near_"):
			_near_trees.append(mmi)
			# QA perf fix 3: beyond 45 m the same pines draw as one card each.
			if not protos.has("card_" + model):
				protos["card_" + model] = _one_card(protos[model])
			var cm := MultiMesh.new()
			cm.transform_format = MultiMesh.TRANSFORM_3D
			cm.mesh = protos["card_" + model]
			cm.instance_count = mm.instance_count
			cm.buffer = buf
			var cmi := MultiMeshInstance3D.new()
			cmi.multimesh = cm
			cmi.material_override = mat
			cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cmi.visibility_range_begin = 75.0
			_static_root.add_child(cmi)
			_veg.append(["card_" + kind, cmi])
		elif kind.begins_with("st_"):
			pass  # roadside stones and plants: too small to need a sun shadow
		elif model.begins_with("rock") or model in ["dead_trunk", "fence_rail"]:
			_casters.append(mmi)
		elif model in CASTERS:
			_casters.append(mmi)
		if kind.begins_with("lod_") and LODS.has(model):
			# Near mesh up to the swap distance, its card beyond (same buffer).
			var lod: Array = LODS[model]
			var card: String = lod[0]
			if not protos.has(card):
				protos[card] = glb_mesh(card)
			var fm := MultiMesh.new()
			fm.transform_format = MultiMesh.TRANSFORM_3D
			fm.use_colors = colored
			fm.mesh = protos[card]
			fm.instance_count = mm.instance_count
			fm.buffer = buf
			var fmi := MultiMeshInstance3D.new()
			fmi.multimesh = fm
			fmi.material_override = _prop_material(kind, card, fm.mesh)
			fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			fmi.visibility_range_begin = float(lod[1])
			_static_root.add_child(fmi)
			_veg.append(["card_lod_" + model, fmi])
		if model == "world6/sodium_lamp":
			for i: int in mm.instance_count:
				var lx: Transform3D = _static_root.transform * mm.get_instance_transform(i)
				_lamp_heads.append(lx.origin + Vector3.UP * 11.0)
	world_ms = Time.get_ticks_msec() - t0


## Model name of a prop kind (prefixes: st_ streamer, near_ / far_ trees,
## srock_ sandstone-tinted rock, lm_ landmark, lod_ near/far pair, col_
## coloured per instance, fxq_ / fxb_ light quads).
static func model_of(kind: String) -> String:
	var m: String = kind
	for pre: String in ["st_", "lm_", "lod_", "col_", "near_", "far_", "srock_"]:
		m = m.trim_prefix(pre)
	return m


## Mesh for a model: a GLB, or a quad for the W6 light fx.
func _proto(model: String) -> Mesh:
	if model == "fxq_light_pool":
		var q := QuadMesh.new()
		q.orientation = PlaneMesh.FACE_Y
		q.size = Vector2(1.0, 1.0)
		return q
	if model == "fxb_sodium_glow":
		var b := QuadMesh.new()
		b.size = Vector2(1.0, 1.0)
		return b
	return glb_mesh(model)


func _prop_material(kind: String, model: String, mesh: Mesh) -> Material:
	if model == "fxq_light_pool" or model == "fxb_sodium_glow":
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		fm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		var pool: bool = model == "fxq_light_pool"
		fm.albedo_texture = load(
			"res://assets/textures/world6/%s.png" % ("fx_light_pool" if pool else "fx_sodium_glow")
		)
		fm.albedo_color = Color(1.0, 0.62, 0.30, 0.22 if pool else 0.9)
		if not pool:
			fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		return fm
	var mat: StandardMaterial3D = RrMats.for_mesh(mesh)
	if kind.begins_with("srock_") or kind.begins_with("st_srock_"):
		mat = sandstone(mat)
	if kind.contains("col_"):
		var key: String = mat.resource_name + "#col"
		if not _col_mats.has(key):
			var cm: StandardMaterial3D = mat.duplicate()
			cm.vertex_color_use_as_albedo = true
			_col_mats[key] = cm
		mat = _col_mats[key]
	if model in RrMats.WATER_FALLS and not mat in _falls:
		_falls.append(mat)
	return mat


## Open water per world (W1 river; W5 river and pool; W6 harbour basin).
func _water_material() -> StandardMaterial3D:
	match track.world_id:
		5:
			return RrMats.water(Color(0.03, 0.05, 0.045), 0.05)
		6:
			return RrMats.water(Color(0.006, 0.010, 0.014), 0.06)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.05, 0.08, 0.07)
	wm.roughness = 0.06
	wm.metallic_specular = 0.7
	wm.normal_enabled = true
	wm.normal_texture = load("res://assets/textures/world1/terrain_gravel_floor_02_normal.jpg")
	wm.normal_scale = 0.15
	wm.uv1_triplanar = true
	wm.uv1_scale = Vector3(0.08, 0.08, 0.08)
	return wm


## The first plane (two triangles) of a four-plane pine impostor.
func _one_card(mesh: Mesh) -> Mesh:
	var arr: Array = mesh.surface_get_arrays(0)
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	arr[Mesh.ARRAY_INDEX] = idx.slice(0, 6)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, mesh.surface_get_material(0))
	return m


## DESIGN 10: the grey rock scans multiplied to sandstone.
static func sandstone(base: StandardMaterial3D) -> StandardMaterial3D:
	var m: StandardMaterial3D = base.duplicate()
	m.albedo_color = Color(1.25, 0.62, 0.42)
	return m


static func glb_mesh(name: String) -> Mesh:
	if _glb_cache.has(name):
		return _glb_cache[name]
	var root: Node = (load("res://assets/models/%s.glb" % name) as PackedScene).instantiate()
	var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	var m: Mesh = RrMats.uv_fixed(mi.mesh)
	root.free()
	_glb_cache[name] = m
	return m


func _mesh_node(name: String, xf: Transform3D, cast: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = glb_mesh(name)
	mi.material_override = RrMats.for_mesh(mi.mesh)
	mi.transform = xf
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if cast:
		_casters.append(mi)
	return mi


## Flat frame at s (yaw only), origin at lateral x and height h.
func _flat(s: float, x: float, h: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, track.yaw(s)), track.world_point(s, x, h))


## Frame at s that follows the slope (pads and ramps sit on the surface).
func _slope_frame(s: float, x: float, h: float) -> Transform3D:
	var f: Transform3D = track.frame(s)
	f.origin = track.world_point(s, x, h)
	return f


func _glow_material(prefix: String, instanced: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/rr_glow_kit.gdshader")
	var d: String = "res://assets/textures/kit/" + prefix
	m.set_shader_parameter("alb", load(d + "_albedo.png"))
	m.set_shader_parameter("nrm", load(d + "_normal.png"))
	m.set_shader_parameter("orm", load(d + "_orm.png"))
	m.set_shader_parameter("emi", load(d + "_emission.png"))
	m.set_shader_parameter("instanced", instanced)
	return m


static func multi(
	parent: Node, mesh: Mesh, xfs: Array[Transform3D], mat: Material, custom: bool = false
) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i: int in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if custom:
			mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


func _build_kit() -> void:
	# Speed pads: one MultiMesh, flare per pad in the custom data.
	var pad_xf: Array[Transform3D] = []
	for pad: Array in track.pads:
		# GDD 4.4: 6 m long plates at 30 m/s (the model is 3 x 4 m).
		var pxf: Transform3D = _slope_frame(float(pad[0]), float(pad[1]), 0.02)
		pxf.basis = pxf.basis.scaled(Vector3(1.0, 1.0, RrBalance.PAD_L_M / 4.0))
		pad_xf.append(pxf)
	_pad_mat = _glow_material("boost_pad", true)
	_pads = multi(self, glb_mesh("boost_pad"), pad_xf, _pad_mat, true)
	_pad_flare.resize(track.pads.size())
	_pad_flare.fill(0.0)
	# Kickers: deck centred KICKER_LEN_M / 2 before the lip, across the width.
	var by_model: Dictionary = {}
	for i: int in track.kickers.size():
		var model: String = track.kicker_models[i]
		if model.begins_with("-") or model == "vent" or model == "world1/river_bridge":
			continue  # the skin is a landmark (RrLandmarks): stack, vent, bridge
		var mesh: Mesh = glb_mesh(model)
		var sc: float = mesh.get_aabb().size.x
		var sm: float = track.kickers[i] - RrBalance.KICKER_LEN_M * 0.5
		var xf: Transform3D = _slope_frame(sm, 0.0, 0.0)
		xf.basis = xf.basis.scaled(Vector3((track.width(sm) + 0.8) / sc, 1.0, 1.0))
		if not by_model.has(model):
			by_model[model] = [mesh, [] as Array[Transform3D]]
		(by_model[model][1] as Array[Transform3D]).append(xf)
	for model: String in by_model:
		var e: Array = by_model[model]
		var mesh2: Mesh = e[0]
		var rmat: StandardMaterial3D = RrMats.for_mesh(mesh2)
		if model == "ramp_rock" and track.world_id == 4:
			rmat = _tinted(rmat, Color(0.35, 0.33, 0.32))  # DESIGN 11.2: basalt
		elif model == "ramp_rock" and track.world_id == 5:
			rmat = _tinted(rmat, Color(0.55, 0.62, 0.45))  # moss on the waterfall lip
		var ramps: MultiMeshInstance3D = multi(self, mesh2, e[1], rmat)
		_casters.append(ramps)
	# Blocks (W1 hay, W5 branch piles, W6 cones): one MultiMesh, a burst one
	# is scaled to zero. Cones stand in threes across the 1.6 m block.
	var block_model: String = String(track.kit.get("block", ""))
	if block_model == "":
		block_model = "hay_bale"
	if not track.blocks.is_empty():
		_hay_xf.clear()
		for b: Array in track.blocks:
			_hay_xf.append(_flat(float(b[0]), float(b[1]), 0.0))
		var hm: Mesh = glb_mesh(block_model)
		if block_model == "world6/traffic_cone":
			hm = RrWorld._triple(hm, 0.55)
		_hay = multi(self, hm, _hay_xf, RrMats.for_mesh(hm))
		_casters.append(_hay)
	# Patches stretched to their rectangles (model per kind, RrWorlds).
	var patch_xf: Dictionary = {}
	for p: Array in track.patches:
		var kind: String = p[4]
		var model3: String = String(RrWorlds.PATCH_MODELS.get(kind, "mud_puddle"))
		var fit: Array = PATCH_FIT.get(model3, PATCH_FIT["mud_puddle"])
		var s0: float = p[0]
		var s1: float = p[1]
		var x0: float = p[2]
		var x1: float = p[3]
		var xf3: Transform3D = _slope_frame((s0 + s1) * 0.5, (x0 + x1) * 0.5, 0.01)
		var across: float = (x1 - x0) * float(fit[3])
		var along: float = (s1 - s0) * float(fit[4])
		if bool(fit[2]):
			xf3.basis = (xf3.basis * Basis(Vector3.UP, PI * 0.5)).scaled(
				Vector3(along / float(fit[0]), 1.0, across / float(fit[1]))
			)
		else:
			xf3.basis = xf3.basis.scaled(
				Vector3(across / float(fit[0]), 1.0, along / float(fit[1]))
			)
		if not patch_xf.has(model3):
			patch_xf[model3] = [] as Array[Transform3D]
		(patch_xf[model3] as Array[Transform3D]).append(xf3)
	for model4: String in patch_xf:
		var pm: Mesh = glb_mesh(model4)
		multi(self, pm, patch_xf[model4], RrMats.for_mesh(pm))
	# Rollers (W2 tumbleweeds, W3 slough, W4 rocks, W6 spools): posed per frame.
	if not track.rollers.is_empty():
		var hidden: Array[Transform3D] = []
		for i: int in track.rollers.size():
			hidden.append(Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		var rmodel: String = String(track.kit.get("roller", "tumbleweed"))
		if rmodel == "":
			rmodel = "tumbleweed"
		var tw: Mesh = glb_mesh(rmodel)
		_weeds = multi(self, tw, hidden, RrMats.for_mesh(tw))
		_weeds.custom_aabb = AABB(Vector3(-5000, -2000, -5000), Vector3(10000, 4000, 10000))
		_weeds.set_meta(&"fit", ROLLER_FIT.get(rmodel, [0.6, true]))
		_casters.append(_weeds)
	# Hops (W4 lava-crust ridges, W5 logs) lie across the whole width.
	var hop_model: String = String(track.kit.get("hop", ""))
	if not track.hops.is_empty() and hop_model != "":
		var hop_xf: Array[Transform3D] = []
		for hs: float in track.hops:
			var hx: Transform3D = _slope_frame(hs, 0.0, 0.0)
			hx.basis = hx.basis.scaled(Vector3((track.width(hs) + 0.6) / 11.0, 1.0, 1.0))
			hop_xf.append(hx)
		var hmesh: Mesh = glb_mesh(hop_model)
		_hops = multi(self, hmesh, hop_xf, RrMats.for_mesh(hmesh))
		_casters.append(_hops)
	# W6 air rings over the jumps, hanging on their cables.
	if not track.rings.is_empty():
		var ring_xf: Array[Transform3D] = []
		for rg: Array in track.rings:
			var rs: float = rg[0]
			var rp: Vector3 = track.world_point(rs, float(rg[1]), 0.0)
			rp.y = track.center(rs).y + float(rg[2]) - 2.7
			ring_xf.append(Transform3D(Basis(Vector3.UP, track.yaw(rs)), rp))
		var ringm: Mesh = glb_mesh("world6/air_ring")
		_rings = multi(self, ringm, ring_xf, RrMats.for_mesh(ringm))
	if bool(look.get("lamps", false)):
		# DESIGN 11.4: two warm omni lights follow the lamps nearest the camera.
		for i: int in 2:
			var o := OmniLight3D.new()
			o.light_color = Color(1.0, 0.62, 0.30)
			o.light_energy = 4.0
			o.omni_range = 14.0
			o.shadow_enabled = false
			add_child(o)
			_omnis.append(o)
	# Swap gates: 11.2 m truss arch; LEDs dormant until the hoverboard unlocks.
	var gm: Mesh = glb_mesh("swap_gate")
	for g: int in track.gates.size():
		var gs: float = track.gates[g][0]
		var xf4: Transform3D = _flat(gs, 0.0, 0.0)
		var span: float = track.width(gs) + 1.0
		if span > 11.2:
			xf4.basis = xf4.basis.scaled(Vector3(span / 11.2, 1.0, 1.0))
		var mi := MeshInstance3D.new()
		mi.mesh = gm
		var mat: ShaderMaterial = _glow_material("swap_gate", false)
		mat.set_shader_parameter("energy", 0.0)
		mi.material_override = mat
		mi.transform = xf4
		add_child(mi)
		_casters.append(mi)
		_gate_mats.append(mat)
	# Finish arch at the line (13.6 m truss), a chequered line on the ground.
	_mesh_node("finish_arch", _flat(track.length, 0.0, 0.0), true)
	_finish_line()
	if track.world_id == 2:
		var towers: Array[Transform3D] = [
			_flat(-12.0, -12.5, 0.0), _flat(track.length + 8.0, 13.5, 0.0)
		]
		for i: int in towers.size():
			var s2: float = -12.0 if i == 0 else track.length + 8.0
			var x2: float = -12.5 if i == 0 else 13.5
			towers[i].origin.y = track.center(s2).y + _ground_lift(s2, x2)
		var tm: Mesh = glb_mesh("water_tower")
		_casters.append(multi(self, tm, towers, RrMats.for_mesh(tm)))


static func _tinted(base: StandardMaterial3D, c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = base.duplicate()
	m.albedo_color = c
	return m


## Three copies of a small mesh side by side (a cone cluster for one Block).
static func _triple(mesh: Mesh, gap: float) -> Mesh:
	var st := SurfaceTool.new()
	for k: int in 3:
		st.append_from(mesh, 0, Transform3D(Basis(), Vector3((float(k) - 1.0) * gap, 0.0, 0.0)))
	var out: ArrayMesh = st.commit()
	out.surface_set_material(0, mesh.surface_get_material(0))
	return out


## Small lift so a landmark beside the track stands on the ground.
func _ground_lift(_s: float, x: float) -> float:
	return clampf((absf(x) - 6.0) * 0.03, 0.0, 0.6)


func _finish_line() -> void:
	var img := Image.create(12, 2, false, Image.FORMAT_RGB8)
	for y: int in 2:
		for x: int in 12:
			var dark: bool = (x + y) % 2 == 0
			img.set_pixel(x, y, Color(0.08, 0.09, 0.11) if dark else Color(0.92, 0.92, 0.92))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.8
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(track.width(track.length), 2.0)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = _slope_frame(track.length, 0.0, 0.02)
	add_child(mi)


## Graphics tier (owner): Høy turns every feature on; Lav keeps the 32-bit
## tablet budget (DESIGN 6, 12): no sun shadow (contact quads instead), no
## glow, MSAA off + FXAA, radiance 64, normal maps on racers only, grass cut
## at 15 m, trees fade at 120 m, no ferns, no sun shafts.
func apply_quality(high: bool) -> void:
	var f: Dictionary = {}
	for k: String in ["shadows", "glow", "msaa", "normals", "veg_far", "shafts"]:
		f[k] = high
	apply_features(f)


func apply_features(f: Dictionary) -> void:
	features = f.duplicate()
	var shadows: bool = f.get("shadows", false)
	sun.shadow_enabled = shadows
	var cast: int = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	for c: GeometryInstance3D in _casters:
		c.cast_shadow = cast
	for v: RrRiderView in views:
		v.set_shadow(shadows)
	fx.set_tier(shadows, f.get("shafts", false))
	var glow: bool = f.get("glow", false)
	env.glow_enabled = glow
	env.glow_intensity = 0.4
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = float(look.get("glow_threshold", 1.2))
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	for i: int in 7:
		env.set_glow_level(i, 1.0 if i in [2, 3] else 0.0)
	_sky.radiance_size = Sky.RADIANCE_SIZE_256 if f.get("msaa", false) else Sky.RADIANCE_SIZE_64
	var vp: Viewport = get_viewport()
	if f.get("msaa", false):
		vp.msaa_3d = Viewport.MSAA_2X
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	else:
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	var normals: bool = f.get("normals", false)
	RrMats.set_quality(normals)
	for m: ShaderMaterial in [_terrain_mat, _lane_mat, _pad_mat]:
		m.set_shader_parameter("use_normals", normals)
	# DESIGN 10a / 11: world-aligned triplanar rock walls (Høy only; W1 keeps
	# its single-axis rock cut).
	_terrain_mat.set_shader_parameter("rock_triplanar", normals and track.world_id >= 2)
	for gm: ShaderMaterial in _gate_mats:
		gm.set_shader_parameter("use_normals", normals)
	var far: bool = f.get("veg_far", false)
	for e: Array in _veg:
		var kind: String = e[0]
		var mmi: MultiMeshInstance3D = e[1]
		var end: float = 0.0
		var model: String = RrWorld.model_of(kind.trim_prefix("card_"))
		if kind.begins_with("lm_"):
			end = 0.0
		elif kind.begins_with("card_lod_"):
			var lod: Array = LODS.get(model, ["", 60.0])
			mmi.visibility_range_begin = float(lod[1]) * (1.0 if far else 0.67)
			end = float(CARD_END.get(model, [300.0, 200.0])[0 if far else 1])
		elif kind.begins_with("lod_"):
			var lod2: Array = LODS.get(model, ["", 60.0])
			end = float(lod2[1]) * (1.0 if far else 0.67) + 4.0
			mmi.visibility_range_end_margin = 4.0
		elif VIS.has(model) and not kind.begins_with("st_"):
			end = float(VIS[model][0 if far else 1])
			if model == "world5/plant_calathea":
				mmi.visible = far  # Lav: one undergrowth layer (DESIGN 11.3)
		elif kind.begins_with("st_"):
			end = RrBalance.PROP_CULL_M  # GDD 11.1 streamers, both tiers
		elif kind.begins_with("near_"):
			# Lav: single cards only (half the tree draws and overdraw).
			end = 75.0  # chunk centres (80 m chunks)
			mmi.visibility_range_end_margin = 4.0
			mmi.visible = far
		elif kind.begins_with("card_"):
			end = 110.0 if far else 95.0
			if track.world_id == 5:
				end = 200.0 if far else 100.0  # the canopy has no far_ trees
			mmi.visibility_range_begin = 75.0 if far else 0.0
		elif kind.begins_with("far_"):
			end = 260.0 if far else 0.0
			mmi.visible = far
		elif kind == "grass_card":
			end = 40.0 if far else 27.0  # 50 m chunks: the own chunk stays on
		elif kind == "fern" and track.world_id == 5:
			end = 45.0
			mmi.visible = far  # DESIGN 12 Lav: ferns off
		elif kind == "fern":
			end = 45.0
			mmi.visible = far
		elif kind == "tape_stake" or kind == "fence_rail":
			end = 160.0
		elif kind == "bush_desert" or kind.begins_with("rock") or kind.begins_with("srock"):
			end = 120.0
			if kind.begins_with("srock_") and kind != "srock_rock_c":
				end = 320.0 if far else 110.0
		elif kind == "dead_trunk":
			end = 150.0
		mmi.visibility_range_end = end
		# Lav: thinner forest and grass (instances are in random order).
		var dense: bool = kind.contains("tree") or kind == "grass_card"
		var n: int = mmi.multimesh.instance_count
		mmi.multimesh.visible_instance_count = n if far or not dense else int(n * 0.6)


# ---------------------------------------------------------------- racers


## Cost-probe hook: show or hide one group of the scene.
func debug_show(group: String, on: bool) -> void:
	for c: Node in get_children() + _static_root.get_children():
		var g: String = ""
		var mo: Material = (c as MeshInstance3D).material_override if c is MeshInstance3D else null
		if mo != null and (mo == _terrain_mat or mo == _terrain_far_mat):
			g = "ground"
		elif mo != null and mo == _lane_mat:
			g = "lanes"
		elif c is RrRiderView:
			g = "racers"
		elif c == fx:
			g = "fx"
		for e: Array in _veg:
			if e[1] == c:
				var k: String = e[0]
				g = (
					"trees"
					if k.contains("tree")
					else ("grass" if k in ["grass_card", "fern"] else "props")
				)
		if g == group:
			(c as Node3D).visible = on


func make_racers(race: RrRace) -> void:
	for v: RrRiderView in views:
		v.queue_free()
	views.clear()
	for r: RrRider in race.riders:
		var view := RrRiderView.new()
		add_child(view)
		view.less_motion = less_motion
		view.build(r.livery)
		views.append(view)
		view.set_shadow(features.get("shadows", false))
	if ghost_view == null:
		_ghost_mat = StandardMaterial3D.new()
		_ghost_mat.albedo_color = Color(
			GHOST_TINT.r, GHOST_TINT.g, GHOST_TINT.b, RrBalance.GHOST_ALPHA
		)
		_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		_ghost_mat.roughness = 0.6
		_ghost_mat.emission_enabled = true
		_ghost_mat.emission = Color(0.25, 0.3, 0.35)
		ghost_view = RrRiderView.new()
		ghost_view.ghost = true
		add_child(ghost_view)
		ghost_view.build(0, _ghost_mat)
	ghost_view.visible = false
	ghost_alpha = 0.0
	if _hay != null:
		for i: int in _hay_xf.size():
			_hay.multimesh.set_instance_transform(i, _hay_xf[i])


func set_gates_live(on: bool) -> void:
	gates_live = on
	for m: ShaderMaterial in _gate_mats:
		m.set_shader_parameter("energy", 1.5 if on else 0.0)


func set_less_motion(on: bool) -> void:
	less_motion = on
	fx.less_motion = on
	for v: RrRiderView in views:
		v.less_motion = on


## GDD 10.8: ghost opacity from its distance to the player; hidden (no draw)
## at GHOST_FADE_NEAR_M and closer, full GHOST_ALPHA from GHOST_FADE_FAR_M.
static func ghost_fade(ds: float, dx: float) -> float:
	var d: float = sqrt(ds * ds + dx * dx)
	var near: float = RrBalance.GHOST_FADE_NEAR_M
	var far: float = RrBalance.GHOST_FADE_FAR_M
	return RrBalance.GHOST_ALPHA * clampf((d - near) / (far - near), 0.0, 1.0)


## Move every racer view to its rider; ghost_row = [s, x, h, vehicle] or [].
func sync(race: RrRace, dt: float, ghost_row: Array) -> void:
	for i: int in race.riders.size():
		var r: RrRider = race.riders[i]
		var view: RrRiderView = views[i]
		view.set_vehicle(r.vehicle, false)
		view.sync_rider(track, r, race.t, dt)
	ghost_alpha = 0.0
	if not ghost_row.is_empty():
		var p: RrRider = race.player
		ghost_alpha = RrWorld.ghost_fade(float(ghost_row[0]) - p.s, float(ghost_row[1]) - p.x)
	if ghost_alpha <= 0.0:
		ghost_view.visible = false
	else:
		ghost_view.visible = true
		_ghost_mat.albedo_color.a = ghost_alpha
		ghost_view.sync_ghost(track, ghost_row, dt)
	_update_hay(race)
	_update_rollers(race)
	_update_pads(dt)
	_update_gates(dt)
	_update_camera(race, dt)
	fx.tick(race, dt, camera, _cam_yaw)
	_update_casters(race, dt)
	_update_world_fx(race, dt)


## Per-world touches: the W1 tunnel darkens the sky light (DESIGN 9a), the
## W5 waterfall flows, the W4 vent puffs, the W6 omni lights follow the
## nearest lamps.
func _update_world_fx(race: RrRace, dt: float) -> void:
	var p: RrRider = race.player
	if track.tunnel.x >= 0.0 and track.world_id == 1:
		var want: float = 0.35 if track.in_tunnel(p.s + 4.0) else _ambient
		env.ambient_light_energy = move_toward(env.ambient_light_energy, want, dt * 2.0)
	for m: StandardMaterial3D in _falls:
		m.uv1_offset.y = fposmod(m.uv1_offset.y - 1.6 * dt, 1.0)
	for i: int in track.kickers.size():
		if track.kicker_models[i] == "vent":
			var on: bool = race.vent_puffing(race.t)
			var lip: float = track.kickers[i]
			if on and not _vent_prev and absf(lip - p.s) < 160.0:
				fx.steam(track.world_point(lip, 0.0, 0.6))
			_vent_prev = on
	if not _omnis.is_empty() and not _lamp_heads.is_empty():
		var cam: Vector3 = camera.global_position
		var fwd: Vector3 = -camera.global_transform.basis.z
		var best: Array = [[1e9, Vector3.ZERO], [1e9, Vector3.ZERO]]
		for h: Vector3 in _lamp_heads:
			var d: Vector3 = h - cam
			if d.dot(fwd) < -6.0:
				continue
			var dd: float = d.length_squared()
			if dd < float(best[0][0]):
				best[1] = best[0]
				best[0] = [dd, h]
			elif dd < float(best[1][0]):
				best[1] = [dd, h]
		for i: int in _omnis.size():
			_omnis[i].visible = (
				float(best[i][0]) < 1e8 and (i == 0 or features.get("shadows", false))
			)
			_omnis[i].global_position = best[i][1]
		# Around the crane jump no lamp stands near the camera: the second light
		# becomes a crane flood over the player (QA 10-07: dark frame).
		var flood: bool = _omnis.size() > 1 and float(best[0][0]) > 900.0
		if flood:
			_omnis[1].visible = true
			_omnis[1].global_position = (
				track.world_point(p.s + 3.0, p.x, 0.0) + Vector3.UP * (track.ramp_height(p.s) + 8.0)
			)
		if _omnis.size() > 1:
			_omnis[1].omni_range = 22.0 if flood else 14.0


func _update_hay(race: RrRace) -> void:
	if _hay == null:
		return
	for i: int in _hay_xf.size():
		var back: float = race.bale_back_at(i)
		var k: float = 1.0
		if back >= 0.0:
			k = 0.0 if race.t < back else clampf((race.t - back) / 0.3, 0.0, 1.0)
		var xf: Transform3D = _hay_xf[i]
		xf.basis = xf.basis.scaled(Vector3.ONE * maxf(k, 0.0001))
		_hay.multimesh.set_instance_transform(i, xf)


func _update_rollers(race: RrRace) -> void:
	if _weeds == null:
		return
	for i: int in track.rollers.size():
		var pose: Array = race.roller_pose(i)
		if pose.is_empty():
			_weeds.multimesh.set_instance_transform(
				i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
			)
			continue
		var s: float = pose[0]
		var x: float = pose[1]
		var spin: float = pose[2]
		var fit: Array = _weeds.get_meta(&"fit", [0.6, true])
		var ch: float = fit[0]
		var c: Vector3 = track.world_point(s, x, ch)
		c.y = track.center(s).y + ch + (absf(sin(spin * 1.3)) * 0.25 if bool(fit[1]) else 0.0)
		var fwd: Vector3 = RrTrack.forward_flat(track.yaw(s))
		var b := Basis(fwd, -spin) * Basis(Vector3.UP, track.yaw(s))
		_weeds.multimesh.set_instance_transform(i, Transform3D(b, c - b * Vector3(0, ch, 0)))


func _update_pads(dt: float) -> void:
	var mm: MultiMesh = _pads.multimesh
	for i: int in _pad_flare.size():
		if _pad_flare[i] > 0.0:
			_pad_flare[i] = maxf(0.0, _pad_flare[i] - dt / 0.2)
			mm.set_instance_custom_data(i, Color(_pad_flare[i], 0, 0, 0))


func _update_gates(dt: float) -> void:
	for i: int in _gate_mats.size():
		if _gate_run[i] < RrBalance.SWAP_FX_S:
			_gate_run[i] += dt
			var k: float = clampf(_gate_run[i] / RrBalance.SWAP_FX_S, 0.0, 1.0)
			_gate_mats[i].set_shader_parameter("run", k if k < 1.0 else -1.0)


## Høy: pine chunks near the player cast shadows, farther ones do not.
func _update_casters(race: RrRace, dt: float) -> void:
	_cast_t -= dt
	if _cast_t > 0.0:
		return
	_cast_t = 0.1
	var on: bool = features.get("shadows", false)
	var p: Vector3 = track.center(race.player.s)
	# Only the player and rivals close to it cast (QA perf fix 1); rivals
	# more than 9 m from the camera ride the low-poly twins (fix 2).
	var cam: Vector3 = camera.global_position
	for i: int in views.size():
		var r: RrRider = race.riders[i]
		views[i].set_shadow(on and (i == 0 or absf(r.s - race.player.s) < 12.0))
		# Lav: rivals always ride the low-poly twins.
		var hi_m: float = 7.0 if features.get("normals", false) else 0.0
		views[i].set_detail(i == 0 or views[i].global_position.distance_to(cam) < hi_m)


# ---------------------------------------------------------------- camera


func _chase_xf(race: RrRace) -> Transform3D:
	var p: RrRider = race.player
	var base: Vector3 = track.world_point(p.s, _cam_x, 0.0)
	var fwd: Vector3 = RrTrack.forward_flat(_cam_yaw)
	var pos: Vector3 = (
		base - fwd * RrBalance.CAM_OFFSET.z + Vector3.UP * (RrBalance.CAM_OFFSET.y + _cam_h)
	)
	var b := Basis(Vector3.UP, _cam_yaw) * Basis(Vector3.RIGHT, deg_to_rad(RrBalance.CAM_PITCH_DEG))
	return Transform3D(b, pos)


func reset_camera(race: RrRace) -> void:
	var p: RrRider = race.player
	_cam_x = p.x
	_cam_yaw = track.yaw(p.s)
	_cam_h = 0.0
	_cam_mode = "intro"
	_cam_t = 0.0
	# QA finding 8: start from a rear 3/4 view, so the swing into the chase
	# view keeps the rider in frame (the front view swung past empty hillside).
	var head: Vector3 = track.world_point(p.s, p.x, 1.2)
	var fwd: Vector3 = RrTrack.forward_flat(_cam_yaw)
	var rt: Vector3 = RrTrack.right_of(_cam_yaw)
	var eye: Vector3 = head - fwd * 3.4 + rt * 3.2 + Vector3.UP * 0.9
	_intro_from = Transform3D(Basis(), eye).looking_at(head, Vector3.UP)
	camera.global_transform = _intro_from
	camera.fov = RrBalance.CAM_FOV
	_fov_base = RrBalance.CAM_FOV
	_boost_blend = 0.0
	_fov_t = 99.0
	_boost_end_t = 99.0


## Hold the front 3/4 view, then ease into the chase view (GDD 10.2).
func skip_intro() -> void:
	_cam_mode = "chase"


func start_finish_shot(_race: RrRace) -> void:
	_cam_mode = "finish"
	_cam_t = 0.0
	_finish_from = camera.global_transform


func fx_boost(on: bool) -> void:
	if on:
		_fov_t = 0.0
		_boost_end_t = 99.0
	else:
		_boost_end_t = 0.0


func fx_land(air: float) -> void:
	if less_motion:
		return
	_dip_t = 0.0
	if air >= RrBalance.LAND_BONUS_MIN_AIR_S:
		_shake_t = 0.0


func _update_camera(race: RrRace, dt: float) -> void:
	if hold_camera:
		return
	var p: RrRider = race.player
	var kpos: float = 1.0 - exp(-RrBalance.CAM_FOLLOW_POS * dt)
	_cam_x = lerpf(_cam_x, p.x, kpos)
	_cam_yaw = lerp_angle(_cam_yaw, track.yaw(p.s), 1.0 - exp(-RrBalance.CAM_FOLLOW_YAW * dt))
	_cam_h = lerpf(_cam_h, p.h, 1.0 - exp(-RrBalance.CAM_FOLLOW_HEIGHT * dt))
	var chase: Transform3D = _chase_xf(race)
	_cam_t += dt
	match _cam_mode:
		"intro":
			var k: float = clampf((_cam_t - 0.6) / 1.0, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			camera.global_transform = _intro_from.interpolate_with(chase, k)
			if k >= 1.0:
				_cam_mode = "chase"
		"finish":
			# Low beside the course just before the arch, looking at the rider
			# as they ride through it (GDD 10.3).
			var fs: float = track.length - 24.0
			var hw: float = track.width(fs) * 0.5
			var eye: Vector3 = track.world_point(fs, -(hw + 3.0), 1.6)
			var arch: Vector3 = track.world_point(track.length, 0.0, 2.6)
			var rider: Vector3 = track.world_point(minf(p.s, track.length + 30.0), p.x, 1.0)
			var lookp: Vector3 = arch.lerp(rider, 0.45)
			var want := Transform3D(Basis(), eye).looking_at(lookp, Vector3.UP)
			var k2: float = clampf(_cam_t / 0.45, 0.0, 1.0)
			if less_motion:
				k2 = 1.0
			camera.global_transform = _finish_from.interpolate_with(
				want, k2 * k2 * (3.0 - 2.0 * k2)
			)
		_:
			var xf: Transform3D = chase
			if _dip_t < 0.15:
				_dip_t += dt
				xf.origin.y -= 0.08 * sin(_dip_t / 0.15 * PI)
			camera.global_transform = xf
	_update_fov(race, dt)
	# Landing shake, else the ground rumble (GDD 11.1): dirt, sand and planks
	# only, never on the hoverboard or the smooth sections.
	var rumble: float = 0.0
	var on_ground: bool = not p.airborne and p.vehicle == RrRider.BIKE and not p.finished
	if on_ground and not track.is_smooth(p.s) and not less_motion and _cam_mode == "chase":
		rumble = minf(RrBalance.RUMBLE_M * p.v / RrBalance.CRUISE_MPS, RrBalance.RUMBLE_MAX_M)
	_rumble_t += dt
	if _shake_t < RrBalance.LAND_SHAKE_S:
		_shake_t += dt
		camera.v_offset = _rng.randf_range(-0.03, 0.03)
		camera.h_offset = _rng.randf_range(-0.03, 0.03)
	elif rumble > 0.0:
		var ph: float = _rumble_t * TAU * RrBalance.RUMBLE_HZ
		camera.v_offset = rumble * sin(ph) * (0.6 + 0.4 * sin(ph * 0.37))
		camera.h_offset = rumble * 0.5 * sin(ph * 0.71 + 1.3)
	else:
		camera.v_offset = 0.0
		camera.h_offset = 0.0


## GDD 11.1 FOV: 70 standing, 75 at cruise, +8 on boost (in 0.15 s, out
## 0.4 s), smoothed 0.25 s. Less motion: fixed 72.
func _update_fov(race: RrRace, dt: float) -> void:
	if less_motion:
		camera.fov = RrBalance.CAM_FOV_LESS_MOTION
		return
	var p: RrRider = race.player
	var k: float = clampf(p.v / RrBalance.CRUISE_MPS, 0.0, 1.0)
	var base: float = lerpf(RrBalance.CAM_FOV, RrBalance.CAM_FOV_CRUISE, k)
	_fov_base = lerpf(_fov_base, base, 1.0 - exp(-dt / 0.25))
	if _boost_end_t < 99.0:
		_boost_end_t += dt
		_boost_blend = 1.0 - clampf(_boost_end_t / RrBalance.CAM_FOV_OUT_S, 0.0, 1.0)
		if _boost_blend <= 0.0:
			_boost_end_t = 99.0
			_fov_t = 99.0
	elif _fov_t < 99.0:
		_fov_t = minf(_fov_t + dt, 50.0)
		var k4: float = clampf(_fov_t / RrBalance.CAM_FOV_IN_S, 0.0, 1.0)
		_boost_blend = 1.0 - (1.0 - k4) * (1.0 - k4)
	if _cam_mode == "finish":
		_boost_blend = move_toward(_boost_blend, 0.0, dt / RrBalance.CAM_FOV_OUT_S)
	camera.fov = _fov_base + RrBalance.CAM_FOV_BOOST_ADD * _boost_blend


# ---------------------------------------------------------------- effects


func fx_pad(i: int, bright: bool) -> void:
	if bright:
		_pad_flare[i] = 1.0


func fx_gate(g: int) -> void:
	if g >= 0 and g < _gate_mats.size() and gates_live:
		_gate_run[g] = 0.0


func rider_pos(i: int, up: float = 0.0) -> Vector3:
	return views[i].global_position + Vector3.UP * up


func screen_pos(world: Vector3) -> Vector2:
	if camera.is_position_behind(world):
		return Vector2(-999, -999)
	return camera.unproject_position(world)
