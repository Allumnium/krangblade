extends RefCounted
## Client logistics lens widget and resource/traffic presentation.
## Reads the same simulation queries as the match; does not dispatch gameplay orders.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const UI_TEXT = preload("res://scripts/ui_text.gd")
const CELESTIAL_VIEW = preload("res://scripts/celestial_view.gd")
const CAMERA_VIEW = preload("res://scripts/camera_view.gd")

var map_canvas: Control
var logistics_overlay: Control
var celestial_view: CELESTIAL_VIEW
var camera: CAMERA_VIEW
var screen_point: Callable
var station_radius: Callable
var fit_query: Callable
var local_player: Callable
var population_texture: Callable
var refresh_match: Callable
var logistics_lens: Button
var active_lens: String = "logistics"

func configure(canvas: Control, overlay: Control, celestial: CELESTIAL_VIEW, camera_view: CAMERA_VIEW, projection: Callable, radius_query: Callable, fit: Callable, player_query: Callable, icon_query: Callable, refresh_query: Callable) -> void:
	map_canvas = canvas
	logistics_overlay = overlay
	celestial_view = celestial
	camera = camera_view
	screen_point = projection
	station_radius = radius_query
	fit_query = fit
	local_player = player_query
	population_texture = icon_query
	refresh_match = refresh_query

func build(parent: Container, strip_width: float, make_button: Callable, make_icon: Callable) -> void:
	logistics_lens = make_button.call("", _toggle_lens.bind("logistics"), parent, false)
	# Linked cargo crates suggest the resource storage / logistics overlay.
	logistics_lens.icon = make_icon.call('<rect x="3" y="3" width="10" height="10" rx="1"/><rect x="19" y="19" width="10" height="10" rx="1"/><path d="M13 8H24V19M20 15L24 19L28 15M8 3V7M24 24V29"/>', 32)
	logistics_lens.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logistics_lens.expand_icon = true
	logistics_lens.add_theme_constant_override("icon_max_width", 24)
	logistics_lens.custom_minimum_size = Vector2.ONE * strip_width
	logistics_lens.toggle_mode = true
	logistics_lens.focus_mode = Control.FOCUS_NONE
	logistics_lens.tooltip_text = "Logistics lens · System resource storage"


func _toggle_lens(kind: String) -> void:
	refresh_match.call()
	active_lens = "" if active_lens == kind else kind
	logistics_lens.set_pressed_no_signal(active_lens == "logistics")
	map_canvas.queue_redraw()

func draw(state: Dictionary, font: Font) -> void:
	if active_lens != "logistics":
		return
	var team: int = ECONOMY._combat_group(state, local_player.call())
	var points: Array = state["map"]["points"]
	for i in range(points.size()):
		var system: Dictionary = state["planets"][i]
		if int(system["owner"]) == 0 or ECONOMY._combat_group(state, int(system["owner"])) != team or not ECONOMY.discovered(state, local_player.call(), "planets", i):
			continue
		if not ECONOMY.has_station(system):
			continue
		var pos: Vector2 = screen_point.call(ECONOMY.station_position(state, i, float(state["elapsed"])))
		var radius: float = station_radius.call()
		if not Rect2(Vector2.ZERO, map_canvas.size).grow(radius + 80.0).has_point(pos):
			continue
		var spacing: float = float(celestial_view.system_visual(i, state)["spacing"]) * fit_query.call() * camera.zoom
		var scale: float = clampf(spacing / 150.0, 0.22, 1.0)
		var origin: Vector2 = pos + Vector2(-94.0 * scale, radius + 5.0 * scale)
		logistics_overlay.draw_rect(Rect2(origin - Vector2.ONE * 3.0 * scale, Vector2(194, 34.0 + 32.0 * float(maxi(0, ceili(float(ECONOMY.RESOURCES.size()) / 3.0) - 1))) * scale), Color("#0c192899"))
		for r in range(ECONOMY.RESOURCES.size()):
			var resource: String = ECONOMY.RESOURCES[r]
			var cell: Vector2 = origin + Vector2(float(r % 3) * 47.0, floorf(float(r) / 3.0) * 32.0) * scale
			var fraction: float = clampf(float(system["stock"][resource]) / ECONOMY.storage_capacity(system), 0.0, 1.0)
			logistics_overlay.draw_rect(Rect2(cell, Vector2(44, 14) * scale), Color("#263b5080"))
			logistics_overlay.draw_rect(Rect2(cell, Vector2(44.0 * fraction, 14) * scale), HUD.COLORS[resource].darkened(0.4))
			logistics_overlay.draw_texture_rect(HUD.ICONS[resource], Rect2(cell, Vector2(13, 13) * scale), false)
			if scale >= 0.8:
				logistics_overlay.draw_string(font, cell + Vector2(15, 11) * scale, UI_TEXT.tons(float(system["stock"][resource]), 0, true), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
			var grade: int = ECONOMY.specialization_grade(system, resource)
			if grade != 0 and scale >= 0.55:
				var badge_pos: Vector2 = cell + Vector2(8, 16) * scale
				logistics_overlay.draw_texture_rect(HUD.ICONS[resource], Rect2(badge_pos, Vector2(11, 11) * scale), false)
				var marks: String = ("+" if grade > 0 else "-").repeat(absi(grade))
				logistics_overlay.draw_string(font, badge_pos + Vector2(13, 10) * scale, marks, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(9, roundi(13 * scale)), Color("#79e59a") if grade > 0 else Color("#ff7777"))
		var pop_cell: Vector2 = origin + Vector2(141, 0) * scale
		var population: float = float(system["population"])
		var capacity: float = maxf(1.0, ECONOMY.sustainable_population_capacity(system))
		logistics_overlay.draw_rect(Rect2(pop_cell, Vector2(50, 14) * scale), Color("#263b5080"))
		logistics_overlay.draw_rect(Rect2(pop_cell, Vector2(50 * clampf(population / capacity, 0.0, 1.0), 14) * scale), Color("#44647e"))
		logistics_overlay.draw_texture_rect(population_texture.call(24), Rect2(pop_cell, Vector2(13, 13) * scale), false)
		if scale >= 0.8:
			logistics_overlay.draw_string(font, pop_cell + Vector2(15, 11) * scale, "%.1fk" % (population / 1000.0) if population >= 1000 else str(int(population)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	# Aggregate loaded shipments at their origin and final destination.
	var traffic: Dictionary = {}
	for ship in state["ships"]:
		if ECONOMY._combat_group(state, int(ship["owner"])) != team or ship["kind"] != "ship" or ECONOMY._cargo_total(ship) <= ECONOMY.EPS:
			continue
		for endpoint in ["source", "dest"]:
			var node: int = int(ship.get(endpoint, -1))
			if node < 0 or node >= points.size():
				continue
			var lane: Array[int] = ECONOMY._path(state, ECONOMY.planet_teams(state), int(state["planets"][node]["team"]) if state["planets"][node].has("team") else int(ECONOMY.planet_teams(state)[node]), int(ship["source"]), int(ship["dest"]), {})
			if lane.size() < 2:
				continue
			var neighbor: int = lane[1] if endpoint == "source" else lane[lane.size() - 2]
			if not traffic.has(node):
				traffic[node] = {}
			var key: Vector2i = Vector2i(neighbor, 0 if endpoint == "source" else 1)
			if not traffic[node].has(key):
				traffic[node][key] = ECONOMY.empty_stock()
			for resource in ECONOMY.RESOURCES:
				traffic[node][key][resource] += float(ship["cargo"][resource])
	for node in traffic:
		if ECONOMY._combat_group(state, int(state["planets"][node]["owner"])) != team or not ECONOMY.has_station(state["planets"][node]) or not ECONOMY.discovered(state, local_player.call(), "planets", node):
			continue
		var center: Vector2 = screen_point.call(ECONOMY.station_position(state, node, float(state["elapsed"])))
		var radius: float = station_radius.call()
		for key in traffic[node]:
			var endpoint: String = "source" if key.y == 0 else "dest"
			for k in range(ECONOMY.RESOURCES.size()):
				var resource: String = ECONOMY.RESOURCES[k]
				var cargo: float = traffic[node][key][resource]
				if cargo <= ECONOMY.EPS:
					continue
				var radial: Vector2 = (screen_point.call(points[key.x]) - center).normalized()
				var axis: Vector2 = radial if endpoint == "source" else -radial
				var normal: Vector2 = axis.orthogonal()
				var base: Vector2 = center + radial * minf(radius + 24.0 + float(k) * 13.0, center.distance_to(screen_point.call(points[key.x])) * 0.48)
				var count: int = clampi(ceili(3.0 * cargo / ECONOMY.CARGO_CAPACITY), 1, 3)
				logistics_overlay.draw_texture_rect(HUD.ICONS[resource], Rect2(base + radial * 14.0 - Vector2(5, 5), Vector2(10, 10)), false)
				for j in range(count):
					var tip: Vector2 = base + axis * float(j * 5)
					logistics_overlay.draw_polyline(PackedVector2Array([tip - axis * 4.0 + normal * 3.0, tip, tip - axis * 4.0 - normal * 3.0]), HUD.COLORS[resource], 1.5, true)

