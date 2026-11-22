extends RefCounted
## Per-client live and explored fog cells with a shared map/minimap mask.
## This is presentation state, not authority or network visibility enforcement.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const MAP = preload("res://scripts/planet_map.gd")

var _live: Dictionary = {}
var _explored: Dictionary = {}
var texture: ImageTexture
var _origin := Vector2.ZERO
var extent := Vector2.ZERO
var _revision: Array = []
var _map_identity: Array = []
var _systems: Dictionary = {}
var _fields: Dictionary = {}
var _observed_at: Dictionary = {}

func update(state: Dictionary, player: int, motion_revision: Variant, map_size: Vector2) -> bool:
	if state.is_empty():
		_live.clear()
		_explored.clear()
		_systems.clear()
		_fields.clear()
		_observed_at.clear()
		_revision.clear()
		_map_identity.clear()
		texture = null
		return false
	var identity: Array = [player, state["map"].get("seed", 0), map_size, state["map"]["points"]]
	if identity != _map_identity:
		_map_identity = identity
		_live.clear()
		_explored.clear()
		_systems.clear()
		_fields.clear()
		_observed_at.clear()
		_revision.clear()
		_seed_starting_memory(state, player)
	var team: int = ECONOMY._combat_group(state, player)
	var revision: Array = [state.get("elapsed"), motion_revision, team, state["ships"].size(), state.get("diplomacy_revision", 0)]
	if revision == _revision:
		return false
	_revision = revision
	_live = ECONOMY.team_vision(state, team)
	_explored.merge(_live, true)
	_observe_sites(state, player, map_size)
	var cell: float = ECONOMY.VISION_CELL
	var start := Vector2i.ZERO
	var finish: Vector2i = ECONOMY.vision_cell(map_size)
	var dimensions: Vector2i = finish - start + Vector2i.ONE
	var image := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.015, 0.025, 0.04, 0.96))
	for key in _explored:
		var pixel: Vector2i = key - start
		if Rect2i(Vector2i.ZERO, dimensions).has_point(pixel):
			image.set_pixelv(pixel, Color(0.015, 0.025, 0.04, 0.48))
	for key in _live:
		var pixel: Vector2i = key - start
		if Rect2i(Vector2i.ZERO, dimensions).has_point(pixel):
			image.set_pixelv(pixel, Color(0.0, 0.0, 0.0, 0.0))
	if texture == null or texture.get_size() != Vector2(dimensions):
		texture = ImageTexture.create_from_image(image)
	else:
		texture.update(image)
	_origin = Vector2(start) * cell
	extent = Vector2(dimensions) * cell
	return true

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
	var initial_map: Dictionary = state["map"]
	if initial_map.has("layout"):
		initial_map = MAP.generate(int(initial_map["seed"]), ordered.size(), str(initial_map["layout"]))
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
		if ECONOMY.discovered(state, player, "fields", index) and is_visible(fields[index]["position"], map_size):
			_fields[index] = (fields[index] as Dictionary).duplicate(true)

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

func is_visible(point: Vector2, map_size: Vector2) -> bool:
	return point.is_finite() and Rect2(Vector2.ZERO, map_size).has_point(point) and _live.has(ECONOMY.vision_cell(point))

func draw(overlay: Control, bounds: Rect2, map_rect: Rect2, map_size: Vector2) -> void:
	if texture == null:
		return
	var inside: Rect2 = bounds.intersection(map_rect)
	var dark := Color(0.015, 0.025, 0.04, 0.96)
	if not inside.has_area():
		overlay.draw_rect(bounds, dark)
		return
	# Cover every exterior pixel, independent of camera zoom or pan.
	overlay.draw_rect(Rect2(bounds.position, Vector2(bounds.size.x, inside.position.y)), dark)
	overlay.draw_rect(Rect2(Vector2(0, inside.end.y), Vector2(bounds.size.x, bounds.end.y - inside.end.y)), dark)
	overlay.draw_rect(Rect2(Vector2(0, inside.position.y), Vector2(inside.position.x, inside.size.y)), dark)
	overlay.draw_rect(Rect2(Vector2(inside.end.x, inside.position.y), Vector2(bounds.end.x - inside.end.x, inside.size.y)), dark)
	var source := Rect2(Vector2.ZERO, map_size / ECONOMY.VISION_CELL)
	overlay.draw_texture_rect_region(texture, map_rect, source)
