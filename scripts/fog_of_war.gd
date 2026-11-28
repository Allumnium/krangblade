extends RefCounted
## Per-client live and explored fog cells with a shared map/minimap mask.
## This is presentation state, not authority or network visibility enforcement.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const MAP = preload("res://scripts/planet_map.gd")

var _live: Dictionary = {}
var observing: bool = false
var revealed: bool = false
var _mask_stride: int = 1
var _mask_live: Dictionary = {}
var _ship_vision_cache: Dictionary = {}
var _explored: Dictionary = {}
var texture: ImageTexture
var _mask_image: Image
var _origin := Vector2.ZERO
var extent := Vector2.ZERO
var _revision: Array = []
var _map_identity: Array = []
var _systems: Dictionary = {}
var _fields: Dictionary = {}
var _rock_memory: Array = []
var _rock_views: Array = []
var _initial_map: Dictionary = {}
var _observed_at: Dictionary = {}
var profile: Dictionary = {}

func update(state: Dictionary, player: int, motion_revision: Variant, map_size: Vector2) -> bool:
	if state.is_empty():
		observing = false
		revealed = false
		_mask_live.clear()
		_live.clear()
		_ship_vision_cache.clear()
		_explored.clear()
		_systems.clear()
		_fields.clear()
		_rock_memory.clear()
		_rock_views.clear()
		_initial_map = {}
		_observed_at.clear()
		_revision.clear()
		_map_identity.clear()
		texture = null
		_mask_image = null
		return false
	var identity: Array = [player, state["map"].get("seed", 0), map_size, state["map"]["points"]]
	if identity != _map_identity:
		_map_identity = identity
		_mask_image = null
		_live.clear()
		_ship_vision_cache.clear()
		_explored.clear()
		_systems.clear()
		_fields.clear()
		_rock_memory.clear()
		_rock_views.clear()
		_initial_map = {}
		_observed_at.clear()
		_revision.clear()
		_initial_map = state["map"]
		if _initial_map.has("layout"):
			_initial_map = MAP.generate(int(_initial_map["seed"]), int(_initial_map.get("player_count", state.get("starting_empires", []).size())), str(_initial_map["layout"]))
		_seed_rock_memory()
		_seed_starting_memory(state, player)
	var team: int = ECONOMY._combat_group(state, player)
	var next_observing: bool = revealed or state.get("eliminated", []).has(player)
	var revision: Array = [state.get("elapsed"), motion_revision, team, state["ships"].size(), state.get("diplomacy_revision", 0), next_observing]
	if revision == _revision:
		return false
	_revision = revision
	if next_observing:
		observing = true
		texture = null
		_mask_image = null
		_observe_rocks(state, map_size)
		return true
	if observing:
		_mask_image = null
	observing = false
	profile.clear()
	var started: int = Time.get_ticks_usec()
	var prior_live: Dictionary = _live
	_live = ECONOMY.team_vision(state, team, _ship_vision_cache)
	profile["vision"] = float(Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	var coverage_changed: bool = _live != prior_live
	if coverage_changed:
		_explored.merge(_live, true)
	_observe_sites(state, player, map_size)
	profile["sites"] = float(Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	_observe_rocks(state, map_size)
	profile["rocks"] = float(Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	if coverage_changed or _mask_image == null:
		_update_mask(prior_live, map_size)
	profile["mask"] = float(Time.get_ticks_usec() - started) / 1000.0
	return true

# The explored set only grows until map identity changes. A cell leaving
# live vision becomes explored, and a newly live cell becomes transparent.
# Keep the exact original colors and bounds; do not upload unchanged masks.
func mask_world_cell() -> float:
	return ECONOMY.VISION_CELL * float(_mask_stride)

func _mask_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / float(_mask_stride)), floori(float(cell.y) / float(_mask_stride)))

func discovered(state: Dictionary, player: int, kind: String, index: int) -> bool:
	if revealed:
		return index >= 0 and ((kind == "planets" and index < state.get("planets", []).size()) or (kind == "fields" and index < state.get("map", {}).get("fields", []).size()))
	return ECONOMY.discovered(state, player, kind, index)

func _update_mask(_prior_live: Dictionary, map_size: Vector2) -> void:
	# Bound presentation texture uploads independently of exact gameplay sight.
	# A coarse texel is transparent when any of its exact vision cells is live.
	# Entity visibility and picking still use the original 80-unit cells.
	var stride: int = maxi(1, ceili(maxf(map_size.x, map_size.y) / (ECONOMY.VISION_CELL * 1023.0)))
	var stride_changed: bool = stride != _mask_stride
	_mask_stride = stride
	var dimensions := Vector2i(floori(map_size.x / mask_world_cell()) + 1, floori(map_size.y / mask_world_cell()) + 1)
	var bounds := Rect2i(Vector2i.ZERO, dimensions)
	var explored_color := Color(0.015, 0.025, 0.04, 0.48)
	var live_color := Color(0.0, 0.0, 0.0, 0.0)
	var next_live: Dictionary = {}
	for key in _live:
		next_live[_mask_cell(key)] = true
	var rebuild: bool = stride_changed or _mask_image == null or _mask_image.get_size() != dimensions
	var changed: bool = rebuild
	if rebuild:
		_mask_image = Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
		_mask_image.fill(Color(0.015, 0.025, 0.04, 1.0))
		for key in _explored:
			var pixel: Vector2i = _mask_cell(key)
			if bounds.has_point(pixel):
				_mask_image.set_pixelv(pixel, explored_color)
		for pixel in next_live:
			if bounds.has_point(pixel):
				_mask_image.set_pixelv(pixel, live_color)
	else:
		for pixel in _mask_live:
			if not next_live.has(pixel) and bounds.has_point(pixel):
				_mask_image.set_pixelv(pixel, explored_color)
				changed = true
		for pixel in next_live:
			if not _mask_live.has(pixel) and bounds.has_point(pixel):
				_mask_image.set_pixelv(pixel, live_color)
				changed = true
	_mask_live = next_live
	if texture == null or texture.get_size() != Vector2(dimensions):
		texture = ImageTexture.create_from_image(_mask_image)
	elif changed:
		texture.update(_mask_image)
	_origin = Vector2.ZERO
	extent = Vector2(dimensions) * mask_world_cell()

# Reconstruct the opening survey once; late snapshots must not expose
# current enemy buildings, population or depleted ore outside live sight.
func _seed_starting_memory(state: Dictionary, player: int) -> void:
	var ordered: Array[int] = []
	ordered.assign(state.get("starting_empires", []))
	if ordered.is_empty():
		return
	var team: int = ECONOMY._combat_group(state, player)
	var regions: Array = []
	for region in state.get("starting_survey", []):
		if ECONOMY._shares_group_vision(state, team, ECONOMY._combat_group(state, int(region["owner"]))):
			regions.append(region)
			ECONOMY._stamp_vision(_explored, region["center"], float(region["radius"]))
	if regions.is_empty():
		return
	var players: Dictionary = {}
	for owner in ordered:
		players[owner] = {"team": int(state["teams"].get(owner, owner))}
	var initial_map: Dictionary = _initial_map
	var initial: Dictionary = ECONOMY.create(initial_map, players, ordered, false)
	for region in regions:
		var center: Vector2 = region["center"]
		var squared: float = float(region["radius"]) ** 2
		for index in range(initial_map["points"].size()):
			if center.distance_squared_to(initial_map["points"][index]) <= squared:
				_systems[index] = (initial["planets"][index] as Dictionary).duplicate(true)
				_observed_at[index] = 0.0
		var fields: Array = initial_map.get("fields", [])
		for index in range(fields.size()):
			if center.distance_squared_to(fields[index]["position"]) <= squared:
				_fields[index] = (fields[index] as Dictionary).duplicate(true)
			if index < _rock_memory.size() and not bool(fields[index].get("antimatter", false)):
				for asteroid in fields[index].get("chunks", []):
					if center.distance_squared_to(asteroid["position"]) <= squared:
						var observed: Dictionary = asteroid.duplicate()
						observed["surveyed"] = true
						_rock_memory[index][int(asteroid["id"])] = observed

# Site memory is presentation-only and never written back to replicated state.
# Deep copies prevent in-place solo/host updates from changing remembered data.
func _observe_sites(state: Dictionary, player: int, map_size: Vector2) -> void:
	var points: Array = state["map"]["points"]
	for index in range(state["planets"].size()):
		if ECONOMY.discovered(state, player, "planets", index) and is_visible(points[index], map_size):
			_systems[index] = (state["planets"][index] as Dictionary).duplicate(true)
			_observed_at[index] = float(state["elapsed"])
	var fields: Array = state["map"].get("fields", [])
	for index in range(fields.size()):
		if bool(fields[index].get("antimatter", false)) and ECONOMY.discovered(state, player, "fields", index) and is_visible(fields[index]["position"], map_size):
			_fields[index] = (fields[index] as Dictionary).duplicate(true)

# Only surveyed rocks enter memory. Starting survey seeds historical ore;
# other rocks enter on actual sight, never from unexplored geography.
func _seed_rock_memory() -> void:
	for field in _initial_map.get("fields", []):
		_rock_memory.append({})
		_rock_views.append({})

func _observe_rocks(state: Dictionary, map_size: Vector2) -> void:
	var fields: Array = state["map"].get("fields", [])
	for index in range(mini(fields.size(), _rock_memory.size())):
		var field: Dictionary = fields[index]
		if bool(field.get("antimatter", false)):
			continue
		var memory: Dictionary = _rock_memory[index]
		var live_ids: Dictionary = {}
		for chunk in field.get("chunks", []):
			if is_visible(chunk["position"], map_size):
				var id: int = int(chunk["id"])
				var previous: Dictionary = memory.get(id, {})
				if not bool(previous.get("surveyed", false)) or previous.get("remaining", -1.0) != chunk["remaining"] or previous.get("position") != chunk["position"]:
					var observed: Dictionary = chunk.duplicate()
					observed["surveyed"] = true
					memory[id] = observed
				live_ids[id] = true
		var visible_rocks: Array = []
		var hidden_rocks: Array = []
		for id in memory.keys():
			var rock: Dictionary = memory[id]
			if live_ids.has(id):
				visible_rocks.append(rock)
			elif is_visible(rock["position"], map_size):
				memory.erase(id)
			else:
				hidden_rocks.append(rock)
		# Only last-observed rocks populate the minimap memory. The main view
		# consumes live only; no concatenated per-frame terrain list is needed.
		_rock_views[index] = {"live": visible_rocks, "hidden": hidden_rocks}

func rock_view(index: int) -> Dictionary:
	if index < 0 or index >= _rock_views.size():
		return {}
	return _rock_views[index]

func rock_at(index: int, id: int) -> Dictionary:
	if index < 0 or index >= _rock_memory.size():
		return {}
	return _rock_memory[index].get(id, {})

func system_view(state: Dictionary, index: int, map_size: Vector2) -> Dictionary:
	if index < 0 or index >= state.get("planets", []).size():
		return {}
	if is_visible(state["map"]["points"][index], map_size):
		return state["planets"][index]
	return _systems.get(index, {})

func field_view(state: Dictionary, index: int, map_size: Vector2) -> Dictionary:
	var fields: Array = state.get("map", {}).get("fields", [])
	if index < 0 or index >= fields.size():
		return {}
	if is_visible(fields[index]["position"], map_size):
		return fields[index]
	return _fields.get(index, {})

func observed_time(index: int) -> float:
	return float(_observed_at.get(index, 0.0))

# A shallow view for structure rendering and colonization previews. Unknown
# systems are neutral placeholders, not secretly read from current state.
func observed_state(state: Dictionary, map_size: Vector2) -> Dictionary:
	var view: Dictionary = state.duplicate()
	var systems: Array = []
	for index in range(state["planets"].size()):
		var remembered: Dictionary = system_view(state, index, map_size)
		systems.append(remembered if not remembered.is_empty() else {"owner": 0, "station": {}, "home": false})
	view["planets"] = systems
	return view

func is_explored(point: Vector2, map_size: Vector2) -> bool:
	return point.is_finite() and Rect2(Vector2.ZERO, map_size).has_point(point) and (observing or _explored.has(ECONOMY.vision_cell(point)) or _live.has(ECONOMY.vision_cell(point)))

func is_visible(point: Vector2, map_size: Vector2) -> bool:
	return point.is_finite() and Rect2(Vector2.ZERO, map_size).has_point(point) and (observing or _live.has(ECONOMY.vision_cell(point)))

func draw(overlay: Control, bounds: Rect2, map_rect: Rect2, map_size: Vector2) -> void:
	if texture == null:
		return
	var inside: Rect2 = bounds.intersection(map_rect)
	var dark := Color(0.015, 0.025, 0.04, 1.0)
	if not inside.has_area():
		overlay.draw_rect(bounds, dark)
		return
	# Cover every exterior pixel, independent of camera zoom or pan.
	overlay.draw_rect(Rect2(bounds.position, Vector2(bounds.size.x, inside.position.y)), dark)
	overlay.draw_rect(Rect2(Vector2(0, inside.end.y), Vector2(bounds.size.x, bounds.end.y - inside.end.y)), dark)
	overlay.draw_rect(Rect2(Vector2(0, inside.position.y), Vector2(inside.position.x, inside.size.y)), dark)
	overlay.draw_rect(Rect2(Vector2(inside.end.x, inside.position.y), Vector2(bounds.end.x - inside.end.x, inside.size.y)), dark)
	var source := Rect2(Vector2.ZERO, map_size / mask_world_cell())
	overlay.draw_texture_rect_region(texture, map_rect, source)
