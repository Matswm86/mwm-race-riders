class_name RrSfx
extends Node

## Sound effects (GDD 11): pre-rendered .ogg files in res://assets/sfx/, made
## by tools/render_sfx.py (own synthesis plus Kenney CC0 layers, see
## CREDITS.md). One fixed pool of players, no allocation per hit, plus two
## loops (wind and tyre roll, hoverboard hum) whose pitch and level follow
## the player's speed. Players stay on the "Master" bus (MWM Play routes
## streams outside a "music" path to its Sfx bus). Copied from NbSfx.

## Emitted when the finish cheer starts, with its length, so music ducks.
signal stinger_started(seconds: float)

const POOL: int = 12
const DIR := "res://assets/sfx/"
## Call-site name -> files (variants) and the random pitch spread (+- share).
const SOUNDS: Dictionary = {
	"tick": [["rr_tick_1", "rr_tick_2", "rr_tick_3"], 0.05],
	"board_whoosh": [["rr_board_whoosh"], 0.05],
	"pad": [["rr_pad"], 0.0],
	"boost": [["rr_boost"], 0.02],
	"ready": [["rr_ready"], 0.0],
	"takeoff": [["rr_takeoff"], 0.05],
	"trick": [["rr_trick"], 0.06],
	"land_bike": [["rr_land_bike"], 0.05],
	"land_board": [["rr_land_board"], 0.05],
	"big_land": [["rr_big_land"], 0.0],
	"bonk": [["rr_bonk"], 0.08],
	"scrape": [["rr_scrape"], 0.08],
	"hay": [["rr_hay"], 0.06],
	"tick_up": [["rr_tick_up"], 0.0],
	"swap": [["rr_swap"], 0.03],
	"blip": [["rr_blip"], 0.0],
	"go": [["rr_go"], 0.0],
	"cheer": [["rr_cheer"], 0.0],
	"clink": [["rr_clink"], 0.02],
	"not_yet": [["rr_not_yet"], 0.04],
	"click": [["rr_click"], 0.04],
}
const CHEER_DUCK_S: float = 3.0
## Level of every effect before the player's slider (peaks about -10 dBFS
## with the default slider), the music sits 6 dB under (RrMusic.BASE_DB).
const BASE_DB: float = -10.0
const LOOP_DB: float = -6.0

var enabled: bool = true
## Effects slider, 0..1 (linear), from RaceRiders.sfx_volume.
var volume: float = 1.0
var _streams: Dictionary = {}
var _spread: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _rng := RandomNumberGenerator.new()
var _roll: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _whistle: AudioStreamPlayer
var _whistle_k: float = 0.0
var _loop_level: float = 0.0


func _ready() -> void:
	_rng.randomize()
	for i: int in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for key: String in SOUNDS:
		var entry: Array = SOUNDS[key]
		var list: Array[AudioStream] = []
		for file: String in entry[0]:
			var s: AudioStream = load(DIR + file + ".ogg") as AudioStream
			if s != null:
				list.append(s)
			else:
				push_warning("RrSfx: missing " + file)
		_streams[key] = list
		_spread[key] = float(entry[1])
	_roll = _loop_player("rr_roll_loop")
	_hum = _loop_player("rr_hum_loop")
	_wind = _loop_player("rr_wind_loop")
	_whistle = _loop_player("rr_wind_whistle")


func _loop_player(file: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s: AudioStreamOggVorbis = load(DIR + file + ".ogg") as AudioStreamOggVorbis
	if s != null:
		s.loop = true
	p.stream = s
	p.volume_db = -80.0
	add_child(p)
	return p


func play(name: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not enabled or volume <= 0.01 or not _streams.has(name):
		return
	var list: Array[AudioStream] = _streams[name]
	if list.is_empty():
		return
	var spread: float = _spread[name]
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = list[_rng.randi() % list.size()]
	p.pitch_scale = clampf(pitch * (1.0 + _rng.randf_range(-spread, spread)), 0.25, 4.0)
	p.volume_db = vol_db + BASE_DB + linear_to_db(volume)
	p.play()
	if name == "cheer":
		stinger_started.emit(CHEER_DUCK_S)


## Riding loops: level 0..1 (0 = silent), speed as a share of cruise, and
## which vehicle hums. Called every frame by RrMain.
func set_ride(level: float, speed_k: float, board: bool) -> void:
	_loop_level = move_toward(_loop_level, level, 0.05)
	var on: bool = enabled and volume > 0.01 and _loop_level > 0.01
	for p: AudioStreamPlayer in [_roll, _hum]:
		var want: bool = on and ((p == _hum) == board or p == _roll)
		if want and not p.playing:
			p.play()
		elif not want and p.playing:
			p.stop()
	var base: float = BASE_DB + LOOP_DB + linear_to_db(maxf(volume * _loop_level, 0.001))
	_roll.volume_db = base + (-8.0 if board else 0.0) + (speed_k - 1.0) * 6.0
	_roll.pitch_scale = clampf(0.85 + 0.25 * speed_k, 0.5, 1.6)
	_hum.volume_db = base + (speed_k - 1.0) * 4.0
	_hum.pitch_scale = clampf(0.8 + 0.35 * speed_k, 0.5, 1.8)


## GDD 11.1 wind: -30 dB at a standstill to -12 dB at 45 m/s, pitch 0.8 ->
## 1.3; a high whistle layer fades in above 35 m/s and on boost. Called
## every frame with the player's speed (0 = off).
func set_wind(v: float, boosting: bool) -> void:
	var k: float = clampf(v / RrBalance.SPEED_LINES_FULL_MPS, 0.0, 1.0)
	var on: bool = enabled and volume > 0.01 and v > 0.5
	for p: AudioStreamPlayer in [_wind, _whistle]:
		if on and not p.playing:
			p.play()
		elif not on and p.playing:
			p.stop()
	if not on:
		return
	var vol: float = linear_to_db(maxf(volume, 0.001))
	_wind.volume_db = lerpf(RrBalance.WIND_DB.x, RrBalance.WIND_DB.y, k) + vol
	_wind.pitch_scale = lerpf(RrBalance.WIND_PITCH.x, RrBalance.WIND_PITCH.y, k)
	var from: float = RrBalance.WIND_WHISTLE_FROM_MPS
	var w: float = clampf((v - from) / (RrBalance.SPEED_LINES_FULL_MPS - from), 0.0, 1.0)
	if boosting:
		w = 1.0
	_whistle_k = move_toward(_whistle_k, w, 0.02)
	_whistle.volume_db = linear_to_db(maxf(_whistle_k, 0.001)) + RrBalance.WIND_DB.y - 4.0 + vol
	_whistle.pitch_scale = lerpf(0.9, 1.2, k)


func stop_all() -> void:
	for p: AudioStreamPlayer in _players:
		p.stop()
	_roll.stop()
	_hum.stop()
	_wind.stop()
	_whistle.stop()
	_loop_level = 0.0
