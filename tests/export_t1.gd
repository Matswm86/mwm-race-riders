extends SceneTree

## Writes tracks/w<w>_t1.json from the hand-made tables in RrWorlds.gd, so
## tools/track_gen.py can build track 1's Pro variant from the same numbers.
## The game itself reads track 1 from RrWorlds:
##   godot --headless --audio-driver Dummy -s tests/export_t1.gd

const KEYS: Array[String] = [
	"id",
	"length",
	"sections",
	"widths",
	"kid_line",
	"pads",
	"kickers",
	"kicker_air",
	"kicker_models",
	"blocks",
	"patches",
	"rollers",
	"gates",
	"bends",
	"grades",
	"drops",
	"gap",
	"tunnel",
	"fence",
	"river",
	"zones"
]


func _init() -> void:
	for w: int in range(1, RrBalance.WORLDS_BUILT + 1):
		if not RrWorlds.has_table(w):
			continue
		var d: Dictionary = RrTracks.get_def(RrTracks.key(w, 1))
		var out: Dictionary = {"key": RrTracks.key(w, 1), "track": 1, "pro": false}
		out["s_max"] = d["s_max"]
		out["mirrored"] = false
		out["look"] = "day"
		for k: String in KEYS:
			out[k] = d.get(k, [])
		var lines: PackedStringArray = ["{"]
		var ks: Array = out.keys()
		for i: int in ks.size():
			var sep: String = "," if i < ks.size() - 1 else ""
			lines.append("  %s: %s%s" % [JSON.stringify(ks[i]), JSON.stringify(out[ks[i]]), sep])
		lines.append("}")
		DirAccess.make_dir_recursive_absolute("res://tracks")
		var f := FileAccess.open("res://tracks/w%d_t1.json" % w, FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
		f.close()
		print("wrote tracks/w%d_t1.json" % w)
	quit(0)
