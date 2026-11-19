extends SceneTree
## Run with --script res://tests/network_smoke.gd -- host 2
## or --script res://tests/network_smoke.gd -- client 2 1
var session: Node
var role: String = ""
var expected_players: int = 2
var saw_match: bool = false
var started: bool = false
var finishing: bool = false
var ready_sent: bool = false
var color_requested: bool = false
var expected_color: int = 0
var economy_verified: bool = false
var observed_commands: Dictionary = {}
var home_index: int = -1
var cancel_id: int = -1
var cancel_sent: bool = false
var cancelled_yard_id: int = -1
var promoted_yard_id: int = -1
var yard_rebuilt: bool = false
var commands_sent: bool = false
var hold_release_id: int = -1
var hold_release_sent: bool = false
var hold_release_verified: bool = false
var miner_weapon_verified: bool = false
var next_diagnostic: float = 10.0
var speed_stage: int = 0
var paused_elapsed: float = -1.0
const TEST_SPEEDS: Array[int] = [0, 2, 5, 1]
const ECON = preload("res://scripts/economy_rules.gd")
var saw_loading: bool = false
var preview_seed: int = 0
var mode: String = "normal"
const MAP = preload("res://scripts/planet_map.gd")
const RULES = preload("res://scripts/lobby_rules.gd")

func _expected_layout() -> String:
	return ("Grid" if expected_players == 2 else "Hex Grid") if mode == "normal" else MAP.DEFAULT_LAYOUT

func _initialize() -> void:
	call_deferred("_begin")

func _begin() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		_fail("Missing role/count arguments.")
		return
	role = args[0]
	expected_players = int(args[1])
	mode = str(args[2]) if role == "host" and args.size() >= 3 else (str(args[3]) if role == "client" and args.size() >= 4 else "normal")
	session = root.get_node_or_null("GameSession")
	if session == null:
		_fail("GameSession autoload is missing.")
		return
	session.connect("phase_changed", _phase_changed)
	session.connect("roster_changed", _roster_changed)
	create_timer(65.0).timeout.connect(func() -> void: _fail("Network smoke test timed out."))
	if role == "host":
		if not bool(session.call("host_game", "TestHost")):
			_fail("Could not host.")
	elif role == "client":
		var index: int = int(args[2]) if args.size() >= 3 else 1
		if mode == "normal":
			session.call("start_lobby_browser", "127.0.0.1")
			var deadline: int = Time.get_ticks_msec() + 8000
			while not session.get("discovered_lobbies").has("127.0.0.1") and Time.get_ticks_msec() < deadline:
				await process_frame
			var games: Dictionary = session.get("discovered_lobbies")
			if not games.has("127.0.0.1") or games["127.0.0.1"]["name"] != "TestHost" or games["127.0.0.1"]["layout"] != _expected_layout():
				_fail("LAN host discovery did not return the actual lobby.")
				return
			session.call("stop_lobby_browser")
		if not bool(session.call("join_game", "Guest%d" % index, "127.0.0.1")):
			_fail("Could not join.")
	else:
		_fail("Unrecognized role.")

func _roster_changed() -> void:
	if session == null or str(session.get("phase")) != "lobby" or saw_match:
		return
	var roster: Dictionary = session.get("players")
	if role == "host":
		if not color_requested:
			color_requested = true
			session.call("reroll_lobby_map")
			session.call("choose_map_layout", _expected_layout())
			session.call("choose_map_layout", "invalid")
			session.call("choose_color", 1, 8)
			return
		if roster.size() == expected_players and not started and bool(session.call("can_start")):
			started = true
			session.call_deferred("start_match")
	elif role == "client":
		var self_id: int = session.multiplayer.get_unique_id()
		var entry: Dictionary = roster.get(self_id, {})
		if not entry.is_empty() and not color_requested:
			color_requested = true
			if str(session.get("map_layout")) != _expected_layout():
				_fail("Host map layout did not replicate to lobby guest.")
				return
			var seed_before: int = int(session.get("lobby_map_seed"))
			session.call("reroll_lobby_map")
			if int(session.get("lobby_map_seed")) != seed_before:
				_fail("Guest was able to reroll the map.")
				return
			session.call("choose_map_layout", "Radial" if _expected_layout() != "Radial" else "Grid")
			expected_color = 7 if expected_players == 2 else int(entry["color"])
			session.call("choose_color", self_id, 8) # occupied by host; must reject
			if expected_players == 2:
				session.call("choose_color", self_id, 7)
			return
		if not entry.is_empty() and int(entry.get("color", 0)) == expected_color and not bool(entry.get("ready", false)) and not ready_sent:
			ready_sent = true
			session.call_deferred("toggle_ready")

func _phase_changed() -> void:
	if session == null:
		return
	var phase: String = str(session.get("phase"))
	if phase == "loading":
		preview_seed = int(session.get("lobby_map_seed"))
		saw_loading = true
		if mode == "drop-loading" and role == "client":
			session.call_deferred("leave_session")
	elif phase == "match" and not saw_match:
		saw_match = true
		if mode == "drop-loading":
			_fail("Match started despite loading guest departing.")
			return
		var roster: Dictionary = session.get("players")
		if roster.size() != expected_players:
			_fail("Wrong roster size in match: %d" % roster.size())
			return
		var colors: Dictionary = {}
		for entry in roster.values():
			var choice: int = int(entry.get("color", 0))
			if choice < 1 or choice > 8 or colors.has(choice):
				_fail("Empire colors must be unique and valid.")
				return
			colors[choice] = true
		if int(roster[1]["color"]) != 8 or (expected_players == 2 and not colors.has(7)):
			_fail("Selected empire colors did not replicate.")
			return
		var owners: Array[int] = session.get("owners")
		var state: Dictionary = session.get("economy")
		if str(session.get("map_layout")) != _expected_layout() or state["map"].get("layout") != _expected_layout():
			_fail("Match map layout did not match host setting.")
			return
		if int(state["map"]["seed"]) != preview_seed or state["map"] != MAP.generate(preview_seed, expected_players, _expected_layout()):
			_fail("Generated map does not match authoritative seed and layout.")
			return
		if mode == "normal" and not _check_map_codec(state):
			_fail("Static-map codec failed exact inventory round trip.")
			return
		if mode == "normal" and not _check_planet_motion_codec(state):
			_fail("Planet template or motion codec failed round trip.")
			return
		for owner in roster:
			var miners: int = 0
			var fighters: int = 0
			for craft in state["ships"]:
				if int(craft["owner"]) == int(owner):
					miners += 1 if craft["kind"] == "miner" else 0
					fighters += 1 if craft["kind"] == "fighter" else 0
			if miners != 3 or fighters != 2:
				_fail("Starting fleet did not replicate.")
				return
		if owners.size() != state["map"]["points"].size() or state["map"]["cluster_sizes"].size() != MAP.cluster_count_for(expected_players, _expected_layout()):
			_fail("Wrong territory count.")
			return
		if mode == "normal":
			if role == "host":
				var ordered: Array[int] = RULES.ordered_peers(roster)
				for index in range(ordered.size()):
					var outpost: Dictionary = state["planets"][int(state["map"]["planetless"][index])]
					outpost["owner"] = ordered[index]
					outpost["station"] = {"hp": ECON.STATION_HP}
					for resource in ECON.ORBITAL_HOUSING_COST:
						outpost["stock"][resource] = ECON.ORBITAL_HOUSING_COST[resource]
				# Isolate station destruction from the home-system RPC scenarios.
				var target_index: int = int(state["map"]["planetless"][expected_players])
				var target: Dictionary = state["planets"][target_index]
				target["owner"] = ordered[1]
				target["station"] = {"hp": ECON.LASER_DAMAGE}
				target["stock"]["Metals"] = 100.0
				var assault: Dictionary = {"id": 960000, "kind": "fighter", "owner": ordered[0], "origin": 0, "at": target_index, "dest": target_index, "operation_target": target_index, "route": [], "leg": 0.0, "position": ECON.station_position(state, target_index, 0.0), "heading": Vector2.UP, "hp": ECON.SHIP_HP, "holding": true, "cargo": ECON.empty_stock()}
				state["ships"].append(assault)
				# A separate neutral system isolates mining-laser combat from
				# the home command fixtures and station assault.
				var remote: int = -1
				var clearance: float = -1.0
				for candidate in range(state["planets"].size()):
					if int(state["planets"][candidate]["owner"]) != 0:
						continue
					var nearest: float = INF
					for occupied in range(state["planets"].size()):
						if int(state["planets"][occupied]["owner"]) != 0:
							nearest = minf(nearest, (state["map"]["points"][candidate] as Vector2).distance_to(state["map"]["points"][occupied]))
					if nearest > clearance:
						remote = candidate
						clearance = nearest
				assert(remote >= 0)
				var test_point: Vector2 = state["map"]["points"][remote]
				for slot in range(2):
					var kind: String = "miner" if slot == 0 else "ship"
					var hull: Dictionary = {"id": 970000 + slot, "kind": kind, "owner": ordered[slot], "origin": slot, "at": remote, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": test_point + Vector2.RIGHT * 100.0 * slot, "heading": Vector2.UP, "hp": ECON.SHIP_HP, "holding": true, "cargo": ECON.empty_stock()}
					hull["cargo"]["Metals"] = ECON.cargo_capacity(kind)
					state["ships"].append(hull)
				for system in state["planets"]:
					if bool(system["home"]):
						system["population"] = 150000.0
						system["levels"]["Organics"] = 3
						for resource in ECON.RESOURCES:
							system["stock"][resource] = maxf(float(system["stock"][resource]), 25000.0)
						# Dedicated held hull and salvage pile for the real RPC test.
						var index: int = state["planets"].find(system)
						ECON._finish(state, index, system, {"id": 900000 + index, "kind": "colony_ship", "population_allocated": ECON.CREW_COSTS["colony_ship"]})
						var craft: Dictionary = state["ships"].back()
						craft["holding"] = true
						var graph: Dictionary = ECON.military_graph(state)
						var repair_point: Vector2 = graph["points"][index] + Vector2.DOWN * minf(350.0, ECON.sector_limit(graph, index, Vector2.DOWN) * 0.5)
						var repairer: Dictionary = {"id": 980000 + index, "kind": "miner", "owner": system["owner"], "origin": index, "at": index, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": repair_point, "heading": Vector2.UP, "hp": ECON.SHIP_HP, "holding": true, "cargo": ECON.empty_stock(), "mining_mode": "delivery", "field": -1}
						repairer["cargo"][ECON.ANTIMATTER] = 3.0
						var repair_victim: Dictionary = repairer.duplicate(true)
						repair_victim.merge({"id": 990000 + index, "kind": "ship", "position": repair_point + Vector2.RIGHT * 40, "hp": ECON.SHIP_HP - 12.0, "cargo": ECON.empty_stock()}, true)
						state["ships"].append(repairer)
						state["ships"].append(repair_victim)
						var point: Vector2 = graph["points"][index] + Vector2.RIGHT * minf(150.0, ECON.sector_limit(graph, index, Vector2.RIGHT) * 0.5)
						var pile_id: int = 910000 + index
						state["salvage"][pile_id] = {"id": pile_id, "resource": ECON.ANTIMATTER, "amount": 12.0, "origin": point, "position": point, "drift": Vector2.ZERO, "born": 0.0, "claim": -1}
						# A separate held hull passively collects a local pile, without RPCs.
						ECON._finish(state, index, system, {"id": 930000 + index, "kind": "colony_ship", "population_allocated": ECON.CREW_COSTS["colony_ship"]})
						var auto_craft: Dictionary = state["ships"].back()
						auto_craft["holding"] = true
						var auto_point: Vector2 = graph["points"][index] + Vector2.LEFT * ECON.sector_limit(graph, index, Vector2.LEFT) * 0.8
						auto_craft["position"] = auto_point
						auto_craft["hold_position"] = auto_point
						auto_craft["hold_sector"] = index
						var auto_pile_id: int = 940000 + index
						state["salvage"][auto_pile_id] = {"id": auto_pile_id, "resource": "Crystals", "amount": 2.0, "origin": auto_point, "position": auto_point, "drift": Vector2.ZERO, "born": 0.0, "expires_at": 105.0, "claim": -1}
						# Separate focus-fire hull so the existing movement and hold
						# scenarios remain independent of this command.
						ECON._finish(state, index, system, {"id": 920000 + index, "kind": "fighter", "population_allocated": 0.0})
						# The queued fighter in this scenario is deliberately canceled;
						# supply a distinct completed launch to validate rally replication.
						var rally_point: Vector2 = graph["points"][index] + Vector2.UP * ECON.sector_limit(graph, index, Vector2.UP) * 0.65
						ECON.set_shipyard_rally(state, int(system["owner"]), index, 0, index, rally_point)
						var launch_id: int = 950000 + index
						system["yards"][0]["job"] = launch_id
						ECON._finish(state, index, system, {"id": launch_id, "kind": "fighter", "population_allocated": 0.0})
						system["yards"][0]["job"] = -1
						ECON.set_shipyard_rally(state, int(system["owner"]), index, 0, -1, Vector2.ZERO)
				session.call("_publish_economy")
			call_deferred("_prepare_commands")
			create_timer(0.5).timeout.connect(_check_economy_sync)
		if role == "host":
			if mode == "host-leave":
				create_timer(1.0).timeout.connect(func() -> void: session.call("leave_session"))
			elif mode == "normal":
				create_timer(0.25).timeout.connect(_return_after_all_verified)
	elif phase == "lobby" and saw_loading and not finishing:
		if (mode == "drop-loading" and role == "host") or (mode == "normal" and saw_match):
			if mode == "normal" and not economy_verified:
				_fail("Never verified all multiplayer command and replication checks before return.")
				return
			finishing = true
			var roster: Dictionary = session.get("players")
			var expected: int = 1 if mode == "drop-loading" else expected_players
			if roster.size() != expected:
				_fail("Wrong roster size after return.")
				return
			for id in roster.keys():
				if int(id) != 1 and bool((roster[id] as Dictionary).get("ready", true)):
					_fail("Guest remained ready after return.")
					return
			if role == "host" and mode == "normal":
				_wait_for_guest_completion()
			else:
				call_deferred("_finish_guest_return")
	elif phase == "offline" and not finishing:
		if (mode == "host-leave" and saw_match) or (mode == "drop-loading" and saw_loading and role == "client"):
			finishing = true
			create_timer(0.8 if role == "host" else 0.2).timeout.connect(_pass)
		else:
			_fail("Connection closed before expected transition.")

func _prepare_commands() -> void:
	var state: Dictionary = session.get("economy")
	var self_id: int = session.multiplayer.get_unique_id()
	for i in range((state["planets"] as Array).size()):
		if int(state["planets"][i]["owner"]) == self_id:
			home_index = i
			break
	if home_index < 0:
		_fail("No home system for player.")
		return
	if bool(state.get("fog_of_war", true)) or (state["map"]["fields"] as Array).is_empty():
		_fail("Expected fully visible map and at least one asteroid field.")
		return
	for i in range((state["planets"] as Array).size()):
		if not ECON.discovered(state, self_id, "planets", i):
			_fail("System hidden with fog disabled.")
			return
	for i in range((state["map"]["fields"] as Array).size()):
		if not ECON.discovered(state, self_id, "fields", i):
			_fail("Asteroid field hidden with fog disabled.")
			return

	if role == "host":
		session.call("request_time_speed", 0)

# Each real peer acknowledges the observed speed before the host advances.
# Reuse otherwise untouched local Crystals thresholds as test acknowledgments.
func _check_time_controls(state: Dictionary) -> bool:
	if speed_stage >= TEST_SPEEDS.size():
		return true
	var expected: int = TEST_SPEEDS[speed_stage]
	var current: int = int(state.get("time_speed", -1))
	if current != expected:
		var speed_requester: bool = (role == "client" and home_index == 1) if expected == 2 else role == "host"
		if speed_requester and speed_stage > 0:
			var confirmed: int = 0
			for system in state["planets"]:
				if bool(system["home"]) and is_equal_approx(float(system["thresholds"]["Crystals"]["min"]), 12.0 + float(speed_stage - 1)):
					confirmed += 1
			if confirmed == expected_players:
				session.call("request_time_speed", expected)
		return false
	if speed_stage == 0:
		if paused_elapsed < 0.0:
			paused_elapsed = float(state["elapsed"])
			# Invalid values are rejected from both host and guest.
			session.call("request_time_speed", 3 if role == "host" else 10)
			return false
		if not is_equal_approx(float(state["elapsed"]), paused_elapsed):
			_fail("Clock advanced while paused.")
			return false
		# Queue and cancel a timed station purchase on every peer
		# while paused, so the replicated queue and refund are observable.
		var outpost_index: int = int(state["map"]["planetless"][home_index])
		var outpost: Dictionary = state["planets"][outpost_index]
		if not bool(get_meta("station_queue_sent", false)):
			set_meta("station_queue_sent", true)
			session.call("request_operation", outpost_index, "economy", "orbital_housing")
			return false
		if not bool(get_meta("station_cancel_sent", false)):
			for job in outpost["queue"]:
				if job["kind"] == "orbital_housing":
					if int(outpost.get("orbital_housing", 0)) != 0 or int(job["size"]) != 0 or job["cost"] != ECON.ORBITAL_HOUSING_COST or float(job["work"]) != ECON._work("orbital_housing", 1) or float(job["progress"]) != 0.0:
						_fail("Station infrastructure queue did not replicate correctly.")
						return false
					set_meta("station_cancel_sent", true)
					session.call("request_cancel", outpost_index, int(job["id"]))
					break
			return false
		if not outpost["queue"].is_empty():
			return false
		for resource in ECON.ORBITAL_HOUSING_COST:
			if not is_equal_approx(float(outpost["stock"][resource]), float(ECON.ORBITAL_HOUSING_COST[resource])):
				_fail("Station construction cancellation did not refund materials.")
				return false
		# Explicit salvage is tested while paused, before automatic collection
		# can sweep the same fixture. Guest commands use the actual RPC path.
		var other: int = 900000 + (home_index + 1) % expected_players
		session.call("request_salvage", [900000 + home_index, other], 910000 + home_index)
		session.call("request_unload_cargo", [other])
		session.call("request_salvage", [900000 + home_index], 910000 + home_index)
	if speed_stage < TEST_SPEEDS.size() - 1:
		session.call("request_thresholds", home_index, "Crystals", 12.0 + float(speed_stage), 25.0)
	speed_stage += 1
	return speed_stage >= TEST_SPEEDS.size()

func _send_commands() -> void:
	commands_sent = true
	var initial: Dictionary = session.get("economy")
	var field_node: int = initial["planets"].size()
	var own_fighters: Array[int] = []
	var own_miners: Array[int] = []
	var enemy_miner: int = -1
	var enemy_fighter: int = -1
	var self_id: int = session.multiplayer.get_unique_id()
	for craft in initial["ships"]:
		if craft["kind"] == "miner":
			if int(craft["owner"]) == self_id:
				own_miners.append(int(craft["id"]))
			else:
				enemy_miner = int(craft["id"])
		if craft["kind"] != "fighter":
			continue
		if int(craft["owner"]) == self_id:
			own_fighters.append(int(craft["id"]))
		else:
			enemy_fighter = int(craft["id"])
	var mining_field: int = -1
	for i in range(initial["map"]["fields"].size()):
		var field: Dictionary = initial["map"]["fields"][i]
		if i != 0 and not bool(field.get("antimatter", false)) and ECON.field_access_systems(initial["map"], field).has(home_index) and not field["chunks"].is_empty():
			mining_field = i
			break
	if mining_field < 0:
		var teams: Array[int] = ECON.planet_teams(initial)
		var team: int = int(initial["teams"][self_id])
		for i in range(1, initial["map"]["fields"].size()):
			var field: Dictionary = initial["map"]["fields"][i]
			if bool(field.get("antimatter", false)) or field["chunks"].is_empty():
				continue
			for anchor in ECON.field_access_systems(initial["map"], field):
				if not ECON._mining_path(initial, teams, team, home_index, anchor, {}).is_empty():
					mining_field = i
					break
			if mining_field >= 0:
				break
	if mining_field < 0:
		_fail("No reachable regular mining field for command test.")
		return
	session.call("request_miner_assignment", [own_miners[0]], mining_field)
	session.call("request_miner_assignment", [own_miners[0], enemy_miner], -1)
	session.call("request_miner_assignment", [own_miners[0]], 999999)
	session.call("request_fighter_move", [own_fighters[0]], field_node, true)
	var patrol_graph: Dictionary = ECON.military_graph(initial)
	var patrol_point: Vector2 = patrol_graph["points"][field_node] + Vector2.UP * ECON.sector_limit(patrol_graph, field_node, Vector2.UP) * 0.3
	session.call("request_unit_orders", [{"ids": [own_fighters[0]], "order": {"kind": "patrol", "target": field_node, "point": patrol_point}}], false)
	session.call("request_unit_orders", [{"ids": [own_fighters[0]], "order": {"kind": "patrol", "target": field_node, "point": Vector2.INF}}], false)
	session.call("request_tactical_order", [own_fighters[0], enemy_fighter], "patrol", home_index)
	session.call("request_tactical_order", [own_fighters[0]], "patrol", -1)
	var attack_id: int = 920000 + home_index
	var service_id: int = 980000 + home_index
	session.call("request_autocast", [service_id], "repair", false)
	session.call("request_autocast", [service_id], "mine", false)
	session.call("request_autocast", [service_id], "salvage", true)
	session.call("request_autocast", [service_id], "wander", false)
	session.call("request_repair_auto", [980000 + (home_index + 1) % expected_players], false)
	session.call("request_unit_orders", [{"ids": [service_id], "order": {"kind": "repair", "target": 990000 + home_index}}], false)
	session.call("request_unit_orders", [{"ids": [service_id], "order": {"kind": "deposit", "target": ECON.station_target_id(initial, home_index)}}], true)
	var victim_id: int = 920000 + (home_index + 1) % expected_players
	session.call("request_tactical_order", [attack_id], "attack", victim_id)
	session.call("request_unit_orders", [{"ids": [attack_id], "order": {"kind": "sector_entry", "target": home_index, "move_only": true}}], true)
	session.call("request_unit_orders", [{"ids": [attack_id, victim_id], "order": {"kind": "sector", "target": field_node}}], true)
	session.call("request_tactical_order", [attack_id], "attack", own_fighters[0])
	session.call("request_tactical_order", [attack_id, victim_id], "patrol", field_node)
	session.call("request_tactical_order", [attack_id], "invalid", home_index)
	session.call("request_fighter_move", [own_fighters[0]], -1)
	session.call("request_fighter_move", [own_fighters[0], enemy_fighter], home_index)
	session.call("request_fighter_hold", [own_fighters[1]])
	session.call("request_fighter_hold", [own_fighters[0], enemy_fighter])
	var graph: Dictionary = ECON.military_graph(initial)
	var local_point: Vector2 = graph["points"][home_index] + Vector2.RIGHT * ECON.sector_limit(graph, home_index, Vector2.RIGHT) * 0.25
	session.call("request_local_position", [own_fighters[1]], home_index, local_point, true)
	session.call("request_unit_orders", [{"ids": [own_fighters[1]], "order": {"kind": "position", "target": home_index, "point": local_point, "move_only": true, "heading": Vector2.UP}}], false)
	session.call("request_local_position", [own_fighters[1], enemy_fighter], home_index, local_point, true)
	session.call("request_local_position", [own_fighters[1]], home_index, graph["points"][(home_index + 1) % expected_players])
	session.call("request_unit_hold", [own_fighters[1], enemy_fighter], true)
	hold_release_id = own_miners[1]
	session.call("request_unit_hold", [hold_release_id], false)
	session.call("request_thresholds", home_index, "Metals", 15.0, 65.0)
	# Invalid and unauthorized threshold requests must not win.
	session.call("request_thresholds", home_index, "Metals", 99.0, 101.0)
	session.call("request_thresholds", (home_index + 1) % expected_players, "Metals", 77.0, 88.0)
	session.call("request_operation", home_index, "economy", "warehouse")
	session.call("request_operation", home_index, "economy", "Crystals")
	session.call("request_operation", home_index, "economy", "Crystals")
	session.call("request_operation", home_index, "economy", "invalid")
	session.call("request_operation", home_index, "economy", "Plastics")
	session.call("request_thresholds", home_index, "Tech", 15.0, 65.0)
	session.call("request_operation", (home_index + 1) % expected_players, "economy", "Metals")
	session.call("request_operation", home_index, "pds", "999")
	session.call("request_operation", (home_index + 1) % expected_players, "pds", "1")
	session.call("request_operation", home_index, "pds", "0") # already defended
	session.call("request_operation", home_index, "pds")
	session.call("request_operation", home_index, "pds")
	session.call("request_operation", home_index, "shipyard_build", "0:ship")
	session.call("request_operation", home_index, "shipyard_build", "0:fighter")
	session.call("request_operation", home_index, "shipyard_autobuild", "0:ship:1")
	session.call("request_operation", (home_index + 1) % expected_players, "shipyard_autobuild", "0:ship:0")
	session.call("request_shipyard_rally", home_index, 0, home_index, graph["points"][home_index])
	session.call("request_shipyard_rally", (home_index + 1) % expected_players, 0, home_index, graph["points"][home_index])
	session.call("request_continuous", home_index, "colony_ship", true)
	session.call("request_continuous", home_index, "miner", true)
	session.call("request_continuous", home_index, "economy_building:Organics", true)
	session.call("request_continuous", home_index, "production:Organics", true)
	session.call("request_operation", home_index, "production", "Organics")
	session.call("request_continuous", home_index, "yard_upgrade:0", true)
	session.call("request_mining_policy", 0, true, false, true)
	for index in range(session.get("economy")["map"]["fields"].size()):
		if bool(session.get("economy")["map"]["fields"][index].get("antimatter", false)):
			session.call("request_mining_policy", index, true, false, true)
	session.call("request_operation", home_index, "yard", "3") # invalid gap
	session.call("request_operation", home_index, "yard", "port:2")
	session.call("request_operation", home_index, "yard", "port:3")
	session.call("request_operation", home_index, "yard", "port:3") # duplicate
	session.call("request_operation", home_index, "reinforced_plating")
	session.call("request_operation", home_index, "laser_matrix")
	session.call("request_operation", home_index, "laser_matrix") # duplicate

func _check_economy_sync() -> void:
	if economy_verified or str(session.get("phase")) != "match":
		return
	var state: Dictionary = session.get("economy")
	var test_miner: Dictionary = {}
	var test_victim: Dictionary = {}
	for hull in state["ships"]:
		if int(hull["id"]) == 970000:
			test_miner = hull
		elif int(hull["id"]) == 970001:
			test_victim = hull
	if not test_miner.is_empty() and not test_victim.is_empty():
		miner_weapon_verified = miner_weapon_verified or (int(test_miner.get("combat_target", -1)) == 970001 and int(test_miner.get("pursuit_target", -1)) == -1 and float(test_victim["hp"]) < ECON.SHIP_HP and not bool(test_miner.get("mining_active", false)))
	if home_index < 0 or not _check_time_controls(state):
		if role == "host" and int(Time.get_ticks_msec() / 5000) > int(get_meta("speed_debug", -1)):
			set_meta("speed_debug", int(Time.get_ticks_msec() / 5000))
			print("DEBUG: time stage=", speed_stage, " speed=", state.get("time_speed"), " elapsed=", state.get("elapsed"), " home=", home_index)
		create_timer(0.25).timeout.connect(_check_economy_sync)
		return
	var self_id: int = session.multiplayer.get_unique_id()
	var outpost_index: int = int(state["map"]["planetless"][home_index])
	if not bool(get_meta("orbital_sent", false)) and int(state["planets"][outpost_index]["owner"]) == self_id:
		set_meta("orbital_sent", true)
		session.call("request_operation", outpost_index, "economy", "orbital_housing")
		session.call("request_operation", int(state["map"]["planetless"][(home_index + 1) % expected_players]), "economy", "orbital_housing")
	if not commands_sent and home_index >= 0 and ECON.discovered(state, self_id, "fields", 0):
		_send_commands()
		state = session.get("economy")
	if commands_sent:
		for craft in state["ships"]:
			if int(craft["id"]) != hold_release_id:
				continue
			if not hold_release_sent and bool(craft.get("holding", false)):
				hold_release_sent = true
				session.call("request_unit_hold", [hold_release_id], true)
			elif hold_release_sent and not bool(craft.get("holding", false)):
				hold_release_verified = true
		var own: Dictionary = state["planets"][home_index]
		if not cancel_sent:
			for item in own["queue"]:
				if item["kind"] == "fighter":
					cancel_id = int(item["id"])
					cancel_sent = true
					session.call("request_cancel", home_index, cancel_id)
					break
		var own_yard_jobs: Dictionary = {}
		for job in own["queue"]:
			if job["kind"] == "yard":
				own_yard_jobs[int(job["level"])] = job
		if cancelled_yard_id < 0 and own_yard_jobs.has(2) and own_yard_jobs.has(3):
			cancelled_yard_id = int(own_yard_jobs[2]["id"])
			promoted_yard_id = int(own_yard_jobs[3]["id"])
			session.call("request_cancel", home_index, cancelled_yard_id)
		elif cancelled_yard_id >= 0 and not yard_rebuilt and own_yard_jobs.has(2) and not own_yard_jobs.has(3):
			if int(own_yard_jobs[2]["id"]) != promoted_yard_id or own_yard_jobs[2]["cost"] != ECON._cost("yard", 2) or int(own_yard_jobs[2].get("station_slot", 0)) != 3:
				_fail("Shipyard stack did not retain and reprice later construction.")
				return
			yard_rebuilt = true
			session.call("request_operation", home_index, "yard", "port:2")
		var verified: int = 0
		for system in state["planets"]:
			if not bool(system["home"]):
				continue
			var owner: int = int(system["owner"])
			var thresholds: Dictionary = system["thresholds"]["Metals"]
			var flags: Dictionary = system["continuous"]
			var policy: Dictionary = ECON.mining_policy(state, owner, 0)
			var raw_policy_ok: bool = false
			var raw_fields: int = 0
			for field_index in range(state["map"]["fields"].size()):
				var field: Dictionary = state["map"]["fields"][field_index]
				if bool(field.get("antimatter", false)):
					raw_fields += 1
					var raw_policy: Dictionary = ECON.mining_policy(state, owner, field_index)
					if not raw_policy["enabled"]:
						raw_fields = -1
						break
			raw_policy_ok = raw_fields > 0
			var ship_progress: bool = false
			var fighter_pending: bool = false
			var upgrade_pending: bool = false
			var yard_pending: bool = false
			var repeat_colony: bool = false
			var repeat_miner: bool = false
			for job in system["queue"]:
				if job["kind"] == "ship" and float(job["progress"]) > 0.0:
					ship_progress = is_equal_approx(float(job.get("population_allocated", 0.0)), float(ECON.CREW_COSTS["ship"]) * float(job["progress"]) / float(job["work"]))
				elif job["kind"] == "fighter":
					fighter_pending = true
				elif job["kind"] == "economy_building" and job["target"] == "Organics":
					upgrade_pending = true
				elif job["kind"] == "yard_upgrade":
					yard_pending = true
				elif job["kind"] == "colony_ship" and bool(job.get("automatic", false)):
					repeat_colony = true
				elif job["kind"] == "miner" and bool(job.get("automatic", false)):
					repeat_miner = true
			for ship in state["ships"]:
				if not ship.has("hp") or float(ship["hp"]) <= 0.0 or float(ship["hp"]) > ECON.SHIP_HP:
					_fail("Replicated hull hit points are invalid.")
					return
				if int(ship["owner"]) == owner and ship.get("kind", "ship") == "ship":
					ship_progress = is_equal_approx(float(ship.get("crew", 0.0)), float(ECON.CREW_COSTS["ship"]))
			var field_node: int = (state["planets"] as Array).size()
			var buildings: Dictionary = system.get("buildings", {})
			var priced_slots: Dictionary = {}
			for job in system["queue"]:
				if job["kind"] == "yard":
					priced_slots[int(job["level"])] = job["cost"]
			var correct_upgrade_costs: bool = true
			for job in system["queue"]:
				for material in job["cost"]:
					if not is_equal_approx(float(job["allocated"][material]), float(job["cost"][material])):
						_fail("Replicated construction was not prepaid.")
						return
				if job["kind"] in ["production", "yard_upgrade"]:
					correct_upgrade_costs = correct_upgrade_costs and job["cost"] == ECON._cost(job["kind"], int(job["level"]))
			var pds_jobs: Array = system["queue"].filter(func(order: Dictionary) -> bool: return order["kind"] == "pds")
			var target_slot: int = 1
			var defense_ok: bool = pds_jobs.size() == 1 and pds_jobs[0]["target"] == str(target_slot) and pds_jobs[0]["cost"] == ECON._cost("pds", target_slot + 1)
			defense_ok = defense_ok or (pds_jobs.is_empty() and system.get("pds", {}).has(0) and system["pds"].has(target_slot) and system["pds"].size() == 2)
			# Commands complete at different times on different systems. Record
			# each replicated condition when observed, rather than requiring
			# every transient queue state to coexist in one snapshot.
			var ordered: int = 0
			var idle: int = 0
			var local_arrived: bool = false
			var local_moving: bool = false
			var patrol_verified: bool = false
			var attack_verified: bool = false
			var order_queue_verified: bool = false
			var rally_attack_move: bool = false
			var graph: Dictionary = ECON.military_graph(state)
			var owner_home: int = state["planets"].find(system)
			var local_point: Vector2 = graph["points"][owner_home] + Vector2.RIGHT * ECON.sector_limit(graph, owner_home, Vector2.RIGHT) * 0.25
			var patrol_point: Vector2 = graph["points"][field_node] + Vector2.UP * ECON.sector_limit(graph, field_node, Vector2.UP) * 0.3
			var rally_point: Vector2 = graph["points"][owner_home] + Vector2.UP * ECON.sector_limit(graph, owner_home, Vector2.UP) * 0.65
			for craft in state["ships"]:
				if int(craft["owner"]) == owner and craft["kind"] == "fighter":
					if int(craft["id"]) == 950000 + owner_home:
						var launch: Dictionary = craft.get("launch_rally", {})
						if bool(craft.get("move_only", false)):
							_fail("Rallying fighter replicated a move-only order.")
							return
						rally_attack_move = launch.get("point", Vector2.INF) == rally_point or (launch.is_empty() and not bool(craft.get("holding", false)) and int(craft["at"]) == owner_home)
					patrol_verified = patrol_verified or (int(craft.get("patrol_from", -1)) == owner_home and int(craft.get("patrol_to", -1)) == field_node and craft.get("patrol_end_point", Vector2.INF) == patrol_point and ECON.sector_contains(graph, owner_home, craft.get("patrol_start_point", Vector2.INF)))
					attack_verified = attack_verified or (int(craft["id"]) == 920000 + owner_home and int(craft.get("attack_order", -1)) == 920000 + (owner_home + 1) % expected_players)
					if int(craft["id"]) == 920000 + owner_home and int(craft.get("attack_order", -1)) >= 0:
						var queue: Array = craft.get("order_queue", [])
						order_queue_verified = queue.size() == 1 and queue[0].get("kind") == "sector_entry" and queue[0].get("target") == owner_home and queue[0].get("move_only", false)
					if craft.get("patrol_to", -1) == field_node and craft.get("direct_order", false):
						ordered += 1
					elif int(craft["at"]) == owner_home and (craft["route"] as Array).is_empty():
						if craft.get("holding", false) or ECON._is_idle_ship(craft):
							idle += 1
						if not craft.get("holding", false):
							local_moving = local_moving or ((craft.get("local_move_target", Vector2.INF) as Vector2).is_equal_approx(local_point) and craft.get("arrival_heading", Vector2.ZERO) == Vector2.UP)
							local_arrived = local_arrived or (not craft.has("local_move_target") and int(craft.get("operation_target", -1)) == owner_home and (craft["position"] as Vector2).is_equal_approx(local_point) and craft.get("heading", Vector2.ZERO) == Vector2.UP and ECON.arrival_wait_remaining(state, craft) > ECON.EPS and ECON.arrival_wait_remaining(state, craft) <= ECON.MOVE_ARRIVAL_WAIT_YEARS + ECON.EPS and not ECON._idle_formation_targets(state, graph).has(int(craft["id"])))
			var assigned_miners: int = 0
			var auto_salvage: bool = false
			var repair_toggled: bool = false
			var repaired: bool = false
			var deposited: bool = false
			for craft in state["ships"]:
				if int(craft["owner"]) == owner and craft["kind"] == "miner" and int(craft.get("assigned_field", -1)) >= 0:
					assigned_miners += 1
				if int(craft["id"]) == 930000 + owner_home:
					auto_salvage = bool(craft.get("holding", false)) and is_equal_approx(float(craft["cargo"]["Crystals"]), 2.0)
				if int(craft["id"]) == 980000 + owner_home:
					repair_toggled = not ECON.autocast_enabled(craft, "repair") and not ECON.autocast_enabled(craft, "mine") and ECON.autocast_enabled(craft, "salvage") and not ECON.autocast_enabled(craft, "wander")
					deposited = float(craft["cargo"].get(ECON.ANTIMATTER, 0.0)) <= ECON.EPS and float(system["stock"].get(ECON.ANTIMATTER, 0.0)) >= 15.0 - ECON.EPS
				if int(craft["id"]) == 990000 + owner_home:
					repaired = float(craft["hp"]) >= ECON.SHIP_HP - ECON.EPS
			var checks: Dictionary = {
				"station_plating": ECON._has_job(system, "reinforced_plating", "") or ECON.station_max_hp(system) == ECON.REINFORCED_STATION_HP,
				"station_matrix": ECON._has_job(system, "laser_matrix", "") or system["station"].get("weapons", []).size() == ECON.STATION_LASER_COUNT,
				"station_port_three": ECON.shipyard_at_port(system, 3) >= 0 or not ECON.shipyard_port_job(system, 3).is_empty(),
				"autobuild": system["yards"][0].get("autobuild", []).has("ship"),
				"rally": int(system["yards"][0].get("rally", {}).get("node", -1)) == owner_home and system["yards"][0].get("rally", {}).get("point", Vector2.INF) == graph["points"][owner_home],
				"rally_attack_move": rally_attack_move,
				"patrol": patrol_verified,
				"attack_target": attack_verified,
				"unit_order_queue": order_queue_verified,
				"salvage_delivery": not state.get("salvage", {}).has(910000 + owner_home) and float(system["stock"].get(ECON.ANTIMATTER, 0.0)) >= 12.0 - 0.001,
				"automatic_salvage": auto_salvage and not state.get("salvage", {}).has(940000 + owner_home),
				"miner_repair_toggle": repair_toggled,
				"miner_repaired": repaired,
				"miner_deposited": deposited,
				"local_move_order": local_moving,
				"local_position": local_arrived,
				"miner_assignment": assigned_miners == 1,
				"no_policies": not state.has("policies") && not flags.has("production:Organics"),
				"0": defense_ok,
				"1": correct_upgrade_costs,
				"2": priced_slots.get(2, {}) == ECON._cost("yard", 2),
				"3": priced_slots.get(3, {}) == ECON._cost("yard", 3),
				"4": int(system.get("warehouse_level", 0)) == 1,
				"5": not buildings.has("invalid") and not buildings.has("Plastics") and not system["thresholds"].has("Tech"),
				"6": buildings.get("Crystals", false),
				"7": ordered == 1,
				"8": idle >= 1,
				"9": is_equal_approx(float(thresholds["min"]), 15.0),
				"10": is_equal_approx(float(thresholds["max"]), 65.0),
				"11": flags.get("economy_building:Organics", false),
				"12": flags.get("yard_upgrade:0", false),
				"13": flags.get("colony_ship", false),
				"14": flags.get("miner", false),
				"15": repeat_colony,
				"16": repeat_miner,
				"17": upgrade_pending,
				"18": yard_pending,
				"19": not fighter_pending,
				"20": ship_progress,
				"21": ECON.shipyard_count(system) == 3,
				"22": policy["enabled"],
				"raw_policy": raw_policy_ok,
				"23": not policy["Metals"],
				"24": policy["Crystals"]
			}
			var observed: Dictionary = observed_commands.get(owner, {})
			for check in checks:
				if checks[check]:
					observed[check] = true
			observed_commands[owner] = observed
			if role == "host" and float(state["elapsed"]) >= next_diagnostic:
				var missing: Array = []
				for check in checks:
					if not observed.has(check):
						missing.append(check)
				print("DEBUG: owner=", owner, " missing checks=", missing, " population=", system["population"])
			if observed.size() == checks.size() and not fighter_pending and correct_upgrade_costs and ECON.shipyard_count(system) == 3:
				verified += 1
		if role == "host" and float(state["elapsed"]) >= next_diagnostic:
			next_diagnostic = float(state["elapsed"]) + 10.0
			print("DEBUG: economy elapsed=", state["elapsed"], " verified=", verified, "/", expected_players, " cancel=", cancel_sent, " stack=", yard_rebuilt, " ships=", state["ships"].size())
		var view: Node = current_scene
		var orbital_verified: bool = true
		for index in range(expected_players):
			var outpost: Dictionary = state["planets"][int(state["map"]["planetless"][index])]
			orbital_verified = orbital_verified and int(outpost.get("orbital_housing", 0)) == 1 and float(outpost["population"]) == ECON.ORBITAL_HOUSING_POPULATION and ECON.has_station(outpost)
		var target_index: int = int(state["map"]["planetless"][expected_players])
		var target: Dictionary = state["planets"][target_index]
		var station_destroyed: bool = false
		for event in state.get("ship_destructions", []):
			if event["kind"] == "station" and int(event["ship"]) == ECON.station_target_id(state, target_index):
				station_destroyed = true
		var station_verified: bool = station_destroyed and int(target["owner"]) == 0 and not ECON.has_station(target)
		if cancel_sent and yard_rebuilt and hold_release_verified and verified == expected_players and orbital_verified and station_verified and miner_weapon_verified and view != null and view.has_method("_update_trade_stock"):
			view.set("selected", home_index)
			view.call("_load_thresholds")
			view.call("_refresh")
			var sliders: Dictionary = view.get("trade_sliders")
			var home: Dictionary = state["planets"][home_index]
			if ECON.next_shipyard_slot(home) != 0:
				_fail("A fourth shipyard slot must not be available.")
				return
			for index in range((home["yards"] as Array).size()):
				if not ECON.shipyard_operational(home, index) and int(home["yards"][index]["job"]) >= 0:
					_fail("Understaffed shipyard is operating on replicated state.")
					return
			for resource in ECON.RESOURCES:
				var slider: Control = sliders[resource]
				var stock: float = float(home["stock"][resource])
				var thresholds: Dictionary = home["thresholds"][resource]
				if not is_equal_approx(float(slider.get("stock_percent")), clampf(stock / ECON.storage_capacity(home) * 100.0, 0.0, 100.0)) or not is_equal_approx(float(slider.get("lower")), float(thresholds["min"])) or not is_equal_approx(float(slider.get("upper")), float(thresholds["max"])):
					_fail("Replicated inventory or thresholds do not match the trade bars.")
					return
			var expected_sectors: Array[int] = []
			var palette_roster: Dictionary = session.get("players")
			for owner in ECON.territory_empires(state):
				expected_sectors.append(int(palette_roster.get(owner, {}).get("color", 0)))
			if view.get("territory_last") != expected_sectors:
				_fail("Territory overlay does not match replicated state.")
				return
			var poses: Dictionary = view.call("_ship_poses", state)
			for ship in state["ships"]:
				if not poses.has(int(ship["id"])):
					_fail("A replicated ship was not rendered.")
					return
				if not ship.get("position") is Vector2 or not ship.get("navigation_target") is Vector2 or not ship.get("heading") is Vector2:
					_fail("Ship is missing replicated physical navigation state.")
					return
				var actual: Vector2 = ship["position"]
				var sample: Dictionary = session.get("motion_samples").get(int(ship["id"]), {})
				if not sample.is_empty():
					if int(sample["revision"]) <= int(session.get("motion_base_revision")):
						_fail("Stale movement sample survived newer reliable state.")
						return
					actual = sample["position"]
				var visual: Dictionary = view.get("ship_visuals").get(int(ship["id"]), {})
				if visual.is_empty() or not (visual["to"] as Vector2).is_equal_approx(actual):
					_fail("Ship render target differs from authoritative physical position.")
					return
			if role == "client" and int(session.get("diagnostic_motion_received")) < 2:
				_fail("Guest did not receive independent movement updates.")
				return
			if role == "client" and int(session.get("diagnostic_compact_received")) < 1:
				_fail("Guest did not receive a map-template-independent inventory update.")
				return
			if role == "client" and int(session.get("diagnostic_planet_compact_received")) < 1:
				_fail("Guest did not reconstruct compact planet state.")
				return
			economy_verified = true
			# A normal game command is the completion acknowledgment. Return
			# only after each real peer has independently verified its replica.
			session.call("request_thresholds", home_index, "Crystals", 11.0, 22.0)
	if not economy_verified:
		create_timer(0.25).timeout.connect(_check_economy_sync)

func _return_after_all_verified() -> void:
	if str(session.get("phase")) != "match":
		return
	var state: Dictionary = session.get("economy")
	var confirmed: int = 0
	for system in state.get("planets", []):
		if not bool(system["home"]):
			continue
		var ack: Dictionary = system["thresholds"]["Crystals"]
		if is_equal_approx(float(ack["min"]), 11.0) and is_equal_approx(float(ack["max"]), 22.0):
			confirmed += 1
	if economy_verified and confirmed == expected_players:
		var pending: Dictionary = session.get("snapshot_pending")
		if pending.size() > expected_players - 1:
			_fail("More than one in-flight snapshot per guest.")
			return
		session.call("return_to_lobby")
	else:
		create_timer(0.25).timeout.connect(_return_after_all_verified)

# Verify the actual lobby scene, then explicitly disconnect rather than
# relying on process teardown to propagate an ENet disconnect.
func _finish_guest_return() -> void:
	if current_scene == null or not current_scene.has_method("_refresh_roster"):
		create_timer(0.1).timeout.connect(_finish_guest_return)
		return
	if role == "client":
		session.call("leave_session")
	_pass()

# Do not close the host while guests are still receiving the lobby transition.
# Every guest must independently pass its own checks before exiting.
func _wait_for_guest_completion() -> void:
	if (session.get("players") as Dictionary).size() == 1 and session.multiplayer.get_peers().is_empty():
		_pass()
	else:
		create_timer(0.25).timeout.connect(_wait_for_guest_completion)

func _pass() -> void:
	print("PASS: network %s %d players (%s)" % [role, expected_players, mode])
	quit(0)

func _fail(reason: String) -> void:
	if session != null:
		print("DEBUG: phase=", session.get("phase"), " roster=", session.get("players"), " loaded=", session.get("loaded"), " status=", session.get("status"), " started=", started, " saw_match=", saw_match)
	push_error("FAIL: %s (%s, %d players)" % [reason, role, expected_players])
	quit(1)

func _check_map_codec(state: Dictionary) -> bool:
	var template: Dictionary = (state["map"] as Dictionary).duplicate(true)
	var live: Dictionary = template.duplicate(true)
	var altered: bool = false
	for field in live["fields"]:
		var chunks: Array = field["chunks"]
		if chunks.size() >= 2:
			chunks.remove_at(0)
			chunks[0]["remaining"] = float(chunks[0]["remaining"]) * 0.5
			altered = true
			break
	if not altered:
		return false
	var wire_state: Dictionary = state.duplicate()
	wire_state["map"] = live
	var first: Dictionary = session.call("_encode_replica", wire_state, template, true)
	var next: Dictionary = session.call("_encode_replica", wire_state, template, false)
	if first.has("map") or next.has("map") or not first.has("_wire_map_template") or next.has("_wire_map_template"):
		return false
	var full_bytes: PackedByteArray = var_to_bytes(wire_state).compress(FileAccess.COMPRESSION_GZIP)
	var compact_bytes: PackedByteArray = var_to_bytes(next).compress(FileAccess.COMPRESSION_GZIP)
	if compact_bytes.size() >= full_bytes.size():
		return false
	var decoded_first: Dictionary = bytes_to_var(var_to_bytes(first))
	var decoded_next: Dictionary = bytes_to_var(compact_bytes.decompress_dynamic(16777216, FileAccess.COMPRESSION_GZIP))
	var restored: Dictionary = session.call("_restore_map_ore", decoded_first["_wire_map_template"], decoded_next["_wire_ore"])
	if restored != live or template != state["map"]:
		return false
	var same: Dictionary = session.call("_restore_map_ore", template, session.call("_encode_map_ore", template, template))
	if same != template:
		return false
	var invalid: Dictionary = session.call("_restore_map_ore", template, [])
	if not invalid.is_empty():
		return false
	var topology: Dictionary = live.duplicate(true)
	topology["seed"] = int(topology["seed"]) + 1
	wire_state["map"] = topology
	var fallback: Dictionary = session.call("_encode_replica", wire_state, template, false)
	return fallback.get("map") == topology and not fallback.has("_wire_ore")

func _check_planet_motion_codec(state: Dictionary) -> bool:
	var template: Array = session.call("_planet_template", state["planets"])
	var live: Array = (state["planets"] as Array).duplicate(true)
	live[0]["stock"]["Metals"] = float(live[0]["stock"]["Metals"]) + 123.456
	live[0]["population"] = float(live[0]["population"]) + 5.0
	var wire_state: Dictionary = state.duplicate()
	wire_state["planets"] = live
	wire_state["ai_waves"] = {1: {"members": [1, 2]}}
	var wire: Dictionary = session.call("_encode_replica", wire_state, state["map"], false, template)
	if not wire.get("_wire_planets_compact", false) or wire.has("_wire_planet_template") or wire.has("ai_waves") or wire.has("next_ai") or wire.has("next_operation_id"):
		return false
	var decoded: Dictionary = bytes_to_var(var_to_bytes(wire))
	var restored: Array = session.call("_restore_planets", decoded["planets"], template)
	if restored != live or wire_state["ai_waves"].is_empty() or wire["operations"] != state["operations"]:
		return false
	var first: Dictionary = session.call("_encode_replica", wire_state, state["map"], true, template)
	if first.get("_wire_planet_template") != template:
		return false
	var full_map_wire: Dictionary = session.call("_encode_replica", wire_state, state["map"], false)
	if var_to_bytes(wire).compress(FileAccess.COMPRESSION_GZIP).size() >= var_to_bytes(full_map_wire).compress(FileAccess.COMPRESSION_GZIP).size():
		return false
	live[0]["size_factor"] = float(live[0]["size_factor"]) + 0.5
	var fallback: Dictionary = session.call("_encode_replica", wire_state, state["map"], false, template)
	if fallback.has("_wire_planets_compact") or fallback["planets"] != live:
		return false
	var packet := PackedByteArray()
	packet.resize(20)
	var position := Vector2(54321.25, -123.125)
	packet.encode_s64(0, 123456789012)
	packet.encode_float(8, position.x)
	packet.encode_float(12, position.y)
	if packet.decode_s64(0) != 123456789012 or Vector2(packet.decode_float(8), packet.decode_float(12)) != position:
		return false
	for i in range(360):
		var heading: Vector2 = Vector2.from_angle(deg_to_rad(float(i)))
		packet.encode_half(16, heading.x)
		packet.encode_half(18, heading.y)
		var restored_heading := Vector2(packet.decode_half(16), packet.decode_half(18))
		if heading.distance_to(restored_heading) > 0.001:
			return false
	return true
