extends SceneTree
## Pure snapshot codec regression: no networking, mutation or scene required.
const CODEC = preload("res://scripts/snapshot_codec.gd")

func _initialize() -> void:
	var map_template: Dictionary = {
		"seed": 7,
		"fields": [{"type": "ore", "chunks": [
			{"id": 10, "remaining": 50.0, "kind": "Metals"},
			{"id": 11, "remaining": 30.0, "kind": "Crystals"}
		]}]
	}
	var current: Dictionary = map_template.duplicate(true)
	current["fields"][0]["chunks"][0]["remaining"] = 12.0
	current["fields"][0]["chunks"].remove_at(1)
	var updates: Variant = CODEC.encode_map_ore(current, map_template)
	assert(updates is Array)
	assert(updates[0][10] == 12.0 and updates[0][11] == -1.0)
	assert(CODEC.restore_map_ore(map_template, updates) == current)
	assert(float(map_template["fields"][0]["chunks"][0]["remaining"]) == 50.0)
	assert(CODEC.restore_map_ore(map_template, [{"invalid_id": -1.0}]).is_empty())
	assert(CODEC.restore_map_ore(map_template, [{10: -2.0}]).is_empty())
	var incompatible: Dictionary = current.duplicate(true)
	incompatible["seed"] = 9
	assert(CODEC.encode_map_ore(incompatible, map_template) == null)

	var live_planets: Array = [{"home": true, "size_factor": 1.5, "population": 42.0, "stock": {"Metals": 90.0}}]
	var template: Array = CODEC.planet_template(live_planets)
	var compacted: Array = CODEC.compact_planets(live_planets, template)
	assert(compacted.size() == 1 and not compacted[0].has("home"))
	assert(CODEC.restore_planets(compacted, template) == live_planets)
	assert(live_planets[0]["home"])
	var wrong_planets: Array = live_planets.duplicate(true)
	wrong_planets[0]["home"] = false
	assert(CODEC.compact_planets(wrong_planets, template).is_empty())
	assert(CODEC.restore_planets([{"home": true}], template).is_empty())

	var state: Dictionary = {"map": current, "planets": live_planets, "next_ai": 3, "ai_waves": {}, "next_operation_id": 8, "_pirate_epoch": 5, "owner": 1}
	var wire: Dictionary = CODEC.encode_replica(state, map_template, true, template)
	assert(not wire.has("map") and wire.has("_wire_ore"))
	assert(wire.has("_wire_planet_template") and wire.has("_wire_map_template"))
	assert(not wire.has("next_ai") and not wire.has("ai_waves") and not wire.has("next_operation_id") and not wire.has("_pirate_epoch"))
	assert(CODEC.restore_map_ore(wire["_wire_map_template"], wire["_wire_ore"]) == current)
	assert(CODEC.restore_planets(wire["planets"], wire["_wire_planet_template"]) == live_planets)
	assert(state.has("map") and state.has("next_ai"))
	var full: Dictionary = CODEC.encode_replica(state, {}, false, [])
	assert(full.has("map") and not full.has("_wire_ore"))
	print("PASS: snapshot codec delta, fallback, planet round-trip and bad input")
	quit()
