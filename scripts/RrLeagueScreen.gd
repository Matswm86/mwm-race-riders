class_name RrLeagueScreen
extends Control

## League screen = the home screen (GDD 17.2), usable by a child who cannot
## read: one big "race next" disc with the next track's picture, everything
## else is shapes. Top: the six league cups (the current one ringed, with its
## tier pips; leagues whose world does not exist yet are dark silhouettes).
## Middle: the 12-row table (rank digit, jersey disc with number and helmet
## icon, name for older riders and parents, form arrow after an absence,
## points); the player's row is the crimson disc on an amber band, and rows
## slide 1.5 s to their new places after a round. Then 5 round dots (done
## rounds show the place disc). Bottom: the free-ride "map" disc, the race
## disc, the next track's board. The top-left 232 px square stays empty for
## the shell, nothing is tappable at y >= 1664, every target is >= 200 px and
## acts on release (RrDisc).

signal race_pressed
signal map_pressed
signal board_pressed

const PANEL := Rect2(50, 248, 980, 1400)
const ROW_Y0: float = 462.0
const ROW_H: float = 58.0
const DOTS_Y: float = 1190.0
const CUP_Y: float = 312.0
const RACE_C := Vector2(540, 1438)
const RACE_R: float = 165.0
const SIDE_R: float = 100.0

var race_disc: RrRaceDisc
var map_disc: RrDisc
var board_disc: RrDisc
var less_motion: bool = false
## Table rows as shown (RrLeague.table()) and the slide start rank per id.
var rows: Array[Dictionary] = []
var _from_rank: Dictionary = {}
var _slide_t: float = 99.0
var _t: float = 0.0


func _ready() -> void:
	size = Vector2(RrBalance.DESIGN_W, RrBalance.DESIGN_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	race_disc = RrRaceDisc.new()
	race_disc.disc_radius = RACE_R
	race_disc.size = Vector2(RACE_R * 2.0 + 30.0, RACE_R * 2.0 + 30.0)
	race_disc.position = RACE_C - race_disc.size * 0.5
	race_disc.tapped.connect(func() -> void: race_pressed.emit())
	add_child(race_disc)
	map_disc = _side_disc("map", Vector2(170, 1460))
	map_disc.tapped.connect(func() -> void: map_pressed.emit())
	board_disc = _side_disc("board", Vector2(910, 1460))
	board_disc.tapped.connect(func() -> void: board_pressed.emit())
	visible = false
	set_process(false)


func _side_disc(icon: String, c: Vector2) -> RrDisc:
	var d := RrDisc.new()
	d.icon = icon
	d.disc_radius = SIDE_R
	d.size = Vector2(220, 220)
	d.position = c - d.size * 0.5
	add_child(d)
	return d


## Rebuild from the league; animate = slide rows from their last places.
func refresh(animate: bool) -> void:
	var lg: RrLeague = RaceRiders.league
	rows = lg.table()
	race_disc.track_key = lg.next_track()
	race_disc.queue_redraw()
	_from_rank.clear()
	if animate and not lg.last_order.is_empty() and not less_motion:
		for i: int in lg.last_order.size():
			_from_rank[lg.last_order[i]] = i
		_slide_t = 0.0
	else:
		_slide_t = 99.0
	_t = 0.0
	visible = true
	set_process(true)
	queue_redraw()


func hide_screen() -> void:
	visible = false
	set_process(false)


func sliding() -> bool:
	return _slide_t < RrBalance.TABLE_SLIDE_S


func _process(delta: float) -> void:
	_t += delta
	_slide_t += delta
	# The race disc pulses gently after 7 s of nothing (rule 18).
	var k: float = 1.0
	if _t > 7.0 and not less_motion:
		k = 1.0 + 0.04 * (0.5 - 0.5 * cos((_t - 7.0) * TAU))
	if absf(race_disc.pulse - k) > 0.001:
		race_disc.pulse = k
		race_disc.queue_redraw()
	queue_redraw()


func _row_y(i: int, id: int) -> float:
	var y: float = ROW_Y0 + float(i) * ROW_H
	if sliding() and _from_rank.has(id):
		var u: float = clampf(_slide_t / RrBalance.TABLE_SLIDE_S, 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		y = lerpf(ROW_Y0 + float(_from_rank[id]) * ROW_H, y, u)
	return y


func _draw() -> void:
	draw_rect(Rect2(Vector2(-2000, -2000), Vector2(6000, 6000)), Color(0.05, 0.06, 0.08, 0.55))
	RrDraw.panel(self, PANEL)
	var lg: RrLeague = RaceRiders.league
	var locked: bool = RaceRiders.locked()
	# League ladder: six cups; built and reached leagues in colour.
	for i: int in RrBalance.LEAGUES.size():
		var c := Vector2(540.0 + (float(i) - 2.5) * 150.0, CUP_Y)
		var reached: bool = i <= lg.league and not (locked and i > 0)
		var built: bool = i < RrBalance.LEAGUES_BUILT and not (locked and i > 0)
		if i == lg.league:
			draw_circle(c + Vector2(0, 4), 66.0, Color(1, 1, 1, 0.12))
			draw_arc(c + Vector2(0, 4), 66.0, 0.0, TAU, 64, RrDraw.AMBER, 5.0, true)
		RrDraw.league_cup(self, c, i, 0.95 if i == lg.league else 0.72, not reached)
		if built and not reached:
			# Next league that exists: its colour as an outline only.
			draw_arc(c + Vector2(0, 4), 50.0, 0.0, TAU, 48, RrDraw.league_color(i), 3.0, true)
		if i == lg.league:
			RrDraw.tier_pips(self, c + Vector2(0, 80), lg.tier, 10.0, RrDraw.league_color(i))
		if i == lg.league and lg.top_done:
			RrDraw.star(self, c + Vector2(50, -50), 22.0, RrDraw.AMBER)
	# Table.
	for i: int in rows.size():
		var row: Dictionary = rows[i]
		var y: float = _row_y(i, int(row["id"]))
		var me: bool = bool(row["me"])
		var band := Rect2(Vector2(80, y - ROW_H * 0.5 + 3.0), Vector2(920, ROW_H - 6.0))
		if me:
			draw_rect(band, Color(1.0, 0.69, 0.0, 0.22))
			draw_rect(band, RrDraw.AMBER, false, 3.0)
		elif i % 2 == 0:
			draw_rect(band, Color(1, 1, 1, 0.05))
		var rank: int = i + 1
		var rank_col: Color = RrDraw.medal_fill(rank) if rank <= 3 else Color(1, 1, 1, 0.8)
		RrDraw.text_centered(self, str(rank), Vector2(122, y + 2), 40, rank_col, "ExtraBoldItalic")
		var dc := Vector2(196, y)
		if me:
			RrDraw.player_disc(self, dc, 25.0)
			RrDraw.text_centered(self, "Du", Vector2(268, y + 2), 38, RrDraw.WHITE, "Bold")
		else:
			RrDraw.jersey_disc(self, dc, 25.0, row["hue"], int(row["number"]), String(row["icon"]))
			var f: Font = RrDraw.font("SemiBold")
			draw_string(
				f, Vector2(238, y + 13), String(row["name"]), HORIZONTAL_ALIGNMENT_LEFT, 520, 36
			)
			RrDraw.form_arrow(self, Vector2(820, y), 14.0, int(row["form"]))
		var pts: String = str(int(row["points"]))
		RrDraw.text_centered(self, pts, Vector2(930, y + 2), 42, RrDraw.WHITE, "Bold")
	# Round dots: done rounds show the place disc, the next one a pulsing ring.
	for r: int in RrBalance.ROUNDS_PER_SEASON:
		var c2 := Vector2(540.0 + (float(r) - 2.0) * 96.0, DOTS_Y)
		if r < lg.my_places.size():
			RrDraw.place_disc(self, c2, lg.my_places[r], 28.0)
		elif r == lg.round_i:
			var pr: float = 30.0 + (0.0 if less_motion else 3.0 * sin(_t * TAU * 0.8))
			draw_circle(c2, pr, Color(1, 1, 1, 0.15))
			draw_arc(c2, pr, 0.0, TAU, 40, RrDraw.WHITE, 5.0, true)
		else:
			draw_arc(c2, 22.0, 0.0, TAU, 32, Color(1, 1, 1, 0.35), 4.0, true)
