extends RefCounted
## Pure economy simulation. A territory graph can later be replaced by regions.
## One step = one simulation second. No per-unit orders are required.

const RULES = preload("res://scripts/lobby_rules.gd")
const RESOURCES = ["iron", "copper", "steel", "supplies"]
const DEPOSITS = [
    "iron", "copper", "iron", "copper", "iron", "copper", "iron", "copper",
    "iron", "copper", "iron", "copper", "iron", "copper", "iron", "copper", ""
]
const EDGE_CAPACITY: int = 3
const STORAGE_CAPACITY: int = 30
const HQ_SUPPLY_CAPACITY: int = 999999
const MINE_RATE: int = 2

static func deposit(index: int) -> String:
    if index < 0 or index >= DEPOSITS.size():
        return ""
    return str(DEPOSITS[index])

static func empty_stocks() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for _index in range(RULES.MAP_NODE_COUNT):
        result.append({"iron": 0, "copper": 0, "steel": 0, "supplies": 0})
    return result

static func starting_buildings(players: Dictionary) -> Array[String]:
    var result: Array[String] = []
    result.resize(RULES.MAP_NODE_COUNT)
    result.fill("")
    var ids: Array[int] = RULES.ordered_peers(players)
    for seat in range(mini(ids.size(), RULES.MAX_PLAYERS)):
        result[seat] = "hq"
    return result

static func can_build(owners: Array[int], buildings: Array[String],
        team: int, index: int, kind: String) -> bool:
    if not RULES.valid_team(team) or owners.size() != RULES.MAP_NODE_COUNT:
        return false
    if buildings.size() != RULES.MAP_NODE_COUNT:
        return false
    if index < 0 or index >= owners.size() or owners[index] != team:
        return false
    if buildings[index] == "hq" or buildings[index] == kind:
        return false
    if kind == "mine":
        return not deposit(index).is_empty()
    return kind == "smelter" or kind == "factory" or kind == ""

static func total_for_team(owners: Array[int], stocks: Array[Dictionary],
        team: int) -> Dictionary:
    var total: Dictionary = {"iron": 0, "copper": 0, "steel": 0, "supplies": 0}
    for node in range(mini(owners.size(), stocks.size())):
        if owners[node] != team:
            continue
        for key in RESOURCES:
            total[key] = int(total[key]) + int(stocks[node].get(key, 0))
    return total

static func tick(owners: Array[int], buildings: Array[String],
        stocks: Array[Dictionary]) -> void:
    if owners.size() != RULES.MAP_NODE_COUNT             or buildings.size() != RULES.MAP_NODE_COUNT             or stocks.size() != RULES.MAP_NODE_COUNT:
        return
    # Production consumes resources on-site. Mining, refining and military
    # supply production all stop when their local output buffer is full.
    for node in range(RULES.MAP_NODE_COUNT):
        if owners[node] <= 0:
            continue
        var stock: Dictionary = stocks[node]
        match buildings[node]:
            "mine":
                var raw: String = deposit(node)
                if not raw.is_empty():
                    stock[raw] = mini(STORAGE_CAPACITY,
                        int(stock.get(raw, 0)) + MINE_RATE)
            "smelter":
                if int(stock["iron"]) >= 2 and int(stock["steel"]) < STORAGE_CAPACITY:
                    stock["iron"] = int(stock["iron"]) - 2
                    stock["steel"] = int(stock["steel"]) + 1
            "factory":
                if int(stock["steel"]) >= 1 and int(stock["copper"]) >= 1                         and int(stock["supplies"]) < STORAGE_CAPACITY:
                    stock["steel"] = int(stock["steel"]) - 1
                    stock["copper"] = int(stock["copper"]) - 1
                    stock["supplies"] = int(stock["supplies"]) + 1
        stocks[node] = stock

    # Shipping uses a snapshot, so goods traverse at most one link per second.
    # All four resources share the same capacity on each undirected edge.
    var before: Array[Dictionary] = []
    var after: Array[Dictionary] = []
    for stock in stocks:
        before.append(stock.duplicate())
        after.append(stock.duplicate())
    var edge_used: Dictionary = {}
    # Deliver finished goods first, then intermediate and raw resources.
    for resource_value in ["supplies", "steel", "copper", "iron"]:
        var resource: String = str(resource_value)
        for source in range(RULES.MAP_NODE_COUNT):
            if owners[source] <= 0:
                continue
            var available: int = int(before[source].get(resource, 0))
            if available <= 0:
                continue
            var route: Array[int] = _route_to_consumer(
                source, resource, owners, buildings, after)
            if route.size() < 2:
                continue
            var next_node: int = route[1]
            var edge: int = mini(source, next_node) * RULES.MAP_NODE_COUNT                 + maxi(source, next_node)
            var edge_free: int = EDGE_CAPACITY - int(edge_used.get(edge, 0))
            var max_at_next: int = HQ_SUPPLY_CAPACITY                 if buildings[next_node] == "hq" and resource == "supplies"                 else STORAGE_CAPACITY
            var space: int = max_at_next - int(after[next_node].get(resource, 0))
            var moving: int = mini(available, mini(edge_free, space))
            if moving <= 0:
                continue
            after[source][resource] = int(after[source][resource]) - moving
            after[next_node][resource] = int(after[next_node][resource]) + moving
            edge_used[edge] = int(edge_used.get(edge, 0)) + moving
    for node in range(RULES.MAP_NODE_COUNT):
        stocks[node] = after[node]

static func _wants(building: String, resource: String) -> bool:
    return (resource == "iron" and building == "smelter")         or (resource == "copper" and building == "factory")         or (resource == "steel" and building == "factory")         or (resource == "supplies" and building == "hq")

static func _route_to_consumer(source: int, resource: String,
        owners: Array[int], buildings: Array[String],
        stocks: Array[Dictionary]) -> Array[int]:
    var team: int = owners[source]
    var queue: Array[int] = [source]
    var predecessor: Dictionary = {source: -1}
    var head: int = 0
    var destination: int = -1
    while head < queue.size() and destination < 0:
        var current: int = queue[head]
        head += 1
        for neighbor in range(RULES.MAP_NODE_COUNT):
            if owners[neighbor] != team or predecessor.has(neighbor):
                continue
            if not RULES.linked(current, neighbor):
                continue
            predecessor[neighbor] = current
            queue.append(neighbor)
            var limit: int = HQ_SUPPLY_CAPACITY                 if buildings[neighbor] == "hq" and resource == "supplies"                 else STORAGE_CAPACITY
            if _wants(buildings[neighbor], resource)                     and int(stocks[neighbor].get(resource, 0)) < limit:
                destination = neighbor
                break
    if destination < 0:
        return []
    var path: Array[int] = [destination]
    var cursor: int = destination
    while cursor != source:
        cursor = int(predecessor[cursor])
        path.push_front(cursor)
    return path
