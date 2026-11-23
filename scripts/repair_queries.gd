extends RefCounted
## Pure repair search queries; authority, movement and mutation remain in EconomyRules.
## Keep dictionary iteration order and equal-distance target ordering unchanged.

static func is_damaged(target: Dictionary, epsilon: float) -> bool:
	return not target.is_empty() and float(target["entity"].get("hp", target["max_hp"])) < float(target["max_hp"]) - epsilon

static func damaged_cells(targets: Dictionary, width: float, epsilon: float) -> Dictionary:
	var cells: Dictionary = {}
	var order: int = 0
	for id in targets:
		var ref: Dictionary = targets[id]
		if is_damaged(ref, epsilon):
			var point: Vector2 = ref.get("repair_position", ref["position"])
			var cell := Vector2i(floori(point.x / width), floori(point.y / width))
			if not cells.has(cell):
				cells[cell] = []
			cells[cell].append([order, id])
		order += 1
	return cells

static func nearby_ids(cells: Dictionary, point: Vector2, width: float) -> Array:
	var cell := Vector2i(floori(point.x / width), floori(point.y / width))
	var entries: Array = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			entries.append_array(cells.get(cell + Vector2i(x, y), []))
	entries.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var ids: Array = []
	for entry in entries:
		ids.append(entry[1])
	return ids

static func retry_due(ship: Dictionary, now: float, epsilon: float) -> bool:
	return now + epsilon >= float(ship.get("_next_repair_search", 0.0))
