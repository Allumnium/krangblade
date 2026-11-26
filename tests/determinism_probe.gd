extends SceneTree
# Behavior-preservation check for refactors: run a seeded simulation and print
# per-key state hashes at fixed checkpoints. Compare output before and after.
# Usage: --scenario=ai_match|battle --ticks=N --seed=N --every=N
const MAP = preload("res://scripts/planet_map.gd")
const ECON = preload("res://scripts/economy_rules.gd")

func _initialize() -> void:
	var scenario: String = "ai_match"
	var ticks: int = 3000
	var seed_value: int = 827
	var every: int = 500
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario = arg.get_slice("=", 1)
		elif arg.begins_with("--ticks="):
			ticks = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.get_slice("=", 1))
		elif arg.begins_with("--every="):
			every = maxi(1, int(arg.get_slice("=", 1)))
	var state: Dictionary = _create(scenario, seed_value)
	if state.is_empty():
		push_error("Unknown scenario")
		quit(2)
		return
	var retained: bool = OS.get_cmdline_user_args().has("--retained-hull-scope")
	if retained:
		ECON.begin_authority_hull_scope(state)
	for tick in range(1, ticks + 1):
		ECON.step(state, 0.1)
		ECON.update_match_outcome(state)
		if tick % every == 0 or tick == ticks:
			_report(tick, state)
	if retained:
		ECON.end_authority_hull_scope()
	quit()

func _create(scenario: String, seed_value: int) -> Dictionary:
	var roster: Dictionary = {}
	var players: Array[int] = []
	var count: int = 4 if scenario == "ai_match" else 2
	for owner in range(1, count + 1):
		players.append(owner)
		roster[owner] = {"team": owner, "ai": true, "color": owner}
	if scenario == "ai_match":
		var state: Dictionary = ECON.create(MAP.generate(seed_value, count, "Radial"), roster, players)
		ECON.initialize_diplomacy(state)
		return state
	if scenario != "battle":
		return {}
	var battle: Dictionary = ECON.create(MAP.generate(seed_value, count, "Radial"), roster, players)
	# Legacy team relations (no diplomacy) put the two empires at war.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var center: Vector2 = battle["map"]["points"][0]
	var next_id: int = int(battle["next_id"])
	for i in range(400):
		var owner: int = i % count + 1
		var kind: String = ["fighter", "cruiser", "destroyer", "scout", "miner"][i % 5]
		var position: Vector2 = center + Vector2.from_angle(rng.randf_range(0.0, TAU)) * sqrt(rng.randf()) * 500.0
		battle["ships"].append({"id": next_id, "kind": kind, "owner": owner, "origin": owner - 1, "at": 0, "position": position, "heading": Vector2.UP, "navigation_target": position, "route": [], "leg": 0.0, "source": -1, "dest": -1, "hp": ECON.ship_max_hp(kind), "crew": 0.0, "cargo": ECON.empty_stock(), "field": -1, "mining_mode": "idle", "field_leg": 0.0})
		next_id += 1
	battle["next_id"] = next_id
	return battle

func _report(tick: int, state: Dictionary) -> void:
	var keys: Array = state.keys()
	keys.sort()
	var hashes: Dictionary = {}
	for key in keys:
		hashes[str(key)] = var_to_str(state[key]).hash()
	var hull_hp: float = 0.0
	for ship in state["ships"]:
		hull_hp += float(ship.get("hp", 0.0))
	print("DETERMINISM " + JSON.stringify({"tick": tick, "ships": state["ships"].size(), "hull_hp": snappedf(hull_hp, 0.01), "all": var_to_str(state).hash(), "keys": hashes}))
