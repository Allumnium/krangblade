extends RefCounted
## Client-only alert detection and cooldowns. No authority mutations.
## Presentation owns hit rectangles, drawing, and camera navigation.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const APPROACH_RANGE: float = 1200.0
const LIFETIME_MS: int = 10000
const REPEAT_MS: int = 15000

# Read-only to the presentation layer; this tracker owns all alert mutations.
var alerts: Dictionary = {}
var _durability: Dictionary = {}
var _positions: Dictionary = {}
var _next_scan: int = 0
var _last_damage_sequence: int = 0
var _rogue_notice_total: int = 0
var _initialized: bool = false

func reset() -> void:
	alerts.clear()
	_durability.clear()
	_positions.clear()
	_next_scan = 0
	_last_damage_sequence = 0
	_rogue_notice_total = 0
	_initialized = false

func sync(state: Dictionary, player: int, now: int, graph: Dictionary, friendly_sectors: Array[int], off_camera: Callable, ship_visible: Callable, ship_kind_name: Callable, poi_name: Callable, play_cue: Callable) -> void:
	for key in alerts.keys():
		if now - int(alerts[key]["born"]) >= REPEAT_MS:
			alerts.erase(key)
	_sync_rogue(state, player, now, ship_kind_name, play_cue)
	_sync_damage_and_wages(state, player, now, off_camera, play_cue)
	_scan_approaches(state, player, now, graph, friendly_sectors, ship_visible, poi_name, play_cue)

func _post(key: String, message: String, point: Vector2, now: int, play_cue: Callable, target_id: int = -1) -> void:
	var previous: Dictionary = alerts.get(key, {})
	if not previous.is_empty() and now - int(previous["born"]) < REPEAT_MS:
		if now - int(previous["born"]) < LIFETIME_MS:
			previous["text"] = message
			previous["point"] = point
			previous["target"] = target_id
		return
	alerts[key] = {"text": message, "point": point, "born": now, "target": target_id}
	play_cue.call("warning")

func _sync_rogue(state: Dictionary, player: int, now: int, ship_kind_name: Callable, play_cue: Callable) -> void:
	var rogue_event: Dictionary = state.get("rogue_events", {}).get(player, {})
	var total: int = int(rogue_event.get("total", 0))
	if total > _rogue_notice_total:
		var count: int = total - _rogue_notice_total
		_rogue_notice_total = total
		var message: String = "%s went rogue due to unpaid wages!  ›" % ship_kind_name.call(str(rogue_event["kind"])) if count == 1 else "%d ships went rogue due to unpaid wages!  ›" % count
		# New batches must not be suppressed by the ordinary warning cooldown.
		alerts["rogue_defection"] = {"text": message, "point": rogue_event["position"], "born": now, "target": -1}
		play_cue.call("warning")

func _sync_damage_and_wages(state: Dictionary, player: int, now: int, off_camera: Callable, play_cue: Callable) -> void:
	var current: Dictionary = {}
	var team: int = ECONOMY._combat_group(state, player)
	var unpaid_count: int = 0
	var unpaid_example: Dictionary = {}
	for ship in state["ships"]:
		if int(ship["owner"]) == player and ship.has("unpaid_since"):
			unpaid_count += 1
			if unpaid_example.is_empty() or float(ship["unpaid_since"]) < float(unpaid_example["unpaid_since"]):
				unpaid_example = ship
		if ECONOMY._combat_group(state, int(ship["owner"])) != team:
			continue
		var id: int = int(ship["id"])
		var point: Vector2 = ship["position"]
		var health: Vector2 = Vector2(float(ship.get("hp", 0.0)), float(ship.get("shield", 0.0)))
		var previous: Vector2 = _durability.get(id, health)
		current[id] = health
		if _initialized and (health.x < previous.x - ECONOMY.EPS or health.y < previous.y - ECONOMY.EPS) and off_camera.call(point):
			var cell := Vector2i(floori(point.x / 1500.0), floori(point.y / 1500.0))
			_post("attack:%s" % str(cell), "Unit under attack!  ›", point, now, play_cue, id)
	for event in state.get("ship_destructions", []):
		var sequence: int = int(event["sequence"])
		if sequence <= _last_damage_sequence:
			continue
		_last_damage_sequence = sequence
		var point: Vector2 = event["position"]
		if _initialized and ECONOMY._combat_group(state, int(event["owner"])) == team and off_camera.call(point):
			var cell := Vector2i(floori(point.x / 1500.0), floori(point.y / 1500.0))
			_post("attack:%s" % str(cell), "Unit under attack!  ›", point, now, play_cue)
	if unpaid_count > 0:
		_post("unpaid_wages", "Insufficient GC: %d ship(s) unpaid  ›" % unpaid_count, unpaid_example["position"], now, play_cue, int(unpaid_example["id"]))
	else:
		alerts.erase("unpaid_wages")
	_durability = current
	_initialized = true

func _scan_approaches(state: Dictionary, player: int, now: int, graph: Dictionary, friendly_sectors: Array[int], ship_visible: Callable, poi_name: Callable, play_cue: Callable) -> void:
	if now < _next_scan:
		return
	_next_scan = now + 500
	if graph.is_empty():
		return
	var points: Array = graph["points"]
	# Build a temporary grid of friendly sector centers. Each visible hostile
	# is counted once, at its nearest approaching friendly sector.
	var cell_size: float = APPROACH_RANGE
	for index in friendly_sectors:
		cell_size = maxf(cell_size, float(graph["sector_radii"][index]) + APPROACH_RANGE)
	var cells: Dictionary = {}
	for index in friendly_sectors:
		var center: Vector2 = points[index]
		var cell := Vector2i(floori(center.x / cell_size), floori(center.y / cell_size))
		if not cells.has(cell):
			cells[cell] = []
		cells[cell].append(index)
	var positions: Dictionary = {}
	var groups: Dictionary = {}
	for ship in state["ships"]:
		if not ECONOMY.military_hull(str(ship["kind"])) or not ECONOMY.empires_hostile(state, player, int(ship["owner"])) or not ship_visible.call(state, ship):
			continue
		var id: int = int(ship["id"])
		var point: Vector2 = ship["position"]
		var previous: Vector2 = _positions.get(id, point)
		positions[id] = point
		var movement: Vector2 = point - previous
		if movement.length_squared() <= ECONOMY.EPS:
			continue
		var cell := Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))
		var best: int = -1
		var best_distance: float = INF
		for x in range(-1, 2):
			for y in range(-1, 2):
				for index in cells.get(cell + Vector2i(x, y), []):
					var center: Vector2 = points[index]
					var distance: float = point.distance_to(center)
					if distance > float(graph["sector_radii"][index]) + APPROACH_RANGE or distance >= best_distance:
						continue
					if ECONOMY.sector_contains(graph, index, point) or movement.normalized().dot(point.direction_to(center)) < 0.35:
						continue
					best = index
					best_distance = distance
		if best >= 0:
			var group: Dictionary = groups.get(best, {"count": 0, "sum": Vector2.ZERO})
			group["count"] = int(group["count"]) + 1
			group["sum"] = (group["sum"] as Vector2) + point
			groups[best] = group
	_positions = positions
	for index in groups:
		var group: Dictionary = groups[index]
		var count: int = int(group["count"])
		var label_text: String = "%d enemy combat unit%s approaching %s!  ›" % [count, "" if count == 1 else "s", poi_name.call(index)]
		_post("approach:%d" % index, label_text, (group["sum"] as Vector2) / float(count), now, play_cue)
