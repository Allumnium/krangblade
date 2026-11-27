extends RefCounted
## Seeded connected planet graph, independent of the rendering layer.
const SIZE := Vector2(2200, 1500)

const TRAVEL_SPEED: float = 95.0
const LONGEST_LINK_YEARS: float = 125.0
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
const ASTEROID_CLUSTER_SCALE: float = 0.55
const ASTEROID_RADIUS_SCALE: float = 0.4
const ASTEROID_MAX_RADIUS: float = 24.0
const ORBIT_ROCK_MIN: int = 64
const ORBIT_ROCK_MAX: int = 80
const ORBIT_WORLD_RADIUS: float = 5400.0
const STAR_SITE_CHANCE: float = 0.30
const ASTEROID_SITE_CHANCE: float = 0.35
const ASTEROID_ORBIT_STEP: float = 1.0
const MAX_CRYSTAL_SHARE: float = 0.2

static func valid_layout(layout: String) -> bool:
	return LAYOUTS.has(layout)

const SYSTEMS_PER_PLAYER: int = 8 # Historical approximate star budget.
const PATTERN_SITES_PER_PLAYER: int = 24

static func cluster_count_for(_player_count: int, _layout: String) -> int:
	return 0

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
	# Each occupied stellar site contains exactly one independent star.
	# Legacy empty cluster metadata is retained only for snapshot compatibility.
	var count: int = player_count * PATTERN_SITES_PER_PLAYER
	var spacing: float = 950.0
	var raw: Array[Vector2] = []
	var bounds: Vector2
	var rotation: float = rng.randf_range(0.0, TAU)
	if radial:
		var per_ring: int = count / 2
		var inner: float = maxf(spacing, spacing / (2.0 * sin(PI / float(per_ring))))
		var outer: float = inner + spacing
		bounds = Vector2.ONE * (outer + spacing) * 2.0
		for ring in range(2):
			for k in range(per_ring):
				var angle: float = rotation + TAU * float(k) / float(per_ring)
				raw.append(bounds * 0.5 + Vector2.from_angle(angle) * (outer if ring == 0 else inner))
	else:
		var columns: int = ceili(sqrt(float(count)))
		var rows: int = ceili(float(count) / float(columns))
		bounds = Vector2(columns + 1.0, rows + 1.0) * spacing
		for row in range(rows):
			var row_count: int = mini(columns, count - raw.size())
			for k in range(row_count):
				var col: int = k if row % 2 == 0 else columns - 1 - k
				var pos := Vector2(float(col) + 0.75, float(row) + 0.75)
				if hex:
					pos.x += float(row % 2) * 0.5
					pos.y = 0.75 + float(row) * sqrt(3.0) * 0.5
				if not grid and not hex:
					pos += Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.15, 0.15))
				raw.append(pos * spacing)
	# Assign spread-out homes first; every home retains a neutral neighbor.
	var home_raw: Array[int] = []
	if radial:
		for player in range(player_count):
			home_raw.append(player * (PATTERN_SITES_PER_PLAYER / 2))
	else:
		var candidates: Array[int] = []
		for k in range(0, count, 2):
			candidates.append(k)
		home_raw.append(candidates.pop_at(rng.randi_range(0, candidates.size() - 1)))
		while home_raw.size() < player_count:
			var best: int = 0
			var best_distance: float = -1.0
			for k in range(candidates.size()):
				var nearest: float = INF
				for home in home_raw:
					nearest = minf(nearest, raw[candidates[k]].distance_squared_to(raw[home]))
				if nearest > best_distance:
					best_distance = nearest
					best = k
			home_raw.append(candidates.pop_at(best))
	# Pattern sites are candidates, not automatically stars or colonies.
	# Keep home indices stable, then roll each other site independently.
	var site_rng := RandomNumberGenerator.new()
	site_rng.seed = seed_value + 88301
	var order: Array[int] = home_raw.duplicate()
	var asteroid_sites: Array[int] = []
	var vacant: Array[int] = []
	for k in range(count):
		if home_raw.has(k):
			continue
		var roll: float = site_rng.randf()
		if roll < STAR_SITE_CHANCE:
			order.append(k)
		elif roll < STAR_SITE_CHANCE + ASTEROID_SITE_CHANCE:
			asteroid_sites.append(k)
		else:
			vacant.append(k)
	# Rare low-star rolls must still allow an expansion neighbor per home
	# and enough planetless colonies for the existing orbital economy.
	var minimum_stars: int = player_count * 4 + 2
	while order.size() < minimum_stars:
		var pool: Array[int] = vacant if not vacant.is_empty() else asteroid_sites
		order.append(pool.pop_at(site_rng.randi_range(0, pool.size() - 1)))
	var neutral_raw: Array[int] = []
	neutral_raw.assign(order.slice(player_count))
	neutral_raw.sort()
	order.assign(home_raw)
	order.append_array(neutral_raw)
	var points: Array[Vector2] = []
	var clusters: Array[int] = []
	var sizes: Array[int] = []
	var remap: Dictionary = {}
	for k in order:
		remap[k] = points.size()
		points.append(raw[k])
		clusters.append(-1)
	var edges: Array = []
	var degrees: Array[int] = []
	degrees.resize(points.size())
	degrees.fill(0)
	# Follow the pattern through occupied neutral positions only.
	# Home systems attach as leaves to keep each start next to a neutral.
	if radial:
		var rings: Array = [[], []]
		for k in neutral_raw:
			rings[0 if k < count / 2 else 1].append(int(remap[k]))
		for chain in rings:
			for k in range(1, chain.size()):
				_add_edge(edges, degrees, [mini(chain[k - 1], chain[k]), maxi(chain[k - 1], chain[k])])
		if not rings[0].is_empty() and not rings[1].is_empty():
			var best_pair: Array = []
			var shortest: float = INF
			for a in rings[0]:
				for b in rings[1]:
					var distance: float = points[a].distance_squared_to(points[b])
					if distance < shortest:
						shortest = distance
						best_pair = [mini(a, b), maxi(a, b)]
			_add_edge(edges, degrees, best_pair)
	else:
		# Nearest-neighbor backbone avoids crossing large vacant spans where possible.
		var remaining: Array[int] = []
		for node in range(player_count, points.size()):
			remaining.append(node)
		var last: int = remaining.pop_front()
		while not remaining.is_empty():
			var best: int = 0
			var shortest: float = INF
			for k in range(remaining.size()):
				var distance: float = points[last].distance_squared_to(points[remaining[k]])
				if distance < shortest:
					shortest = distance
					best = k
			var next: int = remaining.pop_at(best)
			_add_edge(edges, degrees, [mini(last, next), maxi(last, next)])
			last = next
	var home_neighbors: Dictionary = {}
	for home in range(player_count):
		var nearest: int = -1
		var shortest: float = INF
		for node in range(player_count, points.size()):
			if degrees[node] >= MAX_CONNECTIONS or home_neighbors.has(node):
				continue
			var distance: float = points[home].distance_squared_to(points[node])
			if distance < shortest:
				shortest = distance
				nearest = node
		# At least three neutral stars per home guarantee a free port.
		if nearest >= 0:
			_add_edge(edges, degrees, [home, nearest])
			home_neighbors[nearest] = true
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
					special_sites.append(points[index] + Vector2.from_angle(TAU * float(angle) / 12.0) * (340.0 + 105.0 * ring))
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
	# Asteroid-only pattern sites are actual ore fields, never fake stars.
	# Preserve the protected Pulsar corridor and the existing route-port cap;
	# infeasible cluster candidates remain empty.
	var site_fields: Array = []
	for site in asteroid_sites:
		var at: Vector2 = raw[site]
		if radial and specials.size() == 2 and Geometry2D.get_closest_point_to_segment(at, specials[0]["position"], specials[1]["position"]).distance_to(at) <= 100.0:
			continue
		var field: Dictionary = _field_at(at, 100.0, points, edges, fields, degrees, 0)
		if field.is_empty():
			continue
		field.merge({"Metals": rng.randf_range(1.0, 2.0), "Crystals": rng.randf_range(1.0, 2.0), "pattern_cluster": true})
		site_fields.append(field)
		fields.append(field)
	# A few interstellar deposits complement the system rings. Reserve
	# ordinary resource ports only for these static clusters and Pulsars.
	var ordinary: Array = []
	for anchor in range(points.size()):
		if anchor < player_count or degrees[anchor] >= MAX_CONNECTIONS or rng.randf() >= 0.28:
			continue
		var field: Dictionary = _ordinary_field(anchor, points, edges, fields, degrees, rng, specials if radial else [])
		if not field.is_empty():
			ordinary.append(field)
			fields.append(field)
	fields = site_fields + ordinary + specials
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
	var longest: float = 0.0
	for edge in edges:
		longest = maxf(longest, points[edge[0]].distance_to(points[edge[1]]))
	var scale: float = LONGEST_LINK_YEARS * TRAVEL_SPEED / maxf(longest, 1.0)
	# One orbital resource pool per star. These additional logical mining
	# access spurs do not consume a physical star-to-star route port.
	var rings: Array = []
	for anchor in range(points.size()):
		var center: Vector2 = points[anchor]
		var nearest: float = INF
		for other in range(points.size()):
			if other != anchor:
				nearest = minf(nearest, center.distance_to(points[other]))
		var edge_clearance: float = minf(minf(center.x, center.y), minf(bounds.x - center.x, bounds.y - center.y))
		var room: float = minf(nearest * 0.44, edge_clearance * 0.78)
		for special in specials:
			room = minf(room, (center.distance_to(special["position"]) - float(special["radius"])) * 0.72)
		var orbit_radius: float = maxf(12.0, minf(ORBIT_WORLD_RADIUS / scale * rng.randf_range(0.90, 1.10), room * 0.90))
		var phase: float = rng.randf_range(0.0, TAU)
		var node: Vector2 = center + Vector2.from_angle(phase) * orbit_radius * 0.45
		var rate: float = rng.randf_range(0.0015, 0.0035) * (1.0 if rng.randf() < 0.5 else -1.0)
		rings.append({"position": node, "radius": orbit_radius * 1.75, "anchor": anchor, "access": [anchor],
			"orbit_center": center, "orbit_radius": orbit_radius, "orbit_rate": rate,
			"Metals": rng.randf_range(1.0, 2.0), "Crystals": rng.randf_range(1.0, 2.0)})
	# Keep ring indices aligned with systems; shift legacy static-site edges.
	for edge in field_edges:
		edge[0] += rings.size()
		edge[1] += rings.size()
	fields = rings + fields
	for index in range(points.size()):
		points[index] *= scale
	for field in fields:
		field["position"] = (field["position"] as Vector2) * scale
		field["radius"] = float(field["radius"]) * scale
		if field.has("orbit_center"):
			field["orbit_center"] = (field["orbit_center"] as Vector2) * scale
			field["orbit_radius"] = float(field["orbit_radius"]) * scale
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

# Existing seeded spin is uniform and immutable: use it to assign each
# rock to one of three mixed-speed cohorts without new RNG or wire state.
static func asteroid_orbit_group(rock: Dictionary) -> int:
	return clampi(floori(float(rock.get("rotation", 0.0)) / TAU * 3.0), 0, 2)

static func asteroid_orbit_transforms(field: Dictionary, elapsed: float) -> Array[Transform2D]:
	var transforms: Array[Transform2D] = []
	if not field.has("orbit_center"):
		return transforms
	var phase: float = maxf(0.0, elapsed) * float(field["orbit_rate"])
	var center: Vector2 = field["orbit_center"]
	for factor in [0.9, 1.0, 1.1]:
		transforms.append(Transform2D(fposmod(phase * float(factor), TAU), center))
	return transforms

static func asteroid_orbit_position(rock: Dictionary, transforms: Array[Transform2D]) -> Vector2:
	if transforms.is_empty() or not rock.has("orbit_offset"):
		return rock["position"]
	return transforms[asteroid_orbit_group(rock)] * (rock["orbit_offset"] as Vector2)

# Authority and compact replica keep the same inexpensive coarse updates.
# Presentation evaluates these same transforms at the continuous planet clock.
static func update_asteroid_orbits(map_data: Dictionary, elapsed: float) -> void:
	var time: float = floorf(maxf(0.0, elapsed) / ASTEROID_ORBIT_STEP + 0.00001) * ASTEROID_ORBIT_STEP
	for field in map_data.get("fields", []):
		if not field.has("orbit_center"):
			continue
		var transforms: Array[Transform2D] = asteroid_orbit_transforms(field, time)
		for rock in field.get("chunks", []):
			rock["position"] = asteroid_orbit_position(rock, transforms)

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
	var orbital: bool = field.has("orbit_center")
	if not special:
		count = rng.randi_range(ORBIT_ROCK_MIN, ORBIT_ROCK_MAX) if orbital else rng.randi_range(32, 44)
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
		var distance: float = sqrt(rng.randf()) * (0.52 if special else 0.59 * ASTEROID_CLUSTER_SCALE)
		var offset: Vector2 = (Vector2.from_angle(angle) * Vector2(1.0, flatten) * radius * distance).rotated(rotation)
		var rock_radius: float = radius
		if orbital:
			# Stratify angle with jitter, and scatter across a thick annulus.
			var theta: float = rotation + TAU * (float(i) + rng.randf_range(-0.36, 0.36)) / float(count)
			var orbit_radius: float = float(field["orbit_radius"])
			offset = (field["orbit_center"] as Vector2) - center + Vector2.from_angle(theta) * orbit_radius * rng.randf_range(0.87, 1.13)
			rock_radius = maxf(orbit_radius, 1450.0)
		elif not lobes.is_empty():
			var lobe: Dictionary = lobes[i % lobes.size()]
			rock_radius = float(lobe["radius"])
			# Best of several seeded samples avoids rock piles while keeping
			# an organic distribution instead of an artificial grid.
			var best_clearance: float = -1.0
			for attempt in range(6):
				var trial: Vector2 = (lobe["position"] as Vector2) - center + Vector2.from_angle(rng.randf_range(0.0, TAU)) * sqrt(rng.randf()) * rock_radius * 0.89 * (1.0 if special else ASTEROID_CLUSTER_SCALE)
				var clearance: float = INF
				for existing in chunks:
					clearance = minf(clearance, (center + trial).distance_to(existing["position"]) - (float(existing["radius"]) if special else minf(float(existing["radius"]) * ASTEROID_RADIUS_SCALE, ASTEROID_MAX_RADIUS)))
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
	# Apply the visual/harvesting radius reduction after placement; the tighter
	# cluster sampling above does not change counts, RNG draws or resource quantities.
	if not special:
		for chunk in chunks:
			var original: float = float(chunk["radius"])
			# Vary the ceiling using an existing seeded angle, avoiding a pile
			# of identically sized max-radius rocks without consuming RNG.
			var cap: float = ASTEROID_MAX_RADIUS * lerpf(0.5, 1.0, float(chunk["rotation"]) / TAU)
			chunk["radius"] = minf(original * ASTEROID_RADIUS_SCALE, cap)
			if orbital:
				chunk["orbit_offset"] = (chunk["position"] as Vector2) - (field["orbit_center"] as Vector2)
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
	if orbital:
		rock_extent = maxf(rock_extent, center.distance_to(field["orbit_center"]) + float(field["orbit_radius"]) * 1.16 + ASTEROID_MAX_RADIUS)
	for chunk in chunks:
		rock_extent = maxf(rock_extent, center.distance_to(chunk["position"]) + float(chunk["radius"]))
	field["rock_extent"] = rock_extent
	field["chunks"] = chunks

static func blocked(a: Vector2, b: Vector2, fields: Array) -> bool:
	for field in fields:
		if not bool(field.get("antimatter", false)):
			continue
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
