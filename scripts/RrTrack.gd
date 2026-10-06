class_name RrTrack
extends RefCounted

## Track 1 "Furuløypa / Pine Run" (GDD 6.1) in track space: s = metres along
## the centre line, x = metres to the right of it. The centre line is
## integrated once at 1 m steps from a curvature and grade profile, so any s
## maps to a position, a heading and a slope without a physics engine. A
## Path3D built from the same points is exposed for the scene (GDD 4).

const S_MIN: float = -40.0
const S_MAX: float = 1040.0
const STEP: float = 1.0

## Section table, GDD 6.1: [from, to, surface, cruise mult]
## surface: "dirt" = bike ground, "lane" = smooth skyway (hoverboard x1.06).
const SECTIONS: Array = [
	[-40.0, 300.0, "dirt", 1.00],
	[300.0, 600.0, "lane", 1.00],
	[600.0, 880.0, "dirt", 1.05],
	[880.0, 950.0, "dirt", 1.00],
	[950.0, 1040.0, "dirt", 0.5],
]
## Width key points [s, width]; widths ease linearly between them.
const WIDTHS: Array = [
	[-40.0, 12.0],
	[0.0, 12.0],
	[40.0, 10.0],
	[536.0, 10.0],
	[544.0, 8.0],
	[576.0, 8.0],
	[584.0, 10.0],
	[600.0, 10.0],
	[606.0, 9.0],
	[714.0, 9.0],
	[722.0, 7.0],
	[768.0, 7.0],
	[776.0, 9.0],
	[874.0, 9.0],
	[886.0, 12.0],
	[1040.0, 12.0],
]
## Kid line key points [s, x] (GDD 4.3 / 6.1), eased linearly between them.
const KID_LINE: Array = [
	[-40.0, 0.0],
	[305.0, 0.0],
	[328.0, 2.5],
	[375.0, 2.5],
	[395.0, 0.0],
	[482.0, 0.0],
	[500.0, 1.8],
	[540.0, 1.8],
	[558.0, 0.0],
	[664.0, 0.0],
	[684.0, 3.0],
	[715.0, 3.0],
	[732.0, 0.0],
	[1040.0, 0.0],
]
## Speed pads P1-P10 [s, x].
const PADS: Array = [
	[120.0, 0.0],
	[210.0, -3.0],
	[340.0, 2.5],
	[352.0, 2.5],
	[364.0, 2.5],
	[470.0, -3.0],
	[700.0, 3.0],
	[800.0, -3.0],
	[812.0, -3.0],
	[824.0, -3.0],
]
## Kickers K1-K4: s of the lip (air time in RrBalance.KICKER_AIR_S).
const KICKERS: Array[float] = [180.0, 430.0, 760.0, 900.0]
## Hay bales H1-H4 [s, x].
const HAY: Array = [
	[260.0, 2.5],
	[520.0, -0.5],
	[650.0, -2.0],
	[840.0, 1.5],
]
const HAY_HALF_W: float = 0.8
## Swap gates [s, vehicle after the gate]: 1 = hoverboard, 0 = bike.
const GATES: Array = [[300.0, 1], [600.0, 0]]
const TUNNEL: Vector2 = Vector2(540.0, 580.0)
const FENCE: Vector2 = Vector2(718.0, 772.0)
## Curvature profile [from, to, 1/radius]; + = bends right.
const BENDS: Array = [
	[50.0, 100.0, -1.0 / 60.0],
	[110.0, 160.0, 1.0 / 60.0],
	[205.0, 280.0, 1.0 / 150.0],
	[330.0, 420.0, -1.0 / 200.0],
	[460.0, 540.0, 1.0 / 160.0],
	[620.0, 700.0, -1.0 / 130.0],
	[790.0, 860.0, 1.0 / 220.0],
]
## Grade profile [from s, drop per metre]; eased over 20 m between rows.
const GRADES: Array = [
	[-40.0, 0.05],
	[0.0, 0.15],
	[40.0, 0.08],
	[300.0, 0.06],
	[600.0, 0.20],
	[880.0, 0.04],
	[950.0, 0.02],
]

var length: float = RrBalance.TRACK1_LENGTH_M
var _pos: PackedVector3Array = PackedVector3Array()
var _yaw: PackedFloat32Array = PackedFloat32Array()
var _grade: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	_integrate()


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
		var g: float = _grade_at(s)
		p += Vector3(-sin(yaw), -g, -cos(yaw)) * STEP
		_pos[i] = p
		_yaw[i] = yaw
		_grade[i] = g
	p = Vector3.ZERO
	yaw = 0.0
	for i: int in range(i0 - 1, -1, -1):
		var s: float = S_MIN + (i + 0.5) * STEP
		var g: float = _grade_at(s)
		p -= Vector3(-sin(yaw), -g, -cos(yaw)) * STEP
		yaw += _curv_at(s) * STEP
		_pos[i] = p
		_yaw[i] = yaw
		_grade[i] = g


func _curv_at(s: float) -> float:
	for b: Array in BENDS:
		var a: float = b[0]
		var e: float = b[1]
		if s >= a and s < e:
			# Ease the bend in and out over 10 m so the camera never snaps.
			var k: float = minf(1.0, minf((s - a) / 10.0, (e - s) / 10.0))
			return float(b[2]) * clampf(k, 0.0, 1.0)
	return 0.0


func _grade_at(s: float) -> float:
	var g: float = float(GRADES[0][1])
	for i: int in range(1, GRADES.size()):
		var row: Array = GRADES[i]
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
	return _keyed(WIDTHS, s)


func half_limit(s: float) -> float:
	return width(s) * 0.5 - RrBalance.RIDER_RADIUS


func kid_x(s: float) -> float:
	return _keyed(KID_LINE, s)


func section_mult(s: float) -> float:
	for row: Array in SECTIONS:
		if s < float(row[1]):
			return row[3]
	return RrBalance.RUNOUT_MULT


func surface(s: float) -> String:
	for row: Array in SECTIONS:
		if s < float(row[1]):
			return row[2]
	return "dirt"


func is_smooth(s: float) -> bool:
	return surface(s) == "lane"


func in_tunnel(s: float) -> bool:
	return s >= TUNNEL.x and s < TUNNEL.y


## Height of the kicker deck under s (deck from lip - KICKER_LEN_M to lip),
## 0 off the ramps.
func ramp_height(s: float) -> float:
	for k: float in KICKERS:
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
