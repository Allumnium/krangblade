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
    create_timer(65.0).timeout.connect(func() -> void: _fail("Network smoke test timed out."))
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
            elif mode == "normal":
                create_timer(0.25).timeout.connect(_return_after_all_verified)
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
            if role == "host" and mode == "normal":
                _wait_for_guest_completion()
            else:
                create_timer(0.35).timeout.connect(_pass)
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
    if bool(state.get("fog_of_war", true)) or (state["map"]["fields"] as Array).is_empty():
        _fail("Expected fully visible map and at least one asteroid field.")
        return
    for i in range((state["planets"] as Array).size()):
        if not ECON.discovered(state, self_id, "planets", i):
            _fail("System hidden with fog disabled.")
            return
    for i in range((state["map"]["fields"] as Array).size()):
        if not ECON.discovered(state, self_id, "fields", i):
            _fail("Asteroid field hidden with fog disabled.")
            return

func _send_commands() -> void:
    commands_sent = true
    session.call("request_thresholds", home_index, "Metals", 15.0, 65.0)
    # Invalid and unauthorized threshold requests must not win.
    session.call("request_thresholds", home_index, "Metals", 99.0, 101.0)
    session.call("request_thresholds", (home_index + 1) % expected_players, "Metals", 77.0, 88.0)
    session.call("request_operation", home_index, "ship")
    session.call("request_operation", home_index, "fighter")
    session.call("request_continuous", home_index, "colony_ship", true)
    session.call("request_continuous", home_index, "miner", true)
    session.call("request_continuous", home_index, "production:Organics", true)
    session.call("request_continuous", home_index, "yard_upgrade:0", true)
    session.call("request_mining_policy", 0, true, false, true)
    for i in range(3):
        session.call("request_operation", home_index, "yard")
    var state: Dictionary = session.get("economy")
    var node: int = (state["planets"] as Array).size()
    session.call("request_military", "fighter", node, 70)
    session.call("request_military", "fighter", -1, 100)
    session.call("request_military", "fighter", node, 101)

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
            var repeat_colony: bool = false
            var repeat_miner: bool = false
            for job in system["queue"]:
                if job["kind"] == "ship" and float(job["progress"]) > 0.0:
                    ship_progress = true
                elif job["kind"] == "fighter":
                    fighter_pending = true
                elif job["kind"] == "production" and job["target"] == "Organics":
                    upgrade_pending = true
                elif job["kind"] == "yard_upgrade":
                    yard_pending = true
                elif job["kind"] == "colony_ship" and bool(job.get("automatic", false)):
                    repeat_colony = true
                elif job["kind"] == "miner" and bool(job.get("automatic", false)):
                    repeat_miner = true
            for ship in state["ships"]:
                if not ship.has("hp") or float(ship["hp"]) <= 0.0 or float(ship["hp"]) > ECON.SHIP_HP:
                    _fail("Replicated hull hit points are invalid.")
                    return
                if int(ship["owner"]) == owner and ship.get("kind", "ship") == "ship":
                    ship_progress = true
            var military: Dictionary = ECON.military_policy(state, owner, "fighter")
            var field_node: int = (state["planets"] as Array).size()
            if int(military.get(field_node, 0)) == 70 and int(military.get(ECON.military_home(state, owner), 0)) == 30 and is_equal_approx(float(thresholds["min"]), 15.0) and is_equal_approx(float(thresholds["max"]), 65.0) and flags.get("production:Organics", false) and flags.get("yard_upgrade:0", false) and flags.get("colony_ship", false) and flags.get("miner", false) and repeat_colony and repeat_miner and upgrade_pending and yard_pending and not fighter_pending and ship_progress and ECON.shipyard_count(system) == 3 and policy["enabled"] and not policy["Metals"] and policy["Crystals"]:
                verified += 1
        var view: Node = current_scene
        if cancel_sent and verified == expected_players and view != null and view.has_method("_update_trade_stock"):
            view.set("selected", home_index)
            view.call("_load_thresholds")
            view.call("_refresh")
            if not (view.get("yard_button") as Button).disabled:
                _fail("Shipyard build button must be disabled at the maximum.")
                return
            var sliders: Dictionary = view.get("trade_sliders")
            var home: Dictionary = state["planets"][home_index]
            for resource in ECON.RESOURCES:
                var slider: Control = sliders[resource]
                var stock: float = float(home["stock"][resource])
                var thresholds: Dictionary = home["thresholds"][resource]
                if not is_equal_approx(float(slider.get("stock_percent")), clampf(stock / ECON.TRADE_REFERENCE * 100.0, 0.0, 100.0)) or not is_equal_approx(float(slider.get("lower")), float(thresholds["min"])) or not is_equal_approx(float(slider.get("upper")), float(thresholds["max"])):
                    _fail("Replicated inventory or thresholds do not match the trade bars.")
                    return
            var poses: Dictionary = view.call("_ship_poses", state)
            for ship in state["ships"]:
                if not poses.has(int(ship["id"])):
                    _fail("A replicated ship was not rendered.")
                    return
            economy_verified = true
            # A normal game command is the completion acknowledgment. Return
            # only after each real peer has independently verified its replica.
            session.call("request_thresholds", home_index, "Plastics", 11.0, 22.0)
    if not economy_verified:
        create_timer(0.25).timeout.connect(_check_economy_sync)

func _return_after_all_verified() -> void:
    if str(session.get("phase")) != "match":
        return
    var state: Dictionary = session.get("economy")
    var confirmed: int = 0
    for system in state.get("planets", []):
        if not bool(system["home"]):
            continue
        var ack: Dictionary = system["thresholds"]["Plastics"]
        if is_equal_approx(float(ack["min"]), 11.0) and is_equal_approx(float(ack["max"]), 22.0):
            confirmed += 1
    if economy_verified and confirmed == expected_players:
        session.call("return_to_lobby")
    else:
        create_timer(0.25).timeout.connect(_return_after_all_verified)

# Do not close the host while guests are still receiving the lobby transition.
# Every guest must independently pass its own checks before exiting.
func _wait_for_guest_completion() -> void:
    if (session.get("players") as Dictionary).size() == 1 and session.multiplayer.get_peers().is_empty():
        _pass()
    else:
        create_timer(0.25).timeout.connect(_wait_for_guest_completion)

func _pass() -> void:
    print("PASS: network %s %d players (%s)" % [role, expected_players, mode])
    quit(0)

func _fail(reason: String) -> void:
    if session != null:
        print("DEBUG: phase=", session.get("phase"), " roster=", session.get("players"), " loaded=", session.get("loaded"), " status=", session.get("status"), " started=", started, " saw_match=", saw_match)
    push_error("FAIL: %s (%s, %d players)" % [reason, role, expected_players])
    quit(1)
