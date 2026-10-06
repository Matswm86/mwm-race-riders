# gdlint: disable=max-public-methods
class_name RrState
extends Node

## Autoload "RaceRiders": save file, settings, progress and the public hooks
## a host app (MWM Play) calls (GDD 9.2, 12). The stand-alone build never
## calls the hooks, so it keeps everything open (the owner's own copy).
##
## Hooks: set_full_unlock(on), set_difficulty(easy), set_shell_inset(inset),
## set_sfx_on / set_music_on / set_haptics_on / set_less_motion, save_game().
## Signals up: level_card_shown(track_id), free_levels_finished().

signal level_card_shown(track_id: int)
signal free_levels_finished
signal settings_changed

const SAVE_PATH := "user://race_riders_save.json"
const SAVE_VERSION := 1
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
## track id (String) -> {best_time, best_place, won, ghost}
var tracks: Dictionary = {}
var cosmetics: Dictionary = {"outfit": 1, "bike": 1, "board": 1, "owned": []}
var last_track: int = 1
## True when no save existed at start: the race starts by itself sooner.
var first_launch: bool = true
var _free_card_sent: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


func in_shell() -> bool:
	return Engine.has_meta(SHELL_META) and bool(Engine.get_meta(SHELL_META))


# ---------------------------------------------------------------- hooks


func set_full_unlock(on: bool) -> void:
	full_unlock = on
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


func track_data(track_id: int) -> Dictionary:
	return tracks.get(str(track_id), {})


func ghost_rows(track_id: int) -> Array:
	return track_data(track_id).get("ghost", [])


func best_time(track_id: int) -> float:
	return float(track_data(track_id).get("best_time", 0.0))


## Track ids the track page shows (slice: track 1 only).
func visible_tracks() -> Array[int]:
	return [1]


## Record a finish (GDD 9-10). Returns what the card needs:
## {first: bool, new_best: bool, prev_best: float, unlocked_hover: bool}.
func record_finish(track_id: int, time_s: float, place: int, ghost: Array) -> Dictionary:
	var key: String = str(track_id)
	var d: Dictionary = tracks.get(key, {})
	var prev: float = float(d.get("best_time", 0.0))
	var first: bool = prev <= 0.0
	var new_best: bool = first or time_s < prev
	if new_best:
		d["best_time"] = snappedf(time_s, 0.01)
		d["ghost"] = ghost
	d["best_place"] = mini(int(d.get("best_place", 9)), place)
	d["won"] = bool(d.get("won", false)) or place == 1
	tracks[key] = d
	finishes += 1
	first_launch = false
	last_track = track_id
	var unlocked: bool = false
	if not hover_unlocked and finishes >= RrBalance.UNLOCK_HOVER:
		hover_unlocked = true
		unlocked = true
	save_game()
	return {"first": first, "new_best": new_best, "prev_best": prev, "unlocked_hover": unlocked}


## GDD 9.2: from total finish 3 on, at most once per app session, only when
## the host has locked the full game.
func maybe_free_card() -> bool:
	if full_unlock or _free_card_sent or finishes < RrBalance.FREE_CARD_FROM_FINISH:
		return false
	_free_card_sent = true
	free_levels_finished.emit()
	return true


func mark_first_swap_seen() -> void:
	seen_first_swap = true
	save_game()


func save_game() -> void:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"finishes": finishes,
		"hover_unlocked": hover_unlocked,
		"seen_first_swap": seen_first_swap,
		"tracks": tracks,
		"cosmetics": cosmetics,
		"last_track": last_track,
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
	var t: Variant = d.get("tracks", {})
	tracks = t if t is Dictionary else {}
	var c: Variant = d.get("cosmetics", {})
	if c is Dictionary:
		cosmetics = c
	last_track = int(d.get("last_track", 1))
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


## Test hook: forget everything (fresh install).
func reset_all() -> void:
	finishes = 0
	hover_unlocked = false
	seen_first_swap = false
	tracks = {}
	last_track = 1
	first_launch = true
	_free_card_sent = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
