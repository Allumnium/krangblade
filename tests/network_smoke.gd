extends SceneTree
## Run with --script res://tests/network_smoke.gd -- host 2
## or --script res://tests/network_smoke.gd -- client 2 1
var session: Node
var role: String = ""
var expected_players: int = 2
var saw_match: bool = false
var started: bool = false
var finishing: bool = false
var ready_sent: bool = false
var saw_loading: bool = false
var mode: String = "normal"
const MAP = preload("res://scripts/planet_map.gd")

func _initialize() -> void:
    call_deferred("_begin")

func _begin() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 2:
        _fail("Missing role/count arguments.")
        return
    role = args[0]
    expected_players = int(args[1])
    mode = str(args[2]) if role == "host" and args.size() >= 3 else (str(args[3]) if role == "client" and args.size() >= 4 else "normal")
    session = root.get_node_or_null("GameSession")
    if session == null:
        _fail("GameSession autoload is missing.")
        return
    session.connect("phase_changed", _phase_changed)
    session.connect("roster_changed", _roster_changed)
    create_timer(35.0).timeout.connect(func() -> void: _fail("Network smoke test timed out."))
    if role == "host":
        if not bool(session.call("host_game", "TestHost")):
            _fail("Could not host.")
    elif role == "client":
        var index: int = int(args[2]) if args.size() >= 3 else 1
        if not bool(session.call("join_game", "Guest%d" % index, "127.0.0.1")):
            _fail("Could not join.")
    else:
        _fail("Unrecognized role.")

func _roster_changed() -> void:
    if session == null or str(session.get("phase")) != "lobby" or saw_match:
        return
    var roster: Dictionary = session.get("players")
    if role == "host":
        if roster.size() == expected_players and not started and bool(session.call("can_start")):
            started = true
            session.call_deferred("start_match")
    elif role == "client":
        var self_id: int = session.multiplayer.get_unique_id()
        var entry: Dictionary = roster.get(self_id, {})
        if not entry.is_empty() and not bool(entry.get("ready", false)) and not ready_sent:
            ready_sent = true
            session.call_deferred("toggle_ready")

func _phase_changed() -> void:
    if session == null:
        return
    var phase: String = str(session.get("phase"))
    if phase == "loading":
        saw_loading = true
        if mode == "drop-loading" and role == "client":
            session.call_deferred("leave_session")
    elif phase == "match" and not saw_match:
        saw_match = true
        if mode == "drop-loading":
            _fail("Match started despite loading guest departing.")
            return
        var roster: Dictionary = session.get("players")
        if roster.size() != expected_players:
            _fail("Wrong roster size in match: %d" % roster.size())
            return
        var owners: Array[int] = session.get("owners")
        var state: Dictionary = session.get("economy")
        if owners.size() != state["map"]["points"].size() or state["map"]["cluster_sizes"].size() != expected_players * 3:
            _fail("Wrong territory count.")
            return
        if mode == "normal":
            call_deferred("_queue_test_ship")
            create_timer(1.5).timeout.connect(_check_economy_sync)
        if role == "host":
            if mode == "host-leave":
                create_timer(1.0).timeout.connect(func() -> void: session.call("leave_session"))
            else:
                create_timer(2.5).timeout.connect(func() -> void: session.call("return_to_lobby"))
    elif phase == "lobby" and saw_loading and not finishing:
        if (mode == "drop-loading" and role == "host") or (mode == "normal" and saw_match):
            finishing = true
            var roster: Dictionary = session.get("players")
            var expected: int = 1 if mode == "drop-loading" else expected_players
            if roster.size() != expected:
                _fail("Wrong roster size after return.")
                return
            for id in roster.keys():
                if int(id) != 1 and bool((roster[id] as Dictionary).get("ready", true)):
                    _fail("Guest remained ready after return.")
                    return
            create_timer(1.0 if role == "host" else 0.35).timeout.connect(_pass)
    elif phase == "offline" and not finishing:
        if (mode == "host-leave" and saw_match) or (mode == "drop-loading" and saw_loading and role == "client"):
            finishing = true
            create_timer(0.8 if role == "host" else 0.2).timeout.connect(_pass)
        else:
            _fail("Connection closed before expected transition.")

func _queue_test_ship() -> void:
    var state: Dictionary = session.get("economy")
    var self_id: int = session.multiplayer.get_unique_id()
    for i in range((state["planets"] as Array).size()):
        if int(state["planets"][i]["owner"]) == self_id:
            session.call("request_operation", i, "ship")
            return
    _fail("No home planet for player.")

func _check_economy_sync() -> void:
    var state: Dictionary = session.get("economy")
    var homes: int = 0
    for planet in state.get("planets", []):
        if bool(planet["home"]):
            homes += 1
            if (planet["queue"] as Array).size() != 1:
                _fail("Missing replicated ship queue on a home planet.")
                return
            if float(planet["queue"][0]["progress"]) <= 0.0:
                _fail("Shipyard progress did not synchronize.")
                return
    if homes != expected_players:
        _fail("Wrong home planet count.")
        return

func _pass() -> void:
    print("PASS: network %s %d players (%s)" % [role, expected_players, mode])
    quit(0)

func _fail(reason: String) -> void:
    if session != null:
        print("DEBUG: phase=", session.get("phase"), " roster=", session.get("players"), " loaded=", session.get("loaded"), " status=", session.get("status"), " started=", started, " saw_match=", saw_match)
    push_error("FAIL: %s (%s, %d players)" % [reason, role, expected_players])
    quit(1)
