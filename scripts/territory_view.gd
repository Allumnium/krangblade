extends RefCounted
## Cached political polygons; the simulation owns site IDs and geometry.
const ECONOMY = preload("res://scripts/economy_rules.gd")

var friendly_sectors: Array[int] = []
var layer: Control
var radius: float = 1.0
var tints: Array[Color] = []
var region_graph: Dictionary = {}
var _region_cache: Dictionary = {}
var _mesh_root: Node2D
var _fill_material: ShaderMaterial
var _rim_material: ShaderMaterial
var _fills: Array[Polygon2D] = []
var _rims: Array[Line2D] = []
var _border_data: Array = []
var _extent: Vector2 = Vector2.ONE
var _line_scale: float = 0.0

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
	_fill_material = _fog_material(false)
	_rim_material = _fog_material(true)
	_mesh_root.hide()

func _fog_material(rim: bool) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D fog_data : filter_linear, repeat_disable;
uniform vec2 fog_uv_scale = vec2(1.0);
uniform vec2 map_extent = vec2(1.0);
uniform bool fog_ready = false;
uniform bool is_rim = false;
varying vec2 world_point;
void vertex() {
	world_point = VERTEX;
}
void fragment() {
	bool concealed = !fog_ready || texture(fog_data, world_point / map_extent * fog_uv_scale).a > 0.05;
	if (concealed) {
		COLOR = is_rim ? vec4(0.60, 0.68, 0.76, 0.17) : vec4(0.0);
	}
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("is_rim", rim)
	return material

func _rebuild_geometry(geometry: Dictionary, extent: Vector2) -> void:
	for child in _mesh_root.get_children():
		_mesh_root.remove_child(child)
		child.queue_free()
	_fills.clear()
	_rims.clear()
	_extent = extent.max(Vector2.ONE)
	_line_scale = 0.0
	for material in [_fill_material, _rim_material]:
		material.set_shader_parameter("map_extent", _extent)
	for polygon in geometry["polygons"]:
		var fill := Polygon2D.new()
		fill.polygon = polygon
		fill.visible = polygon.size() >= 3
		fill.material = _fill_material
		fill.color = Color.TRANSPARENT
		_mesh_root.add_child(fill)
		_fills.append(fill)
	_border_data = geometry["borders"]
	for border in _border_data:
		var line := Line2D.new()
		line.points = PackedVector2Array([border["a"], border["b"]])
		line.width = 1.0
		line.antialiased = true
		line.material = _rim_material
		_mesh_root.add_child(line)
		_rims.append(line)

func _apply_tints() -> void:
	for i in range(_fills.size()):
		var tint: Color = tints[i]
		_fills[i].color = Color(tint, tint.a * 0.10)
	for i in range(_rims.size()):
		var border: Dictionary = _border_data[i]
		var a: Color = tints[int(border["left"])]
		var b: Color = tints[int(border["right"])] if int(border["right"]) >= 0 else Color.TRANSPARENT
		var neutral := Color("#99adbf")
		var own: bool = a.a > 0.0 and b.a > 0.0 and Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b)) < 0.06
		var dominant: Color = a if a.a >= b.a else b
		var hue: Color = neutral.lerp(Color(dominant, 1.0), dominant.a)
		_rims[i].default_color = Color(hue, 0.15 if own else lerpf(0.18, 0.60, dominant.a))

func refresh(state: Dictionary, local_player: int, map_size: Vector2, roster: Dictionary, empire_color: Callable) -> bool:
	if state.is_empty():
		_mesh_root.hide()
		_region_cache.clear()
		region_graph = {}
		tints.clear()
		return false
	var graph: Dictionary = ECONOMY.military_graph(state)
	var points: Array = graph["points"]
	if points.is_empty():
		_mesh_root.hide()
		return false
	if not is_same(region_graph, graph):
		radius = ECONOMY.sector_base_radius(state["map"])
		tints.clear()
		_region_cache.clear()
		region_graph = graph
		_rebuild_geometry(ECONOMY.sector_geometry(graph), map_size)
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
	var colors: Dictionary = {}
	for player in roster:
		colors[player] = empire_color.call(int(player))
	var next_tints: Array[Color] = []
	for weights_by_player in weights:
		next_tints.append(ECONOMY.influence_color(weights_by_player, colors))
	if next_tints == tints:
		return false
	tints = next_tints
	_apply_tints()
	_mesh_root.show()
	return true

func set_fog(texture: ImageTexture, uv_scale: Vector2) -> void:
	for material in [_fill_material, _rim_material]:
		material.set_shader_parameter("fog_data", texture)
		material.set_shader_parameter("fog_uv_scale", uv_scale)
		material.set_shader_parameter("fog_ready", true)

func set_geometry(origin: Vector2, display_size: Vector2) -> void:
	var padding: Vector2 = Vector2.ONE * radius * 1.5
	var factor: Vector2 = display_size / (_extent + padding * 2.0)
	_mesh_root.position = origin + padding * factor
	_mesh_root.scale = factor
	var line_scale: float = 1.0 / maxf(0.00001, factor.x)
	if not is_equal_approx(line_scale, _line_scale):
		_line_scale = line_scale
		for line in _rims:
			line.width = line_scale * 1.2
