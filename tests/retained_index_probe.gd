extends SceneTree
const ECON = preload("res://scripts/economy_rules.gd")
const MAP = preload("res://scripts/planet_map.gd")
func median(samples: Array) -> float:
	samples.sort()
	return float(samples[samples.size() / 2])
func _initialize() -> void:
	var state: Dictionary = ECON.create(MAP.generate(827, 8, "Radial"), {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	for i in range(2000):
		state["ships"].append({"id": i + 1, "owner": 1, "kind": "fighter", "position": Vector2(i * 12, i * 4), "route": []})
	var ids: Array = [1799, 11, 1400, 25, 6, 1970, 701, 1002]
	var wanted: Dictionary = {}
	for id in ids:
		wanted[id] = true
	var expected: Array = ECON._owned_units(state, 1, ids)
	var expected_service: Dictionary = ECON.service_targets(state, -1, wanted)
	var scans: Array = []
	var direct: Array = []
	var services: Array = []
	var indexed_services: Array = []
	var index_rebuilds: Array = []
	var index_reuse: Array = []
	for trial in range(15):
		ECON._begin_deadline_schedule(state, true)
		var start: int = Time.get_ticks_usec()
		for j in range(100):
			ECON._begin_hull_index(state)
		index_rebuilds.append(float(Time.get_ticks_usec() - start) / 100.0)
		start = Time.get_ticks_usec()
		for j in range(100):
			assert(ECON._owned_units(state, 1, ids) == expected)
		scans.append(float(Time.get_ticks_usec() - start) / 100.0)
		start = Time.get_ticks_usec()
		for j in range(100):
			assert(ECON.service_targets(state, -1, wanted) == expected_service)
		services.append(float(Time.get_ticks_usec() - start) / 100.0)
		ECON._end_hull_index()
		ECON.begin_authority_hull_scope(state)
		ECON._begin_deadline_schedule(state, true)
		ECON._begin_hull_index(state)
		start = Time.get_ticks_usec()
		for j in range(100):
			ECON._begin_hull_index(state)
		index_reuse.append(float(Time.get_ticks_usec() - start) / 100.0)
		assert(ECON._hull_index_rebuilds == 1)
		start = Time.get_ticks_usec()
		for j in range(100):
			assert(ECON._owned_units(state, 1, ids) == expected)
		direct.append(float(Time.get_ticks_usec() - start) / 100.0)
		start = Time.get_ticks_usec()
		for j in range(100):
			assert(ECON.service_targets(state, -1, wanted) == expected_service)
		indexed_services.append(float(Time.get_ticks_usec() - start) / 100.0)
		ECON.end_authority_hull_scope()
	print("INDEX_BENCH ", JSON.stringify({"ships": 2000, "selected": ids.size(), "samples": 15, "iterations": 100, "units_scan_us": median(scans), "units_index_us": median(direct), "service_scan_us": median(services), "service_index_us": median(indexed_services), "index_rebuild_us": median(index_rebuilds), "index_reuse_us": median(index_reuse)}))
	quit()
