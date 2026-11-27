extends RefCounted
## Planetary production inspector helpers and visual-only upgrade deliveries.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const CELESTIAL_VIEW = preload("res://scripts/celestial_view.gd")
const HULL_ART = preload("res://scripts/hull_art.gd")

var map_canvas: Control
var celestial_view: CELESTIAL_VIEW
var hull_art: HULL_ART
var screen_point: Callable
var station_radius: Callable
var job_icon: Callable

func configure(canvas: Control, celestial: CELESTIAL_VIEW, art: HULL_ART, projection: Callable, radius_query: Callable, icon_query: Callable) -> void:
	map_canvas = canvas
	celestial_view = celestial
	hull_art = art
	screen_point = projection
	station_radius = radius_query
	job_icon = icon_query

func production_sources(bodies: Array, resource: String) -> Array:
	var sources: Array = []
	for slot in range(bodies.size()):
		if bodies[slot]["resource"] == resource:
			sources.append(slot)
	if sources.is_empty() and not bodies.is_empty():
		sources.append(0)
	return sources

func production_rate(system: Dictionary, resource: String) -> float:
	if not ECONOMY.has_station(system) or bool(system.get("planet_blockaded", false)):
		return 0.0
	var output: float = ECONOMY.local_flow(system, "Production", resource)
	if resource == "Organics":
		output = maxf(0.0, output - ECONOMY.eco_organics(system))
	return output

func _draw_planet_cargo_pod(point: Vector2, axis: Vector2, size_factor: float, color: Color, alpha: float) -> void:
	var forward: Vector2 = axis * size_factor
	var side: Vector2 = axis.orthogonal() * size_factor
	var hull: PackedVector2Array = hull_art.polygon(point, forward, side, [Vector2(0.72, 0.32), Vector2(0.40, 0.48), Vector2(-0.55, 0.82), Vector2(-0.82, 0.61), Vector2(-0.82, -0.61), Vector2(-0.55, -0.82), Vector2(0.40, -0.48), Vector2(0.72, -0.32)])
	map_canvas.draw_colored_polygon(hull, Color(Color("#a9bfd2"), alpha))
	var cargo: PackedVector2Array = hull_art.polygon(point, forward, side, [Vector2(0.35, 0.30), Vector2(-0.58, 0.50), Vector2(-0.58, -0.50), Vector2(0.35, -0.30)])
	map_canvas.draw_colored_polygon(cargo, Color(color, alpha))
	for sign in [-1.0, 1.0]:
		var jet: Vector2 = point - forward * 0.38 + side * sign * 0.79
		map_canvas.draw_circle(jet, size_factor * 0.24, Color(Color("#526b80"), alpha), true)
		map_canvas.draw_line(jet - forward * 0.18, jet - forward * 0.67, Color(Color("#a1eaff"), alpha * 0.85), maxf(0.2, size_factor * 0.20), true)

func draw_upgrade_deliveries(state: Dictionary, index: int, center: Vector2, radius: float, detail: float) -> void:
	if detail < 0.05:
		return
	var system: Dictionary = state["planets"][index]
	var bodies: Array = celestial_view.system_visual(index, state)["bodies"]
	var elapsed: float = celestial_view.orbit_time(state)
	for item in system["queue"]:
		if not item.has("delivery_slot"):
			continue
		var slot: int = int(item["delivery_slot"])
		if slot < 0 or slot >= bodies.size():
			continue
		var fraction: float = 1.0 - clampf(float(item["delivery_remaining"]) / ECONOMY.PLANET_UPGRADE_DELIVERY_TIME, 0.0, 1.0)
		var origin: Vector2 = screen_point.call(ECONOMY.station_position(state, index, elapsed))
		var destination: Vector2 = center + celestial_view.body_position(bodies[slot], radius, elapsed)
		var point: Vector2 = origin.lerp(destination, fraction)
		var pod_size: float = clampf(radius * 0.025, 2.0, 8.0) * 0.75
		var color: Color = HUD.COLORS.get(str(item["target"]), Color("#d7b774")) if item["kind"] in ["economy_building", "production"] else Color("#d7b774")
		_draw_planet_cargo_pod(point, origin.direction_to(destination), pod_size, color, detail)
		var icon: Texture2D = job_icon.call(item, int(system["owner"]))
		var icon_size: float = pod_size * 0.85
		if icon_size >= 4.0:
			map_canvas.draw_texture_rect(icon, Rect2(point - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size), false, Color(1.0, 1.0, 1.0, detail))
