class_name RrTrackPage
extends Control

## Track page (GDD 10.4): the stand-alone home and the shell's "home inside
## the game". One 440 x 380 card per unlocked track in a 2-column grid from
## y 300, each with its picture and its best trophy shape. Slice: one card.

signal track_chosen(track_id: int)

const INK := RrDraw.INK
const CARD_SIZE := Vector2(440, 380)

var cards: Array[RrTrackCard] = []


func _ready() -> void:
	size = Vector2(RrBalance.DESIGN_W, RrBalance.DESIGN_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func refresh() -> void:
	for c: RrTrackCard in cards:
		c.queue_free()
	cards.clear()
	var ids: Array[int] = RaceRiders.visible_tracks()
	for i: int in ids.size():
		var card := RrTrackCard.new()
		card.track_id = ids[i]
		card.best_place = int(RaceRiders.track_data(ids[i]).get("best_place", 0))
		card.size = CARD_SIZE
		card.position = Vector2(80.0 + float(i % 2) * 480.0, 300.0 + float(i / 2) * 420.0)
		card.tapped.connect(func() -> void: track_chosen.emit(card.track_id))
		add_child(card)
		cards.append(card)


func _draw() -> void:
	draw_rect(Rect2(Vector2(-2000, -2000), Vector2(6000, 6000)), Color(0.839, 0.933, 0.984, 0.55))
