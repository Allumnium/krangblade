extends RefCounted
## Per-match snapshot audio history. Reads authority snapshots; never mutates them.
## The controller supplies spatial context, visibility and the existing mixer.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const SFX = preload("res://scripts/match_sfx.gd")

var sound_elapsed: float = -1.0
var sound_destruction_sequence: int = 0
var sound_objectives: Dictionary = {}
var sound_hulls: Dictionary = {}
var sound_structures: Dictionary = {}
var known_upgrade_jobs: Dictionary = {}
var upgrade_audio_initialized: bool = false

func sync_upgrade_audio(state: Dictionary, local_player: int, sound_mixer: Node) -> void:
	var active: Dictionary = {}
	var structures: Dictionary = {}
	var added: bool = false
	var complete: bool = false
	for system_index in range(state["planets"].size()):
		var system: Dictionary = state["planets"][system_index]
		if int(system["owner"]) != local_player:
			continue
		for job in system["queue"]:
			var id: int = int(job["id"])
			active[id] = true
			if not known_upgrade_jobs.has(id):
				added = true
		var level: int = int(system.get("warehouse_level", 0)) + int(system.get("habitation_level", 0)) + int(system.get("orbital_housing", 0)) + system.get("pds", {}).size()
		for yard in system.get("yards", []):
			level += int(yard["level"])
		for resource in ECONOMY.RESOURCES:
			level += int(system.get("levels", {}).get(resource, 0)) + int(system.get("buildings", {}).get(resource, 0))
		level += int(bool(system.get("station", {}).get("reinforced_plating", false))) + int(bool(system.get("station", {}).get("laser_matrix", false)))
		structures[system_index] = level
		if level > int(sound_structures.get(system_index, -1)):
			complete = true
	var hulls: Dictionary = {}
	var ship_ready: bool = false
	for ship in state["ships"]:
		if int(ship["owner"]) == local_player:
			var id: int = int(ship["id"])
			hulls[id] = true
			if not sound_hulls.has(id):
				ship_ready = true
	if upgrade_audio_initialized:
		if added:
			sound_mixer.play_cue("queue")
		if complete:
			sound_mixer.play_cue("complete")
		if ship_ready:
			sound_mixer.play_cue("ship_ready")
	known_upgrade_jobs = active
	sound_hulls = hulls
	sound_structures = structures
	upgrade_audio_initialized = true

func sync_world_audio(state: Dictionary, local_player: int, center: Vector2, radius: float, zoom_level: float, ship_visible: Callable, sound_mixer: Node) -> void:
	var now: float = float(state["elapsed"])
	var initial: bool = sound_elapsed < 0.0
	var advanced: bool = not initial and now > sound_elapsed
	for event in state.get("ship_destructions", []):
		var sequence: int = int(event["sequence"])
		if sequence <= sound_destruction_sequence:
			continue
		sound_destruction_sequence = sequence
		if not initial:
			var gain: float = _sound_gain(event["position"], center, radius, zoom_level)
			var heavy: bool = event["kind"] in ["station", "shipyard", "cruiser", "destroyer"]
			sound_mixer.offer("heavy_explosion" if heavy else "explosion", gain)
	var notices: Dictionary = {}
	var reward_cue: String = ""
	for event in state.get("objective_events", []):
		var key: String = "%s:%s:%s" % [event["player"], event.get("objective", event.get("reward", "")), event["elapsed"]]
		notices[key] = true
		if not sound_objectives.has(key):
			var cue: String = SFX.objective_cue(event, local_player)
			reward_cue = SFX.stronger_objective_cue(reward_cue, cue)
	# A busy snapshot plays its most significant new reward once. Existing
	# notices and the initial snapshot must never replay a fanfare.
	if not reward_cue.is_empty() and not initial:
		sound_mixer.play_cue(reward_cue)
	sound_objectives = notices
	if advanced:
		# Timestamp edges, not visual-frame repeats. A sampled volley can
		# represent several actual shots between network snapshots.
		for ship in state["ships"]:
			var laser: bool = maxf(float(ship.get("laser_until", -1.0)), float(ship.get("yard_laser_until", -1.0))) > sound_elapsed + 0.2 + ECONOMY.EPS
			var blaster: bool = float(ship.get("blaster_fired", -1.0)) > sound_elapsed + ECONOMY.EPS
			var missile: bool = float(ship.get("missile_until", -1.0)) > sound_elapsed + 0.65 + ECONOMY.EPS
			var mining: bool = bool(ship.get("mining_active", false))
			var repair: bool = ship.has("repair_target")
			var tractor: bool = bool(ship.get("tractor_active", false))
			if not (laser or blaster or missile or mining or repair or tractor) or not ship_visible.call(state, ship):
				continue
			var gain: float = _sound_gain(ship["position"], center, radius, zoom_level)
			if gain < 0.035:
				continue
			if laser:
				sound_mixer.offer("laser", gain)
			if blaster:
				sound_mixer.offer("blaster", gain)
			if missile:
				sound_mixer.offer("missile", gain)
			if mining:
				sound_mixer.offer("mining", gain)
			if repair:
				sound_mixer.offer("repair", gain)
			if tractor:
				sound_mixer.offer("tractor", gain)
		for index in range(state["planets"].size()):
			if not ECONOMY.discovered(state, local_player, "planets", index):
				continue
			var system: Dictionary = state["planets"][index]
			var firing: bool = false
			for weapon in system.get("station", {}).get("weapons", []):
				if float(weapon.get("laser_until", -1.0)) > sound_elapsed + 0.2 + ECONOMY.EPS:
					firing = true
					break
			if not firing:
				for battery in system.get("pds", {}).values():
					if float(battery.get("laser_until", -1.0)) > sound_elapsed + 0.2 + ECONOMY.EPS:
						firing = true
						break
			if firing:
				sound_mixer.offer("laser", _sound_gain(state["map"]["points"][index], center, radius, zoom_level))
	sound_elapsed = now
	sound_mixer.flush()

func _sound_gain(point: Vector2, center: Vector2, radius: float, zoom_level: float) -> float:
	return SFX.spatial_gain(point.distance_to(center), radius, zoom_level)
