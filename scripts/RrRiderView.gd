class_name RrRiderView
extends Node3D

## One racer on screen (DESIGN 7b): rider.glb (one identity mesh shown),
## bike and hoverboard, a blob shadow and the hover glow. Reads an RrRider
## (or ghost rows) every frame: lean, landing squash, bump wobble, tricks
## (bike: no-hands cheer pose, board: 360 spin) and the 0.3 s vehicle swap.

const IDS: Array[String] = ["fox", "bobble", "shark", "bunny", "bear", "unicorn"]

static var _poses: Dictionary = {}
static var _blob_mat: ShaderMaterial
static var _glow_mat: StandardMaterial3D
static var _glow_mesh: ArrayMesh

var ghost: bool = false
## The racer's own palette material (team colour, rim light in Høy).
var mat: ShaderMaterial
var less_motion: bool = false

var _lean_node: Node3D
var _body: Node3D
var _bike: Node3D
var _board: Node3D
var _skel: Skeleton3D
var _blob: MeshInstance3D
var _glow: MeshInstance3D
var _lean: float = 0.0
var _squash_t: float = 99.0
var _squash_k: float = 1.0
var _pose_mix: float = 0.0
var _vehicle: int = -1
var _swap_t: float = 99.0
var _bob_t: float = 0.0
var _pitch: float = 0.0
var _blob_k: float = 1.0


func build(identity: String, team: Color, kit_shader: Shader, palette: Texture2D) -> void:
	mat = ShaderMaterial.new()
	mat.shader = kit_shader
	mat.set_shader_parameter("palette", palette)
	mat.set_shader_parameter("team_color", team)
	if ghost:
		mat.set_shader_parameter("ghost_alpha", RrBalance.GHOST_ALPHA)
	_lean_node = Node3D.new()
	add_child(_lean_node)
	_bike = _instance("res://assets/models/bike.glb", mat)
	_board = _instance("res://assets/models/hoverboard.glb", mat)
	_body = _instance("res://assets/models/rider.glb", mat)
	_skel = _body.find_children("*", "Skeleton3D", true, false)[0]
	for id: String in IDS:
		var n: Node = _skel.get_node_or_null("id_" + id)
		if n != null:
			(n as Node3D).visible = id == identity
	var ap: Node = _body.find_children("*", "AnimationPlayer", true, false)[0]
	_cache_poses(ap as AnimationPlayer)
	ap.queue_free()
	if not ghost:
		_blob = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.9)
		q.orientation = PlaneMesh.FACE_Y
		_blob.mesh = q
		_blob.material_override = RrRiderView.blob_material()
		_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_blob)
		_glow = MeshInstance3D.new()
		_glow.mesh = RrRiderView.glow_mesh()
		_glow.material_override = RrRiderView.glow_material()
		_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_lean_node.add_child(_glow)
	set_vehicle(0, true)


func _instance(path: String, mat: Material) -> Node3D:
	var n: Node3D = (load(path) as PackedScene).instantiate()
	for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lean_node.add_child(n)
	return n


static func _cache_poses(ap: AnimationPlayer) -> void:
	if not _poses.is_empty():
		return
	for a: StringName in ap.get_animation_list():
		var an: Animation = ap.get_animation(a)
		var pose: Array = []
		for i: int in an.get_track_count():
			var path: String = String(an.track_get_path(i))
			var bone: String = path.get_slice(":", 1)
			var ty: int = an.track_get_type(i)
			pose.append([bone, ty, an.track_get_key_value(i, 0)])
		_poses[String(a)] = pose


## Blend two static poses (k = 0 -> a, 1 -> b).
func _apply_pose(a: String, b: String, k: float) -> void:
	var pa: Array = _poses.get(a, [])
	var pb: Array = _poses.get(b, [])
	for i: int in pa.size():
		var ta: Array = pa[i]
		var bi: int = _skel.find_bone(ta[0])
		if bi < 0:
			continue
		var va: Variant = ta[2]
		var vb: Variant = (pb[i] as Array)[2] if i < pb.size() else va
		match int(ta[1]):
			Animation.TYPE_ROTATION_3D:
				_skel.set_bone_pose_rotation(bi, (va as Quaternion).slerp(vb as Quaternion, k))
			Animation.TYPE_POSITION_3D:
				_skel.set_bone_pose_position(bi, (va as Vector3).lerp(vb as Vector3, k))
			Animation.TYPE_SCALE_3D:
				_skel.set_bone_pose_scale(bi, (va as Vector3).lerp(vb as Vector3, k))


## Høy tier: the racer casts a real shadow and gets the rim light; the blob
## stays for contact but lighter. Lav: blob only (DESIGN 7d).
func set_high(on: bool) -> void:
	if ghost:
		return
	var cast: int = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if on
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	for n: Node3D in [_bike, _board, _body]:
		for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = cast
	mat.set_shader_parameter("rim", 0.55 if on else 0.0)
	_blob_k = 0.55 if on else 1.0


func set_vehicle(v: int, instant: bool) -> void:
	if v == _vehicle:
		return
	_vehicle = v
	_swap_t = 99.0 if instant or less_motion else 0.0
	_pose_mix = -1.0
	_bike.visible = v == RrRider.BIKE or not instant
	_board.visible = v == RrRider.BOARD or not instant
	if instant:
		_bike.scale = Vector3.ONE
		_board.scale = Vector3.ONE
		_bike.visible = v == RrRider.BIKE
		_board.visible = v == RrRider.BOARD
	if _glow:
		_glow.visible = v == RrRider.BOARD
	if _blob:
		(_blob.mesh as QuadMesh).size = (
			Vector2(1.0, 1.9) if v == RrRider.BIKE else Vector2(0.9, 1.6)
		)
	_apply_pose("bike" if v == RrRider.BIKE else "board", "cheer", 0.0)


func squash(air: float) -> void:
	if less_motion:
		return
	_squash_t = 0.0
	_squash_k = 1.0 if air >= 0.6 else 0.4


## Place on the track and animate. trick_k: 0..1 progress of a trick, or < 0.
func sync(
	track: RrTrack,
	s: float,
	x: float,
	h: float,
	lat_v: float,
	vy: float,
	v: float,
	trick_k: float,
	wobble_t: float,
	dt: float
) -> void:
	var f: Transform3D = track.frame(s)
	var up: Vector3 = Vector3.UP
	var hover: float = 0.0
	if _vehicle == RrRider.BOARD:
		_bob_t += dt
		hover = RrBalance.HOVER_BOB_M * sin(_bob_t * TAU * RrBalance.HOVER_BOB_HZ)
	var ground: Vector3 = f.origin + f.basis.x * x
	global_transform = Transform3D(Basis(Vector3.UP, track.yaw(s)), ground + up * (h + hover))
	# Pitch with the slope on the ground, with the flight path in the air.
	var slope: float = atan(track.grade(s))
	var target_pitch: float = -slope
	if h > 0.01:
		target_pitch = clampf(atan2(vy, maxf(v, 1.0)) * 0.6, -0.5, 0.5)
	_pitch = lerpf(_pitch, target_pitch, minf(1.0, dt * 10.0))
	var lean_target: float = -lat_v / RrBalance.STEER_LAT_MAX * deg_to_rad(RrBalance.LEAN_MAX_DEG)
	_lean = lerpf(_lean, lean_target, minf(1.0, dt / 0.1))
	var roll: float = _lean
	if wobble_t >= 0.0 and wobble_t < RrBalance.BUMP_TIME_S and not less_motion:
		var decay: float = 1.0 - wobble_t / RrBalance.BUMP_TIME_S
		roll += (
			deg_to_rad(RrBalance.WOBBLE_DEG) * decay * sin(wobble_t * TAU * RrBalance.WOBBLE_HZ)
		)
	var spin: float = 0.0
	var cheer: float = 0.0
	if trick_k >= 0.0:
		var e: float = clampf(trick_k, 0.0, 1.0)
		if _vehicle == RrRider.BOARD:
			spin = TAU * (e * e * (3.0 - 2.0 * e))
			cheer = sin(e * PI) * 0.6
		else:
			cheer = sin(e * PI)
	if absf(cheer - _pose_mix) > 0.01:
		_pose_mix = cheer
		_apply_pose("bike" if _vehicle == RrRider.BIKE else "board", "cheer", cheer)
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
	_swap_anim(dt)
	if _blob:
		var bt := Transform3D(Basis(Vector3.UP, track.yaw(s)), ground + Vector3.UP * 0.06)
		var air: float = clampf(h / 3.0, 0.0, 1.0)
		bt.basis = bt.basis.scaled(Vector3.ONE * lerpf(1.0, 0.7, air))
		_blob.global_transform = bt
		_blob.set_instance_shader_parameter("fade", lerpf(1.0, 0.6, air) * _blob_k)


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


# ---------------------------------------------------------------- shared looks


static func blob_material() -> ShaderMaterial:
	if _blob_mat == null:
		_blob_mat = ShaderMaterial.new()
		_blob_mat.shader = load("res://shaders/rr_blob.gdshader")
	return _blob_mat


static func glow_material() -> StandardMaterial3D:
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glow_mat.albedo_texture = RrRiderView.radial_texture(Color(0.561, 0.937, 1.0, 0.8))
		_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _glow_mat


## Two 0.6 m cyan glow quads under the board pods (DESIGN 7b), one mesh.
static func glow_mesh() -> ArrayMesh:
	if _glow_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for z: float in [-0.42, 0.42]:
			var c := Vector3(0.0, 0.03, z)
			var p: Array[Vector3] = [
				c + Vector3(-0.3, 0, -0.3),
				c + Vector3(0.3, 0, -0.3),
				c + Vector3(0.3, 0, 0.3),
				c + Vector3(-0.3, 0, 0.3),
			]
			var u: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.set_uv(u[k])
				st.add_vertex(p[k])
		_glow_mesh = st.commit()
	return _glow_mesh


static func radial_texture(col: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, col)
	g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t
