extends SceneTree

## Writes tracks/par.json: the par time of every built track (GDD 17.3),
## measured in the real race sim, not the 1D pack sim: the median finish of
## the skilled bot (RrBot.skilled_steer: every pad, around every hindrance,
## boost the moment it is full) over 3 seeds, Vanlig rules, hoverboard on.
## Medal times are par x 1.01 / 1.04 / 1.08. Run after tools/track_gen.py:
##   godot --headless --audio-driver Dummy -s tests/par_times.gd

const SEEDS: Array[int] = [11, 12, 13]


func _init() -> void:
	var out: Dictionary = {}
	for key: String in RrTracks.all_keys(true):
		var times: Array[float] = []
		for sd: int in SEEDS:
			var race := RrRace.new()
			race.setup(RrTrack.new(key), false, true, sd)
			race.start_lights()
			var n: int = 0
			while race.phase != RrRace.Phase.DONE and n < 60 * 120:
				race.step(1.0 / 60.0, RrBot.skilled_steer(race), race.player.meter >= 1.0)
				race.events.clear()
				n += 1
			times.append(race.player.finish_time)
		times.sort()
		out[key] = snappedf(times[1], 0.01)
		print("%s par %.2f s %s" % [key, out[key], times])
	var f := FileAccess.open(RrTracks.PAR_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  ", true) + "\n")
	f.close()
	quit(0)
