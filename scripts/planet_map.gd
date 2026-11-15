extends RefCounted
## Seeded connected planet graph, independent of the rendering layer.
const COUNT: int = 32
const SIZE := Vector2(2200, 1500)

const CLUSTER_COUNT: int = 4

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
    # First connect each cluster internally, then bridge the closest cluster pairs.
    for group in groups:
        var connected: Array = [group[0]]
        while connected.size() < group.size():
            var pair: Array = _closest_pair(points, connected, group, connected)
            edges.append(pair)
            connected.append(pair[1] if connected.has(pair[0]) else pair[0])
    var joined: Array = [0]
    while joined.size() < CLUSTER_COUNT:
        var best_edge: Array = []
        var next_group: int = -1
        var best_distance: float = INF
        for i in joined:
            for j in range(CLUSTER_COUNT):
                if joined.has(j):
                    continue
                var pair: Array = _closest_pair(points, groups[i], groups[j], [])
                var distance: float = points[pair[0]].distance_to(points[pair[1]])
                if distance < best_distance:
                    best_distance = distance
                    best_edge = pair
                    next_group = j
        edges.append(best_edge)
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
    # Add clear distance-weighted loops, limiting redundant links.
    for pair in candidates:
        if not blocked(points[pair[0]], points[pair[1]], fields) and rng.randf() < 0.8:
            edges.append(pair)
    return {"seed": seed_value, "points": points, "edges": edges, "clusters": clusters, "fields": fields}

static func blocked(a: Vector2, b: Vector2, fields: Array) -> bool:
    for field in fields:
        var center: Vector2 = field["position"]
        if Geometry2D.get_closest_point_to_segment(center, a, b).distance_to(center) <= float(field["radius"]):
            return true
    return false

static func _closest_pair(points: Array[Vector2], a: Array, b: Array, excluded: Array) -> Array:
    var best: float = INF
    var pair: Array = []
    for i in a:
        for j in b:
            if i == j or excluded.has(j):
                continue
            var distance: float = points[i].distance_to(points[j])
            if distance < best:
                best = distance
                pair = [mini(i, j), maxi(i, j)]
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
