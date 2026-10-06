extends SceneTree

## Writes assets/generated/<track>.res for every built base track (see
## RrWorldBake; Pro tracks reuse their base bake mirrored). Run after any
## change to RrWorldGen or a track's data, and bump RrWorldBake.VERSION:
##   godot --headless --audio-driver Dummy -s tests/bake_world.gd [w1_t3 ...]


func _init() -> void:
	var ok: bool = true
	var keys: Array[String] = RrTracks.all_keys(false)
	var only: PackedStringArray = OS.get_cmdline_user_args()
	for k: String in keys:
		if not only.is_empty() and not k in only:
			continue
		var t0: int = Time.get_ticks_msec()
		var err: Error = RrWorldBake.bake(k)
		ok = ok and err == OK
		var size: int = FileAccess.get_file_as_bytes(RrWorldBake.path_for(k)).size()
		print(
			(
				"bake %s -> %s in %d ms, %d KB"
				% [
					RrWorldBake.path_for(k),
					error_string(err),
					Time.get_ticks_msec() - t0,
					size / 1024
				]
			)
		)
	quit(0 if ok else 1)
