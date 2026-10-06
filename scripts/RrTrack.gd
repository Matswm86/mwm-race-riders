class_name RrTrack
extends RefCounted

## One world's track (GDD 6.1 / 6.2) in track space: s = metres along the
## centre line, x = metres to the right of it. The centre line is integrated
## once at 1 m steps from the world's curvature and grade profile, so any s
## maps to a position, a heading and a slope without a physics engine. A
## Path3D built from the same points is exposed for the scene (GDD 4). The
## numbers live in RrWorlds; this class only answers questions about them.

const S_MIN: float = -60.0
const S_MAX: float = 1580.0
const STEP: float = 1.0
const HAY_HALF_W: float = 0.8

var world_id: int = 1
## GDD tables for this world (see RrWorlds).
var sections: Array = []
var widths: Array = []
var kid_line: Array = []
var pads: Array = []
var kickers: Array[float] = []
var kicker_air: Array[float] = []
var kicker_models: Array[String] = []
## Block hindrances [s, x] (hay bales).
var blocks: Array = []
## Patch hindrances [s0, s1, x0, x1, kind] (mud, sand).
var patches: Array = []
## Roller hindrances [s, dir] (tumbleweeds).
var rollers: Array = []
var gates: Array = []
var bends: Array = []
var grades: Array = []
var drops: Array = []
## s range with no ground under it (W2 mesa gap), or Vector2(-1, -1).
var gap: Vector2 = Vector2(-1.0, -1.0)
var tunnel: Vector2 = Vector2(-1.0, -1.0)
var fence: Vector2 = Vector2(-1.0, -1.0)
var river: Vector2 = Vector2(-1.0, -1.0)
var look: Dictionary = {}
var length: float = RrBalance.TRACK1_LENGTH_M
var _pos: PackedVector3Array = PackedVector3Array()
var _yaw: PackedFloat32Array = PackedFloat32Array()
var _grade: PackedFloat32Array = PackedFloat32Array()


func _init(id: int = 1) -> void:
	var d: Dictionary = RrWorlds.get_def(id)
	world_id = int(d["id"])
	length = float(d["length"])
	sections = d["sections"]
	widths = d["widths"]
	kid_line = d["kid_line"]
	pads = d["pads"]
	for k: Variant in d["kickers"]:
		kickers.append(float(k))
	for a: Variant in d["kicker_air"]:
		kicker_air.append(float(a))
	for m: Variant in d["kicker_models"]:
		kicker_models.append(String(m))
	blocks = d["blocks"]
	patches = d["patches"]
	rollers = d["rollers"]
	gates = d["gates"]
	bends = d["bends"]
	grades = d["grades"]
	drops = d["drops"]
	gap = _range(d["gap"])
	tunnel = _range(d["tunnel"])
	fence = _range(d["fence"])
	river = _range(d["river"])
	look = d["look"]
	_integrate()


static func _range(a: Array) -> Vector2:
	if a.size() < 2:
		return Vector2(-1.0, -1.0)
	return Vector2(float(a[0]), float(a[1]))


func _integrate() -> void:
	var n: int = int((S_MAX - S_MIN) / STEP) + 1
	_pos.resize(n)
	_yaw.resize(n)
	_grade.resize(n)
	var p := Vector3.ZERO
	var yaw: float = 0.0
	# s = 0 sits at the world origin: integrate forwards and backwards from it.
	var i0: int = int(-S_MIN / STEP)
	_pos[i0] = p
	_yaw[i0] = 0.0
	_grade[i0] = _grade_at(0.0)
	for i: int in range(i0 + 1, n):
		var s: float = S_MIN + (i - 0.5) * STEP
		yaw -= _curv_at(s) * STEP
		var g: float = _grade_at(s) + _drop_at(s)
		p += Vector3(-sin(yaw), -g, -cos(yaw)) * STEP
		_pos[i] = p
		_yaw[i] = yaw
		_grade[i] = g
	p = Vector3.ZERO
	yaw = 0.0
	for i: int in range(i0 - 1, -1, -1):
		var s: float = S_MIN + (i + 0.5) * STEP
		var g: float = _grade_at(s) + _drop_at(s)
		p -= Vector3(-sin(yaw), -g, -cos(yaw)) * STEP
		yaw += _curv_at(s) * STEP
		_pos[i] = p
		_yaw[i] = yaw
		_grade[i] = g


func _curv_at(s: float) -> float:
	for b: Array in bends:
		var a: float = b[0]
		var e: float = b[1]
		if s >= a and s < e:
			# Ease the bend in and out over 10 m so the camera never snaps.
			var k: float = minf(1.0, minf((s - a) / 10.0, (e - s) / 10.0))
			return float(b[2]) * clampf(k, 0.0, 1.0)
	return 0.0


## Extra drop per metre inside a drops row (smoothstep shaped).
func _drop_at(s: float) -> float:
	for d: Array in drops:
		var a: float = d[0]
		var e: float = d[1]
		if s >= a and s < e:
			var u: float = (s - a) / (e - a)
			return float(d[2]) / (e - a) * 6.0 * u * (1.0 - u)
	return 0.0


func _grade_at(s: float) -> float:
	var g: float = float(grades[0][1])
	for i: int in range(1, grades.size()):
		var row: Array = grades[i]
		var start: float = row[0]
		if s >= start + 20.0:
			g = row[1]
		elif s > start - 0.0:
			var k: float = (s - start) / 20.0
			g = lerpf(g, float(row[1]), k)
	return g


static func _keyed(table: Array, s: float) -> float:
	if s <= float(table[0][0]):
		return table[0][1]
	for i: int in range(1, table.size()):
		var a: Array = table[i - 1]
		var b: Array = table[i]
		if s <= float(b[0]):
			var k: float = (s - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0]))
			return lerpf(float(a[1]), float(b[1]), k)
	return table[table.size() - 1][1]


func width(s: float) -> float:
	return _keyed(widths, s)


func half_limit(s: float) -> float:
	return width(s) * 0.5 - RrBalance.RIDER_RADIUS


func kid_x(s: float) -> float:
	return _keyed(kid_line, s)


func section_mult(s: float) -> float:
	for row: Array in sections:
		if s < float(row[1]):
			return row[3]
	return RrBalance.RUNOUT_MULT


func surface(s: float) -> String:
	for row: Array in sections:
		if s < float(row[1]):
			return row[2]
	return "dirt"


func is_smooth(s: float) -> bool:
	return surface(s) == "lane"


func in_tunnel(s: float) -> bool:
	return s >= tunnel.x and s < tunnel.y


func in_gap(s: float) -> bool:
	return s >= gap.x and s < gap.y


## Patch slow-down for a rider at (s, x) on a vehicle (GDD 4.8): 1.0 outside
## every patch; the hoverboard floats over sand.
func patch_mult(s: float, x: float, board: bool, easy: bool) -> float:
	for p: Array in patches:
		if s >= float(p[0]) and s < float(p[1]) and x >= float(p[2]) and x <= float(p[3]):
			if String(p[4]) == "sand":
				if board:
					return 1.0
				return RrBalance.SAND_MULT_L if easy else RrBalance.SAND_MULT_V
			return RrBalance.MUD_MULT
	return 1.0


## Height of the kicker deck under s (deck from lip - KICKER_LEN_M to lip),
## 0 off the ramps.
func ramp_height(s: float) -> float:
	for k: float in kickers:
		var a: float = k - RrBalance.KICKER_LEN_M
		if s >= a and s < k:
			var u: float = (s - a) / RrBalance.KICKER_LEN_M
			return RrBalance.KICKER_LIP_M * u * u
	return 0.0


# ---------------------------------------------------------------- geometry


func _idx(s: float) -> Array:
	var f: float = (clampf(s, S_MIN, S_MAX) - S_MIN) / STEP
	var i: int = mini(int(f), _pos.size() - 2)
	return [i, f - float(i)]


func center(s: float) -> Vector3:
	var a: Array = _idx(s)
	var i: int = a[0]
	return _pos[i].lerp(_pos[i + 1], a[1])


func yaw(s: float) -> float:
	var a: Array = _idx(s)
	var i: int = a[0]
	return lerpf(_yaw[i], _yaw[i + 1], a[1])


func grade(s: float) -> float:
	var a: Array = _idx(s)
	var i: int = a[0]
	return lerpf(_grade[i], _grade[i + 1], a[1])


static func forward_flat(y: float) -> Vector3:
	return Vector3(-sin(y), 0.0, -cos(y))


static func right_of(y: float) -> Vector3:
	return Vector3(cos(y), 0.0, -sin(y))


## Track frame at s: origin on the centre line, x = right, y = up (tilted
## with the slope), -z = forward down the slope.
func frame(s: float) -> Transform3D:
	var y: float = yaw(s)
	var g: float = grade(s)
	var fwd: Vector3 = (forward_flat(y) + Vector3(0.0, -g, 0.0)).normalized()
	var r: Vector3 = right_of(y)
	var b := Basis(r, (-fwd).cross(r), -fwd)
	return Transform3D(b, center(s))


func world_point(s: float, x: float, h: float = 0.0) -> Vector3:
	var y: float = yaw(s)
	return center(s) + right_of(y) * x + Vector3.UP * h


## Path3D centre line (one point every 10 m) for the scene tree.
func make_curve() -> Curve3D:
	var c := Curve3D.new()
	var s: float = S_MIN
	while s <= S_MAX:
		c.add_point(center(s))
		s += 10.0
	return c


func sample_count() -> int:
	return _pos.size()


func sample_pos(i: int) -> Vector3:
	return _pos[i]


func sample_s(i: int) -> float:
	return S_MIN + float(i) * STEP
