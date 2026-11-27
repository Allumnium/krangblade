extends SceneTree
const ECON = preload("res://scripts/economy_rules.gd")
const MAP = preload("res://scripts/planet_map.gd")
const FOG = preload("res://scripts/fog_of_war.gd")
const CELESTIAL = preload("res://scripts/celestial_view.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_asteroid_memory()
	# Art variant assignment is independent of observation, resource and time.
	var tiles: Dictionary = {}
	for id in range(64):
		var tile: int = CELESTIAL.asteroid_tile(id)
		assert(tile >= 0 and tile < 64)
		assert(tile == CELESTIAL.asteroid_tile(id + 64))
		tiles[tile] = true
	assert(tiles.size() == 64)
	assert(CELESTIAL.ROCK_ATLAS.get_size() == Vector2(256, 256))
	var state: Dictionary = ECON.create(MAP.generate(827, 2, "Grid"), {1: {"team": 1}, 2: {"team": 2}}, [1, 2], false)
	ECON.initialize_diplomacy(state)
	var cache: Dictionary = {}
	var fog = FOG.new()
	var size: Vector2 = state["map"]["size"]
	state["fog_of_war"] = false
	var point: Vector2 = state["map"]["points"][0]
	state["ships"] = [{"id": 1, "kind": "fighter", "owner": 1, "position": point + Vector2(3500, 0)}]
	for tick in range(18):
		match tick:
			1: state["ships"][0]["position"] += Vector2(90, 0)
			2: state["ships"][0]["kind"] = "scout"
			3: state["planets"][0]["buildings"]["test"] = 4
			4: state["planets"][0]["yards"].clear()
			5: state["planets"][0]["pds"].clear()
			6:
				assert(ECON.diplomacy_offer_alliance(state, 1, 2))
				assert(ECON.diplomacy_offer_alliance(state, 2, 1))
			7: assert(ECON.diplomacy_set_permission(state, 2, 1, "vision", false))
			8: state["planets"][0]["station"].clear()
			9: state["planets"][0]["owner"] = 2
			10: state["ships"].clear()
			11: state["planets"][0]["owner"] = 1
			12: state["planets"][0]["station"] = {"hp": 1000.0, "orbit_phase": 1.0}
			13: state["planets"][0]["station"]["orbit_phase"] = 2.0
			14: state["map"]["points"][0] += Vector2(80, 160)
			15: state["planets"][0]["pds"][0] = {"hp": 100.0}
			16: state["planets"][0]["buildings"].clear()
		state["elapsed"] = float(tick) * 11.0
		var expected: Dictionary = ECON.team_vision(state, 1)
		var actual: Dictionary = ECON.team_vision(state, 1, cache)
		assert(actual == expected, "Coverage differs at transition %d" % tick)
		actual.clear()
		assert(ECON.team_vision(state, 1, cache) == expected, "Published coverage aliases retained cache")
		fog.update(state, 1, tick, size)
		assert(fog._live == expected)
		for index in range(state["map"].get("fields", []).size()):
			var view: Dictionary = fog.rock_view(index)
			for rock in view.get("live", []):
				assert(fog.is_visible(rock["position"], size) and bool(rock.get("surveyed", false)))
			for rock in view.get("hidden", []):
				assert(not fog.is_visible(rock["position"], size) and bool(rock.get("surveyed", false)))
		var image: Image = fog._mask_image
		var dimensions: Vector2i = image.get_size()
		for y in range(dimensions.y):
			for x in range(dimensions.x):
				var cell := Vector2i(x, y)
				var alpha: float = image.get_pixelv(cell).a
				var expected_alpha: float = 0.0 if expected.has(cell) else (0.48 if fog._explored.has(cell) else 1.0)
				assert(absf(alpha - expected_alpha) <= 1.0 / 255.0 + 0.00001, "Fog mask differs")
		# Identical coverage at a new publication must still observe current visible data.
		var visible_index: int = -1
		for i in range(state["planets"].size()):
			if fog.is_visible(state["map"]["points"][i], size):
				visible_index = i
				break
		if visible_index >= 0:
			state["planets"][visible_index]["stock"]["Metals"] += 1.0
			fog.update(state, 1, tick + 100, size)
			assert(fog._systems[visible_index]["stock"]["Metals"] == state["planets"][visible_index]["stock"]["Metals"])
			assert(fog.observed_time(visible_index) == state["elapsed"])
	fog.update({}, 1, 999, Vector2.ZERO)
	assert(fog._live.is_empty() and fog._ship_vision_cache.is_empty() and fog.texture == null)
	print("PASS: exact static and orbital vision cache, detached masks, diplomacy, ownership, geometry, fog pixels and live observation")
	quit()

# Unexplored terrain is not published; live observation is remembered without
# exposing unseen depletion. Revisiting removes a depleted rock.
func _test_asteroid_memory() -> void:
	var fog = FOG.new()
	var size := Vector2(10000, 10000)
	var point := Vector2(1000, 1000)
	var distant := Vector2(9000, 9000)
	var chunk: Dictionary = {"id": 1, "position": point, "remaining": 10.0, "initial": 10.0, "radius": 8.0, "resource": "Metals", "rotation": 0.0}
	var unseen: Dictionary = chunk.duplicate()
	unseen["id"] = 2
	unseen["position"] = distant
	var fields: Array = [{"position": point, "radius": 10000.0, "chunks": [chunk, unseen]}]
	fog._initial_map = {"fields": fields}
	fog._seed_rock_memory()
	var state: Dictionary = {"map": {"fields": fields}}
	fog._observe_rocks(state, size)
	assert(fog.rock_view(0)["live"].is_empty() and fog.rock_view(0)["hidden"].is_empty())
	assert(fog.rock_at(0, 2).is_empty())
	fog._live[ECON.vision_cell(point)] = true
	fog._observe_rocks(state, size)
	assert(fog.rock_view(0)["live"].size() == 1 and fog.rock_view(0)["hidden"].is_empty())
	fog._live.clear()
	chunk["remaining"] = 4.0
	fog._observe_rocks(state, size)
	assert(fog.rock_view(0)["live"].is_empty() and fog.rock_view(0)["hidden"].size() == 1)
	assert(float(fog.rock_at(0, 1)["remaining"]) == 10.0 and fog.rock_at(0, 2).is_empty())
	fields[0]["chunks"].remove_at(0)
	fog._observe_rocks(state, size)
	assert(fog.rock_view(0)["hidden"].size() == 1)
	fog._live[ECON.vision_cell(point)] = true
	fog._observe_rocks(state, size)
	assert(fog.rock_view(0)["hidden"].is_empty() and fog.rock_at(0, 1).is_empty())
