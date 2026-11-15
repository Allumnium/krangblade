extends RefCounted
## Seeded connected planet graph, independent of the rendering layer.
const COUNT: int = 17
const SIZE := Vector2(1000, 700)

static func generate(seed_value: int) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var points: Array[Vector2] = []
    for i in range(COUNT):
        var candidate := Vector2.ZERO
        var best_distance: float = -1.0
        for attempt in range(100):
            var p := Vector2(rng.randf_range(55, SIZE.x - 55), rng.randf_range(55, SIZE.y - 55))
            var nearest: float = SIZE.length()
            for other in points:
                nearest = minf(nearest, p.distance_to(other))
            if nearest > best_distance:
                candidate = p
                best_distance = nearest
            if nearest >= 120.0:
                break
        points.append(candidate)
    # A minimum spanning tree guarantees connectivity; extra short routes add loops.
    var edges: Array = []
    var connected: Array[int] = [0]
    while connected.size() < COUNT:
        var a: int = -1
        var b: int = -1
        var distance: float = INF
        for i in connected:
            for j in range(COUNT):
                if connected.has(j):
                    continue
                var d: float = points[i].distance_to(points[j])
                if d < distance:
                    a = i
                    b = j
                    distance = d
        edges.append([mini(a, b), maxi(a, b)])
        connected.append(b)
    for i in range(COUNT):
        for j in range(i + 1, COUNT):
            if not edges.has([i, j]) and points[i].distance_to(points[j]) < 225.0:
                if rng.randf() < 0.75:
                    edges.append([i, j])
    return {"seed": seed_value, "points": points, "edges": edges}

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
