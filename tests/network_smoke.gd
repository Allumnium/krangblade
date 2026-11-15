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
var economy_verified: bool = false
var home_index: int = -1
var cancel_id: int = -1
var cancel_sent: bool = false
var commands_sent: bool = false
const ECON = preload("res://scripts/economy_rules.gd")
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
            call_deferred("_prepare_commands")
            create_timer(0.5).timeout.connect(_check_economy_sync)
        if role == "host":
            if mode == "host-leave":
                create_timer(1.0).timeout.connect(func() -> void: session.call("leave_session"))
            else:
                create_timer(12.0).timeout.connect(func() -> void: session.call("return_to_lobby"))
    elif phase == "lobby" and saw_loading and not finishing:
        if (mode == "drop-loading" and role == "host") or (mode == "normal" and saw_match):
            if mode == "normal" and not economy_verified:
                _fail("Never verified all multiplayer command and replication checks before return.")
                return
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
            create_timer(3.0 if role == "host" else 0.35).timeout.connect(_pass)
    elif phase == "offline" and not finishing:
        if (mode == "host-leave" and saw_match) or (mode == "drop-loading" and saw_loading and role == "client"):
            finishing = true
            create_timer(0.8 if role == "host" else 0.2).timeout.connect(_pass)
        else:
            _fail("Connection closed before expected transition.")

func _prepare_commands() -> void:
    var state: Dictionary = session.get("economy")
    var self_id: int = session.multiplayer.get_unique_id()
    for i in range((state["planets"] as Array).size()):
        if int(state["planets"][i]["owner"]) == self_id:
            home_index = i
            break
    if home_index < 0:
        _fail("No home system for player.")
        return
    # Reveal one generated field to every team for a deterministic policy round trip.
    # This is a test-only scenario; the real discovery rules are unchanged.
    if role == "host":
        if (state["map"]["fields"] as Array).is_empty():
            _fail("Generated map has no asteroid field for policy testing.")
            return
        for team in state["explored"]:
            state["explored"][team]["fields"][0] = true
        session.call("_publish_economy")

func _send_commands() -> void:
    commands_sent = true
    session.call("request_thresholds", home_index, "Metals", 15.0, 65.0)
    # Invalid and unauthorized threshold requests must not win.
    session.call("request_thresholds", home_index, "Metals", 99.0, 101.0)
    session.call("request_thresholds", (home_index + 1) % expected_players, "Metals", 77.0, 88.0)
    session.call("request_operation", home_index, "ship")
    session.call("request_operation", home_index, "fighter")
    session.call("request_continuous", home_index, "production:Organics", true)
    session.call("request_continuous", home_index, "yard_upgrade:0", true)
    session.call("request_mining_policy", 0, true, false, true)

func _check_economy_sync() -> void:
    if economy_verified or str(session.get("phase")) != "match":
        return
    var state: Dictionary = session.get("economy")
    var self_id: int = session.multiplayer.get_unique_id()
    if not commands_sent and home_index >= 0 and ECON.discovered(state, self_id, "fields", 0):
        _send_commands()
        state = session.get("economy")
    if commands_sent:
        var own: Dictionary = state["planets"][home_index]
        if not cancel_sent:
            for item in own["queue"]:
                if item["kind"] == "fighter":
                    cancel_id = int(item["id"])
                    cancel_sent = true
                    session.call("request_cancel", home_index, cancel_id)
                    break
        var verified: int = 0
        for system in state["planets"]:
            if not bool(system["home"]):
                continue
            var owner: int = int(system["owner"])
            var thresholds: Dictionary = system["thresholds"]["Metals"]
            var flags: Dictionary = system["continuous"]
            var policy: Dictionary = ECON.mining_policy(state, owner, 0)
            var ship_progress: bool = false
            var fighter_pending: bool = false
            var upgrade_pending: bool = false
            var yard_pending: bool = false
            for job in system["queue"]:
                if job["kind"] == "ship" and float(job["progress"]) > 0.0:
                    ship_progress = true
                elif job["kind"] == "fighter":
                    fighter_pending = true
                elif job["kind"] == "production" and job["target"] == "Organics":
                    upgrade_pending = true
                elif job["kind"] == "yard_upgrade":
                    yard_pending = true
            for ship in state["ships"]:
                if int(ship["owner"]) == owner and ship.get("kind", "ship") == "ship":
                    ship_progress = true
            if is_equal_approx(float(thresholds["min"]), 15.0) and is_equal_approx(float(thresholds["max"]), 65.0) and flags.get("production:Organics", false) and flags.get("yard_upgrade:0", false) and upgrade_pending and yard_pending and not fighter_pending and ship_progress and policy["enabled"] and not policy["Metals"] and policy["Crystals"]:
                verified += 1
        var view: Node = current_scene
        if cancel_sent and verified == expected_players and view != null and view.has_method("_update_trade_stock"):
            view.set("selected", home_index)
            var picker: OptionButton = view.get("trade_picker")
            picker.select(0)
            view.call("_load_thresholds")
            view.call("_refresh")
            var slider: Control = view.get("threshold_slider")
            var stock: float = float(state["planets"][home_index]["stock"]["Metals"])
            if not is_equal_approx(float(slider.get("stock_percent")), clampf(stock / ECON.TRADE_REFERENCE * 100.0, 0.0, 100.0)):
                _fail("Replicated inventory does not match the trade bar.")
                return
            economy_verified = true
    if not economy_verified:
        create_timer(0.25).timeout.connect(_check_economy_sync)

func _pass() -> void:
    print("PASS: network %s %d players (%s)" % [role, expected_players, mode])
    quit(0)

func _fail(reason: String) -> void:
    if session != null:
        print("DEBUG: phase=", session.get("phase"), " roster=", session.get("players"), " loaded=", session.get("loaded"), " status=", session.get("status"), " started=", started, " saw_match=", saw_match)
    push_error("FAIL: %s (%s, %d players)" % [reason, role, expected_players])
    quit(1)
