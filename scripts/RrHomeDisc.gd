class_name RrHomeDisc
extends RrDisc

## Two-tap guarded disc (GDD 3.2, DESIGN 5): the stand-alone home disc in
## the top-left shell square and the settings gear top-right, drawn from the
## HUD atlas (ink disc, 4 px white ring, soft shadow). Copies the MWM Play
## guard: the first tap grows the disc to 1.2x and fills a ring over 2.0 s
## while the race keeps running; a second tap between 0.3 s and 2.0 s
## confirms.

signal confirmed

const HALO := Color(1.0, 1.0, 1.0, 0.25)
const RING_FILL := Color(1.0, 1.0, 1.0)

static var _atlas: Texture2D

var _guard_t: float = -1.0


func _on_tapped() -> void:
	if _guard_t >= 0.0 and _guard_t <= RrBalance.GUARD_WINDOW_S.y:
		if _guard_t >= RrBalance.GUARD_WINDOW_S.x:
			_guard_t = -1.0
			queue_redraw()
			confirmed.emit()
		return
	_guard_t = 0.0
	set_process(true)
	tapped.emit()


func is_guarding() -> bool:
	return _guard_t >= 0.0


func _process(delta: float) -> void:
	_press_t += delta
	if _guard_t >= 0.0:
		_guard_t += delta
		if _guard_t > RrBalance.GUARD_WINDOW_S.y:
			_guard_t = -1.0
	queue_redraw()
	if _guard_t < 0.0 and _press_t > 0.12 and not _down:
		set_process(false)


func _draw() -> void:
	if _atlas == null:
		_atlas = load(RrHudAtlas.PATH)
	var pressed: bool = _down or _press_t < 0.1
	var k: float = 0.92 if pressed else 1.0
	var c: Vector2 = center()
	if _guard_t >= 0.0:
		k = 1.2
		draw_circle(c, 98.0, HALO)
	var e: Array = RrHudAtlas.SPRITES[icon]
	var src: Rect2 = e[0]
	var anchor: Vector2 = e[1]
	draw_texture_rect_region(_atlas, Rect2(c - anchor * k, src.size * k), src)
	if _guard_t >= 0.0:
		var g: float = clampf(_guard_t / RrBalance.GUARD_WINDOW_S.y, 0.0, 1.0)
		draw_arc(c, 68.0 * k + 8.0, -PI * 0.5, -PI * 0.5 + TAU * g, 64, RING_FILL, 8.0, true)
