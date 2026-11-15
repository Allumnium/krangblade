extends RefCounted
## Seeded connected planet graph, independent of the rendering layer.
const COUNT: int = 32
const SIZE := Vector2(2200, 1500)

const CLUSTER_COUNT: int = 4
const TRAVEL_SPEED: float = 95.0
const LONGEST_LINK_YEARS: float = 100.0
const MAX_CONNECTIONS: int = 3
const MAX_JUNCTIONS: int = 6
const EXTRA_LINK_CHANCE: float = 0.35

static func generate(seed_value: int) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var centers: Array[Vector2] = [Vector2(480, 380), Vector2(1720, 380), Vector2(480, 1120), Vector2(1720, 1120)]
    var groups: Array = []
    for i in range(CLUSTER_COUNT):
        centers[i] += Vector2(rng.randf_range(-65, 65), rng.randf_range(-35, 35))
        groups.append([])
    var points: Array[Vector2] = []
    var clusters: Array[int] = []
    # Interleave indices so the first eight homeworlds are spread across clusters.
    for i in range(COUNT):
        var group: int = i % CLUSTER_COUNT
        var candidate := Vector2.ZERO
        var best: float = -1.0
        for attempt in range(160):
            var offset := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
            if offset.length_squared() > 1.0:
                continue
            var p: Vector2 = centers[group] + offset * Vector2(340, 285)
            var nearest: float = SIZE.length()
            for index in groups[group]:
                nearest = minf(nearest, p.distance_to(points[index]))
            if nearest > best:
                candidate = p
                best = nearest
            if nearest >= 190.0:
                break
        points.append(candidate)
        clusters.append(group)
        groups[group].append(i)
    var edges: Array = []
    var degrees: Array[int] = []
    degrees.resize(COUNT)
    degrees.fill(0)
    var junctions: int = 0
    # Grow each local tree by distance, with at most one local junction.
    # Prefer extending a chain over branching; avoid linking two home slots
    # locally so every potential starting world has a neutral neighbor.
    for group in groups:
        var connected: Array = [group[0]]
        var local_junctions: int = 0
        while connected.size() < group.size():
            var pair: Array = _closest_pair(points, connected, group, connected, degrees, 1 - local_junctions, true)
            var added: int = _new_junctions(pair, degrees)
            local_junctions += added
            junctions += added
            _add_edge(edges, degrees, pair)
            connected.append(pair[1] if connected.has(pair[0]) else pair[0])
    var joined: Array = [0]
    while joined.size() < CLUSTER_COUNT:
        var best_edge: Array = []
        var next_group: int = -1
        var best_score: float = INF
        for i in joined:
            for j in range(CLUSTER_COUNT):
                if joined.has(j):
                    continue
                var pair: Array = _closest_pair(points, groups[i], groups[j], [], degrees, MAX_JUNCTIONS - junctions)
                if pair.is_empty():
                    continue
                var score: float = _edge_score(points, pair, degrees)
                if score < best_score:
                    best_score = score
                    best_edge = pair
                    next_group = j
        junctions += _new_junctions(best_edge, degrees)
        _add_edge(edges, degrees, best_edge)
        joined.append(next_group)
    # Protect the connected backbone. Fields occupy potential shortcuts, so
    # ordinary routes never cross a field and the galaxy remains connected.
    var candidates: Array = []
    for i in range(COUNT):
        for j in range(i + 1, COUNT):
            var distance: float = points[i].distance_to(points[j])
            var limit: float = 410.0 if clusters[i] == clusters[j] else 850.0
            if distance <= limit and not edges.has([i, j]):
                candidates.append([i, j])
    var fields: Array = []
    for pair in candidates:
        if fields.size() >= 10:
            break
        var center: Vector2 = (points[pair[0]] + points[pair[1]]) * 0.5
        var radius: float = rng.randf_range(38.0, 62.0)
        var safe: bool = true
        var anchor: int = -1
        var nearest: float = INF
        for i in range(COUNT):
            var distance: float = center.distance_to(points[i])
            if distance < radius + 45.0:
                safe = false
            if distance < nearest:
                nearest = distance
                anchor = i
        for edge in edges:
            if Geometry2D.get_closest_point_to_segment(center, points[edge[0]], points[edge[1]]).distance_to(center) <= radius:
                safe = false
        for field in fields:
            if center.distance_to(field["position"]) < radius + float(field["radius"]) + 30.0:
                safe = false
            if Geometry2D.get_closest_point_to_segment(field["position"], points[anchor], center).distance_to(field["position"]) <= float(field["radius"]):
                safe = false
            if Geometry2D.get_closest_point_to_segment(center, points[int(field["anchor"])], field["position"]).distance_to(center) <= radius:
                safe = false
        if safe:
            fields.append({"position": center, "radius": radius, "anchor": anchor,
                "Metals": rng.randf_range(1.0, 2.0), "Crystals": rng.randf_range(1.0, 2.0)})
    # At most one optional local shortcut, on some maps only. Never
    # violate the degree/junction limits or cross an asteroid field.
    if rng.randf() < EXTRA_LINK_CHANCE:
        var best_extra: Array = []
        var best_extra_score: float = INF
        for pair in candidates:
            if clusters[pair[0]] != clusters[pair[1]]:
                continue
            if not _edge_allowed(pair, degrees, MAX_JUNCTIONS - junctions):
                continue
            if blocked(points[pair[0]], points[pair[1]], fields):
                continue
            var score: float = _edge_score(points, pair, degrees)
            if score < best_extra_score:
                best_extra_score = score
                best_extra = pair
        if not best_extra.is_empty():
            _add_edge(edges, degrees, best_extra)
    # Preserve the topology and obstacle geometry while scaling distances so
    # the longest direct route takes 100 years at the baseline ship speed.
    var longest: float = 0.0
    for edge in edges:
        longest = maxf(longest, points[edge[0]].distance_to(points[edge[1]]))
    var distance_scale: float = LONGEST_LINK_YEARS * TRAVEL_SPEED / maxf(longest, 1.0)
    for i in range(points.size()):
        points[i] *= distance_scale
    for field in fields:
        field["position"] = (field["position"] as Vector2) * distance_scale
        field["radius"] = float(field["radius"]) * distance_scale
    return {"seed": seed_value, "points": points, "edges": edges, "clusters": clusters, "fields": fields, "size": SIZE * distance_scale}

static func blocked(a: Vector2, b: Vector2, fields: Array) -> bool:
    for field in fields:
        var center: Vector2 = field["position"]
        if Geometry2D.get_closest_point_to_segment(center, a, b).distance_to(center) <= float(field["radius"]):
            return true
    return false

static func _new_junctions(pair: Array, degrees: Array[int]) -> int:
    return int(degrees[pair[0]] == 2) + int(degrees[pair[1]] == 2)

static func _edge_allowed(pair: Array, degrees: Array[int], budget: int) -> bool:
    return degrees[pair[0]] < MAX_CONNECTIONS and degrees[pair[1]] < MAX_CONNECTIONS and _new_junctions(pair, degrees) <= budget

static func _edge_score(points: Array[Vector2], pair: Array, degrees: Array[int]) -> float:
    return points[pair[0]].distance_to(points[pair[1]]) * (1.0 + 0.35 * _new_junctions(pair, degrees))

static func _add_edge(edges: Array, degrees: Array[int], pair: Array) -> void:
    edges.append(pair)
    degrees[pair[0]] += 1
    degrees[pair[1]] += 1

static func _closest_pair(points: Array[Vector2], a: Array, b: Array, excluded: Array, degrees: Array[int], budget: int, avoid_home_pair: bool = false) -> Array:
    var best: float = INF
    var pair: Array = []
    for i in a:
        for j in b:
            if i == j or excluded.has(j) or (avoid_home_pair and i < 8 and j < 8):
                continue
            var candidate: Array = [mini(i, j), maxi(i, j)]
            if not _edge_allowed(candidate, degrees, budget):
                continue
            var score: float = _edge_score(points, candidate, degrees)
            if score < best:
                best = score
                pair = candidate
    return pair

static func linked(map_data: Dictionary, a: int, b: int) -> bool:
    return (map_data.get("edges", []) as Array).has([mini(a, b), maxi(a, b)])

static func path(map_data: Dictionary, planet_teams: Array[int], team: int, start: int, goal: int) -> Array[int]:
    if start < 0 or goal < 0 or start >= COUNT or goal >= COUNT:
        return []
    if planet_teams[start] != team or planet_teams[goal] != team:
        return []
    var points: Array = map_data["points"]
    var distances: Dictionary = {start: 0.0}
    var previous: Dictionary = {}
    var open: Array[int] = [start]
    var visited: Dictionary = {}
    while not open.is_empty():
        var current: int = open[0]
        for i in open:
            if float(distances[i]) < float(distances[current]):
                current = i
        open.erase(current)
        if current == goal:
            var result: Array[int] = [goal]
            while current != start:
                current = int(previous[current])
                result.push_front(current)
            return result
        visited[current] = true
        for i in range(COUNT):
            if visited.has(i) or planet_teams[i] != team or not linked(map_data, current, i):
                continue
            var distance: float = float(distances[current]) + (points[current] as Vector2).distance_to(points[i])
            if distance < float(distances.get(i, INF)):
                distances[i] = distance
                previous[i] = current
                if not open.has(i):
                    open.append(i)
    return []

static func route_length(map_data: Dictionary, route: Array[int]) -> float:
    if route.is_empty():
        return INF
    var points: Array = map_data["points"]
    var length: float = 0.0
    for i in range(1, route.size()):
        length += (points[route[i - 1]] as Vector2).distance_to(points[route[i]])
    return length
