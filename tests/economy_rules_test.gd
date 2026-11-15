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
    trade_test["stock"]["Metals"] = 75.0
    assert(is_equal_approx(ECON._need(trade_test, "Metals"), 25.0))
    assert(is_zero_approx(ECON._surplus(trade_test, "Metals")))
    trade_test["stock"]["Metals"] = 150.0
    assert(is_zero_approx(ECON._need(trade_test, "Metals")))
    assert(is_zero_approx(ECON._surplus(trade_test, "Metals")))
    trade_test["stock"]["Metals"] = 250.0
    assert(is_equal_approx(ECON._surplus(trade_test, "Metals"), 50.0))
    trade_test["stock"]["Metals"] = 1250.0
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
    assert(is_equal_approx(float(totals["stock"]["Metals"]), 625.0))
    assert(is_equal_approx(float(totals["cargo"]["Metals"]), 7.0))
    assert(is_equal_approx(float(totals["resources"]["Metals"]), 632.0))
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

    # Upgrade costs increase quadratically; all order types refund actual allocations.
    for kind in ["production", "yard_upgrade"]:
        assert(float(ECON._cost(kind, 2)["Metals"]) >= 600.0)
        assert(float(ECON._cost(kind, 3)["Metals"]) > float(ECON._cost(kind, 2)["Metals"]))
        assert(float(ECON._cost(kind, 4)["Metals"]) > float(ECON._cost(kind, 3)["Metals"]))
    var refunds: Dictionary = ECON.create(graph, players, ids)
    var refund_home: Dictionary = refunds["planets"][0]
    refund_home["levels"]["Metals"] = 0
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
        assert(is_equal_approx(float(refund_home["stock"]["Metals"]), 10000.0))
        assert(int(refund_home["yards"][0]["job"]) == -1)
    # Completed and pending shipyards share a hard three-slot limit.
    var capped: Dictionary = ECON.create(graph, players, ids)
    var cap_home: Dictionary = capped["planets"][0]
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

    # Automatic system and shipyard upgrades use the shared scheduler.
    var upgrades: Dictionary = ECON.create(graph, players, ids)
    var upgrade_home: Dictionary = upgrades["planets"][0]
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
    # Diamond routes exercise equal-probability choices and branching frontiers.
    var patrol_map: Dictionary = MAP.generate(1337)
    patrol_map["edges"] = [[0, 3], [0, 4], [3, 5], [4, 5], [5, 6], [3, 7]]
    var patrol_state: Dictionary = ECON.create(patrol_map, players, ids)
    assert(not ECON.set_outpost(patrol_state, 1, 6, true))
    assert(not ECON.set_outpost(patrol_state, 1, 1, true))
    for index in [3, 4, 5, 6, 7]:
        assert(ECON.set_outpost(patrol_state, 1, index, true))
        assert(int(patrol_state["planets"][index]["owner"]) == 0)
    var patrol_network: Dictionary = ECON.military_network(patrol_state, 1)
    assert(patrol_network["frontiers"] == [6, 7])
    assert(not ECON.set_military(patrol_state, 1, "ship", -1, 50))
    assert(not ECON.set_military(patrol_state, 1, "fighter", 5, 50))
    assert(not ECON.set_military(patrol_state, 1, "fighter", -1, 101))
    assert(ECON.set_military(patrol_state, 1, "fighter", -1, 60))
    assert(ECON.set_military(patrol_state, 1, "fighter", 6, 75))
    var patrol_policy: Dictionary = ECON.military_policy(patrol_state, 1, "fighter", patrol_network)
    assert(patrol_policy["weights"][6] == 75 and patrol_policy["weights"][7] == 25)
    for i in range(20):
        patrol_state["ships"].append({"id": i + 1, "kind": "fighter", "owner": 1, "at": 0, "route": [], "leg": 0.0, "cargo": ECON.empty_stock()})
    var patrol_assignments: Dictionary = ECON.military_assignments(patrol_state, 1, "fighter", patrol_network)
    assert(patrol_assignments.values().count(6) == 9)
    assert(patrol_assignments.values().count(7) == 3)
    assert(patrol_assignments.values().count(-1) == 8)
    var patrol_branches: Dictionary = {}
    for i in range(64):
        var path: Array[int] = ECON._military_homeward(patrol_network, 6)
        patrol_branches[path[2]] = true
    assert(patrol_branches.has(3) and patrol_branches.has(4))
    var patrol_fighter: Dictionary = patrol_state["ships"][0]
    ECON._work_fighter(patrol_state, patrol_fighter, patrol_network, 6, 0.1)
    assert(patrol_fighter["route"].back() == 6)
    ECON._work_fighter(patrol_state, patrol_fighter, patrol_network, 6, 100000.0)
    assert(patrol_fighter["at"] == 6 and patrol_fighter["military_mode"] == "frontier")
    ECON._work_fighter(patrol_state, patrol_fighter, patrol_network, -1, 0.1)
    assert(patrol_fighter["route"].back() == 0)
    ECON._work_fighter(patrol_state, patrol_fighter, patrol_network, -1, 100000.0)
    assert(patrol_fighter["at"] == 0 and patrol_fighter["route"].back() in [6, 7])
    assert(ECON.set_outpost(patrol_state, 1, 5, false))
    patrol_network = ECON.military_network(patrol_state, 1)
    assert(not patrol_network["frontiers"].has(6))
    assert(patrol_network["outposts"].has(6))
    print("PASS: declared patrol_state patrol_network, randomized routes, frontier allocation, patrol return")
    print("PASS: seeded maps, ownership, construction, shipyards, mixed cargo, physical transit, ally sharing")
    quit(0)
