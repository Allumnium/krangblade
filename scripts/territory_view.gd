extends RefCounted
## Client-only territory presentation: shader, textures, region caches and warning destinations.
## The authoritative influence computation remains in economy_rules.
const ECONOMY = preload("res://scripts/economy_rules.gd")

var friendly_sectors: Array[int] = []
var layer: Control
var _image: ColorRect
var _material: ShaderMaterial
var _sites: ImageTexture
var _site_count: int = 0
var radius: float = 1.0
var tints: Array[Color] = []
var _region_cache: Dictionary = {}
var region_graph: Dictionary = {}
var _influence_texture: ImageTexture
var _seed: int = -1

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
	_image = ColorRect.new()
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_image)
	# The texture stores site coordinates, NOT a spatial raster. Every output
	# pixel evaluates continuous circle distances in world space.
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D site_data : filter_nearest, repeat_disable;
uniform int site_count = 0;
uniform sampler2D sector_neighbors : filter_nearest, repeat_disable;
uniform sampler2D lane_data : filter_nearest, repeat_disable;
uniform sampler2D influence_data : filter_nearest, repeat_disable;
uniform sampler2D fog_data : filter_linear, repeat_disable;
uniform vec2 fog_uv_scale = vec2(1.0);
uniform bool fog_ready = false;
uniform int lane_count = 0;
uniform float lane_radius_fraction = 0.35;
uniform vec2 world_extent = vec2(1.0);
uniform float padding = 1.0;
uniform float corner_rounding = 0.32;

// Positive clearance is inside one region. Smooth the intersection of
// constraints inward; the same contour defines both fill and rim.
float rounded_intersection(float a, float b, float width) {
	float overlap = max(0.0, width - abs(a - b));
	return min(a, b) - overlap * overlap / (4.0 * max(width, 0.000001));
}

float sector_distance(vec2 p, vec4 site, int index) {
	vec2 offset = p - site.xy;
	float distance_to_center = length(offset);
	float limit = site.z;
	// Outside the disk this lower bound is sufficient for membership.
	// Near the disk calculate the clipped, rounded radial boundary too,
	// so the lane's region boundary meets the actual sector edge.
	if (distance_to_center > site.z * 1.2) {
		return distance_to_center - site.z;
	}
	vec2 ray = offset / max(distance_to_center, 0.0000001);
	float second = 1e20;
	for (int i = 0; i < int(site.w + 0.5); i++) {
		vec3 neighbor = texelFetch(sector_neighbors, ivec2(i, index), 0).xyz;
		vec2 delta = neighbor.xy;
		float length_sq = neighbor.z;
		float projection = dot(ray, delta);
		if (length_sq > 0.000000000001 && length_sq < 4.0 * site.z * site.z && projection > 0.000000001) {
			float bound = length_sq / (2.0 * projection);
			if (bound < limit) {
				second = limit;
				limit = bound;
			} else {
				second = min(second, bound);
			}
		}
	}
	float width = max(0.000000001, limit * corner_rounding);
	float overlap = max(0.0, width - (second - limit));
	limit -= overlap * overlap / (4.0 * width);
	return distance_to_center - limit;
}

// Lane samples contain axial fraction, centerline distance and radius.
vec3 lane_sample(vec2 p, int index) {
	vec4 edge = texelFetch(lane_data, ivec2(index, 0), 0);
	vec4 a = texelFetch(site_data, ivec2(int(edge.x + 0.5), 0), 0);
	vec4 b = texelFetch(site_data, ivec2(int(edge.y + 0.5), 0), 0);
	vec2 axis = b.xy - a.xy;
	float along = clamp(dot(p - a.xy, axis) / max(dot(axis, axis), 0.00000001), 0.0, 1.0);
	return vec3(along, length(p - (a.xy + axis * along)), min(a.z, b.z) * lane_radius_fraction);
}

vec4 region_color(int region, float clearance, float aa, vec2 p) {
	vec4 tint = texelFetch(influence_data, ivec2(region, 0), 0);
	vec2 fog_uv = p / (world_extent - vec2(2.0 * padding)) * fog_uv_scale;
	if (!fog_ready || texture(fog_data, fog_uv).a > 0.05) { tint.a = 0.0; }
	vec3 neutral = vec3(0.60, 0.68, 0.76);
	float fill = smoothstep(-aa * 0.5, aa * 0.5, clearance);
	// A single centered AA stroke, rather than independent line
	// fragments with conflicting masks. Also visible at deep zoom.
	float rim = 1.0 - smoothstep(aa * 0.45, aa * 1.6, abs(clearance));
	float alpha = fill * 0.10 * tint.a + rim * mix(0.20, 0.45, tint.a);
	return vec4(mix(neutral, tint.rgb, tint.a), alpha);
}

void fragment() {
	vec2 p = UV * world_extent - vec2(padding);
	vec2 bounds = world_extent - vec2(2.0 * padding);
	float map_clearance = min(min(p.x, p.y), min(bounds.x - p.x, bounds.y - p.y));
	if (map_clearance < 0.0) { discard; }
	// Take derivatives before branching, to avoid undefined AA at seams.
	float aa = max(length(fwidth(p)), 0.000001);
	float core_d = 1e20;
	int core = -1;
	float nearest_inside = 1e20;
	int nearest_core = -1;
	for (int i = 0; i < site_count; i++) {
		vec4 site = texelFetch(site_data, ivec2(i, 0), 0);
		float distance_sq = dot(p - site.xy, p - site.xy);
		// Skip expensive radial clipping when the disk lower bound
		// cannot affect either the selected core or the nearby lane rim.
		float disk_d = sqrt(distance_sq) - site.z;
		if (disk_d > max(core_d, aa * 2.0)) { continue; }
		float d = sector_distance(p, site, i);
		if (d < core_d) {
			core_d = d;
			nearest_core = i;
		}
		if (d <= 0.0 && distance_sq < nearest_inside) {
			nearest_inside = distance_sq;
			core = i;
		}
	}
	if (core >= 0) {
		vec4 site = texelFetch(site_data, ivec2(core, 0), 0);
		float clearance = min(-sector_distance(p, site, core), map_clearance);
		COLOR = region_color(core, clearance, aa, p);
	} else {
		// Assign actual lane membership by nearest eligible centerline,
		// matching influence_region. Pick the nearest surface outside for AA.
		int lane = -1;
		int nearest_lane = -1;
		float nearest_distance = 1e20;
		float surface = 1e20;
		vec3 picked = vec3(0.0);
		vec3 outside = vec3(0.0);
		for (int i = 0; i < lane_count; i++) {
			vec3 lane_values = lane_sample(p, i);
			float d = lane_values.y - lane_values.z;
			if (d < surface) {
				surface = d;
				nearest_lane = i;
				outside = lane_values;
			}
			if (d <= 0.0 && lane_values.y < nearest_distance) {
				nearest_distance = lane_values.y;
				lane = i;
				picked = lane_values;
			}
		}
		bool in_lane = lane >= 0;
		if (!in_lane) {
			lane = nearest_lane;
			picked = outside;
		}
		vec4 lane_color = vec4(0.0);
		if (lane >= 0 && (in_lane || surface <= aa * 2.0)) {
			vec4 edge = texelFetch(lane_data, ivec2(lane, 0), 0);
			int sections = max(1, int(edge.w + 0.5));
			float scaled = picked.x * float(sections);
			int section = min(sections - 1, int(floor(scaled)));
			int region = int(edge.z + 0.5) + section;
			vec2 a = texelFetch(site_data, ivec2(int(edge.x + 0.5), 0), 0).xy;
			vec2 b = texelFetch(site_data, ivec2(int(edge.y + 0.5), 0), 0).xy;
			float span = length(b - a) / float(sections);
			float rounding = max(0.000001, picked.z * corner_rounding * 0.25);
			float clearance = min(picked.z - picked.y, map_clearance);
			// Closed lane mouths and section ends, not disconnected
			// lines from a smoothed union. Round only the local corners.
			clearance = rounded_intersection(clearance, core_d, rounding);
			if (section > 0) {
				clearance = rounded_intersection(clearance, (scaled - float(section)) * span, rounding);
			}
			if (section < sections - 1) {
				clearance = rounded_intersection(clearance, (float(section + 1) - scaled) * span, rounding);
			}
			// Clip against competing lanes' assigned areas. A point is
			// ours if outside the other capsule OR nearer our centerline.
			// This also closes contours at crossing or branching highways.
			for (int i = 0; i < lane_count; i++) {
				if (i == lane) { continue; }
				vec3 other = lane_sample(p, i);
				float separation = max(other.y - other.z, (other.y - picked.y) * 0.5);
				if (separation < clearance + rounding) {
					clearance = rounded_intersection(clearance, separation, rounding);
				}
			}
			lane_color = region_color(region, clearance, aa, p);
		}
		// Preserve the outer half of a core rim in empty space and at
		// highway mouths, blending rather than truncating at membership.
		vec4 core_color = vec4(0.0);
		if (nearest_core >= 0 && core_d < aa * 2.0) {
			core_color = region_color(nearest_core, -core_d, aa, p);
		}
		float alpha = core_color.a + lane_color.a * (1.0 - core_color.a);
		COLOR = vec4((core_color.rgb * core_color.a + lane_color.rgb * lane_color.a * (1.0 - core_color.a)) / max(alpha, 0.000001), alpha);
	}
}
"""
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("corner_rounding", ECONOMY.SECTOR_CORNER_ROUNDING)
	_material.set_shader_parameter("lane_radius_fraction", ECONOMY.LANE_RADIUS_FRACTION)
	_image.material = _material
	_image.hide()

# One consistent radius per galaxy, based on median nearest-system spacing.
# Outlier systems cannot create enormous wedges; asteroid fields are smaller.
func refresh(state: Dictionary, local_player: int, map_size: Vector2, roster: Dictionary, empire_color: Callable) -> bool:
	if state.is_empty():
		_image.hide()
		_seed = -1
		_region_cache.clear()
		region_graph = {}
		tints.clear()
		_influence_texture = null
		return false
	var seed_value: int = int(state["map"]["seed"])
	var graph: Dictionary = ECONOMY.military_graph(state)
	var points: Array = graph["points"]
	var edges: Array = graph["edges"]
	if points.is_empty():
		_image.hide()
		return false
	var layout: Dictionary = ECONOMY.highway_regions(graph)
	if _seed != seed_value or _site_count != points.size() or tints.size() != int(layout["size"]):
		radius = ECONOMY.sector_base_radius(state["map"])
		_seed = seed_value
		tints.clear()
		_influence_texture = null
		_site_count = points.size()
		# Cache possible bisector constraints in original site order. Use a
		# conservative margin around the shader's strict disk cutoff.
		var neighbor_rows: Array = []
		var max_neighbors: int = 1
		for i in range(points.size()):
			var row: Array = []
			var normalized_radius: float = float(graph["sector_radii"][i]) / radius
			for j in range(points.size()):
				if i == j:
					continue
				var delta: Vector2 = (points[j] as Vector2) / radius - (points[i] as Vector2) / radius
				var length_sq: float = delta.length_squared()
				if length_sq <= 4.0 * normalized_radius * normalized_radius + 0.00001:
					row.append(Color(delta.x, delta.y, length_sq, 0.0))
			neighbor_rows.append(row)
			max_neighbors = maxi(max_neighbors, row.size())
		var neighbors: Image = Image.create_empty(max_neighbors, points.size(), false, Image.FORMAT_RGBAF)
		var data: Image = Image.create_empty(points.size(), 1, false, Image.FORMAT_RGBAF)
		for i in range(points.size()):
			var point: Vector2 = points[i]
			var row: Array = neighbor_rows[i]
			for j in range(row.size()):
				neighbors.set_pixel(j, i, row[j])
			data.set_pixel(i, 0, Color(point.x / radius, point.y / radius, float(graph["sector_radii"][i]) / radius, float(row.size())))
		_material.set_shader_parameter("sector_neighbors", ImageTexture.create_from_image(neighbors))
		_sites = ImageTexture.create_from_image(data)
		_material.set_shader_parameter("site_data", _sites)
		_material.set_shader_parameter("site_count", _site_count)
		var lanes: Image = Image.create_empty(maxi(1, edges.size()), 1, false, Image.FORMAT_RGBAF)
		for i in range(edges.size()):
			lanes.set_pixel(i, 0, Color(float(edges[i][0]), float(edges[i][1]), float(layout["starts"][i]), float(layout["counts"][i])))
		_material.set_shader_parameter("lane_data", ImageTexture.create_from_image(lanes))
		_material.set_shader_parameter("lane_count", edges.size())
		var extent: Vector2 = map_size / radius + Vector2.ONE * 3.0
		_material.set_shader_parameter("world_extent", extent)
		_material.set_shader_parameter("padding", 1.5)
	var known: Array[int] = ECONOMY.military_pois(state, local_player)
	if not is_same(region_graph, graph):
		_region_cache.clear()
		region_graph = graph
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
	var influence: Image = Image.create_empty(tints.size(), 1, false, Image.FORMAT_RGBAF)
	for i in range(tints.size()):
		influence.set_pixel(i, 0, tints[i])
	if _influence_texture == null:
		_influence_texture = ImageTexture.create_from_image(influence)
		_material.set_shader_parameter("influence_data", _influence_texture)
	else:
		_influence_texture.update(influence)
	_image.show()
	return true

func set_fog(texture: ImageTexture, uv_scale: Vector2) -> void:
	_material.set_shader_parameter("fog_data", texture)
	_material.set_shader_parameter("fog_uv_scale", uv_scale)
	_material.set_shader_parameter("fog_ready", true)

func set_geometry(origin: Vector2, display_size: Vector2) -> void:
	_image.position = origin
	_image.size = display_size
