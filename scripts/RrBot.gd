class_name RrBot
extends RefCounted

## Test and demo drivers (never used in play). skilled_steer steers for every
## pad and around every hay bale, mud puddle and sand drift, the way GDD 7.4
## models a skilled player. knocker_steer rides like that too but holds
## toward any rival riding beside it (GDD 14 acceptance: a bot that holds
## toward every rival it passes).


static func skilled_steer(race: RrRace) -> int:
	var p: RrRider = race.player
	var trk: RrTrack = race.track
	var target: float = p.x
	var have: bool = false
	if p.next_pad < trk.pads.size():
		var pad: Array = trk.pads[p.next_pad]
		if float(pad[0]) - p.s < 65.0:
			target = pad[1]
			have = true
	for o: Array in RrAi.obstacles(trk):
		var ahead: float = float(o[0]) - p.s
		if float(o[1]) < p.s or ahead > 45.0:
			continue
		if String(o[4]) == "sand" and p.vehicle == RrRider.BOARD:
			continue
		var clear: float = float(o[3]) + RrBalance.RIDER_RADIUS + 0.6
		var aim: float = target if have else p.x
		if absf(aim - float(o[2])) < clear:
			var lim: float = trk.half_limit(p.s)
			var right: float = float(o[2]) + clear
			var left: float = float(o[2]) - clear
			if right > lim:
				target = left
			elif left < -lim:
				target = right
			else:
				target = right if absf(right - aim) < absf(left - aim) else left
			have = true
		break
	return _toward(p.x, target)


static func knocker_steer(race: RrRace) -> int:
	var p: RrRider = race.player
	var lim: float = race.track.half_limit(p.s)
	for r: RrRider in race.riders:
		if r.is_player or r.down() or r.finished or race.t < r.immune_until:
			continue
		var ds: float = r.s - p.s
		if absf(ds) < 1.2 and absf(r.x - p.x) < 2.6:
			return 1 if r.x >= p.x else -1
		if ds > 0.0 and ds < 13.5 and absf(r.x - p.x) < 4.0:
			# Come up beside it on its open side, then shoulder it.
			var side: float = -1.0 if r.x > 0.0 else 1.0
			return _toward(p.x, clampf(r.x + side * 1.6, -lim, lim))
	return skilled_steer(race)


static func _toward(x: float, target: float) -> int:
	var err: float = target - x
	if absf(err) < 0.35:
		return 0
	return 1 if err > 0.0 else -1
