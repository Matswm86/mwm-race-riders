class_name RrLandmarks
extends RefCounted

## Set pieces of every world (DESIGN 9a, 10a, 11), placed by the ground
## generator from the track data so they bake with the ground and mirror
## with it on Pro tracks. Each piece is one "lm_<model>" prop (one draw per
## model); scatter props keep clear of them (RrWorldGen.keep_out).
## W1 log cabins, the river bridge on river-road kickers, the closed rock
##    tunnel (portals + lining) replacing the old boulder cut.
## W2 sandstone arch over the dry wash, the gas station on the rim highway,
##    canyon cliffs on the wall tops, the mesa backdrop ring.
## W3 ice cave + crevasse at the signature, glacier hut, a side crevasse with
##    the ladder bridge, the far mountain ridges.
## W4 steam vent, the lava basin behind safety rails, research station,
##    the far crater cone.
## W5 rope bridge over the split path's river, the waterfall at the
##    signature, stone ruins.
## W6 container-stack ramp and gantry crane at the crane jump, ferry, the
##    far lit bridge.

var gen: RrWorldGen
var track: RrTrack
var world: int = 1


func _init(g: RrWorldGen) -> void:
	gen = g
	track = g.track
	world = g.world


func place() -> void:
	match world:
		1:
			_w1()
		2:
			_w2()
		3:
			_w3()
		4:
			_w4()
		5:
			_w5()
		6:
			_w6()


func _put(model: String, xf: Transform3D, keep_r: float = 0.0) -> void:
	gen.put("lm_" + model, 100000.0, 0.0, xf)
	if keep_r > 0.0:
		gen.keep_out(xf.origin, keep_r)


## Flat frame at (s, lat) on the centre-line height, turned by yaw_add.
func _at(s: float, lat: float, yaw_add: float = 0.0, ground: bool = false) -> Transform3D:
	var p: Vector3 = track.world_point(s, lat)
	p.y = gen.ground_at(s, lat).y if ground else track.center(s).y
	return Transform3D(Basis(Vector3.UP, track.yaw(s) + yaw_add), p)


## Frame that follows the slope at s (linings and decks).
func _slope(s: float, lat: float) -> Transform3D:
	var f: Transform3D = track.frame(s)
	f.origin = track.world_point(s, lat)
	f.origin.y = track.center(s).y
	return f


## Middle of the track's bounding box and its mean heading.
func _middle() -> Array:
	var a: Vector3 = track.center(0.0)
	var b: Vector3 = track.center(track.length)
	var mid: Vector3 = track.center(track.length * 0.5)
	var c := Vector3((a.x + b.x + mid.x) / 3.0, mid.y, (a.z + b.z + mid.z) / 3.0)
	var heading: float = atan2(-(b.x - a.x), -(b.z - a.z))
	return [c, heading]


## A far backdrop at distance dist in direction (heading + ang), its -Z
## facing away from the track, at height y.
func _backdrop(model: String, dist: float, ang: float, y: float, sc: float) -> void:
	var m: Array = _middle()
	var c: Vector3 = m[0]
	var yaw: float = float(m[1]) + ang
	var dir := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var p: Vector3 = c + dir * dist
	p.y = y
	_put(model, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc), p))


# ---------------------------------------------------------------- world 1


func _w1() -> void:
	# Log cabins by the start drop and the finish meadow, doors to the track.
	var s0: float = 28.0
	var hw0: float = track.width(s0) * 0.5
	_put("world1/cabin", _at(s0, -(hw0 + 15.0), PI * 0.5, true), 9.0)
	var s1: float = track.length + 22.0
	var hw1: float = track.width(s1) * 0.5
	_put("world1/cabin", _at(s1, hw1 + 16.0, -PI * 0.5, true), 9.0)
	# The river bridge is the skin of every river-road kicker (RrTrack).
	for i: int in track.kickers.size():
		if track.kicker_models[i] != "world1/river_bridge":
			continue
		var lip: float = track.kickers[i]
		var xf: Transform3D = _at(lip - 8.0, 0.0)
		xf.origin.y = track.center(lip - 5.8).y
		_put("world1/river_bridge", xf, 14.0)
		gen.add_water(lip - 8.0, lip + 8.0, -45.0, 45.0, -2.3, 2.0)
	# Closed rock tunnel: a portal at each end and a lining every 10 m.
	if track.tunnel.x >= 0.0:
		var a: float = track.tunnel.x
		var b: float = track.tunnel.y
		_put("world1/rock_tunnel_portal", _at(a, 0.0), 0.0)
		_put("world1/rock_tunnel_portal", _at(b, 0.0, PI), 0.0)
		var t: float = a + 6.0
		while t < b - 6.0 - 0.5:
			_put("world1/rock_tunnel_segment", _slope(t, 0.0))
			t += 10.0
		var k: float = a - 8.0
		while k < b + 8.0:
			gen.keep_out(track.world_point(k, 0.0), 13.0)
			k += 6.0


# ---------------------------------------------------------------- world 2


func _w2() -> void:
	var lane: Vector2 = track.zone("lane")
	if lane.x < 0.0:
		for row: Array in track.sections:
			if String(row[2]) == "lane":
				lane = Vector2(float(row[0]), float(row[1]))
	var slot: Vector2 = track.zone("slot")
	# The arch over the dry wash before the rim highway (track 1: s 150-250).
	var arch_s: float = 200.0
	var lo: float = 140.0
	var hi: float = maxf(lo, lane.x - 50.0)
	arch_s = clampf(arch_s, lo, hi)
	if slot.x >= 0.0 and arch_s > slot.x - 30.0 and arch_s < slot.y + 20.0:
		arch_s = slot.x - 40.0 if slot.x - 40.0 >= lo else slot.y + 40.0
	if not _near_kicker(arch_s, 25.0):
		_put("world2/sandstone_arch", _at(arch_s, 0.0, 0.0), 0.0)
	# The abandoned gas station on the rim highway, forecourt to the road.
	if lane.x >= 0.0:
		var gs: float = lane.x + (lane.y - lane.x) * 0.8
		var hw: float = track.width(gs) * 0.5
		_put("world2/gas_station", _at(gs, hw + 9.5, -PI * 0.5, true), 14.0)
	# Cliff silhouettes on the wall tops (DESIGN 10a), alternating sides.
	var wall: float = float(track.flavor.get("wall", 15.0))
	for i: int in 6:
		var cs: float = track.length * (0.08 + 0.16 * float(i))
		var side: float = -1.0 if i % 2 == 0 else 1.0
		if side < 0.0 and lane.x >= 0.0 and cs > lane.x - 60.0 and cs < lane.y + 40.0:
			side = 1.0
		var lat: float = side * (wall + 20.0 + float(i % 3) * 4.0)
		var model: String = "world2/canyon_cliff_a" if i % 2 == 0 else "world2/canyon_cliff_b"
		var xf: Transform3D = _at(cs, lat, -PI * 0.5 * side, true)
		xf.origin.y -= 3.0
		_put(model, xf, 0.0)
	# The mesa ring closes the horizon (three 120-degree segments, x1.25).
	var y: float = track.center(track.length * 0.5).y - 12.0
	for k: int in 3:
		_backdrop("world2/mesa_backdrop", 0.0, TAU * float(k) / 3.0, y, 1.25)


func _near_kicker(s: float, r: float) -> bool:
	for k: float in track.kickers:
		if absf(k - s) < r:
			return true
	return false


# ---------------------------------------------------------------- world 3


func _w3() -> void:
	if track.tunnel.x >= 0.0:
		_put("world3/ice_cave", _slope(track.tunnel.x, 0.0), 0.0)
		var k: float = track.tunnel.x - 6.0
		while k < track.tunnel.y + 6.0:
			gen.keep_out(track.world_point(k, 0.0), 14.0)
			k += 6.0
	if track.gap.x >= 0.0:
		var mid: float = (track.gap.x + track.gap.y) * 0.5
		var xf: Transform3D = _at(mid - 7.0, 0.0)
		xf.origin.y = track.center(track.gap.x).y
		_put("world3/crevasse", xf, 16.0)
	# The red glacier hut on the sunny side, its door to the piste.
	var pz: Vector2 = track.zone("seracs")
	var hs: float = pz.y + 25.0 if pz.x >= 0.0 else track.length * 0.3
	var hw: float = track.width(hs) * 0.5
	_put("world3/glacier_hut", _at(hs, hw + 15.0, -PI * 0.5, true), 9.0)
	# A side crevasse with the ladder bridge across it, by the serac pass.
	var cs: float = (pz.x + pz.y) * 0.5 if pz.x >= 0.0 else track.length * 0.5
	var cl: float = track.width(cs) * 0.5 + 34.0
	var cx: Transform3D = _at(cs, cl, PI * 0.5, true)
	_put("world3/crevasse", cx, 22.0)
	var lx: Transform3D = cx
	lx.origin.y += 0.3
	_put("world3/ladder_bridge", lx, 0.0)
	# Peaks close the horizon on three sides (camera far 1200 m).
	var y: float = track.center(track.length * 0.5).y - 30.0
	_backdrop("world3/mountain_ridge", 640.0, 0.0, y, 1.0)
	_backdrop("world3/mountain_ridge", 700.0, PI * 0.5, y, 1.0)
	_backdrop("world3/mountain_ridge", 760.0, -PI * 0.5, y, 1.0)


# ---------------------------------------------------------------- world 4


func _w4() -> void:
	for i: int in track.kickers.size():
		if track.kicker_models[i] == "vent":
			_put("world4/steam_vent", _at(track.kickers[i], 0.0), 0.0)
	var lava: Vector2 = track.zone("lava")
	if lava.x >= 0.0:
		var s: float = lava.x + 6.0
		while s < lava.y - 4.0:
			var hw: float = track.width(s) * 0.5
			var rail: Transform3D = _at(s, -(hw + 0.9), PI * 0.5, true)
			_put("world4/safety_rail", rail, 0.0)
			s += 4.0
		var l: float = lava.x + 26.0
		while l < lava.y - 10.0:
			var hw2: float = track.width(l) * 0.5
			var xf: Transform3D = _at(l, -(hw2 + 11.0), 0.0)
			xf.origin.y = track.center(l).y - 1.45
			_put("world4/lava_field", xf, 12.0)
			l += 40.0
		var rs: float = (lava.x + lava.y) * 0.5
		_put(
			"world4/research_station", _at(rs, track.width(rs) * 0.5 + 17.0, -PI * 0.5, true), 14.0
		)
	# The smoking cinder cone, far ahead-right (camera far 1300 m).
	var y: float = track.center(track.length * 0.5).y - 60.0
	_backdrop("world4/crater_cone", 1100.0, -0.6, y, 1.0)


# ---------------------------------------------------------------- world 5


func _w5() -> void:
	var sp: Vector2 = track.zone("split")
	if sp.x >= 0.0 and track.split.size() >= 4:
		var mid: float = (sp.x + sp.y) * 0.5
		var xa: float = float(track.split[2])
		var xb: float = float(track.split[3])
		var hw: float = track.width(mid) * 0.5
		var lane_x: float = (-hw + xa) * 0.5 if xa < 0.0 else (hw + xb) * 0.5
		_put("world5/rope_bridge", _at(mid - 18.0, lane_x), 0.0)
		var t: float = sp.x + 20.0
		while t < sp.y - 15.0:
			var isl: Vector2 = track.island(t)
			var c: float = (isl.x + isl.y) * 0.5
			var p: Vector3 = gen.ground_at(t, c)
			var k: float = gen.rng().randf_range(0.5, 0.9)
			gen.put(
				"st_rock_b",
				300.0,
				t,
				gen.yaw_xf(p, gen.rng().randf() * TAU, Vector3(k, k * 0.7, k))
			)
			t += 9.0
	if track.gap.x >= 0.0:
		var lip: float = track.zone_at("lip", track.gap.x - 2.0)
		var wf: Transform3D = _at(lip, 0.0)
		_put("world5/waterfall_rock", wf, 18.0)
		_put("world5/waterfall_water", wf, 0.0)
		var pool: Transform3D = wf
		pool.basis = pool.basis.scaled(Vector3(1.0, 1.0, 0.78))
		_put("world5/pool_water", pool, 0.0)
	for i: int in 3:
		var rs: float = track.length * (0.2 + 0.3 * float(i))
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var lat: float = side * (track.width(rs) * 0.5 + 13.0 + float(i) * 3.0)
		if gen.free_spot(rs, lat) and not track.in_gap(rs):
			_put("world5/stone_ruin", _at(rs, lat, -PI * 0.5 * side, true), 9.0)


# ---------------------------------------------------------------- world 6


func _w6() -> void:
	var lip: float = track.zone_at("lip", -1.0)
	if track.gap.x >= 0.0 and lip > 0.0:
		var st: Transform3D = _at(lip - 31.2, 0.0)
		st.origin.y = track.center(lip - 31.2).y - maxf(0.0, track.lift_at(lip - 31.2))
		_put("world6/crane_jump_stack", st, 12.0)
		var mid: float = (track.gap.x + track.gap.y) * 0.5
		var cr: Transform3D = _at(mid, 0.0)
		cr.origin.y = track.center(lip).y - track.lift_at(lip)
		cr.basis = cr.basis.scaled(Vector3.ONE * 0.72)
		_put("world6/gantry_crane", cr, 14.0)
	var quay: float = float(track.flavor.get("quay", 15.0))
	var y: float = track.center(track.length * 0.5).y - 3.0
	var fs: float = track.length * 0.45
	var ferry: Transform3D = _at(fs, -(quay + 170.0), PI * 0.5)
	ferry.origin.y = y
	_put("world6/ferry", ferry, 0.0)
	var m: Array = _middle()
	var c: Vector3 = m[0]
	var heading: float = float(m[1]) + PI * 0.5
	var dir := Vector3(-sin(heading), 0.0, -cos(heading))
	var bp: Vector3 = c + dir * 950.0
	bp.y = y
	_put("world6/lit_bridge_far", Transform3D(Basis(Vector3.UP, heading + PI * 0.5), bp), 0.0)
