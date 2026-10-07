extends SceneTree

## Dev check for the world art (DESIGN 11, 16): every GLB under
## assets/models/world1..6 with its AABB, triangle count, material names and
## whether RrMats finds the loose albedo for each material. Exits 1 when a
## material has no albedo. Optional user args: model names to also print the
## height profile along -Z (track direction) for, e.g. world6/crane_jump_stack.
##   godot --headless --audio-driver Dummy -s tests/glb_report.gd [-- world6/crane_jump_stack]


func _init() -> void:
	var ok: bool = true
	for w: int in range(1, 7):
		var dir: String = "res://assets/models/world%d/" % w
		for f: String in DirAccess.get_files_at(dir):
			if not f.ends_with(".glb"):
				continue
			var name: String = "world%d/%s" % [w, f.get_basename()]
			var root: Node = (load(dir + f) as PackedScene).instantiate()
			var tris: int = 0
			var mats: PackedStringArray = []
			var box := AABB()
			var first: bool = true
			for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
				var m: Mesh = (mi as MeshInstance3D).mesh
				for si: int in m.get_surface_count():
					var arr: Array = m.surface_get_arrays(si)
					var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
					tris += idx.size() / 3
					var mat: Material = m.surface_get_material(si)
					var mn: String = mat.resource_name if mat != null else "?"
					if not mn in mats:
						mats.append(mn)
				var bb: AABB = (mi as MeshInstance3D).transform * m.get_aabb()
				box = bb if first else box.merge(bb)
				first = false
			var miss: PackedStringArray = []
			for mn: String in mats:
				if RrMats.find(mn + "_albedo") == "":
					miss.append(mn)
			ok = ok and miss.is_empty()
			print(
				(
					"%-32s tris %5d size %s pos %s mats %s%s"
					% [
						name,
						tris,
						box.size.snapped(Vector3.ONE * 0.1),
						box.position.snapped(Vector3.ONE * 0.1),
						mats,
						"" if miss.is_empty() else "  MISSING albedo " + str(miss)
					]
				)
			)
			root.free()
	for name: String in OS.get_cmdline_user_args():
		_profile(name)
	quit(0 if ok else 1)


## Highest vertex every metre along -Z inside |x| < 2 m.
func _profile(name: String) -> void:
	var root: Node = (load("res://assets/models/%s.glb" % name) as PackedScene).instantiate()
	var top: Dictionary = {}
	for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		var xf: Transform3D = (mi as MeshInstance3D).transform
		for si: int in m.get_surface_count():
			var v: PackedVector3Array = m.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for p: Vector3 in v:
				var q: Vector3 = xf * p
				if absf(q.x) > 2.0:
					continue
				var k: int = int(roundf(-q.z))
				top[k] = maxf(float(top.get(k, -99.0)), q.y)
	var ks: Array = top.keys()
	ks.sort()
	var line: PackedStringArray = []
	for k: int in ks:
		line.append("%d:%.2f" % [k, top[k]])
	print("PROFILE %s (along -Z m: top y) %s" % [name, " ".join(line)])
	root.free()
