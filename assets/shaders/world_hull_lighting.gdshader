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
vec3 compress_highlights(vec3 rgb) {
	float peak = max(rgb.r, max(rgb.g, rgb.b));
	if (peak > 0.72) {
		rgb *= (0.72 + 0.28 * (1.0 - exp(-(peak - 0.72) / 0.28))) / peak;
	}
	return rgb;
}
vec3 surface_lighting(vec2 pos, vec2 axis_x, vec2 axis_y, vec3 normal, vec3 geometric_normal, vec2 local_offset, vec3 albedo, float specular, vec3 ambient, float ao) {
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
		// A sphere sees a stable incoming stellar direction across its disc.
		// Hulls retain local point-light directions for nearby impacts/plumes.
		vec2 ray = stellar && spherical_surface ? light_points[i].xy - receiver_center : delta;
		float height = stellar ? max(0.001, length(ray) * (spherical_surface ? 0.045 : 0.18)) : max(0.001, radius * 0.10);
		vec3 direction = normalize(vec3(dot(ray, axis_x), -dot(ray, axis_y), height));
		float visibility = 1.0;
		if (spherical_surface) {
			visibility = smoothstep(0.0, 0.16, dot(geometric_normal, direction));
		} else if (stellar) {
			// Broad hull silhouette shading prevents isolated bright pixels on the far side.
			visibility = mix(0.18, 1.0, smoothstep(-0.7, 0.35, dot(local_offset, direction.xy)));
		}
		float lambert = max(0.0, dot(normal, direction));
		vec3 energy = light_colors[i].rgb * strength * visibility;
		diffuse_light += energy * lambert;
		vec3 half_vector = normalize(direction + vec3(0.0, 0.0, 1.0));
		shine += energy * pow(max(0.0, dot(normal, half_vector)), 24.0) * specular * 0.12;
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
			float facing = 0.08 + 0.92 * max(0.0, dot(normalize(radial + vec2(0.0001)), normalize(delta + vec2(0.0001))));
			illumination += light_colors[i].rgb * f * f * light_points[i].w * facing;
		}
	}
}
void fragment() {
	// Recover the actual rendered UV axes for authored ship quads. This
	// includes MultiMesh rotation and any mirrored mesh UV convention.
	// Evaluate derivatives before discarding transparent edge fragments.
	vec2 ship_pos = surface_position;
	vec2 ship_axis_x = surface_axis_x;
	vec2 ship_axis_y = surface_axis_y;
	if (authored_sprite && !spherical_surface) {
		ship_pos = SCREEN_UV / SCREEN_PIXEL_SIZE;
		vec2 ux = dFdx(UV);
		vec2 uy = dFdy(UV);
		vec2 px = dFdx(ship_pos);
		vec2 py = dFdy(ship_pos);
		float det = ux.x * uy.y - ux.y * uy.x;
		if (abs(det) > 0.00000001) {
			ship_axis_x = normalize((px * uy.y - py * ux.y) / det);
			ship_axis_y = normalize((py * ux.x - px * uy.x) / det);
		}
	}
	vec4 base = texture(TEXTURE, UV);
	if (base.a <= 0.001) { discard; }
	vec3 lit = base.rgb * illumination;
	if (spherical_surface) {
		vec2 q = (UV - vec2(0.5)) * 2.0;
		vec3 geometric = normalize(vec3(q.x, -q.y, sqrt(max(0.0, 1.0 - dot(q, q)))));
		vec3 n = geometric;
		float ao = 1.0;
		float specular = 0.0;
		if (authored_sprite) {
			// Keep the spherical day/night boundary while adding authored
			// relief and reflections from the same cropped atlas cell.
			vec3 relief = texture(normal_map, UV).rgb * 2.0 - 1.0;
			vec2 pixel = TEXTURE_PIXEL_SIZE;
			float dx = texture(height_map, UV + vec2(pixel.x, 0.0)).r - texture(height_map, UV - vec2(pixel.x, 0.0)).r;
			float dy = texture(height_map, UV + vec2(0.0, pixel.y)).r - texture(height_map, UV - vec2(0.0, pixel.y)).r;
			relief = normalize(relief + vec3(-dx * 0.06, dy * 0.06, 0.15));
			// Perturb only the tangent plane; the atlas cannot replace the sphere normal.
			vec3 tangent_relief = relief - geometric * dot(relief, geometric);
			n = normalize(geometric + tangent_relief * 0.18);
			ao = mix(0.72, 1.0, texture(occlusion_map, UV).r);
			specular = texture(specular_map, UV).r * 0.50;
		}
		lit = surface_lighting(surface_position, surface_axis_x, surface_axis_y, n, geometric, vec2(0.0), base.rgb, specular, vec3(0.035, 0.035, 0.045), ao);
	} else if (authored_sprite) {
		vec3 n = texture(normal_map, UV).rgb * 2.0 - 1.0;
		// The three exported hull normal maps encode lateral slopes
		// opposite to the outward height normal in our tangent space.
		// Correct the normal, not the light or the geometric facing gate.
		n.xy = -n.xy;
		vec2 pixel = TEXTURE_PIXEL_SIZE;
		float dx = texture(height_map, UV + vec2(pixel.x, 0.0)).r - texture(height_map, UV - vec2(pixel.x, 0.0)).r;
		float dy = texture(height_map, UV + vec2(0.0, pixel.y)).r - texture(height_map, UV - vec2(0.0, pixel.y)).r;
		n = normalize(n + vec3(-dx * 0.05, dy * 0.05, 0.38));
		float ao = mix(0.62, 1.0, texture(occlusion_map, UV).r);
		float specular = texture(specular_map, UV).r;
		// _v is an offline preview, not a material input. TEXTURE is the
		// empire-decaled diffuse map; only explicit world lights emit light.
		lit = surface_lighting(ship_pos, ship_axis_x, ship_axis_y, n, n, (UV - vec2(0.5)) * vec2(2.0, -2.0), base.rgb, specular * 0.45, vec3(0.035, 0.040, 0.050), ao);
		// Identical low self-lit surface detail for every authored hull; no idle plume or extra light source.
		lit += base.rgb * 0.012;
	}
	COLOR = vec4(clamp(compress_highlights(lit), vec3(0.0), vec3(1.0)), base.a) * modulation;
}
