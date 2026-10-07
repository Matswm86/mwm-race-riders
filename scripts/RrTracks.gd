class_name RrTracks
extends RefCounted

## Track registry (GDD 17.1): 8 tracks per world plus a Pro variant of each.
## Keys are "w<world>_t<k>" and "w<world>_t<k>p" (Pro). Track 1 of a world
## is the hand-made table in RrWorlds for worlds 1-2; every other track
## (worlds 3-6 track 1 too) and every Pro variant is
## data written offline by tools/track_gen.py into res://tracks/*.json (the
## game never generates a track). Par times come from tests/par_times.gd
## (tracks/par.json). Only built worlds (RrBalance.WORLDS_BUILT) have tracks.

const DIR := "res://tracks/"
const PAR_PATH := "res://tracks/par.json"

static var _defs: Dictionary = {}
static var _par: Dictionary = {}
static var _par_loaded: bool = false


static func key(w: int, k: int, pro: bool = false) -> String:
	return "w%d_t%d%s" % [w, k, "p" if pro else ""]


static func world_of(k: String) -> int:
	return int(k.get_slice("_", 0).trim_prefix("w"))


static func number_of(k: String) -> int:
	return int(k.get_slice("_", 1).trim_prefix("t").trim_suffix("p"))


static func is_pro(k: String) -> bool:
	return k.ends_with("p")


static func base_key(k: String) -> String:
	return k.trim_suffix("p")


## Every built track: base tracks first (world by world), then Pro.
static func all_keys(pro_too: bool = true) -> Array[String]:
	var out: Array[String] = []
	for pro: bool in [false, true]:
		if pro and not pro_too:
			break
		for w: int in range(1, RrBalance.WORLDS_BUILT + 1):
			for k: int in range(1, RrBalance.TRACKS_PER_WORLD + 1):
				out.append(key(w, k, pro))
	return out


static func exists(k: String) -> bool:
	var w: int = world_of(k)
	var n: int = number_of(k)
	if w < 1 or w > RrBalance.WORLDS_BUILT or n < 1 or n > RrBalance.TRACKS_PER_WORLD:
		return false
	if n == 1 and not is_pro(k) and RrWorlds.has_table(w):
		return true
	return FileAccess.file_exists(DIR + k + ".json")


## The track's tables in the RrWorlds format plus key, track, pro, mirrored,
## s_max, zones, flavor and the resolved look dictionary.
static func get_def(k: String) -> Dictionary:
	if _defs.has(k):
		return _defs[k]
	var w: int = world_of(k)
	var d: Dictionary
	if number_of(k) == 1 and not is_pro(k) and RrWorlds.has_table(w):
		d = RrWorlds.get_def(w).duplicate(true)
		d["track"] = 1
		d["pro"] = false
		d["mirrored"] = false
		d["s_max"] = maxf(1580.0, float(d["length"]) + 155.0)
		d["flavor"] = {}
		if not d.has("zones"):
			d["zones"] = {}
	else:
		var path: String = DIR + k + ".json"
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			push_error("RrTracks: cannot read %s, using world 1 track 1" % path)
			return get_def(key(1, 1))
		d = parsed
		d["id"] = w
		d["track"] = number_of(k)
	d["key"] = k
	d["look"] = RrWorlds.look_for(w, bool(d.get("pro", false)))
	d["name"] = String(RrWorlds.get_def(w)["name"])
	d["name_en"] = String(RrWorlds.get_def(w)["name_en"])
	_defs[k] = d
	return d


## Skilled-bot finish time (GDD 17.3 par), or a length-based estimate.
static func par(k: String) -> float:
	if not _par_loaded:
		_par_loaded = true
		if FileAccess.file_exists(PAR_PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PAR_PATH))
			if parsed is Dictionary:
				_par = parsed
	if _par.has(k):
		return float(_par[k])
	return float(get_def(k)["length"]) / 34.0


## Medal times: gold, silver, bronze (GDD 17.3: par x 1.01 / 1.04 / 1.08).
static func medal_times(k: String) -> Array[float]:
	var p: float = par(k)
	var out: Array[float] = []
	for m: float in RrBalance.MEDAL_PAR_MULT:
		out.append(snappedf(p * m, 0.1))
	return out


## 1 gold, 2 silver, 3 bronze, 0 none for a time on track k.
static func medal_for(k: String, time_s: float) -> int:
	if time_s <= 0.0:
		return 0
	var m: Array[float] = medal_times(k)
	for i: int in m.size():
		if time_s <= m[i]:
			return i + 1
	return 0


## Shell / signal id: world x 10 + track, +100 for Pro (w1_t3 = 13).
static func numeric_id(k: String) -> int:
	return world_of(k) * 10 + number_of(k) + (100 if is_pro(k) else 0)
