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
##   thumbs          - world pictures for the card, reveal and world page
##                     (cropped into assets/textures/ui/world_N.jpg, no HUD)

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
	main.card.next_disc.press()
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
		await _until(func(r: RrRace) -> bool: return r.player.s > at, 900.0, 3.0)
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
