extends RefCounted
## Per-match interpolation, heading smoothing and world pose cache.
## Reads snapshots and motion samples only; never mutates authoritative ships.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const SNAPSHOT_SECONDS: float = 0.2
const THRUST_FADE_RATE: float = 5.0
const THRUST_DEAD_ZONE: float = 0.06
const CRUISE_THRUST_MAX: float = 0.28

var pose_frame: int = -1
var pose_revision: Array = []
var pose_world_cache: Dictionary = {}
var ship_visuals: Dictionary = {}
var ship_offsets: Dictionary = {}
var sync_revision: Array = []
var active_visual_ids: Array[int] = []

func invalidate_poses() -> void:
	pose_frame = -1

func advance(delta: float) -> void:
	if delta <= 0.0 or active_visual_ids.is_empty():
		return
	var remaining: Array[int] = []
	for id in active_visual_ids:
		if not ship_visuals.has(id):
			continue
		var visual: Dictionary = ship_visuals[id]
		var duration: float = float(visual.get("duration", SNAPSHOT_SECONDS))
		if float(visual["age"]) < duration:
			visual["age"] = minf(duration, float(visual["age"]) + delta)
		# Acceleration flare decays after interpolation; cruise intensity
		# remains until a new authoritative velocity sample changes it.
		var thrust: float = float(visual.get("thrust", 0.0)) * exp(-delta * THRUST_FADE_RATE)
		visual["thrust"] = thrust
		if float(visual["age"]) < duration or thrust > 0.001:
			remaining.append(id)
		else:
			visual["thrust"] = 0.0
	active_visual_ids = remaining

func world_position(ship: Dictionary, points: Array, session: Node) -> Vector2:
	var visual: Dictionary = ship_visuals.get(int(ship["id"]), {})
	return _ship_position(ship, points, session) if visual.is_empty() else _visual_position(visual)

# Cruise intensity scales with observed speed; suppress tiny corrections.
static func cruise_thrust(speed_ratio: float) -> float:
	return CRUISE_THRUST_MAX * smoothstep(0.04, 0.55, speed_ratio)

func thrust_for(id: int) -> float:
	var visual: Dictionary = ship_visuals.get(id, {})
	var cruise: float = float(visual.get("cruise", 0.0))
	# Blend the transient acceleration flare above the sustained baseline.
	return lerpf(cruise, 1.0, clampf(float(visual.get("thrust", 0.0)), 0.0, 1.0))

func target_position(id: int) -> Vector2:
	var visual: Dictionary = ship_visuals.get(id, {})
	return visual.get("to", Vector2.INF)

func sync(state: Dictionary, session: Node) -> void:
	var signature: Array = [
		session.get("motion_revision"),
		session.get("motion_base_revision"),
		state.get("elapsed"),
		state.get("ships", []).size(),
		state.get("time_speed"),
		session.get("diagnostic_motion_gap_ms"),
	]
	if signature == sync_revision:
		return
	sync_revision = signature
	var updated: Dictionary = {}
	var next_active_ids: Array[int] = []
	if not state.is_empty():
		var points: Array = state["map"]["points"]
		var samples: Dictionary = session.get("motion_samples")
		var guest: bool = not bool(session.get("is_solo")) and not session.multiplayer.is_server()
		var duration: float = clampf(float(session.get("diagnostic_motion_gap_ms")) / 1000.0 * 1.2, 0.1, 0.3) if guest else SNAPSHOT_SECONDS
		for ship in state["ships"]:
			var id: int = int(ship["id"])
			var sample: Dictionary = samples.get(id, {})
			var target: Vector2 = sample.get("position", _ship_position(ship, points, session))
			var heading: Vector2 = sample.get("heading", ship.get("heading", Vector2.UP))
			var previous: Dictionary = ship_visuals.get(id, {})
			var interval: float = duration if not sample.is_empty() else SNAPSHOT_SECONDS
			# Authority revisions, not frame/packet-arrival timing, keep the
			# acceleration estimate stable across rendering rates and peers.
			var revision: int = int(sample.get("revision", session.get("motion_base_revision") if guest else session.get("motion_revision")))
			var speed: int = int(state.get("time_speed", 1))
			if previous.is_empty():
				updated[id] = {"from": target, "to": target, "age": interval, "duration": interval, "heading": heading, "motion_revision": revision, "motion_point": target, "motion_speed": speed, "velocity": Vector2.ZERO, "thrust": 0.0, "cruise": 0.0}
				continue
			var prior_revision: int = int(previous.get("motion_revision", revision))
			if speed <= 0 or int(previous.get("motion_speed", speed)) != speed or revision < prior_revision:
				previous["velocity"] = Vector2.ZERO
				previous["thrust"] = 0.0
				previous["cruise"] = 0.0
				previous["motion_speed"] = speed
				previous["motion_revision"] = revision
				previous["motion_point"] = target
			elif revision > prior_revision:
				var sample_dt: float = float(revision - prior_revision) * 0.1 * float(speed)
				var velocity: Vector2 = (target - (previous.get("motion_point", target) as Vector2)) / maxf(0.1, sample_dt)
				var old_velocity: Vector2 = previous.get("velocity", Vector2.ZERO)
				var nominal: float = maxf(1.0, ECONOMY.ship_speed(str(ship["kind"])))
				var delta_velocity: Vector2 = velocity - old_velocity
				# Forward acceleration drives the main plume. Turning gets
				# a smaller burst; braking and tiny position corrections do not.
				var axis: Vector2 = velocity.normalized()
				var forward_accel: float = maxf(0.0, delta_velocity.dot(axis))
				var turning: float = absf(delta_velocity.cross(axis)) * 0.30
				var impulse: float = (forward_accel + turning) * SNAPSHOT_SECONDS / (nominal * maxf(0.1, sample_dt))
				var thrust: float = smoothstep(THRUST_DEAD_ZONE, 0.75, clampf(impulse, 0.0, 1.0))
				var speed_ratio: float = velocity.length() / nominal
				thrust *= smoothstep(0.04, 0.25, speed_ratio)
				previous["cruise"] = cruise_thrust(speed_ratio)
				previous["thrust"] = maxf(float(previous.get("thrust", 0.0)), thrust) if speed_ratio > 0.04 else 0.0
				previous["velocity"] = velocity
				previous["motion_revision"] = revision
				previous["motion_point"] = target
			previous["motion_speed"] = speed
			if previous["to"] != target:
				previous["from"] = _visual_position(previous)
				previous["to"] = target
				previous["age"] = 0.0
				previous["duration"] = interval
			previous["heading"] = heading
			updated[id] = previous
			if float(previous["age"]) < float(previous["duration"]) or float(previous.get("thrust", 0.0)) > 0.001:
				next_active_ids.append(id)
	ship_visuals = updated
	active_visual_ids = next_active_ids
	for id in ship_offsets.keys():
		if not updated.has(id):
			ship_offsets.erase(id)

# projection, when supplied, is [half_size, world_center, fit, zoom] and
# reproduces screen_point arithmetic without a call per hull.
func poses(state: Dictionary, delta: float, session: Node, ship_visible: Callable, screen_point: Callable, projection: Array = []) -> Dictionary:
	var frame: int = Engine.get_process_frames()
	var revision: Array = [session.get("motion_revision"), session.get("motion_base_revision"), state.get("elapsed"), state["ships"].size(), state.get("time_speed")]
	if delta <= 0.0 and pose_frame == frame and pose_revision == revision:
		return pose_world_cache
	sync(state, session)
	var points: Array = state["map"]["points"]
	var poses: Dictionary = {}
	var weight: float = 1.0 - exp(-delta / SNAPSHOT_SECONDS * 3.0)
	var projected: bool = projection.size() == 4
	var half_size: Vector2 = projection[0] if projected else Vector2.ZERO
	var world_center: Vector2 = projection[1] if projected else Vector2.ZERO
	var fit: float = projection[2] if projected else 1.0
	var zoom: float = projection[3] if projected else 1.0
	for ship in state["ships"]:
		if not ship_visible.call(state, ship):
			continue
		var id: int = int(ship["id"])
		var visual: Dictionary = ship_visuals.get(id, {})
		var pos: Vector2 = _ship_position(ship, points, session) if visual.is_empty() else _visual_position(visual)
		var direction: Vector2 = visual.get("heading", ship.get("heading", Vector2.UP))
		var target_angle: float = direction.angle()
		var angle: float = lerp_angle(float(ship_offsets.get(id, target_angle)), target_angle, weight)
		if delta > 0.0 or not ship_offsets.has(id):
			ship_offsets[id] = angle
		var mining: bool = ship.get("kind", "") == "miner" and ship.get("mining_mode", "idle") in ["outbound", "mining", "return"]
		var point: Vector2 = half_size + (pos - world_center) * fit * zoom if projected else screen_point.call(pos)
		poses[id] = {"point": point, "world": pos, "direction": Vector2.from_angle(angle), "mining": mining, "kind": ship.get("kind", ""), "owner": int(ship["owner"])}
	pose_frame = frame
	pose_revision = revision
	pose_world_cache = poses
	return poses

func _ship_position(ship: Dictionary, _points: Array, session: Node) -> Vector2:
	if ship.has("position"):
		return ship["position"]
	return ECONOMY.combat_position(session.get("economy"), ECONOMY.military_graph(session.get("economy")), ship)

func _visual_position(visual: Dictionary) -> Vector2:
	var duration: float = float(visual.get("duration", SNAPSHOT_SECONDS))
	return (visual["from"] as Vector2).lerp(visual["to"], clampf(float(visual["age"]) / duration, 0.0, 1.0))
