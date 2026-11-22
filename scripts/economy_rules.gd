extends RefCounted
## Development-only balance configuration. No advanced recipes have been defined.
static var cached_civilian_routes: Dictionary = {}
static var cached_route_topology: Dictionary = {}
static var cached_military_graph: Dictionary = {}
static var cached_military_map: Dictionary = {}
static var cached_military_source: Dictionary = {}
# Ephemeral authoritative snapshot, active only during a movement substep.
static var avoidance_cells: Dictionary = {}
const AVOIDANCE_LOOKAHEAD: float = 96.0
const AVOIDANCE_CELL: float = 128.0
const AVOIDANCE_BUCKET_LIMIT: int = 24
const MAP = preload("res://scripts/planet_map.gd")
const SYSTEM_GEOMETRY = preload("res://scripts/system_geometry.gd")
const SECTOR_GEOMETRY = preload("res://scripts/sector_geometry.gd")
const RESOURCES = ["Metals", "Organics", "Crystals"]
const EXTRACTED = ["Metals", "Crystals"]
const ACTIVE_PRODUCTION = RESOURCES
const STARTING_STOCK = {"Metals": 1650.0, "Organics": 300.0, "Crystals": 0.0}
const STARTING_GC: float = 5000.0
const RESIDENT_TAX_RATE: float = 0.005
const ROGUE_GRACE_YEARS: float = 60.0
const ROGUE_CHECK_YEARS: float = 10.0
const ROGUE_CHANCE: float = 0.005
# Annual operating wages for completed mobile hulls; structures are exempt.
const SHIP_UPKEEP_GC = {"scout": 1.0, "miner": 3.0, "fighter": 5.0, "ship": 8.0, "colony_ship": 10.0, "science_ship": 10.0, "cruiser": 15.0, "destroyer": 35.0}
# Fixed labor fee, independent of future fluctuating market prices.
const CONSTRUCTION_CREDIT_FRACTION: float = 0.5
const CONSTRUCTION_REFERENCE_VALUES = {"Metals": 2.0, "Organics": 1.0, "Crystals": 8.0}
const WARP_GATE_CREDIT_COST: float = 1000.0
const BUILDING_BONUS: float = 0.25
const UPGRADE_COST_FACTOR: float = 3.0
# Provisional repeatable local production infrastructure; no self-input recipes.
const ECONOMY_BUILDINGS = {
	"Metals": {"name": "Refinery", "population": 30000, "cost": {"Organics": 90.0}},
	"Organics": {"name": "Farms", "population": 30000, "cost": {"Metals": 240.0}},
	"Crystals": {"name": "Incubator", "population": 30000, "cost": {"Metals": 240.0}}
}
const CONSTRUCTION_RESERVE: float = 500.0
const CONSTRUCTION_PRODUCTION_SHARE: float = 0.1
# Population is expressed in people (fractional values retained in simulation).
const HOME_POPULATION: float = 10000.0
const ORBITAL_HOUSING_POPULATION: float = 5000.0
const ECO_HOUSING_ORGANICS: float = 0.2
const ORBITAL_HOUSING_COST: Dictionary = {"Metals": 180.0}
const COLONY_POPULATION: float = 80000.0
const POPULATION_DOUBLING_YEARS: float = 60.0
# Fixed full-growth food reserve, independent of warehouse size and trade policy.
const POPULATION_FOOD_RESERVE: float = 200.0
const PRODUCTION_PER_LEVEL: float = 4.0
const CRYSTALS_PER_LEVEL: float = 0.06
const STATION_CRYSTALS_PER_YEAR: float = 1.25
const CRYSTAL_COST_MULTIPLIER: float = 4.0
const ORGANICS_PER_LEVEL: float = 4.0
# Food production and demand both halve; population capacity stays unchanged.
const POPULATION_PER_ORGANICS_RATE: float = 25000.0
# Critically damped demographic response (seconds = years).
const POPULATION_RESPONSE: float = 0.065
const FARM_VARIATION: float = 0.05
const FARM_CYCLE_SECONDS: float = 100.0
const START_YEAR: int = 2850
const SYSTEM_WORLD_RADIUS: float = 600.0
const CARGO_CAPACITY: float = 100.0
const FREIGHTER_BAY_COUNT: int = 10
const FREIGHTER_BAY_CAPACITY: float = CARGO_CAPACITY / FREIGHTER_BAY_COUNT
const MINED_RESOURCES = ["Metals", "Crystals"]
const ANTIMATTER = MAP.ANTIMATTER
const FIELD_RESOURCES = ["Metals", "Crystals", ANTIMATTER]
# Provisional per-resource ceilings, independent of unlimited upgrade levels.
const FIELD_MINING_LIMIT: float = 200.0
const MINER_CAPACITY: float = 10.0
const FIGHTER_CAPACITY: float = 0.0
const COLONY_CAPACITY: float = 100.0
const COLONY_FARM_RATE: float = 5.0
const TRACTOR_RANGE: float = 90.0
const TRACTOR_RATE: float = 12.0
const FREIGHTER_TRACTOR_RATE: float = TRACTOR_RATE * 0.25
const RESOURCE_HANDOFF_RANGE: float = TRACTOR_RANGE * 2.0
const RESOURCE_STAGE_SEARCH_YEARS: float = 2.0
const RESOURCE_PARTIAL_WAIT_YEARS: float = 8.0
const SALVAGE_CHANCE: float = 0.75
const SALVAGE_FRACTION: float = 0.20
const SALVAGE_MIN_LIFETIME: float = 90.0
const SALVAGE_MAX_LIFETIME: float = 180.0
const SALVAGE_APPROACH_RANGE: float = TRACTOR_RANGE * 2.0
const AUTO_SALVAGE_RANGE: float = 4000.0
const AUTO_SALVAGE_HOPS: int = 2
# The pair of mining lasers deals one combined volley per year. One point
# of damage to a resource chunk removes one ton, subject to field limits.
const MINER_LASER_DAMAGE: float = 2.0
const MINER_ASTEROID_MULTIPLIER: float = 1.5
const MINER_REPAIR_RATE: float = 10.0
const MINER_REPAIR_SEARCH: float = LASER_RANGE * 2.0
const MINER_RATE: float = MINER_LASER_DAMAGE * MINER_ASTEROID_MULTIPLIER
const SHIP_SPEED: float = MAP.TRAVEL_SPEED # Map-scale reference speed.
const MINER_SPEED: float = SHIP_SPEED * 0.8
const FREIGHTER_SPEED: float = SHIP_SPEED * 1.1
const FIGHTER_SPEED: float = FREIGHTER_SPEED * 1.2
const AUTOCAST_COOLDOWN_YEARS: float = 30.0
const MINING_SALVAGE_COOLDOWN_YEARS: float = 5.0
const MOVE_ARRIVAL_WAIT_YEARS: float = AUTOCAST_COOLDOWN_YEARS
const AUTOCAST_MODES = ["explore", "wander", "mine", "salvage", "repair", "trade", "farm", "collect", "retreat"]
const SHIP_SIZE: int = 1 # Legacy small-class reference.
const SHIP_SIZES = {"fighter": 1, "miner": 1, "ship": 2, "colony_ship": 2, "science_ship": 3, "scout": 1, "cruiser": 2, "destroyer": 3}
const STATION_STORAGE_BAYS: int = 3
const TRANSFER_EVENT_LIMIT: int = 192
const TRANSFER_EVENT_YEARS: float = 6.0
const MAX_SHIPYARDS: int = 3
const EPS: float = 0.00001
const DEFAULT_FOG_OF_WAR: bool = false
# Starting storage capacity per resource; warehouse upgrades increase it.
const TRADE_REFERENCE: float = 2000.0
const DEFAULT_IMPORT_PERCENT: float = 50.0
const DEFAULT_EXPORT_PERCENT: float = 80.0
const WAREHOUSE_CAPACITIES = [2000.0, 5000.0, 12000.0, 30000.0]
# Each tier is 3x the previous one, with each price fitting in the
# immediately preceding warehouse capacity.
const WAREHOUSE_COSTS = [
	{"Metals": 500.0},
	{"Metals": 1500.0},
	{"Metals": 4500.0}
]
const WAREHOUSE_POPULATIONS = [10000, 50000, 150000]
const CIVILIAN_CONSUMPTION = {"Metals": 0.1}
const SHIP_KINDS = ["ship", "colony_ship", "fighter", "miner", "science_ship", "scout", "cruiser", "destroyer"]
const SCIENCE_CAPACITY: float = 1.0
const SCIENCE_COLLECTION_YEARS: float = 30.0
const SHIPYARD_QUEUE_LIMIT = 8
const MAX_SHIPYARD_LEVEL = 3
const CREW_COSTS = {"ship": 4000.0, "colony_ship": COLONY_POPULATION, "fighter": 1000.0, "miner": 1500.0, "science_ship": 4000.0, "scout": 100.0, "cruiser": 3000.0, "destroyer": 8000.0}
const MINING_STAY: float = 5.0
const SHIP_HP: float = 200.0
const YARD_HP: float = 1500.0
const FREIGHTER_HP: float = SHIP_HP * 2.0
const PASSIVE_REGEN: float = 1.0 / 3.0
const STATION_HP: float = 5000.0
const REINFORCED_STATION_HP: float = STATION_HP + 1500.0
const STATION_LASER_COUNT: int = 2
const STATION_UPGRADES = ["reinforced_plating", "laser_matrix", "dyson_sphere"]
const STATION_SALVAGE_FRACTION: float = 0.20
const LASER_DAMAGE: float = 18.0
const PDS_DAMAGE: float = LASER_DAMAGE * 2.0
const PDS_HP: float = 300.0
const LASER_RANGE: float = 180.0
const PDS_RANGE: float = LASER_RANGE * 2.0
const PURSUIT_YEARS: float = 3.0
const AI_INTERVAL: float = 4.0
const AI_WAVE_MIN: int = 3
const AI_RALLY_RADIUS: float = 150.0
const FORMATION_SPACING: float = 28.0
const SHIP_SEPARATION_RADIUS: float = 45.0
const SHIP_CLEARANCE: float = 32.0
# Service within the station footprint; contact correction need not permit exact center arrival.
const STATION_DOCK_RANGE: float = 128.0
const SHIP_CLEARANCE_PASSES: int = 1
const FOLLOW_DISTANCE: float = SHIP_SEPARATION_RADIUS * 2.0
const RALLY_ARRIVAL_RADIUS: float = SHIP_SEPARATION_RADIUS * 2.0
const SHIP_SEPARATION_STRENGTH: float = 0.15
const FORMATION_RADIUS: float = 105.0
const FORMATION_TRAVEL_FRACTION: float = 0.8
const WITHDRAW_HP: float = 92.0
const REPAIR_PER_YEAR: float = 20.0
const STATION_REPAIR_RANGE: float = LASER_RANGE
const REPAIR_SAFE_RADIUS: float = LASER_RANGE * 2.0
static func system_bodies(system: Dictionary, seed_value: int, index: int) -> Array:
	return SYSTEM_GEOMETRY.system_bodies(system, seed_value, index, EXTRACTED)

static func body_position(body: Dictionary, radius: float, elapsed: float) -> Vector2:
	return SYSTEM_GEOMETRY.body_position(body, radius, elapsed)

static func system_world_radius(state: Dictionary, index: int) -> float:
	return SYSTEM_GEOMETRY.system_world_radius(state, index, SYSTEM_WORLD_RADIUS)

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
			thresholds[resource] = {"min": DEFAULT_IMPORT_PERCENT, "max": DEFAULT_EXPORT_PERCENT}
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
			yards.append({"level": 1, "job": -1, "hp": YARD_HP, "station_slot": 1})
		var richness: float = 0.0
		for resource in EXTRACTED:
			richness += float(abundance[resource])
		richness += float(bonuses["Organics"]) - 1.0
		# Environment is generated separately, not inferred from size or deposits.
		var advanced: float = rng.randf_range(1.1, 1.6) if rng.randf() < 0.3 else 1.0
		planets.append({"size_factor": lerpf(0.86, 1.18, clampf(richness / 6.8, 0.0, 1.0)), "advanced_bonus": advanced, "owner": owner, "home": home, "population": HOME_POPULATION + ORBITAL_HOUSING_POPULATION if home else 0.0, "eco_population": ORBITAL_HOUSING_POPULATION if home else 0.0, "population_velocity": 0.0, "farm_phase": float(i) * 2.399963, "farm_factor": 1.0, "stock": stock, "levels": levels,
			"abundance": abundance, "bonuses": bonuses, "thresholds": thresholds,
			"station": {"hp": STATION_HP, "weapons": [_new_pds(), _new_pds()]} if home else {}, "yards": yards, "queue": [], "continuous": {}, "buildings": {}, "warehouse_level": 0, "pds": {0: _new_pds()} if home else {}})
	var ai_players: Array[int] = []
	for id in ordered:
		if bool(players[id].get("ai", false)):
			ai_players.append(id)
	var state: Dictionary = {"ai_players": ai_players, "ai_waves": {}, "operations": {}, "next_operation_id": 1, "next_ai": 0.0, "map": map_data, "planets": planets, "ships": [], "ship_destructions": [], "next_destruction_id": 1, "salvage": {}, "next_salvage_id": 1, "teams": teams, "next_id": 1, "elapsed": 0.0, "fog_of_war": DEFAULT_FOG_OF_WAR, "explored": {}, "mining_policies": {}, "military": {}}
	for index in range(planets.size()):
		var system: Dictionary = planets[index]
		system["planetless"] = not bool(system["home"]) and map_data.get("planetless", []).has(index)
		system["orbital_housing"] = 0
		if not has_planets(system):
			for resource in EXTRACTED:
				system["abundance"][resource] = 0.0
			system["bonuses"]["Organics"] = 1.0
			system["bonuses"]["Crystals"] = 1.0
		planets[index]["planet_count"] = system_bodies(planets[index], int(map_data["seed"]), index).size()
	if starting_fleet:
		for index in range(ordered.size()):
			var slot: int = 0
			for kind in ["miner", "miner", "miner", "fighter", "fighter", "ship"]:
				var id: int = int(state["next_id"])
				state["next_id"] = id + 1
				var offset: Vector2 = Vector2.from_angle(float(index) * 2.399963 + float(slot) * TAU / 6.0) * (SHIP_CLEARANCE * 1.8)
				_finish(state, index, planets[index], {"id": id, "kind": kind, "population_allocated": CREW_COSTS[kind], "spawn_offset": offset, "starting_fleet": true})
				slot += 1
	var credits: Dictionary = {}
	for id in ordered:
		credits[id] = STARTING_GC
	state["galactic_credits"] = credits
	update_exploration(state)
	return state

# Client presentation vision is separate from strategic route discovery.
const VISION_CELL: float = 80.0
const STATION_SIGHT: float = 1500.0
const YARD_SIGHT: float = 1000.0
const PDS_SIGHT: float = 1000.0

static func sight_radius(kind: String) -> float:
	match kind:
		"scout": return 2700.0
		"cruiser", "destroyer": return 1500.0
		"fighter": return 1000.0
		"warp_gate": return 1200.0
		_: return 850.0

static func vision_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / VISION_CELL), floori(point.y / VISION_CELL))

static func _stamp_vision(cells: Dictionary, point: Vector2, radius: float) -> void:
	var center: Vector2i = vision_cell(point)
	var reach: int = ceili(radius / VISION_CELL)
	for y in range(center.y - reach, center.y + reach + 1):
		for x in range(center.x - reach, center.x + reach + 1):
			var cell := Vector2i(x, y)
			if cells.has(cell):
				continue
			if ((Vector2(cell) + Vector2.ONE * 0.5) * VISION_CELL).distance_squared_to(point) <= radius * radius:
				cells[cell] = true

# In bilateral mode, group IDs are empire IDs. Only direct consenting
# allies contribute live sensor coverage, never an ally's ally.
static func _shares_group_vision(state: Dictionary, viewer: int, source: int) -> bool:
	if state.has("diplomacy"):
		return diplomacy_allows(state, viewer, source, "vision")
	return viewer > 0 and viewer == source

static func team_vision(state: Dictionary, team: int) -> Dictionary:
	var cells: Dictionary = {}
	if team <= 0:
		return cells
	var sources: Dictionary = {}
	for ship in state.get("ships", []):
		if not _shares_group_vision(state, team, _combat_group(state, int(ship["owner"]))) or not ship.has("position"):
			continue
		var cell: Vector2i = vision_cell(ship["position"])
		sources[cell] = maxf(float(sources.get(cell, 0.0)), sight_radius(str(ship["kind"])))
	for cell in sources:
		_stamp_vision(cells, (Vector2(cell) + Vector2.ONE * 0.5) * VISION_CELL, float(sources[cell]))
	var elapsed: float = float(state["elapsed"])
	for index in range(state["planets"].size()):
		var system: Dictionary = state["planets"][index]
		if not _shares_group_vision(state, team, _combat_group(state, int(system["owner"]))):
			continue
		if has_station(system):
			_stamp_vision(cells, station_position(state, index, elapsed), STATION_SIGHT)
		for slot in range(system["yards"].size()):
			_stamp_vision(cells, shipyard_position(state, index, slot, elapsed), YARD_SIGHT)
		if not system.get("pds", {}).is_empty():
			_stamp_vision(cells, state["map"]["points"][index], PDS_SIGHT)
	return cells

static func discovered(state: Dictionary, player: int, kind: String, index: int) -> bool:
	var team: int = _combat_group(state, player) if state.has("teams") else 0
	if team <= 0 or index < 0:
		return false
	if not bool(state.get("fog_of_war", DEFAULT_FOG_OF_WAR)):
		if kind == "planets":
			return index < (state.get("planets", []) as Array).size()
		if kind == "fields":
			return index < (state.get("map", {}).get("fields", []) as Array).size()
		return false
	var explored: Dictionary = state.get("explored", {})
	if bool(explored.get(team, {}).get(kind, {}).get(index, false)):
		return true
	if state.has("diplomacy"):
		for ally in state["teams"]:
			if ally != player and diplomacy_allows(state, player, int(ally), "vision") and bool(explored.get(ally, {}).get(kind, {}).get(index, false)):
				return true
	return false

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
		var team: int = _combat_group(state, int(state["planets"][i]["owner"]))
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
			return resources
		for resource in MINED_RESOURCES:
			if bool(policy[resource]):
				resources.append(resource)
	return resources

## Read-only player-wide holdings: stock plus the player's own cargo in transit.
static func storage_capacity(p: Dictionary) -> float:
	return float(WAREHOUSE_CAPACITIES[clampi(int(p.get("warehouse_level", 0)), 0, 3)]) * (1.0 + (1.0 if int(p["owner"]) != 0 and has_reward(p, "storage") else 0.0) + 0.05 * reward_rank(p.get("conquest_rewards", []), "rank_storage"))

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

# Credits are electronic empire balances, not local stock or ship cargo.
static func credit_balance(state: Dictionary, player: int) -> float:
	return float(state.get("galactic_credits", {}).get(player, 0.0))

static func construction_credit_cost(materials: Dictionary, kind: String = "") -> float:
	if materials.is_empty():
		return 0.0
	var value: float = 0.0
	for resource in CONSTRUCTION_REFERENCE_VALUES:
		value += float(materials.get(resource, 0.0)) * float(CONSTRUCTION_REFERENCE_VALUES[resource])
	return maxf(1.0, ceilf(value * CONSTRUCTION_CREDIT_FRACTION)) * (float(ship_size(kind) + 1) if SHIP_KINDS.has(kind) else 1.0)

static func can_pay_credits(state: Dictionary, player: int, amount: float) -> bool:
	return player > 0 and state.get("galactic_credits", {}).has(player) and is_finite(amount) and amount >= 0.0 and credit_balance(state, player) >= amount

static func _pay_credits(state: Dictionary, player: int, amount: float) -> bool:
	if not can_pay_credits(state, player, amount):
		return false
	state["galactic_credits"][player] = credit_balance(state, player) - amount
	return true

static func _refund_credits(state: Dictionary, player: int, amount: float) -> void:
	if state.get("galactic_credits", {}).has(player) and is_finite(amount) and amount > 0.0:
		state["galactic_credits"][player] = credit_balance(state, player) + amount

static func construction_affordable(state: Dictionary, p: Dictionary, cost: Dictionary, kind: String = "") -> bool:
	return affordable(p, cost) and can_pay_credits(state, int(p["owner"]), construction_credit_cost(cost, kind))

static func resident_tax_income(state: Dictionary, player: int) -> float:
	var total: float = 0.0
	if player <= 0 or not state.get("galactic_credits", {}).has(player):
		return total
	for planet in state.get("planets", []):
		if int(planet["owner"]) == player:
			total += maxf(0.0, float(planet["population"])) * RESIDENT_TAX_RATE
	return total

# One pass over systems, independent of fleet size. Use starting residents
# for each simulation substep; ship crews and reserved construction crew do
# not contribute. Never mint funds for neutral or unregistered owners.
static func _accrue_resident_taxes(state: Dictionary, dt: float) -> void:
	if dt <= 0.0:
		return
	var credits: Dictionary = state.get("galactic_credits", {})
	for planet in state.get("planets", []):
		var owner: int = int(planet["owner"])
		if owner > 0 and credits.has(owner):
			credits[owner] = float(credits[owner]) + maxf(0.0, float(planet["population"])) * RESIDENT_TAX_RATE * dt

static func ship_upkeep(kind: String) -> float:
	return float(SHIP_UPKEEP_GC.get(kind, 0.0))

static func unpaid_wage_years(state: Dictionary, ship: Dictionary) -> float:
	if not ship.has("unpaid_since"):
		return 0.0
	return maxf(0.0, float(state["elapsed"]) - float(ship["unpaid_since"]))

# Pay full current-step wages or mark the start of continuous nonpayment.
# Past missed wages are not a debt; a successful payment restores good standing.
static func _pay_hull_wages(credits: Dictionary, ship: Dictionary, amount: float, now: float) -> void:
	var owner: int = int(ship["owner"])
	var balance: float = float(credits[owner])
	if balance + EPS >= amount:
		credits[owner] = maxf(0.0, balance - amount)
		if ship.has("unpaid_since"):
			ship.erase("unpaid_since")
	elif not ship.has("unpaid_since"):
		ship["unpaid_since"] = now

# Taxes are collected first. Civilian hulls get priority over military hulls,
# then stable fleet order within each group. No per-hull sorting or timers.
static func _pay_fleet_upkeep(state: Dictionary, dt: float) -> void:
	if dt <= 0.0:
		return
	var credits: Dictionary = state.get("galactic_credits", {})
	if credits.is_empty():
		return
	var now: float = float(state["elapsed"])
	var military: Array = []
	for ship in state.get("ships", []):
		var owner: int = int(ship["owner"])
		var kind: String = str(ship.get("kind", ""))
		var rate: float = ship_upkeep(kind)
		if owner <= 0 or not credits.has(owner) or rate <= 0.0:
			if ship.has("unpaid_since"):
				ship.erase("unpaid_since")
			continue
		if military_hull(kind):
			military.append(ship)
		else:
			_pay_hull_wages(credits, ship, rate * dt, now)
	for ship in military:
		_pay_hull_wages(credits, ship, ship_upkeep(str(ship["kind"])) * dt, now)

# A seeded roll per hull and period, independent of simulation frame rate.
static func _rogue_roll(seed_value: int, hull_id: int, epoch: int) -> bool:
	return posmod(hash([seed_value, hull_id, epoch]), 1000000) < int(ROGUE_CHANCE * 1000000.0)

static func _make_rogue(ship: Dictionary) -> void:
	# Preserve the actual hull, cargo, crew, health, position and lifetime stats.
	# Drop all orders, inherited technology, auto-service and combat state.
	var point: Vector2 = ship["position"]
	var heading: Vector2 = ship.get("heading", Vector2.UP)
	var retained: Dictionary = {}
	for key in ["id", "kind", "at", "origin", "hp", "crew", "cargo", "kills", "tons_picked", "tons_dropped", "food_produced"]:
		if ship.has(key):
			retained[key] = ship[key]
	ship.clear()
	ship.merge(retained)
	ship.merge({"owner": 0, "rogue": true, "position": point, "heading": heading,
		"navigation_target": point, "route": [], "leg": 0.0, "source": -1, "dest": -1,
		"field": -1, "mining_mode": "idle", "field_leg": 0.0, "holding": true,
		"hold_position": point, "hold_heading": heading})

# Only live bilateral-diplomacy matches use independent neutral hulls.
# Aggregate one bounded, replicated notice per former owner per check.
static func _check_unpaid_defections(state: Dictionary) -> void:
	if not state.has("diplomacy"):
		return
	var now: float = float(state["elapsed"])
	var epoch: int = floori(now / ROGUE_CHECK_YEARS)
	if epoch <= int(state.get("rogue_check_epoch", 0)):
		return
	state["rogue_check_epoch"] = epoch
	var seed_value: int = int(state["map"]["seed"])
	var events: Dictionary = state.get("rogue_events", {})
	for ship in state["ships"]:
		var owner: int = int(ship["owner"])
		if owner <= 0 or not state.get("galactic_credits", {}).has(owner) or not ship.has("unpaid_since") or ship_upkeep(str(ship["kind"])) <= 0.0:
			continue
		if unpaid_wage_years(state, ship) + EPS < ROGUE_GRACE_YEARS or not _rogue_roll(seed_value, int(ship["id"]), epoch):
			continue
		var previous: Dictionary = events.get(owner, {})
		var total: int = int(previous.get("total", 0)) + 1
		var count: int = int(previous.get("count", 0)) + 1 if int(previous.get("epoch", -1)) == epoch else 1
		events[owner] = {"epoch": epoch, "total": total, "count": count, "kind": ship["kind"], "position": ship["position"], "elapsed": now}
		_make_rogue(ship)
	state["rogue_events"] = events

static func empire_totals(state: Dictionary, player: int) -> Dictionary:
	var stock: Dictionary = empty_stock()
	var cargo: Dictionary = empty_stock()
	var total: Dictionary = empty_stock()
	var population: float = 0.0
	var ship_population: float = 0.0
	var upkeep: float = 0.0
	var unpaid_ships: int = 0
	var embarking_population: float = 0.0
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
		embarking_population += embarked_construction_population(planet)
		for resource in RESOURCES:
			stock[resource] = float(stock[resource]) + float(planet["stock"].get(resource, 0.0))
	for ship in state.get("ships", []):
		if int(ship["owner"]) != player:
			continue
		craft += 1
		upkeep += ship_upkeep(str(ship.get("kind", "")))
		if ship.has("unpaid_since"):
			unpaid_ships += 1
		ship_population += float(ship.get("crew", 0.0))
		if ship.get("kind", "ship") == "colony_ship":
			colonies += 1
		elif ship.get("kind", "ship") in ["fighter", "scout", "cruiser", "destroyer"]:
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
	return {"stock": stock, "cargo": cargo, "resources": total, "storage_reference": storage_reference, "population": population + ship_population + embarking_population, "resident_population": population, "ship_population": ship_population, "embarking_population": embarking_population,
		"planets": planets, "craft": craft, "logistics": logistics, "colonies": colonies, "fighters": fighters, "miners": miners,
		"upkeep": upkeep, "unpaid_ships": unpaid_ships}

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
	for planet in state["planets"]:
		result.append(_combat_group(state, int(planet["owner"])) if has_station(planet) else 0)
	return result

## Colony ships can traverse allied worlds, with one final edge into a neutral world.
static func has_station(system: Dictionary) -> bool:
	return not system.get("station", {}).is_empty()

static func colony_path(state: Dictionary, player: int, ship: Dictionary, target: int) -> Array[int]:
	var planets: Array = state.get("planets", [])
	if target < 0 or target >= planets.size() or int(planets[target]["owner"]) != 0 or has_station(planets[target]):
		return []
	if int(ship["owner"]) != player or ship.get("kind", "ship") != "colony_ship" or not (ship["route"] as Array).is_empty():
		return []
	var teams: Array[int] = planet_teams(state)
	var team: int = _combat_group(state, player)
	var start: int = int(ship["at"])
	if team == 0 or (not _civilian_transit_allowed(state, team, teams[start]) and military_home(state, player) >= 0):
		return []
	if not discovered(state, player, "planets", target):
		return []
	var transit: Array[int] = []
	transit.resize(planets.size())
	transit.fill(team)
	if state.has("diplomacy"):
		transit = _civilian_access(state, teams, team)
		transit[start] = team
	return MAP.path(state["map"], transit, team, start, target)

# Select on the authority, not from a stale client-side dropdown.
static func nearest_idle_colony(state: Dictionary, player: int, target: int) -> int:
	var best: float = INF
	var chosen: int = -1
	for ship in state["ships"]:
		if int(ship["owner"]) != player or ship["kind"] != "colony_ship" or not _is_idle_ship(ship) or _unit_order_running(ship) or not ship.get("order_queue", []).is_empty():
			continue
		var path: Array[int] = colony_path(state, player, ship, target)
		if path.is_empty():
			continue
		var pos: Vector2 = ship.get("position", state["map"]["points"][int(ship["at"])])
		var distance: float = pos.distance_to(state["map"]["points"][path[0]]) + MAP.route_length(state["map"], path)
		var id: int = int(ship["id"])
		if distance < best or (is_equal_approx(distance, best) and (chosen < 0 or id < chosen)):
			best = distance
			chosen = id
	return chosen

static func send_colony(state: Dictionary, player: int, ship_id: int, target: int, automatic: bool = true) -> bool:
	for ship in state["ships"]:
		if int(ship["id"]) != ship_id:
			continue
		var path: Array[int] = colony_path(state, player, ship, target)
		if path.is_empty():
			return false
		_cancel_salvage_order(ship)
		_clear_tactical_order(ship)
		_set_unit_order(state, ship, {"kind": "colonize", "target": target, "automatic": automatic})
		ship["dest"] = target
		ship["return_path"] = path.duplicate()
		_clear_local_hold(ship)
		_set_route(ship, path)
		return true
	return false

# Farms produce into the physical hold, not directly into station stock.
# Suspend production during a delivery so the existing unload job can finish.
static func _grow_colony_cargo(ship: Dictionary, dt: float) -> void:
	if not autocast_enabled(ship, "farm") or _salvage_active(ship) or ship.has("cargo_order"):
		return
	var amount: float = minf(cargo_free(ship), COLONY_FARM_RATE * maxf(0.0, dt))
	ship["cargo"]["Organics"] = float(ship["cargo"].get("Organics", 0.0)) + amount
	ship["food_produced"] = float(ship.get("food_produced", 0.0)) + amount

static func _begin_farm_delivery(state: Dictionary, ship: Dictionary) -> bool:
	if not autocast_enabled(ship, "farm") or cargo_free(ship) > EPS or not _is_idle_ship(ship) or _unit_order_running(ship) or not ship.get("order_queue", []).is_empty():
		return false
	if not command_unload_cargo(state, int(ship["owner"]), [ship["id"]]):
		return false
	ship["farm_auto_delivery"] = true
	return true

static func can_transform_colony(state: Dictionary, graph: Dictionary, ship: Dictionary) -> bool:
	if ship.get("kind", "") != "colony_ship" or not ship.get("route", []).is_empty():
		return false
	var node: int = local_sector(graph, ship)
	return node >= 0 and node < state["planets"].size() and int(state["planets"][node]["owner"]) == 0 and not has_station(state["planets"][node]) and discovered(state, int(ship["owner"]), "planets", node)

static func _convert_colony(state: Dictionary, ship: Dictionary, at: int) -> bool:
	var colony: Dictionary = state["planets"][at]
	colony["owner"] = int(ship["owner"])
	var progress: Dictionary = objective_progress(state, int(ship["owner"]))
	progress["colonies"][at] = true
	colony["conquest_rewards"] = progress.get("rewards", []).duplicate()
	colony["station"] = {"hp": STATION_HP, "weapons": [_new_pds(), _new_pds()], "converted_at": float(state["elapsed"])}
	colony["population"] = float(ship.get("crew", COLONY_POPULATION)) + ORBITAL_HOUSING_POPULATION if has_planets(colony) else ORBITAL_HOUSING_POPULATION
	colony["eco_population"] = ORBITAL_HOUSING_POPULATION
	colony["population_velocity"] = 0.0
	colony["yards"].append({"level": 1, "job": -1, "hp": YARD_HP, "station_slot": 1, "converted_at": float(state["elapsed"]), "colony_heading": ship.get("heading", Vector2.UP)})
	if has_planets(colony):
		for resource in ["Metals", "Organics"]:
			colony["levels"][resource] = 1
	for resource in RESOURCES + [ANTIMATTER]:
		var amount: float = float(ship.get("cargo", {}).get(resource, 0.0))
		colony["stock"][resource] = float(colony["stock"].get(resource, 0.0)) + amount
	return true # consumed to establish the colony

static func _work_colony(state: Dictionary, ship: Dictionary, dt: float) -> bool:
	if ship.get("unit_order", {}).get("kind", "") != "colonize":
		if not ship["route"].is_empty():
			_move(state, ship, dt)
		return false
	if state.has("diplomacy") and not _civilian_route_safe(state, ship, planet_teams(state), _combat_group(state, int(ship["owner"]))):
		ship["route"] = []
		ship["leg"] = 0.0
		ship["dest"] = -1
		ship.erase("unit_order")
		ship["navigation_target"] = ship["position"]
		return false
	if not _move(state, ship, dt) or int(ship["dest"]) < 0:
		return false
	var at: int = int(ship["at"])
	if int(state["planets"][at]["owner"]) == 0 and not has_station(state["planets"][at]):
		if bool(ship.get("unit_order", {}).get("automatic", false)):
			return _convert_colony(state, ship, at)
		ship["dest"] = -1
		ship.erase("unit_order")
		ship["holding"] = true
		ship["navigation_target"] = ship["position"]
		return false
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

static func has_planets(system: Dictionary) -> bool:
	return not bool(system.get("planetless", false))

static func eco_housing_count(p: Dictionary) -> int:
	return int(p.get("orbital_housing", 0)) + (p.get("yards", []) as Array).size()

static func eco_capacity(p: Dictionary) -> float:
	return float(eco_housing_count(p)) * ORBITAL_HOUSING_POPULATION

static func eco_population(p: Dictionary) -> float:
	var total: float = maxf(0.0, float(p.get("population", 0.0)))
	if not has_planets(p):
		return total
	return clampf(float(p.get("eco_population", 0.0)), 0.0, minf(total, eco_capacity(p)))

static func planetary_population(p: Dictionary) -> float:
	return maxf(0.0, float(p.get("population", 0.0)) - eco_population(p))

static func eco_organics(p: Dictionary) -> float:
	return ECO_HOUSING_ORGANICS * eco_housing_count(p) * _rank_factor(p, "rank_orbital", 0.05) if int(p.get("owner", 0)) != 0 else 0.0

static func _add_eco_residents(p: Dictionary, count: float) -> void:
	var residents: float = eco_population(p)
	p["population"] = float(p["population"]) + count
	p["eco_population"] = residents + count

static func _regenerate_eco(p: Dictionary, dt: float, residents: float) -> void:
	var capacity: float = eco_capacity(p)
	# Separate bounded habitat growth; even an emptied habitat can be
	# repopulated. Full habitats do not add free residents each tick.
	var next: float = residents
	if residents < capacity:
		next = minf(capacity, maxf(1.0, residents) * exp(log(2.0) * dt / POPULATION_DOUBLING_YEARS))
	p["eco_population"] = next
	p["population"] = float(p["population"]) + next - residents

static func orbital_housing_available(p: Dictionary) -> bool:
	return not has_planets(p) and int(p.get("owner", 0)) != 0 and affordable(p, ORBITAL_HOUSING_COST)

static func overpopulation_penalty(planet: Dictionary, capacity_factor: float = 1.0) -> float:
	if not has_planets(planet):
		return 0.0
	var fraction: float = clampf(planetary_population(planet) / (habitation_capacity(planet) * capacity_factor), 0.0, 1.0)
	return pow(fraction, 3.0)

static func farm_potential(planet: Dictionary) -> float:
	if int(planet["owner"]) == 0 or not has_planets(planet):
		return 0.0
	return ORGANICS_PER_LEVEL * production_level(planet, "Organics") * production_modifier(planet, "Organics") * float(planet.get("farm_factor", 1.0)) * (_rank_factor(planet, "rank_food", 0.05) + (0.5 if has_reward(planet, "agriculture") else 0.0))

static func population_capacity(planet: Dictionary) -> float:
	return farm_potential(planet) * POPULATION_PER_ORGANICS_RATE

static func habitation_capacity(planet: Dictionary) -> float:
	if not has_planets(planet):
		return 0.0
	return 500000.0 * float(planet.get("size_factor", 1.0)) * pow(2.0, int(planet.get("habitation_level", 0))) * _rank_factor(planet, "rank_housing", 0.05)

static func sustainable_population_capacity(planet: Dictionary) -> float:
	return minf(population_capacity(planet), habitation_capacity(planet)) + eco_capacity(planet)

static func population_multiplier(planet: Dictionary) -> float:
	return float(planet["population"]) / HOME_POPULATION

static func population_growth(planet: Dictionary) -> float:
	return float(planet.get("population_velocity", 0.0))

static func organics_demand(planet: Dictionary) -> float:
	if not has_planets(planet):
		return 0.0
	return planetary_population(planet) / POPULATION_PER_ORGANICS_RATE

static func consumption(planet: Dictionary, resource: String) -> float:
	if int(planet["owner"]) == 0 or not has_planets(planet):
		return 0.0
	if resource == "Organics":
		return organics_demand(planet)
	var upkeep: float = 1.0
	if resource == "Metals":
		for key in ["crystals"]:
			if has_reward(planet, key):
				upkeep += 0.15
	return float(CIVILIAN_CONSUMPTION.get(resource, 0.0)) * planetary_population(planet) / HOME_POPULATION * upkeep / (_rank_factor(planet, "rank_upkeep", 0.03) if resource == "Metals" else 1.0)

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
	var station_output: float = STATION_CRYSTALS_PER_YEAR if resource == "Crystals" and int(planet["owner"]) != 0 and has_station(planet) else 0.0
	if bool(planet.get("planet_blockaded", false)) and has_planets(planet):
		return eco_organics(planet) if resource == "Organics" else station_output
	if not ACTIVE_PRODUCTION.has(resource) or int(planet["owner"]) == 0 or (not has_planets(planet) and resource in ["Metals", "Crystals"]):
		return station_output
	var level: int = production_level(planet, resource)
	if resource == "Organics":
		# Small populations still produce a surplus; farm capacity limits output.
		var capacity: float = population_capacity(planet)
		if capacity <= EPS:
			return eco_organics(planet)
		var labor: float = sqrt(clampf(planetary_population(planet) / capacity, 0.0, 1.0))
		return farm_potential(planet) * labor + eco_organics(planet)
	var labor: float = population_multiplier(planet)
	var base_rate: float = CRYSTALS_PER_LEVEL if resource == "Crystals" else PRODUCTION_PER_LEVEL
	var output: float = base_rate * level * production_modifier(planet, resource) * labor
	if resource == "Metals":
		output *= _rank_factor(planet, "rank_metals", 0.05) + (0.5 if has_reward(planet, "industry") else 0.0)
	if resource == "Crystals":
		output *= _rank_factor(planet, "rank_crystals", 0.05) + (1.0 if has_reward(planet, "crystals") else 0.0)
	return station_output + output

static func food_growth_multiplier(planet: Dictionary) -> float:
	# Orbital residents are self-sufficient; only terrestrial growth is food-limited.
	if not has_planets(planet):
		return 1.0
	return clampf(float(planet["stock"].get("Organics", 0.0)) / POPULATION_FOOD_RESERVE, 0.0, 1.0)

static func _update_population(planet: Dictionary, dt: float) -> void:
	var eco: float = eco_population(planet)
	if not has_planets(planet):
		planet["population_velocity"] = 0.0
		_regenerate_eco(planet, dt, eco)
		return
	# Exact solution of x'' + 2*w*x' + w*w*(x-target) = 0
	# for a constant target during this tick. Stable even for large dt.
	var current: float = planetary_population(planet)
	var target: float = minf(population_capacity(planet), habitation_capacity(planet))
	var velocity: float = population_growth(planet)
	var error: float = current - target
	var omega: float = POPULATION_RESPONSE
	var slope: float = velocity + omega * error
	var decay: float = exp(-omega * dt)
	var next: float = target + (error + slope * dt) * decay
	var next_velocity: float = (velocity - omega * slope * dt) * decay
	# Far below equilibrium, limit positive growth to a 60-year doubling at full food reserves.
	# Near capacity the damped response takes over without a hard population cap.
	var growth_constant: float = log(2.0) / POPULATION_DOUBLING_YEARS * food_growth_multiplier(planet)
	if current < habitation_capacity(planet):
		growth_constant *= 1.0 - overpopulation_penalty(planet)
	else:
		growth_constant = 0.0
	growth_constant *= _rank_factor(planet, "rank_growth", 0.05) + (0.5 if has_reward(planet, "population") else 0.0)
	var growth_ceiling: float = current * exp(growth_constant * dt)
	if next > growth_ceiling:
		next = growth_ceiling
		next_velocity = growth_constant * next
	# A food shortfall prevents positive growth even with demographic momentum.
	var food_available: float = civilian_stock_access(planet, "Organics") + rate(planet, "Organics") * dt
	if food_available + EPS < organics_demand(planet) * dt:
		next = minf(next, current)
		next_velocity = minf(next_velocity, 0.0)
	planet["population"] = maxf(0.0, next) + eco
	planet["population_velocity"] = minf(next_velocity, growth_constant * next) if next > 0.0 else 0.0
	_regenerate_eco(planet, dt, eco)

static func ship_size(kind: String) -> int:
	return int(SHIP_SIZES.get(kind, 1))

static func size_name(size_class: int) -> String:
	return ["Small", "Medium", "Large"][clampi(size_class, 1, 3) - 1]

static func yard_fits(p: Dictionary, slot: int, kind: String) -> bool:
	return slot >= 0 and slot < p["yards"].size() and ship_size(kind) <= max_size(int(p["yards"][slot]["level"]))

static func has_fitting_yard(p: Dictionary, kind: String) -> bool:
	for slot in range(p["yards"].size()):
		if yard_fits(p, slot, kind):
			return true
	return false

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
		"ship": return {"Metals": 360.0, "Organics": 15.0}
		"colony_ship": return {"Metals": 1200.0, "Organics": 30.0}
		"fighter": return {"Metals": 270.0, "Organics": 10.0}
		"miner": return {"Metals": 540.0, "Organics": 20.0}
		"science_ship": return {"Metals": 900.0, "Organics": 30.0}
		"scout": return {"Metals": 60.0, "Organics": 2.0}
		"cruiser": return {"Metals": 1800.0, "Organics": 60.0, "Crystals": 80.0 * CRYSTAL_COST_MULTIPLIER}
		"destroyer": return {"Metals": 3800.0, "Organics": 120.0, "Crystals": 200.0 * CRYSTAL_COST_MULTIPLIER}
		"yard":
			match level:
				1: return {"Metals": 480.0}
				2: return {"Metals": 2000.0, "Organics": 200.0, "Crystals": 200.0 * CRYSTAL_COST_MULTIPLIER}
				3: return {"Metals": 6000.0, "Organics": 600.0, "Crystals": 600.0 * CRYSTAL_COST_MULTIPLIER}
		"pds": return {"Metals": 540.0, "Organics": 60.0, "Crystals": 60.0 * CRYSTAL_COST_MULTIPLIER}
		"dyson_sphere": return {"Metals": 20000.0, "Crystals": 10000.0}
		"reinforced_plating": return {"Metals": 4000.0}
		"laser_matrix": return {"Metals": 2500.0, "Crystals": 800.0 * CRYSTAL_COST_MULTIPLIER}
		"yard_upgrade": return {"Metals": 240.0 * pow(UPGRADE_COST_FACTOR, float(maxi(0, level - 1)))}
		"production": return {"Metals": 200.0 * pow(UPGRADE_COST_FACTOR, float(maxi(0, level - 1)))}
		"warehouse": return WAREHOUSE_COSTS[level - 1].duplicate()
		"habitation":
			var factor: float = pow(3.0, level - 1)
			return {"Metals": 600.0 * factor}
		"orbital_housing": return ORBITAL_HOUSING_COST.duplicate()
	return {}

static func _work(kind: String, level: int) -> float:
	match kind:
		"ship": return 48.0
		"colony_ship": return 102.0
		"fighter": return 36.0
		"miner": return 60.0
		"science_ship": return 90.0
		"scout": return 12.0
		"cruiser": return 90.0
		"destroyer": return 180.0
		"yard": return 30.0
		"pds": return 36.0
		"dyson_sphere": return 300.0
		"reinforced_plating", "laser_matrix": return 60.0
		"yard_upgrade": return 15.0 * level
		"production": return 10.0 * level
		"warehouse": return 10.0 + 10.0 * level
		"habitation": return 12.0 + 12.0 * level
		"orbital_housing": return 30.0
	return 1.0

static func _get_owned(state: Dictionary, player: int, index: int) -> Dictionary:
	var planets: Array = state.get("planets", [])
	if index < 0 or index >= planets.size() or int(planets[index]["owner"]) != player or not has_station(planets[index]):
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

# Numbered attachment ports are stable; production indices and price tiers
# retain their existing contiguous-array and refund semantics.
static func shipyard_port(p: Dictionary, index: int) -> int:
	return int(p["yards"][index].get("station_slot", index + 1))

static func shipyard_at_port(p: Dictionary, port: int) -> int:
	for index in range(p["yards"].size()):
		if shipyard_port(p, index) == port:
			return index
	return -1

static func shipyard_port_job(p: Dictionary, port: int) -> Dictionary:
	for item in p["queue"]:
		if item["kind"] == "yard" and int(item.get("station_slot", item["level"])) == port:
			return item
	return {}

static func station_max_hp(p: Dictionary) -> float:
	return REINFORCED_STATION_HP if bool(p.get("station", {}).get("reinforced_plating", false)) else STATION_HP

static func station_upgrade_available(p: Dictionary, kind: String) -> bool:
	return STATION_UPGRADES.has(kind) and (kind != "dyson_sphere" or p.get("conquest_rewards", []).has("dyson_sphere")) and has_station(p) and not bool(p["station"].get(kind, false)) and not _has_job(p, kind, "") and affordable(p, _cost(kind, 1))

# Move later construction down one slot when an earlier job is cancelled.
# Preserve its fractional work, but retain only the cheaper recipe's
# full prepaid allocation; return the difference to local stock.
static func _compact_shipyard_orders(state: Dictionary, p: Dictionary, removed_level: int) -> void:
	for item in p["queue"]:
		if item["kind"] != "yard" or int(item["level"]) <= removed_level:
			continue
		var fraction: float = clampf(float(item["progress"]) / float(item["work"]), 0.0, 1.0)
		var level: int = int(item["level"]) - 1
		var cost: Dictionary = _cost("yard", level)
		var allocated: Dictionary = empty_stock()
		for resource in RESOURCES:
			allocated[resource] = float(cost.get(resource, 0.0))
			p["stock"][resource] += float(item["allocated"][resource]) - float(allocated[resource])
		var reserved_gc: float = float(item.get("credit_cost", 0.0))
		var reduced_gc: float = minf(reserved_gc, construction_credit_cost(cost))
		_refund_credits(state, int(p["owner"]), reserved_gc - reduced_gc)
		item["credit_cost"] = reduced_gc
		item["level"] = level
		item["cost"] = cost
		item["work"] = _work("yard", level)
		item["progress"] = fraction * float(item["work"])
		item["allocated"] = allocated

# Gates apply to new local production orders, not completed infrastructure.
# All three resources use the ordinary local population gate.
static func production_population(_resource: String, level: int) -> int:
	return maxi(1000, 10000 * (level - 1))

static func production_available(p: Dictionary, resource: String) -> bool:
	if not has_planets(p) and resource in ["Metals", "Crystals", "Organics"]:
		return false
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

# Minimum resident population to order the next production building.
static func building_population(resource: String, level: int) -> int:
	var tier: int = maxi(1, level)
	return int(ECONOMY_BUILDINGS[resource]["population"]) * tier * tier

static func building_available(p: Dictionary, resource: String) -> bool:
	return building_blocker(p, resource).is_empty()

static func building_blocker(p: Dictionary, resource: String) -> String:
	if not ECONOMY_BUILDINGS.has(resource):
		return "Unknown building"
	if not production_available(p, resource):
		return "No suitable planetary resource deposit" if has_planets(p) else "Requires a planet"
	if _has_job(p, "economy_building", resource):
		return "Upgrade already queued"
	if float(p["population"]) + EPS < float(building_population(resource, int(p.get("buildings", {}).get(resource, 0)) + 1)):
		return "Insufficient local population"
	return ""

static func warehouse_available(p: Dictionary) -> bool:
	var level: int = int(p.get("warehouse_level", 0))
	return level < 3 and not _has_job(p, "warehouse", "") and float(p["population"]) + EPS >= float(WAREHOUSE_POPULATIONS[level]) and affordable(p, WAREHOUSE_COSTS[level])

static func habitation_cost(p: Dictionary) -> Dictionary:
	var factor: float = pow(3.0, int(p.get("habitation_level", 0)))
	return {"Metals": 600.0 * factor}

static func habitation_available(p: Dictionary) -> bool:
	return has_planets(p) and int(p.get("habitation_level", 0)) < 3 and not _has_job(p, "habitation", "") and affordable(p, habitation_cost(p))

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

static func shipyard_queue_count(p: Dictionary, slot: int) -> int:
	var count: int = 0
	var active: int = int(p["yards"][slot]["job"])
	for item in p["queue"]:
		if (item["kind"] == "yard_upgrade" and int(item["target"]) == slot) or (int(item["size"]) > 0 and (int(item.get("yard_slot", -1)) == slot or int(item["id"]) == active)):
			count += 1
	return count

static func enqueue(state: Dictionary, player: int, index: int, kind: String, target: String = "", yard_slot: int = -1) -> bool:
	var p: Dictionary = _get_owned(state, player, index)
	if p.is_empty():
		return false
	if yard_slot != -1 and (not SHIP_KINDS.has(kind) or not shipyard_operational(p, yard_slot) or not yard_fits(p, yard_slot, kind)):
		return false
	if SHIP_KINDS.has(kind) and not has_fitting_yard(p, kind):
		return false
	if SHIP_KINDS.has(kind) or kind == "yard_upgrade":
		var total: int = 0
		for item in p["queue"]:
			if int(item["size"]) > 0 or item["kind"] == "yard_upgrade":
				total += 1
		if total >= maxi(1, p["yards"].size()) * SHIPYARD_QUEUE_LIMIT or (yard_slot >= 0 and shipyard_queue_count(p, yard_slot) >= SHIPYARD_QUEUE_LIMIT):
			return false
	var level: int = 1
	var station_slot: int = 0
	match kind:
		"ship":
			if not bool(p["home"]):
				return false
			target = ""
		"colony_ship", "fighter", "miner", "science_ship", "scout", "cruiser", "destroyer":
			target = ""
		"yard":
			level = next_shipyard_slot(p)
			if level == 0:
				return false
			if target.begins_with("port:"):
				var requested: String = target.trim_prefix("port:")
				if not requested.is_valid_int():
					return false
				station_slot = int(requested)
				if station_slot < 1 or station_slot > MAX_SHIPYARDS or shipyard_at_port(p, station_slot) >= 0 or not shipyard_port_job(p, station_slot).is_empty():
					return false
			else:
				if not target.is_empty() and target != str(level):
					return false
				for port in range(1, MAX_SHIPYARDS + 1):
					if shipyard_at_port(p, port) < 0 and shipyard_port_job(p, port).is_empty():
						station_slot = port
						break
				if station_slot == 0:
					return false
			target = ""
		"reinforced_plating", "laser_matrix", "dyson_sphere":
			if not target.is_empty() or not station_upgrade_available(p, kind):
				return false
		"yard_upgrade":
			if not target.is_valid_int():
				return false
			var y: int = int(target)
			if y < 0 or y >= (p["yards"] as Array).size():
				return false
			if int(p["yards"][y]["level"]) >= MAX_SHIPYARD_LEVEL or shipyard_queue_count(p, y) >= SHIPYARD_QUEUE_LIMIT:
				return false
			target = str(y)
			if _has_job(p, kind, target):
				return false
			level = int(p["yards"][y]["level"]) + 1
		"pds":
			if not target.is_empty():
				return false
			var slot: int = next_pds(p)
			if slot < 0 or slot >= int(p.get("planet_count", 0)) or p.get("pds", {}).has(slot) or not pds_job(p).is_empty():
				return false
			target = str(slot)
			level = 1
		"economy":
			match target:
				"orbital_housing":
					if not orbital_housing_available(p):
						return false
					kind = target
					target = ""
				"habitation", "warehouse":
					if not (habitation_available(p) if target == "habitation" else warehouse_available(p)):
						return false
					kind = target
					level = int(p.get(kind + "_level", 0)) + 1
					target = ""
				_:
					if not building_available(p, target):
						return false
					kind = "economy_building"
					level = int(p.get("buildings", {}).get(target, 0)) + 1
		"production":
			if not production_unlocked(p, target) or _has_job(p, kind, target):
				return false
			level = int(p["levels"][target]) + 1
		_: return false
	var cost: Dictionary = building_cost(p, target) if kind == "economy_building" else construction_cost(p, kind, level)
	var gc: float = construction_credit_cost(cost, kind)
	if not affordable(p, cost) or not _pay_credits(state, player, gc):
		return false
	var paid: Dictionary = empty_stock()
	for material in cost:
		paid[material] = float(cost[material])
		_spend_material(p, "Construction: " + kind, material, float(cost[material]))
	var id: int = int(state["next_id"])
	state["next_id"] = id + 1
	p["queue"].append({"id": id, "kind": kind, "target": target, "yard_slot": yard_slot, "level": level,
		"cost": cost, "credit_cost": gc, "work": 30.0 if kind == "economy_building" else _work(kind, level),
		"progress": 0.0, "allocated": paid, "population_cost": float(CREW_COSTS.get(kind, 0.0)), "population_allocated": 0.0, "size": ship_size(kind) if SHIP_KINDS.has(kind) else 0})
	if kind == "yard":
		p["queue"][-1]["station_slot"] = station_slot
	return true

static func production_modifier(system: Dictionary, resource: String) -> float:
	var modifier: float = float(system["bonuses"].get(resource, 1.0))
	if MINED_RESOURCES.has(resource):
		modifier *= float(system["abundance"].get(resource, 0.0))
	return clampf(modifier, 0.1, 4.0) * building_multiplier(system, resource)

static func _continuous_target(p: Dictionary, key: String) -> Array:
	if SHIP_KINDS.has(key):
		return [key, ""] if key != "ship" or bool(p["home"]) else []
	if key in ["warehouse", "habitation"]:
		return [key, ""] if key != "habitation" or has_planets(p) else []
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
	if enabled and kind.begins_with("yard_upgrade:") and int(p["yards"][int(kind.trim_prefix("yard_upgrade:"))]["level"]) >= MAX_SHIPYARD_LEVEL:
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
	var all_turns: bool = true
	for key in keys:
		if SHIP_KINDS.has(key) and _maintain_needed(state, index, p, str(key)) and not manual_hulls.has(key) and not cycle.has(key):
			all_turns = false
	if not waiting and idle and all_turns:
		cycle.clear()
	for key in cycle.keys():
		if not _maintain_needed(state, index, p, str(key)):
			cycle.erase(key)
	var hull_waiting_for_funds: bool = false
	for key in keys:
		if not _maintain_needed(state, index, p, str(key)):
			continue
		var order: Array = _continuous_target(p, str(key))
		if order.is_empty():
			continue
		if order[0] in ["warehouse", "habitation"]:
			if int(p.get(str(order[0]) + "_level", 0)) >= 3:
				p["continuous"][key] = false
			elif enqueue(state, int(p["owner"]), index, "economy", order[0]):
				p["queue"][-1]["automatic"] = true
			continue
		if SHIP_KINDS.has(order[0]):
			if hull_waiting_for_funds or not has_fitting_yard(p, str(order[0])) or cycle.has(key) or manual_hulls.has(key):
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
		elif SHIP_KINDS.has(order[0]):
			hull_waiting_for_funds = true
	p["repeat_cycle"] = cycle

static func set_yard_autobuild(state: Dictionary, player: int, index: int, slot: int, kind: String, enabled: bool) -> bool:
	var p: Dictionary = _get_owned(state, player, index)
	if p.is_empty() or slot < 0 or slot >= p["yards"].size() or not SHIP_KINDS.has(kind) or (kind == "ship" and not bool(p["home"])):
		return false
	var modes: Array = p["yards"][slot].get("autobuild", [])
	if enabled and not yard_fits(p, slot, kind):
		return false
	if enabled and not modes.has(kind):
		modes.append(kind)
	elif not enabled:
		modes.erase(kind)
	p["yards"][slot]["autobuild"] = modes
	return true

static func _refill_yard_autobuild(state: Dictionary, index: int, p: Dictionary) -> void:
	for slot in range(p["yards"].size()):
		if not shipyard_operational(p, slot):
			continue
		var yard: Dictionary = p["yards"][slot]
		for kind in yard.get("autobuild", []):
			if not yard_fits(p, slot, kind):
				continue
			var exists: bool = false
			for item in p["queue"]:
				if item["kind"] == kind and (int(item.get("yard_slot", -1)) == slot or int(item["id"]) == int(yard["job"])):
					exists = true
					break
			if not exists:
				if not enqueue(state, int(p["owner"]), index, kind, "", slot):
					break
				p["queue"][-1]["yard_auto"] = true

static func construction_leaves_salvage(item: Dictionary) -> bool:
	return SHIP_KINDS.has(item["kind"])

static func construction_position(state: Dictionary, index: int, item: Dictionary) -> Vector2:
	var elapsed: float = float(state["elapsed"])
	var p: Dictionary = state["planets"][index]
	if item.has("delivery_slot"):
		var bodies: Array = system_bodies(p, int(state["map"].get("seed", 0)), index)
		var slot: int = int(item["delivery_slot"])
		if slot >= 0 and slot < bodies.size():
			var destination: Vector2 = (state["map"]["points"][index] as Vector2) + body_position(bodies[slot], system_world_radius(state, index), elapsed)
			var fraction: float = 1.0 - clampf(float(item["delivery_remaining"]) / PLANET_UPGRADE_DELIVERY_TIME, 0.0, 1.0)
			return station_position(state, index, elapsed).lerp(destination, fraction)
	if item["kind"] == "yard":
		return shipyard_port_position(state, index, int(item.get("station_slot", item["level"])), elapsed)
	if SHIP_KINDS.has(item["kind"]):
		for slot in range(p["yards"].size()):
			if int(p["yards"][slot]["job"]) == int(item["id"]):
				return shipyard_position(state, index, slot, elapsed)
		var slot: int = int(item.get("yard_slot", -1))
		if slot >= 0 and slot < p["yards"].size():
			return shipyard_position(state, index, slot, elapsed)
	if item["kind"] == "pds":
		var bodies: Array = system_bodies(p, int(state["map"].get("seed", 0)), index)
		var slot: int = int(item["target"])
		if slot >= 0 and slot < bodies.size():
			return (state["map"]["points"][index] as Vector2) + body_position(bodies[slot], system_world_radius(state, index), elapsed)
	return station_position(state, index, elapsed)

# Unlike wreck destruction, cancellation recovers every prepaid tonne.
static func _drop_construction_materials(state: Dictionary, index: int, item: Dictionary) -> void:
	var point: Vector2 = construction_position(state, index, item)
	var born: float = float(state["elapsed"])
	var piles: Dictionary = state.get("salvage", {})
	for resource in RESOURCES:
		var amount: float = float(item["allocated"].get(resource, 0.0))
		if amount <= EPS:
			continue
		var id: int = int(state.get("next_salvage_id", 1))
		state["next_salvage_id"] = id + 1
		var axis: Vector2 = Vector2.from_angle(float(id) * 2.399963)
		var origin: Vector2 = point + axis * 14.0
		piles[id] = {"id": id, "resource": resource, "amount": amount, "origin": origin, "position": origin, "drift": axis.orthogonal() * 4.0, "born": born, "claim": -1, "construction_job": item["id"]}
	state["salvage"] = piles

static func cancel(state: Dictionary, player: int, index: int, job_id: int) -> bool:
	var p: Dictionary = _get_owned(state, player, index)
	if p.is_empty():
		return false
	for item in p["queue"]:
		if int(item["id"]) != job_id:
			continue
		if construction_leaves_salvage(item):
			_drop_construction_materials(state, index, item)
		else:
			for resource in RESOURCES:
				p["stock"][resource] = float(p["stock"][resource]) + float(item["allocated"][resource])
		var eco: float = eco_population(p)
		var eco_refund: float = minf(float(item.get("eco_allocated", 0.0)), maxf(0.0, eco_capacity(p) - eco))
		p["population"] = float(p["population"]) + float(item.get("population_allocated", 0.0))
		p["eco_population"] = eco + eco_refund
		for yard in p["yards"]:
			if int(yard["job"]) == job_id:
				if SHIP_KINDS.has(item["kind"]):
					yard.get("autobuild", []).erase(item["kind"])
				yard["job"] = -1
		var slot: int = int(item.get("yard_slot", -1))
		if slot >= 0 and slot < p["yards"].size():
			p["yards"][slot].get("autobuild", []).erase(item["kind"])
		var key: String = str(item["kind"])
		if key == "production" or key == "yard_upgrade" or key == "economy_building":
			key += ":" + str(item["target"])
		if p["continuous"].has(key):
			p["continuous"][key] = false
		if SHIP_KINDS.has(key) and p.has("maintain"):
			p["maintain"][key] = 0
		p["queue"].erase(item)
		_refund_credits(state, player, float(item.get("credit_cost", 0.0)))
		if item["kind"] == "yard":
			_compact_shipyard_orders(state, p, int(item["level"]))
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

static func _spend_material(p: Dictionary, category: String, resource: String, amount: float) -> void:
	p["stock"][resource] = maxf(0.0, float(p["stock"][resource]) - amount)
	var pending: Dictionary = p.get("pending_spending", {})
	if not pending.has(category):
		pending[category] = {}
	pending[category][resource] = float(pending[category].get(resource, 0.0)) + amount
	p["pending_spending"] = pending

static func _possible(p: Dictionary, item: Dictionary, yard_slot: int = -1) -> float:
	var work: float = float(item["work"])
	var possible: float = work - float(item["progress"])
	var crew: float = _remaining_crew(item)
	if crew > EPS:
		var reserve: float = SHIPYARD_POPULATION[0] if item["kind"] == "colony_ship" else 1.0
		if yard_slot >= 0:
			reserve = maxf(reserve, float(SHIPYARD_POPULATION[yard_slot]))
		# A hull may only start/resume when the entire unpaid crew is
		# available, without consuming the yard's operating population.
		if float(p["population"]) + EPS < crew + reserve:
			return 0.0
	return maxf(0.0, possible)

static func _remaining_crew(item: Dictionary) -> float:
	return maxf(0.0, float(item.get("population_cost", 0.0)) - float(item.get("population_allocated", 0.0)))

static func construction_blockers(p: Dictionary, item: Dictionary, yard_slot: int = -1) -> Array[String]:
	var missing: Array[String] = []
	if float(item["work"]) - float(item["progress"]) <= EPS:
		return missing
	var slot: int = yard_slot if yard_slot >= 0 else int(item.get("yard_slot", -1))
	if slot < 0 and int(item.get("size", 0)) > 0 and not p["yards"].is_empty():
		slot = 0
	if _possible(p, item, slot) <= EPS or (int(item.get("size", 0)) > 0 and slot >= 0 and not shipyard_operational(p, slot)) or (item["kind"] == "yard_upgrade" and not shipyard_operational(p, int(item["target"]))):
		missing.append("Population")
	return missing

static func _advance(p: Dictionary, item: Dictionary, work_budget: float, yard_slot: int = -1) -> bool:
	var amount: float = minf(work_budget, _possible(p, item, yard_slot))
	var crew: float = amount * float(item.get("population_cost", 0.0)) / float(item["work"])
	var eco: float = eco_population(p)
	var eco_crew: float = minf(eco, crew)
	p["eco_population"] = eco - eco_crew
	item["eco_allocated"] = float(item.get("eco_allocated", 0.0)) + eco_crew
	p["population"] = maxf(0.0, float(p["population"]) - crew)
	p["crew_rate"] = float(p.get("crew_rate", 0.0)) + crew / maxf(EPS, float(p.get("flow_dt", 1.0)))
	item["population_allocated"] = float(item.get("population_allocated", 0.0)) + crew
	item["progress"] = float(item["progress"]) + amount
	return float(item["progress"]) >= float(item["work"]) - EPS

static func station_position(state: Dictionary, index: int, elapsed: float) -> Vector2:
	var center: Vector2 = state["map"]["points"][index]
	var station: Dictionary = state["planets"][index].get("station", {})
	if station.is_empty():
		return center
	var axis: Vector2 = Vector2.from_angle(float(index) * 2.399963 + elapsed * 0.008)
	var graph: Dictionary = military_graph(state)
	var radius: float = minf(145.0, sector_limit(graph, index, axis) * 0.5)
	var conversion: float = clampf((elapsed - float(station.get("converted_at", -100.0))) / 3.0, 0.0, 1.0)
	return center + axis * radius * smoothstep(0.0, 1.0, conversion)

static func shipyard_position(state: Dictionary, index: int, slot: int, elapsed: float) -> Vector2:
	return shipyard_port_position(state, index, shipyard_port(state["planets"][index], slot), elapsed)

static func shipyard_port_position(state: Dictionary, index: int, port: int, elapsed: float) -> Vector2:
	var angle: float = float(port - 1) * TAU / 3.0 + elapsed * 0.008
	return station_position(state, index, elapsed) + Vector2.from_angle(angle) * 90.0

static func _rally_path(state: Dictionary, index: int, target: int) -> Array[int]:
	var access: Array[int] = []
	access.resize(state["map"]["points"].size())
	access.fill(1)
	return MAP.path(state["map"], access, 1, index, target)

static func set_shipyard_rally(state: Dictionary, player: int, index: int, slot: int, target: int, point: Vector2) -> bool:
	var p: Dictionary = _get_owned(state, player, index)
	if p.is_empty() or slot < 0 or slot >= p["yards"].size():
		return false
	if target == -1:
		p["yards"][slot].erase("rally")
		return true
	if not point.is_finite() or target < 0 or target >= state["planets"].size() or not discovered(state, player, "planets", target):
		return false
	if not sector_contains(military_graph(state), target, point) or _rally_path(state, index, target).is_empty():
		return false
	p["yards"][slot]["rally"] = {"node": target, "point": point}
	return true

static func _launch_to_rally(state: Dictionary, ship: Dictionary, rally: Dictionary) -> void:
	if rally.is_empty():
		return
	var target: int = int(rally["node"])
	var path: Array[int] = _rally_path(state, int(ship["at"]), target)
	if path.is_empty():
		return
	_set_route(ship, path)
	ship["launch_rally"] = rally.duplicate()
	ship["navigation_target"] = rally["point"]
	if ship["kind"] in ["fighter", "scout", "cruiser", "destroyer"]:
		ship["direct_order"] = true
		ship["operation_target"] = target
		ship["dest"] = target
		ship.erase("move_only")

static func _work_launch_rally(state: Dictionary, ship: Dictionary, dt: float) -> bool:
	if not ship.has("launch_rally"):
		return false
	var rally: Dictionary = ship["launch_rally"]
	var fighter: bool = ship["kind"] in ["fighter", "scout", "cruiser", "destroyer"]
	if fighter:
		# Combat and emergency repair use the normal fighter movement branch.
		# Retain the exact rally destination through these temporary detours.
		if bool(ship.get("retreating", false)) or _engaged(ship):
			return false
		var graph: Dictionary = military_graph(state)
		var node: int = int(rally["node"])
		if int(ship.get("dest", -1)) != node:
			_redirect_fighter(graph, ship, node, _military_paths(graph, node))
		if not (ship["route"] as Array).is_empty():
			_move({"map": graph}, ship, dt)
			return true
		if not sector_contains(graph, node, ship["position"]):
			_navigate(ship, graph["points"][node], ship_speed(str(ship.get("kind", "ship"))) * dt)
			return true
	elif not (ship["route"] as Array).is_empty():
		_move(state, ship, dt)
		return true
	# Arrive in the vicinity, not at a shared exact coordinate. Separation
	# can otherwise keep a crowded fleet fighting the same arrival target.
	var distance: float = (ship["position"] as Vector2).distance_to(rally["point"])
	if distance > RALLY_ARRIVAL_RADIUS:
		_navigate(ship, rally["point"], minf(ship_speed(str(ship.get("kind", "ship"))) * dt, distance - RALLY_ARRIVAL_RADIUS * 0.9))
	if (ship["position"] as Vector2).distance_to(rally["point"]) <= RALLY_ARRIVAL_RADIUS:
		ship.erase("launch_rally")
		ship.erase("move_only")
		ship.erase("holding")
		ship.erase("hold_position")
		ship.erase("hold_sector")
		ship.erase("hold_heading")
		ship["at"] = int(rally["node"])
		ship["leg"] = 0.0
		ship["dest"] = int(rally["node"]) if fighter else -1
		ship["source"] = -1
	return true

# Choose a free nearby launch point without changing the shipyard or rally.
static func _launch_position_clear(state: Dictionary, point: Vector2) -> bool:
	for craft in state["ships"]:
		if craft.has("position") and (craft["position"] as Vector2).distance_squared_to(point) < SHIP_CLEARANCE * SHIP_CLEARANCE:
			return false
	return true

static func _free_launch_position(state: Dictionary, node: int, origin: Vector2, preferred: Vector2, id: int) -> Vector2:
	var graph: Dictionary = military_graph(state)
	if sector_contains(graph, node, preferred) and _launch_position_clear(state, preferred):
		return preferred
	if sector_contains(graph, node, origin) and _launch_position_clear(state, origin):
		return origin
	for ring in range(1, 7):
		var radius: float = float(ring) * SHIP_CLEARANCE * 1.1
		for slot in range(12 * ring):
			var angle: float = float(id) * 2.399963 + TAU * float(slot) / float(12 * ring)
			var candidate: Vector2 = origin + Vector2.from_angle(angle) * radius
			if sector_contains(graph, node, candidate) and _launch_position_clear(state, candidate):
				return candidate
	# Extremely crowded or narrow sectors use the regular collision pass.
	return origin

static func _finish(state: Dictionary, index: int, p: Dictionary, item: Dictionary) -> void:
	match str(item["kind"]):
		"economy_building":
			p["buildings"][item["target"]] = int(p["buildings"].get(item["target"], 0)) + 1
		"warehouse", "habitation":
			var kind: String = item["kind"]
			p[kind + "_level"] = int(item["level"])
			if int(item["level"]) >= 3:
				p["continuous"][kind] = false
		"orbital_housing":
			p["orbital_housing"] = int(p.get("orbital_housing", 0)) + 1
			_add_eco_residents(p, ORBITAL_HOUSING_POPULATION)
			p["population_velocity"] = 0.0
		"production":
			p["levels"][item["target"]] = int(item["level"])
		"pds":
			p["pds"][int(item["target"])] = _new_pds()
		"yard":
			p["yards"].append({"level": 1, "job": -1, "hp": YARD_HP, "station_slot": int(item.get("station_slot", item["level"]))})
			_add_eco_residents(p, ORBITAL_HOUSING_POPULATION)
		"reinforced_plating":
			p["station"]["reinforced_plating"] = true
			p["station"]["hp"] = minf(REINFORCED_STATION_HP, float(p["station"]["hp"]) + REINFORCED_STATION_HP - STATION_HP)
		"dyson_sphere":
			p["station"]["dyson_sphere"] = true
		"laser_matrix":
			p["station"]["laser_matrix"] = true
			p["station"]["weapons"] = p["station"].get("weapons", []) + [_new_pds(), _new_pds()]
		"yard_upgrade":
			p["yards"][int(item["target"])]["level"] = int(item["level"])
			p["yards"][int(item["target"])]["hp"] = YARD_HP * int(item["level"])
			if int(item["level"]) >= MAX_SHIPYARD_LEVEL:
				p["continuous"]["yard_upgrade:" + str(item["target"])] = false
		"ship", "colony_ship", "fighter", "miner", "science_ship", "scout", "cruiser", "destroyer":
			var launch: Vector2 = station_position(state, index, float(state["elapsed"]))
			var rally: Dictionary = {}
			for slot in range(p["yards"].size()):
				if int(p["yards"][slot]["job"]) == int(item["id"]):
					launch = shipyard_position(state, index, slot, float(state["elapsed"]))
					rally = p["yards"][slot].get("rally", {})
					break
			launch = _free_launch_position(state, index, launch, launch + (item.get("spawn_offset", Vector2.ZERO) as Vector2), int(item["id"]))
			state["ships"].append({"id": int(item["id"]), "kind": str(item["kind"]), "owner": int(p["owner"]), "origin": index, "at": index,
				"position": launch, "heading": Vector2.UP, "navigation_target": launch,
				"route": [], "leg": 0.0, "source": -1, "dest": -1, "hp": ship_max_hp(str(item["kind"])), "crew": float(item.get("population_allocated", 0.0)), "cargo": empty_stock(), "field": -1, "mining_mode": "idle", "field_leg": 0.0})
			if is_same(state, _indexed_state):
				_hulls_by_id[int(item["id"])] = state["ships"].back()
			_launch_to_rally(state, state["ships"].back(), rally)
			if not bool(item.get("starting_fleet", false)):
				var progress: Dictionary = objective_progress(state, int(p["owner"]))
				if item["kind"] == "colony_ship":
					progress["colony_ships_built"] = int(progress.get("colony_ships_built", 0)) + 1
				elif military_hull(str(item["kind"])):
					progress["military_built"] = int(progress.get("military_built", 0)) + 1
					progress["military_investment"] = float(progress.get("military_investment", 0.0)) + float(_cost(str(item["kind"]), 1).get("Metals", 0.0))
					if item["kind"] in ["cruiser", "destroyer"]:
						progress["capital_built"] = int(progress.get("capital_built", 0)) + 1
					elif item["kind"] == "fighter":
						progress["fighters_built"] = int(progress.get("fighters_built", 0)) + 1
				elif item["kind"] == "science_ship":
					progress["science_built"] = int(progress.get("science_built", 0)) + 1
				elif item["kind"] in ["miner", "ship"]:
					progress["logistics_built"] = int(progress.get("logistics_built", 0)) + 1
	if not SHIP_KINDS.has(item["kind"]) and int(p["owner"]) > 0:
		var progress: Dictionary = objective_progress(state, int(p["owner"]))
		progress["infrastructure_built"] = int(progress.get("infrastructure_built", 0)) + 1
	p["queue"].erase(item)

static func cargo_bay_count(kind: String) -> int:
	return FREIGHTER_BAY_COUNT if kind == "ship" else (2 if kind == "miner" else (5 if kind == "colony_ship" else 1))

static func _transfer_bay(entity: Dictionary, resource: String, amount: float, outgoing: bool) -> int:
	if entity.has("stock"):
		var quantity: float = float(entity["stock"].get(resource, 0.0)) + amount * (-0.5 if outgoing else 0.5)
		return clampi(floori(quantity / maxf(EPS, storage_capacity(entity)) * STATION_STORAGE_BAYS), 0, STATION_STORAGE_BAYS - 1)
	var kind: String = str(entity["kind"])
	var cargo: Dictionary = entity.get("cargo", {})
	var offset: float = 0.0
	for key in RESOURCES + [ANTIMATTER]:
		if key == resource:
			break
		offset += float(cargo.get(key, 0.0))
	offset += float(cargo.get(resource, 0.0)) + amount * (-0.5 if outgoing else 0.5)
	var count: int = cargo_bay_count(kind)
	return clampi(floori(offset / maxf(EPS, cargo_capacity(kind)) * count), 0, count - 1)

static func _cargo_stat(ship: Dictionary, key: String, resource: String, amount: float) -> void:
	if ship.has("kind") and cargo_capacity(str(ship["kind"])) > EPS and resource != ANTIMATTER and amount > EPS:
		ship[key] = float(ship.get(key, 0.0)) + amount

static func _record_transfer(state: Dictionary, source_id: int, source: Dictionary, target_id: int, target: Dictionary, resource: String, amount: float) -> void:
	if amount <= EPS:
		return
	_cargo_stat(source, "tons_dropped", resource, amount)
	_cargo_stat(target, "tons_picked", resource, amount)
	var events: Dictionary = state.get("cargo_transfers", {})
	var key: String = "%d:%d:%s" % [source_id, target_id, resource]
	if not events.has(key) and events.size() >= TRANSFER_EVENT_LIMIT:
		events.erase(events.keys()[0])
	var seq: int = int(state.get("cargo_transfer_seq", 0)) + 1
	state["cargo_transfer_seq"] = seq
	events[key] = {"source": source_id, "target": target_id, "resource": resource, "amount": amount, "from_bay": _transfer_bay(source, resource, amount, true), "to_bay": _transfer_bay(target, resource, amount, false), "elapsed": float(state["elapsed"]), "seq": seq}
	state["cargo_transfers"] = events

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

const PLANET_UPGRADE_DELIVERY_TIME: float = 3.0

# Planetary improvements retain their paid queue entry until the cargo arrives.
# Station equipment, orbital housing and shipyards finish at their own site.
static func planetary_upgrade_slot(state: Dictionary, index: int, item: Dictionary) -> int:
	if not item["kind"] in ["economy_building", "production", "habitation", "pds"]:
		return -1
	var bodies: Array = system_bodies(state["planets"][index], int(state["map"].get("seed", 0)), index)
	if bodies.is_empty():
		return -1
	if item["kind"] == "pds":
		return clampi(int(item["target"]), 0, bodies.size() - 1)
	var resource: String = "Organics" if item["kind"] == "habitation" else str(item["target"])
	for slot in range(bodies.size()):
		if bodies[slot]["resource"] == resource:
			return slot
	return 0

static func _work_upgrade_deliveries(state: Dictionary, index: int, p: Dictionary, dt: float) -> void:
	for item in p["queue"].duplicate():
		if not item.has("delivery_slot"):
			continue
		item["delivery_remaining"] = maxf(0.0, float(item["delivery_remaining"]) - dt)
		if float(item["delivery_remaining"]) <= EPS:
			_finish(state, index, p, item)

static func station_construction_job(p: Dictionary) -> Dictionary:
	for item in p["queue"]:
		if int(item["size"]) == 0 and item["kind"] != "yard_upgrade" and not item.has("delivery_slot"):
			return item
	return {}

static func _work_station_queue(state: Dictionary, index: int, p: Dictionary, dt: float) -> void:
	# Infrastructure shares one FIFO production lane per station, separate
	# from its shipyards. Spend only unused time on the next job.
	var remaining: float = dt
	while remaining > EPS:
		var item: Dictionary = station_construction_job(p)
		if item.is_empty():
			break
		var before: float = float(item["progress"])
		if not _advance(p, item, remaining):
			break
		remaining = maxf(0.0, remaining - (float(item["progress"]) - before))
		if item["kind"] == "yard" and int(item["level"]) != (p["yards"] as Array).size() + 1:
			break
		var slot: int = planetary_upgrade_slot(state, index, item)
		if slot >= 0:
			item["delivery_slot"] = slot
			item["delivery_remaining"] = PLANET_UPGRADE_DELIVERY_TIME
		else:
			_finish(state, index, p, item)

static func _work_planet(state: Dictionary, index: int, dt: float) -> void:
	var p: Dictionary = state["planets"][index]
	if int(p["owner"]) == 0 or not has_station(p):
		return
	p["flows"] = {}
	p["flow_dt"] = dt
	p["crew_rate"] = 0.0
	var before_population: float = float(p["population"])
	var elapsed: float = float(state["elapsed"])
	p["farm_factor"] = 1.0 + FARM_VARIATION * sin(TAU * elapsed / FARM_CYCLE_SECONDS + float(p["farm_phase"]))
	_update_population(p, dt)
	p["demographic_rate"] = (float(p["population"]) - before_population) / maxf(EPS, dt)
	# Residents consume Metals and Organics. Only net surplus can occupy
	# free storage. At capacity production covers demand but stores no excess.
	# Refunds may temporarily exceed capacity; never destroy returned materials.
	var capacity: float = storage_capacity(p)
	var tier: int = int(p.get("warehouse_level", 0))
	var next_costs: Dictionary = WAREHOUSE_COSTS[tier] if tier < WAREHOUSE_COSTS.size() else {}
	for resource in ACTIVE_PRODUCTION:
		var stored: float = float(p["stock"][resource])
		var potential: float = rate(p, resource) * dt
		var demand: float = consumption(p, resource) * dt
		var reserve: float = capacity * float(p["thresholds"][resource]["min"]) / 100.0
		var used: float = minf(demand, minf(maxf(0.0, stored), reserve) + potential)
		if resource != "Organics" and potential > EPS and demand > potential and stored < minf(capacity, maxf(CONSTRUCTION_RESERVE, float(next_costs.get(resource, 0.0)))):
			used = minf(used, potential * (1.0 - CONSTRUCTION_PRODUCTION_SHARE))
		var produced: float = minf(potential, used + maxf(0.0, capacity - stored))
		_record_flow(p, "Production", resource, produced)
		var progress: Dictionary = objective_progress(state, int(p["owner"]))
		var metric: String = "produced_" + resource.to_lower()
		progress[metric] = float(progress.get(metric, 0.0)) + produced
		_record_flow(p, "Population", resource, used)
		p["stock"][resource] = maxf(0.0, stored + produced - used)
	_work_upgrade_deliveries(state, index, p, dt)
	_work_station_queue(state, index, p, dt)
	_refill_yard_autobuild(state, index, p)
	_refill_continuous(state, index, p)
	for category in p.get("pending_spending", {}):
		for material in p["pending_spending"][category]:
			_record_flow(p, str(category), str(material), float(p["pending_spending"][category][material]))
	p.erase("pending_spending")
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
			if item["kind"] == "yard_upgrade" or (int(item["size"]) > 0 and _possible(p, item, y) > EPS):
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
				# Earlier yards may have recruited population this tick.
				if _possible(p, item, y) > EPS:
					chosen = item
				else:
					assigned.erase(int(item["id"]))
					yard["job"] = -1
				break
		if chosen.is_empty():
			# Repeat hulls take turns in queue order, even if the next one
			# is waiting for materials. Otherwise cheap hulls can repeatedly
			# leapfrog a more expensive one and starve it. Manual orders and
			# targeted upgrades retain their existing eligibility rules.
			var repeat_seen: bool = false
			var queue_full: bool = shipyard_queue_count(p, y) >= SHIPYARD_QUEUE_LIMIT
			for item in p["queue"]:
				if assigned.has(int(item["id"])):
					continue
				var upgrade: bool = item["kind"] == "yard_upgrade" and int(item["target"]) == y
				var pinned: int = int(item.get("yard_slot", -1))
				var hull: bool = int(item["size"]) > 0 and int(item["size"]) <= max_size(int(yard["level"])) and (pinned < 0 or pinned == y)
				if hull and pinned < 0 and queue_full:
					continue
				# A population-blocked order never occupies the active slot,
				# even when explicitly pinned to this yard. Keep it queued.
				var possible: bool = (upgrade or hull) and _possible(p, item, y) > EPS
				if hull and not possible:
					continue
				if hull and bool(item.get("automatic", false)):
					if repeat_seen:
						continue
					repeat_seen = true
				if possible:
					chosen = item
					break
		if chosen.is_empty():
			yard["job"] = -1
			continue
		var id: int = int(chosen["id"])
		yard["job"] = id
		assigned[id] = true
		var speed: float = 1.0 if chosen["kind"] == "yard_upgrade" else yard_speed(int(yard["level"]))
		if _advance(p, chosen, speed * dt, y):
			_finish(state, index, p, chosen)
			yard["job"] = -1

static func _cargo_total(ship: Dictionary) -> float:
	var total: float = 0.0
	var cargo: Dictionary = ship.get("cargo", {})
	for r in RESOURCES:
		total += float(cargo.get(r, 0.0))
	return total + float(cargo.get(ANTIMATTER, 0.0))

static func cargo_capacity(kind: String) -> float:
	match kind:
		"miner": return MINER_CAPACITY
		"science_ship": return SCIENCE_CAPACITY
		"fighter", "scout", "cruiser", "destroyer", "warp_gate": return 0.0
		"colony_ship": return COLONY_CAPACITY
	return CARGO_CAPACITY

static func cargo_free(ship: Dictionary) -> float:
	return maxf(0.0, cargo_capacity(str(ship.get("kind", "ship"))) - _cargo_total(ship))

# Pack the shared tonnage into equal display bays, not resource-specific limits.
static func freighter_cargo_bays(cargo: Dictionary) -> Array:
	return cargo_bays(cargo, CARGO_CAPACITY, FREIGHTER_BAY_COUNT)

static func cargo_bays(cargo: Dictionary, capacity: float, count: int) -> Array:
	var bays: Array = []
	var occupied: float = 0.0
	var bay_capacity: float = capacity / float(count)
	for index in range(count):
		bays.append([])
	var bay: int = 0
	for resource in RESOURCES + [ANTIMATTER]:
		var remaining: float = maxf(0.0, float(cargo.get(resource, 0.0)))
		while remaining > EPS and bay < count:
			var amount: float = minf(remaining, bay_capacity - occupied)
			bays[bay].append({"resource": resource, "amount": amount})
			remaining -= amount
			occupied += amount
			if occupied >= bay_capacity - EPS:
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

# Transit is not permission to use another empire's stockpile.
static func _civilian_transit_allowed(state: Dictionary, group: int, sector_group: int) -> bool:
	if state.has("diplomacy"):
		return not empires_hostile(state, group, sector_group)
	return sector_group in [0, group]

static func _civilian_access(state: Dictionary, teams: Array[int], group: int) -> Array[int]:
	var access: Array[int] = []
	for sector_group in teams:
		access.append(group if _civilian_transit_allowed(state, group, sector_group) else sector_group)
	return access

static func _civilian_route_safe(state: Dictionary, ship: Dictionary, teams: Array[int], group: int) -> bool:
	for waypoint in ship.get("route", []):
		if int(waypoint) != int(ship["at"]) and not _civilian_transit_allowed(state, group, teams[int(waypoint)]):
			return false
	return true

static func _path(state: Dictionary, teams: Array[int], team: int, a: int, b: int, _cache: Dictionary) -> Array[int]:
	var routes: Dictionary = _cache["civilian_routes"] if _cache.has("civilian_routes") else _civilian_route_cache(state, teams)
	var key: String = "%d:%d:%d" % [team, a, b]
	if not routes.has(key):
		var access: Array[int] = _civilian_access(state, teams, team) if state.has("diplomacy") else teams
		routes[key] = MAP.path(state["map"], access, team, a, b)
	var result: Array[int] = []
	result.assign(routes[key])
	return result

static func _civilian_route_cache(state: Dictionary, teams: Array[int]) -> Dictionary:
	var map_data: Dictionary = state["map"]
	if cached_route_topology.get("points") != map_data["points"] or cached_route_topology.get("edges") != map_data["edges"] or cached_route_topology.get("teams") != teams or bool(cached_route_topology.get("bilateral", false)) != state.has("diplomacy") or cached_route_topology.get("diplomacy", {}) != state.get("diplomacy", {}):
		cached_civilian_routes = {}
		cached_route_topology = {"points": map_data["points"].duplicate(), "edges": map_data["edges"].duplicate(true), "teams": teams.duplicate(), "bilateral": state.has("diplomacy"), "diplomacy": state.get("diplomacy", {}).duplicate(true)}
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

# Build once from the common pre-movement positions, not once per hull.
static func _begin_ship_avoidance(positions: Dictionary) -> void:
	avoidance_cells.clear()
	for id in positions:
		var point: Vector2 = positions[id]
		var cell := Vector2i(floori(point.x / AVOIDANCE_CELL), floori(point.y / AVOIDANCE_CELL))
		if not avoidance_cells.has(cell):
			avoidance_cells[cell] = []
		# Bound worst-case work in dense swarms; contact correction remains soft.
		if avoidance_cells[cell].size() < AVOIDANCE_BUCKET_LIMIT:
			avoidance_cells[cell].append([id, point])

static func _avoidance_direction(ship: Dictionary, target: Vector2, budget: float) -> Vector2:
	var before: Vector2 = ship["position"]
	var distance: float = before.distance_to(target)
	var axis: Vector2 = before.direction_to(target)
	if avoidance_cells.is_empty() or budget <= EPS or distance <= SHIP_CLEARANCE * 0.5 or bool(ship.get("holding", false)):
		return axis
	var lookahead: float = minf(distance, AVOIDANCE_LOOKAHEAD)
	var cell := Vector2i(floori(before.x / AVOIDANCE_CELL), floori(before.y / AVOIDANCE_CELL))
	var nearest: float = INF
	var blocker: Vector2 = Vector2.ZERO
	for x in range(-1, 2):
		for y in range(-1, 2):
			for entry in avoidance_cells.get(cell + Vector2i(x, y), []):
				if int(entry[0]) == int(ship["id"]):
					continue
				var other: Vector2 = entry[1]
				# Shared endpoints must remain reachable: leave final precision
				# docking, extraction, formation and hold to their existing rules.
				if other.distance_squared_to(target) <= SHIP_CLEARANCE * SHIP_CLEARANCE:
					continue
				var offset: Vector2 = other - before
				var forward: float = offset.dot(axis)
				if forward <= EPS or forward > lookahead or absf(axis.cross(offset)) >= SHIP_CLEARANCE:
					continue
				if forward < nearest:
					nearest = forward
					blocker = offset
	if nearest == INF:
		return axis
	# Steer toward a tangent on the open side. A centered head-on contact
	# always passes on the ship's own right; no symmetric stop or hard wall.
	var lateral: float = axis.cross(blocker)
	var side: float = -1.0 if lateral > 1.0 else 1.0
	var tangent: float = asin(clampf(SHIP_CLEARANCE / maxf(SHIP_CLEARANCE, blocker.length()), 0.0, 1.0))
	var turn: float = axis.angle_to(blocker) + side * (tangent + 0.12)
	return axis.rotated(clampf(turn, -PI * 0.42, PI * 0.42))

# The only movement integrator. Orders change targets, never current position.
# Return the distance actually flown so a tick cannot exceed its travel budget.
static func _navigate(ship: Dictionary, target: Vector2, budget: float) -> float:
	ship["navigation_target"] = target
	var before: Vector2 = ship["position"]
	var direct: Vector2 = before.direction_to(target)
	var steering: Vector2 = _avoidance_direction(ship, target, budget)
	var after: Vector2 = before.move_toward(target, maxf(0.0, budget))
	if not steering.is_equal_approx(direct):
		after = before + steering * minf(maxf(0.0, budget), before.distance_to(target))
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

static func _service_point(state: Dictionary, ship: Dictionary, index: int) -> Vector2:
	if state.has("planets") and has_station(state["planets"][index]):
		var owner: int = int(state["planets"][index]["owner"])
		if _cargo_target_allowed(state, int(ship["owner"]), {"owner": owner}):
			return station_position(state, index, float(state["elapsed"]))
	return state["map"]["points"][index]

static func ship_speed(kind: String) -> float:
	match kind:
		"warp_gate": return 0.0
		"miner": return MINER_SPEED
		"ship": return FREIGHTER_SPEED
		"fighter": return FIGHTER_SPEED
		"scout": return FIGHTER_SPEED * 2.0
		"cruiser": return FIGHTER_SPEED * 0.8
		"destroyer": return FIGHTER_SPEED * 0.6
	return SHIP_SPEED

static func _waiting_berth(state: Dictionary, ship: Dictionary, center: Vector2, reach: float, preferred: Vector2) -> Vector2:
	var axis: Vector2 = preferred.normalized()
	if axis.is_zero_approx():
		axis = Vector2.from_angle(float(int(ship["id"]) % 24) * TAU / 24.0)
	# Long-distance approaches need no berth search until they reach the dock.
	if (ship["position"] as Vector2).distance_to(center) > reach * 3.0:
		return center + axis * reach * 0.9
	var nearby: Array[Vector2] = []
	for other in state.get("ships", []):
		if int(other["id"]) == int(ship["id"]) or not other.has("position"):
			continue
		var point: Vector2 = other["position"]
		if point.distance_squared_to(center) <= pow(reach + SHIP_CLEARANCE, 2.0):
			nearby.append(point)
	var best: Vector2 = center + axis * reach * 0.9
	var best_score: float = INF
	for slot in range(12):
		var candidate: Vector2 = center + axis.rotated(float(slot) * TAU / 12.0) * reach * 0.9
		var score: float = candidate.distance_to(center + axis * reach * 0.9)
		for point in nearby:
			score += maxf(0.0, SHIP_CLEARANCE - candidate.distance_to(point)) * 24.0
		if score < best_score:
			best_score = score
			best = candidate
	return best

static func _move(state: Dictionary, ship: Dictionary, dt: float, explicit_dock: Vector2 = Vector2.INF, dock_index: int = -1, dock_range: float = 0.0) -> bool:
	var route: Array = ship["route"]
	var points: Array = state["map"]["points"]
	_ensure_position(points, ship)
	var distance: float = ship_speed(str(ship.get("kind", "ship"))) * dt
	while not route.is_empty() and distance > EPS:
		var node: int = int(route[0])
		var next: Vector2 = points[node]
		if route.size() == 1:
			if explicit_dock.is_finite() and node == dock_index:
				next = explicit_dock
			elif ship.get("kind", "") not in ["fighter", "scout", "cruiser", "destroyer"] and (int(ship.get("source", -1)) == node or int(ship.get("dest", -1)) == node or ship.get("mining_mode", "") == "approach"):
				next = _service_point(state, ship, node)
		var service: bool = route.size() == 1 and ((explicit_dock.is_finite() and node == dock_index) or (state.has("planets") and node < state["planets"].size() and has_station(state["planets"][node]) and next == _service_point(state, ship, node)))
		var endpoint: Vector2 = _waiting_berth(state, ship, next, dock_range, next.direction_to(ship["position"])) if service and dock_range > EPS else next
		distance -= _navigate(ship, endpoint, distance)
		if (ship["position"] as Vector2).distance_to(next) > (dock_range if service else 0.0) + EPS:
			ship["leg"] = _lane_progress(points, ship)
			return false
		ship["at"] = int(route.pop_front())
		ship["leg"] = 0.0
	if not route.is_empty():
		return false
	var here: int = int(ship["at"])
	var approach: bool = ship.get("mining_mode", "") == "approach"
	var dock_required: bool = int(ship.get("source", -1)) == here or int(ship.get("dest", -1)) == here or approach
	if dock_required and ship.get("kind", "") not in ["fighter", "scout", "cruiser", "destroyer"]:
		var dock: Vector2 = explicit_dock if explicit_dock.is_finite() and here == dock_index else _service_point(state, ship, here)
		var endpoint: Vector2 = _waiting_berth(state, ship, dock, dock_range, dock.direction_to(ship["position"])) if dock_range > EPS and (explicit_dock.is_finite() or (state.has("planets") and has_station(state["planets"][here]))) else dock
		_navigate(ship, endpoint, distance)
		return (ship["position"] as Vector2).distance_to(dock) <= (dock_range if explicit_dock.is_finite() or (state.has("planets") and has_station(state["planets"][here])) else 0.0) + EPS
	return true

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
		if teams[i] != team or not has_station(planets[i]):
			continue
		var useful: bool = false
		for resource in RESOURCES + [ANTIMATTER]:
			var capacity: float = storage_free(planets[i], resource) if resource == ANTIMATTER and int(planets[i]["owner"]) == int(ship["owner"]) else (0.0 if resource == ANTIMATTER else _need(planets[i], resource))
			if float(ship["cargo"].get(resource, 0.0)) > EPS and capacity > EPS:
				useful = true
				break
		if not useful:
			continue
		var path: Array[int] = _path(state, teams, team, int(ship["at"]), i, cache)
		if path.is_empty():
			continue
		var distance: float = MAP.route_length(state["map"], path)
		if distance < best:
			best = distance
			best_dest = i
			best_path = path
	ship["dest"] = best_dest
	if best_dest >= 0:
		_set_route(ship, best_path)

# Local autonomous resource collection uses the existing safe civilian lanes
# and the physical salvage-delivery path. Never reserve or teleport inventory.
static func _clear_resource_stage(ship: Dictionary) -> void:
	if ship.has("resource_stage"):
		ship.erase("resource_stage")
		ship["route"] = []
		ship["leg"] = 0.0
		ship["dest"] = -1
		ship["source"] = -1
	ship.erase("resource_loaded_at")

static func _resource_haul(ship: Dictionary) -> void:
	_clear_resource_stage(ship)
	if _cargo_total(ship) > EPS:
		ship["resource_haul"] = true
		ship["salvage_delivery"] = true
		ship.erase("salvage_depot")
		ship.erase("next_salvage_search")

static func _stage_wait_point(state: Dictionary, graph: Dictionary, ship: Dictionary, rock: Vector2, node: int, anchor: int, threats: Dictionary) -> Vector2:
	var entry: Vector2 = _service_point(state, ship, anchor)
	var toward: Vector2 = rock.direction_to(entry)
	if toward.is_zero_approx():
		toward = Vector2.RIGHT
	# Leave breathing room for contact pushes and small miner movements.
	var offset: Vector2 = _waiting_berth(state, ship, rock, RESOURCE_HANDOFF_RANGE, toward)
	if _salvage_safe(state, graph, int(ship["owner"]), offset, local_sector(graph, ship) if node < 0 else node, threats):
		return offset
	return rock

static func _stage_candidate(state: Dictionary, graph: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, threats: Dictionary, node: int, anchor: int, point: Vector2, resources: Array, demand: float) -> Dictionary:
	var owner: int = int(ship["owner"])
	var team: int = _combat_group(state, owner)
	if not _salvage_safe(state, graph, owner, point, node, threats) or _hostile_system(state, owner, anchor):
		return {}
	var path: Array[int] = _mining_path(state, teams, team, int(ship["at"]), anchor, cache)
	if path.is_empty():
		return {}
	var depot_exists: bool = false
	for resource in resources:
		if _mining_depot(state, ship, teams, team, anchor, str(resource), cache) >= 0:
			depot_exists = true
			break
	if not depot_exists:
		return {}
	var distance: float = MAP.route_length(state["map"], path) + (state["map"]["points"][anchor] as Vector2).distance_to(point)
	if int(ship["at"]) == anchor:
		distance = (ship["position"] as Vector2).distance_to(point)
	return {"node": node, "anchor": anchor, "point": point, "path": path, "score": distance / maxf(1.0, demand)}

static func _choose_resource_stage(state: Dictionary, graph: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, threats: Dictionary, cells: Dictionary) -> bool:
	var owner: int = int(ship["owner"])
	var best: Dictionary = {}
	var best_score: float = INF
	var fields: Array = state["map"].get("fields", [])
	var count: int = state["planets"].size()
	var workers: Dictionary = {}
	var occupied: Dictionary = {}
	for other in state["ships"]:
		if int(other["owner"]) != owner or int(other["id"]) == int(ship["id"]):
			continue
		if other.has("resource_stage"):
			var assigned: int = int(other["resource_stage"]["node"])
			occupied[assigned] = int(occupied.get(assigned, 0)) + 1
		if other.get("kind", "") == "miner" and int(other.get("field", -1)) >= 0 and other.get("mining_mode", "") in ["approach", "outbound", "mining", "return"] and not bool(other.get("holding", false)):
			var field_index: int = int(other["field"])
			if not workers.has(field_index):
				workers[field_index] = []
			workers[field_index].append(other)
	for i in range(fields.size()):
		if not discovered(state, owner, "fields", i):
			continue
		var field: Dictionary = fields[i]
		var resources: Array[String] = []
		var inventory: Dictionary = field_inventory(field)
		for resource in _mining_resources(state, owner, i):
			if float(inventory.get(resource, 0.0)) > EPS:
				resources.append(resource)
		if resources.is_empty():
			continue
		var point: Vector2 = field["position"]
		var active: Array = workers.get(i, [])
		if not active.is_empty():
			# Rendezvous at the actual mining position, not the anchor star.
			var nearest: float = INF
			for miner in active:
				var target: Vector2 = miner.get("mining_target", point)
				var distance: float = (ship["position"] as Vector2).distance_squared_to(target)
				if distance < nearest:
					nearest = distance
					point = target
		var demand: float = 1.0 + float(active.size()) * 2.0
		demand /= 1.0 + float(occupied.get(count + i, 0)) * 4.0
		for anchor in field_access_systems(state["map"], field):
			var wait_point: Vector2 = _stage_wait_point(state, graph, ship, point, count + i, anchor, threats)
			var candidate: Dictionary = _stage_candidate(state, graph, ship, teams, cache, threats, count + i, anchor, wait_point, resources, demand)
			if not candidate.is_empty() and float(candidate["score"]) < best_score:
				best = candidate
				best_score = float(candidate["score"])
	# Group nearby debris into a site. Each pile counts once, and the
	# threshold is a full logistics hold, not an individual small fragment.
	var piles: Dictionary = state.get("salvage", {})
	for cell in cells:
		var total: float = 0.0
		var resources: Array = []
		var point: Vector2 = Vector2.ZERO
		for id in cells[cell]:
			if not piles.has(id):
				continue
			var pile: Dictionary = piles[id]
			var amount: float = float(pile["amount"])
			total += amount
			point += (pile["position"] as Vector2) * amount
			if not resources.has(pile["resource"]):
				resources.append(pile["resource"])
		if total < CARGO_CAPACITY - EPS:
			continue
		point /= total
		var node: int = patrol_node(state, graph, owner, point)
		if node < 0:
			continue
		var anchor: int = node if node < count else int(fields[node - count]["anchor"])
		var demand: float = 2.0 / (1.0 + float(occupied.get(node, 0)) * 4.0)
		var candidate: Dictionary = _stage_candidate(state, graph, ship, teams, cache, threats, node, anchor, point, resources, demand)
		if not candidate.is_empty() and float(candidate["score"]) < best_score:
			best = candidate
			best_score = float(candidate["score"])
			best["salvage_site"] = true
	if best.is_empty():
		return false
	var path: Array[int] = best["path"]
	best.erase("path")
	best.erase("score")
	ship["resource_stage"] = best
	ship["source"] = -1
	ship["dest"] = -1
	_set_route(ship, path)
	ship["navigation_target"] = best["point"]
	return true

static func _work_resource_stage(state: Dictionary, graph: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, threats: Dictionary, cells: Dictionary, busy: Dictionary, dt: float) -> bool:
	if ship.get("kind", "") != "ship":
		return false
	var stage: Dictionary = ship.get("resource_stage", {})
	if stage.is_empty():
		return false
	var owner: int = int(ship["owner"])
	var point: Vector2 = stage["point"]
	var node: int = int(stage["node"])
	var team: int = _combat_group(state, owner)
	var safe: bool = _salvage_safe(state, graph, owner, point, node, threats) and _salvage_safe(state, graph, owner, ship["position"], local_sector(graph, ship), threats)
	for waypoint in ship["route"]:
		if not _civilian_transit_allowed(state, team, teams[int(waypoint)]):
			safe = false
			break
	if not safe or not autocast_ready(state, ship, "trade") or bool(ship.get("holding", false)) or _unit_order_running(ship) or not ship.get("order_queue", []).is_empty():
		_clear_resource_stage(ship)
		if safe and autocast_ready(state, ship, "trade") and not bool(ship.get("holding", false)) and not _unit_order_running(ship) and ship.get("order_queue", []).is_empty() and _cargo_total(ship) > EPS:
			_resource_haul(ship)
			return true
		if not safe and (not _civilian_transit_allowed(state, team, teams[int(ship["at"])]) if state.has("diplomacy") else teams[int(ship["at"])] != team):
			_evacuate_civilian(state, ship, teams)
		return false
	var now: float = float(state["elapsed"])
	if _cargo_total(ship) > EPS:
		if not ship.has("resource_loaded_at"):
			ship["resource_loaded_at"] = now
		if cargo_free(ship) <= EPS or now - float(ship["resource_loaded_at"]) >= RESOURCE_PARTIAL_WAIT_YEARS:
			_resource_haul(ship)
			return true
	if now >= float(ship.get("next_resource_stage_search", 0.0)):
		ship["next_resource_stage_search"] = _next_search_slot(now, int(ship["id"]), RESOURCE_STAGE_SEARCH_YEARS)
		var available: bool = false
		if bool(stage.get("salvage_site", false)):
			var piles: Dictionary = state.get("salvage", {})
			for id in piles:
				if (piles[id]["position"] as Vector2).distance_to(point) <= SALVAGE_APPROACH_RANGE and float(piles[id]["amount"]) > EPS:
					available = true
					break
		else:
			var field_index: int = node - state["planets"].size()
			var fields: Array = state["map"].get("fields", [])
			if field_index >= 0 and field_index < fields.size():
				var inventory: Dictionary = field_inventory(fields[field_index])
				for resource in _mining_resources(state, owner, field_index):
					if float(inventory.get(resource, 0.0)) > EPS:
						available = true
						break
				# Follow local miners as they change rocks; keep a reachable
				# point and let the same physical handoff range do the work.
				var nearest: float = INF
				for miner in state["ships"]:
					if int(miner["owner"]) != owner or miner.get("kind", "") != "miner" or int(miner.get("field", -1)) != field_index or miner.get("mining_mode", "") not in ["outbound", "mining"] or bool(miner.get("holding", false)):
						continue
					var target: Vector2 = miner.get("mining_target", point)
					var wait_point: Vector2 = _stage_wait_point(state, graph, ship, target, node, int(stage["anchor"]), threats)
					var distance: float = (ship["position"] as Vector2).distance_squared_to(wait_point)
					if distance < nearest and _salvage_safe(state, graph, owner, wait_point, node, threats):
						nearest = distance
						point = wait_point
				stage["point"] = point
				ship["navigation_target"] = point
		if not available:
			if _cargo_total(ship) > EPS:
				_resource_haul(ship)
			else:
				_clear_resource_stage(ship)
			return true
		# Existing trade work takes priority over waiting with an empty hold.
		if _cargo_total(ship) <= EPS and ship["route"].is_empty() and teams[int(ship["at"])] == team:
			_choose_delivery(state, ship, teams, team, cache)
			if int(ship.get("source", -1)) >= 0:
				ship.erase("resource_stage")
				ship.erase("resource_loaded_at")
				return true
	if not ship["route"].is_empty():
		_move(state, ship, dt)
	else:
		_navigate(ship, point, minf(ship_speed(str(ship.get("kind", "ship"))) * dt, (ship["position"] as Vector2).distance_to(point)))
		# A staged logistics ship can still collect debris in beam range,
		# but at its reduced rate. It waits for miners rather than chasing.
		_work_opportunistic_salvage(state, graph, ship, dt, busy, cells, false, threats)
	return true

static func _dropoff_budget(ship: Dictionary, dt: float) -> float:
	return maxf(0.0, dropoff_rate(str(ship["kind"])) * maxf(0.0, dt) - float(ship.get("_handoff_sent", 0.0)))

static func dropoff_rate(kind: String) -> float:
	match kind:
		"miner": return 120.0 # Independent of extraction balance.
		"ship": return FREIGHTER_TRACTOR_RATE * 20.0
		"colony_ship": return COLONY_FARM_RATE * 20.0
	return TRACTOR_RATE * 20.0

# Build once before movement; entries retain authoritative fleet order.
static func _handoff_candidates(cells: Dictionary, point: Vector2) -> Array:
	var cell := Vector2i(floori(point.x / RESOURCE_HANDOFF_RANGE), floori(point.y / RESOURCE_HANDOFF_RANGE))
	var ordered: Array = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			for entry in cells.get(cell + Vector2i(x, y), []):
				ordered.append(entry)
	ordered.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var result: Array = []
	for entry in ordered:
		result.append(entry[1])
	return result

static func _miner_handoff(state: Dictionary, graph: Dictionary, miner: Dictionary, receivers: Array, threats: Dictionary, dt: float) -> float:
	if miner.get("kind", "") != "miner" or _cargo_total(miner) <= EPS or bool(miner.get("retreating", false)) or _engaged(miner) or miner.has("repair_order"):
		return 0.0
	var owner: int = int(miner["owner"])
	var point: Vector2 = miner["position"]
	if not _salvage_safe(state, graph, owner, point, local_sector(graph, miner), threats):
		return 0.0
	var total: float = 0.0
	var budget: float = _dropoff_budget(miner, dt)
	for freighter in receivers:
		if int(freighter["owner"]) != owner or freighter.get("kind", "") != "ship" or not autocast_enabled(freighter, "trade") or bool(freighter.get("retreating", false)) or _engaged(freighter) or freighter.has("cargo_order"):
			continue
		if (freighter["position"] as Vector2).distance_to(point) > RESOURCE_HANDOFF_RANGE or not _salvage_safe(state, graph, owner, freighter["position"], local_sector(graph, freighter), threats):
			continue
		for resource in RESOURCES + [ANTIMATTER]:
			var amount: float = minf(budget - total, minf(cargo_free(freighter), float(miner["cargo"].get(resource, 0.0))))
			if amount <= EPS:
				continue
			_record_transfer(state, int(miner["id"]), miner, int(freighter["id"]), freighter, resource, amount)
			miner["cargo"][resource] -= amount
			freighter["cargo"][resource] = float(freighter["cargo"].get(resource, 0.0)) + amount
			total += amount
			if freighter.has("resource_stage"):
				freighter["resource_loaded_at"] = float(state["elapsed"])
		if freighter.has("resource_stage") and cargo_free(freighter) <= EPS:
			_resource_haul(freighter)
		if _cargo_total(miner) <= EPS or total >= budget - EPS:
			break
	var emptied: bool = total > EPS and _cargo_total(miner) <= EPS
	var idle_delivery: bool = emptied and miner.get("mining_mode", "idle") == "idle" and not _unit_order_running(miner) and not bool(miner.get("holding", false)) and not bool(miner.get("move_only", false)) and not miner.has("local_move_target") and not miner.has("launch_rally")
	if total > EPS and (miner.has("cargo_order") or bool(miner.get("salvage_delivery", false)) or miner.get("mining_mode", "") in ["return", "delivery"] or idle_delivery):
		_cancel_salvage_order(miner)
		miner.erase("cargo_order")
		if miner.get("unit_order", {}).get("kind", "") in ["deposit", "drop", "unload"]:
			miner.erase("unit_order")
		_finish_manual(miner)
		miner["source"] = -1
		miner["field"] = -1
		miner["mining_mode"] = "delivery" if _cargo_total(miner) > EPS else "idle"
		miner["navigation_target"] = miner["position"]
		miner["next_mining_search"] = 0.0
		miner["next_unload_search"] = 0.0
		if emptied:
			# Reenter normal queued orders / repair / salvage / mining this step.
			miner.erase("_handoff_delivery")
			miner.erase("_next_repair_search")
		else:
			# Keep the shared transfer budget and defer a partial delivery.
			miner["_handoff_delivery"] = true
	return total

static func _work_ship(state: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, dt: float) -> void:
	var team: int = _combat_group(state, int(ship["owner"]))
	if state.has("diplomacy") and not _civilian_route_safe(state, ship, teams, team):
		_evacuate_civilian(state, ship, teams)
		return
	if not autocast_ready(state, ship, "trade"):
		if team != 0 and (not _civilian_transit_allowed(state, team, teams[int(ship["at"])]) if state.has("diplomacy") else teams[int(ship["at"])] != team):
			if not state.has("diplomacy") or ship["route"].is_empty():
				_evacuate_civilian(state, ship, teams)
			if not (ship["route"] as Array).is_empty():
				_move(state, ship, dt)
		return
	if team == 0 or not _move(state, ship, dt, Vector2.INF, -1, STATION_DOCK_RANGE):
		return
	var planets: Array = state["planets"]
	var here: int = int(ship["at"])
	if (not _civilian_transit_allowed(state, team, teams[here]) if state.has("diplomacy") else teams[here] != team):
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
			_record_transfer(state, station_target_id(state, here), planets[here], int(ship["id"]), ship, resource, amount)
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
		var budget: float = dropoff_rate("ship") * maxf(0.0, dt)
		for resource in RESOURCES + [ANTIMATTER]:
			var capacity: float = storage_free(planets[here], resource) if resource == ANTIMATTER and int(planets[here]["owner"]) == int(ship["owner"]) else (0.0 if resource == ANTIMATTER else _need(planets[here], resource))
			var amount: float = minf(budget, minf(float(ship["cargo"].get(resource, 0.0)), capacity))
			if amount <= EPS:
				continue
			_record_transfer(state, int(ship["id"]), ship, station_target_id(state, here), planets[here], resource, amount)
			ship["cargo"][resource] = float(ship["cargo"][resource]) - amount
			planets[here]["stock"][resource] = float(planets[here]["stock"].get(resource, 0.0)) + amount
			_record_flow(planets[here], "Imports", resource, amount)
			budget -= amount
		if budget <= EPS and _cargo_total(ship) > EPS:
			return
		ship["dest"] = -1
	if _cargo_total(ship) > EPS:
		_pick_loaded_destination(state, ship, teams, team, cache)
		# Import targets control trade demand, not whether existing cargo can be recovered.
		# If nobody requests this load, use the owned-storage delivery job.
		if int(ship["dest"]) < 0:
			_resource_haul(ship)
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
	if not _civilian_transit_allowed(state, team, teams[start]) or not _civilian_transit_allowed(state, team, teams[goal]):
		return []
	var cache: Dictionary = _cache["civilian_routes"] if _cache.has("civilian_routes") else _civilian_route_cache(state, teams)
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
				if visited.has(next) or not _civilian_transit_allowed(state, team, teams[next]):
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
	if field.has("access"):
		var access: Array[int] = []
		access.assign(field["access"])
		return access
	var points: Array = map_data["points"]
	var center: Vector2 = field["position"]
	var original: int = int(field["anchor"])
	var reach: float = center.distance_to(points[original]) * 1.5 + float(field.get("radius", 0.0))
	var result: Array[int] = []
	for i in range(points.size()):
		if i == original or center.distance_to(points[i]) <= reach + EPS:
			result.append(i)
	result.sort_custom(func(a: int, b: int) -> bool: return center.distance_squared_to(points[a]) < center.distance_squared_to(points[b]))
	result.resize(mini(result.size(), MAP.MAX_CONNECTIONS))
	return result

static func command_miners(state: Dictionary, player: int, ids: Array, field_index: int, chunk_id: int = -1) -> bool:
	if ids.is_empty() or not state["teams"].has(player) or field_index < -1 or chunk_id < -1 or (field_index == -1 and chunk_id != -1):
		return false
	var fields: Array = state["map"].get("fields", [])
	if field_index >= fields.size():
		return false
	var requested: Dictionary = {}
	for id in ids:
		if not id is int or requested.has(id):
			return false
		requested[id] = true
	var selected: Array = []
	for ship in state["ships"]:
		if requested.has(ship["id"]):
			if int(ship["owner"]) != player or ship.get("kind", "") != "miner":
				return false
			selected.append(ship)
	if selected.size() != requested.size():
		return false
	if field_index >= 0:
		if not discovered(state, player, "fields", field_index):
			return false
		var field: Dictionary = fields[field_index]
		var resources: Array[String] = _mining_resources(state, player, field_index)
		var useful: bool = false
		for chunk in field.get("chunks", []):
			if (chunk_id < 0 or int(chunk["id"]) == chunk_id) and resources.has(str(chunk["resource"])) and float(chunk["remaining"]) > EPS:
				useful = true
				break
		if not useful:
			return false
		var teams: Array[int] = planet_teams(state)
		var team: int = _combat_group(state, player)
		for ship in selected:
			var reachable: bool = false
			for anchor in field_access_systems(state["map"], field):
				if _mining_path(state, teams, team, int(ship["at"]), anchor, {}).is_empty():
					continue
				for depot in range(state["planets"].size()):
					if int(state["planets"][depot]["owner"]) == player and not _mining_path(state, teams, team, anchor, depot, {}).is_empty():
						reachable = true
						break
				if reachable:
					break
			if not reachable:
				return false
	for ship in selected:
		_cancel_salvage_order(ship)
		_clear_tactical_order(ship)
		_clear_local_hold(ship)
		_set_unit_order(state, ship, {"kind": "mine", "target": field_index, "chunk": chunk_id})
		ship["manual_mine"] = field_index >= 0
		ship["assigned_field"] = field_index
		ship["assigned_chunk"] = chunk_id
		ship["next_mining_search"] = 0.0
		# Preserve physical position, carried ore and the minimum extraction stay.
		if field_index >= 0 and (int(ship.get("field", -1)) != field_index or (chunk_id >= 0 and int(ship.get("chunk", -1)) != chunk_id)):
			var mode: String = str(ship.get("mining_mode", "idle"))
			if mode == "approach":
				var route: Array = ship["route"]
				if not route.is_empty():
					ship["route"] = route.slice(0, 1)
				ship["mining_mode"] = "delivery"
				ship["field"] = -1
			elif mode == "outbound":
				ship["mining_mode"] = "return"
	return true

static func _choose_field(state: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary) -> void:
	var fields: Array = state["map"].get("fields", [])
	var owner: int = int(ship["owner"])
	var team: int = _combat_group(state, owner)
	var best: float = INF
	var chosen: int = -1
	var best_path: Array[int] = []
	var best_chunk: Dictionary = {}
	var best_anchor: int = -1
	var assigned: int = int(ship.get("assigned_field", -1))
	var preferred: int = int(ship.get("assigned_chunk", -1))
	if assigned >= 0:
		var usable: bool = false
		var preferred_usable: bool = false
		for chunk in fields[assigned].get("chunks", []):
			if float(chunk["remaining"]) > EPS and _mining_resources(state, owner, assigned).has(str(chunk["resource"])):
				usable = true
				if int(chunk["id"]) == preferred:
					preferred_usable = true
		if not usable:
			assigned = -1
			ship["assigned_field"] = -1
		if not preferred_usable:
			preferred = -1
			ship["assigned_chunk"] = -1
	for i in range(fields.size()):
		if assigned >= 0 and i != assigned:
			continue
		var field: Dictionary = fields[i]
		if not discovered(state, owner, "fields", i) or _mining_resources(state, owner, i).is_empty():
			continue
		var access_key: String = "mine:access:%d" % i
		if not cache.has(access_key):
			cache[access_key] = field_access_systems(state["map"], field)
		# A viable entrance in the current system wins over a detour
		# through another system for this same field.
		var entrances: Array = cache[access_key].duplicate()
		var here: int = int(ship["at"])
		if entrances.has(here):
			entrances.erase(here)
			entrances.push_front(here)
		for anchor in entrances:
			var local_viable: bool = false
			var path: Array[int] = _mining_path(state, teams, team, int(ship["at"]), anchor, cache)
			if path.is_empty():
				continue
			var resources: Array[String] = _mining_resources(state, owner, i)
			var approach: Vector2 = _service_point(state, ship, anchor)
			var route_distance: float = MAP.route_length(state["map"], path)
			var depots: Dictionary = {}
			var return_distances: Dictionary = {}
			for resource in resources:
				var depot: int = _mining_depot(state, ship, teams, team, anchor, resource, cache)
				depots[resource] = depot
				if depot >= 0:
					return_distances[resource] = MAP.route_length(state["map"], _mining_path(state, teams, team, depot, anchor, cache))
			for chunk in field.get("chunks", []):
				if preferred >= 0 and int(chunk["id"]) != preferred:
					continue
				if not resources.has(str(chunk["resource"])) or float(chunk["remaining"]) <= EPS:
					continue
				var depot: int = int(depots.get(chunk["resource"], -1))
				if depot < 0:
					continue
				local_viable = true
				var distance: float = route_distance + approach.distance_to(chunk["position"]) * 2.0 + float(return_distances[chunk["resource"]])
				if distance < best:
					best = distance
					chosen = i
					best_path = path
					best_chunk = chunk
					best_anchor = anchor
			if anchor == here and local_viable:
				break
	if chosen >= 0:
		ship["field"] = chosen
		ship["mining_anchor"] = best_anchor
		ship["chunk"] = int(best_chunk["id"])
		var rock: Vector2 = best_chunk["position"]
		var radial: Vector2 = (_service_point(state, ship, best_anchor) - rock).normalized()
		if radial.is_zero_approx():
			radial = Vector2.RIGHT
		ship["mining_rock"] = rock
		ship["mining_target"] = rock + radial * (float(best_chunk.get("radius", 0.0)) + 12.0)
		ship["mining_mode"] = "approach"
		_set_route(ship, best_path)

# Align retries to stable hull-specific slots. Initial searches and explicit
# reset-to-zero requests remain immediate; subsequent retries are staggered.
static func _next_search_slot(now: float, id: int, interval: float) -> float:
	var phase: float = float(posmod(id, 5)) * interval / 5.0
	var next: float = floorf((now - phase) / interval) * interval + phase + interval
	if next <= now + EPS:
		next += interval
	return next

static func _work_miner(state: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, budgets: Array, dt: float) -> void:
	ship["mining_active"] = false
	var mode: String = str(ship.get("mining_mode", "idle"))
	if state.has("diplomacy"):
		var group: int = _combat_group(state, int(ship["owner"]))
		var hostile_here: bool = not _civilian_transit_allowed(state, group, teams[int(ship["at"])])
		if hostile_here and mode in ["outbound", "mining"]:
			ship["mining_mode"] = "return"
			mode = "return"
		elif mode in ["approach", "delivery", "idle"] and (not _civilian_route_safe(state, ship, teams, group) or (hostile_here and ship["route"].is_empty())):
			_evacuate_civilian(state, ship, teams)
			return
	if mode == "idle":
		if not bool(ship.get("manual_mine", false)) and not autocast_ready(state, ship, "mine"):
			return
		if (ship["route"] as Array).is_empty():
			ship["dest"] = -1
			ship["source"] = -1
		if float(state["elapsed"]) + EPS >= float(ship.get("next_mining_search", 0.0)):
			_choose_field(state, ship, teams, cache)
			if ship.get("mining_mode", "idle") == "idle" and int(ship.get("assigned_field", -1)) < 0:
				ship.erase("manual_mine")
			# Idle fleets retry twice per game year instead of every tick.
			ship["next_mining_search"] = _next_search_slot(float(state["elapsed"]), int(ship["id"]), 0.5)
		return
	if mode == "delivery":
		if _cargo_total(ship) <= EPS and not ship["route"].is_empty() and not _unit_order_running(ship):
			# Finish the current legal lane before selecting new work.
			if not _move(state, ship, dt, Vector2.INF, -1, STATION_DOCK_RANGE):
				return
		# A loaded miner with nowhere to unload can fly locally while
		# waiting for storage. Reacquire a reachable depot before docking;
		# never transfer cargo from an idle formation's position.
		if (ship["route"] as Array).is_empty() and int(ship.get("dest", -1)) < 0:
			var here: int = int(ship["at"])
			var team: int = _combat_group(state, int(ship["owner"]))
			# Even empty miners must keep retrying escape from hostile space.
			if not _civilian_transit_allowed(state, team, teams[here]):
				if float(state["elapsed"]) + EPS >= float(ship.get("next_unload_search", 0.0)):
					ship["next_unload_search"] = _next_search_slot(float(state["elapsed"]), int(ship["id"]), 0.5)
					_evacuate_civilian(state, ship, teams)
				return
			if _cargo_total(ship) <= EPS:
				ship["mining_mode"] = "idle"
				ship["field"] = -1
				return
			if float(state["elapsed"]) + EPS >= float(ship.get("next_unload_search", 0.0)):
				ship["next_unload_search"] = _next_search_slot(float(state["elapsed"]), int(ship["id"]), 0.5)
				for resource in RESOURCES + [ANTIMATTER]:
					if float(ship["cargo"].get(resource, 0.0)) <= EPS:
						continue
					var depot: int = _mining_depot(state, ship, teams, team, here, resource, cache)
					if depot >= 0:
						ship["dest"] = depot
						_set_route(ship, _mining_path(state, teams, team, here, depot, cache))
						break
			return
		if _move(state, ship, dt, Vector2.INF, -1, STATION_DOCK_RANGE):
			_unload_miner(state, ship, teams, cache, dt)
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
	var origin: Vector2 = _service_point(state, ship, anchor)
	var target: Vector2 = ship["mining_target"]
	var span: Vector2 = target - origin
	_ensure_position(state["map"]["points"], ship)
	if mode == "outbound":
		var chunk: Dictionary = _find_chunk(field, int(ship["chunk"]))
		if chunk.is_empty() or not _mining_resources(state, int(ship["owner"]), field_index).has(str(chunk["resource"])):
			ship["mining_mode"] = "return"
			return
		_navigate(ship, target, ship_speed(str(ship.get("kind", "ship"))) * dt)
		ship["field_leg"] = clampf(((ship["position"] as Vector2) - origin).dot(span) / maxf(EPS, span.length_squared()), 0.0, 1.0)
		if (ship["position"] as Vector2) == target:
			ship["mining_mode"] = "mining"
			ship["mining_years"] = 0.0
		return
	if mode == "mining":
		ship["mining_years"] = float(ship.get("mining_years", 0.0)) + dt
		# The same emitters cannot fire at a rock and a hostile hull at once.
		# Keep the assignment and resume extraction when the threat is gone.
		if _engaged(ship) or int(ship.get("yard_target", -1)) < -1:
			return
		var resources: Array[String] = _mining_resources(state, int(ship["owner"]), field_index)
		var chunk: Dictionary = _find_chunk(field, int(ship["chunk"]))
		var available: bool = not chunk.is_empty() and resources.has(str(chunk["resource"]))
		if available:
			var resource: String = str(chunk["resource"])
			var free: float = MINER_CAPACITY - _cargo_total(ship)
			var amount: float = minf(free, minf(float(chunk["remaining"]), minf(MINER_RATE * float(field[resource]) * dt, float(budgets[field_index][resource]))))
			ship["mining_active"] = amount > EPS
			_cargo_stat(ship, "tons_picked", resource, amount)
			ship["cargo"][resource] = float(ship["cargo"].get(resource, 0.0)) + amount
			chunk["remaining"] = maxf(0.0, float(chunk["remaining"]) - amount)
			budgets[field_index][resource] = maxf(0.0, float(budgets[field_index][resource]) - amount)
			if float(chunk["remaining"]) <= EPS:
				field["chunks"].erase(chunk)
				available = false
		var reassigned: bool = int(ship.get("assigned_field", -1)) >= 0 and (int(ship["assigned_field"]) != field_index or (int(ship.get("assigned_chunk", -1)) >= 0 and int(ship["assigned_chunk"]) != int(ship["chunk"])))
		if float(ship["mining_years"]) >= MINING_STAY - EPS and (reassigned or not available or _cargo_total(ship) >= MINER_CAPACITY - 0.1):
			ship["mining_mode"] = "return"
		return
	if mode == "return":
		_navigate(ship, origin, ship_speed(str(ship.get("kind", "ship"))) * dt)
		ship["field_leg"] = clampf(((ship["position"] as Vector2) - origin).dot(span) / maxf(EPS, span.length_squared()), 0.0, 1.0)
		if (ship["position"] as Vector2) == origin:
			ship["mining_mode"] = "delivery"
			_unload_miner(state, ship, teams, cache, dt)

static func _unload_miner(state: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, dt: float) -> void:
	var here: int = int(ship["at"])
	var owner: int = int(ship["owner"])
	var team: int = _combat_group(state, owner)
	var local: Dictionary = state["planets"][here]
	if not _civilian_transit_allowed(state, team, teams[here]):
		_evacuate_civilian(state, ship, teams)
		return
	if int(local["owner"]) == owner and has_station(local):
		var dock: Vector2 = station_position(state, here, float(state["elapsed"]))
		if _cargo_total(ship) > EPS and (ship["position"] as Vector2).distance_to(dock) > STATION_DOCK_RANGE + EPS:
			ship["dest"] = here
			return
		var budget: float = _dropoff_budget(ship, dt)
		for resource in RESOURCES + [ANTIMATTER]:
			var amount: float = minf(budget, minf(float(ship["cargo"].get(resource, 0.0)), storage_free(local, resource)))
			if amount <= 0.0:
				continue
			_record_transfer(state, int(ship["id"]), ship, station_target_id(state, here), local, resource, amount)
			local["stock"][resource] = float(local["stock"].get(resource, 0.0)) + amount
			_record_flow(local, "Mining deliveries", resource, amount)
			ship["cargo"][resource] -= amount
			budget -= amount
		if budget <= EPS and _cargo_total(ship) > EPS:
			ship["dest"] = here
			return
	if _cargo_total(ship) <= EPS:
		ship.erase("manual_mine")
		ship["mining_mode"] = "idle"
		ship["field"] = -1
		ship["dest"] = -1
		ship["next_mining_search"] = 0.0
		return
	for resource in RESOURCES + [ANTIMATTER]:
		if float(ship["cargo"].get(resource, 0.0)) <= EPS:
			continue
		var depot: int = _mining_depot(state, ship, teams, team, here, resource, cache)
		if depot >= 0 and depot != here:
			ship["dest"] = depot
			_set_route(ship, _mining_path(state, teams, team, here, depot, cache))
			return
	ship["dest"] = -1

static func military_home(state: Dictionary, player: int) -> int:
	var fallback: int = -1
	for i in range((state["planets"] as Array).size()):
		if int(state["planets"][i]["owner"]) != player or not has_station(state["planets"][i]):
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

const SECTOR_CORNER_ROUNDING: float = 0.32

static func sector_limit(graph: Dictionary, node: int, direction: Vector2) -> float:
	# Round the junction between the two tightest radial bounds inward.
	# Never expand beyond the nearest-POI bisector or the original disk.
	var limit: float = float(graph["sector_radii"][node])
	var second: float = INF
	var neighbors: Array = graph["sector_neighbors"][node]
	var squares: Array = graph["sector_neighbor_squares"][node] if graph.has("sector_neighbor_squares") else []
	for i in range(neighbors.size()):
		var delta: Vector2 = neighbors[i]
		var projection: float = direction.dot(delta)
		if projection > EPS:
			var bound: float = (float(squares[i]) if not squares.is_empty() else delta.length_squared()) / (2.0 * projection)
			if bound < limit:
				second = limit
				limit = bound
			else:
				second = minf(second, bound)
	var width: float = maxf(EPS, limit * SECTOR_CORNER_ROUNDING)
	var overlap: float = maxf(0.0, width - (second - limit))
	return limit - overlap * overlap / (4.0 * width)

static func sector_entry_point(graph: Dictionary, node: int, origin: Vector2) -> Vector2:
	var center: Vector2 = graph["points"][node]
	var direction: Vector2 = center.direction_to(origin)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	# A tiny inward inset avoids shared-edge ambiguity and floating-point jitter.
	return center + direction * maxf(0.0, sector_limit(graph, node, direction) - 1.0)

static var _sector_query_graph: Dictionary = {}
static var _sector_query_cache: Dictionary = {}

static func sector_contains(graph: Dictionary, node: int, position: Vector2) -> bool:
	if not is_same(graph, _sector_query_graph) or not position.is_finite():
		return _sector_contains_exact(graph, node, position)
	# Exact coordinates and node are the complete inputs to static containment.
	var key := Vector3(position.x, position.y, float(node))
	if not _sector_query_cache.has(key):
		_sector_query_cache[key] = _sector_contains_exact(graph, node, position)
	return bool(_sector_query_cache[key])

static func _sector_contains_exact(graph: Dictionary, node: int, position: Vector2) -> bool:
	var offset: Vector2 = position - (graph["points"][node] as Vector2)
	var radius: float = float(graph["sector_radii"][node]) + EPS
	var distance_squared: float = offset.length_squared()
	if distance_squared > radius * radius:
		return false
	# Every radial bisector is at least half its center separation away.
	# Rounding can shrink the tightest bound by at most width / 4.
	if graph.has("sector_inner_squared") and distance_squared < float(graph["sector_inner_squared"][node]):
		return true
	return offset.length() <= sector_limit(graph, node, offset.normalized()) + EPS

# Resolve a world point using the same clipped disks used by local orders.
# Prefer the current sector at an exact shared edge to avoid command jitter.
# Static broad phase: insert each sector into every cell touched by its
# bounding disk's AABB. Exact containment and tie-breaking remain unchanged.
static func _sector_candidates(graph: Dictionary, point: Vector2) -> Array:
	if not graph.has("sector_cells"):
		return range(graph["points"].size())
	var width: float = float(graph["sector_cell_width"])
	var cell := Vector2i(floori(point.x / width), floori(point.y / width))
	return graph["sector_cells"].get(cell, [])

static func _index_sector_bounds(graph: Dictionary, width: float) -> void:
	var cells: Dictionary = {}
	for i in range(graph["points"].size()):
		var center: Vector2 = graph["points"][i]
		var radius: float = float(graph["sector_radii"][i]) + EPS
		var low: Vector2 = (center - Vector2.ONE * radius) / width
		var high: Vector2 = (center + Vector2.ONE * radius) / width
		for x in range(floori(low.x), floori(high.x) + 1):
			for y in range(floori(low.y), floori(high.y) + 1):
				var cell := Vector2i(x, y)
				if not cells.has(cell):
					cells[cell] = []
				cells[cell].append(i)
	var inner_squared: Array = []
	for i in range(graph["points"].size()):
		var minimum: float = float(graph["sector_radii"][i])
		for delta in graph["sector_neighbors"][i]:
			minimum = minf(minimum, (delta as Vector2).length() * 0.5)
		var inner: float = maxf(0.0, minimum * (1.0 - SECTOR_CORNER_ROUNDING * 0.25) - EPS - 0.01)
		inner_squared.append(inner * inner)
	graph["sector_inner_squared"] = inner_squared
	graph["sector_cells"] = cells
	graph["sector_cell_width"] = width

static func sector_at(graph: Dictionary, position: Vector2, candidates: Array, preferred: int = -1) -> int:
	if not position.is_finite():
		return -1
	if preferred >= 0 and candidates.has(preferred) and sector_contains(graph, preferred, position):
		return preferred
	var hit: int = -1
	var best: float = INF
	var nearby: Array = _sector_candidates(graph, position)
	for candidate in nearby:
		var node: int = int(candidate)
		if not candidates.has(node) or not sector_contains(graph, node, position):
			continue
		var distance: float = position.distance_squared_to(graph["points"][node])
		if distance < best or (distance == best and node < hit):
			hit = node
			best = distance
	return hit

static func military_graph(state: Dictionary) -> Dictionary:
	var map_data: Dictionary = state["map"]
	# Match topology is immutable; resource quantities can change in place.
	if not cached_military_graph.is_empty() and is_same(cached_military_source, map_data):
		return cached_military_graph
	cached_military_source = map_data
	if not cached_military_graph.is_empty() and cached_military_map.get("points") == map_data["points"] and cached_military_map.get("edges") == map_data["edges"] and cached_military_map.get("field_positions") == _field_positions(map_data) and cached_military_map.get("field_edges") == map_data.get("field_edges", []) and cached_military_map.get("size") == map_data.get("size", MAP.SIZE):
		return cached_military_graph
	var points: Array = map_data["points"].duplicate()
	var edges: Array = map_data["edges"].duplicate()
	for field in state["map"].get("fields", []):
		for anchor in field_access_systems(state["map"], field):
			edges.append([anchor, points.size()])
		points.append(field["position"])
	var count: int = map_data["points"].size()
	for edge in map_data.get("field_edges", []):
		edges.append([count + int(edge[0]), count + int(edge[1])])
	var adjacent: Array = []
	for i in range(points.size()):
		adjacent.append([])
	for edge in edges:
		adjacent[edge[0]].append(edge[1])
		adjacent[edge[1]].append(edge[0])
	var base_radius: float = sector_base_radius(map_data)
	var sector_radii: Array[float] = []
	var sector_neighbors: Array = []
	var sector_neighbor_squares: Array = []
	for i in range(points.size()):
		var radius: float = base_radius if i < (map_data["points"] as Array).size() else base_radius * 0.68
		sector_radii.append(radius)
		var neighbors: Array[Vector2] = []
		var squares: Array[float] = []
		for j in range(points.size()):
			if i == j:
				continue
			var delta: Vector2 = points[j] - points[i]
			if delta.length_squared() < 4.0 * radius * radius and delta.length_squared() > EPS:
				neighbors.append(delta)
				squares.append(delta.length_squared())
		sector_neighbors.append(neighbors)
		sector_neighbor_squares.append(squares)
	cached_military_map = {"points": map_data["points"].duplicate(), "edges": map_data["edges"].duplicate(true), "field_positions": _field_positions(map_data), "field_edges": map_data.get("field_edges", []).duplicate(true), "size": map_data.get("size", MAP.SIZE)}
	cached_military_graph = {"points": points, "edges": edges, "adjacent": adjacent, "paths": {}, "sector_radii": sector_radii, "sector_neighbors": sector_neighbors, "sector_neighbor_squares": sector_neighbor_squares, "system_count": map_data["points"].size(), "map_size": map_data.get("size", MAP.SIZE)}
	_index_sector_bounds(cached_military_graph, base_radius)
	_index_navigation_junctions(cached_military_graph)
	return cached_military_graph

static func _field_positions(map_data: Dictionary) -> Array:
	var result: Array = []
	for field in map_data.get("fields", []):
		result.append([field["position"], field["anchor"], field.get("radius", 0.0), field.get("access", [])])
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
	# A stopped ship inside a corridor can depart through either endpoint,
	# independent of which endpoint was retained as its routing hint.
	if route.is_empty() and graph.has("sector_radii") and graph.has("edges") and not sector_contains(graph, here, position):
		var lane: Vector2i = lane_at(graph, position)
		if lane.x >= 0 and not sector_contains(graph, lane.x, position) and not sector_contains(graph, lane.y, position):
			var cost_a: float = position.distance_to(points[lane.x]) + float(distances.get(lane.x, INF))
			var cost_b: float = position.distance_to(points[lane.y]) + float(distances.get(lane.y, INF))
			var anchor: int = lane.x if cost_a <= cost_b else lane.y
			var other: int = lane.y if anchor == lane.x else lane.x
			return {"distance": minf(cost_a, cost_b), "anchor": anchor, "reverse": false, "edge": true, "from_anchor": other}
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
		if approach.has("from_anchor"):
			ship["at"] = int(approach["from_anchor"])
		elif bool(approach["reverse"]):
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
static func command_fighters(state: Dictionary, player: int, ids: Array, target: int, move_only: bool = false) -> bool:
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
		_cancel_salvage_order(ship)
		_clear_tactical_order(ship)
		_set_unit_order(state, ship, {"kind": "sector", "target": target, "move_only": move_only})
		ship["direct_order"] = true
		_clear_local_hold(ship)
		ship["operation_target"] = target
		ship["move_only"] = move_only
		ship.erase("rally_pending")
		if not bool(ship.get("retreating", false)):
			_redirect_fighter(graph, ship, target, paths)
	return true

# Both orders use the normal military graph and the same automatic combat
# and repair rules as attack-move. The target is a stable hull ID, not a slot.
static func _clear_tactical_order(ship: Dictionary) -> void:
	_clear_local_move(ship)
	ship.erase("science_years")
	ship.erase("guard_arrived")
	ship.erase("launch_rally")
	ship.erase("move_only")
	ship.erase("attack_order")
	ship.erase("attack_local")
	ship.erase("repair_order")
	ship.erase("repair_target")
	ship.erase("cargo_order")
	ship.erase("patrol_from")
	ship.erase("patrol_to")
	ship.erase("patrol_start_point")
	ship.erase("patrol_end_point")
	ship.erase("patrol_returning")
	ship.erase("patrol_arrived")

# Bilateral diplomacy is opt-in until the lobby, routing, trade, sight and
# victory consumers migrate. A missing table retains legacy match behavior.
const TRUCE_YEARS: float = 100.0
const DIPLO_NEUTRAL: String = "neutral"
const DIPLO_ALLIED: String = "allied"
const DIPLO_WAR: String = "war"
const DIPLO_TRUCE: String = "truce"

static func initialize_diplomacy(state: Dictionary) -> bool:
	if state.has("diplomacy"):
		return false
	state["diplomacy"] = {}
	state["diplomacy_revision"] = 1
	# Legacy team exploration cannot be attributed to individual empires.
	# Rebuild from their own stations rather than leaking former team data.
	state["explored"] = {}
	update_exploration(state)
	return true

static func _diplomacy_pair(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))

static func _valid_diplomacy_pair(state: Dictionary, a: int, b: int) -> bool:
	return a > 0 and b > 0 and a != b and state["teams"].has(a) and state["teams"].has(b)

static func diplomatic_relation(state: Dictionary, a: int, b: int) -> String:
	if a > 0 and a == b and state["teams"].has(a):
		return DIPLO_ALLIED
	if not _valid_diplomacy_pair(state, a, b):
		return DIPLO_NEUTRAL
	if not state.has("diplomacy"):
		return DIPLO_ALLIED if state["teams"][a] == state["teams"][b] else DIPLO_WAR
	var entry: Dictionary = state["diplomacy"].get(_diplomacy_pair(a, b), {})
	var relation: String = str(entry.get("relation", DIPLO_NEUTRAL))
	if relation == DIPLO_TRUCE and float(state["elapsed"]) >= float(entry.get("until", 0.0)):
		return DIPLO_NEUTRAL
	return relation

static func empires_hostile(state: Dictionary, a: int, b: int) -> bool:
	return diplomatic_relation(state, a, b) == DIPLO_WAR

static func empires_allied(state: Dictionary, a: int, b: int) -> bool:
	return diplomatic_relation(state, a, b) == DIPLO_ALLIED

static func _can_change_diplomacy(state: Dictionary, a: int, b: int) -> bool:
	return state.has("diplomacy") and _valid_diplomacy_pair(state, a, b) and state.get("match_result", {}).is_empty() and not state.get("eliminated", []).has(a) and not state.get("eliminated", []).has(b)

static func _write_diplomacy(state: Dictionary, a: int, b: int, entry: Dictionary) -> void:
	state["diplomacy"][_diplomacy_pair(a, b)] = entry
	state["diplomacy_revision"] = int(state.get("diplomacy_revision", 0)) + 1

static func diplomacy_declare_war(state: Dictionary, a: int, b: int) -> bool:
	if not _can_change_diplomacy(state, a, b) or diplomatic_relation(state, a, b) != DIPLO_NEUTRAL:
		return false
	_write_diplomacy(state, a, b, {"relation": DIPLO_WAR})
	return true

# A reciprocal offer is acceptance. Repeating one's own offer does nothing.
static func diplomacy_confirm_attack(state: Dictionary, player: int, expected_owner: int, ids: Array, target_id: int) -> bool:
	if not _can_change_diplomacy(state, player, expected_owner) or diplomatic_relation(state, player, expected_owner) != DIPLO_NEUTRAL:
		return false
	var ref: Dictionary = service_targets(state, target_id).get(target_id, {})
	if ref.is_empty() or int(ref.get("owner", 0)) != expected_owner or ref.get("kind", "") == "pds":
		return false
	if not ship_visible_to_team(state, ref.get("entity", ref), _combat_group(state, player)):
		return false
	if bool(state.get("fog_of_war", DEFAULT_FOG_OF_WAR)) and not team_vision(state, _combat_group(state, player)).has(vision_cell(ref["position"])):
		return false
	var units: Array = _owned_units(state, player, ids)
	if units.is_empty() or units.any(func(craft: Dictionary) -> bool: return not armed(craft)):
		return false
	# All validation precedes the declaration. Existing attack command uses
	# the same frozen ownership/visibility predicates on the authority.
	if not diplomacy_declare_war(state, player, expected_owner):
		return false
	return command_attack(state, player, ids, target_id)

static func diplomacy_offer_peace(state: Dictionary, a: int, b: int) -> bool:
	if not _can_change_diplomacy(state, a, b) or diplomatic_relation(state, a, b) != DIPLO_WAR:
		return false
	var entry: Dictionary = state["diplomacy"].get(_diplomacy_pair(a, b), {})
	var proposer: int = int(entry.get("peace_offer", 0))
	if proposer == a:
		return false
	if proposer == b:
		_write_diplomacy(state, a, b, {"relation": DIPLO_TRUCE, "until": float(state["elapsed"]) + TRUCE_YEARS})
	else:
		_write_diplomacy(state, a, b, {"relation": DIPLO_WAR, "peace_offer": a})
	return true

static func diplomacy_offer_alliance(state: Dictionary, a: int, b: int) -> bool:
	if not _can_change_diplomacy(state, a, b) or diplomatic_relation(state, a, b) != DIPLO_NEUTRAL:
		return false
	var entry: Dictionary = state["diplomacy"].get(_diplomacy_pair(a, b), {})
	var proposer: int = int(entry.get("alliance_offer", 0))
	if proposer == a:
		return false
	if proposer == b:
		_write_diplomacy(state, a, b, {"relation": DIPLO_ALLIED, "vision": {a: true, b: true}, "trade": {a: true, b: true}})
	else:
		_write_diplomacy(state, a, b, {"relation": DIPLO_NEUTRAL, "alliance_offer": a})
	return true

static func diplomacy_break_alliance(state: Dictionary, a: int, b: int) -> bool:
	if not _can_change_diplomacy(state, a, b) or not empires_allied(state, a, b):
		return false
	_write_diplomacy(state, a, b, {"relation": DIPLO_NEUTRAL})
	return true

static func diplomacy_allows(state: Dictionary, a: int, b: int, permission: String) -> bool:
	if permission not in ["vision", "trade", "repair"] or not empires_allied(state, a, b):
		return false
	if a == b or permission == "repair" or not state.has("diplomacy"):
		return true
	var entry: Dictionary = state["diplomacy"].get(_diplomacy_pair(a, b), {})
	var preferences: Dictionary = entry.get(permission, {})
	return bool(preferences.get(a, true)) and bool(preferences.get(b, true))

static func diplomacy_set_permission(state: Dictionary, a: int, b: int, permission: String, enabled: bool) -> bool:
	if permission not in ["vision", "trade"] or not _can_change_diplomacy(state, a, b) or not empires_allied(state, a, b):
		return false
	var entry: Dictionary = state["diplomacy"][_diplomacy_pair(a, b)].duplicate(true)
	var preferences: Dictionary = entry.get(permission, {})
	if bool(preferences.get(a, true)) == enabled:
		return false
	preferences[a] = enabled
	entry[permission] = preferences
	_write_diplomacy(state, a, b, entry)
	return true

# Legacy combat groups are teams. In bilateral matches they are individual
# empires: cached hostile buckets must never merge allies transitively.
static func _combat_group(state: Dictionary, owner: int) -> int:
	return owner if state.has("diplomacy") and state["teams"].has(owner) else int(state["teams"].get(owner, 0))

static func _combat_groups_hostile(state: Dictionary, a: int, b: int) -> bool:
	if state.has("diplomacy"):
		return empires_hostile(state, a, b)
	# Preserve historical bucket behavior, including unowned targets.
	return a != b

static func _hostile_hull(state: Dictionary, player: int, target: Dictionary) -> bool:
	var owner: int = int(target.get("owner", 0))
	return target.get("kind", "") != "pds" and empires_hostile(state, player, owner) and ship_visible_to_team(state, target.get("entity", target), _combat_group(state, player))

static func _attack_destination(graph: Dictionary, target: Dictionary) -> int:
	var sector: int = local_sector(graph, target)
	if sector >= 0:
		return sector
	var route: Array = target.get("route", [])
	return int(route[0]) if not route.is_empty() else int(target.get("at", -1))

const MISSILE_SPLASH_RADIUS: float = 30.0
const STATION_MISSILE_COUNT: int = 1
const MISSILE_RANGE: float = 1200.0
const MISSILE_DAMAGE: float = 120.0
const MISSILE_COOLDOWN: float = 12.0

const BLASTER_DAMAGE: float = 1.0
const BLASTER_SHOTS: int = 4
const BLASTER_BURST: float = 1.0
const BLASTER_PAUSE: float = 0.5
const BLASTER_SHOT_INTERVAL: float = BLASTER_BURST / BLASTER_SHOTS
const BLASTER_TRAVEL: float = 0.45

static func blaster_count(kind: String) -> int:
	return int({"scout": 1, "fighter": 2, "cruiser": 3, "destroyer": 4}.get(kind, 0))

static func capital_lasers(kind: String) -> int:
	return int({"cruiser": 2, "destroyer": 4}.get(kind, 0))

static func missile_count(kind: String) -> int:
	return int({"cruiser": 1, "destroyer": 2}.get(kind, 0))

static func ship_max_hp(kind: String) -> float:
	return float({"ship": FREIGHTER_HP, "scout": SHIP_HP * 0.5, "cruiser": 1600.0, "destroyer": 3200.0, "warp_gate": WARP_GATE_HP}.get(kind, SHIP_HP))

static func _regenerate_hull(entity: Dictionary, maximum: float, dt: float) -> void:
	var hp: float = float(entity.get("hp", maximum))
	if hp > 0.0 and hp < maximum:
		entity["hp"] = minf(maximum, hp + PASSIVE_REGEN * maxf(0.0, dt))

static func _passive_regeneration(state: Dictionary, dt: float) -> void:
	for ship in state["ships"]:
		_regenerate_hull(ship, ship_max_hp(str(ship["kind"])), dt)
	for system in state["planets"]:
		if has_station(system):
			_regenerate_hull(system["station"], station_max_hp(system), dt)
		for yard in system["yards"]:
			_regenerate_hull(yard, YARD_HP * int(yard["level"]), dt)
		for battery in system.get("pds", {}).values():
			_regenerate_hull(battery, PDS_HP, dt)

static func armed(ship: Dictionary) -> bool:
	return not bool(ship.get("rogue", false)) and ship.get("kind", "") in ["fighter", "miner", "cruiser", "destroyer", "scout"]

# Stable hull IDs and the existing disjoint structure target IDs. HP lives
# in the actual entity dictionary, so repair never creates a new entity.
static var _indexed_state: Dictionary = {}
static var _hulls_by_id: Dictionary = {}

# Scope derived references to one authority step; never serialize them.
static func _begin_hull_index(state: Dictionary) -> void:
	_indexed_state = state
	_hulls_by_id.clear()
	for ship in state["ships"]:
		_hulls_by_id[int(ship["id"])] = ship

static func _remove_indexed_hull(state: Dictionary, ship: Dictionary) -> void:
	if ship.get("kind", "") == "warp_gate":
		for other in state["ships"]:
			if other.get("kind", "") == "warp_gate" and int(other.get("warp_destination", -1)) == int(ship["id"]):
				other["warp_destination"] = -1
	state["ships"].erase(ship)
	if is_same(state, _indexed_state):
		_hulls_by_id.erase(int(ship["id"]))

static func service_targets(state: Dictionary, only_id: int = -1) -> Dictionary:
	var targets: Dictionary = {}
	var hulls: Array = state["ships"]
	if only_id >= 0 and is_same(state, _indexed_state):
		hulls = [_hulls_by_id[only_id]] if _hulls_by_id.has(only_id) else []
	elif only_id < -1:
		hulls = []
	for ship in hulls:
		if only_id != -1 and int(ship["id"]) != only_id:
			continue
		var position: Vector2 = ship.get("position", Vector2.INF)
		if not position.is_finite():
			continue
		targets[ship["id"]] = {"owner": ship["owner"], "entity": ship, "position": position, "max_hp": ship_max_hp(str(ship["kind"])), "node": -1, "kind": "ship"}
	if only_id >= 0:
		return targets
	var count: int = state["planets"].size()
	for node in range(count):
		var p: Dictionary = state["planets"][node]
		if has_station(p) and (only_id == -1 or only_id == station_target_id(state, node)):
			targets[station_target_id(state, node)] = {"owner": p["owner"], "entity": p["station"], "position": station_position(state, node, float(state["elapsed"])), "max_hp": station_max_hp(p), "node": node, "kind": "station"}
		for slot in range(p["yards"].size()):
			if only_id != -1 and only_id != -2 - node * 3 - slot:
				continue
			var yard: Dictionary = p["yards"][slot]
			targets[-2 - node * 3 - slot] = {"owner": p["owner"], "entity": yard, "position": shipyard_position(state, node, slot, float(state["elapsed"])), "max_hp": YARD_HP * int(yard["level"]), "node": node, "kind": "yard"}
		var defenses: Dictionary = p.get("pds", {})
		if not defenses.is_empty():
			if only_id != -1:
				var matching: bool = false
				for slot in defenses:
					if only_id == -2 - count * 3 - int(slot) * count - node:
						matching = true
						break
				if not matching:
					continue
			var bodies: Array = system_bodies(p, int(state["map"]["seed"]), node)
			var radius: float = system_world_radius(state, node)
			for slot in defenses:
				if only_id != -1 and only_id != -2 - count * 3 - int(slot) * count - node:
					continue
				if int(slot) < 0 or int(slot) >= bodies.size():
					continue
				var center: Vector2 = state["map"]["points"][node]
				var point: Vector2 = center + body_position(bodies[int(slot)], radius, float(state["elapsed"]))
				# Keep established system-centered combat range; repairs use the actual battery.
				targets[-2 - count * 3 - int(slot) * count - node] = {"owner": p["owner"], "entity": defenses[slot], "position": center, "repair_position": point, "max_hp": PDS_HP, "node": node, "kind": "pds"}
	return targets

static func _friendly_target(state: Dictionary, owner: int, target: Dictionary) -> bool:
	return not target.is_empty() and empires_allied(state, owner, int(target.get("owner", 0)))

# Trade permission does not authorize an uncompensated cargo transfer.
# Only explicit paid shipments and gifts may later cross ownership.
static func _cargo_target_allowed(state: Dictionary, owner: int, target: Dictionary) -> bool:
	if state.has("diplomacy"):
		return not target.is_empty() and owner > 0 and int(target.get("owner", 0)) == owner
	return _friendly_target(state, owner, target)

static func _damaged(target: Dictionary) -> bool:
	return not target.is_empty() and float(target["entity"].get("hp", target["max_hp"])) < float(target["max_hp"]) - EPS

static func can_deposit(state: Dictionary, ship: Dictionary, target_id: int) -> bool:
	var ref: Dictionary = service_targets(state, target_id).get(target_id, {})
	if ship.get("kind", "") == "science_ship" or ref.get("entity", {}).get("kind", "") in ["science_ship", "colony_ship"]:
		return false
	if ship.get("kind", "") == "colony_ship" and ref.get("kind", "") != "station":
		return false
	if cargo_capacity(str(ship.get("kind", "ship"))) <= EPS or target_id == int(ship["id"]) or not _cargo_target_allowed(state, int(ship["owner"]), ref) or _cargo_total(ship) <= EPS:
		return false
	if ref["kind"] == "ship":
		return cargo_free(ref["entity"]) > EPS
	if ref["kind"] != "station":
		return false
	var p: Dictionary = state["planets"][ref["node"]]
	for resource in RESOURCES + [ANTIMATTER]:
		if float(ship["cargo"].get(resource, 0.0)) > EPS and storage_free(p, resource) > EPS:
			return true
	return false

static func command_service(state: Dictionary, player: int, ids: Array, order: Dictionary) -> bool:
	var units: Array = _owned_units(state, player, ids)
	var graph: Dictionary = military_graph(state)
	if units.is_empty():
		return false
	for ship in units:
		if not _valid_unit_order(state, graph, ship, order, false):
			return false
	for ship in units:
		_cancel_salvage_order(ship)
		_clear_tactical_order(ship)
		_clear_local_hold(ship)
		_interrupt_work(ship)
		_set_unit_order(state, ship, order.duplicate(true))
		if order["kind"] == "repair":
			ship["repair_order"] = order["target"]
		else:
			ship["cargo_order"] = order.duplicate(true)
			ship["move_only"] = true
	return true

static func supports_autocast(ship: Dictionary, mode: String) -> bool:
	match mode:
		"explore": return ship.get("kind", "") == "scout"
		"wander": return SHIP_KINDS.has(ship.get("kind", ""))
		"mine", "repair": return ship.get("kind", "") == "miner"
		"salvage": return ship.get("kind", "") in ["ship", "miner"]
		"trade": return ship.get("kind", "") == "ship"
		"farm": return ship.get("kind", "") == "colony_ship"
		"collect": return ship.get("kind", "") == "science_ship"
		"retreat": return armed(ship)
	return false

static func autocast_enabled(ship: Dictionary, mode: String) -> bool:
	return not bool(ship.get("rogue", false)) and supports_autocast(ship, mode) and bool(ship.get(mode + "_auto", mode not in ["collect", "retreat", "explore"]))

static func autocast_duration(mode: String) -> float:
	match mode:
		"repair", "farm", "retreat", "explore": return 0.0
		"mine", "salvage": return MINING_SALVAGE_COOLDOWN_YEARS
	return AUTOCAST_COOLDOWN_YEARS

static func autocast_remaining(state: Dictionary, ship: Dictionary, mode: String = "") -> float:
	if mode == "wander" and bool(ship.get("wander_cooldown_override", false)):
		return 0.0
	var duration: float = autocast_duration(mode)
	if duration <= 0.0:
		return 0.0
	# The existing authoritative deadlines represent the longest cooldown.
	# Shorter modes share the same start/arrival timestamp without new fields.
	var longest: float = maxf(arrival_wait_remaining(state, ship), maxf(0.0, float(ship.get("auto_cooldown_until", 0.0)) - float(state["elapsed"])))
	return clampf(longest - (AUTOCAST_COOLDOWN_YEARS - duration), 0.0, duration)

static func autocast_ready(state: Dictionary, ship: Dictionary, mode: String) -> bool:
	return autocast_enabled(ship, mode) and autocast_remaining(state, ship, mode) <= EPS

static func set_autocast(state: Dictionary, player: int, ids: Array, mode: String, enabled: bool) -> bool:
	var units: Array = _owned_units(state, player, ids)
	if not AUTOCAST_MODES.has(mode) or units.is_empty() or units.any(func(ship: Dictionary) -> bool: return not supports_autocast(ship, mode)):
		return false
	if mode == "repair":
		return set_repair_auto(state, player, ids, enabled)
	for ship in units:
		ship[mode + "_auto"] = enabled
		if ship.get("kind", "") == "scout" and enabled:
			if mode == "explore":
				ship["wander_auto"] = false
				ship.erase("wander_cooldown_override")
			elif mode == "wander":
				ship["explore_auto"] = false
		if ((mode == "explore" and not enabled) or (mode == "wander" and enabled)) and bool(ship.get("unit_order", {}).get("exploration", false)):
			ship.erase("unit_order")
			_finish_manual(ship)
			ship["navigation_target"] = ship["position"]
		if mode == "retreat" and not enabled and bool(ship.get("retreating", false)):
			ship["retreating"] = false
			ship.erase("repair_site")
			ship.erase("withdrawal_objective")
			ship["dest"] = -1
		if mode == "trade" and not enabled:
			_clear_resource_stage(ship)
		if mode == "collect" and not enabled and ship.get("unit_order", {}).get("kind", "") == "collect" and bool(ship.get("unit_order", {}).get("automatic", false)):
			ship.erase("unit_order")
			ship.erase("science_years")
			_finish_manual(ship)
			ship["navigation_target"] = ship["position"]
		if mode == "farm" and not enabled and bool(ship.get("farm_auto_delivery", false)):
			_cancel_salvage_order(ship)
			ship.erase("unit_order")
		if mode == "wander":
			if enabled and autocast_remaining(state, ship) > EPS:
				ship["wander_cooldown_override"] = true
			else:
				ship.erase("wander_cooldown_override")
		if enabled:
			continue
		if mode == "salvage":
			_release_auto_salvage(ship, state.get("salvage", {}))
		elif mode == "mine" and not bool(ship.get("manual_mine", false)) and ship.get("mining_mode", "idle") in ["approach", "outbound", "mining", "return"]:
			_interrupt_work(ship)
			ship["route"] = []
			ship["leg"] = 0.0
			ship["mining_active"] = false
			ship["navigation_target"] = ship["position"]
		elif mode == "trade" and not _unit_order_running(ship) and not _salvage_active(ship):
			_interrupt_work(ship)
			ship["route"] = []
			ship["leg"] = 0.0
			ship["navigation_target"] = ship["position"]
	return true

static func set_repair_auto(state: Dictionary, player: int, ids: Array, enabled: bool) -> bool:
	var units: Array = _owned_units(state, player, ids)
	if units.is_empty() or units.any(func(ship: Dictionary) -> bool: return ship["kind"] != "miner"):
		return false
	for ship in units:
		ship["repair_auto"] = enabled
		if not enabled and not ship.has("repair_order"):
			ship.erase("repair_target")
	return true

static func _drop_carried(state: Dictionary, ship: Dictionary) -> void:
	var pos: Vector2 = ship["position"]
	var born: float = float(state["elapsed"])
	var piles: Dictionary = state.get("salvage", {})
	for resource in RESOURCES + [ANTIMATTER]:
		var amount: float = float(ship.get("cargo", {}).get(resource, 0.0))
		if amount <= EPS:
			continue
		var id: int = int(state.get("next_salvage_id", 1))
		state["next_salvage_id"] = id + 1
		var rng := RandomNumberGenerator.new()
		rng.seed = int(state["map"].get("seed", 0)) + id * 15485863
		var angle: float = rng.randf_range(0.0, TAU)
		piles[id] = {"id": id, "resource": resource, "amount": amount, "origin": pos, "position": pos, "drift": Vector2.from_angle(angle) * rng.randf_range(4.0, 10.0), "born": born, "expires_at": born + rng.randf_range(SALVAGE_MIN_LIFETIME, SALVAGE_MAX_LIFETIME), "claim": -1, "dropped_by": ship["id"]}
		_cargo_stat(ship, "tons_dropped", resource, amount)
		ship["cargo"][resource] = 0.0
	state["salvage"] = piles

static func _work_cargo_order(state: Dictionary, graph: Dictionary, ship: Dictionary, targets: Dictionary, dt: float) -> bool:
	if not ship.has("cargo_order"):
		return false
	if _cargo_total(ship) <= EPS:
		ship.erase("cargo_order")
		_finish_manual(ship)
		return false
	var order: Dictionary = ship["cargo_order"]
	var ref: Dictionary = targets.get(int(order.get("target", -1)), {})
	var drop: bool = order["kind"] == "drop"
	if not drop and (not _cargo_target_allowed(state, int(ship["owner"]), ref) or ref.get("entity", {}).get("kind", "") in ["science_ship", "colony_ship"]):
		ship.erase("cargo_order")
		_finish_manual(ship)
		return false
	var point: Vector2 = order["point"] if drop else ref["position"]
	var node: int = patrol_node(state, graph, int(ship["owner"]), point)
	if node < 0:
		ship.erase("cargo_order")
		_finish_manual(ship)
		return false
	var reach: float = 0.0 if drop else (STATION_DOCK_RANGE if ref.get("kind") == "station" else TRACTOR_RANGE)
	if not drop and ship["route"].is_empty() and (ship["position"] as Vector2).distance_to(point) <= reach + EPS:
		_navigate(ship, _waiting_berth(state, ship, point, reach, point.direction_to(ship["position"])), ship_speed(str(ship["kind"])) * dt)
	elif not _manual_travel(state, graph, ship, node, point, dt, reach):
		return true
	if not drop and (ship["position"] as Vector2).distance_to(point) > reach + EPS:
		return true
	if drop:
		_drop_carried(state, ship)
	elif ref["kind"] in ["station", "ship"]:
		var depot: Dictionary = state["planets"][ref["node"]] if ref["kind"] == "station" else ref["entity"]
		var stock: Dictionary = depot["stock"] if ref["kind"] == "station" else depot["cargo"]
		var budget: float = _dropoff_budget(ship, dt)
		for resource in RESOURCES + [ANTIMATTER]:
			var free: float = storage_free(depot, resource) if ref["kind"] == "station" else cargo_free(depot)
			var amount: float = minf(budget, minf(float(ship["cargo"].get(resource, 0.0)), free))
			if amount <= EPS:
				continue
			_record_transfer(state, int(ship["id"]), ship, int(order["target"]), depot, resource, amount)
			ship["cargo"][resource] -= amount
			stock[resource] = float(stock.get(resource, 0.0)) + amount
			budget -= amount
			if ref["kind"] == "station":
				_record_flow(depot, "Manual deliveries", resource, amount)
		if _cargo_total(ship) > EPS and (ref["kind"] == "station" or cargo_free(depot) > EPS):
			return true # wait in range for released capacity; a new order can interrupt
	ship.erase("cargo_order")
	_finish_manual(ship)
	return true

static func _damaged_repair_cells(targets: Dictionary) -> Dictionary:
	var cells: Dictionary = {}
	var order: int = 0
	for id in targets:
		var ref: Dictionary = targets[id]
		if _damaged(ref):
			_spatial_insert(cells, ref.get("repair_position", ref["position"]), MINER_REPAIR_SEARCH, [order, id])
		order += 1
	return cells

static func _nearby_repair_ids(cells: Dictionary, point: Vector2) -> Array:
	var cell := Vector2i(floori(point.x / MINER_REPAIR_SEARCH), floori(point.y / MINER_REPAIR_SEARCH))
	var entries: Array = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			entries.append_array(cells.get(cell + Vector2i(x, y), []))
	entries.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var ids: Array = []
	for entry in entries:
		ids.append(entry[1])
	return ids

static func _repair_retry_due(ship: Dictionary, now: float) -> bool:
	return now + EPS >= float(ship.get("_next_repair_search", 0.0))

static func _work_miner_repair(state: Dictionary, graph: Dictionary, ship: Dictionary, targets: Dictionary, dt: float, damaged_cells: Variant = null) -> bool:
	if ship["kind"] != "miner":
		return false
	ship.erase("repair_target")
	var explicit: bool = ship.has("repair_order")
	if not explicit and (not autocast_ready(state, ship, "repair") or (_unit_order_running(ship) and ship.get("unit_order", {}).get("kind", "") != "mine") or bool(ship.get("holding", false)) or _salvage_active(ship)):
		return false
	var target_id: int = int(ship.get("repair_order", -1))
	var ref: Dictionary = targets.get(target_id, {})
	if explicit and (not _friendly_target(state, int(ship["owner"]), ref) or not _damaged(ref)):
		ship.erase("repair_order")
		_finish_manual(ship)
		return false
	var pos: Vector2 = ship["position"]
	if not explicit:
		# Only throttle unsuccessful automatic searches. Active repairs and
		# explicit orders retain their original per-step behavior.
		if damaged_cells != null and not _repair_retry_due(ship, float(state["elapsed"])):
			return false
		var best: float = MINER_REPAIR_SEARCH * MINER_REPAIR_SEARCH
		for id in (targets.keys() if damaged_cells == null else _nearby_repair_ids(damaged_cells, pos)):
			if id == ship["id"]:
				continue
			var candidate: Dictionary = targets[id]
			if not _friendly_target(state, int(ship["owner"]), candidate) or not _damaged(candidate):
				continue
			var distance: float = pos.distance_squared_to(candidate.get("repair_position", candidate["position"]))
			if distance < best:
				best = distance
				target_id = id
				ref = candidate
	if ref.is_empty():
		if not explicit and damaged_cells != null:
			ship["_next_repair_search"] = _next_search_slot(float(state["elapsed"]), int(ship["id"]), 0.5)
		return false
	ship.erase("_next_repair_search")
	var point: Vector2 = ref.get("repair_position", ref["position"])
	if pos.distance_to(point) > LASER_RANGE:
		if explicit:
			var node: int = patrol_node(state, graph, int(ship["owner"]), point)
			if node < 0:
				ship.erase("repair_order")
				return false
			_manual_travel(state, graph, ship, node, point, dt, LASER_RANGE * 0.8)
		else:
			_navigate(ship, point, minf(ship_speed(str(ship.get("kind", "ship"))) * dt, pos.distance_to(point) - LASER_RANGE * 0.8))
	else:
		var entity: Dictionary = ref["entity"]
		entity["hp"] = minf(float(ref["max_hp"]), float(entity.get("hp", ref["max_hp"])) + MINER_REPAIR_RATE * dt)
		ship["repair_target"] = target_id
		ship["mining_active"] = false
		ship["navigation_target"] = ship["position"]
	if not explicit and ship.get("mining_mode", "") == "mining":
		ship["mining_mode"] = "outbound"
	return true

# A manual command interrupts civilian work, retaining cargo and player
# mining preferences. On completion automation chooses a fresh legal job.
static func _interrupt_work(ship: Dictionary) -> void:
	_clear_resource_stage(ship)
	if ship["kind"] in ["fighter", "scout", "cruiser", "destroyer"]:
		ship["direct_order"] = true
		ship["operation_target"] = int(ship["at"])
		ship.erase("rally_pending")
	else:
		ship["source"] = -1
		ship["dest"] = -1
		if ship["kind"] == "miner":
			ship["mining_mode"] = "delivery" if _cargo_total(ship) > EPS else "idle"
			ship["field"] = -1
			ship["next_mining_search"] = 0.0
			ship["next_unload_search"] = 0.0

static func _manual_nav(state: Dictionary, graph: Dictionary, ship: Dictionary, node: int) -> Dictionary:
	if ship["kind"] in ["fighter", "scout", "cruiser", "destroyer"]:
		return {"graph": graph, "node": node}
	# Civilian work stores star indices; use star lanes for manual travel,
	# then fly from the field's access star to the exact requested point.
	var count: int = state["planets"].size()
	if node >= count:
		node = int(state["map"]["fields"][node - count]["anchor"])
	if not graph.has("civilian_manual_nav"):
		var adjacent: Array = []
		for index in range(count):
			adjacent.append(graph["adjacent"][index].filter(func(other: int) -> bool: return other < count))
		graph["civilian_manual_nav"] = {"points": state["map"]["points"], "edges": state["map"]["edges"], "adjacent": adjacent, "paths": {}, "sector_radii": graph["sector_radii"].slice(0, count), "sector_neighbors": graph["sector_neighbors"].slice(0, count), "sector_neighbor_squares": graph["sector_neighbor_squares"].slice(0, count)}
	return {"graph": graph["civilian_manual_nav"], "node": node}

# A follow order references a stable hull ID and lasts until replaced. Reject
# self-follow, hostile targets and cycles (including queued-order activation).
static func _valid_follow_target(state: Dictionary, ship: Dictionary, target: int, refs: Dictionary) -> bool:
	var ref: Dictionary = refs.get(target, {})
	if ref.get("kind", "") != "ship" or not _friendly_target(state, int(ship["owner"]), ref):
		return false
	var seen: Dictionary = {int(ship["id"]): true}
	var current: int = target
	while current >= 0 and refs.has(current):
		if seen.has(current):
			return false
		seen[current] = true
		var other: Dictionary = refs[current]["entity"]
		var order: Dictionary = other.get("unit_order", {})
		if order.get("kind", "") != "follow":
			break
		current = int(order["target"])
	return true

static func _work_follow(state: Dictionary, graph: Dictionary, ship: Dictionary, refs: Dictionary, dt: float) -> bool:
	var order: Dictionary = ship.get("unit_order", {})
	if order.get("kind", "") != "follow":
		return false
	var target: int = int(order["target"])
	var ref: Dictionary = refs.get(target, {})
	if not _valid_follow_target(state, ship, target, refs):
		ship.erase("unit_order")
		ship.erase("follow_arrived")
		_finish_manual(ship)
		ship["navigation_target"] = ship["position"]
		ship["arrival_wait_until"] = float(state["elapsed"]) + AUTOCAST_COOLDOWN_YEARS
		return true
	var point: Vector2 = ref["position"]
	var pos: Vector2 = ship["position"]
	# Small deterministic spacing variation helps groups avoid occupying
	# one point while retaining a predictable near-target standoff.
	var reach: float = FOLLOW_DISTANCE + float(int(ship["id"]) % 4) * SHIP_SEPARATION_RADIUS * 0.5
	var distance: float = pos.distance_to(point)
	ship["follow_arrived"] = distance <= reach + EPS
	if distance <= reach + EPS:
		ship.erase("move_only")
		ship["navigation_target"] = pos
		# If the target comes towards us, make room without jittering on
		# the outer edge. Keep the saved lane anchor for subsequent travel.
		if distance < reach * 0.65:
			var away: Vector2 = point.direction_to(pos)
			if away.is_zero_approx():
				away = Vector2.from_angle(float(ship["id"]) * 2.399963)
			_navigate(ship, point + away * reach * 0.8, ship_speed(str(ship.get("kind", "ship"))) * dt)
		return true
	ship["move_only"] = not bool(order.get("guard", false))
	var node: int = _attack_destination(graph, ref["entity"])
	if node < 0 or node >= graph["points"].size():
		return true
	# Approach the moving hull through the same lane routing as a manual
	# move, limiting the final step to the current standoff distance.
	var budget_dt: float = minf(dt, maxf(0.0, distance - reach) / ship_speed(str(ship.get("kind", "ship"))))
	_manual_travel(state, graph, ship, node, point, budget_dt, reach)
	ship["follow_arrived"] = (ship["position"] as Vector2).distance_to(point) <= reach + EPS
	return true

# Pulsars retain the finite reservoir and navigation nodes of the old deposits.
static func _science_target_valid(state: Dictionary, graph: Dictionary, ship: Dictionary, index: int) -> bool:
	var fields: Array = state["map"].get("fields", [])
	if ship["kind"] != "science_ship" or _cargo_total(ship) > EPS or index < 0 or index >= fields.size() or not discovered(state, int(ship["owner"]), "fields", index):
		return false
	var field: Dictionary = fields[index]
	if not bool(field.get("antimatter", false)) or float(field_inventory(field)[ANTIMATTER]) < 1.0 - EPS:
		return false
	var node: int = state["planets"].size() + index
	var nav: Dictionary = _manual_nav(state, graph, ship, node)
	return sector_contains(graph, node, ship["position"]) or _military_paths(nav["graph"], nav["node"])["distance"].has(int(ship["at"]))

static func _work_science(state: Dictionary, graph: Dictionary, ship: Dictionary, dt: float) -> bool:
	if ship["kind"] != "science_ship" or bool(ship.get("holding", false)):
		return false
	var order: Dictionary = ship.get("unit_order", {})
	if order.get("kind", "") != "collect":
		if not _is_idle_ship(ship) or _unit_order_running(ship) or not ship.get("order_queue", []).is_empty():
			return false
		if _cargo_total(ship) >= SCIENCE_CAPACITY - EPS:
			ship["navigation_target"] = ship["position"]
			return true
		if not autocast_ready(state, ship, "collect"):
			return false
		var best: float = INF
		var chosen: int = -1
		for index in range(state["map"].get("fields", []).size()):
			if not _science_target_valid(state, graph, ship, index):
				continue
			var distance: float = (ship["position"] as Vector2).distance_squared_to(state["map"]["fields"][index]["position"])
			if distance < best:
				best = distance
				chosen = index
		if chosen < 0:
			return false
		_set_unit_order(state, ship, {"kind": "collect", "target": chosen, "automatic": true})
		ship["science_years"] = 0.0
		order = ship["unit_order"]
	var index: int = int(order["target"])
	if not _science_target_valid(state, graph, ship, index):
		ship.erase("unit_order")
		ship.erase("science_years")
		_finish_manual(ship)
		return true
	var field: Dictionary = state["map"]["fields"][index]
	var point: Vector2 = field["position"]
	var node: int = state["planets"].size() + index
	var reach: float = minf(100.0, float(field["radius"]) * 0.65)
	if (ship["position"] as Vector2).distance_to(point) > reach + EPS:
		_manual_travel(state, graph, ship, node, point, dt, reach * 0.65)
		return true
	ship["navigation_target"] = ship["position"]
	ship["science_years"] = minf(SCIENCE_COLLECTION_YEARS, float(ship.get("science_years", 0.0)) + dt)
	if float(ship["science_years"]) >= SCIENCE_COLLECTION_YEARS - EPS:
		var remaining: float = SCIENCE_CAPACITY
		for chunk in field["chunks"]:
			if chunk["resource"] != ANTIMATTER:
				continue
			var taken: float = minf(remaining, float(chunk["remaining"]))
			chunk["remaining"] -= taken
			remaining -= taken
			if remaining <= EPS:
				break
		ship["cargo"][ANTIMATTER] = SCIENCE_CAPACITY
		var progress: Dictionary = objective_progress(state, int(ship["owner"]))
		progress["antimatter_processed"] = int(progress.get("antimatter_processed", 0)) + 1
		ship.erase("science_years")
		ship.erase("unit_order")
		_finish_manual(ship)
	return true

static func _manual_travel(state: Dictionary, graph: Dictionary, ship: Dictionary, node: int, point: Vector2, dt: float, reach: float = 0.0) -> bool:
	var pos: Vector2 = ship["position"]
	var budget: float = ship_speed(str(ship["kind"])) * dt
	ship["route"] = []
	ship["leg"] = 0.0
	var nav: Dictionary = _manual_nav(state, graph, ship, node)
	ship["dest"] = nav["node"]
	if military_hull(str(ship["kind"])):
		ship["operation_target"] = node
	_navigate(ship, point, minf(budget, maxf(0.0, pos.distance_to(point) - reach)))
	if (ship["position"] as Vector2).distance_to(point) <= reach + EPS:
		ship["at"] = nav["node"]
		return true
	return false


static func _finish_manual(ship: Dictionary) -> void:
	ship["route"] = []
	ship["leg"] = 0.0
	ship["dest"] = -1 if ship["kind"] not in ["fighter", "scout", "cruiser", "destroyer"] else int(ship["at"])
	ship.erase("move_only")
	if ship["kind"] in ["fighter", "scout", "cruiser", "destroyer"]:
		ship["operation_target"] = int(ship["at"])

static func _shift_yard_targets(state: Dictionary, node: int, slot: int) -> void:
	var removed: int = -2 - node * 3 - slot
	var last: int = -2 - node * 3 - 2
	for ship in state["ships"]:
		for key in ["attack_order", "repair_order", "repair_target"]:
			var target: int = int(ship.get(key, -1))
			if target == removed:
				ship.erase(key)
				if key != "repair_target":
					_finish_manual(ship)
			elif target < removed and target >= last:
				ship[key] = target + 1
		for order in [ship.get("unit_order", {})] + ship.get("order_queue", []):
			if order.get("kind", "") not in ["attack", "repair"]:
				continue
			var target: int = int(order.get("target", -1))
			if target == removed:
				order["target"] = -1
			elif target < removed and target >= last:
				order["target"] = target + 1

static func command_attack(state: Dictionary, player: int, ids: Array, target_id: int) -> bool:
	var target: Dictionary = service_targets(state, target_id).get(target_id, {})
	if target.is_empty() or not _hostile_hull(state, player, target):
		return false
	var units: Array = _owned_units(state, player, ids)
	if units.is_empty() or units.any(func(craft: Dictionary) -> bool: return not armed(craft)):
		return false
	for craft in units:
		_cancel_salvage_order(craft)
		_clear_tactical_order(craft)
		_clear_local_hold(craft)
		_interrupt_work(craft)
		craft["attack_order"] = target_id
		_set_unit_order(state, craft, {"kind": "attack", "target": target_id})
	return true

# Each persisted connection is one continuous neutral corridor, not two
# half-sectors. Use the smaller endpoint radius to keep field lanes narrow.
const LANE_RADIUS_FRACTION: float = 0.35

static func lane_radius(graph: Dictionary, a: int, b: int) -> float:
	return minf(float(graph["sector_radii"][a]), float(graph["sector_radii"][b])) * LANE_RADIUS_FRACTION

static func lane_contains(graph: Dictionary, a: int, b: int, point: Vector2) -> bool:
	var center: Vector2 = Geometry2D.get_closest_point_to_segment(point, graph["points"][a], graph["points"][b])
	return point.distance_squared_to(center) <= pow(lane_radius(graph, a, b) + EPS, 2.0)

static func lane_at(graph: Dictionary, point: Vector2, candidates: Array = []) -> Vector2i:
	var result := Vector2i(-1, -1)
	var best: float = INF
	for edge in graph["edges"]:
		var a: int = int(edge[0])
		var b: int = int(edge[1])
		if not candidates.is_empty() and (not candidates.has(a) or not candidates.has(b)):
			continue
		var center: Vector2 = Geometry2D.get_closest_point_to_segment(point, graph["points"][a], graph["points"][b])
		var distance: float = point.distance_squared_to(center)
		if distance < best and distance <= pow(lane_radius(graph, a, b) + EPS, 2.0):
			best = distance
			result = Vector2i(a, b)
	return result

# Fill bounded junctions between three mutually touching sector disks.
# Delaunay faces avoid filling the exterior or bridging distant clusters.
static func _index_navigation_junctions(graph: Dictionary) -> void:
	var points := PackedVector2Array(graph["points"])
	var indices: PackedInt32Array = Geometry2D.triangulate_delaunay(points)
	var cells: Dictionary = {}
	var width: float = graph["sector_cell_width"]
	for i in range(0, indices.size(), 3):
		var nodes := Vector3i(indices[i], indices[i + 1], indices[i + 2])
		var a: Vector2 = points[nodes.x]
		var b: Vector2 = points[nodes.y]
		var c: Vector2 = points[nodes.z]
		var radii: Array = graph["sector_radii"]
		if a.distance_to(b) > float(radii[nodes.x]) + float(radii[nodes.y]) or b.distance_to(c) > float(radii[nodes.y]) + float(radii[nodes.z]) or c.distance_to(a) > float(radii[nodes.z]) + float(radii[nodes.x]):
			continue
		var low: Vector2 = a.min(b).min(c) / width
		var high: Vector2 = a.max(b).max(c) / width
		for x in range(floori(low.x), floori(high.x) + 1):
			for y in range(floori(low.y), floori(high.y) + 1):
				var cell := Vector2i(x, y)
				if not cells.has(cell):
					cells[cell] = []
				cells[cell].append(nodes)
	graph["navigation_junction_cells"] = cells

static func _navigation_junctions(graph: Dictionary, point: Vector2) -> Array:
	if not graph.has("navigation_junction_cells"):
		return []
	var width: float = graph["sector_cell_width"]
	return graph["navigation_junction_cells"].get(Vector2i(floori(point.x / width), floori(point.y / width)), [])

static func _junction_contains(graph: Dictionary, nodes: Vector3i, point: Vector2, candidates: Array) -> bool:
	if not candidates.has(nodes.x) or not candidates.has(nodes.y) or not candidates.has(nodes.z):
		return false
	var points: Array = graph["points"]
	return Geometry2D.point_is_inside_triangle(point, points[nodes.x], points[nodes.y], points[nodes.z])

static func _junction_anchor(graph: Dictionary, point: Vector2, candidates: Array) -> int:
	var nearest: int = -1
	var best: float = INF
	for nodes in _navigation_junctions(graph, point):
		if not _junction_contains(graph, nodes, point, candidates):
			continue
		for node in [nodes.x, nodes.y, nodes.z]:
			var distance: float = point.distance_squared_to(graph["points"][node])
			if distance < best or (distance == best and node < nearest):
				nearest = node
				best = distance
	return nearest

static func lane_direct(graph: Dictionary, origin: Vector2, destination: Vector2, candidates: Array) -> bool:
	if not origin.is_finite() or not destination.is_finite():
		return false
	if _lane_direct_region(graph, origin, destination, candidates):
		return true
	# A triangle is convex, so crossing one enclosed junction is legal.
	for nodes in _navigation_junctions(graph, origin):
		if _junction_contains(graph, nodes, origin, candidates) and _junction_contains(graph, nodes, destination, candidates):
			return true
	return false

static func _lane_direct_region(graph: Dictionary, origin: Vector2, destination: Vector2, candidates: Array) -> bool:
	if not origin.is_finite() or not destination.is_finite():
		return false
	# A sector or corridor is convex. A shared region permits an exact straight leg.
	var sector: int = sector_at(graph, origin, candidates)
	if sector >= 0 and sector_contains(graph, sector, destination):
		return true
	var lane: Vector2i = lane_at(graph, origin, candidates)
	if lane.x >= 0 and lane_contains(graph, lane.x, lane.y, destination):
		return true
	# A center-to-center leg may begin in the sector and enter its corridor.
	if sector >= 0:
		for other in graph["adjacent"][sector]:
			if candidates.has(other) and lane_contains(graph, sector, other, origin) and lane_contains(graph, sector, other, destination):
				return true
	return false


static func patrol_node(state: Dictionary, graph: Dictionary, player: int, point: Vector2) -> int:
	# A discovered POI is only a bookkeeping anchor, not a movement boundary.
	if not point.is_finite() or (state["map"].has("size") and not Rect2(Vector2.ZERO, state["map"]["size"]).has_point(point)):
		return -1
	var candidates: Array[int] = military_pois(state, player)
	var best: float = INF
	var nearest: int = -1
	for node in candidates:
		var distance: float = point.distance_squared_to(graph["points"][node])
		if distance < best:
			best = distance
			nearest = node
	return nearest


static func _position_target_valid(state: Dictionary, graph: Dictionary, player: int, node: int, point: Vector2) -> bool:
	if not military_pois(state, player).has(node):
		return false
	# Validate finite map coordinates and a real known anchor. The nearest
	# anchor is canonical for UI orders; retain valid legacy local anchors.
	var anchor: int = patrol_node(state, graph, player, point)
	return anchor >= 0 and (anchor == node or sector_contains(graph, node, point))


static func command_patrol(state: Dictionary, player: int, ids: Array, target: int, point: Vector2 = Vector2.INF) -> bool:
	var selected: Array = _owned_fighters(state, player, ids)
	var graph: Dictionary = military_graph(state)
	if not military_pois(state, player).has(target) or selected.is_empty():
		return false
	var precise: bool = point != Vector2.INF
	if not precise:
		point = graph["points"][target]
	elif not _position_target_valid(state, graph, player, target, point):
		return false
	var origins: Dictionary = {}
	var starts: Dictionary = {}
	for craft in selected:
		var position: Vector2 = craft["position"]
		var origin: int = local_sector(graph, craft)
		if origin < 0:
			origin = int(craft["at"])
		if position.distance_to(point) <= EPS:
			return false
		if origin < 0 or not military_pois(state, player).has(origin):
			origin = patrol_node(state, graph, player, position)
		if origin < 0:
			return false
		origins[int(craft["id"])] = origin
		starts[int(craft["id"])] = position
	if not command_fighters(state, player, ids, target):
		return false
	for craft in selected:
		craft["patrol_from"] = origins[int(craft["id"])]
		craft["patrol_to"] = target
		craft["patrol_start_point"] = starts[int(craft["id"])]
		craft["patrol_end_point"] = point
		craft["patrol_returning"] = false
		craft["patrol_arrived"] = false
		if not craft.get("retreating", false):
			craft["route"] = []
			craft["leg"] = 0.0
		_set_unit_order(state, craft, {"kind": "patrol", "target": target, "point": point})
	return true

static func _update_tactical_orders(state: Dictionary, graph: Dictionary) -> void:
	var by_id: Dictionary = {}
	var paths: Dictionary = {}
	for craft in state["ships"]:
		if not armed(craft) or bool(craft.get("retreating", false)):
			continue
		var goal: int = -1
		var attack: int = int(craft.get("attack_order", -1))
		craft.erase("attack_local")
		if attack != -1:
			if by_id.is_empty():
				by_id = service_targets(state)
			var victim: Dictionary = by_id.get(attack, {})
			if victim.is_empty() or not _hostile_hull(state, int(craft["owner"]), victim):
				_clear_tactical_order(craft)
				_finish_manual(craft)
				continue
			goal = int(victim["node"]) if int(victim["node"]) >= 0 else _attack_destination(graph, victim["entity"])
			if goal < 0 or goal >= graph["points"].size():
				_clear_tactical_order(craft)
				continue
			var nav: Dictionary = _manual_nav(state, graph, craft, goal)
			if local_sector(graph, craft) == goal:
				craft["attack_local"] = true
				craft["at"] = nav["node"]
				craft["route"] = []
				craft["leg"] = 0.0
				craft["dest"] = nav["node"]
			elif int(craft.get("dest", -1)) != int(nav["node"]):
				_redirect_fighter(nav["graph"], craft, nav["node"], _military_paths(nav["graph"], nav["node"]))
			if craft["kind"] in ["fighter", "scout", "cruiser", "destroyer"]:
				craft["operation_target"] = goal
			continue
		elif craft.has("patrol_from") and craft.get("patrol_arrived", false) and not _engaged(craft):
			craft["patrol_returning"] = not bool(craft.get("patrol_returning", false))
			craft["patrol_arrived"] = false
			goal = int(craft["patrol_from"]) if craft["patrol_returning"] else int(craft["patrol_to"])
		if goal >= 0:
			craft["operation_target"] = goal
			if int(craft.get("dest", -1)) != goal:
				if not paths.has(goal):
					paths[goal] = _military_paths(graph, goal)
				_redirect_fighter(graph, craft, goal, paths[goal])

static func _owned_fighters(state: Dictionary, player: int, ids: Array) -> Array:
	var requested: Dictionary = {}
	for id in ids:
		if not id is int or requested.has(id):
			return []
		requested[id] = true
	var selected: Array = []
	for ship in state["ships"]:
		if requested.has(ship["id"]):
			if int(ship["owner"]) != player or ship.get("kind", "") not in ["fighter", "scout", "cruiser", "destroyer"]:
				return []
			selected.append(ship)
	if selected.size() != requested.size():
		return []
	return selected

# Explicit Hold captures each hull's own pose, including in empty space.
static func _capture_hold_pose(state: Dictionary, ship: Dictionary) -> void:
	if not ship.has("position"):
		return
	var graph: Dictionary = military_graph(state)
	var node: int = local_sector(graph, ship)
	if node < 0:
		node = int(ship["at"])
	ship["hold_position"] = ship["position"]
	ship["hold_heading"] = ship.get("heading", Vector2.UP)
	ship["hold_sector"] = node
	if not bool(ship.get("retreating", false)):
		_interrupt_work(ship)
		_finish_manual(ship)
		ship["navigation_target"] = ship["position"]

static func hold_fighters(state: Dictionary, player: int, ids: Array) -> bool:
	var selected: Array = _owned_fighters(state, player, ids)
	if selected.is_empty():
		return false
	for ship in selected:
		_cancel_salvage_order(ship)
		_clear_tactical_order(ship)
		_clear_local_hold(ship)
		_set_unit_order(state, ship, {})
		ship["direct_order"] = true
		ship["holding"] = true
		ship["operation_target"] = int(ship["at"])
		ship["pursuit_target"] = -1
		ship["pursuit_left"] = 0.0
		ship.erase("pursuit_blocked")
		ship.erase("rally_pending")
		_capture_hold_pose(state, ship)
	return true

# A local point is legal only within the hull's current physical sector.
# A miner at a field uses that field's sector, not its system anchor.
static func local_sector(graph: Dictionary, ship: Dictionary) -> int:
	var node: int = int(ship.get("at", -1))
	var pos: Vector2 = ship.get("position", Vector2.INF)
	if not pos.is_finite():
		return -1
	if ship.has("resource_stage"):
		var stage_node: int = int(ship["resource_stage"]["node"])
		if stage_node >= 0 and stage_node < graph["points"].size() and sector_contains(graph, stage_node, pos):
			return stage_node
	if ship.get("kind", "") == "miner" and ship.get("mining_mode", "") in ["outbound", "mining", "return"]:
		var field_node: int = int(graph["system_count"]) + int(ship.get("field", -1))
		if field_node >= int(graph["system_count"]) and field_node < graph["points"].size() and sector_contains(graph, field_node, pos):
			return field_node
	# An entering hull is already in the next sector once it crosses its
	# boundary along a real lane, even before reaching the central waypoint.
	var route: Array = ship.get("route", [])
	if not route.is_empty():
		var next: int = int(route[0])
		if next >= 0 and next < graph["points"].size() and sector_contains(graph, next, pos):
			return next
	return node if node >= 0 and node < graph["points"].size() and sector_contains(graph, node, pos) else -1

static func _owned_units(state: Dictionary, player: int, ids: Array) -> Array:
	var requested: Dictionary = {}
	for id in ids:
		if not id is int or requested.has(id):
			return []
		requested[id] = true
	if requested.size() == 1 and is_same(state, _indexed_state):
		var craft: Dictionary = _hulls_by_id.get(ids[0], {})
		return [craft] if not craft.is_empty() and int(craft["owner"]) == player and craft.get("kind", "") != "warp_gate" else []
	var units: Array = []
	for ship in state["ships"]:
		if requested.has(ship["id"]):
			if int(ship["owner"]) != player or ship.get("kind", "") == "warp_gate":
				return []
			units.append(ship)
	return units if units.size() == requested.size() else []

const MAX_UNIT_ORDERS: int = 30

# Project previous ship/command origins onto the dragged axis to minimize
# crossing, and choose the perpendicular closest to the group's travel.
static func line_formation_slots(origins: Dictionary, from: Vector2, to: Vector2) -> Array:
	return polyline_formation_slots(origins, PackedVector2Array([from, to]))

static func polyline_formation_slots(origins: Dictionary, stroke: PackedVector2Array) -> Array:
	var slots: Array = []
	if origins.size() < 2 or stroke.size() < 2:
		return slots
	var points := PackedVector2Array([stroke[0]])
	var lengths: Array[float] = [0.0]
	for i in range(1, stroke.size()):
		var span: float = points[-1].distance_to(stroke[i])
		if span > EPS:
			points.append(stroke[i])
			lengths.append(lengths[-1] + span)
	if points.size() < 2:
		return slots
	var centroid: Vector2 = Vector2.ZERO
	var ids: Array = origins.keys()
	var projections: Dictionary = {}
	for id in ids:
		centroid += origins[id]
		var nearest: float = INF
		for i in range(points.size() - 1):
			var delta: Vector2 = points[i + 1] - points[i]
			var t: float = ((origins[id] as Vector2) - points[i]).dot(delta) / delta.length_squared()
			var clamped: float = clampf(t, 0.0, 1.0)
			var distance: float = (origins[id] as Vector2).distance_squared_to(points[i].lerp(points[i + 1], clamped))
			if distance < nearest:
				nearest = distance
				projections[id] = lengths[i] + (t if points.size() == 2 else clamped) * delta.length()
	centroid /= ids.size()
	ids.sort_custom(func(a: int, b: int) -> bool:
		var first: float = projections[a]
		var second: float = projections[b]
		return a < b if is_equal_approx(first, second) else first < second)
	var segment: int = 0
	for i in range(ids.size()):
		var distance: float = lengths[-1] * float(i) / float(ids.size() - 1)
		while segment < points.size() - 2 and distance > lengths[segment + 1]:
			segment += 1
		var point: Vector2 = points[segment].lerp(points[segment + 1], (distance - lengths[segment]) / (lengths[segment + 1] - lengths[segment]))
		var heading: Vector2 = (points[segment + 1] - points[segment]).normalized().orthogonal()
		if heading.dot(point - centroid) < 0.0:
			heading = -heading
		slots.append({"id": ids[i], "point": point, "heading": heading})
	return slots

static func _set_unit_order(state: Dictionary, ship: Dictionary, order: Dictionary) -> void:
	_clear_resource_stage(ship)
	ship.erase("arrival_wait_until")
	ship.erase("manual_mine")
	ship.erase("wander_cooldown_override")
	ship.erase("follow_arrived")
	ship["auto_cooldown_until"] = float(state["elapsed"]) + AUTOCAST_COOLDOWN_YEARS
	ship.erase("order_queue")
	if order.is_empty():
		ship.erase("unit_order")
	else:
		ship["unit_order"] = order

# Resolve stable command destinations for validation, formation assignment and
# the selected order overlay. Missing moving targets have no valid endpoint.
static func unit_order_point(state: Dictionary, graph: Dictionary, ship: Dictionary, order: Dictionary) -> Vector2:
	var target: int = int(order.get("target", -1))
	match order.get("kind", ""):
		"position":
			return order.get("point", Vector2.INF)
		"patrol", "guard":
			if order.has("point"):
				return order["point"]
			if target >= 0 and target < graph["points"].size():
				return graph["points"][target]
		"sector_entry":
			if target >= 0 and target < graph["points"].size():
				if ship.get("unit_order", {}) == order and ship.has("local_move_target"):
					return ship["local_move_target"]
				return sector_entry_point(graph, target, ship["position"])
		"sector", "colonize":
			if target >= 0 and target < graph["points"].size():
				return graph["points"][target]
		"attack", "follow":
			return service_targets(state, target).get(target, {}).get("position", Vector2.INF)
		"repair":
			var ref: Dictionary = service_targets(state, target).get(target, {})
			return ref.get("repair_position", ref.get("position", Vector2.INF))
		"deposit":
			return service_targets(state, target).get(target, {}).get("position", Vector2.INF)
		"drop":
			return order.get("point", Vector2.INF)
		"salvage":
			return state.get("salvage", {}).get(target, {}).get("position", Vector2.INF)
		"collect":
			if target >= 0 and target < state["map"].get("fields", []).size():
				return state["map"]["fields"][target]["position"]
		"mine":
			if target >= 0 and target < state["map"].get("fields", []).size():
				var field: Dictionary = state["map"]["fields"][target]
				for rock in field.get("chunks", []):
					if int(rock["id"]) == int(order.get("chunk", -1)):
						return rock["position"]
				return field["position"]
		"unload":
			var destination: int = int(ship.get("dest", -1))
			if destination >= 0 and destination < state["planets"].size():
				return station_position(state, destination, float(state["elapsed"]))
	return Vector2.INF

static func unit_order_origin(state: Dictionary, graph: Dictionary, ship: Dictionary) -> Vector2:
	var orders: Array = ship.get("order_queue", [])
	for i in range(orders.size() - 1, -1, -1):
		var point: Vector2 = unit_order_point(state, graph, ship, orders[i])
		if point.is_finite():
			return point
	var active: Vector2 = unit_order_point(state, graph, ship, ship.get("unit_order", {})) if _unit_order_running(ship) else Vector2.INF
	if ship.has("patrol_from") and ship.get("patrol_returning", false):
		active = ship["patrol_start_point"]
	if not active.is_finite() and ship.has("launch_rally"):
		active = ship["launch_rally"]["point"]
	return active if active.is_finite() else ship["position"]

static func _unit_order_running(ship: Dictionary) -> bool:
	if bool(ship.get("retreating", false)):
		return true
	var order: Dictionary = ship.get("unit_order", {})
	match order.get("kind", ""):
		"position", "sector_entry":
			return ship.has("local_move_target")
		"sector":
			return not (ship["route"] as Array).is_empty() or (not bool(order.get("move_only", false)) and _engaged(ship))
		"follow":
			return (ship.get("order_queue", []) as Array).is_empty() or not bool(ship.get("follow_arrived", false))
		"attack":
			return ship.has("attack_order")
		"repair":
			return ship.has("repair_order")
		"deposit", "drop":
			return ship.has("cargo_order")
		"guard":
			return (ship.get("order_queue", []) as Array).is_empty() or not bool(ship.get("guard_arrived", false)) or _engaged(ship)
		"patrol":
			return ship.has("patrol_from") and ((ship.get("order_queue", []) as Array).is_empty() or not ship.get("patrol_arrived", false) or _engaged(ship))
		"salvage":
			return int(ship.get("salvage_target", -1)) >= 0
		"unload":
			return bool(ship.get("salvage_delivery", false))
		"colonize":
			return int(ship.get("dest", -1)) >= 0
		"warp_travel":
			return true
		"collect":
			return ship["kind"] == "science_ship" and _cargo_total(ship) < SCIENCE_CAPACITY - EPS
		"mine":
			var target: int = int(order["target"])
			return target >= 0 and int(ship.get("assigned_field", -1)) == target and (int(ship.get("field", -1)) != target or ship.get("mining_mode", "") != "mining")
	return ship.has("launch_rally")

static func _valid_unit_order(state: Dictionary, graph: Dictionary, ship: Dictionary, order: Dictionary, append: bool) -> bool:
	var kind: String = str(order.get("kind", ""))
	var owner: int = int(ship["owner"])
	var fighter: bool = ship["kind"] in ["fighter", "scout", "cruiser", "destroyer"]
	if kind == "warp_build":
		return not append and can_build_warp_gate(state, graph, ship)
	if kind == "warp_travel":
		return not append and order.get("target") is int and _warp_order_valid(state, ship, int(order["target"]))
	if ship.get("kind", "") == "warp_gate":
		return false
	if kind in ["stop", "hold"]:
		return true
	if ship["kind"] == "science_ship" and kind in ["unload", "drop", "deposit", "salvage"]:
		return false
	if ship["kind"] == "colony_ship" and kind in ["salvage", "drop"]:
		return false
	if kind == "transform":
		if not append:
			return can_transform_colony(state, graph, ship)
		if ship["kind"] != "colony_ship":
			return false
		var node: int = sector_at(graph, unit_order_origin(state, graph, ship), military_pois(state, owner))
		return node >= 0 and node < state["planets"].size() and int(state["planets"][node]["owner"]) == 0 and not has_station(state["planets"][node])
	if kind == "unload":
		return cargo_capacity(str(ship["kind"])) > EPS
	if kind == "drop":
		return cargo_capacity(str(ship["kind"])) > EPS and order.get("point") is Vector2 and patrol_node(state, graph, owner, order["point"]) >= 0
	if not order.get("target", null) is int:
		return false
	var target: int = order["target"]
	match kind:
		"position":
			if not order.get("point", null) is Vector2 or not _position_target_valid(state, graph, owner, target, order["point"]):
				return false
			if order.has("heading") and (not order["heading"] is Vector2 or not (order["heading"] as Vector2).is_finite() or (order["heading"] as Vector2).is_zero_approx()):
				return false
			return not bool(ship.get("retreating", false)) or append
		"guard":
			return fighter and military_pois(state, owner).has(target) and order.get("point") is Vector2 and _position_target_valid(state, graph, owner, target, order["point"])
		"patrol":
			if order.has("heading") and (not order["heading"] is Vector2 or not (order["heading"] as Vector2).is_finite() or (order["heading"] as Vector2).is_zero_approx()):
				return false
			return fighter and military_pois(state, owner).has(target) and (not order.has("point") or (order["point"] is Vector2 and _position_target_valid(state, graph, owner, target, order["point"])))
		"sector_entry":
			if target < 0 or target >= state["planets"].size() or not military_pois(state, owner).has(target) or bool(ship.get("retreating", false)):
				return false
			var nav: Dictionary = _manual_nav(state, graph, ship, target)
			return sector_contains(graph, target, ship["position"]) or _military_paths(nav["graph"], nav["node"])["distance"].has(int(ship["at"]))
		"sector":
			return military_pois(state, owner).has(target)
		"follow":
			var refs: Dictionary = service_targets(state, target)
			return (not bool(order.get("guard", false)) or fighter) and _valid_follow_target(state, ship, target, refs)
		"attack":
			return armed(ship) and _hostile_hull(state, owner, service_targets(state, target).get(target, {}))
		"repair":
			var ref: Dictionary = service_targets(state, target).get(target, {})
			return ship["kind"] == "miner" and target != int(ship["id"]) and _friendly_target(state, owner, ref) and _damaged(ref)
		"deposit":
			return can_deposit(state, ship, target)
		"salvage":
			return cargo_capacity(str(ship["kind"])) > EPS and state.get("salvage", {}).has(target)
		"colonize":
			return ship["kind"] == "colony_ship" and target >= 0 and target < state["planets"].size() and discovered(state, owner, "planets", target)
		"collect":
			return _science_target_valid(state, graph, ship, target)
		"mine":
			return ship["kind"] == "miner" and order.get("chunk", -1) is int and (target == -1 or (target >= 0 and target < state["map"].get("fields", []).size() and discovered(state, owner, "fields", target)))
	return false

static func _execute_unit_order(state: Dictionary, player: int, ids: Array, order: Dictionary) -> bool:
	var target: int = int(order.get("target", -1))
	match order["kind"]:
		"warp_build":
			var graph: Dictionary = military_graph(state)
			var changed: bool = false
			for ship in _owned_units(state, player, ids):
				changed = build_warp_gate(state, graph, ship) or changed
			return changed
		"warp_travel":
			for ship in _owned_units(state, player, ids):
				_cancel_salvage_order(ship)
				_clear_tactical_order(ship)
				_clear_local_hold(ship)
				_interrupt_work(ship)
				_finish_manual(ship)
				_set_unit_order(state, ship, order.duplicate(true))
			return true
		"stop":
			return command_stop_units(state, player, ids)
		"hold":
			return command_hold_units(state, player, ids, false)
		"transform":
			var graph: Dictionary = military_graph(state)
			var converted: bool = false
			for ship in _owned_units(state, player, ids):
				if can_transform_colony(state, graph, ship):
					_convert_colony(state, ship, local_sector(graph, ship))
					_remove_indexed_hull(state, ship)
					converted = true
			return converted
		"follow":
			var units: Array = _owned_units(state, player, ids)
			var refs: Dictionary = service_targets(state)
			if units.is_empty() or units.any(func(ship: Dictionary) -> bool: return not _valid_follow_target(state, ship, target, refs)):
				return false
			for ship in units:
				_cancel_salvage_order(ship)
				_clear_tactical_order(ship)
				_clear_local_hold(ship)
				_interrupt_work(ship)
				_set_unit_order(state, ship, order.duplicate(true))
				# Retain an in-flight lane until the follow worker replans it.
				ship["dest"] = -1
				ship["move_only"] = not bool(order.get("guard", false))
			return true
		"sector_entry":
			var graph: Dictionary = military_graph(state)
			var center: Vector2 = graph["points"][target]
			var move_only: bool = bool(order.get("move_only", false))
			var accepted: bool = command_local_position(state, player, ids, target, center, move_only)
			if not accepted:
				accepted = command_remote_position(state, player, ids, target, center, move_only)
			if not accepted:
				return false
			for ship in _owned_units(state, player, ids):
				var origin: Vector2 = ship["position"]
				var route: Array = ship["route"]
				if route.size() > 1:
					origin = graph["points"][int(route[-2])]
				var point: Vector2 = sector_entry_point(graph, target, origin)
				ship["local_move_target"] = point
				ship["navigation_target"] = point
				ship["unit_order"] = {"kind": "sector_entry", "target": target, "move_only": move_only}
			return true
		"sector":
			if _owned_fighters(state, player, ids).size() == ids.size():
				return command_fighters(state, player, ids, target, bool(order.get("move_only", false)))
			var graph: Dictionary = military_graph(state)
			return _execute_unit_order(state, player, ids, {"kind": "position", "target": target, "point": graph["points"][target], "move_only": order.get("move_only", false)})
		"attack":
			return command_attack(state, player, ids, target)
		"guard":
			if not command_fighters(state, player, ids, target):
				return false
			for ship in _owned_fighters(state, player, ids):
				_set_unit_order(state, ship, {"kind": "guard", "target": target, "point": order["point"]})
				ship["guard_arrived"] = false
			return true
		"patrol":
			var accepted: bool = command_patrol(state, player, ids, target, order.get("point", Vector2.INF))
			if accepted and order.has("heading"):
				for ship in _owned_units(state, player, ids):
					ship["unit_order"]["heading"] = order["heading"]
			return accepted
		"collect":
			for ship in _owned_units(state, player, ids):
				_cancel_salvage_order(ship)
				_clear_tactical_order(ship)
				_clear_local_hold(ship)
				_interrupt_work(ship)
				_set_unit_order(state, ship, {"kind": "collect", "target": target})
				ship["science_years"] = 0.0
			return true
		"mine":
			return command_miners(state, player, ids, target, int(order.get("chunk", -1)))
		"salvage":
			return command_salvage(state, player, ids, target)
		"unload":
			return command_unload_cargo(state, player, ids)
		"repair", "deposit", "drop":
			return command_service(state, player, ids, order)
		"colonize":
			return ids.size() == 1 and send_colony(state, player, ids[0], target)
		"position":
			var accepted: bool = command_local_position(state, player, ids, target, order["point"], bool(order.get("move_only", false)))
			if not accepted:
				accepted = command_remote_position(state, player, ids, target, order["point"], bool(order.get("move_only", false)))
			if accepted:
				for ship in _owned_units(state, player, ids):
					ship["unit_order"] = order.duplicate(true)
					if order.has("heading"):
						ship["arrival_heading"] = (order["heading"] as Vector2).normalized()
			return accepted
	return false

# All mutation takes place on the authority. A pending command never reserves
# salvage or changes the current route until it actually starts.
static func issue_unit_order(state: Dictionary, player: int, ids: Array, order: Dictionary, append: bool) -> bool:
	if order.get("kind") == "warp_link":
		return not append and ids.size() == 1 and ids[0] is int and order.get("target") is int and set_warp_destination(state, player, int(ids[0]), int(order["target"]))
	var units: Array = _owned_units(state, player, ids)
	if units.is_empty():
		return false
	var graph: Dictionary = military_graph(state)
	for ship in units:
		if not _valid_unit_order(state, graph, ship, order, append):
			return false
	if not append:
		return _execute_unit_order(state, player, ids, order)
	var all_idle: bool = true
	for ship in units:
		if _unit_order_running(ship) or not (ship.get("order_queue", []) as Array).is_empty():
			all_idle = false
			break
	if all_idle:
		return _execute_unit_order(state, player, ids, order)
	var accepted: bool = false
	for ship in units:
		var queue: Array = ship.get("order_queue", [])
		if queue.size() + int(_unit_order_running(ship)) >= MAX_UNIT_ORDERS:
			continue
		queue.append(order.duplicate(true))
		ship["order_queue"] = queue
		ship.erase("wander_cooldown_override")
		ship["auto_cooldown_until"] = float(state["elapsed"]) + AUTOCAST_COOLDOWN_YEARS
		accepted = true
	return accepted

static func _mark_sector_arrival(state: Dictionary, ship: Dictionary) -> void:
	var order: Dictionary = ship.get("unit_order", {})
	if order.get("kind", "") == "sector" and not ship.has("arrival_wait_until") and not bool(ship.get("retreating", false)) and (ship["route"] as Array).is_empty() and int(ship["at"]) == int(order["target"]):
		ship["arrival_wait_until"] = float(state["elapsed"]) + MOVE_ARRIVAL_WAIT_YEARS

static func arrival_wait_remaining(state: Dictionary, ship: Dictionary) -> float:
	return maxf(0.0, float(ship.get("arrival_wait_until", 0.0)) - float(state.get("elapsed", 0.0)))

static func _advance_unit_orders(state: Dictionary, graph: Dictionary) -> void:
	for ship in (state["ships"] as Array).duplicate():
		if bool(ship.get("rogue", false)):
			continue
		_mark_sector_arrival(state, ship)
		if _unit_order_running(ship):
			continue
		if ship.get("unit_order", {}).get("kind", "") == "follow":
			_finish_manual(ship)
			ship.erase("follow_arrived")
		ship.erase("unit_order")
		var queue: Array = ship.get("order_queue", [])
		while not queue.is_empty():
			var order: Dictionary = queue.pop_front()
			if _valid_unit_order(state, graph, ship, order, false) and _execute_unit_order(state, int(ship["owner"]), [ship["id"]], order):
				break
		if queue.is_empty():
			ship.erase("order_queue")
		else:
			ship["order_queue"] = queue

static func _clear_local_move(ship: Dictionary) -> void:
	ship.erase("local_move_target")
	ship.erase("local_move_sector")
	ship.erase("arrival_heading")

static func _clear_local_hold(ship: Dictionary) -> void:
	_clear_local_move(ship)
	ship.erase("science_years")
	ship.erase("launch_rally")
	ship.erase("move_only")
	if bool(ship.get("holding", false)) and ship.get("kind", "") == "miner" and ship.get("mining_mode", "") == "mining":
		# Resume extraction only after physically returning to the rock.
		ship["mining_mode"] = "outbound"
	ship["holding"] = false
	ship.erase("hold_position")
	ship.erase("hold_sector")
	ship.erase("hold_heading")

static func command_local_position(state: Dictionary, player: int, ids: Array, node: int, point: Vector2, move_only: bool = false) -> bool:
	if not point.is_finite() or not military_pois(state, player).has(node):
		return false
	var graph: Dictionary = military_graph(state)
	if not sector_contains(graph, node, point):
		return false
	var units: Array = _owned_units(state, player, ids)
	if units.is_empty():
		return false
	for ship in units:
		if not sector_contains(graph, node, ship["position"]) or bool(ship.get("retreating", false)):
			return false
	for ship in units:
		_cancel_salvage_order(ship)
		_clear_tactical_order(ship)
		_clear_local_hold(ship)
		_interrupt_work(ship)
		_set_unit_order(state, ship, {"kind": "position", "target": node, "point": point, "move_only": move_only})
		ship["local_move_target"] = point
		ship["local_move_sector"] = node
		ship["move_only"] = move_only
		ship["navigation_target"] = point
		# Extraction must resume by returning to the actual rock.
		if ship.get("kind", "") == "miner" and ship.get("mining_mode", "") == "mining":
			ship["mining_mode"] = "outbound"
		if ship.get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"]:
			ship["direct_order"] = true
			# Once physical containment is validated, normalize the stale lane
			# anchor to the actual sector before clearing its route.
			ship["at"] = node
			ship["operation_target"] = node
			ship["dest"] = node
			ship["route"] = []
			ship["leg"] = 0.0
			ship["pursuit_target"] = -1
			ship["pursuit_left"] = 0.0
			ship.erase("rally_pending")
			ship.erase("pursuit_blocked")
	return true

static func command_remote_position(state: Dictionary, player: int, ids: Array, node: int, point: Vector2, move_only: bool) -> bool:
	var units: Array = _owned_units(state, player, ids)
	var graph: Dictionary = military_graph(state)
	if units.is_empty() or not _position_target_valid(state, graph, player, node, point):
		return false
	for ship in units:
		if bool(ship.get("retreating", false)):
			return false
	for ship in units:
		_cancel_salvage_order(ship)
		_clear_tactical_order(ship)
		_clear_local_hold(ship)
		_interrupt_work(ship)
		var nav: Dictionary = _manual_nav(state, graph, ship, node)
		ship["route"] = []
		ship["leg"] = 0.0
		ship["dest"] = nav["node"]
		if ship["kind"] in ["fighter", "scout", "cruiser", "destroyer"]:
			ship["operation_target"] = node
		ship["local_move_target"] = point
		ship["local_move_sector"] = node
		ship["move_only"] = move_only
		ship["navigation_target"] = point
		_set_unit_order(state, ship, {"kind": "position", "target": node, "point": point, "move_only": move_only})
	return true

# Stop cancels work and queued movement without imposing a persistent hold.

static func command_stop_units(state: Dictionary, player: int, ids: Array) -> bool:
	var units: Array = _owned_units(state, player, ids)
	if units.is_empty():
		return false
	var graph: Dictionary = military_graph(state)
	for ship in units:
		var retreating: bool = bool(ship.get("retreating", false))
		var sector: int = local_sector(graph, ship)
		_cancel_salvage_order(ship)
		_clear_tactical_order(ship)
		_clear_local_hold(ship)
		_set_unit_order(state, ship, {})
		ship.erase("pursuit_blocked")
		ship.erase("rally_pending")
		ship.erase("passing_fire")
		ship["combat_target"] = -1
		ship["pursuit_target"] = -1
		ship["pursuit_left"] = 0.0
		ship["laser_until"] = -1.0
		ship["yard_target"] = -1
		ship["yard_laser_until"] = -1.0
		# Emergency repair travel retains its route and destination.
		if retreating:
			continue
		if sector >= 0 and (ship["kind"] in ["fighter", "scout", "cruiser", "destroyer"] or sector < state["planets"].size()):
			ship["at"] = sector
		_interrupt_work(ship)
		_finish_manual(ship)
		ship["navigation_target"] = ship["position"]
		ship["arrival_wait_until"] = float(state["elapsed"]) + MOVE_ARRIVAL_WAIT_YEARS
	return true

static func command_hold_units(state: Dictionary, player: int, ids: Array, release: bool) -> bool:
	var units: Array = _owned_units(state, player, ids)
	if units.is_empty():
		return false
	for ship in units:
		_set_unit_order(state, ship, {})
		ship.erase("launch_rally")
		_cancel_salvage_order(ship)
		if release:
			if not bool(ship.get("holding", false)):
				continue
			_clear_local_hold(ship)
			if ship.get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"]:
				ship["operation_target"] = int(ship["at"])
				if not bool(ship.get("retreating", false)):
					ship["dest"] = -1
		elif ship.get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"]:
			hold_fighters(state, player, [ship["id"]])
		else:
			_clear_tactical_order(ship)
			_clear_local_hold(ship)
			ship["holding"] = true
			_capture_hold_pose(state, ship)
	return true

# A local move is a one-shot order, not a persistent hold. Keep the
# destination through a repair detour, and resume the normal idle/working
# behavior after a short arrival grace period; queued orders can start immediately.
static func _work_local_move(graph: Dictionary, ship: Dictionary, dt: float, state: Dictionary = {}) -> bool:
	if not ship.has("local_move_target") or bool(ship.get("retreating", false)):
		return false
	var fighter: bool = ship.get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"]
	if fighter and _engaged(ship):
		return false
	var node: int = int(ship["local_move_sector"])
	var destination: Vector2 = ship["local_move_target"]
	if not state.is_empty():
		var nav: Dictionary = _manual_nav(state, graph, ship, node)
		ship["route"] = []
		ship["leg"] = 0.0
		ship["dest"] = nav["node"]
		if _manual_travel(state, graph, ship, node, destination, dt):
			ship["at"] = nav["node"]
			if ship.has("arrival_heading"):
				ship["heading"] = ship["arrival_heading"]
			_clear_local_move(ship)
			_finish_manual(ship)
			ship["arrival_wait_until"] = float(state["elapsed"]) + MOVE_ARRIVAL_WAIT_YEARS
		return true
	if fighter and not sector_contains(graph, node, ship["position"]):
		if int(ship.get("dest", -1)) != node:
			_redirect_fighter(graph, ship, node, _military_paths(graph, node))
		var entry: bool = ship.get("unit_order", {}).get("kind", "") == "sector_entry"
		if (ship["route"] as Array).is_empty():
			_navigate(ship, ship["local_move_target"] if entry else graph["points"][node], ship_speed(str(ship.get("kind", "ship"))) * dt)
		else:
			_move({"map": graph}, ship, dt, ship["local_move_target"] if entry else Vector2.INF, node)
		return true
	var point: Vector2 = ship["local_move_target"]
	_navigate(ship, point, ship_speed(str(ship.get("kind", "ship"))) * dt)
	if (ship["position"] as Vector2).distance_to(point) <= EPS:
		if ship.has("arrival_heading"):
			ship["heading"] = ship["arrival_heading"]
		_clear_local_move(ship)
		ship.erase("move_only")
		if not state.is_empty():
			ship["arrival_wait_until"] = float(state["elapsed"]) + MOVE_ARRIVAL_WAIT_YEARS
		if fighter:
			ship["at"] = node
			ship["dest"] = node
			ship["operation_target"] = node
			ship["route"] = []
			ship["leg"] = 0.0
	return true

static func _work_local_hold(graph: Dictionary, ship: Dictionary, dt: float) -> void:
	if not ship.has("hold_position"):
		ship["navigation_target"] = ship["position"]
		return
	var node: int = int(ship["hold_sector"])
	if (ship["position"] as Vector2).distance_to(ship["hold_position"]) <= EPS:
		ship["navigation_target"] = ship["hold_position"]
		if ship.has("hold_heading"):
			ship["heading"] = ship["hold_heading"]
		ship.erase("move_only")
		return
	# Repair may have taken a fighter to another sector. Return by lanes.
	if ship.get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"] and int(ship["at"]) != node and not sector_contains(graph, node, ship["position"]):
		if int(ship.get("dest", -1)) != node:
			_redirect_fighter(graph, ship, node, _military_paths(graph, node))
		if (ship["route"] as Array).is_empty():
			_navigate(ship, graph["points"][node], ship_speed(str(ship.get("kind", "ship"))) * dt)
		else:
			_move({"map": graph}, ship, dt)
		return
	_navigate(ship, ship["hold_position"], ship_speed(str(ship.get("kind", "ship"))) * dt)
	if (ship["position"] as Vector2).distance_to(ship["hold_position"]) <= EPS:
		if ship.has("hold_heading"):
			ship["heading"] = ship["hold_heading"]
		ship.erase("move_only")

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
	if ship.has("position"):
		return ship["position"]
	var points: Array = graph["points"] if ship.get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"] else state["map"]["points"]
	return _initial_position(points, ship)

# Influence derives from physical state. Fully friendly influence also permits
# manual navigation shortcuts; ownership and conquest remain separate.
const INFLUENCE_CAP: float = 50.0
const INFLUENCE_SPILLOVER: float = 0.05
const INFLUENCE_SPILLOVER_MIN: float = 50.0
const SHIP_INFLUENCE = {"scout": 1, "fighter": 2, "cruiser": 5, "destroyer": 10, "miner": 1, "ship": 1, "colony_ship": 1, "science_ship": 1}
const STATION_INFLUENCE: int = 30
const YARD_INFLUENCE: int = 20
const BUILDING_INFLUENCE: int = 10

# Highway influence sections are independent of the navigation graph.
# Split each centerline into equal lengths no greater than this cap.
const HIGHWAY_MAX_LENGTH: float = 3000.0

static func highway_regions(graph: Dictionary) -> Dictionary:
	if graph.has("highway_regions"):
		return graph["highway_regions"]
	var points: Array = graph["points"]
	var edges: Array = graph["edges"]
	var starts: Array[int] = []
	var counts: Array[int] = []
	var region_edges: Array[int] = []
	for i in range(edges.size()):
		var a: Vector2 = points[int(edges[i][0])]
		var b: Vector2 = points[int(edges[i][1])]
		var count: int = maxi(1, ceili(a.distance_to(b) / HIGHWAY_MAX_LENGTH))
		starts.append(points.size() + region_edges.size())
		counts.append(count)
		for j in range(count):
			region_edges.append(i)
	# Economic influence follows immediate region neighbors: core to first
	# highway section, section to section, last section to the other core.
	var links: Array[Vector2i] = []
	for i in range(edges.size()):
		var start: int = starts[i]
		var count: int = counts[i]
		links.append(Vector2i(int(edges[i][0]), start))
		for j in range(count - 1):
			links.append(Vector2i(start + j, start + j + 1))
		links.append(Vector2i(start + count - 1, int(edges[i][1])))
	var layout: Dictionary = {"starts": starts, "counts": counts, "region_edges": region_edges, "size": points.size() + region_edges.size(), "links": links}
	graph["highway_regions"] = layout
	return layout

# The political tessellation shares the original system/field/highway IDs.
static func sector_geometry(graph: Dictionary) -> Dictionary:
	if not graph.has("sector_geometry"):
		graph["sector_geometry"] = SECTOR_GEOMETRY.build(graph["points"], graph["edges"], highway_regions(graph), graph.get("map_size", MAP.SIZE))
	return graph["sector_geometry"]

static func influence_region(graph: Dictionary, point: Vector2) -> int:
	return SECTOR_GEOMETRY.region_at(sector_geometry(graph), point)

# A friendly shortcut requires full-strength allied influence with no
# competing empire. Sample the authoritative influence once per movement
# phase, then test exact segments against the immutable cells.
static func friendly_sector_travel(state: Dictionary, graph: Dictionary, player: int, origin: Vector2, destination: Vector2) -> bool:
	var during_step: bool = is_same(graph, _sector_query_graph)
	var by_player: Dictionary = graph.get("travel_permissions", {}) if during_step else {}
	if not by_player.has(player) and (not during_step or not graph.has("travel_influence")):
		var current: Array[Dictionary] = territory_influence(state, graph)
		if not during_step:
			return SECTOR_GEOMETRY.segment_allowed(sector_geometry(graph), origin, destination, _fully_friendly_cells(state, player, current))
		graph["travel_influence"] = current
	if not by_player.has(player):
		by_player[player] = _fully_friendly_cells(state, player, graph["travel_influence"])
		graph["travel_permissions"] = by_player
	return SECTOR_GEOMETRY.segment_allowed(sector_geometry(graph), origin, destination, by_player[player])

static func _fully_friendly_cells(state: Dictionary, player: int, weights: Array) -> Dictionary:
	var allowed: Dictionary = {}
	for i in range(weights.size()):
		var friendly: float = 0.0
		var competing: bool = false
		for owner in weights[i]:
			if empires_allied(state, player, int(owner)):
				friendly += float(weights[i][owner])
			elif float(weights[i][owner]) > EPS:
				competing = true
		if not competing and friendly >= INFLUENCE_CAP:
			allowed[i] = true
	return allowed

# Shared physical presence weights; no ownership changes or spatial rules.
static func system_presence_weight(system: Dictionary) -> int:
	var points: int = STATION_INFLUENCE if has_station(system) else 0
	points += YARD_INFLUENCE * (system.get("yards", []) as Array).size()
	var buildings: int = (system.get("pds", {}) as Dictionary).size() + int(system.get("orbital_housing", 0))
	for count in system.get("buildings", {}).values():
		buildings += int(count)
	return points + BUILDING_INFLUENCE * buildings

static func ship_presence_weight(ship: Dictionary) -> int:
	return int(SHIP_INFLUENCE.get(ship["kind"], BUILDING_INFLUENCE if ship["kind"] == "warp_gate" else 1))

static func territory_influence(state: Dictionary, graph: Dictionary, known_pois: Variant = null, region_cache: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(int(highway_regions(graph)["size"])):
		result.append({})
	for i in range(state["planets"].size()):
		var system: Dictionary = state["planets"][i]
		var owner: int = int(system["owner"])
		if owner <= 0:
			continue
		var points: int = system_presence_weight(system)
		if points > 0:
			result[i][owner] = points
	var live_regions: Dictionary = {}
	for ship in state["ships"]:
		var owner: int = int(ship["owner"])
		var weight: int = ship_presence_weight(ship)
		if owner <= 0 or float(ship.get("hp", ship_max_hp(str(ship["kind"])))) <= 0.0:
			continue
		var id: int = int(ship["id"])
		var point: Vector2 = combat_position(state, graph, ship)
		var prior: Variant = region_cache.get(id)
		var region: int = -1
		if prior != null and prior[0] == point:
			region = int(prior[1])
		else:
			region = influence_region(graph, point)
		live_regions[id] = [point, region]
		if region >= 0:
			result[region][owner] = int(result[region].get(owner, 0)) + weight
	region_cache.clear()
	region_cache.merge(live_regions)
	var layout: Dictionary = highway_regions(graph)
	var visible: Array[bool] = []
	if known_pois != null:
		# Preserve discovery boundaries: a hidden donor must not reveal its
		# fleet through the influence color of a discovered neighbor.
		for i in range(result.size()):
			var known: bool = known_pois.has(i)
			if i >= graph["points"].size():
				var edge: Array = graph["edges"][layout["region_edges"][i - graph["points"].size()]]
				known = known_pois.has(int(edge[0])) and known_pois.has(int(edge[1]))
			visible.append(known)
	return influence_spillover(result, sector_geometry(graph)["links"], visible)

# Use only direct influence to decide direction and transfer amounts.
# Incoming points never propagate again or change eligibility in this pass.
static func influence_spillover(direct: Array[Dictionary], links: Array, visible: Array[bool] = []) -> Array[Dictionary]:
	var totals: Array[float] = []
	var result: Array[Dictionary] = []
	for i in range(direct.size()):
		var weights: Dictionary = direct[i] if visible.is_empty() or visible[i] else {}
		var total: float = 0.0
		for value in weights.values():
			total += float(value)
		totals.append(total)
		result.append(weights.duplicate())
	for link in links:
		var a: int = link.x
		var b: int = link.y
		if not visible.is_empty() and (not visible[a] or not visible[b]):
			continue
		if totals[a] == totals[b]:
			continue
		var donor: int = a if totals[a] > totals[b] else b
		var receiver: int = b if donor == a else a
		if totals[donor] < INFLUENCE_SPILLOVER_MIN:
			continue
		for owner in direct[donor]:
			result[receiver][owner] = float(result[receiver].get(owner, 0.0)) + float(direct[donor][owner]) * INFLUENCE_SPILLOVER
	return result

# RGB is the normalized weighted mean; alpha carries influence strength.
# Never clamp individual players' points before computing their share.
static func influence_color(weights: Dictionary, colors: Dictionary) -> Color:
	var sum := Vector3.ZERO
	var total: float = 0.0
	for owner in weights:
		var weight: float = maxf(0.0, float(weights[owner]))
		var tint: Color = colors.get(owner, Color("#99aebf"))
		sum += Vector3(tint.r, tint.g, tint.b) * weight
		total += weight
	if total <= 0.0:
		return Color(0.60, 0.68, 0.76, 0.0)
	sum /= total
	return Color(sum.x, sum.y, sum.z, minf(total / INFLUENCE_CAP, 1.0))

# Only settled infrastructure or resident population creates territory.
# Hostile presence or combat can still suppress existing territory.
static func territory_claims(state: Dictionary) -> Array[int]:
	var graph: Dictionary = military_graph(state)
	var points: Array = graph["points"]
	var claims: Array[int] = planet_teams(state)
	for i in range(state["planets"].size()):
		var system: Dictionary = state["planets"][i]
		if not has_station(system):
			claims[i] = 0
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
		var team: int = _combat_group(state, int(ship["owner"]))
		if team <= 0:
			continue
		var stationary: bool = (ship["route"] as Array).is_empty() and not _engaged(ship) and not ship.has("patrol_from")
		if stationary:
			node = int(ship["at"])
			if claims[node] != 0 and _combat_groups_hostile(state, team, claims[node]):
				contested[node] = true
		if stationary or nearest <= LASER_RANGE * LASER_RANGE:
			if state.has("diplomacy"):
				if not presence.has(node):
					presence[node] = {}
				var occupants: Dictionary = presence[node]
				if _combat_sector_has_hostile(presence, node, team, state):
					contested[node] = true
				occupants[team] = true
			else:
				if presence.has(node) and int(presence[node]) != team:
					contested[node] = true
				presence[node] = team
	for node in presence:
		if claims[node] <= 0:
			continue
		if state.has("diplomacy"):
			if _combat_sector_has_hostile(presence, node, claims[node], state):
				contested[node] = true
		elif claims[node] != int(presence[node]):
			contested[node] = true
	for ship in state["ships"]:
		var target: int = int(ship.get("combat_target", -1))
		if target >= 0 and near_ship.has(target) and (not state.has("diplomacy") or _hostile_hull(state, int(ship["owner"]), service_targets(state, target).get(target, {}))):
			contested[near_ship[int(ship["id"])]] = true
			contested[near_ship[target]] = true
	for node in contested:
		claims[node] = 0
	return claims

# Empire color derives from the system's actual owner, never a ship.
static func territory_empires(state: Dictionary) -> Array[int]:
	var claims: Array[int] = territory_claims(state)
	var owners: Array[int] = []
	owners.resize(claims.size())
	owners.fill(0)
	for i in range((state["planets"] as Array).size()):
		if claims[i] > 0:
			owners[i] = int(state["planets"][i]["owner"])
	return owners

static func _engaged(ship: Dictionary) -> bool:
	return (int(ship.get("combat_target", -1)) >= 0 and not bool(ship.get("passing_fire", false))) or int(ship.get("pursuit_target", -1)) >= 0

# Civilian hulls do not pursue, even if armed. A fighter fleeing along a route (or
# explicitly withdrawing in a future retreat system) is also eligible.
static func _fleeing(other: Dictionary, away: Vector2, previous_target: int) -> bool:
	if other.get("kind", "") not in ["fighter", "scout", "cruiser", "destroyer"] or bool(other.get("retreating", false)):
		return true
	var heading: Vector2 = other.get("heading", Vector2.ZERO)
	return previous_target < 0 and not (other["route"] as Array).is_empty() and heading.dot(away.normalized()) > 0.25

# Bounded, round-scoped combat event history travels in existing reliable
# snapshots. Never infer a kill from a disappearing colony or eliminated fleet.
static func _record_ship_destruction(state: Dictionary, graph: Dictionary, ship: Dictionary) -> void:
	var sequence: int = int(state.get("next_destruction_id", 1))
	state["next_destruction_id"] = sequence + 1
	var cargo: Dictionary = ship.get("cargo", {})
	var materials: Array[String] = []
	for resource in RESOURCES + [ANTIMATTER]:
		if float(cargo.get(resource, 0.0)) > EPS:
			materials.append(resource)
	var events: Array = state.get("ship_destructions", [])
	events.append({"sequence": sequence, "ship": int(ship["id"]), "kind": str(ship["kind"]), "owner": int(ship["owner"]), "position": combat_position(state, graph, ship), "heading": ship.get("heading", Vector2.UP), "materials": materials})
	if events.size() > 128:
		events.pop_front()
	state["ship_destructions"] = events
	_drop_salvage(state, ship, combat_position(state, graph, ship), sequence)

# Cargo survives the kill in full. Roll structural recovery independently for
# every material, using a private deterministic stream (no economy RNG effects).
static func _drop_salvage(state: Dictionary, ship: Dictionary, position: Vector2, sequence: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state["map"].get("seed", 0)) + sequence * 104729
	var decay_rng := RandomNumberGenerator.new()
	decay_rng.seed = int(state["map"].get("seed", 0)) + sequence * 15485863 + 32452843
	var recipe: Dictionary = _cost(str(ship["kind"]), 1)
	var cargo: Dictionary = ship.get("cargo", {})
	var piles: Dictionary = state.get("salvage", {})
	for resource in RESOURCES + [ANTIMATTER]:
		var tons: float = maxf(0.0, float(cargo.get(resource, 0.0)))
		if recipe.has(resource) and rng.randf() < SALVAGE_CHANCE:
			tons += float(recipe[resource]) * rng.randf_range(0.0, SALVAGE_FRACTION)
		if tons <= EPS:
			continue
		var id: int = int(state.get("next_salvage_id", 1))
		state["next_salvage_id"] = id + 1
		var angle: float = rng.randf_range(0.0, TAU)
		var origin: Vector2 = position + Vector2.from_angle(angle) * rng.randf_range(10.0, 36.0)
		var born: float = float(state["elapsed"])
		piles[id] = {"id": id, "resource": resource, "amount": tons, "origin": origin, "position": origin, "drift": Vector2.from_angle(angle + PI * 0.5) * rng.randf_range(4.0, 10.0), "born": born, "expires_at": born + decay_rng.randf_range(SALVAGE_MIN_LIFETIME, SALVAGE_MAX_LIFETIME), "claim": -1}
	state["salvage"] = piles

# The station is the sole ownership anchor. Its stock is physically lost:
# exactly 20% of each stored resource becomes normal drifting salvage.
static func _destroy_station(state: Dictionary, graph: Dictionary, index: int) -> void:
	var p: Dictionary = state["planets"][index]
	if not has_station(p):
		return
	var owner: int = int(p["owner"])
	var point: Vector2 = station_position(state, index, float(state["elapsed"]))
	var salvage: Dictionary = empty_stock()
	for resource in RESOURCES + [ANTIMATTER]:
		salvage[resource] = float(p["stock"].get(resource, 0.0)) * STATION_SALVAGE_FRACTION
		p["stock"][resource] = 0.0
	_record_ship_destruction(state, graph, {"id": station_target_id(state, index), "kind": "station", "owner": owner, "position": point, "heading": Vector2.UP, "cargo": salvage})
	for slot in range(p["yards"].size()):
		_record_ship_destruction(state, graph, {"id": -2 - index * 3 - slot, "kind": "shipyard", "owner": owner, "position": shipyard_position(state, index, slot, float(state["elapsed"])), "heading": Vector2.UP})
	p["station"] = {}
	p["owner"] = 0
	p["home"] = false
	p["population"] = 0.0
	p["eco_population"] = 0.0
	p["population_velocity"] = 0.0
	p["demographic_rate"] = 0.0
	p["crew_rate"] = 0.0
	p["orbital_housing"] = 0
	p["warehouse_level"] = 0
	p["levels"] = empty_stock()
	p["buildings"] = {}
	p["yards"] = []
	p["pds"] = {}
	p["queue"] = []
	p["continuous"] = {}
	p["maintain"] = {}
	p["repeat_cycle"] = {}
	p["flows"] = {}
	p.erase("capture")
	for resource in RESOURCES:
		p["thresholds"][resource] = {"min": DEFAULT_IMPORT_PERCENT, "max": DEFAULT_EXPORT_PERCENT}
	_reroute_after_capture(state, index)

static func station_target_id(state: Dictionary, index: int) -> int:
	# Three yard IDs plus six possible PDS IDs per system precede stations.
	return -2 - state["planets"].size() * 9 - index

static func _salvage_active(ship: Dictionary) -> bool:
	return int(ship.get("salvage_target", -1)) >= 0 or bool(ship.get("salvage_delivery", false))

static func _cancel_salvage_order(ship: Dictionary) -> void:
	ship.erase("resource_haul")
	ship.erase("farm_auto_delivery")
	ship.erase("salvage_target")
	ship.erase("auto_salvage_target")
	ship.erase("auto_salvage_origin")
	ship.erase("tractor_active")
	if bool(ship.get("salvage_delivery", false)):
		ship["route"] = []
		ship["leg"] = 0.0
		ship["dest"] = -1
		ship["source"] = -1
		if ship["kind"] in ["fighter", "scout", "cruiser", "destroyer"]:
			ship["operation_target"] = int(ship["at"])
		elif ship["kind"] == "miner":
			ship["mining_mode"] = "delivery" if _cargo_total(ship) > EPS else "idle"
	ship.erase("salvage_delivery")
	ship.erase("salvage_depot")
	ship.erase("next_salvage_search")

static func _update_salvage(state: Dictionary) -> void:
	var piles: Dictionary = state.get("salvage", {})
	if piles.is_empty():
		return
	var claims: Dictionary = {}
	for ship in state["ships"]:
		var target: int = int(ship.get("salvage_target", ship.get("auto_salvage_target", -1)))
		if target >= 0 and not bool(ship.get("retreating", false)):
			claims[int(ship["id"])] = target
	var elapsed: float = float(state["elapsed"])
	for id in piles.keys():
		var pile: Dictionary = piles[id]
		if not pile.has("construction_job") and elapsed >= float(pile.get("expires_at", float(pile["born"]) + SALVAGE_MAX_LIFETIME)):
			piles.erase(id)
			continue
		if claims.get(int(pile["claim"]), -1) != int(id):
			pile["claim"] = -1
		pile["position"] = (pile["origin"] as Vector2) + (pile["drift"] as Vector2) * sin(maxf(0.0, elapsed - float(pile["born"])) * 0.2)

static func _salvage_combat_busy(state: Dictionary) -> Dictionary:
	var busy: Dictionary = {}
	for craft in state["ships"]:
		if bool(craft.get("retreating", false)) or _engaged(craft) or int(craft.get("yard_target", -1)) < -1:
			busy[int(craft["id"])] = true
		for key in ["combat_target", "pursuit_target"]:
			var target: int = int(craft.get(key, -1))
			if target >= 0:
				busy[target] = true
	for system in state["planets"]:
		for battery in system.get("pds", {}).values():
			var target: int = int(battery.get("target", -1))
			if target >= 0:
				busy[target] = true
	return busy

static func _salvage_cells(piles: Dictionary) -> Dictionary:
	var cells: Dictionary = {}
	for id in piles:
		var point: Vector2 = piles[id]["position"]
		var cell := Vector2i(floori(point.x / SALVAGE_APPROACH_RANGE), floori(point.y / SALVAGE_APPROACH_RANGE))
		if not cells.has(cell):
			cells[cell] = []
		cells[cell].append(id)
	return cells

static func _release_auto_salvage(ship: Dictionary, piles: Dictionary) -> void:
	var id: int = int(ship.get("auto_salvage_target", -1))
	if id < 0:
		return
	if piles.has(id) and int(piles[id]["claim"]) == int(ship["id"]):
		piles[id]["claim"] = -1
	ship.erase("auto_salvage_target")
	ship.erase("tractor_active")

# Cache threat locations for the tick rather than searching every fleet for
# each civilian and each pile. Hostile armed hulls threaten their sector and
# nearby space, including a lane or the far side of a sector boundary.
# Phase-local spatial buckets: preserve insertion order for target tie breaks.
static func _spatial_insert(cells: Dictionary, point: Vector2, width: float, entry: Variant) -> void:
	var cell := Vector2i(floori(point.x / width), floori(point.y / width))
	if not cells.has(cell):
		cells[cell] = []
	cells[cell].append(entry)

# The physical sector hint depends on more than position. Capture the
# relevant routing inputs so post-combat reroutes cannot reuse stale values.
static func _threat_sector_signature(ship: Dictionary) -> Array:
	var route: Array = ship.get("route", [])
	return [ship.get("position", Vector2.INF), int(ship.get("at", -1)), ship.get("kind", ""), ship.get("mining_mode", ""), int(ship.get("field", -1)), int(ship.get("resource_stage", {}).get("node", -1)), int(route[0]) if not route.is_empty() else -1]

# Compare existing signature fields directly without allocating a second array.
static func _threat_signature_matches(ship: Dictionary, signature: Array) -> bool:
	var route: Array = ship.get("route", [])
	return signature[0] == ship.get("position", Vector2.INF) and int(signature[1]) == int(ship.get("at", -1)) and signature[2] == ship.get("kind", "") and signature[3] == ship.get("mining_mode", "") and int(signature[4]) == int(ship.get("field", -1)) and int(signature[5]) == int(ship.get("resource_stage", {}).get("node", -1)) and int(signature[6]) == (int(route[0]) if not route.is_empty() else -1)

# Validate the frozen threat snapshot after combat and withdrawal rerouting.
# If anything relevant changed, fall back to the exact survivor rebuild.
static func _reuse_combat_threats(state: Dictionary, graph: Dictionary, combat_index: Dictionary) -> Dictionary:
	if not combat_index.has("snapshot"):
		return _salvage_threats(state, graph, combat_index)
	var count: int = 0
	for craft in state["ships"]:
		if not armed(craft) or not craft.get("position", Vector2.INF).is_finite():
			continue
		count += 1
		var entry: Array = combat_index.get(int(craft["id"]), [])
		if entry.size() != 3 or not _threat_signature_matches(craft, entry[0]) or int(entry[2]) != _combat_group(state, int(craft["owner"])):
			return _salvage_threats(state, graph, combat_index)
	if count != int(combat_index["count"]):
		return _salvage_threats(state, graph, combat_index)
	return combat_index["snapshot"]

static func _salvage_threats(state: Dictionary, graph: Dictionary, combat_index: Dictionary = {}) -> Dictionary:
	var sectors: Dictionary = {}
	var cells: Dictionary = {}
	var positions := PackedVector2Array()
	var teams := PackedInt32Array()
	var ids := PackedInt64Array()
	for craft in state["ships"]:
		if not armed(craft) or not craft.get("position", Vector2.INF).is_finite():
			continue
		var team: int = _combat_group(state, int(craft["owner"]))
		var point: Vector2 = craft["position"]
		var cached: Array = combat_index.get(int(craft["id"]), [])
		var sector: int
		if not cached.is_empty() and _threat_signature_matches(craft, cached[0]):
			sector = int(cached[1])
		else:
			sector = local_sector(graph, craft)
		if sector >= 0:
			if not sectors.has(sector):
				sectors[sector] = {}
			sectors[sector][team] = true
		_spatial_insert(cells, point, REPAIR_SAFE_RADIUS, positions.size())
		positions.append(point)
		teams.append(team)
		ids.append(int(craft["id"]))
	return {"sectors": sectors, "cells": cells, "positions": positions, "teams": teams, "ids": ids}

static func _salvage_safe(state: Dictionary, graph: Dictionary, owner: int, point: Vector2, sector: int, threats: Dictionary) -> bool:
	if sector < 0 or not sector_contains(graph, sector, point):
		sector = sector_at(graph, point, range(graph["points"].size()))
	if _hostile_system(state, owner, sector):
		return false
	var team: int = _combat_group(state, owner)
	return _salvage_threat_free(point, sector, team, threats, state)

# Threat geometry is frozen for the movement phase; ownership remains live.
# Cache ordered hostile slots per querying team and frozen cell.
# Mixed cells also avoid repeated allied-hull filtering.
static func _threat_hostile_slots(threats: Dictionary, cell: Vector2i, teams: PackedInt32Array, slots: Array, team: int, state: Dictionary = {}) -> Array:
	if not threats.has("hostile_cell_slots"):
		threats["hostile_cell_slots"] = {}
	var cache: Dictionary = threats["hostile_cell_slots"]
	if not cache.has(team):
		cache[team] = {}
	var by_cell: Dictionary = cache[team]
	if not by_cell.has(cell):
		var hostile: Array = []
		for slot in slots:
			if _combat_groups_hostile(state, team, teams[slot]):
				hostile.append(slot)
		by_cell[cell] = hostile
	return by_cell[cell]

static func _salvage_threat_free(point: Vector2, sector: int, team: int, threats: Dictionary, state: Dictionary = {}) -> bool:
	for other_team in threats["sectors"].get(sector, {}):
		if _combat_groups_hostile(state, team, int(other_team)):
			return false
	var cell := Vector2i(floori(point.x / REPAIR_SAFE_RADIUS), floori(point.y / REPAIR_SAFE_RADIUS))
	if threats.has("positions"):
		var positions: PackedVector2Array = threats["positions"]
		var teams: PackedInt32Array = threats["teams"]
		for x in range(-1, 2):
			for y in range(-1, 2):
				var key: Vector2i = cell + Vector2i(x, y)
				var slots: Array = threats["cells"].get(key, [])
				if slots.is_empty():
					continue
				for slot in _threat_hostile_slots(threats, key, teams, slots, team, state):
					if point.distance_squared_to(positions[slot]) <= REPAIR_SAFE_RADIUS * REPAIR_SAFE_RADIUS:
						return false
		return true
	for x in range(-1, 2):
		for y in range(-1, 2):
			for threat in threats["cells"].get(cell + Vector2i(x, y), []):
				if _combat_groups_hostile(state, team, int(threat[0])) and point.distance_squared_to(threat[1]) <= REPAIR_SAFE_RADIUS * REPAIR_SAFE_RADIUS:
					return false
	return true


static func _salvage_sector_center_safe(state: Dictionary, graph: Dictionary, owner: int, node: int, threats: Dictionary) -> bool:
	var point: Vector2 = graph["points"][node]
	if not threats.has("center_sectors"):
		threats["center_sectors"] = {}
	var centers: Dictionary = threats["center_sectors"]
	if not centers.has(node):
		centers[node] = node if sector_contains(graph, node, point) else sector_at(graph, point, range(graph["points"].size()))
	var sector: int = int(centers[node])
	if _hostile_system(state, owner, sector):
		return false
	var team: int = _combat_group(state, owner)
	var key := Vector2i(node, team)
	if not threats.has("center_safety"):
		threats["center_safety"] = {}
	var safety: Dictionary = threats["center_safety"]
	if not safety.has(key):
		safety[key] = _salvage_threat_free(point, sector, team, threats, state)
	return bool(safety[key])

# Cache the bounded topology walk independently of mutable safety. For an
# identical local eligibility mask, all ships on the same team reuse BFS.
static func _auto_salvage_sectors(state: Dictionary, graph: Dictionary, owner: int, origin: int, threats: Dictionary) -> Dictionary:
	if origin < 0 or origin >= graph["points"].size():
		return {}
	if not threats.has("reach_topology"):
		threats["reach_topology"] = {}
	var topology: Dictionary = threats["reach_topology"]
	if not topology.has(origin):
		var candidates: Dictionary = {origin: true}
		var frontier: Array = [origin]
		for hop in range(AUTO_SALVAGE_HOPS):
			var next: Array = []
			for node in frontier:
				for neighbor in graph["adjacent"][node]:
					if not candidates.has(neighbor):
						candidates[neighbor] = true
						next.append(neighbor)
			frontier = next
		topology[origin] = candidates.keys()
	var team: int = _combat_group(state, owner)
	var known: Dictionary = {}
	var planets: int = state["planets"].size()
	for node in topology[origin]:
		if node == origin:
			continue
		if discovered(state, owner, "planets" if node < planets else "fields", node if node < planets else node - planets):
			if _salvage_sector_center_safe(state, graph, owner, node, threats):
				known[node] = true
	if not threats.has("reach_cache"):
		threats["reach_cache"] = {}
	var cache: Dictionary = threats["reach_cache"]
	var key := Vector2i(origin, team)
	var prior: Dictionary = cache.get(key, {})
	if not prior.is_empty() and prior["known"] == known:
		return prior["reached"]
	var reached: Dictionary = {origin: origin}
	var frontier: Array = [origin]
	for hop in range(AUTO_SALVAGE_HOPS):
		var next: Array = []
		for node in frontier:
			for neighbor in graph["adjacent"][node]:
				if reached.has(neighbor) or not known.has(neighbor):
					continue
				reached[neighbor] = neighbor if node == origin else reached[node]
				next.append(neighbor)
		frontier = next
	cache[key] = {"known": known, "reached": reached}
	return reached

# Combat and existing orders always take precedence. An idle craft can make
# a bounded multi-sector detour; a working/held/transiting craft may tractor
# only resources within beam range without changing its route or hold.
static func _work_opportunistic_salvage(state: Dictionary, graph: Dictionary, ship: Dictionary, dt: float, busy: Dictionary, cells: Dictionary, coordinated: bool, threats: Dictionary = {}) -> bool:
	var piles: Dictionary = state.get("salvage", {})
	var previously_collecting: bool = ship.has("auto_salvage_target")
	var prior_origin: int = int(ship.get("auto_salvage_origin", -1))
	_release_auto_salvage(ship, piles)
	ship.erase("auto_salvage_origin")
	if not autocast_ready(state, ship, "salvage"):
		return false
	if cargo_capacity(str(ship.get("kind", "ship"))) <= EPS or _salvage_active(ship) or bool(ship.get("move_only", false)) or busy.has(int(ship["id"])):
		return false
	if piles.is_empty() and not previously_collecting:
		return false
	var pos: Vector2 = ship["position"]
	var idle: bool = not coordinated and _is_idle_ship(ship) and not _unit_order_running(ship) and ship.get("order_queue", []).is_empty()
	var sector: int = local_sector(graph, ship)
	var harvester: bool = ship.get("kind", "") == "miner"
	var priority: bool = harvester and autocast_enabled(ship, "mine")
	# A mining assignment is a preference. Prefer scraps before departing
	# for a rock, and interrupt local extraction, but finish real lane
	# crossings, explicit movement and loaded depot deliveries.
	var can_leave_route: bool = ship["route"].is_empty() or (priority and ship.get("mining_mode", "idle") == "approach" and sector >= 0 and sector == int(ship["at"]))
	var mining_detour: bool = harvester and ship.get("mining_mode", "idle") in ["idle", "approach", "outbound", "mining"] and can_leave_route and not bool(ship.get("holding", false)) and not bool(ship.get("retreating", false)) and (not _unit_order_running(ship) or ship.get("unit_order", {}).get("kind") == "mine")
	var continuing_detour: bool = harvester and previously_collecting and not bool(ship.get("holding", false)) and ship["route"].is_empty() and ship.get("unit_order", {}).get("kind", "mine") == "mine"
	idle = idle or mining_detour or continuing_detour
	var civilian: bool = ship.get("kind", "") in ["miner", "ship"]
	# Interrupting mining clears the field index. Keep the same physical
	# sector available for subsequent approaches from inside asteroid fields.
	if idle and sector < 0:
		sector = sector_at(graph, pos, range(graph["points"].size()))
		if sector < 0:
			sector = prior_origin if previously_collecting and prior_origin >= 0 else patrol_node(state, graph, int(ship["owner"]), pos)
	if civilian:
		if threats.is_empty():
			threats = _salvage_threats(state, graph)
		if not _salvage_safe(state, graph, int(ship["owner"]), pos, sector, threats):
			return false
	if piles.is_empty() or cargo_free(ship) <= EPS:
		if civilian and idle and previously_collecting and _cargo_total(ship) > EPS:
			ship["salvage_delivery"] = true
			return true
		return false
	var limit: float = AUTO_SALVAGE_RANGE if idle and civilian and sector >= 0 else TRACTOR_RANGE
	var reachable: Dictionary = _auto_salvage_sectors(state, graph, int(ship["owner"]), sector, threats) if idle and civilian else {}
	var nearest: float = limit * limit + EPS
	var best: int = -1
	var best_node: int = -1
	var cell := Vector2i(floori(pos.x / SALVAGE_APPROACH_RANGE), floori(pos.y / SALVAGE_APPROACH_RANGE))
	var reach: int = ceili(limit / SALVAGE_APPROACH_RANGE)
	var nearby_cells: Array = []
	# Sparse wreck fields are cheaper to scan than thousands of empty cells.
	if cells.size() < (reach * 2 + 1) * (reach * 2 + 1):
		for key in cells:
			if absi(key.x - cell.x) <= reach and absi(key.y - cell.y) <= reach:
				nearby_cells.append(key)
	else:
		for x in range(-reach, reach + 1):
			for y in range(-reach, reach + 1):
				var key: Vector2i = cell + Vector2i(x, y)
				if cells.has(key):
					nearby_cells.append(key)
	for key in nearby_cells:
		for candidate in cells[key]:
			if not piles.has(candidate) or int(piles[candidate]["claim"]) >= 0:
				continue
			var point: Vector2 = piles[candidate]["position"]
			if piles[candidate].has("dropped_by") and (int(piles[candidate]["dropped_by"]) == int(ship["id"]) or float(state["elapsed"]) - float(piles[candidate]["born"]) < 2.0):
				continue
			var distance: float = pos.distance_squared_to(point)
			if distance > nearest or (is_equal_approx(distance, nearest) and best >= 0 and int(candidate) > best):
				continue
			var node: int = sector_at(graph, point, reachable.keys(), sector)
			if distance > TRACTOR_RANGE * TRACTOR_RANGE + EPS and node < 0:
				continue
			if civilian and not _salvage_safe(state, graph, int(ship["owner"]), point, node, threats):
				continue
			best = int(candidate)
			best_node = node
			nearest = distance
	if best < 0:
		if civilian and idle and previously_collecting and _cargo_total(ship) > EPS:
			ship["salvage_delivery"] = true
			return true
		return false
	var pile: Dictionary = piles[best]
	if mining_detour:
		_interrupt_work(ship)
		ship["route"] = []
		ship["leg"] = 0.0
		ship["mining_active"] = false
	pile["claim"] = int(ship["id"])
	ship["auto_salvage_target"] = best
	var point: Vector2 = pile["position"]
	if pos.distance_to(point) > TRACTOR_RANGE:
		ship["auto_salvage_origin"] = sector
		var waypoint: int = int(reachable.get(best_node, best_node))
		var approach: Vector2 = graph["points"][waypoint] if waypoint >= 0 and waypoint != best_node else point
		var stop_range: float = TRACTOR_RANGE * 0.85 if approach == point else 0.0
		_navigate(ship, approach, minf(ship_speed(str(ship.get("kind", "ship"))) * dt, maxf(0.0, pos.distance_to(approach) - stop_range)))
		# Keep civilian star anchors valid when crossing a field or sector.
		var entered: int = sector_at(graph, ship["position"], reachable.keys(), sector)
		if entered >= 0:
			ship["at"] = entered if entered < state["planets"].size() else int(state["map"]["fields"][entered - state["planets"].size()]["anchor"])
			ship["auto_salvage_origin"] = entered
		return true
	var before_pickup: float = _cargo_total(ship)
	_collect_salvage(ship, pile, dt)
	if ship.has("resource_stage") and _cargo_total(ship) > before_pickup + EPS:
		ship["resource_loaded_at"] = float(state["elapsed"])
	if civilian and idle:
		if float(pile["amount"]) > EPS and cargo_free(ship) > EPS:
			return true
		_release_auto_salvage(ship, piles)
		if float(pile["amount"]) <= EPS:
			piles.erase(best)
		ship["salvage_delivery"] = _cargo_total(ship) > EPS
		return true
	if ship.get("kind", "") == "miner" and ship.get("mining_mode", "idle") == "idle" and (ship["route"] as Array).is_empty() and not bool(ship.get("holding", false)):
		ship["mining_mode"] = "delivery"
	if float(pile["amount"]) <= EPS or cargo_free(ship) <= EPS:
		_release_auto_salvage(ship, piles)
		if float(pile["amount"]) <= EPS:
			piles.erase(best)
	return false

static func _collect_salvage(ship: Dictionary, pile: Dictionary, dt: float) -> void:
	var rate: float = FREIGHTER_TRACTOR_RATE if ship.get("kind", "") == "ship" else TRACTOR_RATE
	var amount: float = minf(cargo_free(ship), minf(float(pile["amount"]), rate * dt))
	if amount <= EPS:
		return
	if not ship.has("cargo"):
		ship["cargo"] = empty_stock()
	var resource: String = pile["resource"]
	_cargo_stat(ship, "tons_picked", resource, amount)
	ship["cargo"][resource] = float(ship["cargo"].get(resource, 0.0)) + amount
	pile["amount"] -= amount
	ship["tractor_active"] = true

static func _salvage_reachable(graph: Dictionary, ship: Dictionary, point: Vector2) -> bool:
	var pos: Vector2 = ship.get("position", Vector2.INF)
	if not pos.is_finite():
		return false
	if pos.distance_to(point) <= TRACTOR_RANGE + EPS:
		return true # A hull passing wreckage on its current lane may beam it in.
	var sector: int = local_sector(graph, ship)
	return sector >= 0 and sector_contains(graph, sector, point)

# Right-click a floating resource. Each pile has one claimant; groups may
# claim additional unclaimed resources at the same wreck, nearest first.
static func command_salvage(state: Dictionary, player: int, ids: Array, target: int) -> bool:
	var units: Array = _owned_units(state, player, ids)
	var piles: Dictionary = state.get("salvage", {})
	if units.is_empty() or not piles.has(target):
		return false
	_update_salvage(state)
	if not piles.has(target):
		return false
	var center: Vector2 = piles[target]["position"]
	var graph: Dictionary = military_graph(state)
	var options: Array = [target]
	for id in piles:
		if id != target and center.distance_to(piles[id]["position"]) <= 80.0:
			options.append(id)
	var changed: bool = false
	# The explicitly clicked resource is always considered first.
	for id in options:
		var pile: Dictionary = piles[id]
		var automatic: Dictionary = {}
		if int(pile["claim"]) >= 0:
			for craft in state["ships"]:
				if int(craft["id"]) == int(pile["claim"]) and int(craft.get("auto_salvage_target", -1)) == int(id) and int(craft["owner"]) == player:
					automatic = craft
					break
		if int(pile["claim"]) >= 0 and automatic.is_empty():
			continue
		var best: Dictionary = {}
		var distance: float = INF
		for ship in units:
			if not supports_autocast(ship, "salvage") or cargo_free(ship) <= EPS or bool(ship.get("retreating", false)) or patrol_node(state, graph, player, pile["position"]) < 0:
				continue
			var d: float = (ship["position"] as Vector2).distance_squared_to(pile["position"])
			if d < distance:
				best = ship
				distance = d
		if best.is_empty():
			continue
		units.erase(best)
		if not automatic.is_empty():
			_release_auto_salvage(automatic, piles)
		var old: int = int(best.get("salvage_target", -1))
		if piles.has(old) and int(piles[old]["claim"]) == int(best["id"]):
			piles[old]["claim"] = -1
		_release_auto_salvage(best, piles)
		_cancel_salvage_order(best)
		_clear_tactical_order(best)
		_clear_local_hold(best)
		_interrupt_work(best)
		_set_unit_order(state, best, {"kind": "salvage", "target": id})
		best["salvage_target"] = id
		pile["claim"] = int(best["id"])
		changed = true
		if units.is_empty():
			break
	return changed

static func command_unload_cargo(state: Dictionary, player: int, ids: Array) -> bool:
	var units: Array = _owned_units(state, player, ids)
	var changed: bool = false
	for ship in units:
		if ship.get("kind", "") == "science_ship" or cargo_capacity(str(ship["kind"])) <= EPS or _cargo_total(ship) <= EPS or bool(ship.get("retreating", false)):
			continue
		_cancel_salvage_order(ship)
		_clear_tactical_order(ship)
		_clear_local_hold(ship)
		if ship["kind"] == "colony_ship":
			ship.erase("return_path")
			ship["dest"] = -1
		_set_unit_order(state, ship, {"kind": "unload"})
		ship["salvage_delivery"] = true
		changed = true
	return changed

static func _salvage_depot_route(state: Dictionary, graph: Dictionary, ship: Dictionary, allow_full: bool = false) -> bool:
	var fighter: bool = ship["kind"] in ["fighter", "scout", "cruiser", "destroyer"]
	var nav: Dictionary = graph if fighter else state["map"]
	var points: Array = nav["points"]
	var owner: int = int(ship["owner"])
	var team: int = _combat_group(state, owner)
	if team == 0:
		return false
	var allowed: Array[int] = planet_teams(state)
	allowed.resize(points.size())
	for node in range(allowed.size()):
		if node >= state["planets"].size() or _civilian_transit_allowed(state, team, allowed[node]):
			allowed[node] = team
	var origins: Array[int] = [int(ship["at"])]
	var sector: int = local_sector(graph, ship)
	if sector >= 0 and sector < points.size() and not origins.has(sector):
		origins.append(sector)
	if not ship["route"].is_empty() and not origins.has(int(ship["route"][0])):
		origins.append(int(ship["route"][0]))
	var best: float = INF
	var chosen: Array[int] = []
	for origin in origins:
		if origin < 0 or origin >= points.size():
			continue
		var access: Array[int] = allowed.duplicate()
		access[origin] = team
		for node in range(state["planets"].size()):
			var p: Dictionary = state["planets"][node]
			if int(p["owner"]) != owner or not has_station(p):
				continue
			var useful: bool = false
			for resource in RESOURCES + [ANTIMATTER]:
				if float(ship.get("cargo", {}).get(resource, 0.0)) > EPS and storage_free(p, resource) > EPS:
					useful = true
					break
			if not useful and not allow_full:
				continue
			var path: Array[int] = MAP.path(nav, access, team, origin, node)
			if path.is_empty():
				continue
			var distance: float = (ship["position"] as Vector2).distance_to(points[origin]) + MAP.route_length(nav, path)
			if distance < best:
				best = distance
				chosen = path
	if chosen.is_empty():
		return false
	# Include the actual entry waypoint, not a direct shortcut to its neighbor.
	ship["route"] = [] if chosen.size() == 1 and int(ship["at"]) == int(chosen.back()) else chosen
	ship["leg"] = 0.0
	ship["source"] = -1
	ship["dest"] = chosen.back()
	ship["salvage_depot"] = chosen.back()
	if ship["kind"] == "miner":
		ship["mining_mode"] = "delivery"
		ship["field"] = -1
	return true

static func _work_salvage(state: Dictionary, graph: Dictionary, ship: Dictionary, dt: float, busy: bool = false) -> bool:
	if not _salvage_active(ship):
		return false
	ship["tractor_active"] = false
	if cargo_capacity(str(ship["kind"])) <= EPS or bool(ship.get("retreating", false)):
		_cancel_salvage_order(ship)
		return false
	var id: int = int(ship.get("salvage_target", -1))
	if id >= 0:
		var piles: Dictionary = state.get("salvage", {})
		var pile: Dictionary = piles.get(id, {})
		if pile.is_empty() or int(pile["claim"]) != int(ship["id"]):
			if not pile.is_empty() and int(pile["claim"]) == int(ship["id"]):
				pile["claim"] = -1
			ship.erase("salvage_target")
			if _cargo_total(ship) > EPS:
				ship["salvage_delivery"] = true
			return not busy
		if busy:
			return false
		var point: Vector2 = pile["position"]
		var pos: Vector2 = ship["position"]
		if pos.distance_to(point) > TRACTOR_RANGE:
			var node: int = patrol_node(state, graph, int(ship["owner"]), point)
			if node < 0:
				_cancel_salvage_order(ship)
				return false
			_manual_travel(state, graph, ship, node, point, dt, TRACTOR_RANGE * 0.85)
			return true
		_collect_salvage(ship, pile, dt)
		if float(pile["amount"]) <= EPS or cargo_free(ship) <= EPS:
			pile["claim"] = -1
			if float(pile["amount"]) <= EPS:
				piles.erase(id)
			ship.erase("salvage_target")
			ship["tractor_active"] = false
			# Sweep neighboring unclaimed debris from the same wreck until full.
			if cargo_free(ship) > EPS:
				var next: int = -1
				var distance: float = INF
				for candidate in piles:
					var other: Dictionary = piles[candidate]
					var d: float = point.distance_to(other["position"])
					if d <= 80.0 and d < distance and int(other["claim"]) < 0 and _salvage_reachable(graph, ship, other["position"]):
						next = int(candidate)
						distance = d
				if next >= 0:
					ship["salvage_target"] = next
					piles[next]["claim"] = int(ship["id"])
					return true
			ship["salvage_delivery"] = _cargo_total(ship) > EPS
		return true
	# Deliver physically to an owned warehouse, respecting storage limits.
	if busy and ship.get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"]:
		return false
	if _cargo_total(ship) <= EPS:
		_cancel_salvage_order(ship)
		return false
	var depot: int = int(ship.get("salvage_depot", -1))
	var owner: int = int(ship["owner"])
	var team: int = _combat_group(state, owner)
	for waypoint in ship["route"]:
		if int(waypoint) == int(ship["at"]) or waypoint >= state["planets"].size():
			continue
		var waypoint_team: int = _combat_group(state, int(state["planets"][waypoint]["owner"]))
		if not _civilian_transit_allowed(state, team, waypoint_team):
			depot = -1
			break
	if depot < 0 or int(state["planets"][depot]["owner"]) != owner or not has_station(state["planets"][depot]):
		ship.erase("salvage_depot")
		if float(state["elapsed"]) + EPS < float(ship.get("next_salvage_search", 0.0)):
			return true
		ship["next_salvage_search"] = _next_search_slot(float(state["elapsed"]), int(ship["id"]), 0.5)
		if not _salvage_depot_route(state, graph, ship):
			if ship.get("kind", "") not in ["ship", "colony_ship", "miner"] or not _salvage_depot_route(state, graph, ship, true):
				return true
		depot = int(ship["salvage_depot"])
	var nav: Dictionary = graph if ship["kind"] in ["fighter", "scout", "cruiser", "destroyer"] else state["map"]
	var dock: Vector2 = station_position(state, depot, float(state["elapsed"]))
	if not (ship["route"] as Array).is_empty():
		_move(state if ship["kind"] not in ["fighter", "scout", "cruiser", "destroyer"] else {"map": nav, "ships": state["ships"]}, ship, dt, dock, depot, STATION_DOCK_RANGE)
		if not ship["route"].is_empty():
			return true
	else:
		var berth: Vector2 = _waiting_berth(state, ship, dock, STATION_DOCK_RANGE, dock.direction_to(ship["position"]))
		_navigate(ship, berth, ship_speed(str(ship.get("kind", "ship"))) * dt)
	if (ship["position"] as Vector2).distance_to(dock) > STATION_DOCK_RANGE + EPS:
		return true
	var p: Dictionary = state["planets"][depot]
	var budget: float = _dropoff_budget(ship, dt)
	for resource in RESOURCES + [ANTIMATTER]:
		var amount: float = minf(budget, minf(float(ship["cargo"].get(resource, 0.0)), storage_free(p, resource)))
		if amount > EPS:
			_record_transfer(state, int(ship["id"]), ship, station_target_id(state, depot), p, resource, amount)
			ship["cargo"][resource] -= amount
			p["stock"][resource] = float(p["stock"].get(resource, 0.0)) + amount
			var category: String = "Farm deliveries" if ship["kind"] == "colony_ship" else ("Resource deliveries" if bool(ship.get("resource_haul", false)) else "Salvage deliveries")
			_record_flow(p, category, resource, amount)
			budget -= amount
	if _cargo_total(ship) <= EPS:
		_cancel_salvage_order(ship)
	elif budget > EPS:
		ship.erase("salvage_depot")
	return true

static func _ship_hit(damage: Dictionary, killed_by: Dictionary, health: Dictionary, target: int, attacker: Dictionary, amount: float, hull_slots: Dictionary = {}, hull_health: PackedFloat64Array = PackedFloat64Array()) -> void:
	var before: float = float(damage.get(target, 0.0))
	damage[target] = before + amount * float(attacker.get("reward_damage_multiplier", 1.0))
	var hp: float = hull_health[hull_slots[target]] if hull_slots.has(target) else float(health.get(target, INF))
	if before < hp and float(damage[target]) >= hp - EPS:
		killed_by[target] = attacker

# Resolve one shot from every mounted blaster at each burst interval.
# Damage is authoritative and simultaneous with other weapons; projectile
# tracer metadata is compact and rides the existing combat snapshot.
# Use the frozen combat spatial index, including structures, for missile splash.
static func _missile_splash(state: Dictionary, cells: Dictionary, positions: Dictionary, teams: Dictionary, team: int, target: int, attacker: Dictionary, amount: float, damage: Dictionary, killed_by: Dictionary, health: Dictionary, hull_slots: Dictionary, hull_health: PackedFloat64Array) -> void:
	var impact: Vector2 = positions[target]
	var cell := Vector2i(floori(impact.x / LASER_RANGE), floori(impact.y / LASER_RANGE))
	for x in range(-1, 2):
		for y in range(-1, 2):
			for other in cells.get(cell + Vector2i(x, y), []):
				var id: int = int(other["id"])
				if _combat_groups_hostile(state, team, int(teams[id])) and impact.distance_squared_to(positions[id]) <= MISSILE_SPLASH_RADIUS * MISSILE_SPLASH_RADIUS:
					_ship_hit(damage, killed_by, health, id, attacker, amount, hull_slots, hull_health)

static func _fire_blaster(state: Dictionary, ship: Dictionary, target: int, positions: Dictionary, damage: Dictionary, killed_by: Dictionary, health: Dictionary, dt: float, hull_slots: Dictionary = {}, hull_health: PackedFloat64Array = PackedFloat64Array()) -> void:
	var mounts: int = blaster_count(str(ship["kind"]))
	if mounts <= 0 or dt <= 0.0:
		return
	var next: float = float(ship.get("blaster_cooldown", 0.0))
	var shot: int = int(ship.get("blaster_shot", 0))
	if target == -1 or not positions.has(target):
		ship["blaster_cooldown"] = maxf(0.0, next - dt)
		if next <= dt:
			ship["blaster_shot"] = 0
		return
	while next < dt - EPS:
		_ship_hit(damage, killed_by, health, target, ship, BLASTER_DAMAGE * mounts, hull_slots, hull_health)
		ship["blaster_origin"] = positions[ship["id"]]
		ship["blaster_endpoint"] = positions[target]
		ship["blaster_fired"] = float(state["elapsed"]) - dt + next
		ship["blaster_visual_shot"] = shot
		if bool(ship.get("cloak_equipped", false)):
			ship["cloak_reveal_until"] = float(state["elapsed"]) + CLOAK_REVEAL_TIME
		shot = (shot + 1) % BLASTER_SHOTS
		next += BLASTER_SHOT_INTERVAL + (BLASTER_PAUSE if shot == 0 else 0.0)
	ship["blaster_shot"] = shot
	ship["blaster_cooldown"] = maxf(0.0, next - dt)

# Precomputed sector presence avoids an O(fleet size) hostile search for
# every moving combat hull, including dense friendly formations.
static func _combat_sector_has_hostile(presence: Dictionary, sector: int, team: int, state: Dictionary = {}) -> bool:
	if sector < 0 or team <= 0:
		return false
	for other_team in presence.get(sector, {}):
		if int(other_team) > 0 and _combat_groups_hostile(state, team, int(other_team)):
			return true
	return false

# Lazily filter each occupied bucket once per team and combat snapshot.
# Keep original insertion order for all weapon-specific tie rules.
static func _hostile_bucket(state: Dictionary, buckets: Dictionary, cache: Dictionary, key: Variant, team: int, team_by_id: Dictionary = {}, positive_only: bool = false) -> Array:
	if not cache.has(team):
		cache[team] = {}
	var by_key: Dictionary = cache[team]
	if not by_key.has(key):
		var hostile: Array = []
		for candidate in buckets.get(key, []):
			var candidate_team: int
			if team_by_id.is_empty():
				candidate_team = _combat_group(state, int(candidate["owner"]))
			else:
				candidate_team = int(team_by_id[int(candidate["id"])])
			if _combat_groups_hostile(state, team, candidate_team) and (not positive_only or candidate_team > 0) and ship_visible_to_team(state, candidate, team):
				hostile.append(candidate)
		by_key[key] = hostile
	return by_key[key]

# Contiguous blocks preserve traversal order, including approximate-distance ties.
# Bounds are built once per hostile bucket, not once per attacking hull.
static func _laser_blocks(candidates: Array, positions: Dictionary, include_structures: bool = false) -> Array:
	var blocks: Array = []
	var ids := PackedInt64Array()
	var points := PackedVector2Array()
	var low := Vector2.ZERO
	var high := Vector2.ZERO
	for other in candidates:
		var id: int = int(other["id"])
		if id < 0 and not include_structures:
			continue
		var point: Vector2 = positions[id]
		if ids.is_empty():
			low = point
			high = point
		else:
			low = low.min(point)
			high = high.max(point)
		ids.append(id)
		points.append(point)
		if ids.size() == 16:
			blocks.append([low, high, ids, points])
			ids = PackedInt64Array()
			points = PackedVector2Array()
	if not ids.is_empty():
		blocks.append([low, high, ids, points])
	return blocks

static func _laser_block_nearest(blocks: Array, _positions: Dictionary, pos: Vector2, best: float, target: int) -> Array:
	for block in blocks:
		var low: Vector2 = block[0]
		var high: Vector2 = block[1]
		var bound: float = pos.distance_squared_to(pos.clamp(low, high))
		# Leave a conservative margin for floating-point and approximate ties.
		if bound > best + maxf(0.001, absf(best) * 0.0001):
			continue
		var ids: PackedInt64Array = block[2]
		var points: PackedVector2Array = block[3]
		for i in range(ids.size()):
			var id: int = ids[i]
			var distance: float = pos.distance_squared_to(points[i])
			if distance < best or (is_equal_approx(distance, best) and (target < 0 or int(id) < target)):
				best = distance
				target = int(id)
	return [best, target]

static func _missile_block_nearest(blocks: Array, _positions: Dictionary, pos: Vector2, best: float, target: int, focused: bool, focus_id: int) -> Array:
	for block in blocks:
		var low: Vector2 = block[0]
		var high: Vector2 = block[1]
		var bound: float = pos.distance_squared_to(pos.clamp(low, high))
		if bound > best + maxf(0.001, absf(best) * 0.0001):
			continue
		var ids: PackedInt64Array = block[2]
		var points: PackedVector2Array = block[3]
		for i in range(ids.size()):
			var id: int = ids[i]
			if focused and int(id) != focus_id:
				continue
			var distance: float = pos.distance_squared_to(points[i])
			if distance <= best:
				best = distance
				target = int(id)
	return [best, target]

static func _reusable_laser_target(state: Dictionary, ship: Dictionary, by_id: Dictionary, positions: Dictionary, pos: Vector2, now: float) -> int:
	if ship.has("attack_order") or int(ship.get("pursuit_target", -1)) >= 0 or ship.get("unit_order", {}).get("kind", "") == "guard":
		return -1
	if now + EPS >= float(ship.get("_next_laser_refresh", 0.0)):
		return -1
	var id: int = int(ship.get("combat_target", -1))
	if id < 0 or not by_id.has(id) or not positions.has(id):
		return -1
	var team: int = _combat_group(state, int(ship["owner"]))
	if team == 0 or not _combat_groups_hostile(state, team, _combat_group(state, int(by_id[id]["owner"]))) or not ship_visible_to_team(state, by_id[id], team):
		return -1
	if pos.distance_squared_to(positions[id]) > LASER_RANGE * LASER_RANGE:
		return -1
	return id

static func _combat_search_due(ship: Dictionary, now: float) -> bool:
	return ship.has("attack_order") or int(ship.get("combat_target", -1)) >= 0 or int(ship.get("pursuit_target", -1)) >= 0 or int(ship.get("yard_target", -1)) < -1 or now + EPS >= float(ship.get("_next_combat_search", 0.0))

static func _combat(state: Dictionary, graph: Dictionary, dt: float, threat_index: Dictionary = {}) -> void:
	var ships: Array = state["ships"]
	var positions: Dictionary = {}
	# Combat needs a frozen reference map until simultaneous damage resolves.
	var indexed: bool = is_same(state, _indexed_state)
	var by_id: Dictionary = _hulls_by_id.duplicate() if indexed else {}
	var team_by_id: Dictionary = {}
	var hull_slots: Dictionary = {}
	var hull_positions := PackedVector2Array()
	var hull_health := PackedFloat64Array()
	var hull_teams := PackedInt32Array()
	var previous_targets := PackedInt64Array()
	var ship_sectors := PackedInt32Array()
	hull_positions.resize(ships.size())
	hull_health.resize(ships.size())
	hull_teams.resize(ships.size())
	previous_targets.resize(ships.size())
	ship_sectors.resize(ships.size())
	var health: Dictionary = {}
	var killed_by: Dictionary = {}
	var cells: Dictionary = {}
	var sectors: Dictionary = {}
	var sector_teams: Dictionary = {}
	var threat_sectors: Dictionary = {}
	var threat_cells: Dictionary = {}
	var threat_positions := PackedVector2Array()
	var threat_teams := PackedInt32Array()
	var threat_ids := PackedInt64Array()
	var threat_count: int = 0
	for ship in ships:
		var id: int = int(ship["id"])
		var pos: Vector2 = combat_position(state, graph, ship)
		positions[id] = pos
		if not indexed:
			by_id[id] = ship
		team_by_id[id] = _combat_group(state, int(ship["owner"]))
		var slot: int = hull_slots.size()
		hull_health[slot] = _effective_health(ship, ship_max_hp(str(ship["kind"])))
		hull_slots[id] = slot
		hull_positions[slot] = pos
		hull_teams[slot] = int(team_by_id[id])
		previous_targets[slot] = int(ship.get("combat_target", -1))
		var sector: int = local_sector(graph, ship)
		var combat_cell := Vector2i(floori(pos.x / LASER_RANGE), floori(pos.y / LASER_RANGE))
		if armed(ship) and ship.get("position", Vector2.INF).is_finite():
			var threat_team: int = int(team_by_id[id])
			threat_index[id] = [_threat_sector_signature(ship), sector, threat_team]
			threat_count += 1
			if sector >= 0:
				if not threat_sectors.has(sector):
					threat_sectors[sector] = {}
				threat_sectors[sector][threat_team] = true
			# Threat cells are exactly two combat cells wide. Reuse the
			# combat coordinate, including floor semantics for negatives.
			var threat_cell := Vector2i(floori(float(combat_cell.x) / 2.0), floori(float(combat_cell.y) / 2.0))
			if not threat_cells.has(threat_cell):
				threat_cells[threat_cell] = []
			threat_cells[threat_cell].append(threat_positions.size())
			threat_positions.append(pos)
			threat_teams.append(threat_team)
			threat_ids.append(id)
		if sector < 0:
			sector = sector_at(graph, pos, range(graph["points"].size()))
		ship_sectors[slot] = sector
		if sector >= 0:
			if not sectors.has(sector):
				sectors[sector] = []
			sectors[sector].append(ship)
			if not sector_teams.has(sector):
				sector_teams[sector] = {}
			sector_teams[sector][int(team_by_id[id])] = true
		if not cells.has(combat_cell):
			cells[combat_cell] = []
		cells[combat_cell].append(ship)
	threat_index["snapshot"] = {"sectors": threat_sectors, "cells": threat_cells, "positions": threat_positions, "teams": threat_teams, "ids": threat_ids}
	threat_index["count"] = threat_count
	var yard_targets: Dictionary = {}
	var station_targets: Dictionary = {}
	var system_count: int = (state["planets"] as Array).size()
	for index in range(system_count):
		var system: Dictionary = state["planets"][index]
		if has_station(system):
			var target_id: int = station_target_id(state, index)
			var pos: Vector2 = station_position(state, index, float(state["elapsed"]))
			station_targets[target_id] = index
			health[target_id] = _effective_health(system["station"], station_max_hp(system))
			positions[target_id] = pos
			team_by_id[target_id] = _combat_group(state, int(system["owner"]))
			_spatial_insert(cells, pos, LASER_RANGE, {"id": target_id, "owner": system["owner"], "kind": "station"})
		for slot in range(system["yards"].size()):
			var target_id: int = -2 - index * 3 - slot
			var pos: Vector2 = shipyard_position(state, index, slot, float(state["elapsed"]))
			yard_targets[target_id] = Vector2i(index, slot)
			health[target_id] = float(system["yards"][slot].get("hp", YARD_HP * int(system["yards"][slot]["level"])))
			positions[target_id] = pos
			team_by_id[target_id] = _combat_group(state, int(system["owner"]))
			_spatial_insert(cells, pos, LASER_RANGE, {"id": target_id, "owner": system["owner"], "kind": "shipyard"})

	_detect_cloaked(state, ships, cells, positions, team_by_id)
	var hostile_cache: Dictionary = {}
	var positive_hostile_cache: Dictionary = {}
	var sector_hostile_cache: Dictionary = {}
	var laser_blocks: Dictionary = {}
	var missile_blocks: Dictionary = {}
	var pursuit_blocks: Dictionary = {}
	var damage: Dictionary = {}
	for ship in ships:
		if bool(ship.get("rogue", false)):
			continue
		var fighter: bool = ship.get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"]
		var miner: bool = ship.get("kind", "") == "miner"
		if not fighter and not miner:
			continue
		if miner:
			ship["mining_active"] = false
		var weapon_damage: float = MINER_LASER_DAMAGE if miner else LASER_DAMAGE * float(capital_lasers(str(ship["kind"])))
		var moving_only: bool = bool(ship.get("move_only", false)) and (ship.has("launch_rally") or ship.has("local_move_target") or ship.get("unit_order", {}).get("kind", "") == "follow" or not (ship["route"] as Array).is_empty() or (ship.has("hold_position") and (ship["position"] as Vector2).distance_to(ship["hold_position"]) > EPS))
		if not moving_only:
			ship.erase("move_only")
		elif fighter and not bool(ship.get("holding", false)) and _combat_sector_has_hostile(sector_teams, int(ship_sectors[hull_slots[int(ship["id"])]]), _combat_group(state, int(ship["owner"])), state):
			moving_only = false
		ship["passing_fire"] = moving_only and fighter
		if bool(ship.get("retreating", false)) or ship.has("cargo_order") or ship.has("repair_order"):
			ship["combat_target"] = -1
			ship["pursuit_target"] = -1
			ship["pursuit_left"] = 0.0
			ship["laser_until"] = -1.0
			ship["yard_target"] = -1
			ship["yard_laser_until"] = -1.0
			_fire_blaster(state, ship, -1, positions, damage, killed_by, health, dt, hull_slots, hull_health)
			continue
		var id: int = int(ship["id"])
		var hull_slot: int = int(hull_slots[id])
		var pos: Vector2 = hull_positions[hull_slot]
		var team: int = hull_teams[hull_slot]
		var launchers: int = missile_count(str(ship["kind"]))
		if launchers > 0:
			var missile_cd: float = maxf(0.0, float(ship.get("missile_cooldown", 0.0)) - dt)
			if missile_cd <= EPS:
				var missile_target: int = -1
				var best: float = MISSILE_RANGE * MISSILE_RANGE
				var focus_id: int = int(ship.get("attack_order", -1))
				var missile_cell := Vector2i(floori(pos.x / LASER_RANGE), floori(pos.y / LASER_RANGE))
				var reach: int = ceili(MISSILE_RANGE / LASER_RANGE)
				if team > 0:
					if not missile_blocks.has(team):
						missile_blocks[team] = {}
					var team_blocks: Dictionary = missile_blocks[team]
					var focused: bool = ship.has("attack_order")
					for x in range(-reach, reach + 1):
						for y in range(-reach, reach + 1):
							var key: Vector2i = missile_cell + Vector2i(x, y)
							if not team_blocks.has(key):
								var candidates: Array = _hostile_bucket(state, cells, positive_hostile_cache, key, team, team_by_id, true)
								team_blocks[key] = _laser_blocks(candidates, positions, true)
							var nearest: Array = _missile_block_nearest(team_blocks[key], positions, pos, best, missile_target, focused, focus_id)
							best = float(nearest[0])
							missile_target = int(nearest[1])
				if missile_target != -1:
					_missile_splash(state, cells, positions, team_by_id, team, missile_target, ship, MISSILE_DAMAGE * launchers, damage, killed_by, health, hull_slots, hull_health)
					missile_cd = MISSILE_COOLDOWN
					ship["missile_origin"] = pos
					ship["missile_endpoint"] = positions[missile_target]
					ship["missile_until"] = float(state["elapsed"]) + 0.65
			ship["missile_cooldown"] = missile_cd
		# Explicit attack is focus fire, never attack-move: even when another
		# hostile is closer, only the ordered entity may receive damage.
		if ship.has("attack_order") and positions.has(int(ship["attack_order"])) and _combat_groups_hostile(state, team, int(team_by_id.get(int(ship["attack_order"]), 0))) and (not by_id.has(int(ship["attack_order"])) or ship_visible_to_team(state, by_id[int(ship["attack_order"])], team)) and pos.distance_to(positions[int(ship["attack_order"])]) <= LASER_RANGE:
			var focus: int = int(ship["attack_order"])
			var in_range: bool = positions.has(focus) and pos.distance_to(positions[focus]) <= LASER_RANGE
			ship["combat_target"] = focus if in_range and focus >= 0 else -1
			ship["yard_target"] = focus if in_range and focus < -1 else -1
			ship["pursuit_target"] = -1
			ship["pursuit_left"] = 0.0
			ship["laser_until"] = -1.0 if int(previous_targets[hull_slot]) != int(ship["combat_target"]) else ship.get("laser_until", -1.0)
			var focus_cooldown: float = maxf(0.0, float(ship.get("laser_cooldown", 0.0)) - dt)
			if in_range and weapon_damage > 0.0 and focus_cooldown <= EPS:
				_ship_hit(damage, killed_by, health, focus, ship, weapon_damage, hull_slots, hull_health)
				focus_cooldown = 1.0
				ship["laser_until" if focus >= 0 else "yard_laser_until"] = float(state["elapsed"]) + 0.2
			ship["laser_cooldown"] = focus_cooldown
			_fire_blaster(state, ship, focus if in_range else -1, positions, damage, killed_by, health, dt, hull_slots, hull_health)
			continue
		var cell := Vector2i(floori(pos.x / LASER_RANGE), floori(pos.y / LASER_RANGE))
		var target: int = -1
		var guard: Dictionary = ship.get("unit_order", {})
		var guard_node: int = int(guard["target"]) if guard.get("kind", "") == "guard" else -1
		var pursuit: int = int(ship.get("pursuit_target", -1)) if fighter else -1
		var remaining: float = float(ship.get("pursuit_left", 0.0))
		var blocked: Dictionary = ship.get("pursuit_blocked", {})
		for blocked_id in blocked.keys():
			if not positions.has(blocked_id) or pos.distance_squared_to(positions[blocked_id]) > LASER_RANGE * LASER_RANGE:
				blocked.erase(blocked_id)
		if moving_only or bool(ship.get("holding", false)) or (guard_node >= 0 and (ship_sectors[hull_slot] != guard_node or (ship_sectors[hull_slots[pursuit]] if hull_slots.has(pursuit) else -1) != guard_node)):
			pursuit = -1
		if pursuit >= 0:
			if ship_sectors[hull_slot] >= 0 and (ship_sectors[hull_slots[pursuit]] if hull_slots.has(pursuit) else -1) == ship_sectors[hull_slot]:
				remaining = PURSUIT_YEARS
			if not by_id.has(pursuit) or not _combat_groups_hostile(state, team, _combat_group(state, int(by_id[pursuit]["owner"]))) or team == 0 or not ship_visible_to_team(state, by_id[pursuit], team):
				pursuit = -1
			elif remaining <= EPS:
				# Do not immediately restart a timed-out chase while the same
				# escaping hull is still in range. A fresh contact may engage.
				blocked[pursuit] = true
				pursuit = -1
			elif by_id[pursuit].get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"] and not bool(by_id[pursuit].get("retreating", false)) and int(previous_targets[hull_slots[pursuit]]) == id and pos.distance_squared_to(positions[pursuit]) <= LASER_RANGE * LASER_RANGE:
				pursuit = -1
		var best: float = LASER_RANGE * LASER_RANGE
		var now: float = float(state["elapsed"])
		var search_due: bool = _combat_search_due(ship, now)
		var reusable: int = _reusable_laser_target(state, ship, by_id, positions, pos, now)
		if reusable >= 0:
			target = reusable
		elif team != 0 and search_due:
			ship["_next_laser_refresh"] = _next_search_slot(now, int(ship["id"]) % 2 * 2, 0.2)
			if not laser_blocks.has(team):
				laser_blocks[team] = {}
			var team_blocks: Dictionary = laser_blocks[team]
			for x in range(-1, 2):
				for y in range(-1, 2):
					var key: Vector2i = cell + Vector2i(x, y)
					if not team_blocks.has(key):
						team_blocks[key] = _laser_blocks(_hostile_bucket(state, cells, hostile_cache, key, team, team_by_id), positions)
					var nearest: Array = _laser_block_nearest(team_blocks[key], positions, pos, best, target)
					best = float(nearest[0])
					target = int(nearest[1])
		if fighter and not moving_only and not bool(ship.get("holding", false)) and pursuit < 0 and target >= 0 and not blocked.has(target) and _fleeing(by_id[target], positions[target] - pos, int(previous_targets[hull_slots[target]])):
			pursuit = target
			remaining = PURSUIT_YEARS
		# A previously engaged fighter may escape the firing envelope before
		# the next scan; its departure is still a valid pursuit trigger.
		var prior: int = int(previous_targets[hull_slot])
		if fighter and not moving_only and not bool(ship.get("holding", false)) and pursuit < 0 and target < 0 and by_id.has(prior) and not blocked.has(prior) and team != 0 and _combat_groups_hostile(state, team, _combat_group(state, int(by_id[prior]["owner"]))) and ship_visible_to_team(state, by_id[prior], team) and _fleeing(by_id[prior], positions[prior] - pos, int(previous_targets[hull_slots[prior]])):
			pursuit = prior
			remaining = PURSUIT_YEARS
		if search_due and fighter and not moving_only and not bool(ship.get("holding", false)) and pursuit < 0 and target < 0 and _combat_sector_has_hostile(sector_teams, int(ship_sectors[hull_slot]), team, state):
			if team > 0:
				if not pursuit_blocks.has(team):
					pursuit_blocks[team] = {}
				var team_blocks: Dictionary = pursuit_blocks[team]
				var sector: int = int(ship_sectors[hull_slot])
				if not team_blocks.has(sector):
					var candidates: Array = _hostile_bucket(state, sectors, sector_hostile_cache, sector, team, team_by_id, true)
					team_blocks[sector] = _laser_blocks(candidates, positions)
				var nearest: Array = _laser_block_nearest(team_blocks[sector], positions, pos, INF, -1)
				pursuit = int(nearest[1])
			if pursuit >= 0:
				remaining = PURSUIT_YEARS
		if guard_node >= 0:
			var guarded: int = guard_node
			if (ship_sectors[hull_slots[pursuit]] if hull_slots.has(pursuit) else -1) != guarded or ship_sectors[hull_slot] != guarded:
				pursuit = -1
			if target >= 0 and ((ship_sectors[hull_slots[target]] if hull_slots.has(target) else -1) != guarded or ship_sectors[hull_slot] != guarded):
				ship["passing_fire"] = true
		if pursuit >= 0:
			target = pursuit if pos.distance_squared_to(positions[pursuit]) <= LASER_RANGE * LASER_RANGE else -1
		else:
			remaining = 0.0
		var ordered_target: int = int(ship.get("attack_order", -1))
		if by_id.has(ordered_target) and _hostile_hull(state, int(ship["owner"]), by_id[ordered_target]):
			if pos.distance_squared_to(positions[ordered_target]) <= LASER_RANGE * LASER_RANGE:
				target = ordered_target
				pursuit = -1
				remaining = 0.0
			elif bool(ship.get("attack_local", false)):
				pursuit = -1
				remaining = 0.0
		ship["pursuit_target"] = pursuit
		ship["pursuit_left"] = remaining
		ship["pursuit_blocked"] = blocked
		if int(previous_targets[hull_slot]) != target:
			ship["laser_until"] = -1.0
		ship["combat_target"] = target
		var cooldown: float = maxf(0.0, float(ship.get("laser_cooldown", 0.0)) - dt)
		if target >= 0 and weapon_damage > 0.0 and cooldown <= EPS:
			_ship_hit(damage, killed_by, health, target, ship, weapon_damage, hull_slots, hull_health)
			cooldown = 1.0
			ship["laser_until"] = float(state["elapsed"]) + 0.2
		ship["laser_cooldown"] = cooldown
		ship["yard_target"] = -1
		if search_due and target < 0 and pursuit < 0:
			var nearest: float = LASER_RANGE * LASER_RANGE
			for x in range(-1, 2):
				for y in range(-1, 2):
					for other in _hostile_bucket(state, cells, hostile_cache, cell + Vector2i(x, y), team, team_by_id):
						var yard_id: int = int(other["id"])
						if yard_id >= 0 or team == 0 or int(team_by_id[int(other["id"])]) == team:
							continue
						var distance: float = pos.distance_squared_to(positions[yard_id])
						if distance < nearest:
							nearest = distance
							ship["yard_target"] = yard_id
			var yard_id: int = int(ship["yard_target"])
			if yard_id < -1 and weapon_damage > 0.0 and cooldown <= EPS:
				_ship_hit(damage, killed_by, health, yard_id, ship, weapon_damage, hull_slots, hull_health)
				ship["laser_cooldown"] = 1.0
				ship["yard_laser_until"] = float(state["elapsed"]) + 0.2
		if target >= 0 or pursuit >= 0 or int(ship["yard_target"]) < -1:
			ship.erase("_next_combat_search")
		elif search_due:
			# Two tick slots at the normal 0.1 simulation step.
			ship["_next_combat_search"] = _next_search_slot(now, int(ship["id"]) % 2 * 2, 0.2)
		_fire_blaster(state, ship, target if target >= 0 else int(ship["yard_target"]), positions, damage, killed_by, health, dt, hull_slots, hull_health)
	# Each matrix emitter has its own cooldown and fires from the station.
	for index in range(system_count):
		var system: Dictionary = state["planets"][index]
		var weapons: Array = system.get("station", {}).get("weapons", [])
		if weapons.is_empty():
			continue
		var team: int = _combat_group(state, int(system["owner"]))
		if team <= 0:
			continue
		var origin: Vector2 = station_position(state, index, float(state["elapsed"]))
		var cell := Vector2i(floori(origin.x / LASER_RANGE), floori(origin.y / LASER_RANGE))
		var station: Dictionary = system["station"]
		var missile_cd: float = maxf(0.0, float(station.get("missile_cooldown", 0.0)) - dt)
		if missile_cd <= EPS:
			var missile_target: int = -1
			var missile_best: float = MISSILE_RANGE * MISSILE_RANGE
			var missile_reach: int = ceili(MISSILE_RANGE / LASER_RANGE)
			for x in range(-missile_reach, missile_reach + 1):
				for y in range(-missile_reach, missile_reach + 1):
					for other in _hostile_bucket(state, cells, positive_hostile_cache, cell + Vector2i(x, y), team, team_by_id, true):
						var other_id: int = int(other["id"])
						if other_id < 0:
							continue
						var distance: float = origin.distance_squared_to(positions[other_id])
						if distance < missile_best or (distance <= missile_best and (missile_target < 0 or other_id < missile_target)):
							missile_target = other_id
							missile_best = distance
			if missile_target >= 0:
				# Station damage uses the same simultaneous resolution as hull missiles.
				var attacker: Dictionary = {"owner": system["owner"]}
				_missile_splash(state, cells, positions, team_by_id, team, missile_target, attacker, MISSILE_DAMAGE * STATION_MISSILE_COUNT, damage, killed_by, health, hull_slots, hull_health)
				missile_cd = MISSILE_COOLDOWN
				station["missile_origin"] = origin
				station["missile_endpoint"] = positions[missile_target]
				station["missile_until"] = float(state["elapsed"]) + 0.65
		station["missile_cooldown"] = missile_cd
		var target: int = -1
		var best: float = LASER_RANGE * LASER_RANGE
		for x in range(-1, 2):
			for y in range(-1, 2):
				for other in _hostile_bucket(state, cells, hostile_cache, cell + Vector2i(x, y), team, team_by_id):
					var other_id: int = int(other["id"])
					if other_id < 0 or int(team_by_id[int(other["id"])]) == team:
						continue
					var distance: float = origin.distance_squared_to(positions[other_id])
					if distance < best or (distance <= best and (target < 0 or other_id < target)):
						target = other_id
						best = distance
		for weapon in weapons:
			if int(weapon["target"]) != target:
				weapon["laser_until"] = -1.0
			weapon["target"] = target
			var cooldown: float = maxf(0.0, float(weapon["cooldown"]) - dt)
			if target >= 0 and cooldown <= EPS:
				damage[target] = float(damage.get(target, 0.0)) + LASER_DAMAGE
				cooldown = 1.0
				weapon["laser_until"] = float(state["elapsed"]) + 0.2
			weapon["cooldown"] = cooldown
	# Planets are visual orbits around a shared authoritative system waypoint.
	# Use that waypoint for range; each installed battery fires independently.
	for index in range((state["planets"] as Array).size()):
		var system: Dictionary = state["planets"][index]
		var defenses: Dictionary = system.get("pds", {})
		if defenses.is_empty():
			continue
		var team: int = _combat_group(state, int(system["owner"]))
		if team <= 0:
			continue
		var origin: Vector2 = graph["points"][index]
		var cell := Vector2i(floori(origin.x / LASER_RANGE), floori(origin.y / LASER_RANGE))
		var target: int = -1
		var best: float = PDS_RANGE * PDS_RANGE
		var reach: int = ceili(PDS_RANGE / LASER_RANGE)
		for x in range(-reach, reach + 1):
			for y in range(-reach, reach + 1):
				for other in _hostile_bucket(state, cells, hostile_cache, cell + Vector2i(x, y), team, team_by_id):
					if int(team_by_id[int(other["id"])]) == team:
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
	for ship in ships:
		if bool(ship.get("cloak_equipped", false)) and float(state["elapsed"]) < float(ship.get("cloak_reveal_until", 0.0)):
			ship["cloaked"] = false
	for target in killed_by:
		var attacker: Dictionary = killed_by[target]
		attacker["kills"] = int(attacker.get("kills", 0)) + 1
	for ship in ships.duplicate():
		var id: int = int(ship["id"])
		if damage.has(id):
			_apply_reward_damage(ship, ship_max_hp(str(ship["kind"])), float(damage[id]), float(state["elapsed"]))
			if float(ship["hp"]) <= EPS:
				if killed_by.has(id) and SHIP_KINDS.has(ship["kind"]):
					var attacker: Dictionary = killed_by[id]
					var progress: Dictionary = objective_progress(state, int(attacker["owner"]))
					progress["enemy_ships_destroyed"] = int(progress.get("enemy_ships_destroyed", 0)) + 1
				_record_ship_destruction(state, graph, ship)
				_remove_indexed_hull(state, ship)
	# Remove in reverse slot order to preserve indices during compaction.
	var destroyed: Array[int] = []
	for id in yard_targets:
		if not damage.has(id):
			continue
		var location: Vector2i = yard_targets[id]
		var yard: Dictionary = state["planets"][location.x]["yards"][location.y]
		yard["hp"] = maxf(0.0, float(yard.get("hp", YARD_HP * int(yard["level"]))) - float(damage[id]))
		if float(yard["hp"]) <= EPS:
			destroyed.append(id)
	destroyed.sort()
	for id in destroyed:
		var location: Vector2i = yard_targets[id]
		var planet: Dictionary = state["planets"][location.x]
		_record_ship_destruction(state, graph, {"id": id, "kind": "shipyard", "owner": planet["owner"], "position": shipyard_position(state, location.x, location.y, float(state["elapsed"])), "heading": Vector2.UP})
		var job_id: int = int(planet["yards"][location.y]["job"])
		for item in planet["queue"].duplicate():
			if int(item["id"]) == job_id or int(item.get("yard_slot", -1)) == location.y or (item["kind"] == "yard_upgrade" and int(item["target"]) == location.y):
				planet["queue"].erase(item)
			elif item["kind"] == "yard_upgrade" and int(item["target"]) > location.y:
				item["target"] = str(int(item["target"]) - 1)
			elif int(item.get("yard_slot", -1)) > location.y:
				item["yard_slot"] = int(item["yard_slot"]) - 1
		# Residents are lost proportionally when their housing is destroyed.
		var eco: float = eco_population(planet)
		var lost: float = minf(eco, eco / maxf(1.0, float(eco_housing_count(planet))))
		for y in range(planet["yards"].size()):
			planet["yards"][y]["station_slot"] = shipyard_port(planet, y)
		planet["yards"].remove_at(location.y)
		_shift_yard_targets(state, location.x, location.y)
		planet["population"] = maxf(0.0, float(planet["population"]) - lost)
		planet["eco_population"] = maxf(0.0, eco - lost)
		_compact_shipyard_orders(state, planet, location.y + 1)
		for slot in range(3):
			planet["continuous"].erase("yard_upgrade:%d" % slot)
	for id in station_targets:
		if not damage.has(id):
			continue
		var index: int = station_targets[id]
		var station: Dictionary = state["planets"][index]["station"]
		_apply_reward_damage(station, station_max_hp(state["planets"][index]), float(damage[id]), float(state["elapsed"]))
		if float(station["hp"]) <= EPS:
			_destroy_station(state, graph, index)

# Strategic diplomacy is deliberately slower than tactical fleet orders.
# All scores are provisional fighter-equivalent estimates, not hidden exact
# enemy economies. Existing treaties remain the sole authority for changes.
const AI_DIPLOMACY_INTERVAL: float = 24.0
const AI_DIPLOMACY_OPENING: float = 60.0
const AI_DIPLOMACY_DISTANCE: float = 8000.0
const AI_DIPLOMACY_MAX_ALLIES: int = 2

static func _ai_diplomatic_estimates(state: Dictionary, player: int) -> Dictionary:
	var estimates: Dictionary = {}
	var fog: bool = bool(state.get("fog_of_war", DEFAULT_FOG_OF_WAR))
	var vision: Dictionary = team_vision(state, player) if fog else {}
	var home: int = military_home(state, player)
	var origin: Vector2 = state["map"]["points"][home] if home >= 0 else Vector2.INF
	var now: float = float(state["elapsed"])
	for id in state["teams"]:
		if not state.get("eliminated", []).has(id):
			estimates[id] = {"fleet": 0.0, "defense": 0.0, "stations": 0, "distance": INF}
	for system_index in range(state["planets"].size()):
		var system: Dictionary = state["planets"][system_index]
		var owner: int = int(system["owner"])
		if not estimates.has(owner) or not has_station(system):
			continue
		var point: Vector2 = station_position(state, system_index, now)
		if owner != player and fog and not vision.has(vision_cell(point)):
			continue
		var estimate: Dictionary = estimates[owner]
		estimate["stations"] += 1
		# A station is harder to conquer than a handful of mobile hulls.
		estimate["defense"] += 5.0 * clampf(float(system["station"].get("hp", STATION_HP)) / STATION_HP, 0.0, 2.0) + 1.5 * system.get("pds", {}).size()
		if origin.is_finite():
			estimate["distance"] = minf(float(estimate["distance"]), origin.distance_to(point))
	for craft in state["ships"]:
		var owner: int = int(craft["owner"])
		var kind: String = str(craft["kind"])
		if not estimates.has(owner) or not armed(craft):
			continue
		var point: Vector2 = craft.get("position", Vector2.INF)
		if owner != player and ((fog and (not point.is_finite() or not vision.has(vision_cell(point)))) or not ship_visible_to_team(state, craft, player)):
			continue
		var weight: float = float({"miner": 0.25, "scout": 0.4, "fighter": 1.0, "cruiser": 5.0, "destroyer": 9.0}.get(kind, 0.0))
		weight *= clampf(float(craft.get("hp", ship_max_hp(kind))) / ship_max_hp(kind), 0.0, 1.0)
		weight *= 0.4 if bool(craft.get("retreating", false)) else 1.0
		estimates[owner]["fleet"] += weight
		if origin.is_finite() and point.is_finite():
			estimates[owner]["distance"] = minf(float(estimates[owner]["distance"]), origin.distance_to(point))
	return estimates

static func _ai_rival_power(estimate: Dictionary) -> float:
	# Incomplete sight is not proof that a rival is defenseless.
	return maxf(3.0, float(estimate["fleet"])) + maxf(3.0, float(estimate["defense"]))

static func _ai_diplomacy_choice(state: Dictionary, player: int, estimates: Dictionary) -> Dictionary:
	if not estimates.has(player):
		return {}
	var own: Dictionary = estimates[player]
	var fleet: float = float(own["fleet"])
	var defense: float = float(own["defense"])
	var own_power: float = maxf(1.0, fleet + defense)
	var rivals: Array = estimates.keys()
	rivals.sort()
	var enemy_burden: float = 0.0
	var wars: int = 0
	var allies: int = 0
	for id in rivals:
		var other: int = int(id)
		if other == player:
			continue
		if empires_hostile(state, player, other):
			wars += 1
			enemy_burden += _ai_rival_power(estimates[other])
		elif empires_allied(state, player, other):
			allies += 1
	var best: Dictionary = {}
	var best_score: float = 0.0
	var now: float = float(state["elapsed"])
	for id in rivals:
		var other: int = int(id)
		if other == player or not _can_change_diplomacy(state, player, other):
			continue
		var relation: String = diplomatic_relation(state, player, other)
		if relation in [DIPLO_ALLIED, DIPLO_TRUCE]:
			continue
		var rival: Dictionary = estimates[other]
		var rival_power: float = _ai_rival_power(rival)
		var distance: float = float(rival["distance"])
		var proximity: float = clampf(1.0 - distance / AI_DIPLOMACY_DISTANCE, 0.0, 1.0)
		var entry: Dictionary = state["diplomacy"].get(_diplomacy_pair(player, other), {})
		var action: String = ""
		var score: float = 0.0
		if relation == DIPLO_WAR:
			if int(entry.get("peace_offer", 0)) == player:
				continue
			var other_fronts: float = maxf(0.0, enemy_burden - rival_power)
			# Opportunity cost: peace frees fleets for defense or a better war.
			var pressure: float = (rival_power + other_fronts * 0.8) / own_power
			var limited_gain: bool = int(rival["stations"]) == 0 or proximity < 0.2
			var incoming: bool = int(entry.get("peace_offer", 0)) == other
			if pressure > 1.2 or (wars > 1 and pressure > 0.85) or (limited_gain and (incoming or wars > 1 or fleet < 3.0)):
				action = "peace"
				score = 3.0 + minf(3.0, pressure) + (1.0 if incoming else 0.0)
		elif relation == DIPLO_NEUTRAL:
			var common_threat: float = 0.0
			var intervention: float = 0.0
			var ally_conflict: bool = false
			for third_id in rivals:
				var third: int = int(third_id)
				if third in [player, other]:
					continue
				var third_power: float = _ai_rival_power(estimates[third])
				if empires_allied(state, other, third) and not empires_allied(state, player, third):
					# Allies need not join a war; price the possibility, not certainty.
					intervention += third_power * 0.35
				if empires_allied(state, player, third) and empires_hostile(state, other, third):
					ally_conflict = true
				if empires_hostile(state, player, third) and empires_hostile(state, other, third):
					common_threat += third_power
				elif not empires_allied(state, other, third) and not empires_allied(state, player, third) and third_power > own_power * 1.5 and third_power > rival_power * 1.2:
					common_threat += third_power * 0.5
			var incoming: bool = int(entry.get("alliance_offer", 0)) == other
			if allies < AI_DIPLOMACY_MAX_ALLIES and not ally_conflict and int(entry.get("alliance_offer", 0)) != player:
				var coalition_value: float = common_threat / own_power
				# Accept useful cooperation even before a common enemy fires.
				if coalition_value > 0.65 or (incoming and wars > 0 and rival_power >= own_power * 0.65) or (incoming and proximity > 0.25 and rival_power >= own_power * 0.75):
					action = "alliance"
					score = 2.0 + minf(3.0, coalition_value) + (0.5 if incoming else 0.0)
			# Require a real, reachable visible station and a substantial
			# offensive advantage; never declare due to ordinary movement.
			var expected_cost: float = rival_power + enemy_burden * 0.8 + intervention
			var advantage: float = fleet / maxf(1.0, expected_cost)
			if action.is_empty() and now >= AI_DIPLOMACY_OPENING and wars < 2 and int(own["stations"]) > 0 and int(rival["stations"]) > 0 and proximity > 0.0 and fleet >= 6.0 and advantage > 1.35:
				action = "declare_war"
				score = minf(4.0, advantage) + proximity - 0.5 * wars
		if not action.is_empty() and score > best_score:
			best_score = score
			best = {"action": action, "other": other}
	return best

static func _ai_diplomacy_turn(state: Dictionary, player: int) -> bool:
	if not state.has("diplomacy") or not state.get("ai_players", []).has(player) or state.get("eliminated", []).has(player) or not state.get("match_result", {}).is_empty():
		return false
	var decision: Dictionary = _ai_diplomacy_choice(state, player, _ai_diplomatic_estimates(state, player))
	var other: int = int(decision.get("other", 0))
	match decision.get("action", ""):
		"declare_war": return diplomacy_declare_war(state, player, other)
		"peace": return diplomacy_offer_peace(state, player, other)
		"alliance": return diplomacy_offer_alliance(state, player, other)
	return false

static func _dispatch_ai_diplomacy(state: Dictionary) -> void:
	if not state.has("diplomacy") or state.get("ai_players", []).is_empty():
		return
	var now: float = float(state["elapsed"])
	var schedule: Dictionary = state.get("_ai_diplomacy_schedule", {})
	for player in state["ai_players"]:
		var id: int = int(player)
		# Stagger initial evaluations across the eight slots, then keep the
		# independent slow decision clock to bound work at large fleet sizes.
		var phase: float = float(posmod(id - 1, 8)) * AI_DIPLOMACY_INTERVAL / 8.0
		if now + EPS < float(schedule.get(id, phase)):
			continue
		_ai_diplomacy_turn(state, id)
		schedule[id] = now + AI_DIPLOMACY_INTERVAL
	state["_ai_diplomacy_schedule"] = schedule

static func _ai_colony_target(state: Dictionary, player: int, ship: Dictionary, reserved: Dictionary) -> int:
	var points: Array = state["map"]["points"]
	var teams: Array[int] = planet_teams(state)
	var team: int = _combat_group(state, player)
	var here: int = int(ship["at"])
	if team == 0 or ((not _civilian_transit_allowed(state, team, teams[here]) if state.has("diplomacy") else teams[here] != team) and military_home(state, player) >= 0):
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
			if state.has("diplomacy") and not _civilian_transit_allowed(state, team, teams[node]):
				continue
			var distance: float = float(distances[current]) + (points[current] as Vector2).distance_to(points[node])
			if teams[node] == 0:
				if not reserved.has(node) and discovered(state, player, "planets", int(node)):
					var richness: float = float(state["planets"][node]["abundance"].get("Metals", 0.0))
					var score: float = distance / (1.0 + minf(richness, 2.0) * 0.15) * (1.0 if has_planets(state["planets"][node]) else 1.6)
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
			if target >= 0 and send_colony(state, player, int(ship["id"]), target, true):
				reserved[target] = true
		return
	var planets: Array = state["planets"]
	var team: int = _combat_group(state, player)
	var owned: Array[int] = []
	var counts: Dictionary = {"ship": 0, "colony_ship": 0, "miner": 0, "fighter": 0, "science_ship": 0, "scout": 0, "cruiser": 0, "destroyer": 0}
	var reserved: Dictionary = {}
	var fighters: Array = []
	var idle_colonies: Array = []
	var useful_fields: int = 0
	for ship in state["ships"]:
		if int(ship["owner"]) != player:
			continue
		var kind: String = ship["kind"]
		if kind == "warp_gate":
			continue
		counts[kind] += 1
		if kind in ["fighter", "scout", "cruiser", "destroyer"]:
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
		var crystal_source: bool = production_available(p, "Crystals") and index != home
		set_thresholds(state, player, index, "Crystals", 0.0 if crystal_source else 50.0, 5.0 if crystal_source else 90.0)
	for ship in idle_colonies:
		var target: int = _ai_colony_target(state, player, ship, reserved)
		if target >= 0 and send_colony(state, player, int(ship["id"]), target, true):
			reserved[target] = true
	var probe: Dictionary = {"kind": "colony_ship", "owner": player, "at": home, "route": []}
	var expansion: bool = _ai_colony_target(state, player, probe, reserved) >= 0
	for index in owned:
		var p: Dictionary = planets[index]
		if not (p["queue"] as Array).is_empty():
			continue
		if not has_planets(p) and float(p["population"]) < ORBITAL_HOUSING_POPULATION:
			enqueue(state, player, index, "economy", "orbital_housing")
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
			# After basic defense, expansion and logistics, reserve a capital
			# budget at the home yard. Other stations keep producing escorts.
			var population: float = float(p["population"])
			if index == home and has_yard and counts["fighter"] >= AI_WAVE_MIN and counts["cruiser"] < maxi(1, mini(4, owned.size())) and population >= SHIPYARD_POPULATION[1] + CREW_COSTS["cruiser"]:
				action = "cruiser"
			elif index == home and has_yard and counts["cruiser"] > 0 and counts["destroyer"] < maxi(1, mini(3, ceili(float(owned.size()) / 2.0))) and population >= SHIPYARD_POPULATION[2] + CREW_COSTS["destroyer"]:
				action = "destroyer"
			elif index != home and production_available(p, "Crystals") and production_level(p, "Crystals") == 0 and counts["fighter"] >= AI_WAVE_MIN:
				action = "economy"
				target = "Crystals"
			elif has_yard and counts["fighter"] < maxi(3, mini(24, owned.size() * 2)):
				action = "fighter"
			elif has_yard and useful_fields > 0 and counts["miner"] < mini(6, useful_fields * 2):
				action = "miner"
			elif abundance > 0.0 and level < 4:
				action = "economy"
				target = "Metals"
			elif has_planets(p) and farm < 3 and float(p["population"]) > population_capacity(p) * 0.8:
				action = "economy"
				target = "Organics"
			elif (p["yards"] as Array).is_empty():
				action = "yard"
			elif counts["fighter"] < 32:
				action = "fighter"
			else:
				for resource in ["Crystals"]:
					if float(p["abundance"].get(resource, 0.0)) > 0.0 and production_level(p, resource) == 0:
						action = "economy"
						target = resource
						break
		if action.is_empty():
			continue
		if action in ["cruiser", "destroyer"]:
			# Do not export the savings needed for capital construction.
			set_thresholds(state, player, index, "Metals", 90.0, 100.0)
		if SHIP_KINDS.has(action) and not has_fitting_yard(p, action):
			if p["yards"].is_empty():
				action = "yard"
				target = ""
			else:
				var best_yard: int = 0
				for slot in range(1, p["yards"].size()):
					if int(p["yards"][slot]["level"]) > int(p["yards"][best_yard]["level"]):
						best_yard = slot
				action = "yard_upgrade"
				target = str(best_yard)
		var build_level: int = next_shipyard_slot(p) if action == "yard" else (int(p["yards"][int(target)]["level"]) + 1 if action == "yard_upgrade" else 1)
		var price: Dictionary = building_cost(p, target) if action == "economy" else construction_cost(p, action, build_level)
		# Capital hulls (and enabling upgrades) cannot fit the initial
		# warehouse. Reserve a normal warehouse upgrade before saving.
		var capacity_needed: float = 0.0
		for resource in price:
			capacity_needed = maxf(capacity_needed, float(price[resource]))
		if capacity_needed > storage_capacity(p) + EPS:
			if warehouse_available(p):
				enqueue(state, player, index, "economy", "warehouse")
			continue
		if not affordable(p, price):
			# Saving for an unaffordable hull must not leave mature systems
			# waiting indefinitely for food or local extraction.
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
		if not can_pay_credits(state, player, construction_credit_cost(price, action)):
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
	var team: int = _combat_group(state, player)
	var planets: Array = state["planets"]
	var points: Array = graph["points"]
	var pois: Array[int] = military_pois(state, player)
	# Repairing hulls cannot defend or form an attack cohort yet. Count
	# only combat-ready ships until they return to the normal order loop.
	var ready: Array = fighters.filter(func(craft: Dictionary) -> bool: return not bool(craft.get("retreating", false)))
	var center: Vector2 = points[home]
	if not ready.is_empty():
		center = Vector2.ZERO
		for ship in ready:
			center += combat_position(state, graph, ship)
		center /= float(ready.size())
	var reference: Dictionary = {"at": home, "route": [], "position": points[home]}
	var reference_distance: float = INF
	for craft in ready:
		var distance: float = combat_position(state, graph, craft).distance_squared_to(center)
		if distance < reference_distance:
			reference = craft
			reference_distance = distance
	var threats: Dictionary = {}
	var opportunities: Dictionary = {}
	for ship in state["ships"]:
		if not empires_hostile(state, player, int(ship["owner"])):
			continue
		var position: Vector2 = combat_position(state, graph, ship)
		if ship.get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"] and not bool(ship.get("retreating", false)):
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
		if node < planets.size() and empires_allied(state, player, int(planets[node]["owner"])):
			continue
		opportunities[node] = true
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
			var distance: float = float(_military_approach(graph, reference, _military_paths(graph, node))["distance"])
			if distance < nearest:
				goal = node
				nearest = distance
	# Keep a three-fighter attack cohort affordable. Small empires attack
	# together in peace and defend together when threatened.
	var defense_weight: int = 100 if goal < 0 else 0
	if goal >= 0:
		if danger > 0:
			defense_weight = 100 if ready.size() < 7 else 60
		elif ready.size() >= 4:
			defense_weight = 25
	if not state.has("ai_objectives"):
		state["ai_objectives"] = {}
	state["ai_objectives"][player] = goal
	var defenders: int = ceili(float(ready.size()) * defense_weight / 100.0)
	if ready.size() - defenders < AI_WAVE_MIN:
		defenders = ready.size()
	# Select defenders closest to the threatened POI. Keep already assigned
	# hulls stable where possible; every order uses the same authority path.
	var ranked: Array = ready.duplicate()
	var distances: Dictionary = {}
	var defense_paths: Dictionary = _military_paths(graph, defense)
	for craft in ranked:
		distances[int(craft["id"])] = float(_military_approach(graph, craft, defense_paths)["distance"])
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: float = distances[int(a["id"])]
		var db: float = distances[int(b["id"])]
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
	return empires_hostile(state, player, owner)

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
	# Membership checks must not scan an entire wave for every hull.
	var wave_members: Dictionary = {}
	var ai_players: Dictionary = {}
	for player in state.get("ai_players", []):
		ai_players[player] = true
	for owner in state.get("ai_waves", {}):
		var members: Dictionary = {}
		for member in state["ai_waves"][owner].get("members", []):
			members[member] = true
		wave_members[owner] = members
	var current: Dictionary = {}
	var indexed: bool = is_same(state, _indexed_state)
	var by_id: Dictionary = _hulls_by_id if indexed else {}
	for ship in state["ships"]:
		if bool(ship.get("rogue", false)) or ship.get("kind", "") not in ["fighter", "scout", "cruiser", "destroyer"]:
			continue
		var owner: int = int(ship["owner"])
		var target: int = int(ship.get("operation_target", ship.get("withdrawal_objective", ship.get("dest", -1))))
		if target < 0:
			target = int(ship["at"])
		var role: String = "hold" if bool(ship.get("holding", false)) else "allocation"
		if ai_players.has(owner) and not bool(ship.get("direct_order", false)):
			var wave: Dictionary = state.get("ai_waves", {}).get(owner, {})
			role = "wave" if wave_members.get(owner, {}).has(int(ship["id"])) else "reserve"
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
		if not indexed:
			by_id[ship_id] = ship
		operation["members"].append(ship_id)
		operation["moving"] = bool(operation["moving"]) or (not (ship["route"] as Array).is_empty() and (not bool(ship.get("holding", false)) or bool(ship.get("retreating", false))))
		operation["engaged"] = bool(operation["engaged"]) or _engaged(ship)
	var reused: Dictionary = {}
	var prior_by_id: Dictionary = {}
	var prior_members: Dictionary = {}
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
				if not prior_members.has(candidate):
					var member_set: Dictionary = {}
					for member in old["members"]:
						member_set[member] = true
					prior_members[candidate] = member_set
				var overlap: int = 0
				for member in operation["members"]:
					if prior_members[candidate].has(member):
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
		var prior_deployed: Dictionary = {}
		for member in operation["deployed"]:
			prior_deployed[member] = true
		var recovering: Array = []
		var rallying: Array = []
		var in_transit: Array = []
		for member in operation["members"]:
			var craft: Dictionary = by_id[member]
			if bool(craft.get("retreating", false)):
				recovering.append(member)
			elif operation["role"] == "wave" or prior_deployed.has(member):
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
	var budget: float = ship_speed(str(ship.get("kind", "ship"))) * dt
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
		if craft.get("kind", "") not in ["fighter", "scout", "cruiser", "destroyer"] or craft.get("unit_order", {}).get("kind", "") in ["follow", "guard", "patrol"] or craft.has("launch_rally") or craft.has("local_move_target") or craft.has("attack_order") or craft.has("cargo_order") or _salvage_active(craft) or _engaged(craft) or bool(craft.get("retreating", false)) or bool(craft.get("holding", false)) or (craft["route"] as Array).is_empty():
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
		var next_progress: float = minf(length, progress + ship_speed(str(first.get("kind", "ship"))) * FORMATION_TRAVEL_FRACTION * dt)
		var arrived: bool = true
		for craft in group:
			var offset: Vector2 = _formation_offset(craft, axis)
			var corrected: Vector2 = craft["position"] - offset
			var own_progress: float = clampf((corrected - origin).dot(axis), 0.0, length)
			var target: Vector2 = origin + axis * maxf(own_progress, next_progress) + offset
			_navigate(craft, target, ship_speed(str(craft.get("kind", "ship"))) * dt)
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
	if not has_station(planet) or (not diplomacy_allows(state, owner, int(planet["owner"]), "repair") if state.has("diplomacy") else int(planet["owner"]) != owner):
		return false
	var center: Vector2 = station_position(state, site, float(state["elapsed"]))
	for other in state["ships"]:
		if other.get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"] and empires_hostile(state, owner, int(other["owner"])) and combat_position(state, graph, other).distance_to(center) <= REPAIR_SAFE_RADIUS:
			return false
	return true

static func _cached_repair_site_safe(state: Dictionary, graph: Dictionary, owner: int, site: int, safety: Dictionary) -> bool:
	var key := Vector2i(owner, site)
	if not safety.has(key):
		safety[key] = _repair_site_safe(state, graph, owner, site)
	return bool(safety[key])

static func _nearest_repair_site(state: Dictionary, graph: Dictionary, ship: Dictionary, paths: Dictionary, safety: Dictionary = {}) -> int:
	var best: int = -1
	var distance: float = INF
	for site in range((state["planets"] as Array).size()):
		if not _cached_repair_site_safe(state, graph, int(ship["owner"]), site, safety):
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
	# Positions and station ownership are fixed during withdrawal planning.
	# Rebuild after combat; movement-time safety still checks live positions.
	var safety: Dictionary = {}
	for ship in state["ships"]:
		if not armed(ship):
			continue
		var withdrawing: bool = bool(ship.get("retreating", false))
		if not withdrawing and (not autocast_enabled(ship, "retreat") or float(ship.get("hp", ship_max_hp(str(ship["kind"])))) > ship_max_hp(str(ship["kind"])) * WITHDRAW_HP / SHIP_HP):
			continue
		var site: int = int(ship.get("repair_site", -1))
		if not withdrawing or not _cached_repair_site_safe(state, graph, int(ship["owner"]), site, safety):
			var replacement: int = _nearest_repair_site(state, graph, ship, paths, safety)
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
			_cancel_salvage_order(ship)
			ship.erase("repair_target")
			if ship["kind"] == "miner":
				_interrupt_work(ship)
		ship["retreating"] = true
		ship["repair_site"] = site
		ship["combat_target"] = -1
		ship["pursuit_target"] = -1
		ship["pursuit_left"] = 0.0
		ship["laser_until"] = -1.0
		if int(ship.get("dest", -1)) != site:
			if not paths.has(site):
				paths[site] = _military_paths(graph, site)
			var nav: Dictionary = _manual_nav(state, graph, ship, site)
			_redirect_fighter(nav["graph"], ship, site, _military_paths(nav["graph"], site))

static func _work_withdrawal(state: Dictionary, graph: Dictionary, ship: Dictionary, dt: float) -> void:
	var site: int = int(ship["repair_site"])
	if not (ship["route"] as Array).is_empty():
		_move({"map": graph}, ship, dt, station_position(state, site, float(state["elapsed"])), site, STATION_REPAIR_RANGE)
		return
	if int(ship["at"]) != site:
		return
	var dock: Vector2 = station_position(state, site, float(state["elapsed"]))
	var distance: float = 0.0
	if (ship["position"] as Vector2).distance_to(dock) > STATION_REPAIR_RANGE:
		var berth: Vector2 = _waiting_berth(state, ship, dock, STATION_REPAIR_RANGE, dock.direction_to(ship["position"]))
		distance = _navigate(ship, berth, ship_speed(str(ship.get("kind", "ship"))) * dt)
	else:
		ship["navigation_target"] = ship["position"]
	if (ship["position"] as Vector2).distance_to(dock) > STATION_REPAIR_RANGE + EPS or not _repair_site_safe(state, graph, int(ship["owner"]), site):
		return
	var repair_time: float = maxf(0.0, dt - distance / ship_speed(str(ship.get("kind", "ship"))))
	var maximum: float = ship_max_hp(str(ship["kind"]))
	ship["hp"] = minf(maximum, float(ship.get("hp", maximum)) + REPAIR_PER_YEAR * repair_time)
	if float(ship["hp"]) >= maximum - EPS:
		ship["hp"] = maximum
		ship["retreating"] = false
		ship.erase("repair_site")
		ship.erase("withdrawal_objective")
		# Normal dispatch resumes the latest allocation or AI reserve order.
		ship["dest"] = -1
		if bool(ship.get("holding", false)):
			ship["operation_target"] = int(ship.get("hold_sector", site))

static func _order_operation_ship(graph: Dictionary, ship: Dictionary, goal: int, paths: Dictionary) -> void:
	if ship.get("unit_order", {}).get("kind", "") == "follow" or _salvage_active(ship) or ship.has("cargo_order") or ship.has("attack_order") or int(ship.get("dest", -1)) == goal:
		return
	if not paths.has(goal):
		paths[goal] = _military_paths(graph, goal)
	_redirect_fighter(graph, ship, goal, paths[goal])

# A hostile-owned system is an attack objective. Other POIs retain immediate
# allocation orders, including home defense and neutral/field assignments.
# Reuse the AI minimum and physical rally radius as provisional defaults.
static func _dispatch_operations(state: Dictionary, graph: Dictionary) -> void:
	var by_id: Dictionary = _hulls_by_id if is_same(state, _indexed_state) else {}
	if not is_same(state, _indexed_state):
		for ship in state["ships"]:
			if ship.get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"]:
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
			attack = empires_hostile(state, owner, defender)
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
		var deployed_set: Dictionary = {}
		for member in operation["deployed"]:
			deployed_set[member] = true
		for member in operation["members"]:
			fighters.append(by_id[member])
			if deployed_set.has(member) and not bool(by_id[member].get("retreating", false)):
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
	var budget: float = ship_speed(str(ship.get("kind", "ship"))) * dt
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
	_navigate(ship, position + separation.normalized() * travel, ship_speed(str(ship.get("kind", "ship"))) * duration)
	ship["pursuit_left"] = maxf(0.0, float(ship["pursuit_left"]) - duration)

# Idle ships remain in their current sector. Up to three same-owner,
# same-kind hulls share a moving local anchor and tangent-relative V slots.
# Routing, docking, mining, combat and withdrawal always take precedence.
# Derived primary activity: existing orders/jobs remain authoritative.
# No replicated state or invalidation requirement; use a local value only
# while the hull's orders, route and combat flags are unchanged.
enum ShipActivity { IDLE, MOVING, FIGHTING, MINING, HAULING, REPAIRING, HOLDING, WITHDRAWING, WORKING }

static func ship_activity(ship: Dictionary) -> ShipActivity:
	if bool(ship.get("retreating", false)):
		return ShipActivity.WITHDRAWING
	if bool(ship.get("holding", false)):
		return ShipActivity.HOLDING
	if _engaged(ship) or ship.has("attack_order"):
		return ShipActivity.FIGHTING
	if ship.has("repair_order") or ship.has("repair_target"):
		return ShipActivity.REPAIRING
	if ship.has("cargo_order") or ship.has("resource_stage") or bool(ship.get("salvage_delivery", false)):
		return ShipActivity.HAULING
	if not (ship["route"] as Array).is_empty() or ship.has("local_move_target") or ship.has("launch_rally") or ship.has("patrol_from"):
		return ShipActivity.MOVING
	var order: Variant = ship.get("unit_order")
	if order != null:
		var order_kind: String = order.get("kind", "")
		if order_kind == "follow" or order_kind == "guard":
			return ShipActivity.MOVING
	if int(ship.get("salvage_target", -1)) >= 0:
		return ShipActivity.WORKING
	var mode: String = str(ship.get("mining_mode", "idle"))
	var kind: String = str(ship.get("kind", ""))
	var dest: int = int(ship.get("dest", -1))
	if mode != "idle" and not (kind == "miner" and mode == "delivery" and dest < 0):
		return ShipActivity.MINING if kind == "miner" else ShipActivity.WORKING
	if int(ship.get("source", -1)) >= 0:
		return ShipActivity.HAULING
	if dest >= 0 and kind != "fighter" and kind != "scout" and kind != "cruiser" and kind != "destroyer":
		return ShipActivity.MOVING
	return ShipActivity.IDLE

static func _is_idle_ship(ship: Dictionary) -> bool:
	return ship_activity(ship) == ShipActivity.IDLE

# Select adjacent connected sectors by low allied occupancy and oldest visit.
static func _dispatch_explorers(state: Dictionary, graph: Dictionary) -> void:
	var occupancy: Dictionary = {}
	var scouts: Array = []
	for craft in state["ships"]:
		var team: int = _combat_group(state, int(craft["owner"]))
		var node: int = int(craft.get("at", -1))
		var key := Vector2i(team, node)
		occupancy[key] = int(occupancy.get(key, 0)) + 1
		if bool(craft.get("unit_order", {}).get("exploration", false)) and not craft.get("route", []).is_empty():
			var destination := Vector2i(team, int(craft.get("dest", node)))
			occupancy[destination] = int(occupancy.get(destination, 0)) + 1
		if craft.get("kind", "") == "scout" and _is_idle_ship(craft) and craft.get("order_queue", []).is_empty() and not _unit_order_running(craft) and autocast_ready(state, craft, "explore"):
			scouts.append(craft)
	if scouts.is_empty():
		return
	for node in range(state["planets"].size()):
		var system: Dictionary = state["planets"][node]
		if has_station(system):
			var key := Vector2i(_combat_group(state, int(system["owner"])), node)
			occupancy[key] = int(occupancy.get(key, 0)) + 8 + system["yards"].size()
	for craft in scouts:
		var node: int = int(craft["at"])
		if node < 0 or node >= graph["adjacent"].size():
			continue
		var team: int = _combat_group(state, int(craft["owner"]))
		var visits: Dictionary = craft.get("explore_visits", {})
		visits[node] = float(state["elapsed"])
		var best: int = -1
		var score: float = -INF
		for candidate in graph["adjacent"][node]:
			var age: float = minf(600.0, float(state["elapsed"]) - float(visits.get(candidate, -600.0)))
			var friendly_occupancy: int = int(occupancy.get(Vector2i(team, candidate), 0))
			if state.has("diplomacy"):
				for ally in state["teams"]:
					if int(ally) != team and empires_allied(state, team, int(ally)):
						friendly_occupancy += int(occupancy.get(Vector2i(int(ally), candidate), 0))
			var value: float = age - float(friendly_occupancy) * 80.0
			if value > score:
				score = value
				best = candidate
		if best < 0:
			continue
		craft["explore_visits"] = visits
		_clear_local_hold(craft)
		_set_unit_order(state, craft, {"kind": "sector", "target": best, "move_only": true, "exploration": true})
		craft["direct_order"] = true
		craft["move_only"] = true
		craft["operation_target"] = best
		_redirect_fighter(graph, craft, best, _military_paths(graph, best))
		var key := Vector2i(team, best)
		occupancy[key] = int(occupancy.get(key, 0)) + 1

static func _idle_formation_targets(state: Dictionary, graph: Dictionary) -> Dictionary:
	var groups: Dictionary = {}
	var stationary_teams: Dictionary = {}
	for ship in state["ships"]:
		if ship.get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"] and (ship["route"] as Array).is_empty() and not bool(ship.get("retreating", false)):
			var node: int = int(ship["at"])
			if not stationary_teams.has(node):
				stationary_teams[node] = {}
			stationary_teams[node][_combat_group(state, int(ship["owner"]))] = true
		if not _is_idle_ship(ship) or not autocast_ready(state, ship, "wander"):
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
			if leader.get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"]:
				var team: int = _combat_group(state, int(leader["owner"]))
				var owner: int = int(state["planets"][node]["owner"]) if node < (state["planets"] as Array).size() else 0
				var hostile_system: bool = empires_hostile(state, int(leader["owner"]), owner)
				var hostile_presence: bool = _combat_sector_has_hostile(stationary_teams, node, team, state) if state.has("diplomacy") else (stationary_teams.get(node, {}) as Dictionary).size() > 1
				compact = bool(leader.get("rally_pending", false)) or hostile_system or hostile_presence
			var phase: float = float(state["elapsed"]) * ship_speed(str(leader.get("kind", "ship"))) / maxf(radius, 100.0)
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
# Find a safe escape route after a civilian's planned route becomes
# hostile. Consider both ends of its existing leg without moving the hull.
# Only the initial hostile waypoint may be used to leave hostile territory.
static func _evacuate_civilian(state: Dictionary, ship: Dictionary, teams: Array[int]) -> bool:
	var team: int = _combat_group(state, int(ship["owner"]))
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
		if state.has("diplomacy") and origin != here and not _civilian_transit_allowed(state, team, teams[origin]):
			continue
		var allowed: Array[int] = _civilian_access(state, teams, team) if state.has("diplomacy") else teams.duplicate()
		allowed[origin] = team
		for node in range(teams.size()):
			if teams[node] != team or (miner and int(state["planets"][node]["owner"]) != int(ship["owner"])):
				continue
			var path: Array[int] = _mining_path(state, allowed, team, origin, node, {}) if miner and not state.has("diplomacy") else MAP.path(state["map"], allowed, team, origin, node)
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
	return destination >= 0

static func _reroute_after_capture(state: Dictionary, index: int) -> void:
	var teams: Array[int] = planet_teams(state)
	for ship in state["ships"]:
		var kind: String = str(ship.get("kind", ""))
		if kind not in ["ship", "miner"] or _salvage_active(ship):
			continue
		var team: int = _combat_group(state, int(ship["owner"]))
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

# Match-only outcome evaluation, invoked by the authoritative session.
# Eliminate only when all stations and hulls are gone. Bilateral mode
# retains conquest as a last-empire fallback, without transitive winners.
# A one-empire sandbox never auto-ends.
static func update_match_outcome(state: Dictionary) -> bool:
	if not state.get("match_result", {}).is_empty():
		return false
	var starting_teams: Dictionary = {}
	for player in state["teams"]:
		starting_teams[_combat_group(state, int(player))] = true
	var viable: Dictionary = {}
	for planet in state["planets"]:
		var owner: int = int(planet["owner"])
		if owner > 0 and has_station(planet):
			viable[owner] = true
	# A fleet remains in play even when every station has fallen.
	for ship in state["ships"]:
		var owner: int = int(ship["owner"])
		if owner > 0:
			viable[owner] = true
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
	if starting_teams.size() < 2:
		return changed
	var remaining_teams: Dictionary = {}
	for player in viable:
		if not eliminated.has(player) and state["teams"].has(player):
			remaining_teams[_combat_group(state, int(player))] = true
	if remaining_teams.size() <= 1:
		var winner: int = int(remaining_teams.keys()[0]) if remaining_teams.size() == 1 else 0
		state["match_result"] = {"team": winner, "reason": "conquest", "elapsed": float(state["elapsed"])}
		if state.has("diplomacy"):
			state["match_result"]["winner"] = winner
		state["time_speed"] = 0
		changed = true
	return changed

static func _profile_stage(profile: Dictionary, stage: String, started: int) -> int:
	if profile.is_empty():
		return 0
	var now: int = Time.get_ticks_usec()
	profile[stage] = int(profile.get(stage, 0)) + now - started
	return now

# Gentle neighborhood steering, not rigid collision or additional travel.
# All hulls are obstacles; ships performing precise service actions are
# not displaced. Use the same pre-movement snapshot for every pair.
static func _separate_ships(state: Dictionary, graph: Dictionary, previous: Dictionary, dt: float, repair_parked: Dictionary = {}) -> void:
	if dt <= 0.0:
		return
	var cells: Dictionary = {}
	var reach: float = SHIP_SEPARATION_RADIUS
	var reach_squared: float = reach * reach
	for ship in state["ships"]:
		var id: int = int(ship["id"])
		if not previous.has(id):
			continue
		var pos: Vector2 = previous[id]
		var cell := Vector2i(floori(pos.x / reach), floori(pos.y / reach))
		if not cells.has(cell):
			cells[cell] = []
		cells[cell].append(id)

	for ship in state["ships"]:
		var id: int = int(ship["id"])
		if not previous.has(id) or repair_parked.has(id) or bool(ship.get("retreating", false)) or _salvage_active(ship):
			continue
		var budget: float = ship_speed(str(ship.get("kind", "ship"))) * dt
		var before: Vector2 = previous[id]
		var planned: Vector2 = ship["position"]
		var held: bool = bool(ship.get("holding", false))
		if held and ship.has("hold_heading"):
			continue
		var local_moving: bool = ship.has("local_move_target")
		# Follow owns its movement budget, including close-range backing off.
		if ship.get("unit_order", {}).get("kind", "") == "follow":
			continue
		# Waiting hulls remain precise obstacles, but combat/withdrawal can move.
		var engaged: bool = _engaged(ship)
		var idle: bool = false
		if not engaged:
			idle = _is_idle_ship(ship)
			var can_wander: bool = idle and autocast_ready(state, ship, "wander")
			if (arrival_wait_remaining(state, ship) > EPS and not can_wander) or (idle and not can_wander):
				continue
		# Preserve the exact endpoint and facing on the arrival tick only.
		# The completed order is retired before next tick's ordinary wandering.
		var order: Dictionary = ship.get("unit_order", {})
		if not local_moving and order.get("kind", "") == "position" and planned == order.get("point", Vector2.INF):
			continue
		# Do not let repulsion prevent completion of a shared point order.
		# The newly idle ships spread naturally after arrival.
		if local_moving and planned.distance_to(ship["local_move_target"]) < reach * 2.0:
			continue
		var route: Array = ship["route"]
		# Exact arrival at a waypoint is required by service and lane logic.
		# Do not push docking or extracting civilian ships off their targets.
		if not held:
			if route.is_empty():
				if not local_moving and not idle and not engaged:
					continue
				var at: int = int(ship["at"])
				if at >= 0 and at < graph["points"].size() and planned.distance_to(graph["points"][at]) <= EPS:
					continue
			else:
				var waypoint: Vector2 = graph["points"][int(route[0])]
				if planned.distance_to(waypoint) < reach * 2.0 + budget:
					continue
		if not held and ship.get("kind", "") == "miner" and ship.get("mining_mode", "") in ["outbound", "mining", "return"]:
			continue
		var force: Vector2 = Vector2.ZERO
		var cell := Vector2i(floori(before.x / reach), floori(before.y / reach))
		for x in range(-1, 2):
			for y in range(-1, 2):
				for other_id in cells.get(cell + Vector2i(x, y), []):
					if int(other_id) == id:
						continue
					var offset: Vector2 = before - (previous[other_id] as Vector2)
					var distance_squared: float = offset.length_squared()
					if distance_squared >= reach_squared:
						continue
					var distance: float = offset.length()
					var direction: Vector2
					if distance <= EPS:
						# Stable opposite directions even for exactly coincident hulls.
						var low: int = mini(id, int(other_id))
						var high: int = maxi(id, int(other_id))
						direction = Vector2.from_angle(float(posmod(low * 97 + high * 193, 360)) * PI / 180.0)
						if id > int(other_id):
							direction = -direction
					else:
						direction = offset / distance
					force += direction * (1.0 - distance / reach)
		if force.is_zero_approx():
			continue
		var movement: Vector2 = planned - before
		if movement.length() > budget + EPS:
			continue
		# A shared hold point is a group anchor. Ease attraction near it
		# so repulsion does not fight a full-speed return to the same pixel.
		if held and ship.has("hold_position") and before.distance_to(ship["hold_position"]) < reach * 2.0:
			movement *= 0.25
		var push: Vector2 = force.limit_length(1.0) * budget * SHIP_SEPARATION_STRENGTH
		var candidate: Vector2 = before + (movement + push).limit_length(budget)
		var sector: int = int(ship.get("local_move_sector", -1)) if local_moving else (int(ship.get("hold_sector", -1)) if held else local_sector(graph, ship))
		if sector >= 0 and sector < graph["points"].size() and sector_contains(graph, sector, planned) and not sector_contains(graph, sector, candidate):
			# Keep local orders and stationary ships inside their legal sector.
			var lower: float = 0.0
			var upper: float = 1.0
			for iteration in range(12):
				var fraction: float = (lower + upper) * 0.5
				if sector_contains(graph, sector, planned.lerp(candidate, fraction)):
					lower = fraction
				else:
					upper = fraction
			candidate = planned.lerp(candidate, lower)
		var displacement: Vector2 = candidate - before
		ship["position"] = candidate
		if not displacement.is_zero_approx():
			ship["heading"] = displacement.normalized()
		if not route.is_empty():
			ship["leg"] = _lane_progress(graph["points"], ship)

# Apply a gentle push on the actual post-movement coordinates, including ships
# exempt from soft steering. This is contact correction, not a new order;
# service actions and arrival checks have already executed for this tick.
# A sparse grid and bounded iterations avoid an all-fleet pair scan.
static func _contact_bucket_near(point: Vector2, bounds: Rect2, cutoff_squared: float) -> bool:
	var nearest: Vector2 = point.clamp(bounds.position, bounds.end)
	# Conservative margin avoids rejecting boundary pairs due to rounding.
	return point.distance_squared_to(nearest) <= cutoff_squared + maxf(0.001, cutoff_squared * 0.0001)

static func _resolve_ship_contacts(state: Dictionary, graph: Dictionary, previous: Dictionary, dt: float = 0.1, repair_parked: Dictionary = {}) -> void:
	var ships: Array = state["ships"]
	if ships.size() < 2:
		return
	var reach: float = SHIP_CLEARANCE
	var cutoff_squared: float = (reach - EPS) * (reach - EPS)
	# Reuse dense indexed scratch arrays across contact passes.
	var corrections := PackedVector2Array()
	corrections.resize(ships.size())
	var touched := PackedByteArray()
	touched.resize(ships.size())
	for iteration in range(SHIP_CLEARANCE_PASSES):
		var cells: Dictionary = {}
		var bounds: Dictionary = {}
		for i in range(ships.size()):
			var point: Vector2 = ships[i]["position"]
			var cell := Vector2i(floori(point.x / reach), floori(point.y / reach))
			if not cells.has(cell):
				cells[cell] = []
			cells[cell].append(i)
			var box: Rect2 = bounds.get(cell, Rect2(point, Vector2.ZERO))
			bounds[cell] = box.expand(point)
		corrections.fill(Vector2.ZERO)
		touched.fill(0)
		var correction_order: Array[int] = []
		for i in range(ships.size()):
			var a: Dictionary = ships[i]
			var pa: Vector2 = a["position"]
			var cell := Vector2i(floori(pa.x / reach), floori(pa.y / reach))
			for x in range(-1, 2):
				for y in range(-1, 2):
					var key: Vector2i = cell + Vector2i(x, y)
					if not bounds.has(key) or not _contact_bucket_near(pa, bounds[key], cutoff_squared):
						continue
					for j in cells[key]:
						if int(j) <= i:
							continue
						var b: Dictionary = ships[j]
						var pb: Vector2 = b["position"]
						var offset: Vector2 = pa - pb
						if offset.length_squared() >= cutoff_squared:
							continue
						var distance: float = offset.length()
						var direction: Vector2
						if distance <= EPS:
							# Side-step a head-on approach; stable IDs break exact ties.
							var old_a: Vector2 = previous.get(int(a["id"]), pa)
							var old_b: Vector2 = previous.get(int(b["id"]), pb)
							var prior: Vector2 = old_a - old_b
							direction = prior.normalized().orthogonal() if prior.length_squared() > EPS else Vector2.from_angle(float(posmod(int(a["id"]) * 97 + int(b["id"]) * 193, 360)) * PI / 180.0)
						else:
							direction = offset / distance
						var push: Vector2 = direction * (reach - distance) * 0.12
						if touched[i] == 0:
							touched[i] = 1
							correction_order.append(i)
						if touched[j] == 0:
							touched[j] = 1
							correction_order.append(int(j))
						corrections[i] += push
						corrections[j] -= push
		if correction_order.is_empty():
			break
		for i in correction_order:
			var craft: Dictionary = ships[i]
			if repair_parked.has(int(craft["id"])) or (bool(craft.get("holding", false)) and craft.has("hold_heading") and not bool(craft.get("retreating", false))):
				continue
			var point: Vector2 = craft["position"]
			var budget: float = ship_speed(str(craft.get("kind", "ship"))) * dt
			var before: Vector2 = previous.get(int(craft["id"]), point)
			var candidate: Vector2 = point + (corrections[i] as Vector2).limit_length(budget * 0.15)
			if before.distance_to(point) <= budget + EPS:
				candidate = before + (candidate - before).limit_length(budget)
			var sector: int = local_sector(graph, craft)
			if sector >= 0 and sector_contains(graph, sector, point) and not sector_contains(graph, sector, candidate):
				var low: float = 0.0
				var high: float = 1.0
				for step_index in range(10):
					var fraction: float = (low + high) * 0.5
					if sector_contains(graph, sector, point.lerp(candidate, fraction)):
						low = fraction
					else:
						high = fraction
				candidate = point.lerp(candidate, low)
			craft["position"] = candidate
			if not craft["route"].is_empty():
				craft["leg"] = _lane_progress(graph["points"], craft)

static func _update_planet_blockades(state: Dictionary, graph: Dictionary) -> void:
	for system in state["planets"]:
		system["planet_blockaded"] = false
	for craft in state["ships"]:
		_ensure_position(graph["points"], craft)
		var node: int = local_sector(graph, craft)
		if node < 0 or node >= state["planets"].size():
			continue
		var system: Dictionary = state["planets"][node]
		var owner: int = int(system["owner"])
		if empires_hostile(state, owner, int(craft["owner"])):
			system["planet_blockaded"] = true

# First turn is immediate. Subsequent turns align to stable player slots
# within the existing strategic interval, independent of eliminated players.
static func _next_ai_slot(now: float, player: int) -> float:
	var phase: float = float(posmod(player - 1, 8)) * AI_INTERVAL / 8.0
	var next: float = floorf((now - phase) / AI_INTERVAL) * AI_INTERVAL + phase + AI_INTERVAL
	if next <= now + EPS:
		next += AI_INTERVAL
	return next

static func step(state: Dictionary, dt: float, profile: Dictionary = {}) -> void:
	var started: int = Time.get_ticks_usec() if not profile.is_empty() else 0
	_accrue_resident_taxes(state, dt)
	_pay_fleet_upkeep(state, dt)
	state["elapsed"] = float(state["elapsed"]) + dt
	if dt > 0.0:
		_check_unpaid_defections(state)
	var transfer_events: Dictionary = state.get("cargo_transfers", {})
	for key in transfer_events.keys():
		if float(state["elapsed"]) - float(transfer_events[key]["elapsed"]) > TRANSFER_EVENT_YEARS:
			transfer_events.erase(key)
	var combat_graph: Dictionary = military_graph(state)
	_sector_query_cache.clear()
	_sector_query_graph = combat_graph
	combat_graph.erase("travel_influence")
	combat_graph.erase("travel_permissions")
	_update_planet_blockades(state, combat_graph)
	for i in range((state["planets"] as Array).size()):
		_work_planet(state, i, dt)
	_refill_empire_fleets(state)
	_begin_hull_index(state)
	started = _profile_stage(profile, "Economy", started)
	# Decide treaties before constructing any relation-dependent route or
	# threat caches for this substep.
	_dispatch_ai_diplomacy(state)
	var teams: Array[int] = planet_teams(state)
	# Validate the static map and territory once per substep, not on each search.
	var cache: Dictionary = {"civilian_routes": _civilian_route_cache(state, teams)}
	var budgets: Array = []
	for field in state["map"].get("fields", []):
		budgets.append({"Metals": field_limit(field, "Metals") * dt, "Crystals": field_limit(field, "Crystals") * dt, ANTIMATTER: field_limit(field, ANTIMATTER) * dt})
	var ai_now: float = float(state["elapsed"])
	var ai_schedule: Dictionary = state.get("_ai_schedule", {})
	for player in state.get("ai_players", []).duplicate():
		if not state["ai_players"].has(player):
			continue
		if ai_now + EPS >= float(ai_schedule.get(player, 0.0)):
			_ai_turn(state, combat_graph, int(player))
			ai_schedule[player] = _next_ai_slot(ai_now, int(player))
	state["_ai_schedule"] = ai_schedule
	started = _profile_stage(profile, "AI / routing setup", started)
	for craft in state["ships"]:
		_ensure_position(combat_graph["points"] if craft.get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"] else state["map"]["points"], craft)
	_passive_regeneration(state, dt)
	_refresh_reward_defenses(state, dt)
	_prepare_withdrawals(state, combat_graph)
	_advance_unit_orders(state, combat_graph)
	_update_tactical_orders(state, combat_graph)
	var threat_index: Dictionary = {}
	_combat(state, combat_graph, dt, threat_index)
	combat_graph.erase("travel_influence")
	combat_graph.erase("travel_permissions")
	# Station destruction changes ownership during combat. Never use stale
	# allied routes or permit a delivery into the destroyed stockpile.
	var surviving_teams: Array[int] = planet_teams(state)
	if surviving_teams != teams:
		teams = surviving_teams
		cache = {"civilian_routes": _civilian_route_cache(state, teams)}
	_prepare_withdrawals(state, combat_graph)
	_update_salvage(state)
	var salvage_busy: Dictionary = _salvage_combat_busy(state)
	var salvage_cells: Dictionary = _salvage_cells(state.get("salvage", {}))
	var salvage_threats: Dictionary = _reuse_combat_threats(state, combat_graph, threat_index)
	var stage_receivers: Dictionary = {}
	var receiver_order: int = 0
	for craft in state["ships"]:
		if craft.get("kind", "") == "ship" and not bool(craft.get("rogue", false)):
			var owner: int = int(craft["owner"])
			if not stage_receivers.has(owner):
				stage_receivers[owner] = {}
			_spatial_insert(stage_receivers[owner], craft["position"], RESOURCE_HANDOFF_RANGE, [receiver_order, craft])
			receiver_order += 1
	# Passive handoff is independent of route and job. Evaluate all hulls before movement.
	for miner in state["ships"]:
		if miner.get("kind", "") == "miner" and not bool(miner.get("rogue", false)) and not salvage_busy.has(int(miner["id"])):
			var receivers: Array = _handoff_candidates(stage_receivers.get(int(miner["owner"]), {}), miner["position"]) if _cargo_total(miner) > EPS else []
			miner["_handoff_sent"] = _miner_handoff(state, combat_graph, miner, receivers, salvage_threats, dt)
	started = _profile_stage(profile, "Combat / repair", started)
	var fleets: Dictionary = {}
	for craft in state["ships"]:
		if craft.get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"]:
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
	_begin_ship_avoidance(combat_positions)
	_dispatch_explorers(state, combat_graph)
	var idle_targets: Dictionary = _idle_formation_targets(state, combat_graph)
	var coordinated: Dictionary = _coordinate_formations(state, combat_graph, dt)
	var service_refs: Dictionary = service_targets(state)
	var damaged_cells: Dictionary = _damaged_repair_cells(service_refs)
	started = _profile_stage(profile, "Formations / orders", started)
	var civilian_usec: int = 0
	var repaired_hulls: Dictionary = {}
	var repair_parked: Dictionary = {}
	var wander_candidates: Dictionary = {}
	for ship in (state["ships"] as Array).duplicate():
		var initial_position: Vector2 = ship["position"]
		if ship.get("kind", "") == "warp_gate" or bool(ship.get("rogue", false)):
			continue
		if ship.get("unit_order", {}).get("kind", "") == "warp_travel" and not bool(ship.get("retreating", false)):
			var previous_warp: float = float(ship.get("warp_ready", 0.0))
			_work_warp_order(state, combat_graph, ship, dt)
			if float(ship.get("warp_ready", 0.0)) > previous_warp:
				combat_positions[int(ship["id"])] = ship["position"]
			continue
		if ship.get("_handoff_delivery", false):
			ship.erase("_handoff_delivery")
			continue
		if ship.get("kind", "") == "colony_ship":
			var previous_food: float = float(ship.get("food_produced", 0.0))
			_grow_colony_cargo(ship, dt)
			var produced: float = float(ship.get("food_produced", 0.0)) - previous_food
			if produced > 0.0:
				var progress: Dictionary = objective_progress(state, int(ship["owner"]))
				progress["colony_food"] = float(progress.get("colony_food", 0.0)) + produced
		var salvage_ship_id: int = int(ship["id"])
		if bool(ship.get("retreating", false)) and armed(ship):
			ship.erase("repair_target")
			var before_hp: float = float(ship["hp"])
			_work_withdrawal(state, combat_graph, ship, dt)
			if float(ship["hp"]) > before_hp and ship["position"] == initial_position:
				repair_parked[salvage_ship_id] = true
			continue
		if bool(ship.get("holding", false)) and ship.has("hold_heading"):
			ship.erase("repair_target")
			_work_local_hold(combat_graph, ship, dt)
			continue
		var follow: Dictionary = ship.get("unit_order", {})
		var escort_far: bool = follow.get("kind", "") == "follow" and bool(follow.get("guard", false)) and (ship["position"] as Vector2).distance_to(service_refs.get(int(follow["target"]), {}).get("position", Vector2.INF)) > FOLLOW_DISTANCE * 2.0
		if (escort_far or not (ship.get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"] and _engaged(ship) and not bool(ship.get("holding", false)))) and _work_follow(state, combat_graph, ship, service_refs, dt):
			continue
		if ship.has("attack_order"):
			var ref: Dictionary = service_refs.get(int(ship["attack_order"]), {})
			if ref.is_empty() or not _hostile_hull(state, int(ship["owner"]), ref):
				_clear_tactical_order(ship)
				_finish_manual(ship)
			else:
				var point: Vector2 = ref["position"]
				var node: int = int(ref["node"]) if int(ref["node"]) >= 0 else _attack_destination(combat_graph, ref["entity"])
				if ship["kind"] in ["fighter", "scout", "cruiser", "destroyer"] and (ship["position"] as Vector2).distance_to(point) <= LASER_RANGE:
					_maneuver_fighter(ship, point, dt)
				elif node >= 0:
					_manual_travel(state, combat_graph, ship, node, point, dt, LASER_RANGE * 0.8)
				continue
		if _work_cargo_order(state, combat_graph, ship, service_refs, dt):
			continue
		if _work_launch_rally(state, ship, dt):
			continue
		var guard: Dictionary = ship.get("unit_order", {})
		if guard.get("kind", "") == "guard" and (not _engaged(ship) or not sector_contains(combat_graph, int(guard["target"]), ship["position"])):
			ship["guard_arrived"] = _manual_travel(state, combat_graph, ship, int(guard["target"]), guard["point"], dt, 8.0)
			continue
		if _work_local_move(combat_graph, ship, dt, state):
			continue
		if _work_salvage(state, combat_graph, ship, dt, salvage_busy.has(salvage_ship_id)):
			continue
		if _work_resource_stage(state, combat_graph, ship, teams, cache, salvage_threats, salvage_cells, salvage_busy, dt):
			continue
		# Each automatic job checks its own cooldown; explicit movement,
		# follow, cargo orders and emergency withdrawal already take priority.
		if ship.get("kind", "ship") == "miner" and (ship.has("repair_order") or not _engaged(ship) and int(ship.get("yard_target", -1)) == -1) and _work_miner_repair(state, combat_graph, ship, service_refs, dt, damaged_cells):
			if ship.has("repair_target") and dt > 0.0:
				var recipient: int = int(ship["repair_target"])
				if service_refs.get(recipient, {}).get("kind", "") == "ship":
					repaired_hulls[recipient] = true
			continue
		ship.erase("repair_target")
		if _work_opportunistic_salvage(state, combat_graph, ship, dt, salvage_busy, salvage_cells, coordinated.has(salvage_ship_id), salvage_threats):
			continue
		if bool(ship.get("holding", false)) and not bool(ship.get("retreating", false)):
			_work_local_hold(combat_graph, ship, dt)
			continue
		if _work_science(state, combat_graph, ship, dt):
			continue
		if ship.get("kind", "ship") == "colony_ship":
			if _begin_farm_delivery(state, ship):
				_work_salvage(state, combat_graph, ship, dt)
				continue
			if _work_colony(state, ship, dt):
				_remove_indexed_hull(state, ship)
				continue
		elif ship.get("kind", "ship") == "ship":
			var before: int = Time.get_ticks_usec() if not profile.is_empty() else 0
			_work_ship(state, ship, teams, cache, dt)
			if _is_idle_ship(ship) and ship.get("order_queue", []).is_empty() and _cargo_total(ship) <= EPS and autocast_ready(state, ship, "trade") and float(state["elapsed"]) >= float(ship.get("next_resource_stage_search", 0.0)):
				ship["next_resource_stage_search"] = _next_search_slot(float(state["elapsed"]), int(ship["id"]), RESOURCE_STAGE_SEARCH_YEARS)
				_choose_resource_stage(state, combat_graph, ship, teams, cache, salvage_threats, salvage_cells)
			if not profile.is_empty():
				civilian_usec += Time.get_ticks_usec() - before
		elif ship.get("kind", "ship") == "miner":
			var before: int = Time.get_ticks_usec() if not profile.is_empty() else 0
			_work_miner(state, ship, teams, cache, budgets, dt)
			if not profile.is_empty():
				civilian_usec += Time.get_ticks_usec() - before
		elif ship.get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"]:
			var target_id: int = int(ship.get("combat_target", -1))
			var pursuit_id: int = int(ship.get("pursuit_target", -1))
			if bool(ship.get("retreating", false)):
				_work_withdrawal(state, combat_graph, ship, dt)
			elif bool(ship.get("holding", false)):
				ship["navigation_target"] = ship["position"]
			elif bool(ship.get("attack_local", false)) and combat_positions.has(int(ship.get("attack_order", -1))):
				var opponent: Vector2 = combat_positions[int(ship["attack_order"])]
				if (ship["position"] as Vector2).distance_to(opponent) <= LASER_RANGE:
					_maneuver_fighter(ship, opponent, dt)
				else:
					_navigate(ship, opponent, ship_speed(str(ship.get("kind", "ship"))) * dt)
			elif coordinated.has(int(ship["id"])):
				pass # Already moved as a group this tick.
			elif combat_positions.has(pursuit_id):
				_pursue_fighter(ship, combat_positions[pursuit_id], dt)
				ship["leg"] = _lane_progress(combat_graph["points"], ship)
			elif combat_positions.has(target_id) and not bool(ship.get("passing_fire", false)):
				ship["pursuit_target"] = -1
				ship["pursuit_left"] = 0.0
				_maneuver_fighter(ship, combat_positions[target_id], dt)
				ship["leg"] = _lane_progress(combat_graph["points"], ship)
			else:
				if not bool(ship.get("passing_fire", false)):
					ship["combat_target"] = -1
				ship["pursuit_target"] = -1
				ship["pursuit_left"] = 0.0
				var patrol_point: Vector2 = (ship["patrol_start_point"] if ship["patrol_returning"] else ship["patrol_end_point"]) if ship.has("patrol_from") else Vector2.INF
				if patrol_point.is_finite():
					ship["route"] = []
					ship["leg"] = 0.0
					_navigate(ship, patrol_point, ship_speed(str(ship.get("kind", "ship"))) * dt)
					ship["patrol_arrived"] = (ship["position"] as Vector2).distance_to(patrol_point) <= EPS
					if ship["patrol_arrived"]:
						ship["at"] = int(ship["patrol_from"] if ship["patrol_returning"] else ship["patrol_to"])
				elif not (ship["route"] as Array).is_empty():
					_move_formation(combat_graph, ship, dt)
		var ship_id: int = int(ship["id"])
		# Only use the idle budget if the ship started and finished its
		# work idle and did not already move this tick.
		if idle_targets.has(ship_id) and _is_idle_ship(ship) and autocast_ready(state, ship, "wander") and not coordinated.has(ship_id) and ship["position"] == initial_position:
			wander_candidates[ship_id] = true
	# Resolve wandering after every Harvester has had a chance to repair.
	# This avoids dependence on whether the recipient precedes its healer
	# in the fleet array. Explicit movement and other work remain legal.
	for ship in state["ships"]:
		var id: int = int(ship["id"])
		if repaired_hulls.has(id) and _is_idle_ship(ship) and not _unit_order_running(ship) and ship["position"] == combat_positions.get(id):
			repair_parked[id] = true
		if repair_parked.has(id):
			ship["navigation_target"] = ship["position"]
		elif wander_candidates.has(id):
			_navigate(ship, idle_targets[id], ship_speed(str(ship.get("kind", "ship"))) * dt)
		ship.erase("_handoff_sent")
		_mark_sector_arrival(state, ship)
		if ship.has("auto_cooldown_until") and float(ship["auto_cooldown_until"]) <= float(state["elapsed"]):
			ship.erase("auto_cooldown_until")
		if ship.has("arrival_wait_until") and arrival_wait_remaining(state, ship) <= EPS and ship.get("unit_order", {}).get("kind", "") != "sector":
			ship.erase("arrival_wait_until")
		if ship.has("wander_cooldown_override") and autocast_remaining(state, ship) <= EPS and not _unit_order_running(ship):
			ship.erase("wander_cooldown_override")
	avoidance_cells.clear()
	_separate_ships(state, combat_graph, combat_positions, dt, repair_parked)
	if dt > 0.0:
		_resolve_ship_contacts(state, combat_graph, combat_positions, dt, repair_parked)
	if not profile.is_empty():
		var now: int = Time.get_ticks_usec()
		profile["Civilian logistics"] = int(profile.get("Civilian logistics", 0)) + civilian_usec
		profile["Other movement"] = int(profile.get("Other movement", 0)) + maxi(0, now - started - civilian_usec)
		started = now
	_sync_operations(state)
	update_exploration(state)
	_update_objectives(state)
	_profile_stage(profile, "Conquest / exploration", started)
	_indexed_state = {}
	_hulls_by_id.clear()
	combat_graph.erase("travel_influence")
	combat_graph.erase("travel_permissions")
	_sector_query_graph = {}
	_sector_query_cache.clear()

static func objective_progress(state: Dictionary, player: int) -> Dictionary:
	if not state.has("objectives"):
		state["objectives"] = {}
	var all_progress: Dictionary = state["objectives"]
	if not all_progress.has(player):
		all_progress[player] = {"colonies": {}, "metals": 0.0, "population": 0.0, "completed": {}, "points": {"economic": 0, "military": 0, "tech": 0}, "offers": {}, "active_goals": {"economic": "colony_ships", "military": "military_built"}, "goal_refresh": {}, "goal_draws": {}}
	return all_progress[player]

static func embarked_construction_population(planet: Dictionary) -> float:
	var total: float = 0.0
	for job in planet.get("queue", []):
		if SHIP_KINDS.has(job["kind"]):
			total += float(job.get("population_allocated", 0.0))
	return total

static func _update_objectives(state: Dictionary) -> void:
	# Aggregate once for all empires; cargo and crew count exactly once.
	var populations: Dictionary = {}
	var metals: Dictionary = {}
	for system in state["planets"]:
		var player: int = int(system["owner"])
		if player > 0:
			populations[player] = float(populations.get(player, 0.0)) + float(system["population"]) + embarked_construction_population(system)
			metals[player] = float(metals.get(player, 0.0)) + float(system["stock"].get("Metals", 0.0))
	for ship in state["ships"]:
		var player: int = int(ship["owner"])
		if player > 0:
			populations[player] = float(populations.get(player, 0.0)) + float(ship.get("crew", 0.0))
			metals[player] = float(metals.get(player, 0.0)) + float(ship.get("cargo", {}).get("Metals", 0.0))
	var first: Dictionary = state.get("objective_first", {})
	var events: Array = state.get("objective_events", [])
	var now: float = float(state.get("objective_clock", state["elapsed"]))
	for player in state["teams"]:
		if state.get("eliminated", []).has(player):
			continue
		var progress: Dictionary = objective_progress(state, int(player))
		progress["population"] = float(populations.get(player, 0.0))
		progress["metals"] = float(metals.get(player, 0.0))
		_assign_category_objectives(state, int(player), progress)
		for objective in active_objectives(progress, float(state.get("objective_clock", 0.0))):
			var key: String = objective["id"]
			if not key.is_empty() and reward_points(progress, str(objective["track"])) == 0 and float(objective["value"]) >= float(objective["target"]) - EPS and not progress["completed"].has(key):
				progress["completed"][key] = float(state.get("objective_clock", 0.0))
				if not first.has(key):
					first[key] = now
				var winner: bool = float(first[key]) == now
				var award: int = 1
				var category: String = objective_category(key)
				progress["points"][category] = reward_points(progress, category) + award
				var earned: Dictionary = progress.get("earned_points", {})
				earned[category] = int(earned.get(category, 0)) + award
				progress["earned_points"] = earned
				events.append({"player": player, "objective": key, "first": winner, "award": award, "elapsed": now})
				if events.size() > 64:
					events.pop_front()
	state["objective_first"] = first
	state["objective_events"] = events
	for player in state["teams"]:
		for category in REWARD_CATEGORIES:
			_fill_reward_offer(state, int(player), category)
			if state.get("ai_players", []).has(player):
				var progress: Dictionary = objective_progress(state, int(player))
				var offer: Array = reward_offer(progress, category)
				if not offer.is_empty():
					acquire_reward(state, int(player), str(offer[0]), reward_generation(progress), category)

static func specialization_grade(system: Dictionary, resource: String) -> int:
	if not has_planets(system):
		return -2
	var factor: float = float(system["bonuses"].get(resource, 1.0))
	if MINED_RESOURCES.has(resource):
		factor *= float(system["abundance"].get(resource, 0.0))
	if factor < 0.5:
		return -2
	if factor < 0.9:
		return -1
	if factor >= 1.5:
		return 2
	if factor >= 1.1:
		return 1
	return 0

const REWARD_CATEGORIES = ["economic", "military", "tech"]
const UNIQUE_CONQUEST_REWARDS = ["cloak", "shield_3", "warp_gate", "crystals"]
const CONQUEST_REWARDS = {
	"industry": ["Industrial Revolution", "+50% planetary Metals output", "", "economic", "Metals"],
	"crystals": ["Crystalline Synthesis", "+100% Incubator output", "+15% civilian Metals demand", "economic", "Crystals"],
	"agriculture": ["Agricultural Revolution", "+50% planetary Organics output", "", "economic", "Organics"],
	"population": ["Population Boom", "+50% terrestrial growth ceiling", "", "general", "habitation"],
	"storage": ["Megastructures", "+100% station storage capacity", "", "general", "warehouse"],
	"shield_1": ["Shields 1", "Military +30% shield HP; stations +50%.", "Military construction: extra Crystals (20% of base Metals).", "military", "guard"],
	"shield_2": ["Shields 2", "Military +60% shield HP; stations +100%.", "Military construction: extra Crystals (40% of base Metals).", "military", "guard"],
	"shield_3": ["Shields 3", "Military +90% shield HP; stations +150%.", "Military construction: extra Crystals (60% of base Metals).", "military", "guard"],
	"armor": ["Reinforced Armor", "Military hulls take 15% less hull damage.", "Military construction: +15% Metals.", "military", "reinforced_plating"],
	"dyson_sphere": ["Dyson Sphere", "Unlock a stellar megastructure: all local ship material costs -50%.", "20kt Metals and 10kt Crystals per sector.", "tech", "dyson_sphere"],
	"warp_gate": ["Warp Gates", "Deploy a science vessel as a gate; link owned gates for rapid travel.", "Consumes 1 antimatter per gate.", "tech", "transform"],
	"cloak": ["Cloaking Field", "Scouts hide outside 250-unit enemy detection. Firing reveals them for 5 s.", "Replaces Scout armor/shields; extra Crystals (60% of base Metals).", "military", "auto_wander"],
	"rank_metals": ["Precision Refining", "+5% base planetary Metals output per rank.", "", "economic", "Metals"],
	"rank_food": ["Cultivation", "+5% base planetary Organics output per rank.", "", "economic", "Organics"],
	"rank_growth": ["Medical Research", "+5% base terrestrial growth ceiling per rank.", "", "economic", "habitation"],
	"rank_orbital": ["Orbital Agriculture", "+5% base orbital food output per rank.", "", "economic", "Organics"],
	"rank_storage": ["Expanded Warehouses", "+5% base storage capacity per rank.", "", "general", "warehouse"],
	"rank_housing": ["Habitat Engineering", "+5% base terrestrial housing capacity per rank.", "", "general", "habitation"],
	"rank_upkeep": ["Material Efficiency", "+3% civilian Metals efficiency per rank.", "", "general", "Metals"],
	"rank_crystals": ["Incubator Research", "+5% base planetary Crystals output per rank.", "", "tech", "Crystals"],
	"rank_science": ["Scientific Fabrication", "+3% science ship Metals cost efficiency per rank.", "", "tech", "science_ship"],
	"rank_civilian": ["Civilian Fabrication", "+3% civilian ship Metals cost efficiency per rank.", "", "tech", "ship"],
	"rank_damage": ["Weapons Calibration", "+2% military weapon damage per rank.", "", "military", "attack"],
	"rank_armor": ["Hull Materials", "+2% military hull damage efficiency per rank.", "Does not affect cloaked Scouts.", "military", "reinforced_plating"],
	"rank_military_metal": ["Fleet Fabrication", "+3% military Metals cost efficiency per rank.", "", "military", "Metals"],
	"rank_military_crystal": ["Crystal Engineering", "+3% military Crystals cost efficiency per rank.", "", "military", "Crystals"]
}

static func reward_repeatable(key: String) -> bool:
	return key.begins_with("rank_") and CONQUEST_REWARDS.has(key)

static func reward_rank(rewards: Array, key: String) -> int:
	return rewards.count(key)

static func _rank_factor(system: Dictionary, key: String, step: float) -> float:
	return 1.0 + step * reward_rank(system.get("conquest_rewards", []), key)

static func objective_category(key: String) -> String:
	var spec: Array = objective_spec(key)
	return str(spec[0]) if not spec.is_empty() else "economic"

static func reward_points(progress: Dictionary, category: String) -> int:
	return int(progress.get("points", {}).get(category, 0))

static func lifetime_reward_points(progress: Dictionary, category: String) -> int:
	return int(progress.get("earned_points", {}).get(category, 0))

static func reward_offer(progress: Dictionary, category: String) -> Array:
	return progress.get("offers", {}).get(category, [])

static func reward_is_unique(key: String) -> bool:
	return UNIQUE_CONQUEST_REWARDS.has(key)

static func reward_generation(progress: Dictionary) -> int:
	return int(progress.get("draft_generation", progress.get("rewards", []).size()))

static func reward_available(state: Dictionary, key: String) -> bool:
	return not reward_is_unique(key) or not state.get("unique_reward_claims", {}).has(key)

static func has_reward(system: Dictionary, key: String) -> bool:
	return system.get("conquest_rewards", []).has(key)

static func reward_eligible(rewards: Array, key: String, category: String) -> bool:
	if not CONQUEST_REWARDS.has(key) or (rewards.has(key) and not reward_repeatable(key)):
		return false
	var pool: String = CONQUEST_REWARDS[key][3]
	if pool != category and pool != "general":
		return false
	if key == "dyson_sphere":
		return rewards.has("warp_gate") or rewards.count("rank_crystals") + rewards.count("rank_science") + rewards.count("rank_civilian") >= 3
	if key == "shield_2":
		return rewards.has("shield_1")
	if key == "shield_3":
		return rewards.has("shield_2")
	return true

static func _fill_reward_offer(state: Dictionary, player: int, category: String, excluded: String = "") -> void:
	var progress: Dictionary = objective_progress(state, player)
	if not REWARD_CATEGORIES.has(category) or reward_points(progress, category) < 1 or not reward_offer(progress, category).is_empty():
		return
	var available: Array = []
	var repeatable: Array = []
	for key in CONQUEST_REWARDS:
		if key == excluded or not reward_available(state, key) or not reward_eligible(progress.get("rewards", []), key, category):
			continue
		if reward_repeatable(key):
			repeatable.append(key)
		else:
			available.append(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state["map"]["seed"]) + player * 7919 + reward_generation(progress) * 104729 + REWARD_CATEGORIES.find(category) * 15485863
	var offer: Array = []
	# Reserve one slot for incremental research from the start.
	while not available.is_empty() and offer.size() < 2:
		offer.append(available.pop_at(rng.randi_range(0, available.size() - 1)))
	while not repeatable.is_empty() and offer.size() < 3:
		offer.append(repeatable.pop_at(rng.randi_range(0, repeatable.size() - 1)))
	progress["offers"][category] = offer

static func acquire_reward(state: Dictionary, player: int, key: String, generation: int, category: String) -> bool:
	if not state["teams"].has(player) or not REWARD_CATEGORIES.has(category):
		return false
	var progress: Dictionary = objective_progress(state, player)
	var rewards: Array = progress.get("rewards", [])
	if generation != reward_generation(progress) or reward_points(progress, category) < 1 or not reward_offer(progress, category).has(key) or not reward_eligible(rewards, key, category) or not reward_available(state, key):
		return false
	if reward_is_unique(key):
		var claims: Dictionary = state.get("unique_reward_claims", {})
		claims[key] = player
		state["unique_reward_claims"] = claims
		var events: Array = state.get("objective_events", [])
		events.append({"player": player, "reward": key, "elapsed": float(state.get("objective_clock", 0.0))})
		if events.size() > 64:
			events.pop_front()
		state["objective_events"] = events
	progress["draft_generation"] = generation + 1
	rewards.append(key)
	progress["rewards"] = rewards
	progress["points"][category] = reward_points(progress, category) - 1
	progress["offers"][category] = []
	for system in state["planets"]:
		if int(system["owner"]) == player:
			system["conquest_rewards"] = rewards.duplicate()
	# Shared rewards cannot survive in another category's existing draft.
	for other in REWARD_CATEGORIES:
		if reward_offer(progress, other).has(key):
			progress["offers"][other] = []
		_fill_reward_offer(state, player, other, key)
	# First authority-accepted purchase permanently reserves a unique reward.
	# Invalidate every competing draft containing it, even when paused.
	if reward_is_unique(key):
		for rival in state.get("objectives", {}):
			if int(rival) == player:
				continue
			var rival_progress: Dictionary = state["objectives"][rival]
			var affected: Array = []
			for rival_category in REWARD_CATEGORIES:
				if reward_offer(rival_progress, rival_category).has(key):
					rival_progress["offers"][rival_category] = []
					affected.append(rival_category)
			if affected.is_empty():
				continue
			rival_progress["draft_generation"] = reward_generation(rival_progress) + 1
			for rival_category in affected:
				_fill_reward_offer(state, int(rival), rival_category)
	# Apply a newly acquired defense immediately, even while paused.
	if key.begins_with("shield_") or key in ["armor", "cloak", "rank_damage", "rank_armor"]:
		_refresh_reward_defenses(state, 0.0)
	return true

const WARP_GATE_HP: float = 10000.0
const WARP_RANGE: float = 180.0
const WARP_COOLDOWN: float = 10.0

static func warp_gate(state: Dictionary, owner: int, id: int) -> Dictionary:
	if id < 0:
		return {}
	var gate: Dictionary = service_targets(state, id).get(id, {}).get("entity", {})
	return gate if gate.get("kind", "") == "warp_gate" and int(gate.get("owner", -1)) == owner and float(gate.get("hp", 0.0)) > EPS else {}

static func warp_gate_choices(state: Dictionary, owner: int, id: int) -> Array[int]:
	var result: Array[int] = []
	for candidate in state["ships"]:
		if candidate.get("kind", "") == "warp_gate" and int(candidate["owner"]) == owner and int(candidate["id"]) != id and float(candidate.get("hp", 0.0)) > EPS:
			result.append(int(candidate["id"]))
	result.sort()
	return result

static func can_build_warp_gate(state: Dictionary, graph: Dictionary, ship: Dictionary) -> bool:
	if ship.get("kind", "") != "science_ship" or float(ship.get("cargo", {}).get(ANTIMATTER, 0.0)) < 1.0 - EPS:
		return false
	var owner: int = int(ship["owner"])
	if not can_pay_credits(state, owner, WARP_GATE_CREDIT_COST):
		return false
	if not state.get("objectives", {}).get(owner, {}).get("rewards", []).has("warp_gate"):
		return false
	var node: int = sector_at(graph, ship["position"], military_pois(state, owner))
	if node < 0 or node >= state["planets"].size() or int(state["planets"][node]["owner"]) != owner or not has_station(state["planets"][node]):
		return false
	for other in state["ships"]:
		if other.get("kind", "") == "warp_gate" and int(other["owner"]) == owner and int(other["at"]) == node:
			return false
	return true

static func build_warp_gate(state: Dictionary, graph: Dictionary, ship: Dictionary) -> bool:
	if not can_build_warp_gate(state, graph, ship):
		return false
	var owner: int = int(ship["owner"])
	var id: int = int(ship["id"])
	var position: Vector2 = ship["position"]
	var node: int = sector_at(graph, position, military_pois(state, owner))
	var choices: Array[int] = warp_gate_choices(state, owner, id)
	if not _pay_credits(state, owner, WARP_GATE_CREDIT_COST):
		return false
	# Preserve the existing stable combat/replication ID; replace all mobile orders.
	var crew: float = float(ship.get("crew", 0.0))
	ship.clear()
	ship.merge({"id": id, "kind": "warp_gate", "owner": owner, "origin": node, "at": node, "position": position, "heading": Vector2.UP,
		"navigation_target": position, "route": [], "leg": 0.0, "source": -1, "dest": -1, "hp": WARP_GATE_HP, "crew": crew,
		"cargo": empty_stock(), "field": -1, "mining_mode": "idle", "holding": true, "hold_position": position, "hold_heading": Vector2.UP, "hold_sector": node,
		"warp_destination": choices[0] if not choices.is_empty() else -1}, true)
	for other_id in choices:
		var other: Dictionary = warp_gate(state, owner, other_id)
		if int(other.get("warp_destination", -1)) < 0:
			other["warp_destination"] = id
	return true

static func set_warp_destination(state: Dictionary, owner: int, source: int, destination: int) -> bool:
	var gate: Dictionary = warp_gate(state, owner, source)
	if gate.is_empty() or source == destination or (destination != -1 and warp_gate(state, owner, destination).is_empty()):
		return false
	gate["warp_destination"] = destination
	return true

static func _warp_order_valid(state: Dictionary, ship: Dictionary, source: int) -> bool:
	var owner: int = int(ship["owner"])
	var gate: Dictionary = warp_gate(state, owner, source)
	return ship.get("kind", "") != "warp_gate" and not bool(ship.get("retreating", false)) and not gate.is_empty() and not warp_gate(state, owner, int(gate.get("warp_destination", -1))).is_empty()

static func _work_warp_order(state: Dictionary, graph: Dictionary, ship: Dictionary, dt: float) -> bool:
	var order: Dictionary = ship.get("unit_order", {})
	if order.get("kind", "") != "warp_travel":
		return false
	var source: int = int(order["target"])
	if not _warp_order_valid(state, ship, source):
		ship.erase("unit_order")
		_finish_manual(ship)
		return true
	var owner: int = int(ship["owner"])
	var gate: Dictionary = warp_gate(state, owner, source)
	var destination: Dictionary = warp_gate(state, owner, int(gate["warp_destination"]))
	var point: Vector2 = gate["position"]
	if (ship["position"] as Vector2).distance_to(point) > WARP_RANGE:
		_manual_travel(state, graph, ship, int(gate["at"]), point, dt, WARP_RANGE * 0.8)
		return true
	if float(state["elapsed"]) < float(ship.get("warp_ready", 0.0)):
		ship["navigation_target"] = ship["position"]
		return true
	var exit: Vector2 = destination["position"]
	var offset: Vector2 = Vector2.from_angle(float(int(ship["id"]) % 24) * TAU / 24.0) * 60.0
	var node: int = int(destination["at"])
	if sector_contains(graph, node, exit + offset):
		exit += offset
	ship["position"] = exit
	ship["navigation_target"] = exit
	ship["at"] = node
	ship["warp_ready"] = float(state["elapsed"]) + WARP_COOLDOWN
	ship.erase("unit_order")
	_finish_manual(ship)
	return true

static func shield_tier(rewards: Array) -> int:
	for level in range(3, 0, -1):
		if rewards.has("shield_%d" % level):
			return level
	return 0

static func military_hull(kind: String) -> bool:
	return kind in ["scout", "fighter", "cruiser", "destroyer"]

static func construction_cost(p: Dictionary, kind: String, level: int) -> Dictionary:
	var cost: Dictionary = _construction_cost_before_dyson(p, kind, level)
	if SHIP_KINDS.has(kind) and bool(p.get("station", {}).get("dyson_sphere", false)):
		for resource in cost:
			cost[resource] = float(cost[resource]) * 0.5
	return cost

static func _construction_cost_before_dyson(p: Dictionary, kind: String, level: int) -> Dictionary:
	var cost: Dictionary = _cost(kind, level)
	if military_hull(kind):
		var rewards: Array = p.get("conquest_rewards", [])
		var metal: float = float(cost.get("Metals", 0.0))
		if kind == "scout" and rewards.has("cloak"):
			cost["Crystals"] = float(cost.get("Crystals", 0.0)) + ceilf(metal * 0.15 * CRYSTAL_COST_MULTIPLIER)
		else:
			var tier: int = shield_tier(rewards)
			if tier > 0:
				cost["Crystals"] = float(cost.get("Crystals", 0.0)) + ceilf(metal * 0.05 * tier * CRYSTAL_COST_MULTIPLIER)
			if rewards.has("armor"):
				cost["Metals"] = ceilf(metal * 1.15)
		for resource in ["Metals", "Crystals"]:
			if cost.has(resource):
				cost[resource] = ceilf(float(cost[resource]) / _rank_factor(p, "rank_military_metal" if resource == "Metals" else "rank_military_crystal", 0.03))
		return cost
	if kind in ["ship", "miner", "colony_ship", "science_ship"] and cost.has("Metals"):
		var efficiency: float = _rank_factor(p, "rank_civilian", 0.03)
		if kind == "science_ship":
			efficiency += 0.03 * reward_rank(p.get("conquest_rewards", []), "rank_science")
		cost["Metals"] = ceilf(float(cost["Metals"]) / efficiency)
	return cost

static func _update_shield(entity: Dictionary, maximum: float, now: float, dt: float) -> void:
	var previous: float = float(entity.get("shield_max", 0.0))
	if maximum <= 0.0:
		entity.erase("shield")
		entity.erase("shield_max")
		entity.erase("shield_hit")
		return
	entity["shield_max"] = maximum
	var current: float = minf(maximum, float(entity.get("shield", 0.0)) + maxf(0.0, maximum - previous))
	if now - float(entity.get("shield_hit", -INF)) >= 5.0:
		current = minf(maximum, current + maximum * 0.05 * dt)
	entity["shield"] = current

static func _refresh_reward_defenses(state: Dictionary, dt: float) -> void:
	var now: float = float(state["elapsed"])
	var levels: Dictionary = {}
	var armors: Dictionary = {}
	var damage_factors: Dictionary = {}
	var cloaks: Dictionary = {}
	for player in state["teams"]:
		var rewards: Array = state.get("objectives", {}).get(player, {}).get("rewards", [])
		levels[player] = shield_tier(rewards)
		armors[player] = 1.0 - (0.85 if rewards.has("armor") else 1.0) / (1.0 + 0.02 * reward_rank(rewards, "rank_armor"))
		damage_factors[player] = 1.0 + 0.02 * reward_rank(rewards, "rank_damage")
		cloaks[player] = rewards.has("cloak")
	if not levels.values().any(func(level: int) -> bool: return level > 0) and not armors.values().any(func(value: float) -> bool: return value > 0.0) and not damage_factors.values().any(func(value: float) -> bool: return value > 1.0) and not cloaks.values().has(true):
		return
	for ship in state["ships"]:
		if not military_hull(str(ship["kind"])):
			continue
		var owner: int = int(ship["owner"])
		var damage_factor: float = float(damage_factors.get(owner, 1.0))
		if damage_factor > 1.0:
			ship["reward_damage_multiplier"] = damage_factor
		else:
			ship.erase("reward_damage_multiplier")
		if ship["kind"] == "scout" and bool(cloaks.get(owner, false)):
			ship["cloak_equipped"] = true
			ship["cloaked"] = now >= float(ship.get("cloak_reveal_until", 0.0))
			if ship.has("shield_max"):
				_update_shield(ship, 0.0, now, dt)
			ship.erase("armor")
			continue
		var tier: int = int(levels.get(owner, 0))
		if tier > 0 or ship.has("shield_max"):
			_update_shield(ship, ship_max_hp(str(ship["kind"])) * 0.3 * tier, now, dt)
		if float(armors.get(owner, 0.0)) > 0.0:
			ship["armor"] = float(armors[owner])
		else:
			ship.erase("armor")
	for system in state["planets"]:
		if has_station(system):
			var tier: int = int(levels.get(int(system["owner"]), 0))
			if tier > 0 or system["station"].has("shield_max"):
				_update_shield(system["station"], station_max_hp(system) * 0.5 * tier, now, dt)

const CLOAK_DETECTION_RANGE: float = 250.0
const CLOAK_REVEAL_TIME: float = 5.0

static func ship_visible_to_team(state: Dictionary, ship: Dictionary, team: int) -> bool:
	if not bool(ship.get("cloaked", false)):
		return true
	if _shares_group_vision(state, team, _combat_group(state, int(ship.get("owner", -1)))):
		return true
	for detector in ship.get("cloak_detected", []):
		if _shares_group_vision(state, team, int(detector)):
			return true
	return false

static func _detect_cloaked(state: Dictionary, ships: Array, cells: Dictionary, positions: Dictionary, team_by_id: Dictionary) -> void:
	var reach: int = ceili(CLOAK_DETECTION_RANGE / LASER_RANGE)
	var range_squared: float = CLOAK_DETECTION_RANGE * CLOAK_DETECTION_RANGE
	for ship in ships:
		if not bool(ship.get("cloaked", false)):
			continue
		var id: int = int(ship["id"])
		var pos: Vector2 = positions[id]
		var team: int = int(team_by_id[id])
		var cell := Vector2i(floori(pos.x / LASER_RANGE), floori(pos.y / LASER_RANGE))
		var detected: Array[int] = []
		for x in range(-reach, reach + 1):
			for y in range(-reach, reach + 1):
				for sensor in cells.get(cell + Vector2i(x, y), []):
					var sensor_id: int = int(sensor["id"])
					var sensor_team: int = int(team_by_id[sensor_id])
					if sensor_team <= 0 or sensor_team == team or detected.has(sensor_team):
						continue
					if pos.distance_squared_to(positions[sensor_id]) <= range_squared:
						detected.append(sensor_team)
		ship["cloak_detected"] = detected

static func _effective_health(entity: Dictionary, maximum: float) -> float:
	return float(entity.get("shield", 0.0)) + float(entity.get("hp", maximum)) / (1.0 - float(entity.get("armor", 0.0)))

static func _apply_reward_damage(entity: Dictionary, maximum: float, amount: float, now: float) -> void:
	if entity.has("shield_max"):
		var absorbed: float = minf(amount, float(entity.get("shield", 0.0)))
		entity["shield"] = float(entity.get("shield", 0.0)) - absorbed
		entity["shield_hit"] = now
		amount -= absorbed
	entity["hp"] = maxf(0.0, float(entity.get("hp", maximum)) - amount * (1.0 - float(entity.get("armor", 0.0))))

const OBJECTIVE_REFRESH_SECONDS: float = 60.0
const OBJECTIVE_COMPLETE_SECONDS: float = 10.0
# category, lifetime/current metric, target, label, required prior objective
const OBJECTIVE_SPECS = {
	"colony_ships": ["economic", "colony_ships_built", 2, "Build 2 colony ships", ""],
	"colonies": ["economic", "colonies", 2, "Colonize 2 systems", "colony_ships"],
	"colonies_2": ["economic", "colonies", 4, "Colonize 4 systems", "colonies"],
	"colonies_3": ["economic", "colonies", 8, "Colonize 8 systems", "colonies_2"],
	"advanced_colonies": ["economic", "colonies", 12, "Colonize 12 systems", "colonies_3"],
	"colony_food": ["economic", "colony_food", 1000, "Produce 1kt colony ship food", ""],
	"colony_food_2": ["economic", "colony_food", 3000, "Produce 3kt colony ship food", "colony_food"],
	"metals": ["economic", "metals", 3000, "Have 3kt Metals", ""],
	"metals_2": ["economic", "metals", 6000, "Have 6kt Metals", "metals"],
	"metals_3": ["economic", "metals", 10000, "Have 10kt Metals", "metals_2"],
	"advanced_metals": ["economic", "metals", 20000, "Have 20kt Metals", "metals_3"],
	"population": ["economic", "population", 80000, "Reach 80k population", ""],
	"population_2": ["economic", "population", 200000, "Reach 200k population", "population"],
	"population_3": ["economic", "population", 500000, "Reach 500k population", "population_2"],
	"advanced_population": ["economic", "population", 1000000, "Reach 1M population", "population_3"],
	"military_built": ["military", "military_built", 5, "Build 5 military ships", ""],
	"military_built_2": ["military", "military_built", 15, "Build 15 military ships", "military_built"],
	"military_built_3": ["military", "military_built", 30, "Build 30 military ships", "military_built_2"],
	"enemy_ships": ["military", "enemy_ships_destroyed", 3, "Destroy 3 enemy ships", ""],
	"enemy_ships_2": ["military", "enemy_ships_destroyed", 10, "Destroy 10 enemy ships", "enemy_ships"],
	"enemy_ships_3": ["military", "enemy_ships_destroyed", 30, "Destroy 30 enemy ships", "enemy_ships_2"],
	"advanced_antimatter": ["tech", "antimatter_processed", 2, "Process 2 antimatter", ""],
	"antimatter_2": ["tech", "antimatter_processed", 4, "Process 4 antimatter", "advanced_antimatter"]
}

# category, first lifetime target, incremental step, label format, fixed prerequisite
const REPEAT_OBJECTIVES = {
	"colony_food": ["economic", 5000, 2000, "Produce %st colony ship food", "colony_food_2"],
	"colony_ships_built": ["economic", 4, 2, "Build %s colony ships", "colony_ships"],
	"produced_metals": ["economic", 5000, 3000, "Produce %st Metals", ""],
	"produced_organics": ["economic", 5000, 3000, "Produce %st Organics", ""],
	"logistics_built": ["economic", 5, 4, "Build %s logistics ships", ""],
	"military_built": ["military", 45, 15, "Build %s military ships", "military_built_3"],
	"enemy_ships_destroyed": ["military", 45, 15, "Destroy %s enemy ships", "enemy_ships_3"],
	"military_investment": ["military", 2500, 2000, "Build %st of base-metal military hulls", "military_built"],
	"capital_built": ["military", 3, 3, "Build %s capital ships", "military_built"],
	"fighters_built": ["military", 12, 8, "Build %s fighters", "military_built"],
	"antimatter_processed": ["tech", 6, 2, "Process %s antimatter", "antimatter_2"],
	"produced_crystals": ["tech", 150, 100, "Produce %st Crystals", ""],
	"science_built": ["tech", 2, 2, "Build %s science ships", ""],
	"infrastructure_built": ["tech", 8, 5, "Complete %s infrastructure projects", ""]
}

static func _repeat_objective_key(metric: String, tier: int) -> String:
	return "repeat:%s:%d" % [metric, tier]

static func objective_spec(key: String) -> Array:
	if OBJECTIVE_SPECS.has(key):
		return OBJECTIVE_SPECS[key]
	var parts: PackedStringArray = key.split(":")
	if parts.size() != 3 or parts[0] != "repeat" or not REPEAT_OBJECTIVES.has(parts[1]) or not parts[2].is_valid_int():
		return []
	var tier: int = int(parts[2])
	if tier < 1:
		return []
	var metric: String = parts[1]
	var spec: Array = REPEAT_OBJECTIVES[metric]
	# Arithmetic growth in the increment, rather than exponential targets.
	var increments: float = float(tier - 1)
	var target: int = int(spec[1]) + roundi(float(spec[2]) * (increments + 0.05 * increments * (increments - 1.0)))
	return [spec[0], metric, target, str(spec[3]) % objective_amount(float(target)), spec[4]]

static func objective_amount(value: float) -> String:
	if value >= 1000000.0:
		return ("%0.1f" % (value / 1000000.0)).trim_suffix(".0") + "M"
	if value >= 1000.0:
		return ("%0.1f" % (value / 1000.0)).trim_suffix(".0") + "k"
	return str(int(value))

static func objective_label(key: String) -> String:
	var spec: Array = objective_spec(key)
	return str(spec[3]) if not spec.is_empty() else "Objective"

static func objective_tech_unlocked(progress: Dictionary) -> bool:
	var count: int = 0
	for key in progress.get("completed", {}):
		if objective_category(str(key)) == "economic":
			count += 1
	return count >= 3 or int(progress.get("antimatter_processed", 0)) > 0 or reward_points(progress, "tech") > 0

static func _objective_row(progress: Dictionary, key: String) -> Dictionary:
	var spec: Array = objective_spec(key)
	var metric: String = spec[1]
	var target: int = spec[2]
	var value: float = float((progress.get("colonies", {}) as Dictionary).size()) if metric == "colonies" else float(progress.get(metric, 0))
	if progress.get("completed", {}).has(key):
		value = maxf(value, float(target))
	var counter: String = "%s / %s" % [objective_amount(minf(value, target)), objective_amount(target)]
	return {"id": key, "track": spec[0], "metric": metric, "target": target, "value": value, "label": spec[3], "counter": counter}

static func active_objectives(progress: Dictionary, _clock: float) -> Array:
	var result: Array = []
	var active: Dictionary = progress.get("active_goals", {"economic": "colony_ships", "military": "military_built"})
	for category in REWARD_CATEGORIES:
		if category == "tech" and not objective_tech_unlocked(progress):
			continue
		var key: String = str(active.get(category, ""))
		if not objective_spec(key).is_empty():
			result.append(_objective_row(progress, key))
		else:
			result.append({"id": "", "track": category, "target": 1, "value": 0, "label": "Preparing objective", "counter": ""})
	return result

static func _objective_target_met(progress: Dictionary, key: String) -> bool:
	var row: Dictionary = _objective_row(progress, key)
	return float(row["value"]) >= float(row["target"]) - EPS

static func _objective_prerequisite_met(progress: Dictionary, key: String) -> bool:
	return key.is_empty() or progress["completed"].has(key) or _objective_target_met(progress, key)

static func objective_candidates(progress: Dictionary, category: String, excluded: String = "") -> Array:
	var candidates: Array = []
	var completed: Dictionary = progress.get("completed", {})
	for key in OBJECTIVE_SPECS:
		var spec: Array = OBJECTIVE_SPECS[key]
		if spec[0] != category or key == excluded or completed.has(key) or _objective_target_met(progress, key):
			continue
		if _objective_prerequisite_met(progress, str(spec[4])):
			candidates.append(key)
	for metric in REPEAT_OBJECTIVES:
		var spec: Array = REPEAT_OBJECTIVES[metric]
		if spec[0] != category or not _objective_prerequisite_met(progress, str(spec[4])):
			continue
		if category == "economic" and str(spec[4]).is_empty() and not completed.keys().any(func(key) -> bool: return objective_category(str(key)) == "economic"):
			continue
		var tier: int = 1
		while completed.has(_repeat_objective_key(str(metric), tier)) or _objective_target_met(progress, _repeat_objective_key(str(metric), tier)):
			tier += 1
		var key: String = _repeat_objective_key(str(metric), tier)
		if key != excluded:
			candidates.append(key)
	return candidates

static func _draw_objective(state: Dictionary, player: int, progress: Dictionary, category: String, excluded: String = "") -> String:
	var candidates: Array = objective_candidates(progress, category, excluded)
	if candidates.is_empty():
		return ""
	var draws: Dictionary = progress.get("goal_draws", {})
	var draw: int = int(draws.get(category, 0)) + 1
	draws[category] = draw
	progress["goal_draws"] = draws
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state["map"]["seed"]) + player * 7919 + draw * 104729 + REWARD_CATEGORIES.find(category) * 15485863
	return str(candidates[rng.randi_range(0, candidates.size() - 1)])

static func _assign_category_objectives(state: Dictionary, player: int, progress: Dictionary) -> void:
	var active: Dictionary = progress.get("active_goals", {"economic": "colony_ships", "military": "military_built"})
	var completed: Dictionary = progress["completed"]
	for category in REWARD_CATEGORIES:
		if category == "tech" and not objective_tech_unlocked(progress):
			continue
		var current: String = str(active.get(category, ""))
		if reward_points(progress, category) > 0 or (not current.is_empty() and not completed.has(current)):
			continue
		# Continue the introductory colony chain before ordinary random goals.
		if current == "colony_ships" and not completed.has("colonies") and not _objective_target_met(progress, "colonies"):
			active[category] = "colonies"
		else:
			active[category] = _draw_objective(state, player, progress, category, current)
	progress["active_goals"] = active

static func objective_refresh_remaining(progress: Dictionary, category: String, clock: float) -> float:
	return maxf(0.0, float(progress.get("goal_refresh", {}).get(category, 0.0)) - clock)

static func refresh_objective(state: Dictionary, player: int, category: String, expected: String) -> bool:
	if not state["teams"].has(player) or state.get("eliminated", []).has(player) or not REWARD_CATEGORIES.has(category):
		return false
	var progress: Dictionary = objective_progress(state, player)
	if category == "tech" and not objective_tech_unlocked(progress):
		return false
	var active: Dictionary = progress["active_goals"]
	var current: String = str(active.get(category, ""))
	var clock: float = float(state.get("objective_clock", 0.0))
	if reward_points(progress, category) > 0 or current.is_empty() or current != expected or progress["completed"].has(current) or objective_refresh_remaining(progress, category, clock) > EPS:
		return false
	var next: String = _draw_objective(state, player, progress, category, current)
	if next.is_empty():
		return false
	active[category] = next
	progress["goal_refresh"][category] = clock + OBJECTIVE_REFRESH_SECONDS
	return true

const EMPIRE_TARGET_STEPS = [0, 1, 2, 3, 5, 7, 10, 15, 20, 30, 50, 75, 100, 150, 200, 300, 500]
const EMPIRE_TARGET_MAX: int = 500

static func empire_target_at_tick(position: float) -> int:
	var index: int = clampi(floori(position), 0, EMPIRE_TARGET_STEPS.size() - 2)
	return roundi(lerpf(float(EMPIRE_TARGET_STEPS[index]), float(EMPIRE_TARGET_STEPS[index + 1]), clampf(position - index, 0.0, 1.0)))

static func empire_target_tick(amount: int) -> float:
	var target: int = clampi(amount, 0, EMPIRE_TARGET_MAX)
	for index in range(EMPIRE_TARGET_STEPS.size() - 1):
		var low: int = EMPIRE_TARGET_STEPS[index]
		var high: int = EMPIRE_TARGET_STEPS[index + 1]
		if target <= high:
			return float(index) + float(target - low) / float(high - low)
	return float(EMPIRE_TARGET_STEPS.size() - 1)

static func empire_fleet_counts(state: Dictionary, player: int) -> Dictionary:
	var live: Dictionary = {}
	var queued: Dictionary = {}
	for ship in state["ships"]:
		if int(ship["owner"]) == player and SHIP_KINDS.has(ship["kind"]):
			var kind: String = str(ship["kind"])
			live[kind] = int(live.get(kind, 0)) + 1
	for p in state["planets"]:
		if int(p["owner"]) != player:
			continue
		for job in p["queue"]:
			var kind: String = str(job["kind"])
			if SHIP_KINDS.has(kind):
				queued[kind] = int(queued.get(kind, 0)) + 1
	return {"live": live, "queued": queued}

static func empire_ship_available(state: Dictionary, player: int, kind: String, counts: Dictionary) -> bool:
	if int(counts["live"].get(kind, 0)) + int(counts["queued"].get(kind, 0)) > 0:
		return true
	for p in state["planets"]:
		if int(p["owner"]) == player and (kind != "ship" or bool(p["home"])) and has_fitting_yard(p, kind):
			return true
	return false

static func set_empire_target(state: Dictionary, player: int, kind: String, amount: int) -> bool:
	if not state["teams"].has(player) or not SHIP_KINDS.has(kind) or amount < 0 or amount > EMPIRE_TARGET_MAX:
		return false
	if amount > 0 and not empire_ship_available(state, player, kind, empire_fleet_counts(state, player)):
		return false
	var targets: Dictionary = state.get("empire_targets", {})
	var fleet: Dictionary = targets.get(player, {})
	if amount == 0:
		fleet.erase(kind)
	else:
		fleet[kind] = amount
	targets[player] = fleet
	state["empire_targets"] = targets
	return true

static func _refill_empire_fleets(state: Dictionary) -> void:
	var now: float = float(state["elapsed"])
	if now + EPS < float(state.get("_next_empire_refill", 0.0)):
		return
	state["_next_empire_refill"] = now + 0.5
	for player in state.get("empire_targets", {}):
		var fleet: Dictionary = state["empire_targets"][player]
		if fleet.is_empty():
			continue
		var counts: Dictionary = empire_fleet_counts(state, int(player))
		for kind in fleet:
			var needed: int = int(fleet[kind]) - int(counts["live"].get(kind, 0)) - int(counts["queued"].get(kind, 0))
			if needed <= 0:
				continue
			for index in range(state["planets"].size()):
				var p: Dictionary = state["planets"][index]
				if int(p["owner"]) != int(player) or (kind == "ship" and not bool(p["home"])):
					continue
				for slot in range(p["yards"].size()):
					if not shipyard_operational(p, slot) or not yard_fits(p, slot, kind):
						continue
					if enqueue(state, int(player), index, kind, "", slot):
						p["queue"][-1]["empire_auto"] = true
						needed -= 1
					if needed <= 0:
						break
				if needed <= 0:
					break
