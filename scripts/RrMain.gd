class_name RrMain
extends Node

## Root of MWM Race Riders: the 3D world, the HUD, the card, the league
## screen (home), the season card, the free-ride track page and boards,
## settings and the race controller. Every launch goes straight into the next
## league race (GDD 10.2, 17.2): Bronze III round 1 = world 1 track 1 the
## first time. After a league round the card's "next" disc opens the league
## table; after round 5 the season card promotes (or not). Free rides (any
## open track, no points) start from the track page or the card's replay.
## Touches are read here (GDD 3): hold the left or right half to steer
## (latest touch wins), the centre boost disc acts on release, the home and
## gear squares and the wrist strip never steer.
## Inside MWM Play (Engine meta "mwm_play_shell") the own home disc and the
## back button are left to the shell.

## Test hooks: a fake top safe-area inset in window px (< 0 = ask the
## display), and a bot that steers instead of touches (-1, 0, 1 or a Callable).
var fake_safe_top: float = -1.0
var bot: Callable = Callable()
var screen: String = ""
var paused: bool = false
## Owner rule: drop to Lav when fps stays under 45 for 3 s in a race.
var auto_quality: bool = true

var world_id: int = 0
## Track key of the loaded world and of the current race.
var track_key: String = ""
## "league" (a round that scores) or "free" (no points).
var race_mode: String = "league"
## League table ids of the five rivals in this race (AI slots 0-4).
var heat: Array[int] = []
var track: RrTrack
var race: RrRace
var world: RrWorld
var sfx: RrSfx
var music: RrMusic
var ui: CanvasLayer
var screen_root: Control
var center_frame: Control
var hud: RrHud
var card: RrCard
var page: RrTrackPage
var league_screen: RrLeagueScreen
var season_card: RrSeasonCard
var board_view: RrBoardView
var settings: RrSettings
var home: RrHomeDisc
var gear: RrHomeDisc
var resume_disc: RrDisc
var flash := RrFlashLimiter.new()
var ghost: RrGhost
## Card data of the last finish, for tests.
var last_result: Dictionary = {}
## Result of the last league round and of the last season end, for tests.
var last_round: Dictionary = {}
var last_season: Dictionary = {}
## Where the board was opened from ("page" or "league").
var _board_from: String = "league"

var _touches: Dictionary = {}
var _steer_order: Array[int] = []
var _boost_tap: bool = false
var _holdover_until: float = 0.0
var _clock: float = 0.0
var _pre_t: float = 0.0
var _auto_start_s: float = RrBalance.AUTO_START_S
var _slowmo: float = 1.0
var _slowmo_until: float = -1.0
var _finish_t: float = -1.0
var _last_steer_t: float = 0.0
var _next_idle_hint: float = RrBalance.IDLE_HINT_S
var _was_boosting: bool = false
var _scrape_t: float = 0.0
var _first_swap_pending: bool = false
var _slow_fps_t: float = 0.0
var _quality_applied: int = -1


func _ready() -> void:
	sfx = RrSfx.new()
	add_child(sfx)
	music = RrMusic.new()
	add_child(music)
	sfx.stinger_started.connect(music.duck)
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	screen_root = Control.new()
	screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(screen_root)
	hud = RrHud.new()
	hud.world = world
	screen_root.add_child(hud)
	center_frame = Control.new()
	center_frame.size = Vector2(RrBalance.DESIGN_W, RrBalance.DESIGN_H)
	center_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(center_frame)
	league_screen = RrLeagueScreen.new()
	center_frame.add_child(league_screen)
	league_screen.race_pressed.connect(_on_league_race)
	league_screen.map_pressed.connect(open_track_page)
	league_screen.board_pressed.connect(
		func() -> void: open_board(RaceRiders.league.next_track(), "league")
	)
	page = RrTrackPage.new()
	center_frame.add_child(page)
	page.board_requested.connect(func(k: String) -> void: open_board(k, "page"))
	page.back_pressed.connect(_on_back_to_league)
	board_view = RrBoardView.new()
	center_frame.add_child(board_view)
	board_view.race_pressed.connect(_on_board_race)
	board_view.back_pressed.connect(_on_board_back)
	season_card = RrSeasonCard.new()
	center_frame.add_child(season_card)
	season_card.continued.connect(_on_season_continue)
	card = RrCard.new()
	center_frame.add_child(card)
	card.replay_pressed.connect(_on_card_replay)
	card.home_pressed.connect(_on_card_home)
	card.next_pressed.connect(_on_card_next)
	settings = RrSettings.new()
	center_frame.add_child(settings)
	settings.closed.connect(_close_settings)
	settings.sfx_preview.connect(func() -> void: sfx.play("pad"))
	home = _guard_disc("home")
	home.confirmed.connect(func() -> void: open_league_screen(false))
	gear = _guard_disc("gear")
	gear.confirmed.connect(_open_settings)
	resume_disc = RrDisc.new()
	resume_disc.icon = "play"
	resume_disc.disc_radius = 120.0
	resume_disc.size = Vector2(260, 260)
	resume_disc.tapped.connect(_resume)
	resume_disc.visible = false
	screen_root.add_child(resume_disc)
	RaceRiders.settings_changed.connect(_apply_settings)
	get_viewport().size_changed.connect(_layout)
	_layout()
	start_race(RaceRiders.launch_track(), "league")


## Build the 3D scene of a track (one RrWorld per track; the old one goes).
func _load_world(key: String) -> void:
	if key == track_key and world != null:
		return
	if world != null:
		remove_child(world)
		world.queue_free()
	track_key = key
	track = RrTrack.new(key)
	world_id = track.world_id
	world = RrWorld.new()
	add_child(world)
	move_child(world, 0)
	world.setup(track)
	world.apply_quality(RaceRiders.quality_high)
	_quality_applied = 1 if RaceRiders.quality_high else 0
	hud.world = world


func _guard_disc(icon: String) -> RrHomeDisc:
	var d := RrHomeDisc.new()
	d.icon = icon
	d.disc_radius = 68.0
	d.ring_px = 5.0
	d.tapped.connect(func() -> void: sfx.play("click"))
	screen_root.add_child(d)
	return d


func _apply_settings() -> void:
	sfx.enabled = RaceRiders.sfx_on or RaceRiders.in_shell()
	sfx.volume = RaceRiders.sfx_volume
	music.set_enabled(RaceRiders.music_on or RaceRiders.in_shell())
	music.set_volume(RaceRiders.music_volume)
	world.set_less_motion(RaceRiders.less_motion)
	var q: int = 1 if RaceRiders.quality_high else 0
	if q != _quality_applied:
		_quality_applied = q
		world.apply_quality(RaceRiders.quality_high)
	hud.less_motion = RaceRiders.less_motion
	card.less_motion = RaceRiders.less_motion
	var shell: bool = RaceRiders.in_shell()
	home.visible = screen == "race" and not shell
	gear.visible = screen in ["race", "card", "page", "league", "board"]
	league_screen.less_motion = RaceRiders.less_motion
	season_card.less_motion = RaceRiders.less_motion
	if world.ghost_view != null and not RaceRiders.ghost_on:
		ghost = null


func _layout() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	center_frame.position = Vector2(
		(vs.x - RrBalance.DESIGN_W) * 0.5, (vs.y - RrBalance.DESIGN_H) * 0.5
	)
	resume_disc.position = vs * 0.5 - resume_disc.size * 0.5
	apply_safe_area()


## Home disc and gear move below a camera cutout; their touch areas still run
## to the screen corner (copied from ball-connect 7ad7d50 via Neon Bricks).
## The HUD band (bar, place disc, time) moves down by the same amount.
func apply_safe_area() -> void:
	var dy: float = top_shift()
	hud.top_dy = dy
	var hit: float = RrBalance.HOME_HIT
	home.position = Vector2.ZERO
	home.size = Vector2(hit, hit + dy)
	home.disc_center = Vector2(104.0, 104.0 + dy)
	home.queue_redraw()
	var vw: float = get_viewport().get_visible_rect().size.x
	gear.position = Vector2(vw - hit, 0.0)
	gear.size = Vector2(hit, hit + dy)
	gear.disc_center = Vector2(hit - 104.0, 104.0 + dy)
	gear.queue_redraw()


## How far the top row moves down for a camera cutout (px).
func top_shift() -> float:
	return maxf(0.0, safe_top_inset() - RrBalance.TOP_ROW_CLEAR)


## Depth of the top screen cutout in viewport px (0 on desktop).
func safe_top_inset() -> float:
	var top_px: float = fake_safe_top
	if top_px < 0.0:
		if not OS.has_feature("mobile"):
			return 0.0
		top_px = float(DisplayServer.get_display_safe_area().position.y)
	var win: Vector2i = DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	return maxf(0.0, top_px * get_viewport().get_visible_rect().size.y / float(win.y))


# ---------------------------------------------------------------- flow


## Start a race. mode "league": the league's next round (its five heat
## rivals, GDD 17.2); mode "free": track key alone, no points (GDD 17.2 free
## ride), only on tracks the free ride offers.
func start_race(key: String = "", mode: String = "league") -> void:
	var lg: RrLeague = RaceRiders.league
	if mode == "free" and not RaceRiders.can_ride(key):
		mode = "league"
	if mode == "league" and lg.season_over():
		_show_season_end()
		return
	if mode == "league":
		key = lg.next_track()
	race_mode = mode
	_load_world(key)
	screen = "race"
	paused = false
	race = RrRace.new()
	var skills: Array[float] = []
	heat.clear()
	if mode == "league":
		heat = lg.heat_rivals()
		skills = lg.heat_skills(heat, RaceRiders.easy, track.pro)
	race.setup(track, RaceRiders.easy, RaceRiders.hover_unlocked, -1, skills)
	world.make_racers(race)
	world.set_gates_live(RaceRiders.hover_unlocked)
	world.reset_camera(race)
	# GDD 10.8: the ghost is your best run on THIS track, so a track's first
	# run never has one (QA finding 1).
	ghost = null
	var rows: Array = RaceRiders.ghost_rows(track_key)
	if RaceRiders.ghost_on and rows.size() > 1:
		ghost = RrGhost.new(rows)
	hud.race = race
	hud.vanlig = not RaceRiders.easy
	hud.reset()
	hud.visible = true
	hud.show_pre_hint = true
	hud.show_boost_hint = false
	card.hide_card()
	_hide_screens()
	settings.visible = false
	resume_disc.visible = false
	_pre_t = 0.0
	_auto_start_s = (
		RrBalance.AUTO_START_FIRST_S if RaceRiders.first_launch else RrBalance.AUTO_START_S
	)
	_finish_t = -1.0
	_slowmo = 1.0
	_slowmo_until = -1.0
	_last_steer_t = 0.0
	_next_idle_hint = RrBalance.IDLE_HINT_S
	_was_boosting = false
	_first_swap_pending = RaceRiders.hover_unlocked and not RaceRiders.seen_first_swap
	_touches.clear()
	_steer_order.clear()
	_holdover()
	music.play()
	_apply_settings()


func _hide_screens() -> void:
	page.visible = false
	board_view.visible = false
	league_screen.hide_screen()
	season_card.hide_card()


## Common entry of every menu screen: no HUD, no card, quiet ride sounds.
func _menu(name: String) -> void:
	screen = name
	paused = false
	hud.visible = false
	card.hide_card()
	_hide_screens()
	settings.visible = false
	resume_disc.visible = false
	sfx.set_ride(0.0, 0.0, false)
	sfx.set_wind(0.0, false)
	_holdover()


## Home (GDD 17.2): the league table and the big race disc. animate = rows
## slide from their places before the last round.
func open_league_screen(animate: bool = false) -> void:
	if RaceRiders.league.season_over():
		_show_season_end()
		return
	_menu("league")
	league_screen.refresh(animate)
	RaceRiders.save_game()
	_apply_settings()


func open_track_page() -> void:
	_menu("page")
	page.refresh()
	page.visible = true
	RaceRiders.save_game()
	_apply_settings()


func open_board(key: String, from: String) -> void:
	_board_from = from
	_menu("board")
	board_view.show_board(key)
	_apply_settings()


func _show_season_end() -> void:
	_menu("season")
	last_season = RaceRiders.end_season()
	season_card.show_result(last_season)
	sfx.play("cheer" if bool(last_season.get("promoted", false)) else "clink")
	_apply_settings()


func _on_season_continue() -> void:
	sfx.play("click")
	open_league_screen(false)


func _on_league_race() -> void:
	sfx.play("click")
	start_race("", "league")


func _on_board_race(key: String) -> void:
	sfx.play("click")
	start_race(key, "free")


func _on_board_back() -> void:
	sfx.play("click")
	if _board_from == "page":
		open_track_page()
	else:
		open_league_screen(false)


func _on_back_to_league() -> void:
	sfx.play("click")
	open_league_screen(false)


func _holdover() -> void:
	_holdover_until = _clock + RrBalance.HOLDOVER_S
	RrDisc.block_input(int(RrBalance.HOLDOVER_S * 1000.0))


func _show_card() -> void:
	screen = "card"
	hud.visible = false
	var p: RrRider = race.player
	var res: Dictionary = RaceRiders.record_finish(
		track_key, p.finish_time, p.place, race.ghost_rows
	)
	var mode: String = "none"
	if not bool(res["first"]):
		mode = "new_best" if bool(res["new_best"]) else "best"
	var reveals: Array[String] = []
	if bool(res["unlocked_hover"]):
		reveals.append("board")
	var next_key: String = ""
	last_round = {}
	if race_mode == "league":
		last_round = RaceRiders.record_league_round(heat, heat_times())
		# After round 5 the disc shows the league cup: it opens the season card.
		var lg: RrLeague = RaceRiders.league
		next_key = RrRaceDisc.SEASON if lg.season_over() else lg.next_track()
	last_result = res.duplicate()
	last_result["place"] = p.place
	last_result["time"] = p.finish_time
	last_result["ghost_line"] = mode
	last_result["track"] = track_key
	last_result["mode"] = race_mode
	last_result["next_track"] = next_key
	card.show_card(
		p.place,
		p.finish_time,
		mode,
		float(res["prev_best"]),
		next_key,
		reveals,
		int(res["medal"]),
		bool(res["new_medal"])
	)
	sfx.play("clink")
	_apply_settings()
	RaceRiders.level_card_shown.emit(RrTracks.numeric_id(track_key))


## Finish time per rider index (0 = player); riders still on course are
## placed by projected time (GDD 10.3), so the heat always has six results.
func heat_times() -> Array[float]:
	var out: Array[float] = []
	for r: RrRider in race.riders:
		if r.finished:
			out.append(r.finish_time)
		else:
			var v: float = maxf(r.v, RrBalance.MIN_SPEED_FRAC * RrBalance.CRUISE_MPS)
			out.append(race.t + maxf(0.0, track.length - r.s) / v)
	return out


## Replay = a free ride on the same track (the round has already scored).
func _on_card_replay() -> void:
	sfx.play("click")
	start_race(track_key, "free")


## The card's biggest disc after a league round: the league table (or the
## season card after round 5).
func _on_card_next() -> void:
	sfx.play("click")
	open_league_screen(true)


func _on_card_home() -> void:
	sfx.play("click")
	open_league_screen(false)


func _open_settings() -> void:
	paused = true
	sfx.set_ride(0.0, 0.0, false)
	sfx.set_wind(0.0, false)
	settings.open()


func _close_settings() -> void:
	settings.visible = false
	paused = false
	sfx.play("click")
	_holdover()


func _resume() -> void:
	resume_disc.visible = false
	paused = false
	_holdover()


func card_visible() -> bool:
	return card.visible


# ---------------------------------------------------------------- input


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touch_down(st.index, st.position)
		else:
			_touch_up(st.index, st.position)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _touches.has(sd.index):
			var d: Dictionary = _touches[sd.index]
			d["pos"] = sd.position
			if sd.relative.length() > 4.0:
				d["moved"] = _clock


func _zone(pos: Vector2) -> String:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	# The home and gear hit squares grow with the safe-area shift (QA 5).
	var hit: float = RrBalance.HOME_HIT + 16.0
	if pos.y < hit + top_shift() and (pos.x < hit or pos.x > vs.x - hit):
		return "none"
	if pos.distance_to(hud.boost_center()) <= RrBalance.BOOST_HIT_R:
		return "boost"
	if pos.y >= vs.y - (RrBalance.DESIGN_H - RrBalance.WRIST_Y):
		return "none"
	return "steer"


func _touch_down(index: int, pos: Vector2) -> void:
	if screen != "race" or paused or settings.visible or _clock < _holdover_until:
		_touches[index] = {"kind": "none", "pos": pos, "moved": _clock, "t0": _clock}
		return
	var kind: String = _zone(pos)
	if race.phase == RrRace.Phase.DONE:
		kind = "none"
	_touches[index] = {"kind": kind, "pos": pos, "moved": _clock, "t0": _clock}
	if kind == "none":
		return
	if race.phase == RrRace.Phase.PRE:
		_start_lights()
	if kind == "steer":
		_steer_order.erase(index)
		_steer_order.append(index)
		_last_steer_t = _clock
		_next_idle_hint = race.t + RrBalance.IDLE_HINT_S
		var dir: int = _dir_of(pos)
		hud.steer_pressed(dir)
		if race.phase == RrRace.Phase.RACE:
			sfx.play("board_whoosh" if race.player.vehicle == RrRider.BOARD else "tick")


func _touch_up(index: int, pos: Vector2) -> void:
	if not _touches.has(index):
		return
	var d: Dictionary = _touches[index]
	_touches.erase(index)
	_steer_order.erase(index)
	if (
		String(d["kind"]) == "boost"
		and pos.distance_to(hud.boost_center()) <= RrBalance.BOOST_HIT_R
	):
		_boost_tap = true


func _dir_of(pos: Vector2) -> int:
	return -1 if pos.x < get_viewport().get_visible_rect().size.x * 0.5 else 1


## Latest steer touch that is not a resting palm (held > 8 s without moving).
func steer_dir() -> int:
	for i: int in range(_steer_order.size() - 1, -1, -1):
		var d: Dictionary = _touches.get(_steer_order[i], {})
		if d.is_empty():
			continue
		if _clock - float(d["moved"]) > RrBalance.PALM_IGNORE_S:
			continue
		return _dir_of(d["pos"])
	return 0


func _start_lights() -> void:
	if race.phase == RrRace.Phase.PRE:
		race.start_lights()
		hud.show_pre_hint = false
		world.skip_intro()


# ---------------------------------------------------------------- frame


func _process(delta: float) -> void:
	_clock += delta
	if screen in ["page", "league", "board", "season"] or race == null:
		return
	if paused:
		return
	var real: float = minf(delta, 0.05)
	if _slowmo_until >= 0.0 and _clock >= _slowmo_until:
		_slowmo = 1.0
		_slowmo_until = -1.0
	var dt: float = real * _slowmo
	if race.phase == RrRace.Phase.PRE:
		_pre_t += real
		if _pre_t >= _auto_start_s:
			_start_lights()
	var steer: int = steer_dir()
	if bot.is_valid():
		steer = int(bot.call(race))
	hud.steer_dir = steer
	race.step(dt, steer, _boost_tap)
	_boost_tap = false
	_handle_events()
	var row: Array = []
	if ghost != null and race.phase != RrRace.Phase.PRE:
		row = ghost.sample(maxf(0.0, race.t))
	elif ghost != null:
		row = ghost.sample(0.0)
	world.sync(race, dt, row)
	_feel(real)
	if _finish_t >= 0.0:
		_finish_t += real
		if _finish_t >= RrBalance.FINISH_SHOT_S and screen == "race":
			_show_card()


func _feel(real: float) -> void:
	var p: RrRider = race.player
	var racing: bool = race.phase == RrRace.Phase.RACE
	var boosting: bool = p.boosting(race.t)
	if _was_boosting and not boosting:
		world.fx_boost(false)
	_was_boosting = boosting
	var level: float = 0.0
	if race.phase == RrRace.Phase.RACE or race.phase == RrRace.Phase.DONE:
		level = clampf(p.v / RrBalance.CRUISE_MPS, 0.0, 1.0)
		if p.airborne:
			level *= 0.4
	sfx.set_ride(level, p.v / RrBalance.CRUISE_MPS, p.vehicle == RrRider.BOARD)
	var moving: bool = race.phase == RrRace.Phase.RACE or race.phase == RrRace.Phase.DONE
	sfx.set_wind(p.v if moving else 0.0, boosting)
	# Race 1 only: a hand taps the boost disc when it first fills.
	hud.show_boost_hint = (
		racing and RaceRiders.finishes == 0 and p.meter >= 1.0 and p.full_since < 15.0
	)
	# 7 s without a touch: a hand points toward the next pad (rule 18).
	if racing and steer_dir() == 0 and race.t >= _next_idle_hint:
		_next_idle_hint = race.t + RrBalance.IDLE_HINT_S
		if p.next_pad < track.pads.size():
			var px: float = track.pads[p.next_pad][1]
			hud.idle_hint(-1.0 if px < p.x else 1.0)
	elif steer_dir() != 0:
		_next_idle_hint = race.t + RrBalance.IDLE_HINT_S
	_scrape_t -= real
	_watch_fps(real)


func _watch_fps(real: float) -> void:
	if not auto_quality or not RaceRiders.quality_high or race.phase != RrRace.Phase.RACE:
		_slow_fps_t = 0.0
		return
	if race.t < 2.0:
		return
	if Engine.get_frames_per_second() < 45.0:
		_slow_fps_t += real
		if _slow_fps_t >= 3.0:
			_slow_fps_t = 0.0
			print("RaceRiders: fps under 45 for 3 s, graphics -> Lav")
			RaceRiders.set_quality_high(false, true)
	else:
		_slow_fps_t = 0.0


func _slow(scale: float, seconds: float) -> void:
	if RaceRiders.less_motion:
		return
	_slowmo = scale
	_slowmo_until = _clock + seconds


func _near(i: int) -> bool:
	return absf(race.riders[i].s - race.player.s) < 52.0


func _handle_events() -> void:
	for e: Array in race.events:
		var name: String = e[0]
		var who: int = e[1]
		var data: Variant = e[2]
		var me: bool = who == 0
		match name:
			"light":
				sfx.play("blip", [1.0, 1.122, 1.26][clampi(int(data) - 1, 0, 2)])
			"go":
				sfx.play("go")
				hud.go()
			"pad":
				var pd: Array = data
				var bright: bool = flash.allow(_clock)
				world.fx_pad(int(pd[0]), bright)
				if me:
					sfx.play("pad", 1.0 + 0.12 * float(int(pd[1]) - 1))
					hud.pad_hit(int(pd[1]))
					if not RaceRiders.less_motion:
						world.fx.flakes(world.rider_pos(0, 0.3), 8, Color(1.0, 0.69, 0.0), 3.0, 0.5)
				elif _near(who):
					sfx.play("pad", 1.0, -9.0)
			"boost":
				if me:
					sfx.play("boost")
					world.fx_boost(true)
			"boost_ready":
				if me:
					sfx.play("ready")
					hud.boost_ready()
			"notyet":
				if me:
					sfx.play("not_yet")
					hud.boost_not_ready()
			"takeoff":
				if me:
					sfx.play("takeoff")
			"trick":
				if me:
					sfx.play("trick")
			"land":
				var air: float = data
				world.views[who].squash(air)
				if _near(who) and air > 0.5 and not RaceRiders.less_motion:
					var lp: Vector3 = world.rider_pos(who, 0.1)
					world.fx.dust(lp, 10, 0.8, 0.25, Vector2(0.6, 1.4), Vector2(0.7, 1.8))
				if me:
					sfx.play("land_board" if race.player.vehicle == RrRider.BOARD else "land_bike")
					world.fx_land(air)
					if air >= RrBalance.LAND_BONUS_MIN_AIR_S:
						sfx.play("big_land")
						hud.big_landing()
			"bump":
				if _near(who):
					sfx.play("bonk", 1.0, -8.0)
			"nudge":
				# A rival hit the player: a soft side thud, a little dust.
				sfx.play("bonk", 1.0, -3.0)
				if not RaceRiders.less_motion:
					world.fx.dust(
						world.rider_pos(0, 0.2), 4, 0.5, 0.2, Vector2(0.3, 0.8), Vector2(0.5, 1.2)
					)
			"knock":
				_on_knock(who, data)
			"rail":
				if me and _scrape_t <= 0.0:
					_scrape_t = 0.4
					sfx.play("scrape")
					if not RaceRiders.less_motion:
						world.fx.dust(
							world.rider_pos(0, 0.1),
							3,
							0.4,
							0.2,
							Vector2(0.2, 0.6),
							Vector2(0.6, 1.4)
						)
			"hay":
				var b: Array = track.blocks[int(data)]
				if _near(who):
					sfx.play("hay", 1.0, 0.0 if me else -6.0)
					var hp: Vector3 = track.world_point(float(b[0]), float(b[1]), 0.6)
					world.fx.flakes(hp, 20, Color(0.847, 0.753, 0.537), 4.0)
			"patch":
				if _near(who) and not RaceRiders.less_motion:
					var mud: bool = world_id == 1
					var pp: Vector3 = world.rider_pos(who, 0.15)
					if mud:
						world.fx.flakes(pp, 12, Color(0.22, 0.16, 0.10), 3.0, 0.5)
					else:
						world.fx.dust(pp, 6, 0.6, 0.22, Vector2(0.4, 1.0), Vector2(0.6, 1.6))
				if me:
					sfx.play("scrape", 0.8, -6.0)
			"roller_hit":
				var rr: Array = race.roller_pose(int(data))
				var rp: Vector3 = world.rider_pos(who, 0.7)
				if not rr.is_empty():
					rp = track.world_point(float(rr[0]), float(rr[1]), 0.7)
				if _near(who):
					sfx.play("hay", 1.2, 0.0 if me else -6.0)
					world.fx.flakes(rp, 16, Color(0.62, 0.48, 0.30), 4.0)
			"swap":
				var sw: Array = data
				world.fx_gate(int(sw[0]))
				if _near(who) and not RaceRiders.less_motion:
					var wp: Vector3 = world.rider_pos(who, 0.3)
					world.fx.dust(wp, 16, 0.8, 0.18, Vector2(0.5, 1.5), Vector2(0.6, 1.6))
				if me:
					sfx.play("swap")
					if _first_swap_pending:
						_first_swap_pending = false
						RaceRiders.mark_first_swap_seen()
						_slow(RrBalance.FIRST_SWAP_TIMESCALE, RrBalance.FIRST_SWAP_SLOWMO_S)
			"overtake":
				sfx.play("tick_up")
			"finish":
				if me:
					_on_player_finish()
	race.events.clear()


func _on_player_finish() -> void:
	_finish_t = 0.0
	hud.visible = false
	world.start_finish_shot(race)
	world.fx_boost(false)
	_slow(RrBalance.FINISH_SLOWMO, RrBalance.FINISH_SLOWMO_S)
	sfx.play("cheer")
	if race.player.place <= 3 and not RaceRiders.less_motion:
		var fs: float = track.length + 2.0
		world.fx.confetti(track.world_point(fs, 0.0, 6.0))


## GDD 4.7 / 11, DESIGN 2c, 7: the rival tips over away from the player with
## a realistic dust burst and 6 stones; the tumbling-bike icon shows 500 ms.
## No stars, no shake for the rival's fall.
func _on_knock(who: int, data: Variant) -> void:
	var at: Array = data
	var p: Vector3 = track.world_point(float(at[0]), float(at[1]), 0.15)
	world.fx.knock(p)
	hud.knock_icon(who)
	sfx.play("bonk")
	sfx.play("scrape", 0.9, -4.0)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			RaceRiders.save_game()
			if screen == "race" and not settings.visible:
				paused = true
				sfx.set_ride(0.0, 0.0, false)
				sfx.set_wind(0.0, false)
		NOTIFICATION_APPLICATION_RESUMED:
			if screen == "race" and paused and not settings.visible:
				resume_disc.visible = true
				_holdover()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back()


func _on_back() -> void:
	if RaceRiders.in_shell():
		return
	if settings.visible:
		_close_settings()
	elif screen == "race":
		home.press()
	elif screen in ["card", "page", "season"]:
		open_league_screen(false)
	elif screen == "board":
		_on_board_back()
	else:
		RaceRiders.save_game()
		get_tree().quit()
