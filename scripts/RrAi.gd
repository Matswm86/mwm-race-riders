class_name RrAi
extends RefCounted

## Brain of one rival (GDD 7.2): follows the kid line plus its lane offset,
## rolls once per pad to go for it, once per hay bale to swerve, and once per
## traffic encounter to move aside. It never aims at the player.

var rider: RrRider
var slot: int = 0
var skill: float = 1.0
var pad_seek: float = 0.3
var lane: float = 0.0
var rng := RandomNumberGenerator.new()

var _pad_rolled: int = -1
var _pad_x: float = 0.0
var _pad_s: float = -1.0
var _hay_rolled: int = -1
var _hay_shift: float = 0.0
var _hay_s: float = -1.0
var _traffic_shift: float = 0.0
var _traffic_until: float = -1.0
var _traffic_cool: Dictionary = {}


func setup(r: RrRider, slot_i: int, easy: bool, seed_v: int) -> void:
	rider = r
	slot = slot_i
	skill = (RrBalance.AI_SKILL_L if easy else RrBalance.AI_SKILL_V)[slot_i]
	pad_seek = (RrBalance.AI_PAD_SEEK_L if easy else RrBalance.AI_PAD_SEEK_V)[slot_i]
	lane = RrBalance.AI_LANE_OFFSETS[slot_i]
	rng.seed = seed_v


## Lateral target x for this frame.
func target_x(track: RrTrack, riders: Array[RrRider], t: float) -> float:
	var r: RrRider = rider
	var lim: float = track.half_limit(r.s)
	var tx: float = clampf(track.kid_x(r.s) + lane, -lim, lim)
	# Pads: one roll per pad, 30 m ahead.
	if r.next_pad < RrTrack.PADS.size():
		var pad: Array = RrTrack.PADS[r.next_pad]
		var ps: float = pad[0]
		if ps - r.s <= RrBalance.AI_PAD_LOOKAHEAD_M and _pad_rolled != r.next_pad:
			_pad_rolled = r.next_pad
			if rng.randf() < pad_seek:
				_pad_x = pad[1]
				_pad_s = ps
	if _pad_s >= 0.0:
		if r.s > _pad_s + RrBalance.PAD_L_M * 0.5:
			_pad_s = -1.0
		else:
			tx = _pad_x
	# Hay: one roll per bale that sits in the path.
	if r.next_hay < RrTrack.HAY.size():
		var bale: Array = RrTrack.HAY[r.next_hay]
		var hs: float = bale[0]
		var hx: float = bale[1]
		if hs - r.s <= RrBalance.AI_HAY_LOOKAHEAD_M and _hay_rolled != r.next_hay:
			_hay_rolled = r.next_hay
			var clear: float = RrTrack.HAY_HALF_W + RrBalance.RIDER_RADIUS
			if absf(tx - hx) < clear and rng.randf() < RrBalance.AI_HAY_AVOID:
				var dir: float = -1.0 if hx > 0.0 else 1.0
				_hay_shift = hx + dir * (clear + RrBalance.AI_HAY_SHIFT_M * 0.5) - tx
				_hay_s = hs + 1.0
	if _hay_s >= 0.0:
		if r.s > _hay_s:
			_hay_s = -1.0
			_hay_shift = 0.0
		else:
			tx += _hay_shift
	# Traffic: roll once per rider ahead, then shift for about a second.
	for o: RrRider in riders:
		if o == r or o.finished:
			continue
		var ds: float = o.s - r.s
		if ds > 0.0 and ds < RrBalance.AI_TRAFFIC_LOOK_M:
			if absf(o.x - r.x) < RrBalance.AI_TRAFFIC_DX_M and t >= _traffic_until:
				var key: int = o.index
				if t >= float(_traffic_cool.get(key, -1.0)):
					_traffic_cool[key] = t + 1.0
					if rng.randf() < RrBalance.AI_TRAFFIC_AVOID:
						var open_right: bool = (lim - o.x) > (o.x + lim)
						_traffic_shift = (
							RrBalance.AI_TRAFFIC_SHIFT_M
							if open_right
							else -RrBalance.AI_TRAFFIC_SHIFT_M
						)
						_traffic_until = t + 1.0
	if t < _traffic_until:
		tx += _traffic_shift
	tx = clampf(tx, -lim, lim)
	if _pad_s < 0.0 and r.next_pad < RrTrack.PADS.size():
		# A pad it did not roll for: ride past its edge, so pad hits stay at
		# the pad_seek rate the pack sim was tuned with.
		var skip: Array = RrTrack.PADS[r.next_pad]
		var reach: float = RrBalance.PAD_W_M * 0.5 + RrBalance.RIDER_RADIUS + 0.5
		var px: float = skip[1]
		if float(skip[0]) - r.s <= RrBalance.AI_PAD_LOOKAHEAD_M and absf(tx - px) < reach:
			var side: float = 1.0 if tx >= px else -1.0
			if absf(px + side * reach) > lim:
				side = -side
			tx = clampf(px + side * reach, -lim, lim)
	return tx


## Seconds to wait after the meter is full before firing (0.5-3.0 s).
func boost_wait() -> float:
	return rng.randf_range(RrBalance.AI_BOOST_DELAY_S.x, RrBalance.AI_BOOST_DELAY_S.y)
