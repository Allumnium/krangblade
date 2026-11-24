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

static func nearby_ids(cells: Dictionary, point: Vector2, width: float, neighborhoods: Dictionary = {}) -> Array:
	# No damaged targets in the frozen service snapshot. The caller still
	# performs explicit repairs and advances unsuccessful retry deadlines.
	if cells.is_empty():
		return []
	var cell := Vector2i(floori(point.x / width), floori(point.y / width))
	if neighborhoods.has(cell):
		return neighborhoods[cell]
	var entries: Array = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			entries.append_array(cells.get(cell + Vector2i(x, y), []))
	entries.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var ids: Array = []
	for entry in entries:
		ids.append(entry[1])
	if neighborhoods.size() < 4096 and ids.size() <= 256:
		neighborhoods[cell] = ids
	return ids

# Keep only damaged ID/order records and sorted neighborhood candidates.
# The caller refreshes this index at the original service snapshot boundary.
class PersistentDamagedIndex:
	var cells: Dictionary = {}
	var neighborhoods: Dictionary = {}

	func clear() -> void:
		cells.clear()
		neighborhoods.clear()

	func _invalidate(cell: Vector2i) -> void:
		for x in range(-1, 2):
			for y in range(-1, 2):
				neighborhoods.erase(cell + Vector2i(x, y))

	func refresh(targets: Dictionary, width: float, epsilon: float, damaged: Callable) -> void:
		var counts: Dictionary = {}
		var changed: Dictionary = {}
		var order: int = 0
		for id in targets:
			var ref: Dictionary = targets[id]
			if not damaged.call(ref, epsilon):
				order += 1
				continue
			var point: Vector2 = ref.get("repair_position", ref["position"])
			var cell := Vector2i(floori(point.x / width), floori(point.y / width))
			var slot: int = int(counts.get(cell, 0))
			if not cells.has(cell):
				cells[cell] = []
			var bucket: Array = cells[cell]
			if slot == bucket.size():
				bucket.append([order, id])
				changed[cell] = true
			else:
				var entry: Array = bucket[slot]
				if entry[0] != order or entry[1] != id:
					bucket[slot] = [order, id]
					changed[cell] = true
			counts[cell] = slot + 1
			order += 1
		for cell in cells.keys():
			var count: int = int(counts.get(cell, 0))
			var bucket: Array = cells[cell]
			if count == 0:
				cells.erase(cell)
				changed[cell] = true
			elif count != bucket.size():
				bucket.resize(count)
				changed[cell] = true
		for cell in changed:
			_invalidate(cell)

static func retry_due(ship: Dictionary, now: float, epsilon: float) -> bool:
	return now + epsilon >= float(ship.get("_next_repair_search", 0.0))
