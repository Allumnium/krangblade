extends RefCounted
## Development-only balance configuration. No advanced recipes have been defined.
static var cached_civilian_routes: Dictionary = {}
static var cached_route_topology: Dictionary = {}
static var cached_military_graph: Dictionary = {}
static var cached_military_map: Dictionary = {}
const MAP = preload("res://scripts/planet_map.gd")
const RESOURCES = ["Metals", "Plastics", "Textiles", "Organics", "Tech", "Crystals"]
const EXTRACTED = ["Metals", "Plastics", "Crystals"]
const ACTIVE_PRODUCTION = RESOURCES
const STARTING_STOCK = {"Metals": 1650.0, "Plastics": 360.0, "Textiles": 240.0, "Organics": 300.0, "Tech": 240.0, "Crystals": 0.0}
const BASE_INDUSTRIAL_RATE: float = 1.0
const INDUSTRIAL_POPULATION_PER_LEVEL: float = 100000.0
const BUILDING_BONUS: float = 0.25
const UPGRADE_COST_FACTOR: float = 3.0
# Provisional repeatable local production infrastructure; no self-input recipes.
const ECONOMY_BUILDINGS = {
	"Metals": {"name": "Refinery", "population": 500, "cost": {"Plastics": 90.0, "Textiles": 60.0, "Tech": 45.0}},
	"Plastics": {"name": "Polymer factory", "population": 500, "cost": {"Metals": 240.0, "Textiles": 45.0, "Tech": 30.0}},
	"Textiles": {"name": "Textile mill", "population": 500, "cost": {"Metals": 240.0, "Plastics": 45.0, "Tech": 30.0}},
	"Organics": {"name": "Agricultural complex", "population": 500, "cost": {"Metals": 240.0, "Plastics": 45.0, "Tech": 30.0}},
	"Tech": {"name": "Electronics factory", "population": 500, "cost": {"Metals": 300.0, "Plastics": 90.0, "Textiles": 60.0}},
	"Crystals": {"name": "Crystal processor", "population": 500, "cost": {"Metals": 240.0, "Plastics": 45.0, "Tech": 30.0}}
}
const CONSTRUCTION_RESERVE: float = 500.0
const CONSTRUCTION_PRODUCTION_SHARE: float = 0.1
# Population is expressed in people (fractional values retained in simulation).
const HOME_POPULATION: float = 10000.0
const COLONY_POPULATION: float = 40000.0
const POPULATION_DOUBLING_YEARS: float = 30.0
const PRODUCTION_PER_LEVEL: float = 4.0
const ORGANICS_PER_LEVEL: float = 4.0
# Food production and demand both halve; population capacity stays unchanged.
const POPULATION_PER_ORGANICS_RATE: float = 25000.0
# Critically damped demographic response (seconds = years).
const POPULATION_RESPONSE: float = 0.065
const FARM_VARIATION: float = 0.05
const FARM_CYCLE_SECONDS: float = 100.0
const START_YEAR: int = 1
const CARGO_CAPACITY: float = 30.0
const FREIGHTER_BAY_COUNT: int = 7
const FREIGHTER_BAY_CAPACITY: float = CARGO_CAPACITY / FREIGHTER_BAY_COUNT
const MINED_RESOURCES = ["Metals", "Crystals"]
const ANTIMATTER = MAP.ANTIMATTER
const FIELD_RESOURCES = ["Metals", "Crystals", ANTIMATTER]
# Provisional per-resource ceilings, independent of unlimited upgrade levels.
const PLANET_MINING_LIMIT: float = 100.0
const FIELD_MINING_LIMIT: float = 200.0
const MINER_CAPACITY: float = 60.0
const MINER_RATE: float = 6.0
const SHIP_SPEED: float = MAP.TRAVEL_SPEED
const SHIP_SIZE: int = 1
const MAX_SHIPYARDS: int = 3
const EPS: float = 0.00001
const DEFAULT_FOG_OF_WAR: bool = false
# Starting storage capacity per resource; warehouse upgrades increase it.
const TRADE_REFERENCE: float = 2000.0
const WAREHOUSE_CAPACITIES = [2000.0, 5000.0, 12000.0, 30000.0]
# Each tier is 3x the previous one, with each price fitting in the
# immediately preceding warehouse capacity (instant purchase).
const WAREHOUSE_COSTS = [
	{"Metals": 500.0, "Plastics": 80.0, "Tech": 40.0},
	{"Metals": 1500.0, "Plastics": 240.0, "Tech": 120.0},
	{"Metals": 4500.0, "Plastics": 720.0, "Tech": 360.0}
]
const WAREHOUSE_POPULATIONS = [10000, 50000, 150000]
const CIVILIAN_CONSUMPTION = {"Metals": 0.1, "Plastics": 0.25, "Textiles": 0.25, "Tech": 0.25}
const SHIP_KINDS = ["ship", "colony_ship", "fighter", "miner"]
const CREW_COSTS = {"ship": 2000.0, "colony_ship": COLONY_POPULATION, "fighter": 500.0, "miner": 750.0}
const MINING_STAY: float = 5.0
const SHIP_HP: float = 100.0
const LASER_DAMAGE: float = 18.0
const PDS_DAMAGE: float = LASER_DAMAGE * 2.0
const PDS_HP: float = SHIP_HP
const LASER_RANGE: float = 180.0
const PURSUIT_YEARS: float = 3.0
const AI_INTERVAL: float = 4.0
const AI_WAVE_MIN: int = 3
const AI_RALLY_RADIUS: float = 150.0
const FORMATION_SPACING: float = 28.0
const FORMATION_RADIUS: float = 105.0
const FORMATION_TRAVEL_FRACTION: float = 0.8
const WITHDRAW_HP: float = 46.0
const REPAIR_PER_YEAR: float = 10.0
const REPAIR_SAFE_RADIUS: float = LASER_RANGE * 2.0
# Decorative bodies are derived from immutable system data, not simulated entities.
# Separate RNG keeps the economy's seeded resource generation unchanged.
static func system_bodies(system: Dictionary, seed_value: int, index: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 31013 + index * 7919
	var weights: Dictionary = {}
	var richness: float = 0.0
	for resource in EXTRACTED:
		var amount: float = float(system["abundance"].get(resource, 0.0))
		weights[resource] = amount
		richness += amount
	var organic: float = maxf(0.0, float(system["bonuses"].get("Organics", 1.0)) - 1.0)
	weights["Organics"] = organic * 2.0
	richness += organic
	var count: int = clampi(roundi(2.0 + richness * 0.64 + rng.randf_range(-0.65, 0.65)), 2, 6)
	var bodies: Array = []
	for i in range(count):
		var total: float = 0.8
		for resource in weights:
			total += float(weights[resource])
		var choice: float = rng.randf_range(0.0, total)
		var material: String = ""
		for resource in weights:
			choice -= float(weights[resource])
			if choice < 0.0:
				material = resource
				break
		bodies.append({"resource": material, "orbit": lerpf(0.28, 0.88, float(i) / float(count - 1)),
			"phase": rng.randf_range(0.0, TAU), "speed": rng.randf_range(0.65, 1.0) / (1.0 + float(i) * 0.42),
			"size": rng.randf_range(0.035, 0.095), "surface_seed": rng.randi_range(1, 2147483646),
			"surface_angle": rng.randf_range(0.0, TAU), "muted": rng.randf_range(0.0, 0.65), "bands": rng.randf() < 0.3})
	return bodies

static func empty_stock() -> Dictionary:
	var result: Dictionary = {}
	for resource in RESOURCES:
		result[resource] = 0.0
	return result

static func create(map_data: Dictionary, players: Dictionary, ordered: Array[int], starting_fleet: bool = true) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(map_data["seed"]) + 271
	var planets: Array = []
	var teams: Dictionary = {}
	for id in ordered:
		teams[id] = int(players[id]["team"])
	for i in range((map_data["points"] as Array).size()):
		var stock: Dictionary = empty_stock()
		var levels: Dictionary = empty_stock()
		var abundance: Dictionary = {}
		var bonuses: Dictionary = {"Organics": 1.0, "Crystals": 1.0}
		for resource in ["Organics", "Crystals"]:
			if rng.randf() < 0.5:
				bonuses[resource] = rng.randf_range(1.1, 1.8)
		var thresholds: Dictionary = {}
		for resource in RESOURCES:
			thresholds[resource] = {"min": 10.0, "max": 20.0}
		for resource in EXTRACTED:
			abundance[resource] = 0.1 if rng.randf() < 0.35 else rng.randf_range(0.5, 4.0)
		var home: bool = i < ordered.size()
		var owner: int = ordered[i] if home else 0
		var yards: Array = []
		if home:
			# Bootstrap values are test data, not final economy balance.
			abundance["Metals"] = maxf(1.0, float(abundance["Metals"]))
			for resource in RESOURCES:
				if resource != "Crystals":
					levels[resource] = 1
			stock = STARTING_STOCK.duplicate()
			yards.append({"level": 1, "job": -1, "hp": SHIP_HP * 10.0})
		var richness: float = 0.0
		for resource in EXTRACTED:
			richness += float(abundance[resource])
		richness += float(bonuses["Organics"]) - 1.0
		# Environment is generated separately, not inferred from size or deposits.
		var advanced: float = rng.randf_range(1.1, 1.6) if rng.randf() < 0.3 else 1.0
		planets.append({"size_factor": lerpf(0.86, 1.18, clampf(richness / 6.8, 0.0, 1.0)), "advanced_bonus": advanced, "owner": owner, "home": home, "population": HOME_POPULATION if home else 0.0, "population_velocity": 0.0, "farm_phase": float(i) * 2.399963, "farm_factor": 1.0, "stock": stock, "levels": levels,
			"abundance": abundance, "bonuses": bonuses, "thresholds": thresholds,
			"yards": yards, "queue": [], "continuous": {}, "buildings": {}, "warehouse_level": 0, "pds": {0: _new_pds()} if home else {}})
	var ai_players: Array[int] = []
	for id in ordered:
		if bool(players[id].get("ai", false)):
			ai_players.append(id)
	var state: Dictionary = {"ai_players": ai_players, "ai_waves": {}, "operations": {}, "next_operation_id": 1, "next_ai": 0.0, "map": map_data, "planets": planets, "ships": [], "teams": teams, "next_id": 1, "elapsed": 0.0, "fog_of_war": DEFAULT_FOG_OF_WAR, "explored": {}, "mining_policies": {}, "military": {}}
	for index in range(planets.size()):
		planets[index]["planet_count"] = system_bodies(planets[index], int(map_data["seed"]), index).size()
	if starting_fleet:
		for index in range(ordered.size()):
			for kind in ["miner", "miner", "miner", "fighter", "fighter"]:
				var id: int = int(state["next_id"])
				state["next_id"] = id + 1
				_finish(state, index, planets[index], {"id": id, "kind": kind, "population_allocated": CREW_COSTS[kind]})
	update_exploration(state)
	return state

static func discovered(state: Dictionary, player: int, kind: String, index: int) -> bool:
	var team: int = int(state.get("teams", {}).get(player, 0))
	if team <= 0 or index < 0:
		return false
	if not bool(state.get("fog_of_war", DEFAULT_FOG_OF_WAR)):
		if kind == "planets":
			return index < (state.get("planets", []) as Array).size()
		if kind == "fields":
			return index < (state.get("map", {}).get("fields", []) as Array).size()
		return false
	return bool(state.get("explored", {}).get(team, {}).get(kind, {}).get(index, false))

static func _survey(state: Dictionary, team: int, index: int) -> void:
	if team <= 0:
		return
	var explored: Dictionary = state["explored"]
	if not explored.has(team):
		explored[team] = {"planets": {}, "fields": {}}
	var knowledge: Dictionary = explored[team]
	knowledge["planets"][index] = true
	# Local surveys reveal neighboring worlds from the route endpoint.
	for edge in state["map"]["edges"]:
		if int(edge[0]) == index:
			knowledge["planets"][edge[1]] = true
		elif int(edge[1]) == index:
			knowledge["planets"][edge[0]] = true
	var fields: Array = state["map"].get("fields", [])
	for i in range(fields.size()):
		if int(fields[i]["anchor"]) == index:
			knowledge["fields"][i] = true

static func update_exploration(state: Dictionary) -> void:
	for i in range((state["planets"] as Array).size()):
		var team: int = int(state["teams"].get(int(state["planets"][i]["owner"]), 0))
		if team > 0:
			_survey(state, team, i)

static func mining_policy(state: Dictionary, player: int, index: int) -> Dictionary:
	var fields: Array = state.get("map", {}).get("fields", [])
	var special: bool = index >= 0 and index < fields.size() and bool(fields[index].get("antimatter", false))
	return state.get("mining_policies", {}).get(player, {}).get(index, {"enabled": not special, "Metals": true, "Crystals": true})

static func set_mining_policy(state: Dictionary, player: int, index: int, enabled: bool, metals: bool, crystals: bool) -> bool:
	if not state["teams"].has(player) or index < 0 or index >= (state["map"].get("fields", []) as Array).size() or not discovered(state, player, "fields", index):
		return false
	var policies: Dictionary = state["mining_policies"]
	if not policies.has(player):
		policies[player] = {}
	policies[player][index] = {"enabled": enabled, "Metals": metals, "Crystals": crystals}
	return true

static func _mining_resources(state: Dictionary, player: int, index: int) -> Array[String]:
	var policy: Dictionary = mining_policy(state, player, index)
	var resources: Array[String] = []
	if bool(policy["enabled"]):
		if bool(state["map"]["fields"][index].get("antimatter", false)):
			return [ANTIMATTER]
		for resource in MINED_RESOURCES:
			if bool(policy[resource]):
				resources.append(resource)
	return resources

## Read-only player-wide holdings: stock plus the player's own cargo in transit.
static func storage_capacity(p: Dictionary) -> float:
	return float(WAREHOUSE_CAPACITIES[clampi(int(p.get("warehouse_level", 0)), 0, 3)])

static func storage_free(p: Dictionary, resource: String) -> float:
	return maxf(0.0, storage_capacity(p) - float(p["stock"].get(resource, 0.0)))

static func raw_antimatter_totals(state: Dictionary, player: int) -> Dictionary:
	var stock: float = 0.0
	var cargo: float = 0.0
	for planet in state["planets"]:
		if int(planet["owner"]) == player:
			stock += float(planet["stock"].get(ANTIMATTER, 0.0))
	for ship in state["ships"]:
		if int(ship["owner"]) == player:
			cargo += float(ship.get("cargo", {}).get(ANTIMATTER, 0.0))
	return {"stock": stock, "cargo": cargo}

static func empire_totals(state: Dictionary, player: int) -> Dictionary:
	var stock: Dictionary = empty_stock()
	var cargo: Dictionary = empty_stock()
	var total: Dictionary = empty_stock()
	var population: float = 0.0
	var capacity: float = 0.0
	var planets: int = 0
	var craft: int = 0
	var logistics: int = 0
	var colonies: int = 0
	var fighters: int = 0
	var miners: int = 0
	for planet in state.get("planets", []):
		if int(planet["owner"]) != player:
			continue
		planets += 1
		capacity += storage_capacity(planet)
		population += float(planet["population"])
		for resource in RESOURCES:
			stock[resource] = float(stock[resource]) + float(planet["stock"].get(resource, 0.0))
	for ship in state.get("ships", []):
		if int(ship["owner"]) != player:
			continue
		craft += 1
		if ship.get("kind", "ship") == "colony_ship":
			colonies += 1
		elif ship.get("kind", "ship") == "fighter":
			fighters += 1
		elif ship.get("kind", "ship") == "miner":
			miners += 1
		else:
			logistics += 1
		var contents: Dictionary = ship.get("cargo", {})
		for resource in RESOURCES:
			cargo[resource] = float(cargo[resource]) + float(contents.get(resource, 0.0))
	for resource in RESOURCES:
		total[resource] = float(stock[resource]) + float(cargo[resource])
	var storage_reference: Dictionary = empty_stock()
	for resource in RESOURCES:
		storage_reference[resource] = capacity
	return {"stock": stock, "cargo": cargo, "resources": total, "storage_reference": storage_reference, "population": population,
		"planets": planets, "craft": craft, "logistics": logistics, "colonies": colonies, "fighters": fighters, "miners": miners}

## Host-only sample history; only the derived rates are replicated.
static func sample_resource_rates(state: Dictionary, history: Dictionary) -> void:
	var now: float = float(state["elapsed"])
	var rates: Dictionary = {}
	for player in state["teams"]:
		var totals: Dictionary = empire_totals(state, int(player))["resources"]
		var samples: Array = history.get(player, [])
		if not samples.is_empty() and is_equal_approx(float(samples.back()["time"]), now):
			samples.pop_back()
		samples.append({"time": now, "stock": totals})
		var cutoff: float = now - 5.0
		while samples.size() > 1 and float(samples[1]["time"]) <= cutoff:
			samples.pop_front()
		history[player] = samples
		var first: Dictionary = samples[0]
		var start_time: float = maxf(cutoff, float(first["time"]))
		var duration: float = now - start_time
		var result: Dictionary = empty_stock()
		if duration > EPS:
			for resource in RESOURCES:
				var previous: float = float(first["stock"][resource])
				if samples.size() > 1 and start_time > float(first["time"]):
					var second: Dictionary = samples[1]
					var fraction: float = (start_time - float(first["time"])) / (float(second["time"]) - float(first["time"]))
					previous = lerpf(previous, float(second["stock"][resource]), fraction)
				result[resource] = (float(totals[resource]) - previous) / duration
		rates[player] = result
	state["resource_rates"] = rates

static func planet_teams(state: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var teams: Dictionary = state["teams"]
	for planet in state["planets"]:
		result.append(int(teams.get(int(planet["owner"]), 0)))
	return result

## Colony ships can traverse allied worlds, with one final edge into a neutral world.
static func colony_path(state: Dictionary, player: int, ship: Dictionary, target: int) -> Array[int]:
	var planets: Array = state.get("planets", [])
	if target < 0 or target >= planets.size() or int(planets[target]["owner"]) != 0:
		return []
	if int(ship["owner"]) != player or ship.get("kind", "ship") != "colony_ship" or not (ship["route"] as Array).is_empty():
		return []
	var teams: Array[int] = planet_teams(state)
	var team: int = int(state["teams"].get(player, 0))
	var start: int = int(ship["at"])
	if team == 0 or (teams[start] != team and military_home(state, player) >= 0):
		return []
	if not discovered(state, player, "planets", target):
		return []
	var transit: Array[int] = []
	transit.resize(planets.size())
	transit.fill(team)
	return MAP.path(state["map"], transit, team, start, target)

static func send_colony(state: Dictionary, player: int, ship_id: int, target: int) -> bool:
	for ship in state["ships"]:
		if int(ship["id"]) != ship_id:
			continue
		var path: Array[int] = colony_path(state, player, ship, target)
		if path.is_empty():
			return false
		ship["dest"] = target
		ship["return_path"] = path.duplicate()
		_set_route(ship, path)
		return true
	return false

static func _work_colony(state: Dictionary, ship: Dictionary, dt: float) -> bool:
	if not _move(state, ship, dt) or int(ship["dest"]) < 0:
		return false
	var at: int = int(ship["at"])
	if int(state["planets"][at]["owner"]) == 0:
		var colony: Dictionary = state["planets"][at]
		colony["owner"] = int(ship["owner"])
		colony["population"] = float(ship.get("crew", COLONY_POPULATION))
		colony["population_velocity"] = 0.0
		colony["yards"].append({"level": 1, "job": -1, "hp": SHIP_HP * 10.0, "converted_at": float(state["elapsed"]), "colony_heading": ship.get("heading", Vector2.UP)})
		for resource in ["Metals", "Plastics", "Textiles", "Organics", "Tech"]:
			colony["levels"][resource] = 1
		return true # consumed to establish the colony
	# Another ship arrived first. Return to launch without claiming or combat.
	var back: Array[int] = []
	back.assign(ship["return_path"])
	back.reverse()
	ship["dest"] = -1
	_set_route(ship, back)
	return false

static func current_year(state: Dictionary) -> int:
	return START_YEAR + floori(float(state.get("elapsed", 0.0)) + EPS)

static func building_multiplier(planet: Dictionary, resource: String) -> float:
	return 1.0 + BUILDING_BONUS * int(planet.get("buildings", {}).get(resource, 0))

static func production_level(planet: Dictionary, resource: String) -> int:
	return maxi(int(planet["levels"][resource]), 1 if int(planet.get("buildings", {}).get(resource, 0)) > 0 else 0)

static func overpopulation_penalty(planet: Dictionary, capacity_factor: float = 1.0) -> float:
	var fraction: float = clampf(float(planet["population"]) / (habitation_capacity(planet) * capacity_factor), 0.0, 1.0)
	return 1.0 - pow(1.0 - fraction, 3.0)

static func farm_potential(planet: Dictionary) -> float:
	if int(planet["owner"]) == 0:
		return 0.0
	return ORGANICS_PER_LEVEL * production_level(planet, "Organics") * production_modifier(planet, "Organics") * float(planet.get("farm_factor", 1.0))

static func population_capacity(planet: Dictionary) -> float:
	return farm_potential(planet) * POPULATION_PER_ORGANICS_RATE

static func habitation_capacity(planet: Dictionary) -> float:
	return 5000000.0 * float(planet.get("size_factor", 1.0)) * pow(2.0, int(planet.get("habitation_level", 0)))

static func population_multiplier(planet: Dictionary) -> float:
	return float(planet["population"]) / HOME_POPULATION

static func population_growth(planet: Dictionary) -> float:
	return float(planet.get("population_velocity", 0.0))

static func organics_demand(planet: Dictionary) -> float:
	return float(planet["population"]) / POPULATION_PER_ORGANICS_RATE

static func consumption(planet: Dictionary, resource: String) -> float:
	if int(planet["owner"]) == 0:
		return 0.0
	if resource == "Organics":
		return organics_demand(planet)
	return float(CIVILIAN_CONSUMPTION.get(resource, 0.0)) * population_multiplier(planet)

static func civilian_stock_access(planet: Dictionary, resource: String) -> float:
	# Stock above the import target is reserved for trade and construction.
	var threshold: float = float(planet["thresholds"][resource]["min"])
	var reserve: float = storage_capacity(planet) * threshold / 100.0
	return minf(maxf(0.0, float(planet["stock"][resource])), reserve)

static func construction_reserve(planet: Dictionary, resource: String) -> float:
	# A shortage should not prevent saving for the next storage tier.
	var tier: int = int(planet.get("warehouse_level", 0))
	var next_cost: float = float(WAREHOUSE_COSTS[tier].get(resource, 0.0)) if tier < WAREHOUSE_COSTS.size() else 0.0
	return minf(storage_capacity(planet), maxf(CONSTRUCTION_RESERVE, next_cost))

static func net_rate(planet: Dictionary, resource: String) -> float:
	var net: float = rate(planet, resource) - consumption(planet, resource)
	if net > 0.0 and storage_free(planet, resource) <= EPS:
		return 0.0
	if net < 0.0 and resource != "Organics" and rate(planet, resource) > EPS and float(planet["stock"][resource]) < construction_reserve(planet, resource):
		return rate(planet, resource) * CONSTRUCTION_PRODUCTION_SHARE
	if net < 0.0 and civilian_stock_access(planet, resource) <= EPS:
		return 0.0
	return net

static func rate(planet: Dictionary, resource: String) -> float:
	if not ACTIVE_PRODUCTION.has(resource) or int(planet["owner"]) == 0:
		return 0.0
	var level: int = production_level(planet, resource)
	if resource == "Organics":
		# Small populations still produce a surplus; farm capacity limits output.
		var capacity: float = population_capacity(planet)
		if capacity <= EPS:
			return 0.0
		var labor: float = sqrt(clampf(float(planet["population"]) / capacity, 0.0, 1.0))
		return farm_potential(planet) * labor
	var base: float = PRODUCTION_PER_LEVEL
	if resource in ["Textiles", "Tech"]:
		base = BASE_INDUSTRIAL_RATE
	elif resource == "Plastics":
		# Baseline polymer production is possible even without a deposit.
		base = BASE_INDUSTRIAL_RATE
	var labor: float = population_multiplier(planet)
	if resource in ["Plastics", "Textiles", "Tech"]:
		# Installed production capacity limits the number of productive workers.
		# Population demand continues increasing after this output saturates.
		labor = minf(labor, INDUSTRIAL_POPULATION_PER_LEVEL * (level + int(planet.get("buildings", {}).get(resource, 0))) / HOME_POPULATION)
	var output: float = base * level * production_modifier(planet, resource) * labor
	return minf(output, PLANET_MINING_LIMIT) if MINED_RESOURCES.has(resource) else output

static func _update_population(planet: Dictionary, dt: float) -> void:
	# Exact solution of x'' + 2*w*x' + w*w*(x-target) = 0
	# for a constant target during this tick. Stable even for large dt.
	var current: float = float(planet["population"])
	var target: float = population_capacity(planet)
	var velocity: float = population_growth(planet)
	var error: float = current - target
	var omega: float = POPULATION_RESPONSE
	var slope: float = velocity + omega * error
	var decay: float = exp(-omega * dt)
	var next: float = target + (error + slope * dt) * decay
	var next_velocity: float = (velocity - omega * slope * dt) * decay
	# Far below equilibrium, limit positive growth to a 30-year doubling.
	# Near capacity the damped response takes over without a hard population cap.
	var growth_constant: float = log(2.0) / POPULATION_DOUBLING_YEARS
	if current < habitation_capacity(planet):
		growth_constant *= 1.0 - overpopulation_penalty(planet)
	else:
		growth_constant = 0.0
	var growth_ceiling: float = current * exp(growth_constant * dt)
	if next > growth_ceiling:
		next = growth_ceiling
		next_velocity = growth_constant * next
	# A food shortfall prevents positive growth even with demographic momentum.
	var food_available: float = civilian_stock_access(planet, "Organics") + rate(planet, "Organics") * dt
	if food_available + EPS < organics_demand(planet) * dt:
		next = minf(next, current)
		next_velocity = minf(next_velocity, 0.0)
	planet["population"] = maxf(0.0, next)
	planet["population_velocity"] = minf(next_velocity, growth_constant * next) if next > 0.0 else 0.0

static func max_size(level: int) -> int:
	return level

static func yard_speed(level: int) -> float:
	return 6.0 * level

static func _has_job(planet: Dictionary, kind: String, target: String) -> bool:
	for item in planet["queue"]:
		if item["kind"] == kind and item["target"] == target:
			return true
	return false

static func _cost(kind: String, level: int) -> Dictionary:
	# Explicit prototype values; the final costs/recipes are intentionally undefined.
	match kind:
		"ship": return {"Metals": 360.0, "Plastics": 75.0, "Textiles": 45.0, "Organics": 15.0, "Tech": 30.0}
		"colony_ship": return {"Metals": 1200.0, "Plastics": 120.0, "Textiles": 90.0, "Organics": 30.0, "Tech": 90.0}
		"fighter": return {"Metals": 270.0, "Plastics": 60.0, "Textiles": 30.0, "Organics": 10.0, "Tech": 30.0}
		"miner": return {"Metals": 540.0, "Plastics": 90.0, "Textiles": 45.0, "Organics": 20.0, "Tech": 60.0}
		"yard":
			match level:
				1: return {"Metals": 480.0}
				2: return {"Metals": 2000.0, "Plastics": 500.0, "Textiles": 500.0, "Organics": 200.0, "Tech": 100.0, "Crystals": 100.0}
				3: return {"Metals": 6000.0, "Plastics": 1500.0, "Textiles": 1500.0, "Organics": 600.0, "Tech": 300.0, "Crystals": 300.0}
		"pds":
			var factor: float = pow(UPGRADE_COST_FACTOR, float(maxi(0, level - 1)))
			return {"Metals": 540.0 * factor, "Plastics": 120.0 * factor, "Textiles": 60.0 * factor, "Organics": 60.0 * factor, "Tech": 60.0 * factor}
		"yard_upgrade": return {"Metals": 240.0 * pow(UPGRADE_COST_FACTOR, float(maxi(0, level - 1)))}
		"production": return {"Metals": 200.0 * pow(UPGRADE_COST_FACTOR, float(maxi(0, level - 1)))}
	return {}

static func _work(kind: String, level: int) -> float:
	match kind:
		"ship": return 48.0
		"colony_ship": return 102.0
		"fighter": return 36.0
		"miner": return 60.0
		"yard": return 30.0
		"pds": return 36.0
		"yard_upgrade": return 15.0 * level
		"production": return 10.0 * level
	return 1.0

static func _get_owned(state: Dictionary, player: int, index: int) -> Dictionary:
	var planets: Array = state.get("planets", [])
	if index < 0 or index >= planets.size() or int(planets[index]["owner"]) != player:
		return {}
	return planets[index]

# Reserve a slot as soon as construction is ordered.
const SHIPYARD_POPULATION = [500.0, 5000.0, 20000.0]

static func shipyard_operational(p: Dictionary, index: int) -> bool:
	return index >= 0 and index < (p.get("yards", []) as Array).size() and float(p["population"]) + EPS >= float(SHIPYARD_POPULATION[index])

static func operational_shipyards(p: Dictionary) -> int:
	var count: int = 0
	for index in range((p.get("yards", []) as Array).size()):
		if shipyard_operational(p, index):
			count += 1
	return count

static func shipyard_count(p: Dictionary) -> int:
	var count: int = (p.get("yards", []) as Array).size()
	for item in p.get("queue", []):
		if item["kind"] == "yard":
			count += 1
	return count

# Completed and queued construction slots form one contiguous stack.
static func next_shipyard_slot(p: Dictionary) -> int:
	var count: int = shipyard_count(p)
	return count + 1 if count < MAX_SHIPYARDS else 0

# Move later construction down one slot when an earlier job is cancelled.
# Preserve its fractional work, but retain only the cheaper recipe's
# proportional allocation; return the difference to local stock.
static func _compact_shipyard_orders(p: Dictionary, removed_level: int) -> void:
	for item in p["queue"]:
		if item["kind"] != "yard" or int(item["level"]) <= removed_level:
			continue
		var fraction: float = clampf(float(item["progress"]) / float(item["work"]), 0.0, 1.0)
		var level: int = int(item["level"]) - 1
		var cost: Dictionary = _cost("yard", level)
		var allocated: Dictionary = empty_stock()
		for resource in RESOURCES:
			allocated[resource] = float(cost.get(resource, 0.0)) * fraction
			p["stock"][resource] += float(item["allocated"][resource]) - float(allocated[resource])
		item["level"] = level
		item["cost"] = cost
		item["work"] = _work("yard", level)
		item["progress"] = fraction * float(item["work"])
		item["allocated"] = allocated

# Gates apply to new local production orders, not completed infrastructure.
# Early farming remains available, so capacity can grow toward the Tech gate.
static func production_population(resource: String, level: int) -> int:
	if resource == "Tech":
		return maxi(1000, 200000 * (level - 1))
	return maxi(1000, 10000 * (level - 1))

static func production_available(p: Dictionary, resource: String) -> bool:
	return RESOURCES.has(resource) and (not MINED_RESOURCES.has(resource) or float(p["abundance"].get(resource, 0.0)) > 0.0)

static func production_unlocked(p: Dictionary, resource: String) -> bool:
	return production_available(p, resource) and float(p["population"]) + EPS >= float(production_population(resource, int(p["levels"][resource]) + 1))

static func affordable(p: Dictionary, cost: Dictionary) -> bool:
	if cost.is_empty():
		return false
	for resource in cost:
		if float(p["stock"].get(resource, 0.0)) + EPS < float(cost[resource]):
			return false
	return true

static func building_available(p: Dictionary, resource: String) -> bool:
	if not ECONOMY_BUILDINGS.has(resource) or _has_job(p, "economy_building", resource) or not production_available(p, resource):
		return false
	var definition: Dictionary = ECONOMY_BUILDINGS[resource]
	return float(p["population"]) + EPS >= float(definition["population"])

static func warehouse_available(p: Dictionary) -> bool:
	var level: int = int(p.get("warehouse_level", 0))
	return level < 3 and float(p["population"]) + EPS >= float(WAREHOUSE_POPULATIONS[level]) and affordable(p, WAREHOUSE_COSTS[level])

static func habitation_cost(p: Dictionary) -> Dictionary:
	var factor: float = pow(3.0, int(p.get("habitation_level", 0)))
	return {"Metals": 600.0 * factor, "Tech": 100.0 * factor, "Plastics": 150.0 * factor}

static func habitation_available(p: Dictionary) -> bool:
	return int(p.get("habitation_level", 0)) < 3 and affordable(p, habitation_cost(p))

static func _buy_habitation(p: Dictionary) -> bool:
	if not habitation_available(p):
		return false
	for resource in habitation_cost(p):
		p["stock"][resource] -= habitation_cost(p)[resource]
	p["habitation_level"] = int(p.get("habitation_level", 0)) + 1
	return true

static func _buy_warehouse(p: Dictionary) -> bool:
	if not warehouse_available(p):
		return false
	var level: int = int(p.get("warehouse_level", 0))
	for material in WAREHOUSE_COSTS[level]:
		p["stock"][material] -= float(WAREHOUSE_COSTS[level][material])
	p["warehouse_level"] = level + 1
	return true

static func building_cost(_p: Dictionary, resource: String) -> Dictionary:
	return ECONOMY_BUILDINGS[resource]["cost"].duplicate()

static func pds_job(p: Dictionary) -> Dictionary:
	for item in p.get("queue", []):
		if item["kind"] == "pds":
			return item
	return {}

static func _new_pds() -> Dictionary:
	return {"hp": PDS_HP, "cooldown": 0.0, "target": -1, "laser_until": -1.0}

static func next_pds(p: Dictionary) -> int:
	for slot in range(int(p.get("planet_count", 0))):
		if not p.get("pds", {}).has(slot):
			return slot
	return -1

static func enqueue(state: Dictionary, player: int, index: int, kind: String, target: String = "") -> bool:
	var p: Dictionary = _get_owned(state, player, index)
	if p.is_empty():
		return false
	var level: int = 1
	match kind:
		"ship":
			if not bool(p["home"]):
				return false
			target = ""
		"colony_ship", "fighter", "miner":
			target = ""
		"yard":
			level = next_shipyard_slot(p)
			if level == 0 or (not target.is_empty() and target != str(level)):
				return false
			target = ""
		"yard_upgrade":
			if not target.is_valid_int():
				return false
			var y: int = int(target)
			if y < 0 or y >= (p["yards"] as Array).size():
				return false
			target = str(y)
			if _has_job(p, kind, target):
				return false
			level = int(p["yards"][y]["level"]) + 1
		"pds":
			var slot: int = next_pds(p)
			if slot < 0 or not pds_job(p).is_empty() or (not target.is_empty() and target != str(slot)):
				return false
			target = str(slot)
			level = slot + 1
		"economy":
			if target == "habitation":
				return _buy_habitation(p)
			if target == "warehouse":
				return _buy_warehouse(p)
			if not building_available(p, target):
				return false
			kind = "economy_building"
			level = int(p.get("buildings", {}).get(target, 0)) + 1
		"production":
			if not production_unlocked(p, target) or _has_job(p, kind, target):
				return false
			level = int(p["levels"][target]) + 1
		_: return false
	var id: int = int(state["next_id"])
	state["next_id"] = id + 1
	p["queue"].append({"id": id, "kind": kind, "target": target, "level": level,
		"cost": building_cost(p, target) if kind == "economy_building" else _cost(kind, level), "work": 30.0 if kind == "economy_building" else _work(kind, level),
		"progress": 0.0, "allocated": empty_stock(), "population_cost": float(CREW_COSTS.get(kind, 0.0)), "population_allocated": 0.0, "size": SHIP_SIZE if kind in ["ship", "colony_ship", "fighter", "miner"] else 0})
	return true

static func production_modifier(system: Dictionary, resource: String) -> float:
	var modifier: float = float(system["bonuses"].get(resource, 1.0))
	if MINED_RESOURCES.has(resource):
		modifier *= float(system["abundance"].get(resource, 0.0))
	elif resource == "Plastics":
		modifier *= maxf(1.0, float(system["abundance"].get(resource, 0.0)))
	return clampf(modifier, 0.1, 4.0) * building_multiplier(system, resource)

static func _continuous_target(p: Dictionary, key: String) -> Array:
	if SHIP_KINDS.has(key):
		return [key, ""] if key != "ship" or bool(p["home"]) else []
	if key in ["warehouse", "habitation"]:
		return [key, ""]
	if key.begins_with("economy_building:"):
		var resource: String = key.trim_prefix("economy_building:")
		if ECONOMY_BUILDINGS.has(resource) and production_available(p, resource):
			return ["economy", resource]
	if key.begins_with("production:"):
		var resource: String = key.trim_prefix("production:")
		if production_available(p, resource):
			return ["production", resource]
	if key.begins_with("yard_upgrade:"):
		var target: String = key.trim_prefix("yard_upgrade:")
		if target.is_valid_int() and int(target) >= 0 and int(target) < (p["yards"] as Array).size() and target == str(int(target)):
			return ["yard_upgrade", target]
	return []

static func set_continuous(state: Dictionary, player: int, index: int, kind: String, enabled: bool) -> bool:
	var p: Dictionary = _get_owned(state, player, index)
	if p.is_empty() or _continuous_target(p, kind).is_empty():
		return false
	p["continuous"][kind] = enabled
	return true

static func origin_count(state: Dictionary, index: int, kind: String) -> int:
	var count: int = 0
	for ship in state.get("ships", []):
		if ship["kind"] == kind and int(ship.get("origin", -1)) == index and int(ship["owner"]) == int(state["planets"][index]["owner"]):
			count += 1
	return count

static func set_maintain(state: Dictionary, player: int, index: int, kind: String, amount: int) -> bool:
	var p: Dictionary = _get_owned(state, player, index)
	if p.is_empty() or not SHIP_KINDS.has(kind) or amount < 0 or amount > 9999:
		return false
	if not p.has("maintain"):
		p["maintain"] = {}
	p["maintain"][kind] = amount
	p["continuous"][kind] = false
	return true

static func _maintain_needed(state: Dictionary, index: int, p: Dictionary, key: String) -> bool:
	if bool(p["continuous"].get(key, false)):
		return true
	if not SHIP_KINDS.has(key):
		return false
	var target: int = int(p.get("maintain", {}).get(key, 0))
	if target <= 0:
		return false
	var count: int = origin_count(state, index, key)
	for item in p["queue"]:
		if item["kind"] == key:
			count += 1
	return count < target

static func _refill_continuous(state: Dictionary, index: int, p: Dictionary) -> void:
	var keys: Array = p["continuous"].keys()
	for key in p.get("maintain", {}):
		if not keys.has(key):
			keys.append(key)
	# Shipyards share one repeat cycle. Once every turn has started, the next
	# cycle may start on any idle shipyard, even while a slower hull is active.
	# Independent infrastructure upgrades must not consume turns in this cycle.
	var active: Dictionary = {}
	var idle: bool = false
	for yard in p["yards"]:
		var id: int = int(yard["job"])
		if id < 0:
			idle = true
		else:
			active[id] = true
	var waiting: bool = false
	var manual_hulls: Dictionary = {}
	for item in p["queue"]:
		if int(item["size"]) <= 0:
			continue
		if bool(item.get("automatic", false)):
			if not active.has(int(item["id"])):
				waiting = true
		else:
			manual_hulls[item["kind"]] = true
	var cycle: Dictionary = p.get("repeat_cycle", {})
	if not waiting and idle:
		cycle.clear()
	for key in cycle.keys():
		if not _maintain_needed(state, index, p, str(key)):
			cycle.erase(key)
	for key in keys:
		if not _maintain_needed(state, index, p, str(key)):
			continue
		var order: Array = _continuous_target(p, str(key))
		if order.is_empty():
			continue
		if order[0] in ["warehouse", "habitation"]:
			if order[0] == "warehouse":
				_buy_warehouse(p)
			else:
				_buy_habitation(p)
			if int(p.get(str(order[0]) + "_level", 0)) >= 3:
				p["continuous"][key] = false
			continue
		if SHIP_KINDS.has(order[0]):
			if (p["yards"] as Array).is_empty() or cycle.has(key) or manual_hulls.has(key):
				continue
			# Do not duplicate a waiting order if its repeat toggle was
			# switched off and on during the same cycle.
			var existing: bool = false
			for item in p["queue"]:
				if item["kind"] == key and not active.has(int(item["id"])):
					existing = true
					break
			if existing:
				cycle[key] = true
				continue
		elif _has_job(p, "economy_building" if order[0] == "economy" else order[0], order[1]):
			continue
		if enqueue(state, int(p["owner"]), index, order[0], order[1]):
			p["queue"][-1]["automatic"] = true
			if SHIP_KINDS.has(order[0]):
				cycle[key] = true
	p["repeat_cycle"] = cycle

static func cancel(state: Dictionary, player: int, index: int, job_id: int) -> bool:
	var p: Dictionary = _get_owned(state, player, index)
	if p.is_empty():
		return false
	for item in p["queue"]:
		if int(item["id"]) != job_id:
			continue
		for resource in RESOURCES:
			p["stock"][resource] = float(p["stock"][resource]) + float(item["allocated"][resource])
		p["population"] = float(p["population"]) + float(item.get("population_allocated", 0.0))
		for yard in p["yards"]:
			if int(yard["job"]) == job_id:
				yard["job"] = -1
		var key: String = str(item["kind"])
		if key == "production" or key == "yard_upgrade" or key == "economy_building":
			key += ":" + str(item["target"])
		if p["continuous"].has(key):
			p["continuous"][key] = false
		if SHIP_KINDS.has(key) and p.has("maintain"):
			p["maintain"][key] = 0
		p["queue"].erase(item)
		if item["kind"] == "yard":
			_compact_shipyard_orders(p, int(item["level"]))
		return true
	return false

static func set_thresholds(state: Dictionary, player: int, index: int, resource: String, minimum: float, maximum: float, importing: bool = true, exporting: bool = true) -> bool:
	var p: Dictionary = _get_owned(state, player, index)
	if p.is_empty() or not RESOURCES.has(resource):
		return false
	if not is_finite(minimum) or not is_finite(maximum) or minimum < 0.0 or maximum < 0.0 or minimum > 100.0 or (importing and exporting and maximum < minimum) or maximum > 100.0:
		return false
	p["thresholds"][resource] = {"min": minimum, "max": maximum, "import": importing, "export": exporting}
	return true

static func _possible(p: Dictionary, item: Dictionary) -> float:
	var work: float = float(item["work"])
	var possible: float = work - float(item["progress"])
	if item["kind"] == "colony_ship" and float(p["population"]) + EPS < _remaining_colony_crew(item) + SHIPYARD_POPULATION[0]:
		return 0.0
	for resource in item["cost"]:
		var per_work: float = float(item["cost"][resource]) / work
		if per_work > 0.0:
			possible = minf(possible, float(p["stock"][resource]) / per_work)
	var people_per_work: float = float(item.get("population_cost", 0.0)) / work
	if people_per_work > 0.0:
		possible = minf(possible, maxf(0.0, float(p["population"]) - 1.0) / people_per_work)
	return maxf(0.0, possible)

static func _remaining_colony_crew(item: Dictionary) -> float:
	return maxf(0.0, float(item.get("population_cost", 0.0)) - float(item.get("population_allocated", 0.0)))

static func construction_blockers(p: Dictionary, item: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	if float(item["work"]) - float(item["progress"]) <= EPS:
		return missing
	for resource in item["cost"]:
		if float(item["cost"][resource]) > EPS and float(p["stock"].get(resource, 0.0)) <= EPS:
			missing.append(resource)
	if (item["kind"] == "colony_ship" and float(p["population"]) + EPS < _remaining_colony_crew(item) + SHIPYARD_POPULATION[0]) or (float(item.get("population_cost", 0.0)) > 0.0 and float(p["population"]) <= 1.0 + EPS) or (int(item.get("size", 0)) > 0 and not p["yards"].is_empty() and operational_shipyards(p) == 0) or (item["kind"] == "yard_upgrade" and not shipyard_operational(p, int(item["target"]))):
		missing.append("Population")
	return missing

static func _advance(p: Dictionary, item: Dictionary, work_budget: float) -> bool:
	var amount: float = minf(work_budget, _possible(p, item))
	for resource in item["cost"]:
		var used: float = amount * float(item["cost"][resource]) / float(item["work"])
		p["stock"][resource] = maxf(0.0, float(p["stock"][resource]) - used)
		item["allocated"][resource] = float(item["allocated"][resource]) + used
		_record_flow(p, "Construction: " + str(item["kind"]), resource, used)
	var crew: float = amount * float(item.get("population_cost", 0.0)) / float(item["work"])
	p["population"] = maxf(0.0, float(p["population"]) - crew)
	p["crew_rate"] = float(p.get("crew_rate", 0.0)) + crew / maxf(EPS, float(p.get("flow_dt", 1.0)))
	item["population_allocated"] = float(item.get("population_allocated", 0.0)) + crew
	item["progress"] = float(item["progress"]) + amount
	return float(item["progress"]) >= float(item["work"]) - EPS

static func shipyard_position(state: Dictionary, index: int, slot: int, elapsed: float) -> Vector2:
	var yard: Dictionary = state["planets"][index]["yards"][slot]
	var center: Vector2 = state["map"]["points"][index]
	var angle: float = float(slot) * TAU / 3.0 + elapsed * 0.008
	var conversion: float = clampf((elapsed - float(yard.get("converted_at", -100.0))) / 3.0, 0.0, 1.0)
	return center + Vector2.from_angle(angle) * 95.0 * smoothstep(0.0, 1.0, conversion)

static func _finish(state: Dictionary, index: int, p: Dictionary, item: Dictionary) -> void:
	match str(item["kind"]):
		"economy_building":
			p["buildings"][item["target"]] = int(p["buildings"].get(item["target"], 0)) + 1
		"production":
			p["levels"][item["target"]] = int(item["level"])
		"pds":
			p["pds"][int(item["target"])] = _new_pds()
		"yard":
			p["yards"].append({"level": 1, "job": -1, "hp": SHIP_HP * 10.0})
		"yard_upgrade":
			p["yards"][int(item["target"])]["level"] = int(item["level"])
			p["yards"][int(item["target"])]["hp"] = SHIP_HP * 10.0 * int(item["level"])
		"ship", "colony_ship", "fighter", "miner":
			var launch: Vector2 = state["map"]["points"][index]
			for slot in range(p["yards"].size()):
				if int(p["yards"][slot]["job"]) == int(item["id"]):
					launch = shipyard_position(state, index, slot, float(state["elapsed"]))
					break
			state["ships"].append({"id": int(item["id"]), "kind": str(item["kind"]), "owner": int(p["owner"]), "origin": index, "at": index,
				"position": launch, "heading": Vector2.UP, "navigation_target": state["map"]["points"][index],
				"route": [], "leg": 0.0, "source": -1, "dest": -1, "hp": SHIP_HP, "crew": float(item.get("population_allocated", 0.0)), "cargo": empty_stock(), "field": -1, "mining_mode": "idle", "field_leg": 0.0})
	p["queue"].erase(item)

static func _record_flow(p: Dictionary, category: String, resource: String, amount: float) -> void:
	if amount <= EPS or not p.has("flows"):
		return
	var flows: Dictionary = p["flows"]
	if not flows.has(category):
		flows[category] = {}
	flows[category][resource] = float(flows[category].get(resource, 0.0)) + amount

static func local_flow(p: Dictionary, category: String, resource: String) -> float:
	if not p.has("flows"):
		if category == "Production":
			return rate(p, resource)
		if category == "Population":
			return consumption(p, resource)
		return 0.0
	return float(p["flows"].get(category, {}).get(resource, 0.0)) / maxf(EPS, float(p.get("flow_dt", 1.0)))

static func _work_planet(state: Dictionary, index: int, dt: float) -> void:
	var p: Dictionary = state["planets"][index]
	if int(p["owner"]) == 0:
		return
	p["flows"] = {}
	p["flow_dt"] = dt
	p["crew_rate"] = 0.0
	var before_population: float = float(p["population"])
	var elapsed: float = float(state["elapsed"])
	p["farm_factor"] = 1.0 + FARM_VARIATION * sin(TAU * elapsed / FARM_CYCLE_SECONDS + float(p["farm_phase"]))
	_update_population(p, dt)
	p["demographic_rate"] = (float(p["population"]) - before_population) / maxf(EPS, dt)
	# Residents consume all non-crystal resources. Only net surplus can occupy
	# free storage. At capacity production covers demand but stores no excess.
	# Refunds may temporarily exceed capacity; never destroy returned materials.
	for resource in ACTIVE_PRODUCTION:
		var stored: float = float(p["stock"][resource])
		var potential: float = rate(p, resource) * dt
		var demand: float = consumption(p, resource) * dt
		var used: float = minf(demand, civilian_stock_access(p, resource) + potential)
		if resource != "Organics" and potential > EPS and demand > potential and stored < construction_reserve(p, resource):
			used = minf(used, potential * (1.0 - CONSTRUCTION_PRODUCTION_SHARE))
		var produced: float = minf(potential, used + storage_free(p, resource))
		_record_flow(p, "Production", resource, produced)
		_record_flow(p, "Population", resource, used)
		p["stock"][resource] = maxf(0.0, stored + produced - used)
	# New yards and planetary production use infrastructure work, not an existing yard.
	for item in (p["queue"] as Array).duplicate():
		if int(item["size"]) == 0 and item["kind"] != "yard_upgrade" and _advance(p, item, dt):
			# Construction may advance concurrently, but completed shipyards
			# join the active array only in contiguous slot order.
			if item["kind"] != "yard" or int(item["level"]) == (p["yards"] as Array).size() + 1:
				_finish(state, index, p, item)
	_refill_continuous(state, index, p)
	var assigned: Dictionary = {}
	# Preserve active jobs. A started upgrade remains attached to its own yard even if blocked.
	for y in range((p["yards"] as Array).size()):
		var yard: Dictionary = p["yards"][y]
		if not shipyard_operational(p, y):
			yard["job"] = -1
			continue
		var retained: bool = false
		for item in p["queue"]:
			if int(item["id"]) != int(yard["job"]):
				continue
			if item["kind"] == "yard_upgrade" or (int(item["size"]) > 0 and _possible(p, item) > EPS):
				assigned[int(item["id"])] = true
				retained = true
				break
		if not retained:
			yard["job"] = -1
	for y in range((p["yards"] as Array).size()):
		if not shipyard_operational(p, y):
			continue
		var yard: Dictionary = p["yards"][y]
		var chosen: Dictionary = {}
		for item in p["queue"]:
			if int(item["id"]) == int(yard["job"]):
				chosen = item
				break
		if chosen.is_empty():
			# Repeat hulls take turns in queue order, even if the next one
			# is waiting for materials. Otherwise cheap hulls can repeatedly
			# leapfrog a more expensive one and starve it. Manual orders and
			# targeted upgrades retain their existing eligibility rules.
			var repeat_seen: bool = false
			for item in p["queue"]:
				if assigned.has(int(item["id"])):
					continue
				var upgrade: bool = item["kind"] == "yard_upgrade" and int(item["target"]) == y
				var hull: bool = int(item["size"]) > 0 and int(item["size"]) <= max_size(int(yard["level"]))
				if hull and bool(item.get("automatic", false)):
					if repeat_seen:
						continue
					repeat_seen = true
				if (upgrade or hull) and _possible(p, item) > EPS:
					chosen = item
					break
		if chosen.is_empty():
			yard["job"] = -1
			continue
		var id: int = int(chosen["id"])
		yard["job"] = id
		assigned[id] = true
		var speed: float = 1.0 if chosen["kind"] == "yard_upgrade" else yard_speed(int(yard["level"]))
		if _advance(p, chosen, speed * dt):
			_finish(state, index, p, chosen)
			yard["job"] = -1

static func _cargo_total(ship: Dictionary) -> float:
	var total: float = 0.0
	for r in RESOURCES:
		total += float(ship["cargo"][r])
	return total + float(ship["cargo"].get(ANTIMATTER, 0.0))

# Pack the shared tonnage into equal display bays, not resource-specific limits.
static func freighter_cargo_bays(cargo: Dictionary) -> Array:
	var bays: Array = []
	var occupied: float = 0.0
	for index in range(FREIGHTER_BAY_COUNT):
		bays.append([])
	var bay: int = 0
	for resource in RESOURCES + [ANTIMATTER]:
		var remaining: float = maxf(0.0, float(cargo.get(resource, 0.0)))
		while remaining > EPS and bay < FREIGHTER_BAY_COUNT:
			var amount: float = minf(remaining, FREIGHTER_BAY_CAPACITY - occupied)
			bays[bay].append({"resource": resource, "amount": amount})
			remaining -= amount
			occupied += amount
			if occupied >= FREIGHTER_BAY_CAPACITY - EPS:
				bay += 1
				occupied = 0.0
	return bays

static func _need(p: Dictionary, resource: String) -> float:
	if not bool(p["thresholds"][resource].get("import", true)):
		return 0.0
	return maxf(0.0, storage_capacity(p) * float(p["thresholds"][resource]["min"]) / 100.0 - float(p["stock"][resource]))

static func _surplus(p: Dictionary, resource: String) -> float:
	if not bool(p["thresholds"][resource].get("export", true)):
		return 0.0
	return maxf(0.0, float(p["stock"][resource]) - storage_capacity(p) * float(p["thresholds"][resource]["max"]) / 100.0)

static func _opportunity(a: Dictionary, b: Dictionary) -> bool:
	for r in RESOURCES:
		if _surplus(a, r) > EPS and _need(b, r) > EPS:
			return true
	return false

static func _path(state: Dictionary, teams: Array[int], team: int, a: int, b: int, _cache: Dictionary) -> Array[int]:
	var routes: Dictionary = _civilian_route_cache(state, teams)
	var key: String = "%d:%d:%d" % [team, a, b]
	if not routes.has(key):
		routes[key] = MAP.path(state["map"], teams, team, a, b)
	var result: Array[int] = []
	result.assign(routes[key])
	return result

static func _civilian_route_cache(state: Dictionary, teams: Array[int]) -> Dictionary:
	var map_data: Dictionary = state["map"]
	if cached_route_topology.get("points") != map_data["points"] or cached_route_topology.get("edges") != map_data["edges"] or cached_route_topology.get("teams") != teams:
		cached_civilian_routes.clear()
		cached_route_topology = {"points": map_data["points"].duplicate(), "edges": map_data["edges"].duplicate(true), "teams": teams.duplicate()}
	return cached_civilian_routes

static func _set_route(ship: Dictionary, path: Array[int]) -> void:
	ship["route"] = path.slice(1)
	ship["leg"] = 0.0

# Legacy test fixtures may omit position. Real hulls are initialized at birth.
static func _initial_position(points: Array, ship: Dictionary) -> Vector2:
	var origin: Vector2 = points[int(ship["at"])]
	if ship.get("kind", "") == "miner" and ship.get("mining_mode", "") in ["outbound", "mining", "return"]:
		return origin.lerp(ship["mining_target"], clampf(float(ship["field_leg"]), 0.0, 1.0))
	var route: Array = ship["route"]
	if not route.is_empty():
		var next: Vector2 = points[int(route[0])]
		return origin.lerp(next, clampf(float(ship["leg"]) / maxf(EPS, origin.distance_to(next)), 0.0, 1.0))
	return origin

static func _ensure_position(points: Array, ship: Dictionary) -> void:
	if not ship.has("position"):
		ship["position"] = _initial_position(points, ship)
		ship["heading"] = Vector2.UP
		ship["navigation_target"] = ship["position"]

# The only movement integrator. Orders change targets, never current position.
# Return the distance actually flown so a tick cannot exceed its travel budget.
static func _navigate(ship: Dictionary, target: Vector2, budget: float) -> float:
	ship["navigation_target"] = target
	var before: Vector2 = ship["position"]
	var after: Vector2 = before.move_toward(target, maxf(0.0, budget))
	var displacement: Vector2 = after - before
	if not displacement.is_zero_approx():
		ship["heading"] = displacement.normalized()
	ship["position"] = after
	return displacement.length()

static func _lane_progress(points: Array, ship: Dictionary) -> float:
	var route: Array = ship["route"]
	if route.is_empty():
		return 0.0
	var origin: Vector2 = points[int(ship["at"])]
	var edge: Vector2 = (points[int(route[0])] as Vector2) - origin
	return clampf(((ship["position"] as Vector2) - origin).dot(edge.normalized()), 0.0, edge.length())

static func _move(state: Dictionary, ship: Dictionary, dt: float) -> bool:
	var route: Array = ship["route"]
	var points: Array = state["map"]["points"]
	_ensure_position(points, ship)
	var distance: float = SHIP_SPEED * dt
	if route.is_empty():
		var here: int = int(ship["at"])
		var dock_required: bool = int(ship.get("source", -1)) == here or int(ship.get("dest", -1)) == here or ship.get("mining_mode", "") == "approach"
		if dock_required and ship.get("kind", "") != "fighter":
			var dock: Vector2 = points[here]
			_navigate(ship, dock, distance)
			return (ship["position"] as Vector2) == dock
		return true
	while not route.is_empty() and distance > EPS:
		var next: Vector2 = points[int(route[0])]
		distance -= _navigate(ship, next, distance)
		if (ship["position"] as Vector2) != next:
			ship["leg"] = _lane_progress(points, ship)
			return false
		ship["at"] = int(route.pop_front())
		ship["leg"] = 0.0
	return route.is_empty()

static func _choose_delivery(state: Dictionary, ship: Dictionary, teams: Array[int], team: int, cache: Dictionary) -> void:
	var planets: Array = state["planets"]
	var here: int = int(ship["at"])
	var best: float = INF
	var best_source: int = -1
	var best_dest: int = -1
	var best_path: Array[int] = []
	for a in range(planets.size()):
		if teams[a] != team:
			continue
		var first: Array[int] = _path(state, teams, team, here, a, cache)
		if first.is_empty():
			continue
		var first_length: float = MAP.route_length(state["map"], first)
		for b in range(planets.size()):
			if a == b or teams[b] != team or not _opportunity(planets[a], planets[b]):
				continue
			var second: Array[int] = _path(state, teams, team, a, b, cache)
			var distance: float = first_length + MAP.route_length(state["map"], second)
			if distance < best:
				best = distance
				best_source = a
				best_dest = b
				best_path = first
	if best_source >= 0:
		ship["source"] = best_source
		ship["dest"] = best_dest
		_set_route(ship, best_path)

static func _pick_loaded_destination(state: Dictionary, ship: Dictionary, teams: Array[int], team: int, cache: Dictionary) -> void:
	var planets: Array = state["planets"]
	var best: float = INF
	var best_dest: int = -1
	var best_path: Array[int] = []
	for i in range(planets.size()):
		if teams[i] != team:
			continue
		var useful: bool = false
		for resource in RESOURCES:
			if float(ship["cargo"][resource]) > EPS and _need(planets[i], resource) > EPS:
				useful = true
				break
		if not useful:
			continue
		var path: Array[int] = _path(state, teams, team, int(ship["at"]), i, cache)
		var distance: float = MAP.route_length(state["map"], path)
		if distance < best:
			best = distance
			best_dest = i
			best_path = path
	ship["dest"] = best_dest
	if best_dest >= 0:
		_set_route(ship, best_path)

static func _work_ship(state: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, dt: float) -> void:
	var team: int = int(state["teams"].get(int(ship["owner"]), 0))
	if team == 0 or not _move(state, ship, dt):
		return
	var planets: Array = state["planets"]
	var here: int = int(ship["at"])
	if teams[here] != team:
		_evacuate_civilian(state, ship, teams)
		return
	var source: int = int(ship["source"])
	var dest: int = int(ship["dest"])
	if source == here and dest >= 0 and teams[here] == team and teams[dest] == team:
		# No reservations: actual arrival decides which surplus remains.
		var free: float = CARGO_CAPACITY - _cargo_total(ship)
		for resource in RESOURCES:
			var amount: float = minf(free, minf(_surplus(planets[here], resource), _need(planets[dest], resource)))
			if amount <= EPS:
				continue
			planets[here]["stock"][resource] = float(planets[here]["stock"][resource]) - amount
			_record_flow(planets[here], "Exports", resource, amount)
			ship["cargo"][resource] = float(ship["cargo"][resource]) + amount
			free -= amount
		ship["source"] = -1
		if _cargo_total(ship) > EPS:
			_set_route(ship, _path(state, teams, team, here, dest, cache))
			return
		ship["dest"] = -1
	elif source >= 0:
		ship["source"] = -1
		ship["dest"] = -1
	if int(ship["dest"]) == here and teams[here] == team and _cargo_total(ship) > EPS:
		for resource in RESOURCES:
			var amount: float = minf(float(ship["cargo"][resource]), _need(planets[here], resource))
			ship["cargo"][resource] = float(ship["cargo"][resource]) - amount
			planets[here]["stock"][resource] = float(planets[here]["stock"][resource]) + amount
			_record_flow(planets[here], "Imports", resource, amount)
		ship["dest"] = -1
	if _cargo_total(ship) > EPS:
		_pick_loaded_destination(state, ship, teams, team, cache)
	else:
		ship["source"] = -1
		ship["dest"] = -1
		_choose_delivery(state, ship, teams, team, cache)

static func field_limit(field: Dictionary, resource: String) -> float:
	return FIELD_MINING_LIMIT * float(field.get(resource, 0.0)) if FIELD_RESOURCES.has(resource) else 0.0

static func field_inventory(field: Dictionary) -> Dictionary:
	var stock: Dictionary = {"Metals": 0.0, "Crystals": 0.0, ANTIMATTER: 0.0}
	for chunk in field.get("chunks", []):
		var resource: String = str(chunk["resource"])
		stock[resource] = float(stock[resource]) + float(chunk["remaining"])
	return stock

static func _find_chunk(field: Dictionary, id: int) -> Dictionary:
	for chunk in field.get("chunks", []):
		if int(chunk["id"]) == id:
			return chunk
	return {}

# One shortest-path tree per source/team per tick. Sparse adjacency avoids
# scanning every lane for every candidate node and every asteroid field.
static func _mining_path(state: Dictionary, teams: Array[int], team: int, start: int, goal: int, _cache: Dictionary) -> Array[int]:
	if start < 0 or goal < 0 or start >= teams.size() or goal >= teams.size():
		return []
	if teams[start] not in [0, team] or teams[goal] not in [0, team]:
		return []
	var cache: Dictionary = _civilian_route_cache(state, teams)
	var points: Array = state["map"]["points"]
	if not cache.has("mine:adj"):
		var adjacency: Array = []
		for i in range(points.size()):
			adjacency.append([])
		for edge in state["map"]["edges"]:
			adjacency[int(edge[0])].append(int(edge[1]))
			adjacency[int(edge[1])].append(int(edge[0]))
		cache["mine:adj"] = adjacency
	var key: String = "mine:tree:%d:%d" % [team, start]
	if not cache.has(key):
		var adjacency: Array = cache["mine:adj"]
		var distances: Dictionary = {start: 0.0}
		var previous: Dictionary = {}
		var open: Array[int] = [start]
		var visited: Dictionary = {}
		while not open.is_empty():
			var current: int = open[0]
			for candidate in open:
				if float(distances[candidate]) < float(distances[current]):
					current = candidate
			open.erase(current)
			visited[current] = true
			for neighbor in adjacency[current]:
				var next: int = int(neighbor)
				if visited.has(next) or teams[next] not in [0, team]:
					continue
				var distance: float = float(distances[current]) + (points[current] as Vector2).distance_to(points[next])
				if distance < float(distances.get(next, INF)):
					distances[next] = distance
					previous[next] = current
					if not open.has(next):
						open.append(next)
		cache[key] = previous
	var previous: Dictionary = cache[key]
	var route: Array[int] = [goal]
	var current: int = goal
	while current != start:
		if not previous.has(current):
			return []
		current = int(previous[current])
		route.push_front(current)
	return route

static func _mining_depot(state: Dictionary, ship: Dictionary, teams: Array[int], team: int, anchor: int, resource: String, cache: Dictionary) -> int:
	var best: float = INF
	var chosen: int = -1
	for i in range((state["planets"] as Array).size()):
		var p: Dictionary = state["planets"][i]
		if int(p["owner"]) != int(ship["owner"]) or storage_free(p, resource) <= EPS:
			continue
		var distance: float = MAP.route_length(state["map"], _mining_path(state, teams, team, i, anchor, cache))
		if distance < best:
			best = distance
			chosen = i
	return chosen

static func field_access_systems(map_data: Dictionary, field: Dictionary) -> Array[int]:
	var points: Array = map_data["points"]
	var center: Vector2 = field["position"]
	var original: int = int(field["anchor"])
	var reach: float = center.distance_to(points[original]) * 1.5 + float(field.get("radius", 0.0))
	var result: Array[int] = []
	for i in range(points.size()):
		if i == original or center.distance_to(points[i]) <= reach + EPS:
			result.append(i)
	return result

static func _choose_field(state: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary) -> void:
	var fields: Array = state["map"].get("fields", [])
	var owner: int = int(ship["owner"])
	var team: int = int(state["teams"].get(owner, 0))
	var best: float = INF
	var chosen: int = -1
	var best_path: Array[int] = []
	var best_chunk: Dictionary = {}
	var best_anchor: int = -1
	for i in range(fields.size()):
		var field: Dictionary = fields[i]
		if not discovered(state, owner, "fields", i) or _mining_resources(state, owner, i).is_empty():
			continue
		var access_key: String = "mine:access:%d" % i
		if not cache.has(access_key):
			cache[access_key] = field_access_systems(state["map"], field)
		for anchor in cache[access_key]:
			var path: Array[int] = _mining_path(state, teams, team, int(ship["at"]), anchor, cache)
			if path.is_empty():
				continue
			var resources: Array[String] = _mining_resources(state, owner, i)
			var approach: Vector2 = state["map"]["points"][anchor]
			var route_distance: float = MAP.route_length(state["map"], path)
			var depots: Dictionary = {}
			var return_distances: Dictionary = {}
			for resource in resources:
				var depot: int = _mining_depot(state, ship, teams, team, anchor, resource, cache)
				depots[resource] = depot
				if depot >= 0:
					return_distances[resource] = MAP.route_length(state["map"], _mining_path(state, teams, team, depot, anchor, cache))
			for chunk in field.get("chunks", []):
				if not resources.has(str(chunk["resource"])) or float(chunk["remaining"]) <= EPS:
					continue
				var depot: int = int(depots.get(chunk["resource"], -1))
				if depot < 0:
					continue
				var distance: float = route_distance + approach.distance_to(chunk["position"]) * 2.0 + float(return_distances[chunk["resource"]])
				if distance < best:
					best = distance
					chosen = i
					best_path = path
					best_chunk = chunk
					best_anchor = anchor
	if chosen >= 0:
		ship["field"] = chosen
		ship["mining_anchor"] = best_anchor
		ship["chunk"] = int(best_chunk["id"])
		var rock: Vector2 = best_chunk["position"]
		var radial: Vector2 = (state["map"]["points"][best_anchor] - rock).normalized()
		if radial.is_zero_approx():
			radial = Vector2.RIGHT
		ship["mining_rock"] = rock
		ship["mining_target"] = rock + radial * (float(best_chunk.get("radius", 0.0)) + 12.0)
		ship["mining_mode"] = "approach"
		_set_route(ship, best_path)

static func _work_miner(state: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, budgets: Array, dt: float) -> void:
	var mode: String = str(ship.get("mining_mode", "idle"))
	if mode == "idle":
		if float(state["elapsed"]) + EPS >= float(ship.get("next_mining_search", 0.0)):
			_choose_field(state, ship, teams, cache)
			# Idle fleets retry twice per game year instead of every tick.
			ship["next_mining_search"] = float(state["elapsed"]) + 0.5
		return
	if mode == "delivery":
		if _move(state, ship, dt) and float(state["elapsed"]) + EPS >= float(ship.get("next_unload_search", 0.0)):
			_unload_miner(state, ship, teams, cache)
			ship["next_unload_search"] = float(state["elapsed"]) + 0.5
		return
	var field_index: int = int(ship["field"])
	var field: Dictionary = state["map"]["fields"][field_index]
	var anchor: int = int(ship.get("mining_anchor", field["anchor"]))
	if mode == "approach":
		if _move(state, ship, dt):
			var chunk: Dictionary = _find_chunk(field, int(ship["chunk"]))
			if chunk.is_empty() or not _mining_resources(state, int(ship["owner"]), field_index).has(str(chunk["resource"])):
				ship["mining_mode"] = "idle"
				ship["field"] = -1
				return
			ship["mining_mode"] = "outbound"
			ship["field_leg"] = 0.0
		return
	var origin: Vector2 = state["map"]["points"][anchor]
	var target: Vector2 = ship["mining_target"]
	var span: Vector2 = target - origin
	_ensure_position(state["map"]["points"], ship)
	if mode == "outbound":
		var chunk: Dictionary = _find_chunk(field, int(ship["chunk"]))
		if chunk.is_empty() or not _mining_resources(state, int(ship["owner"]), field_index).has(str(chunk["resource"])):
			ship["mining_mode"] = "return"
			return
		_navigate(ship, target, SHIP_SPEED * dt)
		ship["field_leg"] = clampf(((ship["position"] as Vector2) - origin).dot(span) / maxf(EPS, span.length_squared()), 0.0, 1.0)
		if (ship["position"] as Vector2) == target:
			ship["mining_mode"] = "mining"
			ship["mining_years"] = 0.0
		return
	if mode == "mining":
		ship["mining_years"] = float(ship.get("mining_years", 0.0)) + dt
		var resources: Array[String] = _mining_resources(state, int(ship["owner"]), field_index)
		var chunk: Dictionary = _find_chunk(field, int(ship["chunk"]))
		var available: bool = not chunk.is_empty() and resources.has(str(chunk["resource"]))
		if available:
			var resource: String = str(chunk["resource"])
			var free: float = MINER_CAPACITY - _cargo_total(ship)
			var amount: float = minf(free, minf(float(chunk["remaining"]), minf(MINER_RATE * float(field[resource]) * dt, float(budgets[field_index][resource]))))
			ship["cargo"][resource] = float(ship["cargo"].get(resource, 0.0)) + amount
			chunk["remaining"] = maxf(0.0, float(chunk["remaining"]) - amount)
			budgets[field_index][resource] = maxf(0.0, float(budgets[field_index][resource]) - amount)
			if float(chunk["remaining"]) <= EPS:
				field["chunks"].erase(chunk)
				available = false
		if float(ship["mining_years"]) >= MINING_STAY - EPS and (not available or _cargo_total(ship) >= MINER_CAPACITY - 0.1):
			ship["mining_mode"] = "return"
		return
	if mode == "return":
		_navigate(ship, origin, SHIP_SPEED * dt)
		ship["field_leg"] = clampf(((ship["position"] as Vector2) - origin).dot(span) / maxf(EPS, span.length_squared()), 0.0, 1.0)
		if (ship["position"] as Vector2) == origin:
			ship["mining_mode"] = "delivery"
			_unload_miner(state, ship, teams, cache)

static func _unload_miner(state: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary) -> void:
	var here: int = int(ship["at"])
	var owner: int = int(ship["owner"])
	var team: int = int(state["teams"].get(owner, 0))
	var local: Dictionary = state["planets"][here]
	if teams[here] not in [0, team]:
		_evacuate_civilian(state, ship, teams)
		return
	if int(local["owner"]) == owner:
		for resource in FIELD_RESOURCES:
			var amount: float = minf(float(ship["cargo"].get(resource, 0.0)), storage_free(local, resource))
			if amount <= 0.0:
				continue
			local["stock"][resource] = float(local["stock"].get(resource, 0.0)) + amount
			_record_flow(local, "Mining deliveries", resource, amount)
			ship["cargo"][resource] -= amount
	if _cargo_total(ship) <= EPS:
		ship["mining_mode"] = "idle"
		ship["field"] = -1
		ship["dest"] = -1
		return
	for resource in FIELD_RESOURCES:
		if float(ship["cargo"].get(resource, 0.0)) <= EPS:
			continue
		var depot: int = _mining_depot(state, ship, teams, team, here, resource, cache)
		if depot >= 0 and depot != here:
			ship["dest"] = depot
			_set_route(ship, _mining_path(state, teams, team, here, depot, cache))
			return
	ship["dest"] = here

static func military_home(state: Dictionary, player: int) -> int:
	var fallback: int = -1
	for i in range((state["planets"] as Array).size()):
		if int(state["planets"][i]["owner"]) != player:
			continue
		if bool(state["planets"][i]["home"]):
			return i
		if fallback < 0:
			fallback = i
	return fallback

# Exact integer percentages / hull counts via largest remainder, stable tie order.
static func _apportion(keys: Array, weights: Dictionary, total: int) -> Dictionary:
	var result: Dictionary = {}
	if keys.is_empty():
		return result
	var sum: float = 0.0
	for key in keys:
		sum += maxf(0.0, float(weights.get(key, 0)))
	var remainder: Dictionary = {}
	var left: int = total
	for key in keys:
		var exact: float = float(total) * (maxf(0.0, float(weights.get(key, 0))) / sum if sum > EPS else 1.0 / float(keys.size()))
		result[key] = floori(exact)
		remainder[key] = exact - float(result[key])
		left -= int(result[key])
	while left > 0:
		var best: Variant = keys[0]
		for key in keys:
			if float(remainder[key]) > float(remainder[best]):
				best = key
		result[best] += 1
		remainder[best] = -1.0
		left -= 1
	return result

# POI identifiers: system indices followed by stable asteroid field indices.
static func sector_base_radius(map_data: Dictionary) -> float:
	var points: Array = map_data["points"]
	var spacings: Array[float] = []
	for i in range(points.size()):
		var shortest: float = INF
		for j in range(points.size()):
			if i != j:
				shortest = minf(shortest, (points[i] as Vector2).distance_to(points[j]))
		if is_finite(shortest) and shortest > 0.0:
			spacings.append(shortest)
	spacings.sort()
	return 300.0 if spacings.is_empty() else maxf(100.0, spacings[floori(float(spacings.size()) * 0.5)] * 0.73)

static func sector_limit(graph: Dictionary, node: int, direction: Vector2) -> float:
	# A sector is the local territory disk clipped by the nearest-POI
	# bisectors. Its convex bounds also contain straight-line idle movement.
	var limit: float = float(graph["sector_radii"][node])
	for delta in graph["sector_neighbors"][node]:
		var projection: float = direction.dot(delta)
		if projection > EPS:
			limit = minf(limit, (delta as Vector2).length_squared() / (2.0 * projection))
	return limit

static func sector_contains(graph: Dictionary, node: int, position: Vector2) -> bool:
	var offset: Vector2 = position - (graph["points"][node] as Vector2)
	return offset.length() <= sector_limit(graph, node, offset.normalized()) + EPS

static func military_graph(state: Dictionary) -> Dictionary:
	var map_data: Dictionary = state["map"]
	if not cached_military_graph.is_empty() and cached_military_map.get("points") == map_data["points"] and cached_military_map.get("edges") == map_data["edges"] and cached_military_map.get("field_positions") == _field_positions(map_data):
		return cached_military_graph
	var points: Array = map_data["points"].duplicate()
	var edges: Array = map_data["edges"].duplicate()
	for field in state["map"].get("fields", []):
		for anchor in field_access_systems(state["map"], field):
			edges.append([anchor, points.size()])
		points.append(field["position"])
	var adjacent: Array = []
	for i in range(points.size()):
		adjacent.append([])
	for edge in edges:
		adjacent[edge[0]].append(edge[1])
		adjacent[edge[1]].append(edge[0])
	var base_radius: float = sector_base_radius(map_data)
	var sector_radii: Array[float] = []
	var sector_neighbors: Array = []
	for i in range(points.size()):
		var radius: float = base_radius if i < (map_data["points"] as Array).size() else base_radius * 0.68
		sector_radii.append(radius)
		var neighbors: Array[Vector2] = []
		for j in range(points.size()):
			if i == j:
				continue
			var delta: Vector2 = points[j] - points[i]
			if delta.length_squared() < 4.0 * radius * radius and delta.length_squared() > EPS:
				neighbors.append(delta)
		sector_neighbors.append(neighbors)
	cached_military_map = {"points": map_data["points"].duplicate(), "edges": map_data["edges"].duplicate(true), "field_positions": _field_positions(map_data)}
	cached_military_graph = {"points": points, "edges": edges, "adjacent": adjacent, "paths": {}, "sector_radii": sector_radii, "sector_neighbors": sector_neighbors}
	return cached_military_graph

static func _field_positions(map_data: Dictionary) -> Array:
	var result: Array = []
	for field in map_data.get("fields", []):
		result.append([field["position"], field["anchor"], field.get("radius", 0.0)])
	return result

static func military_pois(state: Dictionary, player: int) -> Array[int]:
	var result: Array[int] = []
	var count: int = (state["planets"] as Array).size()
	for i in range(count):
		if discovered(state, player, "planets", i):
			result.append(i)
	for i in range((state["map"].get("fields", []) as Array).size()):
		if discovered(state, player, "fields", i):
			result.append(count + i)
	return result

static func military_policy(state: Dictionary, player: int, kind: String) -> Dictionary:
	var keys: Array = military_pois(state, player)
	var saved: Dictionary = state.get("military", {}).get(player, {}).get(kind, {})
	var weights: Dictionary = {}
	var home: int = military_home(state, player)
	for node in keys:
		weights[node] = int(saved.get(node, 0 if not saved.is_empty() or node != home else 100))
	if not keys.is_empty() and weights.values().max() == 0:
		weights[home if keys.has(home) else keys[0]] = 100
	return _apportion(keys, weights, 100)

static func change_military_weights(weights: Dictionary, home: int, node: int, percent: int) -> Dictionary:
	var others: Array = weights.keys()
	others.erase(node)
	var sum: int = 0
	for key in others:
		sum += int(weights[key])
	if sum == 0:
		# Never spread a sole allocation across dozens of zero-valued POIs.
		var result: Dictionary = weights.duplicate()
		if node != home and others.has(home):
			result[home] = 100 - percent
			result[node] = percent
		else:
			result[node] = 100
		return result
	var result: Dictionary = _apportion(others, weights, 100 - percent)
	result[node] = percent
	return result

static func set_military(state: Dictionary, player: int, kind: String, node: int, percent: int) -> bool:
	if not state["teams"].has(player) or kind != "fighter" or percent < 0 or percent > 100:
		return false
	var weights: Dictionary = military_policy(state, player, kind)
	if not weights.has(node):
		return false
	if not state["military"].has(player):
		state["military"][player] = {}
	state["military"][player][kind] = change_military_weights(weights, military_home(state, player), node, percent)
	return true

# Dijkstra from the destination: all military ships may traverse star lanes,
# regardless of ownership. Fields use their existing service-system approach.
static func _military_paths(graph: Dictionary, goal: int) -> Dictionary:
	if graph.has("paths") and graph["paths"].has(goal):
		return graph["paths"][goal]
	var points: Array = graph["points"]
	var distances: Dictionary = {goal: 0.0}
	var next_hop: Dictionary = {}
	var open: Array[int] = [goal]
	var visited: Dictionary = {}
	while not open.is_empty():
		var current: int = open[0]
		for node in open:
			if float(distances[node]) < float(distances[current]):
				current = node
		open.erase(current)
		visited[current] = true
		for node in graph["adjacent"][current]:
			if visited.has(node):
				continue
			var distance: float = float(distances[current]) + (points[current] as Vector2).distance_to(points[node])
			if distance < float(distances.get(node, INF)):
				distances[node] = distance
				next_hop[node] = current
				if not open.has(node):
					open.append(node)
	var result: Dictionary = {"distance": distances, "next": next_hop}
	if graph.has("paths"):
		graph["paths"][goal] = result
	return result

static func _military_approach(graph: Dictionary, ship: Dictionary, paths: Dictionary) -> Dictionary:
	var points: Array = graph["points"]
	var here: int = int(ship["at"])
	var distances: Dictionary = paths["distance"]
	var route: Array = ship["route"]
	var position: Vector2 = ship.get("position", _initial_position(points, ship))
	var best: float = position.distance_to(points[here]) + float(distances.get(here, INF))
	var reverse: bool = not route.is_empty() and position.distance_to(points[here]) > EPS
	if not route.is_empty():
		var other: int = int(route[0])
		var forward: float = position.distance_to(points[other]) + float(distances.get(other, INF))
		if forward <= best:
			return {"distance": forward, "anchor": other, "reverse": false, "edge": true}
	return {"distance": best, "anchor": here, "reverse": reverse, "edge": reverse}

static func _redirect_fighter(graph: Dictionary, ship: Dictionary, target: int, paths: Dictionary) -> void:
	_ensure_position(graph["points"], ship)
	var approach: Dictionary = _military_approach(graph, ship, paths)
	var anchor: int = int(approach["anchor"])
	var route: Array[int] = []
	if bool(approach["edge"]):
		if bool(approach["reverse"]):
			ship["at"] = int(ship["route"][0])
		route.append(anchor)
	else:
		ship["leg"] = 0.0
	var current: int = anchor
	while current != target and paths["next"].has(current):
		current = int(paths["next"][current])
		route.append(current)
	ship["route"] = route
	ship["leg"] = _lane_progress(graph["points"], ship)
	ship["dest"] = target

# Validate the entire selection before changing any order. Only owned fighters
# can receive military movement orders, including during automatic repairs.
static func command_fighters(state: Dictionary, player: int, ids: Array, target: int) -> bool:
	if ids.is_empty() or not military_pois(state, player).has(target):
		return false
	var selected: Array = _owned_fighters(state, player, ids)
	if selected.is_empty():
		return false
	var graph: Dictionary = military_graph(state)
	var paths: Dictionary = _military_paths(graph, target)
	for ship in selected:
		if not paths["distance"].has(int(ship["at"])):
			return false
	for ship in selected:
		ship["direct_order"] = true
		ship["holding"] = false
		ship["operation_target"] = target
		ship.erase("rally_pending")
		if not bool(ship.get("retreating", false)):
			_redirect_fighter(graph, ship, target, paths)
	return true

static func _owned_fighters(state: Dictionary, player: int, ids: Array) -> Array:
	var requested: Dictionary = {}
	for id in ids:
		if not id is int or requested.has(id):
			return []
		requested[id] = true
	var selected: Array = []
	for ship in state["ships"]:
		if requested.has(ship["id"]):
			if int(ship["owner"]) != player or ship.get("kind", "") != "fighter":
				return []
			selected.append(ship)
	if selected.size() != requested.size():
		return []
	return selected

static func hold_fighters(state: Dictionary, player: int, ids: Array) -> bool:
	var selected: Array = _owned_fighters(state, player, ids)
	if selected.is_empty():
		return false
	for ship in selected:
		ship["direct_order"] = true
		ship["holding"] = true
		ship["operation_target"] = int(ship["at"])
		ship["pursuit_target"] = -1
		ship["pursuit_left"] = 0.0
		ship.erase("pursuit_blocked")
		ship.erase("rally_pending")
		if not bool(ship.get("retreating", false)) and ship.has("position"):
			ship["navigation_target"] = ship["position"]
	return true

static func _allocate_fighters(state: Dictionary, graph: Dictionary, player: int, fleet: Array, defer_routes: bool = false) -> void:
	var weights: Dictionary = military_policy(state, player, "fighter")
	var counts: Dictionary = _apportion(weights.keys(), weights, fleet.size())
	var actual: Dictionary = {}
	for ship in fleet:
		var dest: int = int(ship.get("operation_target", ship.get("dest", -1))) if defer_routes else int(ship.get("dest", -1))
		actual[dest] = int(actual.get(dest, 0)) + 1
	var matches: bool = true
	for node in counts:
		if int(counts[node]) != int(actual.get(node, 0)):
			matches = false
			break
	if matches:
		if defer_routes:
			for ship in fleet:
				ship["operation_target"] = int(ship.get("operation_target", ship.get("dest", -1)))
		return
	var paths: Dictionary = {}
	for node in counts:
		if int(counts[node]) > 0:
			paths[node] = _military_paths(graph, int(node))
	var remaining: Array = fleet.duplicate()
	# Greedily reserve closest available ship/POI pairs by remaining travel
	# distance, using stable fleet and POI order for equal distances.
	while not remaining.is_empty():
		var best_ship: Dictionary = {}
		var best_node: int = -1
		var best: float = INF
		for ship in remaining:
			for node in paths:
				if int(counts[node]) <= 0:
					continue
				var distance: float = float(_military_approach(graph, ship, paths[node])["distance"])
				if distance < best:
					best = distance
					best_ship = ship
					best_node = int(node)
		if best_ship.is_empty():
			return
		if defer_routes:
			best_ship["operation_target"] = best_node
		elif int(best_ship.get("dest", -1)) != best_node:
			_redirect_fighter(graph, best_ship, best_node, paths[best_node])
		counts[best_node] -= 1
		remaining.erase(best_ship)

static func combat_position(state: Dictionary, graph: Dictionary, ship: Dictionary) -> Vector2:
	var points: Array = graph["points"] if ship.get("kind", "") == "fighter" else state["map"]["points"]
	return ship.get("position", _initial_position(points, ship))

# Territory is derived from ownership and actual fleet presence, not orders.
# Stationed fighters claim neutral POIs. Hostile presence or combat suppresses
# the local sector; allied fighters contribute the same team color.
static func territory_claims(state: Dictionary) -> Array[int]:
	var graph: Dictionary = military_graph(state)
	var points: Array = graph["points"]
	var claims: Array[int] = planet_teams(state)
	claims.resize(points.size())
	for i in range((state["planets"] as Array).size(), claims.size()):
		claims[i] = 0
	var presence: Dictionary = {}
	var contested: Dictionary = {}
	var near_ship: Dictionary = {}
	for ship in state["ships"]:
		var kind: String = ship.get("kind", "")
		var position: Vector2 = combat_position(state, graph, ship)
		var node: int = -1
		var nearest: float = INF
		for i in range(points.size()):
			var distance: float = position.distance_squared_to(points[i])
			if distance < nearest:
				nearest = distance
				node = i
		if node < 0:
			continue
		near_ship[int(ship["id"])] = node
		if kind != "fighter":
			continue
		var team: int = int(state["teams"].get(int(ship["owner"]), 0))
		if team <= 0:
			continue
		var stationary: bool = (ship["route"] as Array).is_empty() and not _engaged(ship)
		if stationary:
			node = int(ship["at"])
			if claims[node] == 0:
				claims[node] = team
			elif claims[node] != team:
				contested[node] = true
		if stationary or nearest <= LASER_RANGE * LASER_RANGE:
			if presence.has(node) and int(presence[node]) != team:
				contested[node] = true
			presence[node] = team
	for node in presence:
		if claims[node] > 0 and claims[node] != int(presence[node]):
			contested[node] = true
	for ship in state["ships"]:
		var target: int = int(ship.get("combat_target", -1))
		if target >= 0 and near_ship.has(target):
			contested[near_ship[int(ship["id"])]] = true
			contested[near_ship[target]] = true
	for node in contested:
		claims[node] = 0
	return claims

# Visual owner identity is separate from team control and contested logic.
# An owned system uses its owner's color; a neutral claim uses the lowest
# ID of its stationary friendly fighters for a deterministic tie.
static func territory_empires(state: Dictionary) -> Array[int]:
	var claims: Array[int] = territory_claims(state)
	var owners: Array[int] = []
	owners.resize(claims.size())
	owners.fill(0)
	for i in range((state["planets"] as Array).size()):
		if claims[i] > 0:
			owners[i] = int(state["planets"][i]["owner"])
	for craft in state["ships"]:
		if craft.get("kind", "") != "fighter" or not (craft["route"] as Array).is_empty() or _engaged(craft):
			continue
		var node: int = int(craft["at"])
		var owner: int = int(craft["owner"])
		if node < 0 or node >= claims.size() or claims[node] <= 0 or claims[node] != int(state["teams"].get(owner, 0)):
			continue
		if node < (state["planets"] as Array).size() and int(state["planets"][node]["owner"]) != 0:
			continue
		if owners[node] == 0 or owner < owners[node]:
			owners[node] = owner
	return owners

static func _engaged(ship: Dictionary) -> bool:
	return int(ship.get("combat_target", -1)) >= 0 or int(ship.get("pursuit_target", -1)) >= 0

# Unarmed hulls are pursuit targets. A fighter fleeing along a route (or
# explicitly withdrawing in a future retreat system) is also eligible.
static func _fleeing(other: Dictionary, away: Vector2, previous_target: int) -> bool:
	if other.get("kind", "") != "fighter" or bool(other.get("retreating", false)):
		return true
	var heading: Vector2 = other.get("heading", Vector2.ZERO)
	return previous_target < 0 and not (other["route"] as Array).is_empty() and heading.dot(away.normalized()) > 0.25

static func _combat(state: Dictionary, graph: Dictionary, dt: float) -> void:
	var ships: Array = state["ships"]
	var positions: Dictionary = {}
	var by_id: Dictionary = {}
	var previous_targets: Dictionary = {}
	var cells: Dictionary = {}
	for ship in ships:
		var id: int = int(ship["id"])
		var pos: Vector2 = combat_position(state, graph, ship)
		positions[id] = pos
		by_id[id] = ship
		previous_targets[id] = int(ship.get("combat_target", -1))
		var cell := Vector2i(floori(pos.x / LASER_RANGE), floori(pos.y / LASER_RANGE))
		if not cells.has(cell):
			cells[cell] = []
		cells[cell].append(ship)
	var yard_targets: Dictionary = {}
	var pds_targets: Dictionary = {}
	var system_count: int = (state["planets"] as Array).size()
	for index in range(system_count):
		var system: Dictionary = state["planets"][index]
		for slot in range(system["yards"].size()):
			var target_id: int = -2 - index * 3 - slot
			var pos: Vector2 = shipyard_position(state, index, slot, float(state["elapsed"]))
			yard_targets[target_id] = Vector2i(index, slot)
			positions[target_id] = pos
			var cell := Vector2i(floori(pos.x / LASER_RANGE), floori(pos.y / LASER_RANGE))
			if not cells.has(cell):
				cells[cell] = []
			cells[cell].append({"id": target_id, "owner": system["owner"], "kind": "shipyard"})
		for slot in system.get("pds", {}):
			# Disjoint negative ID range; all batteries use the same
			# authoritative fire/range origin as their defensive shots.
			var target_id: int = -2 - system_count * 3 - int(slot) * system_count - index
			var pos: Vector2 = graph["points"][index]
			pds_targets[target_id] = Vector2i(index, int(slot))
			positions[target_id] = pos
			var cell := Vector2i(floori(pos.x / LASER_RANGE), floori(pos.y / LASER_RANGE))
			if not cells.has(cell):
				cells[cell] = []
			cells[cell].append({"id": target_id, "owner": system["owner"], "kind": "pds"})
	var damage: Dictionary = {}
	for ship in ships:
		if ship.get("kind", "") != "fighter":
			continue
		if bool(ship.get("retreating", false)):
			ship["combat_target"] = -1
			ship["pursuit_target"] = -1
			ship["pursuit_left"] = 0.0
			ship["laser_until"] = -1.0
			ship["yard_target"] = -1
			ship["yard_laser_until"] = -1.0
			continue
		var id: int = int(ship["id"])
		var pos: Vector2 = positions[id]
		var team: int = int(state["teams"].get(int(ship["owner"]), 0))
		var cell := Vector2i(floori(pos.x / LASER_RANGE), floori(pos.y / LASER_RANGE))
		var target: int = -1
		var pursuit: int = int(ship.get("pursuit_target", -1))
		var remaining: float = float(ship.get("pursuit_left", 0.0))
		var blocked: Dictionary = ship.get("pursuit_blocked", {})
		for blocked_id in blocked.keys():
			if not positions.has(blocked_id) or pos.distance_squared_to(positions[blocked_id]) > LASER_RANGE * LASER_RANGE:
				blocked.erase(blocked_id)
		if pursuit >= 0:
			if not by_id.has(pursuit) or int(state["teams"].get(int(by_id[pursuit]["owner"]), 0)) == team or team == 0:
				pursuit = -1
			elif remaining <= EPS:
				# Do not immediately restart a timed-out chase while the same
				# escaping hull is still in range. A fresh contact may engage.
				blocked[pursuit] = true
				pursuit = -1
			elif by_id[pursuit].get("kind", "") == "fighter" and not bool(by_id[pursuit].get("retreating", false)) and int(previous_targets[pursuit]) == id and pos.distance_squared_to(positions[pursuit]) <= LASER_RANGE * LASER_RANGE:
				pursuit = -1
		var best: float = LASER_RANGE * LASER_RANGE
		for x in range(-1, 2):
			for y in range(-1, 2):
				for other in cells.get(cell + Vector2i(x, y), []):
					if int(state["teams"].get(int(other["owner"]), 0)) == team or team == 0:
						continue
					var other_id: int = int(other["id"])
					if other_id < 0:
						continue
					var distance: float = pos.distance_squared_to(positions[other_id])
					if blocked.has(other_id) and _fleeing(other, positions[other_id] - pos, int(previous_targets[other_id])):
						continue
					if distance < best or (is_equal_approx(distance, best) and (target < 0 or other_id < target)):
						best = distance
						target = other_id
		if not bool(ship.get("holding", false)) and pursuit < 0 and target >= 0 and _fleeing(by_id[target], positions[target] - pos, int(previous_targets[target])):
			pursuit = target
			remaining = PURSUIT_YEARS
		# A previously engaged fighter may escape the firing envelope before
		# the next scan; its departure is still a valid pursuit trigger.
		var prior: int = int(previous_targets[id])
		if not bool(ship.get("holding", false)) and pursuit < 0 and target < 0 and by_id.has(prior) and not blocked.has(prior) and team != 0 and int(state["teams"].get(int(by_id[prior]["owner"]), 0)) != team and _fleeing(by_id[prior], positions[prior] - pos, int(previous_targets[prior])):
			pursuit = prior
			remaining = PURSUIT_YEARS
		if pursuit >= 0:
			target = pursuit if pos.distance_squared_to(positions[pursuit]) <= LASER_RANGE * LASER_RANGE else -1
		else:
			remaining = 0.0
		ship["pursuit_target"] = pursuit
		ship["pursuit_left"] = remaining
		ship["pursuit_blocked"] = blocked
		if int(previous_targets[id]) != target:
			ship["laser_until"] = -1.0
		ship["combat_target"] = target
		var cooldown: float = maxf(0.0, float(ship.get("laser_cooldown", 0.0)) - dt)
		if target >= 0 and cooldown <= EPS:
			damage[target] = float(damage.get(target, 0.0)) + LASER_DAMAGE
			cooldown = 1.0
			ship["laser_until"] = float(state["elapsed"]) + 0.2
		ship["laser_cooldown"] = cooldown
		ship["yard_target"] = -1
		if target < 0 and pursuit < 0:
			var nearest: float = LASER_RANGE * LASER_RANGE
			for x in range(-1, 2):
				for y in range(-1, 2):
					for other in cells.get(cell + Vector2i(x, y), []):
						var yard_id: int = int(other["id"])
						if yard_id >= 0 or team == 0 or int(state["teams"].get(int(other["owner"]), 0)) == team:
							continue
						var distance: float = pos.distance_squared_to(positions[yard_id])
						if distance < nearest:
							nearest = distance
							ship["yard_target"] = yard_id
			var yard_id: int = int(ship["yard_target"])
			if yard_id < -1 and cooldown <= EPS:
				damage[yard_id] = float(damage.get(yard_id, 0.0)) + LASER_DAMAGE
				ship["laser_cooldown"] = 1.0
				ship["yard_laser_until"] = float(state["elapsed"]) + 0.2
	# Planets are visual orbits around a shared authoritative system waypoint.
	# Use that waypoint for range; each installed battery fires independently.
	for index in range((state["planets"] as Array).size()):
		var system: Dictionary = state["planets"][index]
		var defenses: Dictionary = system.get("pds", {})
		if defenses.is_empty():
			continue
		var team: int = int(state["teams"].get(int(system["owner"]), 0))
		if team <= 0:
			continue
		var origin: Vector2 = graph["points"][index]
		var cell := Vector2i(floori(origin.x / LASER_RANGE), floori(origin.y / LASER_RANGE))
		var target: int = -1
		var best: float = LASER_RANGE * LASER_RANGE
		for x in range(-1, 2):
			for y in range(-1, 2):
				for other in cells.get(cell + Vector2i(x, y), []):
					if int(state["teams"].get(int(other["owner"]), 0)) == team:
						continue
					var other_id: int = int(other["id"])
					if other_id < 0:
						continue
					var distance: float = origin.distance_squared_to(positions[other_id])
					if distance < best or (distance <= best and (target < 0 or other_id < target)):
						target = other_id
						best = distance
		for battery in defenses.values():
			if int(battery["target"]) != target:
				battery["laser_until"] = -1.0
			battery["target"] = target
			var cooldown: float = maxf(0.0, float(battery["cooldown"]) - dt)
			if target >= 0 and cooldown <= EPS:
				damage[target] = float(damage.get(target, 0.0)) + PDS_DAMAGE
				cooldown = 1.0
				battery["laser_until"] = float(state["elapsed"]) + 0.2
			battery["cooldown"] = cooldown
	for ship in ships.duplicate():
		var id: int = int(ship["id"])
		if damage.has(id):
			ship["hp"] = maxf(0.0, float(ship.get("hp", SHIP_HP)) - float(damage[id]))
			if float(ship["hp"]) <= EPS:
				ships.erase(ship)
	# Fixed batteries and shipyards participate in simultaneous damage.
	for id in pds_targets:
		if not damage.has(id):
			continue
		var location: Vector2i = pds_targets[id]
		var defenses: Dictionary = state["planets"][location.x]["pds"]
		var battery: Dictionary = defenses[location.y]
		battery["hp"] = maxf(0.0, float(battery.get("hp", PDS_HP)) - float(damage[id]))
		if float(battery["hp"]) <= EPS:
			defenses.erase(location.y)
	# Remove in reverse slot order to preserve indices during compaction.
	var destroyed: Array[int] = []
	for id in yard_targets:
		if not damage.has(id):
			continue
		var location: Vector2i = yard_targets[id]
		var yard: Dictionary = state["planets"][location.x]["yards"][location.y]
		yard["hp"] = maxf(0.0, float(yard.get("hp", SHIP_HP * 10.0 * int(yard["level"]))) - float(damage[id]))
		if float(yard["hp"]) <= EPS:
			destroyed.append(id)
	destroyed.sort()
	for id in destroyed:
		var location: Vector2i = yard_targets[id]
		var planet: Dictionary = state["planets"][location.x]
		var job_id: int = int(planet["yards"][location.y]["job"])
		for item in planet["queue"].duplicate():
			if int(item["id"]) == job_id or (item["kind"] == "yard_upgrade" and int(item["target"]) == location.y):
				planet["queue"].erase(item)
			elif item["kind"] == "yard_upgrade" and int(item["target"]) > location.y:
				item["target"] = str(int(item["target"]) - 1)
		planet["yards"].remove_at(location.y)
		_compact_shipyard_orders(planet, location.y + 1)
		for slot in range(3):
			planet["continuous"].erase("yard_upgrade:%d" % slot)

static func _ai_colony_target(state: Dictionary, player: int, ship: Dictionary, reserved: Dictionary) -> int:
	var points: Array = state["map"]["points"]
	var teams: Array[int] = planet_teams(state)
	var team: int = int(state["teams"].get(player, 0))
	var here: int = int(ship["at"])
	if team == 0 or (teams[here] != team and military_home(state, player) >= 0):
		return -1
	var adjacency: Array = []
	for i in range(points.size()):
		adjacency.append([])
	for edge in state["map"]["edges"]:
		adjacency[edge[0]].append(edge[1])
		adjacency[edge[1]].append(edge[0])
	var distances: Dictionary = {here: 0.0}
	var open: Array[int] = [here]
	var visited: Dictionary = {}
	var best: float = INF
	var target: int = -1
	while not open.is_empty():
		var current: int = open[0]
		for node in open:
			if float(distances[node]) < float(distances[current]):
				current = node
		open.erase(current)
		visited[current] = true
		for node in adjacency[current]:
			var distance: float = float(distances[current]) + (points[current] as Vector2).distance_to(points[node])
			if teams[node] == 0:
				if not reserved.has(node) and discovered(state, player, "planets", int(node)):
					var richness: float = float(state["planets"][node]["abundance"].get("Metals", 0.0))
					var score: float = distance / (1.0 + minf(richness, 2.0) * 0.15)
					if score < best:
						best = score
						target = int(node)
			if not visited.has(node) and distance < float(distances.get(node, INF)):
				distances[node] = distance
				if not open.has(node):
					open.append(node)
	return target

static func _ai_turn(state: Dictionary, graph: Dictionary, player: int) -> void:
	var home: int = military_home(state, player)
	if home < 0:
		# A surviving colony hull can establish a new home even after the
		# empire loses its last owned system.
		var reserved: Dictionary = {}
		for ship in state["ships"]:
			if int(ship["owner"]) == player and ship.get("kind", "") == "colony_ship" and not (ship["route"] as Array).is_empty():
				reserved[int(ship["dest"])] = true
		for ship in state["ships"]:
			if int(ship["owner"]) != player or ship.get("kind", "") != "colony_ship" or not (ship["route"] as Array).is_empty():
				continue
			var target: int = _ai_colony_target(state, player, ship, reserved)
			if target >= 0 and send_colony(state, player, int(ship["id"]), target):
				reserved[target] = true
		return
	var planets: Array = state["planets"]
	var team: int = int(state["teams"][player])
	var owned: Array[int] = []
	var counts: Dictionary = {"ship": 0, "colony_ship": 0, "miner": 0, "fighter": 0}
	var reserved: Dictionary = {}
	var fighters: Array = []
	var idle_colonies: Array = []
	var useful_fields: int = 0
	for ship in state["ships"]:
		if int(ship["owner"]) != player:
			continue
		var kind: String = ship["kind"]
		counts[kind] += 1
		if kind == "fighter":
			fighters.append(ship)
		elif kind == "colony_ship":
			if (ship["route"] as Array).is_empty():
				idle_colonies.append(ship)
			elif int(ship["dest"]) >= 0:
				reserved[int(ship["dest"])] = true
	for field in state["map"].get("fields", []):
		if float(field_inventory(field)["Metals"]) <= EPS:
			continue
		for anchor in field_access_systems(state["map"], field):
			if int(planets[anchor]["owner"]) == player:
				useful_fields += 1
				break
	for index in range(planets.size()):
		var p: Dictionary = planets[index]
		if int(p["owner"]) != player:
			continue
		owned.append(index)
		for job in p["queue"]:
			if SHIP_KINDS.has(job["kind"]):
				counts[job["kind"]] += 1
		var producer: bool = int(p["levels"]["Metals"]) > 0
		set_thresholds(state, player, index, "Metals", 10.0 if bool(p["home"]) else (35.0 if producer else 90.0), 40.0 if bool(p["home"]) else (60.0 if producer else 95.0))
	for ship in idle_colonies:
		var target: int = _ai_colony_target(state, player, ship, reserved)
		if target >= 0 and send_colony(state, player, int(ship["id"]), target):
			reserved[target] = true
	var probe: Dictionary = {"kind": "colony_ship", "owner": player, "at": home, "route": []}
	var expansion: bool = _ai_colony_target(state, player, probe, reserved) >= 0
	for index in owned:
		var p: Dictionary = planets[index]
		if not (p["queue"] as Array).is_empty():
			continue
		var level: int = production_level(p, "Metals") + int(p.get("buildings", {}).get("Metals", 0))
		var abundance: float = float(p["abundance"].get("Metals", 0.0))
		var farm: int = production_level(p, "Organics") + int(p.get("buildings", {}).get("Organics", 0))
		var action: String = ""
		var target: String = ""
		var has_yard: bool = operational_shipyards(p) > 0
		# Select the next goal before checking funding. Save for that goal
		# rather than continually buying cheaper ships or secondary upgrades.
		if abundance > 0.0 and level == 0:
			action = "economy"
			target = "Metals"
		elif index == home and owned.size() > 1 and counts["ship"] == 0:
			action = "ship"
		elif has_yard and owned.size() > 1 and counts["fighter"] < mini(12, owned.size() * 2):
			action = "fighter"
		elif index == home and expansion and counts["colony_ship"] == 0:
			if float(p["population"]) >= CREW_COSTS["colony_ship"] + SHIPYARD_POPULATION[0]:
				action = "colony_ship"
			elif population_capacity(p) < CREW_COSTS["colony_ship"] + SHIPYARD_POPULATION[0]:
				action = "economy"
				target = "Organics"
		elif has_yard and counts["fighter"] == 0:
			action = "fighter"
		elif has_yard and useful_fields > 0 and counts["miner"] == 0:
			action = "miner"
		elif index == home and level < 2 and abundance > 0.0:
			action = "economy"
			target = "Metals"
		elif has_yard and counts["fighter"] < AI_WAVE_MIN:
			action = "fighter"
		elif index == home and counts["ship"] < mini(12, owned.size() * 2) and owned.size() > 1:
			action = "ship"
		elif has_yard and expansion and counts["colony_ship"] < 3 and float(p["population"]) >= CREW_COSTS["colony_ship"] + SHIPYARD_POPULATION[0]:
			var local_probe: Dictionary = {"kind": "colony_ship", "owner": player, "at": index, "route": []}
			if _ai_colony_target(state, player, local_probe, reserved) >= 0:
				action = "colony_ship"
		if action.is_empty():
			if has_yard and counts["fighter"] < maxi(3, mini(24, owned.size() * 2)):
				action = "fighter"
			elif has_yard and useful_fields > 0 and counts["miner"] < mini(6, useful_fields * 2):
				action = "miner"
			elif abundance > 0.0 and level < 4 and rate(p, "Metals") < PLANET_MINING_LIMIT:
				action = "economy"
				target = "Metals"
			elif farm < 3 and float(p["population"]) > population_capacity(p) * 0.8:
				action = "economy"
				target = "Organics"
			elif (p["yards"] as Array).is_empty():
				action = "yard"
			elif counts["fighter"] < 32:
				action = "fighter"
			else:
				for resource in ["Plastics", "Crystals"]:
					if float(p["abundance"].get(resource, 0.0)) > 0.0 and production_level(p, resource) == 0:
						action = "economy"
						target = resource
						break
		if action.is_empty():
			continue
		var build_level: int = next_shipyard_slot(p) if action == "yard" else 1
		var price: Dictionary = building_cost(p, target) if action == "economy" else _cost(action, build_level)
		if not affordable(p, price):
			# Saving for an unaffordable hull must not leave mature systems
			# waiting indefinitely for food or saturated industrial output.
			for resource in price:
				if float(p["stock"][resource]) >= float(price[resource]) or not ECONOMY_BUILDINGS.has(resource):
					continue
				if resource == "Metals" and abundance <= EPS:
					continue
				if rate(p, resource) - consumption(p, resource) >= 0.5:
					continue
				if int(p.get("buildings", {}).get(resource, 0)) >= 3:
					continue
				if affordable(p, building_cost(p, resource)) and enqueue(state, player, index, "economy", resource):
					break
			continue
		if float(p["population"]) < float(CREW_COSTS.get(action, 0.0)) + 1.0:
			continue
		if enqueue(state, player, index, action, target) and SHIP_KINDS.has(action):
			counts[action] += 1
	_ai_military_orders(state, graph, player, home, owned, fighters)

# Choose strategic objectives on the AI clock, not every movement tick.
# Local hostile fighters determine defensive urgency; friendly systems and
# allied ships never count as invasion targets or threats.
static func _ai_military_orders(state: Dictionary, graph: Dictionary, player: int, home: int, owned: Array[int], fighters: Array) -> void:
	var team: int = int(state["teams"][player])
	var planets: Array = state["planets"]
	var points: Array = graph["points"]
	var pois: Array[int] = military_pois(state, player)
	var center: Vector2 = points[home]
	if not fighters.is_empty():
		center = Vector2.ZERO
		for ship in fighters:
			center += combat_position(state, graph, ship)
		center /= float(fighters.size())
	var threats: Dictionary = {}
	var opportunities: Dictionary = {}
	for ship in state["ships"]:
		var enemy_team: int = int(state["teams"].get(int(ship["owner"]), 0))
		if enemy_team <= 0 or enemy_team == team:
			continue
		var position: Vector2 = combat_position(state, graph, ship)
		if ship.get("kind", "") == "fighter" and not bool(ship.get("retreating", false)):
			for node in owned:
				if position.distance_squared_to(points[node]) <= REPAIR_SAFE_RADIUS * REPAIR_SAFE_RADIUS:
					threats[node] = int(threats.get(node, 0)) + 1
		var node: int = int(ship["at"])
		if not (ship["route"] as Array).is_empty():
			node = int(ship["route"][0])
		if ship.get("kind", "") == "miner" and ship.get("mining_mode", "") in ["outbound", "mining", "return"]:
			node = planets.size() + int(ship["field"])
		if not pois.has(node):
			continue
		if node < planets.size() and int(state["teams"].get(int(planets[node]["owner"]), 0)) == team:
			continue
		var distance: float = center.distance_squared_to(position)
		opportunities[node] = minf(distance, float(opportunities.get(node, INF)))
	var defense: int = home
	var danger: int = 0
	for node in owned:
		var pressure: int = int(threats.get(node, 0))
		if pressure > danger:
			defense = node
			danger = pressure
	# Prefer a persistent hostile objective; only change it when the
	# opportunity disappears. Neutral/field targets require enemy presence.
	var goal: int = -1
	var previous: int = int(state.get("ai_objectives", {}).get(player, -1))
	if pois.has(previous) and (_hostile_system(state, player, previous) or opportunities.has(previous)):
		goal = previous
	if goal < 0:
		var nearest: float = INF
		for node in pois:
			if not opportunities.has(node) and not _hostile_system(state, player, node):
				continue
			var distance: float = float(opportunities.get(node, center.distance_squared_to(points[node])))
			if distance < nearest:
				goal = node
				nearest = distance
	# Keep a three-fighter attack cohort affordable. Small empires attack
	# together in peace and defend together when threatened.
	var defense_weight: int = 100 if goal < 0 else 0
	if goal >= 0:
		if danger > 0:
			defense_weight = 100 if fighters.size() < 7 else 60
		elif fighters.size() >= 4:
			defense_weight = 25
	if not state.has("ai_objectives"):
		state["ai_objectives"] = {}
	state["ai_objectives"][player] = goal
	var defenders: int = ceili(float(fighters.size()) * defense_weight / 100.0)
	if fighters.size() - defenders < AI_WAVE_MIN:
		defenders = fighters.size()
	# Select defenders closest to the threatened POI. Keep already assigned
	# hulls stable where possible; every order uses the same authority path.
	var ranked: Array = fighters.duplicate()
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: float = combat_position(state, graph, a).distance_squared_to(points[defense])
		var db: float = combat_position(state, graph, b).distance_squared_to(points[defense])
		return da < db if not is_equal_approx(da, db) else int(a["id"]) < int(b["id"]))
	for i in range(ranked.size()):
		var craft: Dictionary = ranked[i]
		var target: int = defense if i < defenders else goal
		if target >= 0 and (not bool(craft.get("direct_order", false)) or int(craft.get("operation_target", -1)) != target):
			command_fighters(state, player, [int(craft["id"])], target)

static func _hostile_system(state: Dictionary, player: int, node: int) -> bool:
	if node < 0 or node >= state["planets"].size():
		return false
	var owner: int = int(state["planets"][node]["owner"])
	return owner != 0 and state["teams"].get(owner, 0) != state["teams"].get(player, 0)

# Launch only assembled cohorts; newly built fighters are held in reserve
# until the next wave. Existing human allocation behavior is unaffected.
static func _ai_wave_order(state: Dictionary, graph: Dictionary, player: int, home: int, goal: int, fighters: Array) -> void:
	var waves: Dictionary = state["ai_waves"]
	var wave: Dictionary = waves.get(player, {})
	var members: Array = wave.get("members", [])
	var active: Array[int] = []
	var target: int = int(wave.get("target", -1))
	var all_arrived: bool = true
	var engaged: bool = false
	for ship in fighters:
		var id: int = int(ship["id"])
		if not members.has(id) or bool(ship.get("retreating", false)):
			continue
		active.append(id)
		all_arrived = all_arrived and int(ship["at"]) == target and (ship["route"] as Array).is_empty()
		engaged = engaged or _engaged(ship)
	# Once a wave reaches its objective and combat has ended, or is reduced
	# to a lone unengaged survivor, its remaining hulls regroup.
	if active.is_empty() or (not engaged and (all_arrived or active.size() < 2)):
		active.clear()
		target = -1
	active = _dispatch_cohorts(state, graph, home, target if not active.is_empty() else goal, fighters, active, true)
	var next_target: int = (target if target >= 0 else goal) if not active.is_empty() else -1
	var operation_id: int = int(wave.get("operation_id", 0))
	if operation_id == 0:
		operation_id = int(state.get("next_operation_id", 1))
		state["next_operation_id"] = operation_id + 1
	waves[player] = {"target": next_target, "members": active, "home": home, "operation_id": operation_id}
	# Store strategic objectives separately from temporary movement destinations.
	# Recovery and regroup routes must not split an active wave's formation.
	for ship in fighters:
		if active.has(int(ship["id"])):
			ship["operation_target"] = next_target
		else:
			ship["operation_target"] = home

# Shared authoritative rally and deployment mechanics. AI keeps one active
# wave; human allocations may launch additional assembled cohorts.
static func _dispatch_cohorts(state: Dictionary, graph: Dictionary, home: int, goal: int, fighters: Array, deployed: Array[int], exclusive_wave: bool, minimum: int = AI_WAVE_MIN) -> Array[int]:
	var ready: Array = []
	var paths: Dictionary = {}
	for ship in fighters:
		var member: int = int(ship["id"])
		if bool(ship.get("retreating", false)):
			continue
		if deployed.has(member):
			ship.erase("rally_pending")
			_order_operation_ship(graph, ship, goal, paths)
			continue
		ship["rally_pending"] = goal >= 0 and goal != home
		_order_operation_ship(graph, ship, home, paths)
		if int(ship["at"]) == home and (ship["route"] as Array).is_empty() and combat_position(state, graph, ship).distance_to(graph["points"][home]) <= AI_RALLY_RADIUS and not _engaged(ship):
			ready.append(ship)
	if ready.size() >= minimum and goal >= 0 and goal != home and (not exclusive_wave or deployed.is_empty()):
		if not paths.has(goal):
			paths[goal] = _military_paths(graph, goal)
		if paths[goal]["distance"].has(home):
			for ship in ready:
				ship.erase("rally_pending")
				_order_operation_ship(graph, ship, goal, paths)
				deployed.append(int(ship["id"]))
	return deployed

# Operations own human deployment; quotas choose membership rather than routes.
# Keep exact group identities first, then preserve a disappearing group's ID
# when its members are reassigned together to another objective.
static func _sync_operations(state: Dictionary) -> void:
	var previous: Dictionary = state.get("operations", {})
	var current: Dictionary = {}
	var by_id: Dictionary = {}
	for ship in state["ships"]:
		if ship.get("kind", "") != "fighter":
			continue
		var owner: int = int(ship["owner"])
		var target: int = int(ship.get("operation_target", ship.get("withdrawal_objective", ship.get("dest", -1))))
		if target < 0:
			target = int(ship["at"])
		var role: String = "hold" if bool(ship.get("holding", false)) else "allocation"
		if state.get("ai_players", []).has(owner) and not bool(ship.get("direct_order", false)):
			var wave: Dictionary = state.get("ai_waves", {}).get(owner, {})
			role = "wave" if wave.get("members", []).has(int(ship["id"])) else "reserve"
			# An explicitly assigned objective remains stable while the craft
			# pursues enemies or takes a detour to repair.
			if role == "wave" and int(wave.get("target", -1)) >= 0:
				target = int(wave["target"])
			elif role == "reserve" and int(wave.get("home", -1)) >= 0:
				target = int(wave["home"])
		var key: String = "%d:%s:%d" % [owner, role, target]
		if not current.has(key):
			current[key] = {"id": 0, "owner": owner, "target": target, "role": role, "members": [], "moving": false, "engaged": false, "phase": "assigned", "deployed": []}
		var operation: Dictionary = current[key]
		var ship_id: int = int(ship["id"])
		by_id[ship_id] = ship
		operation["members"].append(ship_id)
		operation["moving"] = bool(operation["moving"]) or (not (ship["route"] as Array).is_empty() and (not bool(ship.get("holding", false)) or bool(ship.get("retreating", false))))
		operation["engaged"] = bool(operation["engaged"]) or _engaged(ship)
	var reused: Dictionary = {}
	var prior_by_id: Dictionary = {}
	for old_operation in previous.values():
		prior_by_id[int(old_operation["id"])] = old_operation
	# Reserve persistent wave identities before matching transient groups.
	for wave_record in state.get("ai_waves", {}).values():
		var persistent_id: int = int(wave_record.get("operation_id", 0))
		if persistent_id > 0:
			reused[persistent_id] = true
	for key in current:
		var operation: Dictionary = current[key]
		operation["members"].sort()
		var old: Dictionary = previous.get(key, {})
		if operation["role"] == "wave":
			var wave_record: Dictionary = state.get("ai_waves", {}).get(int(operation["owner"]), {})
			var persistent_id: int = int(wave_record.get("operation_id", 0))
			if persistent_id > 0:
				operation["id"] = persistent_id
				reused[persistent_id] = true
				continue
		if not old.is_empty():
			operation["id"] = int(old["id"])
			operation["phase"] = old.get("phase", "assigned")
			operation["deployed"] = old.get("deployed", []).duplicate()
			reused[int(old["id"])] = true
	for key in current:
		var operation: Dictionary = current[key]
		if int(operation["id"]) == 0:
			var best_id: int = 0
			var best_overlap: int = 0
			for old_key in previous:
				var old: Dictionary = previous[old_key]
				var candidate: int = int(old["id"])
				if reused.has(candidate) or current.has(old_key) or old["owner"] != operation["owner"] or old["role"] != operation["role"]:
					continue
				var overlap: int = 0
				for member in operation["members"]:
					if old["members"].has(member):
						overlap += 1
				if overlap > best_overlap:
					best_overlap = overlap
					best_id = candidate
			if best_id == 0:
				best_id = int(state.get("next_operation_id", 1))
				state["next_operation_id"] = best_id + 1
			operation["id"] = best_id
			reused[best_id] = true
		var old_slots: Dictionary = prior_by_id.get(int(operation["id"]), {}).get("slots", {})
		var slots: Dictionary = {}
		var claimed: Dictionary = {}
		# Retain surviving assignments; reinforcements fill vacant slots.
		for member in operation["members"]:
			if old_slots.has(member):
				var retained: int = int(old_slots[member])
				slots[member] = retained
				claimed[retained] = true
		var free_slot: int = 0
		var last_slot: int = 0
		for member in operation["members"]:
			if not slots.has(member):
				while claimed.has(free_slot):
					free_slot += 1
				slots[member] = free_slot
				claimed[free_slot] = true
			last_slot = maxi(last_slot, int(slots[member]))
		operation["slots"] = slots
		var deployed: Array = []
		var recovering: Array = []
		var rallying: Array = []
		var in_transit: Array = []
		for member in operation["members"]:
			var craft: Dictionary = by_id[member]
			if bool(craft.get("retreating", false)):
				recovering.append(member)
			elif operation["role"] == "wave" or operation["deployed"].has(member):
				deployed.append(member)
			elif operation["role"] == "reserve" or operation["phase"] in ["rallying", "deployed"]:
				rallying.append(member)
			if not (craft["route"] as Array).is_empty():
				in_transit.append(member)
		operation["deployed"] = deployed
		operation["recovering"] = recovering
		operation["rallying"] = rallying
		operation["in_transit"] = in_transit
		if operation["role"] == "wave":
			operation["phase"] = "deployed"
		elif operation["role"] == "reserve":
			operation["phase"] = "rallying"
		for member in operation["members"]:
			var craft: Dictionary = by_id[member]
			craft["operation_id"] = int(operation["id"])
			craft["formation_slot"] = int(slots[member])
			craft["formation_size"] = (operation["members"] as Array).size()
			craft["formation_extent"] = last_slot
	state["operations"] = current

# Stable disk slots in a lane-relative coordinate frame. Large groups fit
# inside the rally radius; movement always uses the authoritative integrator.
static func _formation_offset(ship: Dictionary, direction: Vector2) -> Vector2:
	if int(ship.get("formation_size", 0)) < 2:
		return Vector2.ZERO
	var slot: int = int(ship.get("formation_slot", 0))
	var extent: int = int(ship.get("formation_extent", 0))
	var spacing: float = minf(FORMATION_SPACING, FORMATION_RADIUS / sqrt(maxf(1.0, float(extent))))
	var local: Vector2 = Vector2.from_angle(float(slot) * 2.399963) * spacing * sqrt(float(slot))
	return local.rotated(direction.angle())

static func _move_formation(graph: Dictionary, ship: Dictionary, dt: float) -> bool:
	if int(ship.get("formation_size", 0)) < 2:
		return _move({"map": graph}, ship, dt)
	var points: Array = graph["points"]
	var route: Array = ship["route"]
	_ensure_position(points, ship)
	var budget: float = SHIP_SPEED * dt
	if route.is_empty():
		# Stationed formations gather around a common point rather than
		# independently orbiting the star. Keep the full disk in rally range.
		var station: Vector2 = points[int(ship["at"])] + Vector2(36.0, 0.0) + _formation_offset(ship, Vector2.RIGHT)
		_navigate(ship, station, budget)
		return true
	while not route.is_empty() and budget > EPS:
		var origin: Vector2 = points[int(ship["at"])]
		var next: Vector2 = points[int(route[0])]
		var direction: Vector2 = (next - origin).normalized()
		var waypoint: Vector2 = next + _formation_offset(ship, direction)
		budget -= _navigate(ship, waypoint, budget)
		if (ship["position"] as Vector2) != waypoint:
			ship["leg"] = _lane_progress(points, ship)
			return false
		ship["at"] = int(route.pop_front())
		ship["leg"] = 0.0
	return route.is_empty()

# Coordinate only ships with the same operation and current directed lane.
# Combat, returning reinforcements and independent recovery remain independent.
# The shared anchor advances from the slowest slot-corrected projection;
# leading ships wait for stragglers instead of reversing or teleporting.
static func _formation_lane_groups(state: Dictionary) -> Dictionary:
	var groups: Dictionary = {}
	for craft in state["ships"]:
		if craft.get("kind", "") != "fighter" or _engaged(craft) or bool(craft.get("retreating", false)) or bool(craft.get("holding", false)) or (craft["route"] as Array).is_empty():
			continue
		var key: String = "%d:%d:%d:%d" % [int(craft.get("operation_id", 0)), int(craft["at"]), int(craft["route"][0]), int(craft.get("dest", -1))]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(craft)
	return groups

static func _coordinate_formations(state: Dictionary, graph: Dictionary, dt: float) -> Dictionary:
	var moved: Dictionary = {}
	var points: Array = graph["points"]
	for group in _formation_lane_groups(state).values():
		if group.size() < 2:
			continue
		var first: Dictionary = group[0]
		var origin: Vector2 = points[int(first["at"])]
		var endpoint: Vector2 = points[int(first["route"][0])]
		var axis: Vector2 = (endpoint - origin).normalized()
		var length: float = origin.distance_to(endpoint)
		if length <= EPS:
			continue
		var progress: float = length
		for craft in group:
			var corrected: Vector2 = craft["position"] - _formation_offset(craft, axis)
			progress = minf(progress, clampf((corrected - origin).dot(axis), 0.0, length))
		var next_progress: float = minf(length, progress + SHIP_SPEED * FORMATION_TRAVEL_FRACTION * dt)
		var arrived: bool = true
		for craft in group:
			var offset: Vector2 = _formation_offset(craft, axis)
			var corrected: Vector2 = craft["position"] - offset
			var own_progress: float = clampf((corrected - origin).dot(axis), 0.0, length)
			var target: Vector2 = origin + axis * maxf(own_progress, next_progress) + offset
			_navigate(craft, target, SHIP_SPEED * dt)
			craft["leg"] = _lane_progress(points, craft)
			arrived = arrived and (craft["position"] as Vector2).distance_to(endpoint + offset) <= EPS
			moved[int(craft["id"])] = true
		if arrived:
			for craft in group:
				craft["at"] = int(craft["route"].pop_front())
				craft["leg"] = 0.0
	return moved

static func _repair_site_safe(state: Dictionary, graph: Dictionary, owner: int, site: int) -> bool:
	if site < 0 or site >= (state["planets"] as Array).size():
		return false
	var planet: Dictionary = state["planets"][site]
	if int(planet["owner"]) != owner or operational_shipyards(planet) == 0:
		return false
	var center: Vector2 = graph["points"][site]
	var team: int = int(state["teams"].get(owner, 0))
	for other in state["ships"]:
		if other.get("kind", "") == "fighter" and int(state["teams"].get(int(other["owner"]), 0)) != team and combat_position(state, graph, other).distance_to(center) <= REPAIR_SAFE_RADIUS:
			return false
	return true

static func _nearest_repair_site(state: Dictionary, graph: Dictionary, ship: Dictionary, paths: Dictionary) -> int:
	var best: int = -1
	var distance: float = INF
	for site in range((state["planets"] as Array).size()):
		if not _repair_site_safe(state, graph, int(ship["owner"]), site):
			continue
		if not paths.has(site):
			paths[site] = _military_paths(graph, site)
		var approach: float = float(_military_approach(graph, ship, paths[site])["distance"])
		if approach < distance:
			best = site
			distance = approach
	return best

# Individual withdrawal is a temporary navigation override. Keep the human
# operation objective distinct from the physical repair destination.
static func _prepare_withdrawals(state: Dictionary, graph: Dictionary) -> void:
	var paths: Dictionary = {}
	for ship in state["ships"]:
		if ship.get("kind", "") != "fighter":
			continue
		var withdrawing: bool = bool(ship.get("retreating", false))
		if not withdrawing and float(ship.get("hp", SHIP_HP)) > WITHDRAW_HP:
			continue
		var site: int = int(ship.get("repair_site", -1))
		if not withdrawing or not _repair_site_safe(state, graph, int(ship["owner"]), site):
			var replacement: int = _nearest_repair_site(state, graph, ship, paths)
			if replacement < 0:
				if withdrawing:
					ship["retreating"] = false
					ship.erase("repair_site")
					ship.erase("withdrawal_objective")
					ship["dest"] = -1
				continue
			site = replacement
		if not withdrawing:
			ship["withdrawal_objective"] = int(ship.get("dest", ship["at"]))
		ship["retreating"] = true
		ship["repair_site"] = site
		ship["combat_target"] = -1
		ship["pursuit_target"] = -1
		ship["pursuit_left"] = 0.0
		ship["laser_until"] = -1.0
		if int(ship.get("dest", -1)) != site:
			if not paths.has(site):
				paths[site] = _military_paths(graph, site)
			_redirect_fighter(graph, ship, site, paths[site])

static func _work_withdrawal(state: Dictionary, graph: Dictionary, ship: Dictionary, dt: float) -> void:
	var site: int = int(ship["repair_site"])
	if not (ship["route"] as Array).is_empty():
		_move({"map": graph}, ship, dt)
		return
	if int(ship["at"]) != site:
		return
	var dock: Vector2 = graph["points"][site]
	var distance: float = _navigate(ship, dock, SHIP_SPEED * dt)
	if (ship["position"] as Vector2) != dock or not _repair_site_safe(state, graph, int(ship["owner"]), site):
		return
	var repair_time: float = maxf(0.0, dt - distance / SHIP_SPEED)
	ship["hp"] = minf(SHIP_HP, float(ship.get("hp", SHIP_HP)) + REPAIR_PER_YEAR * repair_time)
	if float(ship["hp"]) >= SHIP_HP - EPS:
		ship["hp"] = SHIP_HP
		ship["retreating"] = false
		ship.erase("repair_site")
		ship.erase("withdrawal_objective")
		# Normal dispatch resumes the latest allocation or AI reserve order.
		ship["dest"] = -1
		if bool(ship.get("holding", false)):
			ship["operation_target"] = site

static func _order_operation_ship(graph: Dictionary, ship: Dictionary, goal: int, paths: Dictionary) -> void:
	if int(ship.get("dest", -1)) == goal:
		return
	if not paths.has(goal):
		paths[goal] = _military_paths(graph, goal)
	_redirect_fighter(graph, ship, goal, paths[goal])

# A hostile-owned system is an attack objective. Other POIs retain immediate
# allocation orders, including home defense and neutral/field assignments.
# Reuse the AI minimum and physical rally radius as provisional defaults.
static func _dispatch_operations(state: Dictionary, graph: Dictionary) -> void:
	var by_id: Dictionary = {}
	for ship in state["ships"]:
		if ship.get("kind", "") == "fighter":
			by_id[int(ship["id"])] = ship
	var paths: Dictionary = {}
	for operation in state["operations"].values():
		if operation["role"] != "allocation":
			continue
		var owner: int = int(operation["owner"])
		var target: int = int(operation["target"])
		var home: int = military_home(state, owner)
		var attack: bool = false
		if target >= 0 and target < (state["planets"] as Array).size():
			var defender: int = int(state["planets"][target]["owner"])
			attack = defender != 0 and state["teams"].get(defender, 0) != state["teams"].get(owner, 0)
		# Explicit RTS orders depart immediately, without requiring a cohort.
		for member in operation["members"]:
			if bool(by_id[member].get("direct_order", false)):
				attack = false
				break
		if not attack or home < 0:
			operation["phase"] = "assigned"
			operation["deployed"] = []
			for member in operation["members"]:
				by_id[member].erase("rally_pending")
				if not bool(by_id[member].get("retreating", false)):
					_order_operation_ship(graph, by_id[member], target, paths)
			continue
		var deployed: Array[int] = []
		var fighters: Array = []
		for member in operation["members"]:
			fighters.append(by_id[member])
			if operation["deployed"].has(member) and not bool(by_id[member].get("retreating", false)):
				deployed.append(member)
		if deployed.size() == 1 and not _engaged(by_id[deployed[0]]):
			deployed.clear()
		deployed = _dispatch_cohorts(state, graph, home, target, fighters, deployed, false)
		operation["deployed"] = deployed
		operation["phase"] = "rallying" if deployed.is_empty() else "deployed"

# Local combat flight temporarily overrides lane navigation, without changing
# its queued waypoints or teleporting back on disengagement. All maneuvers
# use positions captured before any hull moves this tick.
static func _maneuver_fighter(ship: Dictionary, opponent: Vector2, dt: float) -> void:
	var position: Vector2 = ship["position"]
	var radial: Vector2 = position - opponent
	var radius: float = radial.length()
	var direction: Vector2 = radial / radius if radius > EPS else Vector2.from_angle(float(int(ship["id"]) % 64) * 2.399963)
	var budget: float = SHIP_SPEED * dt
	var preferred_radius: float = LASER_RANGE * 0.60
	# Move tangentially while gradually correcting distance. An angular
	# waypoint (rather than a straight tangent) keeps the path curved.
	var next_radius: float = move_toward(radius, preferred_radius, budget * 0.45)
	var angle: float = minf(0.6, budget * 0.85 / maxf(preferred_radius, radius))
	var waypoint: Vector2 = opponent + direction.rotated(angle) * next_radius
	_navigate(ship, waypoint, budget)

# Close on escaping prey instead of spending the travel budget tangentially.
# Keep a firing standoff; beyond it, use the full available speed.
static func _pursue_fighter(ship: Dictionary, opponent: Vector2, dt: float) -> void:
	var position: Vector2 = ship["position"]
	var separation: Vector2 = opponent - position
	var travel: float = maxf(0.0, separation.length() - LASER_RANGE * 0.60)
	var duration: float = minf(dt, float(ship.get("pursuit_left", 0.0)))
	_navigate(ship, position + separation.normalized() * travel, SHIP_SPEED * duration)
	ship["pursuit_left"] = maxf(0.0, float(ship["pursuit_left"]) - duration)

# Idle ships remain in their current sector. Up to three same-owner,
# same-kind hulls share a moving local anchor and tangent-relative V slots.
# Routing, docking, mining, combat and withdrawal always take precedence.
static func _is_idle_ship(ship: Dictionary) -> bool:
	var fighter: bool = ship.get("kind", "") == "fighter"
	return (ship["route"] as Array).is_empty() and ship.get("mining_mode", "idle") == "idle" and (fighter or int(ship.get("dest", -1)) < 0) and int(ship.get("source", -1)) < 0 and not _engaged(ship) and not bool(ship.get("retreating", false)) and not bool(ship.get("holding", false))

static func _idle_formation_targets(state: Dictionary, graph: Dictionary) -> Dictionary:
	var groups: Dictionary = {}
	var stationary_teams: Dictionary = {}
	for ship in state["ships"]:
		if ship.get("kind", "") == "fighter" and (ship["route"] as Array).is_empty() and not bool(ship.get("retreating", false)):
			var node: int = int(ship["at"])
			if not stationary_teams.has(node):
				stationary_teams[node] = {}
			stationary_teams[node][int(state["teams"].get(int(ship["owner"]), 0))] = true
		if not _is_idle_ship(ship):
			continue
		var key: String = "%d:%s:%d:%d" % [int(ship["owner"]), str(ship.get("kind", "ship")), int(ship["at"]), int(ship.get("operation_id", 0))]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(ship)
	var targets: Dictionary = {}
	for group in groups.values():
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["id"]) < int(b["id"]))
		for first in range(0, group.size(), 3):
			var leader: Dictionary = group[first]
			var node: int = int(leader["at"])
			var center: Vector2 = graph["points"][node]
			var seed: int = int(leader["id"]) % 97
			var radius: float = float(graph["sector_radii"][node])
			var compact: bool = false
			if leader.get("kind", "") == "fighter":
				var team: int = int(state["teams"].get(int(leader["owner"]), 0))
				var owner: int = int(state["planets"][node]["owner"]) if node < (state["planets"] as Array).size() else 0
				var hostile_system: bool = owner != 0 and int(state["teams"].get(owner, 0)) != team
				compact = bool(leader.get("rally_pending", false)) or hostile_system or (stationary_teams.get(node, {}) as Dictionary).size() > 1
			var phase: float = float(state["elapsed"]) * SHIP_SPEED / maxf(radius, 100.0)
			var angle: float = float(seed) * 2.399963 + (float(state["elapsed"]) * 0.32 if compact else phase * 0.55)
			var radial: Vector2 = Vector2.from_angle(angle)
			var direction: Vector2 = radial.orthogonal()
			var extent: float = sector_limit(graph, node, radial)
			var range_fraction: float = 0.52 + 0.43 * sin(phase * 0.41 + float(seed) * 1.713)
			var distance: float = maxf(0.0, extent - 30.0) * range_fraction
			if compact:
				distance = minf(distance, 58.0 + 12.0 * float(seed % 3))
			var anchor: Vector2 = radial * distance
			for i in range(first, mini(first + 3, group.size())):
				var offset: int = i - first
				var formation: Vector2 = Vector2.ZERO
				if offset > 0:
					formation = -direction * 22.0 + radial * (16.0 if offset == 1 else -16.0)
				var relative: Vector2 = anchor + formation
				var bound: float = sector_limit(graph, node, relative.normalized())
				if compact:
					bound = minf(bound, AI_RALLY_RADIUS - 10.0)
				targets[int(group[i]["id"])] = center + relative.limit_length(maxf(0.0, bound - 1.0))
	return targets

# Directly ordered fighters occupying a hostile system can transfer it.
# Surviving shipyards and nearby hostile fighters prevent occupation.
const CAPTURE_YEARS: float = 20.0

# Find a safe escape route after a civilian's planned route becomes
# hostile. Consider both ends of its existing leg without moving the hull.
# Only the initial hostile waypoint may be used to leave hostile territory.
static func _evacuate_civilian(state: Dictionary, ship: Dictionary, teams: Array[int]) -> bool:
	var team: int = int(state["teams"].get(int(ship["owner"]), 0))
	var miner: bool = ship.get("kind", "") == "miner"
	var points: Array = state["map"]["points"]
	_ensure_position(points, ship)
	var here: int = int(ship["at"])
	var origins: Array[int] = [here]
	if not (ship["route"] as Array).is_empty():
		origins.append(int(ship["route"][0]))
	var best: float = INF
	var chosen: Array[int] = []
	var destination: int = -1
	for origin in origins:
		var allowed: Array[int] = teams.duplicate()
		allowed[origin] = team
		for node in range(teams.size()):
			if teams[node] != team or (miner and int(state["planets"][node]["owner"]) != int(ship["owner"])):
				continue
			var path: Array[int] = _mining_path(state, allowed, team, origin, node, {}) if miner else MAP.path(state["map"], allowed, team, origin, node)
			if path.is_empty():
				continue
			var distance: float = (ship["position"] as Vector2).distance_to(points[origin]) + MAP.route_length(state["map"], path)
			if distance < best:
				best = distance
				chosen = path
				destination = node
	ship["route"] = chosen
	ship["leg"] = _lane_progress(points, ship)
	ship["source"] = -1
	ship["dest"] = destination
	if miner:
		ship["mining_mode"] = "delivery"
		ship["field"] = -1
		if destination < 0:
			ship["dest"] = here
	return destination >= 0

static func _reroute_after_capture(state: Dictionary, index: int) -> void:
	var teams: Array[int] = planet_teams(state)
	for ship in state["ships"]:
		var kind: String = str(ship.get("kind", ""))
		if kind not in ["ship", "miner"]:
			continue
		var team: int = int(state["teams"].get(int(ship["owner"]), 0))
		if teams[index] == team:
			continue
		if int(ship["at"]) != index and int(ship.get("source", -1)) != index and int(ship.get("dest", -1)) != index and not (ship["route"] as Array).has(index):
			continue
		# Off-lane miners must first fly back to their former approach
		# waypoint, then escape rather than unload into hostile stocks.
		if kind == "miner" and ship.get("mining_mode", "") in ["outbound", "mining", "return"]:
			ship["mining_mode"] = "return"
			continue
		_evacuate_civilian(state, ship, teams)

static func _capture_system(state: Dictionary, index: int, player: int) -> void:
	var planet: Dictionary = state["planets"][index]
	var former: int = int(planet["owner"])
	# Refund surviving unfinished work to the local colony before transfer;
	# completed infrastructure and population stay with the system.
	for job in planet["queue"].duplicate():
		cancel(state, former, index, int(job["id"]))
	planet["continuous"].clear()
	planet["maintain"] = {}
	planet["repeat_cycle"] = {}
	planet["pds"].clear()
	planet["home"] = false
	planet["owner"] = player
	planet["capture"] = {}
	_reroute_after_capture(state, index)

static func _step_conquest(state: Dictionary, graph: Dictionary, dt: float) -> void:
	var planets: Array = state["planets"]
	var points: Array = graph["points"]
	var occupiers: Dictionary = {}
	var fighters: Array = []
	for ship in state["ships"]:
		if ship.get("kind", "") != "fighter" or bool(ship.get("retreating", false)):
			continue
		fighters.append(ship)
		var player: int = int(ship["owner"])
		var node: int = int(ship["at"])
		if node < 0 or node >= planets.size() or not (ship["route"] as Array).is_empty() or int(ship.get("operation_target", ship.get("dest", -1))) != node:
			continue
		if combat_position(state, graph, ship).distance_to(points[node]) > AI_RALLY_RADIUS:
			continue
		var owner: int = int(planets[node]["owner"])
		if owner == 0 or state["teams"].get(owner, 0) == state["teams"].get(player, 0):
			continue
		if not occupiers.has(node):
			occupiers[node] = {}
		occupiers[node][player] = int(occupiers[node].get(player, 0)) + 1
	for node in range(planets.size()):
		var planet: Dictionary = planets[node]
		if not occupiers.has(node) or not (planet["yards"] as Array).is_empty() or not planet.get("pds", {}).is_empty():
			if planet.has("capture"):
				planet.erase("capture")
			continue
		var candidates: Dictionary = occupiers[node]
		var winner: int = -1
		for player in candidates:
			if winner < 0 or int(candidates[player]) > int(candidates[winner]) or (int(candidates[player]) == int(candidates[winner]) and int(player) < winner):
				winner = int(player)
		var team: int = int(state["teams"].get(winner, 0))
		var contested: bool = false
		for ship in fighters:
			var position: Vector2 = combat_position(state, graph, ship)
			var local_patrol: bool = int(ship["at"]) == node and (ship["route"] as Array).is_empty() and sector_contains(graph, node, position)
			if int(state["teams"].get(int(ship["owner"]), 0)) != team and (position.distance_to(points[node]) <= LASER_RANGE or local_patrol):
				contested = true
				break
		if contested:
			planet.erase("capture")
			continue
		var progress: Dictionary = planet.get("capture", {})
		var held: float = float(progress.get("held", 0.0)) if int(progress.get("player", -1)) == winner else 0.0
		held += dt
		if held + EPS >= CAPTURE_YEARS:
			_capture_system(state, node, winner)
		else:
			planet["capture"] = {"player": winner, "held": held}

# Match-only outcome evaluation, invoked by the authoritative session.
# A colony ship permits recovery while a neutral system remains. Eliminate
# only empires with neither a colony nor a viable colonization opportunity.
# Teams win together; sandbox matches with one starting team never auto-end.
static func update_match_outcome(state: Dictionary) -> bool:
	if not state.get("match_result", {}).is_empty():
		return false
	var starting_teams: Dictionary = {}
	for team in state["teams"].values():
		starting_teams[team] = true
	var viable: Dictionary = {}
	var neutral_exists: bool = false
	for planet in state["planets"]:
		var owner: int = int(planet["owner"])
		if owner == 0:
			neutral_exists = true
		else:
			viable[owner] = true
	if neutral_exists:
		for ship in state["ships"]:
			if ship.get("kind", "") == "colony_ship":
				viable[int(ship["owner"])] = true
	var eliminated: Array = state.get("eliminated", [])
	var changed: bool = false
	for player in state["teams"]:
		if viable.has(player) or eliminated.has(player):
			continue
		eliminated.append(player)
		changed = true
		state["ai_waves"].erase(player)
		state["ai_players"].erase(player)
	state["eliminated"] = eliminated
	if changed:
		# Surviving non-colony hulls of defeated empires stand down.
		for ship in state["ships"].duplicate():
			if eliminated.has(int(ship["owner"])):
				state["ships"].erase(ship)
		_sync_operations(state)
	if starting_teams.size() < 2:
		return changed
	var remaining_teams: Dictionary = {}
	for player in viable:
		if not eliminated.has(player) and state["teams"].has(player):
			remaining_teams[state["teams"][player]] = true
	if remaining_teams.size() <= 1:
		var winner: int = int(remaining_teams.keys()[0]) if remaining_teams.size() == 1 else 0
		state["match_result"] = {"team": winner, "reason": "conquest", "elapsed": float(state["elapsed"])}
		state["time_speed"] = 0
		changed = true
	return changed

static func step(state: Dictionary, dt: float) -> void:
	state["elapsed"] = float(state["elapsed"]) + dt
	for i in range((state["planets"] as Array).size()):
		_work_planet(state, i, dt)
	var teams: Array[int] = planet_teams(state)
	var cache: Dictionary = {}
	var budgets: Array = []
	for field in state["map"].get("fields", []):
		budgets.append({"Metals": field_limit(field, "Metals") * dt, "Crystals": field_limit(field, "Crystals") * dt, ANTIMATTER: field_limit(field, ANTIMATTER) * dt})
	var combat_graph: Dictionary = military_graph(state)
	if float(state["elapsed"]) >= float(state.get("next_ai", 0.0)) and not state.get("ai_players", []).is_empty():
		state["next_ai"] = float(state["elapsed"]) + AI_INTERVAL
		for player in state["ai_players"]:
			_ai_turn(state, combat_graph, int(player))
	for craft in state["ships"]:
		_ensure_position(combat_graph["points"] if craft.get("kind", "") == "fighter" else state["map"]["points"], craft)
	_prepare_withdrawals(state, combat_graph)
	_combat(state, combat_graph, dt)
	_prepare_withdrawals(state, combat_graph)
	var fleets: Dictionary = {}
	for craft in state["ships"]:
		if craft.get("kind", "") == "fighter":
			var player: int = int(craft["owner"])
			if not fleets.has(player):
				fleets[player] = []
			fleets[player].append(craft)
	for player in fleets:
		# Legacy allocation fixtures still exercise routing; live games use
		# individual commands. Unordered reinforcements stay at their origin.
		if state.get("military", {}).has(player):
			_allocate_fighters(state, combat_graph, int(player), fleets[player], true)
		else:
			for fighter in fleets[player]:
				if not fighter.has("operation_target"):
					fighter["operation_target"] = int(fighter.get("at", 0))
	_sync_operations(state)
	_dispatch_operations(state, combat_graph)
	var combat_positions: Dictionary = {}
	for craft in state["ships"]:
		combat_positions[int(craft["id"])] = craft["position"]
	var idle_targets: Dictionary = _idle_formation_targets(state, combat_graph)
	var coordinated: Dictionary = _coordinate_formations(state, combat_graph, dt)
	for ship in (state["ships"] as Array).duplicate():
		var initial_position: Vector2 = ship["position"]
		if ship.get("kind", "ship") == "colony_ship":
			if _work_colony(state, ship, dt):
				state["ships"].erase(ship)
				continue
		elif ship.get("kind", "ship") == "ship":
			_work_ship(state, ship, teams, cache, dt)
		elif ship.get("kind", "ship") == "miner":
			_work_miner(state, ship, teams, cache, budgets, dt)
		elif ship.get("kind", "") == "fighter":
			var target_id: int = int(ship.get("combat_target", -1))
			var pursuit_id: int = int(ship.get("pursuit_target", -1))
			if bool(ship.get("retreating", false)):
				_work_withdrawal(state, combat_graph, ship, dt)
			elif bool(ship.get("holding", false)):
				ship["navigation_target"] = ship["position"]
			elif coordinated.has(int(ship["id"])):
				pass # Already moved as a group this tick.
			elif combat_positions.has(pursuit_id):
				_pursue_fighter(ship, combat_positions[pursuit_id], dt)
				ship["leg"] = _lane_progress(combat_graph["points"], ship)
			elif combat_positions.has(target_id):
				ship["pursuit_target"] = -1
				ship["pursuit_left"] = 0.0
				_maneuver_fighter(ship, combat_positions[target_id], dt)
				ship["leg"] = _lane_progress(combat_graph["points"], ship)
			else:
				ship["combat_target"] = -1
				ship["pursuit_target"] = -1
				ship["pursuit_left"] = 0.0
				if not (ship["route"] as Array).is_empty():
					_move_formation(combat_graph, ship, dt)
		var ship_id: int = int(ship["id"])
		# Only use the idle budget if the ship started and finished its
		# work idle and did not already move this tick.
		if idle_targets.has(ship_id) and _is_idle_ship(ship) and not coordinated.has(ship_id) and ship["position"] == initial_position:
			_navigate(ship, idle_targets[ship_id], SHIP_SPEED * dt)
	_step_conquest(state, combat_graph, dt)
	_sync_operations(state)
	update_exploration(state)
