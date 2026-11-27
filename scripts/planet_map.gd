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
const ANTIMATTER_RADIUS: float = 96.0
const ASTEROID_INVENTORY_MULTIPLIER: float = 1.0
const MAX_CRYSTAL_SHARE: float = 0.2

static func valid_layout(layout: String) -> bool:
	return LAYOUTS.has(layout)

const SYSTEMS_PER_PLAYER: int = 8

static func cluster_count_for(player_count: int, layout: String) -> int:
	if layout == "Hex Grid":
		return player_count
	if layout == "Radial":
		return 2 if player_count == 1 else maxi(3, player_count) * 2
	return player_count * 2

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
	player_count = clampi(player_count, 1, 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var radial: bool = layout == "Radial"
	var grid: bool = layout == "Grid"
	var hex: bool = layout == "Hex Grid"
	var sectors: int = maxi(3, player_count)
	var group_count: int = sectors * 2 if radial else cluster_count_for(player_count, layout)
	var centers: Array[Vector2] = []
	var sizes: Array[int] = []
	var groups: Array = []
	var columns: int = ceili(sqrt(float(group_count)))
	var rows: int = ceili(float(group_count) / columns)
	var spacing: float = 1600.0 if hex else (1400.0 if grid else 2100.0)
	var bounds: Vector2 = Vector2(columns, rows) * spacing
	if hex:
		bounds = Vector2(columns + 0.5, 1.0 + (rows - 1) * sqrt(3.0) * 0.5) * spacing
	var rotation: float = rng.randf_range(0.0, TAU)
	if radial:
		var inner: float = maxf(1600.0, 1800.0 / (2.0 * sin(PI / float(sectors))))
		var outer: float = inner + 1700.0
		bounds = Vector2.ONE * (outer + 1400.0) * 2.0
		for ring in range(2):
			for sector in range(sectors):
				var angle: float = rotation + TAU * float(sector) / sectors + rng.randf_range(-0.15, 0.15)
				var radius: float = (outer if ring == 0 else inner) * rng.randf_range(0.9, 1.1)
				centers.append(bounds * 0.5 + Vector2.from_angle(angle) * radius)
	else:
		var candidates: Array[Vector2] = []
		for index in range(group_count):
			var row: int = index / columns
			var lattice: Vector2 = Vector2(float(index % columns) + 0.5, float(row) + 0.5)
			if hex:
				lattice = Vector2(lattice.x + float(row % 2) * 0.5, 0.5 + float(row) * sqrt(3.0) * 0.5)
			var jitter: float = 0.0 if grid or hex else 0.25
			candidates.append(lattice * spacing + Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter)) * spacing)
		centers.append(candidates.pop_at(rng.randi_range(0, candidates.size() - 1)))
		while centers.size() < player_count:
			var best: int = 0
			var best_distance: float = -1.0
			for index in range(candidates.size()):
				var nearest: float = INF
				for center in centers:
					nearest = minf(nearest, candidates[index].distance_squared_to(center))
				if nearest > best_distance:
					best_distance = nearest
					best = index
			centers.append(candidates.pop_at(best))
		centers.append_array(candidates)
	for group in range(group_count):
		groups.append([])
		sizes.append(6 if hex else (1 if radial and player_count == 1 else (2 if radial and player_count == 2 else 3)))
	if not radial and not hex:
		for group in range(0, group_count - 1, 2):
			if rng.randf() < 0.65 or grid:
				var shift: int = 1 if rng.randf() < 0.5 else -1
				sizes[group] += shift
				sizes[group + 1] -= shift
	var points: Array[Vector2] = []
	var clusters: Array[int] = []
	var local_points: Array = []
	for group in range(group_count):
		var positions: Array[Vector2] = []
		var center: Vector2 = centers[group]
		var angle: float = rng.randf_range(0.0, TAU)
		if hex:
			var radius: float = 460.0
			for index in range(6):
				var direction: float = TAU * float(index) / 6.0
				positions.append(center + Vector2.from_angle(direction) * radius)
		elif grid:
			# Each cluster occupies a two-by-two patch on the finer square lattice.
			var offsets: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
			var start: int = rng.randi_range(0, 3)
			for index in range(sizes[group]):
				positions.append(center + offsets[(start + index) % 4] * spacing * 0.15)
		else:
			positions.append(center)
			for index in range(1, sizes[group]):
				var candidate: Vector2 = center
				var best_clearance: float = -1.0
				for attempt in range(80):
					var trial: Vector2 = center + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(120.0, 460.0)
					var nearest: float = INF
					for other in positions:
						nearest = minf(nearest, trial.distance_to(other))
					if nearest > best_clearance:
						best_clearance = nearest
						candidate = trial
					if nearest >= 125.0:
						break
				positions.append(candidate)
		local_points.append(positions)
	for group in range(player_count):
		points.append(local_points[group][0])
		clusters.append(group)
		groups[group].append(points.size() - 1)
	for group in range(group_count):
		for index in range(1 if group < player_count else 0, sizes[group]):
			points.append(local_points[group][index])
			clusters.append(group)
			groups[group].append(points.size() - 1)
	var edges: Array = []
	var degrees: Array[int] = []
	degrees.resize(points.size())
	degrees.fill(0)
	for group in groups:
		if hex or (grid and group.size() == 4):
			for index in range(group.size()):
				var first: int = group[index]
				var second: int = group[(index + 1) % group.size()]
				_add_edge(edges, degrees, [mini(first, second), maxi(first, second)])
		else:
			var connected: Array = [group[0]]
			while connected.size() < group.size():
				var pair: Array = _closest_pair(points, connected, group, connected, degrees, points.size())
				_add_edge(edges, degrees, pair)
				connected.append(pair[1] if connected.has(pair[0]) else pair[0])
	if radial:
		var bridges: Array = []
		for sector in range(sectors):
			bridges.append([sector, (sector + 1) % sectors])
			bridges.append([sector + sectors, (sector + 1) % sectors + sectors])
			if player_count > 1 or sector < 2:
				bridges.append([sector, sector + sectors])
		_connect_radial_bridges(points, groups, bridges, edges, degrees)
	else:
		var joined: Array = [0]
		var connected_groups: Dictionary = {}
		while joined.size() < group_count:
			var best_pair: Array = []
			var best_group: int = -1
			var best_from: int = -1
			var best_distance: float = INF
			for first in joined:
				for second in range(group_count):
					if joined.has(second):
						continue
					var pair: Array = _closest_pair(points, groups[first], groups[second], [], degrees, points.size())
					if pair.is_empty():
						continue
					var distance: float = points[pair[0]].distance_squared_to(points[pair[1]])
					# Prefer lattice neighbors over diagonal or skipping links.
					if (grid or hex) and centers[first].distance_to(centers[second]) > spacing * 1.05:
						distance += bounds.length_squared()
					if distance < best_distance:
						best_distance = distance
						best_pair = pair
						best_group = second
						best_from = first
			_add_edge(edges, degrees, best_pair)
			connected_groups[Vector2i(mini(best_from, best_group), maxi(best_from, best_group))] = true
			joined.append(best_group)
		if grid or hex:
			_add_lattice_bridges(points, centers, groups, spacing, connected_groups, edges, degrees, player_count)
	if radial and player_count == 1:
		for index in range(clusters.size()):
			clusters[index] = 0 if clusters[index] < sectors else 1
		sizes = [sectors, sectors]
	var target: int = mini(player_count * SYSTEMS_PER_PLAYER, points.size() + roundi(float(points.size()) * 0.25))
	while points.size() < target:
		var best_edge: int = -1
		var best_distance: float = -1.0
		for index in range(edges.size()):
			var edge: Array = edges[index]
			if clusters[edge[0]] >= 0 and clusters[edge[0]] == clusters[edge[1]]:
				continue
			var distance: float = points[edge[0]].distance_squared_to(points[edge[1]])
			if distance > best_distance:
				best_distance = distance
				best_edge = index
		if best_edge >= 0:
			var edge: Array = edges[best_edge]
			var point: Vector2 = points[edge[0]].lerp(points[edge[1]], 0.5 if grid or hex else rng.randf_range(0.36, 0.64))
			var node: int = points.size()
			points.append(point)
			clusters.append(-1)
			degrees.append(2)
			edges[best_edge] = [edge[0], node]
			edges.append([edge[1], node])
		else:
			var anchor: int = -1
			for index in range(points.size()):
				if degrees[index] < MAX_CONNECTIONS and (anchor < 0 or degrees[index] < degrees[anchor]):
					anchor = index
			var direction: Vector2 = (points[anchor] - centers[0]).normalized()
			if direction.is_zero_approx():
				direction = Vector2.RIGHT
			var node: int = points.size()
			points.append(points[anchor] + direction * rng.randf_range(270.0, 430.0))
			clusters.append(-1)
			degrees.append(0)
			_add_edge(edges, degrees, [anchor, node])
	# Place deposits against actual remaining ports, not nominal cluster counts.
	var fields: Array = []
	var special_sites: Array[Vector2] = []
	var galaxy_center: Vector2 = bounds * 0.5
	if radial:
		for y in range(-5, 6):
			for x in range(-5, 6):
				special_sites.append(galaxy_center + Vector2(x * 80.0, y * 80.0))
		special_sites.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(galaxy_center) < b.distance_squared_to(galaxy_center))
	else:
		for index in range(player_count, points.size()):
			for ring in range(1, 4):
				for angle in range(12):
					special_sites.append(points[index] + Vector2.from_angle(TAU * float(angle) / 12.0) * (110.0 + 85.0 * ring))
		for index in range(special_sites.size() - 1, 0, -1):
			var other: int = rng.randi_range(0, index)
			var swap: Vector2 = special_sites[index]
			special_sites[index] = special_sites[other]
			special_sites[other] = swap
	var needed: int = 1 if player_count <= 2 else 2
	for center in special_sites:
		if fields.size() >= needed:
			break
		var remote: bool = true
		for home in range(player_count):
			if center.distance_to(points[home]) < ANTIMATTER_CLEARANCE + ANTIMATTER_RADIUS:
				remote = false
				break
		if not remote:
			continue
		var field: Dictionary = _field_at(center, ANTIMATTER_RADIUS, points, edges, fields, degrees, player_count)
		if field.is_empty():
			continue
		field.merge({"Metals": 1.0, "Crystals": 1.0, "antimatter": true})
		fields.append(field)
	var specials: Array = fields.duplicate()
	# Nearest available ordinary ports first, prioritizing each starting
	# cluster. Extra fields may use neutral systems' remaining ports.
	var ordinary: Array = []
	var used: Dictionary = {}
	for home in range(player_count):
		var anchors: Array[int] = []
		for index in range(points.size()):
			if index == home or index >= player_count:
				anchors.append(index)
		anchors.sort_custom(func(a: int, b: int) -> bool: return points[a].distance_squared_to(points[home]) < points[b].distance_squared_to(points[home]))
		for anchor in anchors:
			if used.has(anchor) or degrees[anchor] >= MAX_CONNECTIONS:
				continue
			var field: Dictionary = _ordinary_field(anchor, points, edges, fields, degrees, rng, specials if radial else [])
			if not field.is_empty():
				ordinary.append(field)
				fields.append(field)
				used[anchor] = true
				break
	for anchor in range(points.size()):
		if used.has(anchor) or degrees[anchor] >= MAX_CONNECTIONS:
			continue
		var field: Dictionary = _ordinary_field(anchor, points, edges, fields, degrees, rng, specials if radial else [])
		if not field.is_empty():
			ordinary.append(field)
			fields.append(field)
	fields = ordinary + specials
	# Reserve nearby deposit-to-deposit lanes before filling spare star ports.
	# The central radial antimatter pair is a deliberate traversal corridor.
	var field_edges: Array = []
	var field_degrees: Array[int] = []
	var field_options: Array = []
	for field in fields:
		field_degrees.append(field["access"].size())
	for a in range(fields.size()):
		for b in range(a + 1, fields.size()):
			var start: Vector2 = fields[a]["position"]
			var finish: Vector2 = fields[b]["position"]
			var distance: float = start.distance_to(finish)
			var central_pair: bool = radial and fields[a].get("antimatter", false) and fields[b].get("antimatter", false)
			if not central_pair and distance > 3.0 * (float(fields[a]["radius"]) + float(fields[b]["radius"])):
				continue
			var clear: bool = true
			for other in range(fields.size()):
				if other != a and other != b and Geometry2D.get_closest_point_to_segment(fields[other]["position"], start, finish).distance_to(fields[other]["position"]) <= float(fields[other]["radius"]):
					clear = false
					break
			if clear:
				field_options.append({"a": a, "b": b, "score": -1.0 if central_pair else distance})
	field_options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] < b["score"])
	for option in field_options:
		var a: int = option["a"]
		var b: int = option["b"]
		if field_degrees[a] < MAX_CONNECTIONS and field_degrees[b] < MAX_CONNECTIONS:
			field_edges.append([a, b])
			field_degrees[a] += 1
			field_degrees[b] += 1
	var options: Array = []
	for index in range(fields.size()):
		var field: Dictionary = fields[index]
		var center: Vector2 = field["position"]
		var reach: float = center.distance_to(points[int(field["anchor"])]) * 1.5 + float(field["radius"])
		for node in range(points.size()):
			if degrees[node] >= MAX_CONNECTIONS or field["access"].has(node) or (bool(field.get("antimatter", false)) and node < player_count):
				continue
			var distance: float = center.distance_to(points[node])
			if distance > reach:
				continue
			var clear: bool = true
			for other in range(fields.size()):
				if other != index and Geometry2D.get_closest_point_to_segment(fields[other]["position"], center, points[node]).distance_to(fields[other]["position"]) <= float(fields[other]["radius"]):
					clear = false
					break
			if clear:
				options.append({"field": index, "node": node, "distance": distance})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["distance"] < b["distance"])
	for option in options:
		var node: int = option["node"]
		var access: Array = fields[option["field"]]["access"]
		if degrees[node] < MAX_CONNECTIONS and field_degrees[option["field"]] < MAX_CONNECTIONS:
			access.append(node)
			degrees[node] += 1
			field_degrees[option["field"]] += 1
	# Grow ordinary deposits after allocating the legacy graph ports. The
	# graph remains connected and every original resource site remains accessible.
	_grow_asteroid_belts(fields, points, edges, bounds, rng)
	var longest: float = 0.0
	for edge in edges:
		longest = maxf(longest, points[edge[0]].distance_to(points[edge[1]]))
	var scale: float = LONGEST_LINK_YEARS * TRAVEL_SPEED / maxf(longest, 1.0)
	for index in range(points.size()):
		points[index] *= scale
	for field in fields:
		field["position"] = (field["position"] as Vector2) * scale
		field["radius"] = float(field["radius"]) * scale
		for lobe in field.get("belt_lobes", []):
			lobe["position"] = (lobe["position"] as Vector2) * scale
			lobe["radius"] = float(lobe["radius"]) * scale
		_populate_field(field, rng)
		if bool(field.get("antimatter", false)):
			field["Metals"] = 0.0
			field["Crystals"] = 0.0
			field[ANTIMATTER] = 1.0
			for chunk in field["chunks"]:
				chunk["resource"] = ANTIMATTER
				chunk["remaining"] = floorf(float(chunk["remaining"]))
				chunk["initial"] = chunk["remaining"]
	return {"seed": seed_value, "layout": layout, "planetless": planetless_systems(seed_value, points.size(), edges, player_count), "antimatter_home_clearance": ANTIMATTER_CLEARANCE * scale, "names": system_names(seed_value, points.size()), "points": points, "edges": edges, "clusters": clusters, "fields": fields, "field_edges": field_edges, "size": bounds * scale, "cluster_sizes": sizes, "player_count": player_count, "max_junctions": points.size()}

# Each ridge is an open chain: a new lobe intersects only its previous
# neighbor, never a different ridge, a star corridor, or the map boundary.
# Consequently these obstacles cannot create a closed pocket of free space.
static func _belt_lobe_clear(candidate: Dictionary, fields: Array, index: int, lobes: Array, points: Array[Vector2], edges: Array, bounds: Vector2) -> bool:
	var center: Vector2 = candidate["position"]
	var radius: float = float(candidate["radius"])
	const GAP: float = 48.0
	if not Rect2(Vector2.ONE * (radius + GAP), bounds - Vector2.ONE * (radius + GAP) * 2.0).has_point(center):
		return false
	for point in points:
		if center.distance_to(point) < radius + 95.0:
			return false
	for edge in edges:
		if Geometry2D.get_closest_point_to_segment(center, points[edge[0]], points[edge[1]]).distance_to(center) <= radius + GAP:
			return false
	for i in range(lobes.size() - 1):
		if center.distance_to(lobes[i]["position"]) <= radius + float(lobes[i]["radius"]) + GAP:
			return false
	for other in range(fields.size()):
		if other == index:
			continue
		var field: Dictionary = fields[other]
		for lobe in field.get("belt_lobes", [{"position": field["position"], "radius": field["radius"]}]):
			if center.distance_to(lobe["position"]) <= radius + float(lobe["radius"]) + GAP:
				return false
		# Keep legacy access to other resource sites open, too.
		for anchor in field["access"]:
			if Geometry2D.get_closest_point_to_segment(center, points[anchor], field["position"]).distance_to(center) <= radius + GAP:
				return false
	return true

static func _grow_asteroid_belts(fields: Array, points: Array[Vector2], edges: Array, bounds: Vector2, rng: RandomNumberGenerator) -> void:
	for index in range(fields.size()):
		var field: Dictionary = fields[index]
		if bool(field.get("antimatter", false)):
			continue
		var start: Vector2 = field["position"]
		var initial_radius: float = float(field["radius"])
		if not Rect2(Vector2.ONE * (initial_radius + 48.0), bounds - Vector2.ONE * (initial_radius + 48.0) * 2.0).has_point(start):
			continue
		var lobes: Array = [{"position": start, "radius": initial_radius}]
		var axis: Vector2 = (start - points[int(field["anchor"])]).normalized()
		if axis.is_zero_approx():
			axis = Vector2.RIGHT
		# Mix isolated deposits, short knots, thin ridges and broad belts.
		# A field-specific width and bend rate make each chain distinct.
		var goal: int = rng.randi_range(1, 13)
		var width: float = rng.randf_range(70.0, 190.0)
		var bend: float = rng.randf_range(0.12, 0.72)
		for step in range(1, goal):
			var previous: Dictionary = lobes[-1]
			var radius: float = width * rng.randf_range(0.70, 1.30)
			var found: bool = false
			var turn: float = rng.randf_range(-bend, bend)
			for adjustment in [0.0, 0.35, -0.35, 0.7, -0.7, 1.05, -1.05]:
				var direction: Vector2 = axis.rotated(turn + float(adjustment))
				var center: Vector2 = previous["position"] + direction * (float(previous["radius"]) + radius) * rng.randf_range(0.77, 0.84)
				var candidate: Dictionary = {"position": center, "radius": radius}
				if not _belt_lobe_clear(candidate, fields, index, lobes, points, edges, bounds):
					continue
				lobes.append(candidate)
				axis = direction
				found = true
				break
			if not found:
				break
		if lobes.size() < 2 or _belt_outline(lobes).is_empty():
			continue
		field["belt_lobes"] = lobes
		for lobe in lobes:
			field["radius"] = maxf(float(field["radius"]), start.distance_to(lobe["position"]) + float(lobe["radius"]))

static func _belt_outline(lobes: Array) -> PackedVector2Array:
	var outline := PackedVector2Array()
	for lobe in lobes:
		var ring := PackedVector2Array()
		for vertex in range(16):
			ring.append((lobe["position"] as Vector2) + Vector2.from_angle(TAU * float(vertex) / 16.0) * float(lobe["radius"]))
		if outline.is_empty():
			outline = ring
		else:
			var merged: Array[PackedVector2Array] = Geometry2D.merge_polygons(outline, ring)
			if merged.size() == 1:
				outline = merged[0]
			else:
				# Never substitute a convex hull that could close an open
				# passage if the polygon union unexpectedly fails.
				return PackedVector2Array()
	return outline

static func terrain_contains(field: Dictionary, point: Vector2) -> bool:
	if field.has("belt_lobes"):
		return Geometry2D.is_point_in_polygon(point, PackedVector2Array(field["outline"]))
	return point.distance_to(field["position"]) <= float(field["radius"])

static func polygon_blocks_segment(polygon: PackedVector2Array, a: Vector2, b: Vector2) -> bool:
	if Geometry2D.is_point_in_polygon(a, polygon) or Geometry2D.is_point_in_polygon(b, polygon):
		return true
	for i in range(polygon.size()):
		if Geometry2D.segment_intersects_segment(a, b, polygon[i], polygon[(i + 1) % polygon.size()]) != null:
			return true
	return false

static func _field_at(center: Vector2, radius: float, points: Array[Vector2], edges: Array, fields: Array, degrees: Array[int], first_node: int, required_anchor: int = -1) -> Dictionary:
	var field: Dictionary = _safe_field(center, radius, points, edges, fields)
	if field.is_empty():
		return {}
	var best: int = -1
	var distance: float = INF
	for node in range(first_node, points.size()):
		if degrees[node] >= MAX_CONNECTIONS or (required_anchor >= 0 and node != required_anchor):
			continue
		var clear: bool = true
		for other in fields:
			var position: Vector2 = other["position"]
			if Geometry2D.get_closest_point_to_segment(position, center, points[node]).distance_to(position) <= float(other["radius"]):
				clear = false
				break
		if clear and center.distance_squared_to(points[node]) < distance:
			best = node
			distance = center.distance_squared_to(points[node])
	if best < 0:
		return {}
	field["anchor"] = best
	field["access"] = [best]
	degrees[best] += 1
	return field

static func _ordinary_field(anchor: int, points: Array[Vector2], edges: Array, fields: Array, degrees: Array[int], rng: RandomNumberGenerator, protected_pair: Array = []) -> Dictionary:
	var start: float = rng.randf_range(0.0, TAU)
	for ring in range(5):
		for angle in range(16):
			var center: Vector2 = points[anchor] + Vector2.from_angle(start + TAU * float(angle) / 16.0) * (190.0 + float(ring) * 60.0)
			if protected_pair.size() == 2 and Geometry2D.get_closest_point_to_segment(center, protected_pair[0]["position"], protected_pair[1]["position"]).distance_to(center) <= 84.0:
				continue
			var field: Dictionary = _field_at(center, 84.0, points, edges, fields, degrees, 0, anchor)
			if not field.is_empty():
				field.merge({"Metals": rng.randf_range(1.0, 2.0), "Crystals": rng.randf_range(1.0, 2.0)})
				return field
	return {}

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
	var lobes: Array = field.get("belt_lobes", [])
	if not lobes.is_empty():
		outline.assign(Array(_belt_outline(lobes)))
		field["outline"] = outline
	var chunks: Array = []
	var special: bool = bool(field.get("antimatter", false))
	var count: int = 4 * clampi(roundi(7.0 + radius / 100.0), 9, 28)
	if not special:
		count = rng.randi_range(18, 28) if lobes.is_empty() else lobes.size() * rng.randi_range(16, 26)
	var profile: float = rng.randf()
	# Seeded variety: some pure-metal fields, and other fields containing
	# between 3% and 20% crystals by initial tonnage (not just rock count).
	# Antimatter keeps its separate inventory and concentration.
	var crystal_share: float = 0.0 if profile < 0.15 or special else rng.randf_range(0.03, MAX_CRYSTAL_SHARE)
	var crystal_count: int = ceili(count * crystal_share)
	var metal_count: int = count - crystal_count
	var slots: Array[int] = []
	for i in range(count):
		slots.append(i)
	for i in range(count - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: int = slots[i]
		slots[i] = slots[j]
		slots[j] = swap
	if metal_count == count:
		field["Crystals"] = 0.0
	var totals: Dictionary = {"Metals": 0.0, "Crystals": 0.0}
	for i in range(count):
		var angle: float = rng.randf_range(0.0, TAU)
		var distance: float = sqrt(rng.randf()) * (0.52 if special else 0.59)
		var offset: Vector2 = (Vector2.from_angle(angle) * Vector2(1.0, flatten) * radius * distance).rotated(rotation)
		var rock_radius: float = radius
		if not lobes.is_empty():
			var lobe: Dictionary = lobes[i % lobes.size()]
			rock_radius = float(lobe["radius"])
			# Best of several seeded samples avoids rock piles while keeping
			# an organic distribution instead of an artificial grid.
			var best_clearance: float = -1.0
			for attempt in range(6):
				var trial: Vector2 = (lobe["position"] as Vector2) - center + Vector2.from_angle(rng.randf_range(0.0, TAU)) * sqrt(rng.randf()) * rock_radius * 0.89
				var clearance: float = INF
				for existing in chunks:
					clearance = minf(clearance, (center + trial).distance_to(existing["position"]) - float(existing["radius"]))
				if clearance > best_clearance:
					best_clearance = clearance
					offset = trial
		var size_factor: float = rng.randf_range(0.0225, 0.0425) if special else lerpf(0.012, 0.065, pow(rng.randf(), 1.7))
		var resource: String = "Metals" if slots[i] < metal_count else "Crystals"
		var amount: float = rng.randf_range(90.0, 260.0) * float(field[resource]) * (1.0 if special else ASTEROID_INVENTORY_MULTIPLIER)
		totals[resource] += amount
		var shape: Array[float] = []
		for vertex in range(7 if special else rng.randi_range(5, 10)):
			shape.append(rng.randf_range(0.62, 1.0))
		chunks.append({"id": i, "position": center + offset, "resource": resource,
			"remaining": amount, "initial": amount, "radius": rock_radius * size_factor * (1.0 if special else 4.0),
			"rotation": rng.randf_range(0.0, TAU), "shape": shape})
	# Preserve the generated total while normalizing individual ore amounts.
	# Otherwise random rock sizes and concentration can exceed the cap.
	if crystal_count > 0:
		var total: float = float(totals["Metals"]) + float(totals["Crystals"])
		for chunk in chunks:
			var ore: String = chunk["resource"]
			var share: float = crystal_share if ore == "Crystals" else 1.0 - crystal_share
			var amount: float = float(chunk["initial"]) * total * share / float(totals[ore])
			chunk["initial"] = amount
			chunk["remaining"] = amount
	# Keep placement/strategic pool radius independent of rock geometry.
	var rock_extent: float = radius
	for chunk in chunks:
		rock_extent = maxf(rock_extent, center.distance_to(chunk["position"]) + float(chunk["radius"]))
	field["rock_extent"] = rock_extent
	field["chunks"] = chunks

static func blocked(a: Vector2, b: Vector2, fields: Array) -> bool:
	for field in fields:
		var center: Vector2 = field["position"]
		if field.has("belt_lobes"):
			for lobe in field["belt_lobes"]:
				var lobe_center: Vector2 = lobe["position"]
				if Geometry2D.get_closest_point_to_segment(lobe_center, a, b).distance_to(lobe_center) <= float(lobe["radius"]):
					return true
		elif Geometry2D.get_closest_point_to_segment(center, a, b).distance_to(center) <= float(field["radius"]):
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

# Complete nearby lattice loops wherever spare ports permit. Keep at least
# one port in each cluster and avoid spending a home's final port on an
# optional bridge, so ordinary and protected deposits still have access.
static func _add_lattice_bridges(points: Array[Vector2], centers: Array[Vector2], groups: Array, spacing: float, connected: Dictionary, edges: Array, degrees: Array[int], homes: int) -> void:
	var candidates: Array[Vector2i] = []
	var spare: Array[int] = []
	for group in groups:
		var ports: int = 0
		for node in group:
			ports += MAX_CONNECTIONS - degrees[node]
		spare.append(ports)
	for a in range(groups.size()):
		for b in range(a + 1, groups.size()):
			var key := Vector2i(a, b)
			if not connected.has(key) and centers[a].distance_to(centers[b]) <= spacing * 1.05:
				candidates.append(key)
	while not candidates.is_empty():
		var best_index: int = -1
		var best_pair: Array = []
		var best_distance: float = INF
		for index in range(candidates.size()):
			var key: Vector2i = candidates[index]
			if spare[key.x] <= 1 or spare[key.y] <= 1:
				continue
			for a in groups[key.x]:
				if degrees[a] >= MAX_CONNECTIONS - int(a < homes):
					continue
				for b in groups[key.y]:
					if degrees[b] >= MAX_CONNECTIONS - int(b < homes):
						continue
					var distance: float = points[a].distance_squared_to(points[b])
					if distance < best_distance:
						best_distance = distance
						best_index = index
						best_pair = [mini(a, b), maxi(a, b)]
		if best_index < 0:
			break
		var chosen: Vector2i = candidates.pop_at(best_index)
		_add_edge(edges, degrees, best_pair)
		spare[chosen.x] -= 1
		spare[chosen.y] -= 1

# Preserve the required ring and spoke connections, but grant the shortest
# eligible bridge first instead of preferring nodes with fewer than two lanes.
# Every cluster has enough spare ports for its required bridges. Revisit the
# chosen endpoints once all bridges exist to remove avoidable long links.
static func _connect_radial_bridges(points: Array[Vector2], groups: Array, bridges: Array, edges: Array, degrees: Array[int]) -> void:
	var pending: Array = bridges.duplicate()
	var chosen: Array = []
	while not pending.is_empty():
		var best: float = INF
		var best_index: int = -1
		var best_pair: Array = []
		for index in range(pending.size()):
			var bridge: Array = pending[index]
			var pair: Array = _closest_pair(points, groups[bridge[0]], groups[bridge[1]], [], degrees, points.size())
			if pair.is_empty():
				continue
			var distance: float = _edge_score(points, pair, degrees)
			if distance < best:
				best = distance
				best_index = index
				best_pair = pair
		chosen.append({"bridge": pending.pop_at(best_index), "edge": edges.size()})
		_add_edge(edges, degrees, best_pair)
	var improved: bool = true
	while improved:
		improved = false
		for entry in chosen:
			var index: int = entry["edge"]
			var bridge: Array = entry["bridge"]
			var old: Array = edges[index]
			degrees[old[0]] -= 1
			degrees[old[1]] -= 1
			var pair: Array = _closest_pair(points, groups[bridge[0]], groups[bridge[1]], [], degrees, points.size())
			if _edge_score(points, pair, degrees) < _edge_score(points, old, degrees) - 0.001:
				edges[index] = pair
				improved = true
			var current: Array = edges[index]
			degrees[current[0]] += 1
			degrees[current[1]] += 1

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
