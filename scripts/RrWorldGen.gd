class_name RrWorldGen
extends RefCounted

## Builds the static ground of one world (DESIGN 9-10) into chunk meshes and
## prop MultiMeshes, baked by tests/bake_world.gd so the phone never runs it.
## Ground: a track-aligned strip (dense across the trail edge and the canyon
## walls) plus a coarse far grid. Each vertex carries splat weights for the
## terrain shader in COLOR (R trail, G rock, B grass patch, A verge) and its
## lateral offset from the centre line in UV2.x. Lane sections (river road,
## old highway) get their own ribbon on top. Props are MultiMeshes per chunk
## and kind (DESIGN 9: MultiMesh per 100 m chunk, visibility ranges).

const SAMPLE_STEP: float = 2.0
const ROW_STEP: float = 2.0
const STRIP_CHUNK: float = 100.0
const FAR_STEP: float = 10.0
const FAR_CHUNK: float = 300.0
const FAR_PAD: float = 420.0
## Lateral offsets past the track edge for the strip, per world (m).
const OUT_W1: Array[float] = [0.25, 0.7, 1.3, 2.1, 3.2, 4.6, 6.5, 9.0, 12.0, 16.0, 21.0, 27.0, 34.0]
const OUT_W2: Array[float] = [
	0.25,
	0.7,
	1.3,
	2.1,
	3.2,
	4.6,
	6.0,
	7.6,
	9.2,
	10.8,
	12.4,
	14.0,
	15.6,
	17.2,
	18.8,
	20.4,
	22.0,
	23.8,
	25.8,
	28.0,
	31.0,
	35.0,
	40.0,
	44.0
]
const IN_LATS: Array[float] = [-1.0, -0.75, -0.45, -0.2, 0.0, 0.2, 0.45, 0.75, 1.0]

var track: RrTrack
var world: int = 1
## [ArrayMesh, centre, tri count, far grid?] per ground chunk.
var ground: Array = []
## [ArrayMesh, centre, tri count] per lane chunk.
var lanes: Array = []
## [ArrayMesh, centre] water (world 1 river).
var water: Array = []
## [kind, MultiMesh buffer (12 floats per instance), centre] per prop chunk and kind.
var props: Array = []
var build_ms: int = 0

var _sx := PackedFloat32Array()
var _sz := PackedFloat32Array()
var _ss := PackedFloat32Array()
var _noise := FastNoiseLite.new()
var _noise2 := FastNoiseLite.new()
var _patch := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _prop_buf: Dictionary = {}


func build(trk: RrTrack) -> void:
	var t0: int = Time.get_ticks_msec()
	track = trk
	world = trk.world_id
	_rng.seed = 11 + world * 7
	_noise.seed = 3 + world
	_noise.frequency = 0.012
	_noise2.seed = 9 + world
	_noise2.frequency = 0.05
	_patch.seed = 21 + world
	_patch.frequency = 0.035
	var s: float = RrTrack.S_MIN
	while s <= RrTrack.S_MAX:
		var c: Vector3 = track.center(s)
		_sx.append(c.x)
		_sz.append(c.z)
		_ss.append(s)
		s += SAMPLE_STEP
	_strip()
	_far()
	_lanes()
	if track.river.x >= 0.0:
		_river()
	_scenery()
	build_ms = Time.get_ticks_msec() - t0


func _outs() -> Array[float]:
	return OUT_W2 if world == 2 else OUT_W1


func strip_reach() -> float:
	var o: Array[float] = _outs()
	return o[o.size() - 1]


# ---------------------------------------------------------------- nearest


func _d2(i: int, x: float, z: float) -> float:
	var dx: float = _sx[i] - x
	var dz: float = _sz[i] - z
	return dx * dx + dz * dz


func _nearest_global(x: float, z: float) -> int:
	var best: float = INF
	var bi: int = 0
	for i: int in _sx.size():
		var d: float = _d2(i, x, z)
		if d < best:
			best = d
			bi = i
	return bi


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


## [s, lateral (+ = right)] of a world x/z, from a nearest sample.
func _probe(x: float, z: float, i: int) -> Vector2:
	var s: float = _ss[i]
	var c: Vector3 = track.center(s)
	var fwd: Vector3 = RrTrack.forward_flat(track.yaw(s))
	var off := Vector3(x - c.x, 0.0, z - c.z)
	# Slide s to the foot point so the lateral value is exact.
	s = clampf(s + off.dot(fwd), RrTrack.S_MIN, RrTrack.S_MAX)
	c = track.center(s)
	off = Vector3(x - c.x, 0.0, z - c.z)
	return Vector2(s, off.dot(RrTrack.right_of(track.yaw(s))))


static func _sm(a: float, b: float, x: float) -> float:
	var t: float = clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------- height


## Ground height at (s, lat) for world x/z (DESIGN 9 forest, 10 canyon).
func height(s: float, lat: float, x: float, z: float) -> float:
	if world == 2:
		return _height_w2(s, lat, x, z)
	return _height_w1(s, lat, x, z)


func _height_w1(s: float, lat: float, x: float, z: float) -> float:
	var th: float = track.center(s).y
	var hw: float = track.width(s) * 0.5
	var d: float = absf(lat)
	var off: float = maxf(0.0, d - hw)
	var hills: float = _noise.get_noise_2d(x, z) * 9.0 + _noise2.get_noise_2d(x, z) * 1.5
	var h: float = th - 0.04 + _sm(0.0, 5.0, off) * 0.35 + off * 0.10
	h += _sm(5.0, 40.0, off) * (hills + 4.0) + _sm(60.0, 170.0, off) * 22.0
	if d <= hw:
		h = th - 0.04
	if track.river.x >= 0.0 and s > track.river.x - 10.0 and s < track.river.y + 10.0:
		var along: float = _sm(track.river.x - 10.0, track.river.x + 6.0, s)
		along *= 1.0 - _sm(track.river.y - 6.0, track.river.y + 10.0, s)
		var k: float = (1.0 - _sm(4.5, 11.0, absf(lat - 17.0))) * along
		h = lerpf(h, th - 1.7, k)
	if track.in_tunnel(s - 6.0) or track.in_tunnel(s + 6.0):
		# Rock cut: steep walls close to the trail edge.
		var k2: float = _sm(track.tunnel.x - 10.0, track.tunnel.x, s)
		k2 *= 1.0 - _sm(track.tunnel.y, track.tunnel.y + 10.0, s)
		h += k2 * _sm(0.6, 3.5, off) * (7.0 + _noise2.get_noise_2d(x, z) * 2.0)
	return h


## Where the canyon wall starts (m from the centre line) on this side.
func _wall_at(s: float, left: bool) -> float:
	var hw: float = track.width(s) * 0.5
	var w: float = 15.0
	if s < 60.0:
		w = lerpf(13.0, 15.0, _sm(0.0, 60.0, s))
	if s > 214.0 and s < 302.0:
		w = lerpf(w, hw + 1.6, _sm(214.0, 226.0, s) * (1.0 - _sm(292.0, 302.0, s)))
	if s >= 620.0 and s < 900.0:
		w = lerpf(15.0, 19.0, _sm(620.0, 650.0, s))
	if s >= 900.0:
		w = lerpf(19.0, 24.0, _sm(900.0, 930.0, s))
	if s >= 300.0 and s < 620.0 and not left:
		w = 14.0
	return w


static func _strata(v: float) -> float:
	var step: float = 4.5
	var k: float = floorf(v / step)
	return step * k + step * _sm(0.5, 1.0, v / step - k)


func _height_w2(s: float, lat: float, x: float, z: float) -> float:
	var th: float = track.center(s).y
	var hw: float = track.width(s) * 0.5
	var d: float = absf(lat)
	var off: float = maxf(0.0, d - hw)
	var dune: float = _noise2.get_noise_2d(x, z) * 0.5 + _noise.get_noise_2d(x, z) * 1.2
	var h: float = th - 0.04 + _sm(0.0, 4.0, off) * (0.25 + dune * 0.4) + off * 0.02
	if d <= hw:
		h = th - 0.04
	var left: bool = lat < 0.0
	var wall: float = _wall_at(s, left) + _noise.get_noise_2d(x * 1.7, z * 1.7) * 2.5
	var q: float = d - wall
	if q > 0.0:
		var jitter: float = _noise2.get_noise_2d(x * 0.6, z * 0.6) * 1.5
		h = maxf(h, th + minf(_strata(q * 2.1 + jitter), 48.0 + dune * 4.0))
	if left and s > 240.0 and s < 650.0:
		# Old rim highway: the canyon drops away on the left behind a rail.
		# Long blends at both ends, so no cliff face stands across the view.
		var k: float = _sm(240.0, 330.0, s) * (1.0 - _sm(596.0, 650.0, s))
		var drop: float = -_sm(2.5, 16.0, off) * 42.0 + _sm(150.0, 210.0, d) * 60.0
		var hd: float = th - 0.04 + _sm(0.0, 4.0, off) * 0.25 if d <= hw + 2.5 else th + drop
		h = lerpf(h, hd + dune * 2.0 * _sm(2.0, 6.0, off), k)
	if track.gap.x >= 0.0:
		var g: float = _sm(track.gap.x - 1.0, track.gap.x + 1.5, s)
		g *= 1.0 - _sm(track.gap.y - 1.5, track.gap.y + 1.0, s)
		var floor_y: float = track.center(track.gap.x).y - 22.0 + dune * 2.0
		h = lerpf(h, minf(h, floor_y), g * (1.0 - _sm(30.0, 45.0, d)))
	return h


## Splat weights (R trail, G rock, B patch, A verge) at a strip vertex.
func _splat(s: float, lat: float, x: float, z: float, slope: float) -> Color:
	var hw: float = track.width(s) * 0.5
	var d: float = absf(lat)
	var edge: float = 0.9 + _noise2.get_noise_2d(x * 2.0, z * 2.0) * 0.6
	var trail: float = 1.0 - _sm(hw - 0.4, hw + edge, d)
	if track.is_smooth(s) or track.in_gap(s):
		trail = 0.0
	var rock: float = _sm(0.32, 0.62, slope)
	var patch: float = 0.0
	var verge: float = 0.0
	if world == 1:
		patch = _sm(0.12, 0.38, _patch.get_noise_2d(x, z)) * _sm(1.5, 4.0, d - hw)
		verge = _sm(hw - 0.3, hw + 0.4, d) * (1.0 - _sm(2.5 + edge * 2.0, 6.0 + edge * 2.0, d - hw))
	else:
		verge = _sm(hw - 0.2, hw + 0.6, d) * (1.0 - _sm(1.5, 5.0 + edge * 3.0, d - hw)) * 0.8
	return Color(trail, rock, patch, verge)


# ---------------------------------------------------------------- ground


func _strip() -> void:
	var outs: Array[float] = _outs()
	var lats: Array[float] = []
	for i: int in range(outs.size() - 1, -1, -1):
		lats.append(-(1.0 + 0.0) * 99.0 - outs[i])
	for v: float in IN_LATS:
		lats.append(v)
	for o: float in outs:
		lats.append(99.0 + o)
	var cols: int = lats.size()
	var rows: int = int((RrTrack.S_MAX - RrTrack.S_MIN) / ROW_STEP) + 1
	var pos := PackedVector3Array()
	var lat_v := PackedFloat32Array()
	var s_v := PackedFloat32Array()
	pos.resize(rows * cols)
	lat_v.resize(rows * cols)
	s_v.resize(rows * cols)
	for r: int in rows:
		var s: float = RrTrack.S_MIN + float(r) * ROW_STEP
		var hw: float = track.width(s) * 0.5
		for c: int in cols:
			var l: float = lats[c]
			var lat: float
			if l <= -99.0:
				lat = -hw - (-l - 99.0)
			elif l >= 99.0:
				lat = hw + (l - 99.0)
			else:
				lat = l * hw
			var p: Vector3 = track.world_point(s, lat)
			p.y = height(s, lat, p.x, p.z)
			if c == 0 or c == cols - 1:
				p.y -= 4.0  # skirt hides the seam to the far grid
			pos[r * cols + c] = p
			lat_v[r * cols + c] = lat
			s_v[r * cols + c] = s
	var nrm := PackedVector3Array()
	nrm.resize(rows * cols)
	for r: int in rows:
		for c: int in cols:
			var a: Vector3 = pos[mini(r + 1, rows - 1) * cols + c] - pos[maxi(r - 1, 0) * cols + c]
			var b: Vector3 = pos[r * cols + mini(c + 1, cols - 1)] - pos[r * cols + maxi(c - 1, 0)]
			var n: Vector3 = b.cross(a).normalized()
			if n.y < 0.0:
				n = -n
			nrm[r * cols + c] = n
	var per: int = int(STRIP_CHUNK / ROW_STEP)
	var r0: int = 0
	while r0 < rows - 1:
		var r1: int = mini(r0 + per, rows - 1)
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var cols_c := PackedColorArray()
		var uv2 := PackedVector2Array()
		var idx := PackedInt32Array()
		for r: int in range(r0, r1 + 1):
			for c: int in cols:
				var k: int = r * cols + c
				var p: Vector3 = pos[k]
				verts.append(p)
				norms.append(nrm[k])
				cols_c.append(_splat(s_v[k], lat_v[k], p.x, p.z, 1.0 - nrm[k].y))
				uv2.append(Vector2(lat_v[k], track.width(s_v[k]) * 0.5))
		for r: int in range(r1 - r0):
			for c: int in cols - 1:
				var a: int = r * cols + c
				var b: int = a + 1
				var d: int = a + cols
				var e: int = d + 1
				idx.append_array(PackedInt32Array([a, d, e, a, e, b]))
		var ctr: Vector3 = pos[((r0 + r1) / 2) * cols + cols / 2]
		ground.append([_commit(verts, norms, cols_c, uv2, idx, ctr), ctr, idx.size() / 3, false])
		r0 = r1


func _far() -> void:
	var b := Rect2(Vector2(_sx[0], _sz[0]), Vector2.ZERO)
	for i: int in _sx.size():
		b = b.expand(Vector2(_sx[i], _sz[i]))
	var area: Rect2 = b.grow(FAR_PAD)
	var nx: int = int(area.size.x / FAR_STEP) + 1
	var nz: int = int(area.size.y / FAR_STEP) + 1
	var hs := PackedFloat32Array()
	var cover := PackedByteArray()
	var spl := PackedColorArray()
	hs.resize(nx * nz)
	cover.resize(nx * nz)
	spl.resize(nx * nz)
	var reach: float = strip_reach()
	var guess: int = 0
	for j: int in nz:
		var z: float = area.position.y + float(j) * FAR_STEP
		for i: int in nx:
			var x: float = area.position.x + float(i) * FAR_STEP
			var idx: int = _nearest_from(x, z, guess)
			if i == 0 or i % 16 == 0:
				var g: int = _nearest_global(x, z)
				if _d2(g, x, z) < _d2(idx, x, z):
					idx = g
			guess = idx
			var pr: Vector2 = _probe(x, z, idx)
			var hw: float = track.width(pr.x) * 0.5
			var inside_s: bool = pr.x > RrTrack.S_MIN + 4.0 and pr.x < RrTrack.S_MAX - 4.0
			var covered: bool = inside_s and absf(pr.y) < hw + reach - 6.0
			cover[j * nx + i] = 1 if covered else 0
			hs[j * nx + i] = height(pr.x, pr.y, x, z) - 0.35
			spl[j * nx + i] = Color(0, 0, _sm(0.12, 0.38, _patch.get_noise_2d(x, z)) * 0.6, 0)
	var chunks: Dictionary = {}
	for j: int in nz - 1:
		for i: int in nx - 1:
			var k: int = j * nx + i
			if cover[k] + cover[k + 1] + cover[k + nx] + cover[k + nx + 1] == 4:
				continue
			var x0: float = area.position.x + float(i) * FAR_STEP
			var z0: float = area.position.y + float(j) * FAR_STEP
			var key := Vector2i(floori(x0 / FAR_CHUNK), floori(z0 / FAR_CHUNK))
			if not chunks.has(key):
				chunks[key] = []
			(chunks[key] as Array).append(k)
	for key: Vector2i in chunks:
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var cols_c := PackedColorArray()
		var uv2 := PackedVector2Array()
		var idx := PackedInt32Array()
		var remap: Dictionary = {}
		for k: int in chunks[key]:
			var corners: Array[int] = [k, k + 1, k + nx + 1, k + nx]
			var vi: Array[int] = []
			for q: int in corners:
				if not remap.has(q):
					remap[q] = verts.size()
					var gi: int = q % nx
					var gj: int = q / nx
					var p := Vector3(
						area.position.x + float(gi) * FAR_STEP,
						hs[q],
						area.position.y + float(gj) * FAR_STEP
					)
					verts.append(p)
					var hx: float = (
						hs[mini(gi + 1, nx - 1) + gj * nx] - hs[maxi(gi - 1, 0) + gj * nx]
					)
					var hz: float = (
						hs[gi + mini(gj + 1, nz - 1) * nx] - hs[gi + maxi(gj - 1, 0) * nx]
					)
					var n := Vector3(-hx, 2.0 * FAR_STEP, -hz).normalized()
					norms.append(n)
					var sc: Color = spl[q]
					sc.g = _sm(0.32, 0.62, 1.0 - n.y)
					cols_c.append(sc)
					uv2.append(Vector2(99.0, 1.0))
				vi.append(remap[q])
			idx.append_array(PackedInt32Array([vi[0], vi[1], vi[2], vi[0], vi[2], vi[3]]))
		var ctr := Vector3((float(key.x) + 0.5) * FAR_CHUNK, 0.0, (float(key.y) + 0.5) * FAR_CHUNK)
		var far_mesh: ArrayMesh = _commit(verts, norms, cols_c, uv2, idx, Vector3.ZERO)
		ground.append([far_mesh, ctr, idx.size() / 3, true])


func _commit(
	v: PackedVector3Array,
	n: PackedVector3Array,
	c: PackedColorArray,
	uv2: PackedVector2Array,
	idx: PackedInt32Array,
	_ctr: Vector3
) -> ArrayMesh:
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	if not c.is_empty():
		arr[Mesh.ARRAY_COLOR] = c
	if not uv2.is_empty():
		arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


# ---------------------------------------------------------------- lanes


## Smooth-surface ribbon (W1 gravel river road, W2 cracked asphalt), 0.6 m
## past the edge with a vertex-alpha fringe the lane shader dithers out.
func _lanes() -> void:
	var lats: Array[float] = [-1.06, -0.98, -0.6, -0.2, 0.0, 0.2, 0.6, 0.98, 1.06]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols_c := PackedColorArray()
	var uv := PackedVector2Array()
	var tans := PackedFloat32Array()
	var idx := PackedInt32Array()
	var s: float = RrTrack.S_MIN
	var started: bool = false
	var chunk_s: float = 0.0
	var prev_row: int = -1
	while s <= RrTrack.S_MAX:
		var smooth: bool = track.is_smooth(s) or track.is_smooth(s - ROW_STEP)
		if smooth:
			if not started:
				started = true
				chunk_s = s
				prev_row = -1
			var hw: float = track.width(s) * 0.5 + 0.35
			var row0: int = verts.size()
			var y: float = track.center(s).y + 0.03
			for l: float in lats:
				var p: Vector3 = track.world_point(s, l * hw)
				p.y = y
				verts.append(p)
				norms.append(track.frame(s).basis.y)
				var a: float = 1.0 - _sm(0.97, 1.06, absf(l))
				var end_fade: float = _sm(-1.0, 3.0, s - _lane_start(s))
				cols_c.append(Color(1, 1, 1, a * end_fade))
				uv.append(Vector2(l * hw, s))
				var rt: Vector3 = RrTrack.right_of(track.yaw(s))
				tans.append_array(PackedFloat32Array([rt.x, rt.y, rt.z, -1.0]))
			if prev_row >= 0:
				for c: int in lats.size() - 1:
					var a2: int = prev_row + c
					var d: int = row0 + c
					idx.append_array(PackedInt32Array([a2, d, d + 1, a2, d + 1, a2 + 1]))
			prev_row = row0
			if s - chunk_s >= STRIP_CHUNK:
				_flush_lane(verts, norms, cols_c, uv, tans, idx)
				verts = PackedVector3Array()
				norms = PackedVector3Array()
				cols_c = PackedColorArray()
				uv = PackedVector2Array()
				tans = PackedFloat32Array()
				idx = PackedInt32Array()
				chunk_s = s
				prev_row = -1
				continue  # re-emit this row as the first row of the next chunk
		elif started:
			_flush_lane(verts, norms, cols_c, uv, tans, idx)
			verts = PackedVector3Array()
			norms = PackedVector3Array()
			cols_c = PackedColorArray()
			uv = PackedVector2Array()
			tans = PackedFloat32Array()
			idx = PackedInt32Array()
			started = false
		s += ROW_STEP
	if started:
		_flush_lane(verts, norms, cols_c, uv, tans, idx)


func _lane_start(s: float) -> float:
	for row: Array in track.sections:
		if String(row[2]) == "lane" and s >= float(row[0]) - 4.0 and s < float(row[1]) + 4.0:
			return float(row[0])
	return s


func _flush_lane(
	v: PackedVector3Array,
	n: PackedVector3Array,
	c: PackedColorArray,
	uv: PackedVector2Array,
	tans: PackedFloat32Array,
	idx: PackedInt32Array
) -> void:
	if idx.is_empty():
		return
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TANGENT] = tans
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	lanes.append([m, v[v.size() / 2], idx.size() / 3])


func _river() -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var s: float = track.river.x - 8.0
	while s <= track.river.y + 8.0:
		var y: float = track.center(s).y - 1.2
		var row: int = verts.size()
		for lat: float in [10.0, 24.0]:
			var p: Vector3 = track.world_point(s, lat)
			p.y = y
			verts.append(p)
			norms.append(Vector3.UP)
		if row > 0:
			var a: int = row - 2
			idx.append_array(PackedInt32Array([a, row, row + 1, a, row + 1, a + 1]))
		s += 4.0
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	water.append([m, verts[verts.size() / 2]])


# ---------------------------------------------------------------- props


## Ground point at (s, lat) as a world position.
func ground_at(s: float, lat: float) -> Vector3:
	var p: Vector3 = track.world_point(s, lat)
	p.y = height(s, lat, p.x, p.z)
	return p


func _put(kind: String, chunk_m: float, s: float, xf: Transform3D) -> void:
	var key: String = "%s|%d" % [kind, floori(s / chunk_m)]
	if not _prop_buf.has(key):
		_prop_buf[key] = [kind, [], chunk_m]
	(_prop_buf[key][1] as Array).append(xf)


func _yaw_xf(p: Vector3, yaw: float, sc: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(sc), p)


func _free_spot(s: float, lat: float) -> bool:
	var hw: float = track.width(s) * 0.5
	if absf(lat) < hw + 0.2:
		return false
	if track.river.x >= 0.0 and s > track.river.x - 6.0 and s < track.river.y + 6.0:
		if absf(lat - 17.0) < 8.5:
			return false
	if world == 1 and absf(lat) < hw + 3.0:
		for g: Array in track.gates:
			if absf(s - float(g[0])) < 9.0:
				return false
		if absf(s - track.length) < 12.0 or absf(s) < 14.0:
			return false
	return true


func _scenery() -> void:
	if world == 2:
		_scenery_w2()
	else:
		_scenery_w1()
	# Transforms are baked as raw MultiMesh buffers (12 floats per instance):
	# a headless bake has no rendering server to keep MultiMesh data in.
	for key: String in _prop_buf:
		var e: Array = _prop_buf[key]
		var list: Array = e[1]
		var buf := PackedFloat32Array()
		buf.resize(list.size() * 12)
		var ctr := Vector3.ZERO
		for i: int in list.size():
			var xf: Transform3D = list[i]
			var b: Basis = xf.basis
			var o: Vector3 = xf.origin
			var row := PackedFloat32Array(
				[b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z]
			)
			for k: int in 12:
				buf[i * 12 + k] = row[k]
			ctr += o
		props.append([e[0], buf, ctr / float(maxi(1, list.size()))])
	_prop_buf.clear()


func _scenery_w1() -> void:
	var kinds: Array[String] = ["tree_pine_a", "tree_pine_b", "tree_pine_c"]
	# Pines: dense wall from 4 m off the trail edge, thinning with distance.
	var n: int = 0
	var tries: int = 0
	# GPU cost (cost probe): every pine is four alpha-tested cards, so the
	# forest is a dense wall near the trail and thin beyond 40 m; the HDRI
	# carries the far forest.
	while n < 1500 and tries < 60000:
		tries += 1
		var s: float = _rng.randf_range(-30.0, RrTrack.S_MAX - 6.0)
		var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
		var hw: float = track.width(s) * 0.5
		var off: float = 3.6 + pow(_rng.randf(), 1.6) * 46.0
		var lat: float = side * (hw + off)
		if not _free_spot(s, lat) or track.in_tunnel(s) and off < 9.0:
			continue
		var p: Vector3 = ground_at(s, lat)
		p.y -= 0.2
		var sc: float = _rng.randf_range(0.7, 1.2)
		var kind: String = kinds[_rng.randi() % 3]
		var chunk: float = 100.0 if off < 45.0 else 300.0
		_put(
			("near_" if off < 45.0 else "far_") + kind,
			chunk,
			s,
			_yaw_xf(p, _rng.randf() * TAU, Vector3.ONE * sc)
		)
		n += 1
	_edge_props(1)


func _scenery_w2() -> void:
	# Brush on the wash floor, fallen sandstone blocks at the wall foot.
	var n: int = 0
	var tries: int = 0
	while n < 420 and tries < 9000:
		tries += 1
		var s: float = _rng.randf_range(-30.0, RrTrack.S_MAX - 6.0)
		var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
		var hw: float = track.width(s) * 0.5
		var wall: float = _wall_at(s, side < 0.0)
		var lat: float = side * _rng.randf_range(hw + 0.8, maxf(hw + 1.5, wall - 1.0))
		if side < 0.0 and s > 304.0 and s < 616.0:
			continue
		if track.in_gap(s) or not _free_spot(s, lat):
			continue
		var p: Vector3 = ground_at(s, lat)
		var sc: float = _rng.randf_range(0.6, 1.3)
		_put("bush_desert", 100.0, s, _yaw_xf(p, _rng.randf() * TAU, Vector3.ONE * sc))
		n += 1
	n = 0
	tries = 0
	var rocks: Array[String] = ["rock_a", "rock_b", "rock_c"]
	while n < 260 and tries < 9000:
		tries += 1
		var s2: float = _rng.randf_range(-30.0, RrTrack.S_MAX - 6.0)
		var side2: float = -1.0 if _rng.randf() < 0.5 else 1.0
		if side2 < 0.0 and s2 > 304.0 and s2 < 616.0:
			continue
		if track.in_gap(s2):
			continue
		var wall2: float = _wall_at(s2, side2 < 0.0)
		var lat2: float = side2 * (wall2 + _rng.randf_range(-2.5, 1.5))
		if not _free_spot(s2, lat2) or absf(lat2) < track.width(s2) * 0.5 + 1.2:
			continue
		var p2: Vector3 = ground_at(s2, lat2)
		p2.y -= 0.3
		var sc2: float = _rng.randf_range(1.5, 3.5)
		var kind2: String = rocks[_rng.randi() % 3]
		var xf := _yaw_xf(
			p2, _rng.randf() * TAU, Vector3(sc2, sc2 * _rng.randf_range(0.7, 1.1), sc2)
		)
		_put("srock_" + kind2, 150.0, s2, xf)
		n += 1
	for k: int in 14:
		var s3: float = _rng.randf_range(20.0, RrTrack.S_MAX - 40.0)
		var side3: float = -1.0 if _rng.randf() < 0.5 else 1.0
		if track.in_gap(s3) or side3 < 0.0 and s3 > 304.0 and s3 < 616.0:
			continue
		var lat3: float = side3 * (track.width(s3) * 0.5 + _rng.randf_range(2.0, 7.0))
		var p3: Vector3 = ground_at(s3, lat3)
		_put("dead_trunk", 300.0, s3, _yaw_xf(p3, _rng.randf() * TAU, Vector3.ONE))
	_edge_props(2)


## Undergrowth, course tape and fences near the trail (DESIGN 9 / 10).
func _edge_props(w: int) -> void:
	var s: float = -14.0
	while s < RrTrack.S_MAX - 4.0:
		var hw: float = track.width(s) * 0.5
		var yaw: float = track.yaw(s)
		var smooth: bool = track.is_smooth(s)
		for side: float in [-1.0, 1.0]:
			if w == 1:
				var in_fence: bool = s >= track.fence.x and s < track.fence.y
				if in_fence and int(s) % 4 == 0:
					var fp: Vector3 = ground_at(s + 2.0, side * (hw + 0.55))
					_put(
						"fence_rail",
						100.0,
						s,
						_yaw_xf(fp, track.yaw(s + 2.0) + PI * 0.5, Vector3.ONE)
					)
				elif (
					not smooth
					and not track.in_tunnel(s)
					and int(s) % 4 == 0
					and s < track.length + 2.0
				):
					var tp: Vector3 = ground_at(s, side * (hw + 0.7))
					_put("tape_stake", 100.0, s, _yaw_xf(tp, track.yaw(s + 2.0), Vector3.ONE))
				# Grass cards along the verge, a few ferns and stones.
				for k: int in 2:
					var lat: float = side * (hw + _rng.randf_range(0.3, 6.0))
					var ss: float = s + _rng.randf() * 2.0
					if _free_spot(ss, lat):
						var gp: Vector3 = ground_at(ss, lat)
						var gs: float = _rng.randf_range(0.7, 1.3)
						_put(
							"grass_card",
							25.0,
							ss,
							_yaw_xf(
								gp,
								_rng.randf() * TAU,
								Vector3(gs, gs * _rng.randf_range(0.8, 1.2), gs)
							)
						)
				if _rng.randf() < 0.12:
					var fl: float = side * (hw + _rng.randf_range(1.5, 9.0))
					if _free_spot(s, fl):
						_put(
							"fern",
							25.0,
							s,
							_yaw_xf(
								ground_at(s, fl),
								_rng.randf() * TAU,
								Vector3.ONE * _rng.randf_range(0.8, 1.4)
							)
						)
				if _rng.randf() < 0.06:
					var rl: float = side * (hw + _rng.randf_range(1.0, 24.0))
					if _free_spot(s, rl):
						var rp: Vector3 = ground_at(s, rl)
						rp.y -= 0.15
						var rs: float = _rng.randf_range(0.35, 1.1)
						_put(
							["rock_a", "rock_b", "rock_c"][_rng.randi() % 3],
							100.0,
							s,
							_yaw_xf(rp, _rng.randf() * TAU, Vector3.ONE * rs)
						)
			else:
				if smooth and side < 0.0 and int(s) % 4 == 0 and s > 302.0 and s < 618.0:
					var rp2: Vector3 = ground_at(s + 2.0, side * (hw + 0.6))
					_put(
						"fence_rail",
						100.0,
						s,
						_yaw_xf(rp2, track.yaw(s + 2.0) + PI * 0.5, Vector3.ONE)
					)
				if _rng.randf() < 0.07:
					var sl: float = side * (hw + _rng.randf_range(0.6, 4.0))
					if _free_spot(s, sl) and not track.in_gap(s):
						var sp: Vector3 = ground_at(s, sl)
						sp.y -= 0.1
						var sr: float = _rng.randf_range(0.18, 0.45)
						_put(
							"srock_rock_c",
							150.0,
							s,
							_yaw_xf(sp, _rng.randf() * TAU, Vector3.ONE * sr)
						)
		s += 2.0
	if w == 1:
		# Rock cut: big boulders on both sides of the tunnel section.
		var t: float = track.tunnel.x - 6.0
		while t < track.tunnel.y + 6.0:
			for side2: float in [-1.0, 1.0]:
				var hw2: float = track.width(t) * 0.5
				var bp: Vector3 = ground_at(t, side2 * (hw2 + 2.2))
				var bs: float = _rng.randf_range(1.6, 2.6)
				_put(
					["rock_a", "rock_b"][_rng.randi() % 2],
					100.0,
					t,
					_yaw_xf(bp, _rng.randf() * TAU, Vector3(bs, bs * 1.5, bs))
				)
			t += 3.5


## Everything the bake stores.
func result() -> Dictionary:
	return {"ground": ground, "lanes": lanes, "water": water, "props": props}
