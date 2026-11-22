extends RefCounted
## Client command intent, target rings, destinations and formation preview art.
## Match owns selection, drag state, command generation and authority dispatch.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const HULL_ART = preload("res://scripts/hull_art.gd")
const CELESTIAL_VIEW = preload("res://scripts/celestial_view.gd")
const CAMERA_VIEW = preload("res://scripts/camera_view.gd")

var map_canvas: Control
var hull_art: HULL_ART
var celestial_view: CELESTIAL_VIEW
var camera: CAMERA_VIEW
var ship_scale: Callable
var screen_point: Callable
var station_radius: Callable
var planet_radius: Callable
var salvage_radius: Callable
var fit_query: Callable
var local_player: Callable

func configure(canvas: Control, art: HULL_ART, celestial: CELESTIAL_VIEW, camera_view: CAMERA_VIEW, scale_query: Callable, projection: Callable, station_query: Callable, planet_query: Callable, salvage_query: Callable, fit: Callable, player_query: Callable) -> void:
	map_canvas = canvas
	hull_art = art
	celestial_view = celestial
	camera = camera_view
	ship_scale = scale_query
	screen_point = projection
	station_radius = station_query
	planet_radius = planet_query
	salvage_radius = salvage_query
	fit_query = fit
	local_player = player_query

func draw_destination_ghost(kind: String, point: Vector2, heading: Vector2, tint: Color) -> void:
	var axis: Vector2 = heading.normalized() if not heading.is_zero_approx() else Vector2.UP
	var scale: float = maxf(0.42, ship_scale.call(false))
	var shape: PackedVector2Array = hull_art.polygon(point, axis * scale, axis.orthogonal() * scale, HULL_ART.HULL_OUTLINES.get(kind, HULL_ART.FREIGHTER_OUTLINE))
	if not Geometry2D.triangulate_polygon(shape).is_empty():
		map_canvas.draw_colored_polygon(shape, Color(tint, 0.24))
	shape.append(shape[0])
	map_canvas.draw_polyline(shape, Color(tint, 0.85), 1.0, true)

func draw_sector_target(graph: Dictionary, node: int, tint: Color, drawn: Dictionary) -> void:
	if node < 0 or node >= graph["points"].size() or drawn.has(node):
		return
	drawn[node] = true
	var center: Vector2 = screen_point.call(graph["points"][node])
	map_canvas.draw_arc(center, 12.0, 0.0, TAU, 24, Color(tint, 0.9), 1.5, true)
	map_canvas.draw_circle(center, 2.0, tint)

func draw_formation_preview(state: Dictionary, formation_button: int, formation_length: float, formation_mode: String, formation_path: PackedVector2Array, formation_orders: Callable, selected_owned_units: Callable) -> void:
	if formation_button == 0 or formation_length <= 5.0:
		return
	var entries: Array = formation_orders.call(state)
	if entries.is_empty():
		return
	var color: Color = Color("#b880fa") if formation_mode == "patrol" else Color("#ff605c") if formation_mode == "attack" else HUD.ACCENT
	if selected_owned_units.call(state, formation_mode not in ["attack", "patrol"]).size() == 1:
		map_canvas.draw_line(formation_path[0], formation_path[-1], color, 1.5, true)
	else:
		map_canvas.draw_polyline(formation_path, color, 1.5, true)
	for entry in entries:
		var order: Dictionary = entry["order"]
		var point: Vector2 = screen_point.call(order["point"])
		var heading: Vector2 = order["heading"]
		draw_destination_ghost(entry["hull"], point, heading, color if entry["valid"] else Color("#a88b83"))

# Target indicators use authoritative entity IDs, not the ship's navigation
# waypoint. They follow the interpolated pose and rendered structure geometry.
func _target_ring_entity(state: Dictionary, poses: Dictionary, refs: Dictionary, id: int) -> Dictionary:
	var ref: Dictionary = refs.get(id, {})
	if ref.is_empty():
		return {}
	var center: Vector2 = poses[id]["point"] if poses.has(id) else screen_point.call(ref["position"])
	var radius: float = maxf(8.0, hull_art.ui_radius(str(ref.get("entity", {}).get("kind", ""))) * ship_scale.call(false))
	match str(ref["kind"]):
		"station": radius = station_radius.call() + 4.0
		"yard": radius = maxf(8.0, 23.0 * ship_scale.call(true) * pow(1.2, int(ref["entity"]["level"]) - 1))
		"pds":
			var node: int = int(ref["node"])
			var slot: int = floori(float(-2 - id - state["planets"].size() * 3) / float(state["planets"].size()))
			var system_radius: float = planet_radius.call(node, state)
			var body: Dictionary = celestial_view.system_visual(node, state)["bodies"][slot]
			center = screen_point.call(ref["repair_position"])
			radius = maxf(6.0, system_radius * float(body["size"]) * 0.55 + 5.0)
	return {"point": center, "radius": radius, "owner": ref["owner"]}

func _ship_target_ring(state: Dictionary, poses: Dictionary, refs: Dictionary, ship: Dictionary) -> Dictionary:
	var destination: int = -1
	if bool(ship.get("retreating", false)):
		destination = int(ship.get("repair_site", -1))
		if destination >= 0:
			return _target_ring_entity(state, poses, refs, ECONOMY.station_target_id(state, destination))
		return {}
	for key in ["attack_order", "combat_target", "pursuit_target", "yard_target", "repair_order", "repair_target"]:
		var target: int = int(ship.get(key, -1))
		if target != -1 and refs.has(target):
			return _target_ring_entity(state, poses, refs, target)
	var cargo: Dictionary = ship.get("cargo_order", {})
	if cargo.get("kind", "") == "deposit":
		return _target_ring_entity(state, poses, refs, int(cargo.get("target", -1)))
	for key in ["salvage_target", "auto_salvage_target"]:
		var pile: Dictionary = state.get("salvage", {}).get(int(ship.get(key, -1)), {})
		if not pile.is_empty():
			return {"point": screen_point.call(pile["position"]), "radius": salvage_radius.call(pile) + 5.0, "owner": 0}
	if ship.has("local_move_target") or ship.has("launch_rally") or bool(ship.get("holding", false)):
		return {}
	if ship["kind"] == "miner" and ship.get("mining_mode", "") in ["approach", "outbound", "mining"]:
		var field: int = int(ship.get("field", -1))
		if field >= 0 and field < state["map"]["fields"].size():
			var chunk: Dictionary = ECONOMY._find_chunk(state["map"]["fields"][field], int(ship.get("chunk", -1)))
			if not chunk.is_empty():
				var radius: float = float(chunk["radius"]) * fit_query.call() * camera.zoom * sqrt(float(chunk["remaining"]) / float(chunk["initial"]))
				return {"point": screen_point.call(chunk["position"]), "radius": maxf(6.0, radius + 4.0), "owner": 0}
	if bool(ship.get("salvage_delivery", false)):
		destination = int(ship.get("salvage_depot", -1))
	elif ship["kind"] == "miner" and ship.get("mining_mode", "") in ["return", "delivery"]:
		destination = int(ship.get("mining_anchor", -1)) if ship.get("mining_mode", "") == "return" else int(ship.get("dest", -1))
	elif ship["kind"] == "ship":
		destination = int(ship.get("source", -1)) if int(ship.get("source", -1)) >= 0 else int(ship.get("dest", -1))
	elif ship["kind"] == "colony_ship":
		destination = int(ship.get("dest", -1))
	if destination >= 0 and destination < state["planets"].size():
		if refs.has(ECONOMY.station_target_id(state, destination)):
			return _target_ring_entity(state, poses, refs, ECONOMY.station_target_id(state, destination))
		return {"point": screen_point.call(state["map"]["points"][destination]), "radius": maxf(8.0, celestial_view.star_draw_radius(planet_radius.call(destination, state)) + 5.0), "owner": state["planets"][destination]["owner"]}
	return {}

func draw_ship_target_rings(state: Dictionary, poses: Dictionary, refs: Dictionary, selected_units: Array[int], selected_ship_id: int) -> void:
	var drawn: Dictionary = {}
	for ship in state["ships"]:
		if not selected_units.has(int(ship["id"])) and int(ship["id"]) != selected_ship_id:
			continue
		var target: Dictionary = _ship_target_ring(state, poses, refs, ship)
		if target.is_empty() or drawn.has(target["point"]):
			continue
		drawn[target["point"]] = true
		var owner: int = int(target["owner"])
		var tint: Color = Color("#50a8ff") if ECONOMY._friendly_target(state, local_player.call(), target) else (Color("#ff5058") if ECONOMY.empires_hostile(state, local_player.call(), owner) else Color.WHITE)
		var radius: float = float(target["radius"]) + 4.0
		if Rect2(Vector2.ZERO, map_canvas.size).grow(radius + 4.0).has_point(target["point"]):
			map_canvas.draw_arc(target["point"], radius, 0.0, TAU, clampi(ceili(radius * 0.7), 24, 96), tint, 1.8, true)

func order_color(ship: Dictionary, order: Dictionary) -> Color:
	var kind: String = str(order.get("kind", ""))
	if kind == "patrol":
		return Color("#b880fa")
	if ECONOMY.armed(ship) and (kind == "attack" or (kind in ["sector", "sector_entry", "position"] and not bool(order.get("move_only", false)))):
		return Color("#ff605c")
	if kind == "repair":
		return Color("#55c88b")
	return HUD.ACCENT

# Use the authoritative remaining route, never reconstruct a straight-line path.
func draw_command_route(graph: Dictionary, ship: Dictionary, start: Vector2, finish: Vector2, tint: Color, dashed: bool = false) -> void:
	var cursor: Vector2 = start
	var points: Array = graph["points"]
	var route: Array = ship.get("route", [])
	for node in route:
		if int(node) < 0 or int(node) >= points.size():
			continue
		var waypoint: Vector2 = screen_point.call(points[int(node)])
		if cursor.distance_to(waypoint) > 1.0:
			if dashed:
				map_canvas.draw_dashed_line(cursor, waypoint, Color(tint, 0.8), 1.5, 6.0, true, true)
			else:
				map_canvas.draw_line(cursor, waypoint, Color(tint, 0.8), 1.5, true)
		cursor = waypoint
	if cursor.distance_to(finish) > 1.0:
		if dashed:
			map_canvas.draw_dashed_line(cursor, finish, Color(tint, 0.8), 1.5, 6.0, true, true)
		else:
			map_canvas.draw_line(cursor, finish, Color(tint, 0.8), 1.5, true)

func draw_single_command_line(state: Dictionary, graph: Dictionary, ship: Dictionary, start: Vector2, poses: Dictionary, refs: Dictionary) -> void:
	var order: Dictionary = ship.get("unit_order", {})
	var endpoint: Vector2 = Vector2.INF
	var tint: Color = order_color(ship, order)
	var target: int = int(order.get("target", -1))
	if bool(ship.get("retreating", false)):
		var site: int = int(ship.get("repair_site", -1))
		if site >= 0 and site < state["planets"].size():
			endpoint = ECONOMY.station_position(state, site, float(state["elapsed"]))
			tint = Color("#55c88b")
	elif ship.has("patrol_from"):
		endpoint = ship["patrol_start_point"] if bool(ship.get("patrol_returning", false)) else ship["patrol_end_point"]
	elif order.get("kind", "") == "follow" and poses.has(target):
		# The existing follow branch draws its own live line.
		return
	elif ship.has("launch_rally"):
		# The existing rally branch draws its own line.
		return
	elif ship.has("local_move_target"):
		endpoint = ship["local_move_target"]
	elif ECONOMY._unit_order_running(ship):
		endpoint = ECONOMY.unit_order_point(state, graph, ship, order)
		if order.get("kind", "") in ["attack", "repair", "deposit"] and poses.has(target):
			endpoint = Vector2.INF
			draw_command_route(graph, ship, start, poses[target]["point"], tint)
			return
	if not endpoint.is_finite():
		var depot: int = int(ship.get("salvage_depot", ship.get("dest", -1)))
		var repair: int = int(ship.get("repair_target", -1))
		var salvage: int = int(ship.get("salvage_target", ship.get("auto_salvage_target", -1)))
		var combat: int = int(ship.get("combat_target", -1))
		if refs.has(repair):
			endpoint = refs[repair].get("repair_position", refs[repair]["position"])
			tint = Color("#55c88b")
		elif poses.has(combat):
			draw_command_route(graph, ship, start, poses[combat]["point"], Color("#ff605c"))
			return
		elif state.get("salvage", {}).has(salvage):
			endpoint = state["salvage"][salvage]["position"]
		elif ship.has("resource_stage"):
			endpoint = ship["resource_stage"]["point"]
		elif ship.get("mining_mode", "") in ["outbound", "mining"] and ship.has("mining_target"):
			endpoint = ship["mining_target"]
		elif depot >= 0 and depot < state["planets"].size() and ECONOMY.has_station(state["planets"][depot]) and ship.get("kind", "") not in ["fighter", "scout", "cruiser", "destroyer"]:
			endpoint = ECONOMY.station_position(state, depot, float(state["elapsed"]))
		elif not ship["route"].is_empty():
			var node: int = int(ship["route"].back())
			if node >= 0 and node < graph["points"].size():
				endpoint = graph["points"][node]
		elif ship.has("hold_position") and bool(ship.get("holding", false)):
			endpoint = ship["hold_position"]
		else:
			endpoint = ship.get("navigation_target", Vector2.INF)
	if endpoint.is_finite():
		var finish: Vector2 = screen_point.call(endpoint)
		draw_command_route(graph, ship, start, finish, tint)

# Shared orders use semantic targets, not individual route legs or formation
# offsets. A sector-entry order has one sector despite differing approach points.
func _group_command_target(state: Dictionary, graph: Dictionary, ship: Dictionary, poses: Dictionary, refs: Dictionary) -> Dictionary:
	if bool(ship.get("holding", false)):
		return {}
	var order: Dictionary = ship.get("unit_order", {})
	var kind: String = str(order.get("kind", ""))
	var target: int = int(order.get("target", -1))
	var endpoint: Vector2 = Vector2.INF
	var tint: Color = order_color(ship, order)
	var signature: Array = [kind, target, bool(order.get("move_only", false)), bool(order.get("guard", false)), int(order.get("chunk", -1))]
	if bool(ship.get("retreating", false)):
		var site: int = int(ship.get("repair_site", -1))
		if site < 0 or site >= state["planets"].size():
			return {}
		signature = ["withdraw", site]
		endpoint = screen_point.call(ECONOMY.station_position(state, site, float(state["elapsed"])))
		tint = Color("#55c88b")
	elif ship.has("launch_rally"):
		signature = ["rally", ship["launch_rally"]["point"]]
		endpoint = screen_point.call(ship["launch_rally"]["point"])
		tint = Color("#ff605c")
	elif kind.is_empty() or not ECONOMY._unit_order_running(ship):
		return {}
	elif kind in ["sector", "sector_entry"]:
		if target < 0 or target >= graph["points"].size():
			return {}
		endpoint = screen_point.call(graph["points"][target])
	elif kind == "patrol" and ship.has("patrol_from"):
		var leg_end: Vector2 = ship["patrol_start_point"] if bool(ship.get("patrol_returning", false)) else ship["patrol_end_point"]
		signature.append(leg_end)
		endpoint = screen_point.call(leg_end)
	elif kind in ["follow", "attack", "repair", "deposit"]:
		if poses.has(target):
			endpoint = poses[target]["point"]
		elif refs.has(target):
			var ref: Dictionary = refs[target]
			var world: Vector2 = ref.get("repair_position", ref["position"]) if kind == "repair" else ref["position"]
			endpoint = screen_point.call(world)
		if kind == "follow":
			tint = HUD.ACCENT
	else:
		var world: Vector2 = ECONOMY.unit_order_point(state, graph, ship, order)
		if world.is_finite():
			endpoint = screen_point.call(world)
		# Point orders and automatically chosen unload destinations must
		# actually agree; a shared sector alone is not enough.
		signature.append(world)
	if not endpoint.is_finite():
		return {}
	return {"signature": signature, "point": endpoint, "tint": tint}

func draw_group_command_line(state: Dictionary, poses: Dictionary, refs: Dictionary, selected_units: Array[int]) -> void:
	var graph: Dictionary = ECONOMY.military_graph(state)
	var shared: Dictionary = {}
	var center := Vector2.ZERO
	var count: int = 0
	for ship in state["ships"]:
		var id: int = int(ship["id"])
		if not selected_units.has(id):
			continue
		if not poses.has(id):
			return
		var command: Dictionary = _group_command_target(state, graph, ship, poses, refs)
		if command.is_empty():
			return
		if shared.is_empty():
			shared = command
		elif command["signature"] != shared["signature"]:
			return
		# Use attack-move color if a mixed fleet has armed members.
		elif command["tint"] == Color("#ff605c"):
			shared["tint"] = command["tint"]
		center += poses[id]["point"] as Vector2
		count += 1
	if count < 2 or count != selected_units.size():
		return
	center /= float(count)
	var finish: Vector2 = shared["point"]
	if center.distance_to(finish) > 1.0:
		# One direct intent indicator; individual ships may take different lanes.
		map_canvas.draw_line(center, finish, Color(shared["tint"], 0.8), 1.5, true)

# Drag placement orders already carry authoritative points and headings.
# Draw their original hull slots independently of shared command-line targets.
func draw_formation_order_ghost(ship: Dictionary, order: Dictionary, bounds: Rect2) -> void:
	if order.get("kind", "") not in ["position", "patrol"] or not order.get("heading") is Vector2 or not order.get("point") is Vector2:
		return
	var world: Vector2 = order["point"]
	if not world.is_finite():
		return
	var point: Vector2 = screen_point.call(world)
	if not bounds.has_point(point):
		return
	draw_destination_ghost(str(ship["kind"]), point, order["heading"], order_color(ship, order))

func draw_group_formation_ghosts(state: Dictionary, viewport_bounds: Rect2, selected_units: Array[int]) -> void:
	var bounds: Rect2 = viewport_bounds.grow(60.0 * maxf(0.42, ship_scale.call(false)))
	for ship in state["ships"]:
		if not selected_units.has(int(ship["id"])) or int(ship["owner"]) != local_player.call():
			continue
		var order: Dictionary = ship.get("unit_order", {})
		# Preserve the planned patrol endpoint on either leg and the move
		# destination through combat or repair. Completed orders disappear.
		if (order.get("kind", "") == "position" and ship.has("local_move_target")) or (order.get("kind", "") == "patrol" and ship.has("patrol_from")):
			draw_formation_order_ghost(ship, order, bounds)
		for queued in ship.get("order_queue", []):
			draw_formation_order_ghost(ship, queued, bounds)

func draw_queued_orders(state: Dictionary, graph: Dictionary, ship: Dictionary, start: Vector2, drawn_sectors: Dictionary) -> void:
	var order: Dictionary = ship.get("unit_order", {})
	var endpoint: Vector2 = ECONOMY.unit_order_point(state, graph, ship, order)
	if ship.has("patrol_from") and ship.get("patrol_returning", false):
		endpoint = ship["patrol_start_point"]
	if endpoint.is_finite() and ECONOMY._unit_order_running(ship):
		start = screen_point.call(endpoint)
	elif ship.has("launch_rally"):
		start = screen_point.call(ship["launch_rally"]["point"])
	for pending in ship.get("order_queue", []):
		endpoint = ECONOMY.unit_order_point(state, graph, ship, pending)
		if not endpoint.is_finite():
			continue
		var finish: Vector2 = screen_point.call(endpoint)
		var tint: Color = order_color(ship, pending)
		if pending["kind"] in ["sector", "sector_entry"]:
			draw_sector_target(graph, int(pending["target"]), tint, drawn_sectors)
		elif pending["kind"] == "position" or (pending["kind"] == "patrol" and pending.has("heading")):
			draw_destination_ghost(ship["kind"], finish, pending.get("heading", finish - start), tint)
		map_canvas.draw_dashed_line(start, finish, Color(tint, 0.45), 1.0, 5.0, true, true)
		start = finish

