class_name RrMeshBuilder
extends RefCounted

## Flat-shaded mesh assembly on the one palette (DESIGN 7a): every triangle
## gets its own normal and the UV of one palette cell centre, so the whole
## static world shares one material and each chunk is one draw call.

## Palette cells (col, row), DESIGN 2.
const CELLS: Dictionary = {
	"grass": Vector2i(0, 0),
	"grass_dark": Vector2i(1, 0),
	"meadow": Vector2i(2, 0),
	"hill_far": Vector2i(3, 0),
	"mountain": Vector2i(4, 0),
	"snow": Vector2i(5, 0),
	"flower": Vector2i(6, 0),
	"petal": Vector2i(7, 0),
	"dirt": Vector2i(0, 1),
	"dirt_dark": Vector2i(1, 1),
	"curb": Vector2i(2, 1),
	"lane": Vector2i(3, 1),
	"lane_dark": Vector2i(4, 1),
	"lane_stripe": Vector2i(5, 1),
	"rock": Vector2i(6, 1),
	"rock_dark": Vector2i(7, 1),
	"trunk": Vector2i(0, 2),
	"leaf": Vector2i(1, 2),
	"cloud": Vector2i(6, 2),
	"cloud_shade": Vector2i(7, 2),
	"tangerine": Vector2i(0, 3),
	"wood": Vector2i(1, 3),
	"cream": Vector2i(2, 3),
	"sun": Vector2i(3, 3),
	"sky": Vector2i(4, 3),
	"white": Vector2i(5, 3),
	"ink": Vector2i(6, 3),
	"dark": Vector2i(1, 4),
	"dirt_mid": Vector2i(0, 5),
	"pebble": Vector2i(1, 5),
	"g_cyan": Vector2i(2, 6),
}

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var uvs := PackedVector2Array()


static func uv(cell: String) -> Vector2:
	var c: Vector2i = CELLS[cell]
	return Vector2((float(c.x) + 0.5) / 8.0, (float(c.y) + 0.5) / 8.0)


func tri_count() -> int:
	return verts.size() / 3


## a -> b -> c clockwise seen from the front face (Godot's front winding).
func tri(a: Vector3, b: Vector3, c: Vector3, cell: String) -> void:
	var n: Vector3 = (c - a).cross(b - a).normalized()
	var u: Vector2 = uv(cell)
	verts.append(a)
	verts.append(b)
	verts.append(c)
	for i: int in 3:
		normals.append(n)
		uvs.append(u)


## Quad a-b-c-d in order around its front face.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, cell: String) -> void:
	tri(a, b, c, cell)
	tri(a, c, d, cell)


## Triangle turned so its front faces `out` (any winding in).
func tri_out(a: Vector3, b: Vector3, c: Vector3, cell: String, out: Vector3) -> void:
	if (c - a).cross(b - a).dot(out) < 0.0:
		tri(a, c, b, cell)
	else:
		tri(a, b, c, cell)


func quad_out(a: Vector3, b: Vector3, c: Vector3, d: Vector3, cell: String, out: Vector3) -> void:
	tri_out(a, b, c, cell, out)
	tri_out(a, c, d, cell, out)


## Copy mesh arrays (from an imported GLB surface) through a transform.
func add_arrays(arr: Array, xf: Transform3D) -> void:
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var tuv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var nb: Basis = xf.basis.inverse().transposed()
	if idx.is_empty():
		for i: int in v.size():
			verts.append(xf * v[i])
			normals.append((nb * nn[i]).normalized())
			uvs.append(tuv[i])
		return
	for i: int in idx:
		verts.append(xf * v[i])
		normals.append((nb * nn[i]).normalized())
		uvs.append(tuv[i])


## Box from its 8 corners: centre, half extents, basis.
func box(c: Vector3, half: Vector3, b: Basis, cell: String) -> void:
	var p: Array[Vector3] = []
	for k: int in 8:
		var o := Vector3(
			half.x if k & 1 else -half.x, half.y if k & 2 else -half.y, half.z if k & 4 else -half.z
		)
		p.append(c + b * o)
	# faces: -x, +x, -y, +y, -z, +z
	quad_out(p[0], p[4], p[6], p[2], cell, b.x * -1.0)
	quad_out(p[1], p[3], p[7], p[5], cell, b.x)
	quad_out(p[0], p[1], p[5], p[4], cell, b.y * -1.0)
	quad_out(p[2], p[6], p[7], p[3], cell, b.y)
	quad_out(p[0], p[2], p[3], p[1], cell, b.z * -1.0)
	quad_out(p[4], p[5], p[7], p[6], cell, b.z)


## Low-poly ball (icosahedron, optional one subdivision) for clouds and pebbles.
func ico(c: Vector3, r: Vector3, cell: String, subdiv: int, cell_low: String = "") -> void:
	var t: float = (1.0 + sqrt(5.0)) / 2.0
	var base: Array[Vector3] = [
		Vector3(-1, t, 0),
		Vector3(1, t, 0),
		Vector3(-1, -t, 0),
		Vector3(1, -t, 0),
		Vector3(0, -1, t),
		Vector3(0, 1, t),
		Vector3(0, -1, -t),
		Vector3(0, 1, -t),
		Vector3(t, 0, -1),
		Vector3(t, 0, 1),
		Vector3(-t, 0, -1),
		Vector3(-t, 0, 1),
	]
	var faces: Array[Vector3i] = [
		Vector3i(0, 11, 5),
		Vector3i(0, 5, 1),
		Vector3i(0, 1, 7),
		Vector3i(0, 7, 10),
		Vector3i(0, 10, 11),
		Vector3i(1, 5, 9),
		Vector3i(5, 11, 4),
		Vector3i(11, 10, 2),
		Vector3i(10, 7, 6),
		Vector3i(7, 1, 8),
		Vector3i(3, 9, 4),
		Vector3i(3, 4, 2),
		Vector3i(3, 2, 6),
		Vector3i(3, 6, 8),
		Vector3i(3, 8, 9),
		Vector3i(4, 9, 5),
		Vector3i(2, 4, 11),
		Vector3i(6, 2, 10),
		Vector3i(8, 6, 7),
		Vector3i(9, 8, 1),
	]
	var tris: Array = []
	for f: Vector3i in faces:
		tris.append([base[f.x].normalized(), base[f.y].normalized(), base[f.z].normalized()])
	for _s: int in subdiv:
		var nxt: Array = []
		for tr: Array in tris:
			var a: Vector3 = tr[0]
			var b: Vector3 = tr[1]
			var cc: Vector3 = tr[2]
			var ab: Vector3 = ((a + b) * 0.5).normalized()
			var bc: Vector3 = ((b + cc) * 0.5).normalized()
			var ca: Vector3 = ((cc + a) * 0.5).normalized()
			nxt.append([a, ab, ca])
			nxt.append([b, bc, ab])
			nxt.append([cc, ca, bc])
			nxt.append([ab, bc, ca])
		tris = nxt
	for tr: Array in tris:
		var a2: Vector3 = c + (tr[0] as Vector3) * r
		var b2: Vector3 = c + (tr[1] as Vector3) * r
		var c2: Vector3 = c + (tr[2] as Vector3) * r
		var col: String = cell
		if cell_low != "" and (a2.y + b2.y + c2.y) / 3.0 < c.y - r.y * 0.25:
			col = cell_low
		tri_out(a2, b2, c2, col, (a2 + b2 + c2) / 3.0 - c)


## Tube along a polyline (curbs, rails), `sides` facets.
func tube(pts: PackedVector3Array, radius: float, sides: int, cell: String) -> void:
	if pts.size() < 2:
		return
	var rings: Array = []
	for i: int in pts.size():
		var d: Vector3
		if i == 0:
			d = pts[1] - pts[0]
		elif i == pts.size() - 1:
			d = pts[i] - pts[i - 1]
		else:
			d = pts[i + 1] - pts[i - 1]
		d = d.normalized()
		var side: Vector3 = d.cross(Vector3.UP).normalized()
		var up: Vector3 = side.cross(d).normalized()
		var ring: Array[Vector3] = []
		for k: int in sides:
			var a: float = TAU * float(k) / float(sides)
			ring.append(pts[i] + (side * cos(a) + up * sin(a)) * radius)
		rings.append(ring)
	for i: int in pts.size() - 1:
		var r0: Array[Vector3] = rings[i]
		var r1: Array[Vector3] = rings[i + 1]
		for k: int in sides:
			var k2: int = (k + 1) % sides
			var mid: Vector3 = (r0[k] + r1[k2]) * 0.5 - (pts[i] + pts[i + 1]) * 0.5
			quad_out(r0[k], r1[k], r1[k2], r0[k2], cell, mid)


func commit(mesh: ArrayMesh = null) -> ArrayMesh:
	var m: ArrayMesh = mesh if mesh != null else ArrayMesh.new()
	if verts.is_empty():
		return m
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uvs
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
