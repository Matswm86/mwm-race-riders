# gdlint: disable=max-public-methods
class_name RrState
extends Node

## Autoload "RaceRiders": save file, settings, progress and the public hooks
## a host app (MWM Play) calls (GDD 9.2, 12, 17.5). The stand-alone build
## never calls the hooks, so it keeps everything open (the owner's own copy):
## every built track and Pro variant can be free-ridden, and the league
## ladder climbs as far as its worlds exist.
##
## Hooks: set_full_unlock(on), set_difficulty(easy), set_shell_inset(inset),
## set_sfx_on / set_music_on / set_haptics_on / set_less_motion, save_game().
## Signals up: level_card_shown(track_id), free_levels_finished().
## track_id = world x 10 + track number, +100 for a Pro variant (RrTracks).
## full_unlock false (GDD 17.5) = the Bronze III season only (world 1 tracks
## 1-5); its season end sends free_levels_finished (once per app session)
## instead of promoting, and the season can be replayed forever.
## Progress is per track (best time, best place, ghost, medal); the ladder
## lives in an RrLeague. Saves from the two-world slice (version 1) migrate:
## world N's best run becomes track wN_t1's. Version 2 (the Bronze/Silver
## ladder) migrates to 3 (six leagues) keeping everything; a Silver winner
## moves on to Gold III (RrLeague.migrate_v2).

signal level_card_shown(track_id: int)
signal free_levels_finished
signal settings_changed

const SAVE_PATH := "user://race_riders_save.json"
const SAVE_VERSION := 3
const SHELL_META := &"mwm_play_shell"

var full_unlock: bool = true
var easy: bool = true
var shell_inset: Vector2 = Vector2.ZERO
var sfx_on: bool = true
var music_on: bool = true
## Volume sliders, 0..1 (linear).
var sfx_volume: float = RrBalance.SFX_VOL_DEFAULT / 100.0
var music_volume: float = RrBalance.MUSIC_VOL_DEFAULT / 100.0
var ghost_on: bool = RrBalance.GHOST_DEFAULT_ON
var haptics_on: bool = false
var less_motion: bool = false
## Graphics tier: true = Høy (shadows, glow, filmic, GPU particles, rim),
## false = Lav (DESIGN 7e phone budget). Auto: Lav on 32-bit ARM.
var quality_high: bool = not OS.has_feature("arm32")
## Set when the game dropped to Lav by itself (fps < 45 for 3 s).
var quality_auto_dropped: bool = false
var finishes: int = 0
var hover_unlocked: bool = false
var seen_first_swap: bool = false
## track key -> {best_time, best_place, won, ghost, medal}
var tracks: Dictionary = {}
var cosmetics: Dictionary = {"outfit": 1, "bike": 1, "board": 1, "owned": []}
var league := RrLeague.new()
## The full ladder while a host has locked the game (restored on unlock).
var parked_league: Dictionary = {}
## Unix time of the last save (rivals' form after 8 h away, GDD 17.2).
var last_seen: float = 0.0
## True when the last load gave the rivals a form (arrows on the table).
var form_shown: bool = false
## True when no save existed at start: the race starts by itself sooner.
var first_launch: bool = true
## The save was a version-1 (two-world) save, migrated at load.
var migrated_from: int = 0
var _free_card_sent: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


func in_shell() -> bool:
	return Engine.has_meta(SHELL_META) and bool(Engine.get_meta(SHELL_META))


# ---------------------------------------------------------------- hooks


func set_full_unlock(on: bool) -> void:
	if full_unlock == on:
		return
	full_unlock = on
	if not on and (league.league > 0 or league.tier > 0):
		# Locked: race the Bronze III season; park the full ladder.
		parked_league = league.to_dict()
		var seed_v: int = league.save_seed
		league = RrLeague.new()
		league.save_seed = seed_v
	elif on and not parked_league.is_empty():
		league = RrLeague.new()
		league.from_dict(parked_league)
		parked_league = {}
	settings_changed.emit()


func locked() -> bool:
	return not full_unlock


## "Nedrykk" (GDD 17.2): Vanlig soft demotion, default off.
func set_demotion(on: bool) -> void:
	league.demotion_on = on
	save_game()
	settings_changed.emit()


## Takes effect at the next race start (GDD 8).
func set_difficulty(is_easy: bool) -> void:
	if easy == is_easy:
		return
	easy = is_easy
	save_game()
	settings_changed.emit()


## The shell's home square. Nothing of the game sits there, so this only
## stores the value.
func set_shell_inset(inset: Vector2) -> void:
	shell_inset = inset


func set_sfx_on(on: bool) -> void:
	sfx_on = on
	save_game()
	settings_changed.emit()


func set_music_on(on: bool) -> void:
	music_on = on
	save_game()
	settings_changed.emit()


## Slider drags call this with save = false on every step and save once
## when the drag ends.
func set_sfx_volume(v: float, save: bool = true) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	if save:
		save_game()
	settings_changed.emit()


func set_music_volume(v: float, save: bool = true) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	if save:
		save_game()
	settings_changed.emit()


func set_ghost_on(on: bool) -> void:
	ghost_on = on
	save_game()
	settings_changed.emit()


func set_haptics_on(on: bool) -> void:
	haptics_on = on
	save_game()
	settings_changed.emit()


func set_quality_high(on: bool, auto: bool = false) -> void:
	quality_high = on
	quality_auto_dropped = auto and not on
	save_game()
	settings_changed.emit()


func set_less_motion(on: bool) -> void:
	less_motion = on
	save_game()
	settings_changed.emit()


# ---------------------------------------------------------------- progress


func track_data(key: String) -> Dictionary:
	return tracks.get(key, {})


## Ghost of this track only (GDD 10.8); empty until the track is finished.
func ghost_rows(key: String) -> Array:
	return track_data(key).get("ghost", [])


func best_time(key: String) -> float:
	return float(track_data(key).get("best_time", 0.0))


func finished_track(key: String) -> bool:
	return best_time(key) > 0.0


## Medal earned on a track: 1 gold, 2 silver, 3 bronze, 0 none.
func medal(key: String) -> int:
	return RrTracks.medal_for(key, best_time(key))


## Tracks the free ride offers (GDD 17.2): every built track and Pro variant
## in the stand-alone build; the Bronze III tracks when a host locks it.
func free_ride_tracks() -> Array[String]:
	var out: Array[String] = []
	if locked():
		for k: int in range(1, RrBalance.FREE_TRACKS_W1 + 1):
			out.append(RrTracks.key(1, k))
		return out
	for k: String in RrTracks.all_keys(true):
		if RrTracks.exists(k):
			out.append(k)
	return out


func can_ride(key: String) -> bool:
	return key in free_ride_tracks() or key == league.next_track()


## GDD 10.2: every launch goes straight into the next league race.
func launch_track() -> String:
	return league.next_track()


## Record a finish on a track (GDD 10.3, 17.3). Returns what the card needs:
## {first, new_best, prev_best, unlocked_hover, medal, new_medal}.
func record_finish(key: String, time_s: float, place: int, ghost: Array) -> Dictionary:
	var d: Dictionary = tracks.get(key, {})
	var prev: float = float(d.get("best_time", 0.0))
	var old_medal: int = RrTracks.medal_for(key, prev)
	var first: bool = prev <= 0.0
	var new_best: bool = first or time_s < prev
	if new_best:
		d["best_time"] = snappedf(time_s, 0.01)
		d["ghost"] = ghost
	d["best_place"] = mini(int(d.get("best_place", 9)), place)
	d["won"] = bool(d.get("won", false)) or place == 1
	var m: int = RrTracks.medal_for(key, float(d["best_time"]))
	d["medal"] = m
	tracks[key] = d
	finishes += 1
	first_launch = false
	var unlocked: bool = false
	if not hover_unlocked and finishes >= RrBalance.UNLOCK_HOVER:
		hover_unlocked = true
		unlocked = true
	save_game()
	return {
		"first": first,
		"new_best": new_best,
		"prev_best": prev,
		"unlocked_hover": unlocked,
		"medal": m,
		"new_medal": m > 0 and (old_medal == 0 or m < old_medal),
	}


## A league round was raced (finish: rider index -> time; 0 = player).
func record_league_round(heat: Array[int], finish: Array[float]) -> Dictionary:
	var r: Dictionary = league.record_round(heat, finish, easy)
	save_game()
	return r


## Close the season (GDD 17.2 / 17.5). In the locked free part the shell
## gets free_levels_finished (at most once per app session) instead of a
## promotion.
func end_season() -> Dictionary:
	var r: Dictionary = league.end_season(easy, locked())
	for rw: String in league.rewards:
		if not rw in (cosmetics.get("owned", []) as Array):
			(cosmetics["owned"] as Array).append(rw)
	if locked() and not _free_card_sent:
		_free_card_sent = true
		r["free_card"] = true
		free_levels_finished.emit()
	save_game()
	return r


func mark_first_swap_seen() -> void:
	seen_first_swap = true
	save_game()


func save_game() -> void:
	last_seen = Time.get_unix_time_from_system()
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"finishes": finishes,
		"hover_unlocked": hover_unlocked,
		"seen_first_swap": seen_first_swap,
		"tracks": tracks,
		"league": league.to_dict(),
		"parked_league": parked_league,
		"cosmetics": cosmetics,
		"last_seen": last_seen,
		"difficulty": "lett" if easy else "vanlig",
		"settings":
		{
			"sfx_on": sfx_on,
			"sfx_volume": sfx_volume,
			"music_on": music_on,
			"music_volume": music_volume,
			"ghost": ghost_on,
			"haptics": haptics_on,
			"less_motion": less_motion,
			"quality": "hoy" if quality_high else "lav",
		},
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("RaceRiders: cannot write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data))
	f.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		first_launch = true
		_new_seed()
		return
	first_launch = false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary:
		push_warning("RaceRiders: save file unreadable, starting fresh")
		return
	var d: Dictionary = parsed
	finishes = maxi(0, int(d.get("finishes", 0)))
	hover_unlocked = bool(d.get("hover_unlocked", finishes >= RrBalance.UNLOCK_HOVER))
	seen_first_swap = bool(d.get("seen_first_swap", false))
	_load_progress(d)
	var c: Variant = d.get("cosmetics", {})
	if c is Dictionary:
		cosmetics = c
		if not cosmetics.get("owned", []) is Array:
			cosmetics["owned"] = []
	easy = String(d.get("difficulty", "lett")) != "vanlig"
	var s: Variant = d.get("settings", {})
	if s is Dictionary:
		var sd: Dictionary = s
		sfx_on = bool(sd.get("sfx_on", true))
		music_on = bool(sd.get("music_on", true))
		sfx_volume = clampf(float(sd.get("sfx_volume", sfx_volume)), 0.0, 1.0)
		music_volume = clampf(float(sd.get("music_volume", music_volume)), 0.0, 1.0)
		ghost_on = bool(sd.get("ghost", true))
		haptics_on = bool(sd.get("haptics", false))
		less_motion = bool(sd.get("less_motion", false))
		if sd.has("quality"):
			quality_high = String(sd["quality"]) == "hoy"
	# GDD 17.2: 8 h or more away gives the rivals a form for the next round.
	last_seen = float(d.get("last_seen", 0.0))
	if last_seen > 0.0:
		var hours: float = (Time.get_unix_time_from_system() - last_seen) / 3600.0
		form_shown = league.apply_away(hours, int(last_seen))


## Per-track progress and the ladder. Version 1 (the two-world slice) kept
## one record per world under "worlds" (the toy build: "tracks" = world ids);
## world N becomes track wN_t1, nothing is dropped.
func _load_progress(d: Dictionary) -> void:
	var version: int = int(d.get("version", 1))
	tracks = {}
	if version < 2:
		migrated_from = version
		var old: Variant = d.get("worlds", d.get("tracks", {}))
		if old is Dictionary:
			for wk: Variant in old:
				var rec: Variant = old[wk]
				var w: int = int(String(wk))
				if rec is Dictionary and w >= 1 and w <= RrBalance.WORLD_COUNT:
					var r2: Dictionary = (rec as Dictionary).duplicate(true)
					r2["medal"] = RrTracks.medal_for(
						RrTracks.key(w, 1), float(r2.get("best_time", 0.0))
					)
					tracks[RrTracks.key(w, 1)] = r2
		league = RrLeague.new()
		_new_seed()
		return
	var t: Variant = d.get("tracks", {})
	tracks = t if t is Dictionary else {}
	league = RrLeague.new()
	var lg: Variant = d.get("league", {})
	if lg is Dictionary:
		league.from_dict(lg)
	var pk: Variant = d.get("parked_league", {})
	parked_league = pk if pk is Dictionary else {}
	if version < 3:
		# Version 2 = the two-world ladder (Bronze, Silver): see migrate_v2.
		migrated_from = version
		league.migrate_v2()
		if not parked_league.is_empty():
			var pl := RrLeague.new()
			pl.from_dict(parked_league)
			pl.migrate_v2()
			parked_league = pl.to_dict()
	if league.save_seed == 0:
		_new_seed()


## GDD 17.8 save_seed: random once at first launch, on the device only.
func _new_seed() -> void:
	var r := RandomNumberGenerator.new()
	r.randomize()
	league.save_seed = r.randi_range(1, 2147483646)


## Test hook: forget everything (fresh install).
func reset_all() -> void:
	finishes = 0
	hover_unlocked = false
	seen_first_swap = false
	tracks = {}
	league = RrLeague.new()
	parked_league = {}
	_new_seed()
	cosmetics = {"outfit": 1, "bike": 1, "board": 1, "owned": []}
	full_unlock = true
	first_launch = true
	form_shown = false
	migrated_from = 0
	_free_card_sent = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
