class_name RrCard
extends Control

## Finish and reward card (GDD 10.3, 17.2-17.3), no words: trophy by place,
## the time in digits with the medal flag it earned on this track (a star if
## it is a new medal), the ghost line (new best, or the saved best; none on a
## track's first run), and the discs at y 1420 that act on release: home,
## and after a league round "next" (biggest, the picture of the next round's
## world; it opens the league table) + replay (a free ride on the same
## track), or replay as the biggest after a free ride. Unlocks get their
## reveal cards after the first disc tap (the hoverboard), then the chosen
## action runs. The card never advances by itself; after 7 s the biggest
## disc pulses.

signal replay_pressed
signal home_pressed
signal next_pressed

const PANEL := Rect2(90, 330, 900, 900)
const IDLE_PULSE_S: float = 7.0

var place: int = 1
var time_s: float = 0.0
var ghost_mode: String = "none"
var best_s: float = 0.0
## Next league round's track for the "next" disc ("" = none: free ride).
var next_key: String = ""
var less_motion: bool = false
## Medal on this track (1 gold, 2 silver, 3 bronze, 0 none) and if it is new.
var medal: int = 0
var new_medal: bool = false
var home_disc: RrDisc
var replay_disc: RrDisc
var next_disc: RrRaceDisc

var _t: float = 0.0
## Reveal queue: "board" and/or "world:<id>".
var _reveals: Array[String] = []
var _revealing: bool = false
var _reveal_t: float = 0.0
var _pending: String = ""


func _ready() -> void:
	size = Vector2(RrBalance.DESIGN_W, RrBalance.DESIGN_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	home_disc = _disc("home", Vector2(270, 1420), 100.0)
	replay_disc = _disc("replay", Vector2(810, 1420), 120.0)
	next_disc = RrRaceDisc.new()
	add_child(next_disc)
	_place_disc(next_disc, Vector2(810, 1420), 120.0)
	home_disc.tapped.connect(func() -> void: _choose("home"))
	replay_disc.tapped.connect(func() -> void: _choose("replay"))
	next_disc.tapped.connect(func() -> void: _choose("next"))
	visible = false
	set_process(false)


func _disc(icon: String, c: Vector2, r: float) -> RrDisc:
	var d := RrDisc.new()
	d.icon = icon
	d.size = Vector2(r * 2.0 + 20.0, r * 2.0 + 20.0)
	add_child(d)
	_place_disc(d, c, r)
	return d


func _place_disc(d: RrDisc, c: Vector2, r: float) -> void:
	d.disc_radius = r
	d.size = Vector2(r * 2.0 + 20.0, r * 2.0 + 20.0)
	d.position = c - d.size * 0.5
	d.queue_redraw()


## next: the next league round's track for the "next" disc, "" = none.
## reveals: unlocks to show after the first tap ("board").
func show_card(
	p: int,
	t: float,
	ghost: String,
	best: float,
	next: String,
	reveals: Array[String],
	medal_v: int = 0,
	medal_new: bool = false
) -> void:
	medal = medal_v
	new_medal = medal_new
	place = p
	time_s = t
	ghost_mode = ghost
	best_s = best
	next_key = next
	_reveals = reveals.duplicate()
	_revealing = false
	_pending = ""
	_t = 0.0 if not less_motion else 1.0
	visible = true
	home_disc.visible = true
	if next_key != "":
		next_disc.visible = true
		next_disc.track_key = next_key
		_place_disc(next_disc, Vector2(810, 1420), 120.0)
		replay_disc.visible = true
		_place_disc(replay_disc, Vector2(540, 1420), 100.0)
	else:
		next_disc.visible = false
		replay_disc.visible = true
		_place_disc(replay_disc, Vector2(810, 1420), 120.0)
	modulate.a = 0.0 if not less_motion else 1.0
	set_process(true)
	RrDisc.block_input(int(RrBalance.HOLDOVER_S * 1000.0))


func hide_card() -> void:
	visible = false
	set_process(false)


func is_revealing() -> bool:
	return _revealing


func reveal_kind() -> String:
	return _reveals[0] if _revealing and not _reveals.is_empty() else ""


func _choose(what: String) -> void:
	if not _reveals.is_empty() and not _revealing:
		_pending = what
		_start_reveal()
		return
	_finish(what)


func _start_reveal() -> void:
	_revealing = true
	_reveal_t = 0.0
	home_disc.visible = false
	replay_disc.visible = false
	next_disc.visible = false
	RrDisc.block_input(int(RrBalance.HOLDOVER_S * 1000.0))


func _finish(what: String) -> void:
	match what:
		"home":
			home_pressed.emit()
		"next":
			next_pressed.emit()
		_:
			replay_pressed.emit()


## A release continues the reveal, but never one in the wrist strip (rule 6,
## QA finding 6).
func _gui_input(event: InputEvent) -> void:
	if not _revealing:
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _reveal_t < RrBalance.HOLDOVER_S or mb.position.y >= RrBalance.WRIST_Y:
		return
	accept_event()
	tap_reveal()


## Test hook and the release handler: the tap that ends one reveal card.
func tap_reveal() -> void:
	if not _revealing:
		return
	if not _reveals.is_empty():
		_reveals.pop_front()
	if _reveals.is_empty():
		_revealing = false
		_finish(_pending)
	else:
		_reveal_t = 0.0
		RrDisc.block_input(int(RrBalance.HOLDOVER_S * 1000.0))


func _process(delta: float) -> void:
	_t += delta
	_reveal_t += delta
	modulate.a = clampf(_t / RrBalance.CARD_FADE_S, 0.0, 1.0)
	# Idle cue (rule 18, QA finding 7): the biggest disc pulses at 1 Hz.
	var big: RrDisc = next_disc if next_key != "" else replay_disc
	var k: float = 1.0
	if _t >= IDLE_PULSE_S and not less_motion and not _revealing:
		k = 1.0 + 0.05 * (0.5 - 0.5 * cos((_t - IDLE_PULSE_S) * TAU))
	if absf(big.pulse - k) > 0.001:
		big.pulse = k
		big.queue_redraw()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-2000, -2000), Vector2(6000, 6000)), Color(0, 0, 0, 0.35))
	RrDraw.panel(self, PANEL)
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
	RrDraw.text_centered(self, txt, Vector2(540, 880), 96, RrDraw.WHITE, "SemiBold")
	if medal > 0:
		RrDraw.medal_flag(self, Vector2(770, 880), 44.0, medal)
		if new_medal:
			RrDraw.star(self, Vector2(830, 820), 26.0, RrDraw.AMBER)
	match ghost_mode:
		"new_best":
			_ghost_icon(Vector2(420, 1070))
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
			draw_polyline(up + PackedVector2Array([up[0]]), RrDraw.WHITE, 4.0, true)
			RrDraw.star(self, Vector2(670, 1060), 52.0, RrDraw.AMBER)
		"best":
			_ghost_icon(Vector2(380, 1070))
			var bt: String = "%d:%04.1f" % [int(best_s / 60.0), fmod(best_s, 60.0)]
			RrDraw.text_centered(self, bt, Vector2(600, 1070), 64, RrDraw.WHITE, "SemiBold")


func _ghost_icon(c: Vector2) -> void:
	RrDisc.draw_icon(self, "ghost", c, 70.0, Color(0.92, 0.95, 1.0), RrDraw.INK)


func _draw_reveal() -> void:
	var kind: String = reveal_kind()
	var c := Vector2(540, 760)
	var spin: float = 1.0
	if not less_motion:
		spin = cos(clampf(_reveal_t / 2.0, 0.0, 1.0) * TAU * 2.0)
	# Soft floor shadow instead of a pedestal (QA finding 7: the grey pill
	# read as an empty button).
	draw_set_transform(c + Vector2(0, 250), 0.0, Vector2(1.0, 0.18))
	draw_circle(Vector2.ZERO, 230.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if kind.begins_with("world:"):
		var wid: int = int(kind.get_slice(":", 1))
		var r: float = 230.0 * (1.0 if less_motion else minf(1.0, 0.4 + _reveal_t / 0.6))
		draw_circle(c + Vector2(0, 6), r + 4.0, Color(0, 0, 0, 0.35))
		RrDraw.world_picture(self, c - Vector2(0, 20), r, wid)
		draw_arc(c - Vector2(0, 20), r - 3.0, 0.0, TAU, 96, RrDraw.WHITE, 6.0, true)
	else:
		RrDraw.board_icon(self, c + Vector2(0, 30), 300.0, maxf(0.08, absf(spin)))
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0 + _reveal_t * 0.5
		RrDraw.star(self, c + Vector2(cos(a), sin(a) * 0.6) * 340.0, 24.0, RrDraw.AMBER)
	if _reveal_t > 2.0:
		var pulse: float = 0.6 + 0.4 * sin(_reveal_t * TAU * 0.8)
		RrDisc.draw_icon(self, "play", Vector2(540, 1100), 70.0, Color(1, 1, 1, pulse))
