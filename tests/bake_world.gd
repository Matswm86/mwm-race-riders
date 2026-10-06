extends SceneTree

## Writes assets/generated/track1_world.res (see RrWorldBake). Run after any
## change to RrWorldGen or the RrTrack geometry, and bump RrWorldBake.VERSION:
##   godot --headless --audio-driver Dummy -s tests/bake_world.gd


func _init() -> void:
	var t0: int = Time.get_ticks_msec()
	var err: Error = RrWorldBake.bake(RrWorld.BAKED_PATH)
	print(
		(
			"bake %s -> %s in %d ms"
			% [RrWorld.BAKED_PATH, error_string(err), Time.get_ticks_msec() - t0]
		)
	)
	quit(0 if err == OK else 1)
