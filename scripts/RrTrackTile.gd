class_name RrTrackTile
extends RrDisc

## One track on the free-ride page (GDD 17.2): its picture tile, number and
## Pro mark (RrDraw.track_tile), the medal flag earned there and the best
## time. Acts on release; the whole tile is the touch area (>= 200 px).

var track_key: String = "w1_t1"
var medal: int = 0
var best_s: float = 0.0


func _draw() -> void:
	var pressed: bool = _down or _press_t < 0.1
	var r := Rect2(Vector2.ZERO, size)
	RrDraw.track_tile(self, r, track_key, pressed)
	if best_s > 0.0:
		var band := Rect2(Vector2(10, size.y - 62), Vector2(size.x - 20, 52))
		draw_rect(band, Color(0.078, 0.090, 0.110, 0.78))
		RrDraw.text_centered(
			self, RrDraw.time_text(best_s), band.get_center() + Vector2(-14, 0), 38, WHITE
		)
	RrDraw.medal_flag(self, Vector2(size.x - 34, size.y - 40), 26.0, medal)
