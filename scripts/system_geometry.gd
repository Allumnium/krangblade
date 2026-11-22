extends RefCounted
## Pure deterministic system geometry; no simulation mutation or cached state.

# Decorative bodies are derived from immutable system data, not simulated entities.
# Separate RNG keeps the economy's seeded resource generation unchanged.
static func system_bodies(system: Dictionary, seed_value: int, index: int, extracted: Array) -> Array:
	if bool(system.get("planetless", false)):
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 31013 + index * 7919
	var weights: Dictionary = {}
	var richness: float = 0.0
	for resource in extracted:
		var amount: float = float(system["abundance"].get(resource, 0.0))
		weights[resource] = amount
		richness += amount
	var organic: float = maxf(0.0, float(system["bonuses"].get("Organics", 1.0)) - 1.0)
	weights["Organics"] = organic * 2.0
	richness += organic
	var count: int = clampi(roundi(2.0 + richness * 0.64 + rng.randf_range(-0.65, 0.65)), 2, 6)
	var bodies: Array = []
	for i in range(count):
		var total: float = 0.8
		for resource in weights:
			total += float(weights[resource])
		var choice: float = rng.randf_range(0.0, total)
		var material: String = ""
		for resource in weights:
			choice -= float(weights[resource])
			if choice < 0.0:
				material = resource
				break
		bodies.append({"resource": material, "orbit": lerpf(0.28, 0.88, float(i) / float(count - 1)),
			"phase": rng.randf_range(0.0, TAU), "speed": rng.randf_range(0.65, 1.0) / (1.0 + float(i) * 0.42),
			"size": rng.randf_range(0.035, 0.095), "surface_seed": rng.randi_range(1, 2147483646),
			"surface_angle": rng.randf_range(0.0, TAU), "muted": rng.randf_range(0.0, 0.65), "bands": rng.randf() < 0.3})
	return bodies

# Match the rendered orbit geometry using the authoritative simulation clock.
static func body_position(body: Dictionary, radius: float, elapsed: float) -> Vector2:
	var angle: float = float(body["phase"]) + elapsed * float(body["speed"]) * 0.22
	var orbit_radius: float = radius * float(body["orbit"])
	return Vector2(cos(angle) * orbit_radius, sin(angle) * orbit_radius * 0.65)

static func system_world_radius(state: Dictionary, index: int, base_radius: float) -> float:
	var points: Array = state["map"]["points"]
	var closest: float = INF
	for i in range(points.size()):
		if i != index:
			closest = minf(closest, (points[index] as Vector2).distance_to(points[i]))
	return minf(base_radius * float(state["planets"][index].get("size_factor", 1.0)), closest * 0.39)

