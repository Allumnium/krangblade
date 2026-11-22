extends RefCounted
## Per-match station and shipyard presentation, including construction and cargo bays.
## Match owns selection, picking and visibility; authoritative rules own construction.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const HULL_ART = preload("res://scripts/hull_art.gd")
const WORLD_RENDER_BATCHES = preload("res://scripts/world_render_batches.gd")
const COMMAND_CARD_UI = preload("res://scripts/command_card_ui.gd")

var map_canvas: Control
var world_batches: WORLD_RENDER_BATCHES
var hull_art: HULL_ART
var command_card_ui: COMMAND_CARD_UI
var screen_point: Callable
var station_radius: Callable
var job_icon: Callable
var draw_damage_bar: Callable
var shield_fraction: Callable
var ship_scale: Callable
var overview_multiplier: Callable

func configure(canvas: Control, batches: WORLD_RENDER_BATCHES, art: HULL_ART, cards: COMMAND_CARD_UI, projection: Callable, radius_query: Callable, icon_query: Callable, damage_draw: Callable, shield_query: Callable, scale_query: Callable, overview_query: Callable) -> void:
	map_canvas = canvas
	world_batches = batches
	hull_art = art
	command_card_ui = cards
	screen_point = projection
	station_radius = radius_query
	job_icon = icon_query
	draw_damage_bar = damage_draw
	shield_fraction = shield_query
	ship_scale = scale_query
	overview_multiplier = overview_query

static func bay_point(center: Vector2, radius: float, elapsed: float, resource: String, bay: int) -> Vector2:
	var resources: Array = ECONOMY.RESOURCES + [ECONOMY.ANTIMATTER]
	var slot: int = resources.find(resource) * ECONOMY.STATION_STORAGE_BAYS + bay
	return center + Vector2.from_angle((float(slot) + 0.5) * TAU / float(resources.size() * ECONOMY.STATION_STORAGE_BAYS) + elapsed * 0.008) * radius * 0.71

func _draw_station_storage(system: Dictionary, center: Vector2, radius: float, elapsed: float) -> void:
	if radius < 8.0:
		return
	var half: float = radius * 0.115
	for resource in ECONOMY.RESOURCES + [ECONOMY.ANTIMATTER]:
		var color: Color = HUD.COLORS[resource]
		var fill: float = clampf(float(system["stock"].get(resource, 0.0)) / maxf(ECONOMY.EPS, ECONOMY.storage_capacity(system)), 0.0, 1.0) * ECONOMY.STATION_STORAGE_BAYS
		for bay in range(ECONOMY.STATION_STORAGE_BAYS):
			var point: Vector2 = bay_point(center, radius, elapsed, resource, bay)
			var bounds := Rect2(point - Vector2.ONE * half, Vector2.ONE * half * 2.0)
			map_canvas.draw_rect(bounds, Color("#111d2b"))
			var fraction: float = clampf(fill - float(bay), 0.0, 1.0)
			if fraction > 0.0:
				map_canvas.draw_rect(Rect2(bounds.position + Vector2(0.0, bounds.size.y * (1.0 - fraction)), Vector2(bounds.size.x, bounds.size.y * fraction)), color.darkened(0.25))
			map_canvas.draw_rect(bounds, color, false, maxf(0.8, radius * 0.018))

# Show current production lanes, not queued future yard work.
func _draw_station_jobs(system: Dictionary, center: Vector2, radius: float, tint: Color) -> void:
	if radius < 22.0 or not Rect2(Vector2.ZERO, map_canvas.size).grow(radius).has_point(center):
		return
	var jobs: Array = []
	var infrastructure: Dictionary = ECONOMY.station_construction_job(system)
	if not infrastructure.is_empty():
		jobs.append(infrastructure)
	if jobs.is_empty():
		return
	var columns: int = mini(2, jobs.size())
	var rows: int = ceili(float(jobs.size()) / float(columns))
	var cell: float = radius * (0.46 if jobs.size() == 1 else (0.30 if rows == 1 else 0.20))
	var gap: float = maxf(1.0, cell * 0.1)
	var step: float = cell + gap
	for i in range(jobs.size()):
		var job: Dictionary = jobs[i]
		var row: int = floori(float(i) / float(columns))
		var in_row: int = mini(columns, jobs.size() - row * columns)
		var point: Vector2 = center + Vector2((float(i % columns) - float(in_row - 1) * 0.5) * step, (float(row) - float(rows - 1) * 0.5) * step)
		var icon: Texture2D = job_icon.call(job, int(system["owner"]))
		var icon_size: float = cell * 0.82
		map_canvas.draw_texture_rect(icon, Rect2(point - Vector2(icon_size * 0.5, cell * 0.5), Vector2.ONE * icon_size), false)
		var width: float = cell * 0.92
		var height: float = maxf(1.0, cell * 0.09)
		var bar := Rect2(point + Vector2(-width * 0.5, cell * 0.39), Vector2(width, height))
		var fraction: float = clampf(float(job["progress"]) / maxf(ECONOMY.EPS, float(job["work"])), 0.0, 1.0)
		map_canvas.draw_rect(bar, Color("#101a26"))
		map_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), tint.lightened(0.35))

func draw_station(state: Dictionary, index: int, tint: Color, elapsed: float, building_selection_kind: String, selected_buildings: Dictionary) -> void:
	var system: Dictionary = state["planets"][index]
	if not ECONOMY.has_station(system):
		return
	var center: Vector2 = screen_point.call(ECONOMY.station_position(state, index, elapsed))
	var radius: float = station_radius.call()
	var frame: Color = Color("#71869b")
	var selected_station: bool = building_selection_kind == "station" and selected_buildings.has(Vector2i(index, 0))
	# Orbital hub with circular habitat/industrial ring, central docking
	# berth, and three fixed module attachment arms on its rotating frame.
	map_canvas.draw_circle(center, radius, Color("#131e2b"), true, -1.0, true)
	map_canvas.draw_arc(center, radius * 0.85, 0.0, TAU, 48, frame, maxf(2.0, radius * 0.22), true)
	map_canvas.draw_arc(center, radius, 0.0, TAU, 48, tint.lightened(0.30), maxf(1.0, radius * 0.055), true)
	map_canvas.draw_circle(center, radius * 0.32, Color("#293c51"), true, -1.0, true)
	map_canvas.draw_arc(center, radius * 0.35, 0.0, TAU, 24, tint, maxf(1.0, radius * 0.07), true)
	for slot in range(3):
		var axis: Vector2 = Vector2.from_angle(float(slot) * TAU / 3.0 + elapsed * 0.008)
		var side: Vector2 = axis.orthogonal()
		map_canvas.draw_line(center + axis * radius * 0.35, center + axis * radius * 0.87, frame.darkened(0.3), maxf(1.0, radius * 0.13), true)
		var port: Vector2 = center + axis * radius
		map_canvas.draw_line(port - side * radius * 0.18, port + side * radius * 0.18, tint.lightened(0.4), maxf(1.0, radius * 0.07), true)
		var yard_index: int = ECONOMY.shipyard_at_port(system, slot + 1)
		if yard_index >= 0:
			var dock: Vector2 = screen_point.call(ECONOMY.shipyard_position(state, index, yard_index, elapsed))
			map_canvas.draw_line(port, dock, frame, maxf(1.0, radius * 0.12), true)
	if radius >= 12.0:
		for segment in range(12):
			var a: float = float(segment) * TAU / 12.0 + elapsed * 0.008
			var direction: Vector2 = Vector2.from_angle(a)
			map_canvas.draw_line(center + direction * radius * 0.74, center + direction * radius * 0.95, Color("#1a293a"), maxf(1.0, radius * 0.05), true)
			map_canvas.draw_circle(center + direction * radius * 0.88, maxf(0.8, radius * 0.035), tint.lightened(0.4))
	_draw_station_storage(system, center, radius, elapsed)
	_draw_station_jobs(system, center, radius, tint)
	if selected_station:
		world_batches.draw_selection_ring(center, radius + 4.0)
	var hp: float = float(system["station"]["hp"]) / ECONOMY.station_max_hp(system)
	draw_damage_bar.call(center, radius, hp, shield_fraction.call(system["station"]))
	if shield_fraction.call(system["station"]) > 0.0:
		# Stations themselves have a circular hull; use a continuous glow.
		for band in [[3.0, 0.10], [1.75, 0.23], [0.65, 0.70]]:
			map_canvas.draw_arc(center, radius, 0.0, TAU, 48, Color(0.47, 0.8, 1.0, float(band[1])), float(band[0]), true)

func _draw_shipyard_construction(state: Dictionary, index: int, job: Dictionary, tint: Color, elapsed: float) -> void:
	var port: int = int(job.get("station_slot", job["level"]))
	var point: Vector2 = screen_point.call(ECONOMY.shipyard_port_position(state, index, port, elapsed))
	var scale: float = ship_scale.call(true)
	if not Rect2(Vector2.ZERO, map_canvas.size).grow(maxf(16.0, 32.0 * scale)).has_point(point):
		return
	var u: float = clampf(float(job["progress"]) / maxf(ECONOMY.EPS, float(job["work"])), 0.0, 1.0)
	var angle: float = float(port - 1) * TAU / 3.0 + elapsed * 0.008
	var lateral: Vector2 = Vector2.from_angle(angle) * scale
	var forward: Vector2 = lateral.orthogonal()
	if scale < 0.15 * overview_multiplier.call():
		map_canvas.draw_rect(Rect2(point - Vector2.ONE, Vector2.ONE * 2.0), Color(tint, 0.25 + u * 0.75))
		return
	for sign in [-1.0, 1.0]:
		var rail: Array = [Vector2(-17, sign * 8), Vector2(-15, sign * 13), Vector2(-10, sign * 14), Vector2(10, sign * 14), Vector2(15, sign * 13), Vector2(17, sign * 8), Vector2(12, sign * 7), Vector2(-12, sign * 7)]
		var hull: PackedVector2Array = hull_art.polygon(point, forward, lateral, rail)
		for k in range(hull.size()):
			var a: Vector2 = hull[k]
			var b: Vector2 = hull[(k + 1) % hull.size()]
			map_canvas.draw_line(a, b, Color(tint, 0.18), maxf(0.65, scale), true)
			var part: float = clampf(u * 2.0 * float(hull.size()) - float(k), 0.0, 1.0)
			if part > 0.0:
				map_canvas.draw_line(a, a.lerp(b, part), tint.lightened(0.4), maxf(0.65, scale), true)
		if u > 0.5:
			map_canvas.draw_colored_polygon(hull, Color(Color("#607387"), (u - 0.5) * 2.0))
	for end in [-1.0, 1.0]:
		var bridge: Vector2 = point + forward * end * 16.0
		map_canvas.draw_line(bridge - lateral * 8.5, bridge + lateral * 8.5, Color(tint, clampf(u * 2.0, 0.18, 1.0)), maxf(0.65, scale), true)

func draw_shipyards(state: Dictionary, index: int, tint: Color, elapsed: float, selected: int, selected_yard: int, building_selection_kind: String, selected_buildings: Dictionary) -> void:
	var planet: Dictionary = state["planets"][index]
	var pending: Dictionary = ECONOMY.station_construction_job(planet)
	if pending.get("kind", "") == "yard":
		_draw_shipyard_construction(state, index, pending, tint, elapsed)
	for slot in range(planet["yards"].size()):
		var yard: Dictionary = planet["yards"][slot]
		var scale: float = ship_scale.call(true) * pow(1.2, int(yard["level"]) - 1)
		var angle: float = float(ECONOMY.shipyard_port(planet, slot) - 1) * TAU / 3.0 + elapsed * 0.008
		var axis: Vector2 = Vector2.from_angle(angle)
		var side: Vector2 = axis.orthogonal()
		var point: Vector2 = screen_point.call(ECONOMY.shipyard_position(state, index, slot, elapsed))
		if not Rect2(Vector2.ZERO, map_canvas.size).grow(maxf(16.0, 32.0 * scale)).has_point(point):
			continue
		if scale < 0.15 * overview_multiplier.call():
			var half_size: float = overview_multiplier.call()
			map_canvas.draw_rect(Rect2(point - Vector2.ONE * half_size, Vector2.ONE * half_size * 2.0), tint.lightened(0.25))
			if (selected == index and selected_yard == slot) or (building_selection_kind == "shipyard" and selected_buildings.has(Vector2i(index, slot))):
				world_batches.draw_selection_ring(point, 9.0)
			continue
		var conversion: float = clampf((elapsed - float(yard.get("converted_at", -100.0))) / 3.0, 0.0, 1.0)
		var frame: PackedVector2Array = PackedVector2Array([point - axis * 11.0 * scale - side * 17.0 * scale, point + axis * 11.0 * scale - side * 17.0 * scale, point + axis * 11.0 * scale + side * 17.0 * scale, point - axis * 11.0 * scale + side * 17.0 * scale])
		if conversion < 1.0:
			var heading: Vector2 = yard.get("colony_heading", Vector2.UP)
			var cross: Vector2 = heading.orthogonal()
			var original := PackedVector2Array([point + heading * 6.0 * scale, point + cross * 3.5 * scale, point - heading * 4.5 * scale, point - cross * 3.5 * scale])
			for k in range(4):
				frame[k] = original[k].lerp(frame[k], smoothstep(0.0, 1.0, conversion))
			if not Geometry2D.triangulate_polygon(frame).is_empty():
				map_canvas.draw_colored_polygon(frame, Color(tint.lightened(0.35), 1.0 - conversion))
		if conversion < 1.0:
			for k in range(4):
				map_canvas.draw_line(frame[k], frame[(k + 1) % 4], tint, maxf(0.8, 2.0 * scale), true)
		else:
			# Industrial drydock: open central berth, two reinforced gantries,
			# habitat pods, end clamps and work lights. Draw the large
			# silhouette at every zoom, the finer hardware only up close.
			var forward: Vector2 = side * scale
			var lateral: Vector2 = axis * scale
			for sign in [-1.0, 1.0]:
				var rail: Array = [Vector2(-17, sign * 8), Vector2(-15, sign * 13), Vector2(-10, sign * 14), Vector2(10, sign * 14), Vector2(15, sign * 13), Vector2(17, sign * 8), Vector2(12, sign * 7), Vector2(-12, sign * 7)]
				var hull: PackedVector2Array = hull_art.polygon(point, forward, lateral, rail)
				map_canvas.draw_colored_polygon(hull, Color("#607387"))
				hull.append(hull[0])
				map_canvas.draw_polyline(hull, tint, maxf(0.65, scale), true)
				if scale >= 0.42:
					for longitudinal in [-8.0, 1.0, 9.0]:
						var module: Vector2 = point + forward * longitudinal + lateral * sign * 10.5
						var panel: PackedVector2Array = hull_art.polygon(module, forward, lateral, [Vector2(-3.5, -2), Vector2(3.5, -2), Vector2(3.5, 2), Vector2(-3.5, 2)])
						map_canvas.draw_colored_polygon(panel, Color("#23384b"))
						map_canvas.draw_line(module - forward * 2.4, module + forward * 2.4, Color("#b0d5e6"), maxf(0.65, scale), true)
					for end in [-1.0, 1.0]:
						var clamp_origin: Vector2 = point + forward * end * 14.0 + lateral * sign * 8.0
						map_canvas.draw_line(clamp_origin, clamp_origin - lateral * sign * 3.0, Color("#d6a965"), maxf(1.0, 2.0 * scale), true)
						map_canvas.draw_circle(clamp_origin, maxf(0.75, scale), tint.lightened(0.45))
			for end in [-1.0, 1.0]:
				var bridge: Vector2 = point + forward * end * 16.0
				map_canvas.draw_line(bridge - lateral * 8.5, bridge + lateral * 8.5, Color("#829aad"), maxf(0.8, 2.0 * scale), true)
			if scale >= 0.42:
				for end in [-1.0, 1.0]:
					var light: Vector2 = point + forward * end * 16.0
					map_canvas.draw_line(light - lateral * 3.0, light + lateral * 3.0, tint.lightened(0.4), maxf(0.7, scale), true)
		if (selected == index and selected_yard == slot) or (building_selection_kind == "shipyard" and selected_buildings.has(Vector2i(index, slot))):
			world_batches.draw_selection_ring(point, maxf(9.0, 23.0 * scale))
		var health: float = float(yard.get("hp", ECONOMY.YARD_HP * int(yard["level"]))) / (ECONOMY.YARD_HP * int(yard["level"]))
		draw_damage_bar.call(point, maxf(8.0, 22.0 * scale), health, -1.0)
		for job in planet["queue"]:
			if int(job["id"]) != int(yard["job"]):
				continue
			if job["kind"] == "yard_upgrade":
				var icon: Texture2D = command_card_ui.icon("upgrade")
				var icon_size: float = 14.0 * scale
				map_canvas.draw_texture_rect(icon, Rect2(point - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size), false)
				var fraction: float = clampf(float(job["progress"]) / maxf(ECONOMY.EPS, float(job["work"])), 0.0, 1.0)
				var bar := Rect2(point + Vector2(-7.0, 8.0) * scale, Vector2(14.0 * scale, maxf(1.0, 1.5 * scale)))
				map_canvas.draw_rect(bar, Color("#101a26"))
				map_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), tint.lightened(0.35))
				break
			if not ECONOMY.SHIP_KINDS.has(job["kind"]):
				continue
			var u: float = clampf(float(job["progress"]) / float(job["work"]), 0.0, 1.0)
			var shape: Array = HULL_ART.HULL_OUTLINES.get(str(job["kind"]), HULL_ART.FREIGHTER_OUTLINE)
			var hull := PackedVector2Array()
			for vertex in shape:
				hull.append(point + side * vertex.x * scale * 0.5 + axis * vertex.y * scale * 0.5)
			var edges: int = mini(hull.size(), floori(u * 2.0 * hull.size()))
			for k in range(edges):
				map_canvas.draw_line(hull[k], hull[(k + 1) % hull.size()], tint.lightened(0.4), 0.75 * scale, true)
			if u > 0.5 and not Geometry2D.triangulate_polygon(hull).is_empty():
				map_canvas.draw_colored_polygon(hull, Color(tint.lightened(0.4), (u - 0.5) * 2.0))
			break

