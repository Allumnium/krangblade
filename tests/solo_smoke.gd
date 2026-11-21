extends SceneTree
const ECON = preload("res://scripts/economy_rules.gd")
const MAP = preload("res://scripts/planet_map.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session: Node = root.get_node("GameSession")
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
	var menu: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(menu)
	menu.call("_show_solo_setup")
	var initial: Dictionary = menu.get("solo_players")
	if not (initial.size() == 4):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	for id in range(1, 5):
		if not (initial[id]["team"] == id and initial[id]["color"] == id):
			push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
			quit(1)
			return
		var row: Dictionary = menu.get("solo_rows")[id]
		if not ((row["color"] as OptionButton).is_item_disabled(0) == (id != 1)):
			push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
			quit(1)
			return
	menu.call("_solo_color_selected", 4, 1)
	if not (initial[1]["color"] == 5):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	menu.call("_solo_color_selected", 1, 1)
	if not (initial[1]["color"] == 5):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	for i in range(4):
		(menu.get("solo_add_button") as Button).pressed.emit()
	if not (initial.size() == 8 and (menu.get("solo_add_button") as Button).disabled):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	menu.call("_remove_solo_player", 8)
	if not ((menu.get("solo_players") as Dictionary).size() == 7):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (menu.get("solo_players").has(1)):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (not (menu.get("solo_add_button") as Button).disabled):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	menu.call("_show_menu")
	menu.call("_show_solo_setup")
	if not ((menu.get("solo_players") as Dictionary).size() == 4):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	menu.call("_show_multiplayer")
	if not (menu.get("screen") == "multiplayer"):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	menu.call("_show_solo_setup")
	menu.call("_solo_color_selected", 6, 1)
	var expected_seed: int = int(menu.get("solo_random_seed"))
	menu.call("_start_solo_from_setup")
	if int(session.get("economy")["map"]["seed"]) != expected_seed:
		push_error("Solo start did not retain the preview seed.")
		quit(1)
		return
	if not (session.get("players").size() == 4 and session.get("players")[1]["color"] == 7):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	if not (session.get("economy")["ships"].size() == 24):
		push_error("Solo smoke assertion failed at original line " + str(get_stack()[0]["line"]))
		quit(1)
		return
	session.call("leave_solo")
	menu.free()
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
		session.call("_economy_tick")
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
	planets[0]["population"] = 150000.0
	planets[0]["levels"]["Organics"] = 3
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
	for i in range(1020):
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
	if not (planets[neighbor]["yards"].size() == 1):
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
		setup["planets"][index]["population"] = 150000.0
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
	for i in range(250):
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
