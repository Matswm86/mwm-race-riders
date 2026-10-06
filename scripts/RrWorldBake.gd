class_name RrWorldBake
extends RefCounted

## Pre-built static world for track 1 (the tablet would spend seconds in
## RrWorldGen at every launch). tests/bake_world.gd writes it; RrWorld uses it
## only when VERSION matches, else it builds at runtime. Bump VERSION with
## every change to RrWorldGen or RrTrack geometry.

const VERSION: int = 1


static func bake(path: String) -> Error:
	var gen := RrWorldGen.new()
	gen.build(RrTrack.new())
	var res := Resource.new()
	res.set_meta(&"version", VERSION)
	res.set_meta(&"chunks", gen.meshes())
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return ResourceSaver.save(res, path, ResourceSaver.FLAG_COMPRESS)
