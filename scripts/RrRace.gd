class_name RrRace
extends RefCounted

## One race on one world (GDD 4, 7, 10.2): the player and five rivals moved
## in track space. Pure logic with no nodes, so tests can run whole races in
## a loop. RrMain feeds it the steering input every frame and turns its
## events into sound, effects and HUD.
## Contact (GDD 4.7): the player knocks a rival off by steering into its side;
## rivals only nudge the player, who never falls and is never slowed.
## Hindrances (GDD 4.8): Block (hay), Patch (mud, sand) and Roller
## (tumbleweed); none of them makes anyone fall.

enum Phase { PRE, LIGHTS, RACE, DONE }

## DESIGN 2a: jersey colour and number per livery r1-r6 (r1 = the player).
const TEAM: Array[Color] = [
	Color(0.784, 0.125, 0.169),
	Color(0.949, 0.663, 0.000),
	Color(0.118, 0.357, 0.839),
	Color(0.059, 0.561, 0.431),
	Color(0.914, 0.925, 0.937),
	Color(0.165, 0.180, 0.208),
]
const NUMBERS: Array[int] = [7, 12, 23, 31, 4, 88]
## Roller states.
const ROLL_WAIT: int = 0
const ROLL_GO: int = 1
const ROLL_GONE: int = 2

var track: RrTrack
var easy: bool = true
var hover_on: bool = false
var riders: Array[RrRider] = []
var ais: Array[RrAi] = []
var player: RrRider
var phase: Phase = Phase.PRE
## Seconds since GO (negative before).
var t: float = 0.0
var phase_t: float = 0.0
var lights_lit: int = 0
var since_finish: float = -1.0
var all_placed: bool = false
## Race-level events for the presentation: [name, rider index, data].
var events: Array = []
## Ghost rows recorded this race: [s, x, h, vehicle] at GHOST_HZ.
var ghost_rows: Array = []
var min_speed_after_go: float = 999.0
## Rollers in flight: [state, x, dir, spin angle] per track.rollers row.
var roller_state: Array = []
## Test log: player speed right before and after every contact.
var contact_log: Array = []

var _release_t: float = -99.0
var _was_steering: bool = false
var _ghost_next: float = 0.0
var _pair_cool: Dictionary = {}
var _bale_back: PackedFloat32Array = PackedFloat32Array()
var _rng := RandomNumberGenerator.new()


## skills: the five rivals' skills, slowest first (a league heat, GDD 17.2);
## empty = the AI table (AI_SKILL_L / _V), plus PRO_AI_SKILL_ADD on Pro tracks.
func setup(
	trk: RrTrack, is_easy: bool, hover: bool, seed_v: int = -1, skills: Array[float] = []
) -> void:
	track = trk
	easy = is_easy
	hover_on = hover
	if seed_v < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_v
	riders.clear()
	ais.clear()
	player = RrRider.new()
	player.index = 0
	player.is_player = true
	player.livery = 0
	player.number = NUMBERS[0]
	player.team = TEAM[0]
	riders.append(player)
	for i: int in 5:
		var r := RrRider.new()
		r.index = i + 1
		r.livery = i + 1
		r.number = NUMBERS[i + 1]
		r.team = TEAM[i + 1]
		r.s = RrBalance.AI_START_GAP_M * float(i + 1)
		r.x = RrBalance.AI_LANE_OFFSETS[i]
		riders.append(r)
		var ai := RrAi.new()
		ai.setup(r, i, easy, _rng.randi())
		if i < skills.size():
			ai.skill = skills[i]
		elif track.pro:
			ai.skill += RrBalance.PRO_AI_SKILL_ADD
		ais.append(ai)
	_bale_back.resize(track.blocks.size())
	_bale_back.fill(-1.0)
	roller_state.clear()
	for row: Array in track.rollers:
		roller_state.append([ROLL_WAIT, 0.0, float(row[1]), 0.0])
	phase = Phase.PRE
	phase_t = 0.0
	t = -RrBalance.START_LIGHTS_S


## Touch-down in the steer zone before GO, or the auto-start timer.
func start_lights() -> void:
	if phase != Phase.PRE:
		return
	phase = Phase.LIGHTS
	phase_t = 0.0
	lights_lit = 0
	t = -RrBalance.START_LIGHTS_S


func bale_visible(i: int) -> bool:
	return _bale_back[i] < 0.0 or t >= _bale_back[i]


## Bale i burst at time; it grows back BALE_RESPAWN_S later.
func bale_back_at(i: int) -> float:
	return _bale_back[i]


func step(dt: float, steer: int, boost_tap: bool) -> void:
	phase_t += dt
	match phase:
		Phase.PRE:
			return
		Phase.LIGHTS:
			t += dt
			var lit: int = mini(3, int(phase_t / (RrBalance.START_LIGHTS_S / 3.0)) + 1)
			if lit > lights_lit:
				lights_lit = lit
				events.append(["light", 0, lit])
			if t >= 0.0:
				phase = Phase.RACE
				phase_t = t
				events.append(["go", 0, null])
			else:
				return
		_:
			t += dt
	_step_riders(dt, steer, boost_tap)


func _step_riders(dt: float, steer: int, boost_tap: bool) -> void:
	# Player input bookkeeping (Lett assist resumes ASSIST_RESUME_S after release).
	var steering: bool = steer != 0 and not player.finished
	if _was_steering and not steering:
		_release_t = t
	_was_steering = steering
	if steering:
		player.recentre_until = -99.0
	for r: RrRider in riders:
		if r.fall_t >= 0.0:
			r.fall_t += dt
		_boost(r, dt, boost_tap if r.is_player else false)
		_speed(r, dt)
		_lateral(r, dt, steer if r.is_player else 0)
		_vertical(r, dt)
		_elements(r)
	_rollers(dt)
	_bumps()
	_places()
	if not player.finished:
		min_speed_after_go = minf(min_speed_after_go, player.v if player.reached_floor else 999.0)
		if t >= _ghost_next:
			_ghost_next += 1.0 / float(RrBalance.GHOST_HZ)
			ghost_rows.append(
				[
					snappedf(player.s, 0.01),
					snappedf(player.x, 0.01),
					snappedf(player.h, 0.01),
					player.vehicle
				]
			)
	else:
		since_finish += dt
		if since_finish >= RrBalance.AI_FINISH_WAIT_S and not all_placed:
			_project_unfinished()


# ---------------------------------------------------------------- speed


func _effects(r: RrRider) -> float:
	var m: float = 1.0
	if t < r.pad_until:
		m *= r.pad_mult
	if r.boosting(t):
		m *= RrBalance.BOOST_MULT
	if t < r.land_until:
		m *= RrBalance.LAND_BONUS_MULT
	if t < r.hay_until:
		m *= RrBalance.HAY_MULT
	if t < r.bump_until:
		m *= RrBalance.BUMP_MULT_PLAYER if r.is_player else RrBalance.BUMP_MULT_AI
	return m * r.patch_mult


func _target_speed(r: RrRider) -> float:
	var mult: float = track.section_mult(r.s) * _effects(r)
	if r.vehicle == RrRider.BOARD and track.is_smooth(r.s):
		mult *= RrBalance.HOVER_SMOOTH_MULT
	# GDD 4.1: all effects together top out at SPEED_MULT_CAP (48 m/s).
	var target: float = RrBalance.CRUISE_MPS * minf(mult, RrBalance.SPEED_MULT_CAP)
	if r.rail:
		target *= RrBalance.RAIL_MULT_L if easy else RrBalance.RAIL_MULT_V
	if not r.is_player:
		target *= _ai_mult(r)
	if r.s >= track.length + RrBalance.RUNOUT_STOP_M:
		target = 0.0
	return target


func _speed(r: RrRider, dt: float) -> void:
	var was: float = r.patch_mult
	r.patch_mult = 1.0
	if r.h < 0.5 and not r.down():
		r.patch_mult = track.patch_mult(r.s, r.x, r.vehicle == RrRider.BOARD, easy)
	if r.patch_mult < 1.0 and was >= 1.0:
		events.append(["patch", r.index, null])
	if r.knocked and r.fall_t < RrBalance.FALL_DOWN_S + RrBalance.GETUP_S:
		# Thrown off: slows to a stop, lies down, gets up (GDD 4.7 fall table).
		r.v = maxf(0.0, r.v - RrBalance.FALL_DECEL * dt)
		r.s = minf(r.s + r.v * dt, track.s_max - 2.0)
		return
	var target: float = _target_speed(r)
	if target > r.v:
		var up: float = RrBalance.REJOIN_ACCEL if r.knocked else RrBalance.ACCEL_UP
		r.v = minf(target, r.v + up * dt)
	else:
		r.v = maxf(target, r.v - RrBalance.ACCEL_DOWN * dt)
	if r.knocked and r.v >= RrBalance.REJOIN_RB_OFF_FRAC * target:
		r.knocked = false
		r.fall_t = -1.0
		events.append(["rejoined", r.index, null])
	var floor_v: float = RrBalance.MIN_SPEED_FRAC * RrBalance.CRUISE_MPS
	if r.v >= floor_v:
		r.reached_floor = true
	if r.reached_floor and r.s < track.length and not r.knocked:
		r.v = maxf(r.v, floor_v)
	r.s = minf(r.s + r.v * dt, track.s_max - 2.0)


func _ai_mult(r: RrRider) -> float:
	var ai: RrAi = ais[r.index - 1]
	var m: float = ai.skill
	if player.finished or r.knocked:
		return m
	var gap_m: float = r.s - player.s
	var k: float = minf(1.0, absf(gap_m) / RrBalance.RB_RANGE_M)
	var prog: float = player.s / track.length
	var fade_from: float = RrBalance.RB_FADE_FROM_L if easy else RrBalance.RB_FADE_FROM_V
	var fade: float = 1.0
	if prog >= fade_from:
		fade = maxf(0.0, 1.0 - (prog - fade_from) / RrBalance.RB_FADE_SPAN)
	if gap_m > 0.0:
		m *= 1.0 - (RrBalance.RB_AHEAD_L if easy else RrBalance.RB_AHEAD_V) * k * fade
	else:
		m *= 1.0 + (RrBalance.RB_BEHIND_L if easy else RrBalance.RB_BEHIND_V) * k * fade
	# Clamp the AI's whole multiplier (skill x rubber band).
	return clampf(m, RrBalance.AI_MULT_CLAMP.x, RrBalance.AI_MULT_CLAMP.y)


func _boost(r: RrRider, dt: float, tap: bool) -> void:
	if r.finished or r.down():
		return
	if r.boosting(t):
		if tap:
			events.append(["notyet", r.index, null])
		return
	var fill_s: float = RrBalance.BOOST_FIRST_S if r.full_since < -0.5 else RrBalance.BOOST_REFILL_S
	if r.meter < 1.0:
		r.meter = minf(1.0, r.meter + dt / fill_s)
		if r.meter >= 1.0:
			r.full_since = t
			r.boost_delay = -1.0
			events.append(["boost_ready", r.index, null])
		elif tap:
			events.append(["notyet", r.index, null])
		return
	var fire: bool = false
	if r.is_player:
		fire = tap or (easy and t - r.full_since >= RrBalance.AUTO_BOOST_S_L)
	else:
		if r.boost_delay < 0.0:
			r.boost_delay = ais[r.index - 1].boost_wait()
		fire = t - r.full_since >= r.boost_delay
	if fire:
		fire_boost(r)


func fire_boost(r: RrRider) -> void:
	r.boost_until = t + RrBalance.BOOST_TIME_S
	r.meter = 0.0
	r.full_since = maxf(r.full_since, 0.0)
	events.append(["boost", r.index, null])


# ---------------------------------------------------------------- lateral


func _lateral(r: RrRider, dt: float, steer: int) -> void:
	var lim: float = track.half_limit(r.s)
	if r.down():
		# Slides toward the nearest rail while it slows (GDD 4.7, 0-0.5 s).
		if r.v > 0.0:
			var side: float = 1.0 if r.x >= 0.0 else -1.0
			r.x = clampf(r.x + side * RrBalance.FALL_SLIDE_LAT_MPS * dt, -lim, lim)
		r.lat_v = 0.0
		r.rail = false
		return
	var target: float = 0.0
	var rate: float = 0.0
	var hover: float = RrBalance.HOVER_STEER_MULT if r.vehicle == RrRider.BOARD else 1.0
	if r.is_player:
		if r.finished:
			target = 0.0
			rate = RrBalance.STEER_LAT_MAX / RrBalance.STEER_RELEASE_S
		elif steer != 0:
			target = float(steer) * RrBalance.STEER_LAT_MAX * hover
			rate = RrBalance.STEER_LAT_MAX * hover / RrBalance.STEER_EASE_S
		elif t < r.recentre_until:
			# After a nudge: hold still while pushed, then steer back (GDD 4.7).
			if t >= r.push_until:
				# Lett: the x it would have had is the kid line (assist resumes).
				var home: float = r.recentre_x
				if easy and t - _release_t >= RrBalance.ASSIST_RESUME_S:
					home = track.kid_x(r.s)
				var err: float = home - r.x
				target = clampf(
					err * RrBalance.ASSIST_GAIN,
					-RrBalance.RECENTRE_LAT_MPS,
					RrBalance.RECENTRE_LAT_MPS
				)
				if absf(err) < 0.05:
					r.recentre_until = -99.0
			rate = RrBalance.STEER_LAT_MAX / RrBalance.STEER_RELEASE_S
		elif easy and t - _release_t >= RrBalance.ASSIST_RESUME_S:
			target = clampf(
				(track.kid_x(r.s) - r.x) * RrBalance.ASSIST_GAIN,
				-RrBalance.ASSIST_LAT_MAX,
				RrBalance.ASSIST_LAT_MAX
			)
			rate = RrBalance.ASSIST_LAT_MAX / RrBalance.ASSIST_EASE_S
		else:
			target = 0.0
			rate = RrBalance.STEER_LAT_MAX / RrBalance.STEER_RELEASE_S
	else:
		var tx: float = ais[r.index - 1].target_x(track, riders, t)
		target = clampf(
			(tx - r.x) * RrBalance.AI_LINE_GAIN, -RrBalance.AI_LAT_MAX, RrBalance.AI_LAT_MAX
		)
		rate = RrBalance.AI_LAT_MAX / RrBalance.AI_LAT_EASE_S
	if r.airborne:
		target *= RrBalance.AIR_STEER_FRAC
	r.lat_v = move_toward(r.lat_v, target, rate * dt)
	var push: float = r.push_v if t < r.push_until else 0.0
	r.x += (r.lat_v + push) * dt
	var was_rail: bool = r.rail
	r.rail = false
	if r.x > lim:
		r.x = lim
		r.rail = r.lat_v > 0.1 or push > 0.0
	elif r.x < -lim:
		r.x = -lim
		r.rail = r.lat_v < -0.1 or push < 0.0
	if r.rail and not was_rail and not r.finished:
		events.append(["rail", r.index, null])


# ---------------------------------------------------------------- vertical


func _vertical(r: RrRider, dt: float) -> void:
	if r.airborne:
		r.air_t += dt
		r.vy -= RrBalance.GRAVITY * dt
		r.h += r.vy * dt
		if r.air_total >= RrBalance.TRICK_MIN_AIR_S:
			var start: float = 0.15
			if r.trick_t < 0.0 and r.air_t >= start:
				r.trick_t = 0.0
				r.trick_len = minf(RrBalance.TRICK_TIME_S, r.air_total - 0.3)
				events.append(["trick", r.index, r.trick_count])
			elif r.trick_t >= 0.0:
				r.trick_t += dt
		# Never land inside a gorge: hold the height until the far lip.
		if r.h <= 0.0 and r.vy < 0.0 and track.in_gap(r.s):
			r.h = 0.0
			r.vy = 0.0
		elif r.h <= 0.0 and r.vy < 0.0:
			r.h = 0.0
			r.airborne = false
			r.trick_t = -1.0
			if r.air_total >= RrBalance.TRICK_MIN_AIR_S:
				r.trick_count += 1
			if r.air_total >= RrBalance.LAND_BONUS_MIN_AIR_S:
				r.land_until = t + RrBalance.LAND_BONUS_TIME_S
			events.append(["land", r.index, r.air_total])
		return
	var rh: float = track.ramp_height(r.s)
	r.on_ramp = rh > 0.0
	r.h = rh


func _launch(r: RrRider, air: float, h0: float) -> void:
	r.airborne = true
	r.on_ramp = false
	r.air_t = 0.0
	r.air_total = air
	r.h = h0
	r.vy = (RrBalance.GRAVITY * air * air * 0.5 - h0) / air
	r.trick_t = -1.0
	if air >= RrBalance.TRICK_MIN_AIR_S:
		events.append(["takeoff", r.index, air])


# ---------------------------------------------------------------- elements


func _elements(r: RrRider) -> void:
	# Pads: crossing the pad's centre with the rider inside its widened width.
	while r.next_pad < track.pads.size() and r.s >= float(track.pads[r.next_pad][0]):
		var pad: Array = track.pads[r.next_pad]
		var reach: float = RrBalance.PAD_W_M * 0.5 + RrBalance.RIDER_RADIUS
		var ok: bool = not r.finished and not r.down()
		if absf(r.x - float(pad[1])) < reach and r.h < 1.0 and ok:
			if t - r.last_pad_t < RrBalance.PAD_CHAIN_WINDOW_S:
				r.chain = mini(r.chain + 1, 3)
			else:
				r.chain = 1
			r.last_pad_t = t
			r.pad_mult = RrBalance.PAD_MULT[r.chain - 1]
			r.pad_until = t + RrBalance.PAD_TIME_S
			events.append(["pad", r.index, [r.next_pad, r.chain]])
		r.next_pad += 1
	while r.next_kick < track.kickers.size() and r.s >= track.kickers[r.next_kick]:
		if not r.airborne and not r.down():
			var air: float = track.kicker_air[r.next_kick]
			var lip: float = track.kickers[r.next_kick]
			if track.gap.x > lip and track.gap.x - lip < 10.0:
				# Gap jump: always clear the far lip, whatever the speed.
				air = maxf(air, (track.gap.y + 3.0 - r.s) / maxf(r.v, 1.0))
			_launch(r, air, RrBalance.KICKER_LIP_M)
		r.next_kick += 1
	while r.next_hay < track.blocks.size() and r.s >= float(track.blocks[r.next_hay][0]):
		var bale: Array = track.blocks[r.next_hay]
		var reach_h: float = RrTrack.HAY_HALF_W + RrBalance.RIDER_RADIUS
		if absf(r.x - float(bale[1])) < reach_h and r.h < 0.9 and bale_visible(r.next_hay):
			r.hay_until = t + RrBalance.HAY_TIME_S
			_bale_back[r.next_hay] = t + RrBalance.BALE_RESPAWN_S
			events.append(["hay", r.index, r.next_hay])
		r.next_hay += 1
	while r.next_gate < track.gates.size() and r.s >= float(track.gates[r.next_gate][0]):
		var gate: Array = track.gates[r.next_gate]
		if hover_on and r.vehicle != int(gate[1]):
			r.vehicle = gate[1]
			r.swap_t = t
			if not r.airborne:
				var air2: float = 2.0 * sqrt(2.0 * RrBalance.GRAVITY * RrBalance.SWAP_HOP_M)
				_launch(r, air2 / RrBalance.GRAVITY, 0.0)
			events.append(["swap", r.index, [r.next_gate, r.vehicle]])
		r.next_gate += 1
	if not r.finished and r.s >= track.length:
		r.finished = true
		var over: float = (r.s - track.length) / maxf(r.v, 1.0)
		r.finish_time = t - over
		if r.is_player:
			since_finish = 0.0
			phase = Phase.DONE
		events.append(["finish", r.index, r.finish_time])


## Rollers (GDD 4.8): each one starts at a rail when the player is
## ROLLER_TRIGGER_M before it, rolls across and leaves at the other rail. A
## rider it touches gets a sideways nudge (no speed loss) and it bursts.
func _rollers(dt: float) -> void:
	if phase != Phase.RACE and phase != Phase.DONE:
		return
	var lat: float = RrBalance.ROLLER_LAT_MPS_L if easy else RrBalance.ROLLER_LAT_MPS_V
	var reach: float = RrBalance.ROLLER_DIAM_M * 0.5 + RrBalance.RIDER_RADIUS
	for i: int in roller_state.size():
		var st: Array = roller_state[i]
		var rs: float = float(track.rollers[i][0])
		var dir: float = st[2]
		var hw: float = track.width(rs) * 0.5 + 0.6
		if int(st[0]) == ROLL_WAIT:
			if player.s >= rs - RrBalance.ROLLER_TRIGGER_M:
				st[0] = ROLL_GO
				st[1] = -dir * hw
				events.append(["roller_go", i, null])
			continue
		if int(st[0]) != ROLL_GO:
			continue
		st[1] = float(st[1]) + dir * lat * dt
		st[3] = float(st[3]) + dir * lat * dt / (RrBalance.ROLLER_DIAM_M * 0.5)
		if absf(float(st[1])) > hw and float(st[1]) * dir > 0.0:
			st[0] = ROLL_GONE
			continue
		for r: RrRider in riders:
			if r.finished or r.down() or r.h > 1.2:
				continue
			if absf(r.s - rs) < reach and absf(r.x - float(st[1])) < reach:
				var v0: float = r.v
				r.push_v = dir * RrBalance.ROLLER_NUDGE_MPS
				r.push_until = t + RrBalance.ROLLER_NUDGE_S
				if r.is_player:
					r.recentre_x = r.x
					r.recentre_until = t + RrBalance.ROLLER_NUDGE_S + RrBalance.RECENTRE_MAX_S
					contact_log.append(["roller", v0, r.v, t])
				st[0] = ROLL_GONE
				events.append(["roller_hit", r.index, i])
				break


## World position helper for the views: roller i as [s, x, spin], or [].
func roller_pose(i: int) -> Array:
	var st: Array = roller_state[i]
	if int(st[0]) != ROLL_GO:
		return []
	return [float(track.rollers[i][0]), float(st[1]), float(st[3])]


# ---------------------------------------------------------------- contact


func _bumps() -> void:
	if phase != Phase.RACE and phase != Phase.DONE:
		return
	for i: int in riders.size():
		var a: RrRider = riders[i]
		if a.finished or a.down():
			continue
		for j: int in range(i + 1, riders.size()):
			var b: RrRider = riders[j]
			if b.finished or b.down():
				continue
			if absf(a.s - b.s) >= RrBalance.BUMP_DS_M or absf(a.x - b.x) >= RrBalance.BUMP_DX_M:
				continue
			if absf(a.h - b.h) > 1.0:
				continue
			var key: int = i * 8 + j
			if t < float(_pair_cool.get(key, -1.0)):
				continue
			_pair_cool[key] = t + RrBalance.BUMP_PAIR_COOLDOWN_S
			if a.is_player:
				_player_contact(a, b)
			else:
				_rival_bump(a, b)


## GDD 4.7 order: a qualifying side hit knocks the rival off; anything else
## is a nudge on the player (pushed away, then auto-recentred, no slow-down).
func _player_contact(p: RrRider, r: RrRider) -> void:
	var toward: float = 1.0 if r.x >= p.x else -1.0
	if absf(r.x - p.x) < 0.01:
		toward = 1.0 if p.lat_v >= 0.0 else -1.0
	var thr: float = RrBalance.KNOCK_LAT_MIN_L if easy else RrBalance.KNOCK_LAT_MIN_V
	var v0: float = p.v
	var side: bool = absf(r.s - p.s) < RrBalance.KNOCK_DS_M
	var ground: bool = not p.airborne and not r.airborne and p.h < 0.1 and r.h < 0.1
	var safe_spot: bool = not (r.s > track.gap.x - 30.0 and r.s < track.gap.y)
	if side and p.lat_v * toward >= thr and ground and t >= r.immune_until and safe_spot:
		_knock(r, toward)
		contact_log.append(["knock", v0, p.v, t])
		events.append(["knock", r.index, [p.s + (r.s - p.s) * 0.5, (p.x + r.x) * 0.5]])
		return
	p.push_v = -toward * RrBalance.NUDGE_PUSH_MPS
	p.push_until = t + RrBalance.NUDGE_PUSH_S
	p.recentre_x = p.x
	p.recentre_until = t + RrBalance.NUDGE_PUSH_S + RrBalance.RECENTRE_MAX_S
	r.push_v = toward * RrBalance.BUMP_PUSH_MPS
	r.push_until = t + RrBalance.BUMP_PUSH_S
	r.bump_until = t + RrBalance.BUMP_TIME_S
	contact_log.append(["nudge", v0, p.v, t])
	events.append(["nudge", 0, r.index])


func _knock(r: RrRider, dir: float) -> void:
	r.knocked = true
	r.fall_t = 0.0
	r.fall_dir = dir
	r.knock_count += 1
	r.lat_v = 0.0
	r.push_until = -99.0
	r.pad_until = -99.0
	r.boost_until = -99.0
	r.immune_until = t + RrBalance.FALL_DOWN_S + RrBalance.GETUP_S + RrBalance.KNOCK_IMMUNE_S


func _rival_bump(a: RrRider, b: RrRider) -> void:
	var dir: float = 1.0 if a.x >= b.x else -1.0
	a.push_v = RrBalance.BUMP_PUSH_MPS * dir
	b.push_v = -RrBalance.BUMP_PUSH_MPS * dir
	a.push_until = t + RrBalance.BUMP_PUSH_S
	b.push_until = t + RrBalance.BUMP_PUSH_S
	a.bump_until = t + RrBalance.BUMP_TIME_S
	b.bump_until = t + RrBalance.BUMP_TIME_S
	events.append(["bump", a.index, b.index])


func _places() -> void:
	var order: Array[RrRider] = riders.duplicate()
	order.sort_custom(_ahead)
	var before: int = player.place
	for i: int in order.size():
		order[i].place = i + 1
	if player.place < before and phase == Phase.RACE and t > 0.5:
		events.append(["overtake", 0, player.place])


static func _ahead(a: RrRider, b: RrRider) -> bool:
	if a.finished and b.finished:
		return a.finish_time < b.finish_time
	if a.finished != b.finished:
		return a.finished
	return a.s > b.s


## GDD 10.3: any AI not over the line 4 s after the player is placed by its
## projected time, so the card never shows blanks.
func _project_unfinished() -> void:
	all_placed = true
	for r: RrRider in riders:
		if not r.finished:
			r.finished = true
			r.projected = true
			var v: float = maxf(r.v, RrBalance.MIN_SPEED_FRAC * RrBalance.CRUISE_MPS)
			r.finish_time = t + (track.length - r.s) / v
	_places()


func player_progress() -> float:
	return clampf(player.s / track.length, 0.0, 1.0)


func progress_of(i: int) -> float:
	return clampf(riders[i].s / track.length, 0.0, 1.0)


## Seconds the player's meter still needs (0 = full).
func boost_fill() -> float:
	return player.meter
