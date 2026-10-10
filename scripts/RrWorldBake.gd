class_name RrWorldBake
extends RefCounted

## Pre-built static ground and prop transforms per base track (the tablet
## would spend seconds in RrWorldGen at every launch). tests/bake_world.gd
## writes them; RrWorld uses a bake only when VERSION matches, else it builds
## at runtime. Pro tracks reuse their base track's bake, mirrored in X.
## Bump VERSION with every change to RrWorldGen or a track's data.

const VERSION: int = 18
const PATH := "res://assets/generated/%s.res"


## Bake file of a track key (Pro keys share the base track's file).
static func path_for(key: String) -> String:
	return PATH % RrTracks.base_key(key)


static func bake(key: String) -> Error:
	var base: String = RrTracks.base_key(key)
	var gen := RrWorldGen.new()
	gen.build(RrTrack.new(base))
	var res := Resource.new()
	res.set_meta(&"version", VERSION)
	var data: Dictionary = gen.result()
	for e: Array in data["ground"]:
		e[0] = RrWorldBake.with_lods(e[0])
	res.set_meta(&"world", data)
	var path: String = path_for(base)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return ResourceSaver.save(res, path, ResourceSaver.FLAG_COMPRESS)


## The mesh with automatic LODs (needs the editor build: bake time only).
## Far ground then drops detail by itself, more on Lav (RrWorld raises the
## viewport's mesh LOD threshold there).
static func with_lods(m: ArrayMesh) -> ArrayMesh:
	var im := ImporterMesh.new()
	for i: int in m.get_surface_count():
		im.add_surface(
			Mesh.PRIMITIVE_TRIANGLES, m.surface_get_arrays(i), [], {}, m.surface_get_material(i)
		)
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()
