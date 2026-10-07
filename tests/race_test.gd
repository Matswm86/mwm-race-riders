# gdlint: disable=max-file-lines
extends Node

## Headless race test. Run with a throwaway user dir, at portrait size:
##   XDG_DATA_HOME=<tmp> godot --headless --audio-driver Dummy --resolution 1080x1920 \
##     res://tests/race_test.tscn
## 1. Every built track (48 base + 48 Pro, worlds 1-6): the bake is current
##    (base tracks), idle Lett finishes in 41-51 s every run (owner 10-07)
##    and in the top 3 in >= 9 of 10 runs (GDD 14; Pro: >= 4 of 5, rivals +0.01),
##    never rides through a mud/sand patch, never drops under 18 m/s, and no
##    pad, hindrance or roller lies inside a landing slope (GDD 6.3).
## 2. Track 1 of every world: idle Vanlig, skilled Vanlig bot (GDD 14),
##    knock-off bot (GDD 4.7); ghost fade, flash limiter. World features: the
##    W3 ice and W6 steel slide without slowing, the W4 vent launches only
##    while it puffs, the W5 island keeps riders on a route, W6 rings speed.
## 3. League rules (GDD 17.2): Vanlig demotion is off by default and only
##    demotes when switched on; Lett never demotes and promotes anyway after
##    2 stuck seasons; rivals do not score while the player is away (form
##    arrows only after 8 h); the MWM Play free part is the Bronze III season
##    and its season end sends free_levels_finished instead of promoting;
##    a version-1 (two-world) save migrates without losing anything; a
##    version-2 save (Bronze/Silver ladder) migrates to version 3, a Silver
##    winner moving on to Gold III; an idle Lett rider climbs the whole ladder
##    Bronze III -> Champion I in real races and is never demoted.
## 4. Touch targets of the league screen, track page, board and season card:
##    >= 200 px, nothing in the shell's top-left 232 px square, nothing at
##    y >= 1664.
## 5. The real Main scene with no steering input at all: race 1 starts by
##    itself on world 1 track 1 (Bronze III round 1), the card's next disc
##    opens the league table, its race disc starts the next round on a
##    different track; a whole Bronze III season of 5 rounds promotes to
##    Bronze II with the paint-set reward; ghosts are per track.
## Prints PASS/FAIL per check and "RACE TEST PASS" / "RACE TEST FAIL".

var fails: int = 0
var free_signals: int = 0


func _ready() -> void:
	RaceRiders.reset_all()
	RaceRiders.easy = true
	RaceRiders.ghost_on = true
	_bake_check()
	_all_tracks()
	for w: int in range(1, RrBalance.WORLDS_BUILT + 1):
		_sim_batches(w)
		_knock_batch(w)
	_feature_checks()
	_ghost_fade_check()
	_flash_check()
	_league_rules()
	_lock_check()
	_rotation_rules()
	_away_check()
	_migration_check()
	_migration_v2_check()
	_ladder_climb()
	RaceRiders.reset_all()
	RaceRiders.easy = true
	await _main_checks()
	print("RACE TEST %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	Engine.time_scale = 1.0
	get_tree().quit(1 if fails > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


## Runs one race in the pure sim. strat: "idle", "skilled" or "knock".
## w: a world id (= its track 1) or a track key.
func _run(
	w: Variant, easy: bool, hover: bool, strat: String, seed_v: int, skills: Array[float] = []
) -> RrRace:
	var race := RrRace.new()
	race.setup(RrTrack.new(w), easy, hover, seed_v, skills)
	race.start_lights()
	race.set_meta(&"patch_frames", 0)
	race.set_meta(&"player_down", false)
	race.set_meta(&"reknock", 0)
	var last_ride: Dictionary = {}
	var n: int = 0
	while race.phase != RrRace.Phase.DONE and n < 60 * 120:
		var steer: int = 0
		var tap: bool = false
		if strat == "skilled":
			steer = RrBot.skilled_steer(race)
			tap = race.player.meter >= 1.0
		elif strat == "knock":
			steer = RrBot.knocker_steer(race)
			tap = race.player.meter >= 1.0
		race.step(1.0 / 60.0, steer, tap)
		for e: Array in race.events:
			if e[0] == "knock":
				var who: int = e[1]
				# Riding again at fall 1.7 s; a new knock needs 6 s after that.
				if last_ride.has(who) and race.t - float(last_ride[who]) < RrBalance.KNOCK_IMMUNE_S:
					race.set_meta(&"reknock", int(race.get_meta(&"reknock")) + 1)
				last_ride[who] = race.t + RrBalance.FALL_DOWN_S + RrBalance.GETUP_S
		race.events.clear()
		if race.player.patch_mult < 1.0:
			race.set_meta(&"patch_frames", int(race.get_meta(&"patch_frames")) + 1)
		if race.player.fall_t >= 0.0 or race.player.knocked:
			race.set_meta(&"player_down", true)
		n += 1
	# Let the pack finish so the margin is known.
	var extra: int = 0
	while not race.all_placed and extra < 60 * 10:
		race.step(1.0 / 60.0, 0, false)
		race.events.clear()
		extra += 1
	return race


func _sim_batches(w: int) -> void:
	print("--- world %d" % w)
	var times: Array[float] = []
	var places: Array[int] = []
	var min_v: float = 999.0
	var sand: int = 0
	for k: int in 10:
		var r: RrRace = _run(RrTracks.key(w, 1), true, w >= 2, "idle", 500 + k)
		times.append(snappedf(r.player.finish_time, 0.1))
		places.append(r.player.place)
		min_v = minf(min_v, r.min_speed_after_go)
		sand += int(r.get_meta(&"patch_frames"))
	var in_window: bool = true
	for t: float in times:
		in_window = in_window and t >= 41.0 and t <= 51.0
	var top3: int = places.filter(func(p: int) -> bool: return p <= 3).size()
	print("idle Lett times %s places %s" % [times, places])
	_check(in_window, "idle Lett: every race finishes in 41-51 s")
	_check(top3 >= 9, "idle Lett: top 3 in %d of 10 (need 9)" % top3)
	_check(min_v >= 17.99, "speed never below 18 m/s after GO (min %.2f)" % min_v)
	_check(sand == 0, "idle Lett never rides through a mud/sand patch (%d frames)" % sand)
	var par: float = RrTracks.par(RrTracks.key(w, 1))
	var med: int = RrTracks.medal_for(RrTracks.key(w, 1), times[0])
	print(
		(
			"W%d par %.1f s, idle Lett %.1f s earns medal %d (GDD 17.3 example: silver)"
			% [w, par, times[0], med]
		)
	)
	times.clear()
	places.clear()
	for k: int in 10:
		var r2: RrRace = _run(RrTracks.key(w, 1), false, true, "idle", 600 + k)
		times.append(snappedf(r2.player.finish_time, 0.1))
		places.append(r2.player.place)
	print("idle Vanlig times %s places %s" % [times, places])
	_check(times.max() <= 55.0, "idle Vanlig: finishes inside 55 s")
	var wins: int = 0
	var margins: Array[float] = []
	for k: int in 10:
		var r3: RrRace = _run(RrTracks.key(w, 1), false, true, "skilled", 700 + k)
		var second: float = 999.0
		for o: RrRider in r3.riders:
			if not o.is_player:
				second = minf(second, o.finish_time)
		var m: float = second - r3.player.finish_time
		margins.append(snappedf(m, 0.01))
		if r3.player.place == 1 and m >= 1.5:
			wins += 1
	print("skilled Vanlig margins %s" % [margins])
	# GDD 14 hint (from the 1D pack sim): wins by >= 1.5 s in 9 of 10. Reported,
	# not enforced: rivals on a pad chain cannot leave the line between pads
	# 12 m apart, so the spatial sim's pack is faster than the 1D model.
	print("INFO  skilled Vanlig bot wins by >= 1.5 s in %d of 10 (GDD hint 9)" % wins)
	var all_win: bool = margins.all(func(m: float) -> bool: return m > 0.0)
	_check(all_win, "skilled Vanlig bot wins every race")


## GDD 4.7 / 14: a bot that holds toward every rival it passes knocks off at
## least 2 per race, the player is never knocked off and never slowed by any
## contact, and no rival is knocked again inside its immunity.
func _knock_batch(w: int) -> void:
	var counts: Array[int] = []
	var slowed: int = 0
	var contacts: int = 0
	var down: bool = false
	var reknock: int = 0
	for k: int in 10:
		var r: RrRace = _run(RrTracks.key(w, 1), k % 2 == 0, true, "knock", 800 + k)
		var c: int = 0
		for o: RrRider in r.riders:
			c += o.knock_count
		counts.append(c)
		for e: Array in r.contact_log:
			contacts += 1
			if float(e[2]) < float(e[1]) - 0.0001:
				slowed += 1
		down = down or bool(r.get_meta(&"player_down"))
		reknock += int(r.get_meta(&"reknock"))
	var two: int = counts.filter(func(c: int) -> bool: return c >= 2).size()
	print("knock bot W%d knock-offs per race %s, player contacts %d" % [w, counts, contacts])
	_check(two >= 8, "knock bot knocks off >= 2 rivals in %d of 10 races (need 8)" % two)
	_check(not down, "the player is never knocked off")
	_check(slowed == 0, "player speed never drops on contact (%d of %d)" % [slowed, contacts])
	_check(reknock == 0, "no rival re-knocked inside its 6 s immunity (%d)" % reknock)


## GDD 6.3: no pad, hindrance or roller inside a landing slope (lip + 18*air
## - 3 to lip + 48*air + 5); hindrances also not in the 30 m after it.
func _landing_bad(trk: RrTrack) -> Array:
	var bad: Array = []
	for k: int in trk.kickers.size():
		var lip: float = trk.kickers[k]
		var air: float = trk.kicker_air[k]
		var a: float = lip + 18.0 * air - 3.0
		var b: float = lip + 48.0 * air + 5.0
		var items: Array = []
		for pad: Array in trk.pads:
			items.append(["pad", float(pad[0]), 0.0])
		for bl: Array in trk.blocks:
			items.append(["hay", float(bl[0]), RrBalance.LANDING_CLEAR_AFTER_M])
		for pa: Array in trk.patches:
			items.append(["patch", float(pa[0]), RrBalance.LANDING_CLEAR_AFTER_M])
		for ro: Array in trk.rollers:
			items.append(["roller", float(ro[0]), RrBalance.LANDING_CLEAR_AFTER_M])
		for hp: float in trk.hops:
			items.append(["hop", hp, RrBalance.LANDING_CLEAR_AFTER_M])
		for it: Array in items:
			if float(it[1]) > a and float(it[1]) < b + float(it[2]):
				bad.append("%s s %.0f in K%d slope %.0f-%.0f" % [it[0], it[1], k + 1, a, b])
	return bad


## Every built track: idle Lett (no input) 10 runs on base tracks, 5 on Pro.
func _all_tracks() -> void:
	print("--- all tracks, idle Lett")
	var keys: Array[String] = RrTracks.all_keys(true)
	var n_all: int = RrBalance.WORLDS_BUILT * RrBalance.TRACKS_PER_WORLD * 2
	_check(
		keys.size() == 96 and n_all == 96,
		"96 races registered (48 base + 48 Pro): %d" % keys.size()
	)
	var summary: Array = []
	var lengths_ok: bool = true
	for key: String in keys:
		var trk := RrTrack.new(key)
		var want: float = (
			RrBalance.WORLD_LENGTH_M[trk.world_id - 1]
			+ RrBalance.TRACK_STEP_W[trk.world_id - 1] * float(trk.number - 1)
		)
		lengths_ok = lengths_ok and absf(trk.length - want) < 0.5 and RrTracks.exists(key)
		var runs: int = 5 if trk.pro else 10
		var times: Array[float] = []
		var places: Array[int] = []
		var min_v: float = 999.0
		var patch: int = 0
		for k: int in runs:
			var r: RrRace = _run(key, true, true, "idle", 900 + k)
			times.append(snappedf(r.player.finish_time, 0.1))
			places.append(r.player.place)
			min_v = minf(min_v, r.min_speed_after_go)
			patch += int(r.get_meta(&"patch_frames"))
		var bad: Array = _landing_bad(trk)
		var ok_t: bool = times.all(func(t: float) -> bool: return t >= 41.0 and t <= 51.0)
		var top3: int = places.filter(func(p: int) -> bool: return p <= 3).size()
		var ok_p: bool = top3 >= runs - 1
		print(
			(
				"%-6s L %4.0f par %.1f times %s places %s patch %d min v %.1f landing %s"
				% [
					key,
					trk.length,
					RrTracks.par(key),
					times,
					places,
					patch,
					min_v,
					"clear" if bad.is_empty() else str(bad)
				]
			)
		)
		_check(
			ok_t and ok_p and patch == 0 and min_v >= 17.99 and bad.is_empty(),
			(
				"%s: idle Lett 41-51 s, top 3 in %d of %d, no patch, >= 18 m/s, landing clear"
				% [key, top3, runs]
			)
		)
		summary.append("%s %.1f-%.1f s top3 %d/%d" % [key, times.min(), times.max(), top3, runs])
	print("TRACK TABLE (idle Lett, time range, top 3):")
	for line: String in summary:
		print("  " + line)
	_check(lengths_ok, "every track is world length + step x (k - 1) long")


## GDD 10.8: hidden at 4 m and closer, full GHOST_ALPHA from 6 m.
func _ghost_fade_check() -> void:
	var a3: float = RrWorld.ghost_fade(3.0, 0.5)
	var a5: float = RrWorld.ghost_fade(5.0, 0.0)
	var a8: float = RrWorld.ghost_fade(8.0, 1.0)
	print("ghost alpha at 3 m %.2f, 5 m %.2f, 8 m %.2f" % [a3, a5, a8])
	_check(a3 == 0.0 and a5 > 0.0 and a5 < RrBalance.GHOST_ALPHA, "ghost fades out within 4 m")
	_check(absf(a8 - RrBalance.GHOST_ALPHA) < 0.001, "ghost fully visible from 6 m")


## The shipped static worlds must match what RrWorldGen builds now.
func _bake_check() -> void:
	var all_ok: bool = true
	var total_kb: int = 0
	for k: String in RrTracks.all_keys(false):
		var t0: int = Time.get_ticks_msec()
		var baked: Resource = load(RrWorldBake.path_for(k))
		var load_ms: int = Time.get_ticks_msec() - t0
		var ok_v: bool = (
			baked != null and int(baked.get_meta(&"version", -1)) == RrWorldBake.VERSION
		)
		var gen := RrWorldGen.new()
		gen.build(RrTrack.new(k))
		var fresh: int = 0
		for e: Array in gen.ground:
			fresh += int(e[2])
		var shipped: int = 0
		if baked != null:
			for e: Array in (baked.get_meta(&"world", {}) as Dictionary).get("ground", []):
				shipped += int(e[2])
		var kb: int = FileAccess.get_file_as_bytes(RrWorldBake.path_for(k)).size() / 1024
		total_kb += kb
		print(
			(
				"%s bake: load %d ms, %d KB, build %d ms, %d tris fresh vs %d baked"
				% [k, load_ms, kb, gen.build_ms, fresh, shipped]
			)
		)
		all_ok = all_ok and ok_v and fresh == shipped
	print("bakes total %d KB" % total_kb)
	_check(all_ok, "all 48 base-track bakes are current (Pro tracks reuse them mirrored)")


func _flash_check() -> void:
	var race := RrRace.new()
	race.setup(RrTrack.new(1), true, true, 42)
	race.start_lights()
	var lim := RrFlashLimiter.new()
	var granted: Array[float] = []
	var pads: int = 0
	var n: int = 0
	while race.phase != RrRace.Phase.DONE and n < 60 * 120:
		race.step(1.0 / 60.0, 0, false)
		for e: Array in race.events:
			if e[0] == "pad":
				pads += 1
				if lim.allow(race.t):
					granted.append(race.t)
		race.events.clear()
		n += 1
	var worst: int = 0
	for i: int in granted.size():
		var c: int = 0
		for j: int in range(i, granted.size()):
			if granted[j] - granted[i] < 1.0:
				c += 1
		worst = maxi(worst, c)
	print("pad hits %d, flares granted %d, denied %d" % [pads, lim.granted, lim.denied])
	_check(
		worst <= RrBalance.MAX_FLASHES_PER_S, "flash limiter: worst 1 s window %d (max 3)" % worst
	)


# ---------------------------------------------------------------- league


## Sets a season up so the player ends last (rank 12) and closes it.
func _last_place_season(lg: RrLeague, easy: bool) -> Dictionary:
	for i: int in RrBalance.TABLE_RIVALS:
		lg.points[i] = 20 + i
	lg.my_points = 0
	lg.round_i = RrBalance.ROUNDS_PER_SEASON
	return lg.end_season(easy, false)


func _league_rules() -> void:
	print("--- league rules")
	var fresh := RrLeague.new()
	_check(not fresh.demotion_on, "Vanlig demotion (Nedrykk) is off by default")
	_check(not RaceRiders.league.demotion_on, "a fresh save has demotion off")
	# A whole Bronze III season in the pure sim: idle Lett, real races.
	var lg := RrLeague.new()
	lg.save_seed = 4242
	var places: Array[int] = []
	var keys: Array[String] = []
	for r: int in RrBalance.ROUNDS_PER_SEASON:
		var key: String = lg.next_track()
		keys.append(key)
		var heat: Array[int] = lg.heat_rivals()
		var skills: Array[float] = lg.heat_skills(heat, true, RrTracks.is_pro(key))
		var race: RrRace = _run(key, true, true, "idle", 1100 + r, skills)
		var times: Array[float] = []
		for rd: RrRider in race.riders:
			times.append(rd.finish_time)
		var res: Dictionary = lg.record_round(heat, times, true)
		places.append(int(res["place"]))
	var table: Array = []
	for row: Dictionary in lg.table():
		table.append("%s %d" % ["YOU" if row["me"] else row["name"], row["points"]])
	print("Bronze III rounds %s, places %s, table %s" % [keys, places, table])
	_season_shape(keys, 1, "Bronze III")
	var base3: Array[String] = RrLeague.rounds_of(0, 0)
	_check(
		keys.filter(func(k: String) -> bool: return k in base3).size() == 4,
		"Bronze III = 4 of world 1 tracks 1-5 + 1 guest (%s)" % [keys]
	)
	var end: Dictionary = lg.end_season(true, false)
	print(
		(
			"season end: rank %d promoted %s reward %s -> league %d tier %d"
			% [end["rank"], end["promoted"], end["reward"], lg.league, lg.tier]
		)
	)
	_check(bool(end["promoted"]) and lg.tier == 1, "idle Lett promotes out of Bronze III")
	_check(String(end["reward"]) == "paint:0", "promotion III -> II gives the paint set")
	_check(lg.next_track() == "w1_t6", "Bronze II round 1 is world 1 track 6")
	_check(
		RrLeague.rounds_of(0, 1) == ["w1_t6", "w1_t7", "w1_t8", "w2_t1", "w2_t2"],
		"Bronze II = W1 tracks 6-8 + W2 tracks 1-2 (preview)"
	)
	_check(
		RrLeague.rounds_of(0, 2) == ["w1_t1p", "w1_t3p", "w1_t5p", "w1_t7p", "w1_t8p"],
		"Bronze I = W1 Pro tracks 1, 3, 5, 7, 8"
	)
	for tr: int in 3:
		for lgi: int in RrBalance.LEAGUES_BUILT:
			for k: String in RrLeague.rounds_of(lgi, tr):
				_check(RrTracks.exists(k), "league %d tier %d track %s exists" % [lgi, tr, k])
	# Vanlig: bottom 2 do not drop unless Nedrykk is on; never out of a league.
	var v1 := RrLeague.new()
	v1.tier = 1
	var r1: Dictionary = _last_place_season(v1, false)
	_check(not bool(r1["demoted"]) and v1.tier == 1, "Vanlig last place, Nedrykk off: no drop")
	var v2 := RrLeague.new()
	v2.tier = 1
	v2.demotion_on = true
	var r2: Dictionary = _last_place_season(v2, false)
	_check(bool(r2["demoted"]) and v2.tier == 0, "Vanlig last place, Nedrykk on: one tier down")
	var v3 := RrLeague.new()
	v3.demotion_on = true
	var r3: Dictionary = _last_place_season(v3, false)
	_check(not bool(r3["demoted"]) and v3.tier == 0, "never drops out of the league reached")
	# Lett: never demoted, promoted anyway after 2 stuck seasons.
	var l1 := RrLeague.new()
	l1.tier = 1
	l1.demotion_on = true
	var got: Array = []
	for k: int in 3:
		var rr: Dictionary = _last_place_season(l1, true)
		got.append([rr["promoted"], rr["safety"], rr["demoted"], l1.tier])
	print("Lett last place 3 seasons: [promoted, safety, demoted, tier] %s" % [got])
	_check(not bool(got[0][2]) and not bool(got[1][2]), "Lett is never demoted")
	_check(
		not bool(got[0][0]) and not bool(got[1][0]) and bool(got[2][0]) and bool(got[2][1]),
		"Lett: after 2 stuck seasons the next season end promotes anyway"
	)
	var vs := RrLeague.new()
	var vgot: Array = []
	for k: int in 3:
		vgot.append(_last_place_season(vs, false)["promoted"])
	_check(vgot == [false, false, false], "Vanlig gets no safety-net promotion")
	# Bronze II -> I gives a part; Bronze I won -> Silver III on world 2.
	var b2 := RrLeague.new()
	b2.tier = 1
	b2.round_i = RrBalance.ROUNDS_PER_SEASON
	b2.my_points = 99
	var rb2: Dictionary = b2.end_season(true, false)
	_check(
		bool(rb2["promoted"]) and b2.tier == 2 and String(rb2["reward"]).begins_with("part:"),
		"promotion Bronze II -> I gives a part (%s)" % rb2["reward"]
	)
	var b1 := RrLeague.new()
	b1.tier = 2
	b1.round_i = RrBalance.ROUNDS_PER_SEASON
	b1.my_points = 99
	var rb1: Dictionary = b1.end_season(true, false)
	print(
		(
			"Bronze I won: reward %s -> league %d tier %d, next %s"
			% [rb1["reward"], b1.league, b1.tier, b1.next_track()]
		)
	)
	_check(
		bool(rb1["promoted"]) and b1.league == 1 and b1.tier == 0 and not b1.top_done,
		"winning Bronze I promotes to Silver III"
	)
	_check("trophy:0" in b1.rewards and "jersey:0" in b1.rewards, "Bronze won: trophy + jersey")
	_check(b1.round_i == 0, "Silver III season from round 1")
	_season_shape(b1.rounds(), 2, "Silver III")
	# Silver I won: Gold III on world 3 (worlds 3-6 arrive with their leagues).
	var top := RrLeague.new()
	top.league = 1
	top.tier = 2
	top.round_i = 5
	top.my_points = 99
	var rt: Dictionary = top.end_season(false, false)
	_check(
		bool(rt["promoted"]) and top.league == 2 and top.tier == 0 and not top.top_done,
		"winning Silver I promotes to Gold III"
	)
	_check("trophy:1" in top.rewards and "jersey:1" in top.rewards, "league won: trophy + jersey")
	_season_shape(top.rounds(), 3, "Gold III")
	_check(
		RrLeague.rounds_of(5, 1) == ["w6_t6", "w6_t7", "w6_t8", "w1_t1p", "w2_t1p"],
		"Champion II = W6 tracks 6-8 + the Pro track 1 of worlds 1 and 2"
	)
	# Champion I won: the end of the ladder (top_done, stays in Champion I).
	var ch := RrLeague.new()
	ch.league = 5
	ch.tier = 2
	ch.round_i = 5
	ch.my_points = 99
	var rc: Dictionary = ch.end_season(true, false)
	_check(
		bool(rc["promoted"]) and ch.league == 5 and ch.tier == 2 and ch.top_done,
		"winning Champion I: trophy, the ladder is done (top_done)"
	)
	_check("trophy:5" in ch.rewards, "Champion trophy")


## World features in the pure sim (GDD 6.0).
func _feature_checks() -> void:
	print("--- world features")
	var trk := RrTrack.new("w3_t1")
	var ice: Array = []
	for p: Array in trk.patches:
		if String(p[4]) == "ice":
			ice = p
	_check(not ice.is_empty(), "W3 track 1 has an ice patch")
	if not ice.is_empty():
		var sx: float = (float(ice[0]) + float(ice[1])) * 0.5
		var x: float = (float(ice[2]) + float(ice[3])) * 0.5
		_check(
			trk.patch_slides(sx, x) and trk.patch_mult(sx, x, false, true) == 1.0,
			"ice slides, never slows"
		)
	_check(
		RrTrack.kind_mult("ash", true, true) == 1.0 and RrTrack.kind_mult("ash", false, true) < 1.0,
		"the board floats over ash"
	)
	_check(
		(
			RrTrack.kind_mult("ford", true, false) == 1.0
			and RrTrack.kind_mult("ford", false, false) < 1.0
		),
		"the board is immune to the ford"
	)
	var race := RrRace.new()
	race.setup(RrTrack.new("w4_t1"), false, true, 3)
	_check(
		race.vent_puffing(0.5) and not race.vent_puffing(1.5),
		"W4 vent puffs 1.2 s of every 2 s (Vanlig)"
	)
	var w5 := RrTrack.new("w5_t1")
	var mid: float = (float(w5.split[0]) + float(w5.split[1])) * 0.5
	var isl: Vector2 = w5.island(mid)
	_check(
		isl.x < isl.y and w5.kid_x(mid) < isl.x,
		"W5 split: island between the routes, kid line on the bridge"
	)
	var r5: RrRace = _run("w5_t1", false, true, "skilled", 44)
	_check(r5.player.finished, "W5 skilled bot finishes through the split")
	var r6: RrRace = _run("w6_t1", true, true, "idle", 45)
	_check(r6.player.finished, "W6 idle finishes (rings %d)" % r6.track.rings.size())
	var w6 := RrTrack.new("w6_t1")
	_check(
		w6.rings.size() >= 3 and not w6.lifts.is_empty(),
		"W6: air rings over the jumps, the stack ramp lifts the line"
	)


## Version-2 save (Bronze/Silver ladder) -> version 3: nothing lost, a Silver
## winner moves on to Gold III; a winner mid-season promotes at its end.
func _migration_v2_check() -> void:
	print("--- save migration v2 -> v3")
	RaceRiders.reset_all()
	RaceRiders.record_finish("w2_t3", 46.0, 1, [[0.0, 0.0, 0.0, 0]])
	RaceRiders.league.league = 1
	RaceRiders.league.tier = 2
	RaceRiders.league.top_done = true
	RaceRiders.league.rewards.append_array(["trophy:0", "jersey:0", "trophy:1", "jersey:1"])
	RaceRiders.save_game()
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RrState.SAVE_PATH))
	d["version"] = 2
	_write_save(d)
	RaceRiders.load_game()
	var lg: RrLeague = RaceRiders.league
	_check(RaceRiders.migrated_from == 2, "version-2 save detected")
	_check(lg.league == 2 and lg.tier == 0 and not lg.top_done, "Silver winner -> Gold III")
	_check(
		"trophy:1" in lg.rewards and absf(RaceRiders.best_time("w2_t3") - 46.0) < 0.001,
		"trophies and best times kept"
	)
	# Mid-season (round 3 of a replay season): finish it, then promote.
	d["league"]["season_round"] = 2
	d["league"]["table"]["me"] = [12, 0, 6]
	_write_save(d)
	RaceRiders.load_game()
	lg = RaceRiders.league
	_check(
		lg.league == 1 and lg.round_i == 2 and lg.my_points == 12,
		"mid-season: the season and its points are kept"
	)
	for r: int in 3:
		lg.record_round(lg.heat_rivals(), [60.0, 40.0, 41.0, 42.0, 43.0, 44.0], true)
	var e: Dictionary = lg.end_season(true, false)
	_check(
		bool(e["promoted"]) and lg.league == 2 and lg.tier == 0,
		"that season's end promotes to Gold III"
	)
	RaceRiders.save_game()
	var d2: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RrState.SAVE_PATH))
	_check(int(d2["version"]) == 3, "saved as version 3")


## GDD 17.2: an idle Lett rider (holds nothing) climbs Bronze III -> Champion
## I in real races (rubber band on, league rival skills); never demoted.
func _ladder_climb() -> void:
	print("--- full ladder, idle Lett")
	var lg := RrLeague.new()
	lg.save_seed = 777
	var path: Array[String] = []
	var demoted: bool = false
	var safety: int = 0
	var seasons: int = 0
	var places: Array[int] = []
	while not lg.top_done and seasons < 40:
		for r: int in RrBalance.ROUNDS_PER_SEASON:
			var key: String = lg.next_track()
			var heat: Array[int] = lg.heat_rivals()
			var skills: Array[float] = lg.heat_skills(heat, true, RrTracks.is_pro(key))
			var race: RrRace = _run(key, true, true, "idle", 3000 + seasons * 10 + r, skills)
			var times: Array[float] = []
			for rd: RrRider in race.riders:
				times.append(rd.finish_time)
			places.append(int(lg.record_round(heat, times, true)["place"]))
		var lvl: int = lg.league * 3 + lg.tier
		var e: Dictionary = lg.end_season(true, false)
		seasons += 1
		demoted = demoted or bool(e["demoted"]) or lg.league * 3 + lg.tier < lvl
		safety += 1 if bool(e["safety"]) else 0
		path.append(
			(
				"%s%s r%d"
				% [
					RrBalance.LEAGUES[int(e["from_league"])],
					["III", "II", "I"][int(e["from_tier"])],
					int(e["rank"])
				]
			)
		)
	var top3: int = places.filter(func(p: int) -> bool: return p <= 3).size()
	print("ladder: %d seasons %s" % [seasons, path])
	print("ladder races %d, top 3 in %d, safety-net promotions %d" % [places.size(), top3, safety])
	_check(lg.top_done and lg.league == 5 and lg.tier == 2, "idle Lett reaches and wins Champion I")
	_check(not demoted, "Lett is never demoted on the way up")
	for i: int in 6:
		_check(("trophy:%d" % i) in lg.rewards, "trophy of league %d" % i)


## MWM Play free part (GDD 17.5): Bronze III only; season end -> shell card.
func _lock_check() -> void:
	print("--- MWM Play free part")
	RaceRiders.reset_all()
	RaceRiders.easy = true
	RaceRiders.free_levels_finished.connect(func() -> void: free_signals += 1)
	RaceRiders.set_full_unlock(false)
	var fr: Array[String] = RaceRiders.free_ride_tracks()
	_check(fr == ["w1_t1", "w1_t2", "w1_t3", "w1_t4", "w1_t5"], "free ride = W1 tracks 1-5")
	_check(not RaceRiders.can_ride("w1_t6") and not RaceRiders.can_ride("w2_t1"), "rest locked")
	for season: int in 2:
		for r: int in RrBalance.ROUNDS_PER_SEASON:
			var heat: Array[int] = RaceRiders.league.heat_rivals()
			_check(
				RaceRiders.league.next_track() == RrTracks.key(1, r + 1),
				"locked round %d is W1 track %d" % [r + 1, r + 1]
			)
			RaceRiders.record_league_round(heat, [40.0, 50.0, 51.0, 52.0, 53.0, 54.0])
		var before: int = free_signals
		var res: Dictionary = RaceRiders.end_season()
		_check(
			free_signals == before,
			"locked season %d: no shell card under the podium" % (season + 1)
		)
		RaceRiders.season_card_closed(res)
		print("locked season %d: %s, signals %d" % [season + 1, res, free_signals])
		_check(not bool(res["promoted"]), "locked season %d: no promotion" % (season + 1))
		_check(
			RaceRiders.league.league == 0 and RaceRiders.league.tier == 0,
			"locked season %d: still Bronze III" % (season + 1)
		)
	_check(free_signals == 1, "free_levels_finished sent once per app session (%d)" % free_signals)
	# A host that unlocks continues the ladder from Bronze III.
	RaceRiders.set_full_unlock(true)
	for r: int in RrBalance.ROUNDS_PER_SEASON:
		var heat2: Array[int] = RaceRiders.league.heat_rivals()
		RaceRiders.record_league_round(heat2, [40.0, 50.0, 51.0, 52.0, 53.0, 54.0])
	var res2: Dictionary = RaceRiders.end_season()
	RaceRiders.season_card_closed(res2)
	_check(bool(res2["promoted"]) and RaceRiders.league.tier == 1, "unlocked: promotes")
	_check(free_signals == 1, "no shell card when unlocked")
	# Locking a save that is past Bronze III parks the ladder; unlocking restores it.
	RaceRiders.set_full_unlock(false)
	_check(RaceRiders.league.tier == 0 and not RaceRiders.parked_league.is_empty(), "parked")
	RaceRiders.set_full_unlock(true)
	_check(RaceRiders.league.tier == 1, "unlock restores the parked ladder")


## GDD 17.2: rivals never score while away; 8 h+ gives only a form arrow.
func _away_check() -> void:
	print("--- away")
	var lg := RrLeague.new()
	lg.save_seed = 99
	for i: int in RrBalance.TABLE_RIVALS:
		lg.points[i] = i * 2
	var before: Array[int] = lg.points.duplicate()
	var short: bool = lg.apply_away(2.0, 5)
	_check(not short and lg.form.all(func(f: int) -> bool: return f == 0), "2 h away: no form")
	var long: bool = lg.apply_away(9.0, 5)
	var nonzero: int = lg.form.filter(func(f: int) -> bool: return f != 0).size()
	print("9 h away: form %s" % [lg.form])
	_check(long and nonzero > 0, "9 h away: rivals get a form arrow")
	_check(lg.points == before, "points do not change while away")
	# Through the save: last_seen 9 h ago -> form on load, points unchanged.
	RaceRiders.reset_all()
	RaceRiders.league.points[3] = 7
	RaceRiders.save_game()
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RrState.SAVE_PATH))
	d["last_seen"] = Time.get_unix_time_from_system() - 9.0 * 3600.0
	_write_save(d)
	RaceRiders.load_game()
	_check(RaceRiders.form_shown, "a save last seen 9 h ago shows form arrows")
	_check(RaceRiders.league.points[3] == 7, "and keeps the table points")


func _write_save(d: Dictionary) -> void:
	var f := FileAccess.open(RrState.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()


## A save from the two-world build (version 1) keeps everything.
func _migration_check() -> void:
	print("--- save migration")
	var v1: Dictionary = {
		"version": 1,
		"finishes": 4,
		"hover_unlocked": true,
		"seen_first_swap": true,
		"worlds":
		{
			"1":
			{
				"best_time": 43.21,
				"best_place": 1,
				"won": true,
				"ghost": [[0.0, 0.0, 0.0, 0], [3.0, 0.1, 0.0, 0]]
			},
			"2":
			{
				"best_time": 44.5,
				"best_place": 2,
				"won": false,
				"ghost": [[0.0, 0.0, 0.0, 0], [3.0, 0.5, 0.0, 1], [6.1, 0.4, 0.0, 1]]
			},
		},
		"cosmetics": {"outfit": 2, "bike": 1, "board": 1, "owned": ["outfit2"]},
		"last_world": 2,
		"difficulty": "vanlig",
		"settings":
		{
			"sfx_on": false,
			"sfx_volume": 0.5,
			"music_on": true,
			"music_volume": 0.3,
			"ghost": true,
			"haptics": false,
			"less_motion": true,
			"quality": "lav"
		},
	}
	_write_save(v1)
	RaceRiders.load_game()
	var ok: bool = (
		absf(RaceRiders.best_time("w1_t1") - 43.21) < 0.001
		and absf(RaceRiders.best_time("w2_t1") - 44.5) < 0.001
		and RaceRiders.ghost_rows("w1_t1").size() == 2
		and RaceRiders.ghost_rows("w2_t1").size() == 3
		and int(RaceRiders.track_data("w1_t1").get("best_place", 0)) == 1
		and bool(RaceRiders.track_data("w1_t1").get("won", false))
	)
	print(
		(
			"migrated: tracks %s, finishes %d, hover %s, easy %s, owned %s"
			% [
				RaceRiders.tracks.keys(),
				RaceRiders.finishes,
				RaceRiders.hover_unlocked,
				RaceRiders.easy,
				RaceRiders.cosmetics["owned"]
			]
		)
	)
	_check(RaceRiders.migrated_from == 1, "version-1 save detected")
	_check(ok, "world 1 / 2 best times, places and ghosts -> tracks w1_t1 / w2_t1")
	_check(
		RaceRiders.finishes == 4 and RaceRiders.hover_unlocked and RaceRiders.seen_first_swap,
		"finishes, hoverboard and first-swap flag kept"
	)
	_check("outfit2" in (RaceRiders.cosmetics["owned"] as Array), "cosmetics kept")
	_check(
		not RaceRiders.easy and not RaceRiders.sfx_on and RaceRiders.less_motion,
		"difficulty and settings kept"
	)
	_check(
		RaceRiders.league.league == 0 and RaceRiders.league.round_i == 0,
		"the ladder starts at Bronze III round 1"
	)
	RaceRiders.save_game()
	RaceRiders.load_game()
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RrState.SAVE_PATH))
	_check(
		int(d["version"]) == 3 and absf(RaceRiders.best_time("w2_t1") - 44.5) < 0.001,
		"saved again as version 3 with nothing lost"
	)
	RaceRiders.sfx_on = true
	RaceRiders.less_motion = false
	RaceRiders.quality_high = true


## Every tappable disc on a menu screen: >= 200 px, clear of the shell's
## top-left 232 px square, above the wrist strip (y < 1664).
func _audit(root: Control, what: String) -> void:
	var discs: Array[Node] = root.find_children("*", "RrDisc", true, false)
	var bad: Array = []
	var n: int = 0
	for nd: Node in discs:
		var d: RrDisc = nd
		if not d.is_visible_in_tree():
			continue
		n += 1
		var r := Rect2(d.global_position, d.size)
		if minf(r.size.x, r.size.y) < 200.0:
			bad.append("%s small %s" % [d.icon, r.size])
		if r.end.y > RrBalance.WRIST_Y:
			bad.append("%s reaches y %.0f" % [d.icon, r.end.y])
		if r.intersects(Rect2(0, 0, 232, 232)):
			bad.append("%s in the shell square" % d.icon)
	print("%s: %d targets, problems %s" % [what, n, bad])
	_check(n > 0 and bad.is_empty(), "%s: targets >= 200 px, none top-left or at y >= 1664" % what)


func _race_to_card(main: RrMain, limit: float = 200.0) -> float:
	Engine.time_scale = 4.0
	var t: float = 0.0
	while not main.card_visible() and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()
	Engine.time_scale = 1.0
	return t


func _main_checks() -> void:
	print("--- Main scene")
	# Headless ignores --resolution: force the portrait window (QA finding 11).
	get_window().size = Vector2i(1080, 1920)
	await _frames(2)
	var shown: Array[int] = []
	RaceRiders.level_card_shown.connect(func(id: int) -> void: shown.append(id))
	var main: RrMain = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	# Touch zones, at portrait size (QA finding 11).
	var vs: Vector2 = get_viewport().get_visible_rect().size
	print("viewport %s" % [vs])
	_check(vs.x < vs.y, "touch checks run on a portrait viewport")
	_check(main._zone(Vector2(100, 100)) == "none", "touch in the home square never steers")
	_check(main._zone(Vector2(vs.x - 100, 100)) == "none", "touch in the gear square never steers")
	_check(main._zone(Vector2(300, vs.y - 100)) == "none", "touch in the wrist strip is ignored")
	_check(main._zone(main.hud.boost_center()) == "boost", "boost disc centre is the boost button")
	_check(main._zone(Vector2(200, 900)) == "steer", "left half steers")
	_check(main._zone(Vector2(900, 400)) == "steer", "HUD strip steers too")
	main._holdover_until = -1.0
	var lx := Vector2(vs.x * 0.2, 900)
	var rx := Vector2(vs.x * 0.8, 900)
	main._touch_down(0, lx)
	main._touch_down(1, rx)
	var both: int = main.steer_dir()
	main._touch_up(1, rx)
	var after: int = main.steer_dir()
	main._touch_up(0, lx)
	_check(both == 1 and after == -1, "latest touch wins, older finger takes over on release")
	# Launch: straight into Bronze III round 1, no input at all.
	_check(
		main.track_key == "w1_t1" and main.race_mode == "league",
		"launch goes straight into the league race on W1 track 1 (%s)" % main.track_key
	)
	main.start_race()
	var lights_at: float = -1.0
	var t: float = 0.0
	Engine.time_scale = 4.0
	var fov_cruise: Array[float] = []
	var fov_boost: float = 0.0
	while not main.card_visible() and t < 200.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		if lights_at < 0.0 and main.race.phase != RrRace.Phase.PRE:
			lights_at = t
		var pl: RrRider = main.race.player
		if main.race.phase == RrRace.Phase.RACE:
			var since_boost: float = main.race.t - (pl.boost_until - RrBalance.BOOST_TIME_S)
			if pl.boosting(main.race.t) and since_boost > 0.3:
				fov_boost = maxf(fov_boost, main.world.camera.fov)
			elif absf(pl.v - RrBalance.CRUISE_MPS) < 0.3 and main.race.t > pl.boost_until + 1.5:
				fov_cruise.append(main.world.camera.fov)
	Engine.time_scale = 1.0
	var p: RrRider = main.race.player
	print(
		(
			"round 1: %s auto start %.1f s, finish %.2f s, place %d, round %s"
			% [main.track_key, lights_at, p.finish_time, p.place, main.last_round]
		)
	)
	_check(lights_at > 0.0 and lights_at <= RrBalance.AUTO_START_S + 0.3, "race starts by itself")
	var fc: float = 0.0
	for f: float in fov_cruise:
		fc += f / float(maxi(1, fov_cruise.size()))
	_check(absf(fc - 75.0) <= 1.0, "FOV 75 +-1 at steady cruise (%.1f)" % fc)
	_check(absf(fov_boost - 83.0) <= 1.0, "FOV 83 +-1 at the peak of a boost (%.1f)" % fov_boost)
	_check(main.card_visible() and p.place <= 3, "card appears, idle Lett top 3 (%d)" % p.place)
	_check(
		int(main.last_round.get("points", 0)) == RrBalance.LEAGUE_POINTS[p.place - 1],
		"round 1 scores %d points for place %d" % [int(main.last_round.get("points", 0)), p.place]
	)
	_check(bool(main.last_result.get("unlocked_hover", false)), "first finish unlocks the board")
	_check(RaceRiders.ghost_rows("w1_t1").size() > 300, "ghost saved for track w1_t1")
	_check(shown == [11], "level_card_shown(11) for world 1 track 1 (%s)" % [shown])
	_check(main.card.next_disc.visible, "league card shows the next disc")
	_check(
		(
			main.card.next_disc.disc_radius > main.card.replay_disc.disc_radius
			and main.card.next_disc.disc_radius > main.card.home_disc.disc_radius
			and (
				absf(main.card.next_disc.position.x + main.card.next_disc.size.x * 0.5 - 540.0)
				< 1.0
			)
		),
		"card: next race is the biggest disc, in the centre; replay is small at the side"
	)
	_check(
		main.card.next_key != "w1_t1" and main.card.next_key == RaceRiders.league.next_track(),
		"card: next = the next league round on another track (%s)" % main.card.next_key
	)
	var season_keys: Array[String] = RaceRiders.league.rounds().duplicate()
	# Home disc -> board reveal -> league table, rows sliding to new places.
	main.card.home_disc.press()
	_check(main.card.reveal_kind() == "board", "first reveal: hoverboard")
	main.card.tap_reveal()
	await _frames(2)
	_check(main.screen == "league" and main.league_screen.visible, "home opens the league screen")
	_check(main.league_screen.sliding(), "table rows slide to their new places")
	_check(main.league_screen.rows.size() == 12, "table: you + 11 rivals")
	_check(not main.home.visible, "league screen: the top-left square stays free")
	_audit(main.league_screen, "league screen")
	# Round 2 through the league screen's race disc, rounds 3-5 straight from
	# the card's next disc; no steering.
	var seen: Array[String] = ["w1_t1"]
	main.league_screen.race_disc.press()
	await _frames(2)
	for r: int in range(2, 6):
		_check(main.screen == "race" and main.race_mode == "league", "round %d starts" % r)
		_check(main.ghost == null, "round %d: no ghost on a track's first run" % r)
		_check(not main.track_key in seen, "round %d is a new track (%s)" % [r, main.track_key])
		seen.append(main.track_key)
		await _race_to_card(main)
		print(
			(
				"round %d: %s L %.0f finish %.2f place %d -> %s"
				% [
					r,
					main.track_key,
					main.track.length,
					main.race.player.finish_time,
					main.race.player.place,
					main.last_round
				]
			)
		)
		_check(main.card_visible() and main.race.player.place <= 3, "round %d: top 3" % r)
		main.card.next_disc.press()
		await _frames(2)
	_check(seen == season_keys, "season = its saved track list %s" % [seen])
	_season_shape(seen, 1, "first season")
	_check(main.screen == "season" and main.season_card.visible, "round 5 -> season card")
	_audit(main.season_card, "season card")
	print("season: %s" % [main.last_season])
	_check(bool(main.last_season.get("promoted", false)), "a full Bronze III season promotes")
	main.season_card.go_disc.press()
	_check(main.season_card.step == "reward", "promotion card shows the reward")
	main.season_card.go_disc.press()
	await _frames(2)
	_check(
		main.screen == "race" and main.race_mode == "league" and main.track_key == "w1_t6",
		"then straight into Bronze II round 1 on W1 track 6 (%s)" % main.track_key
	)
	_check(RaceRiders.league.tier == 1, "now Bronze II")
	_check("paint:0" in RaceRiders.league.rewards, "paint set owned")
	# Free ride: track page -> board -> race with that track's ghost.
	main.open_league_screen(false)
	await _frames(2)
	main.league_screen.map_disc.press()
	await _frames(2)
	_check(main.screen == "page" and main.page.tiles.size() == 16, "track page: 8 + 8 Pro tiles")
	_audit(main.page, "track page")
	main.page.tiles[0].press()
	await _frames(2)
	_check(main.screen == "board" and main.board_view.rows.size() == 12, "board: 12 rows")
	_audit(main.board_view, "track board")
	var pts_before: int = RaceRiders.league.my_points
	main.board_view.race_disc.press()
	await _frames(2)
	_check(main.race_mode == "free" and main.track_key == "w1_t1", "free ride on W1 track 1")
	_check(main.ghost != null, "free ride brings that track's ghost")
	Engine.time_scale = 4.0
	t = 0.0
	var near_drawn: int = 0
	var far_drawn: int = 0
	while main.race.player.s < 900.0 and t < 120.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		if main.race.phase != RrRace.Phase.RACE:
			continue
		var row: Array = main.ghost.sample(main.race.t)
		var ds: float = float(row[0]) - main.race.player.s
		var dx: float = float(row[1]) - main.race.player.x
		if main.world.ghost_view.visible:
			if sqrt(ds * ds + dx * dx) <= RrBalance.GHOST_FADE_NEAR_M:
				near_drawn += 1
			else:
				far_drawn += 1
	Engine.time_scale = 1.0
	print("W1 free ride ghost frames drawn: far %d, within 4 m %d" % [far_drawn, near_drawn])
	_check(near_drawn == 0, "ghost never drawn within 4 m of the player")
	await _race_to_card(main)
	_check(
		main.card.next_disc.visible and main.card.next_key == RaceRiders.league.next_track(),
		"free-ride card: the big disc is the waiting league round (%s)" % main.card.next_key
	)
	_check(RaceRiders.league.my_points == pts_before, "free rides score no points")
	await _next_ten(main)
	# A Pro track loads mirrored on the base bake.
	main.start_race("w2_t3p", "free")
	await _frames(2)
	_check(
		main.track.mirrored and main.world.world_baked and main.world._static_root.scale.x < 0.0,
		"Pro track w2_t3p: base bake, mirrored (%d ms)" % main.world.world_ms
	)
	main.queue_free()
	await _frames(2)


## Track rotation (owner 2026-10-07) without the scene: every league and tier,
## the MWM Play free part, the free-ride pick and the save.
func _rotation_rules() -> void:
	print("--- track rotation")
	var bad: Array = []
	for lgi: int in RrBalance.LEAGUES_BUILT:
		for tr: int in RrBalance.TIERS_PER_LEAGUE:
			for sd: int in 20:
				var ks: Array[String] = RrLeague.mix_rounds(lgi, tr, RrLeague.open_worlds(), sd, "")
				var w: Dictionary = {}
				var u: Dictionary = {}
				for k: String in ks:
					w[RrTracks.world_of(k)] = true
					u[k] = true
					if not RrTracks.exists(k):
						bad.append(k)
				if (
					u.size() != 5
					or w.size() < 2
					or RrTracks.world_of(ks[0]) != RrLeague.home_world(lgi) and tr != 1
				):
					bad.append([lgi, tr, sd, ks])
	_check(
		bad.is_empty(), "every league/tier season: 5 tracks, 2+ worlds, opens at home %s" % [bad]
	)
	var one: Array[int] = [1]
	_check(
		RrLeague.mix_rounds(0, 0, one, 7, "") == RrLeague.rounds_of(0, 0),
		"only world 1 open: Bronze III stays W1 tracks 1-5"
	)
	_check(
		RrLeague.mix_rounds(0, 0, RrLeague.open_worlds(), 7, "w1_t1")[0] != "w1_t1",
		"a season never opens on the track just ridden"
	)
	# Save: a restart resumes the same season list; a pre-rotation save mid
	# season finishes on its old tracks.
	var a := RrLeague.new()
	a.save_seed = 99
	a.round_i = 2
	var d: Dictionary = a.to_dict()
	var b := RrLeague.new()
	b.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(b.rounds() == a.rounds() and b.round_i == 2, "restart resumes the same season list")
	d.erase("season_tracks")
	var c := RrLeague.new()
	c.from_dict(d)
	_check(c.rounds() == RrLeague.rounds_of(0, 0), "old save mid-season keeps its tracks")
	# MWM Play free part: W1 tracks 1-5 only, also for the free-ride pick.
	RaceRiders.reset_all()
	RaceRiders.set_full_unlock(false)
	var lk: RrLeague = RaceRiders.league
	_check(lk.rounds() == RrLeague.rounds_of(0, 0), "free part season = W1 tracks 1-5")
	var outside: int = 0
	var same: int = 0
	var cur: String = "w1_t3"
	for i: int in 200:
		var nx: String = RaceRiders.pick_next_free(cur)
		outside += 0 if nx in ["w1_t1", "w1_t2", "w1_t3", "w1_t4", "w1_t5"] else 1
		same += 1 if nx == cur else 0
		cur = nx
	_check(outside == 0 and same == 0, "free part next: inside W1 t1-5, never the same track")
	RaceRiders.set_full_unlock(true)
	var worlds: Dictionary = {}
	same = 0
	cur = "w2_t4"
	for i: int in 200:
		var nx2: String = RaceRiders.pick_next_free(cur)
		same += 1 if nx2 == cur else 0
		worlds[RrTracks.world_of(nx2)] = true
		cur = nx2
	_check(same == 0 and worlds.size() >= 2, "free next: never the same, 2+ worlds over 200 picks")
	RaceRiders.reset_all()


## A season's tracks: 5 different ones, round 1 in the home world, and at
## least 2 worlds (every world is open in the stand-alone build).
func _season_shape(keys: Array[String], home: int, what: String) -> void:
	var worlds: Dictionary = {}
	var uniq: Dictionary = {}
	for k: String in keys:
		worlds[RrTracks.world_of(k)] = true
		uniq[k] = true
	_check(keys.size() == RrBalance.ROUNDS_PER_SEASON, "%s: 5 rounds" % what)
	_check(uniq.size() == keys.size(), "%s: no track twice %s" % [what, keys])
	_check(RrTracks.world_of(keys[0]) == home, "%s: round 1 in world %d" % [what, home])
	_check(worlds.size() >= 2, "%s: tracks from %d worlds" % [what, worlds.size()])


## Owner 2026-10-07: 10 taps on the card's big disc give 10 races, never the
## same track twice in a row, seasons from 2+ worlds, the league moving on.
func _next_ten(main: RrMain) -> void:
	print("--- next disc x10")
	var keys: Array[String] = [main.track_key]
	var rounds_before: int = RaceRiders.league.seasons * 5 + RaceRiders.league.round_i
	for i: int in 10:
		main.card.next_disc.press()
		await _frames(2)
		var guard: int = 0
		while main.screen == "season" and guard < 5:
			main.season_card.go_disc.press()
			await _frames(2)
			guard += 1
		_check(main.screen == "race", "next tap %d starts a race (%s)" % [i + 1, main.screen])
		keys.append(main.track_key)
		await _race_to_card(main)
	var repeats: int = 0
	for i: int in range(1, keys.size()):
		repeats += 1 if keys[i] == keys[i - 1] else 0
	print("next x10 tracks: %s" % [keys])
	_check(repeats == 0, "10 next taps: no track twice in a row")
	var lg: RrLeague = RaceRiders.league
	_check(
		lg.seasons * 5 + lg.round_i >= rounds_before + 9,
		"the league moves on with the next disc (season %d round %d)" % [lg.seasons, lg.round_i]
	)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
