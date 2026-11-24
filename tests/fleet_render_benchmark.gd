extends SceneTree

const ECON = preload("res://scripts/economy_rules.gd")

func _initialize() -> void:
	call_deferred("_run")

func _stats(samples: Array[float]) -> Dictionary:
	var sorted: Array[float] = samples.duplicate()
	sorted.sort()
	return {
		"p50_ms": sorted[ceili(sorted.size() * 0.50) - 1],
		"p95_ms": sorted[ceili(sorted.size() * 0.95) - 1],
		"p99_ms": sorted[ceili(sorted.size() * 0.99) - 1],
		"max_ms": sorted.back(),
	}

func _run() -> void:
	var ship_count: int = 2000
	var frame_count: int = 300
	var seed_value: int = 827
	var zoom: float = 5.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ships="):
			ship_count = int(arg.get_slice("=", 1))
		elif arg.begins_with("--frames="):
			frame_count = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.get_slice("=", 1))
		elif arg.begins_with("--zoom="):
			zoom = float(arg.get_slice("=", 1))
	if ship_count < 1 or frame_count < 30:
		push_error("Render benchmark requires at least one ship and 30 frames.")
		quit(2)
		return

	DisplayServer.window_set_size(Vector2i(1280, 720))
	var session: Node = root.get_node("GameSession")
	session.set("threaded_authority_requested", false)
	if not bool(session.call("start_solo", 1, [], [], seed_value, "Radial")):
		push_error("Could not start the solo render benchmark match.")
		quit(1)
		return
	var state: Dictionary = session.get("economy")
	state["time_speed"] = 1
	state["fog_of_war"] = false
	state["ships"].clear()
	var home: Vector2 = state["map"]["points"][0]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in range(ship_count):
		var position: Vector2 = home + Vector2.from_angle(rng.randf_range(0.0, TAU)) * sqrt(rng.randf()) * 2200.0
		state["ships"].append({
			"id": index + 1,
			"kind": "fighter",
			"owner": 1,
			"origin": 0,
			"at": 0,
			"position": position,
			"heading": Vector2.from_angle(rng.randf_range(0.0, TAU)),
			"navigation_target": position,
			"route": [],
			"leg": 0.0,
			"source": -1,
			"dest": -1,
			"hp": ECON.SHIP_HP,
			"crew": 0.0,
			"cargo": ECON.empty_stock(),
			"field": -1,
			"mining_mode": "idle",
			"field_leg": 0.0,
		})
	state["next_id"] = ship_count + 1
	session.get("economy_timer").stop()

	var match_scene: Node
	for _frame in range(120):
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/match.tscn":
			match_scene = current_scene
			break
	if match_scene == null or not match_scene.has_method("_screen_point"):
		push_error("Match scene did not load for the render benchmark.")
		quit(1)
		return
	session.emit_signal("economy_changed")
	for _frame in range(30):
		await process_frame
	var match_settings: Object = match_scene.get("match_settings")
	match_settings.set("keyboard_pan_percent", 0.0)
	match_settings.set("mouse_pan_percent", 0.0)
	var camera: Object = match_scene.get("camera")
	camera.set("following", false)
	match_scene.call("_center_world", home)
	camera.set("zoom", zoom)
	for _frame in range(5):
		await process_frame
	var home_screen: Vector2 = match_scene.call("_screen_point", home)
	var visible_pose_count: int = (match_scene.call("_ship_poses", state) as Dictionary).size()

	var samples: Array[float] = []
	var draw_call_samples: Array[float] = []
	var previous_usec: int = Time.get_ticks_usec()
	for _frame in range(frame_count):
		await process_frame
		var now_usec: int = Time.get_ticks_usec()
		samples.append(float(now_usec - previous_usec) / 1000.0)
		draw_call_samples.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		previous_usec = now_usec
	var screenshot_path: String = "user://fleet_render_%d_%d.png" % [ship_count, Time.get_ticks_msec()]
	var screenshot_error: int = root.get_texture().get_image().save_png(screenshot_path)
	if screenshot_error != OK:
		push_error("Could not save render benchmark screenshot (error %d)." % screenshot_error)
		quit(1)
		return
	var result: Dictionary = {
		"version": ProjectSettings.get_setting("application/config/version"),
		"engine": Engine.get_version_info()["string"],
		"cpu": OS.get_processor_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"window": DisplayServer.window_get_size(),
		"mode": "match_render_only_simulation_stopped",
		"seed": seed_value,
		"ships": ship_count,
		"camera_zoom": camera.get("zoom"),
		"camera_world": camera.get("world"),
		"camera_following": camera.get("following"),
		"map_size": state["map"]["size"],
		"home_world": home,
		"home_screen": home_screen,
		"visible_ship_poses": visible_pose_count,
		"warmup_frames": 30,
		"measured_frames": frame_count,
		"frame_ms": _stats(samples),
		"avg_2d_draw_calls": draw_call_samples.reduce(func(total: float, count: float) -> float: return total + count, 0.0) / float(draw_call_samples.size()),
		"frames_over_16_67ms": samples.filter(func(sample: float) -> bool: return sample > 16.67).size(),
		"screenshot": ProjectSettings.globalize_path(screenshot_path),
	}
	print("FLEET_RENDER " + JSON.stringify(result))
	quit()
