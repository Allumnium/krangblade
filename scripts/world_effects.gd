extends RefCounted
## Per-match transient combat and transfer presentation. No authority mutations.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const HULL_ART = preload("res://scripts/hull_art.gd")
const CELESTIAL_VIEW = preload("res://scripts/celestial_view.gd")
const WORLD_RENDER_BATCHES = preload("res://scripts/world_render_batches.gd")
const FIGHTER_MUZZLE: float = 12.0
const MINER_MUZZLE: Vector2 = Vector2(10.0, 3.75)
const DESTRUCTION_LIFETIME: float = 1.35
const MAX_VISIBLE_DESTRUCTIONS: int = 32

var last_destruction_sequence: int = 0
var ship_destructions: Array = []
var transfer_visuals: Dictionary = {}
var transfer_visual_seed: int = -1

func reset_destructions() -> void:
	ship_destructions.clear()
	last_destruction_sequence = 0

func sync_destructions(state: Dictionary, visual_clock: float, empire_color: Callable, hull_art: HULL_ART) -> void:
	while not ship_destructions.is_empty() and visual_clock - float(ship_destructions[0]["started"]) >= DESTRUCTION_LIFETIME:
		ship_destructions.pop_front()
	for event in state.get("ship_destructions", []):
		var sequence: int = int(event["sequence"])
		if sequence <= last_destruction_sequence:
			continue
		last_destruction_sequence = sequence
		var kind: String = event["kind"]
		var heading: Vector2 = event["heading"]
		var angle: float = heading.angle() if not heading.is_zero_approx() else -PI * 0.5
		var empire: Color = empire_color.call(int(event["owner"]))
		var hull: Color = empire.lightened(0.35)
		var rng := RandomNumberGenerator.new()
		rng.seed = sequence * 7919 + int(event["ship"])
		var vertices: Array = HULL_ART.HULL_OUTLINES.get(kind, HULL_ART.FREIGHTER_OUTLINE)
		if kind == "station":
			vertices = []
			for segment in range(16):
				vertices.append(Vector2.from_angle(TAU * float(segment) / 16.0) * 12.0)
		elif kind == "shipyard":
			vertices = [Vector2(-12, -8), Vector2(12, -8), Vector2(12, 8), Vector2(-12, 8)]
		var panels: Array = HULL_ART.HULL_PANELS.get(kind, [])
		var edge_color: Color = empire_color.call(int(event["owner"])).lightened(0.2)
		var fragments: Array = []
		for index in range(vertices.size()):
			var a: Vector2 = vertices[index]
			var b: Vector2 = vertices[(index + 1) % vertices.size()]
			var center: Vector2 = (a + b) * 0.5
			var velocity: Vector2 = center.normalized().rotated(rng.randf_range(-0.45, 0.45)) * rng.randf_range(12.0, 30.0)
			fragments.append({"offset": center, "half": (b - a) * 0.5, "velocity": velocity, "spin": rng.randf_range(-5.0, 5.0), "color": edge_color, "hull": hull})
		var sparks: Array = []
		# Emit from the actual interior panels rather than a generic fire palette.
		for panel in panels:
			var center: Vector2 = Vector2.ZERO
			var polygon: Array = panel[1]
			for vertex in polygon:
				center += vertex
			center /= float(polygon.size())
			for index in range(2):
				sparks.append(_destruction_spark(center, hull_art.panel_color(empire, panel[0]), rng))
		if panels.is_empty():
			# The freighter has dark cargo wells and resource-colored bays.
			for index in range(8):
				sparks.append(_destruction_spark(Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-5.0, 5.0)), Color("#182333"), rng))
			for resource in event.get("materials", []):
				for index in range(3):
					sparks.append(_destruction_spark(Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-5.0, 5.0)), HUD.COLORS.get(resource, hull), rng))
		for index in range(5):
			sparks.append(_destruction_spark(Vector2.ZERO, hull, rng))
		ship_destructions.append({"position": event["position"], "angle": angle, "started": visual_clock, "fragments": fragments, "sparks": sparks, "scale": 3.2 if kind == "station" else HULL_ART.visual_scale(kind), "structure": not ECONOMY.SHIP_KINDS.has(kind)})
		if ship_destructions.size() > MAX_VISIBLE_DESTRUCTIONS:
			ship_destructions.pop_front()

func _destruction_spark(offset: Vector2, color: Color, rng: RandomNumberGenerator) -> Dictionary:
	var direction: Vector2 = Vector2.from_angle(rng.randf_range(0.0, TAU))
	return {"offset": offset, "velocity": direction * rng.randf_range(18.0, 42.0), "size": rng.randf_range(0.65, 1.65), "color": color}

func draw_destructions(viewport_bounds: Rect2, visual_clock: float, ship_scale: Callable, screen_point: Callable, world_batches: WORLD_RENDER_BATCHES) -> void:
	for effect in ship_destructions:
		var scale: float = maxf(0.2, ship_scale.call(bool(effect.get("structure", false)))) * float(effect.get("scale", 1.0))
		var point: Vector2 = screen_point.call(effect["position"])
		if not viewport_bounds.grow(maxf(80.0, 60.0 * scale)).has_point(point):
			continue
		var age: float = visual_clock - float(effect["started"])
		var fade: float = clampf(1.0 - age / DESTRUCTION_LIFETIME, 0.0, 1.0)
		if fade <= 0.0:
			continue
		# Local forward and lateral match the original hull transform.
		var forward: Vector2 = Vector2.from_angle(float(effect["angle"])) * scale
		var lateral: Vector2 = forward.orthogonal()
		var travel: float = (1.0 - exp(-2.2 * age)) / 2.2
		for particle in effect["sparks"]:
			var offset: Vector2 = particle["offset"] + particle["velocity"] * travel
			var position: Vector2 = point + forward * offset.x + lateral * offset.y
			world_batches.queue_projectile(position, maxf(0.65, float(particle["size"]) * scale * (0.55 + fade * 0.45)), Color(particle["color"], fade))
		# Each original outline segment detaches, drifts and tumbles.
		for fragment in effect["fragments"]:
			var offset: Vector2 = fragment["offset"] + fragment["velocity"] * travel
			var half: Vector2 = (fragment["half"] as Vector2).rotated(float(fragment["spin"]) * age)
			var center: Vector2 = point + forward * offset.x + lateral * offset.y
			var edge: Vector2 = forward * half.x + lateral * half.y
			world_batches.queue_beam(center - edge, center + edge, Color(fragment["hull"], fade), maxf(1.0, 2.0 * scale))
			world_batches.queue_beam(center - edge, center + edge, Color(fragment["color"], fade), maxf(0.6, scale))

# Same source-player hue for every beam. The wider translucent halo
# and brighter core retain readability without changing the allegiance.
# GPU instanced, color-modulated quads. The circle shader softens edges
# without per-projectile tessellation; beams retain their exact endpoints.
func draw_owned_laser(origin: Vector2, target: Vector2, owner: int, width: float, empire_color: Callable, world_batches: WORLD_RENDER_BATCHES) -> void:
	var tint: Color = empire_color.call(owner)
	world_batches.queue_beam(origin, target, Color(tint, 0.28), width * 3.0)
	world_batches.queue_beam(origin, target, tint.lightened(0.28), width)

func draw_blaster_tracers(state: Dictionary, ship: Dictionary, poses: Dictionary, celestial_view: CELESTIAL_VIEW, screen_point: Callable, empire_color: Callable, ship_scale: Callable, world_batches: WORLD_RENDER_BATCHES) -> void:
	if not ship.has("blaster_fired"):
		return
	var age: float = maxf(0.0, celestial_view.orbit_time(state) - float(ship["blaster_fired"]))
	if age >= ECONOMY.BLASTER_TRAVEL:
		return
	var mounts: Array = {"scout": [Vector2(11, 0)], "fighter": [Vector2(1, -5), Vector2(1, 5)], "cruiser": [Vector2(17, 0), Vector2(5, -10), Vector2(5, 10)], "destroyer": [Vector2(34, -5), Vector2(34, 5), Vector2(14, -15), Vector2(14, 15)]}.get(ship["kind"], [])
	var start: Vector2 = screen_point.call(ship["blaster_origin"])
	var endpoint: Vector2 = screen_point.call(ship["blaster_endpoint"])
	var direction: Vector2 = poses.get(int(ship["id"]), {}).get("direction", start.direction_to(endpoint))
	var tint: Color = empire_color.call(int(ship["owner"])).lightened(0.45)
	var scale: float = ship_scale.call()
	for prior in range(int(ship.get("blaster_visual_shot", 0)) + 1):
		var travel: float = (age + float(prior) * ECONOMY.BLASTER_SHOT_INTERVAL) / ECONOMY.BLASTER_TRAVEL
		if travel >= 1.0:
			break
		for mount in mounts:
			var muzzle: Vector2 = start + (direction * mount.x + direction.orthogonal() * mount.y) * scale
			var point: Vector2 = muzzle.lerp(endpoint, travel)
			var radius: float = clampf(scale * 0.9, 1.0, 3.5)
			world_batches.queue_projectile(point, radius * 1.8, Color(tint, 0.24))
			world_batches.queue_projectile(point, radius, tint)

func draw_ship_laser(ship: Dictionary, pose: Dictionary, endpoint: Vector2, width: float, ship_scale: Callable, empire_color: Callable, world_batches: WORLD_RENDER_BATCHES) -> void:
	if ship["kind"] in ["scout", "fighter"]:
		return
	if ship["kind"] != "miner":
		var mounts: Array = {"cruiser": [Vector2(20, 3), Vector2(20, -3)], "destroyer": [Vector2(30, 12), Vector2(30, -12), Vector2(21, 16), Vector2(21, -16)]}.get(ship["kind"], [Vector2(FIGHTER_MUZZLE, 0)])
		var axis: Vector2 = pose["direction"]
		for mount in mounts:
			draw_owned_laser((pose["point"] as Vector2) + (axis * mount.x + axis.orthogonal() * mount.y) * ship_scale.call(), endpoint, int(ship["owner"]), width, empire_color, world_batches)
		return
	var point: Vector2 = pose["point"]
	var direction: Vector2 = pose["direction"] if bool(ship.get("holding", false)) else point.direction_to(endpoint)
	if direction.is_zero_approx():
		direction = pose["direction"]
	pose["direction"] = direction
	var scale: float = ship_scale.call()
	for sign in [-1.0, 1.0]:
		var origin: Vector2 = point + (direction * MINER_MUZZLE.x + direction.orthogonal() * sign * MINER_MUZZLE.y) * scale
		draw_owned_laser(origin, endpoint, int(ship["owner"]), maxf(0.65, width * 0.65), empire_color, world_batches)

func draw_cargo_transfers(state: Dictionary, poses: Dictionary, refs: Dictionary, bounds: Rect2, visual_clock: float, ship_scale: Callable, map_canvas: Control, transfer_anchor: Callable) -> void:
	var seed_value: int = int(state["map"]["seed"])
	if transfer_visual_seed != seed_value:
		transfer_visual_seed = seed_value
		transfer_visuals.clear()
	var events: Dictionary = state.get("cargo_transfers", {})
	for key in transfer_visuals.keys():
		if not events.has(key):
			transfer_visuals.erase(key)
	for key in events:
		var event: Dictionary = events[key]
		var old: Dictionary = transfer_visuals.get(key, {})
		if int(old.get("seq", -1)) != int(event["seq"]):
			var start: float = float(old.get("start", visual_clock)) if visual_clock - float(old.get("last", -100.0)) < 0.65 else visual_clock
			old = {"seq": event["seq"], "start": start, "last": visual_clock}
			transfer_visuals[key] = old
		var age: float = visual_clock - float(old["last"])
		if age > 0.65:
			continue
		var resource: String = event["resource"]
		var a: Vector2 = transfer_anchor.call(state, poses, refs, int(event["source"]), resource, int(event["from_bay"]))
		var b: Vector2 = transfer_anchor.call(state, poses, refs, int(event["target"]), resource, int(event["to_bay"]))
		if not a.is_finite() or not b.is_finite() or (not bounds.grow(30.0).has_point(a) and not bounds.grow(30.0).has_point(b)):
			continue
		var color: Color = HUD.COLORS[resource]
		var count: int = clampi(ceili(sqrt(float(event["amount"])) * 2.0), 2, 8)
		var radius: float = clampf(ship_scale.call() * 1.2, 0.9, 3.5)
		for i in range(count):
			var phase: float = fposmod((visual_clock - float(old["start"])) * 2.8 + float(i) / float(count), 1.0)
			var point: Vector2 = a.lerp(b, phase)
			var alpha: float = (1.0 - age / 0.65) * smoothstep(0.0, 0.15, phase) * (1.0 - smoothstep(0.85, 1.0, phase))
			map_canvas.draw_circle(point, radius * 2.0, Color(color, alpha * 0.18), true, -1.0, true)
			map_canvas.draw_rect(Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), Color(color.lightened(0.2), alpha))


# Read the same replicated visual hit endpoints as the weapon renderer.
# No new combat events or simulation mutations. Limit retained flashes to 4.
func _impact_entry(lights: Array, world: Vector2, color: Color, strength: float, radius: float, bounds: Rect2, project: Callable, visible: Callable) -> void:
	if strength <= 0.0 or not world.is_finite() or not visible.call(world):
		return
	var point: Vector2 = project.call(world)
	if not bounds.grow(radius).has_point(point):
		return
	var distance: float = bounds.get_center().distance_squared_to(point)
	var priority: float = distance / maxf(0.1, strength)
	# Merge multiple simultaneous hits on the same target.
	for entry in lights:
		if (entry[0] as Vector2).distance_squared_to(point) < 9.0:
			entry[3] = minf(2.5, maxf(float(entry[3]), strength) + 0.15)
			return
	var index: int = lights.size()
	while index > 0 and priority < float(lights[index - 1][4]):
		index -= 1
	if index >= 4:
		return
	lights.insert(index, [point, radius, color, strength, priority])
	if lights.size() > 4:
		lights.pop_back()

func _impact_target(id: int, poses: Dictionary, refs: Dictionary) -> Vector2:
	if poses.has(id):
		return poses[id]["world"]
	var ref: Dictionary = refs.get(id, {})
	if ref.get("kind", "") == "ship":
		return Vector2.INF
	return ref.get("position", Vector2.INF)

func impact_lights(state: Dictionary, poses: Dictionary, refs: Dictionary, bounds: Rect2, scale: float, now: float, project: Callable, visible: Callable, empire_color: Callable) -> Array:
	var lights: Array = []
	if scale < 0.42:
		return lights
	var elapsed: float = float(state["elapsed"])
	var radius: float = maxf(15.0, 48.0 * scale)
	for ship in state["ships"]:
		if not poses.has(int(ship["id"])):
			continue
		var tint: Color = empire_color.call(int(ship["owner"]))
		if ship.has("blaster_fired") and ship.has("blaster_endpoint"):
			var age: float = now - float(ship["blaster_fired"])
			for prior in range(int(ship.get("blaster_visual_shot", 0)) + 1):
				var since_hit: float = age + float(prior) * ECONOMY.BLASTER_SHOT_INTERVAL - ECONOMY.BLASTER_TRAVEL
				if since_hit >= 0.0 and since_hit < 0.18:
					_impact_entry(lights, ship["blaster_endpoint"], tint, 1.3 * (1.0 - since_hit / 0.18), radius, bounds, project, visible)
		for prefix in ["railgun", "cannon", "wall_laser"]:
			if ship.has(prefix + "_endpoint") and float(ship.get(prefix + "_until", -1.0)) >= elapsed:
				_impact_entry(lights, ship[prefix + "_endpoint"], tint, 1.5, radius, bounds, project, visible)
		if ship.has("missile_endpoint"):
			var since_hit: float = now - float(ship.get("missile_until", -10.0))
			if since_hit >= 0.0 and since_hit < 0.35:
				_impact_entry(lights, ship["missile_endpoint"], Color("#ffad65"), 2.5 * (1.0 - since_hit / 0.35), radius * 1.8, bounds, project, visible)
		if ship.get("kind", "") not in ["scout", "fighter"]:
			if float(ship.get("laser_until", -1.0)) >= elapsed:
				_impact_entry(lights, _impact_target(int(ship.get("combat_target", -1)), poses, refs), tint, 1.1, radius, bounds, project, visible)
			if float(ship.get("yard_laser_until", -1.0)) >= elapsed:
				_impact_entry(lights, _impact_target(int(ship.get("yard_target", -1)), poses, refs), tint, 1.1, radius, bounds, project, visible)
	for index in range(state["planets"].size()):
		if not visible.call(state["map"]["points"][index]):
			continue
		var system: Dictionary = state["planets"][index]
		var tint: Color = empire_color.call(int(system["owner"]))
		var station: Dictionary = system.get("station", {})
		if station.has("missile_endpoint"):
			var since_hit: float = now - float(station.get("missile_until", -10.0))
			if since_hit >= 0.0 and since_hit < 0.35:
				_impact_entry(lights, station["missile_endpoint"], Color("#ffad65"), 2.5 * (1.0 - since_hit / 0.35), radius * 1.8, bounds, project, visible)
		var weapons: Array = station.get("weapons", []).duplicate()
		weapons.append_array(system.get("pds", {}).values())
		for weapon in weapons:
			if float(weapon.get("laser_until", -1.0)) >= elapsed:
				var target: Vector2 = weapon.get("wall_laser_endpoint", _impact_target(int(weapon.get("target", -1)), poses, refs))
				_impact_entry(lights, target, tint, 1.4, radius, bounds, project, visible)
	return lights
