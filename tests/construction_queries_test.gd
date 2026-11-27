extends SceneTree
## Base recipe tests run independently of multiplayer scenes.
const QUERIES = preload("res://scripts/construction_queries.gd")
const ECON = preload("res://scripts/economy_rules.gd")
const MAP = preload("res://scripts/planet_map.gd")

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

	var staggered: Dictionary = _wall_fixture([_wall_segment(1, Vector2(800, 0), Vector2(800, 400)), _wall_segment(2, Vector2(800, 400), Vector2(800, 800)), _wall_segment(3, Vector2(800, 800), Vector2(800, 1200)), _wall_segment(4, Vector2(800, 1200), Vector2(800, 1400)), _wall_segment(5, Vector2(1200, 600), Vector2(1200, 1000)), _wall_segment(6, Vector2(1200, 1000), Vector2(1200, 1400)), _wall_segment(7, Vector2(1200, 1400), Vector2(1200, 1800)), _wall_segment(8, Vector2(1200, 1800), Vector2(1200, 2000))])
	var staggered_grid: Dictionary = ECON.wall_grid(staggered)
	var staggered_goal := Vector2(1600, 800)
	var staggered_route: Array = ECON.wall_navigation_route(staggered, staggered_grid, 1, start, staggered_goal)
	assert(staggered_route.size() >= 3 and staggered_route.back() == staggered_goal)
	previous = start
	for waypoint in staggered_route:
		assert(ECON.wall_first_hit(staggered, staggered_grid, 1, previous, waypoint, true).is_empty())
		previous = waypoint

func _test_multi_source_materials() -> void:
	var state: Dictionary = ECON.create(MAP.generate(712, 2, "Grid"), {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	state["planets"][1]["owner"] = 1
	state["planets"][0]["stock"] = {"Metals": 350.0, "Crystals": 0.0, "Organics": 0.0}
	state["planets"][1]["stock"] = {"Metals": 250.0, "Crystals": 40.0, "Organics": 0.0}
	var point: Vector2 = ECON.station_position(state, 0, 0.0) + Vector2(100, 100)
	var stocks: Dictionary = ECON._construction_stocks(state, 1)
	var before: Dictionary = stocks.duplicate(true)
	assert(ECON._plan_site_materials(state, point, {"Metals": 601.0}, stocks).is_empty())
	assert(stocks == before)
	var recipe: Dictionary = ECON.static_recipe("resource_depot")
	var plan: Dictionary = ECON._plan_site_materials(state, point, recipe, stocks)
	assert(plan.size() == 2 and plan[0]["cargo"]["Metals"] == 350.0 and plan[1]["cargo"]["Crystals"] == 40.0)
	assert(state["planets"][0]["stock"]["Metals"] == 350.0)
	var site: Dictionary = {"id": 100, "owner": 1, "position": point, "build_reservations": {}, "build_recipe": recipe}
	ECON._reserve_site_materials(state, site, plan)
	assert(ECON._site_reserved_total(site) == 640.0)
	assert(state["planets"][0]["stock"]["Metals"] == 0.0 and state["planets"][1]["stock"]["Crystals"] == 0.0)
	ECON._refund_site(state, site, false)
	assert(ECON._site_reserved_total(site) == 0.0)
	assert(state["planets"][0]["stock"]["Metals"] == 350.0 and state["planets"][1]["stock"]["Metals"] == 250.0 and state["planets"][1]["stock"]["Crystals"] == 40.0)

func _test_supply_recovery() -> void:
	var state: Dictionary = ECON.create(MAP.generate(713, 2, "Grid"), {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	state["planets"][0]["stock"]["Metals"] = 200.0
	var point: Vector2 = ECON.station_position(state, 0, 0.0)
	var site: Dictionary = {"id": 100, "owner": 1, "position": point, "build_recipe": {"Metals": 180.0}, "build_delivered": {"Metals": 50.0}, "build_reservations": {}}
	var builder: Dictionary = {"id": 101, "owner": 1, "kind": "construction_ship", "position": point, "construction_target": 100, "cargo": {"Metals": 30.0}}
	var freighter: Dictionary = {"id": 102, "owner": 1, "kind": "ship", "position": point, "construction_supply_site": 100, "construction_supply_builder": 101, "cargo": {"Metals": 100.0}}
	state["ships"] = [builder, freighter]
	assert(ECON._site_shortfall(state, site).is_empty())
	ECON._recover_site_materials(state, site)
	assert(state["planets"][0]["stock"]["Metals"] == 200.0)
	state["ships"].erase(freighter)
	assert(ECON._site_shortfall(state, site)["Metals"] == 100.0)
	state["elapsed"] = ECON.CONSTRUCTION_RECOVERY_YEARS
	ECON._recover_site_materials(state, site)
	assert(ECON._site_reserved_total(site) == 100.0 and state["planets"][0]["stock"]["Metals"] == 100.0)
	state["elapsed"] += ECON.CONSTRUCTION_RECOVERY_YEARS
	ECON._recover_site_materials(state, site)
	assert(ECON._site_reserved_total(site) == 100.0 and state["planets"][0]["stock"]["Metals"] == 100.0)
	builder["holding"] = true
	assert(ECON._site_shortfall(state, site)["Metals"] == 30.0)
	state["elapsed"] += ECON.CONSTRUCTION_RECOVERY_YEARS
	ECON._recover_site_materials(state, site)
	assert(ECON._site_reserved_total(site) == 130.0 and state["planets"][0]["stock"]["Metals"] == 70.0)
	# Returning cargo is not created by recovery. Cancel refunds only escrow.
	ECON._refund_site(state, site, false)
	assert(state["planets"][0]["stock"]["Metals"] == 200.0 and builder["cargo"]["Metals"] == 30.0)

func _test_depot_policy() -> void:
	var state: Dictionary = ECON.create(MAP.generate(714, 2, "Grid"), {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var depot: Dictionary = {"id": 100, "kind": "resource_depot", "owner": 1, "build_progress": 1.0, "position": Vector2(200, 200), "hp": 1200.0, "cargo": {"Metals": 500.0}}
	state["ships"].append(depot)
	assert(ECON.depot_receive_capacity(depot, "Metals") == 1500.0)
	assert(ECON.depot_dispatch_stock(depot, "Metals") == 500.0)
	assert(not ECON.set_depot_policy(state, 2, 100, "Metals", 10.0, 70.0, true, true))
	assert(not ECON.set_depot_policy(state, 1, 100, "Metals", 80.0, 70.0, true, true))
	assert(not ECON.set_depot_policy(state, 1, 100, ECON.ANTIMATTER, 0.0, 100.0, true, true))
	assert(ECON.set_depot_policy(state, 1, 100, "Metals", 10.0, 70.0, true, true))
	assert(ECON.depot_receive_capacity(depot, "Metals") == 900.0)
	assert(ECON.depot_dispatch_stock(depot, "Metals") == 300.0)
	assert(ECON.set_depot_policy(state, 1, 100, "Metals", 10.0, 70.0, false, false))
	assert(ECON.depot_receive_capacity(depot, "Metals") == 0.0 and ECON.depot_dispatch_stock(depot, "Metals") == 0.0)
	assert(ECON.depot_free(depot, "Metals") == 1500.0)

func _test_physical_construction() -> void:
	var state: Dictionary = ECON.create(MAP.generate(715, 2, "Grid"), {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	state["planets"][1]["owner"] = 1
	state["planets"][0]["stock"] = {"Metals": 350.0, "Crystals": 0.0, "Organics": 0.0}
	state["planets"][1]["stock"] = {"Metals": 250.0, "Crystals": 40.0, "Organics": 0.0}
	var dock: Vector2 = ECON.station_position(state, 0, 0.0)
	var point: Vector2 = dock + Vector2(250, 250)
	var graph: Dictionary = ECON.military_graph(state)
	var builder: Dictionary = {"id": 100, "kind": "construction_ship", "owner": 1, "origin": 0, "at": 0, "position": dock, "navigation_target": dock, "heading": Vector2.UP, "route": [], "leg": 0.0, "source": -1, "dest": -1, "crew": 0.0, "cargo": ECON.empty_stock(), "hp": ECON.ship_max_hp("construction_ship"), "wander_auto": false}
	state["ships"] = [builder]
	state["next_id"] = 101
	assert(ECON.issue_unit_order(state, 1, [100], {"kind": "build_depot", "point": point}, false))
	var site: Dictionary = state["ships"].back()
	assert(ECON._site_reserved_total(site) == 640.0 and site["build_progress"] == 0.0)
	var saw_partial: bool = false
	var visited_second: bool = false
	for tick in range(5000):
		ECON._rock_plan_tick += 1
		ECON._rock_plan_budget = ECON.ROCK_PLAN_LIMIT
		ECON._rock_route_queries.clear()
		var before: Vector2 = builder["position"]
		var delivered: Dictionary = site["build_delivered"].duplicate()
		ECON._work_construction(state, graph, builder, 0.5)
		assert(before.distance_to(builder["position"]) <= ECON.ship_speed("construction_ship") * 0.5 + 0.01)
		if delivered != site["build_delivered"]:
			assert((builder["position"] as Vector2).distance_to(point) <= ECON.TRACTOR_RANGE + 0.01)
		if (builder["position"] as Vector2).distance_to(ECON.station_position(state, 1, float(state["elapsed"]))) <= ECON.STATION_DOCK_RANGE + 0.01:
			visited_second = true
		if site["build_progress"] > ECON.EPS and not ECON.static_complete(site):
			saw_partial = true
		for resource in site["build_recipe"]:
			var total: float = float(site["build_delivered"].get(resource, 0.0)) + float(builder["cargo"].get(resource, 0.0))
			for record in site["build_reservations"].values():
				total += float(record["cargo"].get(resource, 0.0))
			assert(is_equal_approx(total, float(site["build_recipe"][resource])))
		if ECON.static_complete(site):
			break
		state["elapsed"] += 0.5
	assert(saw_partial and visited_second and ECON.static_complete(site))
	assert(is_equal_approx(float(site["hp"]), ECON.DEPOT_HP) and ECON._cargo_total(builder) <= ECON.EPS)
	print("PASS: physical multi-station construction, movement budget and per-resource conservation")

func _test_wall_movement_and_weapons() -> void:
	var start := Vector2(400, 800)
	var goal := Vector2(1200, 800)
	var state: Dictionary = _wall_fixture([_wall_segment(1, Vector2(800, 400), Vector2(800, 800)), _wall_segment(2, Vector2(800, 800), Vector2(800, 1200))])
	var grid: Dictionary = ECON.wall_grid(state)
	ECON._refresh_movement_fields([])
	ECON._movement_wall_state = state
	ECON._movement_wall_grid = grid
	var ship: Dictionary = {"id": 200, "kind": "fighter", "owner": 1, "position": start, "heading": Vector2.RIGHT, "navigation_target": goal}
	for tick in range(200):
		ECON._wall_nav_budget = ECON.WALL_NAV_PLAN_LIMIT
		ECON._rock_plan_tick += 1
		var before: Vector2 = ship["position"]
		ECON._navigate(ship, goal, 20.0, false)
		assert(before.distance_to(ship["position"]) <= 20.01)
		assert(ECON.wall_first_hit(state, grid, 1, before, ship["position"], true).is_empty())
		if (ship["position"] as Vector2).is_equal_approx(goal):
			break
	ECON._movement_wall_grid = {}
	ECON._movement_wall_state = {}
	assert((ship["position"] as Vector2).is_equal_approx(goal))
	ECON._combat_wall_grid = grid
	var damage: Dictionary = {}
	var health: Dictionary = {1: 100.0, 2: 100.0, 201: 100.0}
	var slots: Dictionary = {}
	var packed_health := PackedFloat64Array()
	var impact: Vector2 = ECON._weapon_hit(state, start, goal, 201, ship, 10.0, damage, {}, health, slots, packed_health)
	assert(impact == Vector2(800, 800) and damage.is_empty())
	assert(ECON.diplomacy_declare_war(state, 1, 2))
	ECON._wall_laser_hit(state, start, goal, 201, ship, 10.0, damage, {}, health, slots, packed_health)
	assert(damage.get(1, 0.0) == 10.0 and not damage.has(201) and ship["wall_laser_endpoint"] == impact)
	ECON._combat_wall_grid = {}
	print("PASS: wall detour movement, neutral interception, hostile damage and laser impact endpoint")

func _freight_hull(id: int, kind: String, position: Vector2) -> Dictionary:
	return {"id": id, "kind": kind, "owner": 1, "origin": 0, "at": 0, "position": position, "navigation_target": position, "heading": Vector2.UP, "route": [], "leg": 0.0, "source": -1, "dest": -1, "crew": 0.0, "cargo": ECON.empty_stock(), "hp": ECON.ship_max_hp(kind), "wander_auto": false}

func _advance_freight_fixture(state: Dictionary) -> void:
	state["elapsed"] += 0.5
	ECON._rock_plan_tick += 1
	ECON._rock_plan_budget = ECON.ROCK_PLAN_LIMIT
	ECON._rock_route_queries.clear()

func _test_physical_freight() -> void:
	var state: Dictionary = ECON.create(MAP.generate(716, 2, "Grid"), {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var dock: Vector2 = ECON.station_position(state, 0, 0.0)
	var point: Vector2 = dock + Vector2(250, 250)
	var graph: Dictionary = ECON.military_graph(state)
	var builder: Dictionary = _freight_hull(100, "construction_ship", point)
	var freight: Dictionary = _freight_hull(101, "ship", dock)
	state["ships"] = [builder, freight]
	state["next_id"] = 102
	state["planets"][0]["stock"] = {"Metals": 600.0, "Crystals": 40.0, "Organics": 0.0}
	assert(ECON.issue_unit_order(state, 1, [100], {"kind": "build_depot", "point": point}, false))
	var site: Dictionary = state["ships"].back()
	builder["construction_target"] = site["id"]
	var transferred: bool = false
	for tick in range(3000):
		var progress: float = site["build_progress"]
		var before: float = ECON._cargo_total(builder)
		ECON._try_static_freight(state, graph, freight, 0.5)
		assert(site["build_progress"] == progress)
		if ECON._cargo_total(builder) > before + ECON.EPS:
			transferred = true
			assert((freight["position"] as Vector2).distance_to(builder["position"]) <= ECON.TRACTOR_RANGE + 0.01)
		ECON._work_construction(state, graph, builder, 0.5)
		for resource in site["build_recipe"]:
			var total: float = float(site["build_delivered"].get(resource, 0.0)) + float(builder["cargo"].get(resource, 0.0)) + float(freight["cargo"].get(resource, 0.0))
			for record in site["build_reservations"].values():
				total += float(record["cargo"].get(resource, 0.0))
			assert(is_equal_approx(total, float(site["build_recipe"][resource])))
		if ECON.static_complete(site):
			break
		_advance_freight_fixture(state)
	assert(transferred and ECON.static_complete(site))
	print("PASS: physical freighter rendezvous, constructor-only progress and material conservation")

func _test_physical_depot() -> void:
	var state: Dictionary = ECON.create(MAP.generate(717, 2, "Grid"), {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var dock: Vector2 = ECON.station_position(state, 0, 0.0)
	var point: Vector2 = dock + Vector2(250, 250)
	var graph: Dictionary = ECON.military_graph(state)
	var freight: Dictionary = _freight_hull(100, "ship", dock)
	var depot: Dictionary = _freight_hull(101, "resource_depot", point)
	depot["build_progress"] = 1.0
	depot["cargo"]["Metals"] = 500.0
	state["ships"] = [freight, depot]
	var p: Dictionary = state["planets"][0]
	for resource in ECON.RESOURCES:
		assert(ECON.set_depot_policy(state, 1, 101, resource, 0.0, 100.0, false, false))
	assert(ECON.set_depot_policy(state, 1, 101, "Metals", 20.0, 30.0, true, false))
	assert(ECON.set_thresholds(state, 1, 0, "Metals", 0.0, 0.0, false, true))
	p["stock"]["Metals"] = 200.0
	var total: float = 700.0
	for tick in range(2000):
		ECON._try_static_freight(state, graph, freight, 0.5)
		assert(is_equal_approx(total, p["stock"]["Metals"] + depot["cargo"]["Metals"] + freight["cargo"]["Metals"]))
		assert(depot["cargo"]["Metals"] <= 600.0 + ECON.EPS)
		if is_equal_approx(float(depot["cargo"]["Metals"]), 600.0) and not freight.has("depot_freight"):
			break
		_advance_freight_fixture(state)
	assert(is_equal_approx(float(depot["cargo"]["Metals"]), 600.0))
	assert(ECON._cargo_total(freight) <= ECON.EPS)
	assert(ECON.set_depot_policy(state, 1, 101, "Metals", 20.0, 30.0, false, true))
	assert(ECON.set_thresholds(state, 1, 0, "Metals", 100.0, 100.0, true, false))
	for tick in range(2000):
		ECON._try_static_freight(state, graph, freight, 0.5)
		assert(is_equal_approx(total, p["stock"]["Metals"] + depot["cargo"]["Metals"] + freight["cargo"]["Metals"]))
		assert(depot["cargo"]["Metals"] >= 400.0 - ECON.EPS)
		if is_equal_approx(float(depot["cargo"]["Metals"]), 400.0) and not freight.has("depot_freight"):
			break
		_advance_freight_fixture(state)
	assert(is_equal_approx(float(depot["cargo"]["Metals"]), 400.0))
	assert(is_equal_approx(float(p["stock"]["Metals"]), 300.0))
	# Interrupt an active shipment without losing cargo or leaving a stale job.
	assert(ECON.set_depot_policy(state, 1, 101, "Metals", 0.0, 100.0, true, false))
	assert(ECON.set_thresholds(state, 1, 0, "Metals", 0.0, 0.0, false, true))
	for tick in range(2000):
		ECON._try_static_freight(state, graph, freight, 0.5)
		if freight.has("depot_freight") and ECON._cargo_total(freight) > ECON.EPS:
			break
		_advance_freight_fixture(state)
	assert(freight.has("depot_freight") and ECON._cargo_total(freight) > ECON.EPS)
	var retained: Dictionary = freight["cargo"].duplicate()
	assert(ECON.set_autocast(state, 1, [100], "trade", false))
	assert(not freight.has("depot_freight") and freight["cargo"] == retained)
	assert(not ECON._try_static_freight(state, graph, freight, 0.5))
	assert(freight["cargo"] == retained)
	print("PASS: automatic depot receiving ceiling, dispatch floor, physical stock conservation and interruption")

func _initialize() -> void:
	_test_physical_freight()
	_test_physical_depot()
	_test_physical_construction()
	_test_wall_movement_and_weapons()
	_test_depot_policy()
	_test_supply_recovery()
	_test_wall_navigation()
	_test_multi_source_materials()
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
	assert(ECON.depot_capacity(ECON.ANTIMATTER) == 0.0)
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
