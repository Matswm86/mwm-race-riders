class_name RrHud
extends Control

## Race HUD (GDD 10.1, DESIGN 5): progress bar with the six rider tokens,
## place disc under it, Vanlig race time, boost disc, start lights, hand
## hints, steering arrows, pad chevrons and the big-landing star over the
## rider, the tumbling-bike icon over a knocked-off rival, speed streaks on
## boost. Every shape is a sprite from one atlas (RrHudAtlas), so the HUD
## batches into a few draw calls and allocates nothing per frame (QA finding
## 2). Nothing here takes input; RrMain reads the touches.

const AMBER := Color(1.000, 0.690, 0.000)
const INK := Color(0.078, 0.090, 0.110)
const BAR_X0: float = 260.0
const BAR_X1: float = 820.0
const BAR_Y: float = 268.0
const PLACE_Y: float = 350.0
const TIME_X: float = 780.0
const LAMP_Y: float = 640.0
const CHARGE_R: float = 100.0
const STREAKS: int = 16

var race: RrRace
var world: RrWorld
var vanlig: bool = false
var less_motion: bool = false
var show_pre_hint: bool = false
var show_boost_hint: bool = false
## -1 left, 1 right, 0 none: the side the player is holding.
var steer_dir: int = 0
## Safe-area shift of the top band (camera cutouts), px.
var top_dy: float = 0.0

var _atlas: Texture2D
var _font: Font
var _shown_place: int = 6
var _place_t: float = 99.0
var _place_changed_at: float = -99.0
var _clock: float = 0.0
var _arrow_t: Array[float] = [99.0, 99.0]
var _chev_t: float = 99.0
var _chev_n: int = 0
var _star_t: float = 99.0
var _idle_hint_t: float = 99.0
var _idle_hint_dir: float = 1.0
var _notyet_t: float = 99.0
var _ready_pop_t: float = 99.0
var _fill: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _go_t: float = 99.0
var _knock_t: Array[float] = [99.0, 99.0, 99.0, 99.0, 99.0, 99.0]
var _time_txt: String = ""
var _time_next: float = 0.0
var _streak_k: float = 0.0
var _speed_v: float = 0.0
## Speed lines: x (0..1 of the screen), y progress, speed factor, per line.
var _sx: PackedFloat32Array = PackedFloat32Array()
var _sy: PackedFloat32Array = PackedFloat32Array()
var _sk: PackedFloat32Array = PackedFloat32Array()
var _srng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_atlas = load(RrHudAtlas.PATH)
	_font = load("res://assets/fonts/BarlowCondensed-SemiBold.ttf")


func reset() -> void:
	_shown_place = 6
	_place_t = 99.0
	_place_changed_at = -99.0
	_fill.fill(0.0)
	_go_t = 99.0
	_star_t = 99.0
	_chev_t = 99.0
	_idle_hint_t = 99.0
	_knock_t.fill(99.0)
	_time_txt = ""
	_time_next = 0.0
	steer_dir = 0


func boost_center() -> Vector2:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	return Vector2(vs.x * 0.5, vs.y - RrBalance.BOOST_CENTER_Y_FROM_BOTTOM)


func steer_pressed(dir: int) -> void:
	_arrow_t[0 if dir < 0 else 1] = 0.0


func pad_hit(chain: int) -> void:
	_chev_n = chain
	_chev_t = 0.0


func big_landing() -> void:
	_star_t = 0.0


func boost_not_ready() -> void:
	_notyet_t = 0.0


func boost_ready() -> void:
	_ready_pop_t = 0.0


func go() -> void:
	_go_t = 0.0


func idle_hint(dir: float) -> void:
	_idle_hint_dir = dir
	_idle_hint_t = 0.0


## GDD 4.7 / 11: the tumbling-bike icon over a knocked-off rival, 500 ms.
func knock_icon(rider_index: int) -> void:
	_knock_t[rider_index] = 0.0


func _process(delta: float) -> void:
	_clock += delta
	_place_t += delta
	_arrow_t[0] += delta
	_arrow_t[1] += delta
	_chev_t += delta
	_star_t += delta
	_idle_hint_t += delta
	_notyet_t += delta
	_ready_pop_t += delta
	_go_t += delta
	for i: int in 6:
		_knock_t[i] += delta
	if race != null:
		var p: RrRider = race.player
		if p.place != _shown_place and _clock - _place_changed_at >= RrBalance.PLACE_POP_MIN_S:
			_shown_place = p.place
			_place_changed_at = _clock
			_place_t = 0.0
		var k: float = 1.0 - exp(-delta / 0.1)
		for i: int in race.riders.size():
			_fill[i] = lerpf(_fill[i], race.progress_of(i), k)
		if vanlig and race.phase != RrRace.Phase.PRE and _clock >= _time_next:
			_time_next = _clock + 0.1
			var tt: float = maxf(0.0, race.t)
			_time_txt = "%d:%04.1f" % [int(tt / 60.0), fmod(tt, 60.0)]
		# GDD 11.1 speed lines: from SPEED_LINES_FROM_MPS, full at
		# SPEED_LINES_FULL_MPS; never in less motion.
		var want: float = 0.0
		if not less_motion and race.phase == RrRace.Phase.RACE:
			want = clampf(
				(
					(p.v - RrBalance.SPEED_LINES_FROM_MPS)
					/ (RrBalance.SPEED_LINES_FULL_MPS - RrBalance.SPEED_LINES_FROM_MPS)
				),
				0.0,
				1.0
			)
		_speed_v = p.v
		_streak_k = move_toward(_streak_k, want, delta * 2.0)
		_move_streaks(delta)
	queue_redraw()


func _spr(name: String, at: Vector2, k: float = 1.0, mod: Color = Color(1, 1, 1)) -> void:
	var e: Array = RrHudAtlas.SPRITES[name]
	var src: Rect2 = e[0]
	var anchor: Vector2 = e[1]
	draw_texture_rect_region(_atlas, Rect2(at - anchor * k, src.size * k), src, mod)


func _rect(r: Rect2, col: Color) -> void:
	var src: Rect2 = (RrHudAtlas.SPRITES["dot"][0] as Rect2).grow(-4.0)
	draw_texture_rect_region(_atlas, r, src, col)


func _draw() -> void:
	if race == null or _atlas == null:
		return
	var ox: float = (size.x - RrBalance.DESIGN_W) * 0.5
	_draw_streaks()
	_draw_bar(ox)
	_draw_place(ox)
	_draw_lights()
	_draw_arrows()
	_draw_over_riders()
	_draw_boost()
	_draw_hints()
	if vanlig and _time_txt != "" and race.phase != RrRace.Phase.PRE:
		var c := Vector2(ox + TIME_X, PLACE_Y + top_dy)
		_spr("chip", c)
		var w: float = _font.get_string_size(_time_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		var base: float = (_font.get_ascent(40) - _font.get_descent(40)) * 0.5
		draw_string(
			_font, c + Vector2(-w * 0.5, base), _time_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 40
		)


func _draw_bar(ox: float) -> void:
	var y: float = BAR_Y + top_dy
	_spr("bar", Vector2(ox + BAR_X0 - 6.0, y - 13.0))
	var x0: float = ox + BAR_X0
	var span: float = BAR_X1 - BAR_X0
	var px: float = x0 + span * _fill[0]
	if px > x0 + 2.0:
		_rect(Rect2(x0, y - 7.0, px - x0, 14.0), AMBER)
	_spr("flag", Vector2(ox + BAR_X1 + 30.0, y + 20.0))
	# Rival tokens first; pack tokens overlap, the player is drawn on top.
	for i: int in range(1, race.riders.size()):
		var r: RrRider = race.riders[i]
		_spr("tok%d" % r.livery, Vector2(x0 + span * _fill[i], y))
	_spr("player0", Vector2(px, y))


func _draw_place(ox: float) -> void:
	var k: float = 1.0
	if _place_t < 0.25 and not less_motion:
		var u: float = _place_t / 0.25
		k = lerpf(0.85, 1.08, u / 0.6) if u < 0.6 else lerpf(1.08, 1.0, (u - 0.6) / 0.4)
	_spr("place%d" % clampi(_shown_place, 1, 6), Vector2(ox + 540.0, PLACE_Y + top_dy), k)


func _draw_boost() -> void:
	if race.phase == RrRace.Phase.DONE:
		return
	var c: Vector2 = boost_center()
	var p: RrRider = race.player
	if _notyet_t < 0.15:
		c.x += sin(_notyet_t / 0.15 * TAU * 2.0) * 6.0
	var boosting: bool = p.boosting(race.t)
	var ready: bool = p.meter >= 1.0 and not boosting and race.phase == RrRace.Phase.RACE
	var k: float = 1.0
	if ready and not less_motion:
		if _ready_pop_t < 0.2:
			k = 1.0 + 0.06 * sin(_ready_pop_t / 0.2 * PI)
		else:
			k = 1.015 + 0.015 * sin(_clock * TAU * 1.0)
	_spr("boost", c, k)
	var frac: float = p.meter if race.phase == RrRace.Phase.RACE else 0.0
	if boosting:
		frac = clampf((p.boost_until - race.t) / RrBalance.BOOST_TIME_S, 0.0, 1.0)
	if frac >= 0.999:
		_spr("boost_full", c, k)
	elif frac > 0.005:
		var a0: float = -PI * 0.5
		draw_arc(c, CHARGE_R * k, a0, a0 + TAU * frac, 64, AMBER, 14.0 * k, true)


func _draw_lights() -> void:
	var live: bool = race.phase == RrRace.Phase.LIGHTS
	if not live and not (race.phase == RrRace.Phase.RACE and _go_t < 0.5):
		return
	var c := Vector2(size.x * 0.5, LAMP_Y)
	var alpha: float = 1.0 if live else 1.0 - _go_t / 0.5
	var mod := Color(1, 1, 1, alpha)
	_spr("lights_bg", c, 1.0, mod)
	for i: int in 3:
		var lc: Vector2 = c + Vector2((i - 1) * 125.0, 0.0)
		var name: String = "lamp_off"
		if race.phase == RrRace.Phase.RACE:
			name = "lamp_green"
		elif race.lights_lit > i:
			name = "lamp_amber"
		_spr(name, lc, 1.0, mod)


func _draw_arrows() -> void:
	if race.phase != RrRace.Phase.RACE:
		return
	for i: int in 2:
		var dir: float = -1.0 if i == 0 else 1.0
		var a: float = 0.0
		if _arrow_t[i] < RrBalance.STEER_ARROW_S:
			a = 0.85
		elif steer_dir == int(dir):
			a = 0.4
		if a > 0.0:
			var x: float = 90.0 if i == 0 else size.x - 90.0
			_spr("arrow_l" if i == 0 else "arrow_r", Vector2(x, 1000.0), 1.0, Color(1, 1, 1, a))


func _draw_over_riders() -> void:
	if world == null or race.phase == RrRace.Phase.DONE:
		return
	var head: Vector2 = world.screen_pos(world.rider_pos(0, 2.2))
	if head.x > -500.0:
		var n: int = mini(_chev_n, 3) if _chev_t < 0.3 else 0
		for i: int in n:
			_spr("chevron", head + Vector2(0.0, -float(i) * 30.0))
		if _star_t < 0.4:
			var k: float = 1.0 if less_motion else minf(1.0, _star_t / 0.12)
			_spr("star", head + Vector2(0, -100), k)
	for i: int in range(1, race.riders.size()):
		if _knock_t[i] < RrBalance.KNOCK_ICON_S:
			var at: Vector2 = world.screen_pos(world.rider_pos(i, 1.6))
			if at.x > -500.0:
				_spr("knock%d" % race.riders[i].livery, at)


func _new_streak(i: int, y: float) -> void:
	# Outer 25% of the screen, either side, random spot (never a stripe pattern).
	var u: float = _srng.randf_range(0.02, 0.25)
	_sx[i] = u if _srng.randf() < 0.5 else 1.0 - u
	_sy[i] = y
	_sk[i] = _srng.randf_range(0.7, 1.3)


func _move_streaks(delta: float) -> void:
	if _sx.is_empty():
		_sx.resize(STREAKS)
		_sy.resize(STREAKS)
		_sk.resize(STREAKS)
		for i: int in STREAKS:
			_new_streak(i, _srng.randf())
	if _streak_k <= 0.01:
		return
	var rate: float = 0.6 + _speed_v / 30.0
	for i: int in STREAKS:
		_sy[i] += delta * rate * _sk[i]
		if _sy[i] > 1.0:
			_new_streak(i, _srng.randf_range(-0.3, 0.0))


## GDD 11.1: thin soft streaks in the outer quarter, alpha up to 0.25,
## longer with speed, close to the background colour (rule 38).
func _draw_streaks() -> void:
	if _streak_k <= 0.01 or _sx.is_empty():
		return
	var a: float = 0.25 * _streak_k
	var length: float = 220.0 + 480.0 * _streak_k
	for i: int in STREAKS:
		var x: float = size.x * _sx[i]
		var y: float = _sy[i] * (size.y + length) - length
		var w: float = 4.0 + 6.0 * absf(_sx[i] - 0.5) * 2.0
		_rect(Rect2(x - w * 0.5, y, w, length * _sk[i]), Color(0.92, 0.90, 0.86, a))


func _draw_hints() -> void:
	var t: float = _clock
	if show_pre_hint and race.phase == RrRace.Phase.PRE:
		var loop: float = fmod(t, RrBalance.HINT_LOOP_S) / RrBalance.HINT_LOOP_S
		var left: bool = loop < 0.5
		var press: float = sin(fmod(loop * 2.0, 1.0) * PI)
		for i: int in 2:
			var active: bool = (i == 0) == left
			var x: float = size.x * (0.25 if i == 0 else 0.75)
			var tip := Vector2(x, 1180.0 + (press * 30.0 if active else 0.0))
			_spr("hand", tip, 1.0, Color(1, 1, 1, 1.0 if active else 0.45))
	if show_boost_hint and race.phase == RrRace.Phase.RACE:
		var pr: float = sin(fmod(t, 1.2) / 1.2 * PI)
		_spr("hand", boost_center() + Vector2(40, 30 + pr * 25.0), 0.85)
	if _idle_hint_t < RrBalance.IDLE_HINT_SHOW_S and race.phase == RrRace.Phase.RACE:
		var pulse: float = 0.6 + 0.4 * sin(_idle_hint_t * TAU * 1.5)
		var hx: float = size.x * (0.25 if _idle_hint_dir < 0.0 else 0.75)
		_spr("hand", Vector2(hx, 1150.0), 1.0, Color(1, 1, 1, pulse))
