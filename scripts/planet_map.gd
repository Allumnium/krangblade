extends RefCounted
## Seeded connected planet graph, independent of the rendering layer.
const SIZE := Vector2(2200, 1500)

const TRAVEL_SPEED: float = 95.0
const LONGEST_LINK_YEARS: float = 100.0
const MAX_CONNECTIONS: int = 3
const EXTRA_LINK_CHANCE: float = 0.35
const ANTIMATTER := "Raw antimatter"
const LAYOUTS: Array[String] = ["Radial", "Grid", "Hex Grid", "Scramble"]
const DEFAULT_LAYOUT: String = "Radial"
# Clearance from a starting system to the edge of a special field, before
# the map's common travel-distance normalization.
const ANTIMATTER_CLEARANCE: float = 700.0

static func valid_layout(layout: String) -> bool:
	return LAYOUTS.has(layout)

# Each 4-by-2 block contains a six-system ring and two possible
# standalone systems. Keep full blocks to avoid incomplete edge cells.
static func hex_dimensions(player_count: int) -> Vector2i:
	var blocks: int = maxi(3, ceili(float(player_count * 18) / 8.0))
	var columns: int = ceili(sqrt(float(blocks)))
	return Vector2i(columns * 4, ceili(float(blocks) / columns) * 2)

static func cluster_count_for(player_count: int, layout: String) -> int:
	if layout == "Hex Grid":
		var dimensions: Vector2i = hex_dimensions(player_count)
		return floori(float(dimensions.x * dimensions.y) / 8.0)
	return maxi(3, player_count) * 3 if layout == "Radial" else player_count * 3

static func planetless_systems(seed_value: int, count: int, edges: Array, homes: int) -> Array[int]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 176911
	var protected: Dictionary = {}
	for home in range(homes):
		protected[home] = true
		for edge in edges:
			var neighbor: int = edge[1] if edge[0] == home else (edge[0] if edge[1] == home else -1)
			if neighbor >= homes:
				protected[neighbor] = true
				break
	var candidates: Array[int] = []
	for index in range(homes, count):
		if not protected.has(index):
			candidates.append(index)
	for index in range(candidates.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: int = candidates[index]
		candidates[index] = candidates[other]
		candidates[other] = swap
	candidates.resize(mini(candidates.size(), floori(float(count) * 0.5)))
	candidates.sort()
	return candidates

static func generate(seed_value: int, player_count: int = 3, layout: String = DEFAULT_LAYOUT) -> Dictionary:
	if not valid_layout(layout):
		layout = DEFAULT_LAYOUT
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	player_count = clampi(player_count, 1, 8)
	if layout == "Hex Grid":
		return _generate_hex(seed_value, player_count, rng)
	var radial_sectors: int = maxi(3, player_count)
	var cluster_count: int = cluster_count_for(player_count, layout)
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
		# Three concentric rows: outer and inner cycles, with middle
		# clusters forming spokes. Leave the actual center unoccupied.
		var inner_radius: float = maxf(1250.0, 1250.0 / (2.0 * sin(PI / float(radial_sectors))))
		var middle_radius: float = inner_radius + 1100.0
		var outer_radius: float = middle_radius + 1100.0
		bounds = Vector2.ONE * (outer_radius + 650.0) * 2.0
		var center: Vector2 = bounds * 0.5
		var rotation: float = layout_rng.randf_range(0.0, TAU)
		centers.clear()
		for radius in [outer_radius, middle_radius, inner_radius]:
			for sector in range(radial_sectors):
				var angle: float = rotation + TAU * float(sector) / radial_sectors
				centers.append(center + Vector2.from_angle(angle) * float(radius))
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
	if layout == "Radial":
		max_junctions = maxi(max_junctions, radial_sectors * 2)
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
			var local_budget: int = 0 if layout == "Radial" else 1 - local_junctions
			var pair: Array = _closest_pair(points, connected, group, connected, degrees, mini(local_budget, max_junctions - junctions))
			var added: int = _new_junctions(pair, degrees)
			local_junctions += added
			junctions += added
			_add_edge(edges, degrees, pair)
			connected.append(pair[1] if connected.has(pair[0]) else pair[0])
	if layout == "Radial":
		var bridges: Array = []
		for sector in range(radial_sectors):
			bridges.append([sector, sector + radial_sectors])
			bridges.append([sector + radial_sectors, sector + 2 * radial_sectors])
		for ring in [0, 2]:
			for sector in range(radial_sectors):
				bridges.append([ring * radial_sectors + sector, ring * radial_sectors + (sector + 1) % radial_sectors])
		for bridge in bridges:
			# Prefer unused path endpoints, then spend at most one junction
			# on each ring cluster's third bridge.
			var pair: Array = _closest_pair(points, groups[bridge[0]], groups[bridge[1]], [], degrees, 0)
			if pair.is_empty():
				pair = _closest_pair(points, groups[bridge[0]], groups[bridge[1]], [], degrees, mini(1, max_junctions - junctions))
			if pair.is_empty():
				pair = _closest_pair(points, groups[bridge[0]], groups[bridge[1]], [], degrees, max_junctions - junctions)
			junctions += _new_junctions(pair, degrees)
			_add_edge(edges, degrees, pair)
	else:
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
	# Use the empty central region in Radial, and seeded shuffled neutral
	# sites in Grid/Scramble. Every special field must clear every home.
	var special_sites: Array[Vector2] = []
	var galaxy_center: Vector2 = bounds * 0.5
	if layout == "Radial":
		for y in range(-5, 6):
			for x in range(-5, 6):
				special_sites.append(galaxy_center + Vector2(x * 80.0, y * 80.0))
	else:
		for group in range(player_count, cluster_count):
			for y in range(-5, 6):
				for x in range(-5, 6):
					special_sites.append(centers[group] + Vector2(x * 80.0, y * 80.0))
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
	_insert_standalone_systems(points, clusters, edges, fields, distance_scale)
	_assign_field_lanes(points, edges, fields, player_count)
	return {"seed": seed_value, "layout": layout, "planetless": planetless_systems(seed_value, points.size(), edges, player_count), "hex_slots": [], "antimatter_home_clearance": ANTIMATTER_CLEARANCE * distance_scale, "names": system_names(seed_value, points.size()), "points": points, "edges": edges, "clusters": clusters, "fields": fields, "size": bounds * distance_scale, "cluster_sizes": sizes, "player_count": player_count, "max_junctions": max_junctions}

# Insert neutral systems along the existing bridge routes. Preserve the
# longest original lane and all existing home indices, fields and paths.
# A cluster id of -1 means no cluster, not a shared extra cluster.
static func _insert_standalone_systems(points: Array[Vector2], clusters: Array[int], edges: Array, fields: Array, scale: float) -> void:
	var target: int = roundi(float(points.size()) * 0.25)
	var longest: float = 0.0
	var reserved: Array = []
	for edge in edges:
		var length: float = points[edge[0]].distance_squared_to(points[edge[1]])
		if length > longest:
			longest = length
			reserved = edge
	for step in range(target):
		var best: int = -1
		var best_point: Vector2 = Vector2.ZERO
		var score: float = -1.0
		for index in range(edges.size()):
			var edge: Array = edges[index]
			if edge == reserved or (clusters[edge[0]] >= 0 and clusters[edge[0]] == clusters[edge[1]]):
				continue
			var start: Vector2 = points[edge[0]]
			var finish: Vector2 = points[edge[1]]
			for fraction in [0.5, 0.4, 0.6, 0.3, 0.7]:
				var candidate: Vector2 = start.lerp(finish, float(fraction))
				var clearance: float = INF
				for point in points:
					clearance = minf(clearance, candidate.distance_to(point))
				for field in fields:
					clearance = minf(clearance, candidate.distance_to(field["position"]) - float(field["radius"]))
				if clearance >= 45.0 * scale and clearance > score:
					best = index
					best_point = candidate
					score = clearance
		if best < 0:
			break
		var edge: Array = edges[best]
		var node: int = points.size()
		points.append(best_point)
		clusters.append(-1)
		edges[best] = [edge[0], node]
		edges.append([edge[1], node])

static func _generate_hex(seed_value: int, player_count: int, rng: RandomNumberGenerator) -> Dictionary:
	var dimensions: Vector2i = hex_dimensions(player_count)
	var spacing: float = 460.0
	var gap: Vector2 = Vector2(700.0, 850.0)
	var lattice: Array[Vector2] = []
	var slot_groups: Array[int] = []
	var groups: Array = []
	var centers: Array[Vector2] = []
	for row in range(dimensions.y):
		for column in range(dimensions.x):
			lattice.append(Vector2(650.0 + float(column) * sqrt(3.0) * spacing * 0.5, 650.0 + (float(row) * 1.5 + float((column + row) % 2) * 0.5) * spacing) + Vector2(floorf(float(column) / 4.0), floorf(float(row) / 2.0)) * gap)
			slot_groups.append(-1)
	for row in range(0, dimensions.y, 2):
		for column in range(0, dimensions.x, 4):
			var members: Array[int] = []
			var center: Vector2 = Vector2.ZERO
			for y in range(row, row + 2):
				for x in range(column + 1, column + 4):
					var slot: int = y * dimensions.x + x
					members.append(slot)
					center += lattice[slot]
					slot_groups[slot] = groups.size()
			groups.append(members)
			centers.append(center / 6.0)
	# Select widely separated home clusters, then order their home vertices.
	var order: Array[int] = [rng.randi_range(0, groups.size() - 1)]
	while order.size() < player_count:
		var farthest: int = -1
		var best: float = -1.0
		for candidate in range(groups.size()):
			if order.has(candidate):
				continue
			var nearest: float = INF
			for home in order:
				nearest = minf(nearest, centers[candidate].distance_squared_to(centers[home]))
			if nearest > best:
				best = nearest
				farthest = candidate
		order.append(farthest)
	for group in range(groups.size()):
		if not order.has(group):
			order.append(group)
	# Six vertices per block gives 75%; add a few adjacent neutral vertices
	# to nearby non-home clusters to reach the requested rounded 80%.
	var extra: int = roundi(float(lattice.size()) * 0.8) - groups.size() * 6
	for index in range(player_count, order.size()):
		if extra <= 0:
			break
		var group: int = order[index]
		var slot: int = int(groups[group][0]) - 1
		groups[group].append(slot)
		slot_groups[slot] = group
		extra -= 1
	# Contract each local ring slightly, so clusters are visually distinct
	# while retaining their real six-sided connections.
	for slot in range(lattice.size()):
		var group: int = slot_groups[slot]
		if group >= 0:
			lattice[slot] = centers[group] + (lattice[slot] - centers[group]) * 0.82
	var slots: Array[int] = []
	for home in range(player_count):
		slots.append(int(groups[order[home]][0]))
	for slot in range(lattice.size()):
		if not slots.has(slot):
			slots.append(slot)
	var points: Array[Vector2] = []
	var clusters: Array[int] = []
	var sizes: Array[int] = []
	for group in order:
		sizes.append(groups[group].size())
	for slot in slots:
		points.append(lattice[slot])
		clusters.append(order.find(slot_groups[slot]) if slot_groups[slot] >= 0 else -1)
	var edges: Array = []
	var degrees: Array[int] = []
	degrees.resize(points.size())
	degrees.fill(0)
	var bridges: Dictionary = {}
	for row in range(dimensions.y):
		for column in range(dimensions.x):
			var slot: int = row * dimensions.x + column
			var neighbors: Array[int] = []
			if column + 1 < dimensions.x:
				neighbors.append(slot + 1)
			if row + 1 < dimensions.y and (column + row) % 2 == 1:
				neighbors.append(slot + dimensions.x)
			for other in neighbors:
				var first: Vector2i = Vector2i(floori(float(column) / 4.0), floori(float(row) / 2.0))
				var second: Vector2i = Vector2i(floori(float(other % dimensions.x) / 4.0), floori(float(other) / dimensions.x / 2.0))
				var pair: Array = [mini(slots.find(slot), slots.find(other)), maxi(slots.find(slot), slots.find(other))]
				if first == second:
					_add_edge(edges, degrees, pair)
				else:
					var key: Vector4i = Vector4i(first.x, first.y, second.x, second.y)
					if not bridges.has(key) or points[pair[0]].distance_squared_to(points[pair[1]]) < points[bridges[key][0]].distance_squared_to(points[bridges[key][1]]):
						bridges[key] = pair
	for pair in bridges.values():
		_add_edge(edges, degrees, pair)
	# Use actual hex interiors for safe mining fields. Reserve special
	# sites first, away from every home, then populate ordinary deposits.
	var sites: Array[Vector2] = []
	for row in range(dimensions.y - 1):
		for column in range(dimensions.x - 2):
			if (column + row) % 2 != 1 or row % 2 != 0 or column % 4 != 1:
				continue
			var center: Vector2 = Vector2.ZERO
			for y in range(row, row + 2):
				for x in range(column, column + 3):
					center += lattice[y * dimensions.x + x]
			sites.append(center / 6.0)
	for index in range(sites.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: Vector2 = sites[index]
		sites[index] = sites[other]
		sites[other] = swap
	var special: Array = []
	var needed: int = 1 if player_count <= 2 else 2
	for center in sites:
		if special.size() >= needed:
			break
		var field: Dictionary = _safe_field(center, 48.0, points, edges, special)
		if field.is_empty():
			continue
		var reach: float = center.distance_to(points[int(field["anchor"])]) * 1.5 + 48.0
		var remote: bool = true
		for home in range(player_count):
			if center.distance_to(points[home]) < maxf(ANTIMATTER_CLEARANCE + 48.0, reach + 1.0):
				remote = false
				break
		if remote:
			field.merge({"Metals": 1.0, "Crystals": 1.0, "antimatter": true})
			special.append(field)
	var fields: Array = []
	var occupied: Array = special.duplicate()
	for center in sites:
		var field: Dictionary = _safe_field(center, rng.randf_range(48.0, 78.0), points, edges, occupied)
		if field.is_empty():
			continue
		field.merge({"Metals": rng.randf_range(1.0, 2.0), "Crystals": rng.randf_range(1.0, 2.0)})
		fields.append(field)
		occupied.append(field)
	fields.append_array(special)
	# Retain the macro-map reference length rather than stretching every
	# fine hex lane into a 100-year journey.
	var scale: float = LONGEST_LINK_YEARS * TRAVEL_SPEED / 1250.0
	var bounds := Vector2(1300.0 + float(dimensions.x - 1) * sqrt(3.0) * spacing * 0.5, 1300.0 + (float(dimensions.y - 1) * 1.5 + 0.5) * spacing) + Vector2(floorf(float(dimensions.x - 1) / 4.0), floorf(float(dimensions.y - 1) / 2.0)) * gap
	for index in range(points.size()):
		points[index] *= scale
	for field in fields:
		field["position"] = (field["position"] as Vector2) * scale
		field["radius"] = float(field["radius"]) * scale
		_populate_field(field, rng)
		if bool(field.get("antimatter", false)):
			field["Metals"] = 0.0
			field["Crystals"] = 0.0
			field[ANTIMATTER] = 1.0
			for chunk in field["chunks"]:
				chunk["resource"] = ANTIMATTER
	_assign_field_lanes(points, edges, fields, player_count)
	return {"seed": seed_value, "layout": "Hex Grid", "planetless": planetless_systems(seed_value, points.size(), edges, player_count), "hex_slots": slots, "antimatter_home_clearance": ANTIMATTER_CLEARANCE * scale, "names": system_names(seed_value, points.size()), "points": points, "edges": edges, "clusters": clusters, "fields": fields, "size": bounds * scale, "cluster_sizes": sizes, "player_count": player_count, "max_junctions": degrees.count(3)}

# Asteroids and stars share a single degree budget. Reserve one lane per
# special field first, then ordinary fields, then add nearby spare links
# in increasing distance order. Persist the exact links in the map.
static func _assign_field_lanes(points: Array[Vector2], edges: Array, fields: Array, homes: int) -> void:
	var degrees: Array[int] = []
	degrees.resize(points.size())
	degrees.fill(0)
	for edge in edges:
		degrees[edge[0]] += 1
		degrees[edge[1]] += 1
	var options: Array = []
	var ordered: Array = []
	for index in range(fields.size()):
		var field: Dictionary = fields[index]
		field["access"] = []
		var center: Vector2 = field["position"]
		var reach: float = center.distance_to(points[int(field["anchor"])]) * 1.5 + float(field["radius"])
		var special: bool = bool(field.get("antimatter", false))
		for node in range(points.size()):
			var distance: float = center.distance_to(points[node])
			if special and node < homes:
				continue
			if distance > reach and not special:
				continue
			var clear: bool = true
			for other in range(fields.size()):
				if other == index:
					continue
				var obstacle: Dictionary = fields[other]
				var obstacle_pos: Vector2 = obstacle["position"]
				if Geometry2D.get_closest_point_to_segment(obstacle_pos, center, points[node]).distance_to(obstacle_pos) <= float(obstacle["radius"]):
					clear = false
					break
			if clear:
				options.append({"field": index, "node": node, "distance": distance, "nearby": distance <= reach})
		ordered.append(index)
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["distance"] == b["distance"]:
			return a["field"] < b["field"] if a["field"] != b["field"] else a["node"] < b["node"]
		return a["distance"] < b["distance"])
	ordered.sort_custom(func(a: int, b: int) -> bool:
		var first: bool = bool(fields[a].get("antimatter", false))
		var second: bool = bool(fields[b].get("antimatter", false))
		return first if first != second else a < b)
	for index in ordered:
		for option in options:
			var node: int = option["node"]
			if option["field"] != index or degrees[node] >= MAX_CONNECTIONS:
				continue
			fields[index]["access"].append(node)
			fields[index]["anchor"] = node
			degrees[node] += 1
			break
	for option in options:
		var index: int = option["field"]
		var node: int = option["node"]
		var access: Array = fields[index]["access"]
		if access.is_empty() or access.size() >= MAX_CONNECTIONS or degrees[node] >= MAX_CONNECTIONS or access.has(node) or not bool(option["nearby"]):
			continue
		access.append(node)
		degrees[node] += 1
	for index in range(fields.size() - 1, -1, -1):
		if fields[index]["access"].is_empty():
			fields.remove_at(index)

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

static func _edge_score(points: Array[Vector2], pair: Array, _degrees: Array[int]) -> float:
	return points[pair[0]].distance_to(points[pair[1]])

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
