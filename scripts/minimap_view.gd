extends RefCounted
## Client minimap presentation, coordinate conversion, pointer navigation and target hints.
## Match retains modal gating, authoritative command dispatch and camera updates.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const TERRITORY_VIEW = preload("res://scripts/territory_view.gd")
const FOG_OF_WAR = preload("res://scripts/fog_of_war.gd")
const SHIP_MOTION_VIEW = preload("res://scripts/ship_motion_view.gd")

var minimap: Control
var map_canvas: Control
var session: Node
var territory_view: TERRITORY_VIEW
var fog_state: FOG_OF_WAR
var ship_motion: SHIP_MOTION_VIEW
var state_query: Callable
var map_size: Callable
var world_point: Callable
var local_player: Callable
var ship_poses: Callable
var fog_visible: Callable
var ship_visible: Callable
var empire_color: Callable
var minimap_pan_drag: bool = false

func configure(surface: Control, canvas: Control, session_node: Node, territory: TERRITORY_VIEW, fog: FOG_OF_WAR, motion: SHIP_MOTION_VIEW, snapshot_query: Callable, size_query: Callable, world_query: Callable, player_query: Callable, pose_query: Callable, fog_query: Callable, visibility_query: Callable, color_query: Callable) -> void:
	minimap = surface
	map_canvas = canvas
	session = session_node
	territory_view = territory
	fog_state = fog
	ship_motion = motion
	state_query = snapshot_query
	map_size = size_query
	world_point = world_query
	local_player = player_query
	ship_poses = pose_query
	fog_visible = fog_query
	ship_visible = visibility_query
	empire_color = color_query

func _minimap_area() -> Rect2:
	var bounds: Vector2 = map_size.call().max(Vector2.ONE)
	var available: Vector2 = (minimap.size - Vector2(12, 12)).max(Vector2.ONE)
	var scale: float = minf(available.x / bounds.x, available.y / bounds.y)
	var extent: Vector2 = bounds * scale
	return Rect2((minimap.size - extent) * 0.5, extent)

func _minimap_point(point: Vector2, area: Rect2) -> Vector2:
	return area.position + point / map_size.call().max(Vector2.ONE) * area.size

func handle_input(event: InputEvent, pending_command: String, order_command: Callable, pan_camera: Callable) -> void:
	var move_camera: bool = false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			minimap_pan_drag = event.pressed and pending_command.is_empty()
			move_camera = minimap_pan_drag
		if event.pressed and not state_query.call().is_empty() and (event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and not pending_command.is_empty())):
			order_command.call(event)
			minimap.accept_event()
			return
	elif event is InputEventMouseMotion:
		move_camera = minimap_pan_drag and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if move_camera and not state_query.call().is_empty():
		var area: Rect2 = _minimap_area()
		var fraction: Vector2 = ((event.position - area.position) / area.size).clamp(Vector2.ZERO, Vector2.ONE)
		var world: Vector2 = fraction * map_size.call()
		pan_camera.call(world)
	minimap.accept_event()

func order_hint(mouse: InputEventMouseButton, state: Dictionary, pending_command: String) -> Dictionary:
	var area: Rect2 = _minimap_area()
	if not area.has_point(mouse.position):
		return {}
	var world: Vector2 = (mouse.position - area.position) / area.size * map_size.call()
	var hint: Dictionary = {"world": world, "entity": -1, "field": -1, "wreck": -1}
	var graph: Dictionary = ECONOMY.military_graph(state)
	var count: int = state["planets"].size()
	var nearest: float = 5.0
	var node_hit: int = -1
	# Star markers are background landmarks, not implicit destinations or
	# station targets. Only actual entity/service orders use marker hits.
	if not mouse.alt_pressed and pending_command not in ["move", "patrol", "guard", "rally"]:
		var poses: Dictionary = ship_poses.call(state, 0.0)
		nearest = 3.0
		for id in poses:
			var ship_point: Vector2 = poses[id]["world"]
			var distance: float = mouse.position.distance_to(_minimap_point(ship_point, area))
			if distance < nearest:
				nearest = distance
				hint["entity"] = id
		if int(hint["entity"]) == -1:
			nearest = 5.0
			for node in ECONOMY.military_pois(state, local_player.call()):
				if node < count:
					if not ECONOMY.has_station(state["planets"][node]):
						continue
					var station_point: Vector2 = ECONOMY.station_position(state, node, float(state["elapsed"]))
					var distance: float = mouse.position.distance_to(_minimap_point(station_point, area))
					if distance < nearest:
						nearest = distance
						node_hit = node
						hint["entity"] = ECONOMY.station_target_id(state, node)
						hint["field"] = -1
				else:
					var distance: float = mouse.position.distance_to(_minimap_point(graph["points"][node], area))
					if distance < nearest:
						nearest = distance
						node_hit = node
						hint["field"] = node - count
						hint["entity"] = -1
		if pending_command == "load" or (node_hit < 0 and int(hint["entity"]) == -1):
			nearest = 3.0
			for pile in state.get("salvage", {}).values():
				var distance: float = mouse.position.distance_to(_minimap_point(pile["position"], area))
				if distance < nearest:
					nearest = distance
					hint["wreck"] = int(pile["id"])
	return hint

func draw(selected: int, selected_units: Array[int], selected_field: int) -> void:
	var surface := Rect2(Vector2.ZERO, minimap.size)
	minimap.draw_rect(surface, HUD.CONSOLE_BACKGROUND)
	var state: Dictionary = state_query.call()
	if state.is_empty() or minimap.size.x < 12.0 or minimap.size.y < 12.0:
		return
	var area: Rect2 = _minimap_area()
	minimap.draw_rect(area, Color("#090f17"))
	for i in range(1, 5):
		var x: float = area.position.x + area.size.x * float(i) / 5.0
		var y: float = area.position.y + area.size.y * float(i) / 5.0
		minimap.draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color("#142437"))
		minimap.draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color("#142437"))
	var graph: Dictionary = ECONOMY.military_graph(state)
	var points: Array = graph["points"]
	var count: int = state["planets"].size()
	var viewer: int = local_player.call()
	var locations: Array[Vector2] = []
	var known: Array[bool] = []
	for i in range(points.size()):
		locations.append(_minimap_point(points[i], area))
		known.append(ECONOMY.discovered(state, viewer, "planets" if i < count else "fields", i if i < count else i - count))
		if known[i] and i < territory_view.tints.size() and territory_view.tints[i].a > 0.0:
			var radius: float = clampf(territory_view.radius * area.size.x / map_size.call().x, 3.0, 12.0) * (1.0 if i < count else 0.68)
			var influence: Color = territory_view.tints[i]
			minimap.draw_circle(locations[i], radius, Color(influence, 0.30 * influence.a))
	var edges: Array = graph["edges"]
	var layout: Dictionary = ECONOMY.highway_regions(graph)
	for i in range(edges.size()):
		var a: int = int(edges[i][0])
		var b: int = int(edges[i][1])
		var sections: int = int(layout["counts"][i])
		var width: float = clampf(2.0 * ECONOMY.lane_radius(graph, a, b) * area.size.x / map_size.call().x, 1.0, 8.0)
		for j in range(sections):
			var start: Vector2 = locations[a].lerp(locations[b], float(j) / sections)
			var finish: Vector2 = locations[a].lerp(locations[b], float(j + 1) / sections)
			var tint: Color = Color("#69869e") if known[a] and known[b] else Color("#182b3b")
			var weight_index: int = int(layout["starts"][i]) + j
			if known[a] and known[b] and weight_index < territory_view.tints.size():
				var influence: Color = territory_view.tints[weight_index]
				if influence.a > 0.0:
					minimap.draw_line(start, finish, Color(influence, 0.45 * influence.a), width, true)
				tint = tint.lerp(Color(influence, 1.0), influence.a)
			minimap.draw_line(start, finish, tint, 1.0, true)
	for i in range(points.size()):
		var tint := Color("#40566b")
		if i < count:
			var owner: int = int(state["planets"][i]["owner"])
			if known[i] and fog_visible.call(points[i]):
				tint = empire_color.call(owner) if owner > 0 else Color("#a3b0bb")
			minimap.draw_circle(locations[i], 2.4 if owner > 0 and known[i] else 1.8, tint)
		elif known[i]:
			var special: bool = bool(state["map"]["fields"][i - count].get("antimatter", false))
			tint = HUD.COLORS[ECONOMY.ANTIMATTER] if special else Color("#b8a87a")
			minimap.draw_rect(Rect2(locations[i] - Vector2.ONE * 1.8, Vector2.ONE * 3.6), tint, false, 1.0)
		if (i < count and i == selected and selected_units.is_empty() and selected_field < 0) or (i >= count and i - count == selected_field):
			minimap.draw_arc(locations[i], 4.5, 0.0, TAU, 12, HUD.ACCENT, 1.0, true)
	for pile in state.get("salvage", {}).values():
		if not fog_visible.call(pile["position"]):
			continue
		var point: Vector2 = _minimap_point(pile["position"], area)
		if area.has_point(point):
			minimap.draw_circle(point, 1.0, HUD.COLORS[pile["resource"]])
	if fog_state.texture != null:
		var corner: Vector2 = _minimap_point(Vector2.ZERO, area)
		var far: Vector2 = _minimap_point(map_size.call(), area)
		minimap.draw_texture_rect_region(fog_state.texture, Rect2(corner, far - corner), Rect2(Vector2.ZERO, map_size.call() / ECONOMY.VISION_CELL))
	# Mirror the main map's live hull visibility and interpolation; do not
	# reveal undiscovered system ownership.
	for ship in state["ships"]:
		if not ship_visible.call(state, ship):
			continue
		var id: int = int(ship["id"])
		var world: Vector2 = ship_motion.world_position(ship, points, session)
		var point: Vector2 = _minimap_point(world, area)
		if area.has_point(point):
			minimap.draw_circle(point, 2.0, empire_color.call(int(ship["owner"])).lightened(0.2))
			if selected_units.has(id):
				minimap.draw_arc(point, 2.6, 0.0, TAU, 10, Color.WHITE, 1.0, true)
	var corner: Vector2 = _minimap_point(world_point.call(Vector2.ZERO), area)
	var end: Vector2 = _minimap_point(world_point.call(map_canvas.size), area)
	var camera_rect := Rect2(corner, end - corner)
	# Preserve a visible indicator at extreme close-up zoom levels.
	var visible_extent: Vector2 = camera_rect.size.max(Vector2(3, 3))
	var visible_rect := Rect2(camera_rect.get_center() - visible_extent * 0.5, visible_extent)
	minimap.draw_rect(area, Color("#35536a"), false, 1.0)
	var clipped: Rect2 = visible_rect.intersection(area)
	if clipped.has_area():
		minimap.draw_rect(clipped, Color(HUD.ACCENT, 0.08))
		minimap.draw_rect(clipped, HUD.ACCENT, false, 1.2)


