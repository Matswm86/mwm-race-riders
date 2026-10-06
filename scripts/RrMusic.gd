class_name RrMusic
extends Node

## Background music (GDD 11): the owner's track in res://assets/music/ (see
## CREDITS.md). It starts at the first pre-race, loops, and keeps playing
## across races, cards and the track page instead of restarting. The finish
## cheer ducks it by FINISH_DUCK_DB. Plays on the "Music" bus (created here if
## missing; MWM Play makes its own and routes every stream whose path holds
## "music" to it). On/off follows RaceRiders.music_on (shell: set_music_on).

const BUS := &"Music"
const TRACK := "res://assets/music/race_riders_theme.ogg"
## Player level before the slider; with the effects at -10 dB the music sits
## at least 6 dB under the effects (GDD 11, RrBalance.MUSIC_UNDER_SFX_DB).
const BASE_DB: float = -6.0
const SILENT_DB: float = -60.0
const FADE_S: float = 1.2
const DUCK_DB: float = RrBalance.FINISH_DUCK_DB
const DUCK_IN_S: float = 0.15
const DUCK_OUT_S: float = 1.0

var enabled: bool = true
var current: String = ""
var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _duck: float = 0.0
## Music slider (RaceRiders.music_volume) in dB, added on top of fade and duck.
var _vol_db: float = 0.0
var _duck_tween: Tween
var _fade_tweens: Array[Tween] = [null, null]
var _streams: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		var bi: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bi, BUS)
		AudioServer.set_bus_send(bi, &"Master")
	var s: AudioStreamOggVorbis = load(TRACK) as AudioStreamOggVorbis
	if s == null:
		push_warning("RrMusic: missing " + TRACK)
	else:
		s.loop = true
		_streams[TRACK] = s
	for i: int in 2:
		var p := AudioStreamPlayer.new()
		# Stream set before add_child so a host shell routes it by path.
		p.stream = _streams.get(TRACK, null)
		p.bus = BUS
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)


## Starts the track, or leaves it running (it never restarts between races).
func play() -> void:
	_switch(TRACK)


## Slider value 0..1 (linear); takes effect at once, also mid-fade.
func set_volume(v: float) -> void:
	_vol_db = linear_to_db(maxf(v, 0.001))
	_set_duck(_duck)


func set_enabled(on: bool) -> void:
	if enabled == on:
		return
	enabled = on
	if on:
		var want: String = current
		current = ""
		_switch(want)
	else:
		for i: int in 2:
			_fade(i, SILENT_DB, 0.3, true)


## Lower the music under the finish cheer for `seconds`, then bring it back.
func duck(seconds: float) -> void:
	if _duck_tween:
		_duck_tween.kill()
	_duck_tween = create_tween().set_ignore_time_scale(true)
	_duck_tween.tween_method(_set_duck, _duck, DUCK_DB, DUCK_IN_S)
	_duck_tween.tween_interval(maxf(0.0, seconds - DUCK_IN_S))
	_duck_tween.tween_method(_set_duck, DUCK_DB, 0.0, DUCK_OUT_S)


func _set_duck(db: float) -> void:
	_duck = db
	for p: AudioStreamPlayer in _players:
		p.volume_db = minf(p.get_meta(&"fade_db", SILENT_DB) + _duck + _vol_db, 6.0)


func _switch(path: String) -> void:
	if path == "" or not _streams.has(path):
		return
	if path == current and _players[_active].playing:
		return
	current = path
	if not enabled:
		return
	var old: int = _active
	_active = 1 - _active
	var p: AudioStreamPlayer = _players[_active]
	p.stream = _streams[path]
	p.set_meta(&"fade_db", SILENT_DB)
	p.volume_db = SILENT_DB + _duck + _vol_db
	p.play()
	_fade(_active, BASE_DB, FADE_S, false)
	_fade(old, SILENT_DB, FADE_S, true)


func _fade(i: int, to_db: float, secs: float, stop_after: bool) -> void:
	var p: AudioStreamPlayer = _players[i]
	if _fade_tweens[i]:
		_fade_tweens[i].kill()
	if not p.playing:
		p.set_meta(&"fade_db", SILENT_DB)
		return
	var tw: Tween = create_tween().set_ignore_time_scale(true)
	var from: float = p.get_meta(&"fade_db", SILENT_DB)
	tw.tween_method(
		func(db: float) -> void:
			p.set_meta(&"fade_db", db)
			p.volume_db = db + _duck + _vol_db,
		from,
		to_db,
		secs
	)
	if stop_after:
		tw.tween_callback(p.stop)
	_fade_tweens[i] = tw


func _exit_tree() -> void:
	for p: AudioStreamPlayer in _players:
		p.stop()
		p.stream = null
