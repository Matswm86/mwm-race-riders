extends SceneTree

## Writes assets/generated/world<N>.res for every built world (see
## RrWorldBake). Run after any change to RrWorldGen or a world's track, and
## bump RrWorldBake.VERSION:
##   godot --headless --audio-driver Dummy -s tests/bake_world.gd


func _init() -> void:
	var ok: bool = true
	for w: int in range(1, RrBalance.WORLDS_BUILT + 1):
		var t0: int = Time.get_ticks_msec()
		var err: Error = RrWorldBake.bake(w)
		ok = ok and err == OK
		print(
			(
				"bake %s -> %s in %d ms"
				% [RrWorldBake.path_for(w), error_string(err), Time.get_ticks_msec() - t0]
			)
		)
	quit(0 if ok else 1)
