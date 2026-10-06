class_name RrDraw
extends RefCounted

## Shape painters for the HUD, the card and the track page (DESIGN 2e, 3, 4):
## place medal, fox head token, checker flag, trophies, hand hint, chevrons.
## No text except digits, drawn with Fredoka SemiBold.

const INK := Color(0.141, 0.129, 0.114)
const WHITE := Color(1, 1, 1)
const SUN := Color(1.000, 0.824, 0.247)
const SILVER := Color(0.851, 0.871, 0.894)
const BRONZE := Color(0.890, 0.627, 0.420)
const RIBBON := Color(0.204, 0.251, 0.353)
const CHARGE_EMPTY := Color(0.910, 0.894, 0.863)
const FOX := Color(0.910, 0.255, 0.173)
const CREAM := Color(1.000, 0.945, 0.839)
const VISOR := Color(0.118, 0.149, 0.200)
const GREEN := Color(0.298, 0.686, 0.314)

static var _font: FontVariation


static func font() -> FontVariation:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = load("res://assets/fonts/Fredoka.ttf")
		_font.variation_opentype = {"wght": 600}
	return _font


static func text_centered(ci: CanvasItem, t: String, c: Vector2, size: int, col: Color) -> void:
	var f: Font = font()
	var w: float = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc: float = f.get_ascent(size)
	var desc: float = f.get_descent(size)
	ci.draw_string(
		f, c + Vector2(-w * 0.5, (asc - desc) * 0.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col
	)


static func medal_fill(place: int) -> Color:
	match place:
		1:
			return SUN
		2:
			return SILVER
		3:
			return BRONZE
	return WHITE


## Scalloped rosette with ribbon tails and the place digit (DESIGN 4).
static func medal(ci: CanvasItem, c: Vector2, place: int, k: float) -> void:
	var r: float = 100.0 * k
	for side: float in [-1.0, 1.0]:
		var tail := PackedVector2Array(
			[
				c + Vector2(side * 30.0, 40.0) * k,
				c + Vector2(side * 75.0, 40.0) * k,
				c + Vector2(side * 62.0, 146.0) * k,
				c + Vector2(side * 45.0, 124.0) * k,
				c + Vector2(side * 22.0, 140.0) * k,
			]
		)
		ci.draw_colored_polygon(tail, RIBBON)
		ci.draw_polyline(tail + PackedVector2Array([tail[0]]), INK, 4.0, true)
	var pts := PackedVector2Array()
	var n: int = 48
	for i: int in n + 1:
		var a: float = TAU * float(i) / float(n)
		var rr: float = r * (0.93 + 0.07 * cos(a * 16.0))
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, WHITE)
	ci.draw_polyline(pts, INK, 5.0, true)
	var fill: Color = medal_fill(place)
	ci.draw_circle(c, 70.0 * k, fill)
	ci.draw_arc(c, 70.0 * k, 0.0, TAU, 48, INK, 4.0, true)
	if place == 1:
		var cr := PackedVector2Array(
			[
				c + Vector2(-26, -84) * k,
				c + Vector2(-30, -104) * k,
				c + Vector2(-14, -94) * k,
				c + Vector2(0, -110) * k,
				c + Vector2(14, -94) * k,
				c + Vector2(30, -104) * k,
				c + Vector2(26, -84) * k,
			]
		)
		ci.draw_colored_polygon(cr, SUN)
		ci.draw_polyline(cr + PackedVector2Array([cr[0]]), INK, 4.0, true)
	text_centered(ci, str(place), c + Vector2(0, 4) * k, int(112.0 * k), INK)


## Fox head token: red helmet, two ears with cream insides, dark visor with
## two eye shines (hud_parts.png).
static func fox_head(ci: CanvasItem, c: Vector2, r: float, ring: bool) -> void:
	if ring:
		ci.draw_circle(c, r + 7.0, WHITE)
		ci.draw_arc(c, r + 7.0, 0.0, TAU, 40, INK, 4.0, true)
	for side: float in [-1.0, 1.0]:
		var ear := PackedVector2Array(
			[
				c + Vector2(side * 0.25, -0.75) * r,
				c + Vector2(side * 0.95, -1.25) * r,
				c + Vector2(side * 0.9, -0.35) * r,
			]
		)
		ci.draw_colored_polygon(ear, FOX)
		var inner := PackedVector2Array(
			[
				c + Vector2(side * 0.42, -0.72) * r,
				c + Vector2(side * 0.85, -1.05) * r,
				c + Vector2(side * 0.8, -0.5) * r,
			]
		)
		ci.draw_colored_polygon(inner, CREAM)
	ci.draw_circle(c, r, FOX)
	ci.draw_arc(c, r, 0.0, TAU, 40, INK, 3.0, true)
	var vis := Rect2(c + Vector2(-0.62, -0.05) * r, Vector2(1.24, 0.42) * r)
	var sb := StyleBoxFlat.new()
	sb.bg_color = VISOR
	sb.set_corner_radius_all(int(r * 0.2))
	ci.draw_style_box(sb, vis)
	for ex: float in [-0.28, 0.28]:
		ci.draw_circle(c + Vector2(ex, 0.13) * r, r * 0.08, WHITE)


static func checker_flag(ci: CanvasItem, pole: Vector2, size: float) -> void:
	ci.draw_line(pole, pole + Vector2(0, size * 1.2), INK, 5.0, true)
	var cell: float = size / 4.0
	for y: int in 3:
		for x: int in 4:
			var col: Color = INK if (x + y) % 2 == 0 else WHITE
			ci.draw_rect(Rect2(pole + Vector2(x * cell, y * cell), Vector2(cell, cell)), col)
	ci.draw_rect(Rect2(pole, Vector2(size, cell * 3.0)), INK, false, 3.0)


## Cup for places 1-3, a finish-flag rosette for 4-6 (GDD 10.3).
static func trophy(ci: CanvasItem, c: Vector2, place: int, k: float) -> void:
	if place > 3:
		medal(ci, c, place, k * 1.25)
		return
	var fill: Color = medal_fill(place)
	var cup := PackedVector2Array(
		[
			c + Vector2(-110, -130) * k,
			c + Vector2(110, -130) * k,
			c + Vector2(95, -40) * k,
			c + Vector2(55, 10) * k,
			c + Vector2(20, 25) * k,
			c + Vector2(20, 70) * k,
			c + Vector2(70, 95) * k,
			c + Vector2(70, 125) * k,
			c + Vector2(-70, 125) * k,
			c + Vector2(-70, 95) * k,
			c + Vector2(-20, 70) * k,
			c + Vector2(-20, 25) * k,
			c + Vector2(-55, 10) * k,
			c + Vector2(-95, -40) * k,
		]
	)
	for side: float in [-1.0, 1.0]:
		ci.draw_arc(c + Vector2(side * 105, -70) * k, 45.0 * k, 0, TAU, 32, INK, 26.0 * k, true)
		ci.draw_arc(c + Vector2(side * 105, -70) * k, 45.0 * k, 0, TAU, 32, fill, 14.0 * k, true)
	ci.draw_colored_polygon(cup, fill)
	ci.draw_polyline(cup + PackedVector2Array([cup[0]]), INK, 6.0, true)
	ci.draw_circle(c + Vector2(0, -60) * k, 34.0 * k, WHITE)
	ci.draw_arc(c + Vector2(0, -60) * k, 34.0 * k, 0, TAU, 32, INK, 4.0, true)
	text_centered(ci, str(place), c + Vector2(0, -58) * k, int(52.0 * k), INK)


## A simple white hand with an ink outline pointing down (hints).
static func hand(ci: CanvasItem, tip: Vector2, s: float, alpha: float) -> void:
	var w := Color(1, 1, 1, alpha)
	var ink := Color(INK.r, INK.g, INK.b, alpha)
	var palm := Rect2(tip + Vector2(-0.38, 0.55) * s, Vector2(0.86, 0.75) * s)
	var finger := Rect2(tip + Vector2(-0.13, 0.0) * s, Vector2(0.26, 0.7) * s)
	var sb := StyleBoxFlat.new()
	sb.bg_color = w
	sb.border_color = ink
	sb.set_border_width_all(int(maxf(3.0, s * 0.04)))
	sb.set_corner_radius_all(int(s * 0.13))
	ci.draw_style_box(sb, finger)
	sb.set_corner_radius_all(int(s * 0.22))
	ci.draw_style_box(sb, palm)
	var cover := StyleBoxFlat.new()
	cover.bg_color = w
	cover.set_corner_radius_all(int(s * 0.1))
	ci.draw_style_box(cover, Rect2(tip + Vector2(-0.09, 0.5) * s, Vector2(0.18, 0.12) * s))


## n chevrons stacked upward (pad chain over the rider), static shapes.
static func chevrons(ci: CanvasItem, c: Vector2, n: int, s: float, col: Color) -> void:
	for i: int in n:
		var y: float = -float(i) * s * 0.55
		var pts := PackedVector2Array(
			[
				c + Vector2(-0.6 * s, y + 0.25 * s),
				c + Vector2(0.0, y - 0.25 * s),
				c + Vector2(0.6 * s, y + 0.25 * s),
			]
		)
		ci.draw_polyline(pts, INK, s * 0.32, true)
		ci.draw_polyline(pts, col, s * 0.18, true)


## Side arrow chevron for the steering feedback (GDD 3.2).
static func side_arrow(ci: CanvasItem, c: Vector2, dir: float, s: float, alpha: float) -> void:
	var pts := PackedVector2Array(
		[
			c + Vector2(-0.25 * dir, -0.6) * s,
			c + Vector2(0.3 * dir, 0.0) * s,
			c + Vector2(-0.25 * dir, 0.6) * s,
		]
	)
	ci.draw_polyline(pts, Color(INK.r, INK.g, INK.b, alpha * 0.6), s * 0.26, true)
	ci.draw_polyline(pts, Color(1, 1, 1, alpha), s * 0.16, true)


static func star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts: PackedVector2Array = RrDisc.star_points(c, r, r * 0.45)
	ci.draw_colored_polygon(pts, col)
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), INK, maxf(3.0, r * 0.08), true)


## Side-view hoverboard icon (unlock reveal): deck, team stripe, two pods.
static func board_icon(ci: CanvasItem, c: Vector2, s: float, squash_x: float) -> void:
	var w: float = s * squash_x
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREAM
	sb.border_color = INK
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(int(s * 0.12))
	ci.draw_style_box(sb, Rect2(c + Vector2(-w, -s * 0.12), Vector2(w * 2.0, s * 0.24)))
	ci.draw_rect(Rect2(c + Vector2(-w * 0.8, -s * 0.03), Vector2(w * 1.6, s * 0.06)), FOX)
	for px: float in [-0.55, 0.55]:
		ci.draw_circle(c + Vector2(px * w, s * 0.2), s * 0.11, VISOR)
		ci.draw_circle(c + Vector2(px * w, s * 0.27), s * 0.07, Color(0.561, 0.937, 1.0))
