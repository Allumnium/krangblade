extends SceneTree
const MAP = preload("res://scripts/planet_map.gd")
const ECON = preload("res://scripts/economy_rules.gd")

func _initialize() -> void:
    var graph: Dictionary = MAP.generate(2468)
    assert(graph == MAP.generate(2468))
    assert(graph != MAP.generate(2469))
    var all_friendly: Array[int] = []
    all_friendly.resize(MAP.COUNT)
    all_friendly.fill(1)
    for i in range(MAP.COUNT):
        assert(not MAP.path(graph, all_friendly, 1, 0, i).is_empty())
    var players: Dictionary = {1: {"team": 1}, 2: {"team": 1}, 3: {"team": 2}}
    var ids: Array[int] = [1, 2, 3]
    var state: Dictionary = ECON.create(graph, players, ids)
    var p: Dictionary = state["planets"][0]
    assert(p["yards"].size() == 1)
    assert(p["levels"].size() == 6)
    assert(p["stock"].size() == 6)
    assert(not p["abundance"].has("Tech"))
    assert(not p["bonuses"].has("Tech"))
    assert(not ECON.enqueue(state, 2, 0, "ship"))
    assert(not ECON.set_thresholds(state, 1, 0, "Metals", 200, 100))
    assert(ECON.set_thresholds(state, 1, 0, "Metals", 0, 100))
    assert(not ECON.enqueue(state, 1, 0, "production", "Tech"))

    # Construction is proportional, time-dependent and fully refundable.
    p["levels"]["Metals"] = 0
    p["stock"]["Metals"] = 30.0
    assert(ECON.enqueue(state, 1, 0, "ship"))
    ECON.step(state, 1.0)
    assert(is_equal_approx(float(p["queue"][0]["progress"]), 6.0))
    assert(is_equal_approx(float(p["stock"]["Metals"]), 15.0))
    ECON.step(state, 1.0)
    var item: Dictionary = p["queue"][0]
    assert(is_equal_approx(float(item["progress"]), 12.0))
    ECON.step(state, 1.0)
    assert(is_equal_approx(float(item["progress"]), 12.0))
    assert(ECON.cancel(state, 1, 0, int(item["id"])))
    assert(is_equal_approx(float(p["stock"]["Metals"]), 30.0))
    assert(p["queue"].is_empty())

    # Two yards take two different jobs. Upgrading a yard releases its job.
    p["stock"]["Metals"] = 5000.0
    p["yards"].append({"level": 1, "job": -1})
    assert(ECON.enqueue(state, 1, 0, "ship"))
    assert(ECON.enqueue(state, 1, 0, "ship"))
    ECON.step(state, 1.0)
    assert(int(p["yards"][0]["job"]) != int(p["yards"][1]["job"]))
    assert(is_equal_approx(float(p["queue"][0]["progress"]), 6.0))
    assert(is_equal_approx(float(p["queue"][1]["progress"]), 6.0))
    assert(ECON.enqueue(state, 1, 0, "yard_upgrade", "0"))
    assert(int(p["yards"][0]["job"]) == -1)
    ECON.step(state, 1.0)
    assert(is_equal_approx(float(p["queue"][0]["progress"]), 6.0))
    for i in range(25):
        ECON.step(state, 1.0)
    assert(state["ships"].size() == 2)
    assert(p["queue"].size() == 1)
    for i in range(5):
        ECON.step(state, 1.0)
    assert(int(p["yards"][0]["level"]) == 2)
    assert(ECON.max_size(2) > ECON.max_size(1))

    # Physical, mixed cargo from an owned planet to an allied one. No hostile transit.
    var test_map: Dictionary = MAP.generate(123)
    test_map["edges"] = [[0, 1], [1, 2]]
    var points: Array = test_map["points"]
    points[0] = Vector2(0, 0)
    points[1] = Vector2(190, 0)
    points[2] = Vector2(380, 0)
    var transport: Dictionary = ECON.create(test_map, players, ids)
    var source: Dictionary = transport["planets"][0]
    var ally: Dictionary = transport["planets"][1]
    var hostile: Dictionary = transport["planets"][2]
    for planet in [source, ally, hostile]:
        planet["levels"]["Metals"] = 0
        for r in ECON.RESOURCES:
            planet["stock"][r] = 0.0
            planet["thresholds"][r] = {"min": 0.0, "max": 0.0}
    source["stock"]["Metals"] = 4.0
    source["stock"]["Plastics"] = 6.0
    ally["thresholds"]["Metals"] = {"min": 100.0, "max": 100.0}
    ally["thresholds"]["Plastics"] = {"min": 100.0, "max": 100.0}
    hostile["thresholds"]["Metals"] = {"min": 100.0, "max": 100.0}
    for i in range(2):
        transport["ships"].append({"id": i, "owner": 1, "at": 0, "route": [],
            "leg": 0.0, "source": -1, "dest": -1, "cargo": ECON.empty_stock()})
    ECON.step(transport, 1.0)
    ECON.step(transport, 1.0)
    var first: Dictionary = transport["ships"][0]
    var second: Dictionary = transport["ships"][1]
    assert(is_equal_approx(float(first["cargo"]["Metals"]), 4.0))
    assert(is_equal_approx(float(first["cargo"]["Plastics"]), 6.0))
    assert(is_equal_approx(ECON._cargo_total(second), 0.0))
    assert(is_equal_approx(float(ally["stock"]["Metals"]), 0.0))
    ECON.step(transport, 1.0)
    assert(is_equal_approx(float(ally["stock"]["Metals"]), 0.0))
    ECON.step(transport, 1.0)
    assert(is_equal_approx(float(ally["stock"]["Metals"]), 4.0))
    assert(is_equal_approx(float(ally["stock"]["Plastics"]), 6.0))
    assert(is_equal_approx(float(hostile["stock"]["Metals"]), 0.0))
    # Colony hulls use shipyards, travel before ownership changes, and cannot be stolen.
    var colony_map: Dictionary = MAP.generate(12)
    colony_map["edges"] = [[0, 1], [1, 3], [2, 3], [3, 4]]
    var cp: Array = colony_map["points"]
    cp[0] = Vector2(0, 0)
    cp[1] = Vector2(95, 0)
    cp[2] = Vector2(285, 0)
    cp[3] = Vector2(190, 0)
    cp[4] = Vector2(190, 95)
    var colonization: Dictionary = ECON.create(colony_map, players, ids)
    assert(ECON.enqueue(colonization, 1, 0, "colony_ship"))
    assert(ECON.enqueue(colonization, 3, 2, "colony_ship"))
    for i in range(12):
        ECON.step(colonization, 1.0)
    assert(colonization["ships"].size() == 2)
    var c1: Dictionary = colonization["ships"][0]
    var c2: Dictionary = colonization["ships"][1]
    assert(c1["kind"] == "colony_ship" and c2["kind"] == "colony_ship")
    assert(not ECON.send_colony(colonization, 2, int(c1["id"]), 3))
    assert(not ECON.send_colony(colonization, 1, int(c1["id"]), 4))
    assert(not ECON.send_colony(colonization, 1, int(c1["id"]), 2))
    assert(ECON.send_colony(colonization, 1, int(c1["id"]), 3))
    assert(ECON.send_colony(colonization, 3, int(c2["id"]), 3))
    assert(int(colonization["planets"][3]["owner"]) == 0)
    ECON.step(colonization, 0.5)
    assert(int(colonization["planets"][3]["owner"]) == 0)
    ECON.step(colonization, 0.5)
    assert(int(colonization["planets"][3]["owner"]) == 3)
    ECON.step(colonization, 1.0)
    assert(colonization["ships"].size() == 1)
    assert(int(c1["dest"]) == -1)
    ECON.step(colonization, 2.0)
    assert(int(c1["at"]) == 0 and c1["route"].is_empty())
    print("PASS: colony construction, permissions, travel, neutral arrival and competing colonies")
    print("PASS: seeded maps, ownership, construction, shipyards, mixed cargo, physical transit, ally sharing")
    quit(0)
