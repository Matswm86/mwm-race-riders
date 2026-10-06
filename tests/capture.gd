extends Node

## Dev-only screenshot bot. Run under Xvfb with a fresh user dir:
##   XDG_DATA_HOME=<tmp> CAPTURE_DIR=<dir> godot --audio-driver Dummy \
##     --display-driver x11 --resolution 1080x1920 res://tests/capture.tscn
## CAPTURE_PHASE:
##   shots (default) - first launch pre-race, a real touch hold, mid-race,
##                     jump, finish shot, card, reveal, swap gate, board on
##                     the skyway, settings, track page, Vanlig HUD, Lav tier
##   cost            - one fixed race frame: draws, triangles, CPU and GPU ms
##                     with Høy, Lav and each Høy feature switched off alone

var out_dir: String = OS.get_environment("CAPTURE_DIR")
var main: RrMain


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
		_:
			await _phase_shots()
	print("CAPTURE DONE in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	Engine.time_scale = 1.0
	get_tree().quit()


## Run the race at speed until cond(race) is true, then freeze time.
func _until(cond: Callable, limit_s: float = 120.0, speed: float = 2.5) -> void:
	Engine.time_scale = speed
	var t: float = 0.0
	while not cond.call(main.race) and t < limit_s:
		await get_tree().process_frame
		t += get_process_delta_time()
	Engine.time_scale = 1.0


func _phase_shots() -> void:
	await _wait_s(1.5)
	await _shot("01_start_prerace")
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
	# Touch in the wrist strip does not steer.
	var xb: float = main.race.player.lat_v
	_touch(Vector2(200, 1800), true)
	await _frames(6)
	print(
		(
			"wrist-strip touch: steer dir %d (expect 0), lat_v %.2f -> %.2f"
			% [main.steer_dir(), xb, main.race.player.lat_v]
		)
	)
	_touch(Vector2(200, 1800), false)
	await _until(func(r: RrRace) -> bool: return r.player.s > 98.0)
	await _freeze_shot("02_midrace")
	print(
		(
			"mid-race: s %.0f place %d draws %d tris %dk"
			% [main.race.player.s, main.race.player.place, _draws(), _tris() / 1000]
		)
	)
	await _until(func(r: RrRace) -> bool: return r.player.airborne and r.player.trick_t > 0.25)
	await _freeze_shot("03_jump_trick")
	await _until(func(r: RrRace) -> bool: return r.player.finished)
	await _wait_s(0.9)
	await _shot("04_finish_shot")
	while not main.card_visible():
		await get_tree().process_frame
	await _wait_s(0.7)
	await _shot("05_results_card")
	print("card: %s" % [main.last_result])
	# Gear: two taps open settings over the card.
	main.gear.press()
	await _wait_s(0.5)
	main.gear.press()
	await _wait_s(0.3)
	await _shot("06_settings")
	print("settings open %s, race paused %s" % [main.settings.visible, main.paused])
	main.settings.play_disc.press()
	await _wait_s(0.3)
	main.card.replay_disc.press()
	await _wait_s(2.4)
	await _shot("07_unlock_reveal")
	main.card.tap_reveal()
	await _wait_s(0.4)
	await _until(func(r: RrRace) -> bool: return r.player.s > 284.0)
	await _freeze_shot("08_swap_gate")
	await _until(func(r: RrRace) -> bool: return r.player.s > 318.0)
	await _freeze_shot("09_board_skyway")
	print(
		(
			"race 2 at s %.0f: vehicle %d (1 = board), ghost %s"
			% [main.race.player.s, main.race.player.vehicle, main.ghost != null]
		)
	)
	# Lav tier, same moment.
	RaceRiders.set_quality_high(false)
	await _frames(4)
	await _shot("10_board_skyway_lav")
	print("Lav: draws %d tris %dk" % [_draws(), _tris() / 1000])
	RaceRiders.set_quality_high(true)
	await _until(func(r: RrRace) -> bool: return r.player.finished, 120.0, 3.0)
	while not main.card_visible():
		await get_tree().process_frame
	await _wait_s(0.5)
	main.card.home_disc.press()
	await _wait_s(0.6)
	await _shot("11_track_page")
	# Vanlig race with the clock.
	RaceRiders.set_difficulty(false)
	main.page.cards[0].press()
	await _wait_s(0.3)
	await _until(func(r: RrRace) -> bool: return r.player.s > 400.0)
	await _freeze_shot("12_vanlig_hud")
	RaceRiders.set_difficulty(true)


func _phase_cost() -> void:
	await _until(func(r: RrRace) -> bool: return r.player.s > 98.0)
	Engine.time_scale = 0.0
	var vp: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var all: Array[String] = ["shadows", "glow", "filmic", "sun", "msaa", "gpu_fx", "rim"]
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
		var n: int = 120
		for i: int in n:
			await RenderingServer.frame_post_draw
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		print(
			(
				"COST %-20s draws %3d  tris %5.1fk  gpu %.3f ms  cpu %.3f ms"
				% [row[0], _draws(), _tris() / 1000.0, gpu / n, cpu / n]
			)
		)
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
