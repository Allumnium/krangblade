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
var mining_receivers: Dictionary = {}
var mining_commitments: Dictionary = {}

# Formation and service lookups built before hull work.
var combat_positions: Dictionary = {}
var idle_targets: Dictionary = {}
var coordinated: Dictionary = {}
var service_refs: Dictionary = {}
var damaged_cells: Dictionary = {}

# Movement settlement inputs gathered during hull work.
var repaired_hulls: Dictionary = {}
var repair_parked: Dictionary = {}
var wander_candidates: Dictionary = {}
