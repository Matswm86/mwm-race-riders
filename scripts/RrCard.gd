class_name RrCard
extends Control

## Finish and reward card (GDD 10.3), no words: trophy by place, the time in
## digits, the ghost line (new best, or the saved best), and the home and
## replay discs at y 1420 that act on release. An unlocked hoverboard gets
## its reveal card after the first tap on a disc, then the chosen action
## runs. The card never advances by itself.

signal replay_pressed
signal home_pressed

const CARD := Color(1.000, 0.973, 0.933)
const CARD_EDGE := Color(0.561, 0.514, 0.443)
const INK := RrDraw.INK
const PANEL := Rect2(90, 330, 900, 900)

var place: int = 1
var time_s: float = 0.0
var ghost_mode: String = "none"
var best_s: float = 0.0
var reveal_hover: bool = false
var less_motion: bool = false
var home_disc: RrDisc
var replay_disc: RrDisc

var _t: float = 0.0
var _revealing: bool = false
var _reveal_t: float = 0.0
var _pending: String = ""


func _ready() -> void:
	size = Vector2(RrBalance.DESIGN_W, RrBalance.DESIGN_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	home_disc = _disc("home", Vector2(270, 1420), 100.0)
	replay_disc = _disc("replay", Vector2(810, 1420), 120.0)
	home_disc.tapped.connect(func() -> void: _choose("home"))
	replay_disc.tapped.connect(func() -> void: _choose("replay"))
	visible = false
	set_process(false)


func _disc(icon: String, c: Vector2, r: float) -> RrDisc:
	var d := RrDisc.new()
	d.icon = icon
	d.disc_radius = r
	d.ring_px = 6.0
	d.size = Vector2(r * 2.0 + 20.0, r * 2.0 + 20.0)
	d.position = c - d.size * 0.5
	add_child(d)
	return d


func show_card(p: int, t: float, ghost: String, best: float, reveal: bool) -> void:
	place = p
	time_s = t
	ghost_mode = ghost
	best_s = best
	reveal_hover = reveal
	_revealing = false
	_pending = ""
	_t = 0.0 if not less_motion else 1.0
	visible = true
	home_disc.visible = true
	replay_disc.visible = true
	modulate.a = 0.0 if not less_motion else 1.0
	set_process(true)
	RrDisc.block_input(int(RrBalance.HOLDOVER_S * 1000.0))


func hide_card() -> void:
	visible = false
	set_process(false)


func is_revealing() -> bool:
	return _revealing


func _choose(what: String) -> void:
	if reveal_hover and not _revealing:
		_pending = what
		_revealing = true
		_reveal_t = 0.0
		reveal_hover = false
		home_disc.visible = false
		replay_disc.visible = false
		RrDisc.block_input(int(RrBalance.HOLDOVER_S * 1000.0))
		return
	_finish(what)


func _finish(what: String) -> void:
	if what == "home":
		home_pressed.emit()
	else:
		replay_pressed.emit()


func _gui_input(event: InputEvent) -> void:
	if not _revealing:
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _reveal_t < RrBalance.HOLDOVER_S:
		return
	accept_event()
	_revealing = false
	_finish(_pending)


## Test hook: the tap that ends the reveal card.
func tap_reveal() -> void:
	if _revealing:
		_revealing = false
		_finish(_pending)


func _process(delta: float) -> void:
	_t += delta
	_reveal_t += delta
	modulate.a = clampf(_t / RrBalance.CARD_FADE_S, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-2000, -2000), Vector2(6000, 6000)), Color(0, 0, 0, 0.28))
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.border_color = CARD_EDGE
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(56)
	sb.anti_aliasing = true
	draw_style_box(sb, PANEL)
	if _revealing:
		_draw_reveal()
		return
	# Trophy drops in with one bounce.
	var drop: float = 0.0
	if not less_motion:
		var u: float = clampf(_t / 0.45, 0.0, 1.0)
		drop = -260.0 * (1.0 - u) * (1.0 - u) + 30.0 * sin(u * PI) * (1.0 - u)
	RrDraw.trophy(self, Vector2(540, 590 + drop), place, 1.25)
	var txt: String = "%d:%04.1f" % [int(time_s / 60.0), fmod(time_s, 60.0)]
	RrDraw.text_centered(self, txt, Vector2(540, 880), 96, INK)
	match ghost_mode:
		"new_best":
			RrDisc.draw_icon(self, "ghost", Vector2(420, 1070), 70.0, INK)
			var up := PackedVector2Array(
				[
					Vector2(540, 1010),
					Vector2(600, 1080),
					Vector2(565, 1080),
					Vector2(565, 1130),
					Vector2(515, 1130),
					Vector2(515, 1080),
					Vector2(480, 1080),
				]
			)
			draw_colored_polygon(up, RrDraw.GREEN)
			draw_polyline(up + PackedVector2Array([up[0]]), INK, 4.0, true)
			RrDraw.star(self, Vector2(670, 1060), 52.0, RrDraw.SUN)
		"best":
			RrDisc.draw_icon(self, "ghost", Vector2(380, 1070), 70.0, INK)
			var bt: String = "%d:%04.1f" % [int(best_s / 60.0), fmod(best_s, 60.0)]
			RrDraw.text_centered(self, bt, Vector2(600, 1070), 64, INK)


func _draw_reveal() -> void:
	var c := Vector2(540, 760)
	var spin: float = 1.0
	if not less_motion:
		# Two turns on the pedestal over 2 s, ending face-on.
		spin = cos(clampf(_reveal_t / 2.0, 0.0, 1.0) * TAU * 2.0)
	# Pedestal.
	var ped := StyleBoxFlat.new()
	ped.bg_color = RrDraw.SUN
	ped.border_color = INK
	ped.set_border_width_all(6)
	ped.set_corner_radius_all(30)
	draw_style_box(ped, Rect2(c + Vector2(-240, 170), Vector2(480, 110)))
	RrDraw.board_icon(self, c + Vector2(0, 30), 300.0, maxf(0.08, absf(spin)))
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0 + _reveal_t * 0.5
		RrDraw.star(self, c + Vector2(cos(a), sin(a) * 0.6) * 330.0, 26.0, RrDraw.SUN)
	if _reveal_t > 2.0:
		var pulse: float = 0.6 + 0.4 * sin(_reveal_t * TAU * 0.8)
		RrDisc.draw_icon(self, "play", Vector2(540, 1080), 70.0, Color(INK.r, INK.g, INK.b, pulse))
