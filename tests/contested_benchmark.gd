extends SceneTree
const MAP = preload("res://scripts/planet_map.gd")
const ECON = preload("res://scripts/economy_rules.gd")

# Run separately from the fast economic fixtures. Simulation years at 1x
# correspond to real seconds; the optional fine mode uses actual sim ticks.
func _initialize() -> void:
	var fine: bool = "--fine" in OS.get_cmdline_user_args()
	var dt: float = 0.1 if fine else 1.0
	var cases: Array = [[827, 2, "Radial"], [123, 2, "Grid"], [2468, 4, "Hex Grid"]]
	if "--duel-only" in OS.get_cmdline_user_args():
		cases = [cases[0]]
	for case in cases:
		var roster: Dictionary = {}
		var players: Array[int] = []
		for player in range(1, int(case[1]) + 1):
			roster[player] = {"team": player, "ai": true}
			players.append(player)
		var state: Dictionary = ECON.create(MAP.generate(int(case[0]), int(case[1]), str(case[2])), roster, players)
		var first_loss: float = -1.0
		var first_expansion: float = -1.0
		var peak: int = 0
		var duration: float = 900.0
		for tick in range(int(duration / dt)):
			ECON.step(state, dt)
			ECON.update_match_outcome(state)
			var worlds: int = 0
			for p in state["planets"]:
				worlds += int(int(p["owner"]) > 0)
			if first_expansion < 0 and worlds > players.size():
				first_expansion = float(state["elapsed"])
			if first_loss < 0 and int(state.get("next_destruction_id", 1)) > 1:
				first_loss = float(state["elapsed"])
			peak = maxi(peak, state["ships"].size())
			if not state.get("match_result", {}).is_empty():
				break
		var summaries: Array = []
		for player in players:
			var worlds: int = 0
			var yards: int = 0
			var population: float = 0.0
			var total_stock: float = 0.0
			var hulls: Dictionary = {"fighter": 0, "miner": 0, "ship": 0, "colony_ship": 0}
			for p in state["planets"]:
				if int(p["owner"]) != player:
					continue
				worlds += 1
				yards += p["yards"].size()
				population += float(p["population"])
				assert(float(p["population"]) >= 0.0)
				for resource in p["stock"]:
					assert(float(p["stock"][resource]) >= -ECON.EPS)
					total_stock += float(p["stock"][resource])
			for craft in state["ships"]:
				if int(craft["owner"]) != player:
					continue
				hulls[craft["kind"]] += 1
				assert((craft["position"] as Vector2).is_finite())
				assert(ECON._cargo_total(craft) <= ECON.cargo_capacity(str(craft["kind"])) + ECON.EPS)
			summaries.append({"player": player, "worlds": worlds, "shipyards": yards, "population": int(population), "stock_t": int(total_stock), "hulls": hulls})
		print("CONTESTED seed=%d %s players=%d dt=%.1f year=%.1f expansion=%.1f first_loss=%.1f losses=%d peak_hulls=%d winner=%s" % [case[0], case[2], case[1], dt, state["elapsed"], first_expansion, first_loss, int(state.get("next_destruction_id", 1)) - 1, peak, state.get("match_result", {})])
		print(summaries)
		assert(first_expansion >= 0.0)
		assert(first_loss >= 0.0)
	print("PASS: contested economy and military benchmark")
	quit()
