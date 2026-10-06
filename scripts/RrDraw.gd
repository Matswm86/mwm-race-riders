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


## A track's own picture (tests/capture.gd thumbs phase, 320 px), or null.
static func track_picture(key: String) -> Texture2D:
	if not _pics.has(key):
		var p: String = "res://assets/textures/ui/tracks/%s.jpg" % key
		_pics[key] = load(p) if ResourceLoader.exists(p) else null
	return _pics[key]


static func picture(world_id: int) -> Texture2D:
	if not _pics.has(world_id):
		var p: String = "res://assets/textures/ui/world_%d.jpg" % world_id
		_pics[world_id] = load(p) if ResourceLoader.exists(p) else null
	return _pics[world_id]


# ---------------------------------------------------------------- league


## League cup colours, Bronze -> Champion (GDD 17.2).
static func league_color(lg: int) -> Color:
	var cols: Array[Color] = [
		BRONZE,
		SILVER,
		GOLD,
		Color(0.62, 0.86, 0.90),
		Color(0.55, 0.80, 1.0),
		Color(0.95, 0.35, 0.30),
	]
	return cols[clampi(lg, 0, cols.size() - 1)]


## A league cup. locked = a dark silhouette (league not reached / not built).
static func league_cup(ci: CanvasItem, c: Vector2, lg: int, k: float, locked: bool) -> void:
	var fill: Color = Color(0.16, 0.18, 0.21) if locked else league_color(lg)
	var edge: Color = Color(1, 1, 1, 0.25) if locked else INK
	var cup := PackedVector2Array(
		[
			c + Vector2(-46, -50) * k,
			c + Vector2(46, -50) * k,
			c + Vector2(36, -8) * k,
			c + Vector2(10, 8) * k,
			c + Vector2(10, 26) * k,
			c + Vector2(30, 38) * k,
			c + Vector2(30, 50) * k,
			c + Vector2(-30, 50) * k,
			c + Vector2(-30, 38) * k,
			c + Vector2(-10, 26) * k,
			c + Vector2(-10, 8) * k,
			c + Vector2(-36, -8) * k,
		]
	)
	for side: float in [-1.0, 1.0]:
		ci.draw_arc(c + Vector2(side * 44, -28) * k, 18.0 * k, 0, TAU, 24, edge, 9.0 * k, true)
		ci.draw_arc(c + Vector2(side * 44, -28) * k, 18.0 * k, 0, TAU, 24, fill, 5.0 * k, true)
	ci.draw_colored_polygon(cup, fill)
	ci.draw_polyline(cup + PackedVector2Array([cup[0]]), edge, maxf(2.0, 4.0 * k), true)
	if not locked:
		var lit := PackedVector2Array(
			[
				c + Vector2(-34, -45) * k,
				c + Vector2(-18, -45) * k,
				c + Vector2(-16, -6) * k,
				c + Vector2(-26, -10) * k
			]
		)
		ci.draw_colored_polygon(lit, fill.lightened(0.4))


## Tier pips under a cup: III = 1 lit, II = 2, I = 3 (shape, not text).
static func tier_pips(ci: CanvasItem, c: Vector2, tier: int, r: float, lit_col: Color) -> void:
	for i: int in 3:
		var p: Vector2 = c + Vector2((float(i) - 1.0) * r * 2.8, 0.0)
		ci.draw_circle(p, r, lit_col if i <= tier else Color(1, 1, 1, 0.18))
		ci.draw_arc(p, r, 0.0, TAU, 20, INK, 2.0, true)


## Helmet icon shapes for the rivals (rule 36: never colour alone).
static func helmet_icon(ci: CanvasItem, name: String, c: Vector2, s: float, col: Color) -> void:
	match name:
		"star":
			var pts := PackedVector2Array()
			for i: int in 10:
				var a: float = -PI * 0.5 + TAU * float(i) / 10.0
				pts.append(c + Vector2(cos(a), sin(a)) * (s if i % 2 == 0 else s * 0.45))
			ci.draw_colored_polygon(pts, col)
		"moon":
			ci.draw_circle(c, s * 0.85, col)
			ci.draw_circle(c + Vector2(s * 0.42, -s * 0.2), s * 0.7, Color(0, 0, 0, 0))
			var cut := PackedVector2Array()
			for i: int in 25:
				var a: float = TAU * float(i) / 24.0
				cut.append(c + Vector2(s * 0.45, -s * 0.22) + Vector2(cos(a), sin(a)) * s * 0.68)
			ci.draw_colored_polygon(cut, INK)
		"leaf":
			var pts2 := PackedVector2Array()
			for i: int in 17:
				var u: float = float(i) / 16.0
				pts2.append(c + Vector2(sin(u * PI) * s * 0.55, (u - 0.5) * s * 1.8))
			for i: int in 17:
				var u: float = 1.0 - float(i) / 16.0
				pts2.append(c + Vector2(-sin(u * PI) * s * 0.55, (u - 0.5) * s * 1.8))
			ci.draw_set_transform(c, 0.6, Vector2.ONE)
			var local := PackedVector2Array()
			for q: Vector2 in pts2:
				local.append(q - c)
			ci.draw_colored_polygon(local, col)
			ci.draw_line(Vector2(0, -s * 0.8), Vector2(0, s * 0.8), INK, maxf(2.0, s * 0.1), true)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"drop":
			var pts3 := PackedVector2Array([c + Vector2(0, -s)])
			for i: int in 19:
				var a: float = -PI * 0.15 + PI * 1.3 * float(i) / 18.0
				pts3.append(c + Vector2(cos(a), sin(a)) * s * 0.62 + Vector2(0, s * 0.3))
			ci.draw_colored_polygon(pts3, col)
		_:
			var tri := PackedVector2Array(
				[
					c + Vector2(0, -s),
					c + Vector2(s * 0.95, s * 0.75),
					c + Vector2(-s * 0.95, s * 0.75)
				]
			)
			ci.draw_colored_polygon(tri, col)


## Jersey disc: the rival's hue, its number, and its helmet icon on a badge.
static func jersey_disc(
	ci: CanvasItem, c: Vector2, r: float, hue: Color, number: int, icon: String
) -> void:
	ci.draw_circle(c + Vector2(0, 3), r + 1.0, Color(0, 0, 0, 0.3))
	ci.draw_circle(c, r, hue)
	ci.draw_arc(c, r - 1.5, 0.0, TAU, 40, WHITE, 3.0, true)
	var light: bool = hue.get_luminance() > 0.55
	text_centered(ci, str(number), c + Vector2(0, 1), int(r * 1.15), INK if light else WHITE)
	var b: Vector2 = c + Vector2(r * 0.86, r * 0.62)
	ci.draw_circle(b, r * 0.6, INK)
	ci.draw_arc(b, r * 0.6, 0.0, TAU, 24, WHITE, 2.0, true)
	helmet_icon(ci, icon, b, r * 0.4, WHITE)


## The player's own disc: crimson r1 jersey with the big down chevron.
static func player_disc(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c + Vector2(0, 3), r + 1.0, Color(0, 0, 0, 0.3))
	ci.draw_circle(c, r, CRIMSON)
	ci.draw_arc(c, r - 2.0, 0.0, TAU, 40, AMBER, 5.0, true)
	var chev := PackedVector2Array(
		[
			c + Vector2(-r * 0.5, -r * 0.3),
			c + Vector2(0, r * 0.35),
			c + Vector2(r * 0.5, -r * 0.3),
		]
	)
	ci.draw_polyline(chev, WHITE, r * 0.22, true)


## Form arrow (GDD 17.2): up green, down amber; 0 draws nothing.
static func form_arrow(ci: CanvasItem, c: Vector2, s: float, dir: int) -> void:
	if dir == 0:
		return
	var d: float = -1.0 if dir > 0 else 1.0
	var pts := PackedVector2Array(
		[
			c + Vector2(0, d * s),
			c + Vector2(s * 0.8, -d * s * 0.2),
			c + Vector2(-s * 0.8, -d * s * 0.2)
		]
	)
	ci.draw_colored_polygon(pts, GREEN if dir > 0 else AMBER)
	ci.draw_rect(
		Rect2(c + Vector2(-s * 0.28, -d * s * 0.25 - s * 0.3), Vector2(s * 0.56, s * 0.6)),
		GREEN if dir > 0 else AMBER
	)


## Medal flag (GDD 17.4): gold, silver or bronze pennant on a pole; 0 draws
## nothing (no empty markers, GDD 9.1).
static func medal_flag(ci: CanvasItem, c: Vector2, s: float, medal: int) -> void:
	if medal <= 0:
		return
	ci.draw_line(c + Vector2(-s * 0.5, -s), c + Vector2(-s * 0.5, s), INK, s * 0.16, true)
	ci.draw_line(c + Vector2(-s * 0.5, -s), c + Vector2(-s * 0.5, s), WHITE, s * 0.08, true)
	var fill: Color = [GOLD, SILVER, BRONZE][clampi(medal - 1, 0, 2)]
	var flag := PackedVector2Array(
		[
			c + Vector2(-s * 0.45, -s),
			c + Vector2(s * 0.75, -s * 0.6),
			c + Vector2(-s * 0.45, -s * 0.15)
		]
	)
	ci.draw_colored_polygon(flag, fill)
	ci.draw_polyline(flag + PackedVector2Array([flag[0]]), INK, maxf(2.0, s * 0.08), true)


## A track's picture in a rounded rect: its world, with the evening tint and
## a small sun-down mark on Pro tracks, and the track number.
static func track_tile(ci: CanvasItem, r: Rect2, key: String, pressed: bool) -> void:
	var rr: Rect2 = r.grow(-8.0) if pressed else r
	var pts: PackedVector2Array = _round_rect(rr, 28.0)
	var pro: bool = RrTracks.is_pro(key)
	var tex: Texture2D = track_picture(key)
	var own: bool = tex != null
	if not own:
		tex = picture(RrTracks.world_of(key))
	# Without its own picture a Pro track shows its world warm and mirrored.
	var tint: Color = Color(1.0, 0.72, 0.55) if pro and not own else WHITE
	ci.draw_colored_polygon(pts, Color(0, 0, 0, 0.3))
	if tex != null:
		var uvs := PackedVector2Array()
		for p: Vector2 in pts:
			var u: Vector2 = (p - rr.position) / rr.size
			if pro and not own:
				u.x = 1.0 - u.x  # mirrored track, mirrored picture
			uvs.append(u)
		ci.draw_colored_polygon(pts, tint, uvs, tex)
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), WHITE, 4.0, true)
	var nc: Vector2 = rr.position + Vector2(48, 48)
	ci.draw_circle(nc, 34.0, INK)
	ci.draw_arc(nc, 32.0, 0.0, TAU, 32, AMBER if pro else WHITE, 4.0, true)
	text_centered(ci, str(RrTracks.number_of(key)), nc + Vector2(0, 2), 48, WHITE)
	if pro:
		var sc: Vector2 = rr.position + Vector2(rr.size.x - 46, 46)
		ci.draw_circle(sc, 30.0, INK)
		ci.draw_arc(sc + Vector2(0, 8), 16.0, PI, TAU, 16, AMBER, 6.0, true)
		ci.draw_line(sc + Vector2(-22, 9), sc + Vector2(22, 9), AMBER, 4.0, true)


## Stopwatch icon for times on boards.
static func clock_icon(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_arc(c, s, 0.0, TAU, 32, col, s * 0.18, true)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.2, -s * 1.45), Vector2(s * 0.4, s * 0.3)), col)
	ci.draw_line(c, c + Vector2(0, -s * 0.62), col, s * 0.16, true)
	ci.draw_line(c, c + Vector2(s * 0.45, s * 0.1), col, s * 0.16, true)


## m:ss.s
static func time_text(t: float) -> String:
	if t <= 0.0:
		return "-:--.-"
	return "%d:%04.1f" % [int(t / 60.0), fmod(t, 60.0)]
