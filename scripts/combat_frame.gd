extends RefCounted
## Frozen combat snapshot shared by the EconomyRules combat phases.
## Built and consumed within a single _combat call; never stored or replicated.

# Hull and structure lookups (structures use negative target IDs).
var positions: Dictionary = {}
var by_id: Dictionary = {}
var team_by_id: Dictionary = {}
var health: Dictionary = {}
var yard_targets: Dictionary = {}
var station_targets: Dictionary = {}

# Dense per-hull arrays indexed by hull_slots[id], in state["ships"] order.
var hull_slots: Dictionary = {}
var hull_positions := PackedVector2Array()
var hull_health := PackedFloat64Array()
var hull_teams := PackedInt32Array()
var previous_targets := PackedInt64Array()
var ship_sectors := PackedInt32Array()

# Spatial buckets: combat cells (LASER_RANGE) and physical sectors.
var cells: Dictionary = {}
var sectors: Dictionary = {}
var sector_teams: Dictionary = {}

# Lazily filled per-team target caches.
var hostile_cache: Dictionary = {}
var positive_hostile_cache: Dictionary = {}
var sector_hostile_cache: Dictionary = {}
var laser_blocks: Dictionary = {}
var missile_blocks: Dictionary = {}
var pursuit_blocks: Dictionary = {}

# Simultaneous damage accumulation and lethal-hit attribution.
var damage: Dictionary = {}
var killed_by: Dictionary = {}

func sector_of(id: int) -> int:
	return ship_sectors[hull_slots[id]] if hull_slots.has(id) else -1
