extends RefCounted
## Smooth, local presence shading. No political polygon or highway rendering.
## Navigation influence and warning destinations remain authoritative rule queries.
const ECONOMY = preload("res://scripts/economy_rules.gd")

var friendly_sectors: Array[int] = []
var layer: Control
var radius: float = 1.0
var region_graph: Dictionary = {}
var _region_cache: Dictionary = {}
var _mesh_root: Node2D
var _fill_material: ShaderMaterial
var _gradient: GradientTexture2D
var _presence: Array[Dictionary] = []
var _extent: Vector2 = Vector2.ONE

func build(parent: Control) -> void:
	layer = Control.new()
	layer.z_index = 3
	parent.add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.offset_left = 8
	layer.offset_top = 0
	layer.offset_right = -8
	layer.offset_bottom = -8
	layer.clip_contents = true
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mesh_root = Node2D.new()
	layer.add_child(_mesh_root)
	_fill_material = _fog_material()
	_mesh_root.material = _fill_material
	_mesh_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_mesh_root.draw.connect(_draw_presence)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.30, 0.65, 1.0])
	ramp.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.82), Color(1.0, 1.0, 1.0, 0.28), Color(1.0, 1.0, 1.0, 0.0)])
	_gradient = GradientTexture2D.new()
	_gradient.gradient = ramp
	_gradient.width = 128
	_gradient.height = 128
	_gradient.fill = GradientTexture2D.FILL_RADIAL
	_gradient.fill_from = Vector2(0.5, 0.5)
	_gradient.fill_to = Vector2(1.0, 0.5)
	_mesh_root.hide()

func _fog_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D fog_data : filter_linear, repeat_disable;
uniform vec2 fog_uv_scale = vec2(1.0);
uniform vec2 map_extent = vec2(1.0);
uniform bool fog_ready = false;
varying vec2 world_point;
void vertex() {
	world_point = VERTEX;
}
void fragment() {
	if (!fog_ready || any(lessThan(world_point, vec2(0.0))) || any(greaterThan(world_point, map_extent))) {
		COLOR.a = 0.0;
	} else {
		COLOR.a *= 1.0 - smoothstep(0.0, 0.05, texture(fog_data, world_point / map_extent * fog_uv_scale).a);
	}
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func refresh(state: Dictionary, local_player: int, map_size: Vector2, empire_color: Callable, fog_visible: Callable, ship_visible: Callable) -> bool:
	if state.is_empty():
		_mesh_root.hide()
		_presence.clear()
		friendly_sectors.clear()
		_region_cache.clear()
		region_graph = {}
		return false
	var graph: Dictionary = ECONOMY.military_graph(state)
	var points: Array = graph["points"]
	if points.is_empty():
		_mesh_root.hide()
		_presence.clear()
		friendly_sectors.clear()
		return false
	if not is_same(region_graph, graph):
		radius = ECONOMY.sector_base_radius(state["map"])
		_region_cache.clear()
		region_graph = graph
		_extent = map_size.max(Vector2.ONE)
		_fill_material.set_shader_parameter("map_extent", _extent)
	var known: Array[int] = ECONOMY.military_pois(state, local_player)
	var weights: Array[Dictionary] = ECONOMY.territory_influence(state, graph, known, _region_cache)
	# Only known sectors with a friendly majority are warning destinations.
	friendly_sectors.clear()
	for index in range(points.size()):
		if not known.has(index):
			continue
		var friendly: float = 0.0
		var hostile: float = 0.0
		for owner in weights[index]:
			if ECONOMY.empires_allied(state, local_player, int(owner)):
				friendly += float(weights[index][owner])
			else:
				hostile += float(weights[index][owner])
		if friendly > hostile or (index < state["planets"].size() and ECONOMY.has_station(state["planets"][index]) and ECONOMY.empires_allied(state, local_player, int(state["planets"][index]["owner"]))):
			friendly_sectors.append(index)

	var next_presence: Array[Dictionary] = []
	# Infrastructure casts a broad, soft area around its actual system.
	for index in range(state["planets"].size()):
		var system: Dictionary = state["planets"][index]
		var owner: int = int(system["owner"])
		if owner <= 0 or not ECONOMY.discovered(state, local_player, "planets", index) or not fog_visible.call(points[index]):
			continue
		var strength: float = float(ECONOMY.system_presence_weight(system))
		if strength > 0.0:
			var fraction: float = clampf(strength / ECONOMY.INFLUENCE_CAP, 0.0, 1.0)
			next_presence.append({"point": points[index], "radius": radius * lerpf(0.55, 1.0, fraction), "color": Color(empire_color.call(owner), lerpf(0.10, 0.28, fraction))})
	# Aggregate nearby visible ships by player to bound draw count for large fleets.
	# The weighted centroid tracks actual hull locations, not highway/sector sites.
	var groups: Dictionary = {}
	var cell_size: float = maxf(1.0, radius * 0.4)
	for ship in state["ships"]:
		var owner: int = int(ship["owner"])
		if owner <= 0 or float(ship.get("hp", ECONOMY.ship_max_hp(str(ship["kind"])))) <= 0.0 or not ship_visible.call(state, ship):
			continue
		var point: Vector2 = ECONOMY.combat_position(state, graph, ship)
		var weight: float = float(ECONOMY.ship_presence_weight(ship))
		var cell := Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))
		var key := Vector3i(cell.x, cell.y, owner)
		var group: Vector3 = groups.get(key, Vector3.ZERO)
		groups[key] = group + Vector3(point.x * weight, point.y * weight, weight)
	for key in groups:
		var group: Vector3 = groups[key]
		var fraction: float = clampf(group.z / ECONOMY.INFLUENCE_CAP, 0.0, 1.0)
		next_presence.append({"point": Vector2(group.x, group.y) / group.z, "radius": radius * lerpf(0.25, 0.72, fraction), "color": Color(empire_color.call(key.z), lerpf(0.075, 0.23, fraction))})
	if next_presence == _presence and _mesh_root.visible:
		return false
	_presence = next_presence
	_mesh_root.show()
	_mesh_root.queue_redraw()
	return true

func _draw_presence() -> void:
	draw_presence(_mesh_root, Vector2.ZERO, _extent, 1.0)

# The same soft footprints are drawn on the minimap before its fog and markers.
func draw_presence(canvas: CanvasItem, origin: Vector2, display_size: Vector2, opacity_scale: float = 1.5) -> void:
	if _gradient == null:
		return
	var factor: Vector2 = display_size / _extent
	var limits := Rect2(origin, display_size)
	var texture_size := Vector2(_gradient.get_width(), _gradient.get_height())
	for entry in _presence:
		var center: Vector2 = origin + entry["point"] * factor
		var spread: Vector2 = Vector2.ONE * float(entry["radius"]) * factor
		var rect := Rect2(center - spread, spread * 2.0)
		var clipped: Rect2 = rect.intersection(limits)
		if not clipped.has_area():
			continue
		var source := Rect2((clipped.position - rect.position) / rect.size * texture_size, clipped.size / rect.size * texture_size)
		var tint: Color = entry["color"]
		tint.a = minf(1.0, tint.a * opacity_scale)
		canvas.draw_texture_rect_region(_gradient, clipped, source, tint)

func set_fog(texture: ImageTexture, uv_scale: Vector2) -> void:
	_fill_material.set_shader_parameter("fog_data", texture)
	_fill_material.set_shader_parameter("fog_uv_scale", uv_scale)
	_fill_material.set_shader_parameter("fog_ready", true)

func set_geometry(origin: Vector2, display_size: Vector2) -> void:
	var padding: Vector2 = Vector2.ONE * radius * 1.5
	var factor: Vector2 = display_size / (_extent + padding * 2.0)
	_mesh_root.position = origin + padding * factor
	_mesh_root.scale = factor
