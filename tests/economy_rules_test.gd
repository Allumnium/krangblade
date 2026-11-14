extends SceneTree
const RULES = preload("res://scripts/lobby_rules.gd")
const ECONOMY = preload("res://scripts/economy_rules.gd")

func _initialize() -> void:
    var players: Dictionary = {1: {"team": 1, "ready": true}}
    var owners: Array[int] = RULES.starting_owners(players)
    var buildings: Array[String] = ECONOMY.starting_buildings(players)
    var stocks: Array[Dictionary] = ECONOMY.empty_stocks()
    assert(owners.size() == 17 and owners[0] == 1)
    assert(buildings.size() == 17 and buildings[0] == "hq")
    assert(not ECONOMY.can_build(owners, buildings, 1, 0, "mine"))
    assert(not ECONOMY.can_build(owners, buildings, 1, 8, "mine"))
    assert(not ECONOMY.can_build(owners, buildings, 2, 0, "factory"))
    assert(not ECONOMY.can_build(owners, buildings, 1, 0, ""))
    assert(not ECONOMY.can_build(owners, buildings, 1, 8, "nonsense"))

    # Route: HQ 0 <- iron mine 8 -> smelter 9 -> factory 10 <- copper mine 11
    # The two mines produce 2 raw units/tick, the smelter converts 2 iron
    # into steel and the factory turns steel + copper into 1 supply.
    for node in [8, 9, 10, 11]:
        owners[node] = 1
    assert(ECONOMY.can_build(owners, buildings, 1, 8, "mine"))
    assert(ECONOMY.can_build(owners, buildings, 1, 11, "mine"))
    buildings[8] = "mine"
    buildings[9] = "smelter"
    buildings[10] = "factory"
    buildings[11] = "mine"
    assert(ECONOMY.deposit(8) == "iron")
    assert(ECONOMY.deposit(11) == "copper")
    ECONOMY.tick(owners, buildings, stocks)
    assert(int(stocks[9]["iron"]) == 2) # One hop; no same-tick smelting.
    assert(int(stocks[10]["copper"]) == 2)
    assert(int(stocks[0]["supplies"]) == 0)
    for _step in range(20):
        ECONOMY.tick(owners, buildings, stocks)
    var total: Dictionary = ECONOMY.total_for_team(owners, stocks, 1)
    assert(int(total["supplies"]) > 0)
    assert(int(stocks[0]["supplies"]) > 0)
    for stock in stocks:
        for key in ECONOMY.RESOURCES:
            assert(int(stock[key]) >= 0)

    # A bottleneck cannot exceed three units of any mix per edge per tick.
    var cap_stocks: Array[Dictionary] = ECONOMY.empty_stocks()
    var cap_buildings: Array[String] = ECONOMY.starting_buildings(players)
    cap_stocks[8]["iron"] = 20
    cap_buildings[9] = "smelter"
    ECONOMY.tick(owners, cap_buildings, cap_stocks)
    assert(int(cap_stocks[8]["iron"]) == 17)
    assert(int(cap_stocks[9]["iron"]) == ECONOMY.EDGE_CAPACITY)

    # Resources never cross enemy or neutral territory.
    var isolated: Array[int] = RULES.starting_owners(players)
    isolated[8] = 1
    isolated[9] = 2
    var blocked: Array[Dictionary] = ECONOMY.empty_stocks()
    blocked[8]["iron"] = 10
    var isolated_buildings: Array[String] = ECONOMY.starting_buildings(players)
    isolated_buildings[9] = "smelter"
    ECONOMY.tick(isolated, isolated_buildings, blocked)
    assert(int(blocked[8]["iron"]) == 10)
    assert(int(blocked[9]["iron"]) == 0)

    # No free construction on enemy land or over an HQ; clearing works.
    assert(not ECONOMY.can_build(isolated, isolated_buildings, 1, 9, "factory"))
    assert(ECONOMY.can_build(owners, buildings, 1, 11, ""))
    print("PASS: extraction, routing, throughput, refining, storage and team isolation")
    quit(0)
