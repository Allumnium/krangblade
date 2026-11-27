extends SceneTree
const ECON = preload("res://scripts/economy_rules.gd")
const MAP = preload("res://scripts/planet_map.gd")
const MOTION_VIEW = preload("res://scripts/ship_motion_view.gd")
const HULL_ART = preload("res://scripts/hull_art.gd")
const LIGHT_BATCHES = preload("res://scripts/world_render_batches.gd")
const LIGHT_CELESTIAL = preload("res://scripts/celestial_view.gd")

func _initialize() -> void:
	if "--lighting-test" in OS.get_cmdline_user_args():
		call_deferred("_run_lighting_test")
	else:
		call_deferred("_run")

func _run() -> void:
	var art = HULL_ART.new()
	var first: Image = HULL_ART.sprite_cell(HULL_ART.FIGHTER_SPRITE, HULL_ART.FIGHTER_GRID, HULL_ART.FIGHTER_GRID, 0)
	var fighter: Image = HULL_ART.sprite_image("fighter")
	if first.is_empty() or first.get_data() != fighter.get_data():
		push_error("Fighter must use the first atlas cell.")
		quit(1)
		return
	var texture: Texture2D = art.hull_texture("fighter", Color.WHITE, true)
	if art.sprite_kind(texture) != "fighter" or art.production_icon("fighter", Color.WHITE) != texture or art.hull_texture("fighter", Color.WHITE, false) != texture:
		push_error("Fighter sprite must be shared across world and production variants.")
		quit(1)
		return
	# Test the effect contract, not exact visual dimensions or tuning.
	var motion = MOTION_VIEW.new()
	var cruise: float = MOTION_VIEW.cruise_thrust(1.0)
	if not (MOTION_VIEW.cruise_thrust(0.0) == 0.0 and MOTION_VIEW.cruise_thrust(0.01) == 0.0 and cruise > 0.0 and cruise < 1.0):
		push_error("Cruise exhaust must be absent at rest and weaker than full acceleration.")
		quit(1)
		return
	motion.ship_visuals[1] = {"age": 0.2, "duration": 0.2, "thrust": 0.8, "cruise": cruise}
	motion.active_visual_ids.append(1)
	var flare: float = motion.thrust_for(1)
	motion.advance(5.0)
	if not (flare > cruise and is_equal_approx(motion.thrust_for(1), cruise) and motion.active_visual_ids.is_empty()):
		push_error("Acceleration must fade to sustained cruise without keeping an active interpolation job.")
		quit(1)
		return
	motion.ship_visuals[1]["cruise"] = 0.0
	if motion.thrust_for(1) != 0.0:
		push_error("Stopped ships must have no exhaust.")
		quit(1)
		return
	var session: Node = root.get_node("GameSession")
	# This legacy fixture mutates canonical state and manually advances ticks.
	# Keep it on the synchronous reference path; worker tests cover async state.
	session.set("threaded_authority_requested", false)
	if bool(session.call("start_solo", 1, [], [], 827, "invalid")):
		push_error("Invalid solo map layout accepted")
		quit(1)
		return
	if not (not bool(session.call("start_solo", 1, [2], [1, 1]))):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (not bool(session.call("start_solo", 1, [2], [1, 9]))):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (not bool(session.call("start_solo", 1, [2], [1]))):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	# Exercise the public solo/session contract without depending on setup
	# controls, widget names, button state or menu construction.
	if not bool(session.call("start_solo", 1, [2, 3, 4], [7, 2, 3, 4], 827, "Radial")):
		push_error("Valid four-empire solo match was rejected.")
		quit(1)
		return
	var initial_state: Dictionary = session.get("economy")
	var roster: Dictionary = session.get("players")
	if int(initial_state["map"]["seed"]) != 827 or initial_state["map"]["layout"] != "Radial":
		push_error("Solo seed or layout was not preserved by the session.")
		quit(1)
		return
	if roster.size() != 4 or initial_state["ships"].size() != 28:
		push_error("Solo roster or starting fleets are incorrect.")
		quit(1)
		return
	for id in range(1, 5):
		if int(roster[id]["color"]) != (7 if id == 1 else id) or int(roster[id]["team"]) != id:
			push_error("Solo empire identity or unique color did not persist.")
			quit(1)
			return
	session.call("leave_solo")
	if str(session.get("phase")) != "offline":
		push_error("Leaving the solo match did not reset the session.")
		quit(1)
		return
	if not (bool(session.call("start_solo"))):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (bool(session.get("is_solo"))):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	var state: Dictionary = session.get("economy")
	if ECON.credit_balance(state, 1) != ECON.STARTING_GC:
		push_error("Solo treasury did not reset at match start.")
		quit(1)
		return
	if state["map"].get("layout") != MAP.DEFAULT_LAYOUT:
		push_error("Default solo layout is not Radial")
		quit(1)
		return
	if not (int(state["time_speed"]) == 1):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (state["ships"].size() == 7):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (state["ships"].filter(func(craft: Dictionary) -> bool: return craft["kind"] == "miner").size() == 3):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if state["ships"].filter(func(craft: Dictionary) -> bool: return craft["kind"] == "ship").size() != 1:
		push_error("Solo starting logistics ship missing.")
		quit(1)
		return
	if state["ships"].filter(func(craft: Dictionary) -> bool: return craft["kind"] == "science_ship").size() != 1:
		push_error("Solo starting Science Vessel missing or duplicated.")
		quit(1)
		return
	# Isolate original construction and colonization assertions.
	state["ships"].clear()
	session.call("request_time_speed", 0)
	var frozen: Dictionary = state.duplicate(true)
	for i in range(4):
		session.call("_economy_tick")
	# Objective cooldowns use the authority real-time clock, which runs while paused (v0.75.0).
	frozen["objective_clock"] = state.get("objective_clock", 0.0)
	if not (state == frozen):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	session.call("request_time_speed", 3)
	if not (int(state["time_speed"]) == 0):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	for speed in [1, 2, 5]:
		session.call("request_time_speed", speed)
		var before: float = float(state["elapsed"])
		var credits_before: float = ECON.credit_balance(state, 1)
		session.call("_economy_tick")
		if ECON.credit_balance(state, 1) <= credits_before:
			push_error("Solo treasury did not accrue taxes while running.")
			quit(1)
			return
		if not (is_equal_approx(float(state["elapsed"]) - before, 0.1 * float(speed))):
			push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
			quit(1)
			return
	session.call("request_time_speed", 1)
	var planets: Array = state["planets"]
	if not (planets.size() == state["map"]["points"].size()):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (state["map"]["cluster_sizes"].is_empty()):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	var neighbor: int = -1
	for i in range(1, planets.size()):
		if MAP.linked(state["map"], 0, i) and ECON.has_planets(planets[i]):
			neighbor = i
			break
	if not (neighbor >= 0):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	planets[0]["population"] = 1500.0
	planets[0]["stock"]["Metals"] = 400.0
	state["galactic_credits"][1] = 3000.0
	planets[0]["levels"]["Organics"] = 3
	# Colony and Freighter hulls require a Medium shipyard (v0.55.0).
	if planets[0]["yards"].size() != 1 or planets[0]["yards"][0]["level"] != 1:
		push_error("Starting Small shipyard missing.")
		quit(1)
		return
	planets[0]["yards"][0]["level"] = 2
	session.call("request_operation", 0, "colony_ship")
	for i in range(ceili(ECON._work("colony_ship", 1) / ECON.yard_speed(1) / 0.1) + 1):
		session.call("_economy_tick")
	if not (state["ships"].size() == 1):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	session.call("request_colonize", int(state["ships"][0]["id"]), neighbor)
	if not (int(planets[neighbor]["owner"]) == 0):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	# The default solo seed is random; budget for actual travel plus the orbital assembly.
	var colony_hull: Dictionary = state["ships"][0]
	var travel: float = (colony_hull["position"] as Vector2).distance_to(state["map"]["points"][neighbor]) / ECON.ship_speed("colony_ship")
	for i in range(ceili((travel * 1.5 + ECON.COLONY_TRANSFORM_TIME) / 0.1) + 1020):
		session.call("_economy_tick")
		if int(planets[neighbor]["owner"]) == 1:
			break
	if not (int(planets[neighbor]["owner"]) == 1):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (state["ships"].is_empty()):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (planets[neighbor]["yards"].size() == 1 and planets[neighbor]["yards"][0]["level"] == 1):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	for material in ECON._cost("ship", 1):
		planets[0]["stock"][material] = maxf(float(planets[0]["stock"][material]), float(ECON._cost("ship", 1)[material]))
	session.call("request_operation", 0, "ship")
	if not (planets[0]["queue"].size() == 1):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	for i in range(100):
		session.call("_economy_tick")
	if not (state["ships"].size() == 1):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	session.call("leave_solo")
	if not (str(session.get("phase")) == "offline"):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not ((session.get("economy") as Dictionary).is_empty()):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (bool(session.call("start_solo", 3, [3, 2], [8, 4, 6], 827, "Grid"))):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (session.get("players")[1]["color"] == 8 and session.get("players")[2]["color"] == 4 and session.get("players")[3]["color"] == 6):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	var setup: Dictionary = session.get("economy")
	if not (int(setup["time_speed"]) == 1):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if setup["map"].get("layout") != "Grid":
		push_error("Explicit solo map layout not applied")
		quit(1)
		return
	if not (setup["map"]["cluster_sizes"].is_empty()):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (setup.has("diplomacy") and ECON.diplomatic_relation(setup, 1, 2) == ECON.DIPLO_NEUTRAL and ECON.diplomatic_relation(setup, 1, 3) == ECON.DIPLO_NEUTRAL and ECON.diplomatic_relation(setup, 2, 3) == ECON.DIPLO_NEUTRAL):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (session.get("players")[2]["ai"]):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (setup["ai_players"] == [2, 3]):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (setup["ships"].size() == 21):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	for player in [1, 2, 3]:
		if setup["ships"].filter(func(craft: Dictionary) -> bool: return int(craft["owner"]) == player and craft["kind"] == "science_ship").size() != 1:
			push_error("Starting Science Vessel missing or duplicated for player %d." % player)
			quit(1)
			return
		if setup["ships"].filter(func(craft: Dictionary) -> bool: return int(craft["owner"]) == player and craft["kind"] == "ship").size() != 1:
			push_error("Starting logistics ship missing for player %d." % player)
			quit(1)
			return
	for index in [1, 2]:
		setup["planets"][index]["population"] = 1500.0
		setup["planets"][index]["stock"]["Metals"] = 400.0
		setup["planets"][index]["stock"]["Crystals"] = 75.0
		setup["galactic_credits"][index + 1] = 2000.0
		setup["planets"][index]["levels"]["Organics"] = 3
	session.call("_economy_tick")
	if not (not setup["planets"][1]["queue"].is_empty()):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (not setup["planets"][2]["queue"].is_empty()):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (setup["planets"][0]["queue"].is_empty()):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	# AI first upgrades to the Medium shipyard that Colony hulls require (v0.55.0).
	var colony_budget: float = 150.0 + ECON._work("colony_ship", 1) / ECON.yard_speed(2)
	for i in range(ceili(colony_budget * 2.0 / 0.1)):
		session.call("_economy_tick")
		if [2, 3].all(func(player: int) -> bool: return setup["ships"].any(func(ship: Dictionary) -> bool: return int(ship["owner"]) == player and ship["kind"] == "colony_ship")):
			break
	for player in [2, 3]:
		if not (setup["ships"].any(func(ship: Dictionary) -> bool: return int(ship["owner"]) == player and ship["kind"] == "colony_ship")):
			push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
			quit(1)
			return
	session.call("leave_solo")
	print("PASS: offline solo planetary match, colonization, ship construction, reset")
	quit(0)

# Opt-in rendered regression. The ordinary headless solo smoke stays unchanged.
# Run with a real GL Compatibility renderer, not Godot's headless dummy renderer.
func _lighting_capture(viewport: SubViewport) -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func _lighting_luma(c: Color) -> float:
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722

func _lighting_measure(reference: Image, dark: Image, lit: Image, sample: Dictionary, star: Vector2) -> Dictionary:
	var center: Vector2 = sample["center"]
	var extent: float = sample["extent"]
	var toward: Vector2 = (star - center).normalized()
	var reach: int = ceili(extent * sqrt(2.0))
	var totals: Array[float] = [0.0, 0.0]
	var weights: Array[float] = [0.0, 0.0]
	var counts: Array[int] = [0, 0]
	for y in range(floori(center.y) - reach, ceili(center.y) + reach):
		for x in range(floori(center.x) - reach, ceili(center.x) + reach):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var projection: float = (p - center).dot(toward)
			# Ignore the centerline and background/transparent fringe. Reference
			# is the identical rendered batch with its lighting material removed.
			if absf(projection) < extent * 0.10:
				continue
			var base: Color = reference.get_pixel(x, y)
			var weight: float = _lighting_luma(base)
			if base.a < 0.95 or weight < 0.07:
				continue
			var side: int = 0 if projection > 0.0 else 1
			var response: float = maxf(0.0, _lighting_luma(lit.get_pixel(x, y)) - _lighting_luma(dark.get_pixel(x, y)))
			totals[side] += response
			weights[side] += weight
			counts[side] += 1
	var near: float = totals[0] / maxf(weights[0], 0.001)
	var far: float = totals[1] / maxf(weights[1], 0.001)
	var valid: bool = counts[0] >= 20 and counts[1] >= 20 and near + far >= 0.025
	return {"kind": sample["kind"], "bearing_deg": sample["bearing_deg"], "heading_deg": sample["heading_deg"], "extent": extent, "near": near, "far": far, "near_pixels": counts[0], "far_pixels": counts[1], "valid": valid, "correct_side": valid and near > far}

func _run_lighting_test() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Lighting regression requires a rendering display; use xvfb-run on Linux, not --headless.")
		quit(1)
		return
	var output: String = OS.get_environment("WARBOUND_LIGHTING_OUTPUT")
	if output.is_empty():
		output = "user://lighting-test"
	output = ProjectSettings.globalize_path(output)
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot create lighting report folder: " + output)
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 1152)
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := Control.new()
	canvas.size = Vector2(viewport.size)
	viewport.add_child(canvas)
	var art = HULL_ART.new()
	var batches = LIGHT_BATCHES.new()
	batches.build(canvas)
	var celestial = LIGHT_CELESTIAL.new()
	var star := Vector2(viewport.size) * 0.5
	var tint := Color("#ffe6bb")
	# Draw the actual star art. No fog, selection, exhaust or impact lights.
	canvas.draw.connect(func() -> void:
		celestial.draw_star(0, star, 44.0, tint, false, 1.0, canvas, 0.0)
	)
	canvas.queue_redraw()
	var kinds: Array[String] = ["fighter", "science_ship", "ship"]
	var results: Array[Dictionary] = []
	var all_valid: bool = true
	# All eight azimuths for each hull at four distinct absolute headings,
	# at two rendered sizes. Keep ring populations independent of heading.
	for size_index in range(2):
		var extent: float = 44.0 if size_index == 0 else 32.0
		for rotation_index in range(4):
			var samples: Array[Dictionary] = []
			batches.begin_frame()
			for kind_index in range(kinds.size()):
				var kind: String = kinds[kind_index]
				var texture: Texture2D = art.hull_texture(kind, Color("#63a9df"), true)
				var radius: float = 175.0 + 150.0 * float(kind_index)
				for bearing_index in range(8):
					var bearing: float = TAU * float(bearing_index) / 8.0
					var heading: float = PI * 0.5 * float(rotation_index)
					var center: Vector2 = star + Vector2.from_angle(bearing) * radius
					batches.queue_overview_hull(texture, center, heading + HULL_ART.sprite_heading_offset(kind), extent)
					samples.append({"kind": kind, "center": center, "extent": extent, "bearing_deg": bearing_index * 45, "heading_deg": rotation_index * 90})
			batches.set_world_lights([])
			batches.flush_world(0.0, art)
			var materials: Dictionary = {}
			for texture in batches.overview_batches:
				var instance: MultiMeshInstance2D = batches.overview_batches[texture]
				materials[texture] = instance.material
				instance.material = null
			var reference: Image = await _lighting_capture(viewport)
			for texture in materials:
				batches.overview_batches[texture].material = materials[texture]
			var dark: Image = await _lighting_capture(viewport)
			batches.set_world_lights([[star, 1600.0, tint, 1.55, 0.0, true]])
			var lit: Image = await _lighting_capture(viewport)
			if reference == null or dark == null or lit == null or reference.is_empty() or dark.is_empty() or lit.is_empty():
				push_error("Lighting test did not obtain rendered pixels.")
				quit(1)
				return
			var prefix: String = "%s/size%d_heading%d" % [output, size_index, rotation_index * 90]
			if reference.save_png(prefix + "_reference.png") != OK or dark.save_png(prefix + "_ambient.png") != OK or lit.save_png(prefix + "_stellar.png") != OK:
				all_valid = false
			for sample in samples:
				var result: Dictionary = _lighting_measure(reference, dark, lit, sample, star)
				results.append(result)
				if not result["valid"]:
					all_valid = false
				if not result["correct_side"]:
					print("LIGHTING SUSPECT ", JSON.stringify(result))
	var groups: Dictionary = {}
	# Score the broad lighting orientation, not individual decorative
	# pixels. Report every inverted case even if its group passes.
	for kind in kinds:
		for size_index in range(2):
			for heading_index in range(4):
				var key: String = "%s/size%d/heading%d" % [kind, size_index, heading_index * 90]
				var count: int = 0
				var valid: int = 0
				var near: float = 0.0
				var far: float = 0.0
				for result in results:
					if result["kind"] != kind or result["extent"] != (44.0 if size_index == 0 else 32.0) or result["heading_deg"] != heading_index * 90:
						continue
					valid += 1 if result["valid"] else 0
					count += 1 if result["correct_side"] else 0
					near += float(result["near"])
					far += float(result["far"])
				var passed: bool = valid == 8 and count >= 6 and near > far * 1.15
				groups[key] = {"pass": passed, "valid": valid, "correct_side": count, "near_sum": near, "far_sum": far}
				all_valid = all_valid and passed
				print("LIGHTING GROUP ", key, " ", JSON.stringify(groups[key]))
	var report := {"passed": all_valid, "case_count": results.size(), "groups": groups, "cases": results, "criterion": "8 valid bearings per group; >=6 correct; aggregate near response >1.15*far response"}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Could not write lighting report.")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("Lighting report: ", output, " passed=", all_valid)
	viewport.queue_free()
	quit(0 if all_valid else 1)
