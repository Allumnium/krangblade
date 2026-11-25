extends RefCounted
## Per-substep working set shared by the EconomyRules.step stages.
## Created and discarded inside one step call; never serialized.

var profile: Dictionary = {}
var civilian_usec: int = 0
# Motion-only sleep fast path; diagnostics are not authoritative state.
var motion_sleep_enabled: bool = false
var motion_sleep_skips: int = 0
var direct_order_dispatches: int = 0
var deadline_schedule_enabled: bool = false
var persistent_avoidance_enabled: bool = false
var persistent_combat_enabled: bool = false
var persistent_logistics_enabled: bool = false

# Routing and civilian caches valid for this substep.
var graph: Dictionary = {}
var teams: Array[int] = []
var cache: Dictionary = {}
var budgets: Array = []

# Salvage and resource handoff indices built after combat.
var salvage_busy: Dictionary = {}
var salvage_cells: Dictionary = {}
var salvage_threats: Dictionary = {}
# Ordered survivor subsets built once after combat, before resource handoffs.
# Entries are live references; no membership changes before fleet allocation.
var handoff_receivers: Dictionary = {}
var handoff_miners: Array = []
var freighters: Array = []
var military_fleets: Dictionary = {}
var mining_receivers: Dictionary = {}
var mining_commitments: Dictionary = {}

# Formation and service lookups built before hull work.
var combat_positions: Dictionary = {}
var idle_targets: Dictionary = {}
var coordinated: Dictionary = {}
var service_refs: Dictionary = {}
var damaged_cells: Dictionary = {}
# Frozen repair candidates only; target damage and friendliness stay live.
var repair_neighborhoods: Dictionary = {}

# Movement settlement inputs gathered during hull work.
var repaired_hulls: Dictionary = {}
var repair_parked: Dictionary = {}
var wander_candidates: Dictionary = {}

# Retain ordered bucket arrays while rebuilding the exact key-order view.
# The returned view is valid only until the next begin on this index.
class OrderedHullBuckets:
	var _retained: Dictionary = {}
	var _active: Dictionary = {}
	var _counts: Dictionary = {}

	func clear() -> void:
		_retained.clear()
		_active = {}
		_counts.clear()

	func begin() -> void:
		_active = {}
		_counts.clear()

	func append(key: Variant, hull: Variant) -> void:
		var slot: int = int(_counts.get(key, 0))
		if slot == 0:
			if not _retained.has(key):
				_retained[key] = []
			_active[key] = _retained[key]
		var bucket: Array = _active[key]
		if slot == bucket.size():
			bucket.append(hull)
		elif not is_same(bucket[slot], hull):
			bucket[slot] = hull
		_counts[key] = slot + 1

	# Ordered handoff entries wrap a live hull reference. Compare both
	# order and identity, not dictionary value equality.
	func append_ordered_hull(key: Variant, order: int, hull: Dictionary) -> void:
		var slot: int = int(_counts.get(key, 0))
		if slot == 0:
			if not _retained.has(key):
				_retained[key] = []
			_active[key] = _retained[key]
		var bucket: Array = _active[key]
		if slot == bucket.size():
			bucket.append([order, hull])
		else:
			var entry: Array = bucket[slot]
			if entry[0] != order or not is_same(entry[1], hull):
				bucket[slot] = [order, hull]
		_counts[key] = slot + 1

	func finish() -> Dictionary:
		for key in _retained.keys():
			var count: int = int(_counts.get(key, 0))
			if count == 0:
				_retained.erase(key)
			else:
				var bucket: Array = _retained[key]
				if bucket.size() != count:
					bucket.resize(count)
		return _active

# Timestamp-bucket calendar. Equal deadlines share a bucket; rescheduling
# replaces the old entry rather than accumulating stale heap nodes. Only
# inspect buckets when the earliest deadline changes or becomes due.
class DeadlineCalendar:
	var _by_key: Dictionary = {}
	var _buckets: Dictionary = {}
	var _earliest: float = INF
	var _dirty_minimum: bool = false

	func size() -> int:
		return _by_key.size()

	func clear() -> void:
		_by_key.clear()
		_buckets.clear()
		_earliest = INF
		_dirty_minimum = false

	func cancel(key: Variant) -> void:
		if not _by_key.has(key):
			return
		var old: float = float(_by_key[key])
		_by_key.erase(key)
		var bucket: Dictionary = _buckets[old]
		bucket.erase(key)
		if bucket.is_empty():
			_buckets.erase(old)
			if old == _earliest:
				_dirty_minimum = true

	func schedule(key: Variant, timestamp: float) -> void:
		if _by_key.has(key) and float(_by_key[key]) == timestamp:
			return
		cancel(key)
		_by_key[key] = timestamp
		if not _buckets.has(timestamp):
			_buckets[timestamp] = {}
		_buckets[timestamp][key] = true
		if timestamp < _earliest:
			_earliest = timestamp
			_dirty_minimum = false

	func _refresh_minimum() -> void:
		if not _dirty_minimum:
			return
		_earliest = INF
		for timestamp in _buckets:
			_earliest = minf(_earliest, float(timestamp))
		_dirty_minimum = false

	func take_due(now: float, lifetime: float = 0.0, strict_age: bool = false) -> Array:
		var due: Array = []
		_refresh_minimum()
		while not _buckets.is_empty():
			var ready: bool = now - _earliest > lifetime if strict_age else _earliest <= now
			if not ready:
				break
			var bucket: Dictionary = _buckets[_earliest]
			for key in bucket:
				due.append(key)
				_by_key.erase(key)
			_buckets.erase(_earliest)
			_dirty_minimum = true
			_refresh_minimum()
		return due

# Frozen contact workload. Dense slots follow the authoritative roster order;
# no entity Dictionary is read by the pair kernel. The owner reuses this
# buffer at the original separation/contact boundary and commits corrections
# through the existing movement rules. Never serialize or share across workers.
class ContactBatch:
	var ids := PackedInt64Array()
	var positions := PackedVector2Array()
	var previous := PackedVector2Array()
	var corrections := PackedVector2Array()
	var touched := PackedByteArray()
	var correction_order: Array[int] = []

	func begin(count: int) -> void:
		ids.resize(count)
		positions.resize(count)
		previous.resize(count)
		corrections.resize(count)
		touched.resize(count)

	func set_pose(slot: int, id: int, point: Vector2, before: Vector2) -> void:
		ids[slot] = id
		positions[slot] = point
		previous[slot] = before

	# Keep x/y cell and roster traversal order, including first-touch order.
	# Share candidate bucket lists for all slots in a cell; the bounding-box
	# check still uses each hull's exact position.
	func accumulate(cells: Dictionary, bounds: Dictionary, reach: float, epsilon: float) -> void:
		corrections.fill(Vector2.ZERO)
		touched.fill(0)
		correction_order.clear()
		var neighborhoods: Dictionary = {}
		var cutoff_squared: float = (reach - epsilon) * (reach - epsilon)
		var margin: float = maxf(0.001, cutoff_squared * 0.0001)
		for i in range(positions.size()):
			var pa: Vector2 = positions[i]
			var cell := Vector2i(floori(pa.x / reach), floori(pa.y / reach))
			if not neighborhoods.has(cell):
				var buckets: Array = []
				for x in range(-1, 2):
					for y in range(-1, 2):
						var key: Vector2i = cell + Vector2i(x, y)
						if bounds.has(key):
							buckets.append([bounds[key], cells[key]])
				neighborhoods[cell] = buckets
			for bucket in neighborhoods[cell]:
				var box: Rect2 = bucket[0]
				if pa.distance_squared_to(pa.clamp(box.position, box.end)) > cutoff_squared + margin:
					continue
				for j in bucket[1]:
					if int(j) <= i:
						continue
					var offset: Vector2 = pa - positions[j]
					if offset.length_squared() >= cutoff_squared:
						continue
					var distance: float = offset.length()
					var direction: Vector2
					if distance <= epsilon:
						var prior: Vector2 = previous[i] - previous[j]
						direction = prior.normalized().orthogonal() if prior.length_squared() > epsilon else Vector2.from_angle(float(posmod(ids[i] * 97 + ids[j] * 193, 360)) * PI / 180.0)
					else:
						direction = offset / distance
					var push: Vector2 = direction * (reach - distance) * 0.12
					if touched[i] == 0:
						touched[i] = 1
						correction_order.append(i)
					if touched[j] == 0:
						touched[j] = 1
						correction_order.append(int(j))
					corrections[i] += push
					corrections[j] -= push
