extends RefCounted
## Immutable clipped Voronoi geometry. Site IDs match the system/field/highway
## influence layout. All coordinates are world-space; no scene or state dependency.
const EPS: float = 0.001

static func build(points: Array, edges: Array, layout: Dictionary, extent: Vector2) -> Dictionary:
	var sites: Array[Vector2] = []
	for point in points:
		sites.append(point)
	for i in range(edges.size()):
		var a: Vector2 = points[int(edges[i][0])]
		var b: Vector2 = points[int(edges[i][1])]
		var count: int = int(layout["counts"][i])
		for section in range(count):
			var site: Vector2 = a.lerp(b, (float(section) + 0.5) / float(count))
			# Crossing highways can have coincident midpoints. Preserve stable IDs.
			while sites.has(site):
				site += Vector2(0.05, 0.03)
			sites.append(site)
	var polygons: Array[PackedVector2Array] = []
	var bounds: Array[Rect2] = []
	for i in range(sites.size()):
		var polygon := PackedVector2Array([Vector2.ZERO, Vector2(extent.x, 0), extent, Vector2(0, extent.y)])
		for j in range(sites.size()):
			if i == j:
				continue
			var difference: Vector2 = sites[j] - sites[i]
			if difference.is_zero_approx():
				if j < i:
					polygon.clear()
					break
				continue
			polygon = _clip(polygon, (sites[i] + sites[j]) * 0.5, difference.normalized())
			if polygon.is_empty():
				break
		polygons.append(polygon)
		var box := Rect2()
		if not polygon.is_empty():
			box = Rect2(polygon[0], Vector2.ZERO)
			for point in polygon:
				box = box.expand(point)
		bounds.append(box)
	var borders: Array[Dictionary] = []
	var links: Array[Vector2i] = []
	var linked: Dictionary = {}
	for i in range(polygons.size()):
		var polygon: PackedVector2Array = polygons[i]
		for k in range(polygon.size()):
			var a: Vector2 = polygon[k]
			var b: Vector2 = polygon[(k + 1) % polygon.size()]
			if a.distance_squared_to(b) <= EPS * EPS:
				continue
			var midpoint: Vector2 = (a + b) * 0.5
			var neighbor: int = -1
			var closest: float = 0.05
			for j in range(sites.size()):
				if i == j or polygons[j].is_empty():
					continue
				var normal: Vector2 = (sites[j] - sites[i]).normalized()
				var distance: float = absf((midpoint - (sites[j] + sites[i]) * 0.5).dot(normal))
				if distance < closest:
					closest = distance
					neighbor = j
			if neighbor >= 0 and neighbor < i:
				continue
			borders.append({"a": a, "b": b, "left": i, "right": neighbor})
			if neighbor >= 0:
				var pair := Vector2i(i, neighbor)
				if not linked.has(pair):
					linked[pair] = true
					links.append(pair)
	return {"sites": sites, "polygons": polygons, "bounds": bounds, "borders": borders, "links": links, "extent": extent}

static func _clip(polygon: PackedVector2Array, midpoint: Vector2, normal: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	if polygon.is_empty():
		return result
	var previous: Vector2 = polygon[-1]
	var previous_distance: float = (previous - midpoint).dot(normal)
	for point in polygon:
		var distance: float = (point - midpoint).dot(normal)
		if (distance <= 0.0) != (previous_distance <= 0.0):
			_append_distinct(result, previous.lerp(point, previous_distance / (previous_distance - distance)))
		if distance <= 0.0:
			_append_distinct(result, point)
		previous = point
		previous_distance = distance
	if result.size() > 1 and result[0].distance_squared_to(result[-1]) <= EPS * EPS:
		result.remove_at(result.size() - 1)
	return result

static func _append_distinct(polygon: PackedVector2Array, point: Vector2) -> void:
	if polygon.is_empty() or polygon[-1].distance_squared_to(point) > EPS * EPS:
		polygon.append(point)

static func region_at(geometry: Dictionary, point: Vector2) -> int:
	if not point.is_finite() or not Rect2(Vector2.ZERO, geometry["extent"]).has_point(point):
		return -1
	var best: float = INF
	var result: int = -1
	var sites: Array = geometry["sites"]
	for i in range(sites.size()):
		var distance: float = point.distance_squared_to(sites[i])
		if distance < best:
			best = distance
			result = i
	return result

# Reject any segment that touches a non-permitted cell. Exact convex polygon
# intersection, not periodic samples that could miss a narrow hostile wedge.
static func segment_allowed(geometry: Dictionary, origin: Vector2, destination: Vector2, allowed: Dictionary) -> bool:
	var first: int = region_at(geometry, origin)
	var last: int = region_at(geometry, destination)
	if not allowed.has(first) or not allowed.has(last):
		return false
	var segment_box := Rect2(origin, Vector2.ZERO).expand(destination).grow(EPS)
	var polygons: Array = geometry["polygons"]
	for i in range(polygons.size()):
		if allowed.has(i) or not (geometry["bounds"][i] as Rect2).intersects(segment_box, true):
			continue
		var polygon: PackedVector2Array = polygons[i]
		if polygon.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(origin, polygon) or Geometry2D.is_point_in_polygon(destination, polygon):
			return false
		for k in range(polygon.size()):
			if Geometry2D.segment_intersects_segment(origin, destination, polygon[k], polygon[(k + 1) % polygon.size()]) != null:
				return false
	return true
