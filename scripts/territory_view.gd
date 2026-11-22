extends RefCounted
## Cached continuous building territory. Mobile hulls never create map claims.
## Legacy tactical warnings remain separate from the presentation field.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const FIELD_RESOLUTION: int = 384
const MAX_EMPIRES: int = 8
const SCORE_SCALE: float = 64.0
const CLAIM_THRESHOLD: int = 19

var friendly_sectors: Array[int] = []
var layer: Control
var region_graph: Dictionary = {}
var _region_cache: Dictionary = {}
var _mesh_root: Node2D
var _fill_material: ShaderMaterial
var _extent: Vector2 = Vector2.ONE
# Last observed infrastructure only; hidden enemy changes cannot alter claims.
var _observed: Dictionary = {}
var _signature: Array = []
var _field_low: ImageTexture
var _field_high: ImageTexture
var _palette: ImageTexture
var _minimap_texture: ImageTexture
var _viewer: int = 0
var _base_radius: float = 1.0

func build(parent: Control) -> void:
	layer = Control.new()
	# Draw behind stars, hulls, order markers and the existing fog mask.
	layer.z_index = 0
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
	_fill_material = _territory_material()
	_mesh_root.material = _fill_material
	_mesh_root.draw.connect(_draw_claims)
	_mesh_root.hide()

# Setup preview uses the actual starting infrastructure, without spawning fleets.
func prepare_preview(map_data: Dictionary, players: Dictionary, ordered: Array[int], colors: Array[Color]) -> void:
	_observed.clear()
	_minimap_texture = null
	if map_data.is_empty() or ordered.is_empty():
		return
	_extent = (map_data["size"] as Vector2).max(Vector2.ONE)
	_base_radius = ECONOMY.sector_base_radius(map_data)
	var state: Dictionary = ECONOMY.create(map_data, players, ordered, false)
	var palette_by_owner: Dictionary = {}
	for index in range(ordered.size()):
		var owner: int = ordered[index]
		palette_by_owner[owner] = colors[index]
		_observed[index] = {"point": map_data["points"][index], "owner": owner, "weight": mini(150, ECONOMY.system_presence_weight(state["planets"][index]))}
	_rebuild_field(func(owner: int) -> Color: return palette_by_owner[owner])

func _territory_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D field_low : filter_linear, repeat_disable;
uniform sampler2D field_high : filter_linear, repeat_disable;
uniform sampler2D palette : filter_nearest, repeat_disable;
uniform vec2 map_extent = vec2(1.0);
uniform float claim_threshold = 0.0745098;
varying vec2 world_point;
void vertex() {
	world_point = VERTEX;
}
void fragment() {
	vec2 uv = world_point / map_extent;
	vec4 lo = texture(field_low, uv);
	vec4 hi = texture(field_high, uv);
	float best = 0.0;
	float runner = 0.0;
	int winner = 0;
	for (int i = 0; i < 8; i++) {
		float strength = i < 4 ? lo[i] : hi[i - 4];
		if (strength > best) {
			runner = best;
			best = strength;
			winner = i;
		} else {
			runner = max(runner, strength);
		}
	}
	float edge = best - claim_threshold;
	float aa = max(fwidth(edge), 0.00005);
	float coverage = smoothstep(-aa, aa, edge);
	float difference = best - runner;
	float rival_width = max(fwidth(difference), 0.00005);
	float rim = max(1.0 - smoothstep(aa, aa * 2.1, abs(edge)),
		1.0 - smoothstep(rival_width, rival_width * 1.8, difference));
	vec3 tint = texture(palette, vec2((float(winner) + 0.5) / 8.0, 0.5)).rgb;
	COLOR = vec4(mix(tint, mix(tint, vec3(1.0), 0.24), rim), coverage * mix(0.095, 0.38, rim));
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("claim_threshold", float(CLAIM_THRESHOLD) / 255.0)
	return material

func refresh(state: Dictionary, local_player: int, map_size: Vector2, empire_color: Callable, fog_visible: Callable) -> bool:
	if state.is_empty():
		_mesh_root.hide()
		_observed.clear()
		_signature.clear()
		_minimap_texture = null
		friendly_sectors.clear()
		_region_cache.clear()
		region_graph = {}
		_viewer = 0
		return false
	var graph: Dictionary = ECONOMY.military_graph(state)
	var points: Array = graph["points"]
	if points.is_empty():
		_mesh_root.hide()
		_minimap_texture = null
		return false
	if not is_same(region_graph, graph) or _viewer != local_player:
		_base_radius = ECONOMY.sector_base_radius(state["map"])
		_region_cache.clear()
		_observed.clear()
		_signature.clear()
		region_graph = graph
		_viewer = local_player
		_extent = map_size.max(Vector2.ONE)
		_fill_material.set_shader_parameter("map_extent", _extent)
	_refresh_warning_destinations(state, local_player, graph)
	# Only completed infrastructure contributes. Remember explored claims
	# through fog, but never read an unseen opponent's changed ownership.
	for index in range(state["planets"].size()):
		var system: Dictionary = state["planets"][index]
		var owner: int = int(system["owner"])
		if owner != local_player and not fog_visible.call(points[index]):
			if int(_observed.get(index, {}).get("owner", -1)) == local_player:
				_observed.erase(index)
			continue
		var weight: int = ECONOMY.system_presence_weight(system)
		if owner <= 0 or weight <= 0:
			_observed.erase(index)
		else:
			_observed[index] = {"point": points[index], "owner": owner, "weight": mini(weight, 150)}
	var next_signature: Array = []
	var sites: Array = _observed.keys()
	sites.sort()
	for site in sites:
		var source: Dictionary = _observed[site]
		next_signature.append([site, source["owner"], source["weight"], empire_color.call(int(source["owner"]))])
	if next_signature == _signature and _mesh_root.visible:
		return false
	_signature = next_signature
	_rebuild_field(empire_color)
	_mesh_root.show()
	_mesh_root.queue_redraw()
	return true

func _refresh_warning_destinations(state: Dictionary, local_player: int, graph: Dictionary) -> void:
	var points: Array = graph["points"]
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


# Bake compact radial kernels into two four-channel ownership fields. A
# threshold on the sum merges allied infrastructure without sector cells.
# GPU bilinear sampling resolves smooth boundaries at any camera zoom.
func _rebuild_field(empire_color: Callable) -> void:
	var factor: float = float(FIELD_RESOLUTION) / maxf(_extent.x, _extent.y)
	var dimensions := Vector2i(maxi(2, ceili(_extent.x * factor)), maxi(2, ceili(_extent.y * factor)))
	var pixel_count: int = dimensions.x * dimensions.y
	var low := PackedByteArray()
	var high := PackedByteArray()
	low.resize(pixel_count * 4)
	high.resize(pixel_count * 4)
	var owners: Array[int] = []
	for source in _observed.values():
		var owner: int = int(source["owner"])
		if not owners.has(owner):
			owners.append(owner)
	owners.sort()
	var colors := PackedColorArray()
	colors.resize(MAX_EMPIRES)
	var palette_image := Image.create(MAX_EMPIRES, 1, false, Image.FORMAT_RGBA8)
	for slot in range(mini(owners.size(), MAX_EMPIRES)):
		colors[slot] = empire_color.call(owners[slot])
		palette_image.set_pixel(slot, 0, Color(colors[slot], 1.0))
	var sites: Array = _observed.keys()
	sites.sort()
	for site in sites:
		var source: Dictionary = _observed[site]
		var slot: int = owners.find(int(source["owner"]))
		if slot < 0 or slot >= MAX_EMPIRES:
			continue
		if slot < 4:
			_stamp_field(low, dimensions, source, slot)
		else:
			_stamp_field(high, dimensions, source, slot - 4)
	_field_low = ImageTexture.create_from_image(Image.create_from_data(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8, low))
	_field_high = ImageTexture.create_from_image(Image.create_from_data(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8, high))
	_palette = ImageTexture.create_from_image(palette_image)
	if _fill_material != null:
		_fill_material.set_shader_parameter("field_low", _field_low)
		_fill_material.set_shader_parameter("field_high", _field_high)
		_fill_material.set_shader_parameter("palette", _palette)
	# The small minimap uses the same cached samples, winner and threshold.
	var pixels := PackedByteArray()
	pixels.resize(pixel_count * 4)
	for pixel in range(pixel_count):
		var offset: int = pixel * 4
		var best: int = 0
		var runner: int = 0
		var winner: int = 0
		for slot in range(mini(owners.size(), MAX_EMPIRES)):
			var strength: int = low[offset + slot] if slot < 4 else high[offset + slot - 4]
			if strength > best:
				runner = best
				best = strength
				winner = slot
			else:
				runner = maxi(runner, strength)
		if best < CLAIM_THRESHOLD:
			continue
		var tint: Color = colors[winner]
		pixels[offset] = roundi(tint.r * 255.0)
		pixels[offset + 1] = roundi(tint.g * 255.0)
		pixels[offset + 2] = roundi(tint.b * 255.0)
		pixels[offset + 3] = 95 if best - CLAIM_THRESHOLD <= 3 or best - runner <= 3 else 45
	_minimap_texture = ImageTexture.create_from_image(Image.create_from_data(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8, pixels))

func _stamp_field(data: PackedByteArray, dimensions: Vector2i, source: Dictionary, channel: int) -> void:
	var development: float = clampf(float(source["weight"]) / 150.0, 0.0, 1.0)
	var reach: float = 2.0 * _base_radius * lerpf(1.12, 1.52, development)
	var peak: float = lerpf(0.88, 1.65, development) * SCORE_SCALE
	var scale: Vector2 = Vector2(dimensions) / _extent
	var center: Vector2 = source["point"]
	var start: Vector2i = Vector2i(((center - Vector2.ONE * reach) * scale).floor()).max(Vector2i.ZERO)
	var finish: Vector2i = Vector2i(((center + Vector2.ONE * reach) * scale).ceil()).min(dimensions - Vector2i.ONE)
	for y in range(start.y, finish.y + 1):
		for x in range(start.x, finish.x + 1):
			var world: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) / scale
			var remaining: float = 1.0 - world.distance_squared_to(center) / (reach * reach)
			if remaining <= 0.0:
				continue
			var offset: int = (y * dimensions.x + x) * 4 + channel
			data[offset] = mini(255, int(data[offset]) + roundi(peak * remaining * remaining))

func _draw_claims() -> void:
	if _field_low != null:
		_mesh_root.draw_rect(Rect2(Vector2.ZERO, _extent), Color.WHITE)

func draw_claims(canvas: CanvasItem, origin: Vector2, display_size: Vector2) -> void:
	if _minimap_texture != null:
		canvas.draw_texture_rect(_minimap_texture, Rect2(origin, display_size), false)

func set_geometry(origin: Vector2, display_size: Vector2) -> void:
	_mesh_root.position = origin
	_mesh_root.scale = display_size / _extent
