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
const ORGANICS_PER_LEVEL: float = 8.0
const POPULATION_PER_ORGANICS_RATE: float = 12500.0
# Critically damped demographic response (seconds = years).
const POPULATION_RESPONSE: float = 0.065
const FARM_VARIATION: float = 0.05
const FARM_CYCLE_SECONDS: float = 100.0
const START_YEAR: int = 1
const CARGO_CAPACITY: float = 10.0
const MINED_RESOURCES = ["Metals", "Crystals"]
# Provisional per-resource ceilings, independent of unlimited upgrade levels.
const PLANET_MINING_LIMIT: float = 200.0
const FIELD_MINING_LIMIT: float = 400.0
const MINER_CAPACITY: float = 60.0
const MINER_RATE: float = 12.0
const SHIP_SPEED: float = 95.0
const SHIP_SIZE: int = 1
const EPS: float = 0.00001
const MAX_QUEUE: int = 200

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
    for i in range(MAP.COUNT):
        var stock: Dictionary = empty_stock()
        var levels: Dictionary = empty_stock()
        var abundance: Dictionary = {}
        var bonuses: Dictionary = {"Organics": 1.0, "Crystals": 1.0}
        for resource in ["Organics", "Crystals"]:
            if rng.randf() < 0.5:
                bonuses[resource] = rng.randf_range(1.1, 1.8)
        var thresholds: Dictionary = {}
        for resource in RESOURCES:
            thresholds[resource] = {"min": 100.0, "max": 200.0}
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
            "yards": yards, "queue": []})
    return {"map": map_data, "planets": planets, "ships": [], "teams": teams, "next_id": 1, "elapsed": 0.0}

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
    return {"stock": stock, "cargo": cargo, "resources": total, "population": population,
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
    var output: float = 8.0 * level * float(planet["abundance"].get(resource, 0.0)) * bonus * population_multiplier(planet)
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
        "yard_upgrade": return {"Metals": 240.0 * level}
        "production": return {"Metals": 80.0 * level}
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

static func enqueue(state: Dictionary, player: int, index: int, kind: String, target: String = "") -> bool:
    var p: Dictionary = _get_owned(state, player, index)
    if p.is_empty() or (p["queue"] as Array).size() >= MAX_QUEUE:
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
            p["yards"][y]["job"] = -1
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
        p["queue"].erase(item)
        return true
    return false

static func set_thresholds(state: Dictionary, player: int, index: int, resource: String, minimum: float, maximum: float) -> bool:
    var p: Dictionary = _get_owned(state, player, index)
    if p.is_empty() or not RESOURCES.has(resource):
        return false
    if not is_finite(minimum) or not is_finite(maximum) or minimum < 0.0 or maximum < minimum or maximum > 1000000.0:
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
                "route": [], "leg": 0.0, "source": -1, "dest": -1, "cargo": empty_stock(), "field": -1, "mining_mode": "idle", "field_leg": 0.0})
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
    # Upgrades and new infrastructure use fixed durations. Shipyards are not needed.
    for item in (p["queue"] as Array).duplicate():
        if int(item["size"]) == 0 and _advance(p, item, dt):
            _finish(state, index, p, item)
    # Preserve active assignments, but release blocked or upgrading yards.
    var assigned: Dictionary = {}
    for y in range((p["yards"] as Array).size()):
        var yard: Dictionary = p["yards"][y]
        var retained: bool = false
        if not _has_job(p, "yard_upgrade", str(y)):
            for item in p["queue"]:
                if int(item["id"]) == int(yard["job"]) and int(item["size"]) <= max_size(int(yard["level"])) and _possible(p, item) > EPS:
                    assigned[int(item["id"])] = true
                    retained = true
                    break
        if not retained:
            yard["job"] = -1
    for y in range((p["yards"] as Array).size()):
        var yard: Dictionary = p["yards"][y]
        if _has_job(p, "yard_upgrade", str(y)):
            continue
        var chosen: Dictionary = {}
        for item in p["queue"]:
            if int(item["size"]) == 0 or int(item["size"]) > max_size(int(yard["level"])):
                continue
            var id: int = int(item["id"])
            if id == int(yard["job"]):
                if _possible(p, item) > EPS:
                    chosen = item
                    break
                assigned.erase(id)
                yard["job"] = -1
            if int(yard["job"]) == -1 and not assigned.has(id) and _possible(p, item) > EPS:
                chosen = item
                break
        if chosen.is_empty():
            yard["job"] = -1
            continue
        var id: int = int(chosen["id"])
        yard["job"] = id
        assigned[id] = true
        if _advance(p, chosen, yard_speed(int(yard["level"])) * dt):
            _finish(state, index, p, chosen)
            yard["job"] = -1

static func _cargo_total(ship: Dictionary) -> float:
    var total: float = 0.0
    for r in RESOURCES:
        total += float(ship["cargo"][r])
    return total

static func _need(p: Dictionary, resource: String) -> float:
    return maxf(0.0, float(p["thresholds"][resource]["min"]) - float(p["stock"][resource]))

static func _surplus(p: Dictionary, resource: String) -> float:
    return maxf(0.0, float(p["stock"][resource]) - float(p["thresholds"][resource]["max"]))

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

static func _choose_field(state: Dictionary, ship: Dictionary, teams: Array[int], cache: Dictionary) -> void:
    var fields: Array = state["map"].get("fields", [])
    var owner: int = int(ship["owner"])
    var team: int = int(state["teams"].get(owner, 0))
    var best: float = INF
    var chosen: int = -1
    var best_path: Array[int] = []
    for i in range(fields.size()):
        var field: Dictionary = fields[i]
        var anchor: int = int(field["anchor"])
        if int(state["planets"][anchor]["owner"]) != owner:
            continue
        var path: Array[int] = _path(state, teams, team, int(ship["at"]), anchor, cache)
        if path.is_empty():
            continue
        var distance: float = MAP.route_length(state["map"], path) + (state["map"]["points"][anchor] as Vector2).distance_to(field["position"]) * 2.0
        if distance < best:
            best = distance
            chosen = i
            best_path = path
    if chosen >= 0:
        ship["field"] = chosen
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
            ship["mining_mode"] = "outbound"
            ship["field_leg"] = 0.0
        return
    var distance: float = (state["map"]["points"][anchor] as Vector2).distance_to(field["position"])
    var travel: float = SHIP_SPEED * dt / maxf(distance, 1.0)
    if mode == "outbound":
        ship["field_leg"] = minf(1.0, float(ship["field_leg"]) + travel)
        if float(ship["field_leg"]) >= 1.0:
            ship["mining_mode"] = "mining"
        return
    if mode == "mining":
        var free: float = MINER_CAPACITY - _cargo_total(ship)
        # Allocate proportional shares of the remaining hold and shared field budget.
        var richness: float = float(field["Metals"]) + float(field["Crystals"])
        for resource in MINED_RESOURCES:
            var amount: float = minf(free * float(field[resource]) / richness, minf(MINER_RATE * float(field[resource]) * dt, float(budgets[field_index][resource])))
            ship["cargo"][resource] = float(ship["cargo"][resource]) + amount
            budgets[field_index][resource] = maxf(0.0, float(budgets[field_index][resource]) - amount)
        if _cargo_total(ship) >= MINER_CAPACITY - 0.1:
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

static func step(state: Dictionary, dt: float) -> void:
    state["elapsed"] = float(state["elapsed"]) + dt
    for i in range((state["planets"] as Array).size()):
        _work_planet(state, i, dt)
    var teams: Array[int] = planet_teams(state)
    var cache: Dictionary = {}
    var budgets: Array = []
    for field in state["map"].get("fields", []):
        budgets.append({"Metals": field_limit(field, "Metals") * dt, "Crystals": field_limit(field, "Crystals") * dt})
    for ship in (state["ships"] as Array).duplicate():
        if ship.get("kind", "ship") == "colony_ship":
            if _work_colony(state, ship, dt):
                state["ships"].erase(ship)
        elif ship.get("kind", "ship") == "ship":
            _work_ship(state, ship, teams, cache, dt)
        elif ship.get("kind", "ship") == "miner":
            _work_miner(state, ship, teams, cache, budgets, dt)
        # Fighters remain in orbit; combat and military orders are not designed yet.
