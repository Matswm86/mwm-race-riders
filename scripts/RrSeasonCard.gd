class_name RrSeasonCard
extends Control

## Season end (GDD 17.2 / 17.4), no words: the table's top 3 on a podium
## (jersey discs, names, points). Promoted: the player's disc steps up beside
## the new tier cup with its pips and an up arrow, then one tap shows the
## reward reveal (paint set, part or the league trophy with its jersey; all
## cosmetic). Not promoted: the player's place disc and a "ride again" disc,
## with no sad sound and no red. The Lett safety-net promotion looks exactly
## like a normal one. In the MWM Play free part the season simply restarts
## (the shell shows its own card). Acts on release; never advances by itself.

signal continued

const PANEL := Rect2(90, 300, 900, 1000)
const GO_C := Vector2(540, 1440)
## Paint-set colours per league (GDD 17.4 livery reward), cosmetic only.
const PAINTS: Array[Color] = [
	Color(0.10, 0.62, 0.95),
	Color(0.15, 0.70, 0.35),
	Color(0.95, 0.45, 0.10),
	Color(0.10, 0.75, 0.70),
	Color(0.95, 0.80, 0.15),
	Color(0.90, 0.20, 0.25),
]

var result: Dictionary = {}
var less_motion: bool = false
var go_disc: RrDisc
## "season" (podium) or "reward" (promotion reveal).
var step: String = "season"

var _t: float = 0.0


func _ready() -> void:
	size = Vector2(RrBalance.DESIGN_W, RrBalance.DESIGN_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	go_disc = RrDisc.new()
	go_disc.disc_radius = 120.0
	go_disc.size = Vector2(260, 260)
	go_disc.position = GO_C - go_disc.size * 0.5
	go_disc.tapped.connect(_on_go)
	add_child(go_disc)
	visible = false
	set_process(false)


func show_result(r: Dictionary) -> void:
	result = r
	step = "season"
	_t = 0.0 if not less_motion else 2.0
	go_disc.icon = "next" if bool(r.get("promoted", false)) else "replay"
	go_disc.queue_redraw()
	visible = true
	set_process(true)
	RrDisc.block_input(int(RrBalance.HOLDOVER_S * 1000.0))


func hide_card() -> void:
	visible = false
	set_process(false)


func promoted() -> bool:
	return bool(result.get("promoted", false))


func _on_go() -> void:
	if step == "season" and promoted():
		step = "reward"
		_t = 0.0 if not less_motion else 2.0
		go_disc.icon = "next"
		go_disc.queue_redraw()
		RrDisc.block_input(int(RrBalance.HOLDOVER_S * 1000.0))
		return
	continued.emit()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-2000, -2000), Vector2(6000, 6000)), Color(0, 0, 0, 0.45))
	RrDraw.panel(self, PANEL)
	if step == "reward":
		_draw_reward()
	else:
		_draw_podium()


func _draw_podium() -> void:
	var lg: int = int(result.get("from_league", 0))
	var podium: Array = result.get("podium", [])
	# Blocks: 2nd left, 1st middle (tallest), 3rd right.
	var slots: Array = [[1, Vector2(330, 760), 150.0], [0, Vector2(540, 700), 210.0]]
	slots.append([2, Vector2(750, 790), 120.0])
	var rise: float = 1.0 if less_motion else clampf(_t / 0.5, 0.0, 1.0)
	for s: Array in slots:
		var idx: int = s[0]
		if idx >= podium.size():
			continue
		var base: Vector2 = s[1]
		var h: float = float(s[2]) * rise
		var block := Rect2(Vector2(base.x - 95, 980 - h), Vector2(190, h))
		draw_rect(block, RrDraw.medal_fill(idx + 1).darkened(0.15))
		draw_rect(block, RrDraw.INK, false, 4.0)
		RrDraw.text_centered(
			self, str(idx + 1), Vector2(base.x, 980 - h * 0.5), 64, RrDraw.INK, "ExtraBoldItalic"
		)
		var row: Dictionary = podium[idx]
		var dc := Vector2(base.x, 980 - h - 70)
		if bool(row["me"]):
			RrDraw.player_disc(self, dc, 54.0)
		else:
			RrDraw.jersey_disc(self, dc, 54.0, row["hue"], int(row["number"]), String(row["icon"]))
		var nm: String = "Du" if bool(row["me"]) else String(row["name"])
		RrDraw.text_centered(self, nm, Vector2(base.x, 1020), 34, RrDraw.WHITE, "SemiBold")
		RrDraw.text_centered(self, str(int(row["points"])), Vector2(base.x, 1068), 40, RrDraw.AMBER)
	# League cup + tier pips at the top; promoted: the new tier with an arrow.
	var to_lg: int = int(result.get("league", lg))
	var to_tier: int = int(result.get("tier", 0))
	if promoted():
		RrDraw.league_cup(self, Vector2(420, 420), lg, 0.9, false)
		RrDraw.tier_pips(
			self, Vector2(420, 500), int(result["from_tier"]), 10.0, RrDraw.league_color(lg)
		)
		var bob: float = 0.0 if less_motion else 8.0 * sin(_t * TAU * 0.7)
		var up := PackedVector2Array(
			[
				Vector2(540, 380 + bob),
				Vector2(585, 430 + bob),
				Vector2(560, 430 + bob),
				Vector2(560, 470 + bob),
				Vector2(520, 470 + bob),
				Vector2(520, 430 + bob),
				Vector2(495, 430 + bob)
			]
		)
		draw_colored_polygon(up, RrDraw.GREEN)
		draw_polyline(up + PackedVector2Array([up[0]]), RrDraw.WHITE, 3.0, true)
		RrDraw.league_cup(self, Vector2(660, 420), to_lg, 1.1, false)
		RrDraw.tier_pips(self, Vector2(660, 510), to_tier, 11.0, RrDraw.league_color(to_lg))
		for i: int in 5:
			var a: float = TAU * float(i) / 5.0 + _t * 0.6
			RrDraw.star(
				self, Vector2(660, 420) + Vector2(cos(a), sin(a)) * 110.0, 16.0, RrDraw.AMBER
			)
	else:
		RrDraw.league_cup(self, Vector2(540, 420), lg, 1.0, false)
		RrDraw.tier_pips(
			self, Vector2(540, 505), int(result["from_tier"]), 11.0, RrDraw.league_color(lg)
		)
	# The player's own place when off the podium.
	var rank: int = int(result.get("rank", 1))
	if rank > 3:
		RrDraw.player_disc(self, Vector2(400, 1180), 44.0)
		RrDraw.place_disc(self, Vector2(520, 1180), rank, 44.0)


func _draw_reward() -> void:
	var rw: String = String(result.get("reward", ""))
	var c := Vector2(540, 760)
	var grow: float = 1.0 if less_motion else minf(1.0, 0.4 + _t / 0.6)
	var spin: float = 0.0 if less_motion else _t * 0.5
	draw_set_transform(c + Vector2(0, 250), 0.0, Vector2(1.0, 0.18))
	draw_circle(Vector2.ZERO, 230.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if rw.begins_with("paint:"):
		# Paint set: the bike and the board in the new livery colour.
		var col: Color = PAINTS[int(rw.get_slice(":", 1)) % PAINTS.size()]
		_bike(c + Vector2(0, -70), 1.5 * grow, col)
		RrDraw.board_icon(self, c + Vector2(0, 150), 230.0 * grow, 1.0)
		draw_rect(Rect2(c + Vector2(-190, 141) * grow, Vector2(380, 18) * grow), col)
		for k: int in 3:
			var dc: Vector2 = c + Vector2(-260 + k * 260, 300)
			draw_circle(dc, 34.0 * grow, col.lightened(0.15 * float(k) - 0.1))
			draw_arc(dc, 34.0 * grow, 0.0, TAU, 32, RrDraw.WHITE, 4.0, true)
	elif rw.begins_with("part:"):
		_wheel(c, 190.0 * grow, RrDraw.INK)
		draw_arc(c, 150.0 * grow, 0.0, TAU, 64, RrDraw.AMBER, 14.0, true)
	else:
		var lg2: int = int(rw.get_slice(":", 1)) if rw.contains(":") else 0
		RrDraw.league_cup(self, c, lg2, 3.0 * grow, false)
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0 + spin
		RrDraw.star(self, c + Vector2(cos(a), sin(a) * 0.6) * 340.0, 24.0, RrDraw.AMBER)


## Side-view bike: two wheels and a frame in the paint colour.
func _bike(c: Vector2, k: float, col: Color) -> void:
	var rw := c + Vector2(-110, 40) * k
	var fw := c + Vector2(110, 40) * k
	_wheel(rw, 62.0 * k, RrDraw.INK)
	_wheel(fw, 62.0 * k, RrDraw.INK)
	var bb := c + Vector2(-10, 40) * k
	var seat := c + Vector2(-40, -40) * k
	var head := c + Vector2(70, -50) * k
	var w: float = 14.0 * k
	for seg: Array in [[rw, bb], [bb, seat], [seat, rw], [bb, head], [seat, head], [head, fw]]:
		draw_line(seg[0], seg[1], col, w, true)
	draw_line(seat, seat + Vector2(-20, -14) * k, RrDraw.INK, 12.0 * k, true)
	draw_line(head, head + Vector2(-6, -26) * k, RrDraw.INK, 10.0 * k, true)
	draw_line(head + Vector2(-6, -26) * k, head + Vector2(26, -30) * k, RrDraw.INK, 10.0 * k, true)


func _wheel(c: Vector2, r: float, col: Color) -> void:
	draw_arc(c, r, 0.0, TAU, 64, col, r * 0.22, true)
	draw_arc(c, r * 0.9, 0.0, TAU, 64, RrDraw.WHITE, 3.0, true)
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0
		draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.85, RrDraw.WHITE, 3.0, true)
	draw_circle(c, r * 0.14, RrDraw.WHITE)
