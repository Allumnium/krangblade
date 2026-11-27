extends SceneTree
const E = preload("res://scripts/economy_rules.gd")
const M = preload("res://scripts/planet_map.gd")

func _initialize() -> void:
	var state: Dictionary = E.create(M.generate(827, 1, "Grid"), {1: {"team": 1}}, [1], false)
	var p: Dictionary = state["planets"][0]
	assert(p["yards"].is_empty() and p["pds"].is_empty() and p["buildings"].is_empty())
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
	assert(founded["population"] == 250.0 and founded["yards"].is_empty() and founded["stock"]["Organics"] == 20.0)
	for resource in E.RESOURCES:
		assert(E.rate(founded, resource) == 0.0)
	print("PASS: bare home, stock-fed population, completed production, blockade and bare colony")
	quit(0)
