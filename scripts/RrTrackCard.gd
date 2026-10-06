class_name RrTrackCard
extends RrDisc

## One card on the world page: a frame of that world from the real game and
## the best trophy shape earned there (none yet: a play badge). Acts on
## release like every disc.

var track_id: int = 1
var best_place: int = 0


func _draw() -> void:
	var pressed: bool = _down or _press_t < 0.1
	var r := Rect2(Vector2.ZERO, size)
	if pressed:
		r = r.grow(-10.0)
	var pts: PackedVector2Array = RrDraw._round_rect(r, 40.0)
	var tex: Texture2D = RrDraw.picture(track_id)
	draw_colored_polygon(pts + PackedVector2Array(), Color(0, 0, 0, 0.3))
	if tex != null:
		var uvs := PackedVector2Array()
		for p: Vector2 in pts:
			uvs.append((p - r.position) / r.size)
		draw_colored_polygon(pts, Color(1, 1, 1), uvs, tex)
	else:
		draw_colored_polygon(
			pts, Color(0.62, 0.70, 0.78) if track_id == 1 else Color(0.70, 0.40, 0.28)
		)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1), 5.0, true)
	var o: Vector2 = r.position
	if best_place > 0:
		RrDraw.place_disc(self, o + Vector2(r.size.x - 66, 66), best_place, 46.0)
	else:
		var c: Vector2 = o + r.size * 0.5
		draw_circle(c, 64.0, fill)
		draw_arc(c, 62.0, 0.0, TAU, 48, Color(1, 1, 1), 4.0, true)
		RrDisc.draw_icon(self, "play", c + Vector2(6, 0), 38.0, Color(1, 1, 1), INK)
