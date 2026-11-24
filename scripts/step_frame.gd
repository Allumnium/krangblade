extends RefCounted
## Per-substep working set shared by the EconomyRules.step stages.
## Created and discarded inside one step call; never serialized.

var profile: Dictionary = {}
var civilian_usec: int = 0
# Motion-only sleep fast path; diagnostics are not authoritative state.
var motion_sleep_enabled: bool = false
var motion_sleep_skips: int = 0
var deadline_schedule_enabled: bool = false

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
