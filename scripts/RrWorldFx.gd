class_name RrWorldFx
extends Node3D

## Effects of one world (DESIGN 7, 9-10): the dust pool and flake pool (one
## MultiMesh draw each), knock-off stones, contact-shadow quads for Lav, the
## hoverboard under-glow, and the world's weather (W1 pollen, falling needles
## and sun shafts; W2 blowing sand and two distant dust devils; W3 snowfall;
## W4 ash flakes and rising embers; W5 rain streaks; W6 drizzle), and the W4
## steam-vent puffs. Flash rule: nothing here flashes; puffs only fade.

var track: RrTrack
var look: Dictionary = {}
var less_motion: bool = false

var _dust: RrPuffs
var _flakes: RrPuffs
var _stones: RrPuffs
var _contacts: MultiMeshInstance3D
var _glows: MultiMeshInstance3D
var _weather: Array[GPUParticles3D] = []
var _shafts: MultiMeshInstance3D
var _roll_dust_t: PackedFloat32Array = PackedFloat32Array()
var _rng := RandomNumberGenerator.new()


func setup(trk: RrTrack) -> void:
	track = trk
	look = trk.look
	_rng.seed = 9
	_build_fx()
	_build_weather()


## Høy: the sun casts real shadows, so no contact quads; shafts only in Høy.
func set_tier(sun_shadows: bool, shafts: bool) -> void:
	_contacts.visible = not sun_shadows
	if _shafts != null:
		_shafts.visible = shafts
	# Lav (32-bit tablet, <= 60 draws): one weather layer per world.
	for i: int in range(1, _weather.size()):
		_weather[i].visible = shafts


func tick(race: RrRace, dt: float, camera: Camera3D, cam_yaw: float) -> void:
	var cam_b: Basis = camera.global_transform.basis
	_update_contacts(race)
	_roll_dust(race, dt)
	_dust.tick(dt, cam_b)
	_flakes.tick(dt, cam_b)
	_stones.tick(dt, cam_b)
	_update_weather(race, camera, cam_yaw)


func _sprite_mat(
	tex_name: String, additive: bool = false, shaded: bool = false
) -> StandardMaterial3D:
	return _sprite_mat_at("res://assets/textures/fx/%s.png" % tex_name, additive, shaded)


func _sprite_mat_at(path: String, additive: bool, shaded: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = (
		BaseMaterial3D.SHADING_MODE_PER_PIXEL if shaded else BaseMaterial3D.SHADING_MODE_UNSHADED
	)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load(path)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m


func _build_fx() -> void:
	var shadow_tex: Texture2D = load("res://assets/textures/fx/contact_shadow.png")
	var q := QuadMesh.new()
	_dust = RrPuffs.new()
	_dust.setup(160, q, _sprite_mat("dust_puff", false, true))
	add_child(_dust)
	_flakes = RrPuffs.new()
	_flakes.setup(96, q, _sprite_mat("pollen"))
	add_child(_flakes)
	_stones = RrPuffs.new()
	var rock: Mesh = RrWorld.glb_mesh("rock_c")
	var rm: Material = RrMats.for_mesh(rock)
	if track.world_id == 2:
		rm = RrWorld.sandstone(rm as StandardMaterial3D)
	elif track.world_id == 4:
		rm = RrWorld._tinted(rm as StandardMaterial3D, Color(0.3, 0.28, 0.27))
	_stones.setup(8, rock, rm, false)
	add_child(_stones)
	# Contact shadow quads under each racer (Lav: the sun casts no shadow).
	var cq := QuadMesh.new()
	cq.orientation = PlaneMesh.FACE_Y
	cq.size = Vector2(1.0, 2.1)
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.albedo_texture = shadow_tex
	cm.albedo_color = Color(0, 0, 0, 0.75)
	cm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var none: Array[Transform3D] = []
	for i: int in 6:
		none.append(Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	_contacts = RrWorld.multi(self, cq, none, cm)
	_contacts.custom_aabb = AABB(Vector3(-5000, -2000, -5000), Vector3(10000, 4000, 10000))
	# Hoverboard under-glow (DESIGN 7): additive cyan quads under board riders.
	var gq := QuadMesh.new()
	gq.orientation = PlaneMesh.FACE_Y
	gq.size = Vector2(0.9, 1.6)
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gmat.albedo_texture = shadow_tex
	gmat.albedo_color = Color(0.561, 0.875, 1.0, 0.25)
	gmat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_glows = RrWorld.multi(self, gq, none, gmat)
	_glows.custom_aabb = _contacts.custom_aabb
	_roll_dust_t.resize(6)
	_roll_dust_t.fill(0.0)


func _particles(amount: int, life: float, tex_name: String, size: Vector2) -> GPUParticles3D:
	return _particles_at(amount, life, "res://assets/textures/fx/%s.png" % tex_name, size, false)


func _particles_at(
	amount: int, life: float, path: String, size: Vector2, additive: bool
) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
	var q := QuadMesh.new()
	q.size = size
	var m := _sprite_mat_at(path, additive, false)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	_weather.append(p)
	return p


## Falling weather for worlds 3-6 (DESIGN 11): one box emitter round the
## camera; W4 adds rising embers (Høy only, like every second layer).
func _build_weather36(kind: String) -> void:
	var d: String = "res://assets/textures/world%d/" % track.world_id
	var spec: Dictionary = {
		"snow":
		["fx_snowflake", 400, 6.0, Vector2(0.07, 0.07), Vector3(0.6, -1.1, 0.2), 0.9, false],
		"ash":
		["fx_ash_flake", 260, 6.0, Vector2(0.06, 0.06), Vector3(0.4, -0.8, 0.1), 0.85, false],
		"rain":
		["fx_rain_streak", 200, 0.9, Vector2(0.03, 0.35), Vector3(0.0, -14.0, 0.0), 0.18, false],
		"drizzle":
		["fx_drizzle", 260, 1.2, Vector2(0.02, 0.36), Vector3(0.3, -9.0, 0.0), 0.55, false],
	}
	var sp: Array = spec.get(kind, spec["snow"])
	var p: GPUParticles3D = _particles_at(
		int(sp[1]), float(sp[2]), d + String(sp[0]) + ".png", sp[3], false
	)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(15, 8, 18)
	var v: Vector3 = sp[4]
	pm.direction = v.normalized()
	pm.spread = 8.0
	pm.initial_velocity_min = v.length() * 0.8
	pm.initial_velocity_max = v.length() * 1.2
	pm.gravity = Vector3.ZERO
	pm.color = Color(1, 1, 1, float(sp[5]))
	if kind == "rain" or kind == "drizzle":
		# Streaks hang along their fall: no billboard spin.
		(p.draw_pass_1.surface_get_material(0) as StandardMaterial3D).billboard_mode = (
			BaseMaterial3D.BILLBOARD_FIXED_Y
		)
	p.process_material = pm
	if kind == "ash":
		var em: GPUParticles3D = _particles_at(
			40, 3.0, d + "fx_ember.png", Vector2(0.05, 0.05), true
		)
		var am := ParticleProcessMaterial.new()
		am.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		am.emission_box_extents = Vector3(14, 2, 16)
		am.direction = Vector3(0.1, 1.0, 0.0)
		am.spread = 25.0
		am.initial_velocity_min = 0.8
		am.initial_velocity_max = 1.6
		am.gravity = Vector3.ZERO
		am.color = Color(1.0, 0.45, 0.12, 0.9)
		em.process_material = am


## One weather emitter per world plus distance dressing (DESIGN 9, 10).
func _build_weather() -> void:
	var wk: String = String(look["weather"])
	if wk in ["snow", "ash", "rain", "drizzle"]:
		_build_weather36(wk)
		return
	if wk == "pollen":
		var pollen: GPUParticles3D = _particles(300, 7.0, "pollen", Vector2(0.04, 0.04))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(15, 7, 15)
		pm.direction = Vector3(0.3, 0.2, 0.1)
		pm.spread = 180.0
		pm.initial_velocity_min = 0.05
		pm.initial_velocity_max = 0.4
		pm.gravity = Vector3(0.1, -0.03, 0.0)
		pm.turbulence_enabled = false
		pm.color = Color(1, 1, 1, 0.35)
		pollen.process_material = pm
		var needles: GPUParticles3D = _particles(80, 5.0, "speed_streak", Vector2(0.015, 0.09))
		var nm := ParticleProcessMaterial.new()
		nm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		nm.emission_box_extents = Vector3(14, 6, 14)
		nm.direction = Vector3(0, -1, 0)
		nm.initial_velocity_min = 0.5
		nm.initial_velocity_max = 1.0
		nm.gravity = Vector3(0.15, -0.25, 0.0)
		nm.angle_min = -40.0
		nm.angle_max = 40.0
		nm.color = Color(0.45, 0.33, 0.20, 0.8)
		needles.process_material = nm
		_build_shafts()
	else:
		var sand: GPUParticles3D = _particles(200, 2.2, "sand_streak", Vector2(0.9, 0.12))
		var sm := ParticleProcessMaterial.new()
		sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		sm.emission_box_extents = Vector3(16, 1.2, 18)
		sm.direction = Vector3(1, 0.02, 0.2)
		sm.spread = 6.0
		sm.initial_velocity_min = 6.0
		sm.initial_velocity_max = 9.0
		sm.gravity = Vector3.ZERO
		sm.color = Color(0.886, 0.706, 0.549, 0.20)
		sand.process_material = sm
		for i: int in 2:
			var devil: GPUParticles3D = _particles(40, 3.0, "dust_puff", Vector2(2.2, 2.2))
			var dm := ParticleProcessMaterial.new()
			dm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			dm.emission_ring_axis = Vector3.UP
			dm.emission_ring_radius = 1.2
			dm.emission_ring_inner_radius = 0.4
			dm.emission_ring_height = 0.5
			dm.direction = Vector3.UP
			dm.spread = 10.0
			dm.initial_velocity_min = 3.0
			dm.initial_velocity_max = 5.0
			dm.orbit_velocity_min = 0.6
			dm.orbit_velocity_max = 0.9
			dm.gravity = Vector3.ZERO
			dm.scale_min = 0.6
			dm.scale_max = 2.0
			dm.color = Color(0.80, 0.62, 0.48, 0.30)
			devil.process_material = dm
			devil.local_coords = true
			devil.visibility_aabb = AABB(Vector3(-10, -2, -10), Vector3(20, 25, 20))


## Sun shafts (W1, Høy only): six faint additive cards on the sunny side.
func _build_shafts() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 22.0)
	var m := _sprite_mat("speed_streak", true)
	m.albedo_color = Color(1.0, 0.945, 0.863, 0.06)
	m.vertex_color_use_as_albedo = false
	var xfs: Array[Transform3D] = []
	for i: int in 6:
		var b := Basis(Vector3.UP, 0.4 + float(i) * 0.1) * Basis(Vector3.BACK, -0.35)
		xfs.append(Transform3D(b, Vector3(9.0 + float(i % 3) * 5.0, 9.0, -18.0 - float(i) * 9.0)))
	_shafts = RrWorld.multi(self, q, xfs, m)
	_shafts.custom_aabb = AABB(Vector3(-60, -40, -120), Vector3(120, 80, 140))


func _update_contacts(race: RrRace) -> void:
	var lav: bool = _contacts.visible
	var any_board: bool = false
	for i: int in race.riders.size():
		var r: RrRider = race.riders[i]
		var base := Transform3D(
			Basis(Vector3.UP, track.yaw(r.s)), track.world_point(r.s, r.x, 0.04)
		)
		base.origin.y = track.center(r.s).y + track.ramp_height(r.s) + 0.04
		var air: float = clampf(r.h / 3.0, 0.0, 1.0)
		if lav:
			var k: float = lerpf(1.0, 0.6, air) if not r.down() else 0.0
			_contacts.multimesh.set_instance_transform(
				i, Transform3D(base.basis.scaled(Vector3.ONE * k), base.origin)
			)
		var on_board: bool = r.vehicle == RrRider.BOARD and not r.down()
		any_board = any_board or on_board
		var g: float = 1.0 if on_board else 0.0
		_glows.multimesh.set_instance_transform(
			i, Transform3D(base.basis.scaled(Vector3.ONE * g), base.origin + Vector3.UP * 0.02)
		)
	# No board on the track: the glow layer costs no draw call.
	_glows.visible = any_board


## DESIGN 7 rolling dust: two puffs per second behind each rear wheel, near
## the camera only, never on the hoverboard or in the air.
func _roll_dust(race: RrRace, dt: float) -> void:
	if less_motion or race.phase == RrRace.Phase.PRE:
		return
	var dust_col: Color = look["dust"]
	for i: int in race.riders.size():
		var r: RrRider = race.riders[i]
		if r.airborne or r.v < 6.0 or r.vehicle == RrRider.BOARD or r.finished:
			continue
		if absf(r.s - race.player.s) > 60.0:
			continue
		_roll_dust_t[i] -= dt
		if _roll_dust_t[i] > 0.0:
			continue
		_roll_dust_t[i] = 0.5 * (0.9 + _rng.randf() * 0.2)
		var smooth: bool = track.is_smooth(r.s)
		var back: Vector3 = -RrTrack.forward_flat(track.yaw(r.s)) * 0.7
		var p: Vector3 = track.world_point(r.s, r.x, r.h + 0.25) + back
		p.y = track.center(r.s).y + r.h + 0.3
		var col: Color = dust_col
		col.a = 1.0
		_dust.emit(
			p, Vector3(0, 0.4, 0) + back * 0.6, col, 0.8, 1.1, 2.0, 0.08 if smooth else 0.16, 1.5
		)


func _update_weather(race: RrRace, camera: Camera3D, yaw: float) -> void:
	var p: Vector3 = camera.global_position
	var fwd: Vector3 = RrTrack.forward_flat(yaw)
	var rt: Vector3 = RrTrack.right_of(yaw)
	if _weather.is_empty():
		return
	var wk: String = String(look["weather"])
	if wk in ["snow", "ash", "rain", "drizzle"]:
		for i: int in _weather.size():
			_weather[i].global_position = p + fwd * 12.0 + Vector3.UP * (4.0 if i == 0 else -2.0)
		return
	if wk == "pollen":
		_weather[0].global_position = p + fwd * 10.0
		_weather[1].global_position = p + fwd * 12.0 + Vector3.UP * 3.0
		if _shafts != null:
			_shafts.global_transform = Transform3D(Basis(Vector3.UP, yaw), p)
	else:
		_weather[0].global_position = p + fwd * 12.0 - rt * 14.0 - Vector3.UP * 1.5
		var s_ahead: float = minf(race.player.s + 160.0, track.length)
		for i: int in 2:
			var side: float = -1.0 if i == 0 else 1.0
			var lat: float = side * (track.width(s_ahead) * 0.5 + 7.0 + float(i) * 3.0)
			var dp: Vector3 = track.world_point(s_ahead + float(i) * 60.0, lat)
			dp.y = track.center(s_ahead + float(i) * 60.0).y
			_weather[1 + i].global_position = dp


## Dust burst (DESIGN 7): n puffs in a ring of radius r, trail-dust colour.
func dust(pos: Vector3, n: int, ring: float, alpha: float, up: Vector2, size: Vector2) -> void:
	var col: Color = look["dust"]
	for i: int in n:
		var a: float = _rng.randf() * TAU
		var o := Vector3(cos(a), 0.0, sin(a)) * ring * _rng.randf_range(0.5, 1.0)
		var v := Vector3(o.x * 0.8, _rng.randf_range(up.x, up.y), o.z * 0.8)
		_dust.emit(pos + o * 0.5, v, col, RrBalance.KNOCK_DUST_S, size.x, size.y, alpha, 2.0, 0.0)


## Knock-off: 20 dust puffs in a 1.5 m ring and 6 small stones (DESIGN 7).
func knock(pos: Vector3) -> void:
	if less_motion:
		return
	dust(pos, RrBalance.KNOCK_DUST_PARTICLES, 1.5, 0.35, Vector2(1.5, 3.0), Vector2(0.8, 2.4))
	for i: int in 6:
		var a: float = _rng.randf() * TAU
		var v := Vector3(
			cos(a) * _rng.randf_range(2.0, 4.0), _rng.randf_range(2.0, 4.0), sin(a) * 2.0
		)
		_stones.emit(pos + Vector3.UP * 0.2, v, Color(1, 1, 1), 0.9, 0.06, 0.06, 1.0, 0.0, 9.8)


## Small flakes (hay straw, tumbleweed twigs, mud drops, sparks, confetti).
func flakes(pos: Vector3, n: int, col: Color, speed: float, life: float = 0.7) -> void:
	if less_motion:
		return
	for i: int in n:
		var v := Vector3(
			_rng.randf_range(-1, 1), _rng.randf_range(0.4, 1.2), _rng.randf_range(-1, 1)
		)
		_flakes.emit(
			pos,
			v.normalized() * speed * _rng.randf_range(0.5, 1.0),
			col,
			life,
			0.07,
			0.05,
			1.0,
			1.0,
			6.0
		)


func confetti(pos: Vector3) -> void:
	if less_motion:
		return
	for i: int in 48:
		var col: Color = RrRace.TEAM[i % 6]
		var v := Vector3(_rng.randf_range(-3, 3), _rng.randf_range(2, 6), _rng.randf_range(-3, 3))
		_flakes.emit(pos, v, col, 1.8, 0.12, 0.10, 1.0, 1.2, 2.5)


## W4 steam vent puff (DESIGN 11.2): 12 white puffs up about 6 m in 1.2 s.
func steam(pos: Vector3) -> void:
	for i: int in 12:
		var a: float = _rng.randf() * TAU
		var o := Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(0.2, 0.8)
		var v := Vector3(o.x, _rng.randf_range(4.0, 6.0), o.z)
		_dust.emit(pos + o, v, Color(1, 1, 1), 1.2, 0.8, 3.0, 0.55, 1.2, 0.0)


func dust_color() -> Color:
	return look["dust"]
