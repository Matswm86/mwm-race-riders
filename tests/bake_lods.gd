extends SceneTree

## Writes low-poly rival meshes (assets/generated/<model>_lod.res) for the
## skinned rider and bike: Godot's automatic mesh LODs do not switch on
## skinned meshes, so RrRiderView swaps to these by distance (QA 2026-10-06
## perf fix 2). Same vertices, bones and UVs; a decimated index list made
## with the importer's LOD generator (needs the editor build, so this runs
## at dev time, not on the phone):
##   godot --headless --audio-driver Dummy -s tests/bake_lods.gd

const TARGET: float = 0.3  # keep about this share of the triangles


func _init() -> void:
	var ok: bool = true
	for model: String in ["rider", "bike"]:
		var root: Node = (load("res://assets/models/%s.glb" % model) as PackedScene).instantiate()
		var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
		var src: Mesh = mi.mesh
		var arr: Array = src.surface_get_arrays(0)
		var full: int = (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, src.surface_get_material(0))
		im.generate_lods(25.0, 60.0, [])
		var best: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for l: int in im.get_surface_lod_count(0):
			var idx: PackedInt32Array = im.get_surface_lod_indices(0, l)
			if absf(float(idx.size()) / full - TARGET) < absf(float(best.size()) / full - TARGET):
				best = idx
		arr[Mesh.ARRAY_INDEX] = best
		var flags: int = src.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		var out := ArrayMesh.new()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
		out.surface_set_material(0, src.surface_get_material(0))
		var path: String = "res://assets/generated/%s_lod.res" % model
		var err: Error = ResourceSaver.save(out, path, ResourceSaver.FLAG_COMPRESS)
		ok = ok and err == OK
		print("%s: %d -> %d tris, %s" % [model, full / 3, best.size() / 3, error_string(err)])
		root.free()
	quit(0 if ok else 1)
