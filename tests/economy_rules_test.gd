extends SceneTree
const MAP = preload("res://scripts/planet_map.gd")
const ECON = preload("res://scripts/economy_rules.gd")

# Existing demographic, production and colonization scenarios assume planets.
# Retain that explicit fixture while exercising real mixed generation below.
func _planetary_fixture(seed_value: int, players: int = 3, layout: String = "Grid") -> Dictionary:
	var map_data: Dictionary = MAP.generate(seed_value, players, layout)
	map_data["planetless"] = []
	return map_data

func _test_hull_index() -> void:
	var map: Dictionary = _planetary_fixture(426)
	var state: Dictionary = ECON.create(map, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var craft: Dictionary = state["ships"][0]
	var id: int = int(craft["id"])
	craft["position"] = Vector2.ZERO
	ECON._begin_hull_index(state)
	assert(ECON.service_targets(state, id)[id]["entity"] == craft)
	assert(ECON._owned_units(state, int(craft["owner"]), [id]).size() == 1)
	assert(ECON._owned_units(state, -1, [id]).is_empty())
	craft["position"] = Vector2(12, 34)
	assert(ECON.service_targets(state, id)[id]["position"] == craft["position"])
	ECON._remove_indexed_hull(state, craft)
	assert(ECON.service_targets(state, id).is_empty())
	assert(ECON._owned_units(state, int(craft["owner"]), [id]).is_empty())
	ECON._indexed_state = {}
	ECON._hulls_by_id.clear()
	print("PASS: live indexed hull references, ownership and removal")

func _test_shipyard_rally() -> void:
	var map: Dictionary = {"seed": 426, "points": [Vector2.ZERO, Vector2(5000, 0)], "edges": [[0, 1]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var system: Dictionary = state["planets"][0]
	system["population"] = 100000.0
	system["yards"].append({"level": 1, "job": -1, "hp": ECON.YARD_HP})
	for resource in ECON.RESOURCES:
		system["stock"][resource] = 10000.0
	var point := Vector2(100, 100)
	assert(not ECON.set_shipyard_rally(state, 2, 0, 1, 0, point))
	assert(not ECON.set_shipyard_rally(state, 1, 0, 99, 0, point))
	assert(not ECON.set_shipyard_rally(state, 1, 0, 1, 0, Vector2.INF))
	assert(ECON.set_shipyard_rally(state, 1, 0, 1, 0, point))
	assert(not ECON.enqueue(state, 1, 0, "fighter", "", 99))
	assert(ECON.enqueue(state, 1, 0, "fighter", "", 1))
	var job: Dictionary = system["queue"].back()
	ECON._work_planet(state, 0, 0.1)
	assert(int(system["yards"][0]["job"]) != int(job["id"]))
	assert(int(system["yards"][1]["job"]) == int(job["id"]))
	ECON._finish(state, 0, system, job)
	var craft: Dictionary = state["ships"].back()
	assert(craft.has("launch_rally") and not bool(craft.get("move_only", false)))
	var graph: Dictionary = ECON.military_graph(state)
	var enemy: Dictionary = {"id": 990001, "kind": "fighter", "owner": 2, "origin": 1, "at": 0, "position": (craft["position"] as Vector2) + Vector2.RIGHT * ECON.LASER_RANGE * 0.85, "route": [], "leg": 0.0, "dest": 0, "hp": ECON.SHIP_HP}
	state["ships"] = [craft, enemy]
	ECON._combat(state, graph, 0.1)
	assert(int(craft.get("combat_target", -1)) == 990001 and float(enemy["hp"]) < ECON.SHIP_HP)
	assert(not ECON._work_launch_rally(state, craft, 0.1) and craft.has("launch_rally"))
	var before_combat: Vector2 = craft["position"]
	ECON.step(state, 0.1)
	assert(craft.has("launch_rally") and craft["position"] != before_combat and ECON._engaged(craft), "Fighter state after rally engagement: %s, prior position: %s" % [craft, before_combat])
	state["ships"] = [craft]
	ECON._combat(state, graph, 0.1)
	craft["retreating"] = true
	assert(not ECON._work_launch_rally(state, craft, 0.1) and craft.has("launch_rally"))
	craft["retreating"] = false
	craft["dest"] = -1 # Repair clears the current destination.
	for tick in range(200):
		if not ECON._work_launch_rally(state, craft, 0.5):
			break
	assert(not craft.has("launch_rally") and (craft["position"] as Vector2).distance_to(point) <= ECON.RALLY_ARRIVAL_RADIUS and ECON._is_idle_ship(craft))
	var arrived: Vector2 = craft["position"]
	ECON.step(state, 0.1)
	assert(craft["position"] != arrived and not craft.get("holding", false))
	# Multiple hulls within the arrival neighborhood must release even
	# when mutual separation prevents occupying the exact target point.
	for i in range(12):
		var extra: Dictionary = craft.duplicate(true)
		extra["id"] = 990010 + i
		extra["position"] = point + Vector2.from_angle(TAU * i / 12.0) * ECON.SHIP_SEPARATION_RADIUS
		ECON._launch_to_rally(state, extra, {"node": 0, "point": point})
		assert(ECON._work_launch_rally(state, extra, 0.1))
		assert(not extra.has("launch_rally") and ECON._is_idle_ship(extra))
		state["ships"].append(extra)
	assert(ECON.set_shipyard_rally(state, 1, 0, 1, -1, Vector2.ZERO))
	assert(not system["yards"][1].has("rally"))
	print("PASS: shipyard rally attack-move combat, repair destination retention and relaxed fleet arrival")

func _test_rounded_sector_limits() -> void:
	# Equal perpendicular bisectors used to form a sharp corner. The
	# rounded corner must stay inside both constraints while the middle
	# of an isolated straight boundary remains unchanged.
	var graph: Dictionary = {"points": [Vector2.ZERO, Vector2(120, 0), Vector2(0, 120)], "sector_radii": [100.0, 100.0, 100.0], "sector_neighbors": [[Vector2(120, 0), Vector2(0, 120)], [], []]}
	var diagonal: Vector2 = Vector2.ONE.normalized()
	var hard_corner: float = 60.0 / diagonal.x
	var rounded: float = ECON.sector_limit(graph, 0, diagonal)
	assert(is_equal_approx(ECON.sector_limit(graph, 0, Vector2.RIGHT), 60.0))
	assert(rounded < hard_corner and rounded > hard_corner * 0.8)
	assert(ECON.sector_contains(graph, 0, diagonal * (rounded - 0.1)))
	assert(not ECON.sector_contains(graph, 0, diagonal * (rounded + 0.1)))
	assert(not ECON.sector_contains(graph, 0, Vector2(60.1, 0)))
	var cached: Dictionary = graph.duplicate(true)
	ECON._index_sector_bounds(cached, 100.0)
	for x in range(-150, 251, 5):
		for y in range(-150, 251, 5):
			var point := Vector2(x, y)
			assert(ECON.sector_at(graph, point, [0, 1, 2]) == ECON.sector_at(cached, point, [0, 1, 2]))
			assert(ECON.sector_at(graph, point, [2, 0], 2) == ECON.sector_at(cached, point, [2, 0], 2))
	cached["sector_neighbor_squares"] = [[14400.0, 14400.0], [], []]
	for i in range(360):
		var direction: Vector2 = Vector2.from_angle(deg_to_rad(float(i)))
		var boundary: float = ECON.sector_limit(graph, 0, direction)
		assert(is_equal_approx(boundary, ECON.sector_limit(cached, 0, direction)))
		assert(ECON.sector_contains(cached, 0, direction * (boundary - 0.1)))
		assert(not ECON.sector_contains(cached, 0, direction * (boundary + 0.1)))

func _test_explicit_hold_pose() -> void:
	var map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(5000, 0)], "edges": [[0, 1]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}}, [1], false)
	var point := Vector2(100, 200)
	var a: Dictionary = {"id": 501, "kind": "fighter", "owner": 1, "origin": 0, "at": 0, "dest": 1, "source": -1, "route": [1], "leg": 0.0, "position": point, "heading": Vector2.LEFT, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock()}
	var b: Dictionary = a.duplicate(true)
	b.merge({"id": 502, "kind": "miner", "heading": Vector2.DOWN, "mining_mode": "idle"}, true)
	state["ships"] = [a, b]
	assert(ECON.command_hold_units(state, 1, [501, 502], false))
	for tick in range(20):
		ECON.step(state, 0.1)
		assert(a["position"] == point and b["position"] == point)
		assert(a["heading"] == Vector2.LEFT and b["heading"] == Vector2.DOWN)
		assert(a["route"].is_empty() and b["route"].is_empty())
	assert(ECON.command_hold_units(state, 1, [501, 502], true))
	assert(not a.has("hold_heading") and not b.has("hold_heading"))
	print("PASS: explicit hold preserves each ship's position and heading despite overlap")

func _test_soft_separation() -> void:
	var map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(5000, 0)], "edges": [[0, 1]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var point := Vector2(100.0, 200.0)
	var a: Dictionary = {"id": 501, "kind": "fighter", "owner": 1, "at": 0, "route": [], "position": point, "holding": true, "hold_position": point, "hold_sector": 0}
	var b: Dictionary = a.duplicate(true)
	b["id"] = 502
	state["ships"] = [a, b]
	var graph: Dictionary = ECON.military_graph(state)
	var previous: Dictionary = {501: point, 502: point}
	ECON._separate_ships(state, graph, previous, 0.1)
	assert((a["position"] as Vector2).distance_to(b["position"]) > 0.0)
	assert((a["position"] as Vector2).distance_to(point) <= ECON.ship_speed(str(a["kind"])) * 0.1 + ECON.EPS)
	assert((b["position"] as Vector2).distance_to(point) <= ECON.ship_speed(str(b["kind"])) * 0.1 + ECON.EPS)
	assert(((a["position"] as Vector2) + (b["position"] as Vector2)).is_equal_approx(point * 2.0))
	assert(a["hold_position"] == point and b["hold_position"] == point)
	assert(ECON.sector_contains(graph, 0, a["position"]) and ECON.sector_contains(graph, 0, b["position"]))
	state["ships"] = [a]
	previous = {501: a["position"]}
	var unchanged: Vector2 = a["position"]
	ECON._separate_ships(state, graph, previous, 0.1)
	assert(a["position"] == unchanged)
	# Independently ordered, different-owner hulls may converge in the same
	# tick, even when neither was in the old steering neighborhood.
	state["ships"] = [a, b]
	a["position"] = point
	b["position"] = point
	b["owner"] = 2
	b["kind"] = "ship"
	a["arrival_wait_until"] = 30.0
	b["salvage_delivery"] = true
	previous = {501: point - Vector2.RIGHT * 100.0, 502: point + Vector2.RIGHT * 100.0}
	ECON._resolve_ship_contacts(state, graph, previous)
	assert((a["position"] as Vector2).distance_to(b["position"]) > 0.0)
	assert((a["position"] as Vector2).distance_to(b["position"]) < ECON.SHIP_CLEARANCE)
	assert((a["position"] as Vector2).distance_to(point) <= ECON.ship_speed("fighter") * 0.1 * 0.15 + ECON.EPS)
	assert((b["position"] as Vector2).distance_to(point) <= ECON.ship_speed("ship") * 0.1 * 0.15 + ECON.EPS)
	assert(is_equal_approx(ECON.ship_speed("fighter"), ECON.ship_speed("ship") * 1.2))
	assert(ECON.ship_speed("miner") < ECON.SHIP_SPEED and ECON.ship_speed("ship") > ECON.SHIP_SPEED)
	assert(a["holding"] and a["arrival_wait_until"] == 30.0 and b["salvage_delivery"])
	assert(ECON.sector_contains(graph, 0, a["position"]) and ECON.sector_contains(graph, 0, b["position"]))

func _test_maintain_targets() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(827, 1, "Grid"), {1: {"team": 1}}, [1])
	var p: Dictionary = state["planets"][0]
	assert(ECON.origin_count(state, 0, "fighter") == 2)
	assert(not ECON.set_maintain(state, 2, 0, "fighter", 3))
	assert(ECON.set_maintain(state, 1, 0, "fighter", 3))
	ECON._refill_continuous(state, 0, p)
	assert(p["queue"].size() == 1)
	ECON._refill_continuous(state, 0, p)
	assert(p["queue"].size() == 1)
	assert(ECON.set_continuous(state, 1, 0, "fighter", true))
	assert(int(p["maintain"]["fighter"]) == 3)
	assert(ECON.set_maintain(state, 1, 0, "fighter", 2))
	assert(not bool(p["continuous"]["fighter"]))
	p["home"] = false
	p["yards"].clear()
	assert(ECON.set_maintain(state, 1, 0, "ship", 7))
	assert(ECON.set_maintain(state, 1, 0, "miner", 9))
	ECON._refill_continuous(state, 0, p)
	assert(int(p["maintain"]["ship"]) == 7 and int(p["maintain"]["miner"]) == 9)

func _test_yard_autobuild_and_station_approach() -> void:
	var map: Dictionary = {"seed": 426, "points": [Vector2.ZERO, Vector2(5000, 0)], "edges": [[0, 1]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var p: Dictionary = state["planets"][0]
	p["population"] = 100000.0
	p["yards"].append({"level": 1, "job": -1, "hp": ECON.YARD_HP})
	for resource in ECON.RESOURCES:
		p["stock"][resource] = 100000.0
	assert(not ECON.set_yard_autobuild(state, 2, 0, 0, "fighter", true))
	assert(not ECON.set_yard_autobuild(state, 1, 0, 99, "fighter", true))
	assert(ECON.set_yard_autobuild(state, 1, 0, 0, "fighter", true))
	assert(ECON.set_yard_autobuild(state, 1, 0, 0, "miner", true))
	ECON._refill_yard_autobuild(state, 0, p)
	ECON._refill_yard_autobuild(state, 0, p)
	assert(p["queue"].size() == 2 and p["queue"][0]["kind"] == "fighter" and p["queue"][1]["kind"] == "miner")
	ECON._finish(state, 0, p, p["queue"][0])
	ECON._refill_yard_autobuild(state, 0, p)
	assert(p["queue"].size() == 2 and p["queue"][0]["kind"] == "miner" and p["queue"][1]["kind"] == "fighter")
	assert(ECON.set_yard_autobuild(state, 1, 0, 0, "miner", false))
	assert(ECON.cancel(state, 1, 0, int(p["queue"][1]["id"])))
	assert(p["yards"][0]["autobuild"].is_empty())
	for i in range(7):
		assert(ECON.enqueue(state, 1, 0, "fighter", "", 0))
	assert(ECON.shipyard_queue_count(p, 0) == 8 and not ECON.enqueue(state, 1, 0, "fighter", "", 0))
	assert(ECON.enqueue(state, 1, 0, "fighter", "", 1))
	p["yards"][1]["level"] = 3
	assert(not ECON.enqueue(state, 1, 0, "yard_upgrade", "1"))
	var dock: Vector2 = ECON.station_position(state, 0, float(state["elapsed"]))
	var miner: Dictionary = {"kind": "miner", "owner": 1, "at": 1, "dest": 0, "route": [0], "position": Vector2(300, 0), "leg": 0.0, "cargo": ECON.empty_stock()}
	assert(not ECON._move(state, miner, 0.1) and miner["navigation_target"] == dock)
	assert(ECON._move(state, miner, 100.0) and miner["position"] == dock and miner["navigation_target"] == dock)
	var fighter: Dictionary = {"kind": "fighter", "owner": 1, "at": 1, "route": [0], "position": Vector2(300, 0), "leg": 0.0}
	assert(ECON._move({"map": map}, fighter, 100.0, dock, 0) and fighter["position"] == dock)
	print("PASS: per-shipyard round robin, capacity, cancellation, upgrade cap and direct station approach")

func _test_population_queue_priority() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(827, 1), {1: {"team": 1}}, [1], false)
	var p: Dictionary = state["planets"][0]
	p["population"] = 10000.0
	for resource in ECON.RESOURCES:
		p["stock"][resource] = 100000.0
	assert(not ECON.enqueue(state, 1, 0, "colony_ship", "", 0))
	p["yards"][0]["level"] = 2
	assert(ECON.enqueue(state, 1, 0, "colony_ship", "", 0))
	var colony: Dictionary = p["queue"][0]
	ECON._work_planet(state, 0, 0.1)
	assert(int(p["yards"][0]["job"]) == -1 and colony["progress"] == 0.0)
	assert(ECON.enqueue(state, 1, 0, "fighter", "", 0))
	var fighter: Dictionary = p["queue"][1]
	ECON._work_planet(state, 0, 0.1)
	assert(int(p["yards"][0]["job"]) == int(fighter["id"]) and fighter["progress"] > 0.0 and colony["progress"] == 0.0)
	var progress: float = fighter["progress"]
	p["population"] = 600.0
	p["eco_population"] = 0.0
	ECON._work_planet(state, 0, 0.1)
	assert(int(p["yards"][0]["job"]) == -1 and fighter["progress"] == progress)
	assert("Population" in ECON.construction_blockers(p, fighter, 0))
	p["population"] = 45000.0
	ECON._work_planet(state, 0, 0.1)
	assert(int(p["yards"][0]["job"]) == int(colony["id"]) and colony["progress"] > 0.0)
	assert(fighter["progress"] == progress and p["queue"].size() == 2)
	assert(ECON.cancel(state, 1, 0, int(colony["id"])))
	ECON._work_planet(state, 0, 0.1)
	assert(int(p["yards"][0]["job"]) == int(fighter["id"]) and fighter["progress"] > progress)
	print("PASS: population-blocked pinned jobs release the yard, eligible work advances and retained progress resumes")

func _test_mining_lasers() -> void:
	var rock := Vector2(1000, 0)
	var map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(5000, 0)], "edges": [[0, 1]], "fields": [{"position": rock, "radius": 40.0, "anchor": 0, "Metals": 0.5, "Crystals": 0.5, "chunks": [{"id": 7, "position": rock, "resource": "Metals", "remaining": 24.0}]}]}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var graph: Dictionary = ECON.military_graph(state)
	var miner: Dictionary = {"id": 100, "owner": 1, "kind": "miner", "at": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": rock + Vector2.LEFT * 20, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock(), "mining_mode": "mining", "field": 0, "chunk": 7, "mining_rock": rock, "mining_target": rock + Vector2.LEFT * 20, "mining_years": 0.0}
	var enemy: Dictionary = {"id": 101, "owner": 2, "kind": "ship", "at": 1, "dest": -1, "route": [], "leg": 0.0, "position": rock + Vector2.UP * 50, "hp": ECON.SHIP_HP}
	var friend: Dictionary = {"id": 102, "owner": 1, "kind": "fighter", "at": 0, "dest": 0, "route": [], "leg": 0.0, "position": rock + Vector2.LEFT * 300, "hp": ECON.SHIP_HP}
	state["ships"] = [miner, enemy, friend]
	var field: Dictionary = state["map"]["fields"][0]
	var chunk: Dictionary = field["chunks"][0]
	var budgets: Array = [{"Metals": 100.0, "Crystals": 100.0}]
	ECON._combat(state, graph, 1.0)
	assert(enemy["hp"] == ECON.SHIP_HP - ECON.MINER_LASER_DAMAGE and miner["combat_target"] == 101 and miner["pursuit_target"] == -1)
	assert(friend["hp"] == ECON.SHIP_HP and chunk["remaining"] == 24.0)
	ECON._work_miner(state, miner, ECON.planet_teams(state), {}, budgets, 1.0)
	assert(chunk["remaining"] == 24.0 and not miner["mining_active"])
	# Moving armed ships still fire in range.
	miner["move_only"] = true
	miner["local_move_target"] = rock
	ECON._combat(state, graph, 1.0)
	assert(miner["combat_target"] == 101 and enemy["hp"] == ECON.SHIP_HP - ECON.MINER_LASER_DAMAGE * 2.0)
	miner.erase("local_move_target")
	state["ships"].erase(enemy)
	ECON._combat(state, graph, 1.0)
	assert(not ECON.command_miners(state, 1, [102], 0, 7))
	ECON._work_miner(state, miner, ECON.planet_teams(state), {}, budgets, 1.0)
	var mined: float = ECON.MINER_LASER_DAMAGE * ECON.MINER_ASTEROID_MULTIPLIER * 0.5
	assert(miner["mining_active"] and is_equal_approx(chunk["remaining"], 24.0 - mined) and is_equal_approx(miner["cargo"]["Metals"], mined))
	assert(is_equal_approx(budgets[0]["Metals"], 100.0 - mined))
	print("PASS: weak miner fire, friendly safety, no pursuit, passing fire, asteroid bonus and conserved ore")

func _test_repair_pauses_wander() -> void:
	assert(ECON.MINER_REPAIR_RATE == 10.0 and ECON.REPAIR_PER_YEAR == 20.0)
	for reverse in [false, true]:
		var map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(5000, 0)], "edges": [[0, 1]], "fields": []}
		var state: Dictionary = ECON.create(map, {1: {"team": 1}}, [1], false)
		var miner: Dictionary = {"id": 100, "owner": 1, "kind": "miner", "origin": 0, "at": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": Vector2(500, 0), "heading": Vector2.UP, "hp": ECON.ship_max_hp("miner"), "cargo": ECON.empty_stock(), "mining_mode": "idle", "mine_auto": false, "salvage_auto": false, "wander_auto": false}
		var patient: Dictionary = {"id": 101, "owner": 1, "kind": "scout", "origin": 0, "at": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": Vector2(550, 0), "heading": Vector2.UP, "hp": 20.0, "cargo": ECON.empty_stock(), "wander_auto": true}
		state["ships"] = [patient, miner] if reverse else [miner, patient]
		var point: Vector2 = patient["position"]
		for tick in range(5):
			ECON.step(state, 0.1)
			assert(patient["position"] == point and miner.get("repair_target", -1) == 101)
		assert(float(patient["hp"]) > 20.0 and ECON.autocast_enabled(patient, "wander"))
		for tick in range(100):
			ECON.step(state, 0.1)
			if patient["position"] != point:
				break
		assert(is_equal_approx(float(patient["hp"]), ECON.ship_max_hp("scout")) and patient["position"] != point)
	print("PASS: active repair rates, idle recipient motion pause, automatic wander resumption in either fleet order")

func _test_miner_service_orders() -> void:
	var map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(5000, 0), Vector2(10000, 0)], "edges": [[0, 1], [1, 2]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var graph: Dictionary = ECON.military_graph(state)
	var miner: Dictionary = {"id": 100, "owner": 1, "kind": "miner", "at": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": Vector2(500, 0), "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock(), "mining_mode": "delivery", "field": -1}
	var ally: Dictionary = miner.duplicate(true)
	ally.merge({"id": 101, "kind": "ship", "hp": 70.0, "position": Vector2(550, 0)}, true)
	var foe: Dictionary = ally.duplicate(true)
	foe.merge({"id": 102, "owner": 2, "position": Vector2(800, 0)}, true)
	state["ships"] = [miner, ally, foe]
	assert(ECON._work_miner_repair(state, graph, miner, ECON.service_targets(state), 1.0))
	assert(ally["hp"] == 70.0 + ECON.MINER_REPAIR_RATE and foe["hp"] == 70.0 and miner["repair_target"] == 101)
	assert(not ECON.set_repair_auto(state, 2, [100], false))
	assert(ECON.set_repair_auto(state, 1, [100], false))
	assert(not ECON._work_miner_repair(state, graph, miner, ECON.service_targets(state), 1.0))
	assert(not ECON.issue_unit_order(state, 1, [100], {"kind": "repair", "target": 102}, false))
	assert(ECON.issue_unit_order(state, 1, [100], {"kind": "repair", "target": 101}, false))
	assert(ECON._work_miner_repair(state, graph, miner, ECON.service_targets(state), 1.0))
	assert(ally["hp"] == 70.0 + 2.0 * ECON.MINER_REPAIR_RATE)
	var station: Dictionary = state["planets"][0]["station"]
	station["hp"] = ECON.STATION_HP - 10.0
	miner["position"] = ECON.station_position(state, 0, 0.0)
	var station_id: int = ECON.station_target_id(state, 0)
	assert(ECON.issue_unit_order(state, 1, [100], {"kind": "repair", "target": station_id}, false))
	assert(ECON._work_miner_repair(state, graph, miner, ECON.service_targets(state), 1.0))
	assert(station["hp"] == ECON.STATION_HP)
	var pds_id: int = -2 - state["planets"].size() * 3
	var defense: Dictionary = state["planets"][0]["pds"][0]
	defense["hp"] = ECON.PDS_HP - 20.0
	var ref: Dictionary = ECON.service_targets(state)[pds_id]
	var battery_point: Vector2 = ref["repair_position"]
	assert(battery_point.distance_to(map["points"][0]) > ECON.EPS)
	assert(ECON.issue_unit_order(state, 1, [100], {"kind": "repair", "target": pds_id}, false))
	# Opposite side of the star, outside battery range even though near the star.
	miner["position"] = (map["points"][0] as Vector2) - (battery_point - (map["points"][0] as Vector2)).normalized() * (ECON.LASER_RANGE - 1.0)
	assert(ECON._work_miner_repair(state, graph, miner, ECON.service_targets(state), 0.01))
	assert(is_equal_approx(float(defense["hp"]), ECON.PDS_HP - 20.0))
	miner["position"] = battery_point
	assert(ECON._work_miner_repair(state, graph, miner, ECON.service_targets(state), 1.0))
	assert(is_equal_approx(float(defense["hp"]), ECON.PDS_HP - 20.0 + ECON.MINER_REPAIR_RATE))
	assert(int(miner["repair_target"]) == pds_id)
	assert(is_equal_approx(float(station["hp"]), ECON.STATION_HP))
	miner["hp"] = ECON.WITHDRAW_HP
	ECON._prepare_withdrawals(state, graph)
	assert(not miner.get("retreating", false))
	assert(not ECON.set_autocast(state, 2, [int(miner["id"])], "retreat", true))
	assert(ECON.set_autocast(state, 1, [int(miner["id"])], "retreat", true))
	ECON._prepare_withdrawals(state, graph)
	assert(miner.get("retreating", false))
	miner["hp"] = ECON.SHIP_HP
	miner["retreating"] = false
	miner["cargo"]["Metals"] = ECON.MINER_CAPACITY
	# A loaded miner waiting on a full warehouse can travel and dump its
	# exact cargo at an arbitrary point, without creating structural loot.
	var remote := Vector2(10000, 100)
	assert(ECON.issue_unit_order(state, 1, [100], {"kind": "position", "target": 2, "point": remote, "move_only": true}, false))
	assert(miner.has("local_move_target") and not miner.has("repair_order"))
	for tick in range(200):
		if not miner.has("local_move_target"):
			break
		ECON._work_local_move(graph, miner, 1.0, state)
	assert(miner["position"] == remote and miner["at"] == 2 and miner["cargo"]["Metals"] == ECON.MINER_CAPACITY)
	var drop := remote + Vector2(40, 40)
	assert(ECON.issue_unit_order(state, 1, [100], {"kind": "drop", "point": drop}, false))
	assert(ECON._work_cargo_order(state, graph, miner, ECON.service_targets(state), 1.0))
	assert(miner["position"] == drop and ECON._cargo_total(miner) == 0.0 and state["salvage"].size() == 1)
	var pile: Dictionary = state["salvage"].values()[0]
	assert(pile["amount"] == ECON.MINER_CAPACITY and pile["position"] == drop)
	assert(ECON.issue_unit_order(state, 1, [100], {"kind": "salvage", "target": pile["id"]}, false))
	assert(ECON._work_salvage(state, graph, miner, 10.0))
	assert(is_equal_approx(miner["cargo"]["Metals"], ECON.MINER_CAPACITY))
	var depot: Dictionary = state["planets"][0]
	depot["stock"]["Metals"] = ECON.storage_capacity(depot) - 3.0
	assert(ECON.issue_unit_order(state, 1, [100], {"kind": "deposit", "target": station_id}, false))
	miner["position"] = ECON.station_position(state, 0, 0.0)
	assert(ECON._work_cargo_order(state, graph, miner, ECON.service_targets(state), 1.0))
	assert(miner["cargo"]["Metals"] == ECON.MINER_CAPACITY - 3.0 and depot["stock"]["Metals"] == ECON.storage_capacity(depot))
	assert(not ECON.can_deposit(state, miner, station_id))
	assert(not ECON.can_deposit(state, miner, ECON.station_target_id(state, 1)))
	# A focused attack ignores a closer hostile; focus can be a structure.
	miner["position"] = Vector2(500, 0)
	foe["position"] = Vector2(550, 0)
	var far: Dictionary = foe.duplicate(true)
	far.merge({"id": 103, "position": Vector2(1000, 0)}, true)
	state["ships"].append(far)
	assert(ECON.command_attack(state, 1, [100], 103))
	ECON._combat(state, graph, 1.0)
	assert(foe["hp"] == 70.0 and far["hp"] == 70.0)
	assert(ECON.command_attack(state, 1, [100], ECON.station_target_id(state, 1)))
	print("PASS: miner repair/autocast, withdrawal priority, remote orders, targeted cargo conservation and focused attacks")

func _cancelled_material(state: Dictionary, job_id: int, resource: String) -> float:
	var result: float = 0.0
	for pile in state["salvage"].values():
		if int(pile.get("construction_job", -1)) == job_id and pile["resource"] == resource:
			result += float(pile["amount"])
	return result

func _test_station_construction_queue() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(827, 2), {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var p: Dictionary = state["planets"][0]
	for resource in ECON.RESOURCES:
		p["stock"][resource] = 10000.0
	p["population"] = 100000.0
	var prior: Dictionary = p["stock"].duplicate()
	assert(not ECON.enqueue(state, 2, 0, "economy", "habitation"))
	assert(ECON.enqueue(state, 1, 0, "economy", "habitation"))
	var job: Dictionary = p["queue"].back()
	assert(job["kind"] == "habitation" and int(job["size"]) == 0 and int(p.get("habitation_level", 0)) == 0)
	assert(not ECON.enqueue(state, 1, 0, "economy", "habitation"))
	assert(not ECON.cancel(state, 2, 0, int(job["id"])))
	assert(ECON.cancel(state, 1, 0, int(job["id"])))
	for resource in ECON.RESOURCES:
		assert(is_equal_approx(float(p["stock"][resource]) + _cancelled_material(state, int(job["id"]), resource), float(prior[resource])))
		assert(is_zero_approx(_cancelled_material(state, int(job["id"]), resource)))
	assert(ECON.enqueue(state, 1, 0, "economy", "habitation"))
	assert(ECON.enqueue(state, 1, 0, "economy", "Metals"))
	assert(ECON.enqueue(state, 1, 0, "fighter", "", 0))
	assert(ECON.shipyard_queue_count(p, 0) == 1)
	var active: Dictionary = ECON.station_construction_job(p)
	var queued: Dictionary = p["queue"][1]
	var fighter: Dictionary = p["queue"][2]
	var duration: float = ECON._work("habitation", 1)
	assert(duration > 1.0)
	ECON._work_planet(state, 0, 0.1)
	assert(is_equal_approx(float(active["progress"]), 0.1))
	assert(float(queued["progress"]) == 0.0 and float(fighter["progress"]) > 0.0)
	assert(int(p.get("habitation_level", 0)) == 0 and ECON._has_job(p, "habitation", ""))
	assert(ECON._has_job(p, "economy_building", "Metals") and ECON.shipyard_queue_count(p, 0) == 1)
	ECON._work_planet(state, 0, duration - 0.1)
	assert(int(p.get("habitation_level", 0)) == 0 and active.has("delivery_slot"))
	assert(not ECON.enqueue(state, 1, 0, "economy", "habitation"))
	ECON._work_upgrade_deliveries(state, 0, p, ECON.PLANET_UPGRADE_DELIVERY_TIME - 0.1)
	assert(int(p.get("habitation_level", 0)) == 0)
	ECON._work_upgrade_deliveries(state, 0, p, 0.1)
	assert(int(p["habitation_level"]) == 1 and not ECON._has_job(p, "habitation", ""))
	assert(ECON._has_job(p, "economy_building", "Metals") and ECON.shipyard_queue_count(p, 0) == 0)
	assert(ECON.station_construction_job(p) == queued and float(queued["progress"]) < ECON.EPS)
	ECON._work_planet(state, 0, 1.0)
	assert(is_equal_approx(float(queued["progress"]), 1.0))
	assert(ECON.set_continuous(state, 1, 0, "habitation", true))
	ECON._refill_continuous(state, 0, p)
	assert(ECON._has_job(p, "habitation", ""))
	ECON._refill_continuous(state, 0, p)
	var repeat_count: int = 0
	for item in p["queue"]:
		repeat_count += int(item["kind"] == "habitation")
	assert(repeat_count == 1)
	ECON._work_station_queue(state, 0, p, float(queued["work"]) - float(queued["progress"]) + 0.5)
	assert(ECON._has_job(p, "economy_building", "Metals") and queued.has("delivery_slot"))
	ECON._work_upgrade_deliveries(state, 0, p, ECON.PLANET_UPGRADE_DELIVERY_TIME)
	assert(not ECON._has_job(p, "economy_building", "Metals"))
	assert(ECON.station_construction_job(p)["kind"] == "habitation")
	assert(is_equal_approx(float(ECON.station_construction_job(p)["progress"]), 0.5))
	print("PASS: sequential station FIFO, independent shipyards, carryover time, refunds and repeat")

func _test_ai_capital_fleets() -> void:
	var map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(5000, 0)], "edges": [[0, 1]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1, "ai": true}, 2: {"team": 2}}, [1, 2], false)
	var p: Dictionary = state["planets"][0]
	p["population"] = 100000.0
	p["levels"]["Metals"] = 2
	p["yards"][0]["level"] = 2
	for resource in ECON.RESOURCES:
		p["stock"][resource] = 2000.0
	for i in range(ECON.AI_WAVE_MIN):
		state["ships"].append({"id": 500 + i, "kind": "fighter", "owner": 1, "origin": 0, "at": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": Vector2(50.0 * i, 0), "heading": Vector2.UP, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock()})
	var graph: Dictionary = ECON.military_graph(state)
	ECON._ai_turn(state, graph, 1)
	assert(p["queue"].size() == 1 and p["queue"][0]["kind"] == "cruiser")
	p["queue"].clear()
	p["yards"][0]["level"] = 3
	var capital: Dictionary = state["ships"][0].duplicate(true)
	capital.merge({"id": 700, "kind": "cruiser", "hp": ECON.ship_max_hp("cruiser"), "direct_order": false}, true)
	state["ships"].append(capital)
	for resource in ECON.RESOURCES:
		p["stock"][resource] = 2000.0
	ECON._ai_turn(state, graph, 1)
	assert(p["queue"].size() == 1 and p["queue"][0]["kind"] == "warehouse")
	assert(capital.get("direct_order", false))
	p["queue"].clear()
	p["warehouse_level"] = 1
	for resource in ECON.RESOURCES:
		p["stock"][resource] = 5000.0
	ECON._ai_turn(state, graph, 1)
	assert(p["queue"].size() == 1 and p["queue"][0]["kind"] == "destroyer")
	print("PASS: AI cruiser construction, capital deployment, warehouse prerequisite and destroyer construction")

func _test_ai_timed_orbital_housing() -> void:
	var galaxy: Dictionary = MAP.generate(827, 2, "Grid")
	var state: Dictionary = ECON.create(galaxy, {1: {"team": 1}, 2: {"team": 2, "ai": true}}, [1, 2], false)
	var index: int = galaxy["planetless"][0]
	var outpost: Dictionary = state["planets"][index]
	outpost["owner"] = 2
	outpost["station"] = {"hp": ECON.STATION_HP}
	for resource in ECON.ORBITAL_HOUSING_COST:
		outpost["stock"][resource] = ECON.ORBITAL_HOUSING_COST[resource]
	ECON._ai_turn(state, ECON.military_graph(state), 2)
	assert(float(outpost["population"]) == 0.0 and int(outpost["orbital_housing"]) == 0)
	assert(outpost["queue"].size() == 1 and outpost["queue"][0]["kind"] == "orbital_housing")
	var work: float = float(outpost["queue"][0]["work"])
	ECON._work_planet(state, index, work * 0.5)
	assert(float(outpost["queue"][0]["progress"]) > 0.0 and int(outpost["orbital_housing"]) == 0)
	ECON._work_planet(state, index, work * 0.5)
	assert(int(outpost["orbital_housing"]) == 1 and float(outpost["population"]) == ECON.ORBITAL_HOUSING_POPULATION)
	print("PASS: AI orbital housing uses the same timed station construction queue")

func _test_station_defense_and_ports() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(827, 2), {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var p: Dictionary = state["planets"][0]
	p["warehouse_level"] = 3
	for resource in ECON.RESOURCES:
		p["stock"][resource] = 20000.0
	var before: Dictionary = p["stock"].duplicate()
	assert(not ECON.enqueue(state, 2, 0, "reinforced_plating"))
	assert(not ECON.enqueue(state, 1, 0, "yard", "port:1"))
	assert(not ECON.enqueue(state, 1, 0, "yard", "port:4"))
	assert(ECON.enqueue(state, 1, 0, "yard", "port:3"))
	assert(not ECON.enqueue(state, 1, 0, "yard", "port:3"))
	assert(ECON.shipyard_port_job(p, 3)["level"] == 2)
	assert(ECON.enqueue(state, 1, 0, "yard", "port:2"))
	assert(ECON.enqueue(state, 1, 0, "reinforced_plating"))
	var plating: Dictionary = p["queue"].back()
	assert(not ECON.enqueue(state, 1, 0, "reinforced_plating"))
	assert(not ECON.cancel(state, 2, 0, plating["id"]))
	assert(ECON.cancel(state, 1, 0, plating["id"]))
	assert(is_equal_approx(float(p["stock"]["Metals"]), float(before["Metals"]) - 8000.0))
	assert(ECON.enqueue(state, 1, 0, "reinforced_plating"))
	assert(ECON.enqueue(state, 1, 0, "laser_matrix"))
	assert(not ECON.enqueue(state, 1, 0, "laser_matrix"))
	p["station"]["hp"] = ECON.STATION_HP - 100.0
	ECON._work_planet(state, 0, ECON._work("yard", 2))
	assert(ECON.shipyard_at_port(p, 3) == 1 and ECON.shipyard_at_port(p, 2) == -1)
	assert(float(ECON.station_construction_job(p)["progress"]) == 0.0)
	ECON._work_planet(state, 0, ECON._work("yard", 3))
	assert(ECON.shipyard_at_port(p, 2) == 2 and ECON.station_max_hp(p) == 10000.0)
	ECON._work_planet(state, 0, ECON._work("reinforced_plating", 1))
	assert(ECON.station_max_hp(p) == 13000.0 and p["station"]["hp"] == 12900.0)
	assert(ECON.service_targets(state)[ECON.station_target_id(state, 0)]["max_hp"] == 13000.0)
	assert(p["station"].get("weapons", []).size() == 2)
	ECON._work_planet(state, 0, ECON._work("laser_matrix", 1))
	assert(p["station"]["weapons"].size() == 4)
	assert(not ECON.enqueue(state, 1, 0, "reinforced_plating"))
	assert(not ECON.enqueue(state, 1, 0, "laser_matrix"))
	assert(ECON.shipyard_at_port(p, 3) == 1 and ECON.shipyard_at_port(p, 2) == 2)
	var graph: Dictionary = ECON.military_graph(state)
	var origin: Vector2 = ECON.station_position(state, 0, 0.0)
	p["pds"].clear()
	state["ships"] = [
		{"id": 9900, "owner": 2, "kind": "ship", "at": 0, "route": [], "position": origin, "hp": 100.0},
		{"id": 9901, "owner": 1, "kind": "ship", "at": 0, "route": [], "position": origin, "hp": 100.0}]
	ECON._combat(state, graph, 0.1)
	assert(state["ships"][0]["hp"] == 28.0 and state["ships"][1]["hp"] == 100.0)
	ECON._combat(state, graph, 0.1)
	assert(state["ships"][0]["hp"] == 28.0)
	# Existing physical port survives array compaction and can be rebuilt independently.
	var retained: Vector2 = ECON.shipyard_position(state, 0, 1, 0.0)
	p["yards"].remove_at(0)
	assert(ECON.shipyard_at_port(p, 3) == 0 and ECON.shipyard_position(state, 0, 0, 0.0) == retained)
	assert(ECON.shipyard_at_port(p, 1) == -1)
	assert(ECON.enqueue(state, 1, 0, "yard", "port:1"))
	print("PASS: stable station ports, one-time prepaid upgrades, increased repair cap and baseline and upgraded defensive lasers")

func _test_local_avoidance() -> void:
	var craft: Dictionary = {"id": 100, "position": Vector2.ZERO}
	var goal := Vector2(300.0, 0.0)
	ECON._begin_ship_avoidance({100: Vector2.ZERO, 101: Vector2(55.0, 0.0)})
	assert(is_equal_approx(ECON._navigate(craft, goal, 10.0), 10.0))
	assert(absf((craft["position"] as Vector2).y) > 1.0 and (craft["position"] as Vector2).x > 0.0)
	assert(craft["navigation_target"] == goal)
	var initial := Vector2.ZERO
	craft["position"] = initial
	ECON._begin_ship_avoidance({100: initial, 101: Vector2(55.0, 100.0)})
	ECON._navigate(craft, goal, 10.0)
	assert((craft["position"] as Vector2).is_equal_approx(Vector2(10.0, 0.0)))
	craft["position"] = initial
	ECON._begin_ship_avoidance({100: initial, 101: Vector2(20.0, 0.0)})
	ECON._navigate(craft, Vector2(20.0, 0.0), 20.0)
	assert(craft["position"] == Vector2(20.0, 0.0))
	ECON.avoidance_cells.clear()
	print("PASS: forward avoidance, movement budget, unobstructed path and shared endpoint")

func _test_ship_size_classes() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(827, 1), {1: {"team": 1}}, [1], false)
	var p: Dictionary = state["planets"][0]
	for resource in ECON.RESOURCES:
		p["stock"][resource] = 100000.0
	assert(ECON.ship_size("miner") == 1 and ECON.ship_size("fighter") == 1)
	assert(ECON.ship_size("ship") == 2 and ECON.ship_size("colony_ship") == 2 and ECON.ship_size("science_ship") == 3)
	assert(not ECON.enqueue(state, 1, 0, "ship", "", 0))
	assert(not ECON.enqueue(state, 1, 0, "colony_ship"))
	assert(not ECON.set_yard_autobuild(state, 1, 0, 0, "science_ship", true))
	p["yards"][0]["level"] = 2
	assert(ECON.enqueue(state, 1, 0, "ship", "", 0))
	assert(int(p["queue"][-1]["size"]) == 2)
	assert(not ECON.enqueue(state, 1, 0, "science_ship"))
	p["yards"][0]["level"] = 3
	assert(ECON.enqueue(state, 1, 0, "science_ship", "", 0))
	assert(int(p["queue"][-1]["size"]) == 3)
	var source: Dictionary = {"kind": "miner", "cargo": {"Metals": 10.0}}
	var target: Dictionary = {"kind": "ship", "cargo": {"Metals": 20.0}}
	ECON._record_transfer(state, 101, source, 102, target, "Metals", 2.0)
	var event: Dictionary = state["cargo_transfers"]["101:102:Metals"]
	assert(event["from_bay"] == 1 and event["to_bay"] == 2 and event["amount"] == 2.0)
	assert(bytes_to_var(var_to_bytes(state))["cargo_transfers"] == state["cargo_transfers"])
	print("PASS: ship classes, yard authority and cargo transfer metadata")

func _test_passive_health() -> void:
	assert(ECON.ship_max_hp("scout") == 100.0 and ECON.ship_max_hp("fighter") == 200.0)
	assert(ECON.ship_max_hp("miner") == 200.0 and ECON.ship_max_hp("colony_ship") == 200.0 and ECON.ship_max_hp("science_ship") == 200.0)
	assert(ECON.ship_max_hp("cruiser") == 1600.0 and ECON.ship_max_hp("destroyer") == 3200.0)
	assert(ECON.YARD_HP == 3000.0 and ECON.PDS_HP == 300.0)
	var state: Dictionary = ECON.create(_planetary_fixture(827, 1), {1: {"team": 1}}, [1])
	var freighter: Dictionary = {}
	for ship in state["ships"]:
		if ship["kind"] == "ship":
			freighter = ship
	assert(not freighter.is_empty() and freighter["hp"] == 400.0)
	freighter["hp"] = 180.0
	var station: Dictionary = state["planets"][0]["station"]
	station["hp"] = 900.0
	ECON._passive_regeneration(state, 3.0)
	assert(is_equal_approx(float(freighter["hp"]), 181.0) and is_equal_approx(float(station["hp"]), 901.0))
	ECON._passive_regeneration(state, 30000.0)
	assert(freighter["hp"] == 400.0 and station["hp"] == ECON.STATION_HP)
	print("PASS: freighter hull and capped passive regeneration")

func _test_manual_conversion_and_stats() -> void:
	var map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(3000, 0)], "edges": [[0, 1]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}}, [1], false)
	ECON._finish(state, 0, state["planets"][0], {"id": 90001, "kind": "colony_ship", "population_allocated": ECON.COLONY_POPULATION})
	var colony: Dictionary = state["ships"][0]
	colony["position"] = map["points"][1]
	colony["at"] = 1
	colony["dest"] = 1
	colony["unit_order"] = {"kind": "colonize", "target": 1}
	assert(not ECON._work_colony(state, colony, 0.1))
	assert(int(state["planets"][1]["owner"]) == 0)
	ECON._grow_colony_cargo(colony, 1.0)
	assert(is_equal_approx(float(colony["food_produced"]), ECON.COLONY_FARM_RATE))
	assert(not ECON.issue_unit_order(state, 2, [90001], {"kind": "transform"}, false))
	assert(ECON.issue_unit_order(state, 1, [90001], {"kind": "transform"}, false))
	assert(state["ships"].is_empty() and int(state["planets"][1]["owner"]) == 1)
	var source: Dictionary = {"kind": "miner", "cargo": {"Metals": 4.0}}
	var target: Dictionary = {"kind": "ship", "cargo": {"Metals": 0.0}}
	ECON._record_transfer(state, 1, source, 2, target, "Metals", 2.0)
	assert(source["tons_dropped"] == 2.0 and target["tons_picked"] == 2.0)
	var damage: Dictionary = {}
	var killed_by: Dictionary = {}
	ECON._ship_hit(damage, killed_by, {2: 10.0}, 2, source, 10.0)
	assert(killed_by[2] == source)
	print("PASS: manual conversion, lifetime transfer and production counters, lethal hit attribution")

func _test_nearest_colony_and_queued_hold() -> void:
	var map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(2000, 0), Vector2(4000, 0)], "edges": [[0, 1], [1, 2]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}}, [1], false)
	var far: Dictionary = {"id": 100, "owner": 1, "kind": "colony_ship", "at": 0, "origin": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": Vector2.ZERO, "heading": Vector2.UP, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock()}
	var near: Dictionary = far.duplicate(true)
	near.merge({"id": 101, "at": 1, "position": map["points"][1]}, true)
	state["ships"] = [far, near]
	assert(ECON.nearest_idle_colony(state, 1, 2) == 101)
	near["holding"] = true
	assert(ECON.nearest_idle_colony(state, 1, 2) == 100)
	near["holding"] = false
	assert(ECON.send_colony(state, 1, 101, 2))
	assert(ECON.nearest_idle_colony(state, 1, 2) == 100)
	assert(ECON.nearest_idle_colony(state, 2, 2) == -1)
	var point := Vector2(150, 200)
	assert(ECON.issue_unit_order(state, 1, [100], {"kind": "position", "target": 0, "point": point, "move_only": true}, false))
	assert(ECON.issue_unit_order(state, 1, [100], {"kind": "hold"}, true))
	assert(not far.get("holding", false) and far["order_queue"][0]["kind"] == "hold")
	var graph: Dictionary = ECON.military_graph(state)
	for tick in range(300):
		ECON._advance_unit_orders(state, graph)
		ECON._work_local_move(graph, far, 0.1, state)
		if far.get("holding", false):
			break
	assert(far.get("holding", false) and far["position"].is_equal_approx(point))
	assert(not far.has("order_queue"))
	print("PASS: nearest idle colony dispatch and queued hold after movement")

func _test_stop_order() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(827, 1), {1: {"team": 1}}, [1], true)
	var fighter: Dictionary = {}
	for craft in state["ships"]:
		if craft["kind"] == "fighter":
			fighter = craft
			break
	assert(not fighter.is_empty())
	var id: int = int(fighter["id"])
	var point: Vector2 = fighter["position"]
	assert(ECON.command_hold_units(state, 1, [id], false))
	assert(bool(fighter["holding"]))
	fighter["order_queue"] = [{"kind": "sector", "target": 0}]
	assert(not ECON.issue_unit_order(state, 2, [id], {"kind": "stop"}, false))
	assert(ECON.issue_unit_order(state, 1, [id], {"kind": "stop"}, true))
	assert(fighter["order_queue"][-1]["kind"] == "stop")
	assert(bool(fighter["holding"]))
	assert(ECON.issue_unit_order(state, 1, [id], {"kind": "stop"}, false))
	assert(not bool(fighter["holding"]) and not fighter.has("unit_order") and not fighter.has("order_queue"))
	assert(fighter["route"].is_empty() and fighter["position"] == point and fighter["navigation_target"] == point)
	var graph: Dictionary = ECON.military_graph(state)
	var target: Vector2 = graph["points"][0]
	assert(ECON.issue_unit_order(state, 1, [id], {"kind": "position", "target": 0, "point": target, "move_only": true}, false))
	assert(ECON.issue_unit_order(state, 1, [id], {"kind": "position", "target": 0, "point": target, "move_only": false}, true))
	assert(ECON.issue_unit_order(state, 1, [id], {"kind": "stop"}, false))
	assert(not fighter.has("local_move_target") and not fighter.has("order_queue") and not bool(fighter["holding"]))
	print("PASS: Stop cancels Hold, active movement and queued commands")

func _test_combat_sector_presence() -> void:
	var presence: Dictionary = {0: {1: true}, 1: {1: true, 2: true}, 2: {0: true}, 3: {2: true, 3: true}}
	assert(not ECON._combat_sector_has_hostile(presence, 0, 1))
	assert(not ECON._combat_sector_has_hostile(presence, 0, 0))
	assert(not ECON._combat_sector_has_hostile(presence, 2, 1))
	assert(not ECON._combat_sector_has_hostile(presence, -1, 1))
	assert(ECON._combat_sector_has_hostile(presence, 1, 1))
	assert(ECON._combat_sector_has_hostile(presence, 1, 2))
	assert(ECON._combat_sector_has_hostile(presence, 3, 2))
	assert(ECON._combat_sector_has_hostile(presence, 3, 3))
	# Preserve passing-fire behavior: friendly-only move stays move-only,
	# while a hostile in the same sector permits normal pursuit.
	var map_data: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(5000, 0)], "edges": [[0, 1]], "fields": []}
	var state: Dictionary = ECON.create(map_data, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var craft: Dictionary = {"id": 101, "kind": "fighter", "owner": 1, "at": 0, "position": Vector2(20, 0), "heading": Vector2.RIGHT, "route": [1], "leg": 0.0, "dest": 1, "source": -1, "hp": ECON.ship_max_hp("fighter"), "cargo": ECON.empty_stock(), "move_only": true}
	var ally: Dictionary = craft.duplicate(true)
	ally["id"] = 102
	ally["position"] = Vector2(40, 0)
	ally.erase("move_only")
	state["ships"] = [craft, ally]
	var graph: Dictionary = ECON.military_graph(state)
	ECON._combat(state, graph, 0.1)
	assert(bool(craft.get("passing_fire", false)))
	ally["owner"] = 2
	ECON._combat(state, graph, 0.1)
	assert(not bool(craft.get("passing_fire", false)))
	print("PASS: indexed combat sector team presence and move-only behavior")

# Compare the old idle predicate against activity classification for
# representative state transitions, including overlapping orders.
func _legacy_idle_ship(ship: Dictionary) -> bool:
	if ship.get("unit_order", {}).get("kind", "") in ["follow", "guard"] or ship.has("resource_stage") or ECON._salvage_active(ship) or ship.has("local_move_target") or ship.has("launch_rally") or ship.has("patrol_from") or ship.has("attack_order") or ship.has("cargo_order") or ship.has("repair_order") or ship.has("repair_target"):
		return false
	var fighter: bool = ship.get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"]
	var mode: String = str(ship.get("mining_mode", "idle"))
	var waiting_miner: bool = ship.get("kind", "") == "miner" and mode == "delivery" and int(ship.get("dest", -1)) < 0
	return (ship["route"] as Array).is_empty() and (mode == "idle" or waiting_miner) and (fighter or int(ship.get("dest", -1)) < 0) and int(ship.get("source", -1)) < 0 and not ECON._engaged(ship) and not bool(ship.get("retreating", false)) and not bool(ship.get("holding", false))

func _test_ship_activity() -> void:
	var ship: Dictionary = {"kind": "fighter", "route": [], "dest": 0, "source": -1}
	assert(ECON.ship_activity(ship) == ECON.ShipActivity.IDLE)
	var changes: Array = [{"route": [1]}, {"holding": true}, {"retreating": true}, {"combat_target": 12}, {"combat_target": 12, "passing_fire": true}, {"pursuit_target": 12}, {"repair_order": 12}, {"repair_target": 12}, {"cargo_order": {}}, {"resource_stage": {}}, {"salvage_target": 12}, {"salvage_delivery": true}, {"local_move_target": Vector2.ZERO}, {"launch_rally": {}}, {"patrol_from": 0}, {"attack_order": 12}, {"unit_order": {"kind": "follow"}}, {"unit_order": {"kind": "guard"}}, {"source": 0}, {"mining_mode": "mining"}, {"mining_mode": "delivery", "dest": -1}]
	for kind in ECON.SHIP_KINDS:
		ship["kind"] = kind
		for dest in [-1, 0]:
			ship["dest"] = dest
			assert(ECON._is_idle_ship(ship) == _legacy_idle_ship(ship))
			for change in changes:
				var craft: Dictionary = ship.duplicate(true)
				craft.merge(change, true)
				assert(ECON._is_idle_ship(craft) == _legacy_idle_ship(craft))
	assert(ECON.ship_activity({"kind": "miner", "route": [], "mining_mode": "mining"}) == ECON.ShipActivity.MINING)
	print("PASS: derived ship activity and legacy idle parity")

func _test_salvage_center_cache() -> void:
	var map_data: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(5000, 0)], "edges": [[0, 1]], "fields": []}
	var state: Dictionary = ECON.create(map_data, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var graph: Dictionary = ECON.military_graph(state)
	var threats: Dictionary = ECON._salvage_threats(state, graph)
	assert(ECON._salvage_sector_center_safe(state, graph, 1, 0, threats))
	assert(not ECON._salvage_sector_center_safe(state, graph, 1, 1, threats))
	state["planets"][0]["owner"] = 2
	assert(not ECON._salvage_sector_center_safe(state, graph, 1, 0, threats))
	state["planets"][0]["owner"] = 1
	assert(ECON._salvage_sector_center_safe(state, graph, 1, 0, threats))
	var hostile: Dictionary = {"id": 101, "kind": "fighter", "owner": 2, "at": 0, "position": Vector2.ZERO, "route": []}
	state["ships"] = [hostile]
	var fresh: Dictionary = ECON._salvage_threats(state, graph)
	assert(not ECON._salvage_sector_center_safe(state, graph, 1, 0, fresh))
	assert(ECON._salvage_sector_center_safe(state, graph, 1, 0, fresh) == ECON._salvage_safe(state, graph, 1, Vector2.ZERO, 0, fresh))
	state["ships"] = []
	state["planets"][1]["owner"] = 0
	state["fog_of_war"] = false
	var reach: Dictionary = ECON._salvage_threats(state, graph)
	assert(ECON._auto_salvage_sectors(state, graph, 1, 0, reach).has(1))
	state["planets"][1]["owner"] = 2
	assert(not ECON._auto_salvage_sectors(state, graph, 1, 0, reach).has(1))
	state["planets"][1]["owner"] = 0
	assert(ECON._auto_salvage_sectors(state, graph, 1, 0, reach).has(1))
	print("PASS: salvage center threat cache, live ownership and fresh phase invalidation")

func _test_spatial_buckets() -> void:
	var cells: Dictionary = {}
	ECON._spatial_insert(cells, Vector2(-1, 9), 10.0, 1)
	ECON._spatial_insert(cells, Vector2(-9, 0), 10.0, 2)
	ECON._spatial_insert(cells, Vector2(0, 10), 10.0, 3)
	assert(cells[Vector2i(-1, 0)] == [1, 2])
	assert(cells[Vector2i(0, 1)] == [3])
	assert(not ECON._combat_sector_has_hostile({0: {1: true, 0: true}}, 0, 1))
	assert(ECON._combat_sector_has_hostile({0: {1: true, 2: true}}, 0, 1))
	print("PASS: spatial bucket ordering and hostile presence")

func _test_handoff_candidates() -> void:
	var cells: Dictionary = {}
	var radius: float = ECON.RESOURCE_HANDOFF_RANGE
	ECON._spatial_insert(cells, Vector2(radius, 0), radius, [0, {"id": 10}])
	ECON._spatial_insert(cells, Vector2(-1, 0), radius, [1, {"id": 20}])
	ECON._spatial_insert(cells, Vector2(radius * 4, 0), radius, [2, {"id": 30}])
	var candidates: Array = ECON._handoff_candidates(cells, Vector2.ZERO)
	assert(candidates.size() == 2)
	assert(candidates[0]["id"] == 10 and candidates[1]["id"] == 20)

func _test_repair_cells() -> void:
	var radius: float = ECON.MINER_REPAIR_SEARCH
	var targets: Dictionary = {
		10: {"position": Vector2(radius, 0), "entity": {"hp": 1.0}, "max_hp": 10.0},
		20: {"position": Vector2(-radius * 4, 0), "repair_position": Vector2(-1, 0), "entity": {"hp": 1.0}, "max_hp": 10.0},
		30: {"position": Vector2.ZERO, "entity": {"hp": 10.0}, "max_hp": 10.0},
		40: {"position": Vector2(radius * 4, 0), "entity": {"hp": 1.0}, "max_hp": 10.0}}
	assert(ECON._nearby_repair_ids(ECON._damaged_repair_cells(targets), Vector2.ZERO) == [10, 20])

func _test_hostile_buckets() -> void:
	var state: Dictionary = {"teams": {1: 1, 2: 1, 3: 2}}
	var buckets: Dictionary = {Vector2i.ZERO: [{"owner": 1, "id": 4}, {"owner": 3, "id": 8}, {"owner": 2, "id": 6}, {"owner": 3, "id": 2}, {"owner": 0, "id": -2}]}
	var cache: Dictionary = {}
	var hostile: Array = ECON._hostile_bucket(state, buckets, cache, Vector2i.ZERO, 1)
	assert(hostile.map(func(entry: Dictionary) -> int: return int(entry["id"])) == [8, 2, -2])
	assert(ECON._hostile_bucket(state, buckets, cache, Vector2i.ZERO, 2).size() == 3)
	assert(ECON._hostile_bucket(state, buckets, cache, Vector2i.ONE, 1).is_empty())

func _test_laser_blocks() -> void:
	var positions: Dictionary = {}
	var candidates: Array = []
	for id in range(64, 0, -1):
		positions[id] = Vector2(float(id % 8) * 10.0, float(id / 8) * 10.0)
		candidates.append({"id": id})
	var blocks: Array = ECON._laser_blocks(candidates, positions)
	assert(blocks.size() == 4)
	for point in [Vector2.ZERO, Vector2(30, 20), Vector2(100, 100), Vector2(5, 5)]:
		var best: float = ECON.LASER_RANGE * ECON.LASER_RANGE
		var target: int = -1
		for candidate in candidates:
			var id: int = int(candidate["id"])
			var distance: float = point.distance_squared_to(positions[id])
			if distance < best or (is_equal_approx(distance, best) and (target < 0 or id < target)):
				best = distance
				target = id
		assert(ECON._laser_block_nearest(blocks, positions, point, ECON.LASER_RANGE * ECON.LASER_RANGE, -1) == [best, target])

func _test_missile_blocks() -> void:
	var positions: Dictionary = {8: Vector2(10, 0), -2: Vector2(-10, 0), 9: Vector2(100, 0)}
	var candidates: Array = [{"id": 8}, {"id": -2}, {"id": 9}]
	var blocks: Array = ECON._laser_blocks(candidates, positions, true)
	assert(ECON._missile_block_nearest(blocks, positions, Vector2.ZERO, 10000.0, -1, false, -1) == [100.0, -2])
	assert(ECON._missile_block_nearest(blocks, positions, Vector2.ZERO, 10000.0, -1, true, 8) == [100.0, 8])
	assert(ECON._missile_block_nearest(blocks, positions, Vector2.ZERO, 99.0, -1, false, -1) == [99.0, -1])

func _test_pursuit_blocks() -> void:
	var positions: Dictionary = {}
	var candidates: Array = []
	for id in range(48, 0, -1):
		positions[id] = Vector2(float(id) * 1000.0, 0)
		candidates.append({"id": id})
	var blocks: Array = ECON._laser_blocks(candidates, positions)
	assert(ECON._laser_block_nearest(blocks, positions, Vector2(1500, 0), INF, -1) == [250000.0, 1])
	assert(ECON._laser_block_nearest(blocks, positions, Vector2(48000, 0), INF, -1) == [0.0, 48])
	assert(ECON._laser_block_nearest([], positions, Vector2.ZERO, INF, -1)[1] == -1)

func _test_search_slots() -> void:
	var slots: Dictionary = {}
	for id in range(5):
		var next: float = ECON._next_search_slot(10.0, id, 0.5)
		assert(next > 10.0 and next <= 10.5 + ECON.EPS)
		slots[roundi(next * 10.0)] = true
		assert(is_equal_approx(ECON._next_search_slot(next, id, 0.5), next + 0.5))
	assert(slots.size() == 5)

func _test_repair_retry_due() -> void:
	var ship: Dictionary = {}
	assert(ECON._repair_retry_due(ship, 0.0))
	ship["_next_repair_search"] = 1.5
	assert(not ECON._repair_retry_due(ship, 1.2))
	assert(ECON._repair_retry_due(ship, 1.5))

func _test_combat_search_due() -> void:
	var ship: Dictionary = {"_next_combat_search": 1.2}
	assert(not ECON._combat_search_due(ship, 1.1))
	assert(ECON._combat_search_due(ship, 1.2))
	for key in ["attack_order", "combat_target", "pursuit_target", "yard_target"]:
		ship[key] = -2 if key == "yard_target" else 10
		assert(ECON._combat_search_due(ship, 1.1))
		ship.erase(key)

func _test_reusable_laser_target() -> void:
	var state: Dictionary = {"teams": {1: 1, 2: 2}}
	var ship: Dictionary = {"owner": 1, "combat_target": 8, "_next_laser_refresh": 1.2}
	var by_id: Dictionary = {8: {"owner": 2}}
	var positions: Dictionary = {8: Vector2(10, 0)}
	assert(ECON._reusable_laser_target(state, ship, by_id, positions, Vector2.ZERO, 1.1) == 8)
	assert(ECON._reusable_laser_target(state, ship, by_id, positions, Vector2.ZERO, 1.2) == -1)
	assert(ECON._reusable_laser_target(state, ship, {}, positions, Vector2.ZERO, 1.1) == -1)
	assert(ECON._reusable_laser_target(state, ship, by_id, positions, Vector2(ECON.LASER_RANGE * 3, 0), 1.1) == -1)
	ship["attack_order"] = 8
	assert(ECON._reusable_laser_target(state, ship, by_id, positions, Vector2.ZERO, 1.1) == -1)

func _test_contact_bucket_bounds() -> void:
	var bounds := Rect2(Vector2(10, 10), Vector2(10, 10))
	assert(ECON._contact_bucket_near(Vector2(15, 15), bounds, 25.0))
	assert(ECON._contact_bucket_near(Vector2(5, 10), bounds, 25.0))
	assert(not ECON._contact_bucket_near(Vector2.ZERO, bounds, 25.0))
	assert(ECON._contact_bucket_near(Vector2(-10, -10), Rect2(Vector2(-10, -10), Vector2.ZERO), 25.0))

func _test_ai_slots() -> void:
	var slots: Dictionary = {}
	for player in range(1, 9):
		var next: float = ECON._next_ai_slot(4.0, player)
		assert(next > 4.0 and next <= 4.0 + ECON.AI_INTERVAL)
		slots[next] = true
		assert(is_equal_approx(ECON._next_ai_slot(next, player), next + ECON.AI_INTERVAL))
	assert(slots.size() == 8)

func _test_sector_inner_fast_path() -> void:
	var graph: Dictionary = {"points": [Vector2.ZERO, Vector2(100, 0)], "sector_radii": [100.0, 100.0], "sector_neighbors": [[Vector2(100, 0)], [Vector2(-100, 0)]]}
	var baseline: Dictionary = graph.duplicate(true)
	ECON._index_sector_bounds(graph, 100.0)
	for node in range(2):
		for x in range(-100, 201, 5):
			for y in range(-100, 101, 5):
				var point := Vector2(x, y)
				assert(ECON.sector_contains(graph, node, point) == ECON.sector_contains(baseline, node, point))

func _test_sector_query_cache() -> void:
	var graph: Dictionary = {"points": [Vector2.ZERO, Vector2(100, 0)], "sector_radii": [100.0, 100.0], "sector_neighbors": [[Vector2(100, 0)], [Vector2(-100, 0)]]}
	ECON._sector_query_graph = graph
	ECON._sector_query_cache.clear()
	assert(ECON.sector_contains(graph, 0, Vector2.ZERO))
	assert(ECON.sector_contains(graph, 0, Vector2.ZERO))
	assert(ECON._sector_query_cache.size() == 1)
	assert(not ECON.sector_contains(graph, 0, Vector2(100, 0)))
	assert(ECON.sector_contains(graph, 1, Vector2(100, 0)))
	assert(ECON._sector_query_cache.size() == 3)
	var other: Dictionary = graph.duplicate(true)
	other["sector_radii"][0] = 1.0
	assert(not ECON.sector_contains(other, 0, Vector2(10, 0)))
	assert(ECON._sector_query_cache.size() == 3)
	ECON._sector_query_graph = {}
	ECON._sector_query_cache.clear()

func _test_shared_threat_index() -> void:
	var graph: Dictionary = {"points": [Vector2.ZERO, Vector2(1000, 0)], "sector_radii": [200.0, 200.0], "sector_neighbors": [[], []]}
	var ship: Dictionary = {"id": 1, "kind": "fighter", "owner": 1, "position": Vector2.ZERO, "at": 0, "route": []}
	var state: Dictionary = {"ships": [ship], "teams": {1: 1}}
	var index: Dictionary = {1: [ECON._threat_sector_signature(ship), 0]}
	assert(ECON._salvage_threats(state, graph, index) == ECON._salvage_threats(state, graph))
	ship["position"] = Vector2(1000, 0)
	ship["at"] = 1
	assert(ECON._salvage_threats(state, graph, index) == ECON._salvage_threats(state, graph))
	state["ships"].clear()
	assert(ECON._salvage_threats(state, graph, index) ["ids"].is_empty())

func _test_reuse_combat_threats() -> void:
	var graph: Dictionary = {"points": [Vector2.ZERO, Vector2(1000, 0)], "sector_radii": [200.0, 200.0], "sector_neighbors": [[], []]}
	var ship: Dictionary = {"id": 1, "kind": "fighter", "owner": 1, "position": Vector2.ZERO, "at": 0, "route": []}
	var state: Dictionary = {"ships": [ship], "teams": {1: 1}}
	var snapshot: Dictionary = ECON._salvage_threats(state, graph)
	var index: Dictionary = {1: [ECON._threat_sector_signature(ship), 0, 1], "snapshot": snapshot, "count": 1}
	assert(is_same(ECON._reuse_combat_threats(state, graph, index), snapshot))
	state["teams"][1] = 2
	assert(ECON._reuse_combat_threats(state, graph, index) == ECON._salvage_threats(state, graph))
	ship["position"] = Vector2(1000, 0)
	ship["at"] = 1
	assert(ECON._reuse_combat_threats(state, graph, index) == ECON._salvage_threats(state, graph))
	state["ships"].clear()
	assert(ECON._reuse_combat_threats(state, graph, index) ["ids"].is_empty())

func _test_indexed_hostile_bucket() -> void:
	var state: Dictionary = {"teams": {1: 1, 2: 2}}
	var buckets: Dictionary = {0: [{"id": 1, "owner": 1}, {"id": 2, "owner": 2}, {"id": -2, "owner": 2}, {"id": 3, "owner": 0}]}
	var teams: Dictionary = {1: 1, 2: 2, -2: 2, 3: 0}
	for team in range(3):
		assert(ECON._hostile_bucket(state, buckets, {}, 0, team, teams) == ECON._hostile_bucket(state, buckets, {}, 0, team))
		assert(ECON._hostile_bucket(state, buckets, {}, 0, team, teams, true) == ECON._hostile_bucket(state, buckets, {}, 0, team, teams).filter(func(enemy: Dictionary) -> bool: return int(teams[enemy["id"]]) > 0))

func _test_packed_threat_records() -> void:
	var radius: float = ECON.REPAIR_SAFE_RADIUS
	var legacy: Dictionary = {"sectors": {}, "cells": {}}
	var packed: Dictionary = {"sectors": {}, "cells": {}, "positions": PackedVector2Array([Vector2.ZERO, Vector2(-radius, 0)]), "teams": PackedInt32Array([1, 2]), "ids": PackedInt64Array([10, 20])}
	ECON._spatial_insert(legacy["cells"], Vector2.ZERO, radius, [1, Vector2.ZERO])
	ECON._spatial_insert(legacy["cells"], Vector2(-radius, 0), radius, [2, Vector2(-radius, 0)])
	ECON._spatial_insert(packed["cells"], Vector2.ZERO, radius, 0)
	ECON._spatial_insert(packed["cells"], Vector2(-radius, 0), radius, 1)
	for team in range(3):
		for point in [Vector2.ZERO, Vector2(-radius, 0), Vector2(radius, 0), Vector2(radius * 3, 0)]:
			assert(ECON._salvage_threat_free(point, -1, team, packed) == ECON._salvage_threat_free(point, -1, team, legacy))

func _test_empire_targets() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(426), {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	assert(not ECON.set_empire_target(state, 999, "fighter", 5))
	assert(not ECON.set_empire_target(state, 1, "fighter", 4))
	assert(not ECON.set_empire_target(state, 1, "fighter", 750))
	assert(ECON.set_empire_target(state, 1, "fighter", 500))
	assert(ECON.set_empire_target(state, 1, "fighter", 5))
	var p: Dictionary = state["planets"][0]
	p["population"] = 100000.0
	for resource in ECON.RESOURCES:
		p["stock"][resource] = 10000.0
	ECON._refill_empire_fleets(state)
	var counts: Dictionary = ECON.empire_fleet_counts(state, 1)
	assert(int(counts["live"].get("fighter", 0)) + int(counts["queued"].get("fighter", 0)) <= 5)
	assert(ECON.set_empire_target(state, 1, "fighter", 0))

func _test_objective_holdings() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(426), {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	state["ships"] = [{"owner": 1, "crew": 1000.0, "cargo": {"Metals": 100.0}}, {"owner": 2, "crew": 999999.0, "cargo": {"Metals": 100000.0}}]
	var home: Dictionary = state["planets"][0]
	home["population"] = 79000.0
	home["stock"]["Metals"] = 2900.0
	var progress: Dictionary = ECON.objective_progress(state, 1)
	assert(ECON.active_objectives(progress, 0.0).size() == 2)
	assert(progress["active_goals"]["economic"] == "colony_ships")
	progress["colony_ships_built"] = 2
	ECON._update_objectives(state)
	assert(progress["completed"].has("colony_ships") and ECON.reward_points(progress, "economic") == 2)
	assert(float(progress["population"]) == 80000.0 and float(progress["metals"]) == 3000.0)
	assert(not progress["completed"].has("population") and not progress["completed"].has("metals"))
	assert(not ECON.refresh_objective(state, 1, "economic", "colony_ships"))
	state["objective_clock"] = 11.0
	ECON._update_objectives(state)
	assert(progress["active_goals"]["economic"] == "colonies")
	assert(ECON.objective_category("colonies") == "economic")
	assert(ECON.refresh_objective(state, 1, "economic", "colonies"))
	var rerolled: String = progress["active_goals"]["economic"]
	assert(rerolled != "colonies" and ECON.objective_category(rerolled) == "economic")
	assert(not ECON.refresh_objective(state, 1, "economic", rerolled))
	assert(ECON.refresh_objective(state, 1, "military", "military_built"))
	assert(ECON.objective_refresh_remaining(progress, "economic", 11.0) == 60.0)
	assert(not ECON.refresh_objective(state, 99, "economic", rerolled))
	assert(not ECON.refresh_objective(state, 1, "tech", "advanced_antimatter"))
	state["objective_clock"] = 71.0
	assert(ECON.refresh_objective(state, 1, "economic", rerolled))
	progress["active_goals"]["economic"] = "metals"
	assert(int(ECON.OBJECTIVE_SPECS["metals"][2]) > int(ECON.STARTING_STOCK["Metals"]))
	home["stock"]["Metals"] = 2899.0
	ECON._update_objectives(state)
	assert(not progress["completed"].has("metals"))
	home["stock"]["Metals"] = 2900.0
	ECON._update_objectives(state)
	assert(progress["completed"].has("metals"))
	home["stock"]["Metals"] = 100.0
	ECON._update_objectives(state)
	assert(float(progress["metals"]) == 200.0 and progress["completed"].has("metals"))
	progress["active_goals"]["economic"] = "population"
	home["population"] = 78999.0
	ECON._update_objectives(state)
	assert(not progress["completed"].has("population"))
	home["population"] = 79000.0
	ECON._update_objectives(state)
	assert(progress["completed"].has("population"))
	assert(ECON.OBJECTIVE_SPECS["population_2"][2] == 200000)
	progress["active_goals"]["economic"] = "colony_food"
	progress["colony_food"] = 1000.0
	ECON._update_objectives(state)
	assert(progress["completed"].has("colony_food"))
	assert(ECON.objective_tech_unlocked(progress))
	print("PASS: one objective per category, colony prerequisites, current holdings, lifetime food, separate rerolls and cooldowns")

func _test_reward_redraft() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(426), {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var progress: Dictionary = ECON.objective_progress(state, 1)
	progress["points"]["economic"] = 2
	progress["points"]["military"] = 1
	ECON._fill_reward_offer(state, 1, "economic")
	ECON._fill_reward_offer(state, 1, "military")
	var previous: Array = ECON.reward_offer(progress, "economic").duplicate()
	assert(previous.size() == 3)
	var chosen: String = previous[0]
	assert(not ECON.acquire_reward(state, 1, chosen, 0, "tech"))
	assert(ECON.acquire_reward(state, 1, chosen, 0, "economic"))
	assert(ECON.reward_points(progress, "economic") == 1 and ECON.reward_points(progress, "military") == 1)
	assert(not ECON.reward_offer(progress, "economic").has(chosen))
	assert(not ECON.reward_offer(progress, "military").has(chosen))
	assert(not ECON.acquire_reward(state, 1, str(previous[1]), 0, "economic"))
	assert(ECON.acquire_reward(state, 1, str(ECON.reward_offer(progress, "economic")[0]), 1, "economic"))
	assert(ECON.reward_points(progress, "economic") == 0 and ECON.reward_offer(progress, "economic").is_empty())
	assert(not ECON.reward_eligible([], "shield_2", "military"))
	assert(ECON.reward_eligible(["shield_1"], "shield_2", "military"))
	assert(not ECON.reward_eligible(["shield_1"], "shield_3", "military"))
	assert(not ECON.reward_eligible([], "shield_1", "economic"))
	assert(ECON.objective_progress(state, 2).get("rewards", []).is_empty())
	var hull: Dictionary = {"hp": 100.0}
	ECON._update_shield(hull, 30.0, 0.0, 0.0)
	ECON._apply_reward_damage(hull, 100.0, 40.0, 1.0)
	assert(hull["shield"] == 0.0 and hull["hp"] == 90.0)
	ECON._update_shield(hull, 30.0, 5.9, 1.0)
	assert(hull["shield"] == 0.0)
	ECON._update_shield(hull, 30.0, 6.0, 1.0)
	assert(hull["shield"] == 6.0)
	hull["armor"] = 0.15
	ECON._apply_reward_damage(hull, 100.0, 16.0, 6.0)
	assert(is_equal_approx(float(hull["hp"]), 81.5))
	var price: Dictionary = ECON.construction_cost({"conquest_rewards": ["shield_1", "shield_2", "armor"]}, "fighter", 1)
	assert(price["Crystals"] == 135.0 and price["Metals"] == 311.0)
	print("PASS: categorized conquest rewards, stale drafts, hidden zero-balance offers, shield absorption/recharge and armor costs")

func _test_unique_rewards() -> void:
	for key in ECON.UNIQUE_CONQUEST_REWARDS:
		var state: Dictionary = ECON.create(_planetary_fixture(426), {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
		var category: String = ECON.CONQUEST_REWARDS[key][3]
		var first: Dictionary = ECON.objective_progress(state, 1)
		var rival: Dictionary = ECON.objective_progress(state, 2)
		var prerequisite: Array = ["shield_1", "shield_2"] if key == "shield_3" else []
		for progress in [first, rival]:
			progress["rewards"] = prerequisite.duplicate()
			progress["points"][category] = 1
			progress["offers"][category] = [key, "population"]
		var old_generation: int = ECON.reward_generation(rival)
		assert(ECON.reward_available(state, key))
		assert(ECON.acquire_reward(state, 1, key, ECON.reward_generation(first), category))
		assert(state["unique_reward_claims"][key] == 1)
		assert(not ECON.reward_available(state, key))
		assert(not ECON.reward_offer(rival, category).has(key))
		assert(ECON.reward_points(rival, category) == 1)
		assert(ECON.reward_generation(rival) > old_generation)
		assert(not ECON.acquire_reward(state, 2, key, old_generation, category))
		assert(not ECON.acquire_reward(state, 2, "population", old_generation, category))
		# Even forged offers and fresh generations cannot override the claim.
		rival["offers"][category] = [key]
		assert(not ECON.acquire_reward(state, 2, key, ECON.reward_generation(rival), category))
		rival["offers"][category] = []
		ECON._fill_reward_offer(state, 2, category)
		assert(not ECON.reward_offer(rival, category).has(key))
		assert(ECON.acquire_reward(state, 2, str(ECON.reward_offer(rival, category)[0]), ECON.reward_generation(rival), category))
		assert(ECON.reward_points(rival, category) == 0)
		# A defeated empire cannot make its unique reward available again.
		state["eliminated"] = [1]
		assert(not ECON.reward_available(state, key))
	assert(not ECON.reward_is_unique("shield_1") and not ECON.reward_is_unique("shield_2"))
	print("PASS: exclusive conquest claims, rival refresh, stale clicks, retained points and permanent reservation")

func _test_warp_gates() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(426), {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var graph: Dictionary = ECON.military_graph(state)
	var home: Dictionary = state["planets"][0]
	var other_node: int = 2
	state["planets"][other_node]["owner"] = 1
	state["planets"][other_node]["station"] = {"hp": ECON.STATION_HP}
	var a: Dictionary = {"id": 980001, "owner": 1, "kind": "science_ship", "at": 0, "position": graph["points"][0], "cargo": {ECON.ANTIMATTER: 1.0}}
	var b: Dictionary = {"id": 980002, "owner": 1, "kind": "science_ship", "at": other_node, "position": graph["points"][other_node], "cargo": {ECON.ANTIMATTER: 1.0}}
	state["ships"].append(a)
	state["ships"].append(b)
	assert(not ECON.can_build_warp_gate(state, graph, a))
	ECON.objective_progress(state, 1)["rewards"] = ["warp_gate"]
	assert(ECON.build_warp_gate(state, graph, a))
	assert(ECON.build_warp_gate(state, graph, b))
	assert(a["warp_destination"] == b["id"] and b["warp_destination"] == a["id"])
	assert(ECON._cargo_total(a) == 0.0 and a["hp"] == ECON.WARP_GATE_HP)
	assert(not ECON.set_warp_destination(state, 2, int(a["id"]), int(b["id"])))
	assert(not ECON.issue_unit_order(state, 1, [a["id"]], {"kind": "stop"}, false))
	var traveler: Dictionary = state["ships"][0]
	traveler["position"] = a["position"]
	traveler["unit_order"] = {"kind": "warp_travel", "target": a["id"]}
	assert(ECON._work_warp_order(state, graph, traveler, 0.1))
	assert(traveler["at"] == other_node and (traveler["position"] as Vector2).distance_to(b["position"]) <= 60.1)
	ECON._remove_indexed_hull(state, b)
	assert(a["warp_destination"] == -1)
	print("PASS: warp gate deployment, consumption, ownership, linking, travel and destruction")

func _test_cloaking() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(829), {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	ECON.objective_progress(state, 1)["rewards"] = ["shield_1", "armor", "cloak"]
	var scout: Dictionary = {"id": 989901, "kind": "scout", "owner": 1, "position": Vector2.ZERO, "hp": ECON.ship_max_hp("scout")}
	var enemy: Dictionary = {"id": 989902, "kind": "fighter", "owner": 2, "position": Vector2(200.0, 0.0)}
	state["ships"] = [scout, enemy]
	ECON._refresh_reward_defenses(state, 0.0)
	assert(bool(scout["cloaked"]) and not scout.has("shield_max") and not scout.has("armor"))
	var positions: Dictionary = {scout["id"]: scout["position"], enemy["id"]: enemy["position"]}
	var teams: Dictionary = {scout["id"]: 1, enemy["id"]: 2}
	var cells: Dictionary = {}
	ECON._spatial_insert(cells, scout["position"], ECON.LASER_RANGE, scout)
	ECON._spatial_insert(cells, enemy["position"], ECON.LASER_RANGE, enemy)
	ECON._detect_cloaked(state, state["ships"], cells, positions, teams)
	assert(ECON.ship_visible_to_team(state, scout, 2))
	enemy["position"] = Vector2(600.0, 0.0)
	positions[enemy["id"]] = enemy["position"]
	cells.clear()
	ECON._spatial_insert(cells, scout["position"], ECON.LASER_RANGE, scout)
	ECON._spatial_insert(cells, enemy["position"], ECON.LASER_RANGE, enemy)
	ECON._detect_cloaked(state, state["ships"], cells, positions, teams)
	assert(not ECON.ship_visible_to_team(state, scout, 2) and ECON.ship_visible_to_team(state, scout, 1))
	assert(not ECON._hostile_hull(state, 2, scout))
	ECON._fire_blaster(state, scout, int(enemy["id"]), positions, {}, {}, {enemy["id"]: 100.0}, 0.1)
	assert(float(scout["cloak_reveal_until"]) > float(state["elapsed"]))
	ECON._refresh_reward_defenses(state, 0.0)
	assert(not bool(scout["cloaked"]))
	print("PASS: cloak detection, attack reveal and exclusive scout defenses")

func _test_station_crystals() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(827, 1, "Grid"), {1: {"team": 1}}, [1], false)
	var home: Dictionary = state["planets"][0]
	home["levels"]["Crystals"] = 0
	assert(ECON.rate(home, "Crystals") == 1.0)
	ECON._work_planet(state, 0, 3.0)
	assert(is_equal_approx(float(home["stock"]["Crystals"]), 3.0))
	home["levels"]["Crystals"] = 1
	var expected: float = 1.0 + 0.04 * ECON.production_modifier(home, "Crystals") * ECON.population_multiplier(home)
	assert(is_equal_approx(ECON.rate(home, "Crystals"), expected))
	home["planet_blockaded"] = true
	assert(ECON.rate(home, "Crystals") == 1.0)
	home["planetless"] = true
	assert(ECON.rate(home, "Crystals") == 1.0)
	home["station"] = {}
	home["owner"] = 0
	assert(ECON.rate(home, "Crystals") == 0.0)
	assert(ECON._cost("cruiser", 1)["Crystals"] == 400.0)
	assert(ECON._cost("laser_matrix", 1)["Crystals"] == 4000.0)
	assert(ECON.construction_cost({"conquest_rewards": ["cloak"]}, "scout", 1)["Crystals"] == 45.0)
	print("PASS: station baseline, planetary crystal rate, blockade and increased construction costs")

func _test_sfx_rules() -> void:
	var mixer = preload("res://scripts/match_sfx.gd")
	assert(mixer.spatial_gain(0.0, 1000.0, 8.0) > mixer.spatial_gain(800.0, 1000.0, 8.0))
	assert(mixer.spatial_gain(0.0, 1000.0, 8.0) > mixer.spatial_gain(0.0, 1000.0, 1.0))
	assert(mixer.spatial_gain(1800.0, 1000.0, 8.0) == 0.0)
	var instance = mixer.new()
	for i in range(100):
		instance.offer("laser", float(i) / 100.0)
	assert(instance.candidates["laser"].size() == 4)
	assert(instance.candidates["laser"].min() >= 0.96)
	var wav: AudioStreamWAV = instance._synthesize("laser", 0)
	assert(wav.data.size() > 0 and wav.mix_rate == 22050)
	instance.free()
	print("PASS: SFX attenuation, bounded loudest candidates and PCM generation")

func _initialize() -> void:
	_test_sfx_rules()
	_test_station_crystals()
	_test_cloaking()
	_test_warp_gates()
	_test_reward_redraft()
	_test_unique_rewards()
	_test_objective_holdings()
	_test_empire_targets()
	_test_packed_threat_records()
	_test_indexed_hostile_bucket()
	_test_reuse_combat_threats()
	_test_shared_threat_index()
	_test_sector_query_cache()
	_test_sector_inner_fast_path()
	_test_ai_slots()
	_test_contact_bucket_bounds()
	_test_reusable_laser_target()
	_test_combat_search_due()
	_test_repair_retry_due()
	_test_search_slots()
	_test_pursuit_blocks()
	_test_missile_blocks()
	_test_laser_blocks()
	_test_hostile_buckets()
	_test_repair_cells()
	_test_handoff_candidates()
	_test_spatial_buckets()
	_test_salvage_center_cache()
	_test_ship_activity()
	_test_combat_sector_presence()
	_test_stop_order()
	_test_nearest_colony_and_queued_hold()
	_test_manual_conversion_and_stats()
	_test_passive_health()
	_test_ship_size_classes()
	_test_local_avoidance()
	_test_station_defense_and_ports()
	_test_station_construction_queue()
	_test_ai_timed_orbital_housing()
	_test_ai_capital_fleets()
	_test_miner_service_orders()
	_test_repair_pauses_wander()
	_test_mining_lasers()
	_test_yard_autobuild_and_station_approach()
	_test_population_queue_priority()
	_test_unit_order_queue()
	_test_sector_entry_orders()
	_test_gap_position_orders()
	_test_autocast_modes()
	_test_resource_handoff()
	_test_follow_order()
	_test_blaster_bursts()
	_test_conquest()
	_test_territory_influence()
	_test_conquest_resistance_and_evacuation()
	_test_soft_separation()
	_test_explicit_hold_pose()
	_test_rounded_sector_limits()
	_test_hull_index()
	_test_shipyard_rally()
	_test_freighter_bays()
	_test_crowded_dock_delivery()
	_test_recovery_economy()
	_test_opening_pacing()
	_test_neutral_direct_occupation()
	_test_idle_formations()
	_test_local_position_orders()
	_test_tactical_orders()
	_test_precise_patrol()
	_test_salvage()
	_test_opportunistic_salvage()
	_test_remote_salvage()
	_test_colony_farm()
	_test_civilian_waiting_movement()
	_test_depleted_field_routes()
	_test_wide_patrol_rally_and_conquest()
	_test_ai_defensive_orders()
	_test_match_elimination()
	_test_radial_nearest_ports()
	_test_map_layouts()
	_test_orbital_housing()
	_test_eco_regrowth()
	_test_antimatter_extraction()
	assert(is_equal_approx(ECON.habitation_capacity({"size_factor": 1.0}), 500000.0))
	assert(is_equal_approx(ECON.habitation_capacity({"size_factor": 1.5, "habitation_level": 1}), 1500000.0))
	var bounds: Dictionary = ECON.create(_planetary_fixture(827, 1, "Grid"), {1: {"team": 1}}, [1])
	var world: Dictionary = bounds["planets"][0]
	world["abundance"]["Metals"] = 0.1
	assert(is_equal_approx(ECON.production_modifier(world, "Metals"), 0.1))
	assert(ECON.rate(world, "Metals") > 0.0)
	world["abundance"]["Metals"] = 10.0
	assert(is_equal_approx(ECON.production_modifier(world, "Metals"), 4.0))
	_test_maintain_targets()
	var graph: Dictionary = _planetary_fixture(2468, 3, "Grid")
	assert(graph == _planetary_fixture(2468, 3, "Grid"))
	assert(graph != _planetary_fixture(2469, 3, "Grid"))
	var all_friendly: Array[int] = []
	all_friendly.resize(graph["points"].size())
	all_friendly.fill(1)
	for i in range(graph["points"].size()):
		assert(not MAP.path(graph, all_friendly, 1, 0, i).is_empty())
	# Seeded clusters are internally connected and connected by sparse bridges.
	var crystal_shares: Dictionary = {}
	for seed_value in range(24):
		var player_count: int = seed_value % 8 + 1
		var clustered: Dictionary = _planetary_fixture(seed_value, player_count, "Grid")
		var cluster_ids: Array = clustered["clusters"]
		var cluster_points: Array = clustered["points"]
		var local_distance: float = 0.0
		var bridge_distance: float = 0.0
		var locals: int = 0
		var bridges: int = 0
		var longest: float = 0.0
		var degrees: Array[int] = []
		degrees.resize(cluster_points.size())
		degrees.fill(0)
		for edge in clustered["edges"]:
			var length: float = cluster_points[edge[0]].distance_to(cluster_points[edge[1]])
			longest = maxf(longest, length)
			degrees[edge[0]] += 1
			degrees[edge[1]] += 1
			if cluster_ids[edge[0]] >= 0 and cluster_ids[edge[0]] == cluster_ids[edge[1]]:
				locals += 1
				local_distance += length
			else:
				bridges += 1
				bridge_distance += length
		assert(bridges >= MAP.cluster_count_for(player_count, "Grid") - 1 + cluster_ids.count(-1))
		assert(clustered["cluster_sizes"].size() == MAP.cluster_count_for(player_count, "Grid"))
		assert(cluster_points.size() <= player_count * MAP.SYSTEMS_PER_PLAYER)
		for cluster_size in clustered["cluster_sizes"]:
			assert(cluster_size >= 2 and cluster_size <= 4)
		assert(clustered["edges"].size() >= cluster_points.size() - 1)
		assert(clustered["edges"].size() >= cluster_points.size()) # square cells create alternate routes
		assert(degrees.count(3) <= int(clustered["max_junctions"]))
		for degree in degrees:
			assert(degree >= 1 and degree <= MAP.MAX_CONNECTIONS)
		for home in range(player_count):
			assert(clustered["cluster_sizes"][cluster_ids[home]] >= 2)
			var neutral_neighbor: bool = false
			for i in range(player_count, cluster_points.size()):
				if MAP.linked(clustered, home, i):
					neutral_neighbor = true
					break
			assert(neutral_neighbor)
		assert(is_equal_approx(longest / ECON.SHIP_SPEED, MAP.LONGEST_LINK_YEARS))
		assert(not (clustered["fields"] as Array).is_empty())
		for edge in clustered["edges"]:
			assert(not MAP.blocked(cluster_points[edge[0]], cluster_points[edge[1]], clustered["fields"]))
		for field in clustered["fields"]:
			var ore: Dictionary = ECON.field_inventory(field)
			if not bool(field.get("antimatter", false)):
				var total: float = float(ore["Metals"]) + float(ore["Crystals"])
				var crystal_share: float = float(ore["Crystals"]) / total
				assert(total >= field["chunks"].size() * 900.0 and total <= field["chunks"].size() * 5200.0)
				assert(crystal_share <= MAP.MAX_CRYSTAL_SHARE + ECON.EPS and float(ore["Metals"]) > 0.0)
				crystal_shares[roundi(crystal_share * 100.0)] = true
			for resource in ECON.FIELD_RESOURCES:
				assert(ECON.field_limit(field, resource) > ECON.PLANET_MINING_LIMIT if float(ore[resource]) > 0.0 else is_zero_approx(ECON.field_limit(field, resource)))
			assert(ECON.field_limit(field, "Organics") == 0.0)
			assert(field["outline"].size() == 12)
			assert(field["chunks"].size() >= 9)
			var chunk_ids: Dictionary = {}
			for chunk in field["chunks"]:
				assert(not chunk_ids.has(chunk["id"]))
				chunk_ids[chunk["id"]] = true
				assert(ECON.FIELD_RESOURCES.has(chunk["resource"]))
				assert((chunk["resource"] == ECON.ANTIMATTER) == bool(field.get("antimatter", false)))
				assert(float(chunk["remaining"]) > 0.0)
				assert((field["position"] as Vector2).distance_to(chunk["position"]) + float(chunk["radius"]) < float(field["radius"]))
		assert(bridge_distance / (bridges - cluster_ids.count(-1)) >= local_distance / locals - 0.01)
		var seen: Dictionary = {0: true}
		var frontier: Array = [0]
		while not frontier.is_empty():
			var current: int = frontier.pop_back()
			for edge in clustered["edges"]:
				var next: int = -1
				if edge[0] == current:
					next = edge[1]
				elif edge[1] == current:
					next = edge[0]
				if next >= 0 and not seen.has(next):
					seen[next] = true
					frontier.append(next)
		assert(seen.size() == cluster_points.size())
		for i in range(player_count):
			assert(cluster_ids[i] == i)
	assert(crystal_shares.has(0) and crystal_shares.size() >= 5)
	print("PASS: tenfold asteroid inventory, seeded metal-rich fields and crystal tonnage cap")
	var players: Dictionary = {1: {"team": 1}, 2: {"team": 1}, 3: {"team": 2}}
	var ids: Array[int] = [1, 2, 3]
	var state: Dictionary = ECON.create(graph, players, ids, false)
	assert(not state["fog_of_war"])
	for i in range((state["planets"] as Array).size()):
		assert(ECON.discovered(state, 1, "planets", i))
		assert(ECON.discovered(state, 3, "planets", i))
	state["fog_of_war"] = true
	assert(ECON.discovered(state, 1, "planets", 0))
	assert(ECON.discovered(state, 2, "planets", 0))
	assert(not ECON.discovered(state, 3, "planets", 0) or MAP.linked(graph, 0, 2))
	state["fog_of_war"] = false
	var p: Dictionary = state["planets"][0]
	assert(p["yards"].size() == 1)
	assert(ECON.RESOURCES == ["Metals", "Organics", "Crystals"])
	assert(p["levels"].size() == 3)
	assert(p["stock"].size() == 3)
	assert(p["thresholds"].size() == 3)
	for system in state["planets"]:
		for resource in ECON.RESOURCES:
			assert(is_equal_approx(float(system["thresholds"][resource]["min"]), 50.0))
			assert(is_equal_approx(float(system["thresholds"][resource]["max"]), 80.0))
	var default_test: Dictionary = p.duplicate(true)
	default_test["stock"]["Metals"] = 900.0
	assert(is_equal_approx(ECON._need(default_test, "Metals"), 100.0))
	default_test["stock"]["Metals"] = 1000.0
	assert(is_zero_approx(ECON._need(default_test, "Metals")))
	default_test["stock"]["Metals"] = 1600.0
	assert(is_zero_approx(ECON._surplus(default_test, "Metals")))
	default_test["stock"]["Metals"] = 1700.0
	assert(is_equal_approx(ECON._surplus(default_test, "Metals"), 100.0))
	for removed in ["Plastics", "Textiles", "Tech"]:
		assert(not p["stock"].has(removed) and not p["levels"].has(removed))
		assert(not p["abundance"].has(removed) and not p["bonuses"].has(removed))
		assert(not ECON.set_thresholds(state, 1, 0, removed, 10, 20))
		assert(not ECON.enqueue(state, 1, 0, "economy", removed))
		assert(not ECON.enqueue(state, 1, 0, "production", removed))
	assert(not ECON.enqueue(state, 2, 0, "ship"))
	assert(not ECON.set_thresholds(state, 1, 0, "Metals", 200, 100))
	assert(not ECON.set_thresholds(state, 1, 0, "Metals", 0, 101))
	assert(not ECON.set_thresholds(state, 1, 0, "Metals", 80, 20))
	assert(ECON.set_thresholds(state, 1, 0, "Metals", 10, 20))
	var trade_test: Dictionary = state["planets"][0]
	var previous_stock: float = float(trade_test["stock"]["Metals"])
	trade_test["stock"]["Metals"] = 175.0
	assert(is_equal_approx(ECON._need(trade_test, "Metals"), 25.0))
	assert(is_zero_approx(ECON._surplus(trade_test, "Metals")))
	trade_test["stock"]["Metals"] = 300.0
	assert(is_zero_approx(ECON._need(trade_test, "Metals")))
	assert(is_zero_approx(ECON._surplus(trade_test, "Metals")))
	trade_test["stock"]["Metals"] = 450.0
	assert(is_equal_approx(ECON._surplus(trade_test, "Metals"), 50.0))
	trade_test["stock"]["Metals"] = 2250.0
	assert(ECON.set_thresholds(state, 1, 0, "Metals", 0, 100))
	assert(is_equal_approx(ECON._surplus(trade_test, "Metals"), 250.0))
	trade_test["stock"]["Metals"] = previous_stock
	assert(ECON.set_thresholds(state, 1, 0, "Metals", 0, 10))
	assert(not ECON.enqueue(state, 1, 0, "production", "Tech"))

	# Empire totals include cargo once and exclude allied/hostile inventories.
	var totals_state: Dictionary = ECON.create(graph, players, ids, false)
	totals_state["planets"][3]["owner"] = 1
	totals_state["planets"][3]["station"] = {"hp": ECON.STATION_HP}
	totals_state["planets"][3]["population"] = ECON.COLONY_POPULATION
	totals_state["planets"][3]["stock"]["Metals"] = 25.0
	var own_cargo: Dictionary = ECON.empty_stock()
	own_cargo["Metals"] = 7.0
	totals_state["ships"].append({"owner": 1, "kind": "ship", "cargo": own_cargo, "crew": 20.0})
	totals_state["ships"].append({"owner": 1, "kind": "colony_ship", "cargo": ECON.empty_stock(), "crew": 80.0})
	totals_state["ships"].append({"owner": 2, "kind": "ship", "cargo": own_cargo.duplicate(), "crew": 200.0})
	var totals: Dictionary = ECON.empire_totals(totals_state, 1)
	assert(totals["planets"] == 2 and totals["craft"] == 2)
	assert(totals["logistics"] == 1 and totals["colonies"] == 1)
	assert(is_equal_approx(float(totals["population"]), ECON.HOME_POPULATION + ECON.ORBITAL_HOUSING_POPULATION + ECON.COLONY_POPULATION + 100.0))
	assert(is_equal_approx(float(totals["stock"]["Metals"]), float(ECON.STARTING_STOCK["Metals"]) + 25.0))
	assert(is_equal_approx(float(totals["cargo"]["Metals"]), 7.0))
	assert(is_equal_approx(float(totals["resources"]["Metals"]), float(ECON.STARTING_STOCK["Metals"]) + 32.0))
	assert(ECON.empire_totals({}, 1)["craft"] == 0)

	# Rolling window measures net holdings, not internal cargo transfers.
	var history: Dictionary = {}
	var rolling: Dictionary = ECON.create(graph, players, ids, false)
	ECON.sample_resource_rates(rolling, history)
	for i in range(1, 8):
		rolling["elapsed"] = float(i)
		rolling["planets"][0]["stock"]["Metals"] += 10.0 if i <= 5 else -5.0
		ECON.sample_resource_rates(rolling, history)
		if i == 2:
			assert(is_equal_approx(float(rolling["resource_rates"][1]["Metals"]), 10.0))
	assert(is_equal_approx(float(rolling["resource_rates"][1]["Metals"]), 4.0))
	assert(is_zero_approx(float(rolling["resource_rates"][2]["Metals"])))
	var transfer: Dictionary = ECON.empty_stock()
	transfer["Metals"] = 25.0
	rolling["planets"][0]["stock"]["Metals"] -= 25.0
	rolling["ships"].append({"owner": 1, "kind": "ship", "cargo": transfer})
	ECON.sample_resource_rates(rolling, history)
	assert(is_equal_approx(float(rolling["resource_rates"][1]["Metals"]), 4.0))
	rolling["elapsed"] = 7.5
	rolling["planets"][0]["stock"]["Metals"] -= 50.0
	ECON.sample_resource_rates(rolling, history)
	assert(is_equal_approx(float(rolling["resource_rates"][1]["Metals"]), -7.0))
	# Starting growth is exponential when well below a food-supported plateau.
	var demographics: Dictionary = ECON.create(graph, players, ids, false)
	var home: Dictionary = demographics["planets"][0]
	# Isolate terrestrial demographic formulas from independent orbital habitats.
	home["yards"].clear()
	home["eco_population"] = 0.0
	home["population"] = ECON.HOME_POPULATION
	home["bonuses"]["Organics"] = 1.0
	home["abundance"]["Metals"] = 1.0
	var capacity: float = ECON.population_capacity(home)
	assert(is_equal_approx(float(home["population"]), 10000.0))
	assert(is_equal_approx(capacity, 100000.0))
	assert(is_equal_approx(ECON.population_multiplier(home), 1.0))
	assert(is_zero_approx(ECON.population_growth(home)))
	var baseline: float = ECON.rate(home, "Metals")
	assert(is_equal_approx(baseline, 4.0))
	assert(is_equal_approx(ECON.farm_potential(home), 4.0))
	assert(is_equal_approx(ECON.organics_demand(home), 0.4))
	assert(is_equal_approx(ECON.MINER_RATE, 3.0))
	assert(is_equal_approx(ECON.dropoff_rate("miner"), 120.0))
	assert(is_equal_approx(ECON.dropoff_rate("ship"), 60.0))
	assert(is_equal_approx(ECON.dropoff_rate("colony_ship"), 100.0))
	assert(is_equal_approx(ECON.PLANET_MINING_LIMIT, 100.0))
	assert(is_equal_approx(ECON.FIELD_MINING_LIMIT, 200.0))
	home["population"] = ECON.HOME_POPULATION * 0.5
	assert(is_equal_approx(ECON.rate(home, "Metals"), baseline * 0.5))
	home["population"] = ECON.HOME_POPULATION
	assert(ECON.rate(home, "Organics") > ECON.organics_demand(home))
	home["stock"]["Organics"] = ECON.POPULATION_FOOD_RESERVE
	assert(ECON.POPULATION_DOUBLING_YEARS == 60.0)
	for i in range(600):
		ECON._update_population(home, 0.1)
	assert(float(home["population"]) > 19500.0 and float(home["population"]) <= 20000.01)
	for i in range(600):
		ECON._update_population(home, 0.1)
	assert(float(home["population"]) > 39000.0 and float(home["population"]) <= 40000.02)
	# Food reserve affects only positive terrestrial growth, independently of storage tier.
	for fraction in [0.0, 0.25, 0.5, 0.75, 1.0, 2.0]:
		var sample: Dictionary = home.duplicate(true)
		sample["population"] = ECON.HOME_POPULATION
		sample["population_velocity"] = 1000.0
		sample["stock"]["Organics"] = fraction * ECON.POPULATION_FOOD_RESERVE
		var expected: float = minf(fraction, 1.0)
		assert(is_equal_approx(ECON.food_growth_multiplier(sample), expected))
		sample["warehouse_level"] = 3
		assert(is_equal_approx(ECON.food_growth_multiplier(sample), expected))
		var growth_constant: float = log(2.0) / 60.0 * expected * (1.0 - ECON.overpopulation_penalty(sample))
		ECON._update_population(sample, 1.0)
		assert(is_equal_approx(float(sample["population"]), ECON.HOME_POPULATION * exp(growth_constant)))
	# Convergence is damped from either side; no overshoot for fixed capacity.
	var prior: float = float(home["population"])
	for i in range(300):
		ECON._update_population(home, 1.0)
		var next: float = float(home["population"])
		assert(next >= prior - ECON.EPS and next <= capacity + ECON.EPS)
		prior = next
	assert(absf(float(home["population"]) - capacity) < 0.1)
	home["population"] = capacity * 1.5
	home["population_velocity"] = 0.0
	prior = float(home["population"])
	for i in range(300):
		ECON._update_population(home, 1.0)
		var next: float = float(home["population"])
		assert(next <= prior + ECON.EPS and next >= capacity - ECON.EPS)
		prior = next
	assert(absf(float(home["population"]) - capacity) < 0.1)

	# Actual stock rises or falls by farming output minus consumption.
	home["population"] = capacity * 0.5
	home["population_velocity"] = 0.0
	home["stock"]["Organics"] = 100.0
	assert(ECON.current_year(demographics) == 2850)
	ECON.step(demographics, 1.0)
	assert(ECON.current_year(demographics) == 2851)
	assert(is_equal_approx(float(home["stock"]["Organics"]), 100.0 + ECON.rate(home, "Organics") - ECON.organics_demand(home)))
	assert(ECON.population_growth(home) > 0.0)
	home["population"] = capacity * 1.5
	home["population_velocity"] = 0.0
	home["stock"]["Organics"] = 0.0
	ECON.step(demographics, 1.0)
	assert(is_zero_approx(float(home["stock"]["Organics"])))
	assert(ECON.population_growth(home) < 0.0)
	# A farming failure cannot allow positive growth despite prior momentum.
	home["levels"]["Organics"] = 0
	home["population"] = ECON.HOME_POPULATION
	home["population_velocity"] = 1000.0
	ECON._update_population(home, 0.1)
	assert(float(home["population"]) <= ECON.HOME_POPULATION)
	assert(ECON.population_growth(home) <= 0.0)
	home["levels"]["Organics"] = 1
	home["population"] = capacity
	home["population_velocity"] = 0.0
	home["stock"]["Metals"] = 1000.0
	home["stock"]["Organics"] = ECON.POPULATION_FOOD_RESERVE
	assert(ECON.enqueue(demographics, 1, 0, "production", "Organics"))
	ECON.step(demographics, 20.0 + ECON.PLANET_UPGRADE_DELIVERY_TIME)
	assert(int(home["levels"]["Organics"]) == 2)
	assert(is_equal_approx(ECON.population_capacity(home), 200000.0 * float(home["farm_factor"])))
	ECON.step(demographics, 1.0)
	assert(float(home["population"]) > capacity)
	home["bonuses"]["Organics"] = 1.5
	assert(is_equal_approx(ECON.population_capacity(home), 300000.0 * float(home["farm_factor"])))
	assert(is_zero_approx(float(demographics["planets"][3]["population"])))
	for i in range(300):
		ECON.step(demographics, 1.0)
	var smallest: float = INF
	var largest: float = -INF
	for i in range(100):
		ECON.step(demographics, 1.0)
		smallest = minf(smallest, float(home["population"]))
		largest = maxf(largest, float(home["population"]))
	assert(largest - smallest > 1000.0 and largest - smallest < 30000.0)
	assert(smallest > 270000.0 and largest < 330000.0)
	assert(ECON.current_year(demographics) == 3273)
	print("PASS: 60-year doubling, food reserve modifier, warehouse independence, damped population, food shortage, farm upgrades and year clock")

	# Visual planet count loosely follows system richness, without modifying state.
	var poor: Dictionary = {"abundance": {"Metals": 0.0, "Crystals": 0.0}, "bonuses": {"Organics": 1.0}}
	var rich: Dictionary = {"abundance": {"Metals": 2.0, "Crystals": 2.0}, "bonuses": {"Organics": 1.8}}
	var poor_bodies: Array = ECON.system_bodies(poor, 123, 0)
	var rich_bodies: Array = ECON.system_bodies(rich, 123, 0)
	assert(rich_bodies.size() > poor_bodies.size())
	assert(poor_bodies == ECON.system_bodies(poor, 123, 0))
	assert(rich_bodies == ECON.system_bodies(rich, 123, 0))
	for body in poor_bodies:
		assert(body["resource"] == "")
	for body in rich_bodies:
		assert(float(body["orbit"]) + float(body["size"]) < 1.0)
	# Materials are prepaid atomically; work and crew remain time-dependent.
	var saved_population: float = float(p["population"])
	p["population"] = saved_population
	p["levels"]["Metals"] = 0
	p["stock"]["Metals"] = 90.0
	var failed_stock: Dictionary = p["stock"].duplicate()
	var failed_id: int = int(state["next_id"])
	assert(not ECON.enqueue(state, 1, 0, "ship"))
	assert(p["stock"] == failed_stock and p["queue"].is_empty() and int(state["next_id"]) == failed_id)
	p["yards"][0]["level"] = 2
	for material in ECON._cost("ship", 1):
		p["stock"][material] = ECON._cost("ship", 1)[material]
	assert(ECON.enqueue(state, 1, 0, "ship"))
	assert(is_zero_approx(float(p["stock"]["Metals"])))
	ECON._advance(p, p["queue"][0], 6.0)
	assert(is_equal_approx(float(p["queue"][0]["progress"]), 6.0))
	assert(is_zero_approx(float(p["stock"]["Metals"])))
	ECON._advance(p, p["queue"][0], 6.0)
	var item: Dictionary = p["queue"][0]
	assert(is_equal_approx(float(item["progress"]), 12.0))
	ECON._advance(p, p["queue"][0], 6.0)
	assert(is_equal_approx(float(item["progress"]), 18.0))
	assert(ECON.cancel(state, 1, 0, int(item["id"])))
	assert(is_zero_approx(float(p["stock"]["Metals"])))
	assert(is_equal_approx(_cancelled_material(state, int(item["id"]), "Metals"), 360.0))
	assert(p["queue"].is_empty())
	assert(is_equal_approx(float(p["population"]), saved_population))

	# Every repeatable upgrade grows geometrically; all order types refund actual allocations.
	for kind in ["production", "yard_upgrade"]:
		assert(float(ECON._cost(kind, 2)["Metals"]) >= 600.0)
		for level in range(1, 8):
			assert(is_equal_approx(float(ECON._cost(kind, level + 1)["Metals"]), 3.0 * float(ECON._cost(kind, level)["Metals"])))
	assert(ECON._cost("production", 3)["Metals"] == 1800.0)
	assert(ECON._cost("yard_upgrade", 3)["Metals"] == 2160.0)
	for level in range(3):
		for material in ECON.WAREHOUSE_COSTS[level]:
			assert(float(ECON.WAREHOUSE_COSTS[level][material]) <= float(ECON.WAREHOUSE_CAPACITIES[level]))
			if level > 0:
				assert(float(ECON.WAREHOUSE_COSTS[level][material]) == 3.0 * float(ECON.WAREHOUSE_COSTS[level - 1][material]))
	assert(ECON.ECONOMY_BUILDINGS["Organics"]["cost"] == {"Metals": 240.0})
	assert(ECON.ECONOMY_BUILDINGS["Crystals"]["cost"] == {"Metals": 240.0})
	var refunds: Dictionary = ECON.create(graph, players, ids, false)
	var refund_home: Dictionary = refunds["planets"][0]
	refund_home["levels"]["Metals"] = 0
	refund_home["warehouse_level"] = 3
	for kind in ["ship", "colony_ship", "fighter", "miner", "yard", "yard_upgrade", "production"]:
		refund_home["population"] = 150000.0 if kind == "colony_ship" else ECON.HOME_POPULATION
		for material in ECON.RESOURCES:
			refund_home["stock"][material] = 10000.0
		var target: String = "0" if kind == "yard_upgrade" else ("Organics" if kind == "production" else "")
		assert(ECON.enqueue(refunds, 1, 0, kind, target))
		ECON.step(refunds, 1.0)
		var order: Dictionary = refund_home["queue"][0]
		assert(float(order["allocated"]["Metals"]) > 0.0)
		assert(not ECON.cancel(refunds, 2, 0, int(order["id"])))
		assert(ECON.cancel(refunds, 1, 0, int(order["id"])))
		assert(refund_home["queue"].is_empty())
		var dropped: float = _cancelled_material(refunds, int(order["id"]), "Metals")
		assert(is_equal_approx(dropped, float(order["allocated"]["Metals"]) if ECON.SHIP_KINDS.has(order["kind"]) else 0.0))
		assert(is_equal_approx(float(refund_home["stock"]["Metals"]) + dropped, 10000.0 - ECON.consumption(refund_home, "Metals")))
		assert(int(refund_home["yards"][0]["job"]) == -1)
	# Completed and pending shipyards share a hard three-slot limit.
	var capped: Dictionary = ECON.create(graph, players, ids, false)
	var cap_home: Dictionary = capped["planets"][0]
	cap_home["warehouse_level"] = 3
	for material in ECON.RESOURCES:
		cap_home["stock"][material] = 10000.0
	assert(ECON.shipyard_count(cap_home) == 1)
	assert(not ECON.enqueue(capped, 2, 0, "yard"))
	assert(ECON.enqueue(capped, 1, 0, "yard"))
	assert(ECON.enqueue(capped, 1, 0, "yard"))
	assert(ECON.shipyard_count(cap_home) == 3)
	assert(cap_home["queue"][0]["cost"] == {"Metals": 2000.0, "Organics": 200.0, "Crystals": 1000.0})
	assert(cap_home["queue"][1]["cost"]["Metals"] == 6000.0)
	assert(not ECON.enqueue(capped, 1, 0, "yard"))
	assert(ECON.cancel(capped, 1, 0, int(cap_home["queue"][-1]["id"])))
	assert(ECON.shipyard_count(cap_home) == 2)
	assert(not ECON.enqueue(capped, 1, 0, "yard"))
	for material in ECON._cost("yard", 3):
		cap_home["stock"][material] += float(ECON._cost("yard", 3)[material])
	assert(ECON.enqueue(capped, 1, 0, "yard"))
	ECON.step(capped, ECON._work("yard", 2))
	assert(cap_home["yards"].size() == 2)
	assert(float(ECON.station_construction_job(cap_home)["progress"]) == 0.0)
	ECON.step(capped, ECON._work("yard", 3))
	assert(cap_home["yards"].size() == 3)
	assert(ECON.shipyard_count(cap_home) == 3)
	assert(not ECON.enqueue(capped, 1, 0, "yard"))
	assert(ECON.enqueue(capped, 1, 0, "yard_upgrade", "0"))
	var gap_state: Dictionary = ECON.create(graph, players, ids, false)
	var gap_home: Dictionary = gap_state["planets"][0]
	gap_home["warehouse_level"] = 3
	for material in ECON.RESOURCES:
		gap_home["stock"][material] = 10000.0
	assert(not ECON.enqueue(gap_state, 1, 0, "yard", "3"))
	assert(ECON.enqueue(gap_state, 1, 0, "yard", "2"))
	assert(ECON.enqueue(gap_state, 1, 0, "yard", "3"))
	var stack_second: Dictionary = gap_home["queue"][0]
	var stack_third: Dictionary = gap_home["queue"][1]
	ECON._work_planet(gap_state, 0, 6.0)
	assert(float(stack_second["progress"]) > 0.0 and float(stack_third["progress"]) == 0.0)
	# Emulate retained progress from a formerly concurrent construction save.
	ECON._advance(gap_home, stack_third, 3.0)
	var fraction: float = float(stack_third["progress"]) / float(stack_third["work"])
	var total_material: Dictionary = ECON.empty_stock()
	for material in ECON.RESOURCES:
		total_material[material] = float(gap_home["stock"][material]) + float(stack_second["allocated"][material]) + float(stack_third["allocated"][material])
	assert(not ECON.cancel(gap_state, 2, 0, int(stack_second["id"])))
	assert(ECON.cancel(gap_state, 1, 0, int(stack_second["id"])))
	assert(gap_home["queue"].size() == 1 and int(stack_third["level"]) == 2)
	assert(stack_third["cost"] == ECON._cost("yard", 2))
	assert(is_equal_approx(float(stack_third["progress"]) / float(stack_third["work"]), fraction))
	for material in ECON.RESOURCES:
		assert(is_equal_approx(float(stack_third["allocated"][material]), float(stack_third["cost"].get(material, 0.0))))
		assert(is_equal_approx(float(gap_home["stock"][material]) + float(stack_third["allocated"][material]) + _cancelled_material(gap_state, int(stack_second["id"]), material), float(total_material[material])))
	assert(ECON.next_shipyard_slot(gap_home) == 3)
	for material in ECON._cost("yard", 3):
		gap_home["stock"][material] += float(ECON._cost("yard", 3)[material])
	assert(ECON.enqueue(gap_state, 1, 0, "yard", "3"))
	assert(ECON.shipyard_count(gap_home) == 3)
	assert(not ECON.enqueue(gap_state, 1, 0, "yard", "3"))
	# A queued yard waits, even when the previous yard is partially completed.
	var latest: Dictionary = gap_home["queue"][-1]
	ECON._work_planet(gap_state, 0, 1.0)
	assert(gap_home["yards"].size() == 1)
	assert(float(latest["progress"]) == 0.0)
	ECON._work_planet(gap_state, 0, float(stack_third["work"]) - float(stack_third["progress"]))
	assert(gap_home["yards"].size() == 2 and float(latest["progress"]) == 0.0)
	ECON._work_planet(gap_state, 0, float(latest["work"]))
	assert(gap_home["yards"].size() == 3)

	# Yard upgrades wait behind assigned hull production.
	p["warehouse_level"] = 3
	for material in ECON.RESOURCES:
		p["stock"][material] = 5000.0
	p["yards"][0]["level"] = 2
	p["yards"].append({"level": 2, "job": -1})
	assert(ECON.enqueue(state, 1, 0, "ship"))
	assert(ECON.enqueue(state, 1, 0, "ship"))
	ECON.step(state, 1.0)
	assert(int(p["yards"][0]["job"]) != int(p["yards"][1]["job"]))
	var first_job: int = int(p["yards"][0]["job"])
	assert(ECON.enqueue(state, 1, 0, "yard_upgrade", "0"))
	assert(int(p["yards"][0]["job"]) == first_job)
	ECON.step(state, 1.0)
	assert(is_equal_approx(float(p["queue"][0]["progress"]), ECON.yard_speed(2) * 2.0))
	assert(is_zero_approx(float(p["queue"][2]["progress"])))
	for i in range(ceili(ECON._work("ship", 1) / ECON.yard_speed(2)) - 2):
		ECON.step(state, 1.0)
	assert(state["ships"].size() == 2)
	assert(p["queue"].size() == 1)
	ECON.step(state, 1.0)
	assert(int(p["yards"][0]["job"]) == int(p["queue"][0]["id"]))
	assert(is_equal_approx(float(p["queue"][0]["progress"]), 1.0))
	for i in range(ceili(ECON._work("yard_upgrade", 3)) - 1):
		ECON.step(state, 1.0)
	assert(int(p["yards"][0]["level"]) == 3)
	assert(ECON.max_size(2) > ECON.max_size(1))

	# Eight shipyard orders including the active job; repeat waits for space.
	var repeat_state: Dictionary = ECON.create(graph, players, ids, false)
	var repeat_home: Dictionary = repeat_state["planets"][0]
	repeat_home["warehouse_level"] = 3
	repeat_home["yards"][0]["level"] = 2
	for material in ECON.RESOURCES:
		repeat_home["stock"][material] = 5000.0
	assert(not ECON.set_continuous(repeat_state, 2, 0, "fighter", true))
	assert(not ECON.set_continuous(repeat_state, 1, 0, "yard", true))
	assert(ECON.set_continuous(repeat_state, 1, 0, "fighter", true))
	for i in range(8):
		assert(ECON.enqueue(repeat_state, 1, 0, "ship"))
	assert(not ECON.enqueue(repeat_state, 1, 0, "ship"))
	assert(ECON.cancel(repeat_state, 1, 0, int(repeat_home["queue"][-1]["id"])))
	ECON.step(repeat_state, 1.0)
	assert(repeat_home["queue"].size() == 8)
	var repeat_id: int = int(repeat_home["queue"][-1]["id"])
	assert(ECON.cancel(repeat_state, 1, 0, repeat_id))
	assert(not repeat_home["continuous"]["fighter"])
	ECON.step(repeat_state, 1.0)
	assert(not ECON._has_job(repeat_home, "fighter", ""))

	var names: Array = graph["names"]
	assert(names.size() == graph["points"].size())
	var unique: Dictionary = {}
	for system_name in names:
		assert(not unique.has(system_name))
		unique[system_name] = true
	assert(names == MAP.system_names(int(graph["seed"]), names.size()))

	# Repeating hulls cycle in order, including under material starvation.
	var rotation: Dictionary = ECON.create(graph, players, ids, false)
	var rotation_home: Dictionary = rotation["planets"][0]
	rotation_home["population"] = 450000.0
	rotation_home["levels"]["Organics"] = 10
	rotation_home["levels"]["Metals"] = 0
	rotation_home["stock"]["Metals"] = 0.0
	for kind in ["colony_ship", "fighter", "miner"]:
		assert(ECON.set_continuous(rotation, 1, 0, kind, true))
	ECON.step(rotation, 1.0)
	assert(rotation_home["queue"].is_empty())
	# Save for the first turn rather than leapfrogging with a cheaper fighter.
	rotation_home["stock"]["Metals"] = 500.0
	ECON.step(rotation, 1.0)
	assert(rotation["ships"].is_empty() and rotation_home["queue"].is_empty())
	rotation_home["warehouse_level"] = 3
	for material in ECON.RESOURCES:
		rotation_home["stock"][material] = 10000.0
	for i in range(100):
		ECON.step(rotation, 1.0)
		if rotation["ships"].size() >= 9:
			break
	assert(rotation["ships"].size() == 9)
	for i in range(9):
		assert(rotation["ships"][i]["kind"] == ["colony_ship", "fighter", "miner"][i % 3])
	# Canceling an automatic order turns off that type, without stopping the rest.
	ECON._refill_continuous(rotation, 0, rotation_home)
	for job in (rotation_home["queue"] as Array).duplicate():
		if job["kind"] == "fighter":
			assert(ECON.cancel(rotation, 1, 0, int(job["id"])))
	assert(not rotation_home["continuous"]["fighter"])
	for i in range(50):
		ECON.step(rotation, 1.0)
	for i in range(9, rotation["ships"].size()):
		assert(rotation["ships"][i]["kind"] != "fighter")
	# Two shipyards can start consecutive turns in parallel.
	var parallel_repeat: Dictionary = ECON.create(graph, players, ids, false)
	var parallel_home: Dictionary = parallel_repeat["planets"][0]
	parallel_home["warehouse_level"] = 3
	for material in ECON.RESOURCES:
		parallel_home["stock"][material] = 10000.0
	parallel_home["yards"].append({"level": 1, "job": -1})
	for kind in ["fighter", "miner"]:
		assert(ECON.set_continuous(parallel_repeat, 1, 0, kind, true))
	ECON.step(parallel_repeat, 1.0)
	assert(parallel_home["yards"][0]["job"] != parallel_home["yards"][1]["job"])
	assert(float(parallel_home["queue"][0]["progress"]) > 0.0)
	assert(float(parallel_home["queue"][1]["progress"]) > 0.0)
	# Different shipyard speeds and build durations must not give the faster
	# hull type extra starts. Observe assigned jobs, not completion order.
	parallel_home["yards"][0]["level"] = 3
	var started_ids: Dictionary = {}
	var starts: Array[String] = []
	for tick in range(60):
		for yard in parallel_home["yards"]:
			var id: int = int(yard["job"])
			if id < 0 or started_ids.has(id):
				continue
			for job in parallel_home["queue"]:
				if int(job["id"]) == id:
					started_ids[id] = true
					starts.append(str(job["kind"]))
					break
		ECON.step(parallel_repeat, 0.1)
	assert(starts.size() >= 4)
	for i in range(starts.size()):
		assert(starts[i] == ["fighter", "miner"][i % 2])

	# Automatic system and shipyard upgrades use the shared scheduler.
	var upgrades: Dictionary = ECON.create(graph, players, ids, false)
	var upgrade_home: Dictionary = upgrades["planets"][0]
	upgrade_home["warehouse_level"] = 3
	upgrade_home["stock"]["Metals"] = 20000.0
	assert(not ECON.set_continuous(upgrades, 2, 0, "production:Organics", true))
	assert(ECON.set_continuous(upgrades, 1, 0, "production:Crystals", true))
	assert(ECON.set_continuous(upgrades, 1, 0, "production:Crystals", false))
	assert(not ECON.set_continuous(upgrades, 1, 0, "yard_upgrade:8", true))
	assert(ECON.set_continuous(upgrades, 1, 0, "production:Organics", true))
	assert(ECON.set_continuous(upgrades, 1, 0, "yard_upgrade:0", true))
	ECON.step(upgrades, 1.0)
	assert(ECON._has_job(upgrade_home, "production", "Organics"))
	assert(ECON._has_job(upgrade_home, "yard_upgrade", "0"))
	for i in range(32):
		ECON.step(upgrades, 1.0)
	assert(int(upgrade_home["levels"]["Organics"]) == 2)
	assert(int(upgrade_home["yards"][0]["level"]) == 2)
	assert(ECON._has_job(upgrade_home, "production", "Organics"))
	assert(ECON._has_job(upgrade_home, "yard_upgrade", "0"))
	assert(ECON.set_continuous(upgrades, 1, 0, "production:Organics", false))
	assert(ECON.set_continuous(upgrades, 1, 0, "yard_upgrade:0", false))
	for i in range(50):
		ECON.step(upgrades, 1.0)
	assert(upgrade_home["queue"].is_empty())
	assert(int(upgrade_home["levels"]["Organics"]) == 3)
	assert(int(upgrade_home["yards"][0]["level"]) == 3)
	assert(ECON.set_continuous(upgrades, 1, 0, "production:Organics", true))
	assert(not ECON.set_continuous(upgrades, 1, 0, "yard_upgrade:0", true))
	ECON.step(upgrades, 1.0)
	for job in (upgrade_home["queue"] as Array).duplicate():
		assert(ECON.cancel(upgrades, 1, 0, int(job["id"])))
	assert(not upgrade_home["continuous"]["production:Organics"])
	assert(not upgrade_home["continuous"]["yard_upgrade:0"])
	ECON.step(upgrades, 1.0)
	assert(upgrade_home["queue"].is_empty())
	# Fighters use the shipyard and are counted separately; no logistics behavior.
	var military: Dictionary = ECON.create(graph, players, ids, false)
	assert(not ECON.enqueue(military, 2, 0, "fighter"))
	assert(ECON.enqueue(military, 1, 0, "fighter"))
	for i in range(6):
		ECON.step(military, 1.0)
	assert(military["ships"].size() == 1)
	var fighter: Dictionary = military["ships"][0]
	assert(fighter["kind"] == "fighter" and fighter["route"].is_empty())
	assert(ECON.empire_totals(military, 1)["fighters"] == 1)
	assert(ECON.empire_totals(military, 1)["logistics"] == 0)
	assert(not ECON.send_colony(military, 1, int(fighter["id"]), 3))
	for i in range(20):
		ECON.step(military, 1.0)
	assert(int(fighter["at"]) == 0 and fighter["route"].is_empty())
	print("PASS: clustered map and fighter construction")

	# Deterministic mining round trip; no planetary production or unrelated cargo.
	var mineral_map: Dictionary = _planetary_fixture(678, 3, "Grid")
	var mineral_points: Array = mineral_map["points"]
	var metal_pos: Vector2 = (mineral_points[0] as Vector2) + Vector2(95, 0)
	var crystal_pos: Vector2 = (mineral_points[0] as Vector2) + Vector2(95, 30)
	mineral_map["field_edges"] = []
	mineral_map["fields"] = [{"position": metal_pos, "radius": 40.0, "anchor": 0, "Metals": 1.0, "Crystals": 1.0,
		"chunks": [{"id": 7, "position": metal_pos, "resource": "Metals", "remaining": 24.0},
			{"id": 9, "position": crystal_pos, "resource": "Crystals", "remaining": 36.0}]}]
	var mineral: Dictionary = ECON.create(mineral_map, players, ids, false)
	assert(ECON.discovered(mineral, 3, "fields", 0))
	assert(ECON.set_mining_policy(mineral, 3, 0, false, false, false))
	mineral["fog_of_war"] = true
	assert(ECON.discovered(mineral, 1, "fields", 0))
	assert(not ECON.discovered(mineral, 3, "fields", 0))
	assert(not ECON.set_mining_policy(mineral, 3, 0, false, false, false))
	mineral["fog_of_war"] = false
	assert(ECON.set_mining_policy(mineral, 1, 0, true, true, false))
	assert(ECON.mining_policy(mineral, 2, 0)["Crystals"])
	var mine_home: Dictionary = mineral["planets"][0]
	mine_home["levels"]["Metals"] = 1000
	assert(is_equal_approx(ECON.rate(mine_home, "Metals"), ECON.PLANET_MINING_LIMIT))
	mine_home["levels"]["Metals"] = 0
	mine_home["levels"]["Crystals"] = 0
	assert(not ECON.enqueue(mineral, 2, 0, "miner"))
	assert(ECON.enqueue(mineral, 1, 0, "miner"))
	var mining_order: Dictionary = mine_home["queue"][0]
	assert(ECON._advance(mine_home, mining_order, float(mining_order["work"])))
	ECON._finish(mineral, 0, mine_home, mining_order)
	mine_home["population"] = 0.0
	assert(mineral["ships"].size() == 1)
	assert(ECON.empire_totals(mineral, 1)["miners"] == 1)
	var miner: Dictionary = mineral["ships"][0]
	assert(not ECON.command_miners(mineral, 2, [int(miner["id"])], 0, 7))
	assert(not ECON.command_miners(mineral, 1, [int(miner["id"])], 0, 999))
	assert(not ECON.command_miners(mineral, 1, [int(miner["id"])], 0, 9))
	assert(ECON.command_miners(mineral, 1, [int(miner["id"])], 0, 7))
	assert(int(miner["assigned_field"]) == 0 and int(miner["assigned_chunk"]) == 7)
	assert(ECON.command_miners(mineral, 1, [int(miner["id"])], -1))
	assert(int(miner["assigned_field"]) == -1)
	assert(ECON.command_miners(mineral, 1, [int(miner["id"])], 0, 7))
	assert(miner["kind"] == "miner")
	assert(not ECON.send_colony(mineral, 1, int(miner["id"]), 3))
	var after_build: float = float(mine_home["stock"]["Metals"])
	assert(is_equal_approx(after_build, float(ECON.STARTING_STOCK["Metals"]) - float(ECON._cost("miner", 1)["Metals"])))
	ECON.step(mineral, 0.1)
	assert(miner["mining_rock"] == metal_pos)
	assert((miner["mining_target"] as Vector2).distance_to(metal_pos) >= 12.0 - ECON.EPS)
	assert(int(miner["chunk"]) == 7)
	for i in range(20):
		if miner["mining_mode"] == "mining":
			break
		ECON.step(mineral, 1.0)
	assert(miner["mining_mode"] == "mining")
	for i in range(4):
		ECON.step(mineral, 1.0)
		assert(miner["mining_mode"] == "mining")
	assert(ECON._find_chunk(mineral["map"]["fields"][0], 7).is_empty())
	ECON.step(mineral, 1.0)
	assert(miner["mining_mode"] == "return")
	for i in range(20):
		ECON.step(mineral, 1.0)
	assert(is_equal_approx(float(mine_home["stock"]["Metals"]), after_build + 24.0))
	assert(ECON._find_chunk(mineral["map"]["fields"][0], 7).is_empty())
	assert(is_zero_approx(float(ECON.field_inventory(mineral["map"]["fields"][0])["Metals"])))
	assert(is_equal_approx(float(mine_home["stock"]["Crystals"]), float(mineral["elapsed"]) * ECON.STATION_CRYSTALS_PER_YEAR))
	assert(is_zero_approx(float(miner["cargo"]["Crystals"])))
	assert(ECON.set_mining_policy(mineral, 1, 0, true, false, true))
	# The ship may have been wandering away from its dock while no ore
	# was enabled; allow the actual additional return-to-anchor travel.
	var approach_years: int = ceili((miner["position"] as Vector2).distance_to(mineral_points[0]) / ECON.ship_speed(str(miner["kind"])))
	for i in range(20 + approach_years):
		ECON.step(mineral, 1.0)
		if float(mine_home["stock"]["Crystals"]) - float(mineral["elapsed"]) * ECON.STATION_CRYSTALS_PER_YEAR >= 36.0 - ECON.EPS:
			break
	assert(is_equal_approx(float(mine_home["stock"]["Crystals"]), 36.0 + float(mineral["elapsed"]) * ECON.STATION_CRYSTALS_PER_YEAR))
	assert((mineral["map"]["fields"][0]["chunks"] as Array).is_empty())
	assert(is_zero_approx(float(ECON.field_inventory(mineral["map"]["fields"][0])["Crystals"])))
	assert(ECON.set_mining_policy(mineral, 1, 0, false, false, true))
	for i in range(10):
		ECON.step(mineral, 1.0)
	assert(miner["mining_mode"] == "idle")
	assert(is_zero_approx(float(miner["cargo"]["Organics"])))
	assert(ECON._cargo_total(miner) <= ECON.MINER_CAPACITY + ECON.EPS)
	assert(float(mine_home["size_factor"]) >= 0.86 and float(mine_home["size_factor"]) <= 1.18)
	print("PASS: asteroid route obstacles, mining ceiling and physical mineral delivery")

	# Physical, mixed cargo from an owned planet to an allied one. No hostile transit.
	var test_map: Dictionary = _planetary_fixture(123, 3, "Grid")
	test_map["edges"] = [[0, 1], [1, 2]]
	var points: Array = test_map["points"]
	points[0] = Vector2(0, 0)
	points[1] = Vector2(190, 0)
	points[2] = Vector2(380, 0)
	var transport: Dictionary = ECON.create(test_map, players, ids, false)
	var source: Dictionary = transport["planets"][0]
	var ally: Dictionary = transport["planets"][1]
	var hostile: Dictionary = transport["planets"][2]
	for planet in [source, ally, hostile]:
		planet["levels"]["Metals"] = 0
		planet["levels"]["Crystals"] = 0
		planet["population"] = 0.0
		for r in ECON.RESOURCES:
			planet["stock"][r] = 0.0
			planet["thresholds"][r] = {"min": 0.0, "max": 0.0}
	source["stock"]["Metals"] = 4.0
	source["stock"]["Crystals"] = 6.0
	ally["thresholds"]["Metals"] = {"min": 10.0, "max": 10.0}
	ally["thresholds"]["Crystals"] = {"min": 10.0, "max": 10.0}
	hostile["thresholds"]["Metals"] = {"min": 10.0, "max": 10.0}
	for i in range(2):
		transport["ships"].append({"id": i, "owner": 1, "at": 0, "route": [],
			"leg": 0.0, "source": -1, "dest": -1, "cargo": ECON.empty_stock()})
	ECON.step(transport, 1.0)
	var first: Dictionary = transport["ships"][0]
	var second: Dictionary = transport["ships"][1]
	for tick in range(20):
		ECON.step(transport, 0.1)
		if ECON._cargo_total(first) > ECON.EPS:
			break
	assert((first["position"] as Vector2).distance_to(ECON.station_position(transport, 0, float(transport["elapsed"]))) <= ECON.STATION_DOCK_RANGE + ECON.SHIP_CLEARANCE + ECON.EPS)
	assert(is_equal_approx(float(first["cargo"]["Metals"]), 4.0))
	assert(float(first["cargo"]["Crystals"]) >= 6.0)
	assert(is_zero_approx(float(second["cargo"]["Metals"])))
	assert(is_equal_approx(float(ally["stock"]["Crystals"]), float(transport["elapsed"]) * ECON.STATION_CRYSTALS_PER_YEAR))
	assert(is_equal_approx(float(ally["stock"]["Metals"]), 0.0))
	ECON.step(transport, 0.1)
	assert(is_equal_approx(float(ally["stock"]["Metals"]), 0.0))
	for tick in range(100):
		ECON.step(transport, 0.1)
		if float(ally["stock"]["Metals"]) > ECON.EPS:
			break
	assert((first["position"] as Vector2).distance_to(ECON.station_position(transport, 1, float(transport["elapsed"]))) <= ECON.STATION_DOCK_RANGE + ECON.SHIP_CLEARANCE + ECON.EPS)
	assert(is_equal_approx(float(ally["stock"]["Metals"]), 4.0))
	assert(float(ally["stock"]["Crystals"]) >= 6.0 + float(transport["elapsed"]) * ECON.STATION_CRYSTALS_PER_YEAR - ECON.EPS)
	assert(is_equal_approx(float(hostile["stock"]["Metals"]), 0.0))
	# Colony hulls use shipyards, travel before ownership changes, and cannot be stolen.
	var colony_map: Dictionary = _planetary_fixture(12, 3, "Grid")
	colony_map["edges"] = [[0, 1], [1, 3], [2, 3], [3, 4]]
	var cp: Array = colony_map["points"]
	cp[0] = Vector2(0, 0)
	cp[1] = Vector2(95, 0)
	cp[2] = Vector2(285, 0)
	cp[3] = Vector2(190, 0)
	cp[4] = Vector2(190, 95)
	var colonization: Dictionary = ECON.create(colony_map, players, ids, false)
	# This compressed travel/race fixture tests colonization, not overlapping
	# defensive ranges. Disable home batteries so the competing hulls survive.
	for system in colonization["planets"]:
		system["pds"].clear()
	for index in [0, 2]:
		colonization["planets"][index]["population"] = 150000.0
		colonization["planets"][index]["yards"][0]["level"] = 2
	assert(ECON.enqueue(colonization, 1, 0, "colony_ship"))
	assert(ECON.enqueue(colonization, 3, 2, "colony_ship"))
	for i in range(ceili(ECON._work("colony_ship", 1) / ECON.yard_speed(1))):
		ECON.step(colonization, 1.0)
	assert(colonization["ships"].size() == 2)
	var c1: Dictionary = colonization["ships"][0]
	var c2: Dictionary = colonization["ships"][1]
	assert(c1["kind"] == "colony_ship" and c2["kind"] == "colony_ship")
	assert(not ECON.send_colony(colonization, 2, int(c1["id"]), 3))
	assert(ECON.colony_path(colonization, 1, c1, 4) == [0, 1, 3, 4])
	assert(not ECON.send_colony(colonization, 1, int(c1["id"]), 2))
	assert(ECON.send_colony(colonization, 1, int(c1["id"]), 3))
	assert(ECON.send_colony(colonization, 3, int(c2["id"]), 3, true))
	assert(int(colonization["planets"][3]["owner"]) == 0)
	var distance1: float = (c1["position"] as Vector2).distance_to(cp[1]) + (cp[1] as Vector2).distance_to(cp[3])
	var distance2: float = (c2["position"] as Vector2).distance_to(cp[3])
	var first_arrival: float = minf(distance1, distance2) / ECON.SHIP_SPEED
	var winner: int = 1 if distance1 < distance2 else 3
	var loser: Dictionary = c2 if winner == 1 else c1
	var loser_home: int = 2 if winner == 1 else 0
	ECON.step(colonization, first_arrival * 0.5)
	assert(int(colonization["planets"][3]["owner"]) == 0)
	ECON.step(colonization, first_arrival * 0.5 + 0.001)
	assert(int(colonization["planets"][3]["owner"]) == winner)
	assert(is_equal_approx(float(colonization["planets"][3]["population"]), ECON.COLONY_POPULATION + ECON.ORBITAL_HOUSING_POPULATION))
	assert(int(colonization["planets"][3]["levels"]["Organics"]) == 1)
	assert(colonization["ships"].size() == 1)
	assert(colonization["ship_destructions"].is_empty())
	for i in range(20):
		if int(loser["at"]) == loser_home and loser["route"].is_empty():
			break
		var before: Vector2 = loser["position"]
		ECON.step(colonization, 0.5)
		assert(before.distance_to(loser["position"]) <= ECON.ship_speed(str(loser["kind"])) * 0.5 + 0.01)
	assert(int(loser["dest"]) == -1)
	assert(int(loser["at"]) == loser_home and loser["route"].is_empty())
	var distant: Dictionary = ECON.create(colony_map, players, ids, false)
	for system in distant["planets"]:
		system["pds"].clear()
	var distant_ship: Dictionary = {"id": 999, "kind": "colony_ship", "owner": 1, "at": 0, "position": cp[0], "route": [], "leg": 0.0, "dest": -1}
	distant["ships"].append(distant_ship)
	assert(ECON.send_colony(distant, 1, 999, 4, true))
	assert(distant_ship["position"] == cp[0])
	ECON.step(distant, 2.0)
	assert(int(distant["planets"][3]["owner"]) == 0 and int(distant["planets"][4]["owner"]) == 0)
	ECON.step(distant, 1.0)
	assert(int(distant["planets"][3]["owner"]) == 0 and int(distant["planets"][4]["owner"]) == 1)
	print("PASS: colony construction, permissions, travel, neutral arrival and competing colonies")
	# POI allocations reserve nearest fighters, including field destinations.
	var force_map: Dictionary = _planetary_fixture(1337, 3, "Grid")
	var force_points: Array = force_map["points"]
	force_points[0] = Vector2(0, 0)
	force_points[3] = Vector2(1000, 0)
	force_points[4] = Vector2(2000, 0)
	force_map["edges"] = [[0, 3], [3, 4]]
	force_map["field_edges"] = []
	force_map["fields"] = [{"position": Vector2(1000, 100), "anchor": 3}]
	var force_state: Dictionary = ECON.create(force_map, players, ids, false)
	var field_node: int = force_points.size()
	var force_graph: Dictionary = ECON.military_graph(force_state)
	var force_weights: Dictionary = ECON.military_policy(force_state, 1, "fighter")
	assert(force_weights[0] == 100 and force_weights[field_node] == 0)
	assert(not ECON.set_military(force_state, 1, "ship", 3, 50))
	assert(not ECON.set_military(force_state, 1, "fighter", -1, 50))
	assert(not ECON.set_military(force_state, 1, "fighter", field_node + 1, 50))
	assert(not ECON.set_military(force_state, 1, "fighter", 3, 101))
	assert(ECON.set_military(force_state, 1, "fighter", field_node, 50))
	force_weights = ECON.military_policy(force_state, 1, "fighter")
	assert(force_weights[0] == 50 and force_weights[field_node] == 50)
	assert(ECON.set_military(force_state, 1, "fighter", 4, 20))
	force_weights = ECON.military_policy(force_state, 1, "fighter")
	assert(force_weights[0] == 40 and force_weights[field_node] == 40 and force_weights[4] == 20)
	var force_sum: int = 0
	for amount in force_weights.values():
		force_sum += int(amount)
	assert(force_sum == 100)
	assert(ECON.set_military(force_state, 1, "fighter", 4, 0))
	for i in range(2):
		force_state["ships"].append({"id": i + 1, "kind": "fighter", "owner": 1, "at": 0 if i == 0 else 3, "route": [], "leg": 0.0, "dest": -1, "cargo": ECON.empty_stock()})
	var force_fleet: Array = force_state["ships"]
	ECON._allocate_fighters(force_state, force_graph, 1, force_fleet)
	assert(force_fleet[0]["dest"] == 0)
	assert(force_fleet[1]["dest"] == field_node)
	assert(force_fleet[1]["route"] == [field_node])
	ECON._move({"map": force_graph}, force_fleet[1], 0.5)
	assert(is_equal_approx(float(force_fleet[1]["leg"]), 47.5))
	var reversal_position: Vector2 = force_fleet[1]["position"]
	assert(ECON.set_military(force_state, 1, "fighter", 0, 100))
	ECON._allocate_fighters(force_state, force_graph, 1, force_fleet)
	assert(force_fleet[1]["at"] == field_node)
	assert(force_fleet[1]["route"] == [3, 0])
	assert(is_equal_approx(float(force_fleet[1]["leg"]), 52.5))
	assert(force_fleet[1]["position"] == reversal_position)
	ECON._move({"map": force_graph}, force_fleet[1], 0.1)
	assert(is_equal_approx(reversal_position.distance_to(force_fleet[1]["position"]), ECON.ship_speed(str(force_fleet[1]["kind"])) * 0.1))
	ECON._move({"map": force_graph}, force_fleet[1], 100.0)
	assert(force_fleet[1]["at"] == 0 and force_fleet[1]["route"].is_empty())
	assert(ECON.set_military(force_state, 1, "fighter", field_node, 100))
	ECON._allocate_fighters(force_state, force_graph, 1, force_fleet)
	ECON._move({"map": force_graph}, force_fleet[0], 100.0)
	assert(force_fleet[0]["at"] == field_node and force_fleet[0]["route"].is_empty())
	print("PASS: normalized POI force allocation, nearest assignments and continuous reversal")
	# Simultaneous burst fire: allies cannot be targeted; each blaster shot deals 1 HP.
	var duel: Dictionary = ECON.create(force_map, players, ids, false)
	# Isolate fighter-v-fighter combat from the starting planetary batteries.
	for planet in duel["planets"]:
		planet["pds"].clear()
	var duel_graph: Dictionary = ECON.military_graph(duel)
	for owner_id in [1, 3]:
		duel["ships"].append({"id": owner_id, "owner": owner_id, "kind": "fighter", "at": 0, "route": [], "leg": 0.0, "hp": 100.0, "dest": 0})
	for shot in range(18):
		ECON._combat(duel, duel_graph, 1.0)
	assert(duel["ships"].size() == 2)
	assert(duel["ship_destructions"].is_empty())
	assert(is_equal_approx(float(duel["ships"][0]["hp"]), 4.0))
	ECON._combat(duel, duel_graph, 1.0)
	assert(duel["ships"].is_empty())
	assert(duel["ship_destructions"].size() == 2)
	assert(duel["ship_destructions"][0]["sequence"] == 1 and duel["ship_destructions"][1]["sequence"] == 2)
	assert(duel["ship_destructions"][0]["ship"] == 1 and duel["ship_destructions"][0]["kind"] == "fighter")
	assert(duel["ship_destructions"][0]["position"] == duel_graph["points"][0])
	duel["ships"] = [{"id": 1, "owner": 1, "kind": "fighter", "at": 0, "route": [], "leg": 0.0, "hp": 100.0}, {"id": 2, "owner": 2, "kind": "fighter", "at": 0, "route": [], "leg": 0.0, "hp": 100.0}]
	ECON._combat(duel, duel_graph, 1.0)
	assert(float(duel["ships"][0]["hp"]) == 100.0 and int(duel["ships"][0]["combat_target"]) == -1)

	# Combat depends on actual position, not route, POI or activity metadata.
	duel["ships"] = [{"id": 11, "owner": 1, "kind": "fighter", "at": 0, "route": [3], "leg": 0.0, "position": Vector2(500, 0), "hp": 100.0}, {"id": 12, "owner": 3, "kind": "ship", "at": 3, "route": [0], "leg": 0.0, "position": Vector2(550, 0), "hp": 100.0}, {"id": 13, "owner": 3, "kind": "fighter", "at": 0, "route": [], "leg": 0.0, "position": Vector2(5000, 0), "hp": 100.0}]
	ECON._combat(duel, duel_graph, 1.0)
	assert(int(duel["ships"][0]["combat_target"]) == 12)
	assert(is_equal_approx(float(duel["ships"][1]["hp"]), 100.0 - ECON.BLASTER_DAMAGE * ECON.BLASTER_SHOTS * ECON.blaster_count("fighter")))
	assert(is_equal_approx(float(duel["ships"][2]["hp"]), 100.0))
	for tick in range(20):
		var before: Vector2 = miner["position"]
		ECON.step(mineral, 0.1)
		assert(before.distance_to(miner["position"]) <= ECON.ship_speed(str(miner["kind"])) * 0.1 + 0.01)

	var ai_map: Dictionary = {"seed": 123, "points": [Vector2(-950, 0), Vector2.ZERO, Vector2(3800, 0), Vector2(950, 0), Vector2(1900, 0)], "edges": [[0, 1], [1, 3], [3, 4], [4, 2]], "fields": []}
	var ai_roster: Dictionary = {1: {"team": 1}, 2: {"team": 1, "ai": true}, 3: {"team": 2}}
	# Attack orders wait for a physical rally, then commit only that cohort.
	var wave_state: Dictionary = ECON.create(ai_map, ai_roster, ids, false)
	var wave_graph: Dictionary = ECON.military_graph(wave_state)
	var wave_fleet: Array = []
	for i in range(2):
		wave_fleet.append({"id": 100 + i, "owner": 2, "kind": "fighter", "at": 1, "route": [], "leg": 0.0, "position": ai_map["points"][1], "dest": -1})
	ECON._ai_wave_order(wave_state, wave_graph, 2, 1, 2, wave_fleet)
	assert(wave_state["ai_waves"][2]["members"].is_empty())
	assert(wave_fleet[0]["dest"] == 1 and wave_fleet[1]["dest"] == 1)
	wave_fleet.append({"id": 102, "owner": 2, "kind": "fighter", "at": 3, "route": [], "leg": 0.0, "position": ai_map["points"][3], "dest": -1})
	ECON._ai_wave_order(wave_state, wave_graph, 2, 1, 2, wave_fleet)
	assert(wave_state["ai_waves"][2]["members"].is_empty())
	ECON._move({"map": wave_graph}, wave_fleet[2], 10.0)
	ECON._ai_wave_order(wave_state, wave_graph, 2, 1, 2, wave_fleet)
	assert(wave_state["ai_waves"][2]["members"].size() == 3)
	for craft in wave_fleet:
		assert(craft["dest"] == 2 and not craft["route"].is_empty())
	wave_fleet.append({"id": 103, "owner": 2, "kind": "fighter", "at": 1, "route": [], "leg": 0.0, "position": ai_map["points"][1], "dest": -1})
	ECON._ai_wave_order(wave_state, wave_graph, 2, 1, 2, wave_fleet)
	assert(wave_fleet[3]["dest"] == 1 and wave_state["ai_waves"][2]["members"].size() == 3)
	assert(int(wave_state["ai_waves"][2]["target"]) == 2)
	wave_state["ships"] = wave_fleet
	ECON._sync_operations(wave_state)
	var wave_id: int = int(wave_state["operations"]["2:wave:2"]["id"])
	assert(wave_id == int(wave_state["ai_waves"][2]["operation_id"]))
	var saved_dest: int = int(wave_fleet[0]["dest"])
	wave_fleet[0]["dest"] = 1
	wave_fleet[0]["retreating"] = true
	ECON._sync_operations(wave_state)
	assert(int(wave_state["operations"]["2:wave:2"]["id"]) == wave_id)
	assert(wave_state["operations"]["2:wave:2"]["recovering"] == [100])
	assert(wave_state["operations"]["2:wave:2"]["members"].size() == 3)
	wave_fleet[0]["dest"] = saved_dest
	wave_fleet[0]["retreating"] = false
	for i in range(3):
		ECON._move({"map": wave_graph}, wave_fleet[i], 100.0)
	ECON._ai_wave_order(wave_state, wave_graph, 2, 1, 2, wave_fleet)
	assert(wave_state["ai_waves"][2]["members"].is_empty())
	for craft in wave_fleet:
		assert(craft["dest"] == 1)
	ECON._sync_operations(wave_state)
	assert(int(wave_state["ai_waves"][2]["operation_id"]) == wave_id)
	for craft in wave_fleet:
		ECON._move({"map": wave_graph}, craft, 100.0)
	ECON._ai_wave_order(wave_state, wave_graph, 2, 1, 2, wave_fleet)
	ECON._sync_operations(wave_state)
	assert(int(wave_state["operations"]["2:wave:2"]["id"]) == wave_id)
	var ai_state: Dictionary = ECON.create(ai_map, ai_roster, ids, false)
	# Mature empire fixture: test expansion and combat, not opening demographics.
	var ai_home: Dictionary = ai_state["planets"][1]
	ai_home["population"] = 350000.0
	ai_home["levels"]["Organics"] = 8
	ai_home["warehouse_level"] = 3
	for resource in ECON.RESOURCES:
		ai_home["stock"][resource] = 10000.0
	var saw_attack: bool = false
	var saw_logistics: bool = false
	for year in range(500):
		ECON.step(ai_state, 1.0)
		for craft in ai_state["ships"]:
			if int(craft["owner"]) != 2:
				continue
			if craft["kind"] == "fighter" and int(craft["dest"]) == 2:
				saw_attack = true
			elif craft["kind"] == "ship":
				saw_logistics = true
	assert(int(ai_state["planets"][3]["owner"]) == 2)
	assert(int(ai_state["planets"][4]["owner"]) == 2)
	assert(ai_state["planets"][0]["queue"].is_empty())
	assert(saw_attack and saw_logistics)
	# Generated maps, not only a toy graph: each AI builds real ships early.
	for seed_value in [11, 83, 470, 1337]:
		var startup_map: Dictionary = _planetary_fixture(seed_value, 3, "Grid")
		var startup_state: Dictionary = ECON.create(startup_map, {1: {"team": 1}, 2: {"team": 1, "ai": true}, 3: {"team": 1, "ai": true}}, ids, false)
		for index in [1, 2]:
			startup_state["planets"][index]["population"] = 150000.0
			startup_state["planets"][index]["levels"]["Organics"] = 3
			for resource in ECON.RESOURCES:
				startup_state["planets"][index]["stock"][resource] = 2000.0
		var built: Dictionary = {2: {}, 3: {}}
		for year in range(36):
			ECON.step(startup_state, 1.0)
			for craft in startup_state["ships"]:
				if built.has(int(craft["owner"])):
					built[int(craft["owner"])][craft["kind"]] = true
		for player in [2, 3]:
			assert(built[player].has("colony_ship"))
			assert(built[player].has("fighter"))
	print("PASS: six-hit combat, allied safety, AI expansion, logistics and attack")
	# Only a station claims territory; ships, population and modules alone do not.
	var territory: Dictionary = ECON.create(force_map, players, ids, false)
	var sectors: Array[int] = ECON.territory_claims(territory)
	assert(sectors[0] == 1 and sectors[1] == 1 and sectors[2] == 2 and sectors[3] == 0)
	territory["ships"].append({"id": 100, "owner": 1, "kind": "fighter", "at": 3, "route": [], "leg": 0.0})
	territory["ships"].append({"id": 101, "owner": 2, "kind": "fighter", "at": field_node, "route": [], "leg": 0.0})
	sectors = ECON.territory_claims(territory)
	assert(sectors[3] == 0 and sectors[field_node] == 0)
	var empty: Dictionary = territory["planets"][3]
	empty["owner"] = 1
	territory["ships"][territory["ships"].size() - 2]["crew"] = 40000.0
	assert(ECON.territory_claims(territory)[3] == 0)
	empty["population"] = 1.0
	assert(ECON.territory_claims(territory)[3] == 0)
	empty["population"] = 0.0
	empty["yards"].append({"level": 1})
	assert(ECON.territory_claims(territory)[3] == 0)
	empty["station"] = {"hp": ECON.STATION_HP}
	assert(ECON.territory_claims(territory)[3] == 1)
	empty["yards"].clear()
	assert(ECON.territory_empires(territory)[3] == 1)
	empty["station"] = {}
	empty["owner"] = 0
	territory["ships"].append({"id": 102, "owner": 3, "kind": "fighter", "at": 3, "route": [], "leg": 0.0})
	territory["ships"].append({"id": 103, "owner": 3, "kind": "fighter", "at": 0, "route": [], "leg": 0.0})
	sectors = ECON.territory_claims(territory)
	assert(sectors[3] == 0 and sectors[0] == 0 and sectors[field_node] == 0)
	territory["ships"].pop_back()
	territory["ships"].pop_back()
	assert(ECON.territory_claims(territory)[0] == 1)
	territory["ships"][0]["route"] = [4]
	assert(ECON.territory_claims(territory)[3] == 0)
	print("PASS: resident and shipyard territory, no ship-only claims, contested suppression")
	print("PASS: seeded maps, ownership, construction, shipyards, mixed cargo, physical transit, ally sharing")
	# Shared operations retain identity across reinforcement and casualties,
	# distinguish owners, and remove empty groups without recycling IDs.
	var operation_state: Dictionary = ECON.create(graph, players, ids, false)
	var operation_fleet: Array = [
		{"id": 901, "owner": 1, "kind": "fighter", "at": 0, "dest": 2, "route": [2]},
		{"id": 902, "owner": 1, "kind": "fighter", "at": 0, "dest": 2, "route": [2]},
		{"id": 903, "owner": 2, "kind": "fighter", "at": 1, "dest": 2, "route": []}
	]
	operation_state["ships"] = operation_fleet
	ECON._sync_operations(operation_state)
	var operation_key: String = "1:allocation:2"
	var operation_id: int = int(operation_state["operations"][operation_key]["id"])
	assert(operation_state["operations"].size() == 2)
	assert(operation_state["operations"][operation_key]["members"] == [901, 902])
	assert(operation_state["operations"][operation_key]["moving"])
	operation_fleet.remove_at(0)
	ECON._sync_operations(operation_state)
	assert(operation_state["operations"][operation_key]["id"] == operation_id)
	assert(operation_state["operations"][operation_key]["members"] == [902])
	assert(operation_fleet[0]["operation_id"] == operation_id)
	operation_fleet[0]["dest"] = 0
	ECON._sync_operations(operation_state)
	assert(not operation_state["operations"].has(operation_key))
	assert(operation_fleet[0]["operation_id"] == operation_id)
	var replicated: Dictionary = bytes_to_var(var_to_bytes(operation_state))
	assert(replicated["operations"] == operation_state["operations"])
	# Human hostile orders assemble physically; objective membership is
	# independent of the current rally route. Neutral orders remain immediate.
	var rally_state: Dictionary = ECON.create(ai_map, players, ids, false)
	var rally_graph: Dictionary = ECON.military_graph(rally_state)
	var rally_fleet: Array = rally_state["ships"]
	for i in range(2):
		rally_fleet.append({"id": 950 + i, "owner": 2, "kind": "fighter", "at": 1, "route": [], "leg": 0.0, "position": ai_map["points"][1], "dest": -1})
	assert(ECON.set_military(rally_state, 2, "fighter", 2, 100))
	ECON._allocate_fighters(rally_state, rally_graph, 2, rally_fleet, true)
	ECON._sync_operations(rally_state)
	ECON._dispatch_operations(rally_state, rally_graph)
	var rally_key: String = "2:allocation:2"
	assert(rally_state["operations"][rally_key]["phase"] == "rallying")
	assert(rally_fleet[0]["dest"] == 1 and rally_fleet[1]["dest"] == 1)
	rally_fleet.append({"id": 952, "owner": 2, "kind": "fighter", "at": 3, "route": [], "leg": 0.0, "position": ai_map["points"][3], "dest": -1})
	ECON._allocate_fighters(rally_state, rally_graph, 2, rally_fleet, true)
	ECON._sync_operations(rally_state)
	ECON._dispatch_operations(rally_state, rally_graph)
	assert(rally_state["operations"][rally_key]["deployed"].is_empty())
	ECON._move({"map": rally_graph}, rally_fleet[2], 10.0)
	ECON._dispatch_operations(rally_state, rally_graph)
	assert(rally_state["operations"][rally_key]["deployed"].size() == 3)
	for craft in rally_fleet:
		assert(craft["dest"] == 2 and not craft["route"].is_empty())
	rally_fleet.append({"id": 953, "owner": 2, "kind": "fighter", "at": 1, "route": [], "leg": 0.0, "position": ai_map["points"][1], "dest": -1})
	ECON._allocate_fighters(rally_state, rally_graph, 2, rally_fleet, true)
	ECON._sync_operations(rally_state)
	ECON._dispatch_operations(rally_state, rally_graph)
	assert(rally_fleet[3]["dest"] == 1)
	assert(rally_state["operations"][rally_key]["deployed"].size() == 3)
	var rally_id: int = int(rally_state["operations"][rally_key]["id"])
	assert(ECON.set_military(rally_state, 2, "fighter", 3, 100))
	ECON._allocate_fighters(rally_state, rally_graph, 2, rally_fleet, true)
	ECON._sync_operations(rally_state)
	ECON._dispatch_operations(rally_state, rally_graph)
	assert(rally_state["operations"]["2:allocation:3"]["id"] == rally_id)
	for craft in rally_fleet:
		assert(craft["dest"] == 3)
	# Fighters break off their lane to orbit opponents, then resume their original route.
	var transit: Dictionary = ECON.create(ai_map, players, ids, false)
	var travelling: Dictionary = {"id": 970, "owner": 2, "kind": "fighter", "at": 1, "route": [3], "leg": 400.0, "position": Vector2(400, 0), "dest": 3, "hp": 100.0}
	var enemy: Dictionary = {"id": 971, "owner": 3, "kind": "fighter", "at": 3, "route": [], "leg": 0.0, "position": Vector2(450, 0), "dest": 3, "hp": 100.0}
	transit["ships"] = [travelling, enemy]
	assert(ECON.set_military(transit, 2, "fighter", 3, 100))
	var original_route: Array = travelling["route"].duplicate()
	for tick in range(8):
		var before: Vector2 = travelling["position"]
		ECON.step(transit, 0.1)
		assert(int(travelling["combat_target"]) == 971)
		assert(before.distance_to(travelling["position"]) <= ECON.ship_speed(str(travelling["kind"])) * 0.1 + 0.01)
		assert(before.distance_to(travelling["position"]) > 0.01)
		assert(travelling["route"] == original_route and int(travelling["at"]) == 1)
	assert(float(enemy["hp"]) < 100.0)
	assert(absf((travelling["position"] as Vector2).y) > 1.0)
	transit["ships"].erase(enemy)
	var disengaged_position: Vector2 = travelling["position"]
	ECON.step(transit, 0.1)
	assert(int(travelling["combat_target"]) == -1)
	assert(travelling["route"] == original_route)
	assert((travelling["position"] as Vector2).distance_to(ai_map["points"][3]) < disengaged_position.distance_to(ai_map["points"][3]))
	assert(disengaged_position.distance_to(travelling["position"]) <= ECON.ship_speed(str(travelling["kind"])) * 0.1 + 0.01)
	print("PASS: coordinated human rally, reinforcements, retargeting, combat circling and route resumption")
	# Pursuit retains a fleeing civilian beyond laser range, obeys the speed
	# budget and expires after three years even while the target remains nearby.
	var chase: Dictionary = ECON.create(ai_map, players, ids, false)
	# Isolate fighter pursuit behavior from longer-range fixed batteries.
	for system in chase["planets"]:
		system["pds"].clear()
	var hunter: Dictionary = {"id": 980, "owner": 2, "kind": "fighter", "at": 1, "route": [0], "leg": 0.0, "position": Vector2(50, 0), "dest": 0, "hp": 100.0}
	var prey: Dictionary = {"id": 981, "owner": 3, "kind": "colony_ship", "at": 1, "route": [3], "leg": 200.0, "position": Vector2(200, 0), "dest": 3, "hp": 100.0}
	chase["ships"] = [hunter, prey]
	assert(ECON.set_military(chase, 2, "fighter", 0, 100))
	for tick in range(30):
		var before: Vector2 = hunter["position"]
		ECON.step(chase, 0.1)
		assert(int(hunter["pursuit_target"]) == 981)
		assert(hunter["route"] == [0])
		assert(before.distance_to(hunter["position"]) <= ECON.ship_speed(str(hunter["kind"])) * 0.1 + 0.01)
		assert((hunter["position"] as Vector2).x > before.x)
	hunter["pursuit_left"] = 0.0
	prey["position"] = (ai_map["points"][3] as Vector2)
	prey["at"] = 3
	prey["route"] = []
	var expired_at: Vector2 = hunter["position"]
	ECON.step(chase, 0.1)
	assert(int(hunter["pursuit_target"]) == -1)
	assert((hunter["position"] as Vector2).x < expired_at.x)
	assert(hunter["pursuit_blocked"].has(981))
	ECON.step(chase, 0.1)
	assert(int(hunter["pursuit_target"]) == -1)
	# Separate scenario: a live target leaves range, pursuit persists but
	# laser damage does not. Explicitly reposition the fixture to model escape.
	var distant_chase: Dictionary = ECON.create(ai_map, players, ids, false)
	for system in distant_chase["planets"]:
		system["pds"].clear()
	var distant_hunter: Dictionary = {"id": 982, "owner": 2, "kind": "fighter", "at": 1, "route": [], "leg": 0.0, "position": Vector2.ZERO, "dest": 1, "hp": 100.0}
	var fleeing: Dictionary = {"id": 983, "owner": 3, "kind": "fighter", "at": 1, "route": [3], "leg": 0.0, "position": Vector2(150, 0), "heading": Vector2.RIGHT, "dest": 3, "hp": 100.0, "retreating": true}
	distant_chase["ships"] = [distant_hunter, fleeing]
	var distant_graph: Dictionary = ECON.military_graph(distant_chase)
	ECON._combat(distant_chase, distant_graph, 0.1)
	assert(int(distant_hunter["pursuit_target"]) == 983)
	fleeing["position"] = Vector2(300, 0)
	var hp_before: float = float(fleeing["hp"])
	ECON._combat(distant_chase, distant_graph, 1.0)
	assert(int(distant_hunter["pursuit_target"]) == 983 and int(distant_hunter["combat_target"]) == -1)
	assert(float(fleeing["hp"]) == hp_before)
	ECON._pursue_fighter(distant_hunter, fleeing["position"], 0.1)
	assert(is_equal_approx((distant_hunter["position"] as Vector2).length(), ECON.ship_speed(str(distant_hunter["kind"])) * 0.1))
	distant_hunter["pursuit_left"] = 0.0
	ECON._combat(distant_chase, distant_graph, 0.1)
	# An unheld fighter can acquire a hostile beyond weapon range in the same sector.
	var sector_map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(5000, 0)], "edges": [[0, 1]], "fields": []}
	var sector_state: Dictionary = ECON.create(sector_map, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var sector_graph: Dictionary = ECON.military_graph(sector_state)
	var sector_fighter: Dictionary = {"id": 986, "owner": 1, "kind": "fighter", "at": 0, "route": [], "position": Vector2.ZERO, "hp": 100.0}
	var sector_enemy: Dictionary = {"id": 987, "owner": 2, "kind": "ship", "at": 0, "route": [], "position": Vector2.RIGHT * (ECON.LASER_RANGE + 10.0), "hp": 100.0}
	sector_state["ships"] = [sector_fighter, sector_enemy]
	assert(ECON.local_sector(sector_graph, sector_enemy) == 0)
	ECON._combat(sector_state, sector_graph, 0.1)
	assert(sector_fighter["pursuit_target"] == 987 and sector_fighter["combat_target"] == -1)
	sector_fighter["holding"] = true
	ECON._combat(sector_state, sector_graph, 0.1)
	assert(sector_fighter["pursuit_target"] == -1)
	distant_chase["ships"].erase(fleeing)
	ECON._combat(distant_chase, distant_graph, 0.1)
	assert(int(distant_hunter["pursuit_target"]) == -1)
	print("PASS: bounded pursuit, escaping fighters, weapon range and route resumption")
	# Basic construction is independent of the advanced crystal supply.
	var bootstrap: Dictionary = ECON.create(graph, players, ids, false)
	var industry: Dictionary = bootstrap["planets"][0]
	for resource in ECON.RESOURCES:
		if resource == "Crystals":
			assert(is_zero_approx(ECON.rate(industry, resource)))
		else:
			assert(ECON.rate(industry, resource) > 0.0)
	var remaining_stock: Dictionary = industry["stock"].duplicate()
	for kind in ["fighter", "fighter", "ship", "miner"]:
		var cost: Dictionary = ECON._cost(kind, 1)
		assert(cost.size() == 2 and not cost.has("Crystals"))
		for material in cost:
			remaining_stock[material] -= float(cost[material])
			assert(float(remaining_stock[material]) >= 0.0)
	assert(float(remaining_stock["Metals"]) < float(ECON._cost("fighter", 1)["Metals"]))
	assert(ECON._cost("fighter", 1) == {"Metals": 270.0, "Organics": 10.0})
	assert(ECON._cost("pds", 1)["Crystals"] > 0.0)
	assert(ECON._cost("yard", 2)["Crystals"] > 0.0)
	assert(ECON._cost("laser_matrix", 1)["Crystals"] > 0.0)
	assert(not ECON.affordable(industry, ECON._cost("pds", 1)))
	assert(ECON.enqueue(bootstrap, 1, 0, "production", "Crystals"))
	assert(ECON.cancel(bootstrap, 1, 0, int(industry["queue"][0]["id"])))
	industry["population"] = ECON.HOME_POPULATION
	var metal_rate: float = ECON.rate(industry, "Metals")
	var before_stock: Dictionary = industry["stock"].duplicate()
	assert(not ECON.enqueue(bootstrap, 2, 0, "economy", "Metals"))
	assert(not ECON.enqueue(bootstrap, 1, 0, "economy", "unknown"))
	assert(ECON.building_available(industry, "Crystals"))
	assert(ECON.enqueue(bootstrap, 1, 0, "economy", "Metals"))
	var building: Dictionary = industry["queue"][0]
	assert(is_equal_approx(ECON.rate(industry, "Metals"), metal_rate))
	for material in building["cost"]:
		assert(is_equal_approx(float(industry["stock"][material]), float(before_stock[material]) - float(building["cost"][material])))
	assert(not ECON.enqueue(bootstrap, 1, 0, "economy", "Metals"))
	assert(ECON._advance(industry, building, float(building["work"])))
	ECON._finish(bootstrap, 0, industry, building)
	assert(is_equal_approx(ECON.rate(industry, "Metals"), metal_rate * 1.25))
	for material in ECON.ECONOMY_BUILDINGS["Metals"]["cost"]:
		assert(is_equal_approx(float(industry["stock"][material]), float(before_stock[material]) - float(ECON.ECONOMY_BUILDINGS["Metals"]["cost"][material])))
	assert(ECON.enqueue(bootstrap, 1, 0, "economy", "Metals"))
	var next_building: Dictionary = industry["queue"][0]
	for material in ECON.ECONOMY_BUILDINGS["Metals"]["cost"]:
		assert(is_equal_approx(float(next_building["cost"][material]), float(ECON.ECONOMY_BUILDINGS["Metals"]["cost"][material])))
	assert(ECON.cancel(bootstrap, 1, 0, int(next_building["id"])))
	industry["stock"]["Metals"] = 0.0
	assert(not ECON.enqueue(bootstrap, 1, 0, "economy", "Organics"))
	assert(not ECON.enqueue(bootstrap, 1, 0, "fighter"))
	assert(industry["queue"].is_empty())
	for material in ECON._cost("fighter", 1):
		industry["stock"][material] = maxf(float(industry["stock"][material]), float(ECON._cost("fighter", 1)[material]))
	var preallocation: Dictionary = industry["stock"].duplicate()
	assert(ECON.enqueue(bootstrap, 1, 0, "fighter"))
	var build: Dictionary = industry["queue"][0]
	ECON._advance(industry, build, 6.0)
	for material in build["cost"]:
		assert(float(build["allocated"][material]) > 0.0)
	assert(ECON.cancel(bootstrap, 1, 0, int(build["id"])))
	for material in preallocation:
		assert(is_equal_approx(float(industry["stock"][material]) + _cancelled_material(bootstrap, int(build["id"]), material), float(preallocation[material])))
	var timed_state: Dictionary = ECON.create(graph, players, ids, false)
	var timed_home: Dictionary = timed_state["planets"][0]
	assert(ECON.enqueue(timed_state, 1, 0, "economy", "Metals"))
	var timed_building: Dictionary = timed_home["queue"][0]
	assert(is_equal_approx(float(timed_building["work"]), 30.0))
	ECON._work_planet(timed_state, 0, 29.0)
	assert(is_equal_approx(float(timed_building["progress"]), 29.0))
	assert(int(timed_home["buildings"].get("Metals", 0)) == 0)
	ECON._work_planet(timed_state, 0, 1.0)
	assert(int(timed_home["buildings"].get("Metals", 0)) == 0 and timed_building.has("delivery_slot"))
	ECON._work_planet(timed_state, 0, ECON.PLANET_UPGRADE_DELIVERY_TIME)
	assert(int(timed_home["buildings"]["Metals"]) == 1)
	assert(timed_home["queue"].is_empty())
	print("PASS: multi-resource hulls, population gates and permanent local improvements")
	var warehouse_state: Dictionary = ECON.create(graph, players, ids, false)
	var depot: Dictionary = warehouse_state["planets"][0]
	# Isolate legacy linear planetary demand from exempt housing residents.
	depot["yards"].clear()
	depot["eco_population"] = 0.0
	depot["population"] = ECON.HOME_POPULATION
	assert(ECON.storage_capacity(depot) == 2000.0)
	assert(ECON.rate(depot, "Crystals") == ECON.STATION_CRYSTALS_PER_YEAR and ECON.consumption(depot, "Crystals") == 0.0)
	for resource in ["Metals", "Organics"]:
		var demand: float = ECON.consumption(depot, resource)
		assert(demand > 0.0)
		depot["population"] = ECON.HOME_POPULATION * 2.0
		assert(is_equal_approx(ECON.consumption(depot, resource), demand * 2.0))
		depot["population"] = ECON.HOME_POPULATION
	for resource in ["Metals", "Organics"]:
		var original: Dictionary = depot["thresholds"][resource].duplicate()
		depot["thresholds"][resource]["min"] = 0.0
		assert(is_zero_approx(ECON.civilian_stock_access(depot, resource)))
		depot["thresholds"][resource]["min"] = 1.0
		assert(ECON.civilian_stock_access(depot, resource) <= 20.0 + ECON.EPS)
		depot["thresholds"][resource] = original
	var limit: float = ECON.storage_capacity(depot)
	depot["stock"]["Metals"] = limit - 0.01
	ECON._work_planet(warehouse_state, 0, 1.0)
	assert(is_equal_approx(float(depot["stock"]["Metals"]), limit))
	assert(is_zero_approx(ECON.net_rate(depot, "Metals")))
	ECON._work_planet(warehouse_state, 0, 1.0)
	assert(is_equal_approx(float(depot["stock"]["Metals"]), limit))
	depot["levels"]["Metals"] = 0
	depot["stock"]["Metals"] = 100.0
	var metal_before: float = float(depot["stock"]["Metals"])
	ECON._work_planet(warehouse_state, 0, 1.0)
	assert(is_equal_approx(float(depot["stock"]["Metals"]), metal_before - ECON.consumption(depot, "Metals")))
	depot["stock"]["Metals"] = limit
	assert(not ECON.enqueue(warehouse_state, 2, 0, "economy", "warehouse"))
	assert(ECON.enqueue(warehouse_state, 1, 0, "economy", "warehouse"))
	assert(ECON.storage_capacity(depot) == 2000.0 and depot["queue"][-1]["kind"] == "warehouse")
	assert(not ECON.enqueue(warehouse_state, 1, 0, "economy", "warehouse"))
	assert(ECON._work("warehouse", 1) > 1.0)
	ECON._work_planet(warehouse_state, 0, 1.0)
	assert(ECON.storage_capacity(depot) == 2000.0 and ECON._has_job(depot, "warehouse", ""))
	ECON._work_planet(warehouse_state, 0, ECON._work("warehouse", 1) - 1.0)
	assert(ECON.storage_capacity(depot) == 5000.0)
	for level in [1, 2]:
		depot["population"] = float(ECON.WAREHOUSE_POPULATIONS[level])
		for material in ECON.WAREHOUSE_COSTS[level]:
			depot["stock"][material] = ECON.storage_capacity(depot)
		assert(ECON.enqueue(warehouse_state, 1, 0, "economy", "warehouse"))
		ECON._work_planet(warehouse_state, 0, ECON._work("warehouse", level + 1))
		assert(ECON.storage_capacity(depot) == ECON.WAREHOUSE_CAPACITIES[level + 1])
	assert(not ECON.enqueue(warehouse_state, 1, 0, "economy", "warehouse"))
	assert(float(ECON.empire_totals(warehouse_state, 1)["storage_reference"]["Crystals"]) == 30000.0)
	assert(ECON.consumption(depot, "Crystals") == 0.0)
	depot["levels"]["Crystals"] = 1
	depot["population"] = 500000.0
	assert(ECON.rate(depot, "Crystals") > 0.0 and ECON.rate(depot, "Crystals") <= ECON.PLANET_MINING_LIMIT + ECON.STATION_CRYSTALS_PER_YEAR)
	print("PASS: storage caps, three warehouse levels, advanced crystal extraction and linear consumption")
	# Formation slots are persistent, shared by AI/human operations, and
	# actual world-space positions converge without exceeding ship speed.
	var form: Dictionary = ECON.create(ai_map, players, ids, false)
	var form_graph: Dictionary = ECON.military_graph(form)
	var form_fleet: Array = []
	for i in range(4):
		form_fleet.append({"id": 1100 + i, "owner": 2, "kind": "fighter", "at": 1, "route": [3], "leg": 0.0, "position": Vector2.ZERO, "dest": 3})
	form["ships"] = form_fleet
	ECON._sync_operations(form)
	var form_key: String = "2:allocation:3"
	var form_slots: Dictionary = form["operations"][form_key]["slots"].duplicate()
	assert(form_slots.size() == 4)
	var former: int = int(form_slots[1101])
	form_fleet.remove_at(1)
	ECON._sync_operations(form)
	assert(int(form_fleet[1]["formation_slot"]) == int(form_slots[1102]))
	form_fleet.append({"id": 1104, "owner": 2, "kind": "fighter", "at": 1, "route": [3], "leg": 0.0, "position": Vector2.ZERO, "dest": 3})
	ECON._sync_operations(form)
	assert(int(form_fleet[-1]["formation_slot"]) == former)
	for tick in range(130):
		for craft in form_fleet:
			var before: Vector2 = craft["position"]
			ECON._move_formation(form_graph, craft, 0.1)
			assert(before.distance_to(craft["position"]) <= ECON.ship_speed(str(craft["kind"])) * 0.1 + 0.01)
	for craft in form_fleet:
		assert(int(craft["at"]) == 3 and (craft["route"] as Array).is_empty())
		assert((craft["position"] as Vector2).distance_to(ai_map["points"][3]) <= ECON.AI_RALLY_RADIUS)
		for other in form_fleet:
			if craft["id"] != other["id"]:
				assert((craft["position"] as Vector2).distance_to(other["position"]) > 10.0)
	var formation_replica: Dictionary = bytes_to_var(var_to_bytes(form))
	assert(formation_replica["operations"][form_key]["slots"] == form["operations"][form_key]["slots"])
	form["ai_players"] = [2]
	form["ai_waves"][2] = {"members": [1100, 1102, 1103, 1104]}
	ECON._sync_operations(form)
	assert(form["operations"]["2:wave:3"]["slots"].size() == 4)
	assert(form["operations"]["2:wave:3"]["phase"] == "deployed")
	assert(form["operations"]["2:wave:3"]["deployed"].size() == 4)
	print("PASS: persistent formation slots, casualty/reinforcement, bounded movement and shared AI/human slots")
	# Shared travel: a leading craft cannot race ahead on the same lane;
	# everyone crosses the next waypoint together after catching up.
	var cohesion: Dictionary = ECON.create(ai_map, players, ids, false)
	var cohesion_graph: Dictionary = ECON.military_graph(cohesion)
	var lead: Dictionary = {"id": 1200, "owner": 2, "kind": "fighter", "at": 1, "route": [3], "leg": 250.0, "position": Vector2(250, 0), "dest": 3}
	var lag: Dictionary = {"id": 1201, "owner": 2, "kind": "fighter", "at": 1, "route": [3], "leg": 0.0, "position": Vector2.ZERO, "dest": 3}
	cohesion["ships"] = [lead, lag]
	ECON._sync_operations(cohesion)
	for tick in range(200):
		var before_lead: Vector2 = lead["position"]
		var before_lag: Vector2 = lag["position"]
		ECON._coordinate_formations(cohesion, cohesion_graph, 0.1)
		assert(before_lead.distance_to(lead["position"]) <= ECON.ship_speed(str(lead["kind"])) * 0.1 + 0.01)
		assert(before_lag.distance_to(lag["position"]) <= ECON.ship_speed(str(lag["kind"])) * 0.1 + 0.01)
		assert(int(lead["at"]) == int(lag["at"]))
		if tick == 0:
			assert(lead["position"] == before_lead)
		if int(lead["at"]) == 3:
			break
	assert(int(lead["at"]) == 3 and int(lag["at"]) == 3)
	assert((lead["position"] as Vector2).distance_to(lag["position"]) < 50.0)
	# Individual withdrawal: nearest safe owned shipyard, no firing or
	# repair in transit, full recovery before rejoining the assigned objective.
	var recovery: Dictionary = ECON.create(ai_map, players, ids, false)
	var recovery_graph: Dictionary = ECON.military_graph(recovery)
	var wounded: Dictionary = {"id": 1210, "owner": 2, "kind": "fighter", "at": 1, "route": [3], "leg": 400.0, "position": Vector2(400, 0), "dest": 3, "operation_target": 3, "hp": ECON.WITHDRAW_HP}
	recovery["ships"] = [wounded]
	assert(ECON.set_autocast(recovery, 2, [1210], "retreat", true))
	assert(ECON.set_military(recovery, 2, "fighter", 3, 100))
	ECON._prepare_withdrawals(recovery, recovery_graph)
	assert(wounded["retreating"] and int(wounded["repair_site"]) == 1)
	assert(int(wounded["operation_target"]) == 3)
	var wound_position: Vector2 = wounded["position"]
	ECON.step(recovery, 0.1)
	assert((wounded["position"] as Vector2).x < wound_position.x)
	assert(float(wounded["hp"]) == ECON.WITHDRAW_HP)
	assert(not ECON._engaged(wounded))
	for tick in range(200):
		var before: Vector2 = wounded["position"]
		ECON.step(recovery, 0.1)
		assert(before.distance_to(wounded["position"]) <= ECON.ship_speed(str(wounded["kind"])) * 0.1 + 0.01)
		if not wounded["retreating"]:
			break
	assert(not wounded["retreating"] and float(wounded["hp"]) == ECON.SHIP_HP)
	assert((wounded["position"] as Vector2).distance_to(ECON.station_position(recovery, 1, float(recovery["elapsed"]))) > ECON.EPS)
	ECON.step(recovery, 0.1)
	assert(int(wounded["dest"]) == 3 and not (wounded["route"] as Array).is_empty())
	var hostile_repair: Dictionary = {"id": 1211, "owner": 3, "kind": "fighter", "at": 1, "route": [], "leg": 0.0, "position": Vector2.ZERO, "dest": 1, "hp": 100.0}
	var safety: Dictionary = {}
	assert(ECON._cached_repair_site_safe(recovery, recovery_graph, 2, 1, safety))
	recovery["ships"].append(hostile_repair)
	assert(not ECON._repair_site_safe(recovery, recovery_graph, 2, 1))
	assert(not ECON._cached_repair_site_safe(recovery, recovery_graph, 2, 1, {}))
	print("PASS: shared lane pacing, safe individual withdrawal, full repair and rejoining")
	var crew_state: Dictionary = ECON.create(graph, players, ids, false)
	var crew_home: Dictionary = crew_state["planets"][0]
	crew_home["population"] = 150000.0
	for kind in ECON.SHIP_KINDS:
		var people: float = float(ECON.CREW_COSTS[kind])
		assert(people == float({"colony_ship": 40000.0, "ship": 2000.0, "fighter": 500.0, "miner": 750.0, "science_ship": 2000.0}[kind]))
		assert(ECON.enqueue(crew_state, 1, 0, kind))
		var crew_job: Dictionary = crew_home["queue"][0]
		var original_population: float = float(crew_home["population"])
		ECON._advance(crew_home, crew_job, float(crew_job["work"]) * 0.25)
		assert(is_equal_approx(float(crew_job["population_allocated"]), people * 0.25))
		assert(is_equal_approx(float(crew_home["population"]), original_population - people * 0.25))
		assert(ECON.cancel(crew_state, 1, 0, int(crew_job["id"])))
		assert(is_equal_approx(float(crew_home["population"]), original_population))
	crew_home["population"] = 1.0
	assert(ECON.enqueue(crew_state, 1, 0, "fighter"))
	assert(is_zero_approx(ECON._possible(crew_home, crew_home["queue"][0])))
	crew_home["population"] = 1000.0
	var crew_order: Dictionary = crew_home["queue"][0]
	assert(ECON._advance(crew_home, crew_order, float(crew_order["work"])))
	ECON._finish(crew_state, 0, crew_home, crew_order)
	assert(is_equal_approx(float(crew_home["population"]), 500.0))
	assert(is_equal_approx(float(crew_state["ships"][0]["crew"]), 500.0))
	print("PASS: proportional crew costs, refunds, population starvation and completed crew")
	var opening: Dictionary = ECON.create(graph, players, ids)
	assert(opening["ships"].size() == ids.size() * 6)
	for owner in ids:
		var opening_home: int = ECON.military_home(opening, owner)
		var miners: int = 0
		var fighters: int = 0
		var freighters: int = 0
		var spawned: Array[Vector2] = []
		for craft in opening["ships"]:
			if int(craft["owner"]) == owner:
				assert(int(craft["at"]) == opening_home and ECON.sector_contains(ECON.military_graph(opening), opening_home, craft["position"]))
				for other in spawned:
					assert(other.distance_to(craft["position"]) >= ECON.SHIP_CLEARANCE - ECON.EPS)
				spawned.append(craft["position"])
				miners += 1 if craft["kind"] == "miner" else 0
				fighters += 1 if craft["kind"] == "fighter" else 0
				if craft["kind"] == "ship":
					freighters += 1
					assert(ECON._cargo_total(craft) == 0.0 and ECON.autocast_enabled(craft, "trade"))
					assert(is_equal_approx(float(craft["crew"]), float(ECON.CREW_COSTS["ship"])))
		assert(miners == 3 and fighters == 2 and freighters == 1)
		assert(opening["planets"][opening_home]["stock"] == ECON.STARTING_STOCK)
		assert(opening["planets"][opening_home]["population"] == ECON.HOME_POPULATION + ECON.ORBITAL_HOUSING_POPULATION)
		var starting_defenses: Dictionary = opening["planets"][opening_home]["pds"]
		assert(starting_defenses.size() == 1 and starting_defenses.has(0))
		assert(float(starting_defenses[0]["hp"]) == ECON.PDS_HP)
	for planet in opening["planets"]:
		if not planet["home"]:
			assert(planet["pds"].is_empty())
	var defenses: Dictionary = ECON.create(force_map, players, ids, false)
	var defended: Dictionary = defenses["planets"][0]
	assert(int(defended["planet_count"]) == ECON.system_bodies(defended, int(force_map["seed"]), 0).size())
	assert(not ECON.enqueue(defenses, 1, 0, "pds", "0"))
	# System commands choose the first undefended slot and charge a flat recipe.
	var targeted: Dictionary = ECON.create(force_map, players, ids, false)
	var target_home: Dictionary = targeted["planets"][0]
	target_home["pds"].clear()
	var target_recipe: Dictionary = ECON._cost("pds", 2)
	for material in target_recipe:
		target_home["stock"][material] = target_recipe[material]
	assert(not ECON.enqueue(targeted, 2, 0, "pds", "1"))
	assert(not ECON.enqueue(targeted, 1, 0, "pds", "invalid"))
	assert(not ECON.enqueue(targeted, 1, 0, "pds", "-1"))
	assert(not ECON.enqueue(targeted, 1, 0, "pds", "1"))
	assert(ECON.enqueue(targeted, 1, 0, "pds"))
	var target_job: Dictionary = ECON.pds_job(target_home)
	assert(target_job["target"] == "0" and target_job["cost"] == target_recipe)
	assert(not ECON.enqueue(targeted, 1, 0, "pds", "0"))
	for material in target_recipe:
		assert(is_zero_approx(float(target_home["stock"][material])))
	assert(ECON.cancel(targeted, 1, 0, int(target_job["id"])))
	for material in target_recipe:
		assert(is_equal_approx(float(target_home["stock"][material]), float(target_recipe[material])))
		assert(is_zero_approx(_cancelled_material(targeted, int(target_job["id"]), material)))
	assert(ECON.enqueue(targeted, 1, 0, "pds"))
	target_job = ECON.pds_job(target_home)
	assert(ECON._advance(target_home, target_job, float(target_job["work"])))
	ECON._finish(targeted, 0, target_home, target_job)
	assert(target_home["pds"].has(0) and not target_home["pds"].has(1))
	assert(ECON._cost("pds", 1) == ECON._cost("pds", 3))
	assert(not ECON.enqueue(targeted, 1, 0, "pds", "1"))
	# Test construction of a destroyed battery in its original slot.
	defended["pds"].clear()
	defended["stock"]["Crystals"] = float(ECON._cost("pds", 1)["Crystals"])
	assert(not ECON.enqueue(defenses, 2, 0, "pds", "0"))
	assert(not ECON.enqueue(defenses, 1, 0, "pds", "99"))
	assert(ECON.enqueue(defenses, 1, 0, "pds"))
	assert(not ECON.enqueue(defenses, 1, 0, "pds", "0"))
	var first_defense: Dictionary = ECON.pds_job(defended)
	ECON._advance(defended, first_defense, 1.0)
	var refund: float = float(defended["stock"]["Metals"]) + float(first_defense["allocated"]["Metals"])
	assert(ECON.cancel(defenses, 1, 0, int(first_defense["id"])))
	assert(is_equal_approx(float(defended["stock"]["Metals"]) + _cancelled_material(defenses, int(first_defense["id"]), "Metals"), refund))
	for material in first_defense["allocated"]:
		defended["stock"][material] += float(first_defense["allocated"][material]) # separate funds for next build
	assert(ECON.enqueue(defenses, 1, 0, "pds"))
	first_defense = ECON.pds_job(defended)
	assert(ECON._advance(defended, first_defense, float(first_defense["work"])))
	ECON._finish(defenses, 0, defended, first_defense)
	var center: Vector2 = force_map["points"][0]
	var defense_enemy: Dictionary = {"id": 40001, "owner": 3, "kind": "ship", "at": 0, "route": [], "leg": 0.0, "position": center + Vector2(100, 0), "hp": 100.0}
	var friendly: Dictionary = {"id": 40002, "owner": 2, "kind": "ship", "at": 0, "route": [], "leg": 0.0, "position": center, "hp": 100.0}
	defenses["ships"] = [defense_enemy, friendly]
	var defense_graph: Dictionary = ECON.military_graph(defenses)
	ECON._combat(defenses, defense_graph, 0.1)
	assert(float(defense_enemy["hp"]) == 100.0 - 2.0 * ECON.LASER_DAMAGE and float(friendly["hp"]) == 100.0)
	ECON._combat(defenses, defense_graph, 0.1)
	assert(float(defense_enemy["hp"]) == 64.0)
	assert(ECON.PDS_RANGE == 2.0 * ECON.LASER_RANGE)
	defense_enemy["position"] = center + Vector2(ECON.PDS_RANGE - 1.0, 0)
	ECON._combat(defenses, defense_graph, 1.0)
	assert(float(defense_enemy["hp"]) == 28.0 and float(friendly["hp"]) == 100.0)
	defense_enemy["position"] = center + Vector2(ECON.PDS_RANGE + 1.0, 0)
	ECON._combat(defenses, defense_graph, 1.0)
	assert(float(defense_enemy["hp"]) == 28.0)
	for slot in range(1, int(defended["planet_count"])):
		for material in ECON._cost("pds", slot + 1):
			defended["stock"][material] = ECON._cost("pds", slot + 1)[material]
		assert(ECON.enqueue(defenses, 1, 0, "pds"))
		var battery_order: Dictionary = ECON.pds_job(defended)
		assert(ECON._advance(defended, battery_order, float(battery_order["work"])))
		ECON._finish(defenses, 0, defended, battery_order)
	assert(not ECON.enqueue(defenses, 1, 0, "pds"))
	assert(defended["pds"].size() == int(defended["planet_count"]))
	print("PASS: starting fleet, planet-limited defenses, refunds, damage, cooldown and allied safety")
	# Neutral asteroid anchor, with physical return to an owned depot.
	var neutral_mine: Dictionary = ECON.create(mineral_map.duplicate(true), players, ids, false)
	var neutral_map: Dictionary = neutral_mine["map"]
	var neutral_anchor: int = 3
	neutral_map["field_edges"] = []
	neutral_map["fields"] = [{"anchor": neutral_anchor, "position": mineral_points[neutral_anchor] + Vector2(30, 0), "Metals": 1.0, "Crystals": 1.0, "chunks": [{"id": 10001, "position": mineral_points[neutral_anchor] + Vector2(30, 0), "resource": "Crystals", "remaining": 20.0}]}]
	if not MAP.linked(neutral_map, 0, neutral_anchor):
		neutral_map["edges"].append([0, neutral_anchor])
	var neutral_depot: Dictionary = neutral_mine["planets"][0]
	ECON._finish(neutral_mine, 0, neutral_depot, {"id": 90101, "kind": "miner", "population_allocated": 30.0})
	for tick in range(1600):
		ECON.step(neutral_mine, 0.5)
		if float(neutral_depot["stock"]["Crystals"]) - float(neutral_mine["elapsed"]) * ECON.STATION_CRYSTALS_PER_YEAR >= 20.0 - ECON.EPS:
			break
	assert(is_equal_approx(float(neutral_depot["stock"]["Crystals"]), 20.0 + float(neutral_mine["elapsed"]) * ECON.STATION_CRYSTALS_PER_YEAR))
	assert(ECON.field_inventory(neutral_map["fields"][0])["Crystals"] == 0.0)
	var multi_access: Dictionary = ECON.create(mineral_map.duplicate(true), players, ids, false)
	var access_map: Dictionary = multi_access["map"]
	var access_points: Array = access_map["points"]
	var access_center: Vector2 = (access_points[0] + access_points[1]) * 0.5
	var access_field: Dictionary = {"anchor": 1, "access": [0, 1], "position": access_center, "radius": 40.0, "Metals": 1.0, "Crystals": 1.0, "chunks": [{"id": 92001, "position": access_center, "resource": "Crystals", "remaining": 20.0}]}
	access_map["field_edges"] = []
	access_map["fields"] = [access_field]
	var access_home: Dictionary = multi_access["planets"][0]
	assert(ECON.field_access_systems(access_map, access_field).has(0))
	ECON._finish(multi_access, 0, access_home, {"id": 92002, "kind": "miner", "population_allocated": 30.0})
	var access_miner: Dictionary = multi_access["ships"][0]
	# The original anchor is not the local entrance. Prefer direct
	# access despite an off-center deposit closer to the other system.
	access_field["access"] = [1, 0]
	access_field["chunks"][0]["position"] = access_center.lerp(access_points[1], 0.8)
	ECON._choose_field(multi_access, access_miner, ECON.planet_teams(multi_access), {})
	assert(int(access_miner.get("mining_anchor", -1)) == 0)
	assert(access_miner["route"].is_empty())
	var was_loaded: bool = false
	for tick in range(1600):
		ECON.step(multi_access, 0.5)
		if not was_loaded and float(access_miner["cargo"]["Crystals"]) > ECON.EPS:
			assert(is_equal_approx(float(access_home["stock"]["Crystals"]), float(multi_access["elapsed"]) * ECON.STATION_CRYSTALS_PER_YEAR))
			was_loaded = true
		if float(access_home["stock"]["Crystals"]) - float(multi_access["elapsed"]) * ECON.STATION_CRYSTALS_PER_YEAR >= 20.0 - ECON.EPS:
			assert((access_miner["position"] as Vector2).distance_to(ECON.station_position(multi_access, 0, float(multi_access["elapsed"]))) <= ECON.STATION_DOCK_RANGE + ECON.SHIP_CLEARANCE + ECON.EPS)
			assert(ECON.local_flow(access_home, "Mining deliveries", "Crystals") > 0.0)
			break
	assert(was_loaded and is_equal_approx(float(access_home["stock"]["Crystals"]), 20.0 + float(multi_access["elapsed"]) * ECON.STATION_CRYSTALS_PER_YEAR))
	var staffed_state: Dictionary = ECON.create(graph, players, ids, false)
	var staffed_home: Dictionary = staffed_state["planets"][0]
	staffed_home["yards"].append({"level": 1, "job": -1})
	staffed_home["yards"].append({"level": 1, "job": -1})
	staffed_home["population"] = 100.0
	assert(ECON.enqueue(staffed_state, 1, 0, "fighter"))
	var staffed_order: Dictionary = staffed_home["queue"][0]
	ECON._work_planet(staffed_state, 0, 1.0)
	assert(float(staffed_order["progress"]) == 0.0 and ECON.operational_shipyards(staffed_home) == 0)
	assert(ECON.construction_blockers(staffed_home, staffed_order).has("Population"))
	assert(ECON.local_flow(staffed_home, "Construction: fighter", "Metals") > 0.0)
	staffed_home["population"] = 1000.0
	ECON._work_planet(staffed_state, 0, 1.0)
	assert(float(staffed_order["progress"]) > 0.0 and ECON.operational_shipyards(staffed_home) == 1)
	assert(is_zero_approx(ECON.local_flow(staffed_home, "Construction: fighter", "Metals")))
	assert(ECON.local_flow(staffed_home, "Population", "Metals") > 0.0)
	staffed_home["population"] = 6000.0
	assert(ECON.operational_shipyards(staffed_home) == 2)
	staffed_home["population"] = 21000.0
	assert(ECON.operational_shipyards(staffed_home) == 3)
	print("PASS: neutral mining delivery and population-gated shipyards")
	quit(0)

func _test_neutral_direct_occupation() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(827, 2, "Grid"), {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var graph: Dictionary = ECON.military_graph(state)
	var neutral: int = -1
	for node in graph["adjacent"][0]:
		if node >= 2 and node < state["planets"].size():
			neutral = node
			break
	assert(neutral >= 0)
	var field: int = state["planets"].size()
	for i in range(3):
		state["ships"].append({"id": 9400 + i, "owner": 2 if i == 2 else 1, "kind": "fighter", "at": 0, "route": [], "leg": 0.0, "position": graph["points"][0], "dest": 0, "hp": ECON.SHIP_HP})
	assert(not ECON.command_fighters(state, 1, [9400, 9402], neutral))
	assert(not ECON.command_fighters(state, 1, [9400, 9400], neutral))
	assert(not ECON.command_fighters(state, 1, [9400], -1))
	assert(not ECON.command_fighters(state, 1, [9999], field))
	assert(state["ships"][0]["dest"] == 0)
	state["ships"].pop_back()
	assert(ECON.command_fighters(state, 1, [9400], neutral))
	assert(ECON.command_fighters(state, 1, [9401], field))
	ECON.step(state, 0.1)
	var held: Dictionary = state["ships"][0]
	var halted: Vector2 = held["position"]
	assert(not ECON.hold_fighters(state, 1, [9400, 9999]))
	assert(not ECON.hold_fighters(state, 1, [9400, 9400]))
	assert(not ECON.hold_fighters(state, 2, [9400]))
	assert(not held.get("holding", false))
	assert(ECON.hold_fighters(state, 1, [9400]))
	for tick in range(20):
		ECON.step(state, 0.1)
		assert(held["position"] == halted)
	assert(ECON.command_fighters(state, 1, [9400], neutral))
	assert(not held["holding"])
	for tick in range(300):
		ECON.step(state, 1.0)
		if state["ships"][0]["route"].is_empty() and state["ships"][1]["route"].is_empty():
			break
	assert(state["ships"][0]["at"] == neutral and state["ships"][1]["at"] == field)
	var claims: Array[int] = ECON.territory_claims(state)
	assert(claims[neutral] == 0 and claims[field] == 0)
	assert(int(state["planets"][neutral]["owner"]) == 0)
	assert(ECON.command_fighters(state, 1, [9400, 9401], 0))
	assert(state["ships"][0]["dest"] == 0 and state["ships"][1]["dest"] == 0)
	print("PASS: direct individual and group orders, atomic ownership, neutral occupation and retargeting")

func _test_idle_formations() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(827, 1, "Grid"), {1: {"team": 1}}, [1], false)
	var graph: Dictionary = ECON.military_graph(state)
	var center: Vector2 = graph["points"][0]
	for i in range(3):
		state["ships"].append({"id": 9500 + i, "owner": 1, "kind": "fighter", "at": 0, "route": [], "leg": 0.0, "position": center, "dest": 0, "hp": ECON.SHIP_HP})
	for i in range(2):
		state["ships"].append({"id": 9510 + i, "owner": 1, "kind": "colony_ship", "at": 0, "route": [], "leg": 0.0, "position": center, "dest": -1, "hp": ECON.SHIP_HP})
	var furthest: float = 0.0
	for tick in range(500):
		var before: Dictionary = {}
		for craft in state["ships"]:
			before[craft["id"]] = craft["position"]
		ECON.step(state, 0.1)
		for craft in state["ships"]:
			assert((craft["position"] as Vector2).distance_to(before[craft["id"]]) <= ECON.ship_speed(str(craft["kind"])) * 0.1 + 0.01)
			assert(int(craft["at"]) == 0 and (craft["route"] as Array).is_empty())
			assert(ECON.sector_contains(graph, 0, craft["position"]))
			furthest = maxf(furthest, (craft["position"] as Vector2).distance_to(center))
	assert(furthest > ECON.AI_RALLY_RADIUS * 2.0)
	var squad: Array = state["ships"]
	var distance_traveled: float = 0.0
	# Sample over several years: the seeded radial wander can slow near an
	# extremum of its path without actually becoming stationary.
	for tick in range(100):
		var old_position: Vector2 = squad[0]["position"]
		ECON.step(state, 0.1)
		distance_traveled += (squad[0]["position"] as Vector2).distance_to(old_position)
	assert(distance_traveled > 5.0)
	assert((squad[0]["position"] as Vector2).distance_to(squad[1]["position"]) > 10.0)
	assert((squad[0]["position"] as Vector2).distance_to(squad[1]["position"]) < 45.0)
	assert((squad[3]["position"] as Vector2).distance_to(squad[4]["position"]) < 45.0)
	var objective: int = int(graph["adjacent"][0][0])
	assert(ECON.command_fighters(state, 1, [9500, 9501, 9502], objective))
	ECON.step(state, 0.1)
	for i in range(3):
		assert(int(squad[i]["dest"]) == objective and not (squad[i]["route"] as Array).is_empty())
	print("PASS: authoritative idle formations wander, preserve bounds and resume direct navigation")

func _test_unit_order_queue() -> void:
	var curve: Array = ECON.polyline_formation_slots({1: Vector2(0, -50), 2: Vector2(80, -50), 3: Vector2(100, 150)}, PackedVector2Array([Vector2.ZERO, Vector2(100, 0), Vector2(100, 100)]))
	assert(curve.size() == 3 and curve[0]["point"] == Vector2.ZERO and curve[1]["point"] == Vector2(100, 0) and curve[2]["point"] == Vector2(100, 100))
	assert(absf((curve[2]["heading"] as Vector2).dot(Vector2.DOWN)) < ECON.EPS)
	var slots: Array = ECON.line_formation_slots({1: Vector2(100, 0), 2: Vector2(-100, 0), 3: Vector2.ZERO}, Vector2(-200, 100), Vector2(200, 100))
	assert(slots.size() == 3 and slots[0]["id"] == 2 and slots[1]["id"] == 3 and slots[2]["id"] == 1)
	assert(slots[0]["point"] == Vector2(-200, 100) and slots[1]["point"] == Vector2(0, 100) and slots[2]["point"] == Vector2(200, 100))
	assert(slots[0]["heading"] == Vector2.DOWN and slots[1]["heading"] == Vector2.DOWN and slots[2]["heading"] == Vector2.DOWN)
	var reversed: Array = ECON.line_formation_slots({1: Vector2(100, 0), 2: Vector2(-100, 0)}, Vector2(200, 100), Vector2(-200, 100))
	assert(reversed[0]["id"] == 1 and reversed[0]["heading"] == Vector2.DOWN)
	var map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(2000, 0)], "edges": [[0, 1]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}}, [1], false)
	var ship: Dictionary = {"id": 100, "owner": 1, "kind": "fighter", "origin": 0, "at": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": Vector2.ZERO, "heading": Vector2.UP, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock()}
	state["ships"] = [ship]
	var graph: Dictionary = ECON.military_graph(state)
	var first: Dictionary = {"kind": "position", "target": 0, "point": Vector2(100, 100), "move_only": true}
	var second: Dictionary = {"kind": "position", "target": 0, "point": Vector2(200, 100), "move_only": false}
	var third: Dictionary = {"kind": "position", "target": 0, "point": Vector2(200, 200), "move_only": true, "heading": Vector2.LEFT}
	assert(ECON.issue_unit_order(state, 1, [100], first, false))
	assert(ECON.issue_unit_order(state, 1, [100], second, true))
	assert(ECON.issue_unit_order(state, 1, [100], third, true))
	assert(not ECON.issue_unit_order(state, 2, [100], first, true))
	assert(not ECON.issue_unit_order(state, 1, [100], {"kind": "position", "target": 0, "point": Vector2.INF}, true))
	assert(ship["local_move_target"] == first["point"] and ship["order_queue"].size() == 2)
	assert(ECON.unit_order_origin(state, graph, ship) == third["point"])
	var visited: Array = []
	for tick in range(500):
		var previous: Vector2 = ship["position"]
		ECON.step(state, 0.1)
		assert(previous.distance_to(ship["position"]) <= ECON.ship_speed(str(ship["kind"])) * 0.1 + ECON.EPS)
		if not ship.has("local_move_target") and ship["position"] in [first["point"], second["point"], third["point"]] and not visited.has(ship["position"]):
			visited.append(ship["position"])
		if visited.size() == 3:
			break
	assert(visited == [first["point"], second["point"], third["point"]])
	assert(ship["position"] == third["point"] and ship["heading"] == Vector2.LEFT and not ship.get("holding", false))
	assert(is_equal_approx(ECON.arrival_wait_remaining(state, ship), ECON.AUTOCAST_COOLDOWN_YEARS))
	for tick in range(299):
		ECON.step(state, 0.1)
		assert(ship["position"] == third["point"] and ship["heading"] == Vector2.LEFT and not ship.get("holding", false))
	var wander_distance: float = 0.0
	for tick in range(20):
		var previous: Vector2 = ship["position"]
		ECON.step(state, 0.1)
		wander_distance += previous.distance_to(ship["position"])
	assert(wander_distance > ECON.EPS and ECON._is_idle_ship(ship))
	assert(ECON.issue_unit_order(state, 1, [100], first, false))
	for i in range(ECON.MAX_UNIT_ORDERS - 1):
		assert(ECON.issue_unit_order(state, 1, [100], second, true))
	assert(not ECON.issue_unit_order(state, 1, [100], third, true))
	assert(ship["order_queue"].size() == ECON.MAX_UNIT_ORDERS - 1)
	assert(ECON.issue_unit_order(state, 1, [100], third, false))
	assert(not ship.has("order_queue"))
	assert(ECON.issue_unit_order(state, 1, [100], first, true))
	assert(ECON.command_hold_units(state, 1, [100], false))
	assert(not ship.has("order_queue") and not ship.has("unit_order") and ship["holding"])
	# A queued precise move can be validated against the preceding sector
	# destination, rather than the ship's current physical location.
	assert(ECON.command_fighters(state, 1, [100], 1, true))
	var remote: Dictionary = {"kind": "position", "target": 1, "point": Vector2(2000, 100), "move_only": true, "heading": Vector2.DOWN}
	assert(ECON.issue_unit_order(state, 1, [100], remote, true))
	for tick in range(1000):
		ECON.step(state, 0.1)
		if ship["position"] == remote["point"] and not ship.has("local_move_target"):
			break
	assert(ship["position"] == remote["point"] and ship["heading"] == Vector2.DOWN and ship["at"] == 1)
	ECON.step(state, 0.1)
	assert(ship["position"] == remote["point"] and ECON.arrival_wait_remaining(state, ship) > 29.0)
	assert(ECON.command_hold_units(state, 1, [100], false))
	assert(ECON.arrival_wait_remaining(state, ship) == 0.0)
	var held_point: Vector2 = ship["position"]
	for tick in range(10):
		ECON.step(state, 0.1)
	assert(ship["position"] == held_point and not ECON._is_idle_ship(ship))
	assert(ECON.command_fighters(state, 1, [100], 0, true))
	for tick in range(2000):
		ECON.step(state, 0.1)
		if ECON.arrival_wait_remaining(state, ship) > 0.0:
			break
	assert(int(ship["at"]) == 0 and (ship["route"] as Array).is_empty())
	assert(ECON.arrival_wait_remaining(state, ship) > 29.0)
	var sector_arrival: Vector2 = ship["position"]
	for tick in range(299):
		ECON.step(state, 0.1)
		assert(ship["position"] == sector_arrival)
	print("PASS: sequential orders, queue limits, formation facing, 30-year precise and sector arrival waits, hold override")

func _test_follow_order() -> void:
	var map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(2000, 0), Vector2(4000, 0)], "edges": [[0, 1], [1, 2]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}}, [1], false)
	state["ships"].clear()
	for k in range(2):
		state["ships"].append({"id": 9840 + k, "owner": 1, "kind": "fighter" if k == 0 else "colony_ship", "origin": 0, "at": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": Vector2(0, 350 * k), "heading": Vector2.UP, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock(), "wander_auto": false, "salvage_auto": false})
	var follower: Dictionary = state["ships"][0]
	var leader: Dictionary = state["ships"][1]
	var order: Dictionary = {"kind": "follow", "target": 9841, "guard": true}
	assert(not ECON.issue_unit_order(state, 2, [9840], order, false))
	assert(not ECON.issue_unit_order(state, 1, [9840], {"kind": "follow", "target": 9840}, false))
	assert(not ECON.issue_unit_order(state, 1, [9840], {"kind": "follow", "target": 99999}, false))
	assert(ECON.issue_unit_order(state, 1, [9840], order, false))
	assert(not ECON.issue_unit_order(state, 1, [9841], {"kind": "follow", "target": 9840}, false))
	for tick in range(150):
		ECON.step(state, 0.1)
		if bool(follower.get("follow_arrived", false)):
			break
	assert(bool(follower.get("follow_arrived", false)))
	var resting: Vector2 = follower["position"]
	for tick in range(20):
		ECON.step(state, 0.1)
		assert(follower["position"].is_equal_approx(resting))
	assert(ECON._unit_order_running(follower))
	assert(ECON.issue_unit_order(state, 1, [9841], {"kind": "position", "target": 1, "point": map["points"][1], "move_only": true}, false))
	for tick in range(1000):
		var before: Vector2 = follower["position"]
		ECON.step(state, 0.1)
		assert(before.distance_to(follower["position"]) <= ECON.ship_speed(str(follower["kind"])) * 0.1 + ECON.EPS)
		if not leader.has("local_move_target") and bool(follower.get("follow_arrived", false)):
			break
	assert((follower["position"] as Vector2).distance_to(leader["position"]) <= ECON.FOLLOW_DISTANCE + 1.0)
	assert(ECON._unit_order_running(follower))
	assert(ECON.command_hold_units(state, 1, [9840], false))
	assert(follower.get("unit_order", {}).get("kind", "") != "follow")
	assert(ECON.issue_unit_order(state, 1, [9840], order, false))
	state["ships"].erase(leader)
	ECON.step(state, 0.1)
	assert(follower.get("unit_order", {}).get("kind", "") != "follow")
	print("PASS: persistent friendly follow, standoff, lane travel, cycle/ownership validation and cancellation")

func _test_resource_handoff() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(827, 1, "Grid"), {1: {"team": 1}}, [1], false)
	var graph: Dictionary = ECON.military_graph(state)
	var point: Vector2 = graph["points"][0]
	var miner: Dictionary = {"id": 9820, "owner": 1, "kind": "miner", "at": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": point, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock(), "mining_mode": "delivery"}
	var freighter: Dictionary = {"id": 9821, "owner": 1, "kind": "ship", "at": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": point + Vector2.RIGHT * (ECON.RESOURCE_HANDOFF_RANGE + 1.0), "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock(), "resource_stage": {"node": 0, "anchor": 0, "point": point, "salvage_site": true}}
	miner["cargo"]["Metals"] = ECON.MINER_CAPACITY
	state["ships"] = [miner, freighter]
	var threats: Dictionary = ECON._salvage_threats(state, graph)
	assert(ECON._miner_handoff(state, graph, miner, [freighter], threats, 1.0) == 0.0)
	freighter["position"] = point
	freighter["owner"] = 2
	assert(ECON._miner_handoff(state, graph, miner, [freighter], threats, 1.0) == 0.0)
	freighter["owner"] = 1
	freighter["trade_auto"] = false
	assert(ECON._miner_handoff(state, graph, miner, [freighter], threats, 1.0) == 0.0)
	freighter["trade_auto"] = true
	assert(is_equal_approx(ECON._miner_handoff(state, graph, miner, [freighter], threats, 0.01), ECON.dropoff_rate("miner") * 0.01))
	assert(is_equal_approx(ECON._cargo_total(miner) + ECON._cargo_total(freighter), ECON.MINER_CAPACITY))
	freighter["cargo"]["Metals"] = 0.0
	var saved_stage: Dictionary = freighter["resource_stage"]
	freighter.erase("resource_stage")
	freighter["route"] = [1]
	miner["route"] = [1]
	miner["mining_mode"] = "idle"
	miner["cargo"]["Metals"] = ECON.MINER_CAPACITY
	assert(is_equal_approx(ECON._miner_handoff(state, graph, miner, [freighter], threats, 0.01), ECON.dropoff_rate("miner") * 0.01))
	assert(freighter["route"] == [1] and miner["route"] == [1])
	miner["mining_mode"] = "delivery"
	miner["cargo_order"] = {"kind": "deposit", "target": -2}
	assert(ECON._miner_handoff(state, graph, miner, [freighter], threats, 1.0) > 0.0)
	assert(not miner.has("cargo_order") and miner["route"].is_empty() and miner["mining_mode"] == "idle")
	assert(not miner.has("_handoff_delivery") and float(miner["next_mining_search"]) == 0.0)
	assert(miner["navigation_target"] == miner["position"])
	miner["cargo"]["Metals"] = ECON.MINER_CAPACITY - float(freighter["cargo"]["Metals"])
	assert(is_equal_approx(ECON._cargo_total(miner) + ECON._cargo_total(freighter), ECON.MINER_CAPACITY))
	freighter["cargo"]["Metals"] = 0.0
	freighter["route"] = []
	miner["route"] = []
	miner["mining_mode"] = "delivery"
	freighter["resource_stage"] = saved_stage
	assert(ECON.MINER_CAPACITY == 10.0 and ECON.CARGO_CAPACITY == 100.0)
	for load in range(10):
		state["elapsed"] += 1.0
		miner["cargo"]["Metals"] = ECON.MINER_CAPACITY
		assert(is_equal_approx(ECON._miner_handoff(state, graph, miner, [freighter], threats, 1.0), ECON.MINER_CAPACITY))
		assert(is_zero_approx(ECON._cargo_total(miner)))
		assert(not miner.has("_handoff_delivery") and miner["route"].is_empty())
		assert(is_equal_approx(ECON._cargo_total(freighter), ECON.MINER_CAPACITY * float(load + 1)))
		if load < 9:
			assert(float(freighter["resource_loaded_at"]) == float(state["elapsed"]))
			assert(freighter.has("resource_stage") and not freighter.get("salvage_delivery", false))
	assert(is_equal_approx(ECON._cargo_total(freighter), ECON.CARGO_CAPACITY))
	assert(not freighter.has("resource_stage") and bool(freighter["salvage_delivery"]))
	var pile: Dictionary = {"resource": "Metals", "amount": 100.0}
	miner["cargo"] = ECON.empty_stock()
	freighter["cargo"] = ECON.empty_stock()
	ECON._collect_salvage(miner, pile, 0.5)
	ECON._collect_salvage(freighter, pile, 0.5)
	assert(is_equal_approx(ECON._cargo_total(freighter), ECON._cargo_total(miner) * 0.25))
	assert(is_equal_approx(float(pile["amount"]) + ECON._cargo_total(miner) + ECON._cargo_total(freighter), 100.0))
	var staging_map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(5000, 0)], "edges": [[0, 1]], "fields": []}
	var staging: Dictionary = ECON.create(staging_map, {1: {"team": 1}}, [1], false)
	var stage_graph: Dictionary = ECON.military_graph(staging)
	var hauler: Dictionary = {"id": 9822, "owner": 1, "kind": "ship", "origin": 0, "at": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": Vector2.ZERO, "heading": Vector2.UP, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock(), "salvage_auto": false}
	staging["ships"] = [hauler]
	staging["planets"][0]["stock"]["Metals"] = 0.0
	var debris: Dictionary = {"id": 9823, "resource": "Metals", "amount": ECON.CARGO_CAPACITY - 1.0, "position": Vector2(100, 0), "claim": -1}
	staging["salvage"][9823] = debris
	var safe: Dictionary = ECON._salvage_threats(staging, stage_graph)
	assert(not ECON._choose_resource_stage(staging, stage_graph, hauler, ECON.planet_teams(staging), {}, safe, ECON._salvage_cells(staging["salvage"])))
	debris["amount"] = ECON.CARGO_CAPACITY
	assert(ECON._choose_resource_stage(staging, stage_graph, hauler, ECON.planet_teams(staging), {}, safe, ECON._salvage_cells(staging["salvage"])))
	assert(hauler.has("resource_stage"))
	hauler["cargo"]["Metals"] = 5.0
	hauler["resource_loaded_at"] = 0.0
	staging["elapsed"] = ECON.RESOURCE_PARTIAL_WAIT_YEARS - 0.1
	assert(ECON._work_resource_stage(staging, stage_graph, hauler, ECON.planet_teams(staging), {}, safe, ECON._salvage_cells(staging["salvage"]), {}, 0.1))
	assert(hauler.has("resource_stage") and not hauler.get("salvage_delivery", false))
	staging["elapsed"] = ECON.RESOURCE_PARTIAL_WAIT_YEARS
	assert(ECON._work_resource_stage(staging, stage_graph, hauler, ECON.planet_teams(staging), {}, safe, ECON._salvage_cells(staging["salvage"]), {}, 0.1))
	assert(hauler["salvage_delivery"] and not hauler.has("resource_stage"))
	var depot: Dictionary = staging["planets"][0]
	depot["stock"]["Metals"] = ECON.storage_capacity(depot)
	hauler["position"] = Vector2(100, 0)
	assert(ECON._work_salvage(staging, stage_graph, hauler, 100.0))
	assert((hauler["position"] as Vector2).distance_to(ECON.station_position(staging, 0, float(staging["elapsed"]))) <= ECON.STATION_DOCK_RANGE + ECON.EPS)
	assert(is_equal_approx(float(hauler["cargo"]["Metals"]), 5.0))
	assert(is_equal_approx(float(depot["stock"]["Metals"]), ECON.storage_capacity(depot)))
	depot["stock"]["Metals"] -= 5.0
	staging["elapsed"] += 1.0
	assert(ECON._work_salvage(staging, stage_graph, hauler, 100.0))
	assert(ECON._cargo_total(hauler) <= ECON.EPS)
	assert(is_equal_approx(float(depot["stock"]["Metals"]), ECON.storage_capacity(depot)))
	print("PASS: physical resource handoff, ownership, capacity, staging threshold, refreshed loading timer and inactivity dispatch and freighter salvage rate")

func _test_autocast_modes() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(827, 1, "Grid"), {1: {"team": 1}}, [1], false)
	var graph: Dictionary = ECON.military_graph(state)
	var center: Vector2 = graph["points"][0]
	var miner: Dictionary = {"id": 9809, "owner": 1, "kind": "miner", "origin": 0, "at": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": center, "heading": Vector2.UP, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock(), "mining_mode": "idle"}
	state["ships"] = [miner]
	assert(not ECON.set_autocast(state, 2, [9809], "mine", false))
	assert(not ECON.set_autocast(state, 1, [9809], "trade", false))
	assert(not ECON.set_autocast(state, 1, [9809], "invalid", false))
	assert(ECON.set_autocast(state, 1, [9809], "mine", false))
	assert(ECON.set_autocast(state, 1, [9809], "wander", false))
	assert(ECON.set_autocast(state, 1, [9809], "repair", false))
	assert(ECON.autocast_enabled(miner, "salvage") and not ECON.autocast_enabled(miner, "mine"))
	var point: Vector2 = center + Vector2.RIGHT * 10.0
	assert(ECON.issue_unit_order(state, 1, [9809], {"kind": "position", "target": 0, "point": point, "move_only": true}, false))
	assert(is_equal_approx(ECON.autocast_remaining(state, miner), ECON.AUTOCAST_COOLDOWN_YEARS))
	assert(is_equal_approx(ECON.autocast_remaining(state, miner, "mine"), 5.0))
	assert(is_equal_approx(ECON.autocast_remaining(state, miner, "salvage"), 5.0))
	assert(ECON.autocast_remaining(state, miner, "repair") == 0.0)
	for tick in range(100):
		ECON.step(state, 0.1)
		if not miner.has("local_move_target"):
			break
	assert(miner["position"].is_equal_approx(point))
	assert(ECON.set_autocast(state, 1, [9809], "wander", true))
	assert(ECON.autocast_ready(state, miner, "wander"))
	assert(ECON.autocast_remaining(state, miner, "wander") == 0.0)
	assert(is_equal_approx(ECON.autocast_remaining(state, miner, "salvage"), 5.0))
	assert(ECON._idle_formation_targets(state, graph).has(9809))
	assert(ECON.issue_unit_order(state, 1, [9809], {"kind": "position", "target": 0, "point": center, "move_only": true}, false))
	assert(not ECON.autocast_ready(state, miner, "wander"))
	for tick in range(100):
		ECON.step(state, 0.1)
		if not miner.has("local_move_target"):
			break
	assert(ECON.set_autocast(state, 1, [9809], "repair", true))
	assert(ECON.autocast_ready(state, miner, "repair"))
	assert(ECON.set_autocast(state, 1, [9809], "mine", true))
	assert(not ECON.autocast_ready(state, miner, "mine"))
	state["elapsed"] = float(state["elapsed"]) + 4.9
	assert(not ECON.autocast_ready(state, miner, "mine") and not ECON.autocast_ready(state, miner, "salvage"))
	state["elapsed"] = float(state["elapsed"]) + 0.11
	assert(ECON.autocast_ready(state, miner, "mine") and ECON.autocast_ready(state, miner, "salvage"))
	assert(not ECON.autocast_ready(state, miner, "wander"))
	assert(ECON.set_autocast(state, 1, [9809], "mine", false))
	state["elapsed"] = float(state["elapsed"]) + ECON.AUTOCAST_COOLDOWN_YEARS + 0.1
	assert(ECON.autocast_ready(state, miner, "wander"))
	assert(ECON._idle_formation_targets(state, graph).has(9809))
	assert(ECON.set_autocast(state, 1, [9809], "wander", false))
	assert(not ECON._idle_formation_targets(state, graph).has(9809))
	assert(ECON.autocast_ready(state, miner, "salvage") and not ECON.autocast_ready(state, miner, "mine"))
	print("PASS: independent autocast modes, permission validation and command cooldown")

func _test_sector_entry_orders() -> void:
	var map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(2000, 0), Vector2(4000, 0)], "edges": [[0, 1], [1, 2]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}}, [1], false)
	var graph: Dictionary = ECON.military_graph(state)
	for i in range(2):
		state["ships"].append({"id": 9800 + i, "owner": 1, "kind": "fighter" if i == 0 else "colony_ship", "origin": 0, "at": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": Vector2.ZERO, "heading": Vector2.RIGHT, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock()})
	var order: Dictionary = {"kind": "sector_entry", "target": 2, "move_only": true}
	assert(not ECON.issue_unit_order(state, 2, [9800], order, false))
	assert(not ECON.issue_unit_order(state, 1, [9800], {"kind": "sector_entry", "target": 999}, false))
	assert(ECON.issue_unit_order(state, 1, [9800, 9801], order, false))
	var border: Vector2 = ECON.sector_entry_point(graph, 2, graph["points"][1])
	for ship in state["ships"]:
		assert(ship["local_move_target"].is_equal_approx(border))
	for tick in range(2000):
		ECON.step(state, 0.1)
		if state["ships"].all(func(ship: Dictionary) -> bool: return not ship.has("local_move_target")):
			break
	for ship in state["ships"]:
		assert(ship["position"].is_equal_approx(border) and ECON.sector_contains(graph, 2, ship["position"]))
		assert(ECON.arrival_wait_remaining(state, ship) > 0.0)
		assert(not ship.get("holding", false))
	print("PASS: authoritative star-sector entry, border arrival and idle grace")

func _test_gap_position_orders() -> void:
	var map: Dictionary = {"seed": 42, "size": Vector2(10000, 5000), "points": [Vector2(500, 500), Vector2(2500, 500), Vector2(6500, 500), Vector2(8500, 500)], "edges": [[0, 1], [1, 2], [2, 3]], "fields": []}
	for kind in ["fighter", "miner", "ship", "colony_ship", "scout", "science_ship", "cruiser", "destroyer"]:
		var state: Dictionary = ECON.create(map.duplicate(true), {1: {"team": 1}}, [1], false)
		var graph: Dictionary = ECON.military_graph(state)
		var craft: Dictionary = {"id": 9805, "owner": 1, "kind": kind, "origin": 2, "at": 2, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": map["points"][2], "heading": Vector2.LEFT, "hp": ECON.ship_max_hp(kind), "cargo": ECON.empty_stock(), "mining_mode": "idle", "wander_auto": false}
		state["ships"] = [craft]
		var gap := Vector2(4400, 600)
		var second := Vector2(4600, 600)
		assert(ECON.sector_at(graph, gap, [0, 1, 2, 3]) == -1)
		assert(ECON.lane_at(graph, gap) == Vector2i(1, 2) and ECON.lane_at(graph, second) == Vector2i(1, 2))
		assert(ECON.patrol_node(state, graph, 1, Vector2(4500, 2500)) == -1)
		assert(not ECON.issue_unit_order(state, 1, [9805], {"kind": "position", "target": 1, "point": Vector2(4500, 2500)}, false))
		assert(not ECON.issue_unit_order(state, 2, [9805], {"kind": "position", "target": 1, "point": gap}, false))
		assert(not ECON.issue_unit_order(state, 1, [9805], {"kind": "position", "target": 0, "point": gap}, false))
		assert(ECON.issue_unit_order(state, 1, [9805], {"kind": "position", "target": 1, "point": gap, "move_only": true}, false))
		assert(craft["route"].is_empty() and craft["local_move_target"] == gap)
		assert(ECON.issue_unit_order(state, 1, [9805], {"kind": "position", "target": 2, "point": second, "move_only": true}, true))
		var reached_first: bool = false
		for tick in range(2000):
			var previous: Vector2 = craft["position"]
			ECON.step(state, 0.1)
			assert(previous.distance_to(craft["position"]) <= ECON.ship_speed(kind) * 0.1 + 0.01)
			reached_first = reached_first or craft["position"].is_equal_approx(gap)
			if reached_first and not craft.has("local_move_target") and craft["position"].is_equal_approx(second):
				break
		assert(reached_first and craft["position"].is_equal_approx(second) and not craft.has("local_move_target"))
		assert(ECON.local_sector(graph, craft) == -1 and not craft.get("holding", false))
	print("PASS: bounded lane movement, direct cross-midpoint travel, queued destinations and authority validation")

func _test_local_position_orders() -> void:
	var map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(5000, 0)], "edges": [[0, 1]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	for kind in ["fighter", "ship", "miner", "colony_ship"]:
		var id: int = state["ships"].size() + 100
		state["ships"].append({"id": id, "owner": 1, "kind": kind, "origin": 0, "at": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": Vector2.ZERO, "heading": Vector2.UP, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock(), "mining_mode": "idle"})
	var fighter: Dictionary = state["ships"][0]
	var freighter: Dictionary = state["ships"][1]
	freighter["cargo"]["Metals"] = 10.0
	var point := Vector2(150, 200)
	var selection: Array = [100, 101, 102, 103]
	# A neutral neighboring POI must clip the sector at its bisector,
	# not at a much smaller ownership-dependent exclusion circle.
	var boundary_graph: Dictionary = ECON.military_graph(state)
	var candidates: Array = [0, 1]
	assert(ECON.sector_at(boundary_graph, Vector2(2499, 0), candidates) == 0)
	assert(ECON.sector_at(boundary_graph, Vector2(2501, 0), candidates) == 1)
	assert(ECON.sector_at(boundary_graph, Vector2(2500, 0), candidates, 0) == 0)
	assert(ECON.sector_at(boundary_graph, Vector2(2500, 0), candidates, 1) == 1)
	assert(ECON.command_local_position(state, 1, [100], 0, Vector2(2499, 0), true))
	assert(fighter.get("move_only", false))
	assert(fighter["route"].is_empty() and fighter["dest"] == 0 and fighter["local_move_target"] == Vector2(2499, 0) and not fighter.get("holding", false))
	assert(not ECON.command_local_position(state, 1, [100], 0, Vector2(2501, 0)))
	assert(not ECON.command_local_position(state, 2, selection, 0, point))
	assert(not ECON.command_local_position(state, 1, [100, 999], 0, point))
	assert(not ECON.command_local_position(state, 1, [100, 100], 0, point))
	assert(not ECON.command_local_position(state, 1, selection, 1, map["points"][1]))
	assert(not ECON.command_local_position(state, 1, selection, 0, map["points"][1]))
	assert(not ECON.command_local_position(state, 1, selection, 0, Vector2.INF))
	assert(ECON.command_local_position(state, 1, selection, 0, point))
	assert(not fighter.get("move_only", false))
	for craft in state["ships"]:
		assert(craft["position"] == Vector2.ZERO and not craft.get("holding", false) and craft["local_move_target"] == point)
	assert(freighter["cargo"]["Metals"] == 10.0)
	var arrivals: Dictionary = {}
	for tick in range(100):
		var previous: Vector2 = fighter["position"]
		ECON.step(state, 0.1)
		assert(previous.distance_to(fighter["position"]) <= ECON.ship_speed(str(fighter["kind"])) * 0.1 + 0.01)
		for ship in state["ships"]:
			var ship_id: int = int(ship["id"])
			if not arrivals.has(ship_id):
				assert(ECON.sector_contains(ECON.military_graph(state), 0, ship["position"]))
				if not ship.has("local_move_target"):
					assert(not ship.get("holding", false))
					assert((ship["position"] as Vector2).distance_to(point) <= ECON.ship_speed(str(ship["kind"])) * 0.1 + ECON.EPS)
					arrivals[ship_id] = true
		if arrivals.size() == selection.size():
			break
	assert(arrivals.size() == selection.size())
	assert(ECON._is_idle_ship(fighter))
	for craft in state["ships"]:
		assert(ECON.arrival_wait_remaining(state, craft) > 0.0)
	var waiting_positions: Dictionary = {}
	for craft in state["ships"]:
		waiting_positions[craft["id"]] = craft["position"]
	for tick in range(50):
		ECON.step(state, 0.1)
		for craft in state["ships"]:
			assert(craft["position"] == waiting_positions[craft["id"]])
	assert(ECON.command_hold_units(state, 1, selection, false))
	for craft in state["ships"]:
		assert(craft.get("holding", false) and not craft.has("local_move_target"))
	assert(ECON.command_hold_units(state, 1, selection, true))
	for tick in range(320):
		ECON.step(state, 0.1)
	for craft in state["ships"]:
		assert(not craft.get("holding", false) and not craft.has("hold_position"))
	assert(fighter["position"] != point)
	assert(ECON.command_local_position(state, 1, [100], 0, point))
	assert(ECON.command_fighters(state, 1, [100], 1))
	assert(not fighter.get("holding", false) and not fighter.has("local_move_target") and fighter["route"].has(1))
	# The hull has reached the destination sector through its lane, but
	# has not yet docked at the waypoint. It can already be positioned.
	fighter["position"] = Vector2(4000, 0)
	assert(ECON.local_sector(ECON.military_graph(state), fighter) == 1)
	assert(ECON.command_local_position(state, 1, [100], 1, Vector2(4500, 0)))
	assert(fighter["at"] == 1 and fighter["route"].is_empty() and fighter["position"] == Vector2(4000, 0))
	# Emergency repair can temporarily leave the held sector, but the
	# original position must be recovered through the actual lane.
	var repair_map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(5000, 0), Vector2(1000, 0)], "edges": [[0, 2], [1, 2]], "fields": []}
	var repair: Dictionary = ECON.create(repair_map, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var damaged: Dictionary = {"id": 200, "owner": 1, "kind": "fighter", "at": 2, "origin": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": Vector2(1000, 0), "heading": Vector2.UP, "hp": ECON.SHIP_HP}
	repair["ships"] = [damaged]
	var post := Vector2(1000, 25)
	assert(ECON.command_local_position(repair, 1, [200], 2, post))
	damaged["hp"] = ECON.WITHDRAW_HP
	assert(ECON.set_autocast(repair, 1, [200], "retreat", true))
	var repaired: bool = false
	for tick in range(500):
		var previous: Vector2 = damaged["position"]
		ECON.step(repair, 0.1)
		assert(previous.distance_to(damaged["position"]) <= ECON.ship_speed(str(damaged["kind"])) * 0.1 + 0.01)
		repaired = repaired or (damaged["at"] == 0 and is_equal_approx(float(damaged["hp"]), ECON.SHIP_HP))
		if repaired and damaged["at"] == 2 and damaged["position"] == post:
			break
	assert(repaired and damaged["position"] == post and not damaged.get("holding", false) and not damaged.has("local_move_target"))
	print("PASS: one-shot local movement, idle arrival, explicit hold, bounded travel, ownership/sector validation and repair")

func _test_tactical_orders() -> void:
	var map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(5000, 0), Vector2(1000, 0)], "edges": [[0, 2], [1, 2]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var f: Dictionary = {"id": 100, "owner": 1, "kind": "fighter", "origin": 0, "at": 2, "dest": 2, "source": -1, "route": [], "leg": 0.0, "position": Vector2(1000, 0), "heading": Vector2.RIGHT, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock()}
	var enemy: Dictionary = f.duplicate(true)
	enemy.merge({"id": 101, "owner": 2, "kind": "ship", "position": Vector2(1100, 0), "holding": true}, true)
	var decoy: Dictionary = enemy.duplicate(true)
	decoy.merge({"id": 102, "position": Vector2(1010, 0)}, true)
	state["ships"] = [f, enemy, decoy]
	# Ordinary click and formation orders share move-only semantics. Nearby
	# targets are ignored en route, while deliberate attack-move may fire.
	assert(ECON.issue_unit_order(state, 1, [100], {"kind": "position", "target": 2, "point": Vector2(1200, 0), "move_only": true}, false))
	ECON.step(state, 0.1)
	assert(enemy["hp"] == ECON.SHIP_HP and decoy["hp"] == ECON.SHIP_HP)
	assert(f.get("move_only", false) and f.has("local_move_target"))
	assert(ECON.issue_unit_order(state, 1, [100], {"kind": "position", "target": 2, "point": Vector2(1200, 0), "move_only": false}, false))
	ECON.step(state, 0.1)
	assert(decoy["hp"] < ECON.SHIP_HP or enemy["hp"] < ECON.SHIP_HP)
	# Reset damage to isolate the focused-target checks below.
	enemy["hp"] = ECON.SHIP_HP
	decoy["hp"] = ECON.SHIP_HP
	f["blaster_cooldown"] = 0.0
	f["blaster_shot"] = 0
	assert(not ECON.command_attack(state, 2, [100], 101))
	assert(not ECON.command_attack(state, 1, [100], 100))
	assert(not ECON.command_attack(state, 1, [100, 101], 102))
	assert(not ECON.command_attack(state, 1, [100], 999))
	assert(ECON.command_attack(state, 1, [100], 101))
	ECON.step(state, 0.1)
	assert(f["combat_target"] == 101 and enemy["hp"] < ECON.SHIP_HP and decoy["hp"] == ECON.SHIP_HP)
	assert(f["attack_order"] == 101)
	# Retarget the live hull when it changes sectors, without teleporting
	# the attacker onto a different lane or changing its target identity.
	enemy["at"] = 1
	enemy["position"] = map["points"][1]
	var before: Vector2 = f["position"]
	ECON.step(state, 0.1)
	assert(f["attack_order"] == 101 and f["operation_target"] == 1 and (f["route"] as Array).has(1))
	assert(before.distance_to(f["position"]) <= ECON.ship_speed(str(f["kind"])) * 0.1 + 0.01)
	assert(ECON.command_hold_units(state, 1, [100], false))
	assert(not f.has("attack_order"))
	assert(ECON.command_attack(state, 1, [100], 101))
	state["ships"].erase(enemy)
	state["ships"].erase(decoy)
	ECON.step(state, 0.1)
	assert(not f.has("attack_order"))
	assert(not ECON.command_patrol(state, 2, [100], 0))
	assert(not ECON.command_patrol(state, 1, [100], 2))
	assert(ECON.command_patrol(state, 1, [100], 0))
	f["hp"] = ECON.WITHDRAW_HP
	assert(ECON.set_autocast(state, 1, [100], "retreat", true))
	var reached_home: bool = false
	var returned: bool = false
	var restored: bool = false
	for tick in range(1000):
		var previous: Vector2 = f["position"]
		ECON.step(state, 0.25)
		assert(previous.distance_to(f["position"]) <= ECON.ship_speed(str(f["kind"])) * 0.25 + 0.01)
		assert(f["patrol_from"] == 2 and f["patrol_to"] == 0)
		restored = restored or (not bool(f.get("retreating", false)) and is_equal_approx(float(f["hp"]), ECON.SHIP_HP))
		reached_home = reached_home or int(f["at"]) == 0
		if reached_home and restored and int(f["at"]) == 2:
			returned = true
			break
	assert(reached_home and returned and restored and f["patrol_from"] == 2 and f["patrol_to"] == 0)
	assert(ECON.command_fighters(state, 1, [100], 0))
	assert(not f.has("patrol_from") and not f.has("patrol_to"))
	print("PASS: explicit hostile targeting, priority fire, cancellation, bounded lane patrol and return")

func _test_precise_patrol() -> void:
	var map: Dictionary = {"seed": 42, "size": Vector2(6000, 4000), "points": [Vector2(1000, 1000), Vector2(5500, 3500), Vector2(3500, 1000)], "edges": [[0, 2], [2, 1]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var start := Vector2(1050, 1080)
	var craft: Dictionary = {"id": 100, "owner": 1, "kind": "fighter", "origin": 0, "at": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": start, "heading": Vector2.RIGHT, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock()}
	state["ships"] = [craft]
	var graph: Dictionary = ECON.military_graph(state)
	var nearby := Vector2(1300, 1150)
	assert(not ECON.issue_unit_order(state, 2, [100], {"kind": "patrol", "target": 0, "point": nearby}, false))
	assert(not ECON.issue_unit_order(state, 1, [100], {"kind": "patrol", "target": 0, "point": Vector2.INF}, false))
	assert(not ECON.issue_unit_order(state, 1, [100], {"kind": "patrol", "target": 0, "point": Vector2(-1, 10)}, false))
	assert(ECON.issue_unit_order(state, 1, [100], {"kind": "patrol", "target": 0, "point": nearby}, false))
	assert(craft["patrol_start_point"] == start and craft["patrol_end_point"] == nearby)
	var reached: bool = false
	var returned: bool = false
	for tick in range(200):
		var prior: Vector2 = craft["position"]
		ECON.step(state, 0.1)
		assert(prior.distance_to(craft["position"]) <= ECON.ship_speed(str(craft["kind"])) * 0.1 + 0.01)
		reached = reached or craft["position"] == nearby
		if reached and craft["position"] == start:
			returned = true
			break
	assert(reached and returned)
	# A remote click outside travel lanes is invalid; a point on a
	# connected lane remains a valid exact patrol endpoint.
	assert(ECON.patrol_node(state, graph, 1, Vector2(3400, 3000)) == -1)
	var remote := Vector2(4500, 2250)
	var node: int = ECON.patrol_node(state, graph, 1, remote)
	assert(node >= 0 and node != 0)
	assert(ECON.issue_unit_order(state, 1, [100], {"kind": "patrol", "target": node, "point": remote}, false))
	assert(ECON.issue_unit_order(state, 1, [100], {"kind": "sector", "target": 0, "move_only": true}, true))
	reached = false
	for tick in range(2000):
		var prior: Vector2 = craft["position"]
		ECON.step(state, 0.1)
		assert(prior.distance_to(craft["position"]) <= ECON.ship_speed(str(craft["kind"])) * 0.1 + 0.01)
		reached = reached or craft["position"] == remote
		if not craft.has("patrol_from"):
			break
	assert(reached and not craft.has("patrol_from") and craft["unit_order"]["kind"] == "sector")
	print("PASS: exact same-sector patrol, remote lane point, return, queue and input validation")

func _test_salvage() -> void:
	var map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(5000, 0)], "edges": [[0, 1]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var graph: Dictionary = ECON.military_graph(state)
	var wreck: Dictionary = {"id": 99, "owner": 2, "kind": "ship", "at": 0, "position": Vector2.ZERO, "route": [], "leg": 0.0, "cargo": ECON.empty_stock()}
	wreck["cargo"][ECON.ANTIMATTER] = 1.25
	wreck["cargo"]["Metals"] = 5.0
	ECON._record_ship_destruction(state, graph, wreck)
	var recipe: Dictionary = ECON._cost("ship", 1)
	var recovered: Dictionary = ECON.empty_stock()
	var expirations: Dictionary = {}
	for pile in state["salvage"].values():
		var lifetime: float = float(pile["expires_at"]) - float(pile["born"])
		assert(lifetime >= ECON.SALVAGE_MIN_LIFETIME and lifetime <= ECON.SALVAGE_MAX_LIFETIME)
		expirations[lifetime] = true
		var resource: String = pile["resource"]
		recovered[resource] = float(pile["amount"])
		assert(float(pile["amount"]) <= float(wreck["cargo"].get(resource, 0.0)) + float(recipe.get(resource, 0.0)) * 0.2 + 0.0001)
	assert(is_equal_approx(recovered[ECON.ANTIMATTER], 1.25) and recovered["Metals"] >= 5.0)
	var first_pile: Dictionary = state["salvage"].values()[0]
	var initial_point: Vector2 = first_pile["position"]
	state["elapsed"] = 2.0
	ECON._update_salvage(state)
	assert(first_pile["position"] != initial_point)
	assert(expirations.size() > 1)
	state["elapsed"] = 90.0
	ECON._update_salvage(state)
	assert(state["salvage"].size() == expirations.size())
	state["elapsed"] = float(first_pile["expires_at"])
	ECON._update_salvage(state)
	assert(not state["salvage"].has(first_pile["id"]))
	state["elapsed"] = ECON.SALVAGE_MAX_LIFETIME
	ECON._update_salvage(state)
	assert(state["salvage"].is_empty())
	state["elapsed"] = 2.0
	state["salvage"].clear()
	var hauler: Dictionary = {"id": 100, "owner": 1, "kind": "ship", "origin": 0, "at": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": Vector2(200, 0), "heading": Vector2.UP, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock(), "mining_mode": "idle"}
	hauler["cargo"]["Metals"] = ECON.CARGO_CAPACITY - 2.0
	var second: Dictionary = hauler.duplicate(true)
	second["id"] = 101
	state["ships"] = [hauler, second]
	var point := Vector2(500, 0)
	var pile: Dictionary = {"id": 1000, "resource": "Crystals", "amount": 25.0, "origin": point, "position": point, "drift": Vector2.ZERO, "born": 0.0, "claim": -1}
	state["salvage"][1000] = pile
	assert(not ECON.command_salvage(state, 2, [100], 1000))
	assert(not ECON.command_salvage(state, 1, [100, 999], 1000))
	assert(ECON.command_salvage(state, 1, [100], 1000))
	assert(not ECON.command_salvage(state, 1, [101], 1000))
	assert(pile["claim"] == 100)
	var home: Dictionary = state["planets"][0]
	var original: Dictionary = home["stock"].duplicate()
	ECON._work_salvage(state, graph, hauler, 0.1)
	assert(hauler["position"].distance_to(Vector2(200, 0)) <= ECON.ship_speed(str(hauler["kind"])) * 0.1 + 0.01)
	assert(ECON._cargo_total(hauler) == ECON.CARGO_CAPACITY - 2.0)
	for tick in range(200):
		state["elapsed"] += 0.1
		var previous: Vector2 = hauler["position"]
		ECON._work_salvage(state, graph, hauler, 0.1)
		assert(previous.distance_to(hauler["position"]) <= ECON.ship_speed(str(hauler["kind"])) * 0.1 + 0.01)
		assert(ECON._cargo_total(hauler) <= ECON.CARGO_CAPACITY + 0.0001)
		if not ECON._salvage_active(hauler):
			break
	assert(not ECON._salvage_active(hauler) and ECON._cargo_total(hauler) < 0.001)
	assert(is_equal_approx(pile["amount"], 23.0) and pile["claim"] == -1)
	assert(is_equal_approx(home["stock"]["Metals"], original["Metals"] + ECON.CARGO_CAPACITY - 2.0))
	assert(is_equal_approx(home["stock"]["Crystals"], original["Crystals"] + 2.0))
	assert(not ECON.command_unload_cargo(state, 2, [101]))
	assert(ECON.command_unload_cargo(state, 1, [101]))
	for kind in ["ship", "miner", "colony_ship"]:
		var craft: Dictionary = {"kind": kind, "cargo": ECON.empty_stock()}
		var capacity: float = ECON.cargo_capacity(kind)
		craft["cargo"]["Metals"] = capacity * 0.5
		assert(is_equal_approx(ECON.cargo_free(craft), capacity * 0.5))
		assert(ECON.cargo_bays(craft["cargo"], capacity, 4)[0][0]["amount"] > 0.0)
	print("PASS: wreck recovery, drift, ownership, exclusive claim, partial pickup, physical delivery, cargo-capable hulls")

func _test_colony_farm() -> void:
	var map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(5000, 0)], "edges": [[0, 1]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var home: Dictionary = state["planets"][0]
	ECON._finish(state, 0, home, {"id": 901, "kind": "colony_ship"})
	var ship: Dictionary = state["ships"][0]
	var graph: Dictionary = ECON.military_graph(state)
	assert(ECON.COLONY_CAPACITY == 100.0 and not ECON.supports_autocast(ship, "salvage"))
	assert(not ECON.set_autocast(state, 2, [901], "farm", false))
	assert(ECON.set_autocast(state, 1, [901], "farm", false))
	ECON._grow_colony_cargo(ship, 10.0)
	assert(ECON._cargo_total(ship) == 0.0)
	assert(ECON.set_autocast(state, 1, [901], "farm", true))
	home["stock"]["Organics"] = 0.0
	ECON._grow_colony_cargo(ship, 10.0)
	assert(ship["cargo"]["Organics"] == 50.0 and home["stock"]["Organics"] == 0.0)
	assert(not ECON._begin_farm_delivery(state, ship))
	assert(not ECON.command_unload_cargo(state, 2, [901]))
	assert(ECON.issue_unit_order(state, 1, [901], {"kind": "unload"}, false))
	ship["position"] = ECON.station_position(state, 0, float(state["elapsed"]))
	assert(ECON._work_salvage(state, graph, ship, 0.1))
	assert(is_equal_approx(float(home["stock"]["Organics"]), ECON.dropoff_rate("colony_ship") * 0.1))
	assert(ECON._work_salvage(state, graph, ship, 5.0))
	assert(home["stock"]["Organics"] == 50.0 and ECON._cargo_total(ship) == 0.0)
	ship.erase("unit_order")
	ECON._grow_colony_cargo(ship, 40.0)
	assert(ship["cargo"]["Organics"] == 100.0)
	assert(ECON._begin_farm_delivery(state, ship))
	home["stock"]["Organics"] = ECON.storage_capacity(home)
	assert(ECON._work_salvage(state, graph, ship, 1.0))
	assert(ECON._cargo_total(ship) == 100.0)
	home["stock"]["Organics"] -= 100.0
	state["elapsed"] += 1.0
	assert(ECON._work_salvage(state, graph, ship, 100.0))
	assert(ECON._cargo_total(ship) <= ECON.EPS)
	assert(home["stock"]["Organics"] == ECON.storage_capacity(home))
	print("PASS: colony farming, cap, authority, manual and auto delivery, full warehouse")

func _test_remote_salvage() -> void:
	var map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(1000, 0), Vector2(2000, 0), Vector2(3000, 0)], "edges": [[0, 1], [1, 2], [2, 3]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}}, [1], false)
	var graph: Dictionary = ECON.military_graph(state)
	var craft: Dictionary = {"id": 500, "owner": 1, "kind": "miner", "origin": 0, "at": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": Vector2.ZERO, "heading": Vector2.UP, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock(), "mining_mode": "idle"}
	state["ships"] = [craft]
	var piles: Dictionary = state["salvage"]
	piles[300] = {"id": 300, "resource": "Metals", "amount": 3.0, "position": map["points"][3], "claim": -1}
	assert(not ECON._work_opportunistic_salvage(state, graph, craft, 0.1, {}, ECON._salvage_cells(piles), false))
	piles[301] = {"id": 301, "resource": "Metals", "amount": 3.0, "position": map["points"][2], "claim": -1}
	assert(ECON._work_opportunistic_salvage(state, graph, craft, 0.1, {}, ECON._salvage_cells(piles), false))
	assert(craft["auto_salvage_target"] == 301 and craft["position"] != Vector2.ZERO)
	for tick in range(1000):
		ECON._work_opportunistic_salvage(state, graph, craft, 0.1, {}, ECON._salvage_cells(piles), false)
		if craft.get("salvage_delivery", false):
			break
	assert(not piles.has(301) and craft.get("salvage_delivery", false))
	assert(int(craft["at"]) == 2)
	print("PASS: two-hop salvage search, three-hop exclusion, remote pickup and return anchor")

func _test_opportunistic_salvage() -> void:
	var map: Dictionary = {"seed": 42, "points": [Vector2.ZERO, Vector2(5000, 0)], "edges": [[0, 1]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var graph: Dictionary = ECON.military_graph(state)
	state["ships"].clear()
	for kind in ["fighter", "miner", "ship", "colony_ship"]:
		var id: int = 100 + state["ships"].size()
		var pos := Vector2(250.0 * float(id - 100), 0.0)
		var ship: Dictionary = {"id": id, "owner": 1, "kind": kind, "origin": 0, "at": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": pos, "heading": Vector2.UP, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock(), "mining_mode": "idle", "holding": true}
		state["ships"].append(ship)
		state["salvage"][id] = {"id": id, "resource": "Metals", "amount": 50.0, "origin": pos, "position": pos, "drift": Vector2.ZERO, "born": 0.0, "expires_at": 100.0, "claim": -1}
	ECON.step(state, 0.1)
	for ship in state["ships"]:
		var carries_cargo: bool = ECON.supports_autocast(ship, "salvage")
		var expected: float = (ECON.FREIGHTER_TRACTOR_RATE if ship["kind"] == "ship" else ECON.TRACTOR_RATE) * 0.1 if carries_cargo else 0.0
		if ship["kind"] == "colony_ship":
			expected = ECON.COLONY_FARM_RATE * 0.1
			assert(is_zero_approx(float(ship["cargo"]["Metals"])))
		assert(is_equal_approx(ECON._cargo_total(ship), expected))
		assert(ship["holding"] and ship["route"].is_empty())
		assert(int(state["salvage"][ship["id"]]["claim"]) == (int(ship["id"]) if carries_cargo else -1))
	var fighter: Dictionary = state["ships"][0]
	var miner: Dictionary = state["ships"][1]
	var piles: Dictionary = state["salvage"]
	fighter["combat_target"] = int(miner["id"])
	var busy: Dictionary = ECON._salvage_combat_busy(state)
	assert(busy.has(fighter["id"]) and busy.has(miner["id"]))
	for ship in [fighter, miner]:
		assert(not ECON._work_opportunistic_salvage(state, graph, ship, 0.1, busy, ECON._salvage_cells(piles), false))
		assert(is_equal_approx(ECON._cargo_total(ship), 0.0 if ship["kind"] == "fighter" else 1.2))
		assert(piles[ship["id"]]["claim"] == -1)
	fighter["combat_target"] = -1
	assert(not ECON._work_opportunistic_salvage(state, graph, fighter, 0.1, {}, ECON._salvage_cells(piles), false))
	assert(ECON.cargo_capacity("fighter") == 0.0 and ECON.cargo_free(fighter) == 0.0)
	assert(not ECON.command_salvage(state, 1, [fighter["id"]], fighter["id"]))
	assert(not ECON.issue_unit_order(state, 1, [fighter["id"]], {"kind": "salvage", "target": fighter["id"]}, false))
	assert(not ECON.issue_unit_order(state, 1, [fighter["id"]], {"kind": "drop", "point": fighter["position"]}, false))
	assert(not ECON.command_unload_cargo(state, 1, [fighter["id"]]))
	assert(not fighter.has("salvage_target") and not fighter.has("auto_salvage_target"))
	state["elapsed"] = 100.0
	ECON._update_salvage(state)
	assert(piles.is_empty())
	ECON._work_salvage(state, graph, fighter, 0.1, true)
	assert(not fighter.has("salvage_target"))
	# Beam-range pickup does not displace a routed craft; an idle craft
	# may approach nearby debris without violating its movement budget.
	var craft: Dictionary = state["ships"][2]
	craft["holding"] = false
	craft["route"] = [0, 1]
	craft["dest"] = 1
	var pos: Vector2 = craft["position"]
	var point: Vector2 = pos + Vector2(20, 0)
	piles[200] = {"id": 200, "resource": "Crystals", "amount": 50.0, "position": point, "claim": -1}
	var route: Array = craft["route"].duplicate()
	assert(not ECON._work_opportunistic_salvage(state, graph, craft, 0.1, {}, ECON._salvage_cells(piles), false))
	assert(craft["route"] == route and craft["position"] == pos and is_equal_approx(craft["cargo"]["Crystals"], ECON.FREIGHTER_TRACTOR_RATE * 0.1))
	craft["route"] = []
	craft["dest"] = -1
	piles[200]["position"] = pos + Vector2(ECON.TRACTOR_RANGE * 1.5, 0)
	assert(ECON._work_opportunistic_salvage(state, graph, craft, 0.1, {}, ECON._salvage_cells(piles), false))
	assert(pos.distance_to(craft["position"]) > 0.0 and pos.distance_to(craft["position"]) <= ECON.ship_speed(str(craft["kind"])) * 0.1 + 0.01)
	craft["cargo"]["Metals"] = ECON.cargo_capacity("ship") - float(craft["cargo"]["Crystals"])
	assert(ECON._work_opportunistic_salvage(state, graph, craft, 0.1, {}, ECON._salvage_cells(piles), false))
	assert(piles[200]["claim"] == -1 and is_zero_approx(ECON.cargo_free(craft)))
	assert(bool(craft.get("salvage_delivery", false)))
	# Idle civilians approach more distant safe wreckage and finish gathering
	# before resuming autonomous mining or freight. Hostile hulls in the
	# same sector block pickup even when not directly firing.
	for kind in ["miner", "ship"]:
		var civilian: Dictionary = {"id": 500, "owner": 1, "kind": kind, "origin": 0, "at": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": Vector2.ZERO, "heading": Vector2.UP, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock(), "mining_mode": "idle"}
		var enemy: Dictionary = {"id": 501, "owner": 2, "kind": "fighter", "at": 0, "position": Vector2(700, 0), "route": []}
		state["ships"] = [civilian, enemy]
		piles.clear()
		piles[201] = {"id": 201, "resource": "Metals", "amount": 3.0, "position": Vector2(270, 0), "claim": -1}
		assert(not ECON._work_opportunistic_salvage(state, graph, civilian, 0.1, {}, ECON._salvage_cells(piles), false))
		assert(civilian["position"] == Vector2.ZERO and piles[201]["claim"] == -1)
		enemy["owner"] = 1
		assert(ECON._work_opportunistic_salvage(state, graph, civilian, 0.1, {}, ECON._salvage_cells(piles), false))
		assert(civilian["position"] != Vector2.ZERO and piles[201]["claim"] == 500)
		enemy["owner"] = 2
		assert(not ECON._work_opportunistic_salvage(state, graph, civilian, 0.1, {}, ECON._salvage_cells(piles), false))
		assert(piles[201]["claim"] == -1)
		enemy["owner"] = 1
		civilian["position"] = piles[201]["position"]
		assert(ECON._work_opportunistic_salvage(state, graph, civilian, 0.1, {}, ECON._salvage_cells(piles), false))
		var rate: float = ECON.FREIGHTER_TRACTOR_RATE if kind == "ship" else ECON.TRACTOR_RATE
		assert(is_equal_approx(ECON._cargo_total(civilian), rate * 0.1) and not ECON._salvage_active(civilian))
		assert(ECON._work_opportunistic_salvage(state, graph, civilian, 1.0, {}, ECON._salvage_cells(piles), false))
		assert(piles.is_empty() and is_equal_approx(ECON._cargo_total(civilian), 3.0) and civilian["salvage_delivery"])
		var before: float = float(state["planets"][0]["stock"]["Metals"])
		for tick in range(150):
			state["elapsed"] += 0.1
			ECON._work_salvage(state, graph, civilian, 0.1)
			if not ECON._salvage_active(civilian):
				break
		assert(not ECON._salvage_active(civilian) and ECON._cargo_total(civilian) <= ECON.EPS)
		assert(is_equal_approx(float(state["planets"][0]["stock"]["Metals"]), before + 3.0))
	# A miner actively working a rock prefers nearby safe debris and retains
	# its assigned field for the next mining trip.
	var working: Dictionary = {"id": 600, "owner": 1, "kind": "miner", "origin": 0, "at": 0, "dest": 0, "source": -1, "route": [], "leg": 0.0, "position": Vector2.ZERO, "heading": Vector2.UP, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock(), "mining_mode": "mining", "mining_active": true, "assigned_field": 0, "field": 0}
	state["ships"] = [working]
	piles.clear()
	piles[300] = {"id": 300, "resource": "Metals", "amount": 3.0, "position": Vector2(ECON.AUTO_SALVAGE_RANGE + 1.0, 0), "claim": -1}
	assert(not ECON._work_opportunistic_salvage(state, graph, working, 0.1, {}, ECON._salvage_cells(piles), false))
	assert(working["mining_mode"] == "mining" and working["position"] == Vector2.ZERO)
	piles[300]["position"] = Vector2(180, 0)
	var threat: Dictionary = {"id": 601, "owner": 2, "kind": "fighter", "at": 0, "position": Vector2(700, 0), "route": []}
	state["ships"].append(threat)
	assert(not ECON._work_opportunistic_salvage(state, graph, working, 0.1, {}, ECON._salvage_cells(piles), false))
	state["ships"].erase(threat)
	# Prioritize safe salvage even after choosing a mining route, as long
	# as the Harvester is still in its departure sector.
	working["mining_mode"] = "approach"
	working["route"] = [1]
	working["salvage_auto"] = false
	assert(not ECON._work_opportunistic_salvage(state, graph, working, 0.1, {}, ECON._salvage_cells(piles), false))
	assert(working["route"] == [1] and working["position"] == Vector2.ZERO and piles[300]["claim"] == -1)
	working["salvage_auto"] = true
	assert(ECON._work_opportunistic_salvage(state, graph, working, 0.1, {}, ECON._salvage_cells(piles), false))
	assert(working["route"].is_empty() and float(working["leg"]) == 0.0)
	assert(working["position"] != Vector2.ZERO and not working["mining_active"] and working["assigned_field"] == 0 and working["auto_salvage_target"] == 300)
	working["position"] = piles[300]["position"]
	assert(ECON._work_opportunistic_salvage(state, graph, working, 1.0, {}, ECON._salvage_cells(piles), false))
	assert(is_equal_approx(ECON._cargo_total(working), 3.0) and working["salvage_delivery"] and piles.is_empty())
	for tick in range(150):
		state["elapsed"] += 0.1
		ECON._work_salvage(state, graph, working, 0.1)
		if not ECON._salvage_active(working):
			break
	assert(not ECON._salvage_active(working) and working["mining_mode"] == "idle" and working["assigned_field"] == 0)
	print("PASS: randomized expiry, cargo-capable pickup, fighter exclusion, combat priority and mining detours")
	print("PASS: idle civilian salvage detours, threatened-sector exclusion, claim release and automatic delivery")

func _test_civilian_waiting_movement() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(827, 1, "Grid"), {1: {"team": 1}}, [1], false)
	var center: Vector2 = state["map"]["points"][0]
	var home: Dictionary = state["planets"][0]
	state["ships"].clear()
	for kind in ["ship", "colony_ship", "miner"]:
		var craft: Dictionary = {"id": 9800 + state["ships"].size(), "owner": 1, "kind": kind, "origin": 0, "at": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": center, "heading": Vector2.UP, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock(), "mining_mode": "idle"}
		state["ships"].append(craft)
	var miner: Dictionary = state["ships"][2]
	miner["cargo"]["Crystals"] = 10.0
	miner["mining_mode"] = "delivery"
	home["stock"]["Crystals"] = ECON.storage_capacity(home)
	# Block all mineral pickups by removing chunks; isolate local
	# movement while the existing loaded miner waits on a full warehouse.
	for field in state["map"]["fields"]:
		field["chunks"].clear()
	var moved: Dictionary = {}
	for tick in range(30):
		for craft in state["ships"]:
			var previous: Vector2 = craft["position"]
			craft["test_before"] = previous
		ECON.step(state, 0.1)
		for craft in state["ships"]:
			var distance: float = (craft["position"] as Vector2).distance_to(craft["test_before"])
			assert(distance <= ECON.ship_speed(str(craft["kind"])) * 0.1 + 0.01)
			if distance > ECON.EPS:
				moved[craft["id"]] = true
	assert(moved.size() == 3)
	assert(is_equal_approx(float(miner["cargo"]["Crystals"]), 10.0))
	var away: float = (miner["position"] as Vector2).distance_to(center)
	assert(away > 1.0)
	home["stock"]["Crystals"] = 0.0
	var opened_at: float = float(state["elapsed"])
	# Once storage opens, the miner must physically return before delivery.
	for tick in range(500):
		ECON.step(state, 0.1)
		if float(miner["cargo"]["Crystals"]) < 10.0 - ECON.EPS:
			assert((miner["position"] as Vector2).distance_to(ECON.station_position(state, 0, float(state["elapsed"]))) <= ECON.STATION_DOCK_RANGE + ECON.SHIP_CLEARANCE + ECON.EPS)
			if ECON._cargo_total(miner) <= ECON.EPS:
				break
	assert(float(miner["cargo"]["Crystals"]) <= ECON.EPS)
	assert(is_equal_approx(float(home["stock"]["Crystals"]), 10.0 + (float(state["elapsed"]) - opened_at) * ECON.STATION_CRYSTALS_PER_YEAR))
	print("PASS: idle civilian flight and waiting-miner physical delivery")
	# Empty miners must not abandon evacuation when the only route home
	# is blocked by a hostile system. Opening a safe lane must resume travel.
	var trapped_map: Dictionary = {"seed": 827, "points": [Vector2.ZERO, Vector2(570, 0), Vector2(190, 0), Vector2(380, 0)], "edges": [[0, 2], [2, 3], [1, 3]], "fields": []}
	var trapped: Dictionary = ECON.create(trapped_map, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	trapped["planets"][2]["owner"] = 2
	trapped["planets"][2]["station"] = {"hp": ECON.STATION_HP}
	trapped["planets"][3]["owner"] = 2
	trapped["planets"][3]["station"] = {"hp": ECON.STATION_HP}
	var empty_miner: Dictionary = {"id": 9900, "owner": 1, "kind": "miner", "at": 3, "origin": 0, "dest": -1, "source": -1, "route": [], "leg": 0.0, "position": Vector2(380, 0), "heading": Vector2.UP, "cargo": ECON.empty_stock(), "mining_mode": "delivery"}
	ECON._work_miner(trapped, empty_miner, ECON.planet_teams(trapped), {}, [], 0.1)
	assert(empty_miner["mining_mode"] == "delivery" and empty_miner["route"].is_empty())
	trapped["planets"][2]["owner"] = 0
	trapped["planets"][2]["station"] = {}
	trapped["elapsed"] = 1.0
	ECON._work_miner(trapped, empty_miner, ECON.planet_teams(trapped), {}, [], 0.1)
	assert(empty_miner["dest"] == 0 and empty_miner["route"] == [3, 2, 0])
	for tick in range(100):
		var previous: Vector2 = empty_miner["position"]
		trapped["elapsed"] += 0.1
		ECON._work_miner(trapped, empty_miner, ECON.planet_teams(trapped), {}, [], 0.1)
		assert(previous.distance_to(empty_miner["position"]) <= ECON.ship_speed(str(empty_miner["kind"])) * 0.1 + 0.01)
		if empty_miner["mining_mode"] == "idle":
			break
	assert(empty_miner["at"] == 0 and empty_miner["mining_mode"] == "idle")
	print("PASS: empty stranded miner retries and physically evacuates")
	# Exercise actual starter hulls and ordinary mining orders in a seeded
	# four-player radial match, not just manually constructed idle hulls.
	var live: Dictionary = ECON.create(MAP.generate(7021, 4, "Radial"), {1: {"team": 1}, 2: {"team": 2}, 3: {"team": 3}, 4: {"team": 4}}, [1, 2, 3, 4])
	var initial: Dictionary = {}
	for craft in live["ships"]:
		if craft["kind"] == "miner":
			initial[craft["id"]] = craft["position"]
	assert(initial.size() == 12)
	for tick in range(20):
		ECON.step(live, 0.1)
	for craft in live["ships"]:
		if initial.has(craft["id"]):
			assert((craft["position"] as Vector2).distance_to(initial[craft["id"]]) > ECON.EPS)
	print("PASS: starter miners move in a seeded four-player radial match")

func _test_depleted_field_routes() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(827, 1, "Grid"), {1: {"team": 1}}, [1], false)
	var graph: Dictionary = ECON.military_graph(state)
	var count: int = state["planets"].size()
	for index in range(state["map"]["fields"].size()):
		var field: Dictionary = state["map"]["fields"][index]
		var node: int = count + index
		var anchors: Array[int] = ECON.field_access_systems(state["map"], field)
		assert(not anchors.is_empty())
		for anchor in anchors:
			assert(graph["edges"].has([anchor, node]))
		field["chunks"].clear()
		assert(ECON.military_graph(state)["adjacent"][node] == anchors)
		for anchor in anchors:
			assert(ECON.military_graph(state)["edges"].has([anchor, node]))
	var field_pos: Vector2 = graph["points"][count]
	var fighter: Dictionary = {"id": 9515, "owner": 1, "kind": "fighter", "at": count, "route": [], "position": field_pos, "dest": count, "hp": ECON.SHIP_HP}
	state["ships"] = [fighter]
	assert(ECON.command_fighters(state, 1, [9515], count))
	var max_distance: float = 0.0
	for tick in range(100):
		var before: Vector2 = fighter["position"]
		ECON.step(state, 0.5)
		assert(fighter["at"] == count and fighter["route"].is_empty())
		assert(ECON.sector_contains(graph, count, fighter["position"]))
		assert(before.distance_to(fighter["position"]) <= ECON.ship_speed(str(fighter["kind"])) * 0.5 + 0.01)
		max_distance = maxf(max_distance, field_pos.distance_to(fighter["position"]))
	assert(max_distance > ECON.AI_RALLY_RADIUS)
	print("PASS: depleted asteroid access routes and sector-bounded patrol")

func _test_wide_patrol_rally_and_conquest() -> void:
	var map_data: Dictionary = {"seed": 827, "points": [Vector2.ZERO, Vector2(2000, 0)], "edges": [[0, 1]], "fields": []}
	var state: Dictionary = ECON.create(map_data, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var graph: Dictionary = ECON.military_graph(state)
	for i in range(3):
		state["ships"].append({"id": 9520 + i, "owner": 1, "kind": "fighter", "at": 0, "dest": 0, "route": [], "position": Vector2(-600.0, 20.0 * i), "hp": ECON.SHIP_HP})
	assert(ECON.command_fighters(state, 1, [9520, 9521, 9522], 1))
	state["elapsed"] = 20.0
	var launched: bool = false
	for tick in range(80):
		var before: Vector2 = state["ships"][0]["position"]
		ECON.step(state, 0.5)
		assert(before.distance_to(state["ships"][0]["position"]) <= ECON.ship_speed(str(state["ships"][0]["kind"])) * 0.5 + 0.01)
		if int(state["ships"][0]["dest"]) == 1:
			launched = true
			break
	assert(launched)
	for ship in state["ships"]:
		assert(ship["dest"] == 1 and not ship["route"].is_empty())
	# A physical local defender wandering beyond laser range still contests
	# the sector; widening patrols must not grant uncontested conquest.
	state["planets"][1]["yards"].clear()
	state["planets"][1]["pds"].clear()
	var attacker: Dictionary = {"id": 9530, "owner": 1, "kind": "fighter", "at": 1, "dest": 1, "operation_target": 1, "route": [], "position": Vector2(2000, 0), "hp": ECON.SHIP_HP}
	var defender: Dictionary = {"id": 9531, "owner": 2, "kind": "fighter", "at": 1, "dest": 1, "route": [], "position": Vector2(2500, 0), "hp": ECON.SHIP_HP}
	state["ships"] = [attacker, defender]
	assert(ECON.sector_contains(graph, 1, defender["position"]))
	assert((defender["position"] as Vector2).distance_to(attacker["position"]) > ECON.LASER_RANGE)
	assert(ECON.territory_claims(state)[1] == 0 and state["planets"][1]["owner"] == 2)
	state["ships"].erase(defender)
	assert(state["planets"][1]["owner"] == 2 and ECON.has_station(state["planets"][1]))
	print("PASS: wide patrol returns to physical rally and defenders contest their sector")

func _test_ai_defensive_orders() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(827, 2, "Grid"), {1: {"team": 1}, 2: {"team": 2, "ai": true}}, [1, 2], false)
	var graph: Dictionary = ECON.military_graph(state)
	var owned: Array[int] = [1]
	var fighters: Array = []
	for i in range(8):
		fighters.append({"id": 9700 + i, "owner": 2, "kind": "fighter", "at": 1, "dest": 1, "route": [], "position": graph["points"][1], "hp": ECON.SHIP_HP})
	state["ships"] = fighters.duplicate()
	ECON._ai_military_orders(state, graph, 2, 1, owned, fighters)
	assert(fighters.filter(func(ship: Dictionary) -> bool: return ship.get("operation_target", -1) == 0).size() == 6)
	var intruder: Dictionary = {"id": 9800, "owner": 1, "kind": "fighter", "at": 1, "dest": 1, "route": [], "position": graph["points"][1], "hp": ECON.SHIP_HP}
	state["ships"].append(intruder)
	ECON._ai_military_orders(state, graph, 2, 1, owned, fighters)
	assert(fighters.filter(func(ship: Dictionary) -> bool: return ship.get("operation_target", -1) == 1).size() == 5)
	# Four hulls in repair aren't available to cover a defensive response.
	for i in range(4):
		fighters[i]["retreating"] = true
	ECON._ai_military_orders(state, graph, 2, 1, owned, fighters)
	for i in range(4, 8):
		assert(fighters[i]["operation_target"] == 1)
	for craft in fighters:
		craft["retreating"] = false
	state["ships"].erase(intruder)
	ECON._ai_military_orders(state, graph, 2, 1, owned, fighters)
	assert(fighters.filter(func(ship: Dictionary) -> bool: return ship.get("operation_target", -1) == 0).size() == 6)
	print("PASS: AI direct orders and defense allocation")

func _test_blaster_bursts() -> void:
	for kind in ["scout", "fighter", "cruiser", "destroyer"]:
		var mounts: int = ECON.blaster_count(kind)
		var state: Dictionary = {"elapsed": 0.0}
		var ship: Dictionary = {"id": 1, "kind": kind}
		var damage: Dictionary = {}
		var positions: Dictionary = {1: Vector2.ZERO, 2: Vector2(100, 0)}
		var health: Dictionary = {2: 1000.0}
		for tick in range(10):
			state["elapsed"] += 0.1
			ECON._fire_blaster(state, ship, 2, positions, damage, {}, health, 0.1)
		assert(is_equal_approx(float(damage[2]), ECON.BLASTER_DAMAGE * mounts * 4))
		for tick in range(5):
			state["elapsed"] += 0.1
			ECON._fire_blaster(state, ship, 2, positions, damage, {}, health, 0.1)
		assert(is_equal_approx(float(damage[2]), ECON.BLASTER_DAMAGE * mounts * 4))
		state["elapsed"] += 0.1
		ECON._fire_blaster(state, ship, 2, positions, damage, {}, health, 0.1)
		assert(is_equal_approx(float(damage[2]), ECON.BLASTER_DAMAGE * mounts * 5))
	assert(ECON.blaster_count("scout") == 1 and ECON.blaster_count("fighter") == 2)
	assert(ECON.blaster_count("cruiser") == 3 and ECON.blaster_count("destroyer") == 4)
	assert(ECON.armed({"kind": "scout"}) and ECON.capital_lasers("fighter") == 0)
	print("PASS: blaster mounts, four-shot burst and half-second pause")

func _test_territory_influence() -> void:
	var map: Dictionary = {"seed": 42, "size": Vector2(10000, 5000), "points": [Vector2(500, 500), Vector2(2500, 500), Vector2(6500, 500), Vector2(8500, 500)], "edges": [[0, 1], [1, 2], [2, 3]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var graph: Dictionary = ECON.military_graph(state)
	for system in state["planets"]:
		system["owner"] = 0
		system["station"] = {}
		system["yards"] = []
		system["pds"] = {}
		system["buildings"] = {}
		system["orbital_housing"] = 0
	var home: Dictionary = state["planets"][0]
	home["owner"] = 1
	home["station"] = {"hp": ECON.STATION_HP}
	home["yards"] = [{"level": 1}, {"level": 3}]
	state["ships"] = [
		{"id": 1, "owner": 2, "kind": "fighter", "position": Vector2(500, 500)},
		{"id": 2, "owner": 1, "kind": "scout", "position": Vector2(4400, 600)},
		{"id": 3, "owner": 2, "kind": "destroyer", "position": Vector2(4600, 600)},
		{"id": 4, "owner": 1, "kind": "cruiser", "position": Vector2(4500, 2500)},
	]
	var weights: Array[Dictionary] = ECON.territory_influence(state, graph)
	assert(weights[0] == {1: 70, 2: 2})
	var layout: Dictionary = ECON.highway_regions(graph)
	assert(layout["counts"] == [1, 2, 1] and layout["starts"] == [4, 5, 7])
	assert(layout["links"] == [Vector2i(0, 4), Vector2i(4, 1), Vector2i(1, 5), Vector2i(5, 6), Vector2i(6, 2), Vector2i(2, 7), Vector2i(7, 3)])
	assert(is_equal_approx(float(weights[4][1]), 3.5) and is_equal_approx(float(weights[4][2]), 0.1))
	assert(ECON.territory_influence(state, graph, [0])[4].is_empty())
	assert(ECON.territory_influence(state, graph, [1])[0].is_empty())
	assert(weights.size() == 8 and weights[5] == {1: 1} and weights[6] == {2: 10} and weights[1].is_empty() and weights[2].is_empty())
	assert(ECON.influence_region(graph, Vector2(4500, 600)) == 6)
	assert(ECON.lane_direct(graph, Vector2(4400, 600), Vector2(4600, 600), [0, 1, 2, 3]))
	assert(ECON.lane_direct(graph, Vector2(500, 500), Vector2(4500, 2500), [0, 1, 2, 3]))
	var palette: Dictionary = {1: Color.RED, 2: Color.BLUE}
	var mixed: Color = ECON.influence_color(weights[0], palette)
	assert(is_equal_approx(mixed.r, 70.0 / 72.0) and is_equal_approx(mixed.b, 2.0 / 72.0) and mixed.a == 1.0)
	assert(is_equal_approx(ECON.influence_color(weights[5], palette).a, 1.0 / 50.0))
	assert(is_equal_approx(ECON.influence_color(weights[6], palette).a, 10.0 / 50.0))
	assert(ECON.influence_color({}, palette).a == 0.0)
	state["ships"][1]["position"] = Vector2(2500, 500)
	weights = ECON.territory_influence(state, graph)
	assert(weights[1] == {1: 1} and weights[5].is_empty() and weights[6] == {2: 10})
	home["yards"].pop_back()
	home["pds"][0] = {"hp": ECON.PDS_HP}
	weights = ECON.territory_influence(state, graph)
	assert(weights[0] == {1: 60, 2: 2} and home["owner"] == 1)
	assert(ECON.territory_influence(bytes_to_var(var_to_bytes(state)), graph) == weights)
	# Stronger-to-weaker only, threshold inclusive, proportional mixed
	# colors, multiple donors, equal totals and no second-hop propagation.
	var raw: Array[Dictionary] = [{1: 400, 2: 100}, {2: 49}, {}, {1: 50}, {2: 50}, {2: 25}, {1: 49}]
	var links: Array = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(3, 4), Vector2i(3, 5), Vector2i(0, 5), Vector2i(6, 2)]
	var added: Array[Dictionary] = ECON.influence_spillover(raw, links)
	assert(added[0] == raw[0] and added[1] == {1: 20.0, 2: 54.0})
	assert(added[2].is_empty() and added[3] == raw[3] and added[4] == raw[4])
	assert(added[5] == {1: 22.5, 2: 30.0} and added[6] == raw[6])
	assert(raw[1] == {2: 49} and raw[5] == {2: 25})
	print("PASS: physical sector/highway influence, infrastructure, normalized mixed colors, saturation cap, one-hop spillover and snapshot parity")

func _test_conquest() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(827, 2, "Grid"), {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var graph: Dictionary = ECON.military_graph(state)
	var planet: Dictionary = state["planets"][1]
	planet["pds"].clear()
	planet["yards"][0]["hp"] = ECON.BLASTER_DAMAGE * ECON.BLASTER_SHOTS * ECON.blaster_count("fighter")
	var attacker: Dictionary = {"id": 9900, "owner": 1, "kind": "fighter", "at": 1, "dest": 1, "operation_target": 1, "route": [], "position": ECON.shipyard_position(state, 1, 0, 0.0), "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock()}
	state["ships"] = [attacker]
	ECON._combat(state, graph, 1.0)
	assert(planet["yards"].is_empty() and int(planet["owner"]) == 2 and ECON.has_station(planet))
	assert(state["ship_destructions"].back()["kind"] == "shipyard")
	planet["station"]["hp"] = ECON.BLASTER_DAMAGE * ECON.BLASTER_SHOTS * ECON.blaster_count("fighter")
	attacker["position"] = ECON.station_position(state, 1, 0.0)
	attacker["blaster_cooldown"] = 0.0
	attacker["blaster_shot"] = 0
	planet["stock"][ECON.ANTIMATTER] = 50.0
	var stock: Dictionary = planet["stock"].duplicate()
	ECON._combat(state, graph, 1.0)
	assert(int(planet["owner"]) == 0 and not ECON.has_station(planet) and planet["yards"].is_empty())
	assert(planet["queue"].is_empty() and planet["pds"].is_empty() and float(planet["population"]) == 0.0)
	assert(state["ship_destructions"].back()["kind"] == "station")
	var dropped: Dictionary = ECON.empty_stock()
	for pile in state["salvage"].values():
		dropped[pile["resource"]] = float(dropped.get(pile["resource"], 0.0)) + float(pile["amount"])
	for resource in ECON.RESOURCES + [ECON.ANTIMATTER]:
		assert(is_equal_approx(float(dropped.get(resource, 0.0)), float(stock.get(resource, 0.0)) * 0.2))
		assert(float(planet["stock"].get(resource, 0.0)) == 0.0)
	for tick in range(30):
		ECON.step(state, 1.0)
	assert(int(planet["owner"]) == 0 and ECON.territory_claims(state)[1] == 0)
	assert(not ECON.set_thresholds(state, 2, 1, "Metals", 10.0, 20.0))
	assert(not ECON.set_thresholds(state, 1, 1, "Metals", 10.0, 20.0))
	var colony: Dictionary = {"id": 9901, "owner": 1, "kind": "colony_ship", "at": 1, "dest": -1, "route": [], "position": graph["points"][1], "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock()}
	state["ships"].append(colony)
	assert(ECON.send_colony(state, 1, 9901, 1, true))
	assert(ECON._work_colony(state, colony, 0.1))
	assert(int(planet["owner"]) == 1 and ECON.has_station(planet) and planet["yards"].size() == 1)
	assert(ECON.set_thresholds(state, 1, 1, "Metals", 10.0, 20.0))
	assert(int(bytes_to_var(var_to_bytes(state))["planets"][1]["owner"]) == 1)
	print("PASS: module loss preserves station claim; core destruction drops exactly 20%, neutralizes, requires colony, and replicates")

func _test_conquest_resistance_and_evacuation() -> void:
	var map: Dictionary = {"seed": 827, "points": [Vector2.ZERO, Vector2(1200, 0), Vector2(600, 0), Vector2(600, 600)], "edges": [[0, 2], [1, 2], [1, 3], [2, 3]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var graph: Dictionary = ECON.military_graph(state)
	var colony: Dictionary = state["planets"][2]
	colony["owner"] = 2
	colony["station"] = {"hp": ECON.STATION_HP}
	colony["population"] = 10000.0
	colony["pds"][0] = {"hp": ECON.BLASTER_DAMAGE * ECON.BLASTER_SHOTS * ECON.blaster_count("fighter"), "cooldown": 0.0, "target": -1, "laser_until": -1.0}
	var attacker: Dictionary = {"id": 10001, "owner": 1, "kind": "fighter", "at": 2, "dest": 2, "operation_target": 2, "route": [], "position": map["points"][2], "hp": ECON.SHIP_HP}
	state["ships"] = [attacker]
	assert(ECON.command_fighters(state, 1, [10001], 2))
	state["elapsed"] = 20.0
	ECON._combat(state, graph, 1.0)
	assert(colony["pds"].is_empty())
	assert(float(attacker["hp"]) == ECON.SHIP_HP - ECON.PDS_DAMAGE)
	var freighter: Dictionary = {"id": 10002, "owner": 2, "kind": "ship", "at": 1, "route": [2], "leg": 100.0, "position": Vector2(1100, 0), "source": -1, "dest": 2, "cargo": ECON.empty_stock()}
	freighter["cargo"]["Metals"] = 50.0
	state["ships"].append(freighter)
	var before: Vector2 = freighter["position"]
	attacker["position"] = ECON.station_position(state, 2, float(state["elapsed"]))
	attacker["blaster_cooldown"] = 0.0
	attacker["blaster_shot"] = 0
	colony["station"]["hp"] = ECON.BLASTER_DAMAGE * ECON.BLASTER_SHOTS * ECON.blaster_count("fighter")
	ECON._combat(state, graph, 1.0)
	assert(int(colony["owner"]) == 0)
	assert(freighter["position"] == before and int(freighter["dest"]) == 1)
	assert(freighter["cargo"]["Metals"] == 50.0)
	assert(not (freighter["route"] as Array).has(2))
	ECON._work_ship(state, freighter, ECON.planet_teams(state), {}, 0.1)
	assert(before.distance_to(freighter["position"]) <= ECON.ship_speed(str(freighter["kind"])) * 0.1 + 0.01)
	var dock: Vector2 = ECON.station_position(state, 1, float(state["elapsed"]))
	assert((freighter["position"] as Vector2).distance_to(dock) < before.distance_to(dock))
	print("PASS: planetary defense simultaneous damage and safe cargo-preserving station-loss reroute")

func _test_crowded_dock_delivery() -> void:
	var map: Dictionary = {"seed": 827, "points": [Vector2.ZERO, Vector2(5000, 0)], "edges": [[0, 1]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var home: Dictionary = state["planets"][0]
	var graph: Dictionary = ECON.military_graph(state)
	var dock: Vector2 = ECON.station_position(state, 0, float(state["elapsed"]))
	var a: Dictionary = {"id": 52101, "position": dock + Vector2.RIGHT * ECON.STATION_DOCK_RANGE * 0.9}
	var b: Dictionary = {"id": 52102, "position": dock}
	var berth: Vector2 = ECON._waiting_berth({"ships": [a, b]}, b, dock, ECON.STATION_DOCK_RANGE, Vector2.RIGHT)
	assert(berth.distance_to(dock) < ECON.STATION_DOCK_RANGE and berth.distance_to(a["position"]) >= ECON.SHIP_CLEARANCE)
	var guard: Dictionary = {"id": 52103, "kind": "fighter", "owner": 1, "at": 0, "dest": -1, "route": [], "leg": 0.0, "position": Vector2.ZERO, "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock()}
	state["ships"].append(guard)
	assert(not ECON.issue_unit_order(state, 2, [52103], {"kind": "guard", "target": 0, "point": Vector2.ZERO}, false))
	assert(ECON.issue_unit_order(state, 1, [52103], {"kind": "guard", "target": 0, "point": Vector2.ZERO}, false))
	assert(guard["unit_order"]["kind"] == "guard" and ECON._unit_order_running(guard))
	state["ships"].erase(guard)
	home["stock"]["Metals"] = ECON.storage_capacity(home) - 40.0
	var ship: Dictionary = {"id": 521, "owner": 1, "kind": "ship", "at": 0, "origin": 0, "route": [], "leg": 0.0, "dest": -1, "source": -1, "position": dock + Vector2.RIGHT * ECON.SHIP_CLEARANCE, "heading": Vector2.UP, "cargo": ECON.empty_stock(), "hp": ECON.SHIP_HP}
	state["ships"].append(ship)
	ship["cargo"]["Metals"] = 50.0
	home["thresholds"]["Metals"]["import"] = false
	ECON._work_ship(state, ship, ECON.planet_teams(state), {}, 0.01)
	assert(ship.get("resource_haul", false))
	assert(ECON._work_salvage(state, graph, ship, 0.01))
	assert(is_equal_approx(float(ship["cargo"]["Metals"]), 50.0 - ECON.dropoff_rate("ship") * 0.01))
	assert(ECON._work_salvage(state, graph, ship, 10.0))
	assert(is_equal_approx(float(ship["cargo"]["Metals"]), 10.0))
	assert(is_equal_approx(float(home["stock"]["Metals"]), ECON.storage_capacity(home)))
	home["stock"]["Metals"] -= 10.0
	state["elapsed"] += 1.0
	ship["position"] = ECON.station_position(state, 0, float(state["elapsed"])) + Vector2.LEFT * ECON.SHIP_CLEARANCE
	assert(ECON._work_salvage(state, graph, ship, 10.0))
	assert(ECON._cargo_total(ship) <= ECON.EPS)
	assert(is_equal_approx(float(home["stock"]["Metals"]), ECON.storage_capacity(home)))
	ship["cargo"]["Metals"] = 20.0
	home["stock"]["Metals"] -= 10.0
	assert(ECON.issue_unit_order(state, 1, [521], {"kind": "deposit", "target": ECON.station_target_id(state, 0)}, false))
	assert(ECON._work_cargo_order(state, graph, ship, ECON.service_targets(state), 10.0))
	assert(ship.has("cargo_order") and is_equal_approx(float(ship["cargo"]["Metals"]), 10.0))
	home["stock"]["Metals"] -= 10.0
	assert(ECON._work_cargo_order(state, graph, ship, ECON.service_targets(state), 10.0))
	assert(not ship.has("cargo_order") and ECON._cargo_total(ship) <= ECON.EPS)
	print("PASS: dock clearance, leftover trade cargo, partial manual deliveries and storage retry")

func _test_freighter_bays() -> void:
	var cargo: Dictionary = ECON.empty_stock()
	for bay in ECON.freighter_cargo_bays(cargo):
		assert(bay.is_empty())
	cargo["Metals"] = ECON.CARGO_CAPACITY
	var bays: Array = ECON.freighter_cargo_bays(cargo)
	assert(bays.size() == 10 and ECON.FREIGHTER_BAY_CAPACITY == 10.0)
	for bay in bays:
		assert(bay.size() == 1 and bay[0]["resource"] == "Metals")
		assert(is_equal_approx(float(bay[0]["amount"]), ECON.FREIGHTER_BAY_CAPACITY))
	cargo["Metals"] = ECON.CARGO_CAPACITY * 0.4
	cargo["Crystals"] = ECON.CARGO_CAPACITY * 0.6
	var totals: Dictionary = ECON.empty_stock()
	for bay in ECON.freighter_cargo_bays(cargo):
		var bay_total: float = 0.0
		for segment in bay:
			totals[segment["resource"]] += float(segment["amount"])
			bay_total += float(segment["amount"])
		assert(is_equal_approx(bay_total, ECON.FREIGHTER_BAY_CAPACITY))
	assert(is_equal_approx(float(totals["Metals"]), ECON.CARGO_CAPACITY * 0.4))
	assert(is_equal_approx(float(totals["Crystals"]), ECON.CARGO_CAPACITY * 0.6))
	cargo = ECON.empty_stock()
	cargo["Crystals"] = 0.5
	bays = ECON.freighter_cargo_bays(cargo)
	assert(is_equal_approx(float(bays[0][0]["amount"]), 0.5))
	for index in range(1, bays.size()):
		assert(bays[index].is_empty())
	# An actual freight trip can load and deliver a full hold of one resource.
	var map: Dictionary = {"seed": 827, "points": [Vector2.ZERO, Vector2(190.0, 0)], "edges": [[0, 1]], "fields": []}
	var state: Dictionary = ECON.create(map, {1: {"team": 1}, 2: {"team": 1}}, [1, 2], false)
	var source: Dictionary = state["planets"][0]
	var destination: Dictionary = state["planets"][1]
	source["stock"]["Metals"] = 1000.0
	source["thresholds"]["Metals"]["max"] = 20.0
	destination["stock"]["Metals"] = 0.0
	var ship: Dictionary = {"id": 1, "kind": "ship", "owner": 1, "at": 0, "route": [], "leg": 0.0, "position": ECON.station_position(state, 0, 0.0) - Vector2.RIGHT * 150.0, "source": 0, "dest": 1, "cargo": ECON.empty_stock()}
	ECON._work_ship(state, ship, ECON.planet_teams(state), {}, 0.1)
	assert(is_zero_approx(ECON._cargo_total(ship)))
	for tick in range(100):
		ECON._work_ship(state, ship, ECON.planet_teams(state), {}, 0.1)
		if ECON._cargo_total(ship) > ECON.EPS:
			break
	assert((ship["position"] as Vector2).distance_to(ECON.station_position(state, 0, 0.0)) <= ECON.STATION_DOCK_RANGE + ECON.EPS)
	assert(is_equal_approx(float(ship["cargo"]["Metals"]), ECON.CARGO_CAPACITY))
	assert(is_equal_approx(ECON._cargo_total(ship), ECON.CARGO_CAPACITY))
	assert(is_equal_approx(float(source["stock"]["Metals"]), 1000.0 - ECON.CARGO_CAPACITY))
	assert(float(destination["stock"]["Metals"]) == 0.0)
	ECON._work_ship(state, ship, ECON.planet_teams(state), {}, 20.0)
	assert((ship["position"] as Vector2).distance_to(ECON.station_position(state, 1, 0.0)) <= ECON.STATION_DOCK_RANGE + ECON.EPS)
	assert(is_equal_approx(float(destination["stock"]["Metals"]), ECON.CARGO_CAPACITY))
	assert(is_zero_approx(ECON._cargo_total(ship)))
	print("PASS: ten shared ten-ton bays, full single-resource and mixed loads, partial and empty cargo")

# Contract only degree-two standalone connectors to inspect the original
# cluster-level topology without pretending they are a single cluster.
func _cluster_links(galaxy: Dictionary) -> Dictionary:
	var clusters: Array = galaxy["clusters"]
	var adjacency: Array = []
	for point in galaxy["points"]:
		adjacency.append([])
	for edge in galaxy["edges"]:
		adjacency[edge[0]].append(edge[1])
		adjacency[edge[1]].append(edge[0])
	var links: Dictionary = {}
	for node in range(clusters.size()):
		var a: int = clusters[node]
		if a < 0:
			assert(adjacency[node].size() == 2)
			continue
		for neighbor in adjacency[node]:
			var previous: int = node
			var current: int = neighbor
			while int(clusters[current]) < 0:
				var next: int = adjacency[current][0] if adjacency[current][1] == previous else adjacency[current][1]
				previous = current
				current = next
			var b: int = clusters[current]
			if a != b:
				links[Vector2i(mini(a, b), maxi(a, b))] = true
	return links

func _test_radial_nearest_ports() -> void:
	# Node 0 has two local connections but is directly between node 1 and
	# the other cluster. The former zero-junction preference chose node 1.
	var points: Array[Vector2] = [Vector2(100, 0), Vector2.ZERO, Vector2(100, 300), Vector2(300, 0)]
	var groups: Array = [[0, 1, 2], [3]]
	var edges: Array = [[0, 1], [0, 2]]
	var degrees: Array[int] = [2, 1, 1, 0]
	MAP._connect_radial_bridges(points, groups, [[0, 1]], edges, degrees)
	assert(edges.has([0, 3]) and not edges.has([1, 3]))
	assert(degrees == [3, 1, 1, 1])
	print("PASS: radial links choose the nearest endpoint even at its third port")

func _test_map_layouts() -> void:
	assert(MAP.generate(7021, 3)["layout"] == MAP.DEFAULT_LAYOUT)
	assert(not MAP.valid_layout("invalid"))
	for layout in MAP.LAYOUTS:
		for player_count in range(1, 9):
			for seed_value in [31, 7021]:
				var galaxy: Dictionary = MAP.generate(seed_value, player_count, layout)
				assert(galaxy == MAP.generate(seed_value, player_count, layout))
				assert(galaxy["layout"] == layout)
				assert(galaxy["planetless"].size() == floori(float(galaxy["points"].size()) * 0.5))
				for home in range(player_count):
					assert(not galaxy["planetless"].has(home))
				assert(galaxy["cluster_sizes"].size() == MAP.cluster_count_for(player_count, layout))
				assert(galaxy["points"].size() <= player_count * MAP.SYSTEMS_PER_PLAYER)
				if layout == "Radial" and player_count > 1:
					var sectors: int = maxi(3, player_count)
					var bridges: Dictionary = _cluster_links(galaxy)
					for sector in range(sectors):
						var next: int = (sector + 1) % sectors
						assert(bridges.has(Vector2i(mini(sector, next), maxi(sector, next))))
						assert(bridges.has(Vector2i(sectors + mini(sector, next), sectors + maxi(sector, next))))
						assert(bridges.has(Vector2i(sector, sector + sectors)))
				if layout == "Hex Grid":
					for group in range(galaxy["cluster_sizes"].size()):
						var local_degrees: Dictionary = {}
						for node in range(galaxy["points"].size()):
							if galaxy["clusters"][node] == group:
								local_degrees[node] = 0
						assert(local_degrees.size() == 6)
						for edge in galaxy["edges"]:
							if local_degrees.has(edge[0]) and local_degrees.has(edge[1]):
								local_degrees[edge[0]] += 1
								local_degrees[edge[1]] += 1
						for degree in local_degrees.values():
							assert(degree == 2)
				if layout == "Grid" or layout == "Hex Grid":
					# Fine grid cells are regular, and neighboring blocks form
					# cycles rather than only a spanning tree.
					var local_length: float = 0.0
					for edge in galaxy["edges"]:
						var a: int = edge[0]
						var b: int = edge[1]
						if galaxy["clusters"][a] < 0 or galaxy["clusters"][a] != galaxy["clusters"][b]:
							continue
						var delta: Vector2 = galaxy["points"][a] - galaxy["points"][b]
						if local_length == 0.0:
							local_length = delta.length()
						assert(is_equal_approx(delta.length(), local_length))
						if layout == "Grid":
							assert(absf(delta.x) < 0.01 or absf(delta.y) < 0.01)
					if (layout == "Grid" and player_count >= 2) or (layout == "Hex Grid" and player_count >= 3):
						assert(_cluster_links(galaxy).size() >= galaxy["cluster_sizes"].size())
				var points: Array = galaxy["points"]
				var degrees: Array[int] = []
				degrees.resize(points.size())
				degrees.fill(0)
				var adjacency: Array = []
				for point in points:
					adjacency.append([])
				var longest: float = 0.0
				for edge in galaxy["edges"]:
					degrees[edge[0]] += 1
					degrees[edge[1]] += 1
					adjacency[edge[0]].append(edge[1])
					adjacency[edge[1]].append(edge[0])
					assert(not MAP.blocked(points[edge[0]], points[edge[1]], galaxy["fields"]))
					longest = maxf(longest, (points[edge[0]] as Vector2).distance_to(points[edge[1]]))
				assert(is_equal_approx(longest / MAP.TRAVEL_SPEED, MAP.LONGEST_LINK_YEARS))
				var clustered_count: int = 0
				for group in range(galaxy["cluster_sizes"].size()):
					var members: int = galaxy["clusters"].count(group)
					assert(members == int(galaxy["cluster_sizes"][group]) and members >= 2)
					clustered_count += members
				assert(clustered_count + galaxy["clusters"].count(-1) == points.size())
				assert(absi(galaxy["clusters"].count(-1) - roundi(float(points.size()) * 0.2)) <= 1)
				assert(degrees.count(3) <= int(galaxy["max_junctions"]))
				for degree in degrees:
					assert(degree > 0 and degree <= MAP.MAX_CONNECTIONS)
				var seen: Dictionary = {0: true}
				var frontier: Array = [0]
				while not frontier.is_empty():
					var node: int = frontier.pop_back()
					for neighbor in adjacency[node]:
						if not seen.has(neighbor):
							seen[neighbor] = true
							frontier.append(neighbor)
				assert(seen.size() == points.size())
				for home in range(player_count):
					assert(galaxy["clusters"][home] == home)
					assert(adjacency[home].any(func(node: int) -> bool: return node >= player_count))
				var total_degrees: Array[int] = degrees.duplicate()
				for field in galaxy["fields"]:
					var links: Array[int] = ECON.field_access_systems(galaxy, field)
					assert(links.size() >= 1 and links.size() <= MAP.MAX_CONNECTIONS)
					assert(links.has(int(field["anchor"])))
					for anchor in links:
						total_degrees[anchor] += 1
				for degree in total_degrees:
					assert(degree <= MAP.MAX_CONNECTIONS)
				var graph: Dictionary = ECON.military_graph({"map": galaxy})
				for neighbors in graph["adjacent"]:
					assert(neighbors.size() <= MAP.MAX_CONNECTIONS)
				var central_nodes: Array[int] = []
				for index in range(galaxy["fields"].size()):
					if galaxy["fields"][index].get("antimatter", false):
						central_nodes.append(points.size() + index)
				if layout == "Radial" and central_nodes.size() == 2:
					assert(graph["adjacent"][central_nodes[0]].has(central_nodes[1]))
					assert(ECON._military_paths(graph, central_nodes[1])["next"][central_nodes[0]] == central_nodes[1])
				var deposits: int = 0
				for field in galaxy["fields"]:
					if not bool(field.get("antimatter", false)):
						continue
					deposits += 1
					var access: Array[int] = ECON.field_access_systems(galaxy, field)
					var center: Vector2 = field["position"]
					for home in range(player_count):
						assert(not access.has(home))
						assert(center.distance_to(points[home]) - float(field["radius"]) + 0.01 >= float(galaxy["antimatter_home_clearance"]))
						if layout == "Radial":
							assert(center.distance_to(galaxy["size"] * 0.5) < (points[home] as Vector2).distance_to(galaxy["size"] * 0.5) * 0.3)
				assert(deposits == (1 if player_count <= 2 else 2))
	assert(MAP.generate(7021, 4, "Radial")["points"] != MAP.generate(7021, 4, "Grid")["points"])
	assert(MAP.generate(7021, 4, "Grid")["points"] != MAP.generate(7021, 4, "Scramble")["points"])
	assert(MAP.generate(7021, 4, "Grid")["points"] != MAP.generate(7021, 4, "Hex Grid")["points"])
	print("PASS: all map layouts, seed reproducibility, connected routes and protected antimatter")

func _test_orbital_housing() -> void:
	var galaxy: Dictionary = MAP.generate(827, 2, "Grid")
	var state: Dictionary = ECON.create(galaxy, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var index: int = galaxy["planetless"][0]
	var p: Dictionary = state["planets"][index]
	assert(p["planet_count"] == 0 and ECON.system_bodies(p, 827, index).is_empty())
	assert(not ECON.enqueue(state, 1, index, "economy", "orbital_housing"))
	assert(not ECON.enqueue(state, 1, 0, "economy", "orbital_housing"))
	var graph: Dictionary = ECON.military_graph(state)
	var attacker: Dictionary = {"id": 9900, "owner": 1, "kind": "fighter", "at": index, "dest": index, "operation_target": index, "route": [], "position": graph["points"][index], "hp": ECON.SHIP_HP}
	state["ships"] = [attacker]
	ECON.step(state, 1.0)
	assert(int(p["owner"]) == 0)
	var settlement: Dictionary = {"id": 9902, "owner": 1, "kind": "colony_ship", "at": index, "dest": -1, "route": [], "position": graph["points"][index], "hp": ECON.SHIP_HP, "cargo": ECON.empty_stock()}
	state["ships"].append(settlement)
	assert(ECON.send_colony(state, 1, 9902, index, true))
	assert(ECON._work_colony(state, settlement, 0.1))
	assert(int(p["owner"]) == 1 and float(p["population"]) == ECON.ORBITAL_HOUSING_POPULATION and ECON.has_station(p))
	for resource in ECON.ORBITAL_HOUSING_COST:
		p["stock"][resource] = float(ECON.ORBITAL_HOUSING_COST[resource]) * 2.0
	assert(not ECON.enqueue(state, 2, index, "economy", "orbital_housing"))
	for purchase in range(2):
		assert(ECON.enqueue(state, 1, index, "economy", "orbital_housing"))
		assert(int(p["orbital_housing"]) == purchase and p["queue"][-1]["kind"] == "orbital_housing")
		ECON._work_planet(state, index, 1.0)
		assert(int(p["orbital_housing"]) == purchase)
		ECON._work_planet(state, index, ECON._work("orbital_housing", 1) - 1.0)
		assert(float(p["population"]) == ECON.ORBITAL_HOUSING_POPULATION * (purchase + 2))
		assert(int(p["orbital_housing"]) == purchase + 1)
	assert(not ECON.enqueue(state, 1, index, "economy", "orbital_housing"))
	assert(not ECON.enqueue(state, 1, index, "pds"))
	assert(not ECON.production_available(p, "Organics"))
	assert(not ECON.production_available(p, "Metals"))
	assert(not ECON.production_available(p, "Crystals"))
	assert(ECON.overpopulation_penalty(p) == 0.0)
	var stock: Dictionary = p["stock"].duplicate()
	for tick in range(30):
		ECON._work_planet(state, index, 1.0)
	assert(float(p["population"]) == 15000.0)
	for resource in ECON.RESOURCES:
		var expected: float = float(stock[resource]) + (3.0 * ECON.ECO_HOUSING_ORGANICS * 30.0 if resource == "Organics" else (30.0 * ECON.STATION_CRYSTALS_PER_YEAR if resource == "Crystals" else 0.0))
		assert(is_equal_approx(float(p["stock"][resource]), expected))
	for resource in ECON.RESOURCES:
		assert(ECON.consumption(p, resource) == 0.0)
		assert(ECON.local_flow(p, "Population", resource) == 0.0)
	var colony: Dictionary = {"owner": 1, "kind": "colony_ship", "at": 0, "route": []}
	assert(not ECON.colony_path(state, 1, colony, galaxy["planetless"][1]).is_empty())
	print("PASS: planetless station colonization and prepaid repeatable self-sufficient orbital housing")

func _test_eco_regrowth() -> void:
	var galaxy: Dictionary = MAP.generate(827, 1, "Grid")
	var state: Dictionary = ECON.create(galaxy, {1: {"team": 1}}, [1], false)
	var home: Dictionary = state["planets"][0]
	assert(ECON.eco_capacity(home) == 5000.0)
	assert(ECON.eco_population(home) == 5000.0 and ECON.planetary_population(home) == ECON.HOME_POPULATION)
	assert(is_equal_approx(ECON.eco_organics(home), 0.2))
	assert(is_equal_approx(ECON.organics_demand(home), ECON.HOME_POPULATION / ECON.POPULATION_PER_ORGANICS_RATE))
	assert(not ECON.enqueue(state, 1, 0, "economy", "orbital_housing"))
	var index: int = galaxy["planetless"][0]
	var p: Dictionary = state["planets"][index]
	p["owner"] = 1
	p["station"] = {"hp": ECON.STATION_HP}
	for resource in ECON.RESOURCES:
		p["stock"][resource] = 2000.0
	assert(ECON.enqueue(state, 1, index, "yard"))
	var job: Dictionary = p["queue"][0]
	assert(ECON.eco_capacity(p) == 0.0 and float(p["population"]) == 0.0)
	assert(ECON._advance(p, job, float(job["work"])))
	ECON._finish(state, index, p, job)
	assert(ECON.eco_population(p) == 5000.0 and ECON.eco_capacity(p) == 5000.0)
	assert(ECON.shipyard_operational(p, 0))
	assert(is_equal_approx(ECON.rate(p, "Organics"), 0.2))
	assert(ECON.enqueue(state, 1, index, "economy", "orbital_housing"))
	ECON._work_planet(state, index, ECON._work("orbital_housing", 1))
	assert(ECON.eco_capacity(p) == 10000.0 and float(p["population"]) == 10000.0)
	assert(is_equal_approx(ECON.rate(p, "Organics"), 0.4))
	assert(ECON.enqueue(state, 1, index, "fighter"))
	job = p["queue"][0]
	assert(ECON._advance(p, job, float(job["work"])))
	assert(float(p["population"]) == 9500.0 and float(job["eco_allocated"]) == 500.0)
	ECON._finish(state, index, p, job)
	for resource in ECON.RESOURCES:
		p["stock"][resource] = 0.0
	assert(ECON.food_growth_multiplier(p) == 1.0)
	ECON._update_population(p, 1.0)
	assert(is_equal_approx(float(p["population"]), 9500.0 * exp(log(2.0) / 60.0)))
	ECON._update_population(p, 60.0)
	assert(float(p["population"]) == 10000.0)
	assert(ECON.consumption(p, "Organics") == 0.0)
	assert(ECON.overpopulation_penalty(p) == 0.0)
	assert(is_equal_approx(ECON.rate(p, "Organics"), 0.4))
	# Level upgrades do not create another housing module.
	ECON._finish(state, index, p, {"kind": "yard_upgrade", "target": "0", "level": 2})
	assert(ECON.eco_capacity(p) == 10000.0 and float(p["population"]) == 10000.0)
	print("PASS: shipyard and orbital housing, shared crew, independent regeneration, net organic surplus")

func _test_antimatter_extraction() -> void:
	for player_count in range(1, 9):
		var galaxy: Dictionary = _planetary_fixture(7021, player_count, "Radial")
		var center: Vector2 = galaxy["size"] * 0.5
		var furthest_special: float = 0.0
		var nearest_ordinary: float = INF
		var special_count: int = 0
		for field in galaxy["fields"]:
			var distance: float = center.distance_to(field["position"])
			if bool(field.get("antimatter", false)):
				special_count += 1
				furthest_special = maxf(furthest_special, distance)
				assert(ECON.field_inventory(field)[ECON.ANTIMATTER] > 0.0)
				assert(ECON.field_inventory(field)["Metals"] == 0.0)
				assert(ECON.field_inventory(field)["Crystals"] == 0.0)
			else:
				nearest_ordinary = minf(nearest_ordinary, distance)
				assert(ECON.field_inventory(field)[ECON.ANTIMATTER] == 0.0)
		assert(special_count == (1 if player_count <= 2 else 2))
		assert(furthest_special <= nearest_ordinary)
	var map_data: Dictionary = _planetary_fixture(7021, 2, "Grid")
	var points: Array = map_data["points"]
	var deposit: Vector2 = points[0] + Vector2(400.0, 0.0)
	map_data["field_edges"] = []
	map_data["fields"] = [{"anchor": 0, "position": deposit, "radius": 50.0, "antimatter": true,
		"Metals": 0.0, "Crystals": 0.0, ECON.ANTIMATTER: 1.0,
		"chunks": [{"id": 0, "position": deposit, "resource": ECON.ANTIMATTER, "remaining": 30.0}]}]
	var state: Dictionary = ECON.create(map_data, {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	var home: Dictionary = state["planets"][0]
	ECON._finish(state, 0, home, {"id": 900, "kind": "miner"})
	var miner: Dictionary = state["ships"][0]
	assert(not ECON.mining_policy(state, 1, 0)["enabled"])
	assert(not ECON.set_mining_policy(state, 3, 0, true, false, false))
	ECON.step(state, 1.0)
	assert(miner["mining_mode"] == "idle")
	assert(ECON.set_mining_policy(state, 1, 0, true, false, false))
	assert(not ECON.command_miners(state, 1, [900], 0))
	ECON._finish(state, 0, home, {"id": 901, "kind": "science_ship"})
	var craft: Dictionary = state["ships"].back()
	var graph: Dictionary = ECON.military_graph(state)
	assert(ECON.supports_autocast(craft, "collect") and not ECON.autocast_enabled(craft, "collect"))
	assert(not ECON._work_science(state, graph, craft, 1.0))
	assert(not ECON.set_autocast(state, 2, [901], "collect", true))
	assert(not ECON.set_autocast(state, 1, [900], "collect", true))
	assert(ECON.set_autocast(state, 1, [901], "collect", true))
	assert(ECON._work_science(state, graph, craft, 0.1))
	assert(craft["unit_order"].get("automatic", false))
	assert(ECON.set_autocast(state, 1, [901], "collect", false))
	assert(not craft.has("unit_order"))
	assert(not ECON.issue_unit_order(state, 2, [901], {"kind": "collect", "target": 0}, false))
	assert(ECON.issue_unit_order(state, 1, [901], {"kind": "collect", "target": 0}, false))
	var traveler: Dictionary = craft.duplicate(true)
	traveler["position"] = points[1]
	traveler["at"] = 1
	traveler["dest"] = 0
	traveler["route"] = [0]
	var before: Vector2 = traveler["position"]
	ECON._manual_travel(state, graph, traveler, state["planets"].size(), deposit, 0.1, 10.0)
	assert((before.direction_to(traveler["position"])).dot(before.direction_to(points[0])) > 0.999)
	craft["position"] = deposit
	assert(ECON._work_science(state, graph, craft, 29.0))
	assert(ECON._cargo_total(craft) == 0.0)
	assert(ECON._work_science(state, graph, craft, 1.0))
	assert(ECON._cargo_total(craft) == 1.0)
	assert(ECON.field_inventory(map_data["fields"][0])[ECON.ANTIMATTER] == 29.0)
	assert(not ECON.issue_unit_order(state, 1, [901], {"kind": "collect", "target": 0}, false))
	assert(not ECON.command_unload_cargo(state, 1, [901]))
	assert(ECON.raw_antimatter_totals(bytes_to_var(var_to_bytes(state)), 1)["cargo"] == 1.0)
	print("PASS: Pulsar generation, science-only collection, 30-year timer, retained cargo and state serialization")

func _test_match_elimination() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(827, 3, "Grid"), {1: {"team": 1}, 2: {"team": 2}, 3: {"team": 2}}, [1, 2, 3], false)
	state["planets"][1]["owner"] = 1
	var colony: Dictionary = {"id": 11000, "kind": "colony_ship", "owner": 2, "at": 1, "route": [], "dest": -1}
	state["ships"].append(colony)
	assert(not ECON.update_match_outcome(state))
	assert(not state.get("eliminated", []).has(2))
	var target: int = 3
	assert(not ECON.colony_path(state, 2, colony, target).is_empty())
	assert(ECON.send_colony(state, 2, 11000, target, true))
	state["ships"].erase(colony)
	assert(ECON.update_match_outcome(state))
	assert(state["eliminated"].has(2) and state.get("match_result", {}).is_empty())
	state["planets"][2]["owner"] = 1
	assert(ECON.update_match_outcome(state))
	assert(state["match_result"]["team"] == 1 and int(state["time_speed"]) == 0)
	assert(not ECON.update_match_outcome(state))
	assert(bytes_to_var(var_to_bytes(state))["match_result"] == state["match_result"])
	var solo: Dictionary = ECON.create(_planetary_fixture(827, 1, "Grid"), {1: {"team": 1}}, [1], false)
	assert(not ECON.update_match_outcome(solo) and solo.get("match_result", {}).is_empty())
	print("PASS: colony recovery, allied survival, elimination, conquest victory and sandbox")

func _test_recovery_economy() -> void:
	var state: Dictionary = ECON.create(_planetary_fixture(827, 1, "Grid"), {1: {"team": 1}}, [1], false)
	var p: Dictionary = state["planets"][0]
	for resource in ECON.RESOURCES:
		assert(not ECON.building_cost(p, resource).has(resource))
		assert(ECON.building_available(p, resource))
	p["yards"][0]["level"] = 2
	assert(ECON.enqueue(state, 1, 0, "colony_ship"))
	var colony_job: Dictionary = p["queue"][0]
	var starting: float = float(p["population"])
	assert("Population" in ECON.construction_blockers(p, colony_job))
	assert(not ECON._advance(p, colony_job, 6.0))
	assert(float(p["population"]) == starting and float(colony_job["progress"]) == 0.0)
	p["population"] = ECON.COLONY_POPULATION + ECON.SHIPYARD_POPULATION[0]
	for resource in ECON.RESOURCES:
		p["stock"][resource] = ECON.storage_capacity(p)
	assert(ECON._advance(p, colony_job, float(colony_job["work"])))
	assert(is_equal_approx(float(p["population"]), ECON.SHIPYARD_POPULATION[0]))
	assert(ECON.cancel(state, 1, 0, int(colony_job["id"])))
	p["warehouse_level"] = 2
	assert(ECON.construction_reserve(p, "Metals") == 4500.0)
	p["warehouse_level"] = 0
	p["population"] = 1000000.0
	p["stock"] = ECON.empty_stock()
	for resource in ["Metals"]:
		assert(ECON.rate(p, resource) > 0.0)
	for i in range(120):
		ECON._work_planet(state, 0, 1.0)
	for resource in ["Metals"]:
		assert(float(p["stock"][resource]) > 0.0)
	assert(is_equal_approx(ECON.overpopulation_penalty(p), pow(clampf(ECON.planetary_population(p) / ECON.habitation_capacity(p), 0.0, 1.0), 3.0)))
	# A depleted economy can recover enough to prepay a building.
	for i in range(1200):
		if ECON.affordable(p, ECON.building_cost(p, "Organics")):
			break
		ECON._work_planet(state, 0, 1.0)
	assert(ECON.enqueue(state, 1, 0, "economy", "Organics"))
	for i in range(1200):
		ECON._work_planet(state, 0, 1.0)
		if int(p["buildings"].get("Organics", 0)) > 0:
			break
	assert(int(p["buildings"].get("Organics", 0)) == 1)
	p["population"] = ECON.habitation_capacity(p) + ECON.eco_population(p)
	assert(is_equal_approx(ECON.overpopulation_penalty(p), 1.0))
	p["population"] = 10000.0
	for resource in ECON.RESOURCES:
		p["stock"][resource] = 500.0
	assert(ECON.enqueue(state, 1, 0, "economy", "Crystals"))
	var job: Dictionary = p["queue"][0]
	assert(ECON._advance(p, job, float(job["work"])))
	ECON._finish(state, 0, p, job)
	assert(ECON.rate(p, "Crystals") > 0.0)
	print("PASS: no self-cost recipes, depleted stock recovery, crystal bootstrap, overpopulation curve")

func _test_opening_pacing() -> void:
	# Allied AI isolates economic pacing from variable battle casualties.
	# Use a one-year coarse tick for a fast repeatable balance smoke test.
	for seed_value in [827, 123, 2468]:
		var state: Dictionary = ECON.create(_planetary_fixture(seed_value, 2, "Grid"), {1: {"team": 1, "ai": true}, 2: {"team": 1, "ai": true}}, [1, 2])
		var first_colony: int = -1
		var owned: int = 0
		var fighters: int = 0
		var freighters: int = 0
		for year in range(1, 361):
			ECON.step(state, 1.0)
			owned = 0
			for p in state["planets"]:
				if int(p["owner"]) == 1:
					owned += 1
			if owned > 1 and first_colony < 0:
				first_colony = year
		for ship in state["ships"]:
			if int(ship["owner"]) == 1:
				fighters += int(ship["kind"] == "fighter")
				freighters += int(ship["kind"] == "ship")
		assert(first_colony > 0 and first_colony <= 180)
		assert(owned >= 4 and fighters >= 8 and freighters >= 1)
		print("PASS pacing seed %d: first colony %d years, %d worlds, %d fighters, %d freighters at year 360" % [seed_value, first_colony, owned, fighters, freighters])
