extends SceneTree
const SIM = preload("res://scripts/match_simulation.gd")
const MAP = preload("res://scripts/map_generator.gd")
var checks: int = 0
var failed: bool = false

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        push_error("FAIL: " + message)
        failed = true

func _new(roster: Dictionary = {}) -> RefCounted:
    var sim := SIM.new()
    if roster.is_empty():
        roster = {1: {"name": "Host", "team": 1}, -1: {"name": "Bot", "team": 2}}
    sim.setup(roster, 12345)
    for player in sim.players.values():
        player.bot = false
    return sim

func _steps(sim: RefCounted, amount: int) -> void:
    for index in range(amount):
        sim.step()

func _clear_units(sim: RefCounted) -> void:
    sim.units.clear()
    sim._index_units()

func _run() -> void:
    _map_checks()
    _economy_checks()
    _capture_checks()
    _battle_checks()
    _movement_checks()
    _entrenchment_checks()
    _victory_checks()
    _bot_and_load_checks()
    if not failed:
        print("PASS: %d map, economy, movement, combat, elimination, bot, and load checks" % checks)
    quit(1 if failed else 0)

func _map_checks() -> void:
    var sim: RefCounted = _new()
    var map: Dictionary = sim.map
    _check(map.nodes.size() == 129, "129 nodes")
    _check(map.homes[1] == 0 and map.homes[-1] == 52, "opposite starts for two players")
    _check(map == MAP.generate({1: {"name": "Host", "team": 1}, -1: {"name": "Bot", "team": 2}}, 12345), "repeatable generation")
    var objectives: int = 0
    for node in map.nodes:
        if node.kind in ["objective", "central"]:
            objectives += 1
    _check(objectives == 21, "16 branch and 5 central objectives")
    for branch in range(1, 8):
        for offset in range(13):
            var expected: Vector2 = (map.nodes[offset].position as Vector2).rotated(float(branch) * TAU / 8.0)
            _check(expected.distance_to(map.nodes[branch * 13 + offset].position) < 0.001, "rotated branch geometry")
        for link in map.edges:
            if link.x < 13 and link.y < 13:
                _check(map.edges.has(MAP.edge(link.x + branch * 13, link.y + branch * 13)), "matching branch connections")
    var backbone: Array = MAP.adjacency(map, [])
    var reachable: Dictionary = MAP.routing(map, backbone, 128)
    for distance in reachable.distance:
        _check(not is_inf(float(distance)), "permanent graph connected")
    for index in range(8):
        _check(map.nodes[index * 13 + 6].kind == "objective", "mid-branch objective")
        _check(map.nodes[index * 13 + 12].kind == "objective", "inner branch objective")

func _economy_checks() -> void:
    var sim: RefCounted = _new()
    _check(sim.players[1].credits == 100 and sim.players[1].count == 5, "starting resources")
    _check(sim.apply_command(1, "recruit", 5).is_empty(), "buy batch")
    _check(sim.players[1].credits == 0 and sim.players[1].count == 10, "charged once per troop")
    _check(not sim.apply_command(1, "recruit", 1).is_empty(), "insufficient funds")
    _check(not sim.apply_command(1, "base", 52).is_empty(), "enemy base rejected")
    _check(not sim.apply_command(1, "rally", 999).is_empty(), "invalid node rejected")
    _check(not sim.apply_command(999, "auto", 1).is_empty(), "unknown player rejected")
    _check(sim.apply_command(1, "reserve", 52, 2).is_empty(), "plan entrenchment before enemy base capture")
    _steps(sim, 10)
    _check(is_equal_approx(float(sim.players[1].credits), 4.0), "base income")
    sim.players[1].credits = 10000.0
    while int(sim.players[1].count) < SIM.UNIT_CAP:
        sim.command_counts.clear()
        _check(sim.apply_command(1, "recruit", 5).is_empty(), "fill army")
    _check(not sim.apply_command(1, "recruit", 1).is_empty(), "unit cap")
    var roster: Dictionary = {1: {"name": "A", "team": 1}, 2: {"name": "B", "team": 1}, 3: {"name": "C", "team": 1}, -1: {"name": "D", "team": 2}}
    sim = _new(roster)
    sim.owners[6] = 1
    _steps(sim, 30)
    for id in [1, 2, 3]:
        _check(absf(float(sim.players[id].credits) - 114.0) < 0.0001, "fractional objective income retained")
    _check(is_equal_approx(float(sim.players[-1].credits), 112.0), "enemy doesn't share income")
    _check(sim.apply_command(1, "base", int(sim.map.homes[2])).is_empty(), "use teammate base")
    sim.owners[sim.map.homes[1]] = 2
    _steps(sim, 1)
    _check(not bool(sim.players[1].eliminated) and sim.usable_base(1, int(sim.players[1].base)), "survive own base loss")

func _capture_checks() -> void:
    var sim: RefCounted = _new()
    _clear_units(sim)
    sim._spawn(1, 1, 0.0)
    sim.players[1].rally = 1
    _steps(sim, 29)
    _check(sim.owners[1] == 0, "capture requires presence and time")
    _steps(sim, 1)
    _check(sim.owners[1] == 1, "capture after 3 seconds")
    _clear_units(sim)
    sim.owners[6] = 1
    sim.capture_team[6] = 2
    sim.capture_progress[6] = 1.0
    sim._spawn(1, 6, 0.0)
    sim._spawn(-1, 6, 0.0)
    _steps(sim, 5)
    _check(is_equal_approx(float(sim.capture_progress[6]), 1.0), "contesting pauses capture")
    _check(float(sim.players[1].objective_income) == 0.0, "contested objective pays nothing")
    for id in sim.units.keys():
        if int(sim.units[id].player) == -1:
            sim.units.erase(id)
    _steps(sim, 1)
    _check(sim.capture_progress[6] == 0.0, "defender restores control")
    _check(sim.players[1].objective_income == 2.0, "income resumes")

func _battle_checks() -> void:
    var sim: RefCounted = _new()
    _clear_units(sim)
    sim._spawn(1, 128, 20.0)
    sim._spawn(-1, 128, 20.0)
    _steps(sim, 1)
    _check(sim.units.size() == 2, "combat isn't instant")
    for unit in sim.units.values():
        _check(absf(float(unit.hp) - 9.7) < 0.00001, "simultaneous DPS")
    _steps(sim, 33)
    _check(sim.units.is_empty(), "equal forces die simultaneously")
    _check(sim.players[1].refunds == 2.0 and sim.players[-1].refunds == 2.0, "paid loss refunds")
    sim = _new()
    _clear_units(sim)
    sim._spawn(1, 128, 0.0)
    sim._spawn(-1, 128, 0.0)
    _steps(sim, 34)
    _check(sim.players[1].refunds == 0 and sim.players[-1].refunds == 0, "no refunds for free units")
    sim = _new({1: {"name": "A", "team": 1}, 2: {"name": "B", "team": 1}, -1: {"name": "C", "team": 2}})
    _clear_units(sim)
    sim._spawn(1, 6, 20.0)
    sim._spawn(2, 6, 20.0)
    _steps(sim, 1)
    for unit in sim.units.values():
        _check(unit.hp == 10.0, "no friendly fire")
    sim = _new({1: {"name": "A", "team": 1}, -1: {"name": "B", "team": 2}, -2: {"name": "C", "team": 3}})
    _clear_units(sim)
    for id in sim.players:
        sim._spawn(id, 128, 20.0)
    _steps(sim, 1)
    for unit in sim.units.values():
        _check(absf(float(unit.hp) - 9.7) < 0.00001, "three-team damage division")

func _movement_checks() -> void:
    var sim: RefCounted = _new()
    _check(sim.apply_command(1, "rally", 6).is_empty(), "set rally")
    _steps(sim, 1)
    var moving: int = 0
    for unit in sim.units.values():
        if unit.player == 1 and unit.to >= 0:
            moving += 1
    _check(moving == 3, "base garrison remains")
    sim.apply_command(1, "retreat", 0)
    for unit in sim.units.values():
        if unit.player == 1 and unit.to >= 0:
            _check(unit.to == 0 and bool(unit.reversing), "retreat reverses edge")
    _steps(sim, 3)
    _check(int(sim.players[1].count) == 5, "retreat preserves units")
    _clear_units(sim)
    sim._spawn(1, 0, 20.0)
    sim._spawn(-1, 1, 20.0)
    var ids: Array = sim.units.keys()
    sim.units[ids[0]].to = 1
    sim.units[ids[0]].progress = 0.45
    sim.units[ids[1]].to = 0
    sim.units[ids[1]].progress = 0.45
    sim.players[1].retreat = false
    _steps(sim, 1)
    for unit in sim.units.values():
        _check(bool(unit.fighting) and unit.progress == 0.45, "opposing edge armies stop and fight")
    var first: Dictionary = sim.units[ids[0]]
    _check(not sim._retreat_clear(first), "retreat cannot march through opposing troops")
    sim.apply_command(1, "retreat", 0)
    _check(sim._retreat_clear(first), "retreat can disengage away from contact")
    sim = _new()
    _clear_units(sim)
    sim._spawn(1, 0, 20.0)
    sim._spawn(-1, 1, 20.0)
    var endpoint_ids: Array = sim.units.keys()
    sim.units[endpoint_ids[1]].to = 0
    sim.units[endpoint_ids[1]].progress = 0.999
    sim.players[1].rally = 1
    sim.players[1].reserves[0] = 0
    _steps(sim, 1)
    _check(sim.units[endpoint_ids[0]].to == -1 and bool(sim.units[endpoint_ids[0]].fighting), "endpoint defender cannot pass arriving enemy")
    _check(absf(float(sim.units[endpoint_ids[0]].hp) - 9.7) < 0.00001, "endpoint contact applies combat damage once")
    sim = _new()
    _steps(sim, 249)
    _check(sim.pending.is_empty(), "no early route warning")
    _steps(sim, 1)
    _check(sim.pending.size() == 4 and sim.topology == 0, "five-second warning")
    var closing := Vector2i(-1, -1)
    for link in sim.dynamic:
        if not sim.pending.has(link):
            closing = link
            break
    _check(closing.x >= 0, "at least one route changes")
    _steps(sim, 49)
    _clear_units(sim)
    sim._spawn(1, closing.x, 20.0)
    var unit: Dictionary = sim.units.values()[0]
    unit.to = closing.y
    unit.progress = 0.999
    sim.players[1].rally = closing.y
    _steps(sim, 1)
    _check(sim.topology == 1 and not sim.dynamic.has(closing), "route shift applied")
    _check(unit.node == closing.y and unit.to == -1, "closing route doesn't strand traveler")
    _check(not sim.links[closing.x].has(closing.y), "new paths exclude closed route")

func _entrenchment_checks() -> void:
    var sim: RefCounted = _new()
    _clear_units(sim)
    sim.owners[1] = 1
    sim.owners[3] = 1
    sim.players[1].rally = 3
    for index in range(5):
        sim._spawn(1, 1, 20.0)
    _check(sim.apply_command(1, "reserve", 1, 3).is_empty(), "set entrenchment target")
    _steps(sim, 1)
    _check(_held(sim, 1, 1) == 3, "first three stop and surplus continues")
    for index in range(4):
        sim._spawn(1, 1, 20.0)
    _steps(sim, 1)
    _check(_held(sim, 1, 1) == 3, "later arrivals pass a filled holding point")
    sim.apply_command(1, "reserve", 1, 1)
    _steps(sim, 1)
    _check(_held(sim, 1, 1) == 1, "lowering target releases surplus defenders")
    sim.apply_command(1, "reserve", 1, 0)
    _steps(sim, 1)
    _check(_held(sim, 1, 1) == 0, "zero releases all defenders")
    _check(not sim.apply_command(1, "reserve", 1, 101).is_empty(), "target cannot exceed army cap")
    _check(not sim.apply_command(1, "reserve", -1, 2).is_empty(), "invalid holding node rejected")
    sim = _new()
    _clear_units(sim)
    sim.players[1].rally = 3
    for index in range(5):
        sim._spawn(1, 1, 20.0)
    _check(sim.apply_command(1, "reserve", 1, 4).is_empty(), "plan on neutral node")
    _steps(sim, 30)
    _check(sim.owners[1] == 1 and _held(sim, 1, 1) == 4, "planned entrenchment takes effect after capture")
    sim = _new({1: {"name": "A", "team": 1}, 2: {"name": "B", "team": 1}, -1: {"name": "C", "team": 2}})
    _clear_units(sim)
    sim.owners[1] = 1
    sim.players[1].rally = 3
    sim.players[2].rally = 3
    for index in range(5):
        sim._spawn(1, 1, 20.0)
        sim._spawn(2, 1, 20.0)
    sim.apply_command(1, "reserve", 1, 3)
    _steps(sim, 1)
    _check(_held(sim, 1, 1) == 3 and _held(sim, 2, 1) == 0, "orders only stop purchaser's own troops")
    sim.apply_command(1, "retreat", 0)
    _steps(sim, 2)
    _check(_held(sim, 1, 1) == 0, "retreat overrides entrenchment")

func _held(sim: RefCounted, player: int, node: int) -> int:
    var total: int = 0
    for unit in sim.units.values():
        if int(unit.player) == player and int(unit.node) == node and int(unit.to) < 0:
            total += 1
    return total

func _victory_checks() -> void:
    var sim: RefCounted = _new()
    _clear_units(sim)
    sim._spawn(-1, 0, 20.0)
    sim.players[-1].rally = 0
    _steps(sim, 99)
    _check(sim.result.is_empty(), "base capture takes ten seconds")
    _steps(sim, 1)
    _check(sim.winner == 2 and not sim.result.is_empty(), "last base victory")
    _check(bool(sim.players[1].eliminated) and sim.players[1].refunds == 0, "elimination without refunds")
    var stopped_tick: int = int(sim.tick)
    _steps(sim, 10)
    _check(sim.tick == stopped_tick, "victory freezes simulation")
    _check(not sim.apply_command(1, "recruit", 1).is_empty(), "eliminated players cannot order")
    sim = _new({1: {"name": "A", "team": 1}, -1: {"name": "B", "team": 2}, -2: {"name": "C", "team": 3}})
    _clear_units(sim)
    sim._spawn(-1, 0, 20.0)
    sim.players[-1].rally = 0
    sim._spawn(1, 6, 20.0)
    sim.players[1].rally = 6
    _steps(sim, 100)
    _check(sim.result.is_empty() and bool(sim.players[1].eliminated), "other teams continue after elimination")
    _check(sim.players[1].count == 0 and sim.players[1].refunds == 0, "elimination cleanup gives no paid-unit refund")
    _check(sim.apply_command(-1, "base", 0).is_empty(), "captured base becomes recruitment location")
    sim = _new()
    _clear_units(sim)
    sim._spawn(-1, 0, 20.0)
    sim._spawn(1, 52, 20.0)
    sim.players[-1].rally = 0
    sim.players[1].rally = 52
    _steps(sim, 100)
    _check(sim.winner == 0 and not sim.result.is_empty(), "mutual last-base capture draws")
    sim = _new({1: {"name": "A", "team": 1}, -1: {"name": "B", "team": 1}})
    _steps(sim, 2)
    _check(bool(sim.sandbox) and sim.result.is_empty(), "cooperative sandbox")

func _bot_and_load_checks() -> void:
    var sim: RefCounted = _new()
    sim.take_over(-1)
    _steps(sim, 1)
    _check(sim.owners.count(2) == 1, "bot cannot instantly capture")
    _steps(sim, 349)
    _check(sim.owners[58] == 2, "bot reaches income objective")
    _check(float(sim.players[-1].objective_income) > 0 and int(sim.players[-1].count) > 5, "bot recruits and earns income")
    sim.take_over(1)
    _check(bool(sim.players[1].bot) and bool(sim.players[1].auto), "disconnect bot takeover")
    var roster: Dictionary = {}
    for index in range(8):
        roster[index + 1] = {"name": "Player", "team": index + 1}
    sim = _new(roster)
    for id in sim.players:
        for index in range(95):
            sim._spawn(id, int(sim.players[id].base), 20.0)
        sim.players[id].rally = 128
    _check(sim.units.size() == 800, "eight full armies")
    var started: int = Time.get_ticks_usec()
    _steps(sim, 310)
    var elapsed: float = float(Time.get_ticks_usec() - started) / 1000000.0
    _check(elapsed < 31.0, "800 troops simulate faster than real time")
    var bytes: PackedByteArray = var_to_bytes(sim.snapshot())
    var compressed: PackedByteArray = bytes.compress(FileAccess.COMPRESSION_DEFLATE)
    _check(bytes_to_var(compressed.decompress_dynamic(8388608, FileAccess.COMPRESSION_DEFLATE)) == sim.snapshot(), "compressed snapshot round trip")
    print("LOAD: 800 troops, 310 ticks in %.2fs; snapshot %d -> %d bytes" % [elapsed, bytes.size(), compressed.size()])
