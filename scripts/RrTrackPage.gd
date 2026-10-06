class_name RrTrackPage
extends Control

## Free ride (GDD 17.2): any open track or Pro variant, raced alone for no
## points, with its ghost. Two world discs at the top switch the world (only
## world 1 in the MWM Play free part); a 4 x 4 grid of track tiles shows
## tracks 1-8 and their Pro variants (warm, mirrored picture, sun-down mark),
## each with its medal flag and best time. A tile opens that track's board.
## The home disc bottom-left goes back to the league screen (the top-left
## square belongs to the shell). Every target >= 200 px, acts on release,
## nothing below y 1664.

signal board_requested(key: String)
signal back_pressed

const TILE := Vector2(210, 200)
const GRID_Y: float = 500.0

var world: int = 1
var tiles: Array[RrTrackTile] = []
var world_discs: Array[RrDisc] = []
var back_disc: RrDisc


func _ready() -> void:
	size = Vector2(RrBalance.DESIGN_W, RrBalance.DESIGN_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for w: int in range(1, RrBalance.WORLDS_BUILT + 1):
		var d := RrDisc.new()
		d.picture_world = w
		d.disc_radius = 92.0
		d.size = Vector2(210, 210)
		d.position = Vector2(540.0 + (float(w) - 1.5) * 300.0, 330.0) - d.size * 0.5
		d.tapped.connect(
			func() -> void:
				world = w
				refresh()
		)
		add_child(d)
		world_discs.append(d)
	back_disc = RrDisc.new()
	back_disc.icon = "home"
	back_disc.disc_radius = 100.0
	back_disc.size = Vector2(220, 220)
	back_disc.position = Vector2(170, 1480) - back_disc.size * 0.5
	back_disc.tapped.connect(func() -> void: back_pressed.emit())
	add_child(back_disc)
	visible = false


func refresh() -> void:
	for t: RrTrackTile in tiles:
		t.queue_free()
	tiles.clear()
	var open: Array[String] = RaceRiders.free_ride_tracks()
	var worlds_open: Array[int] = []
	for k: String in open:
		if not RrTracks.world_of(k) in worlds_open:
			worlds_open.append(RrTracks.world_of(k))
	if not world in worlds_open:
		world = worlds_open[0] if not worlds_open.is_empty() else 1
	for i: int in world_discs.size():
		world_discs[i].visible = (i + 1) in worlds_open
		world_discs[i].pulse = 1.0 if i + 1 == world else 0.82
		world_discs[i].queue_redraw()
	var n: int = 0
	for pro: bool in [false, true]:
		for k: int in range(1, RrBalance.TRACKS_PER_WORLD + 1):
			var key: String = RrTracks.key(world, k, pro)
			if not key in open:
				continue
			var row: int = (k - 1) / 4 + (2 if pro else 0)
			var col: int = (k - 1) % 4
			var tile := RrTrackTile.new()
			tile.track_key = key
			tile.medal = RaceRiders.medal(key)
			tile.best_s = RaceRiders.best_time(key)
			tile.size = TILE
			tile.position = Vector2(90.0 + float(col) * 230.0, GRID_Y + float(row) * 220.0)
			tile.tapped.connect(func() -> void: board_requested.emit(key))
			add_child(tile)
			tiles.append(tile)
			n += 1
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-2000, -2000), Vector2(6000, 6000)), Color(0.078, 0.090, 0.110, 0.72))
	# The selected world gets an amber ring.
	for i: int in world_discs.size():
		if world_discs[i].visible and i + 1 == world:
			var c: Vector2 = world_discs[i].position + world_discs[i].size * 0.5
			draw_arc(c, 104.0, 0.0, TAU, 64, RrDraw.AMBER, 6.0, true)
