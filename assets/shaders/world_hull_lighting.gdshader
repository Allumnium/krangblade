shader_type canvas_item;
render_mode unshaded;
uniform bool authored_sprite = false;
uniform sampler2D diffuse_map : source_color, filter_nearest;
uniform sampler2D normal_map : filter_nearest;
uniform sampler2D occlusion_map : filter_nearest;
uniform sampler2D height_map : filter_nearest;
uniform sampler2D specular_map : filter_nearest;
uniform sampler2D detail_map : source_color, filter_nearest;
uniform vec4 light_points[16];
uniform vec4 light_colors[16];
uniform int light_count = 0;
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
		vec3 direction = normalize(vec3(dot(delta, axis_x), -dot(delta, axis_y), max(1.0, radius * 0.18)));
		float lambert = max(0.0, dot(normal, direction));
		vec3 energy = light_colors[i].rgb * strength;
		diffuse_light += energy * (0.08 + lambert);
		vec3 half_vector = normalize(direction + vec3(0.0, 0.0, 1.0));
		shine += energy * pow(max(0.0, dot(normal, half_vector)), 12.0) * specular * 0.35;
	}
	return albedo * diffuse_light * ao + shine;
}

void vertex() {
	mat4 transform = CANVAS_MATRIX * MODEL_MATRIX;
	vec2 center = transform[3].xy;
	surface_position = (transform * vec4(VERTEX, 0.0, 1.0)).xy;
	surface_axis_x = normalize(transform[0].xy);
	surface_axis_y = normalize(transform[1].xy);
	modulation = COLOR;
	illumination = vec3(0.16, 0.19, 0.23);
	// Legacy vector hulls retain the inexpensive per-instance path.
	if (!authored_sprite) {
		for (int i = 0; i < 16; i++) {
			if (i >= light_count) { break; }
			vec2 delta = light_points[i].xy - center;
			float f = max(0.0, 1.0 - length(delta) / max(1.0, light_points[i].z));
			illumination += light_colors[i].rgb * f * f * light_points[i].w;
		}
	}
}
void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (base.a <= 0.001) { discard; }
	vec3 lit = base.rgb * min(illumination, vec3(1.25));
	if (authored_sprite) {
		vec3 diffuse = texture(diffuse_map, UV).rgb;
		vec3 n = texture(normal_map, UV).rgb * 2.0 - 1.0;
		vec2 pixel = TEXTURE_PIXEL_SIZE;
		float dx = texture(height_map, UV + vec2(pixel.x, 0.0)).r - texture(height_map, UV - vec2(pixel.x, 0.0)).r;
		float dy = texture(height_map, UV + vec2(0.0, pixel.y)).r - texture(height_map, UV - vec2(0.0, pixel.y)).r;
		n = normalize(n + vec3(-dx * 0.20, dy * 0.20, 0.15));
		float ao = mix(0.62, 1.0, texture(occlusion_map, UV).r);
		float specular = texture(specular_map, UV).r;
		// The bright-detail map includes ordinary hull pixels. Only its
		// positive difference from diffuse is an emissive contribution.
		vec3 emissive = max(texture(detail_map, UV).rgb - diffuse, vec3(0.0));
		lit = surface_lighting(surface_position, surface_axis_x, surface_axis_y, n, mix(base.rgb, diffuse, 0.20), specular, vec3(0.14, 0.17, 0.21), ao);
		lit += emissive * 1.25;
	}
	COLOR = vec4(clamp(lit, vec3(0.0), vec3(1.0)), base.a) * modulation;
}
