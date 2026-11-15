extends SceneTree
const MAP = preload("res://scripts/planet_map.gd")
const ECON = preload("res://scripts/economy_rules.gd")

func _initialize() -> void:
    var graph: Dictionary = MAP.generate(2468)
    assert(graph == MAP.generate(2468))
    assert(graph != MAP.generate(2469))
    var all_friendly: Array[int] = []
    all_friendly.resize(graph["points"].size())
    all_friendly.fill(1)
    for i in range(graph["points"].size()):
        assert(not MAP.path(graph, all_friendly, 1, 0, i).is_empty())
    # Seeded clusters are internally connected and connected by sparse bridges.
    for seed_value in range(24):
        var player_count: int = seed_value % 8 + 1
        var clustered: Dictionary = MAP.generate(seed_value, player_count)
        var cluster_ids: Array = clustered["clusters"]
        var cluster_points: Array = clustered["points"]
        var local_distance: float = 0.0
        var bridge_distance: float = 0.0
        var locals: int = 0
        var bridges: int = 0
        var longest: float = 0.0
        var degrees: Array[int] = []
        degrees.resize(cluster_points.size())
        degrees.fill(0)
        for edge in clustered["edges"]:
            var length: float = cluster_points[edge[0]].distance_to(cluster_points[edge[1]])
            longest = maxf(longest, length)
            degrees[edge[0]] += 1
            degrees[edge[1]] += 1
            if cluster_ids[edge[0]] == cluster_ids[edge[1]]:
                locals += 1
                local_distance += length
            else:
                bridges += 1
                bridge_distance += length
        assert(bridges == player_count * 3 - 1)
        assert(clustered["cluster_sizes"].size() == player_count * 3)
        for cluster_size in clustered["cluster_sizes"]:
            assert(cluster_size >= 3 and cluster_size <= 9)
        assert(clustered["edges"].size() >= cluster_points.size() - 1)
        assert(clustered["edges"].size() <= cluster_points.size())
        assert(degrees.count(3) <= int(clustered["max_junctions"]))
        assert(degrees.count(1) >= 2)
        for degree in degrees:
            assert(degree >= 1 and degree <= MAP.MAX_CONNECTIONS)
        for home in range(player_count):
            assert(clustered["cluster_sizes"][cluster_ids[home]] == 6)
            var neutral_neighbor: bool = false
            for i in range(player_count, cluster_points.size()):
                if MAP.linked(clustered, home, i):
                    neutral_neighbor = true
                    break
            assert(neutral_neighbor)
        assert(is_equal_approx(longest / ECON.SHIP_SPEED, MAP.LONGEST_LINK_YEARS))
        assert(not (clustered["fields"] as Array).is_empty())
        for edge in clustered["edges"]:
            assert(not MAP.blocked(cluster_points[edge[0]], cluster_points[edge[1]], clustered["fields"]))
        for field in clustered["fields"]:
            var ore: Dictionary = ECON.field_inventory(field)
            for resource in ECON.MINED_RESOURCES:
                assert(ECON.field_limit(field, resource) > ECON.PLANET_MINING_LIMIT if float(ore[resource]) > 0.0 else is_zero_approx(ECON.field_limit(field, resource)))
            assert(ECON.field_limit(field, "Organics") == 0.0)
            assert(field["outline"].size() == 12)
            assert(field["chunks"].size() >= 9)
            var chunk_ids: Dictionary = {}
            for chunk in field["chunks"]:
                assert(not chunk_ids.has(chunk["id"]))
                chunk_ids[chunk["id"]] = true
                assert(ECON.MINED_RESOURCES.has(chunk["resource"]))
                assert(float(chunk["remaining"]) > 0.0)
                assert((field["position"] as Vector2).distance_to(chunk["position"]) + float(chunk["radius"]) < float(field["radius"]))
        assert(bridge_distance / bridges > local_distance / locals)
        var seen: Dictionary = {0: true}
        var frontier: Array = [0]
        while not frontier.is_empty():
            var current: int = frontier.pop_back()
            for edge in clustered["edges"]:
                var next: int = -1
                if edge[0] == current:
                    next = edge[1]
                elif edge[1] == current:
                    next = edge[0]
                if next >= 0 and not seen.has(next):
                    seen[next] = true
                    frontier.append(next)
        assert(seen.size() == cluster_points.size())
        for i in range(player_count):
            assert(cluster_ids[i] == i)
    var players: Dictionary = {1: {"team": 1}, 2: {"team": 1}, 3: {"team": 2}}
    var ids: Array[int] = [1, 2, 3]
    var state: Dictionary = ECON.create(graph, players, ids)
    assert(not state["fog_of_war"])
    for i in range((state["planets"] as Array).size()):
        assert(ECON.discovered(state, 1, "planets", i))
        assert(ECON.discovered(state, 3, "planets", i))
    state["fog_of_war"] = true
    assert(ECON.discovered(state, 1, "planets", 0))
    assert(ECON.discovered(state, 2, "planets", 0))
    assert(not ECON.discovered(state, 3, "planets", 0) or MAP.linked(graph, 0, 2))
    state["fog_of_war"] = false
    var p: Dictionary = state["planets"][0]
    assert(p["yards"].size() == 1)
    assert(p["levels"].size() == 6)
    assert(p["stock"].size() == 6)
    assert(not p["abundance"].has("Tech"))
    assert(not p["bonuses"].has("Tech"))
    assert(not ECON.enqueue(state, 2, 0, "ship"))
    assert(not ECON.set_thresholds(state, 1, 0, "Metals", 200, 100))
    assert(not ECON.set_thresholds(state, 1, 0, "Metals", 0, 101))
    assert(not ECON.set_thresholds(state, 1, 0, "Metals", 80, 20))
    assert(ECON.set_thresholds(state, 1, 0, "Metals", 10, 20))
    var trade_test: Dictionary = state["planets"][0]
    var previous_stock: float = float(trade_test["stock"]["Metals"])
    trade_test["stock"]["Metals"] = 175.0
    assert(is_equal_approx(ECON._need(trade_test, "Metals"), 25.0))
    assert(is_zero_approx(ECON._surplus(trade_test, "Metals")))
    trade_test["stock"]["Metals"] = 300.0
    assert(is_zero_approx(ECON._need(trade_test, "Metals")))
    assert(is_zero_approx(ECON._surplus(trade_test, "Metals")))
    trade_test["stock"]["Metals"] = 450.0
    assert(is_equal_approx(ECON._surplus(trade_test, "Metals"), 50.0))
    trade_test["stock"]["Metals"] = 2250.0
    assert(ECON.set_thresholds(state, 1, 0, "Metals", 0, 100))
    assert(is_equal_approx(ECON._surplus(trade_test, "Metals"), 250.0))
    trade_test["stock"]["Metals"] = previous_stock
    assert(ECON.set_thresholds(state, 1, 0, "Metals", 0, 10))
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
    assert(is_equal_approx(float(totals["stock"]["Metals"]), float(ECON.STARTING_STOCK["Metals"]) + 25.0))
    assert(is_equal_approx(float(totals["cargo"]["Metals"]), 7.0))
    assert(is_equal_approx(float(totals["resources"]["Metals"]), float(ECON.STARTING_STOCK["Metals"]) + 32.0))
    assert(ECON.empire_totals({}, 1)["craft"] == 0)

    # Rolling window measures net holdings, not internal cargo transfers.
    var history: Dictionary = {}
    var rolling: Dictionary = ECON.create(graph, players, ids)
    ECON.sample_resource_rates(rolling, history)
    for i in range(1, 8):
        rolling["elapsed"] = float(i)
        rolling["planets"][0]["stock"]["Metals"] += 10.0 if i <= 5 else -5.0
        ECON.sample_resource_rates(rolling, history)
        if i == 2:
            assert(is_equal_approx(float(rolling["resource_rates"][1]["Metals"]), 10.0))
    assert(is_equal_approx(float(rolling["resource_rates"][1]["Metals"]), 4.0))
    assert(is_zero_approx(float(rolling["resource_rates"][2]["Metals"])))
    var transfer: Dictionary = ECON.empty_stock()
    transfer["Metals"] = 25.0
    rolling["planets"][0]["stock"]["Metals"] -= 25.0
    rolling["ships"].append({"owner": 1, "kind": "ship", "cargo": transfer})
    ECON.sample_resource_rates(rolling, history)
    assert(is_equal_approx(float(rolling["resource_rates"][1]["Metals"]), 4.0))
    rolling["elapsed"] = 7.5
    rolling["planets"][0]["stock"]["Metals"] -= 50.0
    ECON.sample_resource_rates(rolling, history)
    assert(is_equal_approx(float(rolling["resource_rates"][1]["Metals"]), -7.0))
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
    assert(is_equal_approx(baseline, 4.0))
    assert(is_equal_approx(ECON.farm_potential(home), 4.0))
    assert(is_equal_approx(ECON.organics_demand(home), 0.4))
    assert(is_equal_approx(ECON.MINER_RATE, 6.0))
    assert(is_equal_approx(ECON.PLANET_MINING_LIMIT, 100.0))
    assert(is_equal_approx(ECON.FIELD_MINING_LIMIT, 200.0))
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
    home["stock"]["Metals"] = 1000.0
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

    # Visual planet count loosely follows system richness, without modifying state.
    var poor: Dictionary = {"abundance": {"Metals": 0.0, "Plastics": 0.0, "Crystals": 0.0}, "bonuses": {"Organics": 1.0}}
    var rich: Dictionary = {"abundance": {"Metals": 2.0, "Plastics": 2.0, "Crystals": 2.0}, "bonuses": {"Organics": 1.8}}
    var poor_bodies: Array = ECON.system_bodies(poor, 123, 0)
    var rich_bodies: Array = ECON.system_bodies(rich, 123, 0)
    assert(rich_bodies.size() > poor_bodies.size())
    assert(poor_bodies == ECON.system_bodies(poor, 123, 0))
    assert(rich_bodies == ECON.system_bodies(rich, 123, 0))
    for body in poor_bodies:
        assert(body["resource"] == "")
    for body in rich_bodies:
        assert(float(body["orbit"]) + float(body["size"]) < 1.0)
    # Construction is proportional, time-dependent and fully refundable.
    var saved_population: float = float(p["population"])
    p["population"] = 0.0
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
    p["population"] = saved_population

    # Upgrade costs increase quadratically; all order types refund actual allocations.
    for kind in ["production", "yard_upgrade"]:
        assert(float(ECON._cost(kind, 2)["Metals"]) >= 600.0)
        assert(float(ECON._cost(kind, 3)["Metals"]) > float(ECON._cost(kind, 2)["Metals"]))
        assert(float(ECON._cost(kind, 4)["Metals"]) > float(ECON._cost(kind, 3)["Metals"]))
    var refunds: Dictionary = ECON.create(graph, players, ids)
    var refund_home: Dictionary = refunds["planets"][0]
    refund_home["levels"]["Metals"] = 0
    refund_home["warehouse_level"] = 3
    for kind in ["ship", "colony_ship", "fighter", "miner", "yard", "yard_upgrade", "production"]:
        refund_home["stock"]["Metals"] = 10000.0
        var target: String = "0" if kind == "yard_upgrade" else ("Organics" if kind == "production" else "")
        assert(ECON.enqueue(refunds, 1, 0, kind, target))
        ECON.step(refunds, 1.0)
        var order: Dictionary = refund_home["queue"][0]
        assert(float(order["allocated"]["Metals"]) > 0.0)
        assert(not ECON.cancel(refunds, 2, 0, int(order["id"])))
        assert(ECON.cancel(refunds, 1, 0, int(order["id"])))
        assert(refund_home["queue"].is_empty())
        assert(is_equal_approx(float(refund_home["stock"]["Metals"]), 10000.0 - ECON.consumption(refund_home, "Metals")))
        assert(int(refund_home["yards"][0]["job"]) == -1)
    # Completed and pending shipyards share a hard three-slot limit.
    var capped: Dictionary = ECON.create(graph, players, ids)
    var cap_home: Dictionary = capped["planets"][0]
    cap_home["warehouse_level"] = 3
    cap_home["stock"]["Metals"] = 5000.0
    assert(ECON.shipyard_count(cap_home) == 1)
    assert(not ECON.enqueue(capped, 2, 0, "yard"))
    assert(ECON.enqueue(capped, 1, 0, "yard"))
    assert(ECON.enqueue(capped, 1, 0, "yard"))
    assert(ECON.shipyard_count(cap_home) == 3)
    assert(not ECON.enqueue(capped, 1, 0, "yard"))
    assert(ECON.cancel(capped, 1, 0, int(cap_home["queue"][-1]["id"])))
    assert(ECON.shipyard_count(cap_home) == 2)
    assert(ECON.enqueue(capped, 1, 0, "yard"))
    ECON.step(capped, 30.0)
    assert(cap_home["yards"].size() == 3)
    assert(ECON.shipyard_count(cap_home) == 3)
    assert(not ECON.enqueue(capped, 1, 0, "yard"))
    assert(ECON.enqueue(capped, 1, 0, "yard_upgrade", "0"))

    # Yard upgrades wait behind assigned hull production.
    p["warehouse_level"] = 3
    p["stock"]["Metals"] = 5000.0
    p["yards"].append({"level": 1, "job": -1})
    assert(ECON.enqueue(state, 1, 0, "ship"))
    assert(ECON.enqueue(state, 1, 0, "ship"))
    ECON.step(state, 1.0)
    assert(int(p["yards"][0]["job"]) != int(p["yards"][1]["job"]))
    var first_job: int = int(p["yards"][0]["job"])
    assert(ECON.enqueue(state, 1, 0, "yard_upgrade", "0"))
    assert(int(p["yards"][0]["job"]) == first_job)
    ECON.step(state, 1.0)
    assert(is_equal_approx(float(p["queue"][0]["progress"]), 12.0))
    assert(is_zero_approx(float(p["queue"][2]["progress"])))
    for i in range(6):
        ECON.step(state, 1.0)
    assert(state["ships"].size() == 2)
    assert(p["queue"].size() == 1)
    ECON.step(state, 1.0)
    assert(int(p["yards"][0]["job"]) == int(p["queue"][0]["id"]))
    assert(is_equal_approx(float(p["queue"][0]["progress"]), 1.0))
    for i in range(29):
        ECON.step(state, 1.0)
    assert(int(p["yards"][0]["level"]) == 2)
    assert(ECON.max_size(2) > ECON.max_size(1))

    # Unlimited build orders; repeat stops when one matching order is canceled.
    var repeat_state: Dictionary = ECON.create(graph, players, ids)
    var repeat_home: Dictionary = repeat_state["planets"][0]
    repeat_home["warehouse_level"] = 3
    repeat_home["stock"]["Metals"] = 5000.0
    assert(not ECON.set_continuous(repeat_state, 2, 0, "fighter", true))
    assert(not ECON.set_continuous(repeat_state, 1, 0, "yard", true))
    assert(ECON.set_continuous(repeat_state, 1, 0, "fighter", true))
    for i in range(12):
        assert(ECON.enqueue(repeat_state, 1, 0, "ship"))
    ECON.step(repeat_state, 1.0)
    assert(repeat_home["queue"].size() == 13)
    var repeat_id: int = int(repeat_home["queue"][-1]["id"])
    assert(ECON.cancel(repeat_state, 1, 0, repeat_id))
    assert(not repeat_home["continuous"]["fighter"])
    ECON.step(repeat_state, 1.0)
    assert(not ECON._has_job(repeat_home, "fighter", ""))

    var names: Array = graph["names"]
    assert(names.size() == graph["points"].size())
    var unique: Dictionary = {}
    for system_name in names:
        assert(not unique.has(system_name))
        unique[system_name] = true
    assert(names == MAP.system_names(int(graph["seed"]), names.size()))

    # Repeating hulls cycle in order, including under material starvation.
    var rotation: Dictionary = ECON.create(graph, players, ids)
    var rotation_home: Dictionary = rotation["planets"][0]
    rotation_home["levels"]["Metals"] = 0
    rotation_home["stock"]["Metals"] = 0.0
    for kind in ["colony_ship", "fighter", "miner"]:
        assert(ECON.set_continuous(rotation, 1, 0, kind, true))
    ECON.step(rotation, 1.0)
    assert(rotation_home["queue"].size() == 3)
    for job in rotation_home["queue"]:
        assert(job["automatic"])
    assert(rotation_home["queue"][0]["kind"] == "colony_ship")
    # Partial funding must go to the first turn, not a cheaper fighter.
    for i in range(12):
        rotation_home["stock"]["Metals"] += 10.0
        ECON.step(rotation, 1.0)
    assert(rotation["ships"].is_empty())
    assert(float(rotation_home["queue"][0]["progress"]) > 0.0)
    assert(is_zero_approx(float(rotation_home["queue"][1]["progress"])))
    rotation_home["warehouse_level"] = 3
    rotation_home["stock"]["Metals"] = 10000.0
    for i in range(100):
        ECON.step(rotation, 1.0)
        if rotation["ships"].size() >= 9:
            break
    assert(rotation["ships"].size() == 9)
    for i in range(9):
        assert(rotation["ships"][i]["kind"] == ["colony_ship", "fighter", "miner"][i % 3])
    # Canceling an automatic order turns off that type, without stopping the rest.
    ECON._refill_continuous(rotation, 0, rotation_home)
    for job in (rotation_home["queue"] as Array).duplicate():
        if job["kind"] == "fighter":
            assert(ECON.cancel(rotation, 1, 0, int(job["id"])))
    assert(not rotation_home["continuous"]["fighter"])
    for i in range(50):
        ECON.step(rotation, 1.0)
    for i in range(9, rotation["ships"].size()):
        assert(rotation["ships"][i]["kind"] != "fighter")
    # Two shipyards can start consecutive turns in parallel.
    var parallel_repeat: Dictionary = ECON.create(graph, players, ids)
    var parallel_home: Dictionary = parallel_repeat["planets"][0]
    parallel_home["warehouse_level"] = 3
    parallel_home["stock"]["Metals"] = 10000.0
    parallel_home["yards"].append({"level": 1, "job": -1})
    for kind in ["fighter", "miner"]:
        assert(ECON.set_continuous(parallel_repeat, 1, 0, kind, true))
    ECON.step(parallel_repeat, 1.0)
    assert(parallel_home["yards"][0]["job"] != parallel_home["yards"][1]["job"])
    assert(float(parallel_home["queue"][0]["progress"]) > 0.0)
    assert(float(parallel_home["queue"][1]["progress"]) > 0.0)
    # Different shipyard speeds and build durations must not give the faster
    # hull type extra starts. Observe assigned jobs, not completion order.
    parallel_home["yards"][0]["level"] = 3
    var started_ids: Dictionary = {}
    var starts: Array[String] = []
    for tick in range(60):
        for yard in parallel_home["yards"]:
            var id: int = int(yard["job"])
            if id < 0 or started_ids.has(id):
                continue
            for job in parallel_home["queue"]:
                if int(job["id"]) == id:
                    started_ids[id] = true
                    starts.append(str(job["kind"]))
                    break
        ECON.step(parallel_repeat, 0.1)
    assert(starts.size() >= 4)
    for i in range(starts.size()):
        assert(starts[i] == ["fighter", "miner"][i % 2])

    # Automatic system and shipyard upgrades use the shared scheduler.
    var upgrades: Dictionary = ECON.create(graph, players, ids)
    var upgrade_home: Dictionary = upgrades["planets"][0]
    upgrade_home["warehouse_level"] = 3
    upgrade_home["stock"]["Metals"] = 20000.0
    assert(not ECON.set_continuous(upgrades, 2, 0, "production:Organics", true))
    assert(not ECON.set_continuous(upgrades, 1, 0, "production:Tech", true))
    assert(not ECON.set_continuous(upgrades, 1, 0, "yard_upgrade:8", true))
    assert(ECON.set_continuous(upgrades, 1, 0, "production:Organics", true))
    assert(ECON.set_continuous(upgrades, 1, 0, "yard_upgrade:0", true))
    ECON.step(upgrades, 1.0)
    assert(ECON._has_job(upgrade_home, "production", "Organics"))
    assert(ECON._has_job(upgrade_home, "yard_upgrade", "0"))
    for i in range(32):
        ECON.step(upgrades, 1.0)
    assert(int(upgrade_home["levels"]["Organics"]) == 2)
    assert(int(upgrade_home["yards"][0]["level"]) == 2)
    assert(ECON._has_job(upgrade_home, "production", "Organics"))
    assert(ECON._has_job(upgrade_home, "yard_upgrade", "0"))
    assert(ECON.set_continuous(upgrades, 1, 0, "production:Organics", false))
    assert(ECON.set_continuous(upgrades, 1, 0, "yard_upgrade:0", false))
    for i in range(50):
        ECON.step(upgrades, 1.0)
    assert(upgrade_home["queue"].is_empty())
    assert(int(upgrade_home["levels"]["Organics"]) == 3)
    assert(int(upgrade_home["yards"][0]["level"]) == 3)
    for key in ["production:Organics", "yard_upgrade:0"]:
        assert(ECON.set_continuous(upgrades, 1, 0, key, true))
    ECON.step(upgrades, 1.0)
    for job in (upgrade_home["queue"] as Array).duplicate():
        assert(ECON.cancel(upgrades, 1, 0, int(job["id"])))
    assert(not upgrade_home["continuous"]["production:Organics"])
    assert(not upgrade_home["continuous"]["yard_upgrade:0"])
    ECON.step(upgrades, 1.0)
    assert(upgrade_home["queue"].is_empty())
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
    var metal_pos: Vector2 = (mineral_points[0] as Vector2) + Vector2(95, 0)
    var crystal_pos: Vector2 = (mineral_points[0] as Vector2) + Vector2(95, 30)
    mineral_map["fields"] = [{"position": metal_pos, "radius": 40.0, "anchor": 0, "Metals": 1.0, "Crystals": 1.0,
        "chunks": [{"id": 7, "position": metal_pos, "resource": "Metals", "remaining": 24.0},
            {"id": 9, "position": crystal_pos, "resource": "Crystals", "remaining": 36.0}]}]
    var mineral: Dictionary = ECON.create(mineral_map, players, ids)
    assert(ECON.discovered(mineral, 3, "fields", 0))
    assert(ECON.set_mining_policy(mineral, 3, 0, false, false, false))
    mineral["fog_of_war"] = true
    assert(ECON.discovered(mineral, 1, "fields", 0))
    assert(not ECON.discovered(mineral, 3, "fields", 0))
    assert(not ECON.set_mining_policy(mineral, 3, 0, false, false, false))
    mineral["fog_of_war"] = false
    assert(ECON.set_mining_policy(mineral, 1, 0, true, true, false))
    assert(ECON.mining_policy(mineral, 2, 0)["Crystals"])
    var mine_home: Dictionary = mineral["planets"][0]
    mine_home["levels"]["Metals"] = 1000
    assert(is_equal_approx(ECON.rate(mine_home, "Metals"), ECON.PLANET_MINING_LIMIT))
    mine_home["levels"]["Metals"] = 0
    mine_home["levels"]["Crystals"] = 0
    mine_home["population"] = 0.0
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
    assert(is_equal_approx(after_build, float(ECON.STARTING_STOCK["Metals"]) - float(ECON._cost("miner", 1)["Metals"])))
    ECON.step(mineral, 0.1)
    assert(miner["mining_target"] == metal_pos)
    assert(int(miner["chunk"]) == 7)
    for i in range(20):
        if miner["mining_mode"] == "mining":
            break
        ECON.step(mineral, 1.0)
    assert(miner["mining_mode"] == "mining")
    for i in range(4):
        ECON.step(mineral, 1.0)
        assert(miner["mining_mode"] == "mining")
    assert(ECON._find_chunk(mineral["map"]["fields"][0], 7).is_empty())
    ECON.step(mineral, 1.0)
    assert(miner["mining_mode"] == "return")
    for i in range(20):
        ECON.step(mineral, 1.0)
    assert(is_equal_approx(float(mine_home["stock"]["Metals"]), after_build + 24.0))
    assert(ECON._find_chunk(mineral["map"]["fields"][0], 7).is_empty())
    assert(is_zero_approx(float(ECON.field_inventory(mineral["map"]["fields"][0])["Metals"])))
    assert(is_zero_approx(float(mine_home["stock"]["Crystals"])))
    assert(is_zero_approx(float(miner["cargo"]["Crystals"])))
    assert(ECON.set_mining_policy(mineral, 1, 0, true, false, true))
    for i in range(20):
        ECON.step(mineral, 1.0)
    assert(is_equal_approx(float(mine_home["stock"]["Crystals"]), 36.0))
    assert((mineral["map"]["fields"][0]["chunks"] as Array).is_empty())
    assert(is_zero_approx(float(ECON.field_inventory(mineral["map"]["fields"][0])["Crystals"])))
    assert(ECON.set_mining_policy(mineral, 1, 0, false, false, true))
    for i in range(10):
        ECON.step(mineral, 1.0)
    assert(miner["mining_mode"] == "idle")
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
        planet["levels"]["Plastics"] = 0
        planet["population"] = 0.0
        for r in ECON.RESOURCES:
            planet["stock"][r] = 0.0
            planet["thresholds"][r] = {"min": 0.0, "max": 0.0}
    source["stock"]["Metals"] = 4.0
    source["stock"]["Plastics"] = 6.0
    ally["thresholds"]["Metals"] = {"min": 10.0, "max": 10.0}
    ally["thresholds"]["Plastics"] = {"min": 10.0, "max": 10.0}
    hostile["thresholds"]["Metals"] = {"min": 10.0, "max": 10.0}
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
    assert(ECON.colony_path(colonization, 1, c1, 4) == [0, 1, 3, 4])
    assert(not ECON.send_colony(colonization, 1, int(c1["id"]), 2))
    assert(ECON.send_colony(colonization, 1, int(c1["id"]), 3))
    assert(ECON.send_colony(colonization, 3, int(c2["id"]), 3))
    assert(int(colonization["planets"][3]["owner"]) == 0)
    var distance1: float = (c1["position"] as Vector2).distance_to(cp[1]) + (cp[1] as Vector2).distance_to(cp[3])
    var distance2: float = (c2["position"] as Vector2).distance_to(cp[3])
    var first_arrival: float = minf(distance1, distance2) / ECON.SHIP_SPEED
    var winner: int = 1 if distance1 < distance2 else 3
    var loser: Dictionary = c2 if winner == 1 else c1
    var loser_home: int = 2 if winner == 1 else 0
    ECON.step(colonization, first_arrival * 0.5)
    assert(int(colonization["planets"][3]["owner"]) == 0)
    ECON.step(colonization, first_arrival * 0.5 + 0.001)
    assert(int(colonization["planets"][3]["owner"]) == winner)
    assert(is_equal_approx(float(colonization["planets"][3]["population"]), ECON.COLONY_POPULATION))
    assert(int(colonization["planets"][3]["levels"]["Organics"]) == 1)
    assert(colonization["ships"].size() == 1)
    for i in range(20):
        if int(loser["at"]) == loser_home and loser["route"].is_empty():
            break
        var before: Vector2 = loser["position"]
        ECON.step(colonization, 0.5)
        assert(before.distance_to(loser["position"]) <= ECON.SHIP_SPEED * 0.5 + 0.01)
    assert(int(loser["dest"]) == -1)
    assert(int(loser["at"]) == loser_home and loser["route"].is_empty())
    var distant: Dictionary = ECON.create(colony_map, players, ids)
    var distant_ship: Dictionary = {"id": 999, "kind": "colony_ship", "owner": 1, "at": 0, "position": cp[0], "route": [], "leg": 0.0, "dest": -1}
    distant["ships"].append(distant_ship)
    assert(ECON.send_colony(distant, 1, 999, 4))
    assert(distant_ship["position"] == cp[0])
    ECON.step(distant, 2.0)
    assert(int(distant["planets"][3]["owner"]) == 0 and int(distant["planets"][4]["owner"]) == 0)
    ECON.step(distant, 1.0)
    assert(int(distant["planets"][3]["owner"]) == 0 and int(distant["planets"][4]["owner"]) == 1)
    print("PASS: colony construction, permissions, travel, neutral arrival and competing colonies")
    # POI allocations reserve nearest fighters, including field destinations.
    var force_map: Dictionary = MAP.generate(1337)
    var force_points: Array = force_map["points"]
    force_points[0] = Vector2(0, 0)
    force_points[3] = Vector2(1000, 0)
    force_points[4] = Vector2(2000, 0)
    force_map["edges"] = [[0, 3], [3, 4]]
    force_map["fields"] = [{"position": Vector2(1000, 100), "anchor": 3}]
    var force_state: Dictionary = ECON.create(force_map, players, ids)
    var field_node: int = force_points.size()
    var force_graph: Dictionary = ECON.military_graph(force_state)
    var force_weights: Dictionary = ECON.military_policy(force_state, 1, "fighter")
    assert(force_weights[0] == 100 and force_weights[field_node] == 0)
    assert(not ECON.set_military(force_state, 1, "ship", 3, 50))
    assert(not ECON.set_military(force_state, 1, "fighter", -1, 50))
    assert(not ECON.set_military(force_state, 1, "fighter", field_node + 1, 50))
    assert(not ECON.set_military(force_state, 1, "fighter", 3, 101))
    assert(ECON.set_military(force_state, 1, "fighter", field_node, 50))
    force_weights = ECON.military_policy(force_state, 1, "fighter")
    assert(force_weights[0] == 50 and force_weights[field_node] == 50)
    assert(ECON.set_military(force_state, 1, "fighter", 4, 20))
    force_weights = ECON.military_policy(force_state, 1, "fighter")
    assert(force_weights[0] == 40 and force_weights[field_node] == 40 and force_weights[4] == 20)
    var force_sum: int = 0
    for amount in force_weights.values():
        force_sum += int(amount)
    assert(force_sum == 100)
    assert(ECON.set_military(force_state, 1, "fighter", 4, 0))
    for i in range(2):
        force_state["ships"].append({"id": i + 1, "kind": "fighter", "owner": 1, "at": 0 if i == 0 else 3, "route": [], "leg": 0.0, "dest": -1, "cargo": ECON.empty_stock()})
    var force_fleet: Array = force_state["ships"]
    ECON._allocate_fighters(force_state, force_graph, 1, force_fleet)
    assert(force_fleet[0]["dest"] == 0)
    assert(force_fleet[1]["dest"] == field_node)
    assert(force_fleet[1]["route"] == [field_node])
    ECON._move({"map": force_graph}, force_fleet[1], 0.5)
    assert(is_equal_approx(float(force_fleet[1]["leg"]), 47.5))
    var reversal_position: Vector2 = force_fleet[1]["position"]
    assert(ECON.set_military(force_state, 1, "fighter", 0, 100))
    ECON._allocate_fighters(force_state, force_graph, 1, force_fleet)
    assert(force_fleet[1]["at"] == field_node)
    assert(force_fleet[1]["route"] == [3, 0])
    assert(is_equal_approx(float(force_fleet[1]["leg"]), 52.5))
    assert(force_fleet[1]["position"] == reversal_position)
    ECON._move({"map": force_graph}, force_fleet[1], 0.1)
    assert(is_equal_approx(reversal_position.distance_to(force_fleet[1]["position"]), ECON.SHIP_SPEED * 0.1))
    ECON._move({"map": force_graph}, force_fleet[1], 100.0)
    assert(force_fleet[1]["at"] == 0 and force_fleet[1]["route"].is_empty())
    assert(ECON.set_military(force_state, 1, "fighter", field_node, 100))
    ECON._allocate_fighters(force_state, force_graph, 1, force_fleet)
    ECON._move({"map": force_graph}, force_fleet[0], 100.0)
    assert(force_fleet[0]["at"] == field_node and force_fleet[0]["route"].is_empty())
    print("PASS: normalized POI force allocation, nearest assignments and continuous reversal")
    # Simultaneous weapon fire: allies cannot be targeted and six hits kill.
    var duel: Dictionary = ECON.create(force_map, players, ids)
    var duel_graph: Dictionary = ECON.military_graph(duel)
    for owner_id in [1, 3]:
        duel["ships"].append({"id": owner_id, "owner": owner_id, "kind": "fighter", "at": 0, "route": [], "leg": 0.0, "hp": 100.0, "dest": 0})
    for shot in range(5):
        ECON._combat(duel, duel_graph, 1.0)
    assert(duel["ships"].size() == 2)
    assert(is_equal_approx(float(duel["ships"][0]["hp"]), 10.0))
    ECON._combat(duel, duel_graph, 1.0)
    assert(duel["ships"].is_empty())
    duel["ships"] = [{"id": 1, "owner": 1, "kind": "fighter", "at": 0, "route": [], "leg": 0.0, "hp": 100.0}, {"id": 2, "owner": 2, "kind": "fighter", "at": 0, "route": [], "leg": 0.0, "hp": 100.0}]
    ECON._combat(duel, duel_graph, 1.0)
    assert(float(duel["ships"][0]["hp"]) == 100.0 and int(duel["ships"][0]["combat_target"]) == -1)

    # Combat depends on actual position, not route, POI or activity metadata.
    duel["ships"] = [{"id": 11, "owner": 1, "kind": "fighter", "at": 0, "route": [3], "leg": 0.0, "position": Vector2(500, 0), "hp": 100.0}, {"id": 12, "owner": 3, "kind": "ship", "at": 3, "route": [0], "leg": 0.0, "position": Vector2(550, 0), "hp": 100.0}, {"id": 13, "owner": 3, "kind": "fighter", "at": 0, "route": [], "leg": 0.0, "position": Vector2(5000, 0), "hp": 100.0}]
    ECON._combat(duel, duel_graph, 1.0)
    assert(int(duel["ships"][0]["combat_target"]) == 12)
    assert(is_equal_approx(float(duel["ships"][1]["hp"]), 100.0 - ECON.LASER_DAMAGE))
    assert(is_equal_approx(float(duel["ships"][2]["hp"]), 100.0))
    for tick in range(20):
        var before: Vector2 = miner["position"]
        ECON.step(mineral, 0.1)
        assert(before.distance_to(miner["position"]) <= ECON.SHIP_SPEED * 0.1 + 0.01)

    var ai_map: Dictionary = {"seed": 123, "points": [Vector2(-950, 0), Vector2.ZERO, Vector2(3800, 0), Vector2(950, 0), Vector2(1900, 0)], "edges": [[0, 1], [1, 3], [3, 4], [4, 2]], "fields": []}
    var ai_roster: Dictionary = {1: {"team": 1}, 2: {"team": 1, "ai": true}, 3: {"team": 2}}
    # Attack orders wait for a physical rally, then commit only that cohort.
    var wave_state: Dictionary = ECON.create(ai_map, ai_roster, ids)
    var wave_graph: Dictionary = ECON.military_graph(wave_state)
    var wave_fleet: Array = []
    for i in range(2):
        wave_fleet.append({"id": 100 + i, "owner": 2, "kind": "fighter", "at": 1, "route": [], "leg": 0.0, "position": ai_map["points"][1], "dest": -1})
    ECON._ai_wave_order(wave_state, wave_graph, 2, 1, 2, wave_fleet)
    assert(wave_state["ai_waves"][2]["members"].is_empty())
    assert(wave_fleet[0]["dest"] == 1 and wave_fleet[1]["dest"] == 1)
    wave_fleet.append({"id": 102, "owner": 2, "kind": "fighter", "at": 3, "route": [], "leg": 0.0, "position": ai_map["points"][3], "dest": -1})
    ECON._ai_wave_order(wave_state, wave_graph, 2, 1, 2, wave_fleet)
    assert(wave_state["ai_waves"][2]["members"].is_empty())
    ECON._move({"map": wave_graph}, wave_fleet[2], 10.0)
    ECON._ai_wave_order(wave_state, wave_graph, 2, 1, 2, wave_fleet)
    assert(wave_state["ai_waves"][2]["members"].size() == 3)
    for craft in wave_fleet:
        assert(craft["dest"] == 2 and not craft["route"].is_empty())
    wave_fleet.append({"id": 103, "owner": 2, "kind": "fighter", "at": 1, "route": [], "leg": 0.0, "position": ai_map["points"][1], "dest": -1})
    ECON._ai_wave_order(wave_state, wave_graph, 2, 1, 2, wave_fleet)
    assert(wave_fleet[3]["dest"] == 1 and wave_state["ai_waves"][2]["members"].size() == 3)
    for i in range(3):
        ECON._move({"map": wave_graph}, wave_fleet[i], 100.0)
    ECON._ai_wave_order(wave_state, wave_graph, 2, 1, 2, wave_fleet)
    assert(wave_state["ai_waves"][2]["members"].is_empty())
    for craft in wave_fleet:
        assert(craft["dest"] == 1)
    var ai_state: Dictionary = ECON.create(ai_map, ai_roster, ids)
    var saw_attack: bool = false
    var saw_logistics: bool = false
    for year in range(500):
        ECON.step(ai_state, 1.0)
        for craft in ai_state["ships"]:
            if int(craft["owner"]) != 2:
                continue
            if craft["kind"] == "fighter" and int(craft["dest"]) == 2:
                saw_attack = true
            elif craft["kind"] == "ship":
                saw_logistics = true
    assert(int(ai_state["planets"][3]["owner"]) == 2)
    assert(int(ai_state["planets"][4]["owner"]) == 2)
    assert(ai_state["planets"][0]["queue"].is_empty())
    assert(saw_attack and saw_logistics)
    # Generated maps, not only a toy graph: each AI builds real ships early.
    for seed_value in [11, 83, 470, 1337]:
        var startup_map: Dictionary = MAP.generate(seed_value, 3)
        var startup_state: Dictionary = ECON.create(startup_map, {1: {"team": 1}, 2: {"team": 1, "ai": true}, 3: {"team": 1, "ai": true}}, ids)
        var built: Dictionary = {2: {}, 3: {}}
        for year in range(36):
            ECON.step(startup_state, 1.0)
            for craft in startup_state["ships"]:
                if built.has(int(craft["owner"])):
                    built[int(craft["owner"])][craft["kind"]] = true
        for player in [2, 3]:
            assert(built[player].has("colony_ship"))
            assert(built[player].has("fighter"))
    print("PASS: six-hit combat, allied safety, AI expansion, logistics and attack")
    # Territory: owners and stationed fighters claim; contest removes tint.
    var territory: Dictionary = ECON.create(force_map, players, ids)
    var sectors: Array[int] = ECON.territory_claims(territory)
    assert(sectors[0] == 1 and sectors[1] == 1 and sectors[2] == 2 and sectors[3] == 0)
    territory["ships"].append({"id": 100, "owner": 1, "kind": "fighter", "at": 3, "route": [], "leg": 0.0})
    territory["ships"].append({"id": 101, "owner": 2, "kind": "fighter", "at": field_node, "route": [], "leg": 0.0})
    sectors = ECON.territory_claims(territory)
    assert(sectors[3] == 1 and sectors[field_node] == 1)
    territory["ships"].append({"id": 102, "owner": 3, "kind": "fighter", "at": 3, "route": [], "leg": 0.0})
    territory["ships"].append({"id": 103, "owner": 3, "kind": "fighter", "at": 0, "route": [], "leg": 0.0})
    sectors = ECON.territory_claims(territory)
    assert(sectors[3] == 0 and sectors[0] == 0 and sectors[field_node] == 1)
    territory["ships"].pop_back()
    territory["ships"].pop_back()
    assert(ECON.territory_claims(territory)[0] == 1)
    territory["ships"][0]["route"] = [4]
    assert(ECON.territory_claims(territory)[3] == 0)
    print("PASS: neutral, allied and contested territory including asteroid fields")
    print("PASS: seeded maps, ownership, construction, shipyards, mixed cargo, physical transit, ally sharing")
    # Shared operations retain identity across reinforcement and casualties,
    # distinguish owners, and remove empty groups without recycling IDs.
    var operation_state: Dictionary = ECON.create(graph, players, ids)
    var operation_fleet: Array = [
        {"id": 901, "owner": 1, "kind": "fighter", "at": 0, "dest": 2, "route": [2]},
        {"id": 902, "owner": 1, "kind": "fighter", "at": 0, "dest": 2, "route": [2]},
        {"id": 903, "owner": 2, "kind": "fighter", "at": 1, "dest": 2, "route": []}
    ]
    operation_state["ships"] = operation_fleet
    ECON._sync_operations(operation_state)
    var operation_key: String = "1:allocation:2"
    var operation_id: int = int(operation_state["operations"][operation_key]["id"])
    assert(operation_state["operations"].size() == 2)
    assert(operation_state["operations"][operation_key]["members"] == [901, 902])
    assert(operation_state["operations"][operation_key]["moving"])
    operation_fleet.remove_at(0)
    ECON._sync_operations(operation_state)
    assert(operation_state["operations"][operation_key]["id"] == operation_id)
    assert(operation_state["operations"][operation_key]["members"] == [902])
    assert(operation_fleet[0]["operation_id"] == operation_id)
    operation_fleet[0]["dest"] = 0
    ECON._sync_operations(operation_state)
    assert(not operation_state["operations"].has(operation_key))
    assert(operation_fleet[0]["operation_id"] == operation_id)
    var replicated: Dictionary = bytes_to_var(var_to_bytes(operation_state))
    assert(replicated["operations"] == operation_state["operations"])
    # Human hostile orders assemble physically; objective membership is
    # independent of the current rally route. Neutral orders remain immediate.
    var rally_state: Dictionary = ECON.create(ai_map, players, ids)
    var rally_graph: Dictionary = ECON.military_graph(rally_state)
    var rally_fleet: Array = rally_state["ships"]
    for i in range(2):
        rally_fleet.append({"id": 950 + i, "owner": 2, "kind": "fighter", "at": 1, "route": [], "leg": 0.0, "position": ai_map["points"][1], "dest": -1})
    assert(ECON.set_military(rally_state, 2, "fighter", 2, 100))
    ECON._allocate_fighters(rally_state, rally_graph, 2, rally_fleet, true)
    ECON._sync_operations(rally_state)
    ECON._dispatch_operations(rally_state, rally_graph)
    var rally_key: String = "2:allocation:2"
    assert(rally_state["operations"][rally_key]["phase"] == "rallying")
    assert(rally_fleet[0]["dest"] == 1 and rally_fleet[1]["dest"] == 1)
    rally_fleet.append({"id": 952, "owner": 2, "kind": "fighter", "at": 3, "route": [], "leg": 0.0, "position": ai_map["points"][3], "dest": -1})
    ECON._allocate_fighters(rally_state, rally_graph, 2, rally_fleet, true)
    ECON._sync_operations(rally_state)
    ECON._dispatch_operations(rally_state, rally_graph)
    assert(rally_state["operations"][rally_key]["deployed"].is_empty())
    ECON._move({"map": rally_graph}, rally_fleet[2], 10.0)
    ECON._dispatch_operations(rally_state, rally_graph)
    assert(rally_state["operations"][rally_key]["deployed"].size() == 3)
    for craft in rally_fleet:
        assert(craft["dest"] == 2 and not craft["route"].is_empty())
    rally_fleet.append({"id": 953, "owner": 2, "kind": "fighter", "at": 1, "route": [], "leg": 0.0, "position": ai_map["points"][1], "dest": -1})
    ECON._allocate_fighters(rally_state, rally_graph, 2, rally_fleet, true)
    ECON._sync_operations(rally_state)
    ECON._dispatch_operations(rally_state, rally_graph)
    assert(rally_fleet[3]["dest"] == 1)
    assert(rally_state["operations"][rally_key]["deployed"].size() == 3)
    var rally_id: int = int(rally_state["operations"][rally_key]["id"])
    assert(ECON.set_military(rally_state, 2, "fighter", 3, 100))
    ECON._allocate_fighters(rally_state, rally_graph, 2, rally_fleet, true)
    ECON._sync_operations(rally_state)
    ECON._dispatch_operations(rally_state, rally_graph)
    assert(rally_state["operations"]["2:allocation:3"]["id"] == rally_id)
    for craft in rally_fleet:
        assert(craft["dest"] == 3)
    # Fighters break off their lane to orbit opponents, then resume their original route.
    var transit: Dictionary = ECON.create(ai_map, players, ids)
    var travelling: Dictionary = {"id": 970, "owner": 2, "kind": "fighter", "at": 1, "route": [3], "leg": 400.0, "position": Vector2(400, 0), "dest": 3, "hp": 100.0}
    var enemy: Dictionary = {"id": 971, "owner": 3, "kind": "fighter", "at": 3, "route": [], "leg": 0.0, "position": Vector2(450, 0), "dest": 3, "hp": 100.0}
    transit["ships"] = [travelling, enemy]
    assert(ECON.set_military(transit, 2, "fighter", 3, 100))
    var original_route: Array = travelling["route"].duplicate()
    for tick in range(8):
        var before: Vector2 = travelling["position"]
        ECON.step(transit, 0.1)
        assert(int(travelling["combat_target"]) == 971)
        assert(before.distance_to(travelling["position"]) <= ECON.SHIP_SPEED * 0.1 + 0.01)
        assert(before.distance_to(travelling["position"]) > 0.01)
        assert(travelling["route"] == original_route and int(travelling["at"]) == 1)
    assert(float(enemy["hp"]) < 100.0)
    assert(absf((travelling["position"] as Vector2).y) > 1.0)
    transit["ships"].erase(enemy)
    var disengaged_position: Vector2 = travelling["position"]
    ECON.step(transit, 0.1)
    assert(int(travelling["combat_target"]) == -1)
    assert(travelling["route"] == original_route)
    assert((travelling["position"] as Vector2).distance_to(ai_map["points"][3]) < disengaged_position.distance_to(ai_map["points"][3]))
    assert(disengaged_position.distance_to(travelling["position"]) <= ECON.SHIP_SPEED * 0.1 + 0.01)
    print("PASS: coordinated human rally, reinforcements, retargeting, combat circling and route resumption")
    # Pursuit retains a fleeing civilian beyond laser range, obeys the speed
    # budget and expires after three years even while the target remains nearby.
    var chase: Dictionary = ECON.create(ai_map, players, ids)
    var hunter: Dictionary = {"id": 980, "owner": 2, "kind": "fighter", "at": 1, "route": [0], "leg": 0.0, "position": Vector2(50, 0), "dest": 0, "hp": 100.0}
    var prey: Dictionary = {"id": 981, "owner": 3, "kind": "colony_ship", "at": 1, "route": [3], "leg": 200.0, "position": Vector2(200, 0), "dest": 3, "hp": 100.0}
    chase["ships"] = [hunter, prey]
    assert(ECON.set_military(chase, 2, "fighter", 0, 100))
    for tick in range(30):
        var before: Vector2 = hunter["position"]
        ECON.step(chase, 0.1)
        assert(int(hunter["pursuit_target"]) == 981)
        assert(hunter["route"] == [0])
        assert(before.distance_to(hunter["position"]) <= ECON.SHIP_SPEED * 0.1 + 0.01)
        assert((hunter["position"] as Vector2).x > before.x)
    assert(float(hunter["pursuit_left"]) <= ECON.EPS)
    var expired_at: Vector2 = hunter["position"]
    ECON.step(chase, 0.1)
    assert(int(hunter["pursuit_target"]) == -1)
    assert((hunter["position"] as Vector2).x < expired_at.x)
    assert(hunter["pursuit_blocked"].has(981))
    ECON.step(chase, 0.1)
    assert(int(hunter["pursuit_target"]) == -1)
    # Separate scenario: a live target leaves range, pursuit persists but
    # laser damage does not. Explicitly reposition the fixture to model escape.
    var distant_chase: Dictionary = ECON.create(ai_map, players, ids)
    var distant_hunter: Dictionary = {"id": 982, "owner": 2, "kind": "fighter", "at": 1, "route": [], "leg": 0.0, "position": Vector2.ZERO, "dest": 1, "hp": 100.0}
    var fleeing: Dictionary = {"id": 983, "owner": 3, "kind": "fighter", "at": 1, "route": [3], "leg": 0.0, "position": Vector2(150, 0), "heading": Vector2.RIGHT, "dest": 3, "hp": 100.0, "retreating": true}
    distant_chase["ships"] = [distant_hunter, fleeing]
    var distant_graph: Dictionary = ECON.military_graph(distant_chase)
    ECON._combat(distant_chase, distant_graph, 0.1)
    assert(int(distant_hunter["pursuit_target"]) == 983)
    fleeing["position"] = Vector2(300, 0)
    var hp_before: float = float(fleeing["hp"])
    ECON._combat(distant_chase, distant_graph, 1.0)
    assert(int(distant_hunter["pursuit_target"]) == 983 and int(distant_hunter["combat_target"]) == -1)
    assert(float(fleeing["hp"]) == hp_before)
    ECON._pursue_fighter(distant_hunter, fleeing["position"], 0.1)
    assert(is_equal_approx((distant_hunter["position"] as Vector2).length(), ECON.SHIP_SPEED * 0.1))
    distant_chase["ships"].erase(fleeing)
    ECON._combat(distant_chase, distant_graph, 0.1)
    assert(int(distant_hunter["pursuit_target"]) == -1)
    print("PASS: bounded pursuit, escaping fighters, weapon range and route resumption")
    # Multi-resource bootstrap: all six resources have local baseline
    # production at home, and the supply funds twelve mixed ships.
    var bootstrap: Dictionary = ECON.create(graph, players, ids)
    var industry: Dictionary = bootstrap["planets"][0]
    for resource in ECON.RESOURCES:
        if resource == "Crystals":
            assert(is_zero_approx(ECON.rate(industry, resource)))
        else:
            assert(ECON.rate(industry, resource) > 0.0)
    var remaining_stock: Dictionary = industry["stock"].duplicate()
    for kind in ["fighter", "fighter", "fighter", "fighter", "fighter", "fighter", "ship", "ship", "ship", "colony_ship", "colony_ship", "miner"]:
        var cost: Dictionary = ECON._cost(kind, 1)
        assert(cost.size() == 5)
        for material in cost:
            remaining_stock[material] -= float(cost[material])
            assert(float(remaining_stock[material]) >= 0.0)
    var tech_rate: float = ECON.rate(industry, "Tech")
    industry["population"] = 20000.0
    assert(is_equal_approx(ECON.rate(industry, "Tech"), tech_rate * 2.0))
    assert(not ECON.enqueue(bootstrap, 1, 0, "production", "Tech"))
    industry["population"] = 199999.0
    assert(not ECON.enqueue(bootstrap, 1, 0, "production", "Tech"))
    industry["population"] = 200000.0
    assert(ECON.enqueue(bootstrap, 1, 0, "production", "Tech"))
    assert(ECON.cancel(bootstrap, 1, 0, int(industry["queue"][0]["id"])))
    industry["population"] = ECON.HOME_POPULATION
    var textile_rate: float = ECON.rate(industry, "Textiles")
    var before_stock: Dictionary = industry["stock"].duplicate()
    assert(not ECON.enqueue(bootstrap, 2, 0, "economy", "Textiles"))
    assert(not ECON.enqueue(bootstrap, 1, 0, "economy", "unknown"))
    assert(not ECON.enqueue(bootstrap, 1, 0, "economy", "Tech"))
    assert(ECON.enqueue(bootstrap, 1, 0, "economy", "Textiles"))
    assert(is_equal_approx(ECON.rate(industry, "Textiles"), textile_rate * 1.25))
    for material in ECON.ECONOMY_BUILDINGS["Textiles"]["cost"]:
        assert(is_equal_approx(float(industry["stock"][material]), float(before_stock[material]) - float(ECON.ECONOMY_BUILDINGS["Textiles"]["cost"][material])))
    var purchased_stock: Dictionary = industry["stock"].duplicate()
    assert(not ECON.enqueue(bootstrap, 1, 0, "economy", "Textiles"))
    assert(industry["stock"] == purchased_stock)
    industry["stock"]["Tech"] = 0.0
    assert(not ECON.enqueue(bootstrap, 1, 0, "economy", "Organics"))
    assert(ECON.enqueue(bootstrap, 1, 0, "fighter"))
    assert(is_zero_approx(ECON._possible(industry, industry["queue"][0])))
    industry["stock"]["Tech"] = 100.0
    var preallocation: Dictionary = industry["stock"].duplicate()
    var build: Dictionary = industry["queue"][0]
    ECON._advance(industry, build, 6.0)
    for material in build["cost"]:
        assert(float(build["allocated"][material]) > 0.0)
    assert(ECON.cancel(bootstrap, 1, 0, int(build["id"])))
    for material in preallocation:
        assert(is_equal_approx(float(industry["stock"][material]), float(preallocation[material])))
    print("PASS: multi-resource hulls, population gates and permanent local improvements")
    var warehouse_state: Dictionary = ECON.create(graph, players, ids)
    var depot: Dictionary = warehouse_state["planets"][0]
    assert(ECON.storage_capacity(depot) == 2000.0)
    assert(ECON.rate(depot, "Crystals") == 0.0 and ECON.consumption(depot, "Crystals") == 0.0)
    for resource in ["Metals", "Plastics", "Textiles", "Organics", "Tech"]:
        var demand: float = ECON.consumption(depot, resource)
        assert(demand > 0.0)
        depot["population"] = ECON.HOME_POPULATION * 2.0
        assert(is_equal_approx(ECON.consumption(depot, resource), demand * 2.0))
        depot["population"] = ECON.HOME_POPULATION
    var limit: float = ECON.storage_capacity(depot)
    depot["stock"]["Metals"] = limit - 0.01
    ECON._work_planet(warehouse_state, 0, 1.0)
    assert(is_equal_approx(float(depot["stock"]["Metals"]), limit))
    assert(is_zero_approx(ECON.net_rate(depot, "Metals")))
    ECON._work_planet(warehouse_state, 0, 1.0)
    assert(is_equal_approx(float(depot["stock"]["Metals"]), limit))
    depot["levels"]["Tech"] = 0
    var tech_before: float = float(depot["stock"]["Tech"])
    ECON._work_planet(warehouse_state, 0, 1.0)
    assert(is_equal_approx(float(depot["stock"]["Tech"]), tech_before - ECON.consumption(depot, "Tech")))
    assert(not ECON.enqueue(warehouse_state, 2, 0, "economy", "warehouse"))
    assert(ECON.enqueue(warehouse_state, 1, 0, "economy", "warehouse"))
    assert(ECON.storage_capacity(depot) == 5000.0)
    assert(not ECON.enqueue(warehouse_state, 1, 0, "economy", "warehouse"))
    for level in [1, 2]:
        depot["population"] = float(ECON.WAREHOUSE_POPULATIONS[level])
        for material in ECON.WAREHOUSE_COSTS[level]:
            depot["stock"][material] = ECON.storage_capacity(depot)
        assert(ECON.enqueue(warehouse_state, 1, 0, "economy", "warehouse"))
        assert(ECON.storage_capacity(depot) == ECON.WAREHOUSE_CAPACITIES[level + 1])
    assert(not ECON.enqueue(warehouse_state, 1, 0, "economy", "warehouse"))
    assert(float(ECON.empire_totals(warehouse_state, 1)["storage_reference"]["Tech"]) == 30000.0)
    print("PASS: storage caps, three warehouse levels, no baseline crystals, linear consumption")
    quit(0)
