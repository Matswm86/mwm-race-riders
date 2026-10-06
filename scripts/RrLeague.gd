class_name RrLeague
extends RefCounted

## Offline league ladder (GDD 17.2-17.4). Pure state and rules, no nodes:
## RrState owns one, saves it, and RrMain drives it. Leagues Bronze ->
## Champion, each with tiers III -> II -> I; a season is 5 rounds in one tier.
## The table is the player plus 11 named rivals of the league. Each round the
## player races the 5 rivals nearest in points; the other 6 race a seeded
## rival-only heat. Points 10/8/6/5/4/3 per heat place. Top 3 at the season
## end promote. Lett never demotes and promotes anyway after 2 stuck seasons;
## Vanlig demotes the bottom 2 only with the "Nedrykk" setting (default off).
## Rivals never score while the player is away: after 8 h they only get a
## seeded form of -0.01 / 0 / +0.01 skill for the next round (an arrow).
## Only leagues whose home world exists are playable (RrBalance.LEAGUES_BUILT);
## a player who wins the last built league stays in its tier I.

## GDD 17.7 roster: within a league, skill rises with list position.
const ROSTER: Array = [
	[
		"Ola Berg",
		"Mia Lund",
		"Sami Ray",
		"Ida Fjell",
		"Leo Park",
		"Nora Vik",
		"Emil Dahl",
		"Ava Moss",
		"Theo Kim",
		"Liv Storm",
		"Max Brook"
	],
	[
		"Selma Hart",
		"Jonas Reed",
		"Zara Quinn",
		"Aksel Holm",
		"Lea Frost",
		"Omar Vale",
		"Tuva Bay",
		"Finn Cole",
		"Ines Ruiz",
		"Kai Moon",
		"Ella Stone"
	],
	[
		"Sindre Falk",
		"Maja Wren",
		"Luca Rossi",
		"Hedda Lie",
		"Arlo Grant",
		"Sofie Nygård",
		"Ravi Shah",
		"Frida Sol",
		"Noah Pike",
		"Yuki Mori",
		"Thea Lark"
	],
	[
		"Henrik Ås",
		"Clara Dune",
		"Mateo Cruz",
		"Ingrid Skog",
		"Oscar Hale",
		"Amira Noor",
		"Elias Vang",
		"Ronja Elv",
		"Felix Byrne",
		"Saga Nord",
		"Iver Rask"
	],
	[
		"Viktor Stål",
		"Alma Bright",
		"Diego Sol",
		"Mathea Ruud",
		"Hugo Lane",
		"Leila Haddad",
		"Johan Brekke",
		"Signe Tind",
		"Rafael Costa",
		"Nina Hav",
		"Sverre Ulv"
	],
	[
		"Astrid Krone",
		"Magnus Fjord",
		"Isla Grey",
		"Tobias Rønning",
		"Elena Petrova",
		"Bjørn Stein",
		"Kaya Lin",
		"Marius Eik",
		"Selin Aydin",
		"Even Brattli",
		"Jade Rivers"
	],
]
## 11 distinct jersey hues (rule 36: always with a number and a helmet icon).
const HUES: Array[Color] = [
	Color(0.85, 0.20, 0.20),
	Color(0.95, 0.55, 0.10),
	Color(0.95, 0.80, 0.15),
	Color(0.55, 0.78, 0.20),
	Color(0.15, 0.62, 0.30),
	Color(0.10, 0.65, 0.65),
	Color(0.20, 0.55, 0.90),
	Color(0.15, 0.25, 0.70),
	Color(0.90, 0.40, 0.60),
	Color(0.55, 0.38, 0.25),
	Color(0.45, 0.48, 0.52),
]
const ICONS: Array[String] = ["star", "moon", "leaf", "drop", "triangle"]
const PARTS: Array[String] = ["wheels", "decal", "deck", "helmet", "wheels", "decal"]
const PLAYER: int = -1

var league: int = 0
## 0 = tier III, 1 = II, 2 = I.
var tier: int = 0
## Next round to race, 0-4.
var round_i: int = 0
## Seasons finished in this tier without promotion (Lett safety net).
var stuck: int = 0
var seasons: int = 0
var points: Array[int] = []
var wins: Array[int] = []
var best: Array[int] = []
var form: Array[int] = []
var my_points: int = 0
var my_wins: int = 0
var my_best: int = 9
## Places the player got this season, per round.
var my_places: Array[int] = []
## Table order (ids, PLAYER = -1) before the last round, for the slide.
var last_order: Array[int] = []
## Track key -> 11 rival best times (GDD 17.3 boards).
var boards: Dictionary = {}
var rewards: Array[String] = []
var demotion_on: bool = RrBalance.DEMOTION_DEFAULT_ON
var save_seed: int = 0
## The player has won the last built league; stays in its tier I.
var top_done: bool = false


func _init() -> void:
	_reset_season()


func _reset_season() -> void:
	points.resize(RrBalance.TABLE_RIVALS)
	points.fill(0)
	wins.resize(RrBalance.TABLE_RIVALS)
	wins.fill(0)
	best.resize(RrBalance.TABLE_RIVALS)
	best.fill(9)
	form.resize(RrBalance.TABLE_RIVALS)
	form.fill(0)
	my_points = 0
	my_wins = 0
	my_best = 9
	my_places.clear()
	round_i = 0
	last_order.clear()


# ---------------------------------------------------------------- tracks


## Home world of a league (Bronze = 1 ... Champion = 6).
static func home_world(lg: int) -> int:
	return lg + 1


## The 5 rounds of a tier (GDD 17.2). Tier II previews the next world's
## tracks 1-2; while that world is not built, home Pro tracks 2 and 4 stand in.
static func rounds_of(lg: int, tr: int) -> Array[String]:
	var w: int = home_world(lg)
	var out: Array[String] = []
	match tr:
		0:
			for k: int in [1, 2, 3, 4, 5]:
				out.append(RrTracks.key(w, k))
		1:
			for k: int in [6, 7, 8]:
				out.append(RrTracks.key(w, k))
			if w + 1 <= RrBalance.WORLDS_BUILT:
				out.append(RrTracks.key(w + 1, 1))
				out.append(RrTracks.key(w + 1, 2))
			else:
				out.append(RrTracks.key(w, 2, true))
				out.append(RrTracks.key(w, 4, true))
		_:
			for k: int in [1, 3, 5, 7, 8]:
				out.append(RrTracks.key(w, k, true))
	return out


func rounds() -> Array[String]:
	return RrLeague.rounds_of(league, tier)


func next_track() -> String:
	return rounds()[mini(round_i, RrBalance.ROUNDS_PER_SEASON - 1)]


# ---------------------------------------------------------------- rivals


static func rival_name(lg: int, i: int) -> String:
	return String(ROSTER[lg][i])


## Jersey number 2-12 and helmet icon, fixed per rival.
static func rival_number(lg: int, i: int) -> int:
	return 2 + (i * 7 + lg * 3) % 11


static func rival_icon(lg: int, i: int) -> String:
	return ICONS[(i + lg) % ICONS.size()]


static func rival_hue(lg: int, i: int) -> Color:
	return HUES[(i * 4 + lg * 5) % HUES.size()]


## Skill of rival i in league lg / tier tr (GDD 17.2): base by list position,
## + LEAGUE_SKILL_STEP per league and a third of it per tier, + Pro, + form.
static func skill_of(lg: int, tr: int, i: int, easy: bool, pro: bool, frm: int = 0) -> float:
	var base: float = (RrBalance.RIVAL_SKILL_BASE_L if easy else RrBalance.RIVAL_SKILL_BASE_V)[i]
	var step: float = RrBalance.LEAGUE_SKILL_STEP_L if easy else RrBalance.LEAGUE_SKILL_STEP_V
	var s: float = base + step * (float(lg) + float(tr) / 3.0)
	if pro:
		s += RrBalance.PRO_AI_SKILL_ADD
	return s + float(frm) * RrBalance.RIVAL_FORM_STEP


func skill(i: int, easy: bool, pro: bool) -> float:
	return RrLeague.skill_of(league, tier, i, easy, pro, form[i])


## The 5 rivals nearest the player in points (ties: the faster rival first),
## ordered slowest first, the way RrRace fills its AI slots (fastest starts
## at the front).
func heat_rivals() -> Array[int]:
	var ids: Array[int] = []
	for i: int in RrBalance.TABLE_RIVALS:
		ids.append(i)
	var me: int = my_points
	ids.sort_custom(
		func(a: int, b: int) -> bool:
			var da: int = absi(points[a] - me)
			var db: int = absi(points[b] - me)
			if da != db:
				return da < db
			return a > b
	)
	var heat: Array[int] = ids.slice(0, 5)
	heat.sort()
	return heat


func heat_skills(heat: Array[int], easy: bool, pro: bool) -> Array[float]:
	var out: Array[float] = []
	for i: int in heat:
		out.append(skill(i, easy, pro))
	return out


# ---------------------------------------------------------------- table


## 12 rows sorted by points: {id, name, points, wins, best, hue, number,
## icon, form, me}. Ties (GDD 17.2): more wins, then the better best finish,
## then the player.
func table() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	(
		rows
		. append(
			{
				"id": PLAYER,
				"name": "",
				"points": my_points,
				"wins": my_wins,
				"best": my_best,
				"me": true,
				"form": 0,
			}
		)
	)
	for i: int in RrBalance.TABLE_RIVALS:
		(
			rows
			. append(
				{
					"id": i,
					"name": RrLeague.rival_name(league, i),
					"points": points[i],
					"wins": wins[i],
					"best": best[i],
					"me": false,
					"form": form[i],
					"hue": RrLeague.rival_hue(league, i),
					"number": RrLeague.rival_number(league, i),
					"icon": RrLeague.rival_icon(league, i),
				}
			)
		)
	rows.sort_custom(RrLeague._row_before)
	return rows


static func _row_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["points"]) != int(b["points"]):
		return int(a["points"]) > int(b["points"])
	if int(a["wins"]) != int(b["wins"]):
		return int(a["wins"]) > int(b["wins"])
	if int(a["best"]) != int(b["best"]):
		return int(a["best"]) < int(b["best"])
	if bool(a["me"]) != bool(b["me"]):
		return bool(a["me"])
	return int(a["id"]) < int(b["id"])


func order_ids() -> Array[int]:
	var out: Array[int] = []
	for r: Dictionary in table():
		out.append(int(r["id"]))
	return out


## 1-based place of the player in the table.
func my_rank() -> int:
	return order_ids().find(PLAYER) + 1


# ---------------------------------------------------------------- rounds


func _rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([save_seed, league, tier, seasons, round_i, salt])
	return r


func _score(id: int, place: int) -> void:
	var p: int = RrBalance.LEAGUE_POINTS[clampi(place - 1, 0, 5)]
	if id == PLAYER:
		my_points += p
		my_best = mini(my_best, place)
		if place == 1:
			my_wins += 1
		my_places.append(place)
	else:
		points[id] += p
		best[id] = mini(best[id], place)
		if place == 1:
			wins[id] += 1


## One raced round. finish: rider index -> finish time for the player's heat
## (index 0 = player, 1-5 = heat[0..4]). Scores both heats, improves board
## times beaten by heat rivals, moves to the next round. Returns {track,
## place, points, season_over}.
func record_round(heat: Array[int], finish: Array[float], easy: bool) -> Dictionary:
	last_order = order_ids()
	var key: String = next_track()
	var pro: bool = RrTracks.is_pro(key)
	var order: Array[int] = [0, 1, 2, 3, 4, 5]
	order.sort_custom(func(a: int, b: int) -> bool: return finish[a] < finish[b])
	var my_place: int = order.find(0) + 1
	for pl: int in order.size():
		var idx: int = order[pl]
		_score(PLAYER if idx == 0 else heat[idx - 1], pl + 1)
	# Rival-only heat (seeded): time = par / skill x (1 + N(0, 0.025)).
	var rest: Array[int] = []
	for i: int in RrBalance.TABLE_RIVALS:
		if not i in heat:
			rest.append(i)
	var rng: RandomNumberGenerator = _rng(7)
	var par: float = RrTracks.par(key)
	var times: Dictionary = {}
	for i: int in rest:
		times[i] = par / skill(i, easy, pro) * (1.0 + rng.randfn(0.0, RrBalance.RIVAL_HEAT_NOISE))
	rest.sort_custom(func(a: int, b: int) -> bool: return times[a] < times[b])
	for pl: int in rest.size():
		_score(rest[pl], pl + 1)
	# Boards: a heat rival who beat its board time on this track keeps it.
	if RrTracks.world_of(key) == RrLeague.home_world(league):
		var b: Array = board(key)
		for k: int in heat.size():
			var t: float = finish[k + 1]
			if t > 0.0 and t < float(b[heat[k]]):
				b[heat[k]] = snappedf(t, 0.01)
		boards[key] = b
	form.fill(0)
	round_i += 1
	return {
		"track": key,
		"place": my_place,
		"points": RrBalance.LEAGUE_POINTS[my_place - 1],
		"season_over": round_i >= RrBalance.ROUNDS_PER_SEASON,
	}


func season_over() -> bool:
	return round_i >= RrBalance.ROUNDS_PER_SEASON


## Close the season (GDD 17.2). locked = MWM Play free part: no promotion,
## the shell gets free_levels_finished instead. Returns {rank, podium (3 table
## rows), promoted, safety, demoted, reward, league, tier, top_done, locked}.
func end_season(easy: bool, locked: bool) -> Dictionary:
	var rows: Array[Dictionary] = table()
	var rank: int = my_rank()
	var res: Dictionary = {
		"rank": rank,
		"podium": rows.slice(0, 3),
		"promoted": false,
		"safety": false,
		"demoted": false,
		"reward": "",
		"from_league": league,
		"from_tier": tier,
		"locked": locked,
	}
	seasons += 1
	if locked:
		stuck = 0
	else:
		var up: bool = rank <= RrBalance.PROMOTE_TOP
		if not up and easy and stuck >= RrBalance.LETT_SAFETY_SEASONS:
			up = true
			res["safety"] = true
		if up:
			res["promoted"] = true
			res["reward"] = _promote()
		else:
			stuck += 1
			var bottom: bool = rank > RrBalance.TABLE_RIVALS + 1 - RrBalance.VANLIG_DEMOTE_BOTTOM
			if not easy and demotion_on and bottom and tier > 0:
				tier -= 1
				stuck = 0
				res["demoted"] = true
	res["league"] = league
	res["tier"] = tier
	res["top_done"] = top_done
	_reset_season()
	return res


## Move up one tier (after tier I: the next league, if its world is built).
## Returns the reward id (GDD 17.4): paint:<league> (III -> II), part:<name>
## (II -> I), trophy:<league> (league won, with its jersey).
func _promote() -> String:
	stuck = 0
	var reward: String
	var won: int = league
	if tier < RrBalance.TIERS_PER_LEAGUE - 1:
		reward = "paint:%d" % league if tier == 0 else "part:%s" % PARTS[league]
		tier += 1
	else:
		reward = "trophy:%d" % league
		if league + 1 < RrBalance.LEAGUES_BUILT:
			league += 1
			tier = 0
		else:
			top_done = true
	if not reward in rewards:
		rewards.append(reward)
	if reward.begins_with("trophy:") and not ("jersey:%d" % won) in rewards:
		rewards.append("jersey:%d" % won)
	return reward


# ---------------------------------------------------------------- boards


## 11 rival best times on track k (GDD 17.3): seeded par / skill x
## (1 + N(0, 0.015)) for the league whose home world k belongs to, then
## improved by heat results.
func board(k: String) -> Array:
	if boards.has(k):
		return boards[k]
	var lg: int = RrTracks.world_of(k) - 1
	var r := RandomNumberGenerator.new()
	r.seed = hash([save_seed, k])
	var out: Array = []
	var par: float = RrTracks.par(k)
	for i: int in RrBalance.TABLE_RIVALS:
		var s: float = RrLeague.skill_of(lg, 0, i, true, RrTracks.is_pro(k))
		out.append(snappedf(par / s * (1.0 + r.randfn(0.0, RrBalance.BOARD_TIME_NOISE)), 0.01))
	boards[k] = out
	return out


# ---------------------------------------------------------------- away


## GDD 17.2 "between sessions": 8 h or more away gives every rival a seeded
## form of -1, 0 or +1 for the next round. Points never change while away.
func apply_away(hours: float, salt: int) -> bool:
	if hours < RrBalance.RIVAL_FORM_AWAY_H:
		return false
	var r: RandomNumberGenerator = _rng(salt)
	for i: int in RrBalance.TABLE_RIVALS:
		form[i] = r.randi_range(-1, 1)
	return true


# ---------------------------------------------------------------- save


func to_dict() -> Dictionary:
	return {
		"league": league,
		"tier": tier,
		"season_round": round_i,
		"seasons_in_tier": stuck,
		"seasons": seasons,
		"table":
		{
			"points": points,
			"wins": wins,
			"best": best,
			"form": form,
			"me": [my_points, my_wins, my_best],
			"my_places": my_places,
		},
		"boards": boards,
		"rewards": rewards,
		"demotion_on": demotion_on,
		"save_seed": save_seed,
		"top_done": top_done,
	}


func from_dict(d: Dictionary) -> void:
	league = clampi(int(d.get("league", 0)), 0, RrBalance.LEAGUES_BUILT - 1)
	tier = clampi(int(d.get("tier", 0)), 0, RrBalance.TIERS_PER_LEAGUE - 1)
	round_i = clampi(int(d.get("season_round", 0)), 0, RrBalance.ROUNDS_PER_SEASON)
	stuck = maxi(0, int(d.get("seasons_in_tier", 0)))
	seasons = maxi(0, int(d.get("seasons", 0)))
	var t: Dictionary = d.get("table", {})
	_fill(points, t.get("points", []), 0)
	_fill(wins, t.get("wins", []), 0)
	_fill(best, t.get("best", []), 9)
	_fill(form, t.get("form", []), 0)
	var me: Array = t.get("me", [0, 0, 9])
	if me.size() >= 3:
		my_points = int(me[0])
		my_wins = int(me[1])
		my_best = int(me[2])
	my_places.clear()
	for p: Variant in t.get("my_places", []):
		my_places.append(int(p))
	var b: Variant = d.get("boards", {})
	boards = b if b is Dictionary else {}
	rewards.clear()
	for r: Variant in d.get("rewards", []):
		rewards.append(String(r))
	demotion_on = bool(d.get("demotion_on", RrBalance.DEMOTION_DEFAULT_ON))
	save_seed = int(d.get("save_seed", 0))
	top_done = bool(d.get("top_done", false))


static func _fill(dst: Array[int], src: Variant, fallback: int) -> void:
	for i: int in dst.size():
		dst[i] = fallback
		if src is Array and i < (src as Array).size():
			dst[i] = int(src[i])
