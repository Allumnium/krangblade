extends SceneTree
const ECON = preload("res://scripts/economy_rules.gd")
func _initialize() -> void:
	for count in [100, 400]:
		for blocked in [false, true]:
			var state: Dictionary = {"ships": [], "teams": {1: 1, 2: 2}, "diplomacy": {}, "elapsed": 0.0, "map": {"size": Vector2(4000, 4000)}}
			if blocked:
				for i in range(5):
					var p := Vector2(1800, 1000 + i * 400)
					state["ships"].append({"id": i + 1000, "owner": 2, "kind": "wall_node", "position": p, "build_progress": 1.0, "hp": 100.0})
					if i > 0:
						state["ships"].append({"id": i + 2000, "owner": 2, "kind": "wall_segment", "wall_a": p - Vector2(0, 400), "wall_b": p, "wall_a_id": i + 999, "wall_b_id": i + 1000, "build_progress": 1.0, "hp": 100.0})
			var units: Array = []
			for i in range(count):
				var point := Vector2(1300, 1400 + i % 400)
				units.append({"id": i + 1, "kind": "fighter", "owner": 1, "position": point, "heading": Vector2.RIGHT, "navigation_target": point, "goal": point + Vector2(1000, 0)})
			ECON._refresh_movement_fields([])
			ECON._movement_wall_state = state
			ECON._movement_wall_grid = ECON.wall_grid(state)
			var samples: Array = []
			var arrived: int = 0
			for tick in range(800):
				ECON._wall_nav_budget = ECON.WALL_NAV_PLAN_LIMIT
				ECON._rock_plan_tick += 1
				var t: int = Time.get_ticks_usec()
				arrived = 0
				for ship in units:
					if (ship["position"] as Vector2).is_equal_approx(ship["goal"]):
						arrived += 1
					else:
						ECON._navigate(ship, ship["goal"], 20.0, false)
				samples.append((Time.get_ticks_usec() - t) / 1000.0)
				if arrived == count:
					break
			if arrived != count:
				push_error("Wall benchmark: not all hulls reached the goal")
				quit(1)
				return
			samples.sort()
			print("WALL_PROFILE count=%d blocked=%s ticks=%d arrived=%d p50=%.3f p95=%.3f max=%.3f" % [count, blocked, samples.size(), arrived, samples[ceili(samples.size()*0.5)-1], samples[ceili(samples.size()*0.95)-1], samples.back()])
	quit()
