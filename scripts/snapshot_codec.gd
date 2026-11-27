extends RefCounted
## Pure economy snapshot encoding and restoration. The session owns peer identity,
## RPCs, template lifetime, revision checks and fallback/recovery decisions.
## Wire keys and ordering are intentionally unchanged.

const PLANET_STATIC_KEYS: Array[String] = ["size_factor", "advanced_bonus", "home", "farm_phase", "abundance", "bonuses", "planetless", "planet_count"]

static func encode_map_ore(live: Dictionary, template: Dictionary) -> Variant:
	var base_fields: Array = template.get("fields", [])
	var live_fields: Array = live.get("fields", [])
	if template.is_empty() or live_fields.size() != base_fields.size() or live.size() != template.size():
		return null
	for key in live:
		if key != "fields" and live[key] != template.get(key):
			return null
	var updates: Array = []
	for i in range(base_fields.size()):
		var base_field: Dictionary = base_fields[i]
		var live_field: Dictionary = live_fields[i]
		if live_field.size() != base_field.size():
			return null
		for key in live_field:
			if key != "chunks" and live_field[key] != base_field.get(key):
				return null
		var base_chunks: Array = base_field.get("chunks", [])
		var live_chunks: Array = live_field.get("chunks", [])
		var changes: Dictionary = {}
		var cursor: int = 0
		# Mining only removes rocks, never renumbers or reorders them.
		for rock in base_chunks:
			var id: int = int(rock["id"])
			if cursor >= live_chunks.size() or int(live_chunks[cursor]["id"]) != id:
				changes[id] = -1.0
				continue
			var active: Dictionary = live_chunks[cursor]
			cursor += 1
			if active.size() != rock.size():
				return null
			for key in active:
				if key != "remaining" and active[key] != rock.get(key):
					return null
			var remaining: float = float(active["remaining"])
			if remaining != float(rock["remaining"]):
				changes[id] = remaining
		if cursor != live_chunks.size():
			return null
		updates.append(changes)
	return updates

static func restore_map_ore(template: Dictionary, updates: Variant) -> Dictionary:
	if template.is_empty() or not updates is Array:
		return {}
	var base_fields: Array = template.get("fields", [])
	if updates.size() != base_fields.size():
		return {}
	var result: Dictionary = template.duplicate()
	var fields: Array = []
	for i in range(base_fields.size()):
		if not updates[i] is Dictionary:
			return {}
		var changes: Dictionary = updates[i]
		var field: Dictionary = (base_fields[i] as Dictionary).duplicate()
		var chunks: Array = []
		var matched: int = 0
		for rock in field.get("chunks", []):
			var id: int = int(rock["id"])
			var remaining: float = float(rock["remaining"])
			if changes.has(id):
				matched += 1
				var value: Variant = changes[id]
				if not value is float and not value is int:
					return {}
				remaining = float(value)
				if remaining == -1.0:
					continue
				if not is_finite(remaining) or remaining < 0.0:
					return {}
			var active: Dictionary = (rock as Dictionary).duplicate()
			active["remaining"] = remaining
			chunks.append(active)
		if matched != changes.size():
			return {}
		field["chunks"] = chunks
		fields.append(field)
	result["fields"] = fields
	return result

static func encode_replica(state: Dictionary, template: Dictionary, needs_template: bool, planet_template: Array = []) -> Dictionary:
	var wire: Dictionary = state.duplicate()
	# Host-only AI scheduling and operation ID allocation. Keep the actual
	# operation records, AI roster, orders and all gameplay state replicated.
	wire.erase("next_ai")
	wire.erase("ai_waves")
	wire.erase("next_operation_id")
	wire.erase("_pirate_epoch")
	wire.erase("_scout_coverage")
	var compact_planets: Array = compact_planets(state["planets"], planet_template)
	if not compact_planets.is_empty():
		wire["planets"] = compact_planets
		wire["_wire_planets_compact"] = true
	if needs_template and not planet_template.is_empty():
		wire["_wire_planet_template"] = planet_template
	var updates: Variant = encode_map_ore(state["map"], template)
	if updates != null:
		wire.erase("map")
		wire["_wire_ore"] = updates
	# Full current map remains the fallback if map topology changes.
	if needs_template:
		wire["_wire_map_template"] = template
	return wire

static func planet_template(planets: Array) -> Array:
	var template: Array = []
	for planet in planets:
		var entry: Dictionary = {}
		for key in PLANET_STATIC_KEYS:
			if planet.has(key):
				entry[key] = planet[key]
		template.append(entry.duplicate(true))
	return template

static func compact_planets(planets: Array, template: Array) -> Array:
	if template.is_empty() or planets.size() != template.size():
		return []
	var result: Array = []
	for i in range(planets.size()):
		var live: Dictionary = planets[i]
		var base: Dictionary = template[i]
		var current: Dictionary = live.duplicate()
		for key in PLANET_STATIC_KEYS:
			if live.has(key) != base.has(key) or live.get(key) != base.get(key):
				return []
			current.erase(key)
		result.append(current)
	return result

static func restore_planets(planets: Array, template: Array) -> Array:
	if template.is_empty() or planets.size() != template.size():
		return []
	var result: Array = []
	for i in range(planets.size()):
		if not planets[i] is Dictionary or not template[i] is Dictionary:
			return []
		var full: Dictionary = (planets[i] as Dictionary).duplicate()
		for key in template[i]:
			if not PLANET_STATIC_KEYS.has(key) or full.has(key):
				return []
		full.merge((template[i] as Dictionary).duplicate(true))
		result.append(full)
	return result
