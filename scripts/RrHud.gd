class_name RrHud
extends Control

## Race HUD (GDD 10.1, DESIGN 4-5), drawn in one _draw: place medal top
## centre, progress bar with the fox token, boost disc (GDD 3.1 centre disc),
## start lights, hand hints, steering arrows, pad chevrons over the rider,
## the big-landing star, soft speed lines and the Vanlig race clock.
## Nothing here takes input; RrMain reads the touches.

const INK := RrDraw.INK
const SUN := RrDraw.SUN
const BAR_X0: float = 92.0
const BAR_X1: float = 930.0
const BAR_Y: float = 312.0
const LAMP_Y: float = 640.0

var race: RrRace
var world: RrWorld
var vanlig: bool = false
var less_motion: bool = false
## Høy tier draws 3D GPU speed streaks instead of the flat HUD lines.
var gpu_lines: bool = false
var show_pre_hint: bool = false
var show_boost_hint: bool = false
## -1 left, 1 right, 0 none: the side the player is holding.
var steer_dir: int = 0

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
var _lines_k: float = 0.0
var _fill: float = 0.0
var _go_t: float = 99.0
## Medal 1-6, fox token and flag rendered once into textures (fewer draw
## calls than the vector shapes every frame); vector fallback until ready.
var _medal_tex: Array[Texture2D] = []
var _token_tex: Texture2D
var _flag_tex: Texture2D


class Painter:
	extends Control
	var fn: Callable

	func _draw() -> void:
		fn.call(self)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if DisplayServer.get_name() != "headless":
		_bake_textures.call_deferred()


func _bake_textures() -> void:
	var sv := SubViewport.new()
	sv.transparent_bg = true
	sv.size = Vector2i(256, 320)
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var painter := Painter.new()
	painter.size = Vector2(256, 320)
	sv.add_child(painter)
	add_child(sv)
	var medals: Array[Texture2D] = []
	for place: int in range(1, 7):
		painter.fn = func(ci: CanvasItem) -> void: RrDraw.medal(ci, Vector2(128, 120), place, 1.0)
		medals.append(await _grab(sv, painter))
	painter.fn = func(ci: CanvasItem) -> void: RrDraw.fox_head(ci, Vector2(128, 160), 36.0, true)
	var token: Texture2D = await _grab(sv, painter)
	painter.fn = func(ci: CanvasItem) -> void: RrDraw.checker_flag(ci, Vector2(100, 120), 56.0)
	var flag: Texture2D = await _grab(sv, painter)
	sv.queue_free()
	_medal_tex = medals
	_token_tex = token
	_flag_tex = flag


func _grab(sv: SubViewport, painter: Control) -> Texture2D:
	painter.queue_redraw()
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = sv.get_texture().get_image()
	if img == null:
		return null
	return ImageTexture.create_from_image(img)


## Draw a baked 256 x 320 texture so that its anchor lands on `at`.
func _blit(tex: Texture2D, at: Vector2, anchor: Vector2, k: float) -> void:
	var sz: Vector2 = Vector2(256, 320) * k
	draw_texture_rect(tex, Rect2(at - anchor * k, sz), false)


func reset() -> void:
	_shown_place = 6
	_place_t = 99.0
	_place_changed_at = -99.0
	_fill = 0.0
	_go_t = 99.0
	_star_t = 99.0
	_chev_t = 99.0
	_idle_hint_t = 99.0
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
	if race != null:
		var p: RrRider = race.player
		var want: int = p.place
		if want != _shown_place and _clock - _place_changed_at >= RrBalance.PLACE_POP_MIN_S:
			_shown_place = want
			_place_changed_at = _clock
			_place_t = 0.0
		_fill = lerpf(_fill, race.player_progress(), 1.0 - exp(-delta / 0.1))
		var fast: float = p.v / RrBalance.CRUISE_MPS
		var lines_want: float = 0.0
		if (
			not less_motion
			and not gpu_lines
			and fast > RrBalance.SPEED_LINES_FROM
			and race.phase == RrRace.Phase.RACE
		):
			lines_want = clampf((fast - RrBalance.SPEED_LINES_FROM) / 0.25, 0.0, 1.0)
		_lines_k = move_toward(_lines_k, lines_want, delta * 3.0)
	queue_redraw()


func _draw() -> void:
	if race == null:
		return
	var ox: float = (size.x - RrBalance.DESIGN_W) * 0.5
	_draw_speed_lines()
	_draw_medal(ox)
	_draw_bar(ox)
	if vanlig and race.phase != RrRace.Phase.PRE:
		var tt: float = maxf(0.0, race.t)
		var txt: String = "%d:%04.1f" % [int(tt / 60.0), fmod(tt, 60.0)]
		RrDraw.text_centered(self, txt, Vector2(ox + 820.0, 382.0), 40, INK)
	_draw_lights()
	_draw_arrows()
	_draw_over_rider()
	_draw_boost()
	_draw_hints()


func _draw_medal(ox: float) -> void:
	var k: float = 1.0
	if _place_t < 0.25 and not less_motion:
		var u: float = _place_t / 0.25
		k = lerpf(0.85, 1.1, u / 0.6) if u < 0.6 else lerpf(1.1, 1.0, (u - 0.6) / 0.4)
	if _medal_tex.size() == 6 and _medal_tex[_shown_place - 1] != null:
		_blit(_medal_tex[_shown_place - 1], Vector2(ox + 540.0, 112.0), Vector2(128, 120), k)
	else:
		RrDraw.medal(self, Vector2(ox + 540.0, 112.0), _shown_place, k)


func _draw_bar(ox: float) -> void:
	var r := Rect2(ox + BAR_X0, BAR_Y - 15.0, BAR_X1 - BAR_X0, 30.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.92)
	sb.border_color = INK
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(21)
	sb.anti_aliasing = true
	draw_style_box(sb, r.grow(3.0))
	var fx: float = r.position.x + r.size.x * _fill
	if _fill > 0.01:
		var fb := StyleBoxFlat.new()
		fb.bg_color = SUN
		fb.set_corner_radius_all(15)
		fb.anti_aliasing = true
		draw_style_box(fb, Rect2(r.position, Vector2(maxf(30.0, fx - r.position.x), 30.0)))
	if _flag_tex != null:
		_blit(_flag_tex, Vector2(ox + 964.0, BAR_Y - 34.0), Vector2(100, 120), 1.0)
	else:
		RrDraw.checker_flag(self, Vector2(ox + 964.0, BAR_Y - 34.0), 56.0)
	if _token_tex != null:
		_blit(_token_tex, Vector2(fx, BAR_Y), Vector2(128, 160), 1.0)
	else:
		RrDraw.fox_head(self, Vector2(fx, BAR_Y), 36.0, true)


func _draw_boost() -> void:
	if race.phase == RrRace.Phase.DONE:
		return
	var c: Vector2 = boost_center()
	var p: RrRider = race.player
	var r: float = RrBalance.BOOST_DRAW_R
	var wiggle: float = 0.0
	if _notyet_t < 0.15:
		wiggle = sin(_notyet_t / 0.15 * TAU * 2.0) * 6.0
	c.x += wiggle
	var boosting: bool = p.boosting(race.t)
	var ready: bool = p.meter >= 1.0 and not boosting
	var k: float = 1.0
	if ready and not less_motion:
		if _ready_pop_t < 0.2:
			k = 1.0 + 0.08 * sin(_ready_pop_t / 0.2 * PI)
		else:
			k = 1.02 + 0.02 * sin(_clock * TAU * 1.0)
	r *= k
	draw_circle(c, r, SUN if ready or boosting else Color(1, 1, 1))
	var ring_r: float = r - 20.0
	draw_arc(c, ring_r, 0.0, TAU, 64, RrDraw.CHARGE_EMPTY, 22.0, true)
	var frac: float = p.meter
	if boosting:
		frac = clampf((p.boost_until - race.t) / RrBalance.BOOST_TIME_S, 0.0, 1.0)
	if frac > 0.0:
		var a0: float = -PI * 0.5
		var sun_ring: Color = SUN if not (ready or boosting) else Color(1, 1, 1)
		draw_arc(c, ring_r, a0, a0 + TAU * frac, 64, sun_ring, 22.0, true)
	draw_arc(c, r - 3.0, 0.0, TAU, 64, INK, 6.0, true)
	RrDisc.draw_icon(self, "bolt", c, 58.0 * k, INK)


func _draw_lights() -> void:
	if race.phase == RrRace.Phase.LIGHTS or (race.phase == RrRace.Phase.RACE and _go_t < 0.5):
		var c := Vector2(size.x * 0.5, LAMP_Y)
		var alpha: float = 1.0 if race.phase == RrRace.Phase.LIGHTS else 1.0 - _go_t / 0.5
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(INK.r, INK.g, INK.b, alpha)
		sb.set_corner_radius_all(70)
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(c - Vector2(200, 66), Vector2(400, 132)))
		for i: int in 3:
			var lc: Vector2 = c + Vector2((i - 1) * 125.0, 0.0)
			var lit: bool = race.lights_lit > i
			var col: Color = Color(0.36, 0.38, 0.42, alpha)
			if race.phase == RrRace.Phase.RACE:
				col = Color(RrDraw.GREEN.r, RrDraw.GREEN.g, RrDraw.GREEN.b, alpha)
			elif lit:
				col = Color(SUN.r, SUN.g, SUN.b, alpha)
			draw_circle(lc, 46.0, col)
			draw_arc(lc, 46.0, 0.0, TAU, 40, Color(1, 1, 1, alpha * 0.9), 4.0, true)


func _draw_arrows() -> void:
	if race.phase != RrRace.Phase.RACE:
		return
	for i: int in 2:
		var dir: float = -1.0 if i == 0 else 1.0
		var held: bool = steer_dir == int(dir)
		var a: float = 0.0
		if _arrow_t[i] < RrBalance.STEER_ARROW_S:
			a = 0.85
		elif held:
			a = 0.4
		if a > 0.0:
			var x: float = 90.0 if i == 0 else size.x - 90.0
			RrDraw.side_arrow(self, Vector2(x, 1000.0), dir, 200.0, a)


func _draw_over_rider() -> void:
	if world == null or race.phase == RrRace.Phase.DONE:
		return
	var head: Vector2 = world.screen_pos(world.rider_pos(0, 2.1))
	if head.x < -500.0:
		return
	if _chev_t < 0.3:
		RrDraw.chevrons(self, head, _chev_n, 46.0, SUN)
	if _star_t < 0.4:
		var k: float = 1.0 if less_motion else minf(1.0, _star_t / 0.12)
		RrDraw.star(self, head + Vector2(0, -90), 60.0 * k, SUN)


func _draw_speed_lines() -> void:
	if _lines_k <= 0.01:
		return
	var a: float = RrBalance.SPEED_LINES_ALPHA_MAX * 0.9 * _lines_k
	for i: int in 8:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var lane: float = float(i / 2)
		var x: float = size.x * 0.5 + side * (size.x * 0.5 - 40.0 - lane * 46.0)
		var period: float = 0.45 + 0.07 * lane
		var y: float = fmod(_clock / period + lane * 0.27, 1.0) * (size.y + 600.0) - 300.0
		draw_line(Vector2(x, y), Vector2(x, y + 260.0), Color(1, 1, 1, a), 10.0, true)


func _draw_hints() -> void:
	var t: float = _clock
	if show_pre_hint and race.phase == RrRace.Phase.PRE:
		var loop: float = fmod(t, RrBalance.HINT_LOOP_S) / RrBalance.HINT_LOOP_S
		var left: bool = loop < 0.5
		var u: float = fmod(loop * 2.0, 1.0)
		var press: float = sin(u * PI)
		for i: int in 2:
			var active: bool = (i == 0) == left
			var x: float = size.x * (0.25 if i == 0 else 0.75)
			var tip := Vector2(x, 1300.0 + (press * 30.0 if active else 0.0))
			RrDraw.hand(self, tip, 180.0, 1.0 if active else 0.45)
			if active and press > 0.6:
				draw_arc(tip, 40.0 + press * 20.0, 0, TAU, 32, Color(1, 1, 1, 0.8), 6.0, true)
	if show_boost_hint and race.phase == RrRace.Phase.RACE:
		var bc: Vector2 = boost_center()
		var u2: float = fmod(t, 1.2) / 1.2
		var pr: float = sin(u2 * PI)
		RrDraw.hand(self, bc + Vector2(30, 40 + pr * 25.0), 160.0, 1.0)
	if _idle_hint_t < RrBalance.IDLE_HINT_SHOW_S and race.phase == RrRace.Phase.RACE:
		var pulse: float = 0.6 + 0.4 * sin(_idle_hint_t * TAU * 1.5)
		var hx: float = size.x * (0.25 if _idle_hint_dir < 0.0 else 0.75)
		RrDraw.hand(self, Vector2(hx, 1250.0), 180.0, pulse)
