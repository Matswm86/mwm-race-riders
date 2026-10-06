class_name RrTrackCard
extends RrDisc

## One card on the track page: a small picture of the track (sky, hills,
## dirt trail with a pad and a pine) and the best trophy shape earned there.
## Acts on release like every disc.

var track_id: int = 1
var best_place: int = 0


func _draw() -> void:
	var pressed: bool = _down or _press_t < 0.1
	var r := Rect2(Vector2.ZERO, size)
	if pressed:
		r = r.grow(-10.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.576, 0.804, 0.949)
	sb.border_color = INK
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(40)
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	var o: Vector2 = r.position
	var w: float = r.size.x
	var h: float = r.size.y
	var hills := PackedVector2Array(
		[
			o + Vector2(8, h * 0.55),
			o + Vector2(w * 0.3, h * 0.38),
			o + Vector2(w * 0.55, h * 0.5),
			o + Vector2(w * 0.8, h * 0.34),
			o + Vector2(w - 8, h * 0.45),
			o + Vector2(w - 8, h - 30),
			o + Vector2(8, h - 30),
		]
	)
	draw_colored_polygon(hills, Color(0.490, 0.780, 0.353))
	var trail := PackedVector2Array(
		[
			o + Vector2(w * 0.47, h * 0.5),
			o + Vector2(w * 0.53, h * 0.5),
			o + Vector2(w * 0.8, h - 30),
			o + Vector2(w * 0.2, h - 30),
		]
	)
	draw_colored_polygon(trail, Color(0.827, 0.604, 0.388))
	draw_colored_polygon(
		PackedVector2Array(
			[
				o + Vector2(w * 0.43, h * 0.72),
				o + Vector2(w * 0.57, h * 0.72),
				o + Vector2(w * 0.6, h * 0.8),
				o + Vector2(w * 0.4, h * 0.8),
			]
		),
		RrDraw.SUN
	)
	for px: float in [0.15, 0.85]:
		var base: Vector2 = o + Vector2(w * px, h * 0.62)
		draw_colored_polygon(
			PackedVector2Array(
				[base + Vector2(-34, 0), base + Vector2(0, -90), base + Vector2(34, 0)]
			),
			Color(0.184, 0.561, 0.357)
		)
	# Ink border drawn again on top of the picture.
	var border := StyleBoxFlat.new()
	border.draw_center = false
	border.border_color = INK
	border.set_border_width_all(6)
	border.set_corner_radius_all(40)
	border.anti_aliasing = true
	draw_style_box(border, r)
	if best_place > 0:
		draw_circle(o + Vector2(w - 70, 70), 56.0, Color(1, 1, 1))
		draw_arc(o + Vector2(w - 70, 70), 56.0, 0, TAU, 40, INK, 5.0, true)
		RrDraw.trophy(self, o + Vector2(w - 70, 74), best_place, 0.28)
	else:
		RrDisc.draw_icon(self, "play", o + Vector2(w * 0.5, h * 0.25), 60.0, INK)
