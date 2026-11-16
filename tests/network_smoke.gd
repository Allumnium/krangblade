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
var color_requested: bool = false
var expected_color: int = 0
var economy_verified: bool = false
var observed_commands: Dictionary = {}
var home_index: int = -1
var cancel_id: int = -1
var cancel_sent: bool = false
var cancelled_yard_id: int = -1
var promoted_yard_id: int = -1
var yard_rebuilt: bool = false
var commands_sent: bool = false
var next_diagnostic: float = 10.0
var speed_stage: int = 0
var paused_elapsed: float = -1.0
const TEST_SPEEDS: Array[int] = [0, 2, 5, 10, 1]
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
        if not color_requested:
            color_requested = true
            session.call("choose_color", 1, 8)
            return
        if roster.size() == expected_players and not started and bool(session.call("can_start")):
            started = true
            session.call_deferred("start_match")
    elif role == "client":
        var self_id: int = session.multiplayer.get_unique_id()
        var entry: Dictionary = roster.get(self_id, {})
        if not entry.is_empty() and not color_requested:
            color_requested = true
            expected_color = 7 if expected_players == 2 else int(entry["color"])
            session.call("choose_color", self_id, 8) # occupied by host; must reject
            if expected_players == 2:
                session.call("choose_color", self_id, 7)
            return
        if not entry.is_empty() and int(entry.get("color", 0)) == expected_color and not bool(entry.get("ready", false)) and not ready_sent:
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
        var colors: Dictionary = {}
        for entry in roster.values():
            var choice: int = int(entry.get("color", 0))
            if choice < 1 or choice > 8 or colors.has(choice):
                _fail("Empire colors must be unique and valid.")
                return
            colors[choice] = true
        if int(roster[1]["color"]) != 8 or (expected_players == 2 and not colors.has(7)):
            _fail("Selected empire colors did not replicate.")
            return
        var owners: Array[int] = session.get("owners")
        var state: Dictionary = session.get("economy")
        for owner in roster:
            var miners: int = 0
            var fighters: int = 0
            for craft in state["ships"]:
                if int(craft["owner"]) == int(owner):
                    miners += 1 if craft["kind"] == "miner" else 0
                    fighters += 1 if craft["kind"] == "fighter" else 0
            if miners != 3 or fighters != 2:
                _fail("Starting fleet did not replicate.")
                return
        if owners.size() != state["map"]["points"].size() or state["map"]["cluster_sizes"].size() != expected_players * 3:
            _fail("Wrong territory count.")
            return
        if mode == "normal":
            if role == "host":
                for system in state["planets"]:
                    if bool(system["home"]):
                        system["population"] = 150000.0
                        system["levels"]["Organics"] = 3
                        for resource in ECON.RESOURCES:
                            system["stock"][resource] = maxf(float(system["stock"][resource]), 2000.0)
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
                call_deferred("_finish_guest_return")
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

    if role == "host":
        session.call("request_time_speed", 0)

# Each real peer acknowledges the observed speed before the host advances.
# Reuse otherwise untouched local Plastics thresholds as test acknowledgments.
func _check_time_controls(state: Dictionary) -> bool:
    if speed_stage >= TEST_SPEEDS.size():
        return true
    var expected: int = TEST_SPEEDS[speed_stage]
    var current: int = int(state.get("time_speed", -1))
    if current != expected:
        if role == "host" and speed_stage > 0:
            var confirmed: int = 0
            for system in state["planets"]:
                if bool(system["home"]) and is_equal_approx(float(system["thresholds"]["Plastics"]["min"]), 12.0 + float(speed_stage - 1)):
                    confirmed += 1
            if confirmed == expected_players:
                session.call("request_time_speed", expected)
        return false
    var view: Node = current_scene
    if view == null or not view.has_method("_refresh_time_controls"):
        return false
    var buttons: Dictionary = view.get("time_buttons")
    if buttons.size() != TEST_SPEEDS.size():
        _fail("Time controls missing.")
        return false
    for speed in TEST_SPEEDS:
        var button: Button = buttons[speed]
        if button.button_pressed != (speed == current) or button.disabled != (role != "host"):
            _fail("Time control selection or authority does not match replicated speed.")
            return false
    if speed_stage == 0:
        if paused_elapsed < 0.0:
            paused_elapsed = float(state["elapsed"])
            # Host rejects invalid values; guests cannot change the speed.
            session.call("request_time_speed", 3 if role == "host" else 5)
            return false
        if not is_equal_approx(float(state["elapsed"]), paused_elapsed):
            _fail("Clock advanced while paused.")
            return false
    if speed_stage < TEST_SPEEDS.size() - 1:
        session.call("request_thresholds", home_index, "Plastics", 12.0 + float(speed_stage), 25.0)
    speed_stage += 1
    return speed_stage >= TEST_SPEEDS.size()

func _send_commands() -> void:
    commands_sent = true
    session.call("request_policy", "defense", "guard")
    session.call("request_policy_target", "defense", home_index, true)
    session.call("request_policy", "wildcard", "guard")
    session.call("request_thresholds", home_index, "Metals", 15.0, 65.0)
    # Invalid and unauthorized threshold requests must not win.
    session.call("request_thresholds", home_index, "Metals", 99.0, 101.0)
    session.call("request_thresholds", (home_index + 1) % expected_players, "Metals", 77.0, 88.0)
    session.call("request_operation", home_index, "economy", "warehouse")
    session.call("request_operation", home_index, "economy", "Textiles")
    session.call("request_operation", home_index, "economy", "Textiles")
    session.call("request_operation", home_index, "economy", "Tech")
    session.call("request_operation", (home_index + 1) % expected_players, "economy", "Metals")
    session.call("request_operation", home_index, "pds", "999")
    session.call("request_operation", (home_index + 1) % expected_players, "pds", "1")
    session.call("request_operation", home_index, "pds", "0")
    session.call("request_operation", home_index, "pds", "0")
    session.call("request_operation", home_index, "ship")
    session.call("request_operation", home_index, "fighter")
    session.call("request_continuous", home_index, "colony_ship", true)
    session.call("request_continuous", home_index, "miner", true)
    session.call("request_continuous", home_index, "production:Organics", true)
    session.call("request_continuous", home_index, "yard_upgrade:0", true)
    session.call("request_mining_policy", 0, true, false, true)
    session.call("request_operation", home_index, "yard", "3") # invalid gap
    session.call("request_operation", home_index, "yard", "2")
    session.call("request_operation", home_index, "yard", "3")
    session.call("request_operation", home_index, "yard", "3") # duplicate
    var state: Dictionary = session.get("economy")
    var node: int = (state["planets"] as Array).size()
    session.call("request_military", "fighter", node, 70)
    session.call("request_military", "fighter", -1, 100)
    session.call("request_military", "fighter", node, 101)

func _check_economy_sync() -> void:
    if economy_verified or str(session.get("phase")) != "match":
        return
    var state: Dictionary = session.get("economy")
    if home_index < 0 or not _check_time_controls(state):
        if role == "host" and int(Time.get_ticks_msec() / 5000) > int(get_meta("speed_debug", -1)):
            set_meta("speed_debug", int(Time.get_ticks_msec() / 5000))
            print("DEBUG: time stage=", speed_stage, " speed=", state.get("time_speed"), " elapsed=", state.get("elapsed"), " home=", home_index)
        create_timer(0.25).timeout.connect(_check_economy_sync)
        return
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
        var own_yard_jobs: Dictionary = {}
        for job in own["queue"]:
            if job["kind"] == "yard":
                own_yard_jobs[int(job["level"])] = job
        if cancelled_yard_id < 0 and own_yard_jobs.has(2) and own_yard_jobs.has(3):
            cancelled_yard_id = int(own_yard_jobs[2]["id"])
            promoted_yard_id = int(own_yard_jobs[3]["id"])
            session.call("request_cancel", home_index, cancelled_yard_id)
        elif cancelled_yard_id >= 0 and not yard_rebuilt and own_yard_jobs.has(2) and not own_yard_jobs.has(3):
            if int(own_yard_jobs[2]["id"]) != promoted_yard_id or own_yard_jobs[2]["cost"] != ECON._cost("yard", 2):
                _fail("Shipyard stack did not retain and reprice later construction.")
                return
            yard_rebuilt = true
            session.call("request_operation", home_index, "yard", "3")
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
                    ship_progress = is_equal_approx(float(job.get("population_allocated", 0.0)), float(ECON.CREW_COSTS["ship"]) * float(job["progress"]) / float(job["work"]))
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
                    ship_progress = is_equal_approx(float(ship.get("crew", 0.0)), float(ECON.CREW_COSTS["ship"]))
            var military: Dictionary = ECON.military_policy(state, owner, "fighter")
            var field_node: int = (state["planets"] as Array).size()
            var buildings: Dictionary = system.get("buildings", {})
            var priced_slots: Dictionary = {}
            for job in system["queue"]:
                if job["kind"] == "yard":
                    priced_slots[int(job["level"])] = job["cost"]
            var correct_upgrade_costs: bool = true
            for job in system["queue"]:
                if job["kind"] in ["production", "yard_upgrade"]:
                    correct_upgrade_costs = correct_upgrade_costs and job["cost"] == ECON._cost(job["kind"], int(job["level"]))
            var pds_jobs: Array = system["queue"].filter(func(order: Dictionary) -> bool: return order["kind"] == "pds")
            var defense_ok: bool = pds_jobs.size() == 1 and pds_jobs[0]["target"] == "0" and pds_jobs[0]["cost"] == ECON._cost("pds", 1)
            defense_ok = defense_ok or (pds_jobs.is_empty() and system.get("pds", {}).has(0) and system["pds"].size() == 1)
            # Commands complete at different times on different systems. Record
            # each replicated condition when observed, rather than requiring
            # every transient queue state to coexist in one snapshot.
            var equipped: Dictionary = state.get("policies", {}).get(owner, {})
            var checks: Dictionary = {
                "policy": equipped.get("defense", {}).get("card", "") == "guard" and equipped.get("defense", {}).get("targets", []).has(state["planets"].find(system)) and not equipped.has("wildcard"),
                "0": defense_ok,
                "1": correct_upgrade_costs,
                "2": priced_slots.get(2, {}) == ECON._cost("yard", 2),
                "3": priced_slots.get(3, {}) == ECON._cost("yard", 3),
                "4": int(system.get("warehouse_level", 0)) == 1,
                "5": buildings.size() == 1,
                "6": buildings.get("Textiles", false),
                "7": int(military.get(field_node, 0)) == 70,
                "8": int(military.get(ECON.military_home(state, owner), 0)) == 30,
                "9": is_equal_approx(float(thresholds["min"]), 15.0),
                "10": is_equal_approx(float(thresholds["max"]), 65.0),
                "11": flags.get("production:Organics", false),
                "12": flags.get("yard_upgrade:0", false),
                "13": flags.get("colony_ship", false),
                "14": flags.get("miner", false),
                "15": repeat_colony,
                "16": repeat_miner,
                "17": upgrade_pending,
                "18": yard_pending,
                "19": not fighter_pending,
                "20": ship_progress,
                "21": ECON.shipyard_count(system) == 3,
                "22": policy["enabled"],
                "23": not policy["Metals"],
                "24": policy["Crystals"]
            }
            var observed: Dictionary = observed_commands.get(owner, {})
            for check in checks:
                if checks[check]:
                    observed[check] = true
            observed_commands[owner] = observed
            if role == "host" and float(state["elapsed"]) >= next_diagnostic:
                var missing: Array = []
                for check in checks:
                    if not observed.has(check):
                        missing.append(check)
                print("DEBUG: owner=", owner, " missing checks=", missing, " population=", system["population"])
            if observed.size() == checks.size() and not fighter_pending and correct_upgrade_costs and ECON.shipyard_count(system) == 3:
                verified += 1
        if role == "host" and float(state["elapsed"]) >= next_diagnostic:
            next_diagnostic = float(state["elapsed"]) + 10.0
            print("DEBUG: economy elapsed=", state["elapsed"], " verified=", verified, "/", expected_players, " cancel=", cancel_sent, " stack=", yard_rebuilt, " ships=", state["ships"].size())
        var view: Node = current_scene
        if cancel_sent and yard_rebuilt and verified == expected_players and view != null and view.has_method("_update_trade_stock"):
            view.set("selected", home_index)
            view.call("_load_thresholds")
            view.call("_refresh")
            var yard_rows: Dictionary = view.get("yard_activity_rows")
            if yard_rows.size() != 3:
                _fail("All three shipyard slots must remain visible.")
                return
            for row in yard_rows.values():
                if (row["build"] as Button).visible:
                    _fail("No shipyard build button may be visible at the maximum.")
                    return
            var sliders: Dictionary = view.get("trade_sliders")
            var home: Dictionary = state["planets"][home_index]
            for index in range((home["yards"] as Array).size()):
                if not ECON.shipyard_operational(home, index) and int(home["yards"][index]["job"]) >= 0:
                    _fail("Understaffed shipyard is operating on replicated state.")
                    return
            for resource in ECON.RESOURCES:
                var slider: Control = sliders[resource]
                var stock: float = float(home["stock"][resource])
                var thresholds: Dictionary = home["thresholds"][resource]
                if not is_equal_approx(float(slider.get("stock_percent")), clampf(stock / ECON.storage_capacity(home) * 100.0, 0.0, 100.0)) or not is_equal_approx(float(slider.get("lower")), float(thresholds["min"])) or not is_equal_approx(float(slider.get("upper")), float(thresholds["max"])):
                    _fail("Replicated inventory or thresholds do not match the trade bars.")
                    return
            var expected_sectors: Array[int] = []
            var palette_roster: Dictionary = session.get("players")
            for owner in ECON.territory_empires(state):
                expected_sectors.append(int(palette_roster.get(owner, {}).get("color", 0)))
            if view.get("territory_last") != expected_sectors:
                _fail("Territory overlay does not match replicated state.")
                return
            var poses: Dictionary = view.call("_ship_poses", state)
            for ship in state["ships"]:
                if not poses.has(int(ship["id"])):
                    _fail("A replicated ship was not rendered.")
                    return
                if not ship.get("position") is Vector2 or not ship.get("navigation_target") is Vector2 or not ship.get("heading") is Vector2:
                    _fail("Ship is missing replicated physical navigation state.")
                    return
                var actual: Vector2 = ship["position"]
                var visual: Dictionary = view.get("ship_visuals").get(int(ship["id"]), {})
                if visual.is_empty() or not (visual["to"] as Vector2).is_equal_approx(actual):
                    _fail("Ship render target differs from authoritative physical position.")
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
        var pending: Dictionary = session.get("snapshot_pending")
        if pending.size() > expected_players - 1:
            _fail("More than one in-flight snapshot per guest.")
            return
        session.call("return_to_lobby")
    else:
        create_timer(0.25).timeout.connect(_return_after_all_verified)

# Verify the actual lobby scene, then explicitly disconnect rather than
# relying on process teardown to propagate an ENet disconnect.
func _finish_guest_return() -> void:
    if current_scene == null or not current_scene.has_method("_refresh_roster"):
        create_timer(0.1).timeout.connect(_finish_guest_return)
        return
    if role == "client":
        session.call("leave_session")
    _pass()

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
