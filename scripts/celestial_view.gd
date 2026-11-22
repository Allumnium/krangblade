extends RefCounted
## Per-match celestial geometry, surface art, detail fades and asteroid meshes.
## Shared geometry is used for picking and drawing; no simulation mutations.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const SYSTEM_WORLD_RADIUS: float = ECONOMY.SYSTEM_WORLD_RADIUS
const PLANET_FADE_START: float = 40.0
const PLANET_FADE_FULL: float = 100.0
const PLANET_FADE_SECONDS: float = 0.22
const STAR_TEXTURE_SIZE: int = 256
const STAR_TEXTURE_CORE: float = 74.0
const STAR_SPARK_COUNT: int = 9

var asteroid_shape_cache: Dictionary = {}
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

func prepare_map(state: Dictionary) -> void:
	var seed_value: int = int(state["map"]["seed"])
	if asteroid_cache_seed != seed_value:
		asteroid_shape_cache.clear()
		asteroid_cache_seed = seed_value

func draw_asteroid_chunks(field: Dictionary, viewport_bounds: Rect2, render_scale: float, map_canvas: Control, screen_point: Callable) -> void:
	var rock_vertices := PackedVector3Array()
	var rock_colors := PackedColorArray()
	for chunk in field["chunks"]:
		var rock_pos: Vector2 = screen_point.call(chunk["position"])
		if not viewport_bounds.grow(maxf(4.0, float(chunk["radius"]) * render_scale * 2.0)).has_point(rock_pos):
			continue
		var fraction: float = float(chunk["remaining"]) / float(chunk["initial"])
		var rock_radius: float = maxf(1.3, float(chunk["radius"]) * render_scale * sqrt(fraction))
		var shape_key: Vector2 = chunk["position"]
		if not asteroid_shape_cache.has(shape_key):
			var unit_shape := PackedVector2Array()
			for k in range(chunk["shape"].size()):
				var angle: float = TAU * float(k) / float(chunk["shape"].size()) + float(chunk["rotation"])
				unit_shape.append(Vector2.from_angle(angle) * float(chunk["shape"][k]))
			asteroid_shape_cache[shape_key] = {"vertices": unit_shape, "triangles": Geometry2D.triangulate_polygon(unit_shape)}
		var rock := PackedVector2Array()
		var cached: Dictionary = asteroid_shape_cache[shape_key]
		for vertex in cached["vertices"]:
			rock.append(rock_pos + vertex * rock_radius)
		var tint: Color = HUD.COLORS[chunk["resource"]]
		for index in cached["triangles"]:
			var p: Vector2 = rock[index]
			rock_vertices.append(Vector3(p.x, p.y, 0.0))
			rock_colors.append(tint.darkened(0.25))
		# Batch thin edge quads, retaining the existing screen-space width.
		for k in range(rock.size()):
			var p: Vector2 = rock[k]
			var q: Vector2 = rock[(k + 1) % rock.size()]
			var normal: Vector2 = (q - p).normalized().orthogonal() * 0.4
			for v in [p - normal, q - normal, q + normal, p - normal, q + normal, p + normal]:
				rock_vertices.append(Vector3(v.x, v.y, 0.0))
				rock_colors.append(tint)
	if not rock_vertices.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = rock_vertices
		arrays[Mesh.ARRAY_COLOR] = rock_colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		asteroid_frame_meshes.append(mesh)
		map_canvas.draw_mesh(mesh, null)

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
func body_texture(body: Dictionary) -> Texture2D:
	if body.has("texture"):
		return body["texture"]
	var noise := FastNoiseLite.new()
	noise.seed = int(body["surface_seed"])
	noise.frequency = 0.065
	noise.fractal_octaves = 3
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	var base: Color = body_base_color(body)
	var highlight: Color = base.lightened(0.48)
	var light := Vector3(-0.55, -0.45, 0.70).normalized()
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
			var diffuse: float = maxf(0.0, Vector3(q.x, q.y, z).dot(light))
			var color: Color = base.lerp(highlight, maxf(0.0, terrain) * 0.7).darkened(clampf(0.74 - diffuse * 0.64 - terrain * 0.18, 0.0, 0.85))
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

