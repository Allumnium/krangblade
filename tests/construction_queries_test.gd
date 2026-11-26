extends SceneTree
## Base recipe tests run independently of multiplayer scenes.
const QUERIES = preload("res://scripts/construction_queries.gd")
const ECON = preload("res://scripts/economy_rules.gd")

func _initialize() -> void:
	for kind in ["ship", "colony_ship", "fighter", "miner", "science_ship", "scout", "cruiser", "destroyer", "yard", "pds", "dyson_sphere", "reinforced_plating", "laser_matrix", "yard_upgrade", "production", "warehouse", "habitation", "orbital_housing"]:
		for level in range(1, 4):
			var expected: Dictionary = ECON._cost(kind, level)
			var actual: Dictionary = QUERIES.base_cost(kind, level, ECON.CRYSTAL_COST_MULTIPLIER, ECON.UPGRADE_COST_FACTOR, ECON.WAREHOUSE_COSTS, ECON.ORBITAL_HOUSING_COST)
			assert(actual == expected)
			assert(QUERIES.base_work(kind, level) == ECON._work(kind, level))
	assert(ECON.static_recipe("defense_cannon", 3)["Metals"] > ECON.static_recipe("defense_cannon", 2)["Metals"])
	assert(ECON.cannon_damage({"structure_level": 3}) > ECON.cannon_damage({"structure_level": 2}))
	assert(ECON.hull_max_hp({"kind": "defense_cannon", "structure_level": 2, "build_progress": 0.0}) == ECON.CANNON_HP[1])
	var wall_points: PackedVector2Array = ECON.wall_chain_points(Vector2.ZERO, Vector2(1000, 0))
	assert(wall_points.size() == 4 and wall_points[0] == Vector2.ZERO and wall_points[-1] == Vector2(1000, 0))
	for index in range(1, wall_points.size()):
		assert(wall_points[index].distance_to(wall_points[index - 1]) <= ECON.WALL_MAX_LENGTH)
	assert(ECON.wall_chain_points(Vector2.ZERO, Vector2.ZERO).size() == 1)
	assert(ECON.wall_chain_points(Vector2.ZERO, Vector2(100000, 0)).is_empty())
	assert(ECON.ship_size("construction_ship") == 1)
	assert(ECON.cargo_capacity("construction_ship") == 180.0)
	assert(ECON.depot_capacity("Metals") == 2000.0)
	assert(ECON.depot_capacity("Organics") == 4000.0)
	assert(ECON.depot_capacity("Crystals") == 500.0)
	assert(ECON.depot_capacity(ECON.ANTIMATTER) == 2.0)
	assert(ECON.ship_presence_weight({"kind": "resource_depot"}) == 0)
	assert(ECON.hull_max_hp({"kind": "resource_depot", "build_progress": 0.0}) == ECON.DEPOT_HP * 0.1)
	assert(QUERIES.base_work("fighter", 1) == 36.0)
	assert(QUERIES.base_cost("fighter", 1, ECON.CRYSTAL_COST_MULTIPLIER, ECON.UPGRADE_COST_FACTOR, ECON.WAREHOUSE_COSTS, ECON.ORBITAL_HOUSING_COST) == {"Metals": 270.0, "Organics": 10.0})
	var plan: Dictionary = {"queue": [{"kind": "fighter", "target": ""}, {"kind": "production", "target": "Metals"}]}
	assert(QUERIES.has_queued_job(plan, "fighter", ""))
	assert(QUERIES.has_queued_job(plan, "production", "Metals"))
	assert(not QUERIES.has_queued_job(plan, "production", "Crystals"))
	var housing: Dictionary = QUERIES.base_cost("orbital_housing", 1, ECON.CRYSTAL_COST_MULTIPLIER, ECON.UPGRADE_COST_FACTOR, ECON.WAREHOUSE_COSTS, ECON.ORBITAL_HOUSING_COST)
	housing["Metals"] = 0.0
	assert(float(ECON.ORBITAL_HOUSING_COST["Metals"]) > 0.0)
	print("PASS: construction recipes, work, queue lookup and source cost isolation")
	quit()
