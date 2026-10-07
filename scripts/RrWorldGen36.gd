class_name RrWorldGen36
extends RefCounted

## Ground and scatter of worlds 3-6 (DESIGN 11) for RrWorldGen: heights,
## splat weights, open water and props. World 3 is a glacier valley (gentle
## sunny right side, rock walls left, an icefall round the ice cave, a
## crevasse under the cave jump); world 4 a volcanic slope (basalt ridges, a
## lava basin left of the rail); world 5 a rainforest floor (the river under
## the split path, the waterfall pool); world 6 a flat night quay (the
## harbour basin left of the quay edge, the water channel under the crane
## jump). Props use RrWorldGen's chunked MultiMeshes; kinds starting with
## "lod_" get a far card in RrWorld (DESIGN 11.0 rule 3), "col_" kinds carry
## a colour per instance (W6 containers).

const SERACS: Array[String] = ["world3/serac_a", "world3/serac_b"]
const JUNGLE: Array[String] = ["world5/tree_jungle_a", "world5/tree_jungle_b"]
## DESIGN 11.4 container paints: red, blue, green, grey, orange.
const PAINTS: Array[Color] = [
	Color(0.557, 0.165, 0.122),
	Color(0.122, 0.306, 0.549),
	Color(0.180, 0.420, 0.227),
	Color(0.549, 0.569, 0.588),
	Color(0.722, 0.329, 0.118),
]

var gen: RrWorldGen
var track: RrTrack
var world: int = 3


func _init(g: RrWorldGen) -> void:
	gen = g
	track = g.track
	world = g.world


func _fl(name: String, fallback: float) -> float:
	return float(track.flavor.get(name, fallback))


static func _sm(a: float, b: float, x: float) -> float:
	return RrWorldGen.sm(a, b, x)


## Centre height for the ground: W6 keeps the quay level under the
## container-stack ramp (the stack mesh is the riding surface there).
func _th(s: float) -> float:
	var y: float = track.center(s).y
	if world == 6:
		y -= maxf(0.0, track.lift_at(s))
	return y


# ---------------------------------------------------------------- height


func height(s: float, lat: float, x: float, z: float) -> float:
	var th: float = _th(s)
	var hw: float = track.width(s) * 0.5
	var d: float = absf(lat)
	var off: float = maxf(0.0, d - hw)
	var h: float = th - 0.04
	match world:
		3:
			h = _glacier(s, lat, x, z, th, hw, off)
		4:
			h = _ash(s, lat, x, z, th, hw, off)
		5:
			h = _forest(s, lat, x, z, th, hw, off)
		_:
			h = _quay(s, lat, x, z, th, hw, off)
	return _gap(s, d, h)


func _glacier(s: float, lat: float, x: float, z: float, th: float, hw: float, off: float) -> float:
	var hills: float = gen.noise(x, z) * _fl("hills", 6.0) + gen.noise2(x, z) * 1.0
	var h: float = th - 0.04 + _sm(0.0, 5.0, off) * 0.25 + off * 0.06
	h += _sm(6.0, 40.0, off) * (hills + 3.0)
	if lat > 0.0:
		# Sun side (DESIGN 11.1): slope <= 0.3 so it never shades the piste.
		h += _sm(40.0, 220.0, off) * 30.0
	else:
		var q: float = absf(lat) - _fl("wall", 36.0) + gen.noise(x * 1.7, z * 1.7) * 4.0
		if q > 0.0:
			h += minf(q * 0.95, 140.0) * (1.0 + 0.25 * gen.noise2(x * 0.5, z * 0.5))
	if absf(lat) <= hw:
		h = th - 0.04
	if track.tunnel.x >= 0.0:
		# The icefall round the ice cave: about 9.5 m of ice beside the mouth.
		var k: float = _sm(track.tunnel.x - 14.0, track.tunnel.x, s)
		k *= 1.0 - _sm(track.tunnel.y, track.tunnel.y + 5.0, s)
		h += k * _sm(2.5, 6.0, off) * (9.5 + gen.noise2(x, z) * 2.0)
	return h


func _ash(s: float, lat: float, x: float, z: float, th: float, hw: float, off: float) -> float:
	var hills: float = gen.noise(x, z) * _fl("hills", 7.0) + gen.noise2(x * 1.4, z * 1.4) * 1.6
	var h: float = th - 0.04 + _sm(0.0, 4.0, off) * 0.3 + off * 0.05
	h += _sm(5.0, 34.0, off) * (hills + 2.0)
	var q: float = absf(lat) - _fl("wall", 40.0) + gen.noise(x * 1.3, z * 1.3) * 5.0
	if q > 0.0:
		# Basalt ridges 34 m+ out (DESIGN 11.2), jagged tops.
		h += minf(q * 0.7, 60.0) * (1.0 + 0.35 * gen.noise2(x * 0.8, z * 0.8))
	if absf(lat) <= hw:
		h = th - 0.04
	var lava: Vector2 = track.zone("lava")
	if lava.x >= 0.0 and lat < 0.0:
		# Lava basin left of the rail: lava only behind rails (GDD 6.0).
		var k: float = _sm(lava.x, lava.x + 14.0, s) * (1.0 - _sm(lava.y - 14.0, lava.y, s))
		k *= _sm(1.6, 3.2, off) * (1.0 - _sm(24.0, 32.0, off))
		h = lerpf(h, th - 1.5, k)
	return h


func _forest(s: float, lat: float, x: float, z: float, th: float, hw: float, off: float) -> float:
	var hills: float = gen.noise(x, z) * _fl("hills", 7.0) + gen.noise2(x, z) * 1.4
	var h: float = th - 0.04 + _sm(0.0, 5.0, off) * 0.3 + off * 0.08
	h += _sm(5.0, 40.0, off) * (hills + 3.0) + _sm(60.0, 170.0, off) * 18.0
	if absf(lat) <= hw:
		h = th - 0.04
	var sp: Vector2 = track.zone("split")
	if sp.x >= 0.0 and track.split.size() >= 4:
		var mid: float = (sp.x + sp.y) * 0.5
		var xa: float = float(track.split[2])
		var xb: float = float(track.split[3])
		var ds: float = absf(s - mid)
		# The river crosses the split path: a deep gorge under the rope bridge
		# (bridge side and beyond), a shallow ford bar on the other route, and
		# the rocky island between them.
		var bridge_left: bool = xa < 0.0
		var on_bridge_side: bool = lat < xa if bridge_left else lat > xb
		var kb: float = 1.0 - _sm(13.0, 17.0, ds)
		var kc: float = 1.0 - _sm(8.0, 12.0, ds)
		if on_bridge_side:
			h = lerpf(h, th - 5.5 + gen.noise2(x, z) * 0.6, kb)
		elif absf(lat) > track.width(s) * 0.5:
			h = lerpf(h, th - 2.6, kc)
		var isl: Vector2 = track.island(s)
		if isl.x < isl.y and lat > isl.x - 0.2 and lat < isl.y + 0.2:
			h = th + 0.35 + absf(gen.noise2(x * 3.0, z * 3.0)) * 0.6
	return h


func _quay(_s: float, lat: float, x: float, z: float, th: float, hw: float, off: float) -> float:
	var h: float = (
		th - 0.04 + _sm(0.0, 3.0, off) * 0.05 + gen.noise2(x, z) * 0.03 * _sm(1.0, 4.0, off)
	)
	if absf(lat) <= hw:
		h = th - 0.04
	var q: float = -lat - _fl("quay", 15.0)
	if q > 0.0:
		# Quay wall down to the harbour basin (water at -3 m, bed at -6 m).
		h = lerpf(h, th - 6.0, _sm(0.0, 1.2, q))
	elif lat > 0.0:
		h += _sm(60.0, 400.0, off) * 2.0
	return h


## A gorge to jump (W3 crevasse 18 m deep, W5 waterfall pool, W6 water
## channel): the ground drops away between the lips.
func _gap(s: float, d: float, h: float) -> float:
	if track.gap.x < 0.0:
		return h
	var g: float = _sm(track.gap.x - 1.0, track.gap.x + 1.5, s)
	g *= 1.0 - _sm(track.gap.y - 1.5, track.gap.y + 1.0, s)
	if g <= 0.0:
		return h
	var depth: float = 18.0
	var reach: Vector2 = Vector2(24.0, 40.0)
	if world == 5:
		depth = 9.5
	elif world == 6:
		depth = 6.0
		reach = Vector2(400.0, 500.0)
	var floor_y: float = _th(track.gap.x) - depth
	return lerpf(h, minf(h, floor_y), g * (1.0 - _sm(reach.x, reach.y, d)))


# ---------------------------------------------------------------- splat


## Splat weights (R trail, G rock, B patch, A verge) for worlds 3-6.
func splat(
	s: float, lat: float, x: float, z: float, slope: float, trail: float, rock: float, edge: float
) -> Color:
	var hw: float = track.width(s) * 0.5
	var d: float = absf(lat)
	var patch: float = _sm(0.1, 0.4, gen.patch_noise(x, z)) * _sm(1.5, 5.0, d - hw)
	var verge: float = _sm(hw - 0.2, hw + 0.5, d) * (1.0 - _sm(1.5, 4.0 + edge * 3.0, d - hw))
	if world == 6:
		verge = 0.0
		patch *= 0.5
	var isl: Vector2 = track.island(s)
	if isl.x < isl.y and lat > isl.x - 0.3 and lat < isl.y + 0.3:
		trail = 0.0
		rock = 1.0
	if world == 3 and slope < 0.2:
		rock *= 0.5
	return Color(trail, rock, patch, verge * 0.85)


# ---------------------------------------------------------------- water


func water() -> void:
	if world == 5:
		var sp: Vector2 = track.zone("split")
		if sp.x >= 0.0:
			var mid: float = (sp.x + sp.y) * 0.5
			gen.add_water(mid - 11.0, mid + 11.0, -90.0, 90.0, -2.2, 2.0)
		if track.gap.x >= 0.0:
			gen.add_water(track.gap.x - 1.0, track.gap.y + 1.0, -40.0, 40.0, -9.0, 2.0)
	elif world == 6:
		var quay: float = _fl("quay", 15.0)
		var s: float = RrTrack.S_MIN
		while s < track.s_max:
			gen.add_water(s, minf(s + 600.0, track.s_max), -quay - 0.5, -quay - 520.0, -3.0, 15.0)
			s += 600.0
		if track.gap.x >= 0.0:
			gen.add_water(track.gap.x - 2.0, track.gap.y + 2.0, -quay, 420.0, -3.0, 2.0)


# ---------------------------------------------------------------- scenery


func scenery() -> void:
	match world:
		3:
			_scenery_w3()
		4:
			_scenery_w4()
		5:
			_scenery_w5()
		_:
			_scenery_w6()
	_streamers()


## Random spot [s, lat] off the trail between a and b metres past the edge.
func _spot(a: float, b: float, power: float = 1.0) -> Vector2:
	var r: RandomNumberGenerator = gen.rng()
	var s: float = r.randf_range(-30.0, track.s_max - 6.0)
	var side: float = -1.0 if r.randf() < 0.5 else 1.0
	var hw: float = track.width(s) * 0.5
	return Vector2(s, side * (hw + a + pow(r.randf(), power) * (b - a)))


func _ok(sp: Vector2) -> bool:
	return gen.free_spot(sp.x, sp.y) and not track.in_gap(sp.x) and not track.in_tunnel(sp.x)


func _scatter(
	kind: String, n: int, a: float, b: float, sc: Vector2, chunk: float, sink: float
) -> void:
	var r: RandomNumberGenerator = gen.rng()
	var placed: int = 0
	var tries: int = 0
	while placed < n and tries < n * 30:
		tries += 1
		var sp: Vector2 = _spot(a, b, 1.4)
		if not _ok(sp):
			continue
		var p: Vector3 = gen.ground_at(sp.x, sp.y)
		p.y -= sink
		var k: float = r.randf_range(sc.x, sc.y)
		var stretch := Vector3(k, k * r.randf_range(0.8, 1.15), k)
		gen.put(kind, chunk, sp.x, gen.yaw_xf(p, r.randf() * TAU, stretch))
		placed += 1


func _scenery_w3() -> void:
	var r: RandomNumberGenerator = gen.rng()
	# Course edge (DESIGN 11.1): a flag pole every 10 m on both sides.
	var s: float = 0.0
	while s < track.length + 20.0:
		if not track.in_tunnel(s) and not track.in_gap(s):
			for side: float in [-1.0, 1.0]:
				var lat: float = side * (track.width(s) * 0.5 + 0.9)
				var fp: Vector3 = gen.ground_at(s, lat)
				gen.put("world3/flag_pole", 150.0, s, gen.yaw_xf(fp, track.yaw(s), Vector3.ONE))
		s += 10.0
	# Seracs: a wall of them along the serac pass, scattered blocks beyond.
	var pz: Vector2 = track.zone("seracs")
	if pz.x >= 0.0:
		var t: float = pz.x
		while t < pz.y:
			for side2: float in [-1.0, 1.0]:
				var lat2: float = side2 * (track.width(t) * 0.5 + r.randf_range(2.2, 5.0))
				var sp2: Vector3 = gen.ground_at(t, lat2)
				sp2.y -= 0.6
				var k2: float = r.randf_range(0.9, 1.5)
				gen.put(
					"lod_" + SERACS[r.randi() % 2],
					150.0,
					t,
					gen.yaw_xf(sp2, r.randf() * TAU, Vector3(k2, k2 * r.randf_range(0.9, 1.3), k2))
				)
			t += r.randf_range(7.0, 11.0)
	for i: int in int(70.0 * _fl("seracs", 1.0)):
		var sp3: Vector2 = _spot(12.0, 90.0, 1.3)
		if not _ok(sp3):
			continue
		var p3: Vector3 = gen.ground_at(sp3.x, sp3.y)
		p3.y -= 0.8
		var k3: float = r.randf_range(0.8, 1.8)
		gen.put(
			"lod_" + SERACS[r.randi() % 2],
			300.0,
			sp3.x,
			gen.yaw_xf(p3, r.randf() * TAU, Vector3.ONE * k3)
		)
	_scatter(
		"lod_world3/glacier_boulder",
		int(240.0 * _fl("rocks", 1.0)),
		2.5,
		70.0,
		Vector2(0.6, 2.2),
		150.0,
		0.15
	)


func _scenery_w4() -> void:
	var r: RandomNumberGenerator = gen.rng()
	_scatter(
		"lod_world4/scoria_rock",
		int(260.0 * _fl("rocks", 1.0)),
		2.0,
		60.0,
		Vector2(0.4, 1.6),
		150.0,
		0.2
	)
	for i: int in int(70.0 * _fl("columns", 1.0)):
		var sp: Vector2 = _spot(14.0, 70.0, 1.2)
		if not _ok(sp):
			continue
		var p: Vector3 = gen.ground_at(sp.x, sp.y)
		p.y -= 0.6
		var k: float = r.randf_range(0.8, 1.7)
		gen.put(
			"lod_world4/basalt_columns",
			300.0,
			sp.x,
			gen.yaw_xf(p, r.randf() * TAU, Vector3(k, k * r.randf_range(0.8, 1.4), k))
		)
	_scatter("world4/burnt_snag", 34, 3.0, 22.0, Vector2(0.8, 1.3), 300.0, 0.05)


func _scenery_w5() -> void:
	var r: RandomNumberGenerator = gen.rng()
	# Canopy: impostor trees, a dense wall near the trail and thin beyond 40 m
	# (the same split into near / far chunks as the W1 pines).
	var count: int = int(1500.0 * _fl("trees", 1.0))
	var reach: float = _fl("reach", 40.0)
	var n: int = 0
	var tries: int = 0
	while n < count and tries < 60000:
		tries += 1
		var sp: Vector2 = _spot(4.5, 4.5 + reach, 1.6)
		if not _ok(sp):
			continue
		var off: float = absf(sp.y) - track.width(sp.x) * 0.5
		var p: Vector3 = gen.ground_at(sp.x, sp.y)
		p.y -= 0.3
		var k: float = r.randf_range(0.75, 1.15)
		var kind: String = JUNGLE[r.randi() % 2]
		var near: bool = off < 45.0
		gen.put(
			("near_" if near else "far_") + kind,
			80.0 if near else 300.0,
			sp.x,
			gen.yaw_xf(p, r.randf() * TAU, Vector3.ONE * k)
		)
		n += 1
	_scatter("lod_world5/buttress_tree", 26, 10.0, 55.0, Vector2(0.8, 1.15), 300.0, 0.4)
	# Big-leaf undergrowth along the verge (DESIGN 11.3: 35 m visibility).
	var s: float = -20.0
	var plants: float = _fl("plants", 1.0)
	while s < track.s_max - 4.0:
		for side: float in [-1.0, 1.0]:
			if r.randf() > 0.55 * plants:
				continue
			var lat: float = side * (track.width(s) * 0.5 + r.randf_range(0.5, 6.0))
			if not gen.free_spot(s, lat) or track.in_gap(s):
				continue
			var gp: Vector3 = gen.ground_at(s, lat)
			var k2: float = r.randf_range(0.7, 1.3)
			var kind2: String = ["world5/shrub_jungle", "world5/plant_calathea", "fern"][
				r.randi() % 3
			]
			gen.put(kind2, 60.0, s, gen.yaw_xf(gp, r.randf() * TAU, Vector3.ONE * k2))
		s += 3.0


func _scenery_w6() -> void:
	var r: RandomNumberGenerator = gen.rng()
	var quay: float = _fl("quay", 15.0)
	var s: float = -40.0
	# Container rows on the land side (right), coloured per instance.
	while s < track.s_max - 10.0:
		var hw: float = track.width(s) * 0.5
		var gap: bool = track.in_gap(s) or track.in_gap(s + 14.0) or track.in_gap(s - 14.0)
		if not gap and r.randf() < 0.8 * _fl("stacks", 1.0):
			var lat: float = hw + r.randf_range(4.0, 9.0)
			_stack(s, lat, r.randi_range(1, 3), 0.0)
			if r.randf() < 0.6:
				_stack(s, lat + r.randf_range(3.0, 4.0), r.randi_range(1, 4), 0.0)
		s += r.randf_range(14.0, 22.0)
	# Container canyon (the W6 landmark piece): stacks close on both sides.
	var cz: Vector2 = track.zone("containers")
	if cz.x >= 0.0:
		var t: float = cz.x + 8.0
		while t < cz.y - 6.0:
			for side: float in [-1.0, 1.0]:
				var lat2: float = side * (track.width(t) * 0.5 + 1.6)
				_stack(t, lat2, r.randi_range(2, 3), 0.0)
			t += 13.0
	# Quay edge: jersey barriers every 1.6 m, bollards every 14 m.
	var e: float = -40.0
	while e < track.s_max - 4.0:
		if not track.in_gap(e):
			var lat3: float = -(quay - 0.8)
			var bp: Vector3 = gen.ground_at(e, lat3)
			gen.put("world6/concrete_barrier", 150.0, e, gen.yaw_xf(bp, track.yaw(e), Vector3.ONE))
			if int(e) % 14 == 0:
				var bo: Vector3 = gen.ground_at(e, -(quay - 0.2))
				gen.put("world6/bollard", 300.0, e, gen.yaw_xf(bo, 0.0, Vector3.ONE))
		e += 1.6
	# Sodium lamps both sides, the inner head over the track (DESIGN 11.4).
	var step: float = _fl("lamp_step", 32.0)
	var l: float = 0.0
	while l < track.length + 40.0:
		if not track.in_gap(l) and not _near_stack(l):
			for side2: float in [-1.0, 1.0]:
				var lat4: float = side2 * (track.width(l) * 0.5 + 2.2)
				var lp: Vector3 = gen.ground_at(l, lat4)
				gen.put("world6/sodium_lamp", 300.0, l, gen.yaw_xf(lp, track.yaw(l), Vector3.ONE))
				var pool: Vector3 = gen.ground_at(l + 2.0, side2 * (track.width(l) * 0.5 - 0.4))
				pool.y += 0.05
				gen.put(
					"fxq_light_pool",
					300.0,
					l,
					gen.yaw_xf(pool, track.yaw(l), Vector3(8.0, 1.0, 9.0))
				)
				var head: Vector3 = (
					lp + RrTrack.right_of(track.yaw(l)) * (-side2 * 2.0) + Vector3.UP * 11.6
				)
				gen.put(
					"fxb_sodium_glow",
					300.0,
					l,
					Transform3D(Basis().scaled(Vector3.ONE * 1.5), head)
				)
		l += step
	# Far land side: warehouses and container stacks in the distance.
	for i: int in 14:
		var ws: float = r.randf_range(0.0, track.s_max)
		var wl: float = track.width(ws) * 0.5 + r.randf_range(55.0, 110.0)
		var wp: Vector3 = gen.ground_at(ws, wl)
		gen.put(
			"world6/warehouse", 10000.0, 0.0, gen.yaw_xf(wp, track.yaw(ws) + PI * 0.5, Vector3.ONE)
		)
	for i: int in 16:
		var fs: float = r.randf_range(-40.0, track.s_max)
		var fl: float = track.width(fs) * 0.5 + r.randf_range(150.0, 320.0)
		var fp: Vector3 = gen.ground_at(fs, fl)
		gen.put(
			"world6/container_stack_far", 10000.0, 0.0, gen.yaw_xf(fp, track.yaw(fs), Vector3.ONE)
		)
	# Channel buoys in the basin.
	for i: int in 12:
		var bs: float = r.randf_range(0.0, track.s_max)
		var bl: float = -(quay + r.randf_range(25.0, 110.0))
		var bpos: Vector3 = track.world_point(bs, bl)
		bpos.y = _th(bs) - 3.2
		gen.put("world6/sea_marker", 10000.0, 0.0, gen.yaw_xf(bpos, r.randf() * TAU, Vector3.ONE))


## True within 40 m of the container-stack jump (no lamp masts in its way).
func _near_stack(s: float) -> bool:
	var lip: float = track.zone_at("lip", -999.0)
	return s > lip - 45.0 and s < lip + 40.0


## A stack of n containers at (s, lat), long side along the track (yaw_add
## 0) or across it (PI / 2), each in one of the five paints.
func _stack(s: float, lat: float, n: int, yaw_add: float) -> void:
	var r: RandomNumberGenerator = gen.rng()
	if not gen.free_spot(s, lat):
		return
	var p: Vector3 = gen.ground_at(s, lat)
	var yaw: float = track.yaw(s) + PI * 0.5 + yaw_add
	for k: int in n:
		var q: Vector3 = p + Vector3.UP * (2.6 * float(k))
		var col: Color = PAINTS[r.randi() % PAINTS.size()]
		gen.put_c("lod_col_world6/container", 150.0, s, gen.yaw_xf(q, yaw, Vector3.ONE), col)


## Close roadside streamers (GDD 11.1) in each world's own small props.
func _streamers() -> void:
	var r: RandomNumberGenerator = gen.rng()
	var spc: Vector2 = RrBalance.PROP_NEAR_SPACING_M
	var kinds: Dictionary = {
		3: ["st_world3/glacier_boulder", Vector2(0.25, 0.5)],
		4: ["st_world4/scoria_rock", Vector2(0.2, 0.45)],
		5: ["st_world5/plant_anthurium", Vector2(0.6, 1.0)],
		6: ["st_world6/traffic_cone", Vector2(0.9, 1.1)],
	}
	if world == 6:
		return  # the quay is bare; barriers and lamps give the speed cue
	var kd: Array = kinds[world]
	for side: float in [-1.0, 1.0]:
		var s: float = -20.0 + r.randf() * spc.y
		while s < track.length + 60.0:
			var lat: float = side * (track.width(s) * 0.5 + 0.6 + r.randf_range(1.0, 3.0))
			if gen.free_spot(s, lat) and not track.in_gap(s) and not track.in_tunnel(s):
				var p: Vector3 = gen.ground_at(s, lat)
				p.y -= 0.05
				var k: float = r.randf_range(kd[1].x, kd[1].y)
				gen.put(String(kd[0]), 150.0, s, gen.yaw_xf(p, r.randf() * TAU, Vector3.ONE * k))
			s += r.randf_range(spc.x, spc.y)
