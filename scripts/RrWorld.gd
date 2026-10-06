class_name RrWorld
extends Node3D

## The 3D scene (DESIGN 6-7): sky, fog and sun, the baked static chunks of
## track 1, the track kit (pads, kickers, hay, swap gates, finish arch), the
## six racers and the ghost, the chase camera and a small particle pool.
## It only draws; RrMain owns the RrRace and calls sync() and the fx_* calls.

const SKY_TOP := Color(0.310, 0.663, 0.910)
const HORIZON := Color(0.839, 0.933, 0.984)
const AMBIENT := Color(0.749, 0.867, 0.949)
const SUN_COL := Color(1.0, 0.941, 0.824)
const SUN := Color(1.0, 0.824, 0.247)
const BAKED_PATH := "res://assets/generated/track1_world.res"

var track: RrTrack
var camera: Camera3D
var env: Environment
var views: Array[RrRiderView] = []
var ghost_view: RrRiderView
var less_motion: bool = false
var gates_live: bool = false
## Build time of the static world (ms) and whether it came from the bake.
var world_ms: int = 0
var world_baked: bool = false

## Graphics features in use (Høy = all on, Lav = all off), see apply_quality.
var features: Dictionary = {}

var _key: DirectionalLight3D
var _psm: ProceduralSkyMaterial
var _pad_mat: ShaderMaterial
var _trail_mat: StandardMaterial3D
var _casters: Array[GeometryInstance3D] = []
var _wheel_dust: GPUParticles3D
var _streaks: GPUParticles3D
var _kit_shader: Shader
var _palette: Texture2D
var _kit_mat: ShaderMaterial
var _pads: MultiMeshInstance3D
var _pad_flare: PackedFloat32Array = PackedFloat32Array()
var _bales: Array[MeshInstance3D] = []
var _curtains: Array[MeshInstance3D] = []
var _curtain_t: PackedFloat32Array = PackedFloat32Array([9.0, 9.0])
var _sky_rig: Node3D
var _clouds: MeshInstance3D
var _fx: Dictionary = {}
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _trail_pts: Array[Vector3] = []

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
var _intro_from: Transform3D
var _finish_from: Transform3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 5
	_kit_shader = load("res://shaders/rr_kit.gdshader")
	_palette = load("res://assets/textures/rr_palette.png")
	_kit_mat = ShaderMaterial.new()
	_kit_mat.shader = _kit_shader
	_kit_mat.set_shader_parameter("palette", _palette)
	_build_environment()
	_build_camera()


func setup(trk: RrTrack) -> void:
	track = trk
	var path := Path3D.new()
	path.name = "CentreLine"
	path.curve = track.make_curve()
	add_child(path)
	_build_static()
	_build_kit()
	_build_far()
	_build_fx()


# ---------------------------------------------------------------- build


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = SKY_TOP
	psm.sky_horizon_color = HORIZON
	psm.sky_curve = 0.12
	psm.ground_bottom_color = HORIZON
	psm.ground_horizon_color = HORIZON
	psm.sun_angle_max = 0.0
	psm.sun_curve = 0.0
	sky.sky_material = psm
	_psm = psm
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = false
	env.ssao_enabled = false
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = HORIZON
	env.fog_light_energy = 1.0
	env.fog_density = 0.7
	env.fog_depth_begin = RrBalance.FOG_BEGIN
	env.fog_depth_end = RrBalance.FOG_END
	env.fog_depth_curve = 1.0
	env.fog_sky_affect = 0.0
	env.fog_sun_scatter = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	_key = key
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 45.0
	key.shadow_bias = 0.06
	key.shadow_normal_bias = 1.2
	key.shadow_blur = 1.5
	key.light_color = SUN_COL
	key.light_energy = 1.0
	key.shadow_enabled = false
	key.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	key.rotation_degrees = Vector3(-48.6, -26.6, 0.0)
	add_child(key)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = RrBalance.CAM_FOV
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.3
	camera.far = RrBalance.CAM_FAR
	camera.current = true
	add_child(camera)


func _build_static() -> void:
	var t0: int = Time.get_ticks_msec()
	var list: Array = []
	if ResourceLoader.exists(BAKED_PATH):
		var baked: Resource = load(BAKED_PATH)
		if baked != null and int(baked.get_meta(&"version", -1)) == RrWorldBake.VERSION:
			list = baked.get_meta(&"chunks", [])
			world_baked = true
	if list.is_empty():
		var gen := RrWorldGen.new()
		gen.build(track)
		list = gen.meshes()
	for e: Array in list:
		var mi := MeshInstance3D.new()
		mi.mesh = e[0]
		mi.material_override = _kit_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var near: bool = e[2]
		mi.visibility_range_end = 330.0 if near else 470.0
		add_child(mi)
	world_ms = Time.get_ticks_msec() - t0


func _glb_mesh(name: String) -> Mesh:
	var root: Node = (load("res://assets/models/%s.glb" % name) as PackedScene).instantiate()
	var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	var m: Mesh = mi.mesh
	root.free()
	return m


func _glb_node(name: String, xf: Transform3D) -> Node3D:
	var n: Node3D = (load("res://assets/models/%s.glb" % name) as PackedScene).instantiate()
	for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = _kit_mat
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.transform = xf
	add_child(n)
	for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
		_casters.append(mi as GeometryInstance3D)
	return n


## Flat frame at s (yaw only), origin at lateral x and height h.
func _flat(s: float, x: float, h: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, track.yaw(s)), track.world_point(s, x, h))


func _build_kit() -> void:
	# Speed pads: one MultiMesh, 3 x 4 m each, flare in the custom data.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _glb_mesh("boost_pad")
	mm.instance_count = RrTrack.PADS.size()
	for i: int in RrTrack.PADS.size():
		var pad: Array = RrTrack.PADS[i]
		var xf: Transform3D = _slope_frame(float(pad[0]), float(pad[1]), 0.04)
		xf.basis = xf.basis.scaled(Vector3(RrBalance.PAD_W_M / 2.5, 1.0, RrBalance.PAD_L_M / 2.1))
		mm.set_instance_transform(i, xf)
		mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
	_pad_flare.resize(RrTrack.PADS.size())
	_pad_flare.fill(0.0)
	_pads = MultiMeshInstance3D.new()
	_pads.multimesh = mm
	var pm := ShaderMaterial.new()
	_pad_mat = pm
	pm.shader = load("res://shaders/rr_pad.gdshader")
	pm.set_shader_parameter("palette", _palette)
	_pads.material_override = pm
	_pads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pads)
	# Kickers: ramp.glb stretched across the full width, lip at the kicker s.
	var rm := MultiMesh.new()
	rm.transform_format = MultiMesh.TRANSFORM_3D
	rm.mesh = _glb_mesh("ramp")
	rm.instance_count = RrTrack.KICKERS.size()
	for i: int in RrTrack.KICKERS.size():
		var s0: float = RrTrack.KICKERS[i] - RrBalance.KICKER_LEN_M
		var xf2: Transform3D = _slope_frame(s0, 0.0, 0.0)
		xf2.basis = xf2.basis.scaled(Vector3((track.width(s0) + 0.6) / 4.6, 1.0, 1.0))
		rm.set_instance_transform(i, xf2)
	var ramps := MultiMeshInstance3D.new()
	ramps.multimesh = rm
	ramps.material_override = _kit_mat
	ramps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ramps)
	_casters.append(ramps)
	# Hay bales.
	var bale: ArrayMesh = _bale_mesh()
	for h: Array in RrTrack.HAY:
		var mi := MeshInstance3D.new()
		mi.mesh = bale
		mi.material_override = _kit_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transform = _flat(float(h[0]), float(h[1]), 0.0)
		add_child(mi)
		_bales.append(mi)
		_casters.append(mi)
	# Swap gates: G1 turns bikes into boards (board sign), G2 back (bike sign).
	for g: int in RrTrack.GATES.size():
		var gate: Array = RrTrack.GATES[g]
		var gs: float = gate[0]
		var model: String = "swap_gate_board" if int(gate[1]) == RrRider.BOARD else "swap_gate_bike"
		var xf3: Transform3D = _flat(gs, 0.0, 0.0)
		var wide: float = (track.width(gs) + 1.2) / 9.0
		xf3.basis = xf3.basis.scaled(Vector3(wide, 1.0, 1.0))
		_glb_node(model, xf3)
		var cur := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(9.0 * wide * 0.86, 5.4 if int(gate[1]) == RrRider.BOARD else 6.6)
		cur.mesh = q
		var cm := ShaderMaterial.new()
		cm.shader = load("res://shaders/rr_curtain.gdshader")
		cur.material_override = cm
		cur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cur.transform = _flat(gs, 0.0, q.size.y * 0.5)
		cur.visible = false
		add_child(cur)
		_curtains.append(cur)
	# Finish arch at the line.
	var fx: Transform3D = _flat(track.length, 0.0, 0.0)
	fx.basis = fx.basis.scaled(Vector3((track.width(track.length) + 1.0) / 11.1, 1.0, 1.0))
	_glb_node("finish_arch", fx)


## Frame at s that follows the slope (pads and ramps sit on the surface).
func _slope_frame(s: float, x: float, h: float) -> Transform3D:
	var f: Transform3D = track.frame(s)
	f.origin = track.world_point(s, x, h)
	return f


func _bale_mesh() -> ArrayMesh:
	var mb := RrMeshBuilder.new()
	var sides: int = 10
	var r: float = 0.5
	var half: float = 0.8
	for k: int in sides:
		var a0: float = TAU * float(k) / float(sides)
		var a1: float = TAU * float(k + 1) / float(sides)
		var p0 := Vector3(0.0, r + sin(a0) * r, cos(a0) * r)
		var p1 := Vector3(0.0, r + sin(a1) * r, cos(a1) * r)
		var out: Vector3 = ((p0 + p1) * 0.5 - Vector3(0, r, 0)).normalized()
		mb.quad_out(
			p0 + Vector3(-half, 0, 0),
			p1 + Vector3(-half, 0, 0),
			p1 + Vector3(half, 0, 0),
			p0 + Vector3(half, 0, 0),
			"pebble" if k % 3 != 0 else "dirt_mid",
			out
		)
		for sx: float in [-half, half]:
			mb.tri_out(
				Vector3(sx, r, 0),
				p0 + Vector3(sx, 0, 0),
				p1 + Vector3(sx, 0, 0),
				"wood",
				Vector3(sx, 0, 0)
			)
	return mb.commit()


## Mountains and clouds ride with the camera (they read as infinitely far).
func _build_far() -> void:
	_sky_rig = Node3D.new()
	add_child(_sky_rig)
	var far := ShaderMaterial.new()
	far.shader = load("res://shaders/rr_far.gdshader")
	far.set_shader_parameter("palette", _palette)
	far.set_shader_parameter("haze", 0.45)
	var mb := RrMeshBuilder.new()
	for i: int in 12:
		var ang: float = TAU * float(i) / 12.0 + _rng.randf_range(-0.15, 0.15)
		var dist: float = _rng.randf_range(330.0, 400.0)
		var c := Vector3(sin(ang) * dist, -60.0, cos(ang) * dist)
		var h: float = _rng.randf_range(95.0, 150.0)
		var rad: float = _rng.randf_range(80.0, 120.0)
		_mountain(mb, c, h, rad, i)
	var mtn := MeshInstance3D.new()
	mtn.mesh = mb.commit()
	mtn.material_override = far
	mtn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sky_rig.add_child(mtn)
	var cloud_mat := ShaderMaterial.new()
	cloud_mat.shader = far.shader
	cloud_mat.set_shader_parameter("palette", _palette)
	cloud_mat.set_shader_parameter("haze", 0.0)
	var cb := RrMeshBuilder.new()
	for i: int in 26:
		var ang2: float = TAU * float(i) / 26.0 + _rng.randf_range(-0.12, 0.12)
		var dist2: float = _rng.randf_range(120.0, 240.0)
		var c2 := Vector3(sin(ang2) * dist2, _rng.randf_range(16.0, 58.0), cos(ang2) * dist2)
		var sc: float = _rng.randf_range(3.0, 5.5)
		for k: int in _rng.randi_range(4, 6):
			var o := Vector3(_rng.randf_range(-2.2, 2.2), _rng.randf_range(-0.3, 0.6), 0.0) * sc
			o.z = _rng.randf_range(-1.0, 1.0) * sc
			var rr: float = _rng.randf_range(1.0, 1.7) * sc
			cb.ico(c2 + o, Vector3(rr, rr * 0.75, rr), "cloud", 1, "cloud_shade")
	_clouds = MeshInstance3D.new()
	_clouds.mesh = cb.commit()
	_clouds.material_override = cloud_mat
	_clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sky_rig.add_child(_clouds)


func _mountain(mb: RrMeshBuilder, c: Vector3, h: float, r: float, seed_i: int) -> void:
	var n: int = 7
	var top := c + Vector3(0.0, h, 0.0)
	var mid: Array[Vector3] = []
	var base: Array[Vector3] = []
	for k: int in n:
		var a: float = TAU * float(k) / float(n) + float(seed_i)
		var rk: float = r * (0.8 + 0.4 * absf(sin(float(k * 7 + seed_i))))
		base.append(c + Vector3(cos(a) * rk, 0.0, sin(a) * rk))
		mid.append(c + Vector3(cos(a) * rk * 0.32, h * 0.68, sin(a) * rk * 0.32))
	for k: int in n:
		var k2: int = (k + 1) % n
		var out := Vector3(
			base[k].x + base[k2].x - 2.0 * c.x, 0.0, base[k].z + base[k2].z - 2.0 * c.z
		)
		mb.quad_out(base[k], base[k2], mid[k2], mid[k], "mountain", out + Vector3.UP * r * 0.3)
		mb.tri_out(mid[k], mid[k2], top, "snow", out + Vector3.UP * r)


func _build_fx() -> void:
	_fx["dust"] = _emitter(10, 0.55, Color(0.827, 0.604, 0.388), 0.22, 2.0)
	_fx["sparkle"] = _emitter(12, 0.45, Color(1.0, 0.902, 0.502), 0.12, 3.5)
	_fx["straw"] = _emitter(20, 0.6, Color(0.902, 0.827, 0.722), 0.14, 4.0)
	_fx["puff"] = _emitter(16, 0.35, Color(1, 1, 1), 0.35, 5.0)
	_fx["confetti"] = _emitter(36, 1.8, Color(1, 1, 1), 0.14, 6.0)
	var conf: CPUParticles3D = _fx["confetti"]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray(
		[
			Color(0.949, 0.329, 0.239),
			Color(1.0, 0.824, 0.247),
			Color(0.243, 0.608, 0.859),
			Color(0.071, 0.627, 0.561),
			Color(1, 1, 1)
		]
	)
	conf.color_initial_ramp = g
	conf.gravity = Vector3(0, -4.0, 0)
	_trail_mesh = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.mesh = _trail_mesh
	var tm := StandardMaterial3D.new()
	_trail_mat = tm
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tm.vertex_color_use_as_albedo = true
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail.material_override = tm
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)
	_build_gpu_fx()


## Høy tier GPU particles: dust off the player's back wheel and 3D speed
## streaks around the view axis while boosting.
func _build_gpu_fx() -> void:
	_wheel_dust = GPUParticles3D.new()
	_wheel_dust.amount = 28
	_wheel_dust.lifetime = 0.7
	_wheel_dust.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0.6)
	pm.spread = 35.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0, -0.6, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.25, 0.05, 0.2)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.55))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	pm.color = Color(0.83, 0.65, 0.45)
	_wheel_dust.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.38, 0.38)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = RrRiderView.radial_texture(Color(1, 1, 1, 1))
	q.material = m
	_wheel_dust.draw_pass_1 = q
	_wheel_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wheel_dust.emitting = false
	add_child(_wheel_dust)
	_streaks = GPUParticles3D.new()
	_streaks.amount = 40
	_streaks.lifetime = 0.35
	_streaks.local_coords = true
	var sp := ParticleProcessMaterial.new()
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	sp.emission_ring_axis = Vector3(0, 0, 1)
	sp.emission_ring_radius = 3.2
	sp.emission_ring_inner_radius = 2.0
	sp.emission_ring_height = 2.0
	sp.direction = Vector3(0, 0, 1)
	sp.spread = 0.0
	sp.initial_velocity_min = 38.0
	sp.initial_velocity_max = 48.0
	sp.gravity = Vector3.ZERO
	sp.particle_flag_align_y = true
	_streaks.process_material = sp
	var line := BoxMesh.new()
	line.size = Vector3(0.025, 1.8, 0.025)
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.albedo_color = Color(1, 1, 1, RrBalance.SPEED_LINES_ALPHA_MAX)
	line.material = lm
	_streaks.draw_pass_1 = line
	_streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_streaks.emitting = false
	_streaks.position = Vector3(0, 0, -9.0)
	camera.add_child(_streaks)


## Graphics tier (owner 2026-10-06): Høy turns on every feature, Lav keeps
## the DESIGN 7e phone budget (no shadow, no glow, linear tonemap, MSAA off +
## FXAA, CPU particles and HUD speed lines only). Single features can be
## switched for the cost probe in tests/capture.gd.
func apply_quality(high: bool) -> void:
	var f: Dictionary = {}
	for k: String in ["shadows", "glow", "filmic", "sun", "msaa", "gpu_fx", "rim"]:
		f[k] = high
	apply_features(f)


func apply_features(f: Dictionary) -> void:
	features = f.duplicate()
	var shadows: bool = f.get("shadows", false)
	_key.shadow_enabled = shadows
	var cast: int = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	for c: GeometryInstance3D in _casters:
		c.cast_shadow = cast
	for v: RrRiderView in views:
		v.set_high(shadows)
		v.mat.set_shader_parameter("rim", 0.55 if f.get("rim", false) else 0.0)
	var glow: bool = f.get("glow", false)
	env.glow_enabled = glow
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i: int in 7:
		env.set_glow_level(i, 1.0 if i in [1, 2, 3] else 0.0)
	_pad_mat.set_shader_parameter("glow_energy", 3.2 if glow else 1.6)
	_trail_mat.albedo_color = Color(2.2, 2.2, 2.2) if glow else Color(1, 1, 1)
	if f.get("filmic", false):
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 1.32
		env.tonemap_white = 6.0
		env.adjustment_enabled = true
		env.adjustment_saturation = 1.12
		env.adjustment_contrast = 1.05
		env.adjustment_brightness = 1.0
	else:
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.tonemap_exposure = 1.0
		env.adjustment_enabled = false
	var sun: bool = f.get("sun", false)
	_psm.sun_angle_max = 30.0 if sun else 0.0
	_psm.sun_curve = 0.15 if sun else 0.0
	_key.sky_mode = (
		DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY if sun else DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	)
	var vp: Viewport = get_viewport()
	if f.get("msaa", false):
		vp.msaa_3d = Viewport.MSAA_2X
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	else:
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	if not f.get("gpu_fx", false):
		_wheel_dust.emitting = false
		_streaks.emitting = false


func _emitter(n: int, life: float, col: Color, size: float, speed: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = n
	p.lifetime = life
	p.explosiveness = 0.95
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = m
	p.color = col
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.local_coords = false
	add_child(p)
	return p


# ---------------------------------------------------------------- racers


func make_racers(race: RrRace) -> void:
	for v: RrRiderView in views:
		v.queue_free()
	views.clear()
	for r: RrRider in race.riders:
		var view := RrRiderView.new()
		add_child(view)
		view.less_motion = less_motion
		view.build(r.identity, r.team, _kit_shader, _palette)
		views.append(view)
		view.set_high(features.get("shadows", false))
		view.mat.set_shader_parameter("rim", 0.55 if features.get("rim", false) else 0.0)
	if ghost_view == null:
		ghost_view = RrRiderView.new()
		ghost_view.ghost = true
		add_child(ghost_view)
		ghost_view.build("fox", Color(1, 1, 1), load("res://shaders/rr_ghost.gdshader"), _palette)
	ghost_view.visible = false
	for i: int in _bales.size():
		_bales[i].visible = true
		_bales[i].scale = Vector3.ONE


func set_gates_live(on: bool) -> void:
	gates_live = on
	for c: MeshInstance3D in _curtains:
		c.visible = on


func set_less_motion(on: bool) -> void:
	less_motion = on
	for v: RrRiderView in views:
		v.less_motion = on


## Move every racer view to its rider; ghost_row = [s, x, h, vehicle] or [].
func sync(race: RrRace, dt: float, ghost_row: Array) -> void:
	for i: int in race.riders.size():
		var r: RrRider = race.riders[i]
		var view: RrRiderView = views[i]
		view.set_vehicle(r.vehicle, false)
		var trick_k: float = -1.0
		if r.trick_t >= 0.0 and r.trick_len > 0.0:
			trick_k = r.trick_t / r.trick_len
		var wob: float = race.t - (r.bump_until - RrBalance.BUMP_TIME_S)
		view.sync(track, r.s, r.x, r.h, r.lat_v, r.vy, r.v, trick_k, wob, dt)
	if ghost_row.is_empty():
		ghost_view.visible = false
	else:
		ghost_view.visible = true
		ghost_view.set_vehicle(int(ghost_row[3]), true)
		ghost_view.sync(
			track,
			float(ghost_row[0]),
			float(ghost_row[1]),
			float(ghost_row[2]),
			0.0,
			0.0,
			20.0,
			-1.0,
			-1.0,
			dt
		)
	for i: int in _bales.size():
		var back: float = race.bale_back_at(i)
		if back < 0.0 or race.t >= back:
			_bales[i].visible = true
			var grow: float = clampf((race.t - back) / 0.3, 0.0, 1.0) if back >= 0.0 else 1.0
			_bales[i].scale = Vector3.ONE * maxf(0.01, grow)
		else:
			_bales[i].visible = false
	_update_pads(dt)
	_update_curtains(dt)
	_update_trail(race)
	_update_camera(race, dt)
	_update_gpu_fx(race)


func _update_gpu_fx(race: RrRace) -> void:
	if not features.get("gpu_fx", false):
		return
	var p: RrRider = race.player
	var moving: bool = race.phase != RrRace.Phase.PRE and p.v > 8.0
	var dust_on: bool = moving and not p.airborne and not less_motion and not p.finished
	var lane: bool = track.is_smooth(p.s)
	_wheel_dust.emitting = dust_on
	if dust_on:
		var back: Vector3 = -RrTrack.forward_flat(track.yaw(p.s)) * 0.75
		_wheel_dust.global_position = track.world_point(p.s, p.x, 0.12) + back
		_wheel_dust.amount_ratio = clampf(p.v / RrBalance.CRUISE_MPS - 0.3, 0.2, 1.0)
		var ppm: ParticleProcessMaterial = _wheel_dust.process_material
		ppm.color = Color(0.92, 0.97, 1.0) if lane else Color(0.83, 0.65, 0.45)
	var fast: bool = p.v > RrBalance.CRUISE_MPS * RrBalance.SPEED_LINES_FROM
	_streaks.emitting = fast and not less_motion and race.phase == RrRace.Phase.RACE


func _update_pads(dt: float) -> void:
	var mm: MultiMesh = _pads.multimesh
	for i: int in _pad_flare.size():
		if _pad_flare[i] > 0.0:
			_pad_flare[i] = maxf(0.0, _pad_flare[i] - dt / 0.2)
			mm.set_instance_custom_data(i, Color(_pad_flare[i], 0, 0, 0))


func _update_curtains(dt: float) -> void:
	for i: int in _curtains.size():
		if _curtain_t[i] < RrBalance.SWAP_FX_S:
			_curtain_t[i] += dt
			var k: float = clampf(_curtain_t[i] / RrBalance.SWAP_FX_S, 0.0, 1.0)
			var m: ShaderMaterial = _curtains[i].material_override
			m.set_shader_parameter("burst", 1.0 - k if k < 1.0 else 0.0)


func _update_trail(race: RrRace) -> void:
	var p: RrRider = race.player
	_trail_mesh.clear_surfaces()
	if not p.boosting(race.t) or p.finished:
		_trail_pts.clear()
		return
	_trail_pts.push_front(track.world_point(p.s, p.x, p.h + 0.45))
	if _trail_pts.size() > 12:
		_trail_pts.resize(12)
	if _trail_pts.size() < 2:
		return
	var right: Vector3 = RrTrack.right_of(track.yaw(p.s)) * 0.22
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i: int in _trail_pts.size():
		var a: float = 0.55 * (1.0 - float(i) / float(_trail_pts.size() - 1))
		var w: float = 1.0 - float(i) / float(_trail_pts.size())
		_trail_mesh.surface_set_color(Color(SUN.r, SUN.g, SUN.b, a))
		_trail_mesh.surface_add_vertex(_trail_pts[i] - right * w)
		_trail_mesh.surface_set_color(Color(SUN.r, SUN.g, SUN.b, a))
		_trail_mesh.surface_add_vertex(_trail_pts[i] + right * w)
	_trail_mesh.surface_end()


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
	var head: Vector3 = track.world_point(p.s, p.x, 1.0)
	var fwd: Vector3 = RrTrack.forward_flat(_cam_yaw)
	var rt: Vector3 = RrTrack.right_of(_cam_yaw)
	var eye: Vector3 = head + fwd * 4.2 + rt * 2.4 + Vector3.UP * 0.5
	_intro_from = Transform3D(Basis(), eye).looking_at(head, Vector3.UP)
	camera.global_transform = _intro_from
	camera.fov = RrBalance.CAM_FOV


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
			# as they ride through it (GDD 10.3, DESIGN 6a).
			var fs: float = track.length - 16.0
			var hw: float = track.width(fs) * 0.5
			var eye: Vector3 = track.world_point(fs, -(hw + 3.0), 1.6)
			var arch: Vector3 = track.world_point(track.length, 0.0, 2.2)
			var rider: Vector3 = track.world_point(minf(p.s, track.length + 30.0), p.x, 1.0)
			var look: Vector3 = arch.lerp(rider, 0.45)
			var want := Transform3D(Basis(), eye).looking_at(look, Vector3.UP)
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
	# Boost FOV kick (DESIGN 6a / GDD 11).
	var fov_hi: float = RrBalance.CAM_FOV_LESS_MOTION if less_motion else RrBalance.CAM_FOV_BOOST
	if _boost_end_t < 99.0:
		_boost_end_t += dt
		var k3: float = clampf(_boost_end_t / RrBalance.CAM_FOV_OUT_S, 0.0, 1.0)
		camera.fov = lerpf(fov_hi, RrBalance.CAM_FOV, k3)
		if k3 >= 1.0:
			_boost_end_t = 99.0
	elif _fov_t < 99.0:
		_fov_t += dt
		var k4: float = clampf(_fov_t / RrBalance.CAM_FOV_IN_S, 0.0, 1.0)
		camera.fov = lerpf(RrBalance.CAM_FOV, fov_hi, 1.0 - (1.0 - k4) * (1.0 - k4))
	if _shake_t < RrBalance.LAND_SHAKE_S:
		_shake_t += dt
		camera.v_offset = _rng.randf_range(-0.03, 0.03)
		camera.h_offset = _rng.randf_range(-0.03, 0.03)
	else:
		camera.v_offset = 0.0
		camera.h_offset = 0.0
	_sky_rig.global_position = camera.global_position
	_clouds.position.x = fmod(race.t * 0.5, 60.0)


# ---------------------------------------------------------------- effects


func fx_burst(kind: String, pos: Vector3, tint: Color = Color(0, 0, 0, 0)) -> void:
	var p: CPUParticles3D = _fx.get(kind)
	if p == null:
		return
	if tint.a > 0.0:
		p.color = tint
	p.global_position = pos
	p.restart()
	p.emitting = true


func fx_pad(i: int, bright: bool) -> void:
	if bright:
		_pad_flare[i] = 1.0


func fx_gate(g: int) -> void:
	if g >= 0 and g < _curtains.size():
		_curtain_t[g] = 0.0


func rider_pos(i: int, up: float = 0.0) -> Vector3:
	return views[i].global_position + Vector3.UP * up


func screen_pos(world: Vector3) -> Vector2:
	if camera.is_position_behind(world):
		return Vector2(-999, -999)
	return camera.unproject_position(world)
