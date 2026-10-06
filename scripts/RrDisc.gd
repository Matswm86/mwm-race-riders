class_name RrDisc
extends Control

## Round icon button (DESIGN 3, 5): ink disc, 4 px white ring, white icon
## drawn from shapes (no text, no fonts), soft shadow. Acts on release inside
## the control; the touch area is the whole control rect, the disc can sit
## anywhere in it.

signal tapped

const INK := Color(0.078, 0.090, 0.110)
const WHITE := Color(1.0, 1.0, 1.0)
const AMBER := Color(1.000, 0.690, 0.000)
const SHADOW := Color(0.0, 0.0, 0.0, 0.28)

## Touches are ignored until this tick (holdover after a screen change).
static var block_until_ms: int = 0

@export var icon: String = "play"
@export var disc_radius: float = 100.0
@export var ring_px: float = 4.0
@export var fill: Color = Color(0.078, 0.090, 0.110, 0.92)
## Disc centre inside the control; negative = the middle of the rect.
@export var disc_center: Vector2 = Vector2(-1, -1)
## > 0: the disc shows that world's picture with a small play badge.
@export var picture_world: int = 0
## Idle cue scale (1.0 = still), set by the owner (GDD rule 18 pulse).
var pulse: float = 1.0

var _down: bool = false
var _press_t: float = 99.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


static func block_input(ms: int) -> void:
	block_until_ms = Time.get_ticks_msec() + ms


func center() -> Vector2:
	return size * 0.5 if disc_center.x < 0.0 else disc_center


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if Time.get_ticks_msec() < block_until_ms:
		_down = false
		return
	if mb.pressed:
		_down = true
		_press_t = 0.0
		set_process(true)
		queue_redraw()
		accept_event()
	elif _down:
		_down = false
		queue_redraw()
		accept_event()
		if Rect2(Vector2.ZERO, size).has_point(mb.position):
			_on_tapped()


func _on_tapped() -> void:
	tapped.emit()


## Test hook and Android back: behaves like a release on the disc.
func press() -> void:
	_on_tapped()


func _process(delta: float) -> void:
	_press_t += delta
	queue_redraw()
	if _press_t > 0.12 and not _down:
		set_process(false)


func _draw() -> void:
	var pressed: bool = _down or _press_t < 0.1
	var k: float = (0.92 if pressed else 1.0) * pulse
	var c: Vector2 = center()
	var r: float = disc_radius * k
	draw_circle(c + Vector2(0, 5), r + 2.0, SHADOW)
	if picture_world > 0:
		RrDraw.world_picture(self, c, r, picture_world)
		draw_arc(c, r - ring_px * 0.5, 0.0, TAU, 64, WHITE, ring_px, true)
		var bc: Vector2 = c + Vector2(r * 0.62, r * 0.62)
		draw_circle(bc, r * 0.3, fill)
		draw_arc(bc, r * 0.3 - 2.0, 0.0, TAU, 40, WHITE, 4.0, true)
		RrDisc.draw_icon(self, "play", bc + Vector2(r * 0.03, 0), r * 0.16, WHITE, INK)
		return
	draw_circle(c, r, fill)
	draw_arc(c, r - ring_px * 0.5, 0.0, TAU, 64, WHITE, ring_px, true)
	RrDisc.draw_icon(self, icon, c, r * 0.55, WHITE, INK)


## Shared icon painter (card, world page, settings). hole = the colour of
## cut-outs (door, gear hub, eyes), normally the disc fill.
static func draw_icon(
	ci: CanvasItem, name: String, c: Vector2, s: float, col: Color, hole: Color = INK
) -> void:
	match name:
		"play", "next":
			var pts := PackedVector2Array(
				[
					c + Vector2(-0.45, -0.6) * s,
					c + Vector2(0.65, 0.0) * s,
					c + Vector2(-0.45, 0.6) * s
				]
			)
			ci.draw_colored_polygon(pts, col)
		"replay":
			# Open "C" with the arrowhead at the top pointing clockwise.
			var a0: float = deg_to_rad(20.0)
			var a1: float = deg_to_rad(285.0)
			ci.draw_arc(c, s * 0.6, a0, a1, 40, col, s * 0.24, true)
			var p: Vector2 = c + Vector2(cos(a1), sin(a1)) * s * 0.6
			var dir := Vector2(-sin(a1), cos(a1))
			var perp := Vector2(-dir.y, dir.x)
			var tri := PackedVector2Array(
				[
					p + dir * s * 0.42,
					p + perp * s * 0.36 - dir * s * 0.05,
					p - perp * s * 0.36 - dir * s * 0.05
				]
			)
			ci.draw_colored_polygon(tri, col)
		"map":
			var p0: Vector2 = c + Vector2(-0.55, 0.5) * s
			var p1: Vector2 = c + Vector2(0.0, 0.0) * s
			var p2: Vector2 = c + Vector2(0.55, -0.5) * s
			ci.draw_line(p0, p2, col, s * 0.14, true)
			for p: Vector2 in [p0, p1, p2]:
				ci.draw_circle(p, s * 0.2, col)
		"home":
			var roof := PackedVector2Array(
				[
					c + Vector2(-0.8, -0.05) * s,
					c + Vector2(0.0, -0.8) * s,
					c + Vector2(0.8, -0.05) * s
				]
			)
			ci.draw_colored_polygon(roof, col)
			ci.draw_rect(Rect2(c + Vector2(-0.55, -0.1) * s, Vector2(1.1, 0.8) * s), col)
			ci.draw_rect(Rect2(c + Vector2(-0.17, 0.25) * s, Vector2(0.34, 0.45) * s), hole)
		"gear":
			var pts := PackedVector2Array()
			for i: int in 32:
				var ang: float = TAU * float(i) / 32.0
				var rr: float = 0.78 if (i / 2) % 2 == 0 else 0.58
				pts.append(c + Vector2(cos(ang), sin(ang)) * rr * s)
			ci.draw_colored_polygon(pts, col)
			ci.draw_circle(c, s * 0.24, hole)
		"left", "right":
			var d: float = -1.0 if name == "left" else 1.0
			var pts := PackedVector2Array(
				[
					c + Vector2(-0.25 * d, -0.6) * s,
					c + Vector2(0.35 * d, 0.0) * s,
					c + Vector2(-0.25 * d, 0.6) * s,
				]
			)
			ci.draw_polyline(pts, col, s * 0.22, true)
		"close":
			ci.draw_line(c + Vector2(-0.5, -0.5) * s, c + Vector2(0.5, 0.5) * s, col, s * 0.2, true)
			ci.draw_line(c + Vector2(0.5, -0.5) * s, c + Vector2(-0.5, 0.5) * s, col, s * 0.2, true)
		"bolt":
			var pts := PackedVector2Array(
				[
					c + Vector2(0.18, -0.95) * s,
					c + Vector2(-0.55, 0.12) * s,
					c + Vector2(-0.02, 0.12) * s,
					c + Vector2(-0.22, 0.95) * s,
					c + Vector2(0.55, -0.18) * s,
					c + Vector2(0.02, -0.18) * s,
				]
			)
			ci.draw_colored_polygon(pts, col)
		"ghost":
			var body := PackedVector2Array()
			for i: int in 13:
				var ang: float = PI + PI * float(i) / 12.0
				body.append(c + Vector2(cos(ang) * 0.6, sin(ang) * 0.6 - 0.1) * s)
			for i: int in 7:
				var fx: float = 0.6 - 1.2 * float(i) / 6.0
				var fy: float = 0.75 if i % 2 == 0 else 0.5
				body.append(c + Vector2(fx, fy) * s)
			ci.draw_colored_polygon(body, col)
			for ex: float in [-0.22, 0.22]:
				ci.draw_circle(c + Vector2(ex, -0.15) * s, s * 0.12, hole)
		"speaker":
			var body := PackedVector2Array(
				[
					c + Vector2(-0.75, -0.25) * s,
					c + Vector2(-0.35, -0.25) * s,
					c + Vector2(0.1, -0.65) * s,
					c + Vector2(0.1, 0.65) * s,
					c + Vector2(-0.35, 0.25) * s,
					c + Vector2(-0.75, 0.25) * s,
				]
			)
			ci.draw_colored_polygon(body, col)
			for k: int in 2:
				var r: float = (0.42 + 0.3 * float(k)) * s
				ci.draw_arc(c + Vector2(0.1, 0) * s, r, -0.8, 0.8, 16, col, s * 0.12, true)
		"music":
			# Two beamed eighth notes.
			var w: float = s * 0.14
			for hx: float in [-0.45, 0.45]:
				var head: Vector2 = c + Vector2(hx, 0.55) * s
				ci.draw_set_transform(head, -0.35, Vector2(1.3, 1.0))
				ci.draw_circle(Vector2.ZERO, s * 0.24, col)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				var top: Vector2 = c + Vector2(hx + 0.26, -0.75) * s
				ci.draw_line(head + Vector2(0.26 * s, 0.0), top, col, w, true)
			ci.draw_line(
				c + Vector2(-0.19, -0.75) * s, c + Vector2(0.71, -0.75) * s, col, s * 0.24, true
			)


## Five-point star polygon.
static func star_points(c: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in 10:
		var ang: float = -PI * 0.5 + TAU * float(i) / 10.0
		var rr: float = outer if i % 2 == 0 else inner
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	return pts
