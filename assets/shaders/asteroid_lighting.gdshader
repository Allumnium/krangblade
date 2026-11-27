shader_type canvas_item;
render_mode unshaded;
uniform sampler2D diffuse_map : source_color, filter_nearest;
uniform sampler2D normal_map : filter_nearest;
uniform sampler2D occlusion_map : filter_nearest;
uniform sampler2D height_map : filter_nearest;
uniform sampler2D specular_map : filter_nearest;
uniform sampler2D detail_map : source_color, filter_nearest;
uniform vec4 light_points[16];
uniform vec4 light_colors[16];
uniform int light_count = 0;
varying vec3 incoming_light;
varying vec3 local_light;
varying float light_strength;
varying float crystal;
void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vec2 axis = normalize(COLOR.rg * 2.0 - 1.0);
	vec2 side = vec2(-axis.y, axis.x);
	crystal = COLOR.b;
	incoming_light = vec3(0.0);
	local_light = vec3(0.0, 0.0, 1.0);
	light_strength = 0.0;
	for (int i = 0; i < 16; i++) {
			if (i >= light_count) { break; }
			vec2 delta = light_points[i].xy - world;
			float f = max(0.0, 1.0 - length(delta) / max(1.0, light_points[i].z));
			float strength = f * f * light_points[i].w;
			incoming_light += light_colors[i].rgb * strength;
			if (strength > light_strength) {
				vec2 dir = delta / max(1.0, length(delta));
				local_light = normalize(vec3(dot(dir, axis), -dot(dir, side), 0.7));
				light_strength = strength;
			}
	}
}
void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 diffuse = mix(base.rgb, texture(diffuse_map, UV).rgb, 0.5);
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	vec2 cell_min = floor(UV * 8.0) / 8.0 + pixel * 0.5;
	vec2 cell_max = cell_min + vec2(0.125) - pixel;
	float dx = texture(height_map, clamp(UV + vec2(pixel.x, 0.0), cell_min, cell_max)).r - texture(height_map, clamp(UV - vec2(pixel.x, 0.0), cell_min, cell_max)).r;
	float dy = texture(height_map, clamp(UV + vec2(0.0, pixel.y), cell_min, cell_max)).r - texture(height_map, clamp(UV - vec2(0.0, pixel.y), cell_min, cell_max)).r;
	vec3 normal = normalize(texture(normal_map, UV).rgb * 2.0 - 1.0 + vec3(-dx, dy, 0.15));
	float ao = mix(0.68, 1.0, texture(occlusion_map, UV).r);
	float lambert = max(0.0, dot(normal, normalize(local_light)));
	float spec = pow(max(0.0, dot(normal, normalize(local_light + vec3(0.0, 0.0, 1.0)))), 14.0) * texture(specular_map, UV).r;
	vec3 lit = diffuse * (vec3(0.19, 0.21, 0.24) + incoming_light * (0.25 + lambert)) * ao + vec3(spec * light_strength * 0.23);
	vec3 veins = texture(detail_map, UV).rgb;
	float ore = smoothstep(0.015, 0.19, veins.g - max(veins.r, veins.b) * 0.75) * crystal;
	lit += vec3(0.62, 0.19, 0.42) * ore * 1.4;
	COLOR = vec4(clamp(lit, vec3(0.0), vec3(1.0)), base.a);
}
