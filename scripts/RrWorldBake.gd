class_name RrWorldBake
extends RefCounted

## Pre-built static ground and prop transforms per base track (the tablet
## would spend seconds in RrWorldGen at every launch). tests/bake_world.gd
## writes them; RrWorld uses a bake only when VERSION matches, else it builds
## at runtime. Pro tracks reuse their base track's bake, mirrored in X.
## Bump VERSION with every change to RrWorldGen or a track's data.

const VERSION: int = 16
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
	res.set_meta(&"world", gen.result())
	var path: String = path_for(base)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return ResourceSaver.save(res, path, ResourceSaver.FLAG_COMPRESS)
