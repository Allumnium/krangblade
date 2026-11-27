extends SceneTree
## Explicit initial-balance contract, independent of legacy fixture magnitudes.
const E = preload("res://scripts/economy_rules.gd")
const M = preload("res://scripts/planet_map.gd")
const U = preload("res://scripts/ui_text.gd")

func _initialize() -> void:
	var state: Dictionary = E.create(M.generate(827, 1, "Grid"), {1: {"team": 1}}, [1], false)
	var home: Dictionary = state["planets"][0]
	assert(home["population"] == 150.0 and E.credit_balance(state, 1) == 500.0)
	assert(home["stock"] == {"Metals": 165.0, "Organics": 30.0, "Crystals": 0.0})
	assert(E.storage_capacity(home, "Metals") == 400.0 and E.storage_capacity(home, "Organics") == 200.0)
	var metals: Dictionary = {"scout": 10, "fighter": 25, "ship": 50, "construction_ship": 40, "miner": 50, "science_ship": 100, "colony_ship": 150, "cruiser": 200, "railgun_ship": 200, "destroyer": 300}
	for kind in metals:
		var price: Dictionary = E.construction_cost(home, kind, 1)
		assert(price["Metals"] == metals[kind])
		assert(float(price.get("Organics", 0.0)) == (10.0 if kind == "colony_ship" else 0.0))
		for reward_set in [[], ["rank_military_metal", "shield_1", "armor"], ["rank_civilian"]]:
			var rewarded: Dictionary = E.construction_cost({"conquest_rewards": reward_set, "station": {"dyson_sphere": true}}, kind, 1)
			for resource in rewarded:
				assert(float(rewarded[resource]) >= 5.0 and fmod(float(rewarded[resource]), 5.0) == 0.0)
			assert(fmod(E.construction_credit_cost(rewarded, kind), 5.0) == 0.0)
	assert(E.cargo_capacity("ship") == 100.0 and E.FREIGHTER_BAY_CAPACITY == 10.0 and E.FREIGHTER_BAY_COUNT == 10)
	assert(E.cargo_capacity("miner") == 5.0 and E.cargo_capacity("construction_ship") == 20.0 and E.cargo_capacity("colony_ship") == 25.0)
	assert(E.depot_capacity("Metals") == 200.0 and E.depot_capacity("Organics") == 400.0 and E.depot_capacity("Crystals") == 50.0 and E.depot_capacity(E.ANTIMATTER) == 0.0)
	assert(E.COLONY_POPULATION == 250.0 and E.COLONY_MIN_ORIGIN_POPULATION == 500.0)
	assert(E.ship_max_hp("fighter") == 20.0 and E.STATION_HP == 500.0)
	assert(U.resource_amount(25.0) == "25" and U.resource_amount(0.02, 2) == "0.02")
	assert(E.OBJECTIVE_SPECS["metals"][2] == 300 and E.OBJECTIVE_SPECS["population"][2] == 800)
	assert(E.enqueue(state, 1, 0, "fighter"))
	var job: Dictionary = home["queue"][0]
	assert(home["stock"]["Metals"] == 140.0 and home["stock"]["Organics"] == 30.0)
	assert(job["population_cost"] == 10.0 and E.reserved_construction_population(home) == 10.0)
	assert(E.credit_balance(state, 1) == 450.0 and E.cancel(state, 1, 0, job["id"]))
	assert(E.credit_balance(state, 1) == 500.0 and E.reserved_construction_population(home) == 0.0)
	assert(E.enqueue(state, 1, 0, "fighter"))
	for _year in range(30):
		E.step(state, 1.0)
	assert(state["ships"].any(func(ship: Dictionary) -> bool: return ship["kind"] == "fighter" and ship["owner"] == 1))
	print("PASS: numerical balance contract, rounded costs, capacities, crew reservations, cancellation and actual construction")
	quit(0)
