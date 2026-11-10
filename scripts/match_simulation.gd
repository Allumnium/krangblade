extends RefCounted
## Pure host simulation. All balance values and command validation live here.
const MAP = preload("res://scripts/map_generator.gd")
const LOBBY = preload("res://scripts/lobby_rules.gd")
const TICK: float = 0.1
const START_CREDITS: float = 100.0
const START_TROOPS: int = 5
const UNIT_COST: float = 20.0
const BASE_INCOME: float = 4.0
const OBJECTIVE_INCOME: float = 2.0
const CENTRAL_INCOME: float = 4.0
const UNIT_HEALTH: float = 10.0
const UNIT_DAMAGE: float = 3.0
const UNIT_SPEED: float = 60.0
const UNIT_CAP: int = 100
const REFUND_RATE: float = 0.1
const CAPTURE_TIME: float = 3.0
const BASE_CAPTURE_TIME: float = 10.0
const SHIFT_SECONDS: float = 30.0
const WARNING_SECONDS: float = 5.0

var map: Dictionary = {}
var players: Dictionary = {}
var units: Dictionary = {}
var owners: Array[int] = []
var capture_team: Array[int] = []
var capture_progress: Array[float] = []
var contested: Array[bool] = []
var dynamic: Array[Vector2i] = []
var pending: Array[Vector2i] = []
var tick: int = 0
var next_unit: int = 1
var shift_at: int = 300
var topology: int = 0
var result: String = ""
var winner: int = 0
var sandbox: bool = false
var rng := RandomNumberGenerator.new()
var links: Array = []
var routes: Dictionary = {}
var occupancy: Dictionary = {}
var command_counts: Dictionary = {}
var fallen_teams: Dictionary = {}

func setup(roster: Dictionary, map_seed: int) -> void:
    map = MAP.generate(roster, map_seed)
    rng.seed = map_seed + 101
    dynamic.assign(map.dynamic)
    links = MAP.adjacency(map, dynamic)
    owners.resize(map.nodes.size())
    owners.fill(0)
    capture_team.resize(owners.size())
    capture_team.fill(0)
    capture_progress.resize(owners.size())
    capture_progress.fill(0.0)
    contested.resize(owners.size())
    contested.fill(false)
    var teams: Dictionary = {}
    for id in LOBBY.ordered_peers(roster):
        var team: int = int(roster[id].team)
        var home: int = int(map.homes[id])
        teams[team] = true
        owners[home] = team
        players[id] = {"name": str(roster[id].name), "team": team, "credits": START_CREDITS,
            "base": home, "rally": home, "auto": false, "reserves": {}, "retreat": false,
            "bot": LOBBY.is_bot(id), "eliminated": false, "refunds": 0.0,
            "income": BASE_INCOME, "objective_income": 0.0, "count": 0}
        for index in range(START_TROOPS):
            _spawn(id, home, 0.0)
    sandbox = teams.size() == 1
    _index_units()

func snapshot() -> Dictionary:
    return {"tick": tick, "players": players.duplicate(true), "units": units.duplicate(true),
        "owners": owners.duplicate(), "capture_team": capture_team.duplicate(),
        "capture_progress": capture_progress.duplicate(), "contested": contested.duplicate(),
        "dynamic": dynamic.duplicate(), "pending": pending.duplicate(), "shift_at": shift_at,
        "topology": topology, "result": result, "winner": winner, "sandbox": sandbox}

func apply_command(id: int, action: String, value: int = 0, extra: int = 0) -> String:
    if not players.has(id) or bool(players[id].eliminated) or not result.is_empty():
        return "Your army is inactive."
    if int(command_counts.get(id, 0)) >= 8:
        return "Too many orders; try again shortly."
    command_counts[id] = int(command_counts.get(id, 0)) + 1
    var player: Dictionary = players[id]
    match action:
        "recruit":
            if value not in [1, 5]:
                return "Recruit one or five troops."
            var reason: String = purchase_reason(id, value)
            if not reason.is_empty():
                return reason
            player.credits -= UNIT_COST * value
            for index in range(value):
                _spawn(id, int(player.base), UNIT_COST)
        "base":
            if not usable_base(id, value):
                return "Choose an uncontested allied base."
            player.base = value
        "rally", "retreat":
            if not valid_node(value):
                return "Choose a map node."
            if action == "retreat" and owners[value] != int(player.team):
                return "Retreat to an allied node."
            player.rally = value
            player.retreat = action == "retreat"
            if action == "retreat":
                for unit in units.values():
                    if int(unit.player) == id and int(unit.to) >= 0 and not bool(unit.reversing):
                        var origin: int = int(unit.node)
                        unit.node = int(unit.to)
                        unit.to = origin
                        unit.progress = 1.0 - float(unit.progress)
                        unit.reversing = true
        "reserve":
            if not valid_node(value) or extra < 0 or extra > UNIT_CAP:
                return "Set entrenchment to 0–100 at a map node."
            player.reserves[value] = extra
        "auto":
            if value not in [0, 1]:
                return "Invalid auto-recruit setting."
            player.auto = value == 1
        _:
            return "Unknown order."
    return ""

func valid_node(node: int) -> bool:
    return node >= 0 and node < owners.size()

func usable_base(id: int, node: int) -> bool:
    return valid_node(node) and map.nodes[node].kind == "base" and owners[node] == int(players[id].team) and not contested[node] and not _hostile_at(node, int(players[id].team))

func purchase_reason(id: int, amount: int) -> String:
    if not usable_base(id, int(players[id].base)):
        return "Recruitment paused: select a safe allied base."
    if int(players[id].count) + amount > UNIT_CAP:
        return "Army limit: %d troops." % UNIT_CAP
    if float(players[id].credits) + 0.00001 < UNIT_COST * amount:
        return "Need %d credits." % int(UNIT_COST * amount)
    return ""

func reserve_for(id: int, node: int) -> int:
    var player: Dictionary = players[id]
    if player.reserves.has(node):
        return int(player.reserves[node])
    match str(map.nodes[node].kind):
        "base": return 2
        "objective", "central": return 1
    return 0

func route_to(target: int) -> Dictionary:
    if not routes.has(target):
        routes[target] = MAP.routing(map, links, target)
    return routes[target]

func path(from: int, target: int) -> Array[int]:
    var result_path: Array[int] = []
    if not valid_node(from) or not valid_node(target):
        return result_path
    var table: Dictionary = route_to(target)
    result_path.append(from)
    while from != target and result_path.size() <= owners.size():
        from = int(table.next[from])
        if from < 0:
            return []
        result_path.append(from)
    return result_path

func take_over(id: int) -> void:
    if players.has(id):
        players[id].bot = true
        players[id].auto = true

func step() -> void:
    if not result.is_empty():
        return
    tick += 1
    command_counts.clear()
    _shift_routes()
    _index_units()
    if tick % 10 == 1:
        _bots()
    _combat()
    _index_units()
    _captures()
    _victory()
    if not result.is_empty():
        return
    _income_and_recruit()
    _move()
    _index_units()

func _spawn(id: int, node: int, paid: float) -> void:
    units[next_unit] = {"id": next_unit, "player": id, "team": int(players[id].team),
        "node": node, "to": -1, "progress": 0.0, "hp": UNIT_HEALTH, "paid": paid,
        "reversing": false, "fighting": false}
    next_unit += 1
    players[id].count += 1

func _index_units() -> void:
    occupancy.clear()
    for player in players.values():
        player.count = 0
    for unit in units.values():
        players[unit.player].count += 1
        if int(unit.to) < 0:
            var node: int = int(unit.node)
            if not occupancy.has(node):
                occupancy[node] = []
            occupancy[node].append(int(unit.id))
    for node in range(owners.size()):
        var teams: Dictionary = _teams_at(node)
        contested[node] = teams.size() > 1 or (not teams.is_empty() and owners[node] != 0 and not teams.has(owners[node]))

func _teams_at(node: int) -> Dictionary:
    var teams: Dictionary = {}
    for id in occupancy.get(node, []):
        var team: int = int(units[id].team)
        if not teams.has(team):
            teams[team] = []
        teams[team].append(id)
    return teams

func _hostile_at(node: int, team: int) -> bool:
    for id in occupancy.get(node, []):
        if int(units[id].team) != team:
            return true
    return false

func _shift_routes() -> void:
    if tick == shift_at - int(WARNING_SECONDS / TICK):
        var candidates: Array[Vector2i] = []
        candidates.assign(map.candidates)
        MAP._shuffle(candidates, rng)
        pending.assign(candidates.slice(0, 4))
        # Ensure every shift changes something even if the RNG picked the same set.
        if pending.all(func(link: Vector2i) -> bool: return dynamic.has(link)):
            pending[0] = candidates[4]
    if tick >= shift_at:
        dynamic.assign(pending)
        pending.clear()
        shift_at += int(SHIFT_SECONDS / TICK)
        topology += 1
        links = MAP.adjacency(map, dynamic)
        routes.clear()

func _combat() -> void:
    var damage: Dictionary = {}
    var edge_groups: Dictionary = {}
    var parents: Dictionary = {}
    for unit in units.values():
        unit.fighting = false
        parents[unit.id] = int(unit.id)
        if int(unit.to) >= 0:
            var key: Vector2i = MAP.edge(int(unit.node), int(unit.to))
            if not edge_groups.has(key):
                edge_groups[key] = []
            edge_groups[key].append(int(unit.id))
    for ids in occupancy.values():
        for index in range(1, ids.size()):
            _join(int(ids[0]), int(ids[index]), parents)
    # Units on each edge form contact clusters. Swept contact prevents crossing
    # between ticks; troops retreating in the same direction can disengage.
    for key in edge_groups:
        var ids: Array = edge_groups[key]
        # Include endpoint defenders in swept contact. Otherwise a defender
        # could depart on the same tick an enemy arrives and pass through it.
        ids.append_array(occupancy.get(key.x, []))
        ids.append_array(occupancy.get(key.y, []))
        var length: float = (map.nodes[key.x].position as Vector2).distance_to(map.nodes[key.y].position)
        var contact: float = UNIT_SPEED * TICK * 2.0 / maxf(length, 1.0) + 0.02
        ids.sort_custom(func(a: int, b: int) -> bool: return _edge_position(units[a], key) < _edge_position(units[b], key))
        for index in range(1, ids.size()):
            if _edge_position(units[ids[index]], key) - _edge_position(units[ids[index - 1]], key) <= contact:
                _join(int(ids[index - 1]), int(ids[index]), parents)
    # Merge contacts before damage so a battle spanning a junction counts
    # every troop once, rather than applying node and edge damage twice.
    var battles: Dictionary = {}
    for id in units:
        var root_id: int = _root(int(id), parents)
        if not battles.has(root_id):
            battles[root_id] = {}
        var team: int = int(units[id].team)
        if not battles[root_id].has(team):
            battles[root_id][team] = []
        battles[root_id][team].append(id)
    for teams in battles.values():
        _battle(teams, damage)
    for id in damage:
        units[id].hp -= float(damage[id])
    for id in units.keys():
        var unit: Dictionary = units[id]
        if float(unit.hp) <= 0.00001:
            var refund: float = float(unit.paid) * REFUND_RATE
            players[unit.player].credits += refund
            players[unit.player].refunds += refund
            units.erase(id)

func _root(id: int, parents: Dictionary) -> int:
    while int(parents[id]) != id:
        parents[id] = parents[parents[id]]
        id = int(parents[id])
    return id

func _join(a: int, b: int, parents: Dictionary) -> void:
    var first: int = _root(a, parents)
    var second: int = _root(b, parents)
    if first != second:
        parents[second] = first

func _edge_position(unit: Dictionary, key: Vector2i) -> float:
    return float(unit.progress) if int(unit.node) == key.x else 1.0 - float(unit.progress)

func _battle(teams: Dictionary, damage: Dictionary) -> void:
    if teams.size() < 2:
        return
    for team in teams:
        for id in teams[team]:
            units[id].fighting = true
        var dealt: float = float(teams[team].size()) * UNIT_DAMAGE * TICK / float(teams.size() - 1)
        for enemy in teams:
            if enemy == team:
                continue
            # Spread damage evenly across the opposing army. Health persists
            # between battles, and all teams deal their damage before deaths.
            var share: float = dealt / float(teams[enemy].size())
            for id in teams[enemy]:
                damage[id] = float(damage.get(id, 0.0)) + share

func _captures() -> void:
    var previous_bases: Dictionary = {}
    var lost_bases: Dictionary = {}
    fallen_teams.clear()
    for node in range(owners.size()):
        if map.nodes[node].kind == "base" and owners[node] != 0:
            previous_bases[owners[node]] = int(previous_bases.get(owners[node], 0)) + 1
    for node in range(owners.size()):
        var teams: Dictionary = _teams_at(node)
        if teams.is_empty():
            capture_progress[node] = 0.0
            capture_team[node] = 0
            continue
        if teams.size() > 1:
            continue
        var team: int = int(teams.keys()[0])
        if owners[node] == team:
            capture_progress[node] = 0.0
            capture_team[node] = 0
            continue
        if capture_team[node] != team:
            capture_team[node] = team
            capture_progress[node] = 0.0
        capture_progress[node] += TICK
        var duration: float = BASE_CAPTURE_TIME if map.nodes[node].kind == "base" else CAPTURE_TIME
        if capture_progress[node] + 0.00001 >= duration:
            if map.nodes[node].kind == "base" and owners[node] != 0:
                lost_bases[owners[node]] = int(lost_bases.get(owners[node], 0)) + 1
            owners[node] = team
            capture_progress[node] = 0.0
            capture_team[node] = 0
            contested[node] = false
    # Losing every base held at the start of this tick is elimination even
    # when another base was captured simultaneously; mutual final losses draw.
    for team in lost_bases:
        if int(lost_bases[team]) == int(previous_bases[team]):
            fallen_teams[team] = true

func _income_and_recruit() -> void:
    var teammates: Dictionary = {}
    var objective_total: Dictionary = {}
    for player in players.values():
        if not bool(player.eliminated):
            teammates[player.team] = int(teammates.get(player.team, 0)) + 1
    for node in range(owners.size()):
        var kind: String = str(map.nodes[node].kind)
        if kind not in ["objective", "central"] or owners[node] == 0 or contested[node]:
            continue
        var rate: float = CENTRAL_INCOME if kind == "central" else OBJECTIVE_INCOME
        objective_total[owners[node]] = float(objective_total.get(owners[node], 0.0)) + rate
    for id in players:
        var player: Dictionary = players[id]
        if bool(player.eliminated):
            player.income = 0.0
            player.objective_income = 0.0
            continue
        player.objective_income = float(objective_total.get(player.team, 0.0)) / float(teammates[player.team])
        player.income = BASE_INCOME + float(player.objective_income)
        player.credits += float(player.income) * TICK
        if not usable_base(id, int(player.base)):
            for node in range(owners.size()):
                if usable_base(id, node):
                    player.base = node
                    break
        if bool(player.auto) and purchase_reason(id, 1).is_empty():
            player.credits -= UNIT_COST
            _spawn(id, int(player.base), UNIT_COST)

func _move() -> void:
    var dispatched: Dictionary = {}
    for unit in units.values():
        var player: Dictionary = players[unit.player]
        if bool(unit.fighting) and (not bool(player.retreat) or not _retreat_clear(unit)):
            continue
        if int(unit.to) >= 0:
            var length: float = (map.nodes[unit.node].position as Vector2).distance_to(map.nodes[unit.to].position)
            unit.progress += UNIT_SPEED * TICK / maxf(length, 1.0)
            if float(unit.progress) >= 1.0:
                unit.node = int(unit.to)
                unit.to = -1
                unit.progress = 0.0
                unit.reversing = false
            continue
        var node: int = int(unit.node)
        var target: int = int(player.rally)
        if node == target:
            continue
        if not bool(player.retreat) and (owners[node] != int(unit.team) or _hostile_at(node, int(unit.team))):
            continue
        var key := Vector2i(int(unit.player), node)
        if not dispatched.has(key):
            var count: int = 0
            for id in occupancy.get(node, []):
                if int(units[id].player) == int(unit.player):
                    count += 1
            dispatched[key] = count - (0 if bool(player.retreat) else reserve_for(int(unit.player), node))
        if int(dispatched[key]) <= 0:
            continue
        var next: int = int(route_to(target).next[node])
        if next >= 0:
            unit.to = next
            unit.progress = 0.0
            dispatched[key] = int(dispatched[key]) - 1

func _retreat_clear(unit: Dictionary) -> bool:
    if int(unit.to) < 0:
        var next: int = int(route_to(int(players[unit.player].rally)).next[unit.node])
        return next >= 0 and not _hostile_at(next, int(unit.team))
    var key: Vector2i = MAP.edge(int(unit.node), int(unit.to))
    var position: float = _edge_position(unit, key)
    var direction: float = 1.0 if int(unit.to) == key.y else -1.0
    for enemy in units.values():
        if int(enemy.team) == int(unit.team) or int(enemy.to) < 0:
            continue
        if MAP.edge(int(enemy.node), int(enemy.to)) != key:
            continue
        # Withdraw away from contact, never march through a hostile army.
        if (_edge_position(enemy, key) - position) * direction > 0.00001:
            return false
    return true

func _victory() -> void:
    var alive: Dictionary = {}
    for node in range(owners.size()):
        if map.nodes[node].kind == "base" and fallen_teams.has(owners[node]):
            owners[node] = 0
        if map.nodes[node].kind == "base" and owners[node] != 0:
            alive[owners[node]] = true
    for player in players.values():
        if not alive.has(player.team):
            player.eliminated = true
            player.auto = false
            player.count = 0
            player.income = 0.0
            player.objective_income = 0.0
    for id in units.keys():
        if bool(players[units[id].player].eliminated):
            units.erase(id)
    if not sandbox and alive.size() <= 1:
        winner = int(alive.keys()[0]) if alive.size() == 1 else 0
        result = "Team %d wins!" % winner if winner > 0 else "Draw — all bases fell."

func _bots() -> void:
    for id in players:
        var player: Dictionary = players[id]
        if not bool(player.bot) or bool(player.eliminated):
            continue
        apply_command(id, "auto", 1)
        var origin: int = int(player.base)
        # Use the leading mobile unit as the front; this avoids pulling the
        # whole army backward toward newly lost objectives near its base.
        var front: int = origin
        var furthest: float = -1.0
        var home_table: Dictionary = route_to(origin)
        for unit in units.values():
            if int(unit.player) == int(id) and float(home_table.distance[unit.node]) > furthest:
                front = int(unit.node)
                furthest = float(home_table.distance[unit.node])
        var best: int = -1
        var best_distance: float = INF
        for node in range(owners.size()):
            if map.nodes[node].kind not in ["objective", "central"] or owners[node] == int(player.team):
                continue
            var distance: float = float(route_to(node).distance[front])
            if distance < best_distance:
                best = node
                best_distance = distance
        if best < 0:
            for node in range(owners.size()):
                if map.nodes[node].kind == "base" and owners[node] != int(player.team):
                    var distance: float = float(route_to(node).distance[front])
                    if distance < best_distance:
                        best = node
                        best_distance = distance
        if best >= 0:
            apply_command(id, "rally", best)
