extends SceneTree
## Base recipe tests run independently of multiplayer scenes.
const QUERIES = preload("res://scripts/construction_queries.gd")
const ECON = preload("res://scripts/economy_rules.gd")

func _wall_segment(id: int, a: Vector2, b: Vector2) -> Dictionary:
	return {"id": id, "owner": 2, "kind": "wall_segment", "wall_a": a, "wall_b": b, "build_progress": 1.0, "hp": 100.0}

func _wall_fixture(segments: Array) -> Dictionary:
	var nodes: Dictionary = {}
	var entities: Array = []
	for wall in segments:
		for side in ["a", "b"]:
			var point: Vector2 = wall["wall_" + side]
			if not nodes.has(point):
				nodes[point] = 100 + nodes.size()
				entities.append({"id": nodes[point], "owner": 2, "kind": "wall_node", "build_progress": 1.0, "hp": 100.0})
			wall["wall_" + side + "_id"] = nodes[point]
		entities.append(wall)
	return {"ships": entities, "teams": {1: 1, 2: 2}, "diplomacy": {}, "elapsed": 0.0, "map": {"size": Vector2(2000, 2000)}}

func _test_wall_navigation() -> void:
	var start := Vector2(400, 800)
	var goal := Vector2(1200, 800)
	var state: Dictionary = _wall_fixture([_wall_segment(1, Vector2(800, 400), Vector2(800, 800)), _wall_segment(2, Vector2(800, 800), Vector2(800, 1200))])
	var grid: Dictionary = ECON.wall_grid(state)
	assert(not ECON.wall_first_hit(state, grid, 1, start, goal, true).is_empty())
	var route: Array = ECON.wall_navigation_route(state, grid, 1, start, goal)
	assert(route.size() >= 2 and route.back() == goal)
	var previous: Vector2 = start
	for waypoint in route:
		assert(ECON.wall_first_hit(state, grid, 1, previous, waypoint, true).is_empty())
		previous = waypoint
	assert(ECON.diplomacy_set_permission(state, 2, 1, "open_borders", true))
	assert(ECON.wall_navigation_route(state, grid, 1, start, goal) == [goal])
	assert(not ECON.wall_first_hit(state, grid, 1, start, goal, false).is_empty())
	var ring: Dictionary = _wall_fixture([_wall_segment(1, Vector2(800, 600), Vector2(1200, 600)), _wall_segment(2, Vector2(1200, 600), Vector2(1200, 1000)), _wall_segment(3, Vector2(1200, 1000), Vector2(800, 1000)), _wall_segment(4, Vector2(800, 1000), Vector2(800, 600))])
	assert(ECON.wall_navigation_route(ring, ECON.wall_grid(ring), 1, start, Vector2(1000, 800)).is_empty())

func _initialize() -> void:
	_test_wall_navigation()
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
