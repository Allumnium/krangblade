extends RefCounted
## World-space graph. Only the host generates it; clients receive the complete map.
const LOBBY = preload("res://scripts/lobby_rules.gd")
const NODE_COUNT: int = 129
const BRANCH_SIZE: int = 13
const GATE_START: int = 104
const INNER_START: int = 112
const CENTER: int = 128

static func edge(a: int, b: int) -> Vector2i:
    return Vector2i(mini(a, b), maxi(a, b))

static func generate(roster: Dictionary, map_seed: int) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = map_seed
    var nodes: Array[Dictionary] = []
    var edges: Array[Vector2i] = []
    for branch in range(8):
        var angle: float = float(branch) * TAU / 8.0 - PI * 0.5
        var axis := Vector2.from_angle(angle)
        var side := axis.orthogonal()
        var start: int = nodes.size()
        nodes.append(_node(start, axis * 1240.0, "node", branch))
        var previous: int = start
        for diamond in range(4):
            var radius: float = 1140.0 - float(diamond) * 200.0
            var left: int = nodes.size()
            nodes.append(_node(left, axis * radius + side * 70.0, "node", branch))
            nodes.append(_node(left + 1, axis * radius - side * 70.0, "node", branch))
            var kind: String = "objective" if diamond in [1, 3] else "node"
            nodes.append(_node(left + 2, axis * (radius - 100.0), kind, branch))
            edges.append(edge(previous, left))
            edges.append(edge(previous, left + 1))
            edges.append(edge(left, left + 2))
            edges.append(edge(left + 1, left + 2))
            previous = left + 2
    for index in range(8):
        nodes.append(_node(nodes.size(), Vector2.from_angle(float(index) * TAU / 8.0 - PI * 0.5) * 280.0, "gate", -1))
        edges.append(edge(index * BRANCH_SIZE + 12, GATE_START + index))
        edges.append(edge(GATE_START + index, INNER_START + index * 2))
    for index in range(16):
        var angle: float = float(index) * TAU / 16.0 - PI * 0.5 + rng.randf_range(-0.055, 0.055)
        var kind: String = "objective" if index in [2, 6, 10, 14] else "node"
        nodes.append(_node(nodes.size(), Vector2.from_angle(angle) * rng.randf_range(150.0, 175.0), kind, -1))
        edges.append(edge(INNER_START + index, INNER_START + (index + 1) % 16))
        if index % 4 == 0:
            edges.append(edge(INNER_START + index, CENTER))
    nodes.append(_node(CENTER, Vector2.ZERO, "central", -1))
    var candidates: Array[Vector2i] = []
    for a in range(16):
        for b in range(a + 1, 16):
            var separation: int = mini(b - a, 16 - (b - a))
            if separation >= 3 and separation <= 7:
                candidates.append(edge(INNER_START + a, INNER_START + b))
    _shuffle(candidates, rng)
    for index in range(6):
        edges.append(candidates.pop_back())
    var dynamic: Array[Vector2i] = []
    for index in range(4):
        dynamic.append(candidates[index])
    var homes: Dictionary = {}
    var peers: Array[int] = LOBBY.ordered_peers(roster)
    for seat in range(peers.size()):
        var branch: int = floori(float(seat) * 8.0 / float(peers.size()))
        var home: int = branch * BRANCH_SIZE
        nodes[home]["kind"] = "base"
        homes[peers[seat]] = home
    return {"seed": map_seed, "nodes": nodes, "edges": edges,
        "candidates": candidates, "dynamic": dynamic, "homes": homes}

static func _node(id: int, position: Vector2, kind: String, branch: int) -> Dictionary:
    return {"id": id, "position": position, "kind": kind, "branch": branch}

static func _shuffle(items: Array[Vector2i], rng: RandomNumberGenerator) -> void:
    for index in range(items.size() - 1, 0, -1):
        var other: int = rng.randi_range(0, index)
        var saved: Vector2i = items[index]
        items[index] = items[other]
        items[other] = saved

static func adjacency(map: Dictionary, dynamic: Array) -> Array:
    var result: Array = []
    for index in range(map.nodes.size()):
        result.append([])
    for item in map.edges + dynamic:
        var link: Vector2i = item
        result[link.x].append(link.y)
        result[link.y].append(link.x)
    return result

static func routing(map: Dictionary, links: Array, target: int) -> Dictionary:
    # Reverse Dijkstra: one table serves every troop moving toward this target.
    var distance: Array[float] = []
    var next: Array[int] = []
    var visited: Array[bool] = []
    distance.resize(map.nodes.size())
    distance.fill(INF)
    next.resize(distance.size())
    next.fill(-1)
    visited.resize(distance.size())
    visited.fill(false)
    distance[target] = 0.0
    for iteration in range(distance.size()):
        var best: int = -1
        for index in range(distance.size()):
            if not visited[index] and (best == -1 or distance[index] < distance[best]):
                best = index
        if best == -1 or is_inf(distance[best]):
            break
        visited[best] = true
        for neighbor in links[best]:
            var length: float = (map.nodes[best].position as Vector2).distance_to(map.nodes[neighbor].position)
            if distance[best] + length < distance[neighbor]:
                distance[neighbor] = distance[best] + length
                next[neighbor] = best
    return {"distance": distance, "next": next}
