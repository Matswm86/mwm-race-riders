class_name RrAi
extends RefCounted

## Brain of one rival (GDD 7.2): follows the kid line plus its lane offset,
## rolls once per pad to go for it, once per hindrance (hay bale, mud, sand
## drift) to swerve, and once per traffic encounter to move aside. Rollers
## are ignored. In Vanlig it now and then leans in toward the player riding
## beside it (GDD 4.7); in Lett it never aims at the player.

var rider: RrRider
var slot: int = 0
var skill: float = 1.0
var pad_seek: float = 0.3
var lane: float = 0.0
var easy: bool = true
var rng := RandomNumberGenerator.new()

var _pad_rolled: int = -1
var _pad_x: float = 0.0
var _pad_s: float = -1.0
var _obst: Array = []
var _obst_i: int = 0
var _obst_rolled: int = -1
var _obst_shift: float = 0.0
var _obst_end: float = -1.0
var _traffic_shift: float = 0.0
var _traffic_until: float = -1.0
var _traffic_cool: Dictionary = {}
var _lean_next: float = 0.0
var _lean_until: float = -1.0
var _lean_dir: float = 0.0


func setup(r: RrRider, slot_i: int, is_easy: bool, seed_v: int) -> void:
	rider = r
	slot = slot_i
	easy = is_easy
	skill = (RrBalance.AI_SKILL_L if easy else RrBalance.AI_SKILL_V)[slot_i]
	pad_seek = (RrBalance.AI_PAD_SEEK_L if easy else RrBalance.AI_PAD_SEEK_V)[slot_i]
	lane = RrBalance.AI_LANE_OFFSETS[slot_i]
	rng.seed = seed_v


## Blocks and patches as [s_from, s_to, x_centre, half_width, kind], by s.
static func obstacles(track: RrTrack) -> Array:
	var out: Array = []
	for b: Array in track.blocks:
		out.append([float(b[0]) - 0.6, float(b[0]) + 0.6, float(b[1]), RrTrack.HAY_HALF_W, "hay"])
	for p: Array in track.patches:
		var x0: float = p[2]
		var x1: float = p[3]
		out.append([float(p[0]), float(p[1]), (x0 + x1) * 0.5, (x1 - x0) * 0.5, String(p[4])])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return out


## Lateral target x for this frame.
func target_x(track: RrTrack, riders: Array[RrRider], t: float) -> float:
	var r: RrRider = rider
	if _obst.is_empty() and (not track.blocks.is_empty() or not track.patches.is_empty()):
		_obst = RrAi.obstacles(track)
	var lim: float = track.half_limit(r.s)
	var tx: float = clampf(track.kid_x(r.s) + lane, -lim, lim)
	# Pads: one roll per pad, 30 m ahead.
	if r.next_pad < track.pads.size():
		var pad: Array = track.pads[r.next_pad]
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
	tx = _avoid(tx, t)
	# Traffic: roll once per rider ahead, then shift for about a second.
	for o: RrRider in riders:
		if o == r or o.finished or o.down():
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
	tx = _lean_in(tx, riders[0], t)
	tx = RrAi.off_island(track, r.s + 8.0, clampf(tx, -lim, lim))
	if _pad_s < 0.0 and r.next_pad < track.pads.size():
		# A pad it did not roll for: ride past its edge, so pad hits stay at
		# the pad_seek rate the pack sim was tuned with.
		var skip: Array = track.pads[r.next_pad]
		var reach: float = RrBalance.PAD_W_M * 0.5 + RrBalance.RIDER_RADIUS + 0.5
		var px: float = skip[1]
		if float(skip[0]) - r.s <= RrBalance.AI_PAD_LOOKAHEAD_M and absf(tx - px) < reach:
			var side: float = 1.0 if tx >= px else -1.0
			if absf(px + side * reach) > lim:
				side = -side
			tx = clampf(px + side * reach, -lim, lim)
	return tx


## W5 split path: a target on the island moves to its nearer edge (the
## rider picks the route it is closer to).
static func off_island(track: RrTrack, s: float, tx: float) -> float:
	var isl: Vector2 = track.island(s)
	if isl.x >= isl.y:
		return tx
	var lo: float = isl.x - RrBalance.RIDER_RADIUS - 0.3
	var hi: float = isl.y + RrBalance.RIDER_RADIUS + 0.3
	if tx > lo and tx < hi:
		return lo if tx - lo < hi - tx else hi
	return tx


## Blocks and patches: one roll (AI_HAY_AVOID) per hindrance in the path,
## then a swerve to the more open side until it is passed.
func _avoid(tx: float, _t: float) -> float:
	var r: RrRider = rider
	while _obst_i < _obst.size() and r.s > float(_obst[_obst_i][1]):
		_obst_i += 1
	if _obst_i < _obst.size():
		var o: Array = _obst[_obst_i]
		var os: float = o[0]
		var ox: float = o[2]
		var half: float = o[3]
		var floats: bool = RrTrack.board_ignores(String(o[4])) and r.vehicle == RrRider.BOARD
		if os - r.s <= RrBalance.AI_HAY_LOOKAHEAD_M and _obst_rolled != _obst_i and not floats:
			_obst_rolled = _obst_i
			var clear: float = half + RrBalance.RIDER_RADIUS
			if absf(tx - ox) < clear and rng.randf() < RrBalance.AI_HAY_AVOID:
				var dir: float = -1.0 if ox > 0.0 else 1.0
				_obst_shift = ox + dir * (clear + RrBalance.AI_HAY_SHIFT_M * 0.5) - tx
				_obst_end = float(o[1]) + 1.0
	if _obst_end >= 0.0:
		if r.s > _obst_end:
			_obst_end = -1.0
			_obst_shift = 0.0
		else:
			tx += _obst_shift
	return tx


## Vanlig only (GDD 4.7): riding beside the player, roll RIVAL_LEAN_IN_V every
## RIVAL_LEAN_IN_EVERY_S to lean RIVAL_LEAN_IN_M toward them. Never in Lett.
func _lean_in(tx: float, p: RrRider, t: float) -> float:
	var r: RrRider = rider
	var chance: float = RrBalance.RIVAL_LEAN_IN_L if easy else RrBalance.RIVAL_LEAN_IN_V
	if t < _lean_until:
		return r.x + _lean_dir * RrBalance.RIVAL_LEAN_IN_M
	if chance <= 0.0 or p.finished or t < _lean_next:
		return tx
	if absf(p.s - r.s) < 1.0 and absf(p.x - r.x) < 2.0:
		_lean_next = t + RrBalance.RIVAL_LEAN_IN_EVERY_S
		if rng.randf() < chance:
			_lean_dir = 1.0 if p.x >= r.x else -1.0
			_lean_until = t + 0.5
			return r.x + _lean_dir * RrBalance.RIVAL_LEAN_IN_M
	return tx


## Seconds to wait after the meter is full before firing (0.5-3.0 s).
func boost_wait() -> float:
	return rng.randf_range(RrBalance.AI_BOOST_DELAY_S.x, RrBalance.AI_BOOST_DELAY_S.y)
