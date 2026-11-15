extends RefCounted
## Development-only balance configuration. No advanced recipes have been defined.
const MAP = preload("res://scripts/planet_map.gd")
const RESOURCES = ["Metals", "Plastics", "Textiles", "Organics", "Tech", "Crystals"]
const EXTRACTED = ["Metals", "Plastics", "Crystals"]
const ACTIVE_PRODUCTION = ["Metals", "Plastics", "Organics", "Crystals"]
# Population is expressed in people (fractional values retained in simulation).
const HOME_POPULATION: float = 10000.0
const COLONY_POPULATION: float = 1000.0
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
const CARGO_CAPACITY: float = 10.0
const MINED_RESOURCES = ["Metals", "Crystals"]
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
# Reference stock, not a storage cap; percentage thresholds use these units.
const TRADE_REFERENCE: float = 1000.0
const SHIP_KINDS = ["ship", "colony_ship", "fighter", "miner"]
const MINING_STAY: float = 5.0
const SHIP_HP: float = 100.0
const LASER_DAMAGE: float = 18.0
const LASER_RANGE: float = 180.0
const AI_INTERVAL: float = 4.0

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

static func create(map_data: Dictionary, players: Dictionary, ordered: Array[int]) -> Dictionary:
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
            abundance[resource] = 0.0 if rng.randf() < 0.35 else rng.randf_range(0.5, 2.0)
        var home: bool = i < ordered.size()
        var owner: int = ordered[i] if home else 0
        var yards: Array = []
        if home:
            # Bootstrap values are test data, not final economy balance.
            abundance["Metals"] = maxf(1.0, float(abundance["Metals"]))
            levels["Metals"] = 1
            levels["Organics"] = 1
            stock["Metals"] = 600.0
            yards.append({"level": 1, "job": -1})
        var richness: float = 0.0
        for resource in EXTRACTED:
            richness += float(abundance[resource])
        richness += float(bonuses["Organics"]) - 1.0
        # Environment is generated separately, not inferred from size or deposits.
        var advanced: float = rng.randf_range(1.1, 1.6) if rng.randf() < 0.3 else 1.0
        planets.append({"size_factor": lerpf(0.86, 1.18, clampf(richness / 6.8, 0.0, 1.0)), "advanced_bonus": advanced, "owner": owner, "home": home, "population": HOME_POPULATION if home else 0.0, "population_velocity": 0.0, "farm_phase": float(i) * 2.399963, "farm_factor": 1.0, "stock": stock, "levels": levels,
            "abundance": abundance, "bonuses": bonuses, "thresholds": thresholds,
            "yards": yards, "queue": [], "continuous": {}})
    var ai_players: Array[int] = []
    for id in ordered:
        if bool(players[id].get("ai", false)):
            ai_players.append(id)
    var state: Dictionary = {"ai_players": ai_players, "next_ai": 0.0, "map": map_data, "planets": planets, "ships": [], "teams": teams, "next_id": 1, "elapsed": 0.0, "fog_of_war": DEFAULT_FOG_OF_WAR, "explored": {}, "mining_policies": {}, "military": {}}
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
    return state.get("mining_policies", {}).get(player, {}).get(index, {"enabled": true, "Metals": true, "Crystals": true})

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
        for resource in MINED_RESOURCES:
            if bool(policy[resource]):
                resources.append(resource)
    return resources

## Read-only player-wide holdings: stock plus the player's own cargo in transit.
static func empire_totals(state: Dictionary, player: int) -> Dictionary:
    var stock: Dictionary = empty_stock()
    var cargo: Dictionary = empty_stock()
    var total: Dictionary = empty_stock()
    var population: float = 0.0
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
        storage_reference[resource] = float(planets) * TRADE_REFERENCE
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
    if team == 0 or teams[start] != team:
        return []
    var best: Array[int] = []
    var distance: float = INF
    for i in range(planets.size()):
        if teams[i] != team or not MAP.linked(state["map"], i, target):
            continue
        var path: Array[int] = MAP.path(state["map"], teams, team, start, i)
        if path.is_empty():
            continue
        path.append(target)
        var length: float = MAP.route_length(state["map"], path)
        if length < distance:
            distance = length
            best = path
    return best

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
        colony["population"] = COLONY_POPULATION
        colony["population_velocity"] = 0.0
        colony["levels"]["Organics"] = 1
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

static func farm_potential(planet: Dictionary) -> float:
    if int(planet["owner"]) == 0:
        return 0.0
    return ORGANICS_PER_LEVEL * int(planet["levels"]["Organics"]) * float(planet["bonuses"].get("Organics", 1.0)) * float(planet.get("farm_factor", 1.0))

static func population_capacity(planet: Dictionary) -> float:
    return farm_potential(planet) * POPULATION_PER_ORGANICS_RATE

static func population_multiplier(planet: Dictionary) -> float:
    return float(planet["population"]) / HOME_POPULATION

static func population_growth(planet: Dictionary) -> float:
    return float(planet.get("population_velocity", 0.0))

static func organics_demand(planet: Dictionary) -> float:
    return float(planet["population"]) / POPULATION_PER_ORGANICS_RATE

static func rate(planet: Dictionary, resource: String) -> float:
    if not ACTIVE_PRODUCTION.has(resource) or int(planet["owner"]) == 0:
        return 0.0
    var level: int = int(planet["levels"][resource])
    var bonus: float = float(planet["bonuses"].get(resource, 1.0))
    if resource == "Organics":
        # Small populations still produce a surplus; farm capacity limits output.
        var capacity: float = population_capacity(planet)
        if capacity <= EPS:
            return 0.0
        var labor: float = sqrt(clampf(float(planet["population"]) / capacity, 0.0, 1.0))
        return farm_potential(planet) * labor
    var output: float = PRODUCTION_PER_LEVEL * level * float(planet["abundance"].get(resource, 0.0)) * bonus * population_multiplier(planet)
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
    var growth_ceiling: float = current * exp(growth_constant * dt)
    if next > growth_ceiling:
        next = growth_ceiling
        next_velocity = growth_constant * next
    # A food shortfall prevents positive growth even with demographic momentum.
    var food_available: float = float(planet["stock"]["Organics"]) + rate(planet, "Organics") * dt
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
        "ship": return {"Metals": 120.0}
        "colony_ship": return {"Metals": 240.0}
        "fighter": return {"Metals": 90.0}
        "miner": return {"Metals": 180.0}
        "yard": return {"Metals": 480.0}
        "yard_upgrade": return {"Metals": 180.0 * float(level) * float(level)}
        "production": return {"Metals": 150.0 * float(level) * float(level)}
    return {}

static func _work(kind: String, level: int) -> float:
    match kind:
        "ship": return 48.0
        "colony_ship": return 72.0
        "fighter": return 36.0
        "miner": return 60.0
        "yard": return 30.0
        "yard_upgrade": return 15.0 * level
        "production": return 10.0 * level
    return 1.0

static func _get_owned(state: Dictionary, player: int, index: int) -> Dictionary:
    var planets: Array = state.get("planets", [])
    if index < 0 or index >= planets.size() or int(planets[index]["owner"]) != player:
        return {}
    return planets[index]

# Reserve a slot as soon as construction is ordered.
static func shipyard_count(p: Dictionary) -> int:
    var count: int = (p.get("yards", []) as Array).size()
    for item in p.get("queue", []):
        if item["kind"] == "yard":
            count += 1
    return count

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
            if shipyard_count(p) >= MAX_SHIPYARDS:
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
        "production":
            if not RESOURCES.has(target) or _has_job(p, kind, target):
                return false
            if EXTRACTED.has(target) and float(p["abundance"].get(target, 0.0)) <= 0.0:
                return false
            # Non-extraction production rules have not been designed yet.
            if not ACTIVE_PRODUCTION.has(target):
                return false
            level = int(p["levels"][target]) + 1
        _: return false
    var id: int = int(state["next_id"])
    state["next_id"] = id + 1
    p["queue"].append({"id": id, "kind": kind, "target": target, "level": level,
        "cost": _cost(kind, level), "work": _work(kind, level),
        "progress": 0.0, "allocated": empty_stock(), "size": SHIP_SIZE if kind in ["ship", "colony_ship", "fighter", "miner"] else 0})
    return true

static func production_modifier(system: Dictionary, resource: String) -> float:
    var modifier: float = float(system["bonuses"].get(resource, 1.0))
    if EXTRACTED.has(resource):
        modifier *= float(system["abundance"].get(resource, 0.0))
    return modifier

static func _continuous_target(p: Dictionary, key: String) -> Array:
    if SHIP_KINDS.has(key):
        return [key, ""] if key != "ship" or bool(p["home"]) else []
    if key.begins_with("production:"):
        var resource: String = key.trim_prefix("production:")
        if ACTIVE_PRODUCTION.has(resource) and (not EXTRACTED.has(resource) or float(p["abundance"].get(resource, 0.0)) > 0.0):
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

static func _refill_continuous(state: Dictionary, index: int, p: Dictionary) -> void:
    var keys: Array = p["continuous"].keys()
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
        if not bool(p["continuous"].get(key, false)):
            cycle.erase(key)
    for key in keys:
        if not bool(p["continuous"][key]):
            continue
        var order: Array = _continuous_target(p, str(key))
        if order.is_empty():
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
        elif _has_job(p, order[0], order[1]):
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
        for yard in p["yards"]:
            if int(yard["job"]) == job_id:
                yard["job"] = -1
        var key: String = str(item["kind"])
        if key == "production" or key == "yard_upgrade":
            key += ":" + str(item["target"])
        if p["continuous"].has(key):
            p["continuous"][key] = false
        p["queue"].erase(item)
        return true
    return false

static func set_thresholds(state: Dictionary, player: int, index: int, resource: String, minimum: float, maximum: float) -> bool:
    var p: Dictionary = _get_owned(state, player, index)
    if p.is_empty() or not RESOURCES.has(resource):
        return false
    if not is_finite(minimum) or not is_finite(maximum) or minimum < 0.0 or maximum < minimum or maximum > 100.0:
        return false
    p["thresholds"][resource] = {"min": minimum, "max": maximum}
    return true

static func _possible(p: Dictionary, item: Dictionary) -> float:
    var work: float = float(item["work"])
    var possible: float = work - float(item["progress"])
    for resource in item["cost"]:
        var per_work: float = float(item["cost"][resource]) / work
        if per_work > 0.0:
            possible = minf(possible, float(p["stock"][resource]) / per_work)
    return maxf(0.0, possible)

static func _advance(p: Dictionary, item: Dictionary, work_budget: float) -> bool:
    var amount: float = minf(work_budget, _possible(p, item))
    for resource in item["cost"]:
        var used: float = amount * float(item["cost"][resource]) / float(item["work"])
        p["stock"][resource] = maxf(0.0, float(p["stock"][resource]) - used)
        item["allocated"][resource] = float(item["allocated"][resource]) + used
    item["progress"] = float(item["progress"]) + amount
    return float(item["progress"]) >= float(item["work"]) - EPS

static func _finish(state: Dictionary, index: int, p: Dictionary, item: Dictionary) -> void:
    match str(item["kind"]):
        "production":
            p["levels"][item["target"]] = int(item["level"])
        "yard":
            p["yards"].append({"level": 1, "job": -1})
        "yard_upgrade":
            p["yards"][int(item["target"])]["level"] = int(item["level"])
        "ship", "colony_ship", "fighter", "miner":
            state["ships"].append({"id": int(item["id"]), "kind": str(item["kind"]), "owner": int(p["owner"]), "at": index,
                "route": [], "leg": 0.0, "source": -1, "dest": -1, "hp": SHIP_HP, "cargo": empty_stock(), "field": -1, "mining_mode": "idle", "field_leg": 0.0})
    p["queue"].erase(item)

static func _work_planet(state: Dictionary, index: int, dt: float) -> void:
    var p: Dictionary = state["planets"][index]
    if int(p["owner"]) == 0:
        return
    var elapsed: float = float(state["elapsed"])
    p["farm_factor"] = 1.0 + FARM_VARIATION * sin(TAU * elapsed / FARM_CYCLE_SECONDS + float(p["farm_phase"]))
    _update_population(p, dt)
    for resource in ACTIVE_PRODUCTION:
        p["stock"][resource] = float(p["stock"][resource]) + rate(p, resource) * dt
    # Consume real local inventory; imported Organics can satisfy demand but
    # cannot permanently raise the local farming plateau.
    p["stock"]["Organics"] = maxf(0.0, float(p["stock"]["Organics"]) - organics_demand(p) * dt)
    # New yards and planetary production use infrastructure work, not an existing yard.
    for item in (p["queue"] as Array).duplicate():
        if int(item["size"]) == 0 and item["kind"] != "yard_upgrade" and _advance(p, item, dt):
            _finish(state, index, p, item)
    _refill_continuous(state, index, p)
    var assigned: Dictionary = {}
    # Preserve active jobs. A started upgrade remains attached to its own yard even if blocked.
    for y in range((p["yards"] as Array).size()):
        var yard: Dictionary = p["yards"][y]
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
    return total

static func _need(p: Dictionary, resource: String) -> float:
    return maxf(0.0, TRADE_REFERENCE * float(p["thresholds"][resource]["min"]) / 100.0 - float(p["stock"][resource]))

static func _surplus(p: Dictionary, resource: String) -> float:
    return maxf(0.0, float(p["stock"][resource]) - TRADE_REFERENCE * float(p["thresholds"][resource]["max"]) / 100.0)

static func _opportunity(a: Dictionary, b: Dictionary) -> bool:
    for r in RESOURCES:
        if _surplus(a, r) > EPS and _need(b, r) > EPS:
            return true
    return false

static func _path(state: Dictionary, teams: Array[int], team: int, a: int, b: int, cache: Dictionary) -> Array[int]:
    var key: String = "%d:%d:%d" % [team, a, b]
    if not cache.has(key):
        cache[key] = MAP.path(state["map"], teams, team, a, b)
    var result: Array[int] = []
    result.assign(cache[key])
    return result

static func _set_route(ship: Dictionary, path: Array[int]) -> void:
    ship["route"] = path.slice(1)
    ship["leg"] = 0.0

static func _move(state: Dictionary, ship: Dictionary, dt: float) -> bool:
    var route: Array = ship["route"]
    var points: Array = state["map"]["points"]
    var distance: float = SHIP_SPEED * dt
    while not route.is_empty() and distance > EPS:
        var current: Vector2 = points[int(ship["at"])]
        var next: Vector2 = points[int(route[0])]
        var remaining: float = current.distance_to(next) - float(ship["leg"])
        if distance < remaining:
            ship["leg"] = float(ship["leg"]) + distance
            return false
        distance -= remaining
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
    var source: int = int(ship["source"])
    var dest: int = int(ship["dest"])
    if source == here and dest >= 0 and teams[dest] == team:
        # No reservations: actual arrival decides which surplus remains.
        var free: float = CARGO_CAPACITY - _cargo_total(ship)
        for resource in RESOURCES:
            var amount: float = minf(free, minf(_surplus(planets[here], resource), _need(planets[dest], resource)))
            if amount <= EPS:
                continue
            planets[here]["stock"][resource] = float(planets[here]["stock"][resource]) - amount
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
    if int(ship["dest"]) == here and _cargo_total(ship) > EPS:
        for resource in RESOURCES:
            var amount: float = minf(float(ship["cargo"][resource]), _need(planets[here], resource))
            ship["cargo"][resource] = float(ship["cargo"][resource]) - amount
            planets[here]["stock"][resource] = float(planets[here]["stock"][resource]) + amount
        ship["dest"] = -1
    if _cargo_total(ship) > EPS:
        _pick_loaded_destination(state, ship, teams, team, cache)
    else:
        ship["source"] = -1
        ship["dest"] = -1
        _choose_delivery(state, ship, teams, team, cache)

static func field_limit(field: Dictionary, resource: String) -> float:
    return FIELD_MINING_LIMIT * float(field.get(resource, 0.0)) if MINED_RESOURCES.has(resource) else 0.0

static func field_inventory(field: Dictionary) -> Dictionary:
    var stock: Dictionary = {"Metals": 0.0, "Crystals": 0.0}
    for chunk in field.get("chunks", []):
        var resource: String = str(chunk["resource"])
        stock[resource] = float(stock[resource]) + float(chunk["remaining"])
    return stock

static func _find_chunk(field: Dictionary, id: int) -> Dictionary:
    for chunk in field.get("chunks", []):
        if int(chunk["id"]) == id:
            return chunk
    return {}

static func _choose_field(state: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary) -> void:
    var fields: Array = state["map"].get("fields", [])
    var owner: int = int(ship["owner"])
    var team: int = int(state["teams"].get(owner, 0))
    var best: float = INF
    var chosen: int = -1
    var best_path: Array[int] = []
    var best_chunk: Dictionary = {}
    for i in range(fields.size()):
        var field: Dictionary = fields[i]
        if not discovered(state, owner, "fields", i) or _mining_resources(state, owner, i).is_empty():
            continue
        var anchor: int = int(field["anchor"])
        if int(state["planets"][anchor]["owner"]) != owner:
            continue
        var path: Array[int] = _path(state, teams, team, int(ship["at"]), anchor, cache)
        if path.is_empty():
            continue
        var resources: Array[String] = _mining_resources(state, owner, i)
        var approach: Vector2 = state["map"]["points"][anchor]
        var route_distance: float = MAP.route_length(state["map"], path)
        for chunk in field.get("chunks", []):
            if not resources.has(str(chunk["resource"])) or float(chunk["remaining"]) <= EPS:
                continue
            var distance: float = route_distance + approach.distance_to(chunk["position"]) * 2.0
            if distance < best:
                best = distance
                chosen = i
                best_path = path
                best_chunk = chunk
    if chosen >= 0:
        ship["field"] = chosen
        ship["chunk"] = int(best_chunk["id"])
        ship["mining_target"] = best_chunk["position"]
        ship["mining_mode"] = "approach"
        _set_route(ship, best_path)

static func _work_miner(state: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary, budgets: Array, dt: float) -> void:
    var mode: String = str(ship.get("mining_mode", "idle"))
    if mode == "idle":
        _choose_field(state, ship, teams, cache)
        return
    var field_index: int = int(ship["field"])
    var field: Dictionary = state["map"]["fields"][field_index]
    var anchor: int = int(field["anchor"])
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
    var distance: float = (state["map"]["points"][anchor] as Vector2).distance_to(ship["mining_target"])
    var travel: float = SHIP_SPEED * dt / maxf(distance, 1.0)
    if mode == "outbound":
        var chunk: Dictionary = _find_chunk(field, int(ship["chunk"]))
        if chunk.is_empty() or not _mining_resources(state, int(ship["owner"]), field_index).has(str(chunk["resource"])):
            ship["mining_mode"] = "return"
            return
        ship["field_leg"] = minf(1.0, float(ship["field_leg"]) + travel)
        if float(ship["field_leg"]) >= 1.0:
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
            ship["cargo"][resource] = float(ship["cargo"][resource]) + amount
            chunk["remaining"] = maxf(0.0, float(chunk["remaining"]) - amount)
            budgets[field_index][resource] = maxf(0.0, float(budgets[field_index][resource]) - amount)
            if float(chunk["remaining"]) <= EPS:
                field["chunks"].erase(chunk)
                available = false
        if float(ship["mining_years"]) >= MINING_STAY - EPS and (not available or _cargo_total(ship) >= MINER_CAPACITY - 0.1):
            ship["mining_mode"] = "return"
        return
    if mode == "return":
        ship["field_leg"] = maxf(0.0, float(ship["field_leg"]) - travel)
        if float(ship["field_leg"]) <= 0.0:
            var stock: Dictionary = state["planets"][anchor]["stock"]
            for resource in MINED_RESOURCES:
                stock[resource] = float(stock[resource]) + float(ship["cargo"][resource])
                ship["cargo"][resource] = 0.0
            ship["mining_mode"] = "idle"
            ship["field"] = -1

static func military_home(state: Dictionary, player: int) -> int:
    for i in range((state["planets"] as Array).size()):
        if int(state["planets"][i]["owner"]) == player and bool(state["planets"][i]["home"]):
            return i
    return -1

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
static func military_graph(state: Dictionary) -> Dictionary:
    var points: Array = state["map"]["points"].duplicate()
    var edges: Array = state["map"]["edges"].duplicate()
    for field in state["map"].get("fields", []):
        edges.append([int(field["anchor"]), points.size()])
        points.append(field["position"])
    var adjacent: Array = []
    for i in range(points.size()):
        adjacent.append([])
    for edge in edges:
        adjacent[edge[0]].append(edge[1])
        adjacent[edge[1]].append(edge[0])
    return {"points": points, "edges": edges, "adjacent": adjacent}

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
    return {"distance": distances, "next": next_hop}

static func _military_approach(graph: Dictionary, ship: Dictionary, paths: Dictionary) -> Dictionary:
    var here: int = int(ship["at"])
    var leg: float = float(ship["leg"])
    var distances: Dictionary = paths["distance"]
    var route: Array = ship["route"]
    var best: float = leg + float(distances.get(here, INF))
    var reverse: bool = not route.is_empty() and leg > EPS
    if not route.is_empty():
        var other: int = int(route[0])
        var length: float = (graph["points"][here] as Vector2).distance_to(graph["points"][other])
        var forward: float = length - leg + float(distances.get(other, INF))
        if forward <= best:
            return {"distance": forward, "anchor": other, "reverse": false, "edge": true}
    return {"distance": best, "anchor": here, "reverse": reverse, "edge": reverse}

static func _redirect_fighter(graph: Dictionary, ship: Dictionary, target: int, paths: Dictionary) -> void:
    var approach: Dictionary = _military_approach(graph, ship, paths)
    var anchor: int = int(approach["anchor"])
    var route: Array[int] = []
    if bool(approach["edge"]):
        if bool(approach["reverse"]):
            var old: int = int(ship["at"])
            ship["at"] = int(ship["route"][0])
            ship["leg"] = (graph["points"][old] as Vector2).distance_to(graph["points"][ship["at"]]) - float(ship["leg"])
        route.append(anchor)
    else:
        ship["leg"] = 0.0
    var current: int = anchor
    while current != target and paths["next"].has(current):
        current = int(paths["next"][current])
        route.append(current)
    ship["route"] = route
    ship["dest"] = target

static func _allocate_fighters(state: Dictionary, graph: Dictionary, player: int, fleet: Array) -> void:
    var weights: Dictionary = military_policy(state, player, "fighter")
    var counts: Dictionary = _apportion(weights.keys(), weights, fleet.size())
    var actual: Dictionary = {}
    for ship in fleet:
        var dest: int = int(ship.get("dest", -1))
        actual[dest] = int(actual.get(dest, 0)) + 1
    var matches: bool = true
    for node in counts:
        if int(counts[node]) != int(actual.get(node, 0)):
            matches = false
            break
    if matches:
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
        if int(best_ship.get("dest", -1)) != best_node:
            _redirect_fighter(graph, best_ship, best_node, paths[best_node])
        counts[best_node] -= 1
        remaining.erase(best_ship)

static func combat_position(state: Dictionary, graph: Dictionary, ship: Dictionary) -> Vector2:
    var points: Array = graph["points"] if ship.get("kind", "") == "fighter" else state["map"]["points"]
    var pos: Vector2 = points[int(ship["at"])]
    if ship.get("kind", "") == "miner" and ship.get("mining_mode", "") in ["outbound", "mining", "return"]:
        return pos.lerp(ship["mining_target"], float(ship["field_leg"]))
    var route: Array = ship["route"]
    if not route.is_empty():
        var next: Vector2 = points[int(route[0])]
        pos = pos.lerp(next, clampf(float(ship["leg"]) / maxf(EPS, pos.distance_to(next)), 0.0, 1.0))
    return pos

static func _combat(state: Dictionary, graph: Dictionary, dt: float) -> void:
    var ships: Array = state["ships"]
    var positions: Dictionary = {}
    var cells: Dictionary = {}
    for ship in ships:
        var id: int = int(ship["id"])
        var pos: Vector2 = combat_position(state, graph, ship)
        positions[id] = pos
        var cell := Vector2i(floori(pos.x / LASER_RANGE), floori(pos.y / LASER_RANGE))
        if not cells.has(cell):
            cells[cell] = []
        cells[cell].append(ship)
    var damage: Dictionary = {}
    for ship in ships:
        if ship.get("kind", "") != "fighter":
            continue
        var id: int = int(ship["id"])
        var pos: Vector2 = positions[id]
        var team: int = int(state["teams"].get(int(ship["owner"]), 0))
        var cell := Vector2i(floori(pos.x / LASER_RANGE), floori(pos.y / LASER_RANGE))
        var target: int = -1
        var best: float = LASER_RANGE * LASER_RANGE
        for x in range(-1, 2):
            for y in range(-1, 2):
                for other in cells.get(cell + Vector2i(x, y), []):
                    if int(state["teams"].get(int(other["owner"]), 0)) == team or team == 0:
                        continue
                    var other_id: int = int(other["id"])
                    var distance: float = pos.distance_squared_to(positions[other_id])
                    if distance < best or (is_equal_approx(distance, best) and (target < 0 or other_id < target)):
                        best = distance
                        target = other_id
        ship["combat_target"] = target
        var cooldown: float = maxf(0.0, float(ship.get("laser_cooldown", 0.0)) - dt)
        if target >= 0 and cooldown <= EPS:
            damage[target] = float(damage.get(target, 0.0)) + LASER_DAMAGE
            cooldown = 1.0
            ship["laser_until"] = float(state["elapsed"]) + 0.2
        ship["laser_cooldown"] = cooldown
    for ship in ships.duplicate():
        var id: int = int(ship["id"])
        if damage.has(id):
            ship["hp"] = maxf(0.0, float(ship.get("hp", SHIP_HP)) - float(damage[id]))
            if float(ship["hp"]) <= EPS:
                ships.erase(ship)

static func _ai_colony_target(state: Dictionary, player: int, ship: Dictionary, reserved: Dictionary) -> int:
    var best: float = INF
    var target: int = -1
    for index in range((state["planets"] as Array).size()):
        if reserved.has(index) or not discovered(state, player, "planets", index):
            continue
        var path: Array[int] = colony_path(state, player, ship, index)
        if path.is_empty():
            continue
        var richness: float = float(state["planets"][index]["abundance"].get("Metals", 0.0))
        var score: float = MAP.route_length(state["map"], path) / (1.0 + minf(richness, 2.0) * 0.15)
        if score < best:
            best = score
            target = index
    return target

static func _ai_turn(state: Dictionary, graph: Dictionary, player: int) -> void:
    var home: int = military_home(state, player)
    if home < 0:
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
        if int(planets[int(field["anchor"])]["owner"]) == player and float(field_inventory(field)["Metals"]) > EPS:
            useful_fields += 1
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
        var metal: float = float(p["stock"]["Metals"])
        var level: int = int(p["levels"]["Metals"])
        var abundance: float = float(p["abundance"].get("Metals", 0.0))
        var farm: int = int(p["levels"]["Organics"])
        # Save for expansion instead of continually spending on cheap hulls.
        if index == home and expansion and counts["colony_ship"] == 0 and metal < 240.0:
            continue
        var action: String = ""
        var target: String = ""
        if abundance > 0.0 and level == 0 and metal >= 150.0:
            action = "production"
            target = "Metals"
        elif index == home and expansion and counts["colony_ship"] == 0 and metal >= 240.0:
            action = "colony_ship"
        elif index == home and owned.size() > 1 and counts["ship"] < mini(12, owned.size() * 2) and metal >= 120.0:
            action = "ship"
        elif not (p["yards"] as Array).is_empty() and useful_fields > 0 and counts["miner"] < mini(6, useful_fields * 2) and metal >= 180.0:
            action = "miner"
        elif not (p["yards"] as Array).is_empty() and counts["fighter"] < maxi(3, mini(24, owned.size() * 2)) and metal >= 90.0:
            action = "fighter"
        elif expansion and not (p["yards"] as Array).is_empty() and counts["colony_ship"] < 3 and metal >= 240.0:
            var local_probe: Dictionary = {"kind": "colony_ship", "owner": player, "at": index, "route": []}
            if _ai_colony_target(state, player, local_probe, reserved) >= 0:
                action = "colony_ship"
        if action.is_empty():
            if abundance > 0.0 and level < 4 and rate(p, "Metals") < PLANET_MINING_LIMIT and metal >= float(_cost("production", level + 1)["Metals"]):
                action = "production"
                target = "Metals"
            elif farm < 3 and float(p["population"]) > population_capacity(p) * 0.8 and metal >= float(_cost("production", farm + 1)["Metals"]):
                action = "production"
                target = "Organics"
            elif (p["yards"] as Array).is_empty() and metal >= 480.0:
                action = "yard"
            elif not (p["yards"] as Array).is_empty() and counts["fighter"] < 32 and metal >= 180.0:
                action = "fighter"
            else:
                for resource in ["Plastics", "Crystals"]:
                    if float(p["abundance"].get(resource, 0.0)) > 0.0 and int(p["levels"][resource]) == 0 and metal >= 300.0:
                        action = "production"
                        target = resource
                        break
        if not action.is_empty() and enqueue(state, player, index, action, target) and SHIP_KINDS.has(action):
            counts[action] += 1
    if fighters.is_empty():
        return
    var center: Vector2 = Vector2.ZERO
    for ship in fighters:
        center += combat_position(state, graph, ship)
    center /= float(fighters.size())
    var goal: int = -1
    var nearest: float = INF
    var pois: Array[int] = military_pois(state, player)
    for ship in state["ships"]:
        if int(state["teams"].get(int(ship["owner"]), 0)) == team:
            continue
        var node: int = int(ship["at"])
        if not pois.has(node):
            continue
        var distance: float = center.distance_squared_to(combat_position(state, graph, ship))
        if distance < nearest:
            nearest = distance
            goal = node if (ship["route"] as Array).is_empty() else int(ship["route"][0])
            if ship.get("kind", "") == "miner" and ship.get("mining_mode", "") in ["outbound", "mining", "return"]:
                goal = planets.size() + int(ship["field"])
    if goal < 0 or not pois.has(goal):
        goal = -1
        nearest = INF
        for node in pois:
            if node >= planets.size() or int(planets[node]["owner"]) == 0 or int(state["teams"].get(int(planets[node]["owner"]), 0)) == team:
                continue
            var distance: float = center.distance_squared_to(graph["points"][node])
            if distance < nearest:
                nearest = distance
                goal = node
    set_military(state, player, "fighter", home if goal < 0 else goal, 100)

static func step(state: Dictionary, dt: float) -> void:
    state["elapsed"] = float(state["elapsed"]) + dt
    for i in range((state["planets"] as Array).size()):
        _work_planet(state, i, dt)
    var teams: Array[int] = planet_teams(state)
    var cache: Dictionary = {}
    var budgets: Array = []
    for field in state["map"].get("fields", []):
        budgets.append({"Metals": field_limit(field, "Metals") * dt, "Crystals": field_limit(field, "Crystals") * dt})
    var combat_graph: Dictionary = military_graph(state)
    if float(state["elapsed"]) >= float(state.get("next_ai", 0.0)) and not state.get("ai_players", []).is_empty():
        state["next_ai"] = float(state["elapsed"]) + AI_INTERVAL
        for player in state["ai_players"]:
            _ai_turn(state, combat_graph, int(player))
    _combat(state, combat_graph, dt)
    var fleets: Dictionary = {}
    for craft in state["ships"]:
        if craft.get("kind", "") == "fighter":
            var player: int = int(craft["owner"])
            if not fleets.has(player):
                fleets[player] = []
            fleets[player].append(craft)
    for player in fleets:
        _allocate_fighters(state, combat_graph, int(player), fleets[player])
    for ship in (state["ships"] as Array).duplicate():
        if ship.get("kind", "ship") == "colony_ship":
            if _work_colony(state, ship, dt):
                state["ships"].erase(ship)
        elif ship.get("kind", "ship") == "ship":
            _work_ship(state, ship, teams, cache, dt)
        elif ship.get("kind", "ship") == "miner":
            _work_miner(state, ship, teams, cache, budgets, dt)
        elif ship.get("kind", "") == "fighter" and int(ship.get("combat_target", -1)) < 0:
            _move({"map": combat_graph}, ship, dt)
    update_exploration(state)
