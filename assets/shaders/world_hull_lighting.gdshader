shader_type canvas_item;
render_mode unshaded;
uniform bool authored_sprite = false;
uniform sampler2D normal_map : filter_nearest;
uniform sampler2D occlusion_map : filter_nearest;
uniform sampler2D height_map : filter_nearest;
uniform sampler2D specular_map : filter_nearest;
uniform vec4 light_points[16];
uniform vec4 light_colors[16];
uniform int light_count = 0;
uniform vec4 shadow_discs[8];
uniform int shadow_count = 0;
// Localized, soft 2D eclipse approximation. Do not shadow a receiver
// with its own bounding disc or with an occluder behind the light.
float stellar_visibility(vec2 pos, vec2 light_pos, vec2 receiver) {
	vec2 ray = light_pos - pos;
	float length_sq = max(0.0001, dot(ray, ray));
	float visibility = 1.0;
	for (int j = 0; j < 8; j++) {
		if (j >= shadow_count) { break; }
		vec2 center = shadow_discs[j].xy;
		float radius = shadow_discs[j].z;
		if (distance(receiver, center) <= radius + 0.5) { continue; }
		float t = dot(center - pos, ray) / length_sq;
		if (t <= 0.0 || t >= 1.0) { continue; }
		float clearance = distance(center, pos + ray * t);
		visibility = min(visibility, smoothstep(radius * 0.72, radius * 1.12, clearance));
	}
	return visibility;
}
uniform bool spherical_surface = false;
varying vec2 receiver_center;

varying vec3 illumination;
varying vec2 surface_position;
varying vec2 surface_axis_x;
varying vec2 surface_axis_y;
varying vec4 modulation;
// Every point light contributes its own diffuse and specular terms, in
// the same canvas space as the submitted light coordinates. A finite
// height prevents singularities at the projected source center.
vec3 surface_lighting(vec2 pos, vec2 axis_x, vec2 axis_y, vec3 normal, vec3 albedo, float specular, vec3 ambient, float ao) {
	vec3 diffuse_light = ambient;
	vec3 shine = vec3(0.0);
	for (int i = 0; i < 16; i++) {
		if (i >= light_count) { break; }
		vec2 delta = light_points[i].xy - pos;
		float radius = max(1.0, light_points[i].z);
		float distance_sq = dot(delta, delta);
		if (distance_sq >= radius * radius) { continue; }
		float falloff = 1.0 - sqrt(distance_sq) / radius;
		float strength = falloff * falloff * light_points[i].w;
		bool stellar = light_colors[i].a > 0.5;
		if (stellar && spherical_surface) { strength *= stellar_visibility(pos, light_points[i].xy, receiver_center); }
		float height = stellar ? max(0.1, length(delta) * 0.08) : max(1.0, radius * 0.10);
		vec3 direction = normalize(vec3(dot(delta, axis_x), -dot(delta, axis_y), height));
		float lambert = max(0.0, dot(normal, direction));
		vec3 energy = light_colors[i].rgb * strength;
		diffuse_light += energy * (0.015 + lambert);
		vec3 half_vector = normalize(direction + vec3(0.0, 0.0, 1.0));
		shine += energy * pow(max(0.0, dot(normal, half_vector)), 16.0) * specular * 0.22;
	}
	return albedo * diffuse_light * ao + shine;
}

void vertex() {
	mat4 transform = CANVAS_MATRIX * MODEL_MATRIX;
	vec2 center = transform[3].xy;
	receiver_center = center;
	surface_position = (transform * vec4(VERTEX, 0.0, 1.0)).xy;
	surface_axis_x = normalize(transform[0].xy);
	surface_axis_y = normalize(transform[1].xy);
	modulation = COLOR;
	illumination = vec3(0.025, 0.030, 0.040);
	// Legacy vector hulls retain the inexpensive per-instance path.
	if (!authored_sprite && !spherical_surface) {
		for (int i = 0; i < 16; i++) {
			if (i >= light_count) { break; }
			vec2 delta = light_points[i].xy - center;
			float f = max(0.0, 1.0 - length(delta) / max(1.0, light_points[i].z));
			vec2 radial = surface_position - center;
			float facing = 0.30 + 0.70 * max(0.0, dot(normalize(radial + vec2(0.0001)), normalize(delta + vec2(0.0001))));
			illumination += light_colors[i].rgb * f * f * light_points[i].w * facing;
		}
	}
}
void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (base.a <= 0.001) { discard; }
	vec3 lit = base.rgb * min(illumination, vec3(1.25));
	if (spherical_surface) {
		vec2 q = (UV - vec2(0.5)) * 2.0;
		vec3 n = normalize(vec3(q.x, -q.y, sqrt(max(0.0, 1.0 - dot(q, q)))));
		float ao = 1.0;
		float specular = 0.0;
		if (authored_sprite) {
			// Keep the spherical day/night boundary while adding authored
			// relief and reflections from the same cropped atlas cell.
			vec3 relief = texture(normal_map, UV).rgb * 2.0 - 1.0;
			vec2 pixel = TEXTURE_PIXEL_SIZE;
			float dx = texture(height_map, UV + vec2(pixel.x, 0.0)).r - texture(height_map, UV - vec2(pixel.x, 0.0)).r;
			float dy = texture(height_map, UV + vec2(0.0, pixel.y)).r - texture(height_map, UV - vec2(0.0, pixel.y)).r;
			relief = normalize(relief + vec3(-dx * 0.10, dy * 0.10, 0.15));
			n = normalize(mix(n, relief, 0.45));
			ao = mix(0.72, 1.0, texture(occlusion_map, UV).r);
			specular = texture(specular_map, UV).r * 0.50;
		}
		lit = surface_lighting(surface_position, surface_axis_x, surface_axis_y, n, base.rgb, specular, vec3(0.035, 0.035, 0.045), ao);
	} else if (authored_sprite) {
		vec3 n = texture(normal_map, UV).rgb * 2.0 - 1.0;
		vec2 pixel = TEXTURE_PIXEL_SIZE;
		float dx = texture(height_map, UV + vec2(pixel.x, 0.0)).r - texture(height_map, UV - vec2(pixel.x, 0.0)).r;
		float dy = texture(height_map, UV + vec2(0.0, pixel.y)).r - texture(height_map, UV - vec2(0.0, pixel.y)).r;
		n = normalize(n + vec3(-dx * 0.12, dy * 0.12, 0.24));
		float ao = mix(0.62, 1.0, texture(occlusion_map, UV).r);
		float specular = texture(specular_map, UV).r;
		// _v is an offline preview, not a material input. TEXTURE is the
		// empire-decaled diffuse map; only explicit world lights emit light.
		lit = surface_lighting(surface_position, surface_axis_x, surface_axis_y, n, base.rgb, specular * 0.65, vec3(0.035, 0.040, 0.050), ao);
		// Identical low self-lit surface detail for every authored hull; no idle plume or extra light source.
		lit += base.rgb * 0.035;
		float peak = max(lit.r, max(lit.g, lit.b));
		if (peak > 0.75) { lit *= (0.75 + 0.25 * (1.0 - exp(-(peak - 0.75) / 0.25))) / peak; }
	}
	COLOR = vec4(clamp(lit, vec3(0.0), vec3(1.0)), base.a) * modulation;
}
