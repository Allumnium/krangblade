extends RefCounted
## Dedicated authority worker. Only value jobs/results cross the mailbox;
## no Node, SceneTree, RPC, UI callback or live authority reference crosses.
const ECON = preload("res://scripts/economy_rules.gd")

var _thread: Thread
var _rules: GDScript
var _mutex := Mutex.new()
var _wake := Semaphore.new()
var _request: Dictionary = {}
var _result: Dictionary = {}
var _stopping: bool = false
# Main-thread-only bookkeeping; never read on the worker.
var _in_flight: bool = false

func start(initial_state: Dictionary) -> bool:
	if _thread != null:
		return false
	# Initialize the immutable, stateless backend on the main thread before
	# any worker can read the shared dependency's cached reference.
	ECON.COMBAT_KERNELS.native_backend()
	if _rules == null:
		# Static simulation caches must not be shared with client read queries.
		# Dependencies have no mutable simulation caches; the optional native
		# backend is initialized above and owns no simulation state.
		_rules = ResourceLoader.load("res://scripts/economy_rules.gd", "GDScript", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
		if not _independent_rules(_rules):
			# Some engine builds may reuse cached script resources. In the
			# editor, compile an anonymous copy before starting any thread.
			_rules = null
			# A preloaded GDScript class exposes its static API, not Script
			# resource properties. Read the editor source file explicitly.
			var source: String = ""
			if FileAccess.file_exists("res://scripts/economy_rules.gd"):
				source = FileAccess.get_file_as_string("res://scripts/economy_rules.gd")
			if not source.is_empty():
				var isolated := GDScript.new()
				isolated.source_code = source
				if isolated.reload() == OK and _independent_rules(isolated):
					_rules = isolated
			if _rules == null:
				return false
	# Recreate the semaphore so a stop that interrupted work cannot leave
	# a stale wake token when restarting a later round.
	_wake = Semaphore.new()
	_request = {}
	_result = {}
	_stopping = false
	_in_flight = false
	_thread = Thread.new()
	if _thread.start(_run.bind(initial_state.duplicate(true))) != OK:
		_thread = null
		return false
	return true

func _independent_rules(candidate: GDScript) -> bool:
	if candidate == null or is_same(candidate, ECON) or not candidate.can_instantiate():
		return false
	var prior: int = ECON.swap_authority_cache_probe(827)
	var candidate_prior: int = int(candidate.call("swap_authority_cache_probe", 426))
	var observed: int = ECON.swap_authority_cache_probe(prior)
	candidate.call("swap_authority_cache_probe", candidate_prior)
	if observed != 827:
		ECON.swap_authority_cache_probe(prior)
		return false
	return true

func busy() -> bool:
	return _in_flight

func submit(job: Dictionary) -> bool:
	if _thread == null or _in_flight:
		return false
	_mutex.lock()
	_request = job.duplicate(true)
	_in_flight = true
	_mutex.unlock()
	_wake.post()
	return true

func take_result() -> Dictionary:
	if not _in_flight:
		return {}
	_mutex.lock()
	var result: Dictionary = _result
	_result = {}
	_mutex.unlock()
	if not result.is_empty():
		_in_flight = false
	return result

func stop() -> void:
	if _thread == null:
		return
	_mutex.lock()
	_stopping = true
	_request = {}
	_mutex.unlock()
	_wake.post()
	# Only round teardown joins; normal rendering never waits for work.
	_thread.wait_to_finish()
	_thread = null
	_request = {}
	_result = {}
	_in_flight = false

func _run(state: Dictionary) -> void:
	_rules.call("begin_authority_hull_scope", state)
	while true:
		_wake.wait()
		_mutex.lock()
		var stopping: bool = _stopping
		var job: Dictionary = _request
		_request = {}
		_mutex.unlock()
		if stopping:
			_rules.call("end_authority_hull_scope")
			return
		if job.is_empty():
			continue
		var result: Dictionary = _execute(state, job)
		_mutex.lock()
		if not _stopping:
			_result = result
		_mutex.unlock()

func _execute(state: Dictionary, job: Dictionary) -> Dictionary:
	var result: Dictionary = {"kind": job["kind"], "thread_id": OS.get_thread_caller_id()}
	if job["kind"] == "command":
		# The method name is selected by a server handler, not an RPC argument.
		var accepted: bool = bool(_rules.callv(str(job["method"]), [state] + job["args"]))
		result["accepted"] = accepted
		if accepted:
			result["snapshot"] = state.duplicate(true)
		return result
	var dt: float = float(job["dt"])
	state["objective_clock"] = float(state.get("objective_clock", 0.0)) + dt
	var speed: int = int(state.get("time_speed", 1))
	var profile: Dictionary = {"enabled": true}
	var urgent: Array[Dictionary] = []
	var started: int = Time.get_ticks_usec()
	var snapshot_usec: int = 0
	for i in range(speed):
		if bool(_rules.call("advance_authority_substep", state, dt, profile)):
			var urgent_copy_started: int = Time.get_ticks_usec()
			urgent.append(state.duplicate(true))
			snapshot_usec += Time.get_ticks_usec() - urgent_copy_started
			if not state["match_result"].is_empty():
				break
	result["sim_ms"] = float(Time.get_ticks_usec() - started - snapshot_usec) / 1000.0
	profile.erase("enabled")
	result["profile"] = profile
	result["speed"] = speed
	result["urgent"] = urgent
	var copy_started: int = Time.get_ticks_usec()
	result["snapshot"] = state.duplicate(true)
	snapshot_usec += Time.get_ticks_usec() - copy_started
	result["snapshot_ms"] = float(snapshot_usec) / 1000.0
	return result
