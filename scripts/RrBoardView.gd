class_name RrBoardView
extends Control

## Track board (GDD 17.3): the track's picture and number, its three medal
## times (gold, silver, bronze flags with a stopwatch), and 12 rows: your best
## time (raced with that run's ghost) and the 11 rivals of that world's
## league, fastest first. Rival times start seeded from par and improve when
## a rival beats them in a heat against you. Big race disc = free ride on
## this track; home disc = back.

signal race_pressed(key: String)
signal back_pressed

const ROW_Y0: float = 640.0
const ROW_H: float = 56.0

var track_key: String = "w1_t1"
var race_disc: RrRaceDisc
var back_disc: RrDisc
var rows: Array[Dictionary] = []


func _ready() -> void:
	size = Vector2(RrBalance.DESIGN_W, RrBalance.DESIGN_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	race_disc = RrRaceDisc.new()
	race_disc.disc_radius = 125.0
	race_disc.size = Vector2(270, 270)
	race_disc.position = Vector2(620, 1475) - race_disc.size * 0.5
	race_disc.tapped.connect(func() -> void: race_pressed.emit(track_key))
	add_child(race_disc)
	back_disc = RrDisc.new()
	back_disc.icon = "home"
	back_disc.disc_radius = 100.0
	back_disc.size = Vector2(220, 220)
	back_disc.position = Vector2(250, 1480) - back_disc.size * 0.5
	back_disc.tapped.connect(func() -> void: back_pressed.emit())
	add_child(back_disc)
	visible = false


func show_board(key: String) -> void:
	track_key = key
	race_disc.track_key = key
	race_disc.queue_redraw()
	var lg_board: Array = RaceRiders.league.board(key)
	var lg: int = RrTracks.world_of(key) - 1
	rows.clear()
	rows.append({"me": true, "time": RaceRiders.best_time(key)})
	for i: int in lg_board.size():
		(
			rows
			. append(
				{
					"me": false,
					"time": float(lg_board[i]),
					"name": RrLeague.rival_name(lg, i),
					"hue": RrLeague.rival_hue(lg, i),
					"number": RrLeague.rival_number(lg, i),
					"icon": RrLeague.rival_icon(lg, i),
				}
			)
		)
	rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var ta: float = float(a["time"]) if float(a["time"]) > 0.0 else 9999.0
			var tb: float = float(b["time"]) if float(b["time"]) > 0.0 else 9999.0
			return ta < tb
	)
	visible = true
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-2000, -2000), Vector2(6000, 6000)), Color(0.078, 0.090, 0.110, 0.8))
	RrDraw.panel(self, Rect2(60, 250, 960, 1360))
	RrDraw.track_tile(self, Rect2(Vector2(300, 280), Vector2(480, 220)), track_key, false)
	var m: Array[float] = RrTracks.medal_times(track_key)
	for i: int in 3:
		var x: float = 250.0 + float(i) * 290.0
		RrDraw.medal_flag(self, Vector2(x - 60, 572), 30.0, i + 1)
		RrDraw.text_centered(self, RrDraw.time_text(m[i]), Vector2(x + 40, 572), 44, RrDraw.WHITE)
	var mine: int = RaceRiders.medal(track_key)
	for i: int in rows.size():
		var row: Dictionary = rows[i]
		var y: float = ROW_Y0 + float(i) * ROW_H
		var band := Rect2(Vector2(90, y - ROW_H * 0.5 + 3.0), Vector2(900, ROW_H - 6.0))
		if bool(row["me"]):
			draw_rect(band, Color(1.0, 0.69, 0.0, 0.22))
			draw_rect(band, RrDraw.AMBER, false, 3.0)
			RrDraw.player_disc(self, Vector2(200, y), 23.0)
			RrDraw.text_centered(self, "Du", Vector2(268, y + 2), 36, RrDraw.WHITE)
			RrDraw.medal_flag(self, Vector2(700, y + 4), 20.0, mine)
		else:
			if i % 2 == 0:
				draw_rect(band, Color(1, 1, 1, 0.05))
			RrDraw.jersey_disc(self, Vector2(200, y), 23.0, row["hue"], row["number"], row["icon"])
			draw_string(
				RrDraw.font("SemiBold"),
				Vector2(240, y + 12),
				String(row["name"]),
				HORIZONTAL_ALIGNMENT_LEFT,
				420,
				34
			)
		RrDraw.text_centered(
			self, str(i + 1), Vector2(130, y + 2), 38, RrDraw.WHITE, "ExtraBoldItalic"
		)
		RrDraw.clock_icon(self, Vector2(780, y), 14.0, Color(1, 1, 1, 0.6))
		var t: float = float(row["time"])
		RrDraw.text_centered(
			self, RrDraw.time_text(t), Vector2(890, y + 2), 40, RrDraw.WHITE, "Bold"
		)
