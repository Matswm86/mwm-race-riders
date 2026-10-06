class_name RrRaceDisc
extends RrDisc

## The big "race next" disc (GDD 17.2 league screen) and other track discs:
## the track's world picture in a circle (warm and mirrored on Pro tracks),
## a play badge, and the track number on a small badge (digits only). Acts on
## release like every disc.

## track_key SEASON: the disc shows the league's cup (the season card next).
const SEASON := "season"

var track_key: String = "w1_t1"


func _draw() -> void:
	var pressed: bool = _down or _press_t < 0.1
	var k: float = (0.92 if pressed else 1.0) * pulse
	var c: Vector2 = center()
	var r: float = disc_radius * k
	draw_circle(c + Vector2(0, 6), r + 3.0, SHADOW)
	if track_key == SEASON:
		draw_circle(c, r, fill)
		draw_arc(c, r - 3.0, 0.0, TAU, 96, AMBER, 6.0, true)
		RrDraw.league_cup(self, c + Vector2(0, -6), RaceRiders.league.league, r / 70.0, false)
		return
	var tex: Texture2D = RrDraw.track_picture(track_key)
	var own: bool = tex != null
	if not own:
		tex = RrDraw.picture(RrTracks.world_of(track_key))
	var pro: bool = RrTracks.is_pro(track_key) and not own
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i: int in 64:
		var a: float = TAU * float(i) / 64.0
		var d := Vector2(cos(a), sin(a))
		pts.append(c + d * r)
		uvs.append(Vector2(0.5 - d.x * 0.5 if pro else 0.5 + d.x * 0.5, 0.5 + d.y * 0.5))
	if tex != null:
		draw_colored_polygon(pts, Color(1.0, 0.72, 0.55) if pro else WHITE, uvs, tex)
	else:
		draw_colored_polygon(pts, fill)
	var pro_ring: bool = RrTracks.is_pro(track_key)
	draw_arc(c, r - 3.0, 0.0, TAU, 96, AMBER if pro_ring else WHITE, 6.0, true)
	var bc: Vector2 = c + Vector2(r * 0.62, r * 0.62)
	draw_circle(bc, r * 0.3, fill)
	draw_arc(bc, r * 0.3 - 2.0, 0.0, TAU, 40, WHITE, 5.0, true)
	RrDisc.draw_icon(self, "play", bc + Vector2(r * 0.03, 0), r * 0.16, WHITE, INK)
	var nc: Vector2 = c + Vector2(-r * 0.62, -r * 0.62)
	draw_circle(nc, r * 0.24, INK)
	draw_arc(nc, r * 0.24 - 2.0, 0.0, TAU, 32, AMBER if pro_ring else WHITE, 4.0, true)
	RrDraw.text_centered(
		self, str(RrTracks.number_of(track_key)), nc + Vector2(0, 2), int(r * 0.34), WHITE
	)
