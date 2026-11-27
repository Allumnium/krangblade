shader_type canvas_item;
render_mode unshaded;
uniform bool science = false;
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
varying vec3 local_light;
varying float directional_strength;
varying vec4 modulation;
void vertex() {
	vec2 center = MODEL_MATRIX[3].xy;
	vec2 axis_x = normalize(MODEL_MATRIX[0].xy);
	vec2 axis_y = normalize(MODEL_MATRIX[1].xy);
	illumination = vec3(0.16, 0.19, 0.23);
	local_light = vec3(0.0, 0.0, 1.0);
	directional_strength = 0.0;
	modulation = COLOR;
	for (int i = 0; i < 16; i++) {
		if (i >= light_count) { break; }
		vec2 delta = light_points[i].xy - center;
		float f = max(0.0, 1.0 - length(delta) / max(1.0, light_points[i].z));
		float strength = f * f * light_points[i].w;
		illumination += light_colors[i].rgb * strength;
		if (strength > directional_strength) {
			vec2 dir = delta / max(1.0, length(delta));
			local_light = normalize(vec3(dot(dir, axis_x), -dot(dir, axis_y), 0.7));
			directional_strength = strength;
		}
	}
}
void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 lit = base.rgb * min(illumination, vec3(1.25));
	if (science) {
		vec3 diffuse = texture(diffuse_map, UV).rgb;
		vec3 n = texture(normal_map, UV).rgb * 2.0 - 1.0;
		vec2 pixel = TEXTURE_PIXEL_SIZE;
		float dx = texture(height_map, UV + vec2(pixel.x, 0.0)).r - texture(height_map, UV - vec2(pixel.x, 0.0)).r;
		float dy = texture(height_map, UV + vec2(0.0, pixel.y)).r - texture(height_map, UV - vec2(0.0, pixel.y)).r;
		n = normalize(n + vec3(-dx, dy, 0.15));
		float ao = mix(0.62, 1.0, texture(occlusion_map, UV).r);
		float ndl = max(0.0, dot(n, local_light));
		float spec = pow(max(0.0, dot(n, normalize(local_light + vec3(0.0, 0.0, 1.0)))), 12.0) * texture(specular_map, UV).r;
		vec3 emissive = max(texture(detail_map, UV).rgb - diffuse * 0.65, vec3(0.0));
		lit = mix(base.rgb, diffuse, 0.20) * (vec3(0.14, 0.17, 0.21) + max(illumination - vec3(0.16, 0.19, 0.23), vec3(0.0)) * (0.3 + ndl)) * ao;
		lit += vec3(spec * directional_strength * 0.42) + emissive * 1.25;
	}
	COLOR = vec4(clamp(lit, vec3(0.0), vec3(1.0)), base.a) * modulation;
}
