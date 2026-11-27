extends RefCounted
## Per-match celestial geometry, surface art, detail fades and asteroid meshes.
## Shared geometry is used for picking and drawing; no simulation mutations.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const ORBIT_MAP = preload("res://scripts/planet_map.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const SYSTEM_WORLD_RADIUS: float = ECONOMY.SYSTEM_WORLD_RADIUS
const PLANET_FADE_START: float = 40.0
const PLANET_FADE_FULL: float = 100.0
const PLANET_FADE_SECONDS: float = 0.22
const STAR_TEXTURE_SIZE: int = 256
const STAR_TEXTURE_CORE: float = 74.0
const STAR_SPARK_COUNT: int = 9

const ROCK_ATLAS = preload("res://assets/sprites/asteroids/pixellab-rocky-realistic-asteroids-of-b-1793247758903_d.png")
const ROCK_LIGHTING = preload("res://assets/shaders/asteroid_lighting.gdshader")
# The 256px atlas has a 4x4 stride, but only its upper-left 3x3
# cells contain planet designs. Diffuse and all material maps share it.
const METAL_PLANET_VARIANTS: int = 9
const METAL_PLANET_CELL: int = 64
const METAL_PLANET_DIFFUSE = preload("res://assets/sprites/metal_planet/pixellab-top-down-lustrous-grey-rocky-p-1795763765639_d.png")
const ROCK_GRID: int = 8
const ROCK_SPRITE_MIN_RADIUS: float = 2.5
var asteroid_sprite_nodes: Dictionary = {}
var planet_sprite_nodes: Dictionary = {}
var metal_planet_textures: Dictionary = {}
var asteroid_material: ShaderMaterial
var asteroid_shape_cache: Dictionary = {}

# Stable atlas choice: never uses simulation RNG or mutable ore amount.
static func asteroid_tile(id: int) -> int:
	return posmod(id * 37 + 17, ROCK_GRID * ROCK_GRID)

func _rock_material() -> ShaderMaterial:
	if asteroid_material == null:
		asteroid_material = ShaderMaterial.new()
		asteroid_material.shader = ROCK_LIGHTING
		asteroid_material.set_shader_parameter("normal_map", preload("res://assets/sprites/asteroids/pixellab-rocky-realistic-asteroids-of-b-1793247758903_n.png"))
		asteroid_material.set_shader_parameter("occlusion_map", preload("res://assets/sprites/asteroids/pixellab-rocky-realistic-asteroids-of-b-1793247758903_o.png"))
		asteroid_material.set_shader_parameter("height_map", preload("res://assets/sprites/asteroids/pixellab-rocky-realistic-asteroids-of-b-1793247758903_p.png"))
		asteroid_material.set_shader_parameter("specular_map", preload("res://assets/sprites/asteroids/pixellab-rocky-realistic-asteroids-of-b-1793247758903_s.png"))
	return asteroid_material

func set_asteroid_lights(canvas: Control, lights: Array) -> void:
	var positions := PackedVector4Array()
	var colors := PackedVector4Array()
	var canvas_transform: Transform2D = canvas.get_global_transform_with_canvas()
	var radius_scale: float = canvas_transform.x.length()
	positions.resize(16)
	colors.resize(16)
	var count: int = mini(16, lights.size())
	for i in range(count):
		var entry: Array = lights[i]
		var pos: Vector2 = canvas_transform * (entry[0] as Vector2)
		var tint: Color = entry[2]
		positions[i] = Vector4(pos.x, pos.y, float(entry[1]) * radius_scale, float(entry[3]))
		colors[i] = Vector4(tint.r, tint.g, tint.b, 1.0 if entry.size() > 5 and bool(entry[5]) else 0.0)
	var material: ShaderMaterial = _rock_material()
	material.set_shader_parameter("light_points", positions)
	material.set_shader_parameter("light_colors", colors)
	material.set_shader_parameter("light_count", count)

func _show_asteroid_mesh(canvas: Control, field_index: int, mesh: ArrayMesh) -> void:
	if mesh == null:
		return
	var instance: MeshInstance2D = asteroid_sprite_nodes.get(field_index)
	if not is_instance_valid(instance):
		instance = MeshInstance2D.new()
		instance.name = "AsteroidAtlas_%d" % field_index
		instance.texture = ROCK_ATLAS
		instance.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		instance.material = _rock_material()
		# Live terrain precedes ships, effects and the fog.
		instance.show_behind_parent = true
		canvas.add_child(instance)
		asteroid_sprite_nodes[field_index] = instance
	if instance.mesh != mesh:
		instance.mesh = mesh
	instance.show()

static func _rock_mesh(vertices: PackedVector3Array, colors: PackedColorArray, uvs: PackedVector2Array = PackedVector2Array()) -> ArrayMesh:
	if vertices.is_empty():
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	if not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

var asteroid_frame_meshes: Array[ArrayMesh] = []
var asteroid_cache_seed: int = -1
var orbit_visual_time: float = -1.0
var orbit_sample_time: float = -1.0
var orbit_sample_age: float = 0.0
var orbit_seed: int = -1
var system_visuals: Dictionary = {}
var star_textures: Dictionary = {}
var system_visual_seed: int = -1
var planet_detail_alpha: Dictionary = {}
var planet_detail_seed: int = -1

func reset_clocks() -> void:
	orbit_visual_time = -1.0
	orbit_sample_time = -1.0
	orbit_seed = -1
	planet_detail_alpha.clear()
	planet_detail_seed = -1

func begin_frame() -> void:
	asteroid_frame_meshes.clear()
	for instance in asteroid_sprite_nodes.values():
		if is_instance_valid(instance):
			instance.hide()
	for instance in planet_sprite_nodes.values():
		if is_instance_valid(instance):
			instance.hide()

func prepare_map(state: Dictionary) -> void:
	var seed_value: int = int(state["map"]["seed"])
	if asteroid_cache_seed != seed_value:
		asteroid_shape_cache.clear()
		for instance in asteroid_sprite_nodes.values():
			if is_instance_valid(instance):
				instance.queue_free()
		asteroid_sprite_nodes.clear()
		for instance in planet_sprite_nodes.values():
			if is_instance_valid(instance):
				instance.queue_free()
		planet_sprite_nodes.clear()
		asteroid_cache_seed = seed_value

# At overview scale, plot each actual rock, never its enclosing belt.
static func draw_terrain_footprint(canvas: Control, field: Dictionary, offset: Vector2, scale: float, tint: Color) -> void:
	var geometry: Dictionary = terrain_footprint(field.get("chunks", []), offset, scale, tint)
	if not geometry["segments"].is_empty():
		canvas.draw_multiline_colors(geometry["segments"], geometry["colors"], 1.0, true)

static func terrain_footprint(chunks: Array, offset: Vector2, scale: float, tint: Color) -> Dictionary:
	var segments := PackedVector2Array()
	var colors := PackedColorArray()
	for rock in chunks:
		var point: Vector2 = offset + (rock["position"] as Vector2) * scale
		var fraction: float = clampf(float(rock["remaining"]) / maxf(ECONOMY.EPS, float(rock["initial"])), 0.0, 1.0)
		var radius: float = maxf(0.42, float(rock["radius"]) * scale * 0.65 * sqrt(fraction))
		var axis: Vector2 = Vector2.from_angle(float(rock["rotation"])) * radius
		segments.append(point - axis)
		segments.append(point + axis)
		colors.append(Color("#b879a0") if rock["resource"] == "Crystals" else tint)
	return {"segments": segments, "colors": colors}

func draw_asteroid_chunks(field: Dictionary, viewport_bounds: Rect2, render_scale: float, map_canvas: Control, screen_center: Vector2, world_center: Vector2, projection_fit: float, projection_zoom: float, shading: float = 1.0, rotation_time: float = 0.0, field_index: int = -1, orbit_transforms: Array[Transform2D] = []) -> void:
	var chunks: Array = field["chunks"]
	var rock_vertices := PackedVector3Array()
	var rock_colors := PackedColorArray()
	var sprite_vertices := PackedVector3Array()
	var sprite_colors := PackedColorArray()
	var sprite_uvs := PackedVector2Array()
	var pixel: Vector2 = Vector2(0.5, 0.5) / Vector2(ROCK_ATLAS.get_size())
	for chunk in chunks:
		var shape_key := Vector2i(field_index, int(chunk["id"]))
		var rock_pos: Vector2 = screen_center + (ORBIT_MAP.asteroid_orbit_position(chunk, orbit_transforms) - world_center) * projection_fit * projection_zoom
		if not viewport_bounds.grow(maxf(4.0, float(chunk["radius"]) * render_scale * 2.0)).has_point(rock_pos):
			continue
		var fraction: float = clampf(float(chunk["remaining"]) / maxf(ECONOMY.EPS, float(chunk["initial"])), 0.0, 1.0)
		var rock_radius: float = maxf(0.65, float(chunk["radius"]) * render_scale * sqrt(fraction))
		var crystal: bool = chunk["resource"] == "Crystals"
		if rock_radius < ROCK_SPRITE_MIN_RADIUS:
			# Keep distant terrain cheap and legible, with the same resource cue.
			var variation: float = 0.5 + 0.5 * sin(float(chunk["rotation"]) * 3.0)
			var tint: Color = (Color("#b879a0") if crystal else Color("#50545a").lerp(Color("#6b5e51"), variation)).darkened(1.0 - shading)
			for point in [rock_pos + Vector2(-rock_radius, rock_radius * 0.65), rock_pos + Vector2(rock_radius, rock_radius * 0.45), rock_pos + Vector2(0.20, -rock_radius)]:
				rock_vertices.append(Vector3(point.x, point.y, 0.0))
				rock_colors.append(tint)
			continue
		if not asteroid_shape_cache.has(shape_key):
			var spin_signature: float = sin(float(chunk["rotation"]) * 5.0)
			var variety: float = fposmod(sin(Vector2(shape_key).dot(Vector2(0.013, 0.021))) * 43758.5453, 1.0)
			var speed: float = deg_to_rad(lerpf(0.15, 0.5, variety))
			asteroid_shape_cache[shape_key] = speed * (1.0 if spin_signature >= 0.0 else -1.0)
		var spin: float = float(chunk["rotation"]) + rotation_time * float(asteroid_shape_cache[shape_key])
		var axis: Vector2 = Vector2.from_angle(spin)
		# Atlas cells have transparent padding; preserve approximately the
		# same physical-radius scale, without modifying collision geometry.
		var extent: float = rock_radius * 1.16
		var basis: Vector2 = axis * extent
		var side: Vector2 = basis.orthogonal()
		var corners: Array[Vector2] = [rock_pos - basis - side, rock_pos + basis - side, rock_pos + basis + side, rock_pos - basis + side]
		var tile: int = asteroid_tile(int(chunk["id"]))
		var cell := Vector2(tile % ROCK_GRID, floori(float(tile) / ROCK_GRID)) / float(ROCK_GRID)
		var uv_min: Vector2 = cell + pixel
		var uv_max: Vector2 = cell + Vector2.ONE / float(ROCK_GRID) - pixel
		var uvs: Array[Vector2] = [uv_min, Vector2(uv_max.x, uv_min.y), uv_max, Vector2(uv_min.x, uv_max.y)]
		# Store the rotation and resource flag as vertex data for the shader.
		# Alpha is intentionally one; the shader uses atlas transparency.
		var meta := Color(axis.x * 0.5 + 0.5, axis.y * 0.5 + 0.5, 1.0 if crystal else 0.0, 1.0)
		for vertex in [0, 1, 2, 0, 2, 3]:
			var point: Vector2 = corners[vertex]
			sprite_vertices.append(Vector3(point.x, point.y, 0.0))
			sprite_colors.append(meta)
			sprite_uvs.append(uvs[vertex])
	var mesh: ArrayMesh = _rock_mesh(rock_vertices, rock_colors)
	if mesh != null:
		asteroid_frame_meshes.append(mesh)
		map_canvas.draw_mesh(mesh, null)
	var sprites: ArrayMesh = _rock_mesh(sprite_vertices, sprite_colors, sprite_uvs)
	_show_asteroid_mesh(map_canvas, field_index, sprites)

func system_visual(index: int, state: Dictionary) -> Dictionary:
	var seed_value: int = int(state["map"]["seed"])
	if system_visual_seed != seed_value:
		system_visual_seed = seed_value
		system_visuals.clear()
	if not system_visuals.has(index):
		var points: Array = state["map"]["points"]
		var closest: float = INF
		for i in range(points.size()):
			if i != index:
				closest = minf(closest, (points[index] as Vector2).distance_to(points[i]))
		system_visuals[index] = {"bodies": ECONOMY.system_bodies(state["planets"][index], seed_value, index), "spacing": closest}
	return system_visuals[index]

func system_world_radius(index: int, state: Dictionary) -> float:
	var ideal: float = SYSTEM_WORLD_RADIUS * float(state["planets"][index].get("size_factor", 1.0))
	return minf(ideal, float(system_visual(index, state)["spacing"]) * 0.39)

func _planet_detail_target(radius: float) -> float:
	return smoothstep(PLANET_FADE_START, PLANET_FADE_FULL, radius)

func planet_detail_opacity(index: int, radius: float) -> float:
	return float(planet_detail_alpha.get(index, _planet_detail_target(radius)))

func update_planet_detail(state: Dictionary, delta: float, fit: float, zoom: float) -> void:
	var seed_value: int = int(state["map"]["seed"])
	if planet_detail_seed != seed_value:
		planet_detail_alpha.clear()
		planet_detail_seed = seed_value
	for index in range(state["planets"].size()):
		var target: float = _planet_detail_target(system_world_radius(index, state) * fit * zoom)
		var previous: float = float(planet_detail_alpha.get(index, 0.0))
		planet_detail_alpha[index] = move_toward(previous, target, delta / PLANET_FADE_SECONDS)

func star_draw_radius(radius: float) -> float:
	# Constant world-space ratio; camera zoom is the only size multiplier.
	return radius * 0.13

func update_orbit_clock(state: Dictionary, delta: float) -> void:
	var elapsed: float = float(state["elapsed"])
	var seed_value: int = int(state["map"]["seed"])
	var speed: float = float(state.get("time_speed", 1))
	if orbit_seed != seed_value or orbit_visual_time < 0.0 or elapsed < orbit_sample_time or speed <= 0.0 or not state.get("match_result", {}).is_empty():
		orbit_seed = seed_value
		orbit_visual_time = elapsed
		orbit_sample_time = elapsed
		orbit_sample_age = 0.0
		return
	if elapsed != orbit_sample_time:
		orbit_sample_time = elapsed
		orbit_sample_age = 0.0
	else:
		orbit_sample_age += delta
	# Predict only a bounded interval; gently converge on authoritative time.
	var target: float = elapsed + minf(orbit_sample_age, 0.6) * speed
	var correction: float = clampf((target - orbit_visual_time) * 4.0, -speed, speed * 2.0)
	orbit_visual_time = minf(maxf(orbit_visual_time, target), orbit_visual_time + delta * maxf(0.0, speed + correction))

func orbit_time(state: Dictionary) -> float:
	return orbit_visual_time if orbit_visual_time >= 0.0 and orbit_seed == int(state["map"]["seed"]) else float(state["elapsed"])

func body_position(body: Dictionary, radius: float, time: float) -> Vector2:
	return ECONOMY.body_position(body, radius, time)

func draw_elliptical_orbit(center: Vector2, radius: float, tint: Color, map_canvas: Control) -> void:
	var points := PackedVector2Array()
	for step in range(65):
		var angle: float = TAU * float(step) / 64.0
		points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius * 0.65))
	map_canvas.draw_polyline(points, tint, 0.8, true)

# Resource palettes use strong surface hues, not UI icon tints.
func body_base_color(body: Dictionary) -> Color:
	var palette: Dictionary = {"Organics": Color("#52a452"), "Metals": Color("#a3a7ad"), "Crystals": Color("#a16bda")}
	var material: String = str(body["resource"])
	var base: Color = palette.get(material, HUD.COLORS.get(material, Color("#7d8b9b")))
	return base.lerp(Color("#7b8790"), float(body["muted"]) * (0.22 if not material.is_empty() else 0.65))

# Generate a unique shaded surface once per visible body; no separate highlight dot.
# Reuse one shared sphere material and one cached sprite per visible body.
# Albedo textures are generated once; the day/night boundary follows lights.
func draw_lit_body(canvas: Control, key: Vector2i, body: Dictionary, point: Vector2, radius: float, opacity: float, material: ShaderMaterial) -> void:
	var sprite: Sprite2D = planet_sprite_nodes.get(key)
	if not is_instance_valid(sprite):
		sprite = Sprite2D.new()
		sprite.texture = body_texture(body)
		sprite.material = material
		if body.get("resource", "") == "Metals":
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.show_behind_parent = true
		canvas.add_child(sprite)
		planet_sprite_nodes[key] = sprite
	sprite.position = point
	sprite.scale = Vector2.ONE * (radius * 2.0 / float(sprite.texture.get_width()))
	sprite.modulate = Color(1.0, 1.0, 1.0, opacity)
	sprite.show()

static func metal_planet_variant(surface_seed: int) -> int:
	return posmod(surface_seed, METAL_PLANET_VARIANTS)

static func metal_planet_cell_rect(variant: int) -> Rect2i:
	var index: int = clampi(variant, 0, METAL_PLANET_VARIANTS - 1)
	# Remove two pixels of transparent padding on every side; keep
	# the exact same crop for the five maps and all nine variants.
	var origin := Vector2i(index % 3, floori(float(index) / 3.0)) * METAL_PLANET_CELL
	return Rect2i(origin + Vector2i(2, 2), Vector2i(60, 60))

static func metal_planet_map(atlas: Texture2D, variant: int) -> Texture2D:
	var source: Image = atlas.get_image()
	if source.is_compressed():
		source.decompress()
	return ImageTexture.create_from_image(source.get_region(metal_planet_cell_rect(variant)))

func body_texture(body: Dictionary) -> Texture2D:
	if body.get("resource", "") == "Metals":
		var variant: int = metal_planet_variant(int(body["surface_seed"]))
		if not metal_planet_textures.has(variant):
			metal_planet_textures[variant] = metal_planet_map(METAL_PLANET_DIFFUSE, variant)
		return metal_planet_textures[variant]
	if body.has("texture"):
		return body["texture"]
	var noise := FastNoiseLite.new()
	noise.seed = int(body["surface_seed"])
	noise.frequency = 0.065
	noise.fractal_octaves = 3
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	var base: Color = body_base_color(body)
	var highlight: Color = base.lightened(0.48)
	var angle: float = float(body["surface_angle"])
	var bands: bool = bool(body["bands"])
	for y in range(96):
		for x in range(96):
			var q := (Vector2(x + 0.5, y + 0.5) - Vector2(48, 48)) / 47.0
			var rr: float = q.length_squared()
			if rr >= 1.0:
				continue
			var z: float = sqrt(1.0 - rr)
			var uv: Vector2 = q.rotated(angle)
			var grain: float = noise.get_noise_2d(uv.x * 90.0 + 300.0 * z, uv.y * 90.0)
			var terrain: float = grain * 0.7
			if bands:
				terrain = sin(uv.y * 29.0 + grain * 2.0) * 0.24 + grain * 0.2
			var color: Color = base.lerp(highlight, maxf(0.0, terrain) * 0.7).darkened(clampf(0.10 - terrain * 0.30, 0.0, 0.30))
			color.a = clampf((1.0 - sqrt(rr)) * 47.0, 0.0, 1.0)
			image.set_pixel(x, y, color)
	body["texture"] = ImageTexture.create_from_image(image)
	return body["texture"]

# Bake two photosphere/corona textures once per match. Every star shares
# its temperature-class texture with its own rotation and small color tint.
# No per-frame noise, particle nodes, network state or random simulation calls.
func _star_texture(cool: bool) -> Texture2D:
	if star_textures.has(cool):
		return star_textures[cool]
	var noise := FastNoiseLite.new()
	noise.seed = 91813 if cool else 41207
	noise.frequency = 0.047
	noise.fractal_octaves = 4
	var image := Image.create(STAR_TEXTURE_SIZE, STAR_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var dark := Color("#496c9b") if cool else Color("#c05a25")
	var middle := Color("#a4c7eb") if cool else Color("#ffbf64")
	var bright := Color("#eaf7ff") if cool else Color("#fff8dc")
	var halo := Color("#77a8df") if cool else Color("#f4a752")
	var half: float = float(STAR_TEXTURE_SIZE) * 0.5
	var extent: float = half / STAR_TEXTURE_CORE
	for y in range(STAR_TEXTURE_SIZE):
		for x in range(STAR_TEXTURE_SIZE):
			var q := (Vector2(x + 0.5, y + 0.5) - Vector2.ONE * half) / STAR_TEXTURE_CORE
			var r: float = q.length()
			if r >= extent:
				continue
			# Directional noise breaks the corona into soft, radial filaments.
			var axis: Vector2 = q.normalized()
			var plume: float = clampf(0.5 + noise.get_noise_2d(axis.x * 87.0 + 133.0, axis.y * 87.0) * 1.25, 0.0, 1.0)
			var distance: float = maxf(0.0, r - 1.0)
			var falloff: float = 1.0 - smoothstep(1.0, extent, r)
			var glow: float = (0.15 * exp(-distance * 7.0) + 0.18 * plume * plume * exp(-distance * 4.5)) * falloff
			var coverage: float = 1.0 - smoothstep(1.0 - 1.0 / STAR_TEXTURE_CORE, 1.0 + 1.0 / STAR_TEXTURE_CORE, r)
			var color: Color = halo.lerp(middle, plume * 0.24)
			if coverage > 0.0:
				var z: float = sqrt(maxf(0.0, 1.0 - r * r))
				var surface: Vector2 = q * 105.0 + Vector2(z * 28.0, z * 15.0)
				# Warp the granulation into curved plasma cells and mottled lanes.
				var warp: float = noise.get_noise_2d(surface.x + 320.0, surface.y - 110.0)
				var cells: float = noise.get_noise_2d(surface.x + warp * 23.0, surface.y + warp * 18.0)
				var grain: float = noise.get_noise_2d(surface.x * 2.8 + 580.0, surface.y * 2.8)
				var heat: float = clampf(0.56 + cells * 0.83 + grain * 0.20 + z * 0.11, 0.0, 1.0)
				var core: Color = dark.lerp(middle, smoothstep(0.0, 0.56, heat)).lerp(bright, smoothstep(0.35, 0.98, heat))
				core = core.darkened((1.0 - z) * 0.18)
				color = color.lerp(core, coverage)
			color.a = coverage + glow * (1.0 - coverage)
			if color.a > 0.001:
				image.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(image)
	star_textures[cool] = texture
	return texture

func draw_star(index: int, pos: Vector2, radius: float, tint: Color, cool: bool, opacity: float, map_canvas: Control, visual_clock: float) -> void:
	var viewport := Rect2(Vector2.ZERO, map_canvas.size)
	var extent: float = radius * float(STAR_TEXTURE_SIZE) / (2.0 * STAR_TEXTURE_CORE)
	if not viewport.grow(extent + 3.0).has_point(pos):
		return
	if radius < 2.0:
		# Keep the smallest overview stars clean and cheap.
		map_canvas.draw_circle(pos, maxf(0.75, radius), Color(tint.lightened(0.22), opacity), true, -1.0, true)
		return
	var texture: Texture2D = _star_texture(cool)
	var rotation: float = float(index) * 2.399963 + visual_clock * (0.012 + 0.003 * float(index % 5))
	var modulation: Color = Color.WHITE.lerp(tint.lightened(0.30), 0.20)
	modulation.a = opacity
	map_canvas.draw_set_transform(pos, rotation)
	map_canvas.draw_texture_rect(texture, Rect2(-Vector2.ONE * extent, Vector2.ONE * extent * 2.0), false, modulation)
	map_canvas.draw_set_transform(Vector2.ZERO)
	# Analytic, short-lived plasma sparks drift away from the limb.
	# Fade in only at detail zoom; fixed count, no persistent emitters.
	var detail: float = smoothstep(10.0, 32.0, radius)
	if detail <= 0.001:
		return
	for i in range(STAR_SPARK_COUNT):
		var phase: float = float(i) * 0.618034 + float(index) * 0.137
		var age: float = fposmod(visual_clock * (0.16 + float(i % 3) * 0.025) + phase, 1.0)
		var angle: float = phase * TAU * 3.0 + rotation + age * 0.15
		var axis: Vector2 = Vector2.from_angle(angle)
		var point: Vector2 = pos + axis * radius * lerpf(0.98, 1.36, age)
		if not viewport.grow(4.0).has_point(point):
			continue
		var fade: float = sin(age * PI) * detail * opacity
		var spark_size: float = clampf(radius * 0.021, 0.65, 2.1)
		var spark_color: Color = tint.lightened(0.48)
		map_canvas.draw_line(point - axis * minf(5.0, radius * 0.045), point, Color(spark_color, fade * 0.26), maxf(0.7, spark_size * 0.65), true)
		map_canvas.draw_circle(point, spark_size, Color(spark_color, fade * 0.54), true, -1.0, true)

# Thin metallic latitude/longitude ribs, clipped to the planet silhouette.
func draw_pds_frame(center: Vector2, radius: float, opacity: float, map_canvas: Control) -> void:
	var r: float = radius * 1.08
	var steel := Color(Color("#c4d1dc"), opacity)
	var shadow := Color(Color("#344655"), opacity)
	map_canvas.draw_arc(center, r, 0.0, TAU, 32, shadow, 2.0, true)
	map_canvas.draw_arc(center, r, 0.0, TAU, 32, steel, 1.0, true)
	if radius < 4.0:
		return
	for angle in [0.0, PI / 3.0, -PI / 3.0]:
		var axis := Vector2.from_angle(angle)
		for fraction in [-0.5, 0.0, 0.5]:
			var midpoint: Vector2 = center + axis.orthogonal() * r * fraction
			var extent: Vector2 = axis * r * sqrt(1.0 - fraction * fraction)
			map_canvas.draw_line(midpoint - extent, midpoint + extent, shadow, 2.0, true)
			map_canvas.draw_line(midpoint - extent, midpoint + extent, steel, 0.8, true)

func planet_color(planet: Dictionary) -> Color:
	var sum := Vector3.ZERO
	var weight: float = 0.0
	for resource in ECONOMY.EXTRACTED:
		var amount: float = float(planet["abundance"].get(resource, 0.0))
		var tint: Color = HUD.COLORS[resource]
		sum += Vector3(tint.r, tint.g, tint.b) * amount
		weight += amount
	var organic: float = maxf(0.0, float(planet["bonuses"].get("Organics", 1.0)) - 1.0)
	var green: Color = HUD.COLORS["Organics"]
	sum += Vector3(green.r, green.g, green.b) * organic
	weight += organic
	if weight <= ECONOMY.EPS:
		return Color("#617587")
	var mix: Vector3 = sum / weight
	return Color(mix.x, mix.y, mix.z)

