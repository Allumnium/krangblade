extends SceneTree
## Run with --script res://tests/network_smoke.gd -- host 2
## or --script res://tests/network_smoke.gd -- client 2 1
var session: Node
var role: String = ""
var expected_players: int = 2
var saw_match: bool = false
var started: bool = false
var finishing: bool = false

func _initialize() -> void:
    call_deferred("_begin")

func _begin() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 2:
        _fail("Missing role/count arguments.")
        return
    role = args[0]
    expected_players = int(args[1])
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
        if not entry.is_empty() and not bool(entry.get("ready", false)):
            session.call_deferred("toggle_ready")

func _phase_changed() -> void:
    if session == null:
        return
    var phase: String = str(session.get("phase"))
    if phase == "match" and not saw_match:
        saw_match = true
        var roster: Dictionary = session.get("players")
        if roster.size() != expected_players:
            _fail("Wrong roster size in match: %d" % roster.size())
            return
        var owners: Array[int] = session.get("owners")
        if owners.size() != 17:
            _fail("Wrong territory count.")
            return
        if role == "host":
            create_timer(1.0).timeout.connect(func() -> void: session.call("return_to_lobby"))
    elif phase == "lobby" and saw_match and not finishing:
        finishing = true
        var roster: Dictionary = session.get("players")
        if roster.size() != expected_players:
            _fail("Wrong roster size after return.")
            return
        for id in roster.keys():
            if int(id) != 1 and bool((roster[id] as Dictionary).get("ready", true)):
                _fail("Guest remained ready after return.")
                return
        create_timer(1.0 if role == "host" else 0.35).timeout.connect(_pass)
    elif phase == "offline" and not finishing:
        _fail("Connection closed before round trip.")

func _pass() -> void:
    print("PASS: network %s %d players, start barrier and return to lobby" % [role, expected_players])
    quit(0)

func _fail(reason: String) -> void:
    push_error("FAIL: %s (%s, %d players)" % [reason, role, expected_players])
    quit(1)
