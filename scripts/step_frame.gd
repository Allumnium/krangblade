extends RefCounted
## Per-substep working set shared by the EconomyRules.step stages.
## Created and discarded inside one step call; never serialized.

var profile: Dictionary = {}
var civilian_usec: int = 0

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
