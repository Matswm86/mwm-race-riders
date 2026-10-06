class_name RrDraw
extends RefCounted

## Shape painters for the card, the reveal and the world page (DESIGN 3-4):
## trophies, the hoverboard icon, stars, round world pictures. No text except
## digits, drawn with Barlow Condensed. The race HUD uses the atlas instead.

const INK := Color(0.078, 0.090, 0.110)
const PANEL := Color(0.078, 0.090, 0.110, 0.88)
const WHITE := Color(1, 1, 1)
const AMBER := Color(1.000, 0.690, 0.000)
const GOLD := Color(0.949, 0.757, 0.306)
const SILVER := Color(0.788, 0.808, 0.839)
const BRONZE := Color(0.788, 0.541, 0.333)
const GREEN := Color(0.298, 0.686, 0.314)
const CYAN := Color(0.561, 0.875, 1.0)
const CRIMSON := Color(0.784, 0.125, 0.169)

static var _fonts: Dictionary = {}
static var _pics: Dictionary = {}


static func font(weight: String = "Bold") -> Font:
	if not _fonts.has(weight):
		_fonts[weight] = load("res://assets/fonts/BarlowCondensed-%s.ttf" % weight)
	return _fonts[weight]


static func text_centered(
	ci: CanvasItem, t: String, c: Vector2, size: int, col: Color, weight: String = "Bold"
) -> void:
	var f: Font = font(weight)
	var w: float = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc: float = f.get_ascent(size)
	var desc: float = f.get_descent(size)
	ci.draw_string(
		f, c + Vector2(-w * 0.5, (asc - desc) * 0.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col
	)


static func medal_fill(place: int) -> Color:
	match place:
		1:
			return GOLD
		2:
			return SILVER
		3:
			return BRONZE
	return WHITE


static func panel(ci: CanvasItem, r: Rect2) -> void:
	var pts := _round_rect(r, 48.0)
	ci.draw_colored_polygon(pts, PANEL)
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.35), 3.0, true)


static func _round_rect(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners: Array[Vector2] = [
		r.position + Vector2(r.size.x - rad, rad),
		r.position + Vector2(r.size.x - rad, r.size.y - rad),
		r.position + Vector2(rad, r.size.y - rad),
		r.position + Vector2(rad, rad),
	]
	for k: int in 4:
		for i: int in 9:
			var a: float = -PI * 0.5 + PI * 0.5 * (float(k) + float(i) / 8.0)
			pts.append(corners[k] + Vector2(cos(a), sin(a)) * rad)
	return pts


## Place disc (DESIGN 5 look) at any size: medal colour, ink ring, digit.
static func place_disc(ci: CanvasItem, c: Vector2, place: int, r: float) -> void:
	ci.draw_circle(c + Vector2(0, 4), r + 2.0, Color(0, 0, 0, 0.3))
	ci.draw_circle(c, r, medal_fill(place))
	ci.draw_arc(c, r - 2.5, 0.0, TAU, 64, INK, 5.0, true)
	ci.draw_arc(c, r * 0.82, 0.0, TAU, 64, Color(1, 1, 1, 0.5), 2.0, true)
	text_centered(ci, str(place), c + Vector2(0, r * 0.06), int(r * 1.5), INK, "ExtraBoldItalic")


## Cup for places 1-3, a finish-flag rosette for 4-6 (GDD 10.3).
static func trophy(ci: CanvasItem, c: Vector2, place: int, k: float) -> void:
	if place > 3:
		_rosette(ci, c, place, k)
		return
	var fill: Color = medal_fill(place)
	var shade: Color = fill.darkened(0.25)
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
		ci.draw_arc(c + Vector2(side * 105, -70) * k, 45.0 * k, 0, TAU, 32, shade, 14.0 * k, true)
	ci.draw_colored_polygon(cup, fill)
	var lit := PackedVector2Array(
		[
			c + Vector2(-80, -122) * k,
			c + Vector2(-40, -122) * k,
			c + Vector2(-38, -20) * k,
			c + Vector2(-62, -30) * k
		]
	)
	ci.draw_colored_polygon(lit, fill.lightened(0.35))
	ci.draw_polyline(cup + PackedVector2Array([cup[0]]), INK, 6.0, true)
	place_disc(ci, c + Vector2(0, -62) * k, place, 36.0 * k)


static func _rosette(ci: CanvasItem, c: Vector2, place: int, k: float) -> void:
	for side: float in [-1.0, 1.0]:
		var tail := PackedVector2Array(
			[
				c + Vector2(side * 24.0, 30.0) * k,
				c + Vector2(side * 78.0, 30.0) * k,
				c + Vector2(side * 66.0, 150.0) * k,
				c + Vector2(side * 46.0, 128.0) * k,
				c + Vector2(side * 20.0, 146.0) * k,
			]
		)
		ci.draw_colored_polygon(tail, CRIMSON)
		ci.draw_polyline(tail + PackedVector2Array([tail[0]]), INK, 4.0, true)
	var pts := PackedVector2Array()
	for i: int in 49:
		var a: float = TAU * float(i) / 48.0
		var rr: float = 110.0 * k * (0.93 + 0.07 * cos(a * 16.0))
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, WHITE)
	ci.draw_polyline(pts, INK, 5.0, true)
	# Chequered ring: the finish flag, then the place digit.
	for i: int in 16:
		var a0: float = TAU * float(i) / 16.0
		var a1: float = TAU * float(i + 1) / 16.0
		ci.draw_arc(c, 88.0 * k, a0, a1, 6, INK if i % 2 == 0 else WHITE, 16.0 * k, false)
	place_disc(ci, c, place, 70.0 * k)


static func star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in 10:
		var ang: float = -PI * 0.5 + TAU * float(i) / 10.0
		var rr: float = r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	ci.draw_colored_polygon(pts, col)
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), INK, maxf(3.0, r * 0.08), true)


## Side-view hoverboard (unlock reveal): carbon deck, crimson rail, pods.
static func board_icon(ci: CanvasItem, c: Vector2, s: float, squash_x: float) -> void:
	var w: float = s * squash_x
	var rad: float = minf(s * 0.1, w * 0.9)
	var deck := _round_rect(Rect2(c + Vector2(-w, -s * 0.11), Vector2(w * 2.0, s * 0.22)), rad)
	ci.draw_colored_polygon(deck, Color(0.16, 0.17, 0.19))
	ci.draw_polyline(deck + PackedVector2Array([deck[0]]), WHITE, 5.0, true)
	ci.draw_rect(Rect2(c + Vector2(-w * 0.82, -s * 0.025), Vector2(w * 1.64, s * 0.05)), CRIMSON)
	for px: float in [-0.55, 0.55]:
		ci.draw_circle(c + Vector2(px * w, s * 0.19), s * 0.1, Color(0.12, 0.13, 0.15))
		ci.draw_circle(c + Vector2(px * w, s * 0.25), s * 0.07, CYAN)


## A world's picture (a frame of the real game) clipped to a circle.
static func world_picture(ci: CanvasItem, c: Vector2, r: float, world_id: int) -> void:
	var tex: Texture2D = picture(world_id)
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i: int in 48:
		var a: float = TAU * float(i) / 48.0
		var d := Vector2(cos(a), sin(a))
		pts.append(c + d * r)
		uvs.append(Vector2(0.5, 0.5) + d * 0.5)
	if tex != null:
		ci.draw_colored_polygon(pts, WHITE, uvs, tex)
	else:
		ci.draw_colored_polygon(
			pts, Color(0.62, 0.70, 0.78) if world_id == 1 else Color(0.70, 0.40, 0.28)
		)


static func picture(world_id: int) -> Texture2D:
	if not _pics.has(world_id):
		var p: String = "res://assets/textures/ui/world_%d.jpg" % world_id
		_pics[world_id] = load(p) if ResourceLoader.exists(p) else null
	return _pics[world_id]
