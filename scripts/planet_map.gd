extends RefCounted
## Seeded connected planet graph, independent of the rendering layer.
const SIZE := Vector2(2200, 1500)

const TRAVEL_SPEED: float = 95.0
const LONGEST_LINK_YEARS: float = 100.0
const MAX_CONNECTIONS: int = 3
const EXTRA_LINK_CHANCE: float = 0.35
const ANTIMATTER := "Raw antimatter"
const LAYOUTS: Array[String] = ["Clustered", "Radial", "Grid", "Scramble"]
const DEFAULT_LAYOUT: String = "Clustered"
const LAYOUT_DESCRIPTIONS = {
	"Clustered": "Local clusters connected by sparse bridges.",
	"Radial": "Outer homeworlds with inward spokes and a connected inner ring.",
	"Grid": "Regular clusters linked in rows and columns, with alternate routes.",
	"Scramble": "Irregularly scattered clusters with varied bridge connections."
}

static func generate(seed_value: int, player_count: int = 3, layout: String = DEFAULT_LAYOUT) -> Dictionary:
	if not LAYOUTS.has(layout):
		layout = DEFAULT_LAYOUT
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	player_count = clampi(player_count, 1, 8)
	var cluster_count: int = player_count * 3
	var columns: int = ceili(sqrt(float(cluster_count)))
	var rows: int = ceili(float(cluster_count) / columns)
	var bounds := Vector2(columns * 1250.0, rows * 1050.0)
	var centers: Array[Vector2] = []
	var groups: Array = []
	var sizes: Array[int] = []
	# Choose home clusters spread over the grid, then assign the remaining ones.
	var slots: Array[int] = []
	for i in range(cluster_count):
		slots.append(i)
	for i in range(player_count):
		var pick: int = i * 3
		var slot: int = slots[pick]
		slots[pick] = slots[i]
		slots[i] = slot
	var radial_inner: float = maxf(950.0, float(player_count) * 1250.0 / TAU)
	var radial_extent: float = radial_inner + 2500.0 + 625.0
	if layout == "Radial":
		bounds = Vector2.ONE * radial_extent * 2.0
	for i in range(cluster_count):
		var slot: int = slots[i]
		var center := Vector2(625.0 + float(slot % columns) * 1250.0, 525.0 + floorf(float(slot) / columns) * 1050.0)
		var offset := Vector2(rng.randf_range(-90, 90), rng.randf_range(-70, 70))
		if layout == "Radial":
			var ring: int = floori(float(i) / float(player_count))
			var angle: float = TAU * float(i % player_count) / float(player_count) - PI * 0.5
			center = bounds * 0.5 + Vector2.from_angle(angle) * (radial_inner + float(2 - ring) * 1250.0)
		elif layout == "Grid":
			offset *= 0.12
		elif layout == "Scramble":
			offset *= 3.0
		centers.append(center + offset)
		groups.append([])
		sizes.append(6 if i < player_count else clampi(roundi(rng.randfn(6.0, 1.5)), 3, 9))
	if layout == "Radial":
		# Tight frame for small player counts; leave room for local systems.
		var low: Vector2 = centers[0]
		var high: Vector2 = centers[0]
		for center in centers:
			low = low.min(center)
			high = high.max(center)
		bounds = high - low + Vector2(1250.0, 1050.0)
		for i in range(centers.size()):
			centers[i] += Vector2(625.0, 525.0) - low
	var points: Array[Vector2] = []
	var clusters: Array[int] = []
	# Indices 0..player_count-1 remain the ordered player homeworlds.
	for group in range(player_count):
		points.append(centers[group])
		clusters.append(group)
		groups[group].append(points.size() - 1)
	for group in range(cluster_count):
		while groups[group].size() < sizes[group]:
			if layout == "Grid":
				var offsets: Array[Vector2] = [Vector2.ZERO, Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1)]
				var position: Vector2 = centers[group] + offsets[groups[group].size()] * 220.0
				points.append(position)
				clusters.append(group)
				groups[group].append(points.size() - 1)
				continue
			var candidate := centers[group]
			var best: float = -1.0
			for attempt in range(160):
				var offset := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
				if offset.length_squared() > 1.0:
					continue
				var p: Vector2 = centers[group] + offset * Vector2(340, 285)
				var nearest: float = bounds.length()
				for index in groups[group]:
					nearest = minf(nearest, p.distance_to(points[index]))
				if nearest > best:
					candidate = p
					best = nearest
				if nearest >= 190.0:
					break
			points.append(candidate)
			clusters.append(group)
			groups[group].append(points.size() - 1)
	var count: int = points.size()
	var max_junctions: int = maxi(1, floori(float(count) * 0.18))
	var edges: Array = []
	var degrees: Array[int] = []
	degrees.resize(count)
	degrees.fill(0)
	var junctions: int = 0
	# Grow each local tree by distance, with at most one local junction.
	# Prefer extending a chain over branching; avoid linking two home slots
	# locally so every potential starting world has a neutral neighbor.
	for group in groups:
		var connected: Array = [group[0]]
		var local_junctions: int = 0
		while connected.size() < group.size():
			var local_budget: int = 0 if layout in ["Radial", "Grid"] else 1 - local_junctions
			var pair: Array = _closest_pair(points, connected, group, connected, degrees, mini(local_budget, max_junctions - junctions))
			var added: int = _new_junctions(pair, degrees)
			local_junctions += added
			junctions += added
			_add_edge(edges, degrees, pair)
			connected.append(pair[1] if connected.has(pair[0]) else pair[0])
	if layout in ["Radial", "Grid"]:
		var bridges: Array = []
		var optional: Array = []
		if layout == "Radial":
			# One inward spoke per home cluster and a connected inner chain.
			for i in range(player_count):
				bridges.append([i, i + player_count])
				bridges.append([i + player_count, i + 2 * player_count])
			for i in range(player_count - 1):
				bridges.append([i + 2 * player_count, i + 2 * player_count + 1])
			if player_count > 2:
				optional.append([2 * player_count, cluster_count - 1])
		else:
			# Horizontal rows plus a vertical spine form the connected backbone.
			for slot in range(cluster_count):
				if slot % columns > 0:
					bridges.append([slots.find(slot - 1), slots.find(slot)])
				if slot >= columns:
					var pair: Array = [slots.find(slot - columns), slots.find(slot)]
					if slot % columns == 0:
						bridges.append(pair)
					else:
						optional.append(pair)
		for bridge in bridges + optional:
			var pair: Array = _closest_pair(points, groups[bridge[0]], groups[bridge[1]], [], degrees, max_junctions - junctions)
			if pair.is_empty():
				# Optional loops are skipped when the junction budget is exhausted.
				# Required bridges have at most three per path cluster and reserve
				# enough junctions by keeping the local trees unbranched.
				continue
			junctions += _new_junctions(pair, degrees)
			_add_edge(edges, degrees, pair)
	else:
		var joined: Array = [0]
		while joined.size() < cluster_count:
			var best_edge: Array = []
			var next_group: int = -1
			var best_score: float = INF
			for i in joined:
				for j in range(cluster_count):
					if joined.has(j):
						continue
					var pair: Array = _closest_pair(points, groups[i], groups[j], [], degrees, max_junctions - junctions)
					if pair.is_empty():
						continue
					var score: float = _edge_score(points, pair, degrees)
					if layout == "Scramble":
						# Stable per-cluster-pair weighting, not random on each iteration.
						var mix: int = posmod(seed_value % 10007 + mini(i, j) * 7919 + maxi(i, j) * 31013, 10007)
						score *= 0.65 + 0.7 * float(mix) / 10006.0
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
	for i in range(count):
		for j in range(i + 1, count):
			var distance: float = points[i].distance_to(points[j])
			var limit: float = 410.0 if clusters[i] == clusters[j] else 850.0
			if distance <= limit and not edges.has([i, j]):
				candidates.append([i, j])
	var fields: Array = []
	for pair in candidates:
		if fields.size() >= cluster_count * 2:
			break
		var center: Vector2 = (points[pair[0]] + points[pair[1]]) * 0.5
		var radius: float = rng.randf_range(32.0, 92.0)
		var safe: bool = true
		var anchor: int = -1
		var nearest: float = INF
		for i in range(count):
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
			if not _edge_allowed(pair, degrees, max_junctions - junctions):
				continue
			if degrees.count(1) - int(degrees[pair[0]] == 1) - int(degrees[pair[1]] == 1) < 2:
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
		_populate_field(field, rng)
	# Reclassify the innermost obstacle fields after generation so the
	# existing safe lane geometry, access points and seed remain unchanged.
	var inner: Array = fields.duplicate()
	var galaxy_center: Vector2 = bounds * distance_scale * 0.5
	inner.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["position"] as Vector2).distance_squared_to(galaxy_center) < (b["position"] as Vector2).distance_squared_to(galaxy_center))
	for i in range(mini(inner.size(), 1 if player_count <= 2 else 2)):
		var field: Dictionary = inner[i]
		field["antimatter"] = true
		field["Metals"] = 0.0
		field["Crystals"] = 0.0
		field[ANTIMATTER] = 1.0
		for chunk in field["chunks"]:
			chunk["resource"] = ANTIMATTER
	return {"seed": seed_value, "layout": layout, "names": system_names(seed_value, points.size()), "points": points, "edges": edges, "clusters": clusters, "fields": fields, "size": bounds * distance_scale, "cluster_sizes": sizes, "player_count": player_count, "max_junctions": max_junctions}

static func system_names(seed_value: int, count: int) -> Array[String]:
	var prefixes := ["Astra", "Vey", "Kor", "Nyx", "Sol", "Tha", "Zer", "Eri", "Vor", "Ly", "Or", "Kael", "Nex", "Quor", "Vel", "Syr", "Ae", "Tal", "Iri", "Xan", "Dra", "Cyr", "Mer", "Rhy"]
	var suffixes := ["ion", "aris", "eth", "ora", "axis", "eon", "ara", "os", "ium", "aris", "una", "ath", "yra", "el", "on", "is", "eus", "arae", "ex", "ova"]
	var pool: Array[String] = []
	for prefix in prefixes:
		for suffix in suffixes:
			var name: String = prefix + suffix
			if not pool.has(name):
				pool.append(name)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 81173
	var names: Array[String] = []
	for i in range(count):
		var pick: int = rng.randi_range(0, pool.size() - 1)
		names.append(pool[pick])
		pool.remove_at(pick)
	return names

# Geometry stays inside the conservative obstacle radius used for route checks.
static func _populate_field(field: Dictionary, rng: RandomNumberGenerator) -> void:
	var center: Vector2 = field["position"]
	var radius: float = float(field["radius"])
	var rotation: float = rng.randf_range(0.0, TAU)
	var flatten: float = rng.randf_range(0.45, 0.95)
	var outline: Array[Vector2] = []
	for i in range(12):
		var angle: float = TAU * float(i) / 12.0
		var length: float = rng.randf_range(0.65, 0.96)
		outline.append(center + (Vector2.from_angle(angle) * Vector2(1.0, flatten) * radius * length).rotated(rotation))
	field["outline"] = outline
	var chunks: Array = []
	var count: int = clampi(roundi(7.0 + radius / 50.0), 9, 28)
	var profile: float = rng.randf()
	var metal_share: float = 0.5
	if profile < 0.25:
		metal_share = 1.0
	elif profile < 0.5:
		metal_share = 0.0
	elif profile < 0.7:
		metal_share = rng.randf_range(0.85, 0.98)
	elif profile < 0.9:
		metal_share = rng.randf_range(0.02, 0.15)
	else:
		metal_share = rng.randf_range(0.35, 0.65)
	var metal_count: int = roundi(float(count) * metal_share)
	var slots: Array[int] = []
	for i in range(count):
		slots.append(i)
	for i in range(count - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: int = slots[i]
		slots[i] = slots[j]
		slots[j] = swap
	if metal_count == 0:
		field["Metals"] = 0.0
	if metal_count == count:
		field["Crystals"] = 0.0
	for i in range(count):
		var angle: float = rng.randf_range(0.0, TAU)
		var distance: float = sqrt(rng.randf()) * 0.52
		var offset: Vector2 = (Vector2.from_angle(angle) * Vector2(1.0, flatten) * radius * distance).rotated(rotation)
		var resource: String = "Metals" if slots[i] < metal_count else "Crystals"
		var amount: float = rng.randf_range(90.0, 260.0) * float(field[resource])
		var shape: Array[float] = []
		for vertex in range(7):
			shape.append(rng.randf_range(0.62, 1.0))
		chunks.append({"id": i, "position": center + offset, "resource": resource,
			"remaining": amount, "initial": amount, "radius": radius * rng.randf_range(0.045, 0.085),
			"rotation": rng.randf_range(0.0, TAU), "shape": shape})
	field["chunks"] = chunks

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

static func _closest_pair(points: Array[Vector2], a: Array, b: Array, excluded: Array, degrees: Array[int], budget: int) -> Array:
	var best: float = INF
	var pair: Array = []
	for i in a:
		for j in b:
			if i == j or excluded.has(j):
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
	var count: int = (map_data.get("points", []) as Array).size()
	if start < 0 or goal < 0 or start >= count or goal >= count:
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
		for i in range(count):
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
