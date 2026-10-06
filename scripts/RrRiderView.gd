class_name RrRiderView
extends Node3D

## One racer on screen (DESIGN 2): the skinned rider.glb on bike.glb or
## hoverboard.glb, dressed in livery r1-r6 by swapping the albedo only.
## Poses come from the GLB animations, sampled by hand (no AnimationPlayer
## per racer): static riding poses blended for tricks, and the timed
## knock-off sequence (rider fall -> lying -> getup, bike crash -> lying,
## DESIGN 2c). Wheels spin with the speed. Reads RrRider state every frame.

const WHEEL_R: float = 0.368  # 29 in wheel
const BIKE_TRICKS: Array[String] = ["trick_nohands", "tailwhip", "trick_superman"]
const BOARD_TRICKS: Array[String] = ["spin", "board_grab", "spin_grab"]

## Shared per animation name: [Animation, [bone name per track], [type per track]].
static var _anims: Dictionary = {}

var ghost: bool = false
var less_motion: bool = false
var livery: int = 0

var _lean_node: Node3D
var _body: Node3D
var _bike: Node3D
var _board: Node3D
var _skel: Skeleton3D
var _bike_skel: Skeleton3D
var _wheel_f: int = -1
var _wheel_r: int = -1
var _wheel_rest: Array[Quaternion] = []
var _wheel_a: float = 0.0
var _bone_idx: Dictionary = {}
var _bike_bone_idx: Dictionary = {}
var _lean: float = 0.0
var _squash_t: float = 99.0
var _squash_k: float = 1.0
var _pose_key: String = ""
var _bike_pose_key: String = ""
var _vehicle: int = -1
var _swap_t: float = 99.0
var _bob_t: float = 0.0
var _pitch: float = 0.0
var _meshes: Array[MeshInstance3D] = []
var _ghost_r: RrRider
var _shadow_on: bool = false


func build(liv: int, ghost_mat: Material = null) -> void:
	livery = liv
	_lean_node = Node3D.new()
	add_child(_lean_node)
	_bike = _instance("res://assets/models/bike.glb", "bike", ghost_mat)
	_board = _instance("res://assets/models/hoverboard.glb", "hoverboard", ghost_mat)
	_body = _instance("res://assets/models/rider.glb", "rider", ghost_mat)
	_skel = _body.find_children("*", "Skeleton3D", true, false)[0]
	_bike_skel = _bike.find_children("*", "Skeleton3D", true, false)[0]
	for n: Node3D in [_body, _bike]:
		var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0]
		RrRiderView._cache_anims(ap)
		ap.queue_free()
	for i: int in _skel.get_bone_count():
		_bone_idx[_skel.get_bone_name(i)] = i
	for i: int in _bike_skel.get_bone_count():
		_bike_bone_idx[_bike_skel.get_bone_name(i)] = i
	_wheel_f = _bike_skel.find_bone("wheel_front")
	_wheel_r = _bike_skel.find_bone("wheel_rear")
	for b: int in [_wheel_f, _wheel_r]:
		_wheel_rest.append(_bike_skel.get_bone_rest(b).basis.get_rotation_quaternion())
	set_vehicle(RrRider.BIKE, true)


func _instance(path: String, kind: String, ghost_mat: Material) -> Node3D:
	var n: Node3D = (load(path) as PackedScene).instantiate()
	for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if kind == "hoverboard":
			m.mesh = RrMats.uv_fixed(m.mesh)
		m.material_override = ghost_mat if ghost_mat != null else RrMats.livery(kind, livery)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_meshes.append(m)
	_lean_node.add_child(n)
	return n


static func _cache_anims(ap: AnimationPlayer) -> void:
	for a: StringName in ap.get_animation_list():
		var key: String = String(a)
		if key == "lying" and _anims.has("lying"):
			key = "bike_lying"
		if _anims.has(key):
			continue
		var an: Animation = ap.get_animation(a)
		var bones: Array[String] = []
		var types: Array[int] = []
		for i: int in an.get_track_count():
			bones.append(String(an.track_get_path(i)).get_slice(":", 1))
			types.append(an.track_get_type(i))
		_anims[key] = [an, bones, types]


## Pose a skeleton at time t of an animation, blended over pose b by k.
func _pose(skel: Skeleton3D, idx: Dictionary, a: String, ta: float, b: String, k: float) -> void:
	var ea: Array = _anims.get(a, [])
	if ea.is_empty():
		return
	var eb: Array = _anims.get(b, []) if k > 0.0 else []
	var an: Animation = ea[0]
	var bones: Array[String] = ea[1]
	var types: Array[int] = ea[2]
	for i: int in bones.size():
		var bi: int = idx.get(bones[i], -1)
		if bi < 0:
			continue
		match types[i]:
			Animation.TYPE_ROTATION_3D:
				var q: Quaternion = an.rotation_track_interpolate(i, ta)
				if not eb.is_empty():
					var qb: Quaternion = (eb[0] as Animation).rotation_track_interpolate(i, 0.0)
					q = q.slerp(qb, k)
				skel.set_bone_pose_rotation(bi, q)
			Animation.TYPE_POSITION_3D:
				var p: Vector3 = an.position_track_interpolate(i, ta)
				if not eb.is_empty():
					p = p.lerp((eb[0] as Animation).position_track_interpolate(i, 0.0), k)
				skel.set_bone_pose_position(bi, p)
			Animation.TYPE_SCALE_3D:
				skel.set_bone_pose_scale(bi, an.scale_track_interpolate(i, ta))


func _rider_pose(a: String, ta: float, b: String = "", k: float = 0.0) -> void:
	var key: String = "%s@%.3f|%s@%.2f" % [a, ta, b, k]
	if key == _pose_key:
		return
	_pose_key = key
	_pose(_skel, _bone_idx, a, ta, b, k)


func _bike_pose(a: String, ta: float, b: String = "", k: float = 0.0) -> void:
	var key: String = "%s@%.3f|%s@%.2f" % [a, ta, b, k]
	if key == _bike_pose_key:
		return
	_bike_pose_key = key
	_pose(_bike_skel, _bike_bone_idx, a, ta, b, k)


## Høy tier: the racer casts a real sun shadow (DESIGN 6).
func set_shadow(on: bool) -> void:
	if ghost or on == _shadow_on:
		return
	_shadow_on = on
	var cast: int = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if on
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	for m: MeshInstance3D in _meshes:
		m.cast_shadow = cast


## Rivals take coarser mesh LODs sooner (DESIGN 12: rivals at LOD1).
func set_lod_bias(bias: float) -> void:
	for m: MeshInstance3D in _meshes:
		if m.lod_bias != bias:
			m.lod_bias = bias


func set_vehicle(v: int, instant: bool) -> void:
	if v == _vehicle:
		return
	_vehicle = v
	_swap_t = 99.0 if instant or less_motion else 0.0
	_pose_key = ""
	_bike.visible = v == RrRider.BIKE or not instant
	_board.visible = v == RrRider.BOARD or not instant
	if instant or less_motion:
		_bike.scale = Vector3.ONE
		_board.scale = Vector3.ONE
		_bike.visible = v == RrRider.BIKE
		_board.visible = v == RrRider.BOARD


func vehicle() -> int:
	return _vehicle


func squash(air: float) -> void:
	if less_motion:
		return
	_squash_t = 0.0
	_squash_k = 1.0 if air >= 0.6 else 0.4


## Place on the track and animate from a rider's state (or a ghost row).
func sync_rider(track: RrTrack, r: RrRider, t: float, dt: float) -> void:
	_place(track, r, t, dt)


func sync_ghost(track: RrTrack, row: Array, dt: float) -> void:
	set_vehicle(int(row[3]), true)
	if _ghost_r == null:
		_ghost_r = RrRider.new()
	_ghost_r.s = float(row[0])
	_ghost_r.x = float(row[1])
	_ghost_r.h = float(row[2])
	_ghost_r.v = RrBalance.CRUISE_MPS
	_place(track, _ghost_r, 0.0, dt)


func _place(track: RrTrack, r: RrRider, t: float, dt: float) -> void:
	var s: float = r.s
	var x: float = r.x
	var h: float = r.h
	var v: float = r.v
	var trick_k: float = -1.0
	if r.trick_t >= 0.0 and r.trick_len > 0.0:
		trick_k = r.trick_t / r.trick_len
	var trick_n: int = r.trick_count
	var wobble_t: float = t - (r.bump_until - RrBalance.BUMP_TIME_S)
	var fall_t: float = r.fall_t if r.fall_t >= 0.0 and r.down() else -1.0
	var fall_dir: float = r.fall_dir
	var f: Transform3D = track.frame(s)
	var hover: float = 0.0
	if _vehicle == RrRider.BOARD and fall_t < 0.0:
		_bob_t += dt
		# The board model is authored floating; only the bob is added.
		hover = RrBalance.HOVER_BOB_M * sin(_bob_t * TAU * RrBalance.HOVER_BOB_HZ)
	var ground: Vector3 = f.origin + f.basis.x * x
	var yaw: float = track.yaw(s)
	global_transform = Transform3D(Basis(Vector3.UP, yaw), ground + Vector3.UP * (h + hover))
	var slope: float = atan(track.grade(s))
	var target_pitch: float = -slope
	if h > 0.01 and fall_t < 0.0:
		target_pitch = clampf(atan2(r.vy, maxf(v, 1.0)) * 0.6, -0.5, 0.5)
	_pitch = lerpf(_pitch, target_pitch, minf(1.0, dt * 10.0))
	var lean_target: float = -r.lat_v / RrBalance.STEER_LAT_MAX * deg_to_rad(RrBalance.LEAN_MAX_DEG)
	_lean = lerpf(_lean, lean_target, minf(1.0, dt / 0.1))
	var roll: float = _lean
	if wobble_t >= 0.0 and wobble_t < RrBalance.BUMP_TIME_S and not less_motion:
		var decay: float = 1.0 - wobble_t / RrBalance.BUMP_TIME_S
		roll += deg_to_rad(RrBalance.WOBBLE_DEG) * decay * sin(wobble_t * TAU * RrBalance.WOBBLE_HZ)
	var spin: float = 0.0
	var bike_yaw: float = 0.0
	if fall_t >= 0.0:
		roll = 0.0
		_knocked_pose(fall_t, fall_dir)
	else:
		_ride_pose(trick_k, trick_n)
		if trick_k >= 0.0:
			var e: float = clampf(trick_k, 0.0, 1.0)
			var smooth: float = e * e * (3.0 - 2.0 * e)
			var name: String = _trick_name(trick_n)
			if name == "tailwhip":
				bike_yaw = TAU * smooth
			elif name.begins_with("spin"):
				spin = TAU * smooth
	var b := Basis(Vector3.UP, spin) * Basis(Vector3.RIGHT, _pitch) * Basis(Vector3.BACK, roll)
	var sc := Vector3.ONE
	if _squash_t < RrBalance.LAND_SQUASH_IN_S + RrBalance.LAND_SQUASH_OUT_S:
		_squash_t += dt
		var k: float
		if _squash_t < RrBalance.LAND_SQUASH_IN_S:
			k = _squash_t / RrBalance.LAND_SQUASH_IN_S
		else:
			k = 1.0 - (_squash_t - RrBalance.LAND_SQUASH_IN_S) / RrBalance.LAND_SQUASH_OUT_S
		k = clampf(k, 0.0, 1.0) * _squash_k
		sc = Vector3(
			lerpf(1.0, RrBalance.LAND_SQUASH.x, k),
			lerpf(1.0, RrBalance.LAND_SQUASH.y, k),
			lerpf(1.0, RrBalance.LAND_SQUASH.x, k)
		)
	_lean_node.transform = Transform3D(b.scaled(sc), Vector3.ZERO)
	_bike.rotation.y = bike_yaw
	_swap_anim(dt)
	# Wheels spin about their own Y (DESIGN 2b) while the bike rolls.
	if _bike.visible and fall_t < 0.0:
		_wheel_a = fmod(_wheel_a + v * dt / WHEEL_R, TAU)
		for i: int in 2:
			var bi: int = _wheel_f if i == 0 else _wheel_r
			_bike_skel.set_bone_pose_rotation(
				bi, _wheel_rest[i] * Quaternion(Vector3.UP, -_wheel_a)
			)


func _trick_name(n: int) -> String:
	if _vehicle == RrRider.BOARD:
		return BOARD_TRICKS[n % BOARD_TRICKS.size()]
	return BIKE_TRICKS[n % BIKE_TRICKS.size()]


func _ride_pose(trick_k: float, trick_n: int) -> void:
	var base: String = "bike" if _vehicle == RrRider.BIKE else "board"
	_bike_pose("ride", 0.0)
	if trick_k < 0.0:
		_rider_pose(base, 0.0)
		return
	var name: String = _trick_name(trick_n)
	var w: float = sin(clampf(trick_k, 0.0, 1.0) * PI)
	if name.begins_with("trick_") or name == "board_grab":
		_rider_pose(base, 0.0, name, w)
	elif name == "spin_grab":
		_rider_pose(base, 0.0, "board_grab", w)
	else:
		_rider_pose(base, 0.0)


## DESIGN 2c: rider fall (1.2 s) -> lying -> getup scaled into GETUP_S; bike
## crash 0.5 s -> lying, lifted back over the last 0.25 s. Tipped away from
## the player (mirrored when the fall goes to the left).
func _knocked_pose(t: float, dir: float) -> void:
	_body.scale = Vector3(dir if dir != 0.0 else 1.0, 1.0, 1.0)
	_bike.scale = _body.scale
	if t < RrBalance.FALL_DOWN_S:
		_rider_pose("fall", minf(t, 1.2))
	else:
		var g: float = clampf((t - RrBalance.FALL_DOWN_S) / RrBalance.GETUP_S, 0.0, 1.0)
		_rider_pose("getup", g * 1.0)
	var end: float = RrBalance.FALL_DOWN_S + RrBalance.GETUP_S
	if t < 0.5:
		_bike_pose("crash", t)
	elif t < end - 0.25:
		_bike_pose("crash", 0.5)
	else:
		_bike_pose("crash", 0.5, "ride", clampf((t - (end - 0.25)) / 0.25, 0.0, 1.0))
	if t >= end - 0.02:
		_body.scale = Vector3.ONE
		_bike.scale = Vector3.ONE


func _swap_anim(dt: float) -> void:
	if _swap_t >= RrBalance.SWAP_FX_S:
		return
	_swap_t += dt
	var half: float = RrBalance.SWAP_FX_S * 0.5
	var out_node: Node3D = _board if _vehicle == RrRider.BIKE else _bike
	var in_node: Node3D = _bike if _vehicle == RrRider.BIKE else _board
	var k_out: float = clampf(1.0 - _swap_t / half, 0.0, 1.0)
	var k_in: float = clampf((_swap_t - half) / half, 0.0, 1.0)
	out_node.visible = k_out > 0.0
	out_node.scale = Vector3.ONE * maxf(k_out, 0.01)
	in_node.visible = _swap_t >= half
	in_node.scale = Vector3.ONE * maxf(k_in, 0.01)
	if _swap_t >= RrBalance.SWAP_FX_S:
		in_node.scale = Vector3.ONE
		out_node.visible = false
