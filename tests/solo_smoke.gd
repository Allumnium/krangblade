extends SceneTree
const ECON = preload("res://scripts/economy_rules.gd")
const MAP = preload("res://scripts/planet_map.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
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
	if roster.size() != 4 or initial_state["ships"].size() != 24:
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
	if not (state["ships"].size() == 6):
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
	if not (state["map"]["cluster_sizes"].size() == MAP.cluster_count_for(1, MAP.DEFAULT_LAYOUT)):
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
	session.call("request_operation", 0, "yard")
	for i in range(ceili(ECON._work("yard", 1) / 0.1) + 1):
		session.call("_economy_tick")
	if planets[0]["yards"].size() != 1:
		push_error("First shipyard must be built explicitly.")
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
	if not (planets[neighbor]["yards"].is_empty()):
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
	if not (setup["map"]["cluster_sizes"].size() == MAP.cluster_count_for(3, "Grid")):
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
	if not (setup["ships"].size() == 18):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	for player in [1, 2, 3]:
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
