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
    # Seeded clusters are internally connected and connected by sparse bridges.
    for seed_value in range(20):
        var clustered: Dictionary = MAP.generate(seed_value)
        var cluster_ids: Array = clustered["clusters"]
        var cluster_points: Array = clustered["points"]
        var local_distance: float = 0.0
        var bridge_distance: float = 0.0
        var locals: int = 0
        var bridges: int = 0
        for edge in clustered["edges"]:
            var length: float = cluster_points[edge[0]].distance_to(cluster_points[edge[1]])
            if cluster_ids[edge[0]] == cluster_ids[edge[1]]:
                locals += 1
                local_distance += length
            else:
                bridges += 1
                bridge_distance += length
        assert(bridges >= MAP.CLUSTER_COUNT - 1)
        assert(not (clustered["fields"] as Array).is_empty())
        for edge in clustered["edges"]:
            assert(not MAP.blocked(cluster_points[edge[0]], cluster_points[edge[1]], clustered["fields"]))
        for field in clustered["fields"]:
            assert(ECON.field_limit(field, "Metals") > ECON.PLANET_MINING_LIMIT)
            assert(ECON.field_limit(field, "Crystals") > ECON.PLANET_MINING_LIMIT)
            assert(ECON.field_limit(field, "Organics") == 0.0)
        assert(bridge_distance / bridges > local_distance / locals)
        for i in range(MAP.COUNT):
            assert(not MAP.path(clustered, all_friendly, 1, 0, i).is_empty())
        for i in range(8):
            assert(cluster_ids[i] == i % MAP.CLUSTER_COUNT)
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

    # Empire totals include cargo once and exclude allied/hostile inventories.
    var totals_state: Dictionary = ECON.create(graph, players, ids)
    totals_state["planets"][3]["owner"] = 1
    totals_state["planets"][3]["population"] = ECON.COLONY_POPULATION
    totals_state["planets"][3]["stock"]["Metals"] = 25.0
    var own_cargo: Dictionary = ECON.empty_stock()
    own_cargo["Metals"] = 7.0
    totals_state["ships"].append({"owner": 1, "kind": "ship", "cargo": own_cargo})
    totals_state["ships"].append({"owner": 1, "kind": "colony_ship", "cargo": ECON.empty_stock()})
    totals_state["ships"].append({"owner": 2, "kind": "ship", "cargo": own_cargo.duplicate()})
    var totals: Dictionary = ECON.empire_totals(totals_state, 1)
    assert(totals["planets"] == 2 and totals["craft"] == 2)
    assert(totals["logistics"] == 1 and totals["colonies"] == 1)
    assert(is_equal_approx(float(totals["population"]), ECON.HOME_POPULATION + ECON.COLONY_POPULATION))
    assert(is_equal_approx(float(totals["stock"]["Metals"]), 625.0))
    assert(is_equal_approx(float(totals["cargo"]["Metals"]), 7.0))
    assert(is_equal_approx(float(totals["resources"]["Metals"]), 632.0))
    assert(ECON.empire_totals({}, 1)["craft"] == 0)

    # Starting growth is exponential when well below a food-supported plateau.
    var demographics: Dictionary = ECON.create(graph, players, ids)
    var home: Dictionary = demographics["planets"][0]
    home["bonuses"]["Organics"] = 1.0
    home["abundance"]["Metals"] = 1.0
    var capacity: float = ECON.population_capacity(home)
    assert(is_equal_approx(float(home["population"]), 10000.0))
    assert(is_equal_approx(capacity, 100000.0))
    assert(is_equal_approx(ECON.population_multiplier(home), 1.0))
    assert(is_zero_approx(ECON.population_growth(home)))
    var baseline: float = ECON.rate(home, "Metals")
    home["population"] = ECON.HOME_POPULATION * 0.5
    assert(is_equal_approx(ECON.rate(home, "Metals"), baseline * 0.5))
    home["population"] = ECON.HOME_POPULATION
    assert(ECON.rate(home, "Organics") > ECON.organics_demand(home))
    home["stock"]["Organics"] = 10000.0
    for i in range(300):
        ECON._update_population(home, 0.1)
    assert(float(home["population"]) > 19500.0 and float(home["population"]) <= 20000.01)
    for i in range(300):
        ECON._update_population(home, 0.1)
    assert(float(home["population"]) > 39000.0 and float(home["population"]) <= 40000.02)
    # Convergence is damped from either side; no overshoot for fixed capacity.
    var prior: float = float(home["population"])
    for i in range(300):
        ECON._update_population(home, 1.0)
        var next: float = float(home["population"])
        assert(next >= prior - ECON.EPS and next <= capacity + ECON.EPS)
        prior = next
    assert(absf(float(home["population"]) - capacity) < 0.1)
    home["population"] = capacity * 1.5
    home["population_velocity"] = 0.0
    prior = float(home["population"])
    for i in range(300):
        ECON._update_population(home, 1.0)
        var next: float = float(home["population"])
        assert(next <= prior + ECON.EPS and next >= capacity - ECON.EPS)
        prior = next
    assert(absf(float(home["population"]) - capacity) < 0.1)

    # Actual stock rises or falls by farming output minus consumption.
    home["population"] = capacity * 0.5
    home["population_velocity"] = 0.0
    home["stock"]["Organics"] = 100.0
    assert(ECON.current_year(demographics) == 1)
    ECON.step(demographics, 1.0)
    assert(ECON.current_year(demographics) == 2)
    assert(is_equal_approx(float(home["stock"]["Organics"]), 100.0 + ECON.rate(home, "Organics") - ECON.organics_demand(home)))
    assert(ECON.population_growth(home) > 0.0)
    home["population"] = capacity * 1.5
    home["population_velocity"] = 0.0
    home["stock"]["Organics"] = 0.0
    ECON.step(demographics, 1.0)
    assert(is_zero_approx(float(home["stock"]["Organics"])))
    assert(ECON.population_growth(home) < 0.0)
    # A farming failure cannot allow positive growth despite prior momentum.
    home["levels"]["Organics"] = 0
    home["population"] = ECON.HOME_POPULATION
    home["population_velocity"] = 1000.0
    ECON._update_population(home, 0.1)
    assert(float(home["population"]) <= ECON.HOME_POPULATION)
    assert(ECON.population_growth(home) <= 0.0)
    home["levels"]["Organics"] = 1
    home["population"] = capacity
    home["population_velocity"] = 0.0
    assert(ECON.enqueue(demographics, 1, 0, "production", "Organics"))
    ECON.step(demographics, 20.0)
    assert(int(home["levels"]["Organics"]) == 2)
    assert(is_equal_approx(ECON.population_capacity(home), 200000.0 * float(home["farm_factor"])))
    ECON.step(demographics, 1.0)
    assert(float(home["population"]) > capacity)
    home["bonuses"]["Organics"] = 1.5
    assert(is_equal_approx(ECON.population_capacity(home), 300000.0 * float(home["farm_factor"])))
    assert(is_zero_approx(float(demographics["planets"][3]["population"])))
    for i in range(300):
        ECON.step(demographics, 1.0)
    var smallest: float = INF
    var largest: float = -INF
    for i in range(100):
        ECON.step(demographics, 1.0)
        smallest = minf(smallest, float(home["population"]))
        largest = maxf(largest, float(home["population"]))
    assert(largest - smallest > 1000.0 and largest - smallest < 30000.0)
    assert(smallest > 270000.0 and largest < 330000.0)
    assert(ECON.current_year(demographics) == 424)
    print("PASS: 30-year doubling, critically damped population, food shortage, farm upgrades and year clock")

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

    # Fighters use the shipyard and are counted separately; no logistics behavior.
    var military: Dictionary = ECON.create(graph, players, ids)
    assert(not ECON.enqueue(military, 2, 0, "fighter"))
    assert(ECON.enqueue(military, 1, 0, "fighter"))
    for i in range(6):
        ECON.step(military, 1.0)
    assert(military["ships"].size() == 1)
    var fighter: Dictionary = military["ships"][0]
    assert(fighter["kind"] == "fighter" and fighter["route"].is_empty())
    assert(ECON.empire_totals(military, 1)["fighters"] == 1)
    assert(ECON.empire_totals(military, 1)["logistics"] == 0)
    assert(not ECON.send_colony(military, 1, int(fighter["id"]), 3))
    for i in range(20):
        ECON.step(military, 1.0)
    assert(int(fighter["at"]) == 0 and fighter["route"].is_empty())
    print("PASS: clustered map and fighter construction")

    # Deterministic mining round trip; no planetary production or unrelated cargo.
    var mineral_map: Dictionary = MAP.generate(678)
    var mineral_points: Array = mineral_map["points"]
    mineral_map["fields"] = [{"position": (mineral_points[0] as Vector2) + Vector2(95, 0), "radius": 20.0, "anchor": 0, "Metals": 1.0, "Crystals": 1.0}]
    var mineral: Dictionary = ECON.create(mineral_map, players, ids)
    var mine_home: Dictionary = mineral["planets"][0]
    mine_home["levels"]["Metals"] = 1000
    assert(is_equal_approx(ECON.rate(mine_home, "Metals"), ECON.PLANET_MINING_LIMIT))
    mine_home["levels"]["Metals"] = 0
    assert(not ECON.enqueue(mineral, 2, 0, "miner"))
    assert(ECON.enqueue(mineral, 1, 0, "miner"))
    for i in range(10):
        ECON.step(mineral, 1.0)
    assert(mineral["ships"].size() == 1)
    assert(ECON.empire_totals(mineral, 1)["miners"] == 1)
    var miner: Dictionary = mineral["ships"][0]
    assert(miner["kind"] == "miner")
    assert(not ECON.send_colony(mineral, 1, int(miner["id"]), 3))
    var after_build: float = float(mine_home["stock"]["Metals"])
    assert(is_equal_approx(after_build, 420.0))
    for i in range(20):
        ECON.step(mineral, 1.0)
    assert(float(mine_home["stock"]["Metals"]) > after_build)
    assert(float(mine_home["stock"]["Crystals"]) > 0.0)
    for resource in ["Organics", "Tech", "Textiles", "Plastics"]:
        assert(is_zero_approx(float(miner["cargo"][resource])))
    assert(ECON._cargo_total(miner) <= ECON.MINER_CAPACITY + ECON.EPS)
    assert(float(mine_home["size_factor"]) >= 0.86 and float(mine_home["size_factor"]) <= 1.18)
    print("PASS: asteroid route obstacles, mining ceiling and physical mineral delivery")

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
    assert(is_equal_approx(float(colonization["planets"][3]["population"]), ECON.COLONY_POPULATION))
    assert(int(colonization["planets"][3]["levels"]["Organics"]) == 1)
    ECON.step(colonization, 1.0)
    assert(colonization["ships"].size() == 1)
    assert(int(c1["dest"]) == -1)
    ECON.step(colonization, 2.0)
    assert(int(c1["at"]) == 0 and c1["route"].is_empty())
    print("PASS: colony construction, permissions, travel, neutral arrival and competing colonies")
    print("PASS: seeded maps, ownership, construction, shipyards, mixed cargo, physical transit, ally sharing")
    quit(0)
