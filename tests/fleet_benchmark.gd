extends SceneTree
const MAP = preload("res://scripts/planet_map.gd")
const ECON = preload("res://scripts/economy_rules.gd")

func _stats(samples: Array) -> Dictionary:
	var sorted: Array = samples.duplicate()
	sorted.sort()
	return {"p50_ms": sorted[ceili(sorted.size() * 0.50) - 1], "p95_ms": sorted[ceili(sorted.size() * 0.95) - 1], "p99_ms": sorted[ceili(sorted.size() * 0.99) - 1], "max_ms": sorted.back()}

func _initialize() -> void:
	var counts: Array = [500, 1000, 2500, 5000, 10000]
	var scenarios: Array = ["dispersed", "battle", "swarm", "logistics"]
	var ticks: int = 100
	var seed_value: int = 827
	var speed: int = 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ships="):
			counts = [int(arg.get_slice("=", 1))]
		elif arg.begins_with("--scenario="):
			scenarios = [arg.get_slice("=", 1)]
		elif arg.begins_with("--ticks="):
			ticks = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.get_slice("=", 1))
		elif arg.begins_with("--speed="):
			speed = int(arg.get_slice("=", 1))
	if ticks < 1 or speed not in [1, 5] or int(counts[0]) < 1:
		push_error("Invalid benchmark options")
		quit(2)
		return
	for scenario in scenarios:
		if scenario not in ["dispersed", "battle", "swarm", "logistics"]:
			push_error("Unknown scenario")
			quit(2)
			return
		for count in counts:
			_run_case(int(count), str(scenario), ticks, seed_value, speed)
	quit()

func _run_case(count: int, scenario: String, ticks: int, seed_value: int, speed: int) -> void:
	var roster: Dictionary = {}
	var players: Array[int] = []
	for owner in range(1, 9):
		players.append(owner)
		roster[owner] = {"team": 1 if scenario == "swarm" else owner, "ai": false}
	var state: Dictionary = ECON.create(MAP.generate(seed_value, 8, "Radial"), roster, players, false)
	state["fog_of_war"] = false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var points: Array = state["map"]["points"]
	for i in range(count):
		var owner: int = i % 8 + 1
		var node: int = owner - 1 if scenario == "logistics" else i % points.size()
		if scenario in ["battle", "swarm"]:
			node = 0
		var kind: String = ["miner", "ship", "fighter", "colony_ship"][i % 4] if scenario == "logistics" else "fighter"
		var radius: float = 300.0 if scenario in ["battle", "swarm"] else 800.0
		var position: Vector2 = points[node] + Vector2.from_angle(rng.randf_range(0.0, TAU)) * sqrt(rng.randf()) * radius
		state["ships"].append({"id": i + 1, "kind": kind, "owner": owner, "origin": owner - 1, "at": node, "position": position, "heading": Vector2.UP, "navigation_target": position, "route": [], "leg": 0.0, "source": -1, "dest": -1, "hp": ECON.ship_max_hp(kind), "crew": 0.0, "cargo": ECON.empty_stock(), "field": -1, "mining_mode": "idle", "field_leg": 0.0})
	state["next_id"] = count + 1
	var samples: Array = []
	var phase_samples: Dictionary = {}
	var misses: int = 0
	var peak: int = count
	var minimum: int = count
	var memory_start: int = OS.get_static_memory_usage()
	for tick in range(ticks):
		var profile: Dictionary = {"Economy": 0}
		var start: int = Time.get_ticks_usec()
		for substep in range(speed):
			ECON.step(state, 0.1, profile)
		var ms: float = float(Time.get_ticks_usec() - start) / 1000.0
		samples.append(ms)
		misses += int(ms > 100.0)
		for key in profile:
			if not phase_samples.has(key):
				phase_samples[key] = []
			phase_samples[key].append(float(profile[key]) / 1000.0)
		peak = maxi(peak, state["ships"].size())
		minimum = mini(minimum, state["ships"].size())
	var phases: Dictionary = {}
	for key in phase_samples:
		phases[key] = _stats(phase_samples[key])
	print("FLEET_BENCH " + JSON.stringify({"version": ProjectSettings.get_setting("application/config/version"), "engine": Engine.get_version_info()["string"], "cpu": OS.get_processor_name(), "cpu_threads": OS.get_processor_count(), "os": OS.get_name(), "mode": "headless_simulation", "seed": seed_value, "scenario": scenario, "players": 8, "speed": speed, "ticks": ticks, "initial_ships": count, "minimum_ships": minimum, "peak_ships": peak, "final_ships": state["ships"].size(), "deadline_misses": misses, "tick_ms": _stats(samples), "phases_ms": phases, "static_memory_start_bytes": memory_start, "static_memory_end_bytes": OS.get_static_memory_usage()}))
