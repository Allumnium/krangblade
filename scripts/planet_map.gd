extends RefCounted
## Seeded connected planet graph, independent of the rendering layer.
const SIZE := Vector2(2200, 1500)

const TRAVEL_SPEED: float = 95.0
const LONGEST_LINK_YEARS: float = 100.0
const MAX_CONNECTIONS: int = 3
const EXTRA_LINK_CHANCE: float = 0.35
const ANTIMATTER := "Raw antimatter"
const LAYOUTS: Array[String] = ["Radial", "Grid", "Scramble"]
const DEFAULT_LAYOUT: String = "Radial"
# Clearance from a starting system to the edge of a special field, before
# the map's common travel-distance normalization.
const ANTIMATTER_CLEARANCE: float = 700.0

static func valid_layout(layout: String) -> bool:
	return LAYOUTS.has(layout)

static func generate(seed_value: int, player_count: int = 3, layout: String = DEFAULT_LAYOUT) -> Dictionary:
	if not valid_layout(layout):
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
	for i in range(cluster_count):
		var slot: int = slots[i]
		centers.append(Vector2(625.0 + float(slot % columns) * 1250.0, 525.0 + floorf(float(slot) / columns) * 1050.0) + Vector2(rng.randf_range(-90, 90), rng.randf_range(-70, 70)))
		groups.append([])
		sizes.append(6 if i < player_count else clampi(roundi(rng.randfn(6.0, 1.5)), 3, 9))
	# The original clustered lattice supplies Grid and a deterministic fallback.
	# Keep the geometry RNG separate from local system/resource generation.
	var layout_rng := RandomNumberGenerator.new()
	layout_rng.seed = seed_value + 49717
	if layout == "Radial":
		var inner_count: int = player_count - 1
		var inner_radius: float = 1250.0 if inner_count <= 2 else maxf(1250.0, 1250.0 / (2.0 * sin(PI / float(inner_count))))
		var middle_radius: float = inner_radius + 1250.0
		var outer_radius: float = middle_radius + 1250.0
		if player_count == 1:
			middle_radius = 1250.0
			outer_radius = 2500.0
		bounds = Vector2.ONE * (outer_radius + 650.0) * 2.0
		var center: Vector2 = bounds * 0.5
		var rotation: float = layout_rng.randf_range(0.0, TAU)
		centers.clear()
		for ring in range(2):
			for i in range(player_count):
				var angle: float = rotation + TAU * float(i) / player_count
				centers.append(center + Vector2.from_angle(angle) * (outer_radius if ring == 0 else middle_radius))
		centers.append(center)
		for i in range(inner_count):
			var angle: float = rotation + TAU * (float(i) + 0.5) / maxf(1.0, float(inner_count))
			centers.append(center + Vector2.from_angle(angle) * inner_radius)
	elif layout == "Scramble":
		var scattered_bounds := Vector2(columns * 1750.0, rows * 1600.0)
		var scattered: Array[Vector2] = []
		for i in range(cluster_count):
			for attempt in range(400):
				var candidate := Vector2(layout_rng.randf_range(550.0, scattered_bounds.x - 550.0), layout_rng.randf_range(550.0, scattered_bounds.y - 550.0))
				var separated: bool = true
				for other in scattered:
					if candidate.distance_to(other) < 1050.0:
						separated = false
						break
				if separated:
					scattered.append(candidate)
					break
			if scattered.size() != i + 1:
				break
		if scattered.size() == cluster_count:
			bounds = scattered_bounds
			centers.clear()
			# Farthest-first home selection avoids packing starts into one region.
			centers.append(scattered.pop_at(0))
			while centers.size() < player_count:
				var best_index: int = 0
				var best_distance: float = -1.0
				for i in range(scattered.size()):
					var nearest_home: float = INF
					for home in centers:
						nearest_home = minf(nearest_home, scattered[i].distance_to(home))
					if nearest_home > best_distance:
						best_distance = nearest_home
						best_index = i
				centers.append(scattered.pop_at(best_index))
			centers.append_array(scattered)
		else:
			# Bounded fallback: jitter the spaced lattice, not an unbounded retry.
			for i in range(centers.size()):
				centers[i] += Vector2(layout_rng.randf_range(-100.0, 100.0), layout_rng.randf_range(-80.0, 80.0))
	var points: Array[Vector2] = []
	var clusters: Array[int] = []
	# Indices 0..player_count-1 remain the ordered player homeworlds.
	for group in range(player_count):
		points.append(centers[group])
		clusters.append(group)
		groups[group].append(points.size() - 1)
	for group in range(cluster_count):
		while groups[group].size() < sizes[group]:
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
			var pair: Array = _closest_pair(points, connected, group, connected, degrees, mini(1 - local_junctions, max_junctions - junctions))
			var added: int = _new_junctions(pair, degrees)
			local_junctions += added
			junctions += added
			_add_edge(edges, degrees, pair)
			connected.append(pair[1] if connected.has(pair[0]) else pair[0])
	var joined: Array = [0]
	while joined.size() < cluster_count:
		var best_edge: Array = []
		var next_group: int = -1
		var best_score: float = INF
		for pass_index in range(2):
			for i in joined:
				for j in range(cluster_count):
					if joined.has(j):
						continue
					if pass_index == 0 and layout == "Radial":
						if (i < player_count and j != i + player_count) or (j < player_count and i != j + player_count):
							continue
					var pair: Array = _closest_pair(points, groups[i], groups[j], [], degrees, max_junctions - junctions)
					if pair.is_empty():
						continue
					var score: float = _edge_score(points, pair, degrees)
					if score < best_score:
						best_score = score
						best_edge = pair
						next_group = j
			if not best_edge.is_empty():
				break
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
	# Reserve remote special deposits before ordinary fields occupy their space.
	# Use the central neutral cluster in Radial, and seeded shuffled neutral
	# sites in Grid/Scramble. Every special field must clear every home.
	var special_sites: Array[Vector2] = []
	for group in range(player_count, cluster_count):
		if layout == "Radial" and group != player_count * 2:
			continue
		for y in range(-5, 6):
			for x in range(-5, 6):
				special_sites.append(centers[group] + Vector2(x * 80.0, y * 80.0))
	var galaxy_center: Vector2 = bounds * 0.5
	if layout == "Radial":
		special_sites.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(galaxy_center) < b.distance_squared_to(galaxy_center))
	else:
		for i in range(special_sites.size() - 1, 0, -1):
			var j: int = layout_rng.randi_range(0, i)
			var swap: Vector2 = special_sites[i]
			special_sites[i] = special_sites[j]
			special_sites[j] = swap
	var special: Array = []
	var needed: int = 1 if player_count <= 2 else 2
	var special_extent: float = 0.0
	for center in special_sites:
		if special.size() >= needed:
			break
		var radius: float = 48.0
		var field: Dictionary = _safe_field(center, radius, points, edges, special)
		if field.is_empty():
			continue
		var remote: bool = true
		var anchor: int = int(field["anchor"])
		var access: float = center.distance_to(points[anchor]) * 1.5 + radius
		for home in range(player_count):
			if center.distance_to(points[home]) < maxf(ANTIMATTER_CLEARANCE + radius, access + 1.0):
				remote = false
				break
		if not remote:
			continue
		field["Metals"] = 1.0
		field["Crystals"] = 1.0
		field["antimatter"] = true
		special.append(field)
		special_extent = maxf(special_extent, center.distance_to(galaxy_center))
	# Keep ordinary starting access intact; special deposits never consume
	# ordinary field slots or occupy an ordinary lane.
	var fields: Array = []
	var occupied: Array = special.duplicate()
	for pair in candidates:
		if fields.size() >= cluster_count * 2:
			break
		var center: Vector2 = (points[pair[0]] + points[pair[1]]) * 0.5
		var radius: float = rng.randf_range(32.0, 92.0)
		if layout == "Radial" and center.distance_to(galaxy_center) < special_extent:
			continue
		var field: Dictionary = _safe_field(center, radius, points, edges, occupied)
		if not field.is_empty():
			field["Metals"] = rng.randf_range(1.0, 2.0)
			field["Crystals"] = rng.randf_range(1.0, 2.0)
			fields.append(field)
			occupied.append(field)
	fields.append_array(special)
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
		if bool(field.get("antimatter", false)):
			field["Metals"] = 0.0
			field["Crystals"] = 0.0
			field[ANTIMATTER] = 1.0
			for chunk in field["chunks"]:
				chunk["resource"] = ANTIMATTER
	return {"seed": seed_value, "layout": layout, "antimatter_home_clearance": ANTIMATTER_CLEARANCE * distance_scale, "names": system_names(seed_value, points.size()), "points": points, "edges": edges, "clusters": clusters, "fields": fields, "size": bounds * distance_scale, "cluster_sizes": sizes, "player_count": player_count, "max_junctions": max_junctions}

static func _safe_field(center: Vector2, radius: float, points: Array[Vector2], edges: Array, fields: Array) -> Dictionary:
	var anchor: int = -1
	var nearest: float = INF
	for i in range(points.size()):
		var distance: float = center.distance_to(points[i])
		if distance < radius + 45.0:
			return {}
		if distance < nearest:
			nearest = distance
			anchor = i
	for edge in edges:
		if Geometry2D.get_closest_point_to_segment(center, points[edge[0]], points[edge[1]]).distance_to(center) <= radius:
			return {}
	for field in fields:
		if center.distance_to(field["position"]) < radius + float(field["radius"]) + 30.0:
			return {}
		if Geometry2D.get_closest_point_to_segment(field["position"], points[anchor], center).distance_to(field["position"]) <= float(field["radius"]):
			return {}
		if Geometry2D.get_closest_point_to_segment(center, points[int(field["anchor"])], field["position"]).distance_to(center) <= radius:
			return {}
	return {"position": center, "radius": radius, "anchor": anchor}

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
