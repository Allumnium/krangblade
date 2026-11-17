shader_type canvas_item;
render_mode unshaded;

// Stable grid-hashed star layers. No external textures or gameplay state.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
vec3 stars(vec2 uv, float scale, float density, float time) {
	vec2 cell = floor(uv * scale);
	vec2 offset = vec2(hash(cell + 17.0), hash(cell + 31.0)) * 0.65 + 0.175;
	vec2 local = fract(uv * scale) - offset;
	float seed = hash(cell);
	float d = length(local);
	float twinkle = 0.65 + 0.35 * sin(time * (0.55 + seed * 1.4) + seed * 61.0);
	float core = 1.0 - smoothstep(0.018, 0.047, d);
	float glow = exp(-d * d * 95.0) * 0.17;
	vec3 tint = mix(vec3(0.49, 0.69, 0.98), vec3(0.98, 0.87, 0.72), hash(cell + 7.0));
	return tint * (core + glow) * twinkle * step(1.0 - density, seed);
}
void fragment() {
	vec2 uv = UV;
	vec2 p = uv * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float haze = exp(-length((uv - vec2(0.31, 0.42)) * vec2(1.2, 2.5)) * 3.0);
	float rim = exp(-length((uv - vec2(0.83, 0.17)) * vec2(2.0, 1.7)) * 4.0);
	vec3 color = vec3(0.014, 0.027, 0.052) + haze * vec3(0.035, 0.065, 0.11) + rim * vec3(0.05, 0.022, 0.085);
	color += stars(p, 69.0, 0.24, TIME) * 0.48;
	color += stars(p + vec2(0.27, 0.13), 30.0, 0.15, TIME) * 0.72;
	color += stars(p + vec2(0.73, 0.51), 12.0, 0.07, TIME);
	COLOR = vec4(color, 1.0);
}