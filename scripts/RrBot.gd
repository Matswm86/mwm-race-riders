class_name RrBot
extends RefCounted

## Test and demo driver (never used in play): a "skilled" rider that steers
## for every pad and around every hay bale, the way GDD 7.4 models it.


static func skilled_steer(race: RrRace) -> int:
	var p: RrRider = race.player
	var target: float = 0.0
	var have: bool = false
	if p.next_pad < RrTrack.PADS.size():
		var pad: Array = RrTrack.PADS[p.next_pad]
		if float(pad[0]) - p.s < 45.0:
			target = pad[1]
			have = true
	if not have and p.next_hay < RrTrack.HAY.size():
		var bale: Array = RrTrack.HAY[p.next_hay]
		if float(bale[0]) - p.s < 30.0 and absf(p.x - float(bale[1])) < 1.6:
			target = float(bale[1]) + (2.0 if float(bale[1]) <= 0.0 else -2.0)
			have = true
	if not have:
		target = p.x
	var err: float = target - p.x
	if absf(err) < 0.35:
		return 0
	return 1 if err > 0.0 else -1
