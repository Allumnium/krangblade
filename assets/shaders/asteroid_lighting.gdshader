shader_type canvas_item;
render_mode unshaded;
uniform sampler2D normal_map : filter_nearest;
uniform sampler2D occlusion_map : filter_nearest;
uniform sampler2D height_map : filter_nearest;
uniform sampler2D specular_map : filter_nearest;
uniform vec4 light_points[16];
uniform vec4 light_colors[16];
uniform int light_count = 0;
varying vec2 surface_position;
varying vec2 surface_axis_x;
varying vec2 surface_axis_y;
varying float crystal;
// Every point light contributes its own diffuse and specular terms, in
// the same canvas space as the submitted light coordinates. A finite
// height prevents singularities at the projected source center.
vec3 compress_highlights(vec3 rgb) {
	float peak = max(rgb.r, max(rgb.g, rgb.b));
	if (peak > 0.72) {
		rgb *= (0.72 + 0.28 * (1.0 - exp(-(peak - 0.72) / 0.28))) / peak;
	}
	return rgb;
}
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
		float height = stellar ? max(0.001, length(delta) * 0.18) : max(0.001, radius * 0.10);
		vec3 direction = normalize(vec3(dot(delta, axis_x), -dot(delta, axis_y), height));
		float lambert = max(0.0, dot(normal, direction));
		vec3 energy = light_colors[i].rgb * strength;
		diffuse_light += energy * lambert;
		vec3 half_vector = normalize(direction + vec3(0.0, 0.0, 1.0));
		shine += energy * pow(max(0.0, dot(normal, half_vector)), 24.0) * specular * 0.12;
	}
	return albedo * diffuse_light * ao + shine;
}

void vertex() {
	mat4 transform = CANVAS_MATRIX * MODEL_MATRIX;
	surface_position = (transform * vec4(VERTEX, 0.0, 1.0)).xy;
	vec2 axis = normalize(COLOR.rg * 2.0 - 1.0);
	vec2 side = vec2(-axis.y, axis.x);
	surface_axis_x = normalize((transform * vec4(axis, 0.0, 0.0)).xy);
	surface_axis_y = normalize((transform * vec4(side, 0.0, 0.0)).xy);
	crystal = COLOR.b;
}
void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (base.a <= 0.001) { discard; }
	vec3 diffuse = base.rgb;
	// Resource coloration is a diffuse mineral tint, not preview emission.
	float ore = smoothstep(0.16, 0.45, dot(diffuse, vec3(0.299, 0.587, 0.114))) * crystal;
	diffuse = mix(diffuse, vec3(0.72, 0.26, 0.47) * max(0.3, length(diffuse)), ore * 0.8);
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	vec2 cell_min = floor(UV * 8.0) / 8.0 + pixel * 0.5;
	vec2 cell_max = cell_min + vec2(0.125) - pixel;
	float dx = texture(height_map, clamp(UV + vec2(pixel.x, 0.0), cell_min, cell_max)).r - texture(height_map, clamp(UV - vec2(pixel.x, 0.0), cell_min, cell_max)).r;
	float dy = texture(height_map, clamp(UV + vec2(0.0, pixel.y), cell_min, cell_max)).r - texture(height_map, clamp(UV - vec2(0.0, pixel.y), cell_min, cell_max)).r;
	vec3 normal = normalize(texture(normal_map, UV).rgb * 2.0 - 1.0 + vec3(-dx * 0.08, dy * 0.08, 0.28));
	float ao = mix(0.68, 1.0, texture(occlusion_map, UV).r);
	float specular = texture(specular_map, UV).r;
	vec3 lit = surface_lighting(surface_position, surface_axis_x, surface_axis_y, normal, diffuse, specular, vec3(0.030, 0.035, 0.045), ao);
	COLOR = vec4(clamp(compress_highlights(lit), vec3(0.0), vec3(1.0)), base.a);
}
