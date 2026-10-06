class_name RrRace
extends RefCounted

## One race on track 1 (GDD 4, 7, 10.2): the player and five rivals moved in
## track space. Pure logic with no nodes, so tests can run whole races in a
## loop. RrMain feeds it the steering input every frame and turns its
## events into sound, effects and HUD.

enum Phase { PRE, LIGHTS, RACE, DONE }

const AI_IDS: Array[String] = ["bear", "bunny", "shark", "bobble", "unicorn"]
const TEAM: Dictionary = {
	"fox": Color(0.910, 0.255, 0.173),
	"bobble": Color(1.000, 0.761, 0.102),
	"shark": Color(0.184, 0.435, 0.894),
	"bunny": Color(0.071, 0.627, 0.561),
	"bear": Color(1.000, 0.494, 0.714),
	"unicorn": Color(0.949, 0.949, 0.933),
}

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

var _release_t: float = -99.0
var _was_steering: bool = false
var _ghost_next: float = 0.0
var _pair_cool: Dictionary = {}
var _bale_back: PackedFloat32Array = PackedFloat32Array()
var _rng := RandomNumberGenerator.new()


func setup(trk: RrTrack, is_easy: bool, hover: bool, seed_v: int = -1) -> void:
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
	player.identity = "fox"
	player.team = TEAM["fox"]
	riders.append(player)
	for i: int in 5:
		var r := RrRider.new()
		r.index = i + 1
		r.identity = AI_IDS[i]
		r.team = TEAM[r.identity]
		r.s = RrBalance.AI_START_GAP_M * float(i + 1)
		r.x = RrBalance.AI_LANE_OFFSETS[i]
		riders.append(r)
		var ai := RrAi.new()
		ai.setup(r, i, easy, _rng.randi())
		ais.append(ai)
	_bale_back.resize(RrTrack.HAY.size())
	_bale_back.fill(-1.0)
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
	for r: RrRider in riders:
		_boost(r, dt, boost_tap if r.is_player else false)
		_speed(r, dt)
		_lateral(r, dt, steer if r.is_player else 0)
		_vertical(r, dt)
		_elements(r)
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
	if t < r.boost_until:
		m *= RrBalance.BOOST_MULT
	if t < r.land_until:
		m *= RrBalance.LAND_BONUS_MULT
	if t < r.hay_until:
		m *= RrBalance.HAY_MULT
	if t < r.bump_until:
		m *= RrBalance.BUMP_MULT_PLAYER if r.is_player else RrBalance.BUMP_MULT_AI
	return m


func _speed(r: RrRider, dt: float) -> void:
	var target: float = RrBalance.CRUISE_MPS * track.section_mult(r.s) * _effects(r)
	if r.vehicle == RrRider.BOARD and track.is_smooth(r.s):
		target *= RrBalance.HOVER_SMOOTH_MULT
	if r.rail:
		target *= RrBalance.RAIL_MULT_L if easy else RrBalance.RAIL_MULT_V
	if not r.is_player:
		target *= _ai_mult(r)
	if r.s >= track.length + RrBalance.RUNOUT_STOP_M:
		target = 0.0
	if target > r.v:
		r.v = minf(target, r.v + RrBalance.ACCEL_UP * dt)
	else:
		r.v = maxf(target, r.v - RrBalance.ACCEL_DOWN * dt)
	var floor_v: float = RrBalance.MIN_SPEED_FRAC * RrBalance.CRUISE_MPS
	if r.v >= floor_v:
		r.reached_floor = true
	if r.reached_floor and r.s < track.length:
		r.v = maxf(r.v, floor_v)
	r.s = minf(r.s + r.v * dt, RrTrack.S_MAX - 2.0)


func _ai_mult(r: RrRider) -> float:
	var ai: RrAi = ais[r.index - 1]
	var m: float = ai.skill
	if player.finished:
		return m
	var gap: float = r.s - player.s
	var k: float = minf(1.0, absf(gap) / RrBalance.RB_RANGE_M)
	var prog: float = player.s / track.length
	var fade_from: float = RrBalance.RB_FADE_FROM_L if easy else RrBalance.RB_FADE_FROM_V
	var fade: float = 1.0
	if prog >= fade_from:
		fade = maxf(0.0, 1.0 - (prog - fade_from) / RrBalance.RB_FADE_SPAN)
	if gap > 0.0:
		m *= 1.0 - (RrBalance.RB_AHEAD_L if easy else RrBalance.RB_AHEAD_V) * k * fade
	else:
		m *= 1.0 + (RrBalance.RB_BEHIND_L if easy else RrBalance.RB_BEHIND_V) * k * fade
	# Clamp the AI's whole multiplier (skill x rubber band).
	return clampf(m, RrBalance.AI_MULT_CLAMP.x, RrBalance.AI_MULT_CLAMP.y)


func _boost(r: RrRider, dt: float, tap: bool) -> void:
	if r.finished:
		return
	if t < r.boost_until:
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
		if r.h <= 0.0 and r.vy < 0.0:
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
	while r.next_pad < RrTrack.PADS.size() and r.s >= float(RrTrack.PADS[r.next_pad][0]):
		var pad: Array = RrTrack.PADS[r.next_pad]
		var reach: float = RrBalance.PAD_W_M * 0.5 + RrBalance.RIDER_RADIUS
		if absf(r.x - float(pad[1])) < reach and r.h < 1.0 and not r.finished:
			if t - r.last_pad_t < RrBalance.PAD_CHAIN_WINDOW_S:
				r.chain = mini(r.chain + 1, 3)
			else:
				r.chain = 1
			r.last_pad_t = t
			r.pad_mult = RrBalance.PAD_MULT[r.chain - 1]
			r.pad_until = t + RrBalance.PAD_TIME_S
			events.append(["pad", r.index, [r.next_pad, r.chain]])
		r.next_pad += 1
	while r.next_kick < RrTrack.KICKERS.size() and r.s >= RrTrack.KICKERS[r.next_kick]:
		if not r.airborne:
			_launch(r, RrBalance.KICKER_AIR_S[r.next_kick], RrBalance.KICKER_LIP_M)
		r.next_kick += 1
	while r.next_hay < RrTrack.HAY.size() and r.s >= float(RrTrack.HAY[r.next_hay][0]):
		var bale: Array = RrTrack.HAY[r.next_hay]
		var reach_h: float = RrTrack.HAY_HALF_W + RrBalance.RIDER_RADIUS
		if absf(r.x - float(bale[1])) < reach_h and r.h < 0.9 and bale_visible(r.next_hay):
			r.hay_until = t + RrBalance.HAY_TIME_S
			_bale_back[r.next_hay] = t + RrBalance.BALE_RESPAWN_S
			events.append(["hay", r.index, r.next_hay])
		r.next_hay += 1
	while r.next_gate < RrTrack.GATES.size() and r.s >= float(RrTrack.GATES[r.next_gate][0]):
		var gate: Array = RrTrack.GATES[r.next_gate]
		if hover_on and r.vehicle != int(gate[1]):
			r.vehicle = gate[1]
			r.swap_t = t
			if not r.airborne:
				var air: float = 2.0 * sqrt(2.0 * RrBalance.GRAVITY * RrBalance.SWAP_HOP_M)
				_launch(r, air / RrBalance.GRAVITY, 0.0)
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


func _bumps() -> void:
	if phase != Phase.RACE and phase != Phase.DONE:
		return
	for i: int in riders.size():
		var a: RrRider = riders[i]
		if a.finished:
			continue
		for j: int in range(i + 1, riders.size()):
			var b: RrRider = riders[j]
			if b.finished:
				continue
			if absf(a.s - b.s) >= RrBalance.BUMP_DS_M or absf(a.x - b.x) >= RrBalance.BUMP_DX_M:
				continue
			if absf(a.h - b.h) > 1.0:
				continue
			var key: int = i * 8 + j
			if t < float(_pair_cool.get(key, -1.0)):
				continue
			_pair_cool[key] = t + RrBalance.BUMP_PAIR_COOLDOWN_S
			var dir: float = 1.0 if a.x >= b.x else -1.0
			a.push_v = RrBalance.BUMP_PUSH_MPS * dir
			b.push_v = -RrBalance.BUMP_PUSH_MPS * dir
			a.push_until = t + RrBalance.BUMP_PUSH_S
			b.push_until = t + RrBalance.BUMP_PUSH_S
			a.bump_until = t + RrBalance.BUMP_TIME_S
			b.bump_until = t + RrBalance.BUMP_TIME_S
			events.append(["bump", i, j])


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
			r.finish_time = t + (track.length - r.s) / maxf(r.v, 1.0)
	_places()


func player_progress() -> float:
	return clampf(player.s / track.length, 0.0, 1.0)


## Seconds the player's meter still needs (0 = full).
func boost_fill() -> float:
	return player.meter
