extends SceneTree
## Real ENet processes. Test-only acceleration covers 30s route shifts quickly.
const SIM = preload("res://scripts/match_simulation.gd")
var session: Node
var role: String
var humans: int = 2
var mode: String = "normal"
var started: bool = false
var ready_sent: bool = false
var saw_loading: bool = false
var saw_match: bool = false
var finishing: bool = false
var saw_travel: bool = false
var saw_battle: bool = false
var saw_warning: bool = false
var saw_shift: bool = false
var saw_income: bool = false
var saw_recruit: bool = false
var final_seen: bool = false
var takeover_seen: bool = false
var guest_left: bool = false
var self_id: int = 0
var last_tick: int = -1
var initial_rally: int = -1
var load_filled: bool = false
var saw_full_load: bool = false

func _initialize() -> void:
    call_deferred("_begin")

func _begin() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 2:
        _fail("Missing arguments")
        return
    role = args[0]
    humans = int(args[1])
    mode = str(args[2]) if role == "host" and args.size() >= 3 else (str(args[3]) if args.size() >= 4 else "normal")
    session = root.get_node("GameSession")
    session.connect("phase_changed", _phase)
    session.connect("roster_changed", _roster)
    session.connect("state_changed", _state)
    create_timer(60.0).timeout.connect(func() -> void: _fail("Network timeout"))
    if role == "host":
        if not bool(session.call("host_game", "TestHost")):
            _fail("Cannot host")
        elif mode in ["bots", "takeover"]:
            session.call("add_bot")
    else:
        if not bool(session.call("join_game", "Guest" + args[2], "127.0.0.1")):
            _fail("Cannot join")

func _expected() -> int:
    return humans + (1 if mode in ["bots", "takeover"] else 0)

func _roster() -> void:
    if session == null or str(session.get("phase")) != "lobby" or saw_match:
        return
    var roster: Dictionary = session.get("players")
    if role == "host":
        if roster.size() == _expected() and not started and bool(session.call("can_start")):
            started = true
            session.call_deferred("start_match")
    elif not ready_sent and roster.has(session.multiplayer.get_unique_id()):
        ready_sent = true
        session.call_deferred("toggle_ready")

func _phase() -> void:
    if session == null:
        return
    var phase: String = str(session.get("phase"))
    if phase == "loading":
        saw_loading = true
        if mode == "drop-loading" and role == "client":
            session.call_deferred("leave_session")
    elif phase == "match" and not saw_match:
        saw_match = true
        self_id = session.multiplayer.get_unique_id()
        var map: Dictionary = session.get("map_data")
        var state: Dictionary = session.get("match_state")
        if map.nodes.size() != 129 or state.players.size() != _expected() or state.units.size() != _expected() * 5:
            _fail("Initial map/armies disagree")
            return
        initial_rally = int(map.homes[self_id]) + 6
        session.call_deferred("command", "recruit", 1)
        session.call_deferred("command", "rally", initial_rally)
        session.call_deferred("command", "auto", 1)
        if role == "client":
            # A stale order and an enemy recruitment base must not override ours.
            session.rpc_id(1, "_rpc_order", int(session.get("round_id")) - 1, "rally", 128, 0)
            session.call_deferred("command", "base", int(map.homes[1]))
        if role == "host":
            call_deferred("_host_fixture")
    elif phase == "lobby" and saw_loading and not finishing:
        if mode == "drop-loading" and role == "host":
            if (session.get("players") as Dictionary).size() != 1:
                _fail("Loading departure not removed")
                return
            finishing = true
            create_timer(0.3).timeout.connect(_pass)
        elif final_seen:
            var roster: Dictionary = session.get("players")
            var expected: int = 2 if mode == "takeover" else _expected()
            if roster.size() != expected or not (session.get("match_state") as Dictionary).is_empty():
                _fail("Return roster or cleanup wrong")
                return
            for id in roster:
                if int(id) > 1 and bool(roster[id].ready):
                    _fail("Human guest remained ready")
                    return
            finishing = true
            create_timer(0.35 if role == "host" else 1.0).timeout.connect(_pass)
    elif phase == "offline" and not finishing:
        if (mode == "drop-loading" and saw_loading and role == "client") or (mode == "host-leave" and saw_match) or (mode == "takeover" and role == "client" and guest_left):
            finishing = true
            create_timer(0.3).timeout.connect(_pass)
        else:
            _fail("Unexpected disconnect")

func _host_fixture() -> void:
    var sim: RefCounted = session.get("simulation")
    if mode not in ["takeover", "host-leave", "drop-loading"]:
        # Controlled central battle verifies combat replication while normal
        # armies travel from their bases. These test troops have no refund value.
        for id in sim.players:
            sim.call("_spawn", id, 128, 0.0)
    # Exercise 800 troops at the actual production snapshot rate. Smaller
    # scenarios accelerate time; 100Hz full-army snapshots are not production.
    (session.get("simulation_timer") as Timer).wait_time = SIM.TICK if mode == "load" else 0.01

func _state() -> void:
    if not saw_match or finishing:
        return
    var state: Dictionary = session.get("match_state")
    if state.is_empty():
        return
    var tick: int = int(state.tick)
    if tick < last_tick:
        _fail("Snapshot tick went backwards")
        return
    last_tick = tick
    var player: Dictionary = state.players[self_id]
    for unit in state.units.values():
        if int(unit.to) >= 0 and float(unit.progress) > 0:
            saw_travel = true
        if bool(unit.fighting) and float(unit.hp) < SIM.UNIT_HEALTH:
            saw_battle = true
    saw_recruit = saw_recruit or int(player.count) > 5
    saw_income = saw_income or float(player.objective_income) > 0
    saw_warning = saw_warning or not state.pending.is_empty()
    saw_shift = saw_shift or int(state.topology) >= 1
    saw_full_load = saw_full_load or state.units.size() == 800
    if role == "client" and tick > 10 and int(player.rally) != initial_rally:
        _fail("Stale order changed rally")
        return
    if mode == "takeover" and role == "client" and tick >= 20 and not guest_left:
        guest_left = true
        session.call_deferred("leave_session")
    if mode == "takeover" and role == "host" and tick > 50:
        for id in state.players:
            if int(id) > 1 and bool(state.players[id].bot):
                takeover_seen = true
    if mode == "host-leave" and role == "host" and tick >= 30 and not guest_left:
        guest_left = true
        session.call_deferred("leave_session")
    if not str(state.result).is_empty() and not final_seen:
        final_seen = true
        if role == "client":
            var stale: Dictionary = state.duplicate(true)
            stale.tick = tick + 100
            stale.result = ""
            var payload: PackedByteArray = var_to_bytes(stale).compress(FileAccess.COMPRESSION_DEFLATE)
            session.call("_accept_snapshot", int(session.get("round_id")), payload)
            session.call("_accept_snapshot", int(session.get("round_id")) - 1, payload)
            if int((session.get("match_state") as Dictionary).tick) != tick or str((session.get("match_state") as Dictionary).result).is_empty():
                _fail("Delayed snapshot changed frozen results")
                return
        if mode == "load" and not saw_full_load:
            _fail("800-troop snapshot not received")
            return
        if not saw_travel or not saw_recruit or not saw_income or not saw_warning or not saw_shift:
            _fail("Missing replication: travel=%s recruit=%s income=%s warning=%s shift=%s" % [saw_travel, saw_recruit, saw_income, saw_warning, saw_shift])
            return
        if mode not in ["takeover", "host-leave"] and not saw_battle:
            _fail("Missing battle replication")
            return
        if mode == "takeover" and role == "host" and not takeover_seen:
            _fail("Missing disconnect takeover")
            return
        if role == "host":
            create_timer(0.5).timeout.connect(func() -> void: session.call("return_to_lobby"))
    if role == "host" and tick >= 360 and str(state.result).is_empty() and mode != "host-leave":
        call_deferred("_finish_fixture")
    if mode == "load" and role == "host" and tick >= 100 and not load_filled:
        load_filled = true
        call_deferred("_load_fixture")

func _load_fixture() -> void:
    var sim: RefCounted = session.get("simulation")
    var participants: Dictionary = sim.get("players")
    for id in participants:
        var player: Dictionary = participants[id]
        for index in range(SIM.UNIT_CAP - int(player.count)):
            sim.call("_spawn", id, int(player.base), 20.0)

func _finish_fixture() -> void:
    var sim: RefCounted = session.get("simulation")
    if sim == null or not str(sim.get("result")).is_empty():
        return
    var map: Dictionary = sim.get("map")
    var ownership: Array[int] = sim.get("owners")
    for node in map.nodes:
        if node.kind == "base":
            ownership[node.id] = 1
    session.call("_simulation_tick")

func _pass() -> void:
    print("PASS: network %s %d humans (%s)" % [role, humans, mode])
    quit(0)

func _fail(reason: String) -> void:
    push_error("FAIL: %s (%s %s tick %d)" % [reason, role, mode, last_tick])
    finishing = true
    quit(1)
