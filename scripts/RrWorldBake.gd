class_name RrWorldBake
extends RefCounted

## Pre-built static ground and prop transforms per world (the tablet would
## spend seconds in RrWorldGen at every launch). tests/bake_world.gd writes
## them; RrWorld uses a bake only when VERSION matches, else it builds at
## runtime. Bump VERSION with every change to RrWorldGen or a world's track.

const VERSION: int = 8
const PATH := "res://assets/generated/world%d.res"


static func path_for(world_id: int) -> String:
	return PATH % world_id


static func bake(world_id: int) -> Error:
	var gen := RrWorldGen.new()
	gen.build(RrTrack.new(world_id))
	var res := Resource.new()
	res.set_meta(&"version", VERSION)
	res.set_meta(&"world", gen.result())
	var path: String = path_for(world_id)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return ResourceSaver.save(res, path, ResourceSaver.FLAG_COMPRESS)
