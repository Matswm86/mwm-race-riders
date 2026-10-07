# gdlint: disable=max-public-methods
class_name RrTrack
extends RefCounted

## One track (GDD 6.1 / 6.2, 17.1) in track space: s = metres along the
## centre line, x = metres to the right of it. The centre line is integrated
## once at 1 m steps from the track's curvature and grade profile, so any s
## maps to a position, a heading and a slope without a physics engine. A
## Path3D built from the same points is exposed for the scene (GDD 4). The
## numbers live in RrWorlds (track 1) and tracks/*.json (RrTracks); this
## class only answers questions about them.

const S_MIN: float = -60.0
const STEP: float = 1.0
const HAY_HALF_W: float = 0.8

var world_id: int = 1
## "w1_t3", "w2_t5p" ... (RrTracks), track number 1-8, Pro variant.
var key: String = "w1_t1"
var number: int = 1
var pro: bool = false
## Pro tracks mirror their base track: the scene reuses the base bake with
## the world mirrored in X (a mirrored centre line is the world mirrored).
var mirrored: bool = false
## Last s with a centre line (length + run-out + margin).
var s_max: float = 1580.0
## Ground-generator set pieces (W2 slot canyon, rim lane, mesa, town).
var zones: Dictionary = {}
## Per-track scenery knobs for the generator (tree density, walls, seed).
var flavor: Dictionary = {}
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
## Roller hindrances [s, dir] (tumbleweeds, snow slough, rocks, spools).
var rollers: Array = []
## Hop hindrances: s of each low object across the whole track (W4 lava
## crust ridge, W5 log): 0.4 s of air, no trick, no slow (GDD 4.8).
var hops: Array[float] = []
## W6 air rings [s, x, h]: flying through gives RING_MULT for RING_TIME_S.
var rings: Array = []
## W5 split path: s range and the island's x range between the narrow
## bridge route (left) and the wide ford route (right), or empty.
var split: Array = []
## Extra centre-line height [s, metres] (W6 container-stack ramp), smoothstep
## between rows; empty = none.
var lifts: Array = []
## The world's track kit (RrWorlds.KIT): block / roller / hop models.
var kit: Dictionary = {}
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


## id: a track key ("w2_t4p") or a world id (= that world's track 1).
func _init(id: Variant = 1) -> void:
	key = String(id) if id is String else RrTracks.key(int(id), 1)
	var d: Dictionary = RrTracks.get_def(key)
	world_id = int(d["id"])
	number = int(d.get("track", 1))
	pro = bool(d.get("pro", false))
	mirrored = bool(d.get("mirrored", false))
	s_max = float(d.get("s_max", 1580.0))
	zones = d.get("zones", {})
	flavor = d.get("flavor", {})
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
	for hp: Variant in d.get("hops", []):
		hops.append(float(hp))
	rings = d.get("rings", [])
	split = d.get("split", [])
	lifts = d.get("lifts", [])
	kit = RrWorlds.kit(world_id)
	gates = d["gates"]
	bends = d["bends"]
	grades = d["grades"]
	drops = d["drops"]
	gap = _range(d["gap"])
	tunnel = _range(d["tunnel"])
	fence = _range(d["fence"])
	river = _range(d["river"])
	look = d["look"]
	if world_id == 1 and river.x >= 0.0:
		# DESIGN 9a: a kicker on the river road is the wooden river bridge's
		# hump (same lip and airtime, a longer, rounder deck).
		for i: int in kickers.size():
			var k: float = kickers[i]
			if k > river.x + 14.0 and k < river.y - 14.0 and kicker_models[i] == "ramp":
				kicker_models[i] = "world1/river_bridge"
	_integrate()


static func _range(a: Array) -> Vector2:
	if a.size() < 2:
		return Vector2(-1.0, -1.0)
	return Vector2(float(a[0]), float(a[1]))


func _integrate() -> void:
	var n: int = int((s_max - S_MIN) / STEP) + 1
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
	if not lifts.is_empty():
		for i: int in n:
			var s2: float = S_MIN + float(i) * STEP
			_pos[i].y += lift_at(s2)
			_grade[i] -= lift_at(s2 + 0.5) - lift_at(s2 - 0.5)


## Extra centre height at s from the lifts table (smoothstep between rows).
func lift_at(s: float) -> float:
	if lifts.is_empty() or s <= float(lifts[0][0]):
		return 0.0 if lifts.is_empty() else float(lifts[0][1])
	for i: int in range(1, lifts.size()):
		var a: Array = lifts[i - 1]
		var b: Array = lifts[i]
		if s <= float(b[0]):
			var k: float = clampf(
				(s - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])), 0.0, 1.0
			)
			k = k * k * (3.0 - 2.0 * k)
			return lerpf(float(a[1]), float(b[1]), k)
	return float(lifts[lifts.size() - 1][1])


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


## A zone range from the track data ("slot", "lane"), or Vector2(-1, -1).
func zone(name: String) -> Vector2:
	var z: Variant = zones.get(name, [])
	if z is Array and (z as Array).size() >= 2:
		return Vector2(float(z[0]), float(z[1]))
	return Vector2(-1.0, -1.0)


## A single zone position ("mesa", "town"), or fallback.
func zone_at(name: String, fallback: float) -> float:
	var z: Variant = zones.get(name, fallback)
	return float(z) if (z is float or z is int) else fallback


## Kind of the patch under (s, x), or "".
func patch_kind(s: float, x: float) -> String:
	for p: Array in patches:
		if s >= float(p[0]) and s < float(p[1]) and x >= float(p[2]) and x <= float(p[3]):
			return String(p[4])
	return ""


## Patch slow-down for a rider at (s, x) on a vehicle (GDD 4.8, 6.0): 1.0
## outside every patch; the hoverboard floats over sand and ash and is immune
## to the ford; ice and wet steel never slow, they slide (patch_slides).
static func kind_mult(kind: String, board: bool, easy: bool) -> float:
	match kind:
		"":
			return 1.0
		"sand":
			if board:
				return 1.0
			return RrBalance.SAND_MULT_L if easy else RrBalance.SAND_MULT_V
		"ash":
			return 1.0 if board else RrBalance.ASH_MULT
		"ford":
			return 1.0 if board else RrBalance.FORD_MULT
		"snow":
			return RrBalance.SNOW_MULT
		"ice", "steel":
			return 1.0
	return RrBalance.MUD_MULT


func patch_mult(s: float, x: float, board: bool, easy: bool) -> float:
	return RrTrack.kind_mult(patch_kind(s, x), board, easy)


## True on ice (W3) or wet steel plates (W6): steering slides (GDD 6.0).
func patch_slides(s: float, x: float) -> bool:
	var k: String = patch_kind(s, x)
	return k == "ice" or k == "steel"


## Patch kinds the hoverboard rides over unslowed (AI and bots skip them).
static func board_ignores(kind: String) -> bool:
	return kind in ["sand", "ash", "ford", "ice", "steel"]


## W5 split path: the island's x range at s (it grows from a point over
## SPLIT_ISLAND_EASE_M at both ends), or Vector2(1, -1) when there is none.
func island(s: float) -> Vector2:
	if split.size() < 4:
		return Vector2(1.0, -1.0)
	var a: float = split[0]
	var b: float = split[1]
	if s <= a or s >= b:
		return Vector2(1.0, -1.0)
	var e: float = RrBalance.SPLIT_ISLAND_EASE_M
	var k: float = clampf(minf(s - a, b - s) / e, 0.0, 1.0)
	var xa: float = split[2]
	var xb: float = split[3]
	var c: float = (xa + xb) * 0.5
	var hw: float = (xb - xa) * 0.5 * k
	return Vector2(c - hw, c + hw)


func in_split(s: float) -> bool:
	return split.size() >= 4 and s > float(split[0]) and s < float(split[1])


## Kicker profile by skin (DESIGN 9a: the W1 river bridge's 0.95 m hump is
## its kicker; W4's steam vent mound launches from the ground): [deck length
## before the lip, lip height].
static func kicker_profile(model: String) -> Vector2:
	if model == "world1/river_bridge":
		return Vector2(5.8, 0.95)
	if model == "vent":
		return Vector2(0.0, 0.0)
	return Vector2(RrBalance.KICKER_LEN_M, RrBalance.KICKER_LIP_M)


## Height of the kicker deck under s (deck from lip - KICKER_LEN_M to lip),
## 0 off the ramps.
func ramp_height(s: float) -> float:
	for i: int in kickers.size():
		var k: float = kickers[i]
		var pr: Vector2 = RrTrack.kicker_profile(kicker_models[i])
		if pr.x <= 0.0:
			continue
		var a: float = k - pr.x
		if s >= a and s < k:
			var u: float = (s - a) / pr.x
			if pr.x > RrBalance.KICKER_LEN_M + 0.1:
				# Bridge hump: rises fast, rounds over the crest.
				return pr.y * (1.0 - (1.0 - u) * (1.0 - u))
			return pr.y * u * u
	return 0.0


# ---------------------------------------------------------------- geometry


func _idx(s: float) -> Array:
	var f: float = (clampf(s, S_MIN, s_max) - S_MIN) / STEP
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
	while s <= s_max:
		c.add_point(center(s))
		s += 10.0
	return c


func sample_count() -> int:
	return _pos.size()


func sample_pos(i: int) -> Vector3:
	return _pos[i]


func sample_s(i: int) -> float:
	return S_MIN + float(i) * STEP
