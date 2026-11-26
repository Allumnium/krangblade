extends SceneTree
const ECON = preload("res://scripts/economy_rules.gd")
const MAP = preload("res://scripts/planet_map.gd")
const WORKER = preload("res://scripts/authority_worker.gd")

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("Authority worker: " + message)

func _await_result(worker: RefCounted) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		var result: Dictionary = worker.call("take_result")
		if not result.is_empty():
			return result
		await process_frame
	_check(false, "worker result timed out")
	return {}

func _await_idle(session: Node) -> bool:
	var deadline: int = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		var worker: RefCounted = session.get("_authority_worker")
		if not bool(worker.call("busy")) and (session.get("_authority_jobs") as Array).is_empty():
			return true
		await process_frame
	_check(false, "session command queue timed out")
	return false

func _roster() -> Dictionary:
	return {1: {"name": "Host", "team": 1, "ready": true, "color": 1}, 2: {"name": "Guest", "team": 2, "ready": true, "color": 2}}

func _reference_tick(state: Dictionary, dt: float) -> void:
	state["objective_clock"] = float(state.get("objective_clock", 0.0)) + dt
	for i in range(int(state["time_speed"])):
		if ECON.advance_authority_substep(state, dt) and not state["match_result"].is_empty():
			break

func _run() -> void:
	var roster: Dictionary = _roster()
	var initial: Dictionary = ECON.create(MAP.generate(827, 2, "Grid"), roster, [1, 2])
	ECON.initialize_diplomacy(initial)
	initial["time_speed"] = 5
	initial["match_result"] = {}
	initial["eliminated"] = []
	var reference: Dictionary = initial.duplicate(true)
	var worker = WORKER.new()
	if not worker.start(initial):
		_check(false, "isolated worker could not start")
		quit(1)
		return
	# A group command before the first tick must use the private roster and
	# match the public full scan, regardless of requested-ID order.
	var ids: Array = []
	for craft in initial["ships"]:
		if int(craft["owner"]) == 1 and craft["kind"] == "fighter":
			ids.push_front(craft["id"])
	_check(ids.size() == 2, "group command fixture missing fighters")
	_check(worker.submit({"kind": "command", "method": "authority_unit_hold_for", "args": [1, ids, false]}), "initial group hold rejected")
	var held: Dictionary = await _await_result(worker)
	_check(ECON.authority_unit_hold_for(reference, 1, ids, false), "reference group hold rejected")
	_check(bool(held.get("accepted", false)) and held.get("snapshot", {}) == reference, "indexed group hold differs from public scan")
	var initial_tick: int = ECON._rock_plan_tick
	_check(worker.submit({"kind": "tick", "dt": 0.1}), "initial tick rejected")
	_check(not worker.submit({"kind": "tick", "dt": 0.1}), "second in-flight job accepted")
	# Exercise the actual main-thread cache while the simulation is running.
	ECON.military_graph(initial)
	var result: Dictionary = await _await_result(worker)
	if result.is_empty():
		worker.stop()
		quit(1)
		return
	_check(int(result["thread_id"]) != OS.get_thread_caller_id(), "simulation ran on the main thread")
	_check(ECON._rock_plan_tick == initial_tick, "simulation cache leaked into main rules")
	_reference_tick(reference, 0.1)
	_check(result["snapshot"] == reference, "5x reference state differs")
	# Neither the original dictionary nor any published copy is authoritative.
	initial["time_speed"] = 2
	result["snapshot"]["time_speed"] = 1
	var command: Dictionary = {"kind": "command", "method": "authority_time_speed_for", "args": [1, 0]}
	_check(worker.submit(command), "pause job rejected")
	command["args"][1] = 5
	result = await _await_result(worker)
	if result.is_empty():
		worker.stop()
		quit(1)
		return
	_check(bool(result["accepted"]), "pause not accepted")
	reference["time_speed"] = 0
	_check(result["snapshot"] == reference, "pause or copied command values differ")
	_check(worker.submit({"kind": "command", "method": "authority_time_speed_for", "args": [2, 5]}), "guest job not submitted")
	result = await _await_result(worker)
	_check(not bool(result.get("accepted", true)), "guest changed authority speed")
	_check(worker.submit({"kind": "tick", "dt": 0.1}), "paused tick rejected")
	result = await _await_result(worker)
	_reference_tick(reference, 0.1)
	_check(result.get("snapshot", {}) == reference, "paused objective clock or state differs")
	worker.stop()
	_check(not worker.busy(), "stop retained a busy worker")
	_check(worker.start(reference), "worker restart failed")
	_check(worker.submit({"kind": "tick", "dt": 0.1}), "restart tick rejected")
	worker.stop()
	_check(worker.take_result().is_empty(), "stopped worker exposed a stale result")

	# Actual session command routing, publication, tick queue and teardown.
	var session: Node = root.get_node("GameSession")
	_check(bool(session.get("threaded_authority_requested")), "threaded authority must be requested by default")
	session.set("is_solo", true)
	session.call("_activate_match", roster, 426)
	(session.get("economy_timer") as Timer).stop()
	_check(bool(session.get("threaded_authority_active")), "session did not activate threaded authority")
	var state_before: Dictionary = session.get("economy")
	var elapsed: float = float(state_before["elapsed"])
	var revision: int = int(session.get("snapshot_revision"))
	session.call("request_time_speed", 5)
	session.call("_economy_tick")
	session.call("request_time_speed", 0)
	if await _await_idle(session):
		var current: Dictionary = session.get("economy")
		_check(is_equal_approx(float(current["elapsed"]) - elapsed, 0.5), "FIFO speed/tick/pause ordering differs")
		_check(int(current["time_speed"]) == 0, "pause not published")
		_check(float(state_before["elapsed"]) == elapsed and int(state_before["time_speed"]) == 1, "previous snapshot mutated")
		_check(int(session.get("snapshot_revision")) >= revision + 2, "accepted commands not published")
		var clock: float = float(current.get("objective_clock", 0.0))
		session.call("_economy_tick")
		if await _await_idle(session):
			current = session.get("economy")
			_check(is_equal_approx(float(current.get("objective_clock", 0.0)) - clock, 0.1), "paused tick did not advance objective clock")
			_check(is_equal_approx(float(current["elapsed"]) - elapsed, 0.5), "paused tick advanced game time")
	session.call("_economy_tick")
	session.call("_reset_network")
	_check(not bool(session.get("threaded_authority_active")) and (session.get("economy") as Dictionary).is_empty(), "round teardown retained old state")
	session.set("is_solo", true)
	session.call("_activate_match", roster, 427)
	(session.get("economy_timer") as Timer).stop()
	_check(bool(session.get("threaded_authority_active")), "second session worker did not start")
	session.call("_economy_tick")
	if await _await_idle(session):
		_check(int(session.get("economy")["map"]["seed"]) == 427, "old-round result replaced new map")
	session.call("_reset_network")
	if not failed:
		print("PASS: actual worker thread, reference parity, detached snapshots, FIFO commands, pause and round lifecycle")
	quit(1 if failed else 0)
