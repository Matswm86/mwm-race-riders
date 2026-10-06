class_name RrWorldGen
extends RefCounted

## Builds the static world of track 1 (DESIGN 7c) into chunk meshes on the
## one palette material: faceted terrain (4 m grid near the track, 16 m far),
## the track ribbon (dirt with ruts and cream curbs, skyway with stripes and
## blue rails), pebbles, fences, the rock cut, the river, trees and rocks.
## Everything static shares one material, so each chunk is one draw call.

const NEAR_STEP: float = 4.0
const FAR_STEP: float = 16.0
const NEAR_CHUNK: float = 96.0
const FAR_CHUNK: float = 288.0
const NEAR_BAND: float = 104.0
const FAR_FROM: float = 92.0
const FAR_PAD: float = 380.0
const SAMPLE_STEP: float = 2.0
const RIVER_OFFSET: float = 17.0
const RIVER_HALF: float = 4.0
const RIVER_S: Vector2 = Vector2(296.0, 604.0)
const TREE_COUNT: int = 330
const FAR_TREE_COUNT: int = 170

var track: RrTrack
var near_chunks: Dictionary = {}
var far_chunks: Dictionary = {}
## Seconds spent, for the log.
var build_ms: int = 0

var _sx := PackedFloat32Array()
var _sz := PackedFloat32Array()
var _ss := PackedFloat32Array()
var _noise := FastNoiseLite.new()
var _noise2 := FastNoiseLite.new()
var _patch := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _protos: Dictionary = {}


func build(trk: RrTrack) -> void:
	var t0: int = Time.get_ticks_msec()
	track = trk
	_rng.seed = 11
	_noise.seed = 3
	_noise.frequency = 0.012
	_noise2.seed = 9
	_noise2.frequency = 0.05
	_patch.seed = 21
	_patch.frequency = 0.03
	_load_protos()
	var s: float = RrTrack.S_MIN
	while s <= RrTrack.S_MAX:
		var c: Vector3 = track.center(s)
		_sx.append(c.x)
		_sz.append(c.z)
		_ss.append(s)
		s += SAMPLE_STEP
	_terrain()
	_ribbon()
	_scenery()
	build_ms = Time.get_ticks_msec() - t0


func _load_protos() -> void:
	for n: String in ["tree_pine", "tree_round", "rock"]:
		var ps: PackedScene = load("res://assets/models/%s.glb" % n)
		var root: Node = ps.instantiate()
		var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
		_protos[n] = mi.mesh.surface_get_arrays(0)
		root.free()


# ---------------------------------------------------------------- nearest


func _d2(i: int, x: float, z: float) -> float:
	var dx: float = _sx[i] - x
	var dz: float = _sz[i] - z
	return dx * dx + dz * dz


func _nearest_global(x: float, z: float) -> int:
	var best: float = INF
	var bi: int = 0
	var i: int = 0
	while i < _sx.size():
		var d: float = _d2(i, x, z)
		if d < best:
			best = d
			bi = i
		i += 1
	return bi


## Hill-climb from a nearby guess (neighbour grid points share a nearest s).
func _nearest_from(x: float, z: float, guess: int) -> int:
	var i: int = clampi(guess, 0, _sx.size() - 1)
	var d: float = _d2(i, x, z)
	var n: int = _sx.size()
	while i + 1 < n and _d2(i + 1, x, z) < d:
		i += 1
		d = _d2(i, x, z)
	while i > 0 and _d2(i - 1, x, z) < d:
		i -= 1
		d = _d2(i, x, z)
	return i


## [distance, s, lateral (+ = right of the track)] for a world x/z.
func _probe(x: float, z: float, i: int) -> Array:
	var s: float = _ss[i]
	var c: Vector3 = track.center(s)
	var r: Vector3 = RrTrack.right_of(track.yaw(s))
	var off := Vector3(x - c.x, 0.0, z - c.z)
	return [sqrt(off.x * off.x + off.z * off.z), s, off.dot(r)]


static func _smooth(a: float, b: float, x: float) -> float:
	var t: float = clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _height(x: float, z: float, pr: Array) -> float:
	var d: float = pr[0]
	var s: float = pr[1]
	var lat: float = pr[2]
	var th: float = track.center(s).y
	var hw: float = track.width(s) * 0.5
	var base: float = th - 0.25 + maxf(0.0, d - hw - 0.4) * 0.18
	var hills: float = _noise.get_noise_2d(x, z) * 9.0 + _noise2.get_noise_2d(x, z) * 2.5
	var h: float = (
		base + _smooth(hw + 4.0, 40.0, d) * (hills + 4.0) + _smooth(60.0, 160.0, d) * 18.0
	)
	if s > RIVER_S.x and s < RIVER_S.y:
		var k: float = 1.0 - _smooth(RIVER_HALF, RIVER_HALF + 7.0, absf(lat - RIVER_OFFSET))
		h = lerpf(h, th - 1.6, k)
	return h


func _terrain_cell(x: float, z: float) -> String:
	var n: float = _patch.get_noise_2d(x, z)
	if n > 0.3:
		return "grass_dark"
	if n < -0.35:
		return "meadow"
	return "grass"


# ---------------------------------------------------------------- terrain


func _bounds() -> Rect2:
	var r := Rect2(Vector2(_sx[0], _sz[0]), Vector2.ZERO)
	for i: int in _sx.size():
		r = r.expand(Vector2(_sx[i], _sz[i]))
	return r


func _terrain() -> void:
	var b: Rect2 = _bounds()
	_grid(b.grow(NEAR_BAND + NEAR_STEP), NEAR_STEP, true)
	_grid(b.grow(FAR_PAD), FAR_STEP, false)


func _grid(area: Rect2, step: float, near: bool) -> void:
	var nx: int = int(area.size.x / step) + 1
	var nz: int = int(area.size.y / step) + 1
	var hs := PackedFloat32Array()
	var ds := PackedFloat32Array()
	hs.resize(nx * nz)
	ds.resize(nx * nz)
	var row_guess: int = 0
	for j: int in nz:
		var z: float = area.position.y + float(j) * step
		var guess: int = _nearest_global(area.position.x, z) if j == 0 else row_guess
		for i: int in nx:
			var x: float = area.position.x + float(i) * step
			var idx: int = _nearest_from(x, z, guess)
			if i == 0:
				# Re-anchor every row with a global look so bends cannot trap us.
				var g: int = _nearest_global(x, z) if j % 8 == 0 else idx
				if _d2(g, x, z) < _d2(idx, x, z):
					idx = g
				row_guess = idx
			guess = idx
			var pr: Array = _probe(x, z, idx)
			ds[j * nx + i] = pr[0]
			hs[j * nx + i] = _height(x, z, pr)
	for j: int in nz - 1:
		for i: int in nx - 1:
			var k: int = j * nx + i
			var dmin: float = minf(minf(ds[k], ds[k + 1]), minf(ds[k + nx], ds[k + nx + 1]))
			var dc: float = (ds[k] + ds[k + 1] + ds[k + nx] + ds[k + nx + 1]) * 0.25
			if near and dmin >= NEAR_BAND:
				continue
			if not near and dc < FAR_FROM:
				continue
			var x0: float = area.position.x + float(i) * step
			var z0: float = area.position.y + float(j) * step
			var p00 := Vector3(x0, hs[k], z0)
			var p10 := Vector3(x0 + step, hs[k + 1], z0)
			var p01 := Vector3(x0, hs[k + nx], z0 + step)
			var p11 := Vector3(x0 + step, hs[k + nx + 1], z0 + step)
			var mb: RrMeshBuilder = _chunk(Vector3(x0 + step * 0.5, 0.0, z0 + step * 0.5), near)
			var cell: String = _terrain_cell(x0, z0)
			var cell2: String = _terrain_cell(x0 + step, z0 + step)
			if not near:
				cell = "hill_far" if dc > 260.0 and _patch.get_noise_2d(x0, z0) > 0.1 else cell
				cell2 = cell
			mb.tri_out(p00, p10, p11, cell, Vector3.UP)
			mb.tri_out(p00, p11, p01, cell2, Vector3.UP)


func _chunk(p: Vector3, near: bool) -> RrMeshBuilder:
	var size: float = NEAR_CHUNK if near else FAR_CHUNK
	var key := Vector2i(floori(p.x / size), floori(p.z / size))
	var d: Dictionary = near_chunks if near else far_chunks
	if not d.has(key):
		d[key] = RrMeshBuilder.new()
	return d[key]


# ---------------------------------------------------------------- track


func _ribbon() -> void:
	var step: float = 2.0
	var s: float = RrTrack.S_MIN
	while s < RrTrack.S_MAX - step:
		var s1: float = s + step
		var mb: RrMeshBuilder = _chunk(track.center(s + step * 0.5), true)
		var hw0: float = track.width(s) * 0.5
		var hw1: float = track.width(s1) * 0.5
		var lane: bool = track.surface(s + 0.5 * step) == "lane"
		for strip: Array in _strips(s, lane):
			var a: float = strip[0]
			var b: float = strip[1]
			var cell: String = strip[2]
			var a0: float = _edge(a, hw0)
			var b0: float = _edge(b, hw0)
			var a1: float = _edge(a, hw1)
			var b1: float = _edge(b, hw1)
			mb.quad_out(
				track.world_point(s, a0, 0.03),
				track.world_point(s, b0, 0.03),
				track.world_point(s1, b1, 0.03),
				track.world_point(s1, a1, 0.03),
				cell,
				Vector3.UP
			)
		# Edge tubes: cream curbs on dirt, blue rails on the skyway.
		for side: float in [-1.0, 1.0]:
			var pts := PackedVector3Array(
				[
					track.world_point(s, side * (hw0 + 0.12), 0.12),
					track.world_point(s1, side * (hw1 + 0.12), 0.12),
				]
			)
			mb.tube(pts, 0.16 if lane else 0.22, 6, "sky" if lane else "curb")
			if not lane and _rng.randf() < 0.9:
				var px: float = side * (hw0 - _rng.randf_range(0.25, 0.9))
				var pp: Vector3 = track.world_point(s + _rng.randf() * step, px, 0.04)
				var r: float = _rng.randf_range(0.06, 0.12)
				mb.ico(pp, Vector3(r * 1.3, r * 0.6, r), "pebble", 0)
		if s >= RrTrack.FENCE.x and s < RrTrack.FENCE.y:
			_fence(mb, s, hw0)
		if s >= RIVER_S.x and s < RIVER_S.y:
			_river(s, s1)
		s = s1
	_lines()
	_rock_cut()


## Strip edges as lateral metres; +-99 marks the moving track edge.
func _edge(v: float, hw: float) -> float:
	if v <= -99.0:
		return -hw
	if v >= 99.0:
		return hw
	if v < 0.0:
		return maxf(v, -hw)
	return minf(v, hw)


func _strips(s: float, lane: bool) -> Array:
	if not lane:
		return [
			[-99.0, -1.45, "dirt"],
			[-1.45, -1.15, "dirt_dark"],
			[-1.15, 1.15, "dirt"],
			[1.15, 1.45, "dirt_dark"],
			[1.45, 99.0, "dirt"],
		]
	var dash: String = "lane_stripe" if int(floorf(s / 3.0)) % 2 == 0 else "lane"
	return [
		[-99.0, -4.65, "lane_dark"],
		[-4.65, -4.45, "lane_stripe"],
		[-4.45, -0.1, "lane"],
		[-0.1, 0.1, dash],
		[0.1, 4.45, "lane"],
		[4.45, 4.65, "lane_stripe"],
		[4.65, 99.0, "lane_dark"],
	]


## Start line (white) and a chequered finish line on the ground.
func _lines() -> void:
	var mb: RrMeshBuilder = _chunk(track.center(0.0), true)
	var hw: float = track.width(0.0) * 0.5
	mb.quad_out(
		track.world_point(-0.2, -hw, 0.05),
		track.world_point(-0.2, hw, 0.05),
		track.world_point(0.2, hw, 0.05),
		track.world_point(0.2, -hw, 0.05),
		"curb",
		Vector3.UP
	)
	var fs: float = track.length
	var fw: float = track.width(fs) * 0.5
	var mf: RrMeshBuilder = _chunk(track.center(fs), true)
	var n: int = 12
	for row: int in 2:
		for k: int in n:
			var x0: float = -fw + 2.0 * fw * float(k) / float(n)
			var x1: float = -fw + 2.0 * fw * float(k + 1) / float(n)
			var s0: float = fs - 1.0 + float(row)
			mf.quad_out(
				track.world_point(s0, x0, 0.05),
				track.world_point(s0, x1, 0.05),
				track.world_point(s0 + 1.0, x1, 0.05),
				track.world_point(s0 + 1.0, x0, 0.05),
				"ink" if (k + row) % 2 == 0 else "white",
				Vector3.UP
			)


func _fence(mb: RrMeshBuilder, s: float, hw: float) -> void:
	var b := Basis(Vector3.UP, track.yaw(s))
	for side: float in [-1.0, 1.0]:
		var base: Vector3 = track.world_point(s, side * (hw + 0.45), 0.0)
		mb.box(base + Vector3.UP * 0.5, Vector3(0.09, 0.5, 0.09), b, "trunk")
		var nxt: Vector3 = track.world_point(s + 2.0, side * (hw + 0.45), 0.0)
		for y: float in [0.45, 0.85]:
			var mid: Vector3 = (base + nxt) * 0.5 + Vector3.UP * y
			mb.box(mid, Vector3(0.05, 0.07, 1.02), b, "wood")


func _river(s: float, s1: float) -> void:
	var mb: RrMeshBuilder = _chunk(track.world_point(s, RIVER_OFFSET), true)
	var y0: float = track.center(s).y - 1.25
	var y1: float = track.center(s1).y - 1.25
	var a0: Vector3 = track.world_point(s, RIVER_OFFSET - RIVER_HALF - 1.0)
	var b0: Vector3 = track.world_point(s, RIVER_OFFSET + RIVER_HALF + 1.0)
	var a1: Vector3 = track.world_point(s1, RIVER_OFFSET - RIVER_HALF - 1.0)
	var b1: Vector3 = track.world_point(s1, RIVER_OFFSET + RIVER_HALF + 1.0)
	a0.y = y0
	b0.y = y0
	a1.y = y1
	b1.y = y1
	mb.quad_out(a0, b0, b1, a1, "lane", Vector3.UP)


## Rock cut (GDD: rock tunnel s 540-580): boulders line both sides.
func _rock_cut() -> void:
	var s: float = RrTrack.TUNNEL.x - 4.0
	while s < RrTrack.TUNNEL.y + 4.0:
		for side: float in [-1.0, 1.0]:
			var hw: float = track.width(s) * 0.5
			var p: Vector3 = track.world_point(s, side * (hw + 1.4), -0.2)
			var sc: float = _rng.randf_range(1.3, 2.1)
			var xf := Transform3D(
				Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc * 1.4, sc)), p
			)
			_chunk(p, true).add_arrays(_protos["rock"], xf)
		s += 3.2


# ---------------------------------------------------------------- scenery


func _scenery() -> void:
	var placed: int = 0
	var tries: int = 0
	while placed < TREE_COUNT and tries < TREE_COUNT * 20:
		tries += 1
		var s: float = _rng.randf_range(-30.0, RrTrack.S_MAX - 10.0)
		var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
		var off: float = 3.2 + pow(_rng.randf(), 1.6) * 70.0
		if _place(s, side, off, true):
			placed += 1
	placed = 0
	tries = 0
	while placed < FAR_TREE_COUNT and tries < FAR_TREE_COUNT * 20:
		tries += 1
		var s2: float = _rng.randf_range(-30.0, RrTrack.S_MAX)
		var side2: float = -1.0 if _rng.randf() < 0.5 else 1.0
		if _place(s2, side2, _rng.randf_range(70.0, 200.0), false):
			placed += 1


func _place(s: float, side: float, off: float, near: bool) -> bool:
	var hw: float = track.width(s) * 0.5
	var p: Vector3 = track.world_point(s, side * (hw + off))
	var gi: int = _nearest_global(p.x, p.z)
	var pr: Array = _probe(p.x, p.z, gi)
	var d: float = pr[0]
	if d < track.width(float(pr[1])) * 0.5 + 2.6:
		return false
	var ps: float = pr[1]
	if ps > RIVER_S.x and ps < RIVER_S.y and absf(float(pr[2]) - RIVER_OFFSET) < RIVER_HALF + 4.0:
		return false
	if absf(ps - RrTrack.TUNNEL.x - 20.0) < 26.0 and d < hw + 4.0:
		return false
	p.y = _height(p.x, p.z, pr) - 0.15
	var kind: String = (
		"tree_pine" if _noise2.get_noise_2d(p.x * 0.4, p.z * 0.4) > -0.1 else "tree_round"
	)
	var sc: float = _rng.randf_range(0.9, 1.5)
	if _rng.randf() < 0.14:
		kind = "rock"
		sc *= 0.8
	if not near:
		sc *= 1.6
	var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * sc), p)
	_chunk(p, near).add_arrays(_protos[kind], xf)
	return true


## All chunk meshes: [ArrayMesh, centre, near?, triangle count].
func meshes() -> Array:
	var out: Array = []
	for near: bool in [true, false]:
		var d: Dictionary = near_chunks if near else far_chunks
		var size: float = NEAR_CHUNK if near else FAR_CHUNK
		for key: Vector2i in d:
			var mb: RrMeshBuilder = d[key]
			if mb.tri_count() == 0:
				continue
			var c := Vector3((float(key.x) + 0.5) * size, 0.0, (float(key.y) + 0.5) * size)
			out.append([mb.commit(), c, near, mb.tri_count()])
	return out
