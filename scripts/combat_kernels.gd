extends RefCounted
## Ordered combat target kernels and simultaneous damage accumulation.
## No state ownership, scene dependencies or cache lifetime changes.

static func ship_hit(damage: Dictionary, killed_by: Dictionary, health: Dictionary, target: int, attacker: Dictionary, amount: float, hull_slots: Dictionary, hull_health: PackedFloat64Array, epsilon: float) -> void:
	var before: float = float(damage.get(target, 0.0))
	damage[target] = before + amount * float(attacker.get("reward_damage_multiplier", 1.0))
	var hp: float = hull_health[hull_slots[target]] if hull_slots.has(target) else float(health.get(target, INF))
	if before < hp and float(damage[target]) >= hp - epsilon:
		killed_by[target] = attacker

static func laser_blocks(candidates: Array, positions: Dictionary, include_structures: bool = false) -> Array:
	var blocks: Array = []
	var ids := PackedInt64Array()
	var points := PackedVector2Array()
	var low := Vector2.ZERO
	var high := Vector2.ZERO
	for other in candidates:
		var id: int = int(other["id"])
		if id < 0 and not include_structures:
			continue
		var point: Vector2 = positions[id]
		if ids.is_empty():
			low = point
			high = point
		else:
			low = low.min(point)
			high = high.max(point)
		ids.append(id)
		points.append(point)
		if ids.size() == 16:
			blocks.append([low, high, ids, points])
			ids = PackedInt64Array()
			points = PackedVector2Array()
	if not ids.is_empty():
		blocks.append([low, high, ids, points])
	return blocks

static func laser_block_nearest(blocks: Array, _positions: Dictionary, pos: Vector2, best: float, target: int) -> Array:
	for block in blocks:
		var low: Vector2 = block[0]
		var high: Vector2 = block[1]
		var bound: float = pos.distance_squared_to(pos.clamp(low, high))
		# Leave a conservative margin for floating-point and approximate ties.
		if bound > best + maxf(0.001, absf(best) * 0.0001):
			continue
		var ids: PackedInt64Array = block[2]
		var points: PackedVector2Array = block[3]
		for i in range(ids.size()):
			var id: int = ids[i]
			var distance: float = pos.distance_squared_to(points[i])
			if distance < best or (is_equal_approx(distance, best) and (target < 0 or int(id) < target)):
				best = distance
				target = int(id)
	return [best, target]

static func missile_block_nearest(blocks: Array, _positions: Dictionary, pos: Vector2, best: float, target: int, focused: bool, focus_id: int) -> Array:
	for block in blocks:
		var low: Vector2 = block[0]
		var high: Vector2 = block[1]
		var bound: float = pos.distance_squared_to(pos.clamp(low, high))
		if bound > best + maxf(0.001, absf(best) * 0.0001):
			continue
		var ids: PackedInt64Array = block[2]
		var points: PackedVector2Array = block[3]
		for i in range(ids.size()):
			var id: int = ids[i]
			if focused and int(id) != focus_id:
				continue
			var distance: float = pos.distance_squared_to(points[i])
			if distance <= best:
				best = distance
				target = int(id)
	return [best, target]
