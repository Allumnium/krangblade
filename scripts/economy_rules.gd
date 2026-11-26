extends RefCounted
## Development-only balance configuration. No advanced recipes have been defined.
# Single source of truth for accepted authoritative time-speed values.
const AUTHORITY_MATCH_SPEEDS: Array[int] = [0, 1, 2, 5]
static var cached_civilian_routes: Dictionary = {}
static var cached_route_topology: Dictionary = {}
static var cached_military_graph: Dictionary = {}
static var cached_military_map: Dictionary = {}
static var cached_military_source: Dictionary = {}
# Ephemeral authoritative snapshot, active only during a movement substep.
static var avoidance_cells: Dictionary = {}
static var _avoidance_neighborhoods: Dictionary = {}
# Persistent derived storage; exposed only during the frozen movement phase.
static var _packed_avoidance_active: bool = false
const AVOIDANCE_NEIGHBORHOOD_LIMIT: int = 4096
static var _movement_fields: Array = []
static var _movement_field_source: Array = []
static var _movement_field_counts: Array[int] = []
static var _rock_cells: Dictionary = {}
# Ordered broad-phase candidates, valid until the rock index is rebuilt.
static var _rock_windows: Dictionary = {}
const ROCK_WINDOW_CACHE_LIMIT: int = 4096
# Exact route requests within a substep; never share mutable ship routes.
static var _rock_route_queries: Dictionary = {}
# Persistent certificates for empty rock corridors. Actual trajectory
# samples retain the old integrator's arithmetic at every substep.
static var _direct_rock_corridors: Dictionary = {}
# Derived fixed-step trajectories; never authoritative or serialized.
static var _direct_trajectories: Dictionary = {}
static var _trajectory_state: Dictionary = {}
static var _trajectory_roster: Array = []
static var _trajectory_tick: int = -1
const DIRECT_CORRIDOR_LOOKAHEAD: float = 768.0
const DIRECT_CORRIDOR_LIMIT: int = 10000
const DIRECT_WINDOW_STEPS: int = 8
const ROCK_CELL: float = 192.0
const ROCK_HARD_CLEARANCE: float = 12.0
const ROCK_PREFERRED_CLEARANCE: float = 26.0
const ROCK_ROUTE_CELL: float = 24.0
const ROCK_ROUTE_HALF: int = 24
const ROCK_ROUTE_NO_CELL: Vector2i = Vector2i(1073741824, 1073741824)
const ROCK_PLAN_LIMIT: int = 12
static var _rock_routes: Dictionary = {}
static var _rock_plan_budget: int = ROCK_PLAN_LIMIT
static var _rock_plan_tick: int = 0
const AVOIDANCE_LOOKAHEAD: float = 96.0
const AVOIDANCE_CELL: float = 128.0
const AVOIDANCE_BUCKET_LIMIT: int = 24
const MAP = preload("res://scripts/planet_map.gd")
const SYSTEM_GEOMETRY = preload("res://scripts/system_geometry.gd")
const COMBAT_KERNELS = preload("res://scripts/combat_kernels.gd")
const REPAIR_QUERIES = preload("res://scripts/repair_queries.gd")
const CONSTRUCTION_QUERIES = preload("res://scripts/construction_queries.gd")
const COMBAT_FRAME = preload("res://scripts/combat_frame.gd")
const STEP_FRAME = preload("res://scripts/step_frame.gd")
# Separate retained indexes at their original frozen snapshot boundaries.
static var _combat_index_state: Dictionary = {}
static var _combat_index_roster: Array = []
static var _combat_cell_index = STEP_FRAME.OrderedHullBuckets.new()
static var _combat_sector_index = STEP_FRAME.OrderedHullBuckets.new()
static var _contact_index_state: Dictionary = {}
static var _contact_index_roster: Array = []
static var _separation_index = STEP_FRAME.OrderedHullBuckets.new()
static var _contact_index = STEP_FRAME.OrderedHullBuckets.new()
static var _contact_batch = STEP_FRAME.ContactBatch.new()
static var _separation_batch = STEP_FRAME.SeparationBatch.new()
static var _avoidance_batch = STEP_FRAME.AvoidanceBatch.new()
static var _logistics_index_state: Dictionary = {}
static var _logistics_index_roster: Array = []
static var _handoff_indexes: Dictionary = {}
static var _rendezvous_indexes: Dictionary = {}
static var _salvage_index = STEP_FRAME.OrderedHullBuckets.new()
static var _repair_index_state: Dictionary = {}
static var _repair_index_roster: Array = []
static var _repair_index = REPAIR_QUERIES.PersistentDamagedIndex.new()
const SECTOR_GEOMETRY = preload("res://scripts/sector_geometry.gd")
const RESOURCES = ["Metals", "Organics", "Crystals"]
const EXTRACTED = ["Metals", "Crystals"]
const ACTIVE_PRODUCTION = RESOURCES
const STARTING_STOCK = {"Metals": 1650.0, "Organics": 300.0, "Crystals": 0.0}
const STARTING_GC: float = 5000.0
const RESIDENT_TAX_RATE: float = 0.005
# Derived slow-rate coefficients only. Live stock, residents and credits are
# still integrated at every authoritative substep.
const ECONOMY_RATE_INTERVAL: float = 0.4
static var _economy_rate_state: Dictionary = {}
static var _economy_rate_roster: Array = []
static var _economy_rate_entries: Dictionary = {}
static var _economy_wage_entries: Dictionary = {}
const ROGUE_GRACE_YEARS: float = 60.0
const ROGUE_CHECK_YEARS: float = 10.0
const ROGUE_CHANCE: float = 0.005
const PIRATE_OWNER: int = -1
const PIRATE_COMBAT_GROUP: int = 2147483000
const PIRATE_DECISION_YEARS: float = 3.0
const PIRATE_GROUP_RANGE: float = 900.0
const PIRATE_DEFENSE_RANGE: float = 1600.0
# Annual operating wages for completed mobile hulls; structures are exempt.
const SHIP_UPKEEP_GC = {"scout": 3.0, "miner": 9.0, "fighter": 15.0, "ship": 24.0, "colony_ship": 30.0, "science_ship": 30.0, "cruiser": 45.0, "destroyer": 105.0}
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
# Population is expressed in people (fractional values retained in simulation).
const HOME_POPULATION: float = 10000.0
const ORBITAL_HOUSING_POPULATION: float = 5000.0
const ECO_HOUSING_ORGANICS: float = 0.2
const ORBITAL_HOUSING_COST: Dictionary = {"Metals": 180.0}
const COLONY_POPULATION: float = 25000.0
const COLONY_TRANSFORM_TIME: float = 30.0
const COLONY_MIN_ORIGIN_POPULATION: float = 50000.0
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
const IDLE_TRADE_RETRY_YEARS: float = 0.4
const RESOURCE_QUEUE_SPACING: float = 80.0
const RESOURCE_PARTIAL_WAIT_YEARS: float = 8.0
const MINING_RENDEZVOUS_RANGE: float = 1600.0
const RESOURCE_MAX_IDLE_YEARS: float = 40.0
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
const BASE_METAL_CAPACITY: float = 4000.0
# Each tier is 3x the previous one, with each price fitting in the
# immediately preceding warehouse capacity.
const WAREHOUSE_COSTS = [
	{"Metals": 500.0},
	{"Metals": 1500.0},
	{"Metals": 4500.0}
]
const WAREHOUSE_POPULATIONS = [10000, 50000, 150000]
const SHIP_KINDS = ["ship", "colony_ship", "fighter", "miner", "science_ship", "scout", "cruiser", "destroyer"]
const SCIENCE_CAPACITY: float = 1.0
const SCIENCE_COLLECTION_YEARS: float = 30.0
const SHIPYARD_QUEUE_LIMIT = 4
const STATION_QUEUE_LIMIT = 4
const MAX_SHIPYARD_LEVEL = 3
const CREW_COSTS = {"ship": 4000.0, "colony_ship": COLONY_POPULATION, "fighter": 1000.0, "miner": 1500.0, "science_ship": 4000.0, "scout": 200.0, "cruiser": 3000.0, "destroyer": 8000.0}
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
# Float32 positions cannot close sub-unit gaps at large map coordinates, so the
# standoff-limited final step could otherwise stop just outside reach forever.
const FOLLOW_ARRIVAL_TOLERANCE: float = 0.5
const RALLY_ARRIVAL_RADIUS: float = SHIP_SEPARATION_RADIUS * 2.0
const SHIP_SEPARATION_STRENGTH: float = 0.15
const FORMATION_RADIUS: float = 105.0
const WANDER_RADIUS: float = 600.0
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
		planets.append(_generate_system(rng, i, ordered))
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
		_spawn_starting_fleets(state, planets, ordered)
	var credits: Dictionary = {}
	for id in ordered:
		credits[id] = STARTING_GC
	state["galactic_credits"] = credits
	state["starting_empires"] = ordered.duplicate()
	state["starting_survey"] = _starting_survey_regions(map_data, planets, ordered)
	_seed_starting_exploration(state)
	update_exploration(state)
	return state

static func _generate_system(rng: RandomNumberGenerator, i: int, ordered: Array[int]) -> Dictionary:
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
	return {"size_factor": lerpf(0.86, 1.18, clampf(richness / 6.8, 0.0, 1.0)), "advanced_bonus": advanced, "owner": owner, "home": home, "population": HOME_POPULATION + ORBITAL_HOUSING_POPULATION if home else 0.0, "eco_population": ORBITAL_HOUSING_POPULATION if home else 0.0, "population_velocity": 0.0, "farm_phase": float(i) * 2.399963, "farm_factor": 1.0, "stock": stock, "levels": levels,
		"abundance": abundance, "bonuses": bonuses, "thresholds": thresholds,
		"station": {"hp": STATION_HP, "weapons": [_new_pds(), _new_pds()]} if home else {}, "yards": yards, "queue": [], "continuous": {}, "buildings": {}, "warehouse_level": 0, "pds": {0: _new_pds()} if home else {}}

static func _spawn_starting_fleets(state: Dictionary, planets: Array, ordered: Array[int]) -> void:
	for index in range(ordered.size()):
		var slot: int = 0
		for kind in ["miner", "miner", "miner", "fighter", "fighter", "ship"]:
			var id: int = int(state["next_id"])
			state["next_id"] = id + 1
			var offset: Vector2 = Vector2.from_angle(float(index) * 2.399963 + float(slot) * TAU / 6.0) * (SHIP_CLEARANCE * 1.8)
			_finish(state, index, planets[index], {"id": id, "kind": kind, "population_allocated": CREW_COSTS[kind], "spawn_offset": offset, "starting_fleet": true})
			slot += 1

static func _starting_survey_regions(map_data: Dictionary, planets: Array, ordered: Array[int]) -> Array:
	var survey_regions: Array = []
	var base_radius: float = sector_base_radius(map_data)
	for index in range(ordered.size()):
		var weight: int = system_presence_weight(planets[index])
		var development: float = clampf(float(weight) / 150.0, 0.0, 1.0)
		var peak: float = lerpf(0.88, 1.65, development) * 64.0
		var claim_radius: float = territory_kernel_reach(base_radius, weight) * sqrt(1.0 - sqrt(19.0 / peak))
		survey_regions.append({"owner": ordered[index], "center": map_data["points"][index], "radius": claim_radius * 3.0})
	return survey_regions

# Client presentation vision is separate from strategic route discovery.
const VISION_CELL: float = 80.0
const TERRITORY_VISION_MARGIN: float = 160.0

static func territory_kernel_reach(base_radius: float, weight: int) -> float:
	return base_radius * lerpf(1.12, 1.52, clampf(float(weight) / 150.0, 0.0, 1.0))
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

# Equivalent to _stamp_vision at each source cell center: offsets between
# cell centers are exact, so each radius has one row-span shape. Overlapping
# spans are merged per row instead of probing every disk cell.
static func _stamp_cell_sources(cells: Dictionary, sources: Dictionary) -> void:
	var source_rows: Dictionary = {}
	# A run of adjacent equal-radius source cells expands into one interval
	# per disk row, exactly the union of the individual source intervals.
	for source: Vector2i in sources:
		var radius: float = float(sources[source])
		if not source_rows.has(radius):
			source_rows[radius] = {}
		var group: Dictionary = source_rows[radius]
		if not group.has(source.y):
			group[source.y] = []
		group[source.y].append(source.x)
	var rows: Dictionary = {}
	for radius in source_rows:
		var shape: PackedInt32Array = _vision_row_spans(float(radius))
		var reach: int = (shape.size() - 1) / 2
		for y in source_rows[radius]:
			var xs: Array = source_rows[radius][y]
			xs.sort()
			# Merge adjacent centers once, before expanding by each half-width.
			var runs: Array[Vector2i] = []
			var first: int = xs[0]
			var last: int = first
			for index in range(1, xs.size()):
				var x: int = xs[index]
				if x > last + 1:
					runs.append(Vector2i(first, last))
					first = x
				last = x
			runs.append(Vector2i(first, last))
			for row in range(shape.size()):
				var half: int = shape[row]
				if half < 0:
					continue
				var target_y: int = int(y) - reach + row
				if not rows.has(target_y):
					rows[target_y] = []
				var spans: Array = rows[target_y]
				# Gaps bridged by this disk row can also be merged immediately.
				var start: int = runs[0].x - half
				var end: int = runs[0].y + half
				for index in range(1, runs.size()):
					var next_start: int = runs[index].x - half
					if next_start > end + 1:
						spans.append(Vector2i(start, end))
						start = next_start
					end = runs[index].y + half
				spans.append(Vector2i(start, end))
	for y: int in rows:
		var spans: Array = rows[y]
		spans.sort()
		var start: int = spans[0].x
		var end: int = spans[0].y
		for index in range(1, spans.size() + 1):
			if index < spans.size() and spans[index].x <= end + 1:
				end = maxi(end, spans[index].y)
				continue
			for x in range(start, end + 1):
				cells[Vector2i(x, y)] = true
			if index < spans.size():
				start = spans[index].x
				end = spans[index].y

# Per-row half widths (-1 for empty rows) using the _stamp_vision predicate.
static func _vision_row_spans(radius: float) -> PackedInt32Array:
	var reach: int = ceili(radius / VISION_CELL)
	var origin: Vector2 = Vector2.ONE * 0.5 * VISION_CELL
	var spans := PackedInt32Array()
	for dy in range(-reach, reach + 1):
		var half: int = -1
		for dx in range(0, reach + 1):
			if ((Vector2(Vector2i(dx, dy)) + Vector2.ONE * 0.5) * VISION_CELL).distance_squared_to(origin) <= radius * radius:
				half = dx
			else:
				break
		spans.append(half)
	return spans

# In bilateral mode, group IDs are empire IDs. Only direct consenting
# allies contribute live sensor coverage, never an ally's ally.
static func _shares_group_vision(state: Dictionary, viewer: int, source: int) -> bool:
	if state.has("diplomacy"):
		return diplomacy_allows(state, viewer, source, "vision")
	return viewer > 0 and viewer == source

# Optional client-owned cache stores only ship-cell coverage, not structures
# or live visibility decisions. Rebuild the exact source map every call so
# movement, owner/sensor changes and removals cannot leave stale coverage.
static func team_vision(state: Dictionary, team: int, ship_cache: Variant = null) -> Dictionary:
	var cells: Dictionary = {}
	if team <= 0:
		return cells
	var sources: Dictionary = {}
	var owner_shares: Dictionary = {}
	var owner_sensor: Dictionary = {}
	for ship in state.get("ships", []):
		var owner: int = int(ship["owner"])
		if not owner_shares.has(owner):
			owner_shares[owner] = _shares_group_vision(state, team, _combat_group(state, owner))
		if not bool(owner_shares[owner]) or not ship.has("position"):
			continue
		var kind: String = str(ship["kind"])
		var factor: float = 1.0
		if military_hull(kind):
			if not owner_sensor.has(owner):
				owner_sensor[owner] = _player_factor(state, owner, "rank_sensor", 0.10)
			factor = float(owner_sensor[owner])
		var cell: Vector2i = vision_cell(ship["position"])
		sources[cell] = maxf(float(sources.get(cell, 0.0)), sight_radius(kind) * factor)
	if ship_cache != null and ship_cache.get("sources") == sources and ship_cache.has("cells"):
		cells = ship_cache["cells"].duplicate()
	else:
		_stamp_cell_sources(cells, sources)
		if ship_cache != null:
			ship_cache["sources"] = sources
			# Structure sight mutates the result below; cache only the ship mask.
			ship_cache["cells"] = cells.duplicate()
	var elapsed: float = float(state["elapsed"])
	var base_radius: float = sector_base_radius(state["map"])
	for index in range(state["planets"].size()):
		var system: Dictionary = state["planets"][index]
		if not _shares_group_vision(state, team, _combat_group(state, int(system["owner"]))):
			continue
		var weight: int = system_presence_weight(system)
		if weight > 0:
			_stamp_vision(cells, state["map"]["points"][index], territory_kernel_reach(base_radius, weight) + TERRITORY_VISION_MARGIN)
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

# Starting survey is historical knowledge, not a continuing sensor.
static func _seed_starting_exploration(state: Dictionary) -> void:
	for region in state.get("starting_survey", []):
		var team: int = _combat_group(state, int(region["owner"]))
		if team <= 0:
			continue
		var explored: Dictionary = state["explored"]
		if not explored.has(team):
			explored[team] = {"planets": {}, "fields": {}}
		var center: Vector2 = region["center"]
		var squared: float = float(region["radius"]) ** 2
		var points: Array = state["map"]["points"]
		for index in range(points.size()):
			if center.distance_squared_to(points[index]) <= squared:
				explored[team]["planets"][index] = true
		var fields: Array = state["map"].get("fields", [])
		for index in range(fields.size()):
			if center.distance_squared_to(fields[index]["position"]) <= squared:
				explored[team]["fields"][index] = true

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
static func storage_capacity(p: Dictionary, resource: String = "Organics") -> float:
	var level: int = clampi(int(p.get("warehouse_level", 0)), 0, 3)
	var base: float = BASE_METAL_CAPACITY if level == 0 and resource == "Metals" else float(WAREHOUSE_CAPACITIES[level])
	return base * (1.0 + (0.20 if int(p["owner"]) != 0 and has_reward(p, "storage") else 0.0) + 0.08 * reward_rank(p.get("conquest_rewards", []), "rank_storage"))

static func storage_free(p: Dictionary, resource: String) -> float:
	return maxf(0.0, storage_capacity(p, resource) - float(p["stock"].get(resource, 0.0)))

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

# Unembarked crew is already committed to its paid job, but remains
# part of resident population (tax, production, consumption) until work starts.
static func reserved_construction_population(p: Dictionary) -> float:
	var total: float = 0.0
	for job in p.get("queue", []):
		total += _remaining_crew(job)
	return total

static func _crew_staff_reserve(p: Dictionary, kind: String, yard_slot: int) -> float:
	if yard_slot >= 0:
		return yard_staff_required(p, yard_slot) if yard_fits(p, yard_slot, kind) else INF
	var reserve: float = INF
	for slot in range(p.get("yards", []).size()):
		if yard_fits(p, slot, kind):
			reserve = minf(reserve, yard_staff_required(p, slot))
	return reserve

static func available_crew_population(p: Dictionary, yard_slot: int = -1, kind: String = "") -> float:
	var staff: float = yard_staff_required(p, yard_slot) if yard_slot >= 0 and kind.is_empty() else _crew_staff_reserve(p, kind, yard_slot)
	return maxf(0.0, float(p.get("population", 0.0)) - reserved_construction_population(p) - staff)

static func ship_crew_available(p: Dictionary, kind: String, yard_slot: int = -1) -> bool:
	var crew: float = float(CREW_COSTS.get(kind, 0.0))
	return crew <= EPS or (available_crew_population(p, yard_slot, kind) + EPS >= crew)

static func construction_affordable(state: Dictionary, p: Dictionary, cost: Dictionary, kind: String = "", yard_slot: int = -1) -> bool:
	return ship_origin_population_met(p, kind) and ship_crew_available(p, kind, yard_slot) and affordable(p, cost) and can_pay_credits(state, int(p["owner"]), construction_credit_cost(cost, kind))

static func ship_origin_population_met(p: Dictionary, kind: String) -> bool:
	return kind != "colony_ship" or float(p.get("population", 0.0)) + EPS >= COLONY_MIN_ORIGIN_POPULATION

static func resident_tax_income(state: Dictionary, player: int) -> float:
	var total: float = 0.0
	if player <= 0 or not state.get("galactic_credits", {}).has(player):
		return total
	for planet in state.get("planets", []):
		if int(planet["owner"]) == player:
			total += maxf(0.0, float(planet["population"])) * RESIDENT_TAX_RATE * _rank_factor(planet, "rank_tax", 0.05)
	return total

# One pass over systems, independent of fleet size. Use starting residents
# for each simulation substep; reserved crew remains taxable until embarked.
# Ship crews and embarked construction crew do not contribute.
static func _accrue_resident_taxes(state: Dictionary, dt: float, bases: Dictionary = {}) -> void:
	if dt <= 0.0:
		return
	var credits: Dictionary = state.get("galactic_credits", {})
	var planets: Array = state.get("planets", [])
	for index in range(planets.size()):
		var planet: Dictionary = planets[index]
		var owner: int = int(planet["owner"])
		if owner > 0 and credits.has(owner):
			var basis: Dictionary = bases.get(index, {})
			var factor: float = _rank_factor(planet, "rank_tax", 0.05) if basis.is_empty() else float(basis["tax"])
			credits[owner] = float(credits[owner]) + maxf(0.0, float(planet["population"])) * RESIDENT_TAX_RATE * factor * dt

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
static func _pay_fleet_upkeep(state: Dictionary, dt: float, wage_tables: Dictionary = {}) -> void:
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
		var rate: float = _scheduled_wage_rate(state, ship, wage_tables)
		if owner <= 0 or not credits.has(owner) or rate <= 0.0:
			if ship.has("unpaid_since"):
				ship.erase("unpaid_since")
			continue
		if military_hull(kind):
			military.append(ship)
		else:
			_pay_hull_wages(credits, ship, rate * dt, now)
	for ship in military:
		_pay_hull_wages(credits, ship, _scheduled_wage_rate(state, ship, wage_tables) * dt, now)

# A seeded roll per hull and period, independent of simulation frame rate.
# Pirates do not join teams, diplomacy, the economy or objective scoring.
# Strategy is host-only and refreshed on a coarse clock. No new RPC.
static func _pirate_power(ship: Dictionary) -> float:
	var kind: String = str(ship.get("kind", ""))
	var strength: float = float({"miner": 0.25, "scout": 0.4, "fighter": 1.0, "cruiser": 5.0, "destroyer": 9.0}.get(kind, 0.0))
	return strength * clampf(float(ship.get("hp", ship_max_hp(kind))) / maxf(EPS, ship_max_hp(kind)), 0.0, 1.0)

static func _pirate_claims(state: Dictionary) -> Array:
	var claims: Array = []
	var base: float = sector_base_radius(state["map"])
	for index in range(state["planets"].size()):
		var system: Dictionary = state["planets"][index]
		if int(system["owner"]) <= 0 or not has_station(system):
			continue
		var radius: float = maxf(territory_kernel_reach(base, system_presence_weight(system)) * 1.15, MISSILE_RANGE + 180.0)
		claims.append({"point": state["map"]["points"][index], "radius": radius})
	return claims

static func _pirate_claim_depth(point: Vector2, claims: Array, extra: float = 0.0) -> float:
	var depth: float = 0.0
	for claim in claims:
		depth += maxf(0.0, float(claim["radius"]) + extra - point.distance_to(claim["point"]))
	return depth

static func _pirate_escape_point(point: Vector2, claims: Array, bounds: Vector2, seed: int) -> Vector2:
	var best: Vector2 = point
	var score: float = INF
	var margin := Vector2.ONE * 60.0
	for ring in range(1, 13):
		for i in range(16):
			var angle: float = (float(i) + float(posmod(seed, 16)) / 16.0) * TAU / 16.0
			var candidate: Vector2 = (point + Vector2.from_angle(angle) * float(ring) * 450.0).clamp(margin, bounds.max(margin * 2.0) - margin)
			if not _point_clear_of_rocks(candidate):
				continue
			var depth: float = _pirate_claim_depth(candidate, claims, 100.0)
			var value: float = point.distance_to(candidate) + depth * 100.0
			if value < score:
				score = value
				best = candidate
		if _pirate_claim_depth(best, claims, 100.0) <= EPS:
			break
	return best

static func _pirate_defense(point: Vector2, cells: Dictionary, claims: Array) -> float:
	# Count every nearby armed defender, even from a different empire.
	var total: float = 0.3
	var cell := Vector2i(floori(point.x / PIRATE_DEFENSE_RANGE), floori(point.y / PIRATE_DEFENSE_RANGE))
	for y in range(-1, 2):
		for x in range(-1, 2):
			for craft in cells.get(cell + Vector2i(x, y), []):
				if point.distance_squared_to(craft["position"]) <= PIRATE_DEFENSE_RANGE * PIRATE_DEFENSE_RANGE:
					total += _pirate_power(craft)
	for claim in claims:
		if point.distance_squared_to(claim["point"]) < pow(float(claim["radius"]), 2.0):
			total += 7.0
	return total

static func _pirate_pick_target(point: Vector2, power: float, targets: Array, cells: Dictionary, claims: Array, epoch: int, seed: int) -> Dictionary:
	if power <= EPS or targets.is_empty():
		return {}
	var best: Dictionary = {}
	var best_score: float = -INF
	# Rotate a bounded sample across the full map. No fog filter and no
	# per-tick pirate × empire-fleet Cartesian search.
	var samples: int = mini(64, targets.size())
	var start: int = posmod(epoch * 61 + seed, targets.size())
	for i in range(samples):
		var target: Dictionary = targets[(start + i) % targets.size()]
		var location: Vector2 = target["position"]
		var defense: float = _pirate_defense(location, cells, claims)
		if defense * 1.5 > power:
			continue
		var priority: float = float({"ship": 4.0, "miner": 3.5, "colony_ship": 3.0, "science_ship": 2.5}.get(str(target["kind"]), 1.0))
		var value: float = priority * 1500.0 - point.distance_to(location) - defense * 200.0
		if value > best_score:
			best_score = value
			best = target
	return best

static func _pirate_decisions(state: Dictionary) -> void:
	var epoch: int = floori(float(state["elapsed"]) / PIRATE_DECISION_YEARS)
	if int(state.get("_pirate_epoch", -1)) == epoch:
		return
	state["_pirate_epoch"] = epoch
	var pirates: Array = []
	for craft in state["ships"]:
		if bool(craft.get("rogue", false)):
			pirates.append(craft)
	if pirates.is_empty():
		return
	var claims: Array = _pirate_claims(state)
	var bounds: Vector2 = state["map"]["size"]
	var combat_cells: Dictionary = {}
	var targets: Array = []
	var pirate_cells: Dictionary = {}
	for craft in state["ships"]:
		if int(craft["owner"]) <= 0:
			continue
		targets.append(craft)
		if armed(craft):
			_spatial_insert(combat_cells, craft["position"], PIRATE_DEFENSE_RANGE, craft)
	for craft in pirates:
		var point: Vector2 = craft["position"]
		if craft.get("pirate_phase", "escape") == "escape":
			if _pirate_claim_depth(point, claims, 100.0) > EPS:
				craft["pirate_goal"] = _pirate_escape_point(point, claims, bounds, int(craft["id"]))
				continue
			craft["owner"] = PIRATE_OWNER
			craft["pirate_phase"] = "roam"
		_spatial_insert(pirate_cells, point, PIRATE_GROUP_RANGE, craft)
	var assigned: Dictionary = {}
	for leader in pirates:
		var leader_id: int = int(leader["id"])
		if int(leader["owner"]) != PIRATE_OWNER or assigned.has(leader_id):
			continue
		var center: Vector2 = leader["position"]
		var cell := Vector2i(floori(center.x / PIRATE_GROUP_RANGE), floori(center.y / PIRATE_GROUP_RANGE))
		var group: Array = _pirate_gather_group(leader, cell, pirate_cells, assigned)
		var power: float = _pirate_power(leader)
		for k in range(1, group.size()):
			power += _pirate_power(group[k])
		var threat: float = _pirate_defense(center, combat_cells, claims)
		var victim: Dictionary = _pirate_pick_target(center, power, targets, combat_cells, claims, epoch, leader_id) if power >= threat * 1.5 else {}
		var destination: Vector2 = center
		var phase: String = "roam"
		if not victim.is_empty():
			destination = victim["position"]
			phase = "hunt"
		elif threat > 0.3 and power < threat * 1.5:
			phase = "retreat"
			destination = _pirate_retreat_point(center, combat_cells, claims, bounds, leader_id)
		else:
			destination = _pirate_patrol_point(center, cell, pirate_cells, assigned, claims, bounds, leader_id, epoch)
		_pirate_assign_group(group, phase, int(victim.get("id", -1)), destination, bounds)

static func _pirate_gather_group(leader: Dictionary, cell: Vector2i, pirate_cells: Dictionary, assigned: Dictionary) -> Array:
	var center: Vector2 = leader["position"]
	var group: Array = [leader]
	assigned[int(leader["id"])] = true
	for y in range(-1, 2):
		for x in range(-1, 2):
			for mate in pirate_cells.get(cell + Vector2i(x, y), []):
				var mate_id: int = int(mate["id"])
				if group.size() >= 12:
					break
				if assigned.has(mate_id) or center.distance_squared_to(mate["position"]) > PIRATE_GROUP_RANGE * PIRATE_GROUP_RANGE:
					continue
				assigned[mate_id] = true
				group.append(mate)
	return group

static func _pirate_retreat_point(center: Vector2, combat_cells: Dictionary, claims: Array, bounds: Vector2, leader_id: int) -> Vector2:
	var away: Vector2 = Vector2.ZERO
	var threat_cell := Vector2i(floori(center.x / PIRATE_DEFENSE_RANGE), floori(center.y / PIRATE_DEFENSE_RANGE))
	for y in range(-1, 2):
		for x in range(-1, 2):
			for foe in combat_cells.get(threat_cell + Vector2i(x, y), []):
				var distance: float = center.distance_to(foe["position"])
				if distance <= PIRATE_DEFENSE_RANGE:
					away += (center - (foe["position"] as Vector2)).normalized() * _pirate_power(foe) / maxf(1.0, distance)
	return _pirate_escape_point(center + away.normalized() * 1000.0, claims, bounds, leader_id)

# Seek other nearby unassigned groups or a seeded open-space patrol point.
static func _pirate_patrol_point(center: Vector2, cell: Vector2i, pirate_cells: Dictionary, assigned: Dictionary, claims: Array, bounds: Vector2, leader_id: int, epoch: int) -> Vector2:
	var destination: Vector2 = center
	var nearest: float = INF
	for y in range(-5, 6):
		for x in range(-5, 6):
			for other in pirate_cells.get(cell + Vector2i(x, y), []):
				if assigned.has(int(other["id"])):
					continue
				var distance: float = center.distance_squared_to(other["position"])
				if distance < nearest and distance < 4000.0 * 4000.0:
					nearest = distance
					destination = other["position"]
	if nearest == INF:
		var direction: Vector2 = Vector2.from_angle(float(posmod(leader_id * 31 + floori(float(epoch) / 4.0), 360)) * PI / 180.0)
		destination = _pirate_escape_point(center + direction * 1100.0, claims, bounds, leader_id)
	return destination

static func _pirate_assign_group(group: Array, phase: String, target_id: int, destination: Vector2, bounds: Vector2) -> void:
	for i in range(group.size()):
		var craft: Dictionary = group[i]
		craft["pirate_phase"] = phase
		craft["pirate_target"] = target_id
		craft["pirate_goal"] = (destination + Vector2.from_angle(float(i) * 2.399963) * (0.0 if i == 0 else 65.0)).clamp(Vector2.ZERO, bounds)
		if phase != "hunt":
			craft["combat_target"] = -1
			craft["laser_until"] = -1.0

static func _work_pirate(state: Dictionary, ship: Dictionary, dt: float) -> void:
	var point: Vector2 = ship["position"]
	var destination: Vector2 = ship.get("pirate_goal", point)
	if ship.get("pirate_phase", "") == "hunt":
		var target: Dictionary = _hulls_by_id.get(int(ship.get("pirate_target", -1)), {})
		if not target.is_empty() and int(target["owner"]) > 0:
			var live: Vector2 = target["position"]
			var reach: float = LASER_RANGE * 0.75 if armed(ship) else LASER_RANGE * 2.0
			destination = live.move_toward(point, reach)
	_navigate(ship, destination, ship_speed(str(ship["kind"])) * dt)

static func _pirate_fire(state: Dictionary, ship: Dictionary, positions: Dictionary, by_id: Dictionary, cells: Dictionary, teams: Dictionary, damage: Dictionary, killed_by: Dictionary, health: Dictionary, slots: Dictionary, hull_health: PackedFloat64Array, dt: float) -> void:
	var target: int = int(ship.get("pirate_target", -1))
	var id: int = int(ship["id"])
	if ship.get("pirate_phase", "") != "hunt" or not armed(ship) or not by_id.has(target) or int(by_id[target]["owner"]) <= 0:
		ship["combat_target"] = -1
		return
	var range_to: float = (positions[id] as Vector2).distance_to(positions[target])
	var in_range: bool = range_to <= LASER_RANGE
	ship["combat_target"] = target if in_range else -1
	var cooldown: float = maxf(0.0, float(ship.get("laser_cooldown", 0.0)) - dt)
	var laser: float = MINER_LASER_DAMAGE if ship["kind"] == "miner" else LASER_DAMAGE * capital_lasers(str(ship["kind"]))
	if in_range and cooldown <= EPS and laser > 0.0:
		_ship_hit(damage, killed_by, health, target, ship, laser, slots, hull_health)
		ship["laser_until"] = float(state["elapsed"]) + 0.2
		cooldown = 1.0
	ship["laser_cooldown"] = cooldown
	_fire_blaster(state, ship, target if in_range else -1, positions, damage, killed_by, health, dt, slots, hull_health)
	var missile_cd: float = maxf(0.0, float(ship.get("missile_cooldown", 0.0)) - dt)
	var launchers: int = missile_count(str(ship["kind"]))
	if launchers > 0 and missile_cd <= EPS and range_to <= MISSILE_RANGE:
		_missile_splash(state, cells, positions, teams, PIRATE_COMBAT_GROUP, target, ship, MISSILE_DAMAGE * launchers, damage, killed_by, health, slots, hull_health)
		ship["missile_origin"] = positions[id]
		ship["missile_endpoint"] = positions[target]
		ship["missile_until"] = float(state["elapsed"]) + 0.65
		missile_cd = MISSILE_COOLDOWN
	ship["missile_cooldown"] = missile_cd

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
		"field": -1, "mining_mode": "idle", "field_leg": 0.0, "holding": false,
		"pirate_phase": "escape"})

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
		if owner <= 0 or colony_morphing(ship) or not state.get("galactic_credits", {}).has(owner) or not ship.has("unpaid_since") or ship_upkeep(str(ship["kind"])) <= 0.0:
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
	var storage_reference: Dictionary = empty_stock()
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
		population += float(planet["population"])
		embarking_population += embarked_construction_population(planet)
		for resource in RESOURCES:
			stock[resource] = float(stock[resource]) + float(planet["stock"].get(resource, 0.0))
			storage_reference[resource] = float(storage_reference[resource]) + storage_capacity(planet, resource)
	for ship in state.get("ships", []):
		if int(ship["owner"]) != player:
			continue
		craft += 1
		upkeep += hull_upkeep(state, ship)
		if ship.has("unpaid_since"):
			unpaid_ships += 1
		ship_population += float(ship.get("crew", 0.0))
		if ship.get("kind", "ship") == "colony_ship":
			colonies += 1
		elif ship.get("kind", "ship") in MILITARY_KINDS:
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

static func colony_morphing(ship: Dictionary) -> bool:
	return ship.get("kind", "") == "colony_ship" and ship.has("colony_transform_progress")

static func colony_path(state: Dictionary, player: int, ship: Dictionary, target: int) -> Array[int]:
	var planets: Array = state.get("planets", [])
	if target < 0 or target >= planets.size() or int(planets[target]["owner"]) != 0 or has_station(planets[target]):
		return []
	if int(ship["owner"]) != player or ship.get("kind", "ship") != "colony_ship" or colony_morphing(ship):
		return []
	var start: int = int(ship["at"])
	if _combat_group(state, player) <= 0:
		return []
	if not discovered(state, player, "planets", target):
		return []
	return _rally_path(state, start, target)

# Select on the authority, not from a stale client-side dropdown.
static func colony_en_route(state: Dictionary, player: int, target: int) -> bool:
	for ship in state["ships"]:
		if int(ship["owner"]) == player and ship["kind"] == "colony_ship" and int(ship.get("dest", -1)) == target and ship.get("unit_order", {}).get("kind", "") == "colonize":
			return true
	return false

static func nearest_idle_colony(state: Dictionary, player: int, target: int) -> int:
	if colony_en_route(state, player, target):
		return -1
	var best: float = INF
	var chosen: int = -1
	for ship in state["ships"]:
		if int(ship["owner"]) != player or ship["kind"] != "colony_ship":
			continue
		if ship.get("unit_order", {}).get("kind", "") == "colonize" and int(ship.get("dest", -1)) >= 0:
			continue
		var path: Array[int] = colony_path(state, player, ship, target)
		if path.is_empty():
			continue
		var pos: Vector2 = ship.get("position", state["map"]["points"][int(ship["at"])])
		var distance: float = pos.distance_to(state["map"]["points"][target])
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
		ship.erase("retreating")
		ship.erase("repair_site")
		ship.erase("withdrawal_objective")
		_set_unit_order(state, ship, {"kind": "colonize", "target": target, "automatic": automatic})
		ship["dest"] = target
		_ensure_position(state["map"]["points"], ship)
		ship["navigation_target"] = colony_approach_position(state, target, ship["position"])
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
	if ship.get("kind", "") != "colony_ship" or not ship.get("route", []).is_empty() or ship.has("colony_transform_progress"):
		return false
	var node: int = local_sector(graph, ship)
	return node >= 0 and node < state["planets"].size() and int(state["planets"][node]["owner"]) == 0 and not has_station(state["planets"][node]) and discovered(state, int(ship["owner"]), "planets", node)

static func _convert_colony(state: Dictionary, ship: Dictionary, at: int) -> bool:
	var colony: Dictionary = state["planets"][at]
	colony["owner"] = int(ship["owner"])
	var progress: Dictionary = objective_progress(state, int(ship["owner"]))
	progress["colonies"][at] = true
	colony["conquest_rewards"] = progress.get("rewards", []).duplicate()
	colony["station"] = {"hp": STATION_HP, "weapons": [_new_pds(), _new_pds()]}
	# The station inherits the committed morph's orbital phase, not a
	# predetermined angle on the opposite side of the star.
	if ship["unit_order"].has("orbit_phase"):
		colony["station"]["orbit_phase"] = ship["unit_order"]["orbit_phase"]
	# Settlement transfers the crew exactly once. The founding yard supplies
	# housing, not an additional free population; planetless residents
	# remain aboard orbital habitats even when above nominal capacity.
	var settlers: float = maxf(0.0, float(ship.get("crew", 0.0)))
	colony["population"] = settlers
	colony["eco_population"] = minf(settlers, ORBITAL_HOUSING_POPULATION) if has_planets(colony) else settlers
	colony["population_velocity"] = 0.0
	colony["yards"].append({"level": 1, "job": -1, "hp": YARD_HP, "station_slot": 1})
	if has_planets(colony):
		for resource in ["Metals", "Organics"]:
			colony["levels"][resource] = 1
	for resource in RESOURCES + [ANTIMATTER]:
		var amount: float = float(ship.get("cargo", {}).get(resource, 0.0))
		colony["stock"][resource] = float(colony["stock"].get(resource, 0.0)) + amount
	return true # consumed to establish the colony

# Colony remains a normal, vulnerable hull until the entire conversion is complete.
# Once assembly starts only destruction can interrupt it. Follow the
# normal station orbit without steering or consuming new movement orders.
static func _work_colony(state: Dictionary, ship: Dictionary, dt: float) -> bool:
	if colony_morphing(ship):
		var site: int = int(ship["dest"])
		var orbit: Vector2 = colony_station_position(state, site, float(state["elapsed"]), float(ship.get("unit_order", {}).get("orbit_phase", INF)))
		ship["position"] = orbit
		ship["navigation_target"] = orbit
		ship["colony_transform_progress"] = minf(COLONY_TRANSFORM_TIME, float(ship["colony_transform_progress"]) + maxf(0.0, dt) * _player_factor(state, int(ship["owner"]), "rank_colony", 0.15))
		return _convert_colony(state, ship, site) if float(ship["colony_transform_progress"]) + EPS >= COLONY_TRANSFORM_TIME else false
	if ship.get("unit_order", {}).get("kind", "") != "colonize":
		ship.erase("colony_transform_progress")
		if not ship["route"].is_empty():
			_move(state, ship, dt)
		return false
	var target: int = int(ship.get("dest", -1))
	if target < 0 or target >= state["planets"].size():
		ship.erase("colony_transform_progress")
		ship.erase("unit_order")
		return false
	if state.has("diplomacy") and not _civilian_route_safe(state, ship, planet_teams(state), _combat_group(state, int(ship["owner"]))):
		ship["route"] = []
		ship["leg"] = 0.0
		ship["dest"] = -1
		ship.erase("unit_order")
		ship.erase("colony_transform_progress")
		ship["navigation_target"] = ship["position"]
		return false
	if int(state["planets"][target]["owner"]) != 0 or has_station(state["planets"][target]):
		# Another ship finished first. Return to launch without claiming.
		var back: Array[int] = []
		back.assign(ship.get("return_path", []))
		back.reverse()
		ship["dest"] = -1
		ship.erase("unit_order")
		ship.erase("colony_transform_progress")
		_set_route(ship, back)
		return false
	_ensure_position(state["map"]["points"], ship)
	var point: Vector2 = colony_approach_position(state, target, ship["position"])
	if not _move(state, ship, dt, point, target):
		ship.erase("colony_transform_progress")
		return false
	if not bool(ship.get("unit_order", {}).get("automatic", false)):
		ship["dest"] = -1
		ship.erase("unit_order")
		ship["holding"] = true
		ship["navigation_target"] = ship["position"]
		return false
	# The first arriving Colony reserves the site until it finishes or dies.
	for other in state["ships"]:
		if colony_morphing(other) and int(other["dest"]) == target:
			var return_route: Array[int] = []
			return_route.assign(ship.get("return_path", []))
			return_route.reverse()
			ship["dest"] = -1
			ship.erase("unit_order")
			_set_route(ship, return_route)
			return false
	# Travel consumes this tick. Assembly discards queued successor orders.
	ship.erase("order_queue")
	var center: Vector2 = state["map"]["points"][target]
	ship["unit_order"]["orbit_phase"] = (point - center).angle() - float(state["elapsed"]) * 0.008
	ship["colony_transform_progress"] = 0.0
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
	return ECO_HOUSING_ORGANICS * eco_housing_count(p) * (_rank_factor(p, "rank_orbital", 0.05) + 0.15 * reward_rank(p.get("conquest_rewards", []), "rank_synthetic")) if int(p.get("owner", 0)) != 0 else 0.0

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

static func _farm_base(planet: Dictionary) -> float:
	return ORGANICS_PER_LEVEL * production_level(planet, "Organics") * production_modifier(planet, "Organics")

static func _farm_bonus(planet: Dictionary) -> float:
	return _rank_factor(planet, "rank_food", 0.05) + (0.15 if has_reward(planet, "agriculture") else 0.0)

static func farm_potential(planet: Dictionary, basis: Dictionary = {}) -> float:
	if int(planet["owner"]) == 0 or not has_planets(planet):
		return 0.0
	var base: float = _farm_base(planet) if basis.is_empty() else float(basis["farm_base"])
	var bonus: float = _farm_bonus(planet) if basis.is_empty() else float(basis["farm_bonus"])
	return base * float(planet.get("farm_factor", 1.0)) * bonus

static func population_capacity(planet: Dictionary, basis: Dictionary = {}) -> float:
	return farm_potential(planet, basis) * POPULATION_PER_ORGANICS_RATE

static func habitation_capacity(planet: Dictionary) -> float:
	if not has_planets(planet):
		return 0.0
	return 500000.0 * float(planet.get("size_factor", 1.0)) * pow(2.0, int(planet.get("habitation_level", 0))) * _rank_factor(planet, "rank_housing", 0.15)

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
	if resource != "Organics" or int(planet["owner"]) == 0:
		return 0.0
	return organics_demand(planet)

static func civilian_stock_access(planet: Dictionary, resource: String) -> float:
	# Stock above the import target is reserved for trade and construction.
	var threshold: float = float(planet["thresholds"][resource]["min"])
	var reserve: float = storage_capacity(planet, resource) * threshold / 100.0
	return minf(maxf(0.0, float(planet["stock"][resource])), reserve)

static func net_rate(planet: Dictionary, resource: String) -> float:
	var net: float = rate(planet, resource) - consumption(planet, resource)
	if net > 0.0 and storage_free(planet, resource) <= EPS:
		return 0.0
	if net < 0.0 and civilian_stock_access(planet, resource) <= EPS:
		return 0.0
	return net

static func _industrial_base(planet: Dictionary, resource: String) -> float:
	var base_rate: float = CRYSTALS_PER_LEVEL if resource == "Crystals" else PRODUCTION_PER_LEVEL
	return base_rate * production_level(planet, resource) * production_modifier(planet, resource)

static func _industrial_bonus(planet: Dictionary, resource: String) -> float:
	if resource == "Metals":
		return _rank_factor(planet, "rank_metals", 0.05) + (0.15 if has_reward(planet, "industry") else 0.0)
	if resource == "Crystals":
		return _rank_factor(planet, "rank_crystals", 0.05) + (0.25 if has_reward(planet, "crystals") else 0.0)
	return 1.0

static func rate(planet: Dictionary, resource: String, basis: Dictionary = {}) -> float:
	var station_output: float = STATION_CRYSTALS_PER_YEAR if resource == "Crystals" and int(planet["owner"]) != 0 and has_station(planet) else 0.0
	if bool(planet.get("planet_blockaded", false)) and has_planets(planet):
		return eco_organics(planet) if resource == "Organics" else station_output
	if not ACTIVE_PRODUCTION.has(resource) or int(planet["owner"]) == 0 or (not has_planets(planet) and resource in ["Metals", "Crystals"]):
		return station_output
	if resource == "Organics":
		# Small populations still produce a surplus; farm capacity limits output.
		var farm: float = farm_potential(planet, basis)
		var capacity: float = farm * POPULATION_PER_ORGANICS_RATE
		if capacity <= EPS:
			return eco_organics(planet)
		var labor: float = sqrt(clampf(planetary_population(planet) / capacity, 0.0, 1.0))
		return farm * labor + eco_organics(planet)
	var labor: float = population_multiplier(planet)
	var base: float = _industrial_base(planet, resource) if basis.is_empty() else float(basis["base"][resource])
	var bonus: float = _industrial_bonus(planet, resource) if basis.is_empty() else float(basis["bonus"][resource])
	return station_output + base * labor * bonus

static func food_growth_multiplier(planet: Dictionary) -> float:
	# Orbital residents are self-sufficient; only terrestrial growth is food-limited.
	if not has_planets(planet):
		return 1.0
	return clampf(float(planet["stock"].get("Organics", 0.0)) / POPULATION_FOOD_RESERVE, 0.0, 1.0)

static func _growth_bonus(planet: Dictionary) -> float:
	return _rank_factor(planet, "rank_growth", 0.05) + (0.15 if has_reward(planet, "population") else 0.0)

static func _update_population(planet: Dictionary, dt: float, basis: Dictionary = {}) -> void:
	var eco: float = eco_population(planet)
	if not has_planets(planet):
		planet["population_velocity"] = 0.0
		_regenerate_eco(planet, dt, eco)
		return
	# Exact solution of x'' + 2*w*x' + w*w*(x-target) = 0
	# for a constant target during this tick. Stable even for large dt.
	var current: float = planetary_population(planet)
	var housing: float = habitation_capacity(planet) if basis.is_empty() else float(basis["housing"])
	var target: float = minf(population_capacity(planet, basis), housing)
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
	if current < housing:
		growth_constant *= 1.0 - pow(clampf(current / housing, 0.0, 1.0), 3.0)
	else:
		growth_constant = 0.0
	growth_constant *= _growth_bonus(planet) if basis.is_empty() else float(basis["growth"])
	var growth_ceiling: float = current * exp(growth_constant * dt)
	if next > growth_ceiling:
		next = growth_ceiling
		next_velocity = growth_constant * next
	# A food shortfall prevents positive growth even with demographic momentum.
	var food_available: float = civilian_stock_access(planet, "Organics") + rate(planet, "Organics", basis) * dt
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
	return CONSTRUCTION_QUERIES.has_queued_job(planet, kind, target)

static func _cost(kind: String, level: int) -> Dictionary:
	return CONSTRUCTION_QUERIES.base_cost(kind, level, CRYSTAL_COST_MULTIPLIER, UPGRADE_COST_FACTOR, WAREHOUSE_COSTS, ORBITAL_HOUSING_COST)

static func _work(kind: String, level: int) -> float:
	return CONSTRUCTION_QUERIES.base_work(kind, level)

static func _get_owned(state: Dictionary, player: int, index: int) -> Dictionary:
	var planets: Array = state.get("planets", [])
	if index < 0 or index >= planets.size() or int(planets[index]["owner"]) != player or not has_station(planets[index]):
		return {}
	return planets[index]

# Reserve a slot as soon as construction is ordered.
const SHIPYARD_POPULATION = [500.0, 5000.0, 20000.0]

static func shipyard_operational(p: Dictionary, index: int) -> bool:
	return index >= 0 and index < (p.get("yards", []) as Array).size() and float(p["population"]) + EPS >= yard_staff_required(p, index)

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
	return (REINFORCED_STATION_HP if bool(p.get("station", {}).get("reinforced_plating", false)) else STATION_HP) * _rank_factor(p, "rank_station", 0.10)

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

# Include active infrastructure and pending planetary deliveries until finished.
static func station_queue_count(p: Dictionary) -> int:
	var count: int = 0
	for item in p.get("queue", []):
		if int(item["size"]) == 0 and item["kind"] != "yard_upgrade":
			count += 1
	return count

static func shipyard_queue_count(p: Dictionary, slot: int) -> int:
	var count: int = 0
	var active: int = int(p["yards"][slot]["job"])
	for item in p["queue"]:
		if (item["kind"] == "yard_upgrade" and int(item["target"]) == slot) or (int(item["size"]) > 0 and (int(item.get("yard_slot", -1)) == slot or int(item["id"]) == active)):
			count += 1
	return count

static func enqueue(state: Dictionary, player: int, index: int, kind: String, target: String = "", yard_slot: int = -1) -> bool:
	var p: Dictionary = _get_owned(state, player, index)
	if p.is_empty() or not _enqueue_admissible(p, kind, yard_slot):
		return false
	var resolved: Dictionary = _resolve_enqueue(p, kind, target)
	if resolved.is_empty():
		return false
	kind = resolved["kind"]
	target = resolved["target"]
	var level: int = resolved["level"]
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
		p["queue"][-1]["station_slot"] = resolved["station_slot"]
	return true

# Yard fit, crew, population and queue-capacity gates checked before any recipe resolution or payment.
static func _enqueue_admissible(p: Dictionary, kind: String, yard_slot: int) -> bool:
	if yard_slot != -1 and (not SHIP_KINDS.has(kind) or not shipyard_operational(p, yard_slot) or not yard_fits(p, yard_slot, kind)):
		return false
	if not ship_origin_population_met(p, kind) or not ship_crew_available(p, kind, yard_slot):
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
	elif station_queue_count(p) >= STATION_QUEUE_LIMIT:
		return false
	return true

# Returns the canonical queued kind, target, level and station port, or {} when the request is invalid.
static func _resolve_enqueue(p: Dictionary, kind: String, target: String) -> Dictionary:
	var level: int = 1
	var station_slot: int = 0
	match kind:
		"ship", "colony_ship", "fighter", "miner", "science_ship", "scout", "cruiser", "destroyer":
			target = ""
		"yard":
			level = next_shipyard_slot(p)
			if level == 0:
				return {}
			station_slot = _enqueue_yard_port(p, target, level)
			if station_slot == 0:
				return {}
			target = ""
		"reinforced_plating", "laser_matrix", "dyson_sphere":
			if not target.is_empty() or not station_upgrade_available(p, kind):
				return {}
		"yard_upgrade":
			if not target.is_valid_int():
				return {}
			var y: int = int(target)
			if y < 0 or y >= (p["yards"] as Array).size():
				return {}
			if int(p["yards"][y]["level"]) >= MAX_SHIPYARD_LEVEL or shipyard_queue_count(p, y) >= SHIPYARD_QUEUE_LIMIT:
				return {}
			target = str(y)
			if _has_job(p, kind, target):
				return {}
			level = int(p["yards"][y]["level"]) + 1
		"pds":
			if not target.is_empty():
				return {}
			var slot: int = next_pds(p)
			if slot < 0 or slot >= int(p.get("planet_count", 0)) or p.get("pds", {}).has(slot) or not pds_job(p).is_empty():
				return {}
			target = str(slot)
			level = 1
		"economy":
			match target:
				"orbital_housing":
					if not orbital_housing_available(p):
						return {}
					kind = target
					target = ""
				"habitation", "warehouse":
					if not (habitation_available(p) if target == "habitation" else warehouse_available(p)):
						return {}
					kind = target
					level = int(p.get(kind + "_level", 0)) + 1
					target = ""
				_:
					if not building_available(p, target):
						return {}
					kind = "economy_building"
					level = int(p.get("buildings", {}).get(target, 0)) + 1
		"production":
			if not production_unlocked(p, target) or _has_job(p, kind, target):
				return {}
			level = int(p["levels"][target]) + 1
		_: return {}
	return {"kind": kind, "target": target, "level": level, "station_slot": station_slot}

# Station port for a new shipyard: an explicit free "port:N" or the first free port; 0 rejects.
static func _enqueue_yard_port(p: Dictionary, target: String, level: int) -> int:
	if target.begins_with("port:"):
		var requested: String = target.trim_prefix("port:")
		if not requested.is_valid_int():
			return 0
		var port: int = int(requested)
		if port < 1 or port > MAX_SHIPYARDS or shipyard_at_port(p, port) >= 0 or not shipyard_port_job(p, port).is_empty():
			return 0
		return port
	if not target.is_empty() and target != str(level):
		return 0
	for port in range(1, MAX_SHIPYARDS + 1):
		if shipyard_at_port(p, port) < 0 and shipyard_port_job(p, port).is_empty():
			return port
	return 0

static func production_modifier(system: Dictionary, resource: String) -> float:
	var modifier: float = float(system["bonuses"].get(resource, 1.0))
	if MINED_RESOURCES.has(resource):
		modifier *= float(system["abundance"].get(resource, 0.0))
	return clampf(modifier, 0.1, 4.0) * building_multiplier(system, resource)

static func _continuous_target(p: Dictionary, key: String) -> Array:
	if SHIP_KINDS.has(key):
		return [key, ""]
	if key in ["warehouse", "habitation", "orbital_housing", "pds", "yard"]:
		return [key, ""]
	if key.begins_with("economy_building:"):
		var resource: String = key.trim_prefix("economy_building:")
		if ECONOMY_BUILDINGS.has(resource):
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

# Repeat is a preference, not an admission to the construction queue.
# Missing requirements are checked by enqueue; only completed caps stop repeat.
static func station_repeat_available(p: Dictionary, key: String) -> bool:
	match key:
		"warehouse", "habitation":
			return int(p.get(key + "_level", 0)) < 3
		"orbital_housing":
			return not has_planets(p)
		"pds":
			return not has_planets(p) or next_pds(p) >= 0
		"yard":
			return next_shipyard_slot(p) > 0
	return key.begins_with("economy_building:") and ECONOMY_BUILDINGS.has(key.trim_prefix("economy_building:"))

static func set_continuous(state: Dictionary, player: int, index: int, kind: String, enabled: bool) -> bool:
	var p: Dictionary = _get_owned(state, player, index)
	if p.is_empty() or _continuous_target(p, kind).is_empty():
		return false
	if enabled and kind.begins_with("yard_upgrade:") and int(p["yards"][int(kind.trim_prefix("yard_upgrade:"))]["level"]) >= MAX_SHIPYARD_LEVEL:
		return false
	if enabled and (kind in ["warehouse", "habitation", "orbital_housing", "pds", "yard"] or kind.begins_with("economy_building:")) and not station_repeat_available(p, kind):
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

# One lazy census for the station-work phase. No hull ownership/removal
# occurs inside that phase; completed construction only appends new hulls.
# Catch those launches before the next query, while queue counts stay live.
static func _repeat_origin_counts(state: Dictionary, census: Dictionary) -> Dictionary:
	var ships: Array = state["ships"]
	if not census.has("counts") or int(census["scanned"]) > ships.size():
		census["counts"] = {}
		census["scanned"] = 0
	var counts: Dictionary = census["counts"]
	for slot in range(int(census["scanned"]), ships.size()):
		var ship: Dictionary = ships[slot]
		var origin: Vector2i = Vector2i(int(ship["owner"]), int(ship.get("origin", -1)))
		if not counts.has(origin):
			counts[origin] = {}
		var kinds: Dictionary = counts[origin]
		var kind: String = str(ship["kind"])
		kinds[kind] = int(kinds.get(kind, 0)) + 1
	census["scanned"] = ships.size()
	return counts

static func _maintain_needed(state: Dictionary, index: int, p: Dictionary, key: String, census: Dictionary = {}) -> bool:
	if bool(p["continuous"].get(key, false)):
		return true
	if not SHIP_KINDS.has(key):
		return false
	var target: int = int(p.get("maintain", {}).get(key, 0))
	if target <= 0:
		return false
	var counts: Dictionary = _repeat_origin_counts(state, census)
	var count: int = int(counts.get(Vector2i(int(p["owner"]), index), {}).get(key, 0))
	for item in p["queue"]:
		if item["kind"] == key:
			count += 1
	return count < target

static func _refill_continuous(state: Dictionary, index: int, p: Dictionary, census: Dictionary = {}) -> void:
	var keys: Array = p["continuous"].keys()
	for key in p.get("maintain", {}):
		if not keys.has(key):
			keys.append(key)
	var cycle: Dictionary = p.get("repeat_cycle", {})
	# With no repeat targets, no queue assignment can be created. The
	# reference cycle refresh would also remove every old cycle key.
	if keys.is_empty():
		cycle.clear()
		p["repeat_cycle"] = cycle
		return
	var queue_state: Dictionary = _repeat_queue_state(p)
	var active: Dictionary = queue_state["active"]
	var manual_hulls: Dictionary = queue_state["manual_hulls"]
	_refresh_repeat_cycle(state, index, p, keys, cycle, queue_state, census)
	var hull_waiting_for_funds: bool = false
	for key in keys:
		if not _maintain_needed(state, index, p, str(key), census):
			continue
		var order: Array = _continuous_target(p, str(key))
		if order.is_empty():
			continue
		if key in ["warehouse", "habitation", "orbital_housing", "pds", "yard"] or str(key).begins_with("economy_building:"):
			_refill_station_repeat(state, index, p, str(key), order)
			continue
		if SHIP_KINDS.has(order[0]):
			if not ship_origin_population_met(p, str(order[0])) or not ship_crew_available(p, str(order[0])):
				continue
			if hull_waiting_for_funds or not has_fitting_yard(p, str(order[0])) or cycle.has(key) or manual_hulls.has(key):
				continue
			# Do not duplicate a waiting order if its repeat toggle was
			# switched off and on during the same cycle.
			if _has_waiting_hull(p, str(key), active):
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

# Shipyards share one repeat cycle. Once every turn has started, the next
# cycle may start on any idle shipyard, even while a slower hull is active.
# Independent infrastructure upgrades must not consume turns in this cycle.
static func _repeat_queue_state(p: Dictionary) -> Dictionary:
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
	return {"active": active, "idle": idle, "waiting": waiting, "manual_hulls": manual_hulls}

static func _refresh_repeat_cycle(state: Dictionary, index: int, p: Dictionary, keys: Array, cycle: Dictionary, queue_state: Dictionary, census: Dictionary = {}) -> void:
	var manual_hulls: Dictionary = queue_state["manual_hulls"]
	var all_turns: bool = true
	for key in keys:
		if SHIP_KINDS.has(key) and ship_origin_population_met(p, str(key)) and ship_crew_available(p, str(key)) and _maintain_needed(state, index, p, str(key), census) and not manual_hulls.has(key) and not cycle.has(key):
			all_turns = false
	if not bool(queue_state["waiting"]) and bool(queue_state["idle"]) and all_turns:
		cycle.clear()
	for key in cycle.keys():
		if not _maintain_needed(state, index, p, str(key), census):
			cycle.erase(key)

static func _refill_station_repeat(state: Dictionary, index: int, p: Dictionary, key: String, order: Array) -> void:
	if not station_repeat_available(p, key):
		p["continuous"][key] = false
		return
	var job_kind: String = "economy_building" if order[0] == "economy" else str(order[0])
	if job_kind == "pds":
		if not pds_job(p).is_empty():
			return
	elif _has_job(p, job_kind, str(order[1])):
		return
	var economy_job: bool = job_kind in ["warehouse", "habitation", "orbital_housing"]
	if enqueue(state, int(p["owner"]), index, "economy" if economy_job else str(order[0]), job_kind if economy_job else str(order[1])):
		p["queue"][-1]["automatic"] = true

static func _has_waiting_hull(p: Dictionary, key: String, active: Dictionary) -> bool:
	for item in p["queue"]:
		if item["kind"] == key and not active.has(int(item["id"])):
			return true
	return false

static func set_yard_autobuild(state: Dictionary, player: int, index: int, slot: int, kind: String, enabled: bool) -> bool:
	var p: Dictionary = _get_owned(state, player, index)
	if p.is_empty() or slot < 0 or slot >= p["yards"].size() or not SHIP_KINDS.has(kind):
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
		var yard: Dictionary = p["yards"][slot]
		var automatic: Array = yard.get("autobuild", [])
		if automatic.is_empty() or not shipyard_operational(p, slot):
			continue
		for kind in automatic:
			if not yard_fits(p, slot, kind) or not ship_origin_population_met(p, kind) or not ship_crew_available(p, kind, slot):
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

static func cancel(state: Dictionary, player: int, index: int, job_id: int) -> bool:
	var p: Dictionary = _get_owned(state, player, index)
	if p.is_empty():
		return false
	for item in p["queue"]:
		if int(item["id"]) != job_id:
			continue
		# Refund the actual prepaid amounts, even if storage is now full.
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
	# The origin population gate was already checked when the job was
	# admitted. A reserved crew cannot be claimed by a new order.
	# Actual resident losses after admission can still postpone embarkation.
	if crew > EPS:
		var slot: int = yard_slot if yard_slot >= 0 else int(item.get("yard_slot", -1))
		var reserve: float = _crew_staff_reserve(p, str(item["kind"]), slot)
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
	if amount <= 0.0:
		return float(item["progress"]) >= float(item["work"]) - EPS
	# All remaining reserved residents embark on the first positive work.
	var crew: float = _remaining_crew(item)
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
	if not has_station(state["planets"][index]):
		return state["map"]["points"][index]
	return colony_station_position(state, index, elapsed)

# Same orbital geometry before and after settlement, with no launch slide.
# Phase is simulation-owned and replicated in the active colonize order
# during assembly, then in the station dictionary until its destruction.
static func colony_station_position(state: Dictionary, index: int, elapsed: float, phase: float = INF) -> Vector2:
	var center: Vector2 = state["map"]["points"][index]
	if not is_finite(phase):
		phase = float(state["planets"][index].get("station", {}).get("orbit_phase", float(index) * 2.399963))
	var axis: Vector2 = Vector2.from_angle(phase + elapsed * 0.008)
	return _colony_orbit_point(state, index, center, axis)

static func _colony_orbit_point(state: Dictionary, index: int, center: Vector2, axis: Vector2) -> Vector2:
	var radius: float = minf(145.0, sector_limit(military_graph(state), index, axis) * 0.5)
	return center + axis * radius

# The nearest radial point on the normal orbit. Re-evaluate from the
# actual hull position so detours never send it to the far side first.
static func colony_approach_position(state: Dictionary, index: int, origin: Vector2) -> Vector2:
	var center: Vector2 = state["map"]["points"][index]
	var axis: Vector2 = center.direction_to(origin)
	if axis.is_zero_approx():
		return colony_station_position(state, index, float(state["elapsed"]))
	return _colony_orbit_point(state, index, center, axis)

static func shipyard_position(state: Dictionary, index: int, slot: int, elapsed: float) -> Vector2:
	return shipyard_port_position(state, index, shipyard_port(state["planets"][index], slot), elapsed)

static func shipyard_port_position(state: Dictionary, index: int, port: int, elapsed: float) -> Vector2:
	var angle: float = float(port - 1) * TAU / 3.0 + elapsed * 0.008
	return station_position(state, index, elapsed) + Vector2.from_angle(angle) * 90.0

static func _rally_path(state: Dictionary, index: int, target: int) -> Array[int]:
	var route: Array[int] = []
	var count: int = state["map"]["points"].size()
	if index < 0 or target < 0 or index >= count or target >= count:
		return route
	route.append(index)
	if index != target:
		route.append(target)
	return route

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
	if ship["kind"] in MILITARY_KINDS:
		ship["direct_order"] = true
		ship["operation_target"] = target
		ship["dest"] = target
		ship.erase("move_only")

static func _work_launch_rally(state: Dictionary, ship: Dictionary, dt: float) -> bool:
	if not ship.has("launch_rally"):
		return false
	var rally: Dictionary = ship["launch_rally"]
	var fighter: bool = ship["kind"] in MILITARY_KINDS
	if fighter and (bool(ship.get("retreating", false)) or _engaged(ship)):
		return false
	# Rally directly to the exact point, even when far from the star.
	ship["route"] = []
	ship["leg"] = 0.0
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
			_launch_finished_hull(state, index, p, item)
			if not bool(item.get("starting_fleet", false)):
				_record_hull_built(state, int(p["owner"]), str(item["kind"]))
	if not SHIP_KINDS.has(item["kind"]) and int(p["owner"]) > 0:
		var progress: Dictionary = objective_progress(state, int(p["owner"]))
		progress["infrastructure_built"] = int(progress.get("infrastructure_built", 0)) + 1
		if item["kind"] == "yard_upgrade" and int(item["level"]) == 2:
			progress["medium_shipyards_completed"] = int(progress.get("medium_shipyards_completed", 0)) + 1
	p["queue"].erase(item)

static func _launch_finished_hull(state: Dictionary, index: int, p: Dictionary, item: Dictionary) -> void:
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
	_register_indexed_hull(state, state["ships"].back())
	_launch_to_rally(state, state["ships"].back(), rally)

static func _record_hull_built(state: Dictionary, owner: int, kind: String) -> void:
	var progress: Dictionary = objective_progress(state, owner)
	if kind == "colony_ship":
		progress["colony_ships_built"] = int(progress.get("colony_ships_built", 0)) + 1
	elif military_hull(kind):
		progress["military_built"] = int(progress.get("military_built", 0)) + 1
		progress["military_investment"] = float(progress.get("military_investment", 0.0)) + float(_cost(kind, 1).get("Metals", 0.0))
		if kind in ["cruiser", "destroyer"]:
			progress["capital_built"] = int(progress.get("capital_built", 0)) + 1
		elif kind == "fighter":
			progress["fighters_built"] = int(progress.get("fighters_built", 0)) + 1
	elif kind == "science_ship":
		progress["science_built"] = int(progress.get("science_built", 0)) + 1
	elif kind in ["miner", "ship"]:
		progress["logistics_built"] = int(progress.get("logistics_built", 0)) + 1

static func cargo_bay_count(kind: String) -> int:
	return FREIGHTER_BAY_COUNT if kind == "ship" else (2 if kind == "miner" else (5 if kind == "colony_ship" else 1))

static func _transfer_bay(entity: Dictionary, resource: String, amount: float, outgoing: bool) -> int:
	if entity.has("stock"):
		var quantity: float = float(entity["stock"].get(resource, 0.0)) + amount * (-0.5 if outgoing else 0.5)
		return clampi(floori(quantity / maxf(EPS, storage_capacity(entity, resource)) * STATION_STORAGE_BAYS), 0, STATION_STORAGE_BAYS - 1)
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
	var scheduled: bool = is_same(state, _deadline_state)
	if scheduled:
		_sync_transfer_deadlines(events)
	var key: String = "%d:%d:%s" % [source_id, target_id, resource]
	if not events.has(key) and events.size() >= TRANSFER_EVENT_LIMIT:
		var evicted: String = events.keys()[0]
		events.erase(evicted)
		if scheduled:
			_transfer_deadlines.cancel(evicted)
	var seq: int = int(state.get("cargo_transfer_seq", 0)) + 1
	state["cargo_transfer_seq"] = seq
	events[key] = {"source": source_id, "target": target_id, "resource": resource, "amount": amount, "from_bay": _transfer_bay(source, resource, amount, true), "to_bay": _transfer_bay(target, resource, amount, false), "elapsed": float(state["elapsed"]), "seq": seq}
	state["cargo_transfers"] = events
	if scheduled:
		_transfer_deadlines.schedule(key, float(state["elapsed"]))

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
		item["delivery_remaining"] = maxf(0.0, float(item["delivery_remaining"]) - dt * _rank_factor(p, "rank_delivery", 0.10))
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
	var remaining: float = dt * _rank_factor(p, "rank_building", 0.10)
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

static func _work_planet(state: Dictionary, index: int, dt: float, basis: Dictionary = {}, census: Dictionary = {}) -> void:
	var p: Dictionary = state["planets"][index]
	if int(p["owner"]) == 0 or not has_station(p):
		return
	p["flows"] = {}
	p["flow_dt"] = dt
	p["crew_rate"] = 0.0
	var before_population: float = float(p["population"])
	var elapsed: float = float(state["elapsed"])
	p["farm_factor"] = 1.0 + FARM_VARIATION * sin(TAU * elapsed / FARM_CYCLE_SECONDS + float(p["farm_phase"]))
	_update_population(p, dt, basis)
	p["demographic_rate"] = (float(p["population"]) - before_population) / maxf(EPS, dt)
	_produce_planet_resources(state, p, dt, basis)
	if not p["queue"].is_empty():
		_work_upgrade_deliveries(state, index, p, dt)
		_work_station_queue(state, index, p, dt)
	_refill_yard_autobuild(state, index, p)
	_refill_continuous(state, index, p, census)
	for category in p.get("pending_spending", {}):
		for material in p["pending_spending"][category]:
			_record_flow(p, str(category), str(material), float(p["pending_spending"][category][material]))
	p.erase("pending_spending")
	# Refills may have created a job this very tick. Only skip assignment
	# and progress queries after they have run; clear stale yard slots.
	if p["queue"].is_empty():
		for yard in p["yards"]:
			yard["job"] = -1
		return
	var assigned: Dictionary = _retain_yard_jobs(p)
	for y in range((p["yards"] as Array).size()):
		if not shipyard_operational(p, y):
			continue
		var yard: Dictionary = p["yards"][y]
		var chosen: Dictionary = _next_yard_job(p, y, yard, assigned)
		if chosen.is_empty():
			yard["job"] = -1
			continue
		var id: int = int(chosen["id"])
		yard["job"] = id
		assigned[id] = true
		var speed: float = 1.0 if chosen["kind"] == "yard_upgrade" else yard_speed(int(yard["level"]))
		if military_hull(str(chosen["kind"])):
			speed *= _rank_factor(p, "rank_assembly", 0.10)
		if _advance(p, chosen, speed * dt, y):
			_finish(state, index, p, chosen)
			yard["job"] = -1

static func _produce_planet_resources(state: Dictionary, p: Dictionary, dt: float, basis: Dictionary = {}) -> void:
	# Only Organics feed residents. Metals and Crystals accumulate up to
	# storage capacity; food production can satisfy demand even at capacity.
	# Refunds may temporarily exceed capacity; never destroy returned materials.
	for resource in ACTIVE_PRODUCTION:
		var capacity: float = storage_capacity(p, resource)
		var stored: float = float(p["stock"][resource])
		var potential: float = rate(p, resource, basis) * dt
		var demand: float = consumption(p, resource) * dt
		var reserve: float = capacity * float(p["thresholds"][resource]["min"]) / 100.0
		var used: float = minf(demand, minf(maxf(0.0, stored), reserve) + potential)
		var produced: float = minf(potential, used + maxf(0.0, capacity - stored))
		_record_flow(p, "Production", resource, produced)
		var progress: Dictionary = objective_progress(state, int(p["owner"]))
		var metric: String = "produced_" + resource.to_lower()
		progress[metric] = float(progress.get(metric, 0.0)) + produced
		_record_flow(p, "Population", resource, used)
		p["stock"][resource] = maxf(0.0, stored + produced - used)

# Preserve active jobs. A started upgrade remains attached to its own yard even if blocked.
static func _retain_yard_jobs(p: Dictionary) -> Dictionary:
	var assigned: Dictionary = {}
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
	return assigned

static func _next_yard_job(p: Dictionary, y: int, yard: Dictionary, assigned: Dictionary) -> Dictionary:
	for item in p["queue"]:
		if int(item["id"]) == int(yard["job"]):
			# Earlier yards may have recruited population this tick.
			if _possible(p, item, y) > EPS:
				return item
			assigned.erase(int(item["id"]))
			yard["job"] = -1
			break
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
			return item
	return {}

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
	return maxf(0.0, storage_capacity(p, resource) * float(p["thresholds"][resource]["min"]) / 100.0 - float(p["stock"][resource]))

static func _surplus(p: Dictionary, resource: String) -> float:
	if not bool(p["thresholds"][resource].get("export", true)):
		return 0.0
	return maxf(0.0, float(p["stock"][resource]) - storage_capacity(p, resource) * float(p["thresholds"][resource]["max"]) / 100.0)

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

# Route arrays retain only origin and final system for existing job bookkeeping.
static func _path(state: Dictionary, teams: Array[int], team: int, a: int, b: int, _cache: Dictionary) -> Array[int]:
	if a < 0 or b < 0 or a >= teams.size() or b >= teams.size() or team <= 0:
		return []
	if state.has("diplomacy"):
		if not _civilian_transit_allowed(state, team, teams[a]) or not _civilian_transit_allowed(state, team, teams[b]):
			return []
	elif teams[a] != team or teams[b] != team:
		return []
	return _rally_path(state, a, b)

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
	# Independent reference rebuild, including callers outside a full step.
	_end_ship_avoidance()
	for id in positions:
		var point: Vector2 = positions[id]
		var cell := Vector2i(floori(point.x / AVOIDANCE_CELL), floori(point.y / AVOIDANCE_CELL))
		if not avoidance_cells.has(cell):
			avoidance_cells[cell] = []
		# Bound worst-case work in dense swarms; contact correction remains soft.
		if avoidance_cells[cell].size() < AVOIDANCE_BUCKET_LIMIT:
			avoidance_cells[cell].append([id, point])

# Detach the active snapshot without destroying retained storage. Movement
# outside the original phase must see the same empty index as before.
static func _end_ship_avoidance() -> void:
	_packed_avoidance_active = false
	avoidance_cells = {}
	_avoidance_neighborhoods = {}

# Rebuild the frozen capped slot view in retained packed storage. No hull
# dictionaries or mutable entry arrays are accessed by steering queries.
static func _begin_persistent_ship_avoidance(_state: Dictionary, positions: Dictionary) -> void:
	_end_ship_avoidance()
	_avoidance_batch.refresh(positions, AVOIDANCE_CELL, AVOIDANCE_BUCKET_LIMIT)
	_packed_avoidance_active = true

# Read-only view of the frozen movement snapshot. Preserve the original
# x/y cell traversal and per-bucket insertion order, including ties.
static func _avoidance_neighborhood(cell: Vector2i) -> Array:
	if _avoidance_neighborhoods.has(cell):
		return _avoidance_neighborhoods[cell]
	var entries: Array = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			entries.append_array(avoidance_cells.get(cell + Vector2i(x, y), []))
	if _avoidance_neighborhoods.size() < AVOIDANCE_NEIGHBORHOOD_LIMIT:
		_avoidance_neighborhoods[cell] = entries
	return entries

static func _avoidance_direction(ship: Dictionary, target: Vector2, budget: float) -> Vector2:
	var before: Vector2 = ship["position"]
	var distance: float = before.distance_to(target)
	var axis: Vector2 = before.direction_to(target)
	if (not _packed_avoidance_active and avoidance_cells.is_empty()) or budget <= EPS or distance <= SHIP_CLEARANCE * 0.5 or bool(ship.get("holding", false)):
		return axis
	var lookahead: float = minf(distance, AVOIDANCE_LOOKAHEAD)
	var cell := Vector2i(floori(before.x / AVOIDANCE_CELL), floori(before.y / AVOIDANCE_CELL))
	if _packed_avoidance_active:
		var packed_blocker: Vector2 = _avoidance_batch.blocker(cell, int(ship["id"]), before, target, axis, lookahead, SHIP_CLEARANCE, EPS)
		return _steer_around_blocker(axis, packed_blocker) if packed_blocker != Vector2.ZERO else axis
	var nearest: float = INF
	var blocker: Vector2 = Vector2.ZERO
	for entry in _avoidance_neighborhood(cell):
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
	return _steer_around_blocker(axis, blocker)

static func _steer_around_blocker(axis: Vector2, blocker: Vector2) -> Vector2:
	# Steer toward a tangent on the open side. A centered head-on contact
	# always passes on the ship's own right; no symmetric stop or hard wall.
	var lateral: float = axis.cross(blocker)
	var side: float = -1.0 if lateral > 1.0 else 1.0
	var tangent: float = asin(clampf(SHIP_CLEARANCE / maxf(SHIP_CLEARANCE, blocker.length()), 0.0, 1.0))
	var turn: float = axis.angle_to(blocker) + side * (tangent + 0.12)
	return axis.rotated(clampf(turn, -PI * 0.42, PI * 0.42))

# The only movement integrator. Orders change targets, never current position.
# Return the distance actually flown so a tick cannot exceed its travel budget.
# Pool bounds are logistics metadata only. Index each surviving rock once
# (and each pulsar exclusion disk). Rebuild only on map/depletion changes.
static func _refresh_movement_fields(fields: Array) -> void:
	var dirty: bool = not is_same(fields, _movement_field_source) or _movement_fields.size() != fields.size()
	if not dirty:
		for i in range(fields.size()):
			if _movement_field_counts[i] != fields[i].get("chunks", []).size():
				dirty = true
				break
	if not dirty:
		return
	# Depletion only removes obstacles; already safe routes remain usable.
	if not is_same(fields, _movement_field_source):
		_rock_routes.clear()
	_movement_field_source = fields
	_movement_fields.clear()
	_movement_field_counts.clear()
	_rock_cells.clear()
	_rock_windows.clear()
	_rock_route_queries.clear()
	_direct_rock_corridors.clear()
	_direct_trajectories.clear()
	for field in fields:
		var center: Vector2 = field["position"]
		var special: bool = bool(field.get("antimatter", false))
		var radius: float = float(field["radius"]) if special else 0.0
		var chunks: Array = field.get("chunks", [])
		_movement_field_counts.append(chunks.size())
		if special:
			_index_rock(center, radius)
		else:
			for rock in chunks:
				var point: Vector2 = rock["position"]
				var rock_radius: float = float(rock.get("radius", 0.0))
				radius = maxf(radius, center.distance_to(point) + rock_radius)
				_index_rock(point, rock_radius)
		_movement_fields.append({"position": center, "radius": radius})

static func _rock_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / ROCK_CELL), floori(point.y / ROCK_CELL))

static func _index_rock(center: Vector2, radius: float) -> void:
	if radius <= EPS:
		return
	var obstacle: Dictionary = {"position": center, "radius": radius}
	var padding: Vector2 = Vector2.ONE * (radius + 64.0)
	var first: Vector2i = _rock_cell(center - padding)
	var last: Vector2i = _rock_cell(center + padding)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			if not _rock_cells.has(cell):
				_rock_cells[cell] = []
			_rock_cells[cell].append(obstacle)

static func _rocks_near(a: Vector2, b: Vector2) -> Array:
	var first: Vector2i = _rock_cell(a.min(b))
	var last: Vector2i = _rock_cell(a.max(b))
	if first == last:
		return _rock_cells.get(first, [])
	# Exact cell bounds, not rounded trajectories. Nearby ships can share
	# the same candidates while retaining individual swept geometry tests.
	var key := Vector4i(first.x, first.y, last.x, last.y)
	if _rock_windows.has(key):
		return _rock_windows[key]
	var result: Array = _collect_rock_window(first, last)
	# Bound retained memory; large or crowded requests use the same fallback.
	if _rock_windows.size() < ROCK_WINDOW_CACHE_LIMIT and last.x - first.x <= 8 and last.y - first.y <= 8 and result.size() <= 256:
		_rock_windows[key] = result
	return result

static func _collect_rock_window(first: Vector2i, last: Vector2i) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			for obstacle in _rock_cells.get(Vector2i(x, y), []):
				var key: Vector2 = obstacle["position"]
				if not seen.has(key):
					seen[key] = true
					result.append(obstacle)
	return result

static func _point_clear_of_rocks(point: Vector2, clearance: float = ROCK_PREFERRED_CLEARANCE) -> bool:
	for obstacle in _rock_cells.get(_rock_cell(point), []):
		if point.distance_squared_to(obstacle["position"]) < pow(float(obstacle["radius"]) + clearance, 2.0):
			return false
	return true

# Swept preferred-clearance test. The final short leg can deliberately
# use the tighter physical margin for precise destinations and docking.
static func _rock_segment_clear(before: Vector2, after: Vector2, clearance: float) -> bool:
	for rock in _rocks_near(before, after):
		var center: Vector2 = rock["position"]
		var radius: float = float(rock["radius"]) + clearance
		if Geometry2D.get_closest_point_to_segment(center, before, after).distance_squared_to(center) < radius * radius:
			return false
	return true

# Find a clear local route around several obstacles together. Build this
# bounded search only when the short direct leg is obstructed; cache the
# resulting waypoints rather than rebuilding a grid every movement tick.
static func _plan_rock_route(before: Vector2, target: Vector2, clearance: float) -> Array:
	# The search grid is centered on the exact start. Only identical
	# endpoints and clearance may share a computed route; the caller still
	# consumes its original planning slot and owns its waypoint array.
	var key := Vector4(before.x, before.y, target.x, target.y)
	var by_clearance: Dictionary = _rock_route_queries.get(key, {})
	if by_clearance.has(clearance):
		return (by_clearance[clearance] as Array).duplicate()
	var route: Array = _compute_rock_route(before, target, clearance)
	if _rock_route_queries.size() < ROCK_PLAN_LIMIT * 2:
		by_clearance[clearance] = route.duplicate()
		_rock_route_queries[key] = by_clearance
	return route

static func _compute_rock_route(before: Vector2, target: Vector2, clearance: float) -> Array:
	var half: int = ROCK_ROUTE_HALF
	var grid: AStarGrid2D = _rock_route_grid(before, clearance)
	var goal: Vector2 = (target - before) / ROCK_ROUTE_CELL
	var limit: float = float(half - 1)
	goal *= minf(1.0, limit / maxf(1.0, maxf(absf(goal.x), absf(goal.y))))
	var start: Vector2i = _rock_route_start(grid, before)
	if start == ROCK_ROUTE_NO_CELL:
		return []
	var goal_id: Vector2i = _rock_route_goal(grid, goal, half)
	if goal_id == ROCK_ROUTE_NO_CELL:
		return []
	var ids: Array[Vector2i] = grid.get_id_path(start, goal_id, false)
	if ids.is_empty():
		return []
	return _compact_rock_route(grid, ids, before, start, clearance)

static func _rock_route_grid(before: Vector2, clearance: float) -> AStarGrid2D:
	var half: int = ROCK_ROUTE_HALF
	var region := Rect2i(Vector2i(-half, -half), Vector2i(half * 2 + 1, half * 2 + 1))
	var grid := AStarGrid2D.new()
	grid.region = region
	grid.cell_size = Vector2.ONE * ROCK_ROUTE_CELL
	grid.offset = before
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var extent: Vector2 = Vector2.ONE * float(half) * ROCK_ROUTE_CELL
	# Rasterize only nearby rock disks; no full-map path search.
	for rock in _rocks_near(before - extent, before + extent):
		var center: Vector2 = rock["position"]
		var radius: float = float(rock["radius"]) + clearance
		var local: Vector2 = (center - before) / ROCK_ROUTE_CELL
		var reach: float = radius / ROCK_ROUTE_CELL
		var first: Vector2i = Vector2i((local - Vector2.ONE * reach).floor()).max(region.position)
		var last: Vector2i = Vector2i((local + Vector2.ONE * reach).ceil()).min(region.end - Vector2i.ONE)
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var cell := Vector2i(x, y)
				if (before + Vector2(cell) * ROCK_ROUTE_CELL).distance_squared_to(center) < radius * radius:
					grid.set_point_solid(cell)
	return grid

# Choose a nearby reachable start if contact or a narrow gap has put
# the hull inside the preferred margin. Actual movement stays swept.
static func _rock_route_start(grid: AStarGrid2D, before: Vector2) -> Vector2i:
	var start := Vector2i.ZERO
	if not grid.is_point_solid(start):
		return start
	var closest: float = INF
	for y in range(-4, 5):
		for x in range(-4, 5):
			var cell := Vector2i(x, y)
			if grid.is_point_solid(cell):
				continue
			var point: Vector2 = grid.get_point_position(cell)
			var distance: float = Vector2(cell).length_squared()
			if distance < closest and _clip_rock_step(before, point).is_equal_approx(point):
				start = cell
				closest = distance
	return ROCK_ROUTE_NO_CELL if closest == INF else start

# Select the closest open grid point to the requested endpoint.
static func _rock_route_goal(grid: AStarGrid2D, goal: Vector2, half: int) -> Vector2i:
	var goal_id := Vector2i(goal.round())
	if not grid.is_point_solid(goal_id):
		return goal_id
	var original_goal: Vector2i = goal_id
	var closest: float = INF
	for y in range(maxi(-half, original_goal.y - 6), mini(half, original_goal.y + 6) + 1):
		for x in range(maxi(-half, original_goal.x - 6), mini(half, original_goal.x + 6) + 1):
			var cell := Vector2i(x, y)
			var distance: float = (Vector2(cell) - goal).length_squared()
			if not grid.is_point_solid(cell) and distance < closest:
				goal_id = cell
				closest = distance
	return ROCK_ROUTE_NO_CELL if closest == INF else goal_id

# Compact the route using actual swept geometry rather than walking
# cell-by-cell; never shortcut across a rock.
static func _compact_rock_route(grid: AStarGrid2D, ids: Array[Vector2i], before: Vector2, start: Vector2i, clearance: float) -> Array:
	var route: Array = []
	if start != Vector2i.ZERO:
		route.append(grid.get_point_position(start))
	var anchor: Vector2 = before if route.is_empty() else route.back()
	var next: int = 1
	while next < ids.size():
		var farthest: int = next
		for j in range(next + 1, ids.size()):
			if not _rock_segment_clear(anchor, grid.get_point_position(ids[j]), clearance):
				break
			farthest = j
		var point: Vector2 = grid.get_point_position(ids[farthest])
		if not _clip_rock_step(anchor, point).is_equal_approx(point):
			return []
		route.append(point)
		anchor = point
		next = farthest + 1
	return route

# Cheap bounded steering for fleets waiting for a planning slot or
# starting in an extremely tight pocket. Try both sides, not one tangent.
static func _rock_steering(before: Vector2, target: Vector2, budget: float) -> Vector2:
	var axis: Vector2 = before.direction_to(target)
	var reach: float = maxf(budget, 48.0)
	var best: Vector2 = before
	var best_score: float = -INF
	for angle in [0.0, 0.35, -0.35, 0.7, -0.7, 1.05, -1.05, 1.57, -1.57, 2.1, -2.1, 2.7, -2.7, PI]:
		var direction: Vector2 = axis.rotated(float(angle))
		var candidate: Vector2 = _clip_rock_step(before, before + direction * reach)
		var distance: float = before.distance_to(candidate)
		if distance <= EPS:
			continue
		var score: float = distance * (0.85 + 0.15 * direction.dot(axis)) - absf(float(angle)) * 4.0
		if _rock_segment_clear(before, candidate, ROCK_PREFERRED_CLEARANCE):
			score += 16.0
		if score > best_score:
			best_score = score
			best = candidate
	return best

static func _field_detour(before: Vector2, target: Vector2, budget: float, ship_id: int = -1) -> Vector2:
	if _rock_cells.is_empty() or before.is_equal_approx(target) or budget <= EPS:
		return target
	var cached: Dictionary = _rock_routes.get(ship_id, {}) if ship_id >= 0 else {}
	if not cached.is_empty() and (cached["target"] as Vector2).distance_to(target) > 96.0:
		_rock_routes.erase(ship_id)
		cached = {}
	var route: Array = cached.get("route", [])
	while not route.is_empty() and before.distance_to(route.front()) <= EPS:
		route.pop_front()
	if not route.is_empty():
		var waypoint: Vector2 = route.front()
		if _clip_rock_step(before, waypoint).is_equal_approx(waypoint):
			return waypoint
		route.clear()
	# Start steering earlier; if the destination is in a narrow but
	# physically accessible gap, allow the precise final approach.
	var end: Vector2 = before.move_toward(target, maxf(budget + 96.0, 240.0))
	var clearance: float = ROCK_HARD_CLEARANCE if before.distance_to(target) <= 96.0 and not _point_clear_of_rocks(target) else ROCK_PREFERRED_CLEARANCE
	if _rock_segment_clear(before, end, clearance):
		_rock_routes.erase(ship_id)
		return target
	if ship_id < 0 or (_rock_plan_budget > 0 and _rock_plan_tick >= int(cached.get("retry", 0))):
		if ship_id >= 0:
			_rock_plan_budget -= 1
		route = _plan_rock_route(before, target, clearance + 8.0)
		if route.is_empty():
			route = _plan_rock_route(before, target, ROCK_HARD_CLEARANCE + 4.0)
		if ship_id >= 0:
			if _rock_routes.size() >= 20000:
				_rock_routes.clear()
			_rock_routes[ship_id] = {"target": target, "route": route, "retry": _rock_plan_tick + 12}
		if not route.is_empty():
			return route.front()
	return _rock_steering(before, target, budget)

# Sweep the actual step, including ship-avoidance steering, so large ticks
# cannot tunnel through a rock. Allow an overlapping hull to move outward.
static func _clip_rock_step(before: Vector2, after: Vector2) -> Vector2:
	var allowed: float = 1.0
	var delta: Vector2 = after - before
	if delta.length_squared() <= EPS * EPS:
		return after
	var overlapping: Array = []
	for obstacle in _rocks_near(before, after):
		var center: Vector2 = obstacle["position"]
		var radius: float = float(obstacle["radius"]) + ROCK_HARD_CLEARANCE
		var relative: Vector2 = before - center
		if relative.length_squared() < radius * radius:
			overlapping.append(obstacle)
			continue
		var hit: float = Geometry2D.segment_intersects_circle(before, after, center, radius)
		if hit >= 0.0:
			allowed = minf(allowed, maxf(0.0, hit - 0.01 / delta.length()))
	var candidate: Vector2 = before.lerp(after, allowed)
	# If the hull begins inside several conservative disks (e.g. at a
	# launch or contact correction), permit escape without entering new
	# disks. Requiring outward motion relative to every center can trap it.
	if overlapping.size() == 1:
		if (before - (overlapping[0]["position"] as Vector2)).dot(candidate - before) < 0.0:
			return before
	elif overlapping.size() > 1:
		# Compare at a short first step so a long sweep cannot tunnel
		# through an existing overlap just because its endpoint is clear.
		var probe: Vector2 = before.move_toward(candidate, 8.0)
		var old_depth: float = 0.0
		var new_depth: float = 0.0
		for obstacle in overlapping:
			var center: Vector2 = obstacle["position"]
			var radius: float = float(obstacle["radius"]) + ROCK_HARD_CLEARANCE
			old_depth += maxf(0.0, radius - before.distance_to(center))
			new_depth += maxf(0.0, radius - probe.distance_to(center))
		if new_depth >= old_depth:
			return before
		return probe
	return candidate

# A direct segment is legal only if the existing frozen avoidance
# neighborhood contains no other hull that could change its steering.
# The subsequent separation/contact passes still run for every ship.
static func _direct_hull_corridor_clear(ship: Dictionary, before: Vector2) -> bool:
	if bool(ship.get("holding", false)):
		return true
	var cell := Vector2i(floori(before.x / AVOIDANCE_CELL), floori(before.y / AVOIDANCE_CELL))
	if _packed_avoidance_active:
		return _avoidance_batch.clear_corridor(cell, int(ship.get("id", -1)))
	if avoidance_cells.is_empty():
		return true
	var entries: Array = _avoidance_neighborhood(cell)
	return entries.is_empty() or (entries.size() == 1 and int(entries[0][0]) == int(ship.get("id", -1)))

# Prove a bounded cell rectangle has no indexed obstacles. The certificate
# covers the full original lookahead and the actual step (not just its end).
# It remains valid until the existing obstacle-index refresh, and may be
# reused on later samples or changed commands only when fully contained.
static func _direct_rock_corridor_clear(id: int, before: Vector2, target: Vector2, after: Vector2, budget: float) -> bool:
	if id < 0 or _rock_routes.has(id) or budget <= EPS or before.is_equal_approx(target):
		return false
	var end: Vector2 = before.move_toward(target, maxf(budget + 96.0, 240.0))
	var first: Vector2i = _rock_cell(before.min(end).min(after))
	var last: Vector2i = _rock_cell(before.max(end).max(after))
	if _direct_rock_corridors.has(id):
		var known: Rect2i = _direct_rock_corridors[id]
		if known.has_point(first) and known.has_point(last):
			return true
	# Predict a longer obstacle-free corridor, but never reject a clear
	# short step solely because there may be an obstacle further ahead.
	var far_end: Vector2 = before.move_toward(target, maxf(budget + 96.0, DIRECT_CORRIDOR_LOOKAHEAD))
	var far_first: Vector2i = _rock_cell(before.min(far_end)).min(first)
	var far_last: Vector2i = _rock_cell(before.max(far_end)).max(last)
	if far_last.x - far_first.x <= 8 and far_last.y - far_first.y <= 8 and _empty_rock_rectangle(far_first, far_last):
		if _direct_rock_corridors.size() < DIRECT_CORRIDOR_LIMIT or _direct_rock_corridors.has(id):
			_direct_rock_corridors[id] = Rect2i(far_first, far_last - far_first + Vector2i.ONE)
		return true
	return false

static func _empty_rock_rectangle(first: Vector2i, last: Vector2i) -> bool:
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if _rock_cells.has(Vector2i(x, y)):
				return false
	return true

# A fixed-step cardinal leg on a bounded binary lattice admits exact
# absolute-tick evaluation. All coordinates on the moving axis are exact
# float32 values; a separation of at most 4096 lattice units has an exact
# squared length, so the original move_toward direction is exactly +/-1.
# Other directions/budgets must keep the incremental reference arithmetic.
static func _new_direct_trajectory(before: Vector2, target: Vector2, budget: float, tick: int) -> Dictionary:
	if budget <= EPS or before == target or (before.x != target.x and before.y != target.y):
		return {}
	var horizontal: bool = before.y == target.y
	var start_axis: float = before.x if horizontal else before.y
	var end_axis: float = target.x if horizontal else target.y
	for scale in [1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 64.0, 128.0, 256.0]:
		var start_units: float = start_axis * scale
		var end_units: float = end_axis * scale
		var step_units: float = budget * scale
		var span: float = absf(end_units - start_units)
		if maxf(absf(start_units), absf(end_units)) > 4194304.0 or span > 4096.0:
			break
		if step_units >= span:
			return {}
		if start_units != floorf(start_units) or end_units != floorf(end_units) or step_units != floorf(step_units) or step_units < 1.0:
			continue
		return {"target": target, "budget": budget, "horizontal": horizontal, "scale": scale, "origin_units": int(start_units), "span": int(span), "step_units": int(step_units), "sign": 1 if end_units > start_units else -1, "anchor_tick": tick, "last_tick": tick - 1, "last_position": before}
	return {}

# A command/speed change, skipped or duplicate movement tick, or any
# displacement from contact, warp or another movement phase reanchors
# at the live pose. An obstacle always discards the prediction.
static func _direct_trajectory_sample(id: int, before: Vector2, target: Vector2, budget: float, tick: int) -> Variant:
	if tick < 0 or id < 0:
		return null
	if before.x != target.x and before.y != target.y:
		_direct_trajectories.erase(id)
		return null
	var record: Dictionary = _direct_trajectories.get(id, {})
	if not record.is_empty() and (record.has("samples") or record["last_tick"] != tick - 1 or record["last_position"] != before or record["target"] != target or record["budget"] != budget):
		_direct_trajectories.erase(id)
		record = {}
	if record.is_empty():
		if _direct_trajectories.size() >= DIRECT_CORRIDOR_LIMIT:
			return null
		record = _new_direct_trajectory(before, target, budget, tick)
		if record.is_empty():
			return null
		_direct_trajectories[id] = record
	var advance: int = mini(int(record["span"]), int(record["step_units"]) * (tick - int(record["anchor_tick"]) + 1))
	var coordinate: float = float(int(record["origin_units"]) + int(record["sign"]) * advance) / float(record["scale"])
	var after: Vector2 = before
	if bool(record["horizontal"]):
		after.x = coordinate
	else:
		after.y = coordinate
	if after == target:
		_direct_trajectories.erase(id)
	else:
		record["last_tick"] = tick
		record["last_position"] = after
	return after

# General-angle motion cannot safely use origin + velocity * ticks:
# repeated Vector2 rounding is part of the authoritative integrator.
# Instead, certify a short sequence of its exact future empty-sweep samples.
# Only try inside an existing broad rock certificate. If the *entire*
# remaining destination is enclosed, all lookaheads and swept steps are
# enclosed too. Otherwise require a conservative bound around the window.
# The samples are indexed by absolute tick; no gameplay step is skipped.
static func _new_direct_window(id: int, before: Vector2, target: Vector2, budget: float, tick: int) -> Dictionary:
	if budget <= EPS or budget > DIRECT_CORRIDOR_LOOKAHEAD / float(DIRECT_WINDOW_STEPS) or before.is_equal_approx(target) or not _direct_rock_corridors.has(id) or _rock_routes.has(id):
		return {}
	var known: Rect2i = _direct_rock_corridors[id]
	# Bound work and avoid speculative samples near an uncertified edge.
	# The exact per-sample cell check below remains the final proof.
	var reach: float = budget * DIRECT_WINDOW_STEPS + maxf(budget + 96.0, 240.0)
	var extent := Vector2.ONE * reach
	var lower: Vector2 = before.min(target).max(before - extent)
	var upper: Vector2 = before.max(target).min(before + extent)
	if not known.has_point(_rock_cell(lower)) or not known.has_point(_rock_cell(upper)):
		return {}
	var samples := PackedVector2Array()
	var cursor: Vector2 = before
	for index in range(DIRECT_WINDOW_STEPS):
		# _field_detour does not consult rocks at approximate arrival, but
		# the normal sweep still does. Let the ordinary path handle it.
		if cursor.is_equal_approx(target):
			break
		var lookahead: Vector2 = cursor.move_toward(target, maxf(budget + 96.0, 240.0))
		var after: Vector2 = cursor.move_toward(target, budget)
		var first: Vector2i = _rock_cell(cursor.min(lookahead).min(after))
		var last: Vector2i = _rock_cell(cursor.max(lookahead).max(after))
		if not known.has_point(first) or not known.has_point(last):
			break
		if (after - cursor).length_squared() > EPS * EPS:
			after = cursor.lerp(after, 1.0)
		if after == cursor:
			break
		samples.append(after)
		cursor = after
		if cursor == target:
			break
	# Avoid retaining a prediction that cannot be reused.
	if samples.size() < 2:
		return {}
	return {"samples": samples, "target": target, "budget": budget, "anchor_tick": tick, "last_tick": tick - 1, "last_position": before}

static func _direct_window_sample(id: int, before: Vector2, target: Vector2, budget: float, tick: int) -> Variant:
	if id < 0 or tick < 0:
		return null
	var record: Dictionary = _direct_trajectories.get(id, {})
	if not record.is_empty() and (not record.has("samples") or record["last_tick"] != tick - 1 or record["last_position"] != before or record["target"] != target or record["budget"] != budget or _rock_routes.has(id) or not _direct_rock_corridors.has(id)):
		_direct_trajectories.erase(id)
		record = {}
	if record.is_empty():
		if _direct_trajectories.size() >= DIRECT_CORRIDOR_LIMIT:
			return null
		record = _new_direct_window(id, before, target, budget, tick)
		if record.is_empty():
			return null
		_direct_trajectories[id] = record
	var samples: PackedVector2Array = record["samples"]
	var index: int = tick - int(record["anchor_tick"])
	if index < 0 or index >= samples.size():
		_direct_trajectories.erase(id)
		return null
	var after: Vector2 = samples[index]
	if index + 1 == samples.size() or after == target:
		_direct_trajectories.erase(id)
	else:
		record["last_tick"] = tick
		record["last_position"] = after
	return after

static func _direct_motion_sample(ship: Dictionary, before: Vector2, target: Vector2, budget: float, avoid_rocks: bool) -> Variant:
	var id: int = int(ship.get("id", -1))
	if not before.is_finite() or not target.is_finite() or not is_finite(budget) or budget < 0.0:
		_direct_trajectories.erase(id)
		return null
	if not _direct_hull_corridor_clear(ship, before):
		_direct_trajectories.erase(id)
		return null
	# General-angle windows already include the exact empty-rock sweep.
	# The live hull-neighborhood guard above must pass on every sample.
	if avoid_rocks and before.x != target.x and before.y != target.y:
		var window_sample: Variant = _direct_window_sample(id, before, target, budget, _trajectory_tick)
		if window_sample != null:
			return window_sample
	var predicted: Variant = _direct_trajectory_sample(id, before, target, budget, _trajectory_tick)
	var after: Vector2 = before.move_toward(target, budget) if predicted == null else predicted
	if avoid_rocks:
		if not _direct_rock_corridor_clear(id, before, target, after, budget):
			_direct_trajectories.erase(id)
			return null
		# Preserve the exact empty-sweep interpolation used by _clip_rock_step.
		if (after - before).length_squared() > EPS * EPS:
			after = before.lerp(after, 1.0)
	return after

static func _navigate(ship: Dictionary, target: Vector2, budget: float, direct_fast_path: bool = true) -> float:
	ship["navigation_target"] = target
	var before: Vector2 = ship["position"]
	var avoid_rocks: bool = ship.get("kind", "") != "miner" and not _rock_cells.is_empty()
	if direct_fast_path:
		var sample: Variant = _direct_motion_sample(ship, before, target, budget, avoid_rocks)
		if sample != null:
			return _commit_motion_sample(ship, before, sample)
	if avoid_rocks:
		target = _field_detour(before, target, budget, int(ship.get("id", -1)))
	var direct: Vector2 = before.direction_to(target)
	# Do not steer away from a planned safe corridor to dodge a hull.
	var steering: Vector2 = direct if not target.is_equal_approx(ship["navigation_target"]) else _avoidance_direction(ship, target, budget)
	var after: Vector2 = before.move_toward(target, maxf(0.0, budget))
	if not steering.is_equal_approx(direct):
		var steered: Vector2 = before + steering * minf(maxf(0.0, budget), before.distance_to(target))
		if not avoid_rocks or _clip_rock_step(before, steered).is_equal_approx(steered):
			after = steered
	if avoid_rocks:
		after = _clip_rock_step(before, after)
	return _commit_motion_sample(ship, before, after)

static func _commit_motion_sample(ship: Dictionary, before: Vector2, after: Vector2) -> float:
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
			elif ship.get("kind", "") not in MILITARY_KINDS and (int(ship.get("source", -1)) == node or int(ship.get("dest", -1)) == node or ship.get("mining_mode", "") == "approach"):
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
	if dock_required and ship.get("kind", "") not in MILITARY_KINDS:
		var dock: Vector2 = explicit_dock if explicit_dock.is_finite() and here == dock_index else _service_point(state, ship, here)
		var endpoint: Vector2 = _waiting_berth(state, ship, dock, dock_range, dock.direction_to(ship["position"])) if dock_range > EPS and (explicit_dock.is_finite() or (state.has("planets") and has_station(state["planets"][here]))) else dock
		_navigate(ship, endpoint, distance)
		return (ship["position"] as Vector2).distance_to(dock) <= (dock_range if explicit_dock.is_finite() or (state.has("planets") and has_station(state["planets"][here])) else 0.0) + EPS
	return true

# Live stock preflight: one resource-mask pass over the stations, before
# counting assigned freighters or evaluating routes. Do not cache across hulls:
# another hull may have loaded or unloaded since the preceding search.
static func _trade_opportunity_masks(planets: Array, teams: Array[int], team: int) -> Dictionary:
	var sources: Dictionary = {}
	var destinations: Dictionary = {}
	var earlier_sources: int = 0
	var earlier_destinations: int = 0
	var possible: bool = false
	for node in range(planets.size()):
		if teams[node] != team:
			continue
		var source_mask: int = 0
		var destination_mask: int = 0
		for resource_index in range(RESOURCES.size()):
			var resource: String = RESOURCES[resource_index]
			if _surplus(planets[node], resource) > EPS:
				source_mask |= 1 << resource_index
			if _need(planets[node], resource) > EPS:
				destination_mask |= 1 << resource_index
		if source_mask != 0:
			sources[node] = source_mask
		if destination_mask != 0:
			destinations[node] = destination_mask
		# Different stations only; matching masks at one node cannot create a job.
		if (source_mask & earlier_destinations) != 0 or (destination_mask & earlier_sources) != 0:
			possible = true
		earlier_sources |= source_mask
		earlier_destinations |= destination_mask
	return {"sources": sources, "destinations": destinations, "possible": possible}

static func _choose_delivery(state: Dictionary, ship: Dictionary, teams: Array[int], team: int, cache: Dictionary, activity_fast_paths: bool = true) -> void:
	var planets: Array = state["planets"]
	var here: int = int(ship["at"])
	var source_nodes: Array = range(planets.size())
	var destination_nodes: Array = source_nodes
	var source_masks: Dictionary = {}
	var destination_masks: Dictionary = {}
	if activity_fast_paths:
		var opportunities: Dictionary = _trade_opportunity_masks(planets, teams, team)
		if not bool(opportunities["possible"]):
			return
		source_masks = opportunities["sources"]
		destination_masks = opportunities["destinations"]
		source_nodes = source_masks.keys()
		destination_nodes = destination_masks.keys()
	var best: float = INF
	var best_source: int = -1
	var best_dest: int = -1
	var best_path: Array[int] = []
	var assigned_routes: Dictionary = {}
	for craft in state["ships"]:
		if int(craft["id"]) == int(ship["id"]) or craft.get("kind", "") != "ship" or int(craft.get("source", -1)) < 0:
			continue
		var key := Vector2i(int(craft["source"]), int(craft.get("dest", -1)))
		assigned_routes[key] = int(assigned_routes.get(key, 0)) + 1
	for a in source_nodes:
		if teams[a] != team:
			continue
		var first: Array[int] = _path(state, teams, team, here, a, cache)
		if first.is_empty():
			continue
		var first_length: float = (ship["position"] as Vector2).distance_to(station_position(state, a, float(state["elapsed"])))
		for b in destination_nodes:
			if a == b or teams[b] != team:
				continue
			# Masks are computed from the same predicates as _opportunity,
			# in original station order. The reference path retains the old scan.
			if activity_fast_paths:
				if (int(source_masks[a]) & int(destination_masks[b])) == 0:
					continue
			elif not _opportunity(planets[a], planets[b]):
				continue
			var second: Array[int] = _path(state, teams, team, a, b, cache)
			var distance: float = first_length + station_position(state, a, float(state["elapsed"])).distance_to(station_position(state, b, float(state["elapsed"])))
			# Prefer unserved routes over another freighter racing for the same stock.
			distance *= 1.0 + float(assigned_routes.get(Vector2i(a, b), 0))
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
		var distance: float = (ship["position"] as Vector2).distance_to(station_position(state, i, float(state["elapsed"])))
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
	var stage: Dictionary = ship.get("resource_stage", {})
	if not stage.is_empty() and not bool(stage.get("salvage_site", false)):
		ship["resource_haul_node"] = int(stage["node"])
	_clear_resource_stage(ship)
	if _cargo_total(ship) > EPS:
		ship["resource_haul"] = true
		ship["salvage_delivery"] = true
		ship.erase("salvage_depot")
		ship.erase("next_salvage_search")

# Returning workers retain their previous field only while close enough to
# assist; do not chase them across the map or reserve inactive mining sites.
static func _stage_worker_field(miner: Dictionary, owner: int) -> int:
	if int(miner["owner"]) != owner or miner.get("kind", "") != "miner" or bool(miner.get("holding", false)) or bool(miner.get("retreating", false)) or _engaged(miner) or miner.has("repair_order") or miner.has("repair_target"):
		return -1
	var mode: String = str(miner.get("mining_mode", ""))
	if mode in ["approach", "outbound", "mining", "return"]:
		return int(miner.get("field", -1))
	if mode == "delivery" and _cargo_total(miner) > EPS:
		var field_index: int = int(miner.get("last_mining_field", -1))
		if field_index >= 0 and field_index < _movement_fields.size():
			var field: Dictionary = _movement_fields[field_index]
			if (miner["position"] as Vector2).distance_to(field["position"]) <= float(field["radius"]) + RESOURCE_HANDOFF_RANGE * 2.0:
				return field_index
	return -1

static func _stage_wait_point(state: Dictionary, graph: Dictionary, ship: Dictionary, miner: Dictionary, node: int, anchor: int, teams: Array[int], cache: Dictionary, threats: Dictionary) -> Vector2:
	var field_index: int = node - state["planets"].size()
	var rock: Vector2 = miner.get("mining_target", miner["position"])
	if miner.get("mining_mode", "") in ["return", "delivery"] and _cargo_total(miner) > EPS:
		rock = miner["position"]
	var depot: int = int(miner.get("dest", -1)) if miner.get("mining_mode", "") == "delivery" else -1
	if depot < 0:
		var chunk: Dictionary = _find_chunk(state["map"]["fields"][field_index], int(miner.get("chunk", -1)))
		var resource: String = str(chunk.get("resource", "Metals"))
		for carried in RESOURCES + [ANTIMATTER]:
			if float(miner["cargo"].get(carried, 0.0)) > EPS:
				resource = carried
				break
		depot = _mining_depot(state, miner, teams, _combat_group(state, int(ship["owner"])), anchor, resource, cache, rock)
	if depot < 0:
		return Vector2.INF
	var toward: Vector2 = rock.direction_to(station_position(state, depot, float(state["elapsed"])))
	if toward.is_zero_approx():
		toward = Vector2.RIGHT
	var offset: Vector2 = rock + toward * RESOURCE_HANDOFF_RANGE * 0.65
	# Find a nearby clear berth along the real depot direction, rather than
	# forcing the Freighter outside an invisible belt.
	for attempt in range(5):
		if _point_clear_of_rocks(offset):
			break
		offset = rock + toward * (RESOURCE_HANDOFF_RANGE * 0.65 + 40.0 * float(attempt + 1))
	if not _point_clear_of_rocks(offset):
		return Vector2.INF
	if _salvage_safe(state, graph, int(ship["owner"]), offset, node, threats):
		return offset
	return Vector2.INF

# Estimate the time until the worker can offer another load. Already
# carried ore is immediately useful, including a returning worker.
static func _mining_pickup_eta(miner: Dictionary, freighter_position: Vector2, berth: Vector2) -> float:
	var travel: float = freighter_position.distance_to(berth) / FREIGHTER_SPEED
	var ready: float = 0.0
	if _cargo_total(miner) < MINER_CAPACITY * 0.5 and not (miner.get("mining_mode", "") in ["return", "delivery"] and _cargo_total(miner) > EPS):
		ready = (MINER_CAPACITY * 0.5 - _cargo_total(miner)) / maxf(EPS, MINER_RATE)
		if miner.get("mining_mode", "") in ["approach", "outbound"]:
			ready += (miner["position"] as Vector2).distance_to(miner.get("mining_target", miner["position"])) / MINER_SPEED
	return maxf(travel, ready) + 0.5

# A long return journey justifies waiting longer for an additional load.
# Cap the wait even at very remote sites; low supply must not strand cargo.
static func _mining_idle_limit(depot_distance: float, cargo: float) -> float:
	var round_trip: float = 2.0 * depot_distance / FREIGHTER_SPEED
	return clampf(RESOURCE_PARTIAL_WAIT_YEARS + round_trip * 0.25 * (1.0 - clampf(cargo / CARGO_CAPACITY, 0.0, 1.0)), RESOURCE_PARTIAL_WAIT_YEARS, RESOURCE_MAX_IDLE_YEARS)

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
	var distance: float = (ship["position"] as Vector2).distance_to(point)
	return {"node": node, "anchor": anchor, "point": point, "path": path, "score": distance / maxf(1.0, demand)}

# One receiving berth plus the estimated number of holds in transit.
# Use conservative extraction estimates and the actual depot distance;
# do not allocate indefinitely just because a site has active workers.
static func _stage_freighter_limit(worker_count: int, depot_distance: float) -> int:
	if worker_count <= 0:
		return 0
	var throughput: float = float(worker_count) * minf(MINER_RATE, MINER_CAPACITY / MINING_STAY)
	var cycle: float = 2.0 * depot_distance / FREIGHTER_SPEED + CARGO_CAPACITY / dropoff_rate("ship") + RESOURCE_PARTIAL_WAIT_YEARS
	return maxi(1, ceili(throughput * cycle / CARGO_CAPACITY) + 1)

static func _stage_queue(state: Dictionary, ship: Dictionary, node: int) -> Array:
	var waiting: Array = []
	for craft in state["ships"]:
		var stage: Dictionary = craft.get("resource_stage", {})
		if int(craft["owner"]) == int(ship["owner"]) and int(stage.get("node", -1)) == node and not bool(stage.get("salvage_site", false)):
			waiting.append(craft)
	waiting.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var first: float = float(a["resource_stage"].get("queued_at", 0.0))
		var second: float = float(b["resource_stage"].get("queued_at", 0.0))
		return int(a["id"]) < int(b["id"]) if first == second else first < second)
	return waiting

static func _stage_queue_position(berth: Vector2, center: Vector2, rank: int) -> Vector2:
	var outward: Vector2 = center.direction_to(berth)
	if outward.is_zero_approx():
		outward = Vector2.RIGHT
	# Tangential arrival lane, with a slight outward slope. Loaded ships
	# depart directly toward their depot instead of reversing along the line.
	return berth + (outward.orthogonal() + outward * 0.25).normalized() * RESOURCE_QUEUE_SPACING * float(rank)

static func _choose_resource_stage(state: Dictionary, graph: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, threats: Dictionary, cells: Dictionary, mining_only: bool = false, excluded_node: int = -1, max_pickup_years: float = INF) -> bool:
	var owner: int = int(ship["owner"])
	var fields: Array = state["map"].get("fields", [])
	_refresh_movement_fields(fields)
	# With neither a mining field nor an indexed salvage site, no stage
	# can be assigned. Preserve the obstacle refresh at its old boundary.
	if fields.is_empty() and (mining_only or cells.is_empty() or state.get("salvage", {}).is_empty()):
		return false
	var census: Dictionary = _stage_census(state, ship, owner)
	var workers: Dictionary = census["workers"]
	var occupied: Dictionary = census["occupied"]
	var result: Array = _best_mining_stage(state, graph, ship, teams, cache, threats, workers, occupied, excluded_node, max_pickup_years)
	if not mining_only:
		result = _best_salvage_stage(state, graph, ship, teams, cache, threats, cells, occupied, result)
	var best: Dictionary = result[0]
	if best.is_empty():
		return false
	best.erase("path")
	best.erase("score")
	best["queued_at"] = float(state["elapsed"])
	if not bool(best.get("salvage_site", false)):
		var waiting: Array = _stage_queue(state, ship, int(best["node"]))
		best["queue_rank"] = waiting.size()
		if not waiting.is_empty():
			best["point"] = waiting[0]["resource_stage"]["point"]
	ship["resource_stage"] = best
	ship["source"] = -1
	ship["dest"] = -1
	ship["route"] = []
	ship["leg"] = 0.0
	ship["navigation_target"] = best["point"]
	return true

# Same-owner stage/haul occupancy per node and active mining workers per field.
static func _stage_census(state: Dictionary, ship: Dictionary, owner: int) -> Dictionary:
	var workers: Dictionary = {}
	var occupied: Dictionary = {}
	for other in state["ships"]:
		if int(other["owner"]) != owner or int(other["id"]) == int(ship["id"]):
			continue
		if other.has("resource_stage"):
			var assigned: int = int(other["resource_stage"]["node"])
			occupied[assigned] = int(occupied.get(assigned, 0)) + 1
		elif bool(other.get("resource_haul", false)) and other.has("resource_haul_node"):
			var hauling_node: int = int(other["resource_haul_node"])
			occupied[hauling_node] = int(occupied.get(hauling_node, 0)) + 1
		var field_index: int = _stage_worker_field(other, owner)
		if field_index >= 0:
			if not workers.has(field_index):
				workers[field_index] = []
			workers[field_index].append(other)
	return {"workers": workers, "occupied": occupied}

# Returns [best_candidate, best_score] over discovered fields with active workers.
static func _best_mining_stage(state: Dictionary, graph: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, threats: Dictionary, workers: Dictionary, occupied: Dictionary, excluded_node: int, max_pickup_years: float) -> Array:
	if workers.is_empty():
		return [{}, INF]
	var owner: int = int(ship["owner"])
	var fields: Array = state["map"].get("fields", [])
	var count: int = state["planets"].size()
	var best: Dictionary = {}
	var best_score: float = INF
	for i in range(fields.size()):
		if count + i == excluded_node or (excluded_node >= 0 and int(occupied.get(count + i, 0)) > 0) or not discovered(state, owner, "fields", i):
			continue
		var active: Array = workers.get(i, [])
		if active.is_empty():
			continue
		var field: Dictionary = fields[i]
		var resources: Array[String] = []
		for resource in _mining_resources(state, owner, i):
			resources.append(resource)
		for miner in active:
			for resource in RESOURCES + [ANTIMATTER]:
				if float(miner["cargo"].get(resource, 0.0)) > EPS and not resources.has(resource):
					resources.append(resource)
		if resources.is_empty():
			continue
		var demand: float = (1.0 + float(active.size()) * 2.0) / (1.0 + float(occupied.get(count + i, 0)) * 4.0)
		var nearest: float = INF
		var point: Vector2 = Vector2.INF
		for miner in active:
			var wait_point: Vector2 = _stage_wait_point(state, graph, ship, miner, count + i, int(miner.get("mining_anchor", field["anchor"])), teams, cache, threats)
			if not wait_point.is_finite():
				continue
			var pickup_eta: float = _mining_pickup_eta(miner, ship["position"], wait_point)
			if pickup_eta < nearest:
				nearest = pickup_eta
				point = wait_point
		if not point.is_finite() or nearest > max_pickup_years:
			continue
		var depot_distance: float = INF
		for resource in resources:
			var depot: int = _mining_depot(state, ship, teams, _combat_group(state, owner), int(field["anchor"]), resource, cache, point)
			if depot >= 0:
				depot_distance = minf(depot_distance, point.distance_to(station_position(state, depot, float(state["elapsed"]))))
		if not is_finite(depot_distance) or int(occupied.get(count + i, 0)) >= _stage_freighter_limit(active.size(), depot_distance):
			continue
		for anchor in field_access_systems(state["map"], field):
			var candidate: Dictionary = _stage_candidate(state, graph, ship, teams, cache, threats, count + i, anchor, point, resources, demand)
			if candidate.is_empty():
				continue
			# Favor ready workers and short collection cycles, penalizing
			# competing haulers without requiring a global assignment solve.
			var score: float = (nearest * FREIGHTER_SPEED + depot_distance * 0.35) / maxf(1.0, demand)
			if score < best_score:
				best = candidate
				best_score = score
	return [best, best_score]

# Group nearby debris into a site. Each pile counts once, and the
# threshold is a full logistics hold, not an individual small fragment.
static func _best_salvage_stage(state: Dictionary, graph: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, threats: Dictionary, cells: Dictionary, occupied: Dictionary, current: Array) -> Array:
	var owner: int = int(ship["owner"])
	var fields: Array = state["map"].get("fields", [])
	var count: int = state["planets"].size()
	var best: Dictionary = current[0]
	var best_score: float = current[1]
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
		if int(occupied.get(node, 0)) >= maxi(1, ceili(total / CARGO_CAPACITY)):
			continue
		var demand: float = 2.0 / (1.0 + float(occupied.get(node, 0)) * 4.0)
		var candidate: Dictionary = _stage_candidate(state, graph, ship, teams, cache, threats, node, anchor, point, resources, demand)
		if not candidate.is_empty() and float(candidate["score"]) < best_score:
			best = candidate
			best_score = float(candidate["score"])
			best["salvage_site"] = true
	return [best, best_score]

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
	var safe: bool = _resource_stage_safe(state, graph, ship, teams, team, point, node, threats)
	if not safe or not autocast_ready(state, ship, "trade") or bool(ship.get("holding", false)) or _unit_order_running(ship) or not ship.get("order_queue", []).is_empty():
		return _abandon_resource_stage(state, ship, teams, team, safe)
	var now: float = float(state["elapsed"])
	if _cargo_total(ship) > EPS:
		if not ship.has("resource_loaded_at"):
			ship["resource_loaded_at"] = now
		if cargo_free(ship) <= EPS or (bool(stage.get("salvage_site", false)) and now - float(ship["resource_loaded_at"]) >= RESOURCE_PARTIAL_WAIT_YEARS):
			_resource_haul(ship)
			return true
	if now >= float(ship.get("next_resource_stage_search", 0.0)):
		var refreshed: Array = _refresh_resource_stage(state, graph, ship, teams, cache, threats, stage, point, node, team, now)
		if refreshed[0]:
			return true
		point = refreshed[1]
	if not bool(stage.get("salvage_site", false)):
		var field_index: int = node - state["planets"].size()
		if field_index >= 0 and field_index < _movement_fields.size():
			var queue_point: Vector2 = _stage_queue_position(point, _movement_fields[field_index]["position"], int(stage.get("queue_rank", 0)))
			if _point_clear_of_rocks(queue_point) and _salvage_safe(state, graph, owner, queue_point, node, threats):
				point = queue_point
			else:
				_resource_haul(ship)
				return true
	ship["route"] = []
	ship["leg"] = 0.0
	_navigate(ship, point, minf(ship_speed(str(ship.get("kind", "ship"))) * dt, (ship["position"] as Vector2).distance_to(point)))
	# Meet the selected worker; recalculate its berth on staggered searches.
	_work_opportunistic_salvage(state, graph, ship, dt, busy, cells, false, threats)
	return true

## Staggered re-survey of a staged site; returns [handled, berth point].
static func _refresh_resource_stage(state: Dictionary, graph: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, threats: Dictionary, stage: Dictionary, point: Vector2, node: int, team: int, now: float) -> Array:
	ship["next_resource_stage_search"] = _next_search_slot(now, int(ship["id"]), RESOURCE_STAGE_SEARCH_YEARS)
	var available: bool = false
	var pickup_eta: float = INF
	var return_distance: float = INF
	if bool(stage.get("salvage_site", false)):
		available = _salvage_site_available(state, point)
	else:
		var field_index: int = node - state["planets"].size()
		var fields: Array = state["map"].get("fields", [])
		if field_index >= 0 and field_index < fields.size():
			var survey: Array = _survey_mining_stage(state, graph, ship, teams, cache, threats, stage, node, team, field_index, now)
			available = survey[0]
			pickup_eta = survey[1]
			return_distance = survey[2]
			point = stage["point"]
	if not bool(stage.get("salvage_site", false)) and _cargo_total(ship) > EPS:
		if _leave_loaded_stage(state, graph, ship, teams, cache, threats, team, node, available, pickup_eta, return_distance, now):
			return [true, point]
	if available and not bool(stage.get("salvage_site", false)) and int(stage.get("queue_rank", 0)) == 0 and _cargo_total(ship) <= EPS and pickup_eta > 5.0:
		if _choose_resource_stage(state, graph, ship, teams, cache, threats, {}, true, node, pickup_eta - 3.0):
			return [true, point]
	if not available:
		if _cargo_total(ship) > EPS:
			_resource_haul(ship)
		else:
			_clear_resource_stage(ship)
		return [true, point]
	# Mining has a bounded allocation; only surplus salvage waiters
	# abandon their site for an ordinary trade opportunity.
	if bool(stage.get("salvage_site", false)) and _cargo_total(ship) <= EPS and ship["route"].is_empty() and teams[int(ship["at"])] == team:
		_choose_delivery(state, ship, teams, team, cache)
		if int(ship.get("source", -1)) >= 0:
			ship.erase("resource_stage")
			ship.erase("resource_loaded_at")
			return [true, point]
	return [false, point]

static func _resource_stage_safe(state: Dictionary, graph: Dictionary, ship: Dictionary, teams: Array[int], team: int, point: Vector2, node: int, threats: Dictionary) -> bool:
	var owner: int = int(ship["owner"])
	if not (_salvage_safe(state, graph, owner, point, node, threats) and _salvage_safe(state, graph, owner, ship["position"], local_sector(graph, ship), threats)):
		return false
	for waypoint in ship["route"]:
		if not _civilian_transit_allowed(state, team, teams[int(waypoint)]):
			return false
	return true

# Drop an invalid stage; still-eligible loaded ships haul what they hold.
static func _abandon_resource_stage(state: Dictionary, ship: Dictionary, teams: Array[int], team: int, safe: bool) -> bool:
	_clear_resource_stage(ship)
	if safe and autocast_ready(state, ship, "trade") and not bool(ship.get("holding", false)) and not _unit_order_running(ship) and ship.get("order_queue", []).is_empty() and _cargo_total(ship) > EPS:
		_resource_haul(ship)
		return true
	if not safe and (not _civilian_transit_allowed(state, team, teams[int(ship["at"])]) if state.has("diplomacy") else teams[int(ship["at"])] != team):
		_evacuate_civilian(state, ship, teams)
	return false

static func _salvage_site_available(state: Dictionary, point: Vector2) -> bool:
	var piles: Dictionary = state.get("salvage", {})
	for id in piles:
		if (piles[id]["position"] as Vector2).distance_to(point) <= SALVAGE_APPROACH_RANGE and float(piles[id]["amount"]) > EPS:
			return true
	return false

# Refresh queue rank and rendezvous for a mining stage. Returns
# [available, pickup_eta, return_distance]; may move stage["point"].
static func _survey_mining_stage(state: Dictionary, graph: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, threats: Dictionary, stage: Dictionary, node: int, team: int, field_index: int, now: float) -> Array:
	var owner: int = int(ship["owner"])
	var fields: Array = state["map"].get("fields", [])
	var point: Vector2 = stage["point"]
	var waiting: Array = _stage_queue(state, ship, node)
	var rank: int = waiting.find(ship)
	stage["queue_rank"] = maxi(0, rank)
	var nearest: float = INF
	var worker_count: int = 0
	var depot_distance: float = INF
	for miner in state["ships"]:
		if _stage_worker_field(miner, owner) != field_index:
			continue
		worker_count += 1
		var wait_point: Vector2 = _stage_wait_point(state, graph, ship, miner, node, int(stage["anchor"]), teams, cache, threats)
		if not wait_point.is_finite():
			continue
		# Keep a usable rendezvous fixed while a loaded miner
		# is approaching it, avoiding two ships chasing a moving goal.
		if _cargo_total(miner) > EPS and (miner["position"] as Vector2).distance_to(point) <= RESOURCE_HANDOFF_RANGE and _point_clear_of_rocks(point):
			wait_point = point
		var eta: float = _mining_pickup_eta(miner, ship["position"], wait_point)
		if eta < nearest:
			nearest = eta
			if rank <= 0:
				stage["point"] = wait_point
		var chunk: Dictionary = _find_chunk(fields[field_index], int(miner.get("chunk", -1)))
		var depot: int = _mining_depot(state, ship, teams, team, int(stage["anchor"]), str(chunk.get("resource", "Metals")), cache, wait_point)
		if depot >= 0:
			depot_distance = minf(depot_distance, wait_point.distance_to(station_position(state, depot, now)))
	var available: bool = nearest < INF
	if available and rank > 0:
		stage["point"] = waiting[0]["resource_stage"]["point"]
	if available and is_finite(depot_distance) and rank >= _stage_freighter_limit(worker_count, depot_distance) and _cargo_total(ship) <= EPS:
		available = false
	return [available, nearest, depot_distance]

# Compare the next local pickup (or a nearby alternative pool) with the
# cost of another depot round trip. Returns true when the stage was left.
static func _leave_loaded_stage(state: Dictionary, graph: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, threats: Dictionary, team: int, node: int, available: bool, pickup_eta: float, return_distance: float, now: float) -> bool:
	var elapsed_idle: float = now - float(ship["resource_loaded_at"])
	if not is_finite(return_distance):
		for resource in RESOURCES + [ANTIMATTER]:
			if float(ship["cargo"].get(resource, 0.0)) <= EPS:
				continue
			var depot: int = _mining_depot(state, ship, teams, team, int(ship["at"]), resource, cache)
			if depot >= 0:
				return_distance = minf(return_distance, (ship["position"] as Vector2).distance_to(station_position(state, depot, now)))
	var limit: float = _mining_idle_limit(return_distance, _cargo_total(ship)) if is_finite(return_distance) else RESOURCE_MAX_IDLE_YEARS
	var remaining_wait: float = maxf(0.0, limit - elapsed_idle)
	if not available or pickup_eta > remaining_wait:
		if remaining_wait > 0.5 and _choose_resource_stage(state, graph, ship, teams, cache, threats, {}, true, node, remaining_wait):
			return true
		_resource_haul(ship)
		return true
	return false

static func _dropoff_budget(ship: Dictionary, dt: float) -> float:
	return maxf(0.0, dropoff_rate(str(ship["kind"])) * float(ship.get("reward_loading_factor", 1.0)) * maxf(0.0, dt) - float(ship.get("_handoff_sent", 0.0)))

static func dropoff_rate(kind: String) -> float:
	match kind:
		"miner": return 120.0 # Independent of extraction balance.
		"ship": return FREIGHTER_TRACTOR_RATE * 20.0
		"colony_ship": return COLONY_FARM_RATE * 20.0
	return TRACTOR_RATE * 20.0

# Build once before movement; entries retain authoritative fleet order.
static func _handoff_candidates(cells: Dictionary, point: Vector2, neighborhoods: Dictionary = {}) -> Array:
	var cell := Vector2i(floori(point.x / RESOURCE_HANDOFF_RANGE), floori(point.y / RESOURCE_HANDOFF_RANGE))
	if neighborhoods.has(cell):
		return neighborhoods[cell]
	var ordered: Array = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			for entry in cells.get(cell + Vector2i(x, y), []):
				ordered.append(entry)
	ordered.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var result: Array = []
	for entry in ordered:
		result.append(entry[1])
	neighborhoods[cell] = result
	return result

static func _miner_handoff(state: Dictionary, graph: Dictionary, miner: Dictionary, receivers: Array, threats: Dictionary, dt: float) -> float:
	# No recipient means no transfer or handoff state change. Skip safety
	# geometry entirely; the caller still records the zero transfer.
	if receivers.is_empty():
		return 0.0
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
		var stage: Dictionary = freighter.get("resource_stage", {})
		if not stage.is_empty() and not bool(stage.get("salvage_site", false)):
			if int(stage.get("queue_rank", 0)) > 0:
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

# Only failed autonomous empty-cargo searches are rate limited. Explicit
# orders, loaded cargo, active routes and arrival work remain incremental.
# Use an absolute simulation-time deadline (not wall time or frame count).
static func _search_idle_trade(state: Dictionary, ship: Dictionary, teams: Array[int], team: int, cache: Dictionary, scheduled: bool) -> void:
	var now: float = float(state["elapsed"])
	if scheduled and now + EPS < float(ship.get("_next_trade_search", 0.0)):
		return
	ship.erase("_next_trade_search")
	_choose_delivery(state, ship, teams, team, cache)
	if scheduled and int(ship.get("source", -1)) < 0:
		ship["_next_trade_search"] = now + IDLE_TRADE_RETRY_YEARS

static func _work_ship(state: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, dt: float, scheduled: bool = false) -> void:
	# Active work, a new order or a cargo arrival invalidates an idle retry.
	if not ship["route"].is_empty() or int(ship.get("source", -1)) >= 0 or int(ship.get("dest", -1)) >= 0 or _cargo_total(ship) > EPS or not scheduled:
		ship.erase("_next_trade_search")
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
		var budget: float = dropoff_rate("ship") * float(ship.get("reward_loading_factor", 1.0)) * maxf(0.0, dt)
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
		_search_idle_trade(state, ship, teams, team, cache, scheduled)

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

# Harvesters fly directly; system IDs only describe job endpoints.
static func _mining_path(state: Dictionary, teams: Array[int], team: int, start: int, goal: int, _cache: Dictionary) -> Array[int]:
	if start < 0 or goal < 0 or start >= teams.size() or goal >= teams.size() or team <= 0:
		return []
	if not _civilian_transit_allowed(state, team, teams[start]) or not _civilian_transit_allowed(state, team, teams[goal]):
		return []
	return _rally_path(state, start, goal)

static func _mining_depot(state: Dictionary, ship: Dictionary, teams: Array[int], team: int, anchor: int, resource: String, _cache: Dictionary, point: Vector2 = Vector2.INF) -> int:
	var best: float = INF
	var chosen: int = -1
	var origin: Vector2 = point if point.is_finite() else ship.get("position", state["map"]["points"][anchor])
	for i in range((state["planets"] as Array).size()):
		var p: Dictionary = state["planets"][i]
		if int(p["owner"]) != int(ship["owner"]) or not has_station(p) or storage_free(p, resource) <= EPS or not _civilian_transit_allowed(state, team, teams[i]):
			continue
		var distance: float = origin.distance_to(station_position(state, i, float(state["elapsed"])))
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
	if field_index >= state["map"].get("fields", []).size():
		return false
	var selected: Array = _selected_owned_miners(state, player, ids)
	if selected.is_empty():
		return false
	if field_index >= 0 and not _miners_can_work_field(state, player, selected, field_index, chunk_id):
		return false
	for ship in selected:
		_reassign_miner(state, ship, field_index, chunk_id)
	return true

static func _selected_owned_miners(state: Dictionary, player: int, ids: Array) -> Array:
	var requested: Dictionary = {}
	for id in ids:
		if not id is int or requested.has(id):
			return []
		requested[id] = true
	var selected: Array = []
	for ship in state["ships"]:
		if requested.has(ship["id"]):
			if int(ship["owner"]) != player or ship.get("kind", "") != "miner":
				return []
			selected.append(ship)
	if selected.size() != requested.size():
		return []
	return selected

static func _miners_can_work_field(state: Dictionary, player: int, selected: Array, field_index: int, chunk_id: int) -> bool:
	if not discovered(state, player, "fields", field_index):
		return false
	var field: Dictionary = state["map"]["fields"][field_index]
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
	return true

static func _reassign_miner(state: Dictionary, ship: Dictionary, field_index: int, chunk_id: int) -> void:
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

static func _choose_field(state: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, profile: Dictionary = {}) -> void:
	_validate_mining_assignment(state, ship)
	var best: Dictionary = _best_mining_chunk(state, ship, teams, cache, int(ship.get("assigned_field", -1)), int(ship.get("assigned_chunk", -1)), profile)
	if not best.is_empty():
		_assign_mining_chunk(ship, int(best["field"]), int(best["anchor"]), best["chunk"])

# Drop explicit field or rock assignments that no longer have usable ore.
static func _validate_mining_assignment(state: Dictionary, ship: Dictionary) -> void:
	var assigned: int = int(ship.get("assigned_field", -1))
	if assigned < 0:
		return
	var owner: int = int(ship["owner"])
	var preferred: int = int(ship.get("assigned_chunk", -1))
	var usable: bool = false
	var preferred_usable: bool = false
	for chunk in state["map"].get("fields", [])[assigned].get("chunks", []):
		if float(chunk["remaining"]) > EPS and _mining_resources(state, owner, assigned).has(str(chunk["resource"])):
			usable = true
			if int(chunk["id"]) == preferred:
				preferred_usable = true
	if not usable:
		ship["assigned_field"] = -1
	if not preferred_usable:
		ship["assigned_chunk"] = -1

static func _best_mining_chunk(state: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, assigned: int, preferred: int, profile: Dictionary = {}) -> Dictionary:
	var fields: Array = state["map"].get("fields", [])
	var owner: int = int(ship["owner"])
	var team: int = _combat_group(state, owner)
	var detailed_profile: bool = bool(profile.get("_detail", false))
	var best_distance: float = INF
	var best: Dictionary = {}
	var path_usec: int = 0
	var depot_usec: int = 0
	var scoring_usec: int = 0
	for i in range(fields.size()):
		if assigned >= 0 and i != assigned:
			continue
		var field: Dictionary = fields[i]
		var candidate_key: String = "mine:candidates:%d:%d" % [owner, i]
		if not cache.has(candidate_key):
			var field_resources: Array[String] = _mining_resources(state, owner, i) if discovered(state, owner, "fields", i) else []
			var field_chunks: Array = []
			for chunk in field.get("chunks", []):
				if field_resources.has(str(chunk["resource"])) and float(chunk["remaining"]) > EPS:
					field_chunks.append(chunk)
			cache[candidate_key] = {"resources": field_resources, "chunks": field_chunks}
		var field_candidates: Dictionary = cache[candidate_key]
		var resources: Array[String] = field_candidates["resources"]
		if resources.is_empty():
			continue
		# Cached references retain original order; live depletion is checked
		# each search because earlier hulls may consume the same rock.
		var eligible_chunks: Array = []
		for chunk in field_candidates["chunks"]:
			if preferred >= 0 and int(chunk["id"]) != preferred:
				continue
			if float(chunk["remaining"]) <= EPS:
				continue
			eligible_chunks.append(chunk)
		if eligible_chunks.is_empty():
			continue
		var access_key: String = "mine:access:%d" % i
		if not cache.has(access_key):
			cache[access_key] = field_access_systems(state["map"], field)
		# Access anchors are eligibility metadata, never flight waypoints.
		var entrances: Array = cache[access_key].duplicate()
		var here: int = int(ship["at"])
		if entrances.has(here):
			entrances.erase(here)
			entrances.push_front(here)
		var reachable_anchor: int = -1
		for anchor in entrances:
			var path_started: int = Time.get_ticks_usec() if detailed_profile else 0
			var path: Array[int] = _mining_path(state, teams, team, int(ship["at"]), anchor, cache)
			if detailed_profile:
				path_usec += Time.get_ticks_usec() - path_started
			if not path.is_empty():
				reachable_anchor = anchor
				break
		if reachable_anchor < 0:
			continue
		# Field-center depot selection and rock scoring do not depend on
		# the access anchor; equal scores retain the first reachable one.
		var depots: Dictionary = {}
		var depot_positions: Dictionary = {}
		for resource in resources:
			var depot_started: int = Time.get_ticks_usec() if detailed_profile else 0
			var depot_index: int = _mining_depot(state, ship, teams, team, reachable_anchor, resource, cache, field["position"])
			depots[resource] = depot_index
			if depot_index >= 0:
				depot_positions[resource] = station_position(state, depot_index, float(state["elapsed"]))
			if detailed_profile:
				depot_usec += Time.get_ticks_usec() - depot_started
		var scoring_started: int = Time.get_ticks_usec() if detailed_profile else 0
		for chunk in eligible_chunks:
			var chunk_depot: int = int(depots.get(chunk["resource"], -1))
			if chunk_depot < 0:
				continue
			var rock: Vector2 = chunk["position"]
			var distance: float = (ship["position"] as Vector2).distance_to(rock) + rock.distance_to(depot_positions[chunk["resource"]])
			if distance < best_distance:
				best_distance = distance
				best = {"field": i, "chunk": chunk, "anchor": reachable_anchor}
		if detailed_profile:
			scoring_usec += Time.get_ticks_usec() - scoring_started
	if detailed_profile:
		profile["Miner access path"] = int(profile.get("Miner access path", 0)) + path_usec
		profile["Miner depot search"] = int(profile.get("Miner depot search", 0)) + depot_usec
		profile["Miner candidate distances"] = int(profile.get("Miner candidate distances", 0)) + scoring_usec
	return best

static func _assign_mining_chunk(ship: Dictionary, field_index: int, anchor: int, chunk: Dictionary) -> void:
	ship.erase("last_mining_field")
	ship["field"] = field_index
	ship["mining_anchor"] = anchor
	ship["chunk"] = int(chunk["id"])
	var rock: Vector2 = chunk["position"]
	var radial: Vector2 = ((ship["position"] as Vector2) - rock).normalized()
	if radial.is_zero_approx():
		radial = Vector2.RIGHT
	ship["mining_rock"] = rock
	ship["mining_target"] = rock + radial * (float(chunk.get("radius", 0.0)) + 12.0)
	ship["mining_mode"] = "outbound"
	ship["route"] = []
	ship["leg"] = 0.0
	ship["field_leg"] = 0.0
	ship["source"] = -1
	ship["dest"] = -1

# Align retries to stable hull-specific slots. Initial searches and explicit
# reset-to-zero requests remain immediate; subsequent retries are staggered.
static func _next_search_slot(now: float, id: int, interval: float) -> float:
	var phase: float = float(posmod(id, 5)) * interval / 5.0
	var next: float = floorf((now - phase) / interval) * interval + phase + interval
	if next <= now + EPS:
		next += interval
	return next

static func _mining_receiver_ready(state: Dictionary, receiver: Dictionary) -> bool:
	var stage: Dictionary = receiver.get("resource_stage", {})
	return receiver.get("kind", "") == "ship" and not stage.is_empty() and not bool(stage.get("salvage_site", false)) and int(stage.get("queue_rank", 0)) == 0 and cargo_free(receiver) > EPS and autocast_ready(state, receiver, "trade") and not bool(receiver.get("rogue", false)) and not bool(receiver.get("retreating", false)) and not bool(receiver.get("holding", false)) and not _engaged(receiver) and not _unit_order_running(receiver) and receiver.get("order_queue", []).is_empty() and not receiver.has("cargo_order")

static func _mining_rendezvous_eta(miner_position: Vector2, receiver_position: Vector2, meeting: Vector2) -> float:
	var miner_eta: float = maxf(0.0, miner_position.distance_to(meeting) - RESOURCE_HANDOFF_RANGE * 0.65) / MINER_SPEED
	var receiver_eta: float = receiver_position.distance_to(meeting) / FREIGHTER_SPEED
	return maxf(miner_eta, receiver_eta)

# Returning miners compare a cooperative rendezvous against a direct depot
# trip. Use one per-owner spatial index and per-step capacity commitments,
# not an all-miners/all-freighters search or a new replicated order type.
static func _work_miner_rendezvous(state: Dictionary, graph: Dictionary, miner: Dictionary, teams: Array[int], cache: Dictionary, threats: Dictionary, receivers: Dictionary, committed: Dictionary, dt: float) -> bool:
	if miner.get("mining_mode", "") not in ["return", "delivery"] or _cargo_total(miner) <= EPS or _engaged(miner) or bool(miner.get("retreating", false)) or bool(miner.get("holding", false)) or miner.has("repair_order") or miner.has("cargo_order"):
		return false
	if _unit_order_running(miner) and miner.get("unit_order", {}).get("kind", "") != "mine":
		return false
	var owner: int = int(miner["owner"])
	var cells: Dictionary = receivers.get(owner, {})
	if cells.is_empty():
		return false
	var position: Vector2 = miner["position"]
	var cell := Vector2i(floori(position.x / MINING_RENDEZVOUS_RANGE), floori(position.y / MINING_RENDEZVOUS_RANGE))
	var load: float = _cargo_total(miner)
	var best: Dictionary = {}
	var meeting: Vector2 = Vector2.INF
	var eta: float = INF
	for x in range(-1, 2):
		for y in range(-1, 2):
			for receiver in cells.get(cell + Vector2i(x, y), []):
				if not _mining_receiver_ready(state, receiver):
					continue
				var id: int = int(receiver["id"])
				if cargo_free(receiver) - float(committed.get(id, 0.0)) < load - EPS:
					continue
				var point: Vector2 = receiver["resource_stage"]["point"]
				if position.distance_squared_to(point) > MINING_RENDEZVOUS_RANGE * MINING_RENDEZVOUS_RANGE:
					continue
				var arrival: float = _mining_rendezvous_eta(position, receiver["position"], point)
				if arrival < eta:
					eta = arrival
					meeting = point
					best = receiver
	if best.is_empty():
		return false
	var team: int = _combat_group(state, owner)
	var depot_eta: float = INF
	for resource in RESOURCES + [ANTIMATTER]:
		if float(miner["cargo"].get(resource, 0.0)) <= EPS:
			continue
		var depot: int = _mining_depot(state, miner, teams, team, int(miner["at"]), resource, cache)
		if depot >= 0:
			depot_eta = minf(depot_eta, maxf(0.0, position.distance_to(station_position(state, depot, float(state["elapsed"]))) - STATION_DOCK_RANGE) / MINER_SPEED)
	if eta + 0.5 >= depot_eta or not _salvage_safe(state, graph, owner, position, local_sector(graph, miner), threats) or not _salvage_safe(state, graph, owner, meeting, int(best["resource_stage"]["node"]), threats):
		return false
	var receiver_id: int = int(best["id"])
	committed[receiver_id] = float(committed.get(receiver_id, 0.0)) + load
	if int(miner.get("field", -1)) >= 0:
		miner["last_mining_field"] = int(miner["field"])
	miner["mining_active"] = false
	# Stop within handoff range. The standard pre-movement handoff performs
	# the transfer on the next step, with its normal budget and capacity.
	var distance: float = position.distance_to(meeting)
	_navigate(miner, meeting, minf(MINER_SPEED * dt, maxf(0.0, distance - RESOURCE_HANDOFF_RANGE * 0.65)))
	return true

static func _work_miner(state: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, budgets: Array, dt: float, profile: Dictionary = {}) -> void:
	ship["mining_active"] = false
	if state.has("diplomacy") and _miner_evacuated(state, ship, teams):
		return
	var mode: String = str(ship.get("mining_mode", "idle"))
	if mode == "idle":
		_miner_idle(state, ship, teams, cache, profile)
		return
	if mode == "delivery":
		_miner_delivery(state, ship, teams, cache, dt)
		return
	var field_index: int = int(ship["field"])
	var field: Dictionary = state["map"]["fields"][field_index]
	var anchor: int = int(ship.get("mining_anchor", field["anchor"]))
	if mode == "approach":
		# Compatibility with existing fixtures and in-flight jobs: skip the old star leg.
		ship["route"] = []
		ship["leg"] = 0.0
		ship["mining_mode"] = "outbound"
		ship["field_leg"] = 0.0
		mode = "outbound"
	var origin: Vector2 = _service_point(state, ship, anchor)
	_ensure_position(state["map"]["points"], ship)
	if mode == "outbound":
		_miner_outbound(state, ship, field, field_index, origin, dt)
	elif mode == "mining":
		_miner_extract(state, ship, field, field_index, budgets, dt)
	elif mode == "return":
		_miner_return(state, ship, teams, cache, field_index, anchor, dt)

# Hostile presence turns active mining into a return trip and evacuates
# vulnerable idle/delivery miners. Returns true when the tick is consumed.
static func _miner_evacuated(state: Dictionary, ship: Dictionary, teams: Array[int]) -> bool:
	var mode: String = str(ship.get("mining_mode", "idle"))
	var group: int = _combat_group(state, int(ship["owner"]))
	var hostile_here: bool = not _civilian_transit_allowed(state, group, teams[int(ship["at"])])
	if hostile_here and mode in ["outbound", "mining"]:
		ship["mining_mode"] = "return"
	elif mode in ["approach", "delivery", "idle"] and (not _civilian_route_safe(state, ship, teams, group) or (hostile_here and ship["route"].is_empty())):
		_evacuate_civilian(state, ship, teams)
		return true
	return false

static func _miner_idle(state: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, profile: Dictionary = {}) -> void:
	var detailed_profile: bool = bool(profile.get("_detail", false))
	if not bool(ship.get("manual_mine", false)) and not autocast_ready(state, ship, "mine"):
		return
	if (ship["route"] as Array).is_empty():
		ship["dest"] = -1
		ship["source"] = -1
	if float(state["elapsed"]) + EPS >= float(ship.get("next_mining_search", 0.0)):
		var search_started: int = Time.get_ticks_usec() if detailed_profile else 0
		_choose_field(state, ship, teams, cache, profile)
		if detailed_profile:
			profile["Miner field selection"] = int(profile.get("Miner field selection", 0)) + Time.get_ticks_usec() - search_started
		if ship.get("mining_mode", "idle") == "idle" and int(ship.get("assigned_field", -1)) < 0:
			ship.erase("manual_mine")
		# Idle fleets retry twice per game year instead of every tick.
		ship["next_mining_search"] = _next_search_slot(float(state["elapsed"]), int(ship["id"]), 0.5)

static func _miner_delivery(state: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, dt: float) -> void:
	var arrived: bool = false
	if _cargo_total(ship) <= EPS and not ship["route"].is_empty() and not _unit_order_running(ship):
		# Finish the current legal lane before selecting new work.
		if not _move(state, ship, dt, Vector2.INF, -1, STATION_DOCK_RANGE):
			return
		arrived = true
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
	# The arrival above already spent this tick's movement budget.
	if arrived or _move(state, ship, dt, Vector2.INF, -1, STATION_DOCK_RANGE):
		_unload_miner(state, ship, teams, cache, dt)

static func _miner_outbound(state: Dictionary, ship: Dictionary, field: Dictionary, field_index: int, origin: Vector2, dt: float) -> void:
	var target: Vector2 = ship["mining_target"]
	var span: Vector2 = target - origin
	var chunk: Dictionary = _find_chunk(field, int(ship["chunk"]))
	if chunk.is_empty() or not _mining_resources(state, int(ship["owner"]), field_index).has(str(chunk["resource"])):
		ship["mining_mode"] = "return"
		return
	_navigate(ship, target, ship_speed(str(ship.get("kind", "ship"))) * dt)
	ship["field_leg"] = clampf(((ship["position"] as Vector2) - origin).dot(span) / maxf(EPS, span.length_squared()), 0.0, 1.0)
	if (ship["position"] as Vector2) == target:
		ship["mining_mode"] = "mining"
		ship["mining_years"] = 0.0

static func _miner_extract(state: Dictionary, ship: Dictionary, field: Dictionary, field_index: int, budgets: Array, dt: float) -> void:
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
		var amount: float = minf(free, minf(float(chunk["remaining"]), minf(MINER_RATE * _player_factor(state, int(ship["owner"]), "rank_extraction", 0.10) * float(field[resource]) * dt, float(budgets[field_index][resource]))))
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

static func _miner_return(state: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, field_index: int, anchor: int, dt: float) -> void:
	# Return directly to a useful owned warehouse from the actual rock.
	ship["last_mining_field"] = field_index
	ship["mining_mode"] = "delivery"
	ship["field"] = -1
	ship["route"] = []
	ship["leg"] = 0.0
	ship["dest"] = -1
	ship["source"] = -1
	var team: int = _combat_group(state, int(ship["owner"]))
	for resource in RESOURCES + [ANTIMATTER]:
		if float(ship["cargo"].get(resource, 0.0)) <= EPS:
			continue
		var depot: int = _mining_depot(state, ship, teams, team, anchor, resource, cache)
		if depot >= 0:
			ship["dest"] = depot
			ship["route"] = [depot]
			if _move(state, ship, dt, Vector2.INF, -1, STATION_DOCK_RANGE):
				_unload_miner(state, ship, teams, cache, dt)
			return
	if _cargo_total(ship) <= EPS:
		ship["mining_mode"] = "idle"
		ship["next_mining_search"] = 0.0

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
	# Keep the compatibility shape for strategic callers, but no graph search.
	if graph.has("paths") and graph["paths"].has(goal):
		return graph["paths"][goal]
	var points: Array = graph["points"]
	var distances: Dictionary = {}
	var next_hop: Dictionary = {}
	if goal >= 0 and goal < points.size():
		var destination: Vector2 = points[goal]
		for node in range(points.size()):
			distances[node] = (points[node] as Vector2).distance_to(destination)
			if node != goal:
				next_hop[node] = goal
	var result: Dictionary = {"goal": goal, "distance": distances, "next": next_hop}
	if graph.has("paths"):
		graph["paths"][goal] = result
	return result


static func _military_approach(graph: Dictionary, ship: Dictionary, paths: Dictionary) -> Dictionary:
	var points: Array = graph["points"]
	var goal: int = int(paths["goal"])
	var position: Vector2 = ship.get("position", _initial_position(points, ship))
	var distance: float = INF
	if goal >= 0 and goal < points.size():
		distance = position.distance_to(points[goal])
	return {"distance": distance, "anchor": goal, "reverse": false, "edge": false}


static func _redirect_fighter(graph: Dictionary, ship: Dictionary, target: int, _paths: Dictionary) -> void:
	_ensure_position(graph["points"], ship)
	# Preserve actual hull position on redirects. The route is a single
	# destination, with the last arrival anchor retained for compatibility.
	var route: Array[int] = []
	if int(ship["at"]) != target or (ship["position"] as Vector2).distance_to(graph["points"][target]) > EPS:
		route.append(target)
	ship["route"] = route
	ship["leg"] = _lane_progress(graph["points"], ship)
	ship["dest"] = target


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
	ship.erase("colony_transform_progress")
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
	ship.erase("patrol_waypoints")
	ship.erase("patrol_index")

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
	_seed_starting_exploration(state)
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
	if a == PIRATE_OWNER or b == PIRATE_OWNER:
		return (a == PIRATE_OWNER and b > 0 and state["teams"].has(b)) or (b == PIRATE_OWNER and a > 0 and state["teams"].has(a))
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
	if owner == PIRATE_OWNER:
		return PIRATE_COMBAT_GROUP
	return owner if state.has("diplomacy") and state["teams"].has(owner) else int(state["teams"].get(owner, 0))

static func _combat_groups_hostile(state: Dictionary, a: int, b: int) -> bool:
	if a == PIRATE_COMBAT_GROUP or b == PIRATE_COMBAT_GROUP:
		return a > 0 and b > 0 and a != b
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

const SHIP_MAX_HP = {"ship": FREIGHTER_HP, "scout": SHIP_HP * 0.5, "cruiser": 1600.0, "destroyer": 3200.0, "warp_gate": WARP_GATE_HP}
const MILITARY_KINDS = ["fighter", "scout", "cruiser", "destroyer"]
const ARMED_KINDS = ["fighter", "miner", "cruiser", "destroyer", "scout"]

static func ship_max_hp(kind: String) -> float:
	return float(SHIP_MAX_HP.get(kind, SHIP_HP))

static func _regenerate_hull(entity: Dictionary, maximum: float, dt: float) -> void:
	var hp: float = float(entity.get("hp", maximum))
	if hp > 0.0 and hp < maximum:
		entity["hp"] = minf(maximum, hp + PASSIVE_REGEN * maxf(0.0, dt))

static func _passive_regeneration(state: Dictionary, dt: float) -> void:
	for ship in state["ships"]:
		_regenerate_hull(ship, ship_max_hp(str(ship["kind"])), dt)
	_regenerate_structures(state, dt)

static func _regenerate_structures(state: Dictionary, dt: float) -> void:
	for system in state["planets"]:
		if has_station(system):
			_regenerate_hull(system["station"], station_max_hp(system), dt)
		for yard in system["yards"]:
			_regenerate_hull(yard, YARD_HP * int(yard["level"]), dt)
		for battery in system.get("pds", {}).values():
			_regenerate_hull(battery, PDS_HP, dt)

static func armed(ship: Dictionary) -> bool:
	return (not bool(ship.get("rogue", false)) or int(ship.get("owner", 0)) == PIRATE_OWNER) and ship.get("kind", "") in ARMED_KINDS

# Stable hull IDs and the existing disjoint structure target IDs. HP lives
# in the actual entity dictionary, so repair never creates a new entity.
static var _indexed_state: Dictionary = {}
static var _hulls_by_id: Dictionary = {}
# Only the worker's private state may retain live references across jobs.
# Public/synchronous callers and fixtures keep the defensive per-step rebuild.
static var _retained_hull_state: Dictionary = {}
static var _indexed_hull_roster: Array = []
# Monotonic private-roster order tokens survive deletion without shifting
# every later hull. They are derived indexes, not replicated IDs or hot data.
static var _hull_order_by_id: Dictionary = {}
static var _next_hull_order: int = 0
const INDEXED_HULL_SUBSET_LIMIT: int = 32
static var _hull_index_rebuilds: int = 0
static var _hull_deadlines_need_sync: bool = true
# Derived motion-dispatch sleep registry, scoped to one authoritative state.
# No entity references or new replicated fields; wake predicates are live.
enum MotionSleep { AWAKE, STOPPED, HELD, IDLE_MILITARY }
static var _motion_sleep_state: Dictionary = {}
static var _motion_sleep_roster: Array = []
static var _motion_sleep_modes: Dictionary = {}
# Independent deadline calendars, derived from the current authority only.
static var _deadline_state: Dictionary = {}
static var _deadline_roster: Array = []
static var _deadline_events: Dictionary = {}
static var _cooldown_deadlines = STEP_FRAME.DeadlineCalendar.new()
static var _transfer_deadlines = STEP_FRAME.DeadlineCalendar.new()

# The worker owns this roster and routes every launch/removal through the
# existing lifecycle helpers. No client or fixture may mutate it directly.
# Start/stop on the authority thread, not on the main thread or per tick.
static func begin_authority_hull_scope(state: Dictionary) -> void:
	assert(_retained_hull_state.is_empty())
	_retained_hull_state = state
	_hull_index_rebuilds = 0
	_indexed_state = {}
	_begin_hull_index(state)

static func end_authority_hull_scope() -> void:
	if is_same(_retained_hull_state, _deadline_state):
		_begin_deadline_schedule(_retained_hull_state, false)
	_retained_hull_state = {}
	_end_hull_index()

static func _end_hull_index() -> void:
	_indexed_state = {}
	_indexed_hull_roster = []
	_hulls_by_id.clear()
	_hull_order_by_id.clear()
	_next_hull_order = 0

# Rebuild for public callers (who can edit fixtures in place). In the private
# scope, append/remove hooks preserve the live dictionary references and order.
# Roster identity/count changes conservatively force a fresh scan.
static func _begin_hull_index(state: Dictionary) -> void:
	var retained: bool = is_same(state, _retained_hull_state)
	var reuse: bool = retained and is_same(state, _indexed_state) and is_same(state["ships"], _indexed_hull_roster) and _hulls_by_id.size() == state["ships"].size()
	var deadlines_active: bool = is_same(state, _deadline_state)
	if reuse and (not deadlines_active or not _hull_deadlines_need_sync):
		return
	if not reuse:
		_indexed_state = state
		_indexed_hull_roster = state["ships"]
		_hulls_by_id.clear()
		_hull_order_by_id.clear()
		_next_hull_order = 0
		_hull_index_rebuilds += 1
	for ship in state["ships"]:
		var id: int = int(ship["id"])
		if not reuse:
			_hulls_by_id[id] = ship
			if retained:
				_hull_order_by_id[id] = _next_hull_order
				_next_hull_order += 1
		# Restore deadlines on scope/state/roster setup. Public callers keep
		# the original per-step reconciliation for externally edited fields.
		if deadlines_active and ship.has("auto_cooldown_until"):
			_cooldown_deadlines.schedule(id, float(ship["auto_cooldown_until"]))
	if deadlines_active:
		_hull_deadlines_need_sync = false

static func _register_indexed_hull(state: Dictionary, ship: Dictionary) -> void:
	if is_same(state, _indexed_state):
		var id: int = int(ship["id"])
		_hulls_by_id[id] = ship
		if is_same(state, _retained_hull_state):
			_hull_order_by_id[id] = _next_hull_order
			_next_hull_order += 1
	if is_same(state, _deadline_state) and ship.has("auto_cooldown_until"):
		_cooldown_deadlines.schedule(int(ship["id"]), float(ship["auto_cooldown_until"]))

static func _remove_indexed_hull(state: Dictionary, ship: Dictionary) -> void:
	if ship.get("kind", "") == "warp_gate":
		for other in state["ships"]:
			if other.get("kind", "") == "warp_gate" and int(other.get("warp_destination", -1)) == int(ship["id"]):
				other["warp_destination"] = -1
	state["ships"].erase(ship)
	_direct_rock_corridors.erase(int(ship["id"]))
	_direct_trajectories.erase(int(ship["id"]))
	if is_same(state, _motion_sleep_state):
		_motion_sleep_modes.erase(int(ship["id"]))
	if is_same(state, _deadline_state):
		_cooldown_deadlines.cancel(int(ship["id"]))
	if is_same(state, _indexed_state):
		_hulls_by_id.erase(int(ship["id"]))
		_hull_order_by_id.erase(int(ship["id"]))

# Only use direct subsets for the worker's retained roster, never arbitrary
# mutable fixture arrays. A small sorted subset preserves roster order; large
# selections keep the existing linear path rather than sorting the whole fleet.
static func _can_index_hull_subset(state: Dictionary, requested: Dictionary) -> bool:
	if not is_same(state, _retained_hull_state) or not is_same(state, _indexed_state) or requested.size() > INDEXED_HULL_SUBSET_LIMIT or requested.size() >= _hulls_by_id.size():
		return false
	for id in requested:
		if not id is int:
			return false
	return true

static func _ordered_indexed_hull_subset(requested: Dictionary) -> Array:
	var ids: Array = []
	for id in requested:
		if _hull_order_by_id.has(id):
			ids.append(id)
	ids.sort_custom(func(a: int, b: int) -> bool: return int(_hull_order_by_id[a]) < int(_hull_order_by_id[b]))
	var hulls: Array = []
	for id in ids:
		hulls.append(_hulls_by_id[id])
	return hulls

static func service_targets(state: Dictionary, only_id: int = -1, requested: Variant = null) -> Dictionary:
	var targets: Dictionary = {}
	var hulls: Array = state["ships"]
	if only_id >= 0 and is_same(state, _indexed_state):
		hulls = [_hulls_by_id[only_id]] if _hulls_by_id.has(only_id) else []
	elif only_id < -1:
		hulls = []
	elif only_id == -1 and requested is Dictionary and _can_index_hull_subset(state, requested):
		hulls = _ordered_indexed_hull_subset(requested)
	for ship in hulls:
		if (only_id != -1 and int(ship["id"]) != only_id) or (requested != null and not requested.has(int(ship["id"]))):
			continue
		var position: Vector2 = ship.get("position", Vector2.INF)
		if not position.is_finite():
			continue
		targets[ship["id"]] = {"owner": ship["owner"], "entity": ship, "position": position, "max_hp": ship_max_hp(str(ship["kind"])), "node": -1, "kind": "ship"}
	if only_id >= 0:
		return targets
	if only_id == -1 and requested is Dictionary:
		var needs_structures: bool = false
		for id in requested:
			if not id is int or int(id) < -1:
				needs_structures = true
				break
		if not needs_structures:
			return targets
	var count: int = state["planets"].size()
	for node in range(count):
		var p: Dictionary = state["planets"][node]
		if has_station(p) and (only_id == -1 or only_id == station_target_id(state, node)) and (requested == null or requested.has(station_target_id(state, node))):
			targets[station_target_id(state, node)] = {"owner": p["owner"], "entity": p["station"], "position": station_position(state, node, float(state["elapsed"])), "max_hp": station_max_hp(p), "node": node, "kind": "station"}
		for slot in range(p["yards"].size()):
			if (only_id != -1 and only_id != -2 - node * 3 - slot) or (requested != null and not requested.has(-2 - node * 3 - slot)):
				continue
			var yard: Dictionary = p["yards"][slot]
			targets[-2 - node * 3 - slot] = {"owner": p["owner"], "entity": yard, "position": shipyard_position(state, node, slot, float(state["elapsed"])), "max_hp": YARD_HP * int(yard["level"]), "node": node, "kind": "yard"}
		var defenses: Dictionary = p.get("pds", {})
		if not defenses.is_empty():
			if only_id != -1 or requested != null:
				var matching: bool = false
				for slot in defenses:
					if (only_id == -1 or only_id == -2 - count * 3 - int(slot) * count - node) and (requested == null or requested.has(-2 - count * 3 - int(slot) * count - node)):
						matching = true
						break
				if not matching:
					continue
			var bodies: Array = system_bodies(p, int(state["map"]["seed"]), node)
			var radius: float = system_world_radius(state, node)
			for slot in defenses:
				if (only_id != -1 and only_id != -2 - count * 3 - int(slot) * count - node) or (requested != null and not requested.has(-2 - count * 3 - int(slot) * count - node)):
					continue
				if int(slot) < 0 or int(slot) >= bodies.size():
					continue
				var center: Vector2 = state["map"]["points"][node]
				var point: Vector2 = center + body_position(bodies[int(slot)], radius, float(state["elapsed"]))
				# Keep established system-centered combat range; repairs use the actual battery.
				targets[-2 - count * 3 - int(slot) * count - node] = {"owner": p["owner"], "entity": defenses[slot], "position": center, "repair_position": point, "max_hp": PDS_HP, "node": node, "kind": "pds"}
	return targets

# Movement uses a frozen service snapshot. With no Harvester, every reader
# names a target explicitly (all active follow-chain links are included).
# Harvester auto-repair can select any damaged entity, so retain the full view.
static func _movement_service_targets(state: Dictionary) -> Dictionary:
	var requested: Dictionary = {}
	for craft in state["ships"]:
		if craft.get("kind", "") == "miner":
			return service_targets(state)
		if craft.has("attack_order"):
			requested[int(craft["attack_order"])] = true
		if craft.has("cargo_order"):
			requested[int(craft["cargo_order"].get("target", -1))] = true
		var order: Dictionary = craft.get("unit_order", {})
		if order.get("kind", "") == "follow":
			requested[int(order["target"])] = true
	if requested.is_empty():
		return {}
	return service_targets(state, -1, requested)

static func _friendly_target(state: Dictionary, owner: int, target: Dictionary) -> bool:
	return not target.is_empty() and empires_allied(state, owner, int(target.get("owner", 0)))

# Trade permission does not authorize an uncompensated cargo transfer.
# Only explicit paid shipments and gifts may later cross ownership.
static func _cargo_target_allowed(state: Dictionary, owner: int, target: Dictionary) -> bool:
	if state.has("diplomacy"):
		return not target.is_empty() and owner > 0 and int(target.get("owner", 0)) == owner
	return _friendly_target(state, owner, target)

static func _damaged(target: Dictionary) -> bool:
	return REPAIR_QUERIES.is_damaged(target, EPS)

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
		_reset_unit_for_order(ship)
		_set_unit_order(state, ship, order.duplicate(true))
		if order["kind"] == "repair":
			ship["repair_order"] = order["target"]
		else:
			ship["cargo_order"] = order.duplicate(true)
			ship["move_only"] = true
	return true

static func supports_autocast(ship: Dictionary, mode: String) -> bool:
	if colony_morphing(ship):
		return false
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

static func _stop_waiting(state: Dictionary, ship: Dictionary) -> bool:
	return float(ship.get("stop_until", 0.0)) > float(state["elapsed"]) + EPS

static func autocast_ready(state: Dictionary, ship: Dictionary, mode: String) -> bool:
	return not _stop_waiting(state, ship) and autocast_enabled(ship, mode) and autocast_remaining(state, ship, mode) <= EPS

static func set_autocast(state: Dictionary, player: int, ids: Array, mode: String, enabled: bool) -> bool:
	var units: Array = _owned_units(state, player, ids)
	if not AUTOCAST_MODES.has(mode) or units.is_empty() or units.any(func(ship: Dictionary) -> bool: return not supports_autocast(ship, mode)):
		return false
	if mode == "repair":
		return set_repair_auto(state, player, ids, enabled)
	for ship in units:
		ship[mode + "_auto"] = enabled
		if enabled:
			ship.erase("stop_until")
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
		if mode == "trade":
			ship.erase("_next_trade_search")
			if not enabled:
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
	return REPAIR_QUERIES.damaged_cells(targets, MINER_REPAIR_SEARCH, EPS)

static func _nearby_repair_ids(cells: Dictionary, point: Vector2, neighborhoods: Dictionary = {}) -> Array:
	return REPAIR_QUERIES.nearby_ids(cells, point, MINER_REPAIR_SEARCH, neighborhoods)

static func _repair_retry_due(ship: Dictionary, now: float) -> bool:
	return REPAIR_QUERIES.retry_due(ship, now, EPS)

static func _work_miner_repair(state: Dictionary, graph: Dictionary, ship: Dictionary, targets: Dictionary, dt: float, damaged_cells: Variant = null, repair_neighborhoods: Dictionary = {}) -> bool:
	if ship["kind"] != "miner":
		return false
	ship.erase("repair_target")
	var explicit: bool = ship.has("repair_order")
	# An automatic repair retry cannot run early, regardless of eligibility.
	# Explicit orders and the unindexed reference path bypass this deadline.
	if not explicit and damaged_cells != null and not _repair_retry_due(ship, float(state["elapsed"])):
		return false
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
		var best: float = MINER_REPAIR_SEARCH * MINER_REPAIR_SEARCH
		for id in (targets.keys() if damaged_cells == null else _nearby_repair_ids(damaged_cells, pos, repair_neighborhoods)):
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
	ship.erase("_next_trade_search")
	_clear_resource_stage(ship)
	if ship["kind"] in MILITARY_KINDS:
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
	if ship["kind"] in MILITARY_KINDS:
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
	ship["follow_arrived"] = distance <= reach + FOLLOW_ARRIVAL_TOLERANCE
	if distance <= reach + FOLLOW_ARRIVAL_TOLERANCE:
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
	ship["follow_arrived"] = (ship["position"] as Vector2).distance_to(point) <= reach + FOLLOW_ARRIVAL_TOLERANCE
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
	ship["science_years"] = minf(SCIENCE_COLLECTION_YEARS, float(ship.get("science_years", 0.0)) + dt * _player_factor(state, int(ship["owner"]), "rank_antimatter", 0.15))
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
	ship.erase("_next_trade_search")
	ship["route"] = []
	ship["leg"] = 0.0
	ship["dest"] = -1 if ship["kind"] not in MILITARY_KINDS else int(ship["at"])
	ship.erase("move_only")
	if ship["kind"] in MILITARY_KINDS:
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
		_reset_unit_for_order(craft)
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
		if bool(craft.get("rogue", false)) or not armed(craft) or bool(craft.get("retreating", false)):
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
			if craft["kind"] in MILITARY_KINDS:
				craft["operation_target"] = goal
			continue
		elif craft.has("patrol_from") and craft.get("patrol_arrived", false) and not _engaged(craft):
			var waypoints: Array = craft.get("patrol_waypoints", [])
			if waypoints.is_empty():
				craft["patrol_returning"] = not bool(craft.get("patrol_returning", false))
			else:
				var next_index: int = int(craft["patrol_index"]) + 1
				if next_index >= waypoints.size():
					craft["patrol_index"] = -1
					craft["patrol_returning"] = true
				else:
					var waypoint: Dictionary = waypoints[next_index]
					craft["patrol_index"] = next_index
					craft["patrol_returning"] = false
					craft["patrol_to"] = waypoint["target"]
					craft["patrol_end_point"] = waypoint["point"]
					craft["unit_order"] = waypoint.duplicate(true)
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
			if int(ship["owner"]) != player or ship.get("kind", "") not in MILITARY_KINDS:
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
		return [craft] if not craft.is_empty() and int(craft["owner"]) == player and craft.get("kind", "") != "warp_gate" and not colony_morphing(craft) else []
	var units: Array = []
	var candidates: Array = _ordered_indexed_hull_subset(requested) if _can_index_hull_subset(state, requested) else state["ships"]
	for ship in candidates:
		if requested.has(ship["id"]):
			if int(ship["owner"]) != player or ship.get("kind", "") == "warp_gate" or colony_morphing(ship):
				return []
			units.append(ship)
	return units if units.size() == requested.size() else []

const MAX_UNIT_ORDERS: int = 4

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

static func _set_auto_cooldown(state: Dictionary, ship: Dictionary) -> void:
	var deadline: float = float(state["elapsed"]) + AUTOCAST_COOLDOWN_YEARS
	ship["auto_cooldown_until"] = deadline
	if is_same(state, _deadline_state):
		_cooldown_deadlines.schedule(int(ship["id"]), deadline)

static func _set_unit_order(state: Dictionary, ship: Dictionary, order: Dictionary) -> void:
	ship.erase("colony_transform_progress")
	ship.erase("stop_until")
	ship.erase("wander_anchor")
	_clear_resource_stage(ship)
	ship.erase("arrival_wait_until")
	ship.erase("manual_mine")
	ship.erase("wander_cooldown_override")
	ship.erase("follow_arrived")
	_set_auto_cooldown(state, ship)
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
		"colonize":
			if target >= 0 and target < state["planets"].size():
				if colony_morphing(ship) and ship.get("unit_order", {}) == order:
					return colony_station_position(state, target, float(state["elapsed"]), float(order.get("orbit_phase", INF)))
				return colony_approach_position(state, target, ship["position"])
		"sector":
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
	var patrol_waypoints: Array = ship.get("patrol_waypoints", [])
	if not patrol_waypoints.is_empty():
		active = patrol_waypoints.back()["point"]
	elif ship.has("patrol_from") and ship.get("patrol_returning", false):
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
			var waypoints: Array = ship.get("patrol_waypoints", [])
			var more_legs: bool = not waypoints.is_empty() and not bool(ship.get("patrol_returning", false)) and int(ship.get("patrol_index", 0)) < waypoints.size() - 1
			return ship.has("patrol_from") and ((ship.get("order_queue", []) as Array).is_empty() or more_legs or not ship.get("patrol_arrived", false) or _engaged(ship))
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
	if colony_morphing(ship):
		return false
	var kind: String = str(order.get("kind", ""))
	var owner: int = int(ship["owner"])
	var fighter: bool = ship["kind"] in MILITARY_KINDS
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
	return _valid_targeted_unit_order(state, graph, ship, order, append, fighter)

static func _valid_order_heading(heading: Variant) -> bool:
	return heading is Vector2 and (heading as Vector2).is_finite() and not (heading as Vector2).is_zero_approx()

static func _valid_targeted_unit_order(state: Dictionary, graph: Dictionary, ship: Dictionary, order: Dictionary, append: bool, fighter: bool) -> bool:
	var kind: String = str(order.get("kind", ""))
	var owner: int = int(ship["owner"])
	var target: int = order["target"]
	match kind:
		"position":
			if not order.get("point", null) is Vector2 or not _position_target_valid(state, graph, owner, target, order["point"]):
				return false
			if order.has("heading") and not _valid_order_heading(order["heading"]):
				return false
			return not bool(ship.get("retreating", false)) or append
		"guard":
			return fighter and military_pois(state, owner).has(target) and order.get("point") is Vector2 and _position_target_valid(state, graph, owner, target, order["point"])
		"patrol":
			if order.has("heading") and not _valid_order_heading(order["heading"]):
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
			return not colony_path(state, owner, ship, target).is_empty()
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
				_reset_unit_for_order(ship)
				_finish_manual(ship)
				_set_unit_order(state, ship, order.duplicate(true))
			return true
		"stop":
			return command_stop_units(state, player, ids)
		"hold":
			return command_hold_units(state, player, ids, false)
		"transform":
			return _order_transform(state, player, ids)
		"follow":
			return _order_follow(state, player, ids, order, target)
		"sector_entry":
			return _order_sector_entry(state, player, ids, order, target)
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
				_reset_unit_for_order(ship)
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
			return _order_position(state, player, ids, order, target)
	return false

# Shared preamble for orders that take over a hull: release salvage, tactical
# orders, local hold and autonomous work, in this order.
static func _reset_unit_for_order(ship: Dictionary) -> void:
	_cancel_salvage_order(ship)
	_clear_tactical_order(ship)
	_clear_local_hold(ship)
	_interrupt_work(ship)

static func _order_transform(state: Dictionary, player: int, ids: Array) -> bool:
	var graph: Dictionary = military_graph(state)
	var converted: bool = false
	for ship in _owned_units(state, player, ids):
		if can_transform_colony(state, graph, ship):
			converted = send_colony(state, player, int(ship["id"]), local_sector(graph, ship), true) or converted
	return converted

static func _order_follow(state: Dictionary, player: int, ids: Array, order: Dictionary, target: int) -> bool:
	var units: Array = _owned_units(state, player, ids)
	var refs: Dictionary = service_targets(state)
	if units.is_empty() or units.any(func(ship: Dictionary) -> bool: return not _valid_follow_target(state, ship, target, refs)):
		return false
	for ship in units:
		# Follow deliberately keeps any tactical order, so skip _reset_unit_for_order.
		_cancel_salvage_order(ship)
		_clear_local_hold(ship)
		_interrupt_work(ship)
		_set_unit_order(state, ship, order.duplicate(true))
		# Retain an in-flight lane until the follow worker replans it.
		ship["dest"] = -1
		ship["move_only"] = not bool(order.get("guard", false))
	return true

static func _order_sector_entry(state: Dictionary, player: int, ids: Array, order: Dictionary, target: int) -> bool:
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

static func _order_position(state: Dictionary, player: int, ids: Array, order: Dictionary, target: int) -> bool:
	var accepted: bool = command_local_position(state, player, ids, target, order["point"], bool(order.get("move_only", false)))
	if not accepted:
		accepted = command_remote_position(state, player, ids, target, order["point"], bool(order.get("move_only", false)))
	if accepted:
		for ship in _owned_units(state, player, ids):
			ship["unit_order"] = order.duplicate(true)
			if order.has("heading"):
				ship["arrival_heading"] = (order["heading"] as Vector2).normalized()
	return accepted

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
		var active_count: int = maxi(int(_unit_order_running(ship)), (ship.get("patrol_waypoints", []) as Array).size())
		if queue.size() + active_count >= MAX_UNIT_ORDERS:
			continue
		queue.append(order.duplicate(true))
		ship["order_queue"] = queue
		_extend_patrol_from_queue(state, graph, ship)
		ship.erase("wander_cooldown_override")
		_set_auto_cooldown(state, ship)
		accepted = true
	return accepted

static func _mark_sector_arrival(state: Dictionary, ship: Dictionary) -> void:
	var order: Dictionary = ship.get("unit_order", {})
	if order.get("kind", "") == "sector" and not ship.has("arrival_wait_until") and not bool(ship.get("retreating", false)) and (ship["route"] as Array).is_empty() and int(ship["at"]) == int(order["target"]):
		ship["arrival_wait_until"] = float(state["elapsed"]) + MOVE_ARRIVAL_WAIT_YEARS

static func arrival_wait_remaining(state: Dictionary, ship: Dictionary) -> float:
	return maxf(0.0, float(ship.get("arrival_wait_until", 0.0)) - float(state.get("elapsed", 0.0)))

# Absorb only adjacent patrol orders, leaving unrelated FIFO successors intact.
# This route is authority-owned, replicated with the hull and cleared with its tactical order.
static func _extend_patrol_from_queue(state: Dictionary, graph: Dictionary, ship: Dictionary) -> void:
	if not ship.has("patrol_from") or ship.get("unit_order", {}).get("kind", "") != "patrol":
		return
	var queue: Array = ship.get("order_queue", [])
	if queue.is_empty() or queue[0].get("kind", "") != "patrol":
		return
	var waypoints: Array = ship.get("patrol_waypoints", [])
	while not queue.is_empty() and queue[0].get("kind", "") == "patrol":
		var pending: Dictionary = queue.pop_front()
		if not _valid_unit_order(state, graph, ship, pending, true):
			continue
		pending["point"] = unit_order_point(state, graph, ship, pending)
		if waypoints.is_empty():
			waypoints.append((ship["unit_order"] as Dictionary).duplicate(true))
			ship["patrol_index"] = -1 if bool(ship.get("patrol_returning", false)) else 0
		waypoints.append(pending)
	if not waypoints.is_empty():
		ship["patrol_waypoints"] = waypoints
	if queue.is_empty():
		ship.erase("order_queue")
	else:
		ship["order_queue"] = queue

static func _advance_unit_orders(state: Dictionary, graph: Dictionary) -> void:
	for ship in (state["ships"] as Array).duplicate():
		# Without an active or queued order, every branch below is a no-op.
		# Check live keys at the original phase, so new orders wake immediately.
		if not ship.has("unit_order") and not ship.has("order_queue"):
			continue
		if bool(ship.get("rogue", false)) or colony_morphing(ship):
			continue
		_mark_sector_arrival(state, ship)
		_extend_patrol_from_queue(state, graph, ship)
		if _unit_order_running(ship):
			continue
		if ship.get("unit_order", {}).get("kind", "") == "follow":
			_finish_manual(ship)
			ship.erase("follow_arrived")
		var previous: Dictionary = ship.get("unit_order", {})
		ship.erase("unit_order")
		var queue: Array = ship.get("order_queue", [])
		var dispatched: bool = false
		while not queue.is_empty():
			var order: Dictionary = queue.pop_front()
			if _valid_unit_order(state, graph, ship, order, false) and _execute_unit_order(state, int(ship["owner"]), [ship["id"]], order):
				dispatched = true
				break
		if not dispatched and previous.get("kind", "") == "patrol" and ship.has("patrol_from"):
			ship["unit_order"] = previous
		if queue.is_empty():
			ship.erase("order_queue")
		else:
			ship["order_queue"] = queue
		_extend_patrol_from_queue(state, graph, ship)

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
		_reset_unit_for_order(ship)
		_set_unit_order(state, ship, {"kind": "position", "target": node, "point": point, "move_only": move_only})
		ship["local_move_target"] = point
		ship["local_move_sector"] = node
		ship["move_only"] = move_only
		ship["navigation_target"] = point
		# Extraction must resume by returning to the actual rock.
		if ship.get("kind", "") == "miner" and ship.get("mining_mode", "") == "mining":
			ship["mining_mode"] = "outbound"
		if ship.get("kind", "") in MILITARY_KINDS:
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
		_reset_unit_for_order(ship)
		var nav: Dictionary = _manual_nav(state, graph, ship, node)
		ship["route"] = []
		ship["leg"] = 0.0
		ship["dest"] = nav["node"]
		if ship["kind"] in MILITARY_KINDS:
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
		if sector >= 0 and (ship["kind"] in MILITARY_KINDS or sector < state["planets"].size()):
			ship["at"] = sector
		_interrupt_work(ship)
		_finish_manual(ship)
		ship["navigation_target"] = ship["position"]
		ship["arrival_wait_until"] = float(state["elapsed"]) + MOVE_ARRIVAL_WAIT_YEARS
		ship["stop_until"] = ship["arrival_wait_until"]
		ship["wander_anchor"] = ship["position"]
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
			if ship.get("kind", "") in MILITARY_KINDS:
				ship["operation_target"] = int(ship["at"])
				if not bool(ship.get("retreating", false)):
					ship["dest"] = -1
		elif ship.get("kind", "") in MILITARY_KINDS:
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
	var fighter: bool = ship.get("kind", "") in MILITARY_KINDS
	if fighter and _engaged(ship):
		return false
	var node: int = int(ship["local_move_sector"])
	var destination: Vector2 = ship["local_move_target"]
	if not state.is_empty():
		# _manual_travel already normalizes route/destination and assigns
		# the resolved node on arrival; do not resolve navigation twice.
		if _manual_travel(state, graph, ship, node, destination, dt):
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

static func _work_local_hold(_graph: Dictionary, ship: Dictionary, dt: float) -> void:
	if not ship.has("hold_position"):
		ship["navigation_target"] = ship["position"]
		return
	if (ship["position"] as Vector2).distance_to(ship["hold_position"]) <= EPS:
		ship["navigation_target"] = ship["hold_position"]
		if ship.has("hold_heading"):
			ship["heading"] = ship["hold_heading"]
		ship.erase("move_only")
		return
	# Return to the precise held coordinate, not the old sector center.
	ship["route"] = []
	ship["leg"] = 0.0
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
	var points: Array = graph["points"] if ship.get("kind", "") in MILITARY_KINDS else state["map"]["points"]
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
	_territory_fighter_presence(state, graph, claims, presence, contested, near_ship)
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

static func _territory_fighter_presence(state: Dictionary, graph: Dictionary, claims: Array[int], presence: Dictionary, contested: Dictionary, near_ship: Dictionary) -> void:
	var points: Array = graph["points"]
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
	if other.get("kind", "") not in MILITARY_KINDS or bool(other.get("retreating", false)):
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
	ship.erase("resource_haul_node")
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
		if ship["kind"] in MILITARY_KINDS:
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
		_mark_hull_salvage_busy(craft, busy)
	_mark_pds_salvage_busy(state, busy)
	return busy

static func _mark_hull_salvage_busy(craft: Dictionary, busy: Dictionary) -> void:
	if bool(craft.get("retreating", false)) or _engaged(craft) or int(craft.get("yard_target", -1)) < -1:
		busy[int(craft["id"])] = true
	for key in ["combat_target", "pursuit_target"]:
		var target: int = int(craft.get(key, -1))
		if target >= 0:
			busy[target] = true

static func _mark_pds_salvage_busy(state: Dictionary, busy: Dictionary) -> void:
	for system in state["planets"]:
		for battery in system.get("pds", {}).values():
			var target: int = int(battery.get("target", -1))
			if target >= 0:
				busy[target] = true

static func _salvage_cells(piles: Dictionary, persistent: bool = false) -> Dictionary:
	var cells: Dictionary = {}
	if persistent:
		_salvage_index.begin()
	for id in piles:
		var point: Vector2 = piles[id]["position"]
		var cell := Vector2i(floori(point.x / SALVAGE_APPROACH_RANGE), floori(point.y / SALVAGE_APPROACH_RANGE))
		if persistent:
			_salvage_index.append(cell, id)
		else:
			if not cells.has(cell):
				cells[cell] = []
			cells[cell].append(id)
	return _salvage_index.finish() if persistent else cells

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
	# A clean hull cannot begin salvage when there is no debris. Retain the
	# existing cleanup/delivery path for any hull with prior salvage metadata.
	if piles.is_empty() and not previously_collecting:
		ship.erase("auto_salvage_origin")
		return false
	var prior_origin: int = int(ship.get("auto_salvage_origin", -1))
	_release_auto_salvage(ship, piles)
	ship.erase("auto_salvage_origin")
	if not autocast_ready(state, ship, "salvage"):
		return false
	if cargo_capacity(str(ship.get("kind", "ship"))) <= EPS or _salvage_active(ship) or bool(ship.get("move_only", false)) or busy.has(int(ship["id"])):
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
	var found: Array = _nearest_salvage(state, graph, ship, piles, cells, limit, reachable, sector, civilian, threats)
	var best: int = found[0]
	var best_node: int = found[1]
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
		_approach_salvage(state, graph, ship, pos, point, sector, best_node, reachable, dt)
		return true
	return _finish_salvage_pickup(state, ship, piles, best, civilian, idle, dt)

# Salvage grid cells within reach of pos, in deterministic scan order.
static func _salvage_nearby_cells(cells: Dictionary, pos: Vector2, limit: float) -> Array:
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
	return nearby_cells

# Returns [pile_id, node] for the nearest unclaimed reachable pile (ID breaks ties), or [-1, -1].
static func _nearest_salvage(state: Dictionary, graph: Dictionary, ship: Dictionary, piles: Dictionary, cells: Dictionary, limit: float, reachable: Dictionary, sector: int, civilian: bool, threats: Dictionary) -> Array:
	var pos: Vector2 = ship["position"]
	var nearest: float = limit * limit + EPS
	var best: int = -1
	var best_node: int = -1
	var nearby_cells: Array = _salvage_nearby_cells(cells, pos, limit)
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
	return [best, best_node]

static func _approach_salvage(state: Dictionary, graph: Dictionary, ship: Dictionary, pos: Vector2, point: Vector2, sector: int, best_node: int, reachable: Dictionary, dt: float) -> void:
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

# Tractor the claimed pile; idle civilians keep collecting or switch to delivery.
static func _finish_salvage_pickup(state: Dictionary, ship: Dictionary, piles: Dictionary, best: int, civilian: bool, idle: bool, dt: float) -> bool:
	var pile: Dictionary = piles[best]
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
	var rate: float = (FREIGHTER_TRACTOR_RATE if ship.get("kind", "") == "ship" else TRACTOR_RATE) * float(ship.get("reward_loading_factor", 1.0))
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
		_reset_unit_for_order(best)
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

static func _salvage_depot_route(state: Dictionary, _graph: Dictionary, ship: Dictionary, allow_full: bool = false) -> bool:
	var owner: int = int(ship["owner"])
	if _combat_group(state, owner) <= 0:
		return false
	var best: float = INF
	var chosen: int = -1
	for node in range(state["planets"].size()):
		var system: Dictionary = state["planets"][node]
		if int(system["owner"]) != owner or not has_station(system):
			continue
		var useful: bool = false
		for resource in RESOURCES + [ANTIMATTER]:
			if float(ship.get("cargo", {}).get(resource, 0.0)) > EPS and storage_free(system, resource) > EPS:
				useful = true
				break
		if not useful and not allow_full:
			continue
		var distance: float = (ship["position"] as Vector2).distance_to(station_position(state, node, float(state["elapsed"])))
		if distance < best:
			best = distance
			chosen = node
	if chosen < 0:
		return false
	ship["route"] = [chosen]
	ship["leg"] = 0.0
	ship["source"] = -1
	ship["dest"] = chosen
	ship["salvage_depot"] = chosen
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
	if int(ship.get("salvage_target", -1)) >= 0:
		return _salvage_pickup(state, graph, ship, dt, busy)
	# Deliver physically to an owned warehouse, respecting storage limits.
	if busy and ship.get("kind", "") in MILITARY_KINDS:
		return false
	if _cargo_total(ship) <= EPS:
		_cancel_salvage_order(ship)
		return false
	return _salvage_delivery(state, graph, ship, dt)

static func _salvage_pickup(state: Dictionary, graph: Dictionary, ship: Dictionary, dt: float, busy: bool) -> bool:
	var id: int = int(ship.get("salvage_target", -1))
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
			var next: int = _next_wreck_salvage(graph, ship, piles, point)
			if next >= 0:
				ship["salvage_target"] = next
				piles[next]["claim"] = int(ship["id"])
				return true
		ship["salvage_delivery"] = _cargo_total(ship) > EPS
	return true

static func _next_wreck_salvage(graph: Dictionary, ship: Dictionary, piles: Dictionary, point: Vector2) -> int:
	var next: int = -1
	var distance: float = INF
	for candidate in piles:
		var other: Dictionary = piles[candidate]
		var d: float = point.distance_to(other["position"])
		if d <= 80.0 and d < distance and int(other["claim"]) < 0 and _salvage_reachable(graph, ship, other["position"]):
			next = int(candidate)
			distance = d
	return next

static func _salvage_delivery(state: Dictionary, graph: Dictionary, ship: Dictionary, dt: float) -> bool:
	var depot: int = _salvage_depot(state, graph, ship)
	if depot < 0:
		return true
	var military: bool = ship["kind"] in MILITARY_KINDS
	var nav: Dictionary = graph if military else state["map"]
	var dock: Vector2 = station_position(state, depot, float(state["elapsed"]))
	if not (ship["route"] as Array).is_empty():
		_move(state if not military else {"map": nav, "ships": state["ships"]}, ship, dt, dock, depot, STATION_DOCK_RANGE)
		if not ship["route"].is_empty():
			return true
	else:
		var berth: Vector2 = _waiting_berth(state, ship, dock, STATION_DOCK_RANGE, dock.direction_to(ship["position"]))
		_navigate(ship, berth, ship_speed(str(ship.get("kind", "ship"))) * dt)
	if (ship["position"] as Vector2).distance_to(dock) > STATION_DOCK_RANGE + EPS:
		return true
	var budget: float = _unload_salvage(state, ship, depot, dt)
	if _cargo_total(ship) <= EPS:
		_cancel_salvage_order(ship)
	elif budget > EPS:
		ship.erase("salvage_depot")
	return true

# Returns the current valid depot, replanning on a throttled schedule; -1 means wait this tick.
static func _salvage_depot(state: Dictionary, graph: Dictionary, ship: Dictionary) -> int:
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
	if depot >= 0 and int(state["planets"][depot]["owner"]) == owner and has_station(state["planets"][depot]):
		return depot
	ship.erase("salvage_depot")
	if float(state["elapsed"]) + EPS < float(ship.get("next_salvage_search", 0.0)):
		return -1
	ship["next_salvage_search"] = _next_search_slot(float(state["elapsed"]), int(ship["id"]), 0.5)
	if not _salvage_depot_route(state, graph, ship):
		if ship.get("kind", "") not in ["ship", "colony_ship", "miner"] or not _salvage_depot_route(state, graph, ship, true):
			return -1
	return int(ship["salvage_depot"])

static func _unload_salvage(state: Dictionary, ship: Dictionary, depot: int, dt: float) -> float:
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
	return budget

static func _ship_hit(damage: Dictionary, killed_by: Dictionary, health: Dictionary, target: int, attacker: Dictionary, amount: float, hull_slots: Dictionary = {}, hull_health: PackedFloat64Array = PackedFloat64Array()) -> void:
	COMBAT_KERNELS.ship_hit(damage, killed_by, health, target, attacker, amount, hull_slots, hull_health, EPS)

# Resolve one shot from every mounted blaster at each burst interval.
# Damage is authoritative and simultaneous with other weapons; projectile
# tracer metadata is compact and rides the existing combat snapshot.
# Use the frozen combat spatial index, including structures, for missile splash.
# Same-team missiles striking the same frozen target have identical
# splash recipients. Preserve traversal order and do not filter by visibility.
static func _missile_splash_ids(state: Dictionary, cells: Dictionary, positions: Dictionary, teams: Dictionary, team: int, target: int, groups: Dictionary = {}) -> Array:
	var key: Array = [team, target]
	if groups.has(key):
		return groups[key]
	var impact: Vector2 = positions[target]
	var cell := Vector2i(floori(impact.x / LASER_RANGE), floori(impact.y / LASER_RANGE))
	var ids: Array = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			for other in cells.get(cell + Vector2i(x, y), []):
				var id: int = int(other["id"])
				if _combat_groups_hostile(state, team, int(teams[id])) and impact.distance_squared_to(positions[id]) <= MISSILE_SPLASH_RADIUS * MISSILE_SPLASH_RADIUS:
					ids.append(id)
	# Bound retained memory in unusually dense combat.
	if groups.size() < 4096 and ids.size() <= 256:
		groups[key] = ids
	return ids

static func _missile_splash(state: Dictionary, cells: Dictionary, positions: Dictionary, teams: Dictionary, team: int, target: int, attacker: Dictionary, amount: float, damage: Dictionary, killed_by: Dictionary, health: Dictionary, hull_slots: Dictionary, hull_health: PackedFloat64Array, groups: Dictionary = {}) -> void:
	for id in _missile_splash_ids(state, cells, positions, teams, team, target, groups):
		# Do not aggregate hits: per-attacker multipliers, damage ordering
		# and lethal-hit attribution must remain unchanged.
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
	return COMBAT_KERNELS.laser_blocks(candidates, positions, include_structures)

static func _laser_block_nearest(blocks: Array, _positions: Dictionary, pos: Vector2, best: float, target: int) -> Array:
	return COMBAT_KERNELS.laser_block_nearest(blocks, _positions, pos, best, target)

static func _missile_block_nearest(blocks: Array, _positions: Dictionary, pos: Vector2, best: float, target: int, focused: bool, focus_id: int) -> Array:
	return COMBAT_KERNELS.missile_block_nearest(blocks, _positions, pos, best, target, focused, focus_id)

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

# Prove an empty combat interaction graph from the current phase, before
# building any hull position/health/sector/cell buffers. No persistent
# certificate: diplomacy, structures, cloaking or orders wake immediately.
static func _peaceful_combat_possible(state: Dictionary, ships: Array) -> bool:
	var owners: Dictionary = {}
	for ship in ships:
		# Keep the full path for any target cleanup, detection or pirate logic.
		if bool(ship.get("rogue", false)) or bool(ship.get("cloaked", false)) or ship.has("attack_order") or int(ship.get("combat_target", -1)) != -1 or int(ship.get("pursuit_target", -1)) != -1 or int(ship.get("yard_target", -1)) != -1 or not ship.get("pursuit_blocked", {}).is_empty():
			return false
		owners[int(ship["owner"])] = true
	for system in state["planets"]:
		if has_station(system) or not system["yards"].is_empty() or not system.get("pds", {}).is_empty() or not system.get("station", {}).get("weapons", []).is_empty():
			owners[int(system["owner"])] = true
	var groups: Dictionary = {}
	for owner in owners:
		var team: int = _combat_group(state, int(owner))
		if team <= 0 or team == PIRATE_COMBAT_GROUP:
			return false
		groups[team] = true
	for team in groups:
		for other in groups:
			if _combat_groups_hostile(state, int(team), int(other)):
				return false
	return true

# One simultaneous resolution per step: freeze positions and health, let every
# hull and structure choose targets and accumulate damage, then apply it all.
# Phase order and ship iteration order are part of the simulation contract.
static func _combat(state: Dictionary, graph: Dictionary, dt: float, threat_index: Dictionary = {}, activity_fast_paths: bool = true, persistent_buckets: bool = false, collect_threats: bool = true) -> void:
	var ships: Array = state["ships"]
	if activity_fast_paths and _peaceful_combat_possible(state, ships):
		# Preserve the exact civilian threat snapshot when requested, but
		# omit target, damage, sector fallback and structure geometry.
		var empty_frame: COMBAT_FRAME = _build_combat_frame(state, graph, ships, threat_index, false, true, true) if collect_threats else COMBAT_FRAME.new()
		empty_frame.activity_bounds_ready = true
		for ship in ships:
			_combat_hull(state, empty_frame, ship, dt, true)
		_fire_station_weapons(state, empty_frame, dt)
		_fire_planetary_defenses(state, graph, empty_frame, dt)
		_resolve_combat_damage(state, graph, empty_frame, ships)
		return
	var frame: COMBAT_FRAME = _build_combat_frame(state, graph, ships, threat_index, persistent_buckets, collect_threats)
	# Optional reference path for state-equivalence tests.
	frame.activity_bounds_ready = activity_fast_paths
	_detect_cloaked(state, ships, frame.cells, frame.positions, frame.team_by_id)
	for ship in ships:
		_combat_hull(state, frame, ship, dt)
	_fire_station_weapons(state, frame, dt)
	_fire_planetary_defenses(state, graph, frame, dt)
	_resolve_combat_damage(state, graph, frame, ships)

# Freeze hull/structure positions, health and spatial buckets; also publish the
# armed-hull threat snapshot consumed later by civilian safety checks.
static func _build_combat_frame(state: Dictionary, graph: Dictionary, ships: Array, threat_index: Dictionary, persistent_buckets: bool = false, collect_threats: bool = true, threat_only: bool = false) -> COMBAT_FRAME:
	if persistent_buckets and not threat_only:
		if not is_same(state, _combat_index_state) or not is_same(ships, _combat_index_roster):
			_combat_index_state = state
			_combat_index_roster = ships
			_combat_cell_index.clear()
			_combat_sector_index.clear()
		_combat_cell_index.begin()
		_combat_sector_index.begin()
	var positions: Dictionary = {}
	# Combat needs a frozen reference map until simultaneous damage resolves.
	var indexed: bool = not threat_only and is_same(state, _indexed_state)
	var by_id: Dictionary = _hulls_by_id.duplicate() if indexed else {}
	var team_by_id: Dictionary = {}
	var hull_slots: Dictionary = {}
	var hull_positions := PackedVector2Array()
	var hull_health := PackedFloat64Array()
	var hull_teams := PackedInt32Array()
	var previous_targets := PackedInt64Array()
	var ship_sectors := PackedInt32Array()
	if not threat_only:
		hull_positions.resize(ships.size())
		hull_health.resize(ships.size())
		hull_teams.resize(ships.size())
		previous_targets.resize(ships.size())
		ship_sectors.resize(ships.size())
	var health: Dictionary = {}
	var cells: Dictionary = {}
	var sectors: Dictionary = {}
	var sector_teams: Dictionary = {}
	var activity_bounds: Dictionary = {}
	var threat_sectors: Dictionary = {}
	var threat_cells: Dictionary = {}
	var threat_positions := PackedVector2Array()
	var threat_teams := PackedInt32Array()
	var threat_ids := PackedInt64Array()
	var threat_count: int = 0
	var all_sectors: Array = []
	for ship in ships:
		var needs_threat: bool = collect_threats and armed(ship) and ship.get("position", Vector2.INF).is_finite()
		if threat_only and not needs_threat:
			continue
		var id: int = int(ship["id"])
		var pos: Vector2 = combat_position(state, graph, ship)
		var team: int = _combat_group(state, int(ship["owner"]))
		var sector: int = local_sector(graph, ship)
		var combat_cell := Vector2i(floori(pos.x / LASER_RANGE), floori(pos.y / LASER_RANGE))
		var slot: int = hull_slots.size()
		if not threat_only:
			positions[id] = pos
			if not indexed:
				by_id[id] = ship
			team_by_id[id] = team
			hull_health[slot] = _effective_health(ship, ship_max_hp(str(ship["kind"])))
			hull_slots[id] = slot
			hull_positions[slot] = pos
			hull_teams[slot] = team
			previous_targets[slot] = int(ship.get("combat_target", -1))
			_include_combat_activity_cell(activity_bounds, team, combat_cell)
		if needs_threat:
			var threat_team: int = team
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
		if threat_only:
			continue
		if sector < 0:
			if all_sectors.is_empty():
				all_sectors = range(graph["points"].size())
			sector = sector_at(graph, pos, all_sectors)
		ship_sectors[slot] = sector
		if sector >= 0:
			if persistent_buckets:
				_combat_sector_index.append(sector, ship)
			else:
				if not sectors.has(sector):
					sectors[sector] = []
				sectors[sector].append(ship)
			if not sector_teams.has(sector):
				sector_teams[sector] = {}
			sector_teams[sector][int(team_by_id[id])] = true
		if persistent_buckets:
			_combat_cell_index.append(combat_cell, ship)
		else:
			if not cells.has(combat_cell):
				cells[combat_cell] = []
			cells[combat_cell].append(ship)
	if persistent_buckets and not threat_only:
		cells = _combat_cell_index.finish()
		sectors = _combat_sector_index.finish()
	if collect_threats:
		threat_index["snapshot"] = {"sectors": threat_sectors, "cells": threat_cells, "positions": threat_positions, "teams": threat_teams, "ids": threat_ids}
		threat_index["count"] = threat_count
	var frame := COMBAT_FRAME.new()
	if threat_only:
		return frame
	frame.positions = positions
	frame.by_id = by_id
	frame.team_by_id = team_by_id
	frame.health = health
	frame.hull_slots = hull_slots
	frame.hull_positions = hull_positions
	frame.hull_health = hull_health
	frame.hull_teams = hull_teams
	frame.previous_targets = previous_targets
	frame.ship_sectors = ship_sectors
	frame.cells = cells
	frame.sectors = sectors
	frame.sector_teams = sector_teams
	frame.activity_bounds = activity_bounds
	_index_combat_structures(state, frame, persistent_buckets)
	frame.activity_bounds_ready = true
	return frame

# Stations and shipyards share the frozen combat maps with hulls.
# Detach a retained hull bucket before adding its first structure.
static func _insert_combat_structure(cells: Dictionary, point: Vector2, entry: Dictionary, detached: Dictionary, persistent_buckets: bool) -> void:
	var cell := Vector2i(floori(point.x / LASER_RANGE), floori(point.y / LASER_RANGE))
	if not cells.has(cell):
		cells[cell] = []
		detached[cell] = true
	elif persistent_buckets and not detached.has(cell):
		cells[cell] = (cells[cell] as Array).duplicate()
		detached[cell] = true
	cells[cell].append(entry)

static func _index_combat_structures(state: Dictionary, frame: COMBAT_FRAME, persistent_buckets: bool = false) -> void:
	var yard_targets: Dictionary = {}
	var station_targets: Dictionary = {}
	var positions: Dictionary = frame.positions
	var health: Dictionary = frame.health
	var team_by_id: Dictionary = frame.team_by_id
	var cells: Dictionary = frame.cells
	var detached: Dictionary = {}
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
			_insert_combat_structure(cells, pos, {"id": target_id, "owner": system["owner"], "kind": "station"}, detached, persistent_buckets)
			_include_combat_activity_cell(frame.activity_bounds, int(team_by_id[target_id]), Vector2i(floori(pos.x / LASER_RANGE), floori(pos.y / LASER_RANGE)))
		for slot in range(system["yards"].size()):
			var target_id: int = -2 - index * 3 - slot
			var pos: Vector2 = shipyard_position(state, index, slot, float(state["elapsed"]))
			yard_targets[target_id] = Vector2i(index, slot)
			health[target_id] = float(system["yards"][slot].get("hp", YARD_HP * int(system["yards"][slot]["level"])))
			positions[target_id] = pos
			team_by_id[target_id] = _combat_group(state, int(system["owner"]))
			_insert_combat_structure(cells, pos, {"id": target_id, "owner": system["owner"], "kind": "shipyard"}, detached, persistent_buckets)
			_include_combat_activity_cell(frame.activity_bounds, int(team_by_id[target_id]), Vector2i(floori(pos.x / LASER_RANGE), floori(pos.y / LASER_RANGE)))
	frame.yard_targets = yard_targets
	frame.station_targets = station_targets

# Conservative occupancy envelopes in the very same integer cells as
# weapon acquisition. A disjoint window proves the original scan empty.
# Include every hull/structure, even cloaked or unarmed ones.
static func _include_combat_activity_cell(bounds: Dictionary, team: int, cell: Vector2i) -> void:
	var point_rect := Rect2i(cell, Vector2i.ONE)
	if not bounds.has(team):
		bounds[team] = point_rect
	else:
		var previous: Rect2i = bounds[team]
		if not previous.has_point(cell):
			bounds[team] = previous.merge(point_rect)

static func _combat_window_may_have_hostile(state: Dictionary, frame: COMBAT_FRAME, team: int, cell: Vector2i, reach: int, positive_only: bool = false) -> bool:
	if not frame.activity_bounds_ready:
		return true
	var cache_key := Vector2i(team, int(positive_only))
	if not frame.activity_hostile_bounds.has(cache_key):
		var hostile_bounds: Array = []
		for other_team in frame.activity_bounds:
			if (not positive_only or int(other_team) > 0) and _combat_groups_hostile(state, team, int(other_team)):
				hostile_bounds.append(frame.activity_bounds[other_team])
		frame.activity_hostile_bounds[cache_key] = hostile_bounds
	var window := Rect2i(cell - Vector2i.ONE * reach, Vector2i.ONE * (reach * 2 + 1))
	for rect in frame.activity_hostile_bounds[cache_key]:
		if window.intersects(rect):
			return true
	return false

# Weapon selection for one hull. Writes only that hull's combat fields and the
# shared damage accumulators; never mutates another hull or the frame snapshot.
static func _combat_hull(state: Dictionary, frame: COMBAT_FRAME, ship: Dictionary, dt: float, peaceful: bool = false) -> void:
	if bool(ship.get("rogue", false)):
		if int(ship["owner"]) == PIRATE_OWNER:
			_pirate_fire(state, ship, frame.positions, frame.by_id, frame.cells, frame.team_by_id, frame.damage, frame.killed_by, frame.health, frame.hull_slots, frame.hull_health, dt)
		return
	var fighter: bool = ship.get("kind", "") in MILITARY_KINDS
	var miner: bool = ship.get("kind", "") == "miner"
	if not fighter and not miner:
		return
	if miner:
		ship["mining_active"] = false
	var weapon_damage: float = MINER_LASER_DAMAGE if miner else LASER_DAMAGE * float(capital_lasers(str(ship["kind"])))
	var moving_only: bool = bool(ship.get("move_only", false)) and (ship.has("launch_rally") or ship.has("local_move_target") or ship.get("unit_order", {}).get("kind", "") == "follow" or not (ship["route"] as Array).is_empty() or (ship.has("hold_position") and (ship["position"] as Vector2).distance_to(ship["hold_position"]) > EPS))
	if not moving_only:
		ship.erase("move_only")
	elif not peaceful and fighter and not bool(ship.get("holding", false)) and _combat_sector_has_hostile(frame.sector_teams, int(frame.ship_sectors[frame.hull_slots[int(ship["id"])]]), _combat_group(state, int(ship["owner"])), state):
		moving_only = false
	ship["passing_fire"] = moving_only and fighter
	if bool(ship.get("retreating", false)) or ship.has("cargo_order") or ship.has("repair_order"):
		ship["combat_target"] = -1
		ship["pursuit_target"] = -1
		ship["pursuit_left"] = 0.0
		ship["laser_until"] = -1.0
		ship["yard_target"] = -1
		ship["yard_laser_until"] = -1.0
		_fire_blaster(state, ship, -1, frame.positions, frame.damage, frame.killed_by, frame.health, dt, frame.hull_slots, frame.hull_health)
		return
	if peaceful:
		_advance_peaceful_weapons(state, frame, ship, dt)
		return
	var hull_slot: int = int(frame.hull_slots[int(ship["id"])])
	var pos: Vector2 = frame.hull_positions[hull_slot]
	var team: int = frame.hull_teams[hull_slot]
	_fire_hull_missiles(state, frame, ship, pos, team, dt)
	if _fire_focused_attack(state, frame, ship, pos, team, hull_slot, weapon_damage, dt):
		return
	_fire_hull_lasers(state, frame, ship, fighter, moving_only, pos, team, hull_slot, weapon_damage, dt)

static func _fire_hull_missiles(state: Dictionary, frame: COMBAT_FRAME, ship: Dictionary, pos: Vector2, team: int, dt: float) -> void:
	var launchers: int = missile_count(str(ship["kind"]))
	if launchers <= 0:
		return
	var positions: Dictionary = frame.positions
	var missile_cd: float = maxf(0.0, float(ship.get("missile_cooldown", 0.0)) - dt)
	if missile_cd <= EPS:
		var missile_target: int = -1
		var best: float = MISSILE_RANGE * MISSILE_RANGE
		var focus_id: int = int(ship.get("attack_order", -1))
		var missile_cell := Vector2i(floori(pos.x / LASER_RANGE), floori(pos.y / LASER_RANGE))
		if team > 0:
			var focused: bool = ship.has("attack_order")
			var nearest: Array = _missile_block_nearest(_missile_neighborhood_blocks(state, frame, missile_cell, team), positions, pos, best, missile_target, focused, focus_id)
			missile_target = int(nearest[1])
		if missile_target != -1:
			_missile_splash(state, frame.cells, positions, frame.team_by_id, team, missile_target, ship, MISSILE_DAMAGE * launchers * _player_factor(state, int(ship["owner"]), "rank_missile", 0.10), frame.damage, frame.killed_by, frame.health, frame.hull_slots, frame.hull_health, frame.missile_splash_groups)
			missile_cd = MISSILE_COOLDOWN
			ship["missile_origin"] = pos
			ship["missile_endpoint"] = positions[missile_target]
			ship["missile_until"] = float(state["elapsed"]) + 0.65
	ship["missile_cooldown"] = missile_cd

# Auto-group missile broad-phase work by team and origin cell. Keep
# original per-cell blocks and order: equal-distance missiles prefer the
# last matching candidate, unlike lasers. Focus and range remain per hull.
static func _missile_neighborhood_blocks(state: Dictionary, frame: COMBAT_FRAME, cell: Vector2i, team: int) -> Array:
	if not _combat_window_may_have_hostile(state, frame, team, cell, ceili(MISSILE_RANGE / LASER_RANGE), true):
		return []
	if not frame.missile_neighborhoods.has(team):
		frame.missile_neighborhoods[team] = {}
	var neighborhoods: Dictionary = frame.missile_neighborhoods[team]
	if neighborhoods.has(cell):
		return neighborhoods[cell]
	if not frame.missile_blocks.has(team):
		frame.missile_blocks[team] = {}
	var team_blocks: Dictionary = frame.missile_blocks[team]
	var blocks: Array = []
	var reach: int = ceili(MISSILE_RANGE / LASER_RANGE)
	for x in range(-reach, reach + 1):
		for y in range(-reach, reach + 1):
			var key: Vector2i = cell + Vector2i(x, y)
			if not team_blocks.has(key):
				var candidates: Array = _hostile_bucket(state, frame.cells, frame.positive_hostile_cache, key, team, frame.team_by_id, true)
				team_blocks[key] = _laser_blocks(candidates, frame.positions, true)
			blocks.append_array(team_blocks[key])
	if neighborhoods.size() < 1024 and blocks.size() <= 512:
		neighborhoods[cell] = blocks
	return blocks

# Explicit attack is focus fire, never attack-move: even when another
# hostile is closer, only the ordered entity may receive damage.
# Returns true when the focused target consumed this hull's weapons.
static func _fire_focused_attack(state: Dictionary, frame: COMBAT_FRAME, ship: Dictionary, pos: Vector2, team: int, hull_slot: int, weapon_damage: float, dt: float) -> bool:
	var positions: Dictionary = frame.positions
	var by_id: Dictionary = frame.by_id
	if not (ship.has("attack_order") and positions.has(int(ship["attack_order"])) and _combat_groups_hostile(state, team, int(frame.team_by_id.get(int(ship["attack_order"]), 0))) and (not by_id.has(int(ship["attack_order"])) or ship_visible_to_team(state, by_id[int(ship["attack_order"])], team)) and pos.distance_to(positions[int(ship["attack_order"])]) <= LASER_RANGE):
		return false
	var focus: int = int(ship["attack_order"])
	var in_range: bool = positions.has(focus) and pos.distance_to(positions[focus]) <= LASER_RANGE
	ship["combat_target"] = focus if in_range and focus >= 0 else -1
	ship["yard_target"] = focus if in_range and focus < -1 else -1
	ship["pursuit_target"] = -1
	ship["pursuit_left"] = 0.0
	ship["laser_until"] = -1.0 if int(frame.previous_targets[hull_slot]) != int(ship["combat_target"]) else ship.get("laser_until", -1.0)
	var focus_cooldown: float = maxf(0.0, float(ship.get("laser_cooldown", 0.0)) - dt)
	if in_range and weapon_damage > 0.0 and focus_cooldown <= EPS:
		_ship_hit(frame.damage, frame.killed_by, frame.health, focus, ship, weapon_damage, frame.hull_slots, frame.hull_health)
		focus_cooldown = 1.0
		ship["laser_until" if focus >= 0 else "yard_laser_until"] = float(state["elapsed"]) + 0.2
	ship["laser_cooldown"] = focus_cooldown
	_fire_blaster(state, ship, focus if in_range else -1, positions, frame.damage, frame.killed_by, frame.health, dt, frame.hull_slots, frame.hull_health)
	return true

# Nearest-hostile lasers, bounded pursuit, guard limits and the structure
# fallback. Laser and blaster share the selected target.
# Same field order and defaults as the inactive full-frame laser path.
static func _normalize_inactive_lasers(ship: Dictionary, dt: float) -> void:
	ship["pursuit_target"] = -1
	ship["pursuit_left"] = 0.0
	ship["pursuit_blocked"] = ship.get("pursuit_blocked", {})
	ship["combat_target"] = -1
	ship["laser_cooldown"] = maxf(0.0, float(ship.get("laser_cooldown", 0.0)) - dt)
	ship["yard_target"] = -1

# No target is possible. Advance the same ordinary timer/metadata writes
# without computing a sector, cell, health slot or target candidate list.
static func _advance_peaceful_weapons(state: Dictionary, frame: COMBAT_FRAME, ship: Dictionary, dt: float) -> void:
	if missile_count(str(ship["kind"])) > 0:
		ship["missile_cooldown"] = maxf(0.0, float(ship.get("missile_cooldown", 0.0)) - dt)
	var now: float = float(state["elapsed"])
	var search_due: bool = _combat_search_due(ship, now)
	if search_due:
		ship["_next_laser_refresh"] = _next_search_slot(now, int(ship["id"]) % 2 * 2, 0.2)
	_normalize_inactive_lasers(ship, dt)
	if search_due:
		ship["_next_combat_search"] = _next_search_slot(now, int(ship["id"]) % 2 * 2, 0.2)
	_fire_blaster(state, ship, -1, frame.positions, frame.damage, frame.killed_by, frame.health, dt, frame.hull_slots, frame.hull_health)

static func _fire_hull_lasers(state: Dictionary, frame: COMBAT_FRAME, ship: Dictionary, fighter: bool, moving_only: bool, pos: Vector2, team: int, hull_slot: int, weapon_damage: float, dt: float) -> void:
	var positions: Dictionary = frame.positions
	var by_id: Dictionary = frame.by_id
	var hull_slots: Dictionary = frame.hull_slots
	var previous_targets: PackedInt64Array = frame.previous_targets
	var ship_sectors: PackedInt32Array = frame.ship_sectors
	var id: int = int(ship["id"])
	var cell := Vector2i(floori(pos.x / LASER_RANGE), floori(pos.y / LASER_RANGE))
	var target: int = -1
	var now: float = float(state["elapsed"])
	var search_due: bool = _combat_search_due(ship, now)
	# No retained or previous target, no pursuit cleanup, and no due
	# search: only the ordinary cooldown and normalized fields remain.
	if frame.activity_bounds_ready and not search_due and int(previous_targets[hull_slot]) == -1 and ship.get("pursuit_blocked", {}).is_empty():
		_normalize_inactive_lasers(ship, dt)
		_fire_blaster(state, ship, -1, positions, frame.damage, frame.killed_by, frame.health, dt, hull_slots, frame.hull_health)
		return
	var guard: Dictionary = ship.get("unit_order", {})
	var guard_node: int = int(guard["target"]) if guard.get("kind", "") == "guard" else -1
	var pursuit: int = int(ship.get("pursuit_target", -1)) if fighter else -1
	var remaining: float = float(ship.get("pursuit_left", 0.0))
	var blocked: Dictionary = ship.get("pursuit_blocked", {})
	for blocked_id in blocked.keys():
		if not positions.has(blocked_id) or pos.distance_squared_to(positions[blocked_id]) > LASER_RANGE * LASER_RANGE:
			blocked.erase(blocked_id)
	if moving_only or bool(ship.get("holding", false)) or (guard_node >= 0 and (ship_sectors[hull_slot] != guard_node or frame.sector_of(pursuit) != guard_node)):
		pursuit = -1
	if pursuit >= 0:
		var checked: Array = _validate_pursuit(state, frame, id, pursuit, remaining, pos, team, hull_slot, blocked)
		pursuit = int(checked[0])
		remaining = float(checked[1])
	target = _scan_laser_target(state, frame, ship, pos, team, cell, now, search_due)
	if fighter and not moving_only and not bool(ship.get("holding", false)) and pursuit < 0:
		var acquired: int = _acquire_pursuit(state, frame, pos, team, hull_slot, target, blocked, search_due)
		if acquired >= 0:
			pursuit = acquired
			remaining = PURSUIT_YEARS
	if guard_node >= 0:
		var guarded: int = guard_node
		if frame.sector_of(pursuit) != guarded or ship_sectors[hull_slot] != guarded:
			pursuit = -1
		if target >= 0 and (frame.sector_of(target) != guarded or ship_sectors[hull_slot] != guarded):
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
		_ship_hit(frame.damage, frame.killed_by, frame.health, target, ship, weapon_damage, hull_slots, frame.hull_health)
		cooldown = 1.0
		ship["laser_until"] = float(state["elapsed"]) + 0.2
	ship["laser_cooldown"] = cooldown
	ship["yard_target"] = -1
	if search_due and target < 0 and pursuit < 0:
		_fire_hull_at_structures(state, frame, ship, pos, team, cell, weapon_damage, cooldown)
	if target >= 0 or pursuit >= 0 or int(ship["yard_target"]) < -1:
		ship.erase("_next_combat_search")
	elif search_due:
		# Two tick slots at the normal 0.1 simulation step.
		ship["_next_combat_search"] = _next_search_slot(now, int(ship["id"]) % 2 * 2, 0.2)
	_fire_blaster(state, ship, target if target >= 0 else int(ship["yard_target"]), positions, frame.damage, frame.killed_by, frame.health, dt, hull_slots, frame.hull_health)

# Keep a pursuit only while it remains hostile, visible and worth chasing.
static func _validate_pursuit(state: Dictionary, frame: COMBAT_FRAME, id: int, pursuit: int, remaining: float, pos: Vector2, team: int, hull_slot: int, blocked: Dictionary) -> Array:
	var positions: Dictionary = frame.positions
	var by_id: Dictionary = frame.by_id
	var hull_slots: Dictionary = frame.hull_slots
	var previous_targets: PackedInt64Array = frame.previous_targets
	var ship_sectors: PackedInt32Array = frame.ship_sectors
	if ship_sectors[hull_slot] >= 0 and frame.sector_of(pursuit) == ship_sectors[hull_slot]:
		remaining = PURSUIT_YEARS
	if not by_id.has(pursuit) or not _combat_groups_hostile(state, team, _combat_group(state, int(by_id[pursuit]["owner"]))) or team == 0 or not ship_visible_to_team(state, by_id[pursuit], team):
		pursuit = -1
	elif remaining <= EPS:
		# Do not immediately restart a timed-out chase while the same
		# escaping hull is still in range. A fresh contact may engage.
		blocked[pursuit] = true
		pursuit = -1
	elif by_id[pursuit].get("kind", "") in MILITARY_KINDS and not bool(by_id[pursuit].get("retreating", false)) and int(previous_targets[hull_slots[pursuit]]) == id and pos.distance_squared_to(positions[pursuit]) <= LASER_RANGE * LASER_RANGE:
		pursuit = -1
	return [pursuit, remaining]

static func _scan_laser_target(state: Dictionary, frame: COMBAT_FRAME, ship: Dictionary, pos: Vector2, team: int, cell: Vector2i, now: float, search_due: bool) -> int:
	var positions: Dictionary = frame.positions
	var by_id: Dictionary = frame.by_id
	var target: int = -1
	var best: float = LASER_RANGE * LASER_RANGE
	var reusable: int = _reusable_laser_target(state, ship, by_id, positions, pos, now)
	if reusable >= 0:
		target = reusable
	elif team != 0 and search_due:
		ship["_next_laser_refresh"] = _next_search_slot(now, int(ship["id"]) % 2 * 2, 0.2)
		var nearest: Array = _laser_block_nearest(_laser_neighborhood_blocks(state, frame, cell, team), positions, pos, best, target)
		target = int(nearest[1])
	return target

# All hulls in one cell querying the same team see the same ordered blocks.
# Preserve the old x/y traversal, per-cell block boundaries and lazy hostile
# bucket population; range and approximate tie resolution stay per attacker.
static func _laser_neighborhood_blocks(state: Dictionary, frame: COMBAT_FRAME, cell: Vector2i, team: int) -> Array:
	if not _combat_window_may_have_hostile(state, frame, team, cell, 1):
		return []
	if not frame.laser_neighborhoods.has(team):
		frame.laser_neighborhoods[team] = {}
	var neighborhoods: Dictionary = frame.laser_neighborhoods[team]
	if neighborhoods.has(cell):
		return neighborhoods[cell]
	if not frame.laser_blocks.has(team):
		frame.laser_blocks[team] = {}
	var team_blocks: Dictionary = frame.laser_blocks[team]
	var blocks: Array = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			var key: Vector2i = cell + Vector2i(x, y)
			if not team_blocks.has(key):
				team_blocks[key] = _laser_blocks(_hostile_bucket(state, frame.cells, frame.hostile_cache, key, team, frame.team_by_id), frame.positions)
			blocks.append_array(team_blocks[key])
	neighborhoods[cell] = blocks
	return blocks

# Start a new chase when the current or prior target flees, or, on a search
# tick, from the nearest hostile hull in the same sector.
static func _acquire_pursuit(state: Dictionary, frame: COMBAT_FRAME, pos: Vector2, team: int, hull_slot: int, target: int, blocked: Dictionary, search_due: bool) -> int:
	var positions: Dictionary = frame.positions
	var by_id: Dictionary = frame.by_id
	var hull_slots: Dictionary = frame.hull_slots
	var previous_targets: PackedInt64Array = frame.previous_targets
	var ship_sectors: PackedInt32Array = frame.ship_sectors
	if target >= 0:
		if not blocked.has(target) and _fleeing(by_id[target], positions[target] - pos, int(previous_targets[hull_slots[target]])):
			return target
		return -1
	# A previously engaged fighter may escape the firing envelope before
	# the next scan; its departure is still a valid pursuit trigger.
	var prior: int = int(previous_targets[hull_slot])
	if by_id.has(prior) and not blocked.has(prior) and team != 0 and _combat_groups_hostile(state, team, _combat_group(state, int(by_id[prior]["owner"]))) and ship_visible_to_team(state, by_id[prior], team) and _fleeing(by_id[prior], positions[prior] - pos, int(previous_targets[hull_slots[prior]])):
		return prior
	if not search_due or team <= 0 or not _combat_sector_has_hostile(frame.sector_teams, int(ship_sectors[hull_slot]), team, state):
		return -1
	if not frame.pursuit_blocks.has(team):
		frame.pursuit_blocks[team] = {}
	var team_blocks: Dictionary = frame.pursuit_blocks[team]
	var sector: int = int(ship_sectors[hull_slot])
	if not team_blocks.has(sector):
		var candidates: Array = _hostile_bucket(state, frame.sectors, frame.sector_hostile_cache, sector, team, frame.team_by_id, true)
		team_blocks[sector] = _laser_blocks(candidates, positions)
	var nearest: Array = _laser_block_nearest(team_blocks[sector], positions, pos, INF, -1)
	return int(nearest[1])

# With no hostile hull or pursuit, lasers fall back to the nearest hostile
# shipyard in the surrounding combat cells.
static func _fire_hull_at_structures(state: Dictionary, frame: COMBAT_FRAME, ship: Dictionary, pos: Vector2, team: int, cell: Vector2i, weapon_damage: float, cooldown: float) -> void:
	var nearest: float = LASER_RANGE * LASER_RANGE
	for candidate_id in _structure_neighborhood(state, frame, cell, team):
		var distance: float = pos.distance_squared_to(frame.positions[candidate_id])
		if distance < nearest:
			nearest = distance
			ship["yard_target"] = candidate_id
	var yard_id: int = int(ship["yard_target"])
	if yard_id < -1 and weapon_damage > 0.0 and cooldown <= EPS:
		_ship_hit(frame.damage, frame.killed_by, frame.health, yard_id, ship, weapon_damage, frame.hull_slots, frame.hull_health)
		ship["laser_cooldown"] = 1.0
		ship["yard_laser_until"] = float(state["elapsed"]) + 0.2

# A structure fallback must not scan every hostile hull again. Filter the
# same cached buckets once per team/cell, keeping their exact tie order.
static func _structure_neighborhood(state: Dictionary, frame: COMBAT_FRAME, cell: Vector2i, team: int) -> Array:
	if not _combat_window_may_have_hostile(state, frame, team, cell, 1):
		return []
	if not frame.structure_neighborhoods.has(team):
		frame.structure_neighborhoods[team] = {}
	var neighborhoods: Dictionary = frame.structure_neighborhoods[team]
	if neighborhoods.has(cell):
		return neighborhoods[cell]
	var ids: Array = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			for other in _hostile_bucket(state, frame.cells, frame.hostile_cache, cell + Vector2i(x, y), team, frame.team_by_id):
				var id: int = int(other["id"])
				if id >= 0 or team == 0 or int(frame.team_by_id[id]) == team:
					continue
				ids.append(id)
	neighborhoods[cell] = ids
	return ids

# Each matrix emitter has its own cooldown and fires from the station.
static func _fire_station_weapons(state: Dictionary, frame: COMBAT_FRAME, dt: float) -> void:
	var positions: Dictionary = frame.positions
	var team_by_id: Dictionary = frame.team_by_id
	var damage: Dictionary = frame.damage
	for index in range((state["planets"] as Array).size()):
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
			if _combat_window_may_have_hostile(state, frame, team, cell, missile_reach, true):
				for x in range(-missile_reach, missile_reach + 1):
					for y in range(-missile_reach, missile_reach + 1):
						for other in _hostile_bucket(state, frame.cells, frame.positive_hostile_cache, cell + Vector2i(x, y), team, team_by_id, true):
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
				_missile_splash(state, frame.cells, positions, team_by_id, team, missile_target, attacker, MISSILE_DAMAGE * STATION_MISSILE_COUNT, damage, frame.killed_by, frame.health, frame.hull_slots, frame.hull_health, frame.missile_splash_groups)
				missile_cd = MISSILE_COOLDOWN
				station["missile_origin"] = origin
				station["missile_endpoint"] = positions[missile_target]
				station["missile_until"] = float(state["elapsed"]) + 0.65
		station["missile_cooldown"] = missile_cd
		var target: int = -1
		var best: float = LASER_RANGE * LASER_RANGE
		if _combat_window_may_have_hostile(state, frame, team, cell, 1):
			for x in range(-1, 2):
				for y in range(-1, 2):
					for other in _hostile_bucket(state, frame.cells, frame.hostile_cache, cell + Vector2i(x, y), team, team_by_id):
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
static func _fire_planetary_defenses(state: Dictionary, graph: Dictionary, frame: COMBAT_FRAME, dt: float) -> void:
	var positions: Dictionary = frame.positions
	var team_by_id: Dictionary = frame.team_by_id
	var damage: Dictionary = frame.damage
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
		if _combat_window_may_have_hostile(state, frame, team, cell, reach):
			for x in range(-reach, reach + 1):
				for y in range(-reach, reach + 1):
					for other in _hostile_bucket(state, frame.cells, frame.hostile_cache, cell + Vector2i(x, y), team, team_by_id):
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

# Apply accumulated damage simultaneously: hulls, then shipyards, then stations.
static func _resolve_combat_damage(state: Dictionary, graph: Dictionary, frame: COMBAT_FRAME, ships: Array) -> void:
	var damage: Dictionary = frame.damage
	var killed_by: Dictionary = frame.killed_by
	for ship in ships:
		if bool(ship.get("cloak_equipped", false)) and float(state["elapsed"]) < float(ship.get("cloak_reveal_until", 0.0)):
			ship["cloaked"] = false
	for target in killed_by:
		var attacker: Dictionary = killed_by[target]
		attacker["kills"] = int(attacker.get("kills", 0)) + 1
	# Nothing was hit. Cloak cleanup above still runs at the original time;
	# no need to duplicate or scan the hull/structure damage lists.
	if damage.is_empty():
		return
	for ship in ships.duplicate():
		var id: int = int(ship["id"])
		if damage.has(id):
			_apply_reward_damage(ship, ship_max_hp(str(ship["kind"])), float(damage[id]), float(state["elapsed"]))
			if float(ship["hp"]) <= EPS:
				if killed_by.has(id) and SHIP_KINDS.has(ship["kind"]) and int(killed_by[id]["owner"]) > 0:
					var attacker: Dictionary = killed_by[id]
					var progress: Dictionary = objective_progress(state, int(attacker["owner"]))
					progress["enemy_ships_destroyed"] = int(progress.get("enemy_ships_destroyed", 0)) + 1
				_record_ship_destruction(state, graph, ship)
				_remove_indexed_hull(state, ship)
	_resolve_shipyard_damage(state, graph, frame.yard_targets, damage)
	for id in frame.station_targets:
		if not damage.has(id):
			continue
		var index: int = frame.station_targets[id]
		var station: Dictionary = state["planets"][index]["station"]
		_apply_reward_damage(station, station_max_hp(state["planets"][index]), float(damage[id]), float(state["elapsed"]))
		if float(station["hp"]) <= EPS:
			_destroy_station(state, graph, index)

# Remove in reverse slot order to preserve indices during compaction.
static func _resolve_shipyard_damage(state: Dictionary, graph: Dictionary, yard_targets: Dictionary, damage: Dictionary) -> void:
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
		var choice: Dictionary = {}
		if relation == DIPLO_WAR:
			choice = _ai_peace_choice(entry, player, other, rival, rival_power, proximity, own_power, enemy_burden, wars, fleet)
		elif relation == DIPLO_NEUTRAL:
			var third: Dictionary = _ai_third_party_pressure(state, estimates, rivals, player, other, own_power, rival_power)
			var incoming: bool = int(entry.get("alliance_offer", 0)) == other
			if allies < AI_DIPLOMACY_MAX_ALLIES and not bool(third["ally_conflict"]) and int(entry.get("alliance_offer", 0)) != player:
				var coalition_value: float = float(third["common_threat"]) / own_power
				# Accept useful cooperation even before a common enemy fires.
				if coalition_value > 0.65 or (incoming and wars > 0 and rival_power >= own_power * 0.65) or (incoming and proximity > 0.25 and rival_power >= own_power * 0.75):
					choice = {"action": "alliance", "score": 2.0 + minf(3.0, coalition_value) + (0.5 if incoming else 0.0)}
			# Require a real, reachable visible station and a substantial
			# offensive advantage; never declare due to ordinary movement.
			var expected_cost: float = rival_power + enemy_burden * 0.8 + float(third["intervention"])
			var advantage: float = fleet / maxf(1.0, expected_cost)
			if choice.is_empty() and now >= AI_DIPLOMACY_OPENING and wars < 2 and int(own["stations"]) > 0 and int(rival["stations"]) > 0 and proximity > 0.0 and fleet >= 6.0 and advantage > 1.35:
				choice = {"action": "declare_war", "score": minf(4.0, advantage) + proximity - 0.5 * wars}
		var action: String = str(choice.get("action", ""))
		var score: float = float(choice.get("score", 0.0))
		if not action.is_empty() and score > best_score:
			best_score = score
			best = {"action": action, "other": other}
	return best

static func _ai_peace_choice(entry: Dictionary, player: int, other: int, rival: Dictionary, rival_power: float, proximity: float, own_power: float, enemy_burden: float, wars: int, fleet: float) -> Dictionary:
	if int(entry.get("peace_offer", 0)) == player:
		return {}
	var other_fronts: float = maxf(0.0, enemy_burden - rival_power)
	# Opportunity cost: peace frees fleets for defense or a better war.
	var pressure: float = (rival_power + other_fronts * 0.8) / own_power
	var limited_gain: bool = int(rival["stations"]) == 0 or proximity < 0.2
	var incoming: bool = int(entry.get("peace_offer", 0)) == other
	if pressure > 1.2 or (wars > 1 and pressure > 0.85) or (limited_gain and (incoming or wars > 1 or fleet < 3.0)):
		return {"action": "peace", "score": 3.0 + minf(3.0, pressure) + (1.0 if incoming else 0.0)}
	return {}

static func _ai_third_party_pressure(state: Dictionary, estimates: Dictionary, rivals: Array, player: int, other: int, own_power: float, rival_power: float) -> Dictionary:
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
	return {"common_threat": common_threat, "intervention": intervention, "ally_conflict": ally_conflict}

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
	var here: int = int(ship["at"])
	var position: Vector2 = ship.get("position", points[here])
	var best: float = INF
	var target: int = -1
	for node in range(state["planets"].size()):
		if reserved.has(node) or colony_path(state, player, ship, node).is_empty():
			continue
		var richness: float = float(state["planets"][node]["abundance"].get("Metals", 0.0))
		var score: float = position.distance_to(points[node]) / (1.0 + minf(richness, 2.0) * 0.15) * (1.0 if has_planets(state["planets"][node]) else 1.6)
		if score < best:
			best = score
			target = node
	return target

static func _ai_turn(state: Dictionary, graph: Dictionary, player: int) -> void:
	var home: int = military_home(state, player)
	if home < 0:
		_ai_resettle(state, player)
		return
	var planets: Array = state["planets"]
	var census: Dictionary = _ai_census(state, player, home)
	var owned: Array[int] = census["owned"]
	var counts: Dictionary = census["counts"]
	var reserved: Dictionary = census["reserved"]
	for ship in census["idle_colonies"]:
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
		var goal: Array = _ai_station_goal(state, player, home, index, census, expansion)
		if not (goal[0] as String).is_empty():
			_ai_pursue_station_goal(state, player, index, goal[0], goal[1], counts)
	_ai_military_orders(state, graph, player, home, owned, census["fighters"])

## A surviving colony hull can establish a new home even after the empire
## loses its last owned system.
static func _ai_resettle(state: Dictionary, player: int) -> void:
	var reserved: Dictionary = {}
	for ship in state["ships"]:
		if int(ship["owner"]) == player and ship.get("kind", "") == "colony_ship" and (not (ship["route"] as Array).is_empty() or colony_morphing(ship)):
			reserved[int(ship["dest"])] = true
	for ship in state["ships"]:
		if int(ship["owner"]) != player or ship.get("kind", "") != "colony_ship" or not (ship["route"] as Array).is_empty() or colony_morphing(ship):
			continue
		var target: int = _ai_colony_target(state, player, ship, reserved)
		if target >= 0 and send_colony(state, player, int(ship["id"]), target, true):
			reserved[target] = true

## Counts owned and queued hulls, reserved colony targets and useful mining
## fields, and refreshes each owned station's trade thresholds.
static func _ai_census(state: Dictionary, player: int, home: int) -> Dictionary:
	var planets: Array = state["planets"]
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
		if kind in MILITARY_KINDS:
			fighters.append(ship)
		elif kind == "colony_ship":
			if (ship["route"] as Array).is_empty() and not colony_morphing(ship):
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
	return {"owned": owned, "counts": counts, "reserved": reserved, "fighters": fighters, "idle_colonies": idle_colonies, "useful_fields": useful_fields}

## Selects the station's next goal before checking funding, returning
## [action, target]. The AI saves for that goal rather than continually
## buying cheaper ships or secondary upgrades.
static func _ai_station_goal(state: Dictionary, player: int, home: int, index: int, census: Dictionary, expansion: bool) -> Array:
	var p: Dictionary = state["planets"][index]
	var owned: Array[int] = census["owned"]
	var counts: Dictionary = census["counts"]
	var useful_fields: int = census["useful_fields"]
	var level: int = production_level(p, "Metals") + int(p.get("buildings", {}).get("Metals", 0))
	var abundance: float = float(p["abundance"].get("Metals", 0.0))
	var action: String = ""
	var target: String = ""
	var has_yard: bool = operational_shipyards(p) > 0
	if abundance > 0.0 and level == 0:
		action = "economy"
		target = "Metals"
	elif (index == home or has_fitting_yard(p, "ship")) and owned.size() > 1 and counts["ship"] == 0:
		action = "ship"
	elif has_yard and owned.size() > 1 and counts["fighter"] < mini(12, owned.size() * 2):
		action = "fighter"
	elif index == home and expansion and counts["colony_ship"] == 0:
		if ship_origin_population_met(p, "colony_ship"):
			action = "colony_ship"
		elif population_capacity(p) < COLONY_MIN_ORIGIN_POPULATION:
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
	elif (index == home or has_fitting_yard(p, "ship")) and counts["ship"] < mini(12, owned.size() * 2) and owned.size() > 1:
		action = "ship"
	elif has_yard and expansion and counts["colony_ship"] < 3 and ship_origin_population_met(p, "colony_ship"):
		var local_probe: Dictionary = {"kind": "colony_ship", "owner": player, "at": index, "route": []}
		if _ai_colony_target(state, player, local_probe, census["reserved"]) >= 0:
			action = "colony_ship"
	if action.is_empty():
		return _ai_late_station_goal(p, home, index, census)
	return [action, target]

## Fallback goal once basic defense, expansion and logistics are covered.
static func _ai_late_station_goal(p: Dictionary, home: int, index: int, census: Dictionary) -> Array:
	var owned: Array[int] = census["owned"]
	var counts: Dictionary = census["counts"]
	var useful_fields: int = census["useful_fields"]
	var level: int = production_level(p, "Metals") + int(p.get("buildings", {}).get("Metals", 0))
	var abundance: float = float(p["abundance"].get("Metals", 0.0))
	var farm: int = production_level(p, "Organics") + int(p.get("buildings", {}).get("Organics", 0))
	var has_yard: bool = operational_shipyards(p) > 0
	var action: String = ""
	var target: String = ""
	# After basic defense, expansion and logistics, reserve a capital
	# budget at the home yard. Other stations keep producing escorts.
	var population: float = float(p["population"])
	if index == home and has_yard and counts["fighter"] >= AI_WAVE_MIN and counts["cruiser"] < maxi(1, mini(4, owned.size())) and population >= yard_staff_required(p, 1) + CREW_COSTS["cruiser"]:
		action = "cruiser"
	elif index == home and has_yard and counts["cruiser"] > 0 and counts["destroyer"] < maxi(1, mini(3, ceili(float(owned.size()) / 2.0))) and population >= yard_staff_required(p, 2) + CREW_COSTS["destroyer"]:
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
	return [action, target]

## Funds and enqueues the chosen goal, substituting a shipyard or warehouse
## prerequisite or a missing economy building when the goal is blocked.
static func _ai_pursue_station_goal(state: Dictionary, player: int, index: int, action: String, target: String, counts: Dictionary) -> void:
	var p: Dictionary = state["planets"][index]
	var abundance: float = float(p["abundance"].get("Metals", 0.0))
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
	var capacity_blocked: bool = false
	for resource in price:
		capacity_blocked = capacity_blocked or float(price[resource]) > storage_capacity(p, str(resource)) + EPS
	if capacity_blocked:
		if warehouse_available(p):
			enqueue(state, player, index, "economy", "warehouse")
		return
	if not affordable(p, price):
		# Saving for an unaffordable hull must not leave mature systems
		# waiting indefinitely for food or local extraction.
		for resource in price:
			if float(p["stock"][resource]) >= float(price[resource]) or not ECONOMY_BUILDINGS.has(resource):
				continue
			if resource == "Metals" and abundance <= EPS:
				continue
			var available_output: float = rate(p, resource)
			if resource == "Organics":
				available_output -= organics_demand(p)
			if available_output >= 0.5:
				continue
			if int(p.get("buildings", {}).get(resource, 0)) >= 3:
				continue
			if affordable(p, building_cost(p, resource)) and enqueue(state, player, index, "economy", resource):
				break
		return
	if not can_pay_credits(state, player, construction_credit_cost(price, action)):
		return
	if float(p["population"]) < float(CREW_COSTS.get(action, 0.0)) + 1.0:
		return
	if enqueue(state, player, index, action, target) and SHIP_KINDS.has(action):
		counts[action] += 1

# Choose strategic objectives on the AI clock, not every movement tick.
# Local hostile fighters determine defensive urgency; friendly systems and
# allied ships never count as invasion targets or threats.
static func _ai_military_orders(state: Dictionary, graph: Dictionary, player: int, home: int, owned: Array[int], fighters: Array) -> void:
	var pois: Array[int] = military_pois(state, player)
	# Repairing hulls cannot defend or form an attack cohort yet. Count
	# only combat-ready ships until they return to the normal order loop.
	var ready: Array = fighters.filter(func(craft: Dictionary) -> bool: return not bool(craft.get("retreating", false)))
	var reference: Dictionary = _ai_reference_hull(state, graph, home, ready)
	var threats: Dictionary = {}
	var opportunities: Dictionary = {}
	_ai_scan_hostiles(state, graph, player, owned, pois, threats, opportunities)
	var defense: int = home
	var danger: int = 0
	for node in owned:
		var pressure: int = int(threats.get(node, 0))
		if pressure > danger:
			defense = node
			danger = pressure
	var goal: int = _ai_attack_goal(state, graph, player, pois, opportunities, reference)
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
	_ai_assign_military(state, graph, player, ready, defense, goal, defenders)

# The combat-ready hull nearest the cohort centroid stands in for the whole group when ranking objectives.
static func _ai_reference_hull(state: Dictionary, graph: Dictionary, home: int, ready: Array) -> Dictionary:
	var points: Array = graph["points"]
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
	return reference

static func _ai_scan_hostiles(state: Dictionary, graph: Dictionary, player: int, owned: Array[int], pois: Array[int], threats: Dictionary, opportunities: Dictionary) -> void:
	var planets: Array = state["planets"]
	var points: Array = graph["points"]
	for ship in state["ships"]:
		if not empires_hostile(state, player, int(ship["owner"])):
			continue
		var position: Vector2 = combat_position(state, graph, ship)
		if ship.get("kind", "") in MILITARY_KINDS and not bool(ship.get("retreating", false)):
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

static func _ai_attack_goal(state: Dictionary, graph: Dictionary, player: int, pois: Array[int], opportunities: Dictionary, reference: Dictionary) -> int:
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
	return goal

static func _ai_assign_military(state: Dictionary, graph: Dictionary, player: int, ready: Array, defense: int, goal: int, defenders: int) -> void:
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
	var indexed: bool = is_same(state, _indexed_state)
	var by_id: Dictionary = _hulls_by_id if indexed else {}
	var current: Dictionary = _group_operations(state, by_id, indexed)
	var prior_by_id: Dictionary = {}
	var prior_members: Dictionary = {}
	for old_operation in previous.values():
		prior_by_id[int(old_operation["id"])] = old_operation
	var reused: Dictionary = _reserve_operation_ids(state, current, previous)
	for key in current:
		var operation: Dictionary = current[key]
		if int(operation["id"]) == 0:
			_match_operation_id(state, operation, current, previous, reused, prior_members)
		var old_slots: Dictionary = prior_by_id.get(int(operation["id"]), {}).get("slots", {})
		var last_slot: int = _assign_formation_slots(operation, old_slots)
		_classify_operation_members(operation, by_id)
		var slots: Dictionary = operation["slots"]
		for member in operation["members"]:
			var craft: Dictionary = by_id[member]
			craft["operation_id"] = int(operation["id"])
			craft["formation_slot"] = int(slots[member])
			craft["formation_size"] = (operation["members"] as Array).size()
			craft["formation_extent"] = last_slot
	state["operations"] = current

## Groups armed hulls by owner, role and objective. Fills by_id when the
## hull index is not active for this state.
static func _group_operations(state: Dictionary, by_id: Dictionary, indexed: bool) -> Dictionary:
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
	for ship in state["ships"]:
		if bool(ship.get("rogue", false)) or ship.get("kind", "") not in MILITARY_KINDS:
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
	return current

## Keeps persistent wave identities and same-key operation identities,
## returning the set of IDs already claimed.
static func _reserve_operation_ids(state: Dictionary, current: Dictionary, previous: Dictionary) -> Dictionary:
	var reused: Dictionary = {}
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
	return reused

## Inherits the unclaimed prior operation with the greatest member overlap,
## or allocates a new ID.
static func _match_operation_id(state: Dictionary, operation: Dictionary, current: Dictionary, previous: Dictionary, reused: Dictionary, prior_members: Dictionary) -> void:
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

## Retains surviving slot assignments; reinforcements fill vacant slots.
## Returns the highest assigned slot.
static func _assign_formation_slots(operation: Dictionary, old_slots: Dictionary) -> int:
	var slots: Dictionary = {}
	var claimed: Dictionary = {}
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
	return last_slot

static func _classify_operation_members(operation: Dictionary, by_id: Dictionary) -> void:
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
		if craft.get("kind", "") not in MILITARY_KINDS or craft.get("unit_order", {}).get("kind", "") in ["follow", "guard", "patrol"] or craft.has("launch_rally") or craft.has("local_move_target") or craft.has("attack_order") or craft.has("cargo_order") or _salvage_active(craft) or _engaged(craft) or bool(craft.get("retreating", false)) or bool(craft.get("holding", false)) or (craft["route"] as Array).is_empty():
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
		var aligned: bool = true
		var offsets: Array[Vector2] = []
		for craft in group:
			var offset: Vector2 = _formation_offset(craft, axis)
			offsets.append(offset)
			var corrected: Vector2 = craft["position"] - offset
			var along: float = (corrected - origin).dot(axis)
			if absf((corrected - origin).cross(axis)) > SHIP_SEPARATION_RADIUS * 2.0 or along < -SHIP_SEPARATION_RADIUS or along > length + SHIP_SEPARATION_RADIUS:
				aligned = false
				break
			progress = minf(progress, clampf(along, 0.0, length))
		if not aligned:
			continue
		var next_progress: float = minf(length, progress + ship_speed(str(first.get("kind", "ship"))) * FORMATION_TRAVEL_FRACTION * dt)
		var arrived: bool = true
		for i in range(group.size()):
			var craft: Dictionary = group[i]
			var offset: Vector2 = offsets[i]
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

# Build only when a hull needs withdrawal planning. The two preparation
# phases each own a fresh index; missing/invalid positions use the old scan.
static func _withdrawal_threat_cells(state: Dictionary) -> Variant:
	var cells: Dictionary = {}
	for other in state["ships"]:
		if other.get("kind", "") not in MILITARY_KINDS:
			continue
		var point: Vector2 = other.get("position", Vector2.INF)
		if not point.is_finite():
			return null
		_spatial_insert(cells, point, REPAIR_SAFE_RADIUS, other)
	return cells

static func _repair_site_safe(state: Dictionary, graph: Dictionary, owner: int, site: int, threat_cells: Variant = null) -> bool:
	if site < 0 or site >= (state["planets"] as Array).size():
		return false
	var planet: Dictionary = state["planets"][site]
	if not has_station(planet) or (not diplomacy_allows(state, owner, int(planet["owner"]), "repair") if state.has("diplomacy") else int(planet["owner"]) != owner):
		return false
	var center: Vector2 = station_position(state, site, float(state["elapsed"]))
	if threat_cells != null and center.is_finite():
		var cell := Vector2i(floori(center.x / REPAIR_SAFE_RADIUS), floori(center.y / REPAIR_SAFE_RADIUS))
		# Conservative extra cell for floating-point boundary rounding.
		# The original inclusive distance and hostility tests remain exact.
		for x in range(-2, 3):
			for y in range(-2, 3):
				for other in threat_cells.get(cell + Vector2i(x, y), []):
					if empires_hostile(state, owner, int(other["owner"])) and combat_position(state, graph, other).distance_to(center) <= REPAIR_SAFE_RADIUS:
						return false
		return true
	for other in state["ships"]:
		if other.get("kind", "") in MILITARY_KINDS and empires_hostile(state, owner, int(other["owner"])) and combat_position(state, graph, other).distance_to(center) <= REPAIR_SAFE_RADIUS:
			return false
	return true

static func _cached_repair_site_safe(state: Dictionary, graph: Dictionary, owner: int, site: int, safety: Dictionary, threat_cells: Variant = null) -> bool:
	var key := Vector2i(owner, site)
	if not safety.has(key):
		safety[key] = _repair_site_safe(state, graph, owner, site, threat_cells)
	return bool(safety[key])

static func _nearest_repair_site(state: Dictionary, graph: Dictionary, ship: Dictionary, paths: Dictionary, safety: Dictionary = {}, threat_cells: Variant = null) -> int:
	var best: int = -1
	var distance: float = INF
	for site in range((state["planets"] as Array).size()):
		if not _cached_repair_site_safe(state, graph, int(ship["owner"]), site, safety, threat_cells):
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
	var threat_cells: Variant = null
	var threat_index_ready: bool = false
	for ship in state["ships"]:
		if not armed(ship):
			continue
		var withdrawing: bool = bool(ship.get("retreating", false))
		if not withdrawing and (not autocast_enabled(ship, "retreat") or float(ship.get("hp", ship_max_hp(str(ship["kind"])))) > ship_max_hp(str(ship["kind"])) * WITHDRAW_HP / SHIP_HP):
			continue
		if not threat_index_ready:
			threat_cells = _withdrawal_threat_cells(state)
			threat_index_ready = true
		var site: int = int(ship.get("repair_site", -1))
		if not withdrawing or not _cached_repair_site_safe(state, graph, int(ship["owner"]), site, safety, threat_cells):
			var replacement: int = _nearest_repair_site(state, graph, ship, paths, safety, threat_cells)
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
		# Direct orders can leave dest at the site with no route; withdrawal needs one.
		if int(ship.get("dest", -1)) != site or ((ship["route"] as Array).is_empty() and int(ship["at"]) != site):
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
	ship["hp"] = minf(maximum, float(ship.get("hp", maximum)) + REPAIR_PER_YEAR * repair_time * _player_factor(state, int(ship["owner"]), "rank_repair", 0.15))
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
			if ship.get("kind", "") in MILITARY_KINDS:
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
		if craft.get("kind", "") == "scout" and _is_idle_ship(craft) and craft.get("order_queue", []).is_empty() and not _unit_order_running(craft) and autocast_ready(state, craft, "explore"):
			scouts.append(craft)
	if scouts.is_empty():
		return
	for craft in state["ships"]:
		var team: int = _combat_group(state, int(craft["owner"]))
		var node: int = int(craft.get("at", -1))
		var key := Vector2i(team, node)
		occupancy[key] = int(occupancy.get(key, 0)) + 1
		if bool(craft.get("unit_order", {}).get("exploration", false)) and not craft.get("route", []).is_empty():
			var destination := Vector2i(team, int(craft.get("dest", node)))
			occupancy[destination] = int(occupancy.get(destination, 0)) + 1
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
		for candidate in range(state["planets"].size()):
			if candidate == node:
				continue
			var age: float = minf(600.0, float(state["elapsed"]) - float(visits.get(candidate, -600.0)))
			var friendly_occupancy: int = int(occupancy.get(Vector2i(team, candidate), 0))
			if state.has("diplomacy"):
				for ally in state["teams"]:
					if int(ally) != team and empires_allied(state, team, int(ally)):
						friendly_occupancy += int(occupancy.get(Vector2i(int(ally), candidate), 0))
			var value: float = age - float(friendly_occupancy) * 80.0 - (craft["position"] as Vector2).distance_to(graph["points"][candidate]) / maxf(1.0, ship_speed("scout"))
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

static func _idle_formation_targets(state: Dictionary, _graph: Dictionary) -> Dictionary:
	# Idle formations orbit their actual last idle position. Group nearby
	# anchors only; distant ships sharing a legacy star index never converge.
	var groups: Dictionary = {}
	for ship in state["ships"]:
		if not _is_idle_ship(ship):
			ship.erase("wander_anchor")
			continue
		if not ship.has("wander_anchor"):
			ship["wander_anchor"] = ship["position"]
		if not autocast_ready(state, ship, "wander"):
			continue
		var anchor: Vector2 = ship["wander_anchor"]
		var cell := Vector2i(floori(anchor.x / 120.0), floori(anchor.y / 120.0))
		var key: Array = [int(ship["owner"]), str(ship["kind"]), cell]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(ship)
	var targets: Dictionary = {}
	for group in groups.values():
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["id"]) < int(b["id"]))
		for first in range(0, group.size(), 3):
			var leader: Dictionary = group[first]
			var center: Vector2 = leader["wander_anchor"]
			var seed: int = int(leader["id"]) % 97
			var compact: bool = bool(leader.get("rally_pending", false))
			var radius: float = minf(WANDER_RADIUS, AI_RALLY_RADIUS - 10.0) if compact else WANDER_RADIUS
			var phase: float = float(state["elapsed"]) * ship_speed(str(leader["kind"])) / radius
			var angle: float = float(seed) * 2.399963 + phase * 0.55
			var radial: Vector2 = Vector2.from_angle(angle)
			var direction: Vector2 = radial.orthogonal()
			var distance: float = radius * (0.52 + 0.43 * sin(phase * 0.41 + float(seed) * 1.713))
			for i in range(first, mini(first + 3, group.size())):
				var offset: int = i - first
				var formation: Vector2 = Vector2.ZERO
				if offset > 0:
					formation = -direction * 22.0 + radial * (16.0 if offset == 1 else -16.0)
				var target: Vector2 = center + (radial * distance + formation).limit_length(radius)
				if state["map"].has("size"):
					target = target.clamp(Vector2.ZERO, state["map"]["size"])
				targets[int(group[i]["id"])] = target
	return targets

# Directly ordered fighters occupying a hostile system can transfer it.
# Surviving shipyards and nearby hostile fighters prevent occupation.
# Find a safe escape route after a civilian's planned route becomes
# hostile. Consider both ends of its existing leg without moving the hull.
# Only the initial hostile waypoint may be used to leave hostile territory.

static func _evacuate_civilian(state: Dictionary, ship: Dictionary, teams: Array[int]) -> bool:
	var team: int = _combat_group(state, int(ship["owner"]))
	var miner: bool = ship.get("kind", "") == "miner"
	_ensure_position(state["map"]["points"], ship)
	var best: float = INF
	var destination: int = -1
	for node in range(teams.size()):
		var system: Dictionary = state["planets"][node]
		if teams[node] != team or not has_station(system) or (miner and int(system["owner"]) != int(ship["owner"])):
			continue
		var distance: float = (ship["position"] as Vector2).distance_to(station_position(state, node, float(state["elapsed"])))
		if distance < best:
			best = distance
			destination = node
	ship["route"] = [destination] if destination >= 0 else []
	ship["leg"] = 0.0
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
# Authority-only substep; publication, RPCs and clock remain in GameSession.
# A future worker must exclusively own state and all static rule caches.
# Server peer membership is checked in GameSession before dispatch.
# Recheck gameplay eligibility against the current authoritative state.
static func _authority_active_player(state: Dictionary, id: int) -> bool:
	return state.get("teams", {}).has(id) and state.get("match_result", {}).is_empty() and not state.get("eliminated", []).has(id)

# The same command implementations serve synchronous and worker modes.
static func authority_colonize_for(state: Dictionary, id: int, ship_id: int, target: int) -> bool:
	if not _authority_active_player(state, id):
		return false
	if ship_id == -1:
		ship_id = nearest_idle_colony(state, id, target)
	if ship_id >= 0 and send_colony(state, id, ship_id, target):
		return true
	return false

static func authority_fighter_move_for(state: Dictionary, id: int, ids: Array, target: int, move_only: bool = false) -> bool:
	if _authority_active_player(state, id) and command_fighters(state, id, ids, target, move_only):
		return true
	return false

static func authority_tactical_order_for(state: Dictionary, id: int, ids: Array, kind: String, target: int) -> bool:
	if not _authority_active_player(state, id):
		return false
	var accepted: bool = false
	match kind:
		"attack":
			accepted = command_attack(state, id, ids, target)
		"patrol":
			accepted = command_patrol(state, id, ids, target)
	if accepted:
		return true
	return false

static func authority_miner_assignment_for(state: Dictionary, id: int, ids: Array, field: int, chunk: int) -> bool:
	if _authority_active_player(state, id) and command_miners(state, id, ids, field, chunk):
		return true
	return false

static func authority_fighter_hold_for(state: Dictionary, id: int, ids: Array) -> bool:
	if _authority_active_player(state, id) and hold_fighters(state, id, ids):
		return true
	return false

static func authority_local_position_for(state: Dictionary, id: int, ids: Array, node: int, point: Vector2, move_only: bool = false) -> bool:
	if _authority_active_player(state, id) and command_local_position(state, id, ids, node, point, move_only):
		return true
	return false

static func authority_salvage_for(state: Dictionary, id: int, ids: Array, target: int) -> bool:
	if _authority_active_player(state, id) and command_salvage(state, id, ids, target):
		return true
	return false

static func authority_unload_cargo_for(state: Dictionary, id: int, ids: Array) -> bool:
	if _authority_active_player(state, id) and command_unload_cargo(state, id, ids):
		return true
	return false

static func authority_unit_hold_for(state: Dictionary, id: int, ids: Array, release: bool) -> bool:
	if _authority_active_player(state, id) and command_hold_units(state, id, ids, release):
		return true
	return false

static func authority_unit_orders_for(state: Dictionary, id: int, orders: Array, append: bool) -> bool:
	if not _authority_active_player(state, id) or orders.size() > state["ships"].size():
		return false
	var changed: bool = false
	for entry in orders:
		if entry is Dictionary and entry.get("ids") is Array and entry.get("order") is Dictionary:
			changed = issue_unit_order(state, id, entry["ids"], entry["order"], append) or changed
	if changed:
		return true
	return false

static func authority_diplomacy_for(state: Dictionary, id: int, action: String, other: int, enabled: bool) -> bool:
	if not _authority_active_player(state, id):
		return false
	var changed: bool = false
	match action:
		"declare_war": changed = diplomacy_declare_war(state, id, other)
		"peace": changed = diplomacy_offer_peace(state, id, other)
		"alliance": changed = diplomacy_offer_alliance(state, id, other)
		"break_alliance": changed = diplomacy_break_alliance(state, id, other)
		"vision", "trade": changed = diplomacy_set_permission(state, id, other, action, enabled)
	if changed:
		return true
	return false

static func authority_confirmed_attack_for(state: Dictionary, id: int, other: int, ids: Array, target: int) -> bool:
	if _authority_active_player(state, id) and ids.size() <= state["ships"].size() and diplomacy_confirm_attack(state, id, other, ids, target):
		return true
	return false

static func authority_autocast_for(state: Dictionary, id: int, ids: Array, mode: String, enabled: bool) -> bool:
	if _authority_active_player(state, id) and set_autocast(state, id, ids, mode, enabled):
		return true
	return false

static func authority_repair_auto_for(state: Dictionary, id: int, ids: Array, enabled: bool) -> bool:
	if _authority_active_player(state, id) and set_repair_auto(state, id, ids, enabled):
		return true
	return false

static func authority_operation_for(state: Dictionary, id: int, index: int, kind: String, target: String) -> bool:
	if not _authority_active_player(state, id) or kind == "production":
		return false
	if kind == "shipyard_build":
		var parts: PackedStringArray = target.split(":")
		if parts.size() == 2 and parts[0].is_valid_int() and int(parts[0]) >= 0 and SHIP_KINDS.has(parts[1]) and enqueue(state, id, index, parts[1], "", int(parts[0])):
			return true
		return false
	if kind == "shipyard_autobuild":
		var parts: PackedStringArray = target.split(":")
		if parts.size() == 3 and parts[0].is_valid_int() and parts[2] in ["0", "1"] and set_yard_autobuild(state, id, index, int(parts[0]), parts[1], parts[2] == "1"):
			return true
		return false
	if enqueue(state, id, index, kind, target):
		return true
	return false

static func authority_shipyard_rally_for(state: Dictionary, id: int, index: int, slot: int, target: int, point: Vector2) -> bool:
	if _authority_active_player(state, id) and set_shipyard_rally(state, id, index, slot, target, point):
		return true
	return false

static func authority_maintain_for(state: Dictionary, id: int, index: int, kind: String, amount: int) -> bool:
	if _authority_active_player(state, id) and set_maintain(state, id, index, kind, amount):
		return true
	return false

static func authority_continuous_for(state: Dictionary, id: int, index: int, kind: String, enabled: bool) -> bool:
	if not kind.begins_with("production:") and _authority_active_player(state, id) and set_continuous(state, id, index, kind, enabled):
		return true
	return false

static func authority_cancel_for(state: Dictionary, id: int, index: int, job_id: int) -> bool:
	if _authority_active_player(state, id) and cancel(state, id, index, job_id):
		return true
	return false

static func authority_thresholds_for(state: Dictionary, id: int, index: int, resource: String, minimum: float, maximum: float, importing: bool = true, exporting: bool = true) -> bool:
	if _authority_active_player(state, id) and set_thresholds(state, id, index, resource, minimum, maximum, importing, exporting):
		return true
	return false

static func authority_mining_policy_for(state: Dictionary, id: int, index: int, enabled: bool, metals: bool, crystals: bool) -> bool:
	if _authority_active_player(state, id) and set_mining_policy(state, id, index, enabled, metals, crystals):
		return true
	return false

static func authority_time_speed_for(state: Dictionary, id: int, speed: int) -> bool:
	if id != 1 or not OS.is_debug_build() or not state.get("teams", {}).has(id):
		return false
	if not state.get("match_result", {}).is_empty() or not AUTHORITY_MATCH_SPEEDS.has(speed) or int(state.get("time_speed", 1)) == speed:
		return false
	state["time_speed"] = speed
	return true

static func authority_conquest_reward_for(state: Dictionary, id: int, key: String, generation: int, category: String) -> bool:
	if _authority_active_player(state, id) and acquire_reward(state, id, key, generation, category):
		return true
	return false

static func authority_objective_refresh_for(state: Dictionary, id: int, category: String, expected: String) -> bool:
	if _authority_active_player(state, id) and refresh_objective(state, id, category, expected):
		return true
	return false

static func authority_empire_target_for(state: Dictionary, id: int, kind: String, amount: int) -> bool:
	if _authority_active_player(state, id) and set_empire_target(state, id, kind, amount):
		return true
	return false

# Verify independent static storage before enabling a worker.
static var _authority_cache_probe: int = 0

static func swap_authority_cache_probe(value: int) -> int:
	var prior: int = _authority_cache_probe
	_authority_cache_probe = value
	return prior

static func advance_authority_substep(state: Dictionary, dt: float, profile: Dictionary = {}) -> bool:
	var diplomatic_revision: int = int(state.get("diplomacy_revision", 0))
	step(state, dt, profile)
	var treaty_changed: bool = diplomatic_revision != int(state.get("diplomacy_revision", 0))
	var outcome_started: int = Time.get_ticks_usec() if not profile.is_empty() else 0
	var changed: bool = update_match_outcome(state)
	if not profile.is_empty():
		profile["Match outcome"] = int(profile.get("Match outcome", 0)) + Time.get_ticks_usec() - outcome_started
	return changed or treaty_changed

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
static func _separate_ships(state: Dictionary, graph: Dictionary, previous: Dictionary, dt: float, repair_parked: Dictionary = {}, persistent: bool = false, prepared_cells: Variant = null, contact_snapshot: Variant = null, prepared_batch: Variant = null) -> void:
	if dt <= 0.0:
		return
	var reach: float = SHIP_SEPARATION_RADIUS
	var ships: Array = state["ships"]
	var batch: STEP_FRAME.SeparationBatch = null
	var cells: Dictionary = {}
	if persistent:
		batch = prepared_batch
		if batch == null:
			batch = _separation_batch
			batch.begin(ships.size(), reach)
			for slot in range(ships.size()):
				var id: int = int(ships[slot]["id"])
				if previous.has(id):
					batch.append(slot, id, previous[id])
			batch.finish()
	else:
		cells = _separation_cells(state, previous, reach) if prepared_cells == null else prepared_cells
	var collect_contacts: bool = persistent and contact_snapshot != null and ships.size() >= 2
	var bounds: Dictionary = {}
	if collect_contacts:
		_contact_index.begin()
		_contact_batch.begin(ships.size())
	for i in range(ships.size()):
		var ship: Dictionary = ships[i]
		_separate_hull(state, graph, ship, previous, dt, repair_parked, cells, reach, batch, i)
		# Separation changes only this hull. Its final position can be
		# collected now, in the same order as the former contact build.
		if collect_contacts:
			var point: Vector2 = ship["position"]
			var id: int = int(ship["id"])
			_append_persistent_contact(i, point, SHIP_CLEARANCE, bounds)
			_contact_batch.set_pose(i, id, point, previous.get(id, point))
	if collect_contacts:
		contact_snapshot["cells"] = _contact_index.finish()
		contact_snapshot["bounds"] = bounds
		contact_snapshot["batch"] = _contact_batch

static func _separate_hull(state: Dictionary, graph: Dictionary, ship: Dictionary, previous: Dictionary, dt: float, repair_parked: Dictionary, cells: Dictionary, reach: float, batch: STEP_FRAME.SeparationBatch, slot: int) -> void:
	var id: int = int(ship["id"])
	if batch != null:
		if batch.present[slot] == 0 or batch.neighbors(slot).size() <= 1:
			return
	elif not previous.has(id):
		return
	if repair_parked.has(id) or _stop_waiting(state, ship) or bool(ship.get("retreating", false)) or _salvage_active(ship):
		return
	var budget: float = ship_speed(str(ship.get("kind", "ship"))) * dt
	if _separation_exempt(state, graph, ship, budget, reach):
		return
	var before: Vector2 = previous[id]
	var planned: Vector2 = ship["position"]
	var held: bool = bool(ship.get("holding", false))
	var local_moving: bool = ship.has("local_move_target")
	var force: Vector2 = batch.force(slot, EPS) if batch != null else _separation_force(id, before, cells, previous, reach)
	if force.is_zero_approx():
		return
	var movement: Vector2 = planned - before
	if movement.length() > budget + EPS:
		return
	# A shared hold point is a group anchor. Ease attraction near it
	# so repulsion does not fight a full-speed return to the same pixel.
	if held and ship.has("hold_position") and before.distance_to(ship["hold_position"]) < reach * 2.0:
		movement *= 0.25
	var push: Vector2 = force.limit_length(1.0) * budget * SHIP_SEPARATION_STRENGTH
	var candidate: Vector2 = before + (movement + push).limit_length(budget)
	var sector: int = int(ship.get("local_move_sector", -1)) if local_moving else (int(ship.get("hold_sector", -1)) if held else local_sector(graph, ship))
	if sector >= 0 and sector < graph["points"].size() and sector_contains(graph, sector, planned) and not sector_contains(graph, sector, candidate):
		# Keep local orders and stationary ships inside their legal sector.
		candidate = _clip_to_sector(graph, sector, planned, candidate)
	var displacement: Vector2 = candidate - before
	ship["position"] = candidate
	if not displacement.is_zero_approx():
		ship["heading"] = displacement.normalized()
	if not (ship["route"] as Array).is_empty():
		ship["leg"] = _lane_progress(graph["points"], ship)

# An occupied singleton cell with no occupied adjacent cell cannot have
# any interaction at this cell width. Cache only within the frozen pass.
static func _isolated_spatial_cell(point: Vector2, reach: float, cells: Dictionary, cache: Dictionary) -> bool:
	var cell := Vector2i(floori(point.x / reach), floori(point.y / reach))
	if cache.has(cell):
		return bool(cache[cell])
	var alone: bool = cells.get(cell, []).size() == 1
	if alone:
		for x in range(-1, 2):
			for y in range(-1, 2):
				if (x != 0 or y != 0) and cells.has(cell + Vector2i(x, y)):
					alone = false
					break
			if not alone:
				break
	cache[cell] = alone
	return alone

static func _begin_contact_indexes(state: Dictionary) -> void:
	if not is_same(state, _contact_index_state) or not is_same(state["ships"], _contact_index_roster):
		_contact_index_state = state
		_contact_index_roster = state["ships"]
		_separation_index.clear()
		_contact_index.clear()

static func _separation_cells(state: Dictionary, previous: Dictionary, reach: float, persistent: bool = false) -> Dictionary:
	var cells: Dictionary = {}
	if persistent:
		_begin_contact_indexes(state)
		_separation_index.begin()
	for ship in state["ships"]:
		var id: int = int(ship["id"])
		if not previous.has(id):
			continue
		var pos: Vector2 = previous[id]
		var cell := Vector2i(floori(pos.x / reach), floori(pos.y / reach))
		if persistent:
			_separation_index.append(cell, id)
		else:
			if not cells.has(cell):
				cells[cell] = []
			cells[cell].append(id)
	return _separation_index.finish() if persistent else cells

## Hulls whose position this tick must stay exact: anchored holds, follow,
## waiting or idle-without-wander hulls, arrival ticks, service waypoints
## and working Harvesters.
static func _separation_exempt(state: Dictionary, graph: Dictionary, ship: Dictionary, budget: float, reach: float) -> bool:
	var planned: Vector2 = ship["position"]
	var held: bool = bool(ship.get("holding", false))
	if held and ship.has("hold_heading"):
		return true
	var local_moving: bool = ship.has("local_move_target")
	# Follow owns its movement budget, including close-range backing off.
	if ship.get("unit_order", {}).get("kind", "") == "follow":
		return true
	# Waiting hulls remain precise obstacles, but combat/withdrawal can move.
	var engaged: bool = _engaged(ship)
	var idle: bool = false
	if not engaged:
		idle = _is_idle_ship(ship)
		var can_wander: bool = idle and autocast_ready(state, ship, "wander")
		if (arrival_wait_remaining(state, ship) > EPS and not can_wander) or (idle and not can_wander):
			return true
	# Preserve the exact endpoint and facing on the arrival tick only.
	# The completed order is retired before next tick's ordinary wandering.
	var order: Dictionary = ship.get("unit_order", {})
	if not local_moving and order.get("kind", "") == "position" and planned == order.get("point", Vector2.INF):
		return true
	# Do not let repulsion prevent completion of a shared point order.
	# The newly idle ships spread naturally after arrival.
	if local_moving and planned.distance_to(ship["local_move_target"]) < reach * 2.0:
		return true
	var route: Array = ship["route"]
	# Exact arrival at a waypoint is required by service and lane logic.
	# Do not push docking or extracting civilian ships off their targets.
	if not held:
		if route.is_empty():
			if not local_moving and not idle and not engaged:
				return true
			var at: int = int(ship["at"])
			if at >= 0 and at < graph["points"].size() and planned.distance_to(graph["points"][at]) <= EPS:
				return true
		else:
			var waypoint: Vector2 = graph["points"][int(route[0])]
			if planned.distance_to(waypoint) < reach * 2.0 + budget:
				return true
	if not held and ship.get("kind", "") == "miner" and ship.get("mining_mode", "") in ["outbound", "mining", "return"]:
		return true
	return false

## Summed linear falloff repulsion from neighbours' previous positions.
static func _separation_force(id: int, before: Vector2, cells: Dictionary, previous: Dictionary, reach: float) -> Vector2:
	var reach_squared: float = reach * reach
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
	return force

## Bisects the farthest point along planned -> candidate that stays inside
## the sector, assuming planned is inside.
static func _clip_to_sector(graph: Dictionary, sector: int, planned: Vector2, candidate: Vector2, iterations: int = 12) -> Vector2:
	var lower: float = 0.0
	var upper: float = 1.0
	for iteration in range(iterations):
		var fraction: float = (lower + upper) * 0.5
		if sector_contains(graph, sector, planned.lerp(candidate, fraction)):
			lower = fraction
		else:
			upper = fraction
	return planned.lerp(candidate, lower)

# Apply a gentle push on the actual post-movement coordinates, including ships
# exempt from soft steering. This is contact correction, not a new order;
# service actions and arrival checks have already executed for this tick.
# A sparse grid and bounded iterations avoid an all-fleet pair scan.
static func _contact_bucket_near(point: Vector2, bounds: Rect2, cutoff_squared: float) -> bool:
	var nearest: Vector2 = point.clamp(bounds.position, bounds.end)
	# Conservative margin avoids rejecting boundary pairs due to rounding.
	return point.distance_squared_to(nearest) <= cutoff_squared + maxf(0.001, cutoff_squared * 0.0001)

static func _resolve_ship_contacts(state: Dictionary, graph: Dictionary, previous: Dictionary, dt: float = 0.1, repair_parked: Dictionary = {}, persistent: bool = false, prepared_snapshot: Dictionary = {}) -> void:
	var ships: Array = state["ships"]
	if ships.size() < 2:
		return
	if persistent:
		_begin_contact_indexes(state)
	var reach: float = SHIP_CLEARANCE
	var cutoff_squared: float = (reach - EPS) * (reach - EPS)
	# Reuse dense indexed scratch arrays across contact passes.
	var corrections := PackedVector2Array()
	var touched := PackedByteArray()
	if not persistent:
		corrections.resize(ships.size())
		touched.resize(ships.size())
	for iteration in range(SHIP_CLEARANCE_PASSES):
		var cells: Dictionary = {}
		var bounds: Dictionary = {}
		if persistent and iteration == 0 and prepared_snapshot.has("cells"):
			cells = prepared_snapshot["cells"]
			bounds = prepared_snapshot["bounds"]
		elif persistent:
			cells = _refresh_persistent_contact_cells(ships, reach, bounds)
		else:
			_index_contact_cells(ships, reach, cells, bounds)
		if persistent:
			# The fused separation pass already staged the exact same pose/ID
			# snapshot. Other callers and future iterations refresh it here.
			if iteration != 0 or not is_same(prepared_snapshot.get("batch"), _contact_batch):
				_contact_batch.begin(ships.size())
				for slot in range(ships.size()):
					var craft: Dictionary = ships[slot]
					var point: Vector2 = craft["position"]
					var id: int = int(craft["id"])
					_contact_batch.set_pose(slot, id, point, previous.get(id, point))
			_contact_batch.accumulate(cells, bounds, reach, EPS)
			if _contact_batch.correction_order.is_empty():
				break
			_apply_contact_corrections(state, graph, previous, dt, repair_parked, _contact_batch.corrections, _contact_batch.correction_order)
			continue
		# Independent dictionary-based reference for semantic parity tests.
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
						var pb: Vector2 = ships[j]["position"]
						var offset: Vector2 = pa - pb
						if offset.length_squared() >= cutoff_squared:
							continue
						var distance: float = offset.length()
						var direction: Vector2
						if distance <= EPS:
							# Side-step a head-on approach; stable IDs break exact ties.
							var b: Dictionary = ships[j]
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
		_apply_contact_corrections(state, graph, previous, dt, repair_parked, corrections, correction_order)

# Contact slots refer to this pass's roster order, never stable IDs.
# Reconcile after separation (and every contact iteration); bounds must
# always be calculated from current positions, even inside the same cell.
static func _refresh_persistent_contact_cells(ships: Array, reach: float, bounds: Dictionary) -> Dictionary:
	_contact_index.begin()
	for i in range(ships.size()):
		_append_persistent_contact(i, ships[i]["position"], reach, bounds)
	return _contact_index.finish()

static func _append_persistent_contact(slot: int, point: Vector2, reach: float, bounds: Dictionary) -> void:
	var cell := Vector2i(floori(point.x / reach), floori(point.y / reach))
	_contact_index.append(cell, slot)
	var box: Rect2 = bounds.get(cell, Rect2(point, Vector2.ZERO))
	bounds[cell] = box.expand(point)

static func _index_contact_cells(ships: Array, reach: float, cells: Dictionary, bounds: Dictionary) -> void:
	for i in range(ships.size()):
		var point: Vector2 = ships[i]["position"]
		var cell := Vector2i(floori(point.x / reach), floori(point.y / reach))
		if not cells.has(cell):
			cells[cell] = []
		cells[cell].append(i)
		var box: Rect2 = bounds.get(cell, Rect2(point, Vector2.ZERO))
		bounds[cell] = box.expand(point)

# Move each touched hull by its bounded share of the accumulated push.
static func _apply_contact_corrections(state: Dictionary, graph: Dictionary, previous: Dictionary, dt: float, repair_parked: Dictionary, corrections: PackedVector2Array, correction_order: Array[int]) -> void:
	var ships: Array = state["ships"]
	for i in correction_order:
		var craft: Dictionary = ships[i]
		if repair_parked.has(int(craft["id"])) or _stop_waiting(state, craft) or (bool(craft.get("holding", false)) and craft.has("hold_heading") and not bool(craft.get("retreating", false))):
			continue
		var point: Vector2 = craft["position"]
		var budget: float = ship_speed(str(craft.get("kind", "ship"))) * dt
		var before: Vector2 = previous.get(int(craft["id"]), point)
		var candidate: Vector2 = point + (corrections[i] as Vector2).limit_length(budget * 0.15)
		if before.distance_to(point) <= budget + EPS:
			candidate = before + (candidate - before).limit_length(budget)
		var sector: int = local_sector(graph, craft)
		if sector >= 0 and sector_contains(graph, sector, point) and not sector_contains(graph, sector, candidate):
			candidate = _clip_to_sector(graph, sector, point, candidate, 10)
		if craft.get("kind", "") != "miner" and not _rock_cells.is_empty():
			candidate = _clip_rock_step(point, candidate)
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

static func step(state: Dictionary, dt: float, profile: Dictionary = {}, motion_sleep_enabled: bool = true, deadline_schedule_enabled: bool = true, persistent_avoidance_enabled: bool = true, persistent_combat_enabled: bool = true, persistent_logistics_enabled: bool = true, economy_rates_enabled: bool = true) -> void:
	_begin_deadline_schedule(state, deadline_schedule_enabled)
	# Before economy work, repair any unexpected private roster replacement.
	if is_same(state, _retained_hull_state) and (not is_same(state["ships"], _indexed_hull_roster) or _hulls_by_id.size() != state["ships"].size()):
		_begin_hull_index(state)
	_rock_plan_tick += 1
	if not is_same(state, _trajectory_state) or not is_same(state["ships"], _trajectory_roster):
		_direct_trajectories.clear()
		_trajectory_state = state
		_trajectory_roster = state["ships"]
	_trajectory_tick = _rock_plan_tick
	_rock_plan_budget = ROCK_PLAN_LIMIT
	_rock_route_queries.clear()
	_refresh_movement_fields(state["map"].get("fields", []))
	var started: int = Time.get_ticks_usec() if not profile.is_empty() else 0
	var frame: STEP_FRAME = STEP_FRAME.new()
	frame.profile = profile
	frame.motion_sleep_enabled = motion_sleep_enabled
	frame.deadline_schedule_enabled = deadline_schedule_enabled
	frame.persistent_avoidance_enabled = persistent_avoidance_enabled
	frame.persistent_combat_enabled = persistent_combat_enabled
	frame.persistent_logistics_enabled = persistent_logistics_enabled
	_step_economy(state, frame, dt, economy_rates_enabled)
	started = _profile_stage(profile, "Economy", started)
	_step_ai(state, frame, dt)
	started = _profile_stage(profile, "AI / routing setup", started)
	_step_combat(state, frame, dt)
	started = _profile_stage(profile, "Combat / repair", started)
	_step_formations(state, frame, dt)
	started = _profile_stage(profile, "Formations / orders", started)
	if motion_sleep_enabled:
		_begin_motion_sleep(state)
	for ship in (state["ships"] as Array).duplicate():
		_step_hull(state, frame, ship, dt)
	_step_settle_movement(state, frame, dt)
	if not profile.is_empty():
		var now: int = Time.get_ticks_usec()
		profile["Civilian logistics"] = int(profile.get("Civilian logistics", 0)) + frame.civilian_usec
		profile["Other movement"] = int(profile.get("Other movement", 0)) + maxi(0, now - started - frame.civilian_usec)
		started = now
	_sync_operations(state)
	update_exploration(state)
	_update_objectives(state)
	_profile_stage(profile, "Conquest / exploration", started)
	if not is_same(state, _retained_hull_state):
		_end_hull_index()
	frame.graph.erase("travel_influence")
	frame.graph.erase("travel_permissions")
	_sector_query_graph = {}
	_sector_query_cache.clear()
	_trajectory_tick = -1

# Calendars store only keys and timestamps. The canonical dictionaries
# remain authoritative and are rebuilt on state/roster replacement.
static func _begin_deadline_schedule(state: Dictionary, enabled: bool) -> void:
	if not enabled:
		_hull_deadlines_need_sync = true
		_deadline_state = {}
		_deadline_roster = []
		_deadline_events = {}
		_cooldown_deadlines.clear()
		_transfer_deadlines.clear()
		return
	if not is_same(state, _deadline_state):
		_hull_deadlines_need_sync = true
		_deadline_state = state
		_deadline_roster = []
		_deadline_events = {}
		_cooldown_deadlines.clear()
		_transfer_deadlines.clear()
	if not is_same(state["ships"], _deadline_roster):
		_deadline_roster = state["ships"]
		_cooldown_deadlines.clear()
		_hull_deadlines_need_sync = true
		# The existing hull index pass will populate live deadlines.

static func _sync_transfer_deadlines(events: Dictionary) -> void:
	if is_same(events, _deadline_events) and _transfer_deadlines.size() == events.size():
		return
	_deadline_events = events
	_transfer_deadlines.clear()
	for key in events:
		_transfer_deadlines.schedule(key, float(events[key]["elapsed"]))

static func _expire_transfer_events(state: Dictionary, scheduled: bool) -> void:
	if not state.has("cargo_transfers"):
		return
	var events: Dictionary = state["cargo_transfers"]
	var now: float = float(state["elapsed"])
	if not scheduled:
		for key in events.keys():
			if now - float(events[key]["elapsed"]) > TRANSFER_EVENT_YEARS:
				events.erase(key)
		return
	_sync_transfer_deadlines(events)
	# Compare using the original subtraction, including strict equality
	# at the lifetime boundary; do not round to a tick or add epsilon.
	for key in _transfer_deadlines.take_due(now, TRANSFER_EVENT_YEARS, true):
		if not events.has(key):
			continue
		var born: float = float(events[key]["elapsed"])
		if now - born > TRANSFER_EVENT_YEARS:
			events.erase(key)
		else:
			_transfer_deadlines.schedule(key, born)

static func _expire_auto_cooldowns(state: Dictionary) -> void:
	var now: float = float(state["elapsed"])
	for id in _cooldown_deadlines.take_due(now):
		var ship: Dictionary = _hulls_by_id.get(id, {})
		if not ship.has("auto_cooldown_until"):
			continue
		var deadline: float = float(ship["auto_cooldown_until"])
		if deadline <= now:
			ship.erase("auto_cooldown_until")
		else:
			_cooldown_deadlines.schedule(id, deadline)

# Slow coefficients depend only on infrastructure, immutable map factors and
# rewards. Compare live inputs on every substep, including in-place edits.
# Population, stocks, blockades and farm variation are deliberately not cached.
static func _economy_rate_inputs(p: Dictionary) -> Array:
	return [p["owner"], p.get("planetless", false), p.get("size_factor", 1.0), p.get("habitation_level", 0),
		p["levels"], p.get("buildings", {}), p["bonuses"], p["abundance"], p.get("conquest_rewards", [])]

static func _rate_entry_due(entry: Dictionary, now: float, inputs: Array) -> bool:
	return entry.is_empty() or now + EPS >= float(entry["due"]) or now < float(entry["sampled"]) or inputs != entry["inputs"]

static func _prepare_economy_rates(state: Dictionary, enabled: bool) -> Dictionary:
	if not enabled or not is_same(state, _economy_rate_state) or not is_same(state["planets"], _economy_rate_roster):
		_economy_rate_entries.clear()
		_economy_wage_entries.clear()
		_economy_rate_state = state if enabled else {}
		_economy_rate_roster = state["planets"] if enabled else []
	if not enabled:
		return {}
	var now: float = float(state["elapsed"])
	var bases: Dictionary = {}
	for index in range((state["planets"] as Array).size()):
		var p: Dictionary = state["planets"][index]
		if int(p["owner"]) <= 0 or not has_station(p):
			_economy_rate_entries.erase(index)
			continue
		var inputs: Array = _economy_rate_inputs(p)
		var entry: Dictionary = _economy_rate_entries.get(index, {})
		if _rate_entry_due(entry, now, inputs):
			var base: Dictionary = {}
			var bonus: Dictionary = {}
			for resource in EXTRACTED:
				base[resource] = _industrial_base(p, resource)
				bonus[resource] = _industrial_bonus(p, resource)
			entry = {"sampled": now, "due": now + ECONOMY_RATE_INTERVAL, "inputs": inputs.duplicate(true),
				"basis": {"base": base, "bonus": bonus, "farm_base": _farm_base(p), "farm_bonus": _farm_bonus(p),
					"housing": habitation_capacity(p), "growth": _growth_bonus(p), "tax": _rank_factor(p, "rank_tax", 0.05)}}
			_economy_rate_entries[index] = entry
		bases[index] = entry["basis"]
	# Remove retired slots (normally the map has a fixed system count).
	for index in _economy_rate_entries.keys():
		if int(index) >= (state["planets"] as Array).size():
			_economy_rate_entries.erase(index)
	return bases

static func _prepare_wage_tables(state: Dictionary, enabled: bool) -> Dictionary:
	if not enabled:
		return {}
	var now: float = float(state["elapsed"])
	var tables: Dictionary = {}
	for owner in state.get("galactic_credits", {}):
		if int(owner) <= 0:
			continue
		var inputs: Array = [state.get("objectives", {}).get(owner, {}).get("rewards", [])]
		var entry: Dictionary = _economy_wage_entries.get(owner, {})
		if _rate_entry_due(entry, now, inputs):
			var factor: float = _player_factor(state, int(owner), "rank_upkeep", 0.05 / 0.95)
			var rates: Dictionary = {}
			for kind in SHIP_UPKEEP_GC:
				rates[kind] = ship_upkeep(kind) / factor
			entry = {"sampled": now, "due": now + ECONOMY_RATE_INTERVAL, "inputs": inputs.duplicate(true), "rates": rates}
			_economy_wage_entries[owner] = entry
		tables[owner] = entry["rates"]
	for owner in _economy_wage_entries.keys():
		if not tables.has(owner):
			_economy_wage_entries.erase(owner)
	return tables

static func _scheduled_wage_rate(state: Dictionary, ship: Dictionary, tables: Dictionary) -> float:
	var owner: int = int(ship["owner"])
	if not tables.has(owner):
		return hull_upkeep(state, ship)
	return float(tables[owner].get(str(ship.get("kind", "")), 0.0))

static func _step_economy(state: Dictionary, frame: STEP_FRAME, dt: float, economy_rates_enabled: bool = true) -> void:
	var bases: Dictionary = _prepare_economy_rates(state, economy_rates_enabled)
	var wage_tables: Dictionary = _prepare_wage_tables(state, economy_rates_enabled)
	_accrue_resident_taxes(state, dt, bases)
	_pay_fleet_upkeep(state, dt, wage_tables)
	state["elapsed"] = float(state["elapsed"]) + dt
	if dt > 0.0:
		_check_unpaid_defections(state)
	_expire_transfer_events(state, frame.deadline_schedule_enabled)
	var combat_graph: Dictionary = military_graph(state)
	frame.graph = combat_graph
	_sector_query_cache.clear()
	_sector_query_graph = combat_graph
	combat_graph.erase("travel_influence")
	combat_graph.erase("travel_permissions")
	_update_planet_blockades(state, combat_graph)
	var census: Dictionary = {}
	for i in range((state["planets"] as Array).size()):
		_work_planet(state, i, dt, bases.get(i, {}), census)
	_refill_empire_fleets(state)
	_begin_hull_index(state)

static func _step_ai(state: Dictionary, frame: STEP_FRAME, dt: float) -> void:
	# Decide treaties before constructing any relation-dependent route or
	# threat caches for this substep.
	_dispatch_ai_diplomacy(state)
	frame.teams = planet_teams(state)
	# Validate the static map and territory once per substep, not on each search.
	frame.cache = {"civilian_routes": _civilian_route_cache(state, frame.teams)}
	var budgets: Array = []
	for field in state["map"].get("fields", []):
		budgets.append({"Metals": field_limit(field, "Metals") * dt, "Crystals": field_limit(field, "Crystals") * dt, ANTIMATTER: field_limit(field, ANTIMATTER) * dt})
	frame.budgets = budgets
	var ai_now: float = float(state["elapsed"])
	var ai_schedule: Dictionary = state.get("_ai_schedule", {})
	for player in state.get("ai_players", []).duplicate():
		if not state["ai_players"].has(player):
			continue
		if ai_now + EPS >= float(ai_schedule.get(player, 0.0)):
			_ai_turn(state, frame.graph, int(player))
			ai_schedule[player] = _next_ai_slot(ai_now, int(player))
	state["_ai_schedule"] = ai_schedule

# Position initialization, passive HP and loading reward touch independent
# fields. Share their hull traversal; keep structure/shield work before
# withdrawal and combat. Reward inputs cannot change during this pass.
static func _prepare_combat_hulls(state: Dictionary, combat_graph: Dictionary, dt: float) -> bool:
	var loading_by_owner: Dictionary = {}
	var needs_threats: bool = false
	for craft in state["ships"]:
		if not needs_threats and craft.get("kind", "") in ["ship", "miner"]:
			needs_threats = true
		_ensure_position(combat_graph["points"] if craft.get("kind", "") in MILITARY_KINDS else state["map"]["points"], craft)
		_regenerate_hull(craft, ship_max_hp(str(craft["kind"])), dt)
		var owner: int = int(craft["owner"])
		if not loading_by_owner.has(owner):
			loading_by_owner[owner] = _player_factor(state, owner, "rank_loading", 0.15)
		var loading: float = float(loading_by_owner[owner])
		if loading > 1.0:
			craft["reward_loading_factor"] = loading
		else:
			craft.erase("reward_loading_factor")
	return needs_threats

static func _step_combat(state: Dictionary, frame: STEP_FRAME, dt: float) -> void:
	var combat_graph: Dictionary = frame.graph
	var needs_threats: bool = _prepare_combat_hulls(state, combat_graph, dt)
	_regenerate_structures(state, dt)
	_refresh_reward_defenses(state, dt)
	_prepare_withdrawals(state, combat_graph)
	_advance_unit_orders(state, combat_graph)
	_update_tactical_orders(state, combat_graph)
	_pirate_decisions(state)
	var threat_index: Dictionary = {}
	_combat(state, combat_graph, dt, threat_index, true, frame.persistent_combat_enabled, needs_threats or not frame.persistent_combat_enabled)
	combat_graph.erase("travel_influence")
	combat_graph.erase("travel_permissions")
	# Station destruction changes ownership during combat. Never use stale
	# allied routes or permit a delivery into the destroyed stockpile.
	var surviving_teams: Array[int] = planet_teams(state)
	if surviving_teams != frame.teams:
		frame.teams = surviving_teams
		frame.cache = {"civilian_routes": _civilian_route_cache(state, frame.teams)}
	_prepare_withdrawals(state, combat_graph)
	_update_salvage(state)
	_index_postcombat_hulls(state, frame)
	frame.salvage_cells = _salvage_cells(state.get("salvage", {}), frame.persistent_logistics_enabled)
	# Only Harvester/Freighter safety reads frozen threat geometry. Combat
	# cannot launch new hulls; the surviving civilian lists are the wake guard.
	if not frame.persistent_combat_enabled or not frame.handoff_miners.is_empty() or not frame.freighters.is_empty():
		frame.salvage_threats = _reuse_combat_threats(state, combat_graph, threat_index)
	_step_resource_handoffs(state, frame, dt)

# One ordered survivor pass for salvage safety, logistics and fleet allocation.
# After combat/withdrawal and before handoffs, membership and position are fixed.
# Keep live hull references; eligibility, cargo and orders are checked at use.
# Each index is retained only for one authority/roster. Owner maps are
# refreshed in original first-encounter order; departed owners are retired.
static func _begin_logistics_indexes(state: Dictionary) -> void:
	if not is_same(state, _logistics_index_state) or not is_same(state["ships"], _logistics_index_roster):
		_logistics_index_state = state
		_logistics_index_roster = state["ships"]
		_handoff_indexes.clear()
		_rendezvous_indexes.clear()
		_salvage_index.clear()

static func _logistics_owner_index(indexes: Dictionary, active: Dictionary, owner: int) -> Variant:
	if not active.has(owner):
		if not indexes.has(owner):
			indexes[owner] = STEP_FRAME.OrderedHullBuckets.new()
		indexes[owner].begin()
		active[owner] = indexes[owner]
	return active[owner]

static func _finish_logistics_owner_indexes(indexes: Dictionary, active: Dictionary, result: Dictionary) -> void:
	for owner in active:
		result[owner] = active[owner].finish()
	for owner in indexes.keys():
		if not active.has(owner):
			indexes.erase(owner)

static func _index_postcombat_hulls(state: Dictionary, frame: STEP_FRAME) -> void:
	var receiver_order: int = 0
	var active: Dictionary = {}
	if frame.persistent_logistics_enabled:
		_begin_logistics_indexes(state)
	for craft in state["ships"]:
		_mark_hull_salvage_busy(craft, frame.salvage_busy)
		var kind: String = str(craft.get("kind", ""))
		if kind == "ship":
			if bool(craft.get("rogue", false)):
				continue
			frame.freighters.append(craft)
			var owner: int = int(craft["owner"])
			if frame.persistent_logistics_enabled:
				var point: Vector2 = craft["position"]
				var cell := Vector2i(floori(point.x / RESOURCE_HANDOFF_RANGE), floori(point.y / RESOURCE_HANDOFF_RANGE))
				_logistics_owner_index(_handoff_indexes, active, owner).append_ordered_hull(cell, receiver_order, craft)
			else:
				if not frame.handoff_receivers.has(owner):
					frame.handoff_receivers[owner] = {}
				_spatial_insert(frame.handoff_receivers[owner], craft["position"], RESOURCE_HANDOFF_RANGE, [receiver_order, craft])
			receiver_order += 1
		elif kind == "miner" and not bool(craft.get("rogue", false)):
			frame.handoff_miners.append(craft)
		elif kind in MILITARY_KINDS:
			var player: int = int(craft["owner"])
			if not frame.military_fleets.has(player):
				frame.military_fleets[player] = []
			frame.military_fleets[player].append(craft)
	if frame.persistent_logistics_enabled:
		_finish_logistics_owner_indexes(_handoff_indexes, active, frame.handoff_receivers)
	_mark_pds_salvage_busy(state, frame.salvage_busy)

static func _step_resource_handoffs(state: Dictionary, frame: STEP_FRAME, dt: float) -> void:
	var stage_receivers: Dictionary = frame.handoff_receivers
	# Passive handoff is independent of route and job. Evaluate all hulls before movement.
	# Membership and positions are frozen here; cargo and eligibility are
	# still checked live for each transfer, in the original fleet order.
	var receiver_neighborhoods: Dictionary = {}
	for miner in frame.handoff_miners:
		if not frame.salvage_busy.has(int(miner["id"])):
			var receivers: Array = []
			if _cargo_total(miner) > EPS:
				var owner: int = int(miner["owner"])
				if not receiver_neighborhoods.has(owner):
					receiver_neighborhoods[owner] = {}
				receivers = _handoff_candidates(stage_receivers.get(owner, {}), miner["position"], receiver_neighborhoods[owner])
			miner["_handoff_sent"] = _miner_handoff(state, frame.graph, miner, receivers, frame.salvage_threats, dt)
	var mining_receivers: Dictionary = frame.mining_receivers
	var active: Dictionary = {}
	for craft in frame.freighters:
		if _mining_receiver_ready(state, craft):
			var owner: int = int(craft["owner"])
			if frame.persistent_logistics_enabled:
				var point: Vector2 = craft["resource_stage"]["point"]
				var cell := Vector2i(floori(point.x / MINING_RENDEZVOUS_RANGE), floori(point.y / MINING_RENDEZVOUS_RANGE))
				_logistics_owner_index(_rendezvous_indexes, active, owner).append(cell, craft)
			else:
				if not mining_receivers.has(owner):
					mining_receivers[owner] = {}
				_spatial_insert(mining_receivers[owner], craft["resource_stage"]["point"], MINING_RENDEZVOUS_RANGE, craft)
	if frame.persistent_logistics_enabled:
		_finish_logistics_owner_indexes(_rendezvous_indexes, active, mining_receivers)

static func _step_formations(state: Dictionary, frame: STEP_FRAME, dt: float) -> void:
	var combat_graph: Dictionary = frame.graph
	var fleets: Dictionary = frame.military_fleets
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
	var combat_positions: Dictionary = frame.combat_positions
	for craft in state["ships"]:
		combat_positions[int(craft["id"])] = craft["position"]
	if frame.persistent_avoidance_enabled:
		_begin_persistent_ship_avoidance(state, combat_positions)
	else:
		_begin_ship_avoidance(combat_positions)
	_dispatch_explorers(state, combat_graph)
	frame.idle_targets = _idle_formation_targets(state, combat_graph)
	frame.coordinated = _coordinate_formations(state, combat_graph, dt)
	frame.service_refs = _movement_service_targets(state) if frame.persistent_combat_enabled else service_targets(state)
	if frame.persistent_combat_enabled:
		if not is_same(state, _repair_index_state) or not is_same(state["ships"], _repair_index_roster):
			_repair_index_state = state
			_repair_index_roster = state["ships"]
			_repair_index.clear()
		if frame.handoff_miners.is_empty():
			_repair_index.clear()
		else:
			_repair_index.refresh(frame.service_refs, MINER_REPAIR_SEARCH, EPS, REPAIR_QUERIES.is_damaged)
			frame.damaged_cells = _repair_index.cells
			frame.repair_neighborhoods = _repair_index.neighborhoods
	else:
		frame.damaged_cells = _damaged_repair_cells(frame.service_refs)

## Runs one hull's highest-priority work for this substep. Hulls that stay
## idle and unmoved become candidates for local wandering.
# Persistent classification, not a second simulation. Replacing the
# state or roster invalidates the entire registry. Dead IDs are removed
# by the canonical removal path; fixture edits are also pruned.
static func _begin_motion_sleep(state: Dictionary) -> void:
	if not is_same(state, _motion_sleep_state) or not is_same(state["ships"], _motion_sleep_roster):
		_motion_sleep_modes.clear()
		_motion_sleep_state = state
		_motion_sleep_roster = state["ships"]
	elif _motion_sleep_modes.size() > _motion_sleep_roster.size():
		for id in _motion_sleep_modes.keys():
			if not _hulls_by_id.has(id):
				_motion_sleep_modes.erase(id)

# A sleeping hull skips only its movement/service dispatch. It remains
# in every authoritative combat, service, vision and collision index.
# These predicates certify that the original path has no observable
# mutation left to perform, including metadata normalization.
static func _motion_sleep_mode(state: Dictionary, frame: STEP_FRAME, ship: Dictionary) -> MotionSleep:
	var kind: String = str(ship.get("kind", ""))
	if kind in ["colony_ship", "warp_gate"] or bool(ship.get("rogue", false)) or bool(ship.get("retreating", false)) or bool(ship.get("_handoff_delivery", false)):
		return MotionSleep.AWAKE
	if ship.get("unit_order", {}).get("kind", "") == "warp_travel":
		return MotionSleep.AWAKE
	if _stop_waiting(state, ship):
		if not ship.has("repair_target") and ship.get("navigation_target") == ship["position"]:
			return MotionSleep.STOPPED
		return MotionSleep.AWAKE
	if ship.has("stop_until"):
		return MotionSleep.AWAKE # The original dispatch must retire the deadline.
	if bool(ship.get("holding", false)):
		if ship.has("hold_heading") and not ship.has("repair_target") and not ship.has("move_only") and ship.get("hold_position") == ship["position"] and ship.get("navigation_target") == ship["position"] and ship.get("heading") == ship["hold_heading"]:
			return MotionSleep.HELD
		return MotionSleep.AWAKE
	# Military hulls have zero cargo capacity and no civilian automatic
	# work. Only the already-normalized, stationary branch may sleep.
	if not military_hull(kind) or ship.has("unit_order") or not ship.get("order_queue", []).is_empty() or not (ship["route"] as Array).is_empty():
		return MotionSleep.AWAKE
	if ship.has("attack_order") or bool(ship.get("attack_local", false)) or ship.has("patrol_from") or ship.has("launch_rally") or ship.has("local_move_target") or ship.has("cargo_order") or ship.has("repair_order") or ship.has("repair_target"):
		return MotionSleep.AWAKE
	if _salvage_active(ship) or ship.has("auto_salvage_target") or ship.has("auto_salvage_origin") or bool(ship.get("passing_fire", false)):
		return MotionSleep.AWAKE
	if ship.get("combat_target") != -1 or ship.get("pursuit_target") != -1 or ship.get("pursuit_left") != 0.0:
		return MotionSleep.AWAKE
	var id: int = int(ship["id"])
	if frame.idle_targets.has(id) or frame.coordinated.has(id):
		return MotionSleep.AWAKE
	return MotionSleep.IDLE_MILITARY

# A military position order returns from the original dispatcher before
# any automatic salvage, repair, science or routine work. Prove that all
# earlier branches are inactive, then call the very same movement/arrival
# routine. The guards are live on every substep, not a cached order type.
# Navigation still checks the rock corridor and nearby hulls (and falls
# back to detours); combat and contact settlement remain independent.
static func _try_direct_order_dispatch(state: Dictionary, frame: STEP_FRAME, ship: Dictionary, dt: float) -> bool:
	if not ship.has("local_move_target") or not military_hull(str(ship.get("kind", ""))):
		return false
	if bool(ship.get("rogue", false)) or bool(ship.get("retreating", false)) or bool(ship.get("_handoff_delivery", false)) or bool(ship.get("holding", false)) or ship.has("stop_until") or _stop_waiting(state, ship):
		return false
	if ship.has("attack_order") or ship.has("cargo_order") or ship.has("launch_rally") or _engaged(ship):
		return false
	var order_kind: String = str(ship.get("unit_order", {}).get("kind", ""))
	if order_kind not in ["position", "sector_entry", ""]:
		return false
	# _work_local_move has the same arrival and queued-order semantics
	# as before, including reanchoring any invalid predictive trajectory.
	return _work_local_move(frame.graph, ship, dt, state)

static func _step_hull(state: Dictionary, frame: STEP_FRAME, ship: Dictionary, dt: float) -> void:
	if not frame.motion_sleep_enabled:
		_step_hull_active(state, frame, ship, dt)
		return
	var id: int = int(ship["id"])
	var prior_mode: int = int(_motion_sleep_modes.get(id, MotionSleep.AWAKE))
	# A new command, enemy, displacement, cooldown expiry or new wander
	# target is checked at the original boundary, even for persistent sleepers.
	if prior_mode != MotionSleep.AWAKE and int(_motion_sleep_mode(state, frame, ship)) == prior_mode:
		frame.motion_sleep_skips += 1
		return
	if prior_mode != MotionSleep.AWAKE:
		_motion_sleep_modes.erase(id)
	if _try_direct_order_dispatch(state, frame, ship, dt):
		frame.direct_order_dispatches += 1
		# Arrival can immediately make the hull eligible for idle sleep.
		# Retain the original classification below for that transition.
	else:
		_step_hull_active(state, frame, ship, dt)
	# Avoid reclassifying expensive civilian routines unless explicitly held
	# or stopped. Colonies must still grow food; morphs must still progress.
	if military_hull(str(ship.get("kind", ""))) or bool(ship.get("holding", false)) or ship.has("stop_until"):
		var next_mode: MotionSleep = _motion_sleep_mode(state, frame, ship)
		if next_mode != MotionSleep.AWAKE:
			_motion_sleep_modes[id] = next_mode

static func _step_hull_active(state: Dictionary, frame: STEP_FRAME, ship: Dictionary, dt: float) -> void:
	var initial_position: Vector2 = ship["position"]
	if _step_hull_overrides(state, frame, ship, initial_position, dt):
		return
	if _step_hull_services(state, frame, ship, dt):
		return
	if _step_hull_routine(state, frame, ship, dt):
		return
	var ship_id: int = int(ship["id"])
	# Only use the idle budget if the ship started and finished its
	# work idle and did not already move this tick.
	if frame.idle_targets.has(ship_id) and _is_idle_ship(ship) and autocast_ready(state, ship, "wander") and not frame.coordinated.has(ship_id) and ship["position"] == initial_position:
		frame.wander_candidates[ship_id] = true

## Pirate, warp, morph, withdrawal, stop, hold, follow and attack orders.
## Returns true when the hull's work for this substep is complete.
static func _step_hull_overrides(state: Dictionary, frame: STEP_FRAME, ship: Dictionary, initial_position: Vector2, dt: float) -> bool:
	var combat_graph: Dictionary = frame.graph
	if bool(ship.get("rogue", false)):
		_work_pirate(state, ship, dt)
		return true
	if ship.get("kind", "") == "warp_gate":
		return true
	if ship.get("unit_order", {}).get("kind", "") == "warp_travel" and not bool(ship.get("retreating", false)):
		var previous_warp: float = float(ship.get("warp_ready", 0.0))
		_work_warp_order(state, combat_graph, ship, dt)
		if float(ship.get("warp_ready", 0.0)) > previous_warp:
			frame.combat_positions[int(ship["id"])] = ship["position"]
		return true
	if colony_morphing(ship):
		if _work_colony(state, ship, dt):
			_remove_indexed_hull(state, ship)
		else:
			frame.repair_parked[int(ship["id"])] = true
		return true
	if ship.get("_handoff_delivery", false):
		ship.erase("_handoff_delivery")
		return true
	if ship.get("kind", "") == "colony_ship":
		var previous_food: float = float(ship.get("food_produced", 0.0))
		_grow_colony_cargo(ship, dt)
		var produced: float = float(ship.get("food_produced", 0.0)) - previous_food
		if produced > 0.0:
			var progress: Dictionary = objective_progress(state, int(ship["owner"]))
			progress["colony_food"] = float(progress.get("colony_food", 0.0)) + produced
	if bool(ship.get("retreating", false)) and armed(ship):
		ship.erase("repair_target")
		var before_hp: float = float(ship["hp"])
		_work_withdrawal(state, combat_graph, ship, dt)
		if float(ship["hp"]) > before_hp and ship["position"] == initial_position:
			frame.repair_parked[int(ship["id"])] = true
		return true
	if _stop_waiting(state, ship):
		ship["navigation_target"] = ship["position"]
		ship.erase("repair_target")
		return true
	ship.erase("stop_until")
	if bool(ship.get("holding", false)) and ship.has("hold_heading"):
		ship.erase("repair_target")
		_work_local_hold(combat_graph, ship, dt)
		return true
	var service_refs: Dictionary = frame.service_refs
	var follow: Dictionary = ship.get("unit_order", {})
	var escort_far: bool = follow.get("kind", "") == "follow" and bool(follow.get("guard", false)) and (ship["position"] as Vector2).distance_to(service_refs.get(int(follow["target"]), {}).get("position", Vector2.INF)) > FOLLOW_DISTANCE * 2.0
	if (escort_far or not (ship.get("kind", "") in MILITARY_KINDS and _engaged(ship) and not bool(ship.get("holding", false)))) and _work_follow(state, combat_graph, ship, service_refs, dt):
		return true
	if ship.has("attack_order"):
		var ref: Dictionary = service_refs.get(int(ship["attack_order"]), {})
		if ref.is_empty() or not _hostile_hull(state, int(ship["owner"]), ref):
			_clear_tactical_order(ship)
			_finish_manual(ship)
		else:
			var point: Vector2 = ref["position"]
			var node: int = int(ref["node"]) if int(ref["node"]) >= 0 else _attack_destination(combat_graph, ref["entity"])
			if ship["kind"] in MILITARY_KINDS and (ship["position"] as Vector2).distance_to(point) <= LASER_RANGE:
				_maneuver_fighter(ship, point, dt)
			elif node >= 0:
				_manual_travel(state, combat_graph, ship, node, point, dt, LASER_RANGE * 0.8)
			return true
	return false

## Explicit cargo, rally, guard, move, salvage, staging, repair, colonize,
## opportunistic salvage, hold and science work, in priority order.
static func _step_hull_services(state: Dictionary, frame: STEP_FRAME, ship: Dictionary, dt: float) -> bool:
	var combat_graph: Dictionary = frame.graph
	var service_refs: Dictionary = frame.service_refs
	var salvage_ship_id: int = int(ship["id"])
	if _work_cargo_order(state, combat_graph, ship, service_refs, dt):
		return true
	if _work_launch_rally(state, ship, dt):
		return true
	var guard: Dictionary = ship.get("unit_order", {})
	if guard.get("kind", "") == "guard" and (not _engaged(ship) or not sector_contains(combat_graph, int(guard["target"]), ship["position"])):
		ship["guard_arrived"] = _manual_travel(state, combat_graph, ship, int(guard["target"]), guard["point"], dt, 8.0)
		return true
	if _work_local_move(combat_graph, ship, dt, state):
		return true
	if _work_salvage(state, combat_graph, ship, dt, frame.salvage_busy.has(salvage_ship_id)):
		return true
	if _work_resource_stage(state, combat_graph, ship, frame.teams, frame.cache, frame.salvage_threats, frame.salvage_cells, frame.salvage_busy, dt):
		return true
	# Each automatic job checks its own cooldown; explicit movement,
	# follow, cargo orders and emergency withdrawal already take priority.
	if ship.get("kind", "ship") == "miner" and (ship.has("repair_order") or not _engaged(ship) and int(ship.get("yard_target", -1)) == -1) and _work_miner_repair(state, combat_graph, ship, service_refs, dt, frame.damaged_cells, frame.repair_neighborhoods):
		if ship.has("repair_target") and dt > 0.0:
			var recipient: int = int(ship["repair_target"])
			if service_refs.get(recipient, {}).get("kind", "") == "ship":
				frame.repaired_hulls[recipient] = true
		return true
	ship.erase("repair_target")
	if ship.get("kind", "") == "colony_ship" and ship.get("unit_order", {}).get("kind", "") == "colonize":
		if _work_colony(state, ship, dt):
			_remove_indexed_hull(state, ship)
		elif ship.has("colony_transform_progress"):
			# Assembly is anchored to the orbit; contact pushes other hulls.
			frame.repair_parked[salvage_ship_id] = true
		return true
	if _work_opportunistic_salvage(state, combat_graph, ship, dt, frame.salvage_busy, frame.salvage_cells, frame.coordinated.has(salvage_ship_id), frame.salvage_threats):
		return true
	if bool(ship.get("holding", false)) and not bool(ship.get("retreating", false)):
		_work_local_hold(combat_graph, ship, dt)
		return true
	if _work_science(state, combat_graph, ship, dt):
		return true
	return false

## Kind-specific autonomous work. Returns true only when a freighter took a
## new resource stage, which skips the idle wander check like before.
static func _step_hull_routine(state: Dictionary, frame: STEP_FRAME, ship: Dictionary, dt: float) -> bool:
	var combat_graph: Dictionary = frame.graph
	var profile: Dictionary = frame.profile
	var detailed_profile: bool = bool(profile.get("_detail", false))
	if ship.get("kind", "ship") == "colony_ship":
		if _begin_farm_delivery(state, ship):
			_work_salvage(state, combat_graph, ship, dt)
			return true
		if _work_colony(state, ship, dt):
			_remove_indexed_hull(state, ship)
			return true
	elif ship.get("kind", "ship") == "ship":
		var before: int = Time.get_ticks_usec() if not profile.is_empty() else 0
		# Allocate the needed mining support before offering excess
		# idle freighters to interstation trade; never interrupt a haul.
		# Check the existing strict retry deadline before costly eligibility.
		var stage_due: bool = float(state["elapsed"]) >= float(ship.get("next_resource_stage_search", 0.0)) and _is_idle_ship(ship) and ship.get("order_queue", []).is_empty() and _cargo_total(ship) <= EPS and autocast_ready(state, ship, "trade")
		if stage_due:
			var search_started: int = Time.get_ticks_usec() if detailed_profile else 0
			var staged: bool = _choose_resource_stage(state, combat_graph, ship, frame.teams, frame.cache, frame.salvage_threats, {}, true)
			if detailed_profile:
				profile["Freighter staging search"] = int(profile.get("Freighter staging search", 0)) + Time.get_ticks_usec() - search_started
			if staged:
				ship["next_resource_stage_search"] = _next_search_slot(float(state["elapsed"]), int(ship["id"]), RESOURCE_STAGE_SEARCH_YEARS)
				if not profile.is_empty():
					frame.civilian_usec += Time.get_ticks_usec() - before
				return true
		var work_started: int = Time.get_ticks_usec() if detailed_profile else 0
		_work_ship(state, ship, frame.teams, frame.cache, dt, frame.deadline_schedule_enabled)
		if detailed_profile:
			profile["Freighter routine"] = int(profile.get("Freighter routine", 0)) + Time.get_ticks_usec() - work_started
		if float(state["elapsed"]) >= float(ship.get("next_resource_stage_search", 0.0)) and _is_idle_ship(ship) and ship.get("order_queue", []).is_empty() and _cargo_total(ship) <= EPS and autocast_ready(state, ship, "trade"):
			ship["next_resource_stage_search"] = _next_search_slot(float(state["elapsed"]), int(ship["id"]), RESOURCE_STAGE_SEARCH_YEARS)
			var retry_started: int = Time.get_ticks_usec() if detailed_profile else 0
			_choose_resource_stage(state, combat_graph, ship, frame.teams, frame.cache, frame.salvage_threats, frame.salvage_cells)
			if detailed_profile:
				profile["Freighter staging search"] = int(profile.get("Freighter staging search", 0)) + Time.get_ticks_usec() - retry_started
		if not profile.is_empty():
			frame.civilian_usec += Time.get_ticks_usec() - before
	elif ship.get("kind", "ship") == "miner":
		var before: int = Time.get_ticks_usec() if not profile.is_empty() else 0
		var rendezvous_started: int = Time.get_ticks_usec() if detailed_profile else 0
		var rendezvous_worked: bool = _work_miner_rendezvous(state, combat_graph, ship, frame.teams, frame.cache, frame.salvage_threats, frame.mining_receivers, frame.mining_commitments, dt)
		if detailed_profile:
			profile["Miner rendezvous"] = int(profile.get("Miner rendezvous", 0)) + Time.get_ticks_usec() - rendezvous_started
		if not rendezvous_worked:
			var autonomous_started: int = Time.get_ticks_usec() if detailed_profile else 0
			_work_miner(state, ship, frame.teams, frame.cache, frame.budgets, dt, profile)
			if detailed_profile:
				profile["Miner autonomous work"] = int(profile.get("Miner autonomous work", 0)) + Time.get_ticks_usec() - autonomous_started
		if not profile.is_empty():
			var miner_usec: int = Time.get_ticks_usec() - before
			if detailed_profile:
				profile["Miner work"] = int(profile.get("Miner work", 0)) + miner_usec
			frame.civilian_usec += miner_usec
	elif ship.get("kind", "") in MILITARY_KINDS:
		_step_military_motion(state, frame, ship, dt)
	return false

static func _step_military_motion(state: Dictionary, frame: STEP_FRAME, ship: Dictionary, dt: float) -> void:
	var combat_graph: Dictionary = frame.graph
	var combat_positions: Dictionary = frame.combat_positions
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
	elif frame.coordinated.has(int(ship["id"])):
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

static func _step_settle_movement(state: Dictionary, frame: STEP_FRAME, dt: float) -> void:
	var repair_parked: Dictionary = frame.repair_parked
	var fuse_spatial: bool = frame.persistent_avoidance_enabled and dt > 0.0
	if fuse_spatial:
		_begin_contact_indexes(state)
		_separation_batch.begin(state["ships"].size(), SHIP_SEPARATION_RADIUS)
	# Resolve wandering after every Harvester has had a chance to repair.
	# This avoids dependence on whether the recipient precedes its healer
	# in the fleet array. Explicit movement and other work remain legal.
	var ships: Array = state["ships"]
	for slot in range(ships.size()):
		var ship: Dictionary = ships[slot]
		var id: int = int(ship["id"])
		if frame.repaired_hulls.has(id) and _is_idle_ship(ship) and not _unit_order_running(ship) and ship["position"] == frame.combat_positions.get(id):
			repair_parked[id] = true
		if repair_parked.has(id):
			ship["navigation_target"] = ship["position"]
		elif frame.wander_candidates.has(id):
			_navigate(ship, frame.idle_targets[id], ship_speed(str(ship.get("kind", "ship"))) * dt)
		ship.erase("_handoff_sent")
		_mark_sector_arrival(state, ship)
		if not frame.deadline_schedule_enabled and ship.has("auto_cooldown_until") and float(ship["auto_cooldown_until"]) <= float(state["elapsed"]):
			ship.erase("auto_cooldown_until")
		if ship.has("arrival_wait_until") and arrival_wait_remaining(state, ship) <= EPS and ship.get("unit_order", {}).get("kind", "") != "sector":
			ship.erase("arrival_wait_until")
		if ship.has("wander_cooldown_override") and autocast_remaining(state, ship) <= EPS and not _unit_order_running(ship):
			ship.erase("wander_cooldown_override")
		# Hull work (including warp and removal) is complete. The original
		# separation snapshot uses these surviving IDs and frozen positions.
		if fuse_spatial and frame.combat_positions.has(id):
			_separation_batch.append(slot, id, frame.combat_positions[id])
	# Expired cooldowns read as zero before and after erasure. Settlement
	# has no cross-hull dependency on these keys; retire only due IDs here,
	# before separation and contact use the settled state.
	if frame.deadline_schedule_enabled:
		_expire_auto_cooldowns(state)
	_end_ship_avoidance()
	if fuse_spatial:
		_separation_batch.finish()
	var contact_snapshot: Dictionary = {}
	_separate_ships(state, frame.graph, frame.combat_positions, dt, repair_parked, frame.persistent_avoidance_enabled, null, contact_snapshot if fuse_spatial else null, _separation_batch if fuse_spatial else null)
	if dt > 0.0:
		_resolve_ship_contacts(state, frame.graph, frame.combat_positions, dt, repair_parked, frame.persistent_avoidance_enabled, contact_snapshot)

const OPENING_OBJECTIVES = {"economic": "medium_shipyard", "military": "military_built"}

static func objective_progress(state: Dictionary, player: int) -> Dictionary:
	if not state.has("objectives"):
		state["objectives"] = {}
	var all_progress: Dictionary = state["objectives"]
	if not all_progress.has(player):
		all_progress[player] = {"colonies": {}, "metals": 0.0, "population": 0.0, "completed": {}, "points": {"economic": 0, "military": 0, "tech": 0}, "offers": {}, "active_goals": OPENING_OBJECTIVES.duplicate(), "goal_refresh": {}, "goal_draws": {}}
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
const CLOAK_PRIOR_MILITARY_REWARDS: int = 3
const UNIQUE_CONQUEST_REWARDS = ["cloak", "shield_3", "warp_gate", "crystals"]
const CONQUEST_REWARDS = {
	"rank_extraction": ["Advanced Extraction","Asteroid mining rate +10% of base","","economic","Metals"],
	"rank_loading": ["Automated Loading","Cargo handoff and unloading speed +15% of base","","economic","ship"],
	"rank_building": ["Efficient Construction","Station construction speed +10% of base","","economic","warehouse"],
	"rank_tax": ["Commercial Networks","Resident tax revenue +5% of base","","economic","Metals"],
	"rank_upkeep": ["Fleet Administration","Fleet upkeep −5% initially (diminishing returns)","","economic","ship"],
	"rank_colony": ["Colonial Engineering","Colony assembly speed +15% of base","","economic","colony_ship"],
	"rank_assembly": ["Rapid Assembly","Military hull construction speed +10% of base","","military","fighter"],
	"rank_missile": ["Missile Engineering","Military ship missile damage +10% of base","","military","attack"],
	"rank_repair": ["Emergency Repairs","Ship repair at stations +15% of base","","military","repair"],
	"rank_station": ["Reinforced Stations","Station maximum HP +10% of base","","military","reinforced_plating"],
	"rank_sensor": ["Advanced Sensors","Military ship vision +10% of base","","military","scout"],
	"rank_antimatter": ["Antimatter Engineering","Antimatter collection speed +15% of base","","tech","science_ship"],
	"rank_robotics": ["Advanced Robotics","Shipyard staffing −10% initially (diminishing returns)","","tech","yard"],
	"rank_delivery": ["Planetary Automation","Planetary upgrade delivery speed +10% of base","","tech","warehouse"],
	"rank_synthetic": ["Synthetic Organics","Orbital Organics production +15% of base","","tech","Organics"],
	"rank_reactor": ["Advanced Reactors","Crystal construction costs −10% initially (diminishing returns)","","tech","Crystals"],
	"rank_stellar": ["Stellar Engineering","Dyson Sphere construction costs −20% initially (diminishing returns)","","tech","dyson_sphere"],
	"industry": ["Industrial Revolution", "Planet Metals production +15%", "", "economic", "Metals"],
	"crystals": ["Crystalline Synthesis", "Planet Crystals production +25%", "", "economic", "Crystals"],
	"agriculture": ["Agricultural Revolution", "Planet Organics production +15%", "", "economic", "Organics"],
	"population": ["Population Boom", "Maximum planet population growth +15%", "", "general", "habitation"],
	"storage": ["Megastructures", "Station storage +20%", "", "general", "warehouse"],
	"shield_1": ["Shields 1", "Military ship shields: 30% of hull HP\nStation shields: 50% of station HP", "Extra Crystals to build military ships: 20% of base Metals cost", "military", "guard"],
	"shield_2": ["Shields 2", "Military ship shields: 60% of hull HP\nStation shields: 100% of station HP", "Extra Crystals to build military ships: 40% of base Metals cost", "military", "guard"],
	"shield_3": ["Shields 3", "Military ship shields: 90% of hull HP\nStation shields: 150% of station HP", "Extra Crystals to build military ships: 60% of base Metals cost", "military", "guard"],
	"armor": ["Reinforced Armor", "Military ships take 15% less hull damage", "Military ships cost 15% more Metals", "military", "reinforced_plating"],
	"dyson_sphere": ["Dyson Sphere", "Unlock Dyson Sphere\nShips built in that system cost 50% fewer materials", "Build cost: 20,000t Metals\n10,000t Crystals", "tech", "dyson_sphere"],
	"warp_gate": ["Warp Gates", "Turn a Science Ship into a Warp Gate\nTravel quickly between linked gates", "1 antimatter per gate", "tech", "transform"],
	"cloak": ["Cloaking Field", "Scouts invisible beyond 250 range\nVisible for 5s after firing", "Replaces Scout shields and armor\nExtra Crystals: 60% of base Metals cost", "military", "auto_wander"],
	"rank_metals": ["Precision Refining", "Planet Metals production +5% of base", "", "economic", "Metals"],
	"rank_food": ["Cultivation", "Planet Organics production +5% of base", "", "economic", "Organics"],
	"rank_growth": ["Medical Research", "Maximum planet population growth +5% of base", "", "economic", "habitation"],
	"rank_orbital": ["Orbital Agriculture", "Orbital Organics production +5% of base", "", "economic", "Organics"],
	"rank_storage": ["Expanded Warehouses", "Station storage +8% of base", "", "general", "warehouse"],
	"rank_housing": ["Habitat Engineering", "Planet housing +15% of base", "", "general", "habitation"],
	"rank_crystals": ["Incubator Research", "Planet Crystals production +5% of base", "", "tech", "Crystals"],
	"rank_science": ["Scientific Fabrication", "Science Ships cost less Metals", "", "tech", "science_ship"],
	"rank_civilian": ["Civilian Fabrication", "Civilian ships cost less Metals", "", "tech", "ship"],
	"rank_damage": ["Weapons Calibration", "Military weapon damage +3% of base", "", "military", "attack"],
	"rank_armor": ["Hull Materials", "Military ships take less hull damage", "Excludes cloaked Scouts", "military", "reinforced_plating"],
	"rank_military_metal": ["Fleet Fabrication", "Military ships cost less Metals", "", "military", "Metals"],
	"rank_military_crystal": ["Crystal Engineering", "Military ships cost less Crystals", "", "military", "Crystals"]
}

static func _player_rank(state: Dictionary, owner: int, key: String) -> int:
	return state.get("objectives", {}).get(owner, {}).get("rewards", []).count(key)

static func _player_factor(state: Dictionary, owner: int, key: String, amount: float) -> float:
	return 1.0 + amount * _player_rank(state, owner, key)

static func hull_upkeep(state: Dictionary, ship: Dictionary) -> float:
	return ship_upkeep(str(ship.get("kind", ""))) / _player_factor(state, int(ship["owner"]), "rank_upkeep", 0.05 / 0.95)

static func yard_staff_required(p: Dictionary, slot: int) -> float:
	return ceilf(float(SHIPYARD_POPULATION[slot]) / _rank_factor(p, "rank_robotics", 1.0 / 0.9 - 1.0))

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
	if key == "cloak":
		# Count military purchases, including repeatable military research.
		# Economic, technology and shared rewards cannot skip this tier.
		var military: int = 0
		for prior in rewards:
			if CONQUEST_REWARDS.has(prior) and CONQUEST_REWARDS[prior][3] == "military":
				military += 1
		return military >= CLOAK_PRIOR_MILITARY_REWARDS
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
			var old_maximum: float = station_max_hp(system)
			system["conquest_rewards"] = rewards.duplicate()
			if has_station(system) and key == "rank_station":
				system["station"]["hp"] = float(system["station"]["hp"]) + station_max_hp(system) - old_maximum
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
	return kind in MILITARY_KINDS

static func construction_cost(p: Dictionary, kind: String, level: int) -> Dictionary:
	var cost: Dictionary = _construction_cost_before_dyson(p, kind, level)
	if cost.has("Crystals"):
		cost["Crystals"] = ceilf(float(cost["Crystals"]) / _rank_factor(p, "rank_reactor", 1.0 / 0.9 - 1.0))
	if kind == "dyson_sphere":
		for resource in cost:
			cost[resource] = ceilf(float(cost[resource]) / _rank_factor(p, "rank_stellar", 0.25))
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
		damage_factors[player] = 1.0 + 0.03 * reward_rank(rewards, "rank_damage")
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
	if team == PIRATE_COMBAT_GROUP:
		return true
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
	"medium_shipyard": ["economic", "medium_shipyards_completed", 1, "Upgrade a shipyard to Medium", ""],
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
	"military_built": ["military", "fighters_built", 7, "Build 7 fighters", ""],
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
	var active: Dictionary = progress.get("active_goals", OPENING_OBJECTIVES.duplicate())
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
	var active: Dictionary = progress.get("active_goals", OPENING_OBJECTIVES.duplicate())
	var completed: Dictionary = progress["completed"]
	for category in REWARD_CATEGORIES:
		if category == "tech" and not objective_tech_unlocked(progress):
			continue
		var current: String = str(active.get(category, ""))
		if reward_points(progress, category) > 0 or (not current.is_empty() and not completed.has(current)):
			continue
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
		if int(p["owner"]) == player and has_fitting_yard(p, kind):
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

# All active empire targets share one census at the original refill boundary.
# Enqueuing for one owner cannot change another owner's live/queued totals.
static func _empire_target_counts(state: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for owner in state.get("empire_targets", {}):
		if not state["empire_targets"][owner].is_empty():
			counts[int(owner)] = {"live": {}, "queued": {}}
	if counts.is_empty():
		return counts
	for ship in state["ships"]:
		var owner: int = int(ship["owner"])
		if not counts.has(owner) or not SHIP_KINDS.has(ship["kind"]):
			continue
		var live: Dictionary = counts[owner]["live"]
		var kind: String = str(ship["kind"])
		live[kind] = int(live.get(kind, 0)) + 1
	for p in state["planets"]:
		var owner: int = int(p["owner"])
		if not counts.has(owner):
			continue
		var queued: Dictionary = counts[owner]["queued"]
		for job in p["queue"]:
			var kind: String = str(job["kind"])
			if SHIP_KINDS.has(kind):
				queued[kind] = int(queued.get(kind, 0)) + 1
	return counts

static func _refill_empire_fleets(state: Dictionary) -> void:
	var now: float = float(state["elapsed"])
	if now + EPS < float(state.get("_next_empire_refill", 0.0)):
		return
	state["_next_empire_refill"] = now + 0.5
	var all_counts: Dictionary = _empire_target_counts(state)
	for player in state.get("empire_targets", {}):
		var fleet: Dictionary = state["empire_targets"][player]
		if fleet.is_empty():
			continue
		var counts: Dictionary = all_counts[int(player)]
		for kind in fleet:
			var needed: int = int(fleet[kind]) - int(counts["live"].get(kind, 0)) - int(counts["queued"].get(kind, 0))
			if needed <= 0:
				continue
			for index in range(state["planets"].size()):
				var p: Dictionary = state["planets"][index]
				if int(p["owner"]) != int(player):
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

# Supported read-only rule queries for the presentation layer.
# Preserve the original internal helpers to keep simulation call sites stable.

static func has_queued_job(planet: Dictionary, kind: String, target: String) -> bool:
	return _has_job(planet, kind, target)

static func nominal_work(kind: String, level: int) -> float:
	return _work(kind, level)

static func base_recipe_cost(kind: String, level: int) -> Dictionary:
	return _cost(kind, level)

static func combat_group(state: Dictionary, owner: int) -> int:
	return _combat_group(state, owner)

static func shares_group_vision(state: Dictionary, viewer: int, source: int) -> bool:
	return _shares_group_vision(state, viewer, source)

static func unit_order_running(ship: Dictionary) -> bool:
	return _unit_order_running(ship)

static func science_target_valid(state: Dictionary, graph: Dictionary, ship: Dictionary, index: int) -> bool:
	return _science_target_valid(state, graph, ship, index)

static func cargo_total(ship: Dictionary) -> float:
	return _cargo_total(ship)

static func friendly_service_target(state: Dictionary, owner: int, target: Dictionary) -> bool:
	return _friendly_target(state, owner, target)

static func repair_site_safe(state: Dictionary, graph: Dictionary, owner: int, site: int) -> bool:
	return _repair_site_safe(state, graph, owner, site)

static func is_idle_ship(ship: Dictionary) -> bool:
	return _is_idle_ship(ship)

static func unit_order_valid(state: Dictionary, graph: Dictionary, ship: Dictionary, order: Dictionary, append: bool) -> bool:
	return _valid_unit_order(state, graph, ship, order, append)

static func hostile_hull(state: Dictionary, player: int, target: Dictionary) -> bool:
	return _hostile_hull(state, player, target)

static func warp_order_valid(state: Dictionary, ship: Dictionary, source: int) -> bool:
	return _warp_order_valid(state, ship, source)

static func ship_engaged(ship: Dictionary) -> bool:
	return _engaged(ship)

static func salvage_active(ship: Dictionary) -> bool:
	return _salvage_active(ship)
