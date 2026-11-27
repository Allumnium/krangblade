extends RefCounted
## Per-match GPU instance batches and their texture/extent caches.
## The match decides draw order and submits projected geometry; no gameplay state.
const HUD = preload("res://scripts/ui_theme.gd")
const HULL_ART = preload("res://scripts/hull_art.gd")
const CLOAK_OPACITY: float = 0.30

var map_canvas: Control
var health_batch: MultiMeshInstance2D
var ring_batch: MultiMeshInstance2D
var health_entries: Array = []
var ring_entries: Array = []
var cargo_batch: MultiMeshInstance2D
var cargo_glow_batch: MultiMeshInstance2D
var cargo_entries: Array = []
var cargo_glow_entries: Array = []
var beam_batch: MultiMeshInstance2D
var projectile_batch: MultiMeshInstance2D
var beam_instances: Array = []
var projectile_instances: Array = []
var exhaust_batch: MultiMeshInstance2D
var exhaust_instances: Array = []
var exhaust_extents: Dictionary = {}
var overview_batches: Dictionary = {}
var overview_instances: Dictionary = {}
var cloaked_overview_batches: Dictionary = {}
var cloaked_overview_instances: Dictionary = {}
var overview_dot_textures: Dictionary = {}
var resource_glow_texture: Texture2D
var lamp_glow_batch: MultiMeshInstance2D
var lamp_glow_entries: Array = []
const HULL_LIGHTING = preload("res://assets/shaders/world_hull_lighting.gdshader")
var vector_lighting: ShaderMaterial
var science_lighting: ShaderMaterial
var fighter_lighting: ShaderMaterial
var freighter_lighting: ShaderMaterial
var world_lights: Array = []
var shadow_discs: Array = []
var shadow_uniforms := PackedVector4Array()
var planet_lighting: ShaderMaterial

func _lighting_material(kind: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = HULL_LIGHTING
	material.set_shader_parameter("authored_sprite", HULL_ART.has_authored_sprite(kind))
	if kind == "science_ship":
		material.set_shader_parameter("normal_map", preload("res://assets/sprites/science-vessel/pixellab-top-down-science-vessel-space--1795754091586_n.png"))
		material.set_shader_parameter("occlusion_map", preload("res://assets/sprites/science-vessel/pixellab-top-down-science-vessel-space--1795754091586_o.png"))
		material.set_shader_parameter("height_map", preload("res://assets/sprites/science-vessel/pixellab-top-down-science-vessel-space--1795754091586_p.png"))
		material.set_shader_parameter("specular_map", preload("res://assets/sprites/science-vessel/pixellab-top-down-science-vessel-space--1795754091586_s.png"))
	elif kind == "fighter":
		material.set_shader_parameter("normal_map", _fighter_map(preload("res://assets/sprites/fighters/pixellab-top-down-white-large-space-shi-1795757475423_n.png")))
		material.set_shader_parameter("occlusion_map", _fighter_map(preload("res://assets/sprites/fighters/pixellab-top-down-white-large-space-shi-1795757475423_o.png")))
		material.set_shader_parameter("height_map", _fighter_map(preload("res://assets/sprites/fighters/pixellab-top-down-white-large-space-shi-1795757475423_p.png")))
		material.set_shader_parameter("specular_map", _fighter_map(preload("res://assets/sprites/fighters/pixellab-top-down-white-large-space-shi-1795757475423_s.png")))
	elif kind == "ship":
		material.set_shader_parameter("normal_map", _freighter_map(preload("res://assets/sprites/freighters/pixellab-top-down-white-large-space-shi-1795760979407_n.png")))
		material.set_shader_parameter("occlusion_map", _freighter_map(preload("res://assets/sprites/freighters/pixellab-top-down-white-large-space-shi-1795760979407_o.png")))
		material.set_shader_parameter("height_map", _freighter_map(preload("res://assets/sprites/freighters/pixellab-top-down-white-large-space-shi-1795760979407_p.png")))
		material.set_shader_parameter("specular_map", _freighter_map(preload("res://assets/sprites/freighters/pixellab-top-down-white-large-space-shi-1795760979407_s.png")))
	return material

func _freighter_map(atlas: Texture2D) -> Texture2D:
	return ImageTexture.create_from_image(HULL_ART.sprite_cell(atlas, HULL_ART.FREIGHTER_GRID, HULL_ART.FREIGHTER_GRID))

func _fighter_map(atlas: Texture2D) -> Texture2D:
	return ImageTexture.create_from_image(HULL_ART.sprite_cell(atlas, HULL_ART.FIGHTER_GRID, HULL_ART.FIGHTER_GRID))

func set_world_lights(lights: Array, blockers: Array = []) -> void:
	world_lights = lights
	shadow_discs = blockers
	var positions := PackedVector4Array()
	var colors := PackedVector4Array()
	var canvas_transform: Transform2D = map_canvas.get_global_transform_with_canvas()
	var radius_scale: float = canvas_transform.x.length()
	positions.resize(16)
	colors.resize(16)
	shadow_uniforms.resize(8)
	for i in range(mini(8, blockers.size())):
		var pos: Vector2 = canvas_transform * (blockers[i][0] as Vector2)
		shadow_uniforms[i] = Vector4(pos.x, pos.y, float(blockers[i][1]) * radius_scale, 0.0)
	for i in range(mini(16, lights.size())):
		var entry: Array = lights[i]
		var pos: Vector2 = canvas_transform * (entry[0] as Vector2)
		var tint: Color = entry[2]
		positions[i] = Vector4(pos.x, pos.y, float(entry[1]) * radius_scale, float(entry[3]))
		colors[i] = Vector4(tint.r, tint.g, tint.b, 1.0 if entry.size() > 5 and bool(entry[5]) else 0.0)
	for material in [vector_lighting, science_lighting, fighter_lighting, freighter_lighting, planet_lighting]:
		material.set_shader_parameter("light_points", positions)
		material.set_shader_parameter("light_colors", colors)
		material.set_shader_parameter("light_count", mini(16, lights.size()))
		if material == planet_lighting:
			material.set_shader_parameter("shadow_discs", shadow_uniforms)
			material.set_shader_parameter("shadow_count", mini(8, blockers.size()))

func light_level(point: Vector2, normal: Vector2 = Vector2.ZERO, _receiver: Vector2 = Vector2.INF) -> float:
	var amount: float = 0.035
	for entry in world_lights:
		var delta: Vector2 = (entry[0] as Vector2) - point
		var falloff: float = maxf(0.0, 1.0 - delta.length() / maxf(1.0, float(entry[1])))
		if falloff <= 0.0:
			continue
		var facing: float = 1.0 if normal.is_zero_approx() else 0.035 + 0.965 * maxf(0.0, normal.dot(delta.normalized()))
		amount += falloff * falloff * float(entry[3]) * facing
	return clampf(amount, 0.035, 1.0)


# Persistent packed transform staging, one stream per texture/opacity.
class HullInstanceStream:
	var buffer := PackedFloat32Array()
	var count: int = 0

	func append_transform(t: Transform2D) -> void:
		if count * 8 >= buffer.size():
			buffer.resize(maxi(64, count * 2) * 8)
		var offset: int = count * 8
		buffer[offset] = t.x.x
		buffer[offset + 1] = t.y.x
		buffer[offset + 3] = t.origin.x
		buffer[offset + 4] = t.x.y
		buffer[offset + 5] = t.y.y
		buffer[offset + 7] = t.origin.y
		count += 1

func build(canvas: Control) -> void:
	map_canvas = canvas
	vector_lighting = _lighting_material("")
	science_lighting = _lighting_material("science_ship")
	fighter_lighting = _lighting_material("fighter")
	freighter_lighting = _lighting_material("ship")
	planet_lighting = _lighting_material("")
	planet_lighting.set_shader_parameter("spherical_surface", true)
	_build_exhaust_batch()
	lamp_glow_batch = _build_effect_batch(false)
	lamp_glow_batch.texture = _resource_glow()
	var glow_shader := Shader.new()
	glow_shader.code = "shader_type canvas_item; render_mode unshaded, blend_add;"
	var glow_material := ShaderMaterial.new()
	glow_material.shader = glow_shader
	lamp_glow_batch.material = glow_material
	beam_batch = _build_effect_batch(false)
	projectile_batch = _build_effect_batch(true)
	health_batch = _build_effect_batch(false)
	health_batch.z_index = 2
	ring_batch = _build_ring_batch()
	cargo_batch = _build_effect_batch(false)
	cargo_glow_batch = _build_effect_batch(false)
	cargo_glow_batch.texture = _resource_glow()
	cargo_batch.z_index = 1
	cargo_glow_batch.z_index = 1

func begin_frame() -> void:
	lamp_glow_entries.clear()
	lamp_glow_batch.hide()
	health_entries.clear()
	ring_entries.clear()
	health_batch.hide()
	ring_batch.hide()
	cargo_entries.clear()
	cargo_glow_entries.clear()
	cargo_batch.hide()
	cargo_glow_batch.hide()
	beam_instances.clear()
	projectile_instances.clear()
	beam_batch.hide()
	projectile_batch.hide()
	exhaust_instances.clear()
	exhaust_batch.hide()
	for stream in overview_instances.values():
		stream.count = 0
	for batch in overview_batches.values():
		batch.hide()
	for stream in cloaked_overview_instances.values():
		stream.count = 0
	for batch in cloaked_overview_batches.values():
		batch.hide()

func flush_world(visual_clock: float, hull_art: HULL_ART) -> void:
	_flush_effect_batch(lamp_glow_batch, lamp_glow_entries)
	_flush_exhaust(visual_clock)
	_flush_effect_batch(beam_batch, beam_instances)
	_flush_effect_batch(projectile_batch, projectile_instances)
	_flush_overview_hulls(hull_art)
	_flush_effect_batch(cargo_batch, cargo_entries)
	_flush_effect_batch(cargo_glow_batch, cargo_glow_entries)

func flush_indicators() -> void:
	_flush_effect_batch(health_batch, health_entries)
	_flush_effect_batch(ring_batch, ring_entries)

func queue_health_rect(rect: Rect2, tint: Color) -> void:
	if rect.size.x <= 0.0 or not rect.intersects(Rect2(Vector2.ZERO, map_canvas.size), true):
		return
	health_entries.append([Transform2D(0.0, rect.size, 0.0, rect.get_center()), tint])

func _build_effect_batch(round_sprite: bool) -> MultiMeshInstance2D:
	var batch := MultiMeshInstance2D.new()
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_2D
	mesh.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mesh.mesh = quad
	batch.multimesh = mesh
	if round_sprite:
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;
render_mode unshaded;
void fragment() {
	float edge = 1.0 - smoothstep(0.85, 1.0, length(UV * 2.0 - 1.0));
	COLOR.a *= edge;
}
"""
		var material := ShaderMaterial.new()
		material.shader = shader
		batch.material = material
	map_canvas.add_child(batch)
	batch.hide()
	return batch

func queue_beam(origin: Vector2, target: Vector2, tint: Color, width: float) -> void:
	var axis: Vector2 = target - origin
	var length: float = axis.length()
	if length <= 0.001:
		return
	var bounds := Rect2(origin, axis).abs().grow(width)
	if not bounds.intersects(Rect2(Vector2.ZERO, map_canvas.size), true):
		return
	beam_instances.append([Transform2D(axis.angle(), Vector2(length, width), 0.0, (origin + target) * 0.5), tint])

func queue_projectile(point: Vector2, radius: float, tint: Color) -> void:
	if not Rect2(Vector2.ZERO, map_canvas.size).grow(radius).has_point(point):
		return
	projectile_instances.append([Transform2D(0.0, Vector2.ONE * radius * 2.0, 0.0, point), tint])

func _flush_effect_batch(batch: MultiMeshInstance2D, entries: Array) -> void:
	if entries.is_empty():
		return
	var mesh: MultiMesh = batch.multimesh
	if mesh.instance_count < entries.size():
		mesh.instance_count = maxi(entries.size(), maxi(64, mesh.instance_count * 2))
	var buffer := PackedFloat32Array()
	buffer.resize(mesh.instance_count * 12)
	for i in range(entries.size()):
		var t: Transform2D = entries[i][0]
		var tint: Color = entries[i][1]
		var offset: int = i * 12
		buffer[offset] = t.x.x
		buffer[offset + 1] = t.y.x
		buffer[offset + 3] = t.origin.x
		buffer[offset + 4] = t.x.y
		buffer[offset + 5] = t.y.y
		buffer[offset + 7] = t.origin.y
		buffer[offset + 8] = tint.r
		buffer[offset + 9] = tint.g
		buffer[offset + 10] = tint.b
		buffer[offset + 11] = tint.a
	mesh.buffer = buffer
	mesh.visible_instance_count = entries.size()
	batch.show()

func _build_ring_batch() -> MultiMeshInstance2D:
	var batch: MultiMeshInstance2D = _build_effect_batch(false)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;
varying float radius;
void vertex() {
	radius = max(1.0, length(MODEL_MATRIX[0].xy) * 0.5 - 2.0);
}
void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * (radius + 2.0);
	float angle = atan(p.y, p.x);
	float count = clamp(floor(6.2831853 * radius / 9.0 + 0.5), 6.0, 128.0);
	float phase = fract(angle / 6.2831853 * count);
	float rim = 1.0 - smoothstep(0.12, 0.85, abs(length(p) - radius));
	float dash = 1.0 - smoothstep(0.67, 0.75, phase);
	COLOR.a *= rim * dash * 0.72;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	batch.material = material
	batch.z_index = 2
	return batch

func draw_selection_ring(point: Vector2, radius: float, tint: Color = HUD.ACCENT) -> void:
	var extent: float = radius + 2.0
	if not Rect2(Vector2.ZERO, map_canvas.size).grow(extent).has_point(point):
		return
	ring_entries.append([Transform2D(0.0, Vector2.ONE * extent * 2.0, 0.0, point), tint])

func _resource_glow() -> Texture2D:
	if is_instance_valid(resource_glow_texture):
		return resource_glow_texture
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var radius: float = ((Vector2(x + 0.5, y + 0.5) - Vector2(32.0, 32.0)) / 32.0).length()
			var alpha: float = pow(maxf(0.0, 1.0 - radius * radius), 3.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	resource_glow_texture = ImageTexture.create_from_image(image)
	return resource_glow_texture

func queue_lamp_glow(point: Vector2, radius: float, tint: Color, strength: float) -> void:
	if not Rect2(Vector2.ZERO, map_canvas.size).grow(radius).has_point(point):
		return
	lamp_glow_entries.append([Transform2D(0.0, Vector2.ONE * radius * 2.0, 0.0, point), Color(tint, strength)])

func queue_cargo_light(point: Vector2, radius: float, tint: Color, strength: float) -> void:
	if not Rect2(Vector2.ZERO, map_canvas.size).grow(radius).has_point(point):
		return
	cargo_glow_entries.append([Transform2D(0.0, Vector2.ONE * radius * 2.0, 0.0, point), Color(tint, strength)])

func draw_resource_glow(point: Vector2, radius: float, tint: Color, strength: float) -> void:
	var extent: float = maxf(1.5, radius)
	map_canvas.draw_texture_rect(_resource_glow(), Rect2(point - Vector2.ONE * extent, Vector2.ONE * extent * 2.0), false, Color(tint.lightened(0.12), strength))

func queue_cargo_rect(shape: PackedVector2Array, tint: Color) -> void:
	var axis: Vector2 = shape[0] - shape[1]
	var width: float = shape[1].distance_to(shape[2])
	cargo_entries.append([Transform2D(axis.angle(), Vector2(axis.length(), width), 0.0, (shape[0] + shape[2]) * 0.5), tint])

func draw_cargo_segment(shape: PackedVector2Array, tint: Color) -> void:
	queue_cargo_rect(shape, tint.lightened(0.14))
	var length: float = shape[0].distance_to(shape[1])
	var width: float = shape[1].distance_to(shape[2])
	if minf(length, width) < 0.8:
		return
	var center: Vector2 = (shape[0] + shape[2]) * 0.5
	var extent: float = clampf(maxf(length, width) * 0.9, 2.0, 48.0)
	var strength: float = 0.32 * clampf(length / maxf(width, 0.1), 0.25, 1.0)
	cargo_glow_entries.append([Transform2D(0.0, Vector2.ONE * extent * 2.0, 0.0, center), Color(tint.lightened(0.12), strength)])

# One GPU-instanced quad batch per cached overview texture. Keep detailed
# hulls and gameplay/picking on their existing paths.
func _build_exhaust_batch() -> void:
	exhaust_batch = MultiMeshInstance2D.new()
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_2D
	mesh.use_colors = true
	mesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mesh.mesh = quad
	exhaust_batch.multimesh = mesh
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;
uniform float visual_time;
varying vec4 plume;
varying vec3 engine_tint;
void vertex() {
	plume = INSTANCE_CUSTOM;
	engine_tint = COLOR.rgb;
}
void fragment() {
	float t = 1.0 - UV.x;
	float y = abs(UV.y * 2.0 - 1.0);
	float taper = max(0.0, 1.0 - t);
	float sheath = (1.0 - smoothstep(taper * 0.75, taper + 0.04, y)) * (1.0 - smoothstep(0.8, 1.0, t));
	float core_width = max(0.0, 0.45 * (1.0 - t / 0.4));
	float core = (1.0 - smoothstep(core_width * 0.7, core_width + 0.025, y)) * (1.0 - smoothstep(0.32, 0.4, t));
	float phase = fract(t * 5.0 - visual_time * 4.5 + plume.y);
	float sparks = (1.0 - smoothstep(0.06, 0.22, abs(phase - 0.5))) * (1.0 - smoothstep(0.12, 0.35, y)) * taper;
	float alpha = clamp(plume.x * (0.34 * sheath + 0.9 * core + 0.45 * sparks), 0.0, 1.0);
	COLOR = vec4(mix(engine_tint, mix(engine_tint, vec3(1.0), 0.28), core), alpha * 0.46);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	exhaust_batch.material = material
	map_canvas.add_child(exhaust_batch)
	exhaust_batch.hide()

func _exhaust_extent(kind: String) -> Vector2:
	if not exhaust_extents.has(kind):
		var rear: float = 0.0
		var nose: float = 0.0
		for vertex in HULL_ART.HULL_OUTLINES.get(kind, HULL_ART.FREIGHTER_OUTLINE):
			rear = minf(rear, vertex.x)
			nose = maxf(nose, vertex.x)
		exhaust_extents[kind] = Vector2(rear, maxf(0.5, (nose - rear) / 18.0))
	return exhaust_extents[kind]

# Use the same plume geometry for emitted light and the rendered exhaust.
func engine_center(kind: String, point: Vector2, direction: Vector2, scale: float) -> Vector2:
	var nozzle: Vector2 = HULL_ART.paired_nozzle(kind)
	return point + direction.normalized() * (nozzle.x if not nozzle.is_zero_approx() else _exhaust_extent(kind).x) * scale

func exhaust_center(kind: String, point: Vector2, direction: Vector2, scale: float, thrust: float) -> Vector2:
	var extent: Vector2 = _exhaust_extent(kind)
	var plume_length: float = extent.y * lerpf(3.0, 14.0, thrust) * scale
	return engine_center(kind, point, direction, scale) - direction.normalized() * plume_length * 0.5

func queue_exhaust(kind: String, point: Vector2, direction: Vector2, scale: float, thrust: float, id: int, bounds: Rect2, tint: Color = Color.WHITE) -> void:
	var extent: Vector2 = _exhaust_extent(kind)
	var engine: Vector2 = engine_center(kind, point, direction, scale)
	var plume_length: float = extent.y * lerpf(3.0, 14.0, thrust) * scale
	var nozzle: Vector2 = HULL_ART.paired_nozzle(kind)
	var paired: bool = not nozzle.is_zero_approx()
	var plume_width: float = extent.y * lerpf(0.65, 1.35, thrust) * scale * (0.62 if paired else 1.0)
	if not bounds.grow(maxf(24.0, plume_length + nozzle.y * scale + 8.0)).has_point(engine):
		return
	var center: Vector2 = exhaust_center(kind, point, direction, scale, thrust)
	for sign in ([-1.0, 1.0] if paired else [0.0]):
		var at: Vector2 = center + direction.normalized().orthogonal() * nozzle.y * sign * scale
		exhaust_instances.append([Transform2D(direction.angle(), Vector2(plume_length, plume_width * 2.0), 0.0, at), thrust, fposmod(float(id) * 0.173 + sign * 0.15, 1.0), tint])

func _flush_exhaust(visual_clock: float) -> void:
	if exhaust_instances.is_empty():
		return
	var mesh: MultiMesh = exhaust_batch.multimesh
	if mesh.instance_count < exhaust_instances.size():
		mesh.instance_count = maxi(exhaust_instances.size(), maxi(64, mesh.instance_count * 2))
	var buffer := PackedFloat32Array()
	buffer.resize(mesh.instance_count * 16)
	for i in range(exhaust_instances.size()):
		var entry: Array = exhaust_instances[i]
		var t: Transform2D = entry[0]
		var offset: int = i * 16
		buffer[offset] = t.x.x
		buffer[offset + 1] = t.y.x
		buffer[offset + 3] = t.origin.x
		buffer[offset + 4] = t.x.y
		buffer[offset + 5] = t.y.y
		buffer[offset + 7] = t.origin.y
		var tint: Color = entry[3]
		buffer[offset + 8] = tint.r
		buffer[offset + 9] = tint.g
		buffer[offset + 10] = tint.b
		buffer[offset + 11] = 1.0
		buffer[offset + 12] = entry[1]
		buffer[offset + 13] = entry[2]
	mesh.buffer = buffer
	mesh.visible_instance_count = exhaust_instances.size()
	(exhaust_batch.material as ShaderMaterial).set_shader_parameter("visual_time", visual_clock)
	exhaust_batch.show()

func overview_dot_texture(tint: Color) -> Texture2D:
	var key: String = tint.to_html(false)
	if not overview_dot_textures.has(key):
		var image := Image.new()
		image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><circle cx="32" cy="32" r="31" fill="#%s"/></svg>' % key)
		overview_dot_textures[key] = ImageTexture.create_from_image(image)
	return overview_dot_textures[key]

func queue_overview_hull(texture: Texture2D, point: Vector2, angle: float, extent: float, cloaked: bool = false) -> void:
	var instances: Dictionary = cloaked_overview_instances if cloaked else overview_instances
	if not instances.has(texture):
		instances[texture] = HullInstanceStream.new()
	var stream: HullInstanceStream = instances[texture]
	stream.append_transform(Transform2D(angle, Vector2.ONE * extent * 2.0, 0.0, point))

func _flush_overview_hulls(hull_art: HULL_ART) -> void:
	_flush_hull_batches(hull_art, overview_instances, overview_batches, 1.0)
	_flush_hull_batches(hull_art, cloaked_overview_instances, cloaked_overview_batches, CLOAK_OPACITY)

func _flush_hull_batches(hull_art: HULL_ART, instances: Dictionary, batches: Dictionary, opacity: float) -> void:
	for texture in instances:
		var stream: HullInstanceStream = instances[texture]
		if stream.count == 0:
			continue
		if not batches.has(texture):
			var instance := MultiMeshInstance2D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2.ONE
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_2D
			mm.mesh = quad
			instance.multimesh = mm
			instance.texture = texture
			instance.self_modulate = Color(1.0, 1.0, 1.0, opacity)
			if hull_art.is_shield_texture(texture):
				instance.z_index = 1
			elif not hull_art.sprite_kind(texture).is_empty():
				var kind: String = hull_art.sprite_kind(texture)
				instance.material = fighter_lighting if kind == "fighter" else freighter_lighting if kind == "ship" else science_lighting
				instance.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			elif not overview_dot_textures.values().has(texture):
				instance.material = vector_lighting
			map_canvas.add_child(instance)
			batches[texture] = instance
		var batch: MultiMeshInstance2D = batches[texture]
		var mesh: MultiMesh = batch.multimesh
		var capacity: int = stream.buffer.size() >> 3
		if mesh.instance_count != capacity:
			mesh.instance_count = capacity
		mesh.buffer = stream.buffer
		mesh.visible_instance_count = stream.count
		batch.show()

