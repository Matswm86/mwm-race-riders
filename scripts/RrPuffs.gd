class_name RrPuffs
extends MultiMeshInstance3D

## One pool of short-lived sprites (or small meshes) drawn as one MultiMesh,
## so every dust puff in the race costs one draw call (DESIGN 7: rolling dust,
## knock-off burst, landings, hay straw, sand, mud droplets, swap puffs,
## confetti). Sprites face the camera; each has its own velocity, drag,
## gravity, size ramp and alpha fade. No per-frame allocations.

var cap: int = 0
var billboard: bool = true
var alive: int = 0

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _s0 := PackedFloat32Array()
var _s1 := PackedFloat32Array()
var _a0 := PackedFloat32Array()
var _drag := PackedFloat32Array()
var _grav := PackedFloat32Array()
var _col := PackedColorArray()
var _spin := PackedFloat32Array()
var _next: int = 0
var _top: int = 0


func setup(n: int, mesh_in: Mesh, mat: Material, faces_camera: bool = true) -> void:
	cap = n
	billboard = faces_camera
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh_in
	mm.instance_count = n
	mm.visible_instance_count = 0
	multimesh = mm
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Packed arrays are values in GDScript: resize each one by name.
	_pos.resize(n)
	_vel.resize(n)
	_age.resize(n)
	_life.resize(n)
	_s0.resize(n)
	_s1.resize(n)
	_a0.resize(n)
	_drag.resize(n)
	_grav.resize(n)
	_spin.resize(n)
	_col.resize(n)
	_life.fill(0.0)
	_age.fill(1.0)
	# A huge AABB: the puffs live anywhere along the track.
	custom_aabb = AABB(Vector3(-5000, -2000, -5000), Vector3(10000, 4000, 10000))


## life s, size s0 -> s1 (m), alpha a0 -> 0, drag 1/s, gravity m/s^2.
func emit(
	p: Vector3,
	v: Vector3,
	col: Color,
	life: float,
	s0: float,
	s1: float,
	a0: float,
	drag: float = 0.0,
	grav: float = 0.0
) -> void:
	var i: int = _next
	_next = (_next + 1) % cap
	_pos[i] = p
	_vel[i] = v
	_age[i] = 0.0
	_life[i] = life
	_s0[i] = s0
	_s1[i] = s1
	_a0[i] = a0
	_drag[i] = drag
	_grav[i] = grav
	_col[i] = col
	_spin[i] = randf() * TAU
	_top = maxi(_top, i + 1)


func clear() -> void:
	_age.fill(1.0)
	_life.fill(0.0)
	_top = 0
	multimesh.visible_instance_count = 0


func tick(dt: float, cam: Basis) -> void:
	if _top == 0:
		return
	var mm: MultiMesh = multimesh
	var last: int = 0
	alive = 0
	for i: int in _top:
		if _life[i] <= 0.0 or _age[i] >= _life[i]:
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
			continue
		_age[i] += dt
		var k: float = clampf(_age[i] / _life[i], 0.0, 1.0)
		var v: Vector3 = _vel[i] * exp(-_drag[i] * dt)
		v.y -= _grav[i] * dt
		_vel[i] = v
		_pos[i] += v * dt
		var sz: float = lerpf(_s0[i], _s1[i], k)
		var b: Basis
		if billboard:
			b = (cam * Basis(Vector3.BACK, _spin[i])).scaled(Vector3.ONE * sz)
		else:
			b = Basis(Vector3(1, 1, 0).normalized(), _spin[i] + k * 8.0).scaled(Vector3.ONE * sz)
		mm.set_instance_transform(i, Transform3D(b, _pos[i]))
		var c: Color = _col[i]
		c.a = _a0[i] * (1.0 - k) * minf(1.0, k * 8.0 + 0.3)
		mm.set_instance_color(i, c)
		last = i + 1
		alive += 1
	_top = last
	mm.visible_instance_count = _top
