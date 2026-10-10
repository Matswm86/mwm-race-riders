extends Node

## Dev-only screenshot bot. Run under Xvfb with a fresh user dir:
##   XDG_DATA_HOME=<tmp> CAPTURE_DIR=<dir> godot --audio-driver Dummy \
##     --display-driver x11 --resolution 1080x1920 res://tests/capture.tscn
## CAPTURE_PHASE:
##   shots (default) - first launch W1 pre-race (Bronze III round 1), a real
##                     touch hold, W1 mid-race (the hero frame, DESIGN 17), a
##                     boost, a knock-off, the card, settings, the board reveal,
##                     the league screen mid-slide and settled, the season end,
##                     the promotion reward, Bronze II with form arrows, the
##                     free-ride track page, a track board, Lav tier
##   tracks          - 3 world 1 and 3 world 2 kit tracks mid-race at their
##                     set pieces (tunnel, jump, river road; slot canyon, rim
##                     highway, mesa gap), plus two Pro tracks in evening light
##   cost            - one fixed frame per track (s 297) on w1_t1, w1_t5,
##                     w2_t1, w2_t5: draws, triangles, CPU and GPU ms, Høy and
##                     Lav, and each Høy feature off
##   look            - W1 and W2 mid-race only, with ACES and AgX (tonemap pick)
##   thumbs          - one picture per track, HUD hidden (tools/make_thumbs.py
##                     crops them into ui/tracks/<key>.jpg and ui/world_N.jpg)
##   worlds          - worlds 2-6 mid-race at their set pieces (W2 swap gate,
##                     tumbleweed, rim highway Høy and Lav; W3 ice cave, W4
##                     lava rail and vent, W5 split path and waterfall, W6
##                     container canyon and crane jump), the 6-world page
##   budget          - draw calls and triangles on every racing frame of all 96
##                     races, Høy and Lav (full idle races, a ghost ahead)
##   probe           - dev: CAPTURE_PLAN shots (see _phase_probe)

var out_dir: String = OS.get_environment("CAPTURE_DIR")
var main: RrMain
var ghost_seen_first_run: bool = false


func _ready() -> void:
	if out_dir == "":
		out_dir = "user://shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	RaceRiders.reset_all()
	RaceRiders.easy = true
	RaceRiders.quality_high = true
	main = load("res://scenes/Main.tscn").instantiate()
	main.auto_quality = false
	add_child(main)
	await _frames(5)
	var t0: int = Time.get_ticks_msec()
	var phase: String = OS.get_environment("CAPTURE_PHASE")
	print("world built in %d ms (baked %s)" % [main.world.world_ms, main.world.world_baked])
	match phase:
		"cost":
			await _phase_cost()
		"tracks":
			await _phase_tracks()
		"look":
			await _phase_look()
		"thumbs":
			await _phase_thumbs()
		"probe":
			await _phase_probe()
		"worlds":
			await _phase_worlds()
		"budget":
			await _phase_budget()
		_:
			await _phase_shots()
	print("CAPTURE DONE in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	Engine.time_scale = 1.0
	get_tree().quit()


## Run the race at speed until cond(race) is true, then return.
func _until(cond: Callable, limit_s: float = 120.0, speed: float = 2.5) -> void:
	Engine.time_scale = speed
	var t: float = 0.0
	while not cond.call(main.race) and t < limit_s:
		await get_tree().process_frame
		t += get_process_delta_time()
		if main.world.ghost_view.visible and main.ghost == null:
			ghost_seen_first_run = true
	Engine.time_scale = 1.0


func _phase_shots() -> void:
	await _wait_s(1.5)
	await _shot("01_w1_prerace")
	print(
		"launch: %s %s round %d" % [main.track_key, main.race_mode, RaceRiders.league.round_i + 1]
	)
	# Real touch: hold the right half; the rider moves right.
	var x0: float = main.race.player.x
	_touch(Vector2(820, 1150), true)
	await _wait_s(0.2)
	await _until(func(r: RrRace) -> bool: return r.phase == RrRace.Phase.RACE and r.t > 1.2)
	var moved: float = main.race.player.x - x0
	_touch(Vector2(820, 1150), false)
	print(
		"touch hold right half: phase %d, x moved %+.2f m (expect > 0)" % [main.race.phase, moved]
	)
	_touch(Vector2(200, 1800), true)
	await _frames(6)
	print("wrist-strip touch: steer dir %d (expect 0)" % main.steer_dir())
	_touch(Vector2(200, 1800), false)
	await _until(func(r: RrRace) -> bool: return r.player.s > 306.0)
	await _freeze_shot("02_w1_midrace")
	print(
		(
			"W1 mid-race: s %.0f place %d draws %d tris %dk"
			% [main.race.player.s, main.race.player.place, _draws(), _tris() / 1000]
		)
	)
	await _until(func(r: RrRace) -> bool: return r.player.boosting(r.t) and r.player.v > 40.0)
	await _freeze_shot("02b_w1_boost")
	main.bot = RrBot.knocker_steer
	await _until(_knock_visible, 40.0, 1.0)
	await _freeze_shot("03_knockoff")
	print("knock-off shot: %s" % [_knock_state()])
	main.bot = Callable()
	await _until(func(r: RrRace) -> bool: return r.player.finished)
	while not main.card_visible():
		await get_tree().process_frame
	await _wait_s(0.7)
	await _shot("04_w1_results_card")
	print("card: %s round %s" % [main.last_result, main.last_round])
	main.gear.press()
	await _wait_s(0.5)
	main.gear.press()
	await _wait_s(0.3)
	await _shot("05_settings")
	main.settings.play_disc.press()
	await _wait_s(0.3)
	# The big centre disc races on; the home disc opens the league table.
	main.card.home_disc.press()
	await _wait_s(2.3)
	await _shot("06_reveal_board")
	main.card.tap_reveal()
	await _wait_s(0.6)
	await _shot("07_league_sliding")
	await _wait_s(1.4)
	await _shot("08_league_screen")
	print(
		(
			"league screen: next %s, rows %d"
			% [main.league_screen.race_disc.track_key, main.league_screen.rows.size()]
		)
	)
	# Rounds 2-5 scored straight into the league (racing them here would only
	# repeat the 5 x 45 s the race test already drives), then the season end.
	var lg: RrLeague = RaceRiders.league
	var my: Array[float] = [43.6, 44.9, 46.2, 46.0]
	for r: int in 4:
		var heat: Array[int] = lg.heat_rivals()
		RaceRiders.record_league_round(heat, [my[r], 45.0, 45.4, 45.9, 46.3, 47.0])
	main.open_league_screen(true)
	await _wait_s(1.0)
	await _shot("09_season_end")
	print("season end: %s" % [main.last_season])
	main.season_card.go_disc.press()
	await _wait_s(1.2)
	await _shot("10_promotion_reward")
	main.season_card.go_disc.press()
	await _wait_s(0.3)
	# (go starts Bronze II round 1 straight away; the shots go back to the table)
	# 9 h away: the rivals get their form arrows (points never move).
	RaceRiders.league.apply_away(9.0, 3)
	main.open_league_screen(false)
	await _wait_s(0.4)
	await _shot("11_league_bronze2_form")
	main.league_screen.map_disc.press()
	await _wait_s(0.4)
	await _shot("12_track_page_w1")
	main.page.world_discs[1].press()
	await _wait_s(0.3)
	await _shot("13_track_page_w2")
	main.page.tiles[2].press()
	await _wait_s(0.4)
	await _shot("14_track_board")
	main.board_view.back_disc.press()
	await _wait_s(0.2)
	main.page.back_disc.press()
	await _wait_s(0.2)
	main.league_screen.race_disc.press()
	await _wait_s(0.4)
	await _until(func(r: RrRace) -> bool: return r.player.s > 260.0)
	RaceRiders.set_quality_high(false)
	await _frames(6)
	await _shot("15_bronze2_round1_lav")
	print(
		(
			"Lav on %s: draws %d tris %dk, sun shadow %s"
			% [main.track_key, _draws(), _tris() / 1000, main.world.sun.shadow_enabled]
		)
	)
	RaceRiders.set_quality_high(true)


## Six kit tracks + two Pro tracks mid-race at a set piece, HUD on.
func _phase_tracks() -> void:
	RaceRiders.hover_unlocked = true
	var plan: Array = [
		["w1_t3", "landmark", 70.0, "tunnel"],
		["w1_t6", "signature", 75.0, "gully jump"],
		["w1_t8", "gate_in", 70.0, "river road"],
		["w2_t2", "landmark", 55.0, "slot canyon"],
		["w2_t5", "gate_in", 90.0, "rim highway"],
		["w2_t7", "signature", 72.0, "mesa gap"],
		["w1_t5p", "landmark", 40.0, "Pro evening"],
		["w2_t4p", "chain", 40.0, "Pro evening"],
	]
	for i: int in plan.size():
		var key: String = plan[i][0]
		var at: float = _span_s(key, String(plan[i][1])) + float(plan[i][2])
		var t0: int = Time.get_ticks_msec()
		main.start_race(key, "free")
		print(
			(
				"%s loaded in %d ms (static %d ms, baked %s)"
				% [key, Time.get_ticks_msec() - t0, main.world.world_ms, main.world.world_baked]
			)
		)
		await _wait_s(0.4)
		await _until(func(r: RrRace) -> bool: return r.player.s > at, 900.0, 3.0)
		await _freeze_shot("t%d_%s" % [i + 1, key])
		print(
			(
				"%s %s at s %.0f: place %d draws %d tris %dk"
				% [
					key,
					plan[i][3],
					main.race.player.s,
					main.race.player.place,
					_draws(),
					_tris() / 1000
				]
			)
		)


## Where a track's picture is taken: each track number shows a different
## kit piece (track 1: the slice frame at s 321).
func _thumb_at(key: String) -> float:
	var plan: Dictionary = {
		2: ["landmark", 50.0],
		3: ["gate_in", 80.0],
		4: ["signature", 20.0],
		5: ["chain", 60.0],
		6: ["gate_out", 70.0],
		7: ["kick_m", 15.0],
		8: ["bend_s", 70.0],
	}
	var n: int = RrTracks.number_of(key)
	if not plan.has(n):
		return 321.0
	var piece: String = plan[n][0]
	var at: float = _span_s(key, piece)
	if at == 300.0 and piece == "kick_m":
		at = _span_s(key, "kick_s")
	if at == 300.0 and piece == "bend_s":
		at = _span_s(key, "sweeper")
	return at + float(plan[n][1])


## Start of the first recipe piece with this name (track JSON), else 300 m.
func _span_s(key: String, piece: String) -> float:
	var d: Dictionary = RrTracks.get_def(key)
	var s0: float = 0.0
	for row: Array in d.get("recipe", []):
		if String(row[0]) == piece:
			return s0
		s0 += float(row[2])
	return 300.0


func _knock_visible(r: RrRace) -> bool:
	for o: RrRider in r.riders:
		if o.fall_t > 0.1 and o.fall_t < 0.5 and absf(o.s - r.player.s) < 7.0:
			return true
	return false


func _knock_state() -> String:
	var out: Array = []
	for o: RrRider in main.race.riders:
		if o.fall_t >= 0.0:
			out.append(
				"rider %d fall_t %.2f ds %.1f" % [o.index, o.fall_t, o.s - main.race.player.s]
			)
	return ", ".join(out)


func _weed_visible(r: RrRace) -> bool:
	for i: int in r.track.rollers.size():
		var pose: Array = r.roller_pose(i)
		if pose.is_empty():
			continue
		var ahead: float = float(pose[0]) - r.player.s
		if ahead > 5.0 and ahead < 11.0 and absf(float(pose[1])) < 2.5:
			return true
	return false


func _phase_look() -> void:
	RaceRiders.hover_unlocked = true
	if OS.get_environment("SUN_SWEEP") != "":
		main.start_race("w2_t1", "free")
		await _wait_s(0.5)
		await _until(func(r: RrRace) -> bool: return r.player.s > 180.0)
		Engine.time_scale = 0.0
		for yaw: float in [0.0, 180.0, 90.0, -90.0]:
			main.world.sun.rotation_degrees.y = yaw
			await _frames(4)
			await _shot("sun_%d" % int(yaw))
		Engine.time_scale = 1.0
		return
	for w: int in [1, 2]:
		main.start_race(RrTracks.key(w, 1), "free")
		await _wait_s(0.5)
		await _until(func(r: RrRace) -> bool: return r.player.s > 288.0)
		Engine.time_scale = 0.0
		for tm: int in [Environment.TONE_MAPPER_ACES, Environment.TONE_MAPPER_AGX]:
			main.world.env.tonemap_mode = tm
			await _frames(4)
			await _shot(
				"look_w%d_%s" % [w, "aces" if tm == Environment.TONE_MAPPER_ACES else "agx"]
			)
		Engine.time_scale = 1.0


## One picture per track (tools/make_thumbs.py crops them into
## assets/textures/ui/tracks/<key>.jpg), HUD hidden, taken at a set piece
## that changes with the track number, so the cards look different.
func _phase_thumbs() -> void:
	RaceRiders.hover_unlocked = true
	var only: String = OS.get_environment("THUMB_ONLY")
	for key: String in RrTracks.all_keys(true):
		if only != "" and not key in only.split(","):
			continue
		var at: float = _thumb_at(key)
		main.start_race(key, "free")
		await _wait_s(0.3)
		# The pack is put just before the spot, then rides into it for 0.8 s.
		await _teleport(at - 24.0)
		Engine.time_scale = 1.0
		await _wait_s(0.8)
		Engine.time_scale = 0.0
		main.hud.visible = false
		main.home.visible = false
		main.gear.visible = false
		await _frames(4)
		await _shot("thumb_" + key)
		main.hud.visible = true
		Engine.time_scale = 1.0


func _phase_cost() -> void:
	RaceRiders.hover_unlocked = false
	var all: Array[String] = ["shadows", "glow", "msaa", "normals", "veg_far", "shafts"]
	for key: String in ["w1_t1", "w1_t5", "w2_t1", "w2_t5"]:
		var w: String = key
		main.start_race(key, "free")
		await _wait_s(0.4)
		await _until(func(r: RrRace) -> bool: return r.player.s > 297.0)
		Engine.time_scale = 0.0
		var vp: RID = get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		var rows: Array = []
		rows.append(["warm-up (Høy)", _feat(all, "")])
		rows.append(["Høy (all on)", _feat(all, "")])
		for k: String in all:
			rows.append(["Høy minus " + k, _feat(all, k)])
		rows.append(["Lav (all off)", {}])
		rows.append(["Lav, HUD hidden", {}])
		for row: Array in rows:
			main.hud.visible = String(row[0]) != "Lav, HUD hidden"
			main.world.apply_features(row[1])
			await _frames(30)
			var gpu: float = 0.0
			var cpu: float = 0.0
			var n: int = 90
			for i: int in n:
				await RenderingServer.frame_post_draw
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
				cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			print(
				(
					"COST %s %-20s draws %3d  tris %6.1fk  gpu %.3f ms  cpu %.3f ms"
					% [w, row[0], _draws(), _tris() / 1000.0, gpu / n, cpu / n]
				)
			)
		main.hud.visible = true
		main.world.apply_quality(true)
		await _frames(10)
		for g: String in ["ground", "lanes", "trees", "grass", "props", "racers", "fx"]:
			main.world.debug_show(g, false)
			await _frames(20)
			var gpu2: float = 0.0
			for i: int in 60:
				await RenderingServer.frame_post_draw
				gpu2 += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			print(
				(
					"COST %s Høy without %-8s draws %3d  tris %6.1fk  gpu %.3f ms"
					% [w, g, _draws(), _tris() / 1000.0, gpu2 / 60.0]
				)
			)
			main.world.debug_show(g, true)
		Engine.time_scale = 1.0


## Worlds 2-6 at their set pieces (README and docs/screenshots).
func _phase_worlds() -> void:
	RaceRiders.hover_unlocked = true
	RaceRiders.seen_first_swap = true
	# World 2 (refreshes the slice's world-2 pictures).
	main.start_race("w2_t1", "free")
	await _wait_s(1.0)
	await _shot("07_reveal_world2")
	await _teleport(232.0)
	await _shot("08_w2_midrace")
	await _teleport(325.0)
	Engine.time_scale = 1.0
	await _until(_weed_visible, 20.0, 1.0)
	await _freeze_shot("09_w2_tumbleweed")
	await _teleport(437.0)
	Engine.time_scale = 1.0
	await _until(
		func(r: RrRace) -> bool: return r.player.swap_t > 0.0 and r.t - r.player.swap_t > 0.12,
		10.0,
		0.5
	)
	await _freeze_shot("10_swap_gate")
	await _teleport(610.0)
	await _shot("11_w2_board_highway")
	main.world.apply_quality(false)
	await _frames(8)
	await _shot("12_w2_highway_lav")
	print("W2 rim highway Lav: draws %d tris %dk" % [_draws(), _tris() / 1000])
	main.world.apply_quality(true)
	var plan: Array = [
		["w3_t1", "sig-18", "16_w3_ice_cave"],
		["w3_t2", "0.2", "17_w3_glacier"],
		["w4_t1", "lava+40", "18_w4_lava_rail"],
		["w4_t3", "sig-22", "19_w4_steam_vent"],
		["w5_t1", "split+12", "20_w5_split_path"],
		["w5_t2", "sig-26", "21_w5_waterfall"],
		["w6_t1", "containers+20", "22_w6_container_canyon"],
		["w6_t2", "sig-40", "23_w6_crane_jump"],
		["w6_t3", "0.3", "24_w6_midrace"],
	]
	for e: Array in plan:
		main.start_race(String(e[0]), "free")
		await _wait_s(0.4)
		await _teleport(_resolve_s(String(e[0]), String(e[1])))
		Engine.time_scale = 1.0
		await _wait_s(0.6)
		await _freeze_shot(String(e[2]))
		print(
			(
				"%s: %s s %.0f draws %d tris %dk"
				% [e[2], e[0], main.race.player.s, _draws(), _tris() / 1000]
			)
		)
	main.open_track_page()
	main.page.world_discs[2].press()
	await _wait_s(0.5)
	await _shot("14_world_page")


## Draw calls on every race (owner 10-07: Høy <= 80, Lav <= 60, Pro evening
## included). QA 10-07: six teleport points missed the peaks, so this drives a
## full idle Lett race per track and tier and keeps the worst racing frame,
## with a ghost riding ahead (its draws count too). BUDGET_ONLY="w1,w4" filters.
func _phase_budget() -> void:
	RaceRiders.hover_unlocked = true
	RaceRiders.seen_first_swap = true
	var only: PackedStringArray = OS.get_environment("BUDGET_ONLY").split(",", false)
	var rows: Array = []
	for key: String in RrTracks.all_keys(true):
		var take: bool = only.is_empty()
		for o: String in only:
			take = take or key.begins_with(o)
		if not take:
			continue
		var row: Array = [key]
		for high: bool in [true, false]:
			RaceRiders.set_quality_high(high)
			main.start_race(key, "free")
			await _frames(2)
			main.world.apply_quality(high)
			main.ghost = RrGhost.new(_ghost_ahead(main.track))
			row.append_array(await _race_worst(80 if high else 60))
		rows.append(row)
		print(
			(
				(
					"BUDGET %-7s hoy %3d draws (s %4.0f, %3d frames over) %4dk tris"
					% [key, row[1], row[2], row[4], int(row[3]) / 1000]
				)
				+ (
					" | lav %3d draws (s %4.0f, %3d frames over) %4dk tris"
					% [row[5], row[6], row[8], int(row[7]) / 1000]
				)
			)
		)
	RaceRiders.set_quality_high(true)
	var worlds: Dictionary = {}
	for r: Array in rows:
		var w: int = RrTracks.world_of(String(r[0]))
		if not worlds.has(w):
			worlds[w] = [0, 0, 0, 0, 0, 0]
		var a: Array = worlds[w]
		a[0] = maxi(a[0], r[1])
		a[1] = maxi(a[1], r[3])
		a[2] += r[4]
		a[3] = maxi(a[3], r[5])
		a[4] = maxi(a[4], r[7])
		a[5] += r[8]
	for w: int in worlds:
		var a2: Array = worlds[w]
		print(
			(
				(
					"BUDGET W%d max: Høy %d draws %dk tris (%d frames over 80)"
					% [w, a2[0], a2[1] / 1000, a2[2]]
				)
				+ " | Lav %d draws %dk tris (%d frames over 60)" % [a2[3], a2[4] / 1000, a2[5]]
			)
		)
	var hi: int = 0
	var lo: int = 0
	for r2: Array in rows:
		hi = maxi(hi, int(r2[1]))
		lo = maxi(lo, int(r2[5]))
	print("BUDGET worst over %d races: Høy %d, Lav %d (limits 80 / 60)" % [rows.size(), hi, lo])


## One race to the card at 3x: [max draws, s at the max, max triangles,
## frames over the limit] over every racing frame.
func _race_worst(limit: int) -> Array:
	var maxd: int = 0
	var at_s: float = 0.0
	var maxt: int = 0
	var over: int = 0
	Engine.time_scale = 3.0
	var t0: int = Time.get_ticks_msec()
	while not main.card_visible() and Time.get_ticks_msec() - t0 < 300000:
		await get_tree().process_frame
		if main.race.phase != RrRace.Phase.RACE or main.race.player.finished:
			continue
		var d: int = _draws()
		if d > maxd:
			maxd = d
			at_s = main.race.player.s
		if d > limit:
			over += 1
		maxt = maxi(maxt, _tris())
	Engine.time_scale = 1.0
	return [maxd, at_s, maxt, over]


## A ghost 15 m ahead of the start at 1.1 x cruise: on screen most of the race.
func _ghost_ahead(trk: RrTrack) -> Array:
	var out: Array = []
	var v: float = RrBalance.CRUISE_MPS * 1.1
	var n: int = int(trk.length / v * float(RrBalance.GHOST_HZ)) + 2
	for i: int in n:
		var sg: float = minf(trk.length, 15.0 + v * float(i) / float(RrBalance.GHOST_HZ))
		var veh: int = RrRider.BOARD if trk.is_smooth(sg) else RrRider.BIKE
		out.append([sg, trk.kid_x(sg), 0.0, veh])
	return out


## Dev probe: CAPTURE_PLAN="w3_t1@sig-20,w4_t2@0.4" (s in metres, a share of
## the length, or a zone name +- metres); one Høy and one Lav shot each with
## draws and triangles.
func _phase_probe() -> void:
	RaceRiders.hover_unlocked = true
	for item: String in OS.get_environment("CAPTURE_PLAN").split(",", false):
		var key: String = item.get_slice("@", 0)
		main.start_race(key, "free")
		await _wait_s(0.3)
		var at: float = _resolve_s(key, item.get_slice("@", 1))
		await _teleport(at)
		for high: bool in [true, false]:
			main.world.apply_quality(high)
			main.world.call("_update_casters", main.race, 1.0)
			await _frames(8)
			var tag: String = "%s_%s_%d" % [key, "hoy" if high else "lav", int(at)]
			await _shot("probe_" + tag)
			print("PROBE %s draws %d tris %dk" % [tag, _draws(), _tris() / 1000])
			if OS.get_environment("PROBE_BREAKDOWN") != "":
				await _breakdown(tag)
		main.world.apply_quality(true)
		Engine.time_scale = 1.0


## Draw calls per scene group at this frame: hide the group, measure the drop.
func _breakdown(tag: String) -> void:
	var w: RrWorld = main.world
	var groups: Dictionary = {"hud": [main.hud, main.home, main.gear], "fx": [w.fx]}
	var racers: Array = []
	for v: RrRiderView in w.views:
		racers.append(v)
	groups["racers"] = racers
	var stat: Node = w.get_node("Static")
	for c: Node in stat.get_children():
		var g: String = "static_other"
		if c is MultiMeshInstance3D:
			var mmi := c as MultiMeshInstance3D
			g = "prop:" + mmi.multimesh.mesh.resource_name if mmi.multimesh.mesh != null else "prop"
			for e: Array in w.get("_veg"):
				if e[1] == c:
					g = "prop:" + RrWorld.model_of(String(e[0]))
		elif c is MeshInstance3D:
			var mo: Material = (c as MeshInstance3D).material_override
			g = "ground" if mo is ShaderMaterial else "water"
			if mo == w.get("_terrain_far_mat"):
				g = "ground_far"
			if (
				mo is ShaderMaterial
				and (mo as ShaderMaterial).shader.resource_path.contains("lane")
			):
				g = "lane"
		if not groups.has(g):
			groups[g] = []
		(groups[g] as Array).append(c)
	for c2: Node in w.get_children():
		if c2 is GeometryInstance3D and not c2 is RrRiderView:
			var kn: String = "kit"
			var km: Mesh = null
			if c2 is MultiMeshInstance3D:
				km = (c2 as MultiMeshInstance3D).multimesh.mesh
			elif c2 is MeshInstance3D:
				km = (c2 as MeshInstance3D).mesh
			if km != null:
				kn = "kit:" + (km.resource_name if km.resource_name != "" else km.get_class())
				if c2.name.begins_with("@") == false:
					kn += "@" + String(c2.name)
			if not groups.has(kn):
				groups[kn] = []
			(groups[kn] as Array).append(c2)
	var base: int = _draws()
	var base_t: int = _tris()
	var rows: Array = []
	for g2: String in groups:
		var was: Array = []
		for n: Node in groups[g2]:
			was.append(n.get("visible"))
			n.set("visible", false)
		await _frames(3)
		rows.append([base - _draws(), g2, base_t - _tris()])
		for i: int in groups[g2].size():
			(groups[g2][i] as Node).set("visible", was[i])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	var line: PackedStringArray = []
	for r: Array in rows:
		if int(r[0]) != 0 or int(r[2]) > 999:
			line.append("%s %d/%dk" % [r[1], r[0], int(r[2]) / 1000])
	print("BREAKDOWN %s total %d draws %dk tris: %s" % [tag, base, base_t / 1000, ", ".join(line)])
	await _frames(3)


## s for a probe spec: "123" metres, "0.4" share of the length, "sig-20"
## the signature lip minus 20 m, "split+10", "lava", "seracs" ... zone starts.
func _resolve_s(_key: String, spec: String) -> float:
	var trk: RrTrack = main.track
	var off: float = 0.0
	var name: String = spec
	for sep: String in ["+", "-"]:
		if spec.contains(sep) and not spec.begins_with(sep):
			name = spec.get_slice(sep, 0)
			off = float(spec.get_slice(sep, 1)) * (1.0 if sep == "+" else -1.0)
	if name.is_valid_float():
		var v: float = float(name)
		return (v * trk.length if v <= 1.0 else v) + off
	if name == "sig":
		return trk.zone_at("lip", trk.kickers[trk.kickers.size() - 2]) + off
	if name == "tunnel":
		return trk.tunnel.x + off
	var z: Vector2 = trk.zone(name)
	return (z.x if z.x >= 0.0 else trk.length * 0.5) + off


## Put the whole pack at s (rivals just ahead), cursors past s, camera behind.
func _teleport(at: float) -> void:
	Engine.time_scale = 0.0
	var race: RrRace = main.race
	if race.phase == RrRace.Phase.PRE:
		race.start_lights()
	race.phase = RrRace.Phase.RACE
	race.t = maxf(race.t, 5.0)
	var offs: Array[float] = [0.0, 6.0, 9.0, 14.0, 22.0, 30.0]
	for i: int in race.riders.size():
		var r: RrRider = race.riders[i]
		r.s = at + offs[i]
		r.x = race.track.kid_x(r.s) + (0.0 if i == 0 else RrBalance.AI_LANE_OFFSETS[i - 1] * 0.6)
		r.v = RrBalance.CRUISE_MPS
		r.reached_floor = true
		r.airborne = false
		r.h = 0.0
		r.next_pad = race.track.pads.filter(func(p: Array) -> bool: return float(p[0]) < r.s).size()
		r.next_kick = race.track.kickers.filter(func(k: float) -> bool: return k < r.s).size()
		r.next_hay = (
			race.track.blocks.filter(func(b: Array) -> bool: return float(b[0]) < r.s).size()
		)
		r.next_gate = (
			race.track.gates.filter(func(g: Array) -> bool: return float(g[0]) < r.s).size()
		)
		r.next_hop = race.track.hops.filter(func(h: float) -> bool: return h < r.s).size()
		r.next_ring = (
			race.track.rings.filter(func(g: Array) -> bool: return float(g[0]) < r.s).size()
		)
		r.vehicle = RrRider.BOARD if race.track.is_smooth(r.s) else RrRider.BIKE
	main.world.reset_camera(race)
	main.world.skip_intro()
	# Shadow casters and rider detail follow the pack the way they do in a race.
	main.world.call("_update_casters", race, 1.0)
	await _frames(4)


func _feat(all: Array[String], off: String) -> Dictionary:
	var d: Dictionary = {}
	for k: String in all:
		d[k] = k != off
	return d


func _draws() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


func _tris() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))


func _freeze_shot(name: String) -> void:
	Engine.time_scale = 0.0
	await _frames(3)
	await _shot(name)
	Engine.time_scale = 1.0


func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _wait_s(s: float) -> void:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(s * 1000.0):
		await get_tree().process_frame


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = out_dir + "/" + name + ".png"
	img.save_png(path)
	print("SHOT ", path)
