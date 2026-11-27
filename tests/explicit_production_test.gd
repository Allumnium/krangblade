extends SceneTree
const E = preload("res://scripts/economy_rules.gd")
const M = preload("res://scripts/planet_map.gd")

func _initialize() -> void:
	var opening: Dictionary = E.create(M.generate(827, 2, "Grid"), {1: {"team": 1}, 2: {"team": 2, "ai": true}}, [1, 2])
	assert(opening["ships"].size() == 14)
	for owner in [1, 2]:
		var science: Array = opening["ships"].filter(func(craft: Dictionary) -> bool: return int(craft["owner"]) == owner and craft["kind"] == "science_ship")
		assert(science.size() == 1)
		assert(float(science[0]["crew"]) == float(E.CREW_COSTS["science_ship"]))
		assert(int(E.objective_progress(opening, owner).get("science_built", 0)) == 0)
		assert(opening["planets"][owner - 1]["stock"] == E.STARTING_STOCK or opening["planets"][owner - 1]["stock"]["Metals"] == E.STARTING_STOCK["Metals"])
		assert(E.credit_balance(opening, owner) == E.STARTING_GC)
		assert(opening["planets"][owner - 1]["yards"].size() == 1 and opening["planets"][owner - 1]["yards"][0]["level"] == 1)
		var upkeep: float = float(E.empire_totals(opening, owner)["upkeep"])
		assert(is_equal_approx(upkeep, 11.5) and E.base_galactic_income(opening, owner) > upkeep)
	opening["ai_players"].clear()
	E._accrue_base_galactic_income(opening, 1.0)
	E._pay_fleet_upkeep(opening, 1.0)
	assert(is_equal_approx(E.credit_balance(opening, 1), E.STARTING_GC + 0.5))
	var state: Dictionary = E.create(M.generate(827, 1, "Grid"), {1: {"team": 1}}, [1], false)
	var p: Dictionary = state["planets"][0]
	assert(p["yards"].size() == 1 and p["yards"][0]["level"] == 1 and p["pds"].is_empty() and p["buildings"].is_empty())
	assert(p["stock"]["Crystals"] == 0.0)
	for resource in E.RESOURCES:
		assert(E.rate(p, resource) == 0.0)
	for year in range(10):
		E.step(state, 1.0)
	assert(is_equal_approx(float(p["population"]), 150.0))
	assert(p["stock"]["Metals"] == 165.0 and p["stock"]["Crystals"] == 0.0 and p["stock"]["Organics"] < 30.0)
	assert(E.enqueue(state, 1, 0, "economy", "Organics"))
	for year in range(30):
		E.step(state, 1.0)
	assert(E.rate(p, "Organics") == 0.0)
	for year in range(4):
		E.step(state, 1.0)
	assert(E.rate(p, "Organics") > 0.0 and E.rate(p, "Metals") == 0.0 and E.rate(p, "Crystals") == 0.0)
	assert(E.enqueue(state, 1, 0, "economy", "Metals"))
	assert(E.enqueue(state, 1, 0, "economy", "Crystals"))
	for year in range(65):
		E.step(state, 1.0)
	assert(E.rate(p, "Metals") > 0.0 and E.rate(p, "Crystals") > 0.0)
	p["planet_blockaded"] = true
	for resource in E.RESOURCES:
		assert(E.rate(p, resource) == 0.0)
	var target: int = 1
	while not E.has_planets(state["planets"][target]):
		target += 1
	var colony: Dictionary = {"id": 999, "owner": 1, "crew": 250.0, "unit_order": {}, "cargo": {"Organics": 20.0}}
	assert(E._convert_colony(state, colony, target))
	var founded: Dictionary = state["planets"][target]
	assert(founded["population"] == 250.0 and founded["yards"].size() == 1 and founded["yards"][0]["level"] == 1 and founded["stock"]["Organics"] == 20.0)
	for resource in E.RESOURCES:
		assert(E.rate(founded, resource) == 0.0)
	print("PASS: free Small shipyards, base income, stock-fed population, explicit production and colony conservation")
	quit(0)
