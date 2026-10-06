extends Node

## Dev-only screenshot bot. Run under Xvfb with a fresh user dir:
##   XDG_DATA_HOME=<tmp> CAPTURE_DIR=<dir> godot --audio-driver Dummy \
##     --display-driver x11 --resolution 1080x1920 res://tests/capture.tscn
## CAPTURE_PHASE:
##   shots (default) - first launch W1 pre-race, a real touch hold, W1 mid-race
##                     (the hero frame, DESIGN 17), a knock-off, the W1 card,
##                     settings, the reveal cards, W2 mid-race, a tumbleweed,
##                     the swap gate, the W2 card, the world page, Lav tier
##   cost            - one fixed frame per world (s 200): draws, triangles,
##                     CPU and GPU ms, Høy and Lav, and each Høy feature off
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
		if main.world.ghost_view.visible and main.race.track.world_id == 2:
			ghost_seen_first_run = true
	Engine.time_scale = 1.0


func _phase_shots() -> void:
	await _wait_s(1.5)
	await _shot("01_w1_prerace")
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
	# Boost moment (GDD 11.1): FOV 83, speed lines, wind whistle.
	await _until(func(r: RrRace) -> bool: return r.player.boosting(r.t) and r.player.v > 40.0)
	await _freeze_shot("02b_w1_boost")
	print(
		(
			"boost: v %.1f m/s fov %.1f s %.0f"
			% [main.race.player.v, main.world.camera.fov, main.race.player.s]
		)
	)
	# Knock-off: the bot shoulders the next rival it comes up beside.
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
	print("card: %s" % [main.last_result])
	main.gear.press()
	await _wait_s(0.5)
	main.gear.press()
	await _wait_s(0.3)
	await _shot("05_settings")
	print("settings open %s, race paused %s" % [main.settings.visible, main.paused])
	main.settings.play_disc.press()
	await _wait_s(0.3)
	# Biggest disc: world 2. Reveal cards: hoverboard, then the world-2 picture.
	main.card.next_disc.press()
	await _wait_s(2.3)
	await _shot("06_reveal_board")
	main.card.tap_reveal()
	await _wait_s(0.8)
	await _shot("07_reveal_world2")
	main.card.tap_reveal()
	await _wait_s(0.4)
	print("race 2: world %d, ghost %s" % [main.world_id, main.ghost != null])
	await _until(func(r: RrRace) -> bool: return r.player.s > 258.0)
	await _freeze_shot("08_w2_midrace")
	print(
		(
			"W2 mid-race: s %.0f place %d draws %d tris %dk"
			% [main.race.player.s, main.race.player.place, _draws(), _tris() / 1000]
		)
	)
	await _until(_weed_visible, 30.0, 1.0)
	await _freeze_shot("09_w2_tumbleweed")
	await _until(func(r: RrRace) -> bool: return r.player.s > 419.0)
	await _freeze_shot("10_swap_gate")
	await _until(func(r: RrRace) -> bool: return r.player.s > 495.0)
	await _freeze_shot("11_w2_board_highway")
	print("W2 at s %.0f: vehicle %d (1 = board)" % [main.race.player.s, main.race.player.vehicle])
	RaceRiders.set_quality_high(false)
	await _frames(6)
	await _shot("12_w2_highway_lav")
	print(
		(
			"Lav: draws %d tris %dk, sun shadow %s"
			% [_draws(), _tris() / 1000, main.world.sun.shadow_enabled]
		)
	)
	RaceRiders.set_quality_high(true)
	await _until(func(r: RrRace) -> bool: return r.player.finished, 120.0, 3.0)
	while not main.card_visible():
		await get_tree().process_frame
	print("W2 first run: ghost ever visible %s (expect false)" % ghost_seen_first_run)
	await _wait_s(0.5)
	await _shot("13_w2_results_card")
	main.card.home_disc.press()
	await _wait_s(0.6)
	await _shot("14_world_page")
	# Replay world 1: now its ghost rides along, faded near the player.
	main.page.cards[0].press()
	await _wait_s(0.3)
	RaceRiders.set_difficulty(false)
	await _until(func(r: RrRace) -> bool: return r.player.s > 180.0)
	await _freeze_shot("15_w1_replay_ghost")
	print("W1 replay: ghost on %s alpha %.2f" % [main.ghost != null, main.world.ghost_alpha])
	RaceRiders.set_difficulty(true)


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
	RaceRiders.worlds = {"1": {"best_time": 44.0, "best_place": 2}}
	RaceRiders.hover_unlocked = true
	if OS.get_environment("SUN_SWEEP") != "":
		main.start_race(2)
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
		main.start_race(w)
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


func _phase_thumbs() -> void:
	RaceRiders.worlds = {"1": {"best_time": 44.0, "best_place": 2}}
	RaceRiders.hover_unlocked = true
	for w: int in [1, 2]:
		main.start_race(w)
		await _wait_s(0.4)
		await _until(func(r: RrRace) -> bool: return r.player.s > 321.0)
		Engine.time_scale = 0.0
		main.hud.visible = false
		main.home.visible = false
		main.gear.visible = false
		await _frames(4)
		await _shot("thumb_world_%d" % w)
		main.hud.visible = true
		Engine.time_scale = 1.0


func _phase_cost() -> void:
	RaceRiders.worlds = {"1": {"best_time": 44.0, "best_place": 2}}
	RaceRiders.hover_unlocked = false
	var all: Array[String] = ["shadows", "glow", "msaa", "normals", "veg_far", "shafts"]
	for w: int in [1, 2]:
		main.start_race(w)
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
					"COST W%d %-20s draws %3d  tris %6.1fk  gpu %.3f ms  cpu %.3f ms"
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
					"COST W%d Høy without %-8s draws %3d  tris %6.1fk  gpu %.3f ms"
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
